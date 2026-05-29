import Foundation
import SwiftData

/// Two-stage shadow-mode orchestration (Phase 20, D-03). **Local-only — never syncs.**
///
/// Stage 1 (`recordPrediction`): at recovery-pipeline run time, write a `CyclePredictionLog`
/// row keyed on today with baseline + cycle-aware predictions for all four outcomes (the
/// predictions are about *tomorrow*), plus the would-be Plan 02 modifier effects (recorded,
/// never applied). Outcome actuals start nil.
///
/// Stage 2 (`resolveOutcomes`): on a later run, find prior-day unresolved rows and fill in
/// the observed actuals by date-join against the persisted RecoverySnapshot / WellnessCheckIn /
/// WorkoutSession. Idempotent: already-resolved rows are skipped.
///
/// `aggregate`: pure MAE math over resolved rows — the shadow signal a future "modifier
/// activation" phase reads to decide whether to flip `CycleModifierActivation.isEnabled`.
@MainActor
struct ShadowAnalyticsService {

    // MARK: - Aggregation output

    struct OutcomeMAE {
        var baselineMAE: Double
        var cycleAwareMAE: Double
        var n: Int
    }

    // MARK: - Stage 1: record prediction

    /// Write today's Stage-1 prediction row. `recoveryHistory` / `wellnessHistory` are recent
    /// series (oldest first) used by `ShadowPredictor` for the persistence/trend baseline;
    /// `completionHistory` is recent per-day completion indicators (0/1). The would-be modifier
    /// effects are captured from the Plan 02 helpers but NOT applied.
    static func recordPrediction(
        athlete: Athlete,
        context: CycleContext,
        cyclesObserved: Int,
        recoveryHistory: [Double],
        wellnessHistory: [Double],
        completionHistory: [Double],
        painHistory: [Double],
        wouldBeVolumeFactor: Double?,
        wouldBeDampenedFatigueIndex: Double?,
        wouldBiasProgressionToMaintain: Bool?,
        modelContext: ModelContext
    ) throws {
        let phase = context.phase
        let bucketRaw: String? = {
            switch RecoveryScoreEngine.bucket(for: phase) {
            case .follicular: return "follicular"
            case .luteal: return "luteal"
            case .none: return nil
            }
        }()

        let repo = CyclePredictionLogRepository(modelContext: modelContext)
        try repo.upsertPrediction(date: .now, athlete: athlete) { row in
            row.estimatedPhase = phase
            row.phaseBucketRaw = bucketRaw
            row.confidence = context.confidence
            row.hadExclusion = context.hasExclusion

            row.recoveryBaseline = ShadowPredictor.baselinePrediction(series: recoveryHistory)
            row.recoveryCycleAware = ShadowPredictor.cycleAwarePrediction(series: recoveryHistory, phase: phase, outcome: .recovery)

            row.wellnessBaseline = ShadowPredictor.baselinePrediction(series: wellnessHistory)
            row.wellnessCycleAware = ShadowPredictor.cycleAwarePrediction(series: wellnessHistory, phase: phase, outcome: .wellness)

            row.completionBaseline = ShadowPredictor.baselinePrediction(series: completionHistory)
            row.completionCycleAware = ShadowPredictor.cycleAwarePrediction(series: completionHistory, phase: phase, outcome: .completion)

            row.painBaseline = ShadowPredictor.baselinePrediction(series: painHistory)
            row.painCycleAware = ShadowPredictor.cycleAwarePrediction(series: painHistory, phase: phase, outcome: .pain)

            // Would-be modifier effects (recorded, never applied — activation off).
            row.wouldBeVolumeFactor = wouldBeVolumeFactor
            row.wouldBeDampenedFatigueIndex = wouldBeDampenedFatigueIndex
            row.wouldBiasProgressionToMaintain = wouldBiasProgressionToMaintain
        }
    }

    // MARK: - Stage 2: resolve outcomes (idempotent)

    /// Fill in observed actuals for unresolved rows whose target day is before `asOf`'s day.
    /// Idempotent — already-resolved rows are not refetched (the repo filters `resolvedAt == nil`),
    /// and a row is only marked resolved once its day's observations are joined.
    @discardableResult
    static func resolveOutcomes(
        athlete: Athlete,
        asOf: Date = .now,
        modelContext: ModelContext
    ) throws -> Int {
        let repo = CyclePredictionLogRepository(modelContext: modelContext)
        let recoveryRepo = RecoveryRepository(modelContext: modelContext)
        let workoutRepo = WorkoutRepository(modelContext: modelContext)

        let unresolved = try repo.fetchUnresolved(olderThan: asOf, athlete: athlete)
        guard !unresolved.isEmpty else { return 0 }

        let calendar = Calendar.current

        // Pull observation windows once, keyed by start-of-day.
        let lookbackDays = max(1, (calendar.dateComponents([.day],
            from: unresolved.first!.date, to: asOf).day ?? 1) + 1)
        let recoverySnaps = (try? recoveryRepo.fetchRecoveryHistory(days: lookbackDays + 2, athlete: athlete)) ?? []
        let sessions = (try? workoutRepo.fetchSessions(last: lookbackDays + 2, athlete: athlete)) ?? []

        var recoveryByDay: [Date: Double] = [:]
        for snap in recoverySnaps {
            recoveryByDay[calendar.startOfDay(for: snap.date)] = snap.recoveryScore
        }
        var sessionDays: Set<Date> = []
        for s in sessions {
            sessionDays.insert(calendar.startOfDay(for: s.sessionDate))
        }
        // Wellness check-ins (wellness + pain actuals) within the same window.
        let wellnessByDay = try fetchWellnessByDay(
            startDay: calendar.startOfDay(for: unresolved.first!.date),
            athlete: athlete, modelContext: modelContext
        )

        var resolvedCount = 0
        for row in unresolved {
            let day = calendar.startOfDay(for: row.date)

            if let rec = recoveryByDay[day] { row.recoveryActual = rec }
            if let w = wellnessByDay[day] {
                row.wellnessActual = w.wellness
                row.painActual = Double(w.soreness)
            }
            // Completion actual: 1 if a session was logged that day, else 0 (always observable).
            row.completionActual = sessionDays.contains(day) ? 1.0 : 0.0

            row.resolvedAt = .now
            row.updatedAt = .now
            resolvedCount += 1
        }
        try repo.save()
        return resolvedCount
    }

    private static func fetchWellnessByDay(
        startDay: Date,
        athlete: Athlete?,
        modelContext: ModelContext
    ) throws -> [Date: (wellness: Double, soreness: Int)] {
        let descriptor: FetchDescriptor<WellnessCheckIn>
        if let athlete {
            let athleteId = athlete.id
            descriptor = FetchDescriptor<WellnessCheckIn>(
                predicate: #Predicate { $0.date >= startDay && $0.athlete?.id == athleteId },
                sortBy: [SortDescriptor(\.date)]
            )
        } else {
            descriptor = FetchDescriptor<WellnessCheckIn>(
                predicate: #Predicate { $0.date >= startDay },
                sortBy: [SortDescriptor(\.date)]
            )
        }
        let checkIns = try modelContext.fetch(descriptor)
        let calendar = Calendar.current
        var map: [Date: (wellness: Double, soreness: Int)] = [:]
        for c in checkIns {
            map[calendar.startOfDay(for: c.date)] = (c.wellnessScore, c.soreness)
        }
        return map
    }

    // MARK: - Aggregation (pure MAE)

    /// Mean absolute error of baseline vs cycle-aware predictions per outcome over resolved
    /// rows. Rows missing an outcome's actual (or its predictions) are excluded from that
    /// outcome's MAE only. Pure — no I/O.
    static func aggregate(resolvedRows: [CyclePredictionLog]) -> [ShadowPredictor.Outcome: OutcomeMAE] {
        var result: [ShadowPredictor.Outcome: OutcomeMAE] = [:]

        func mae(
            _ outcome: ShadowPredictor.Outcome,
            baseline: (CyclePredictionLog) -> Double?,
            cycleAware: (CyclePredictionLog) -> Double?,
            actual: (CyclePredictionLog) -> Double?
        ) {
            var baseSum = 0.0, cycleSum = 0.0, n = 0
            for row in resolvedRows {
                guard let b = baseline(row), let c = cycleAware(row), let a = actual(row) else { continue }
                baseSum += ShadowPredictor.absoluteError(predicted: b, actual: a)
                cycleSum += ShadowPredictor.absoluteError(predicted: c, actual: a)
                n += 1
            }
            guard n > 0 else { return }
            result[outcome] = OutcomeMAE(baselineMAE: baseSum / Double(n), cycleAwareMAE: cycleSum / Double(n), n: n)
        }

        mae(.recovery, baseline: { $0.recoveryBaseline }, cycleAware: { $0.recoveryCycleAware }, actual: { $0.recoveryActual })
        mae(.wellness, baseline: { $0.wellnessBaseline }, cycleAware: { $0.wellnessCycleAware }, actual: { $0.wellnessActual })
        mae(.completion, baseline: { $0.completionBaseline }, cycleAware: { $0.completionCycleAware }, actual: { $0.completionActual })
        mae(.pain, baseline: { $0.painBaseline }, cycleAware: { $0.painCycleAware }, actual: { $0.painActual })

        return result
    }
}
