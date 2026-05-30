import Foundation
import SwiftData

/// Two-stage shadow-mode orchestration (Phase 20, D-03; Phase 24 data-contract). **Local-only — never syncs.**
///
/// Stage 1 (`recordPrediction`): at recovery-pipeline run time, write a `CyclePredictionLog`
/// row keyed on **predictionDate = today** with `targetDate = today + horizon`. For each
/// registered experimental arm (Phase 24, D-11) and each outcome, write one `ShadowArmPrediction`
/// child row (the generic per-arm store) — plus the legacy `*Baseline`/`*CycleAware` columns in
/// parallel for migration safety (D-12 fallback). Outcome actuals start nil.
///
/// Stage 2 (`resolveOutcomes`): on a later run, find rows whose **targetDate** has elapsed and
/// fill in the observed actuals by joining persisted RecoverySnapshot / WellnessCheckIn /
/// WorkoutSession on **targetDate** (NOT predictionDate — this closes the same-day leak, D-03).
/// Idempotent: already-resolved rows are skipped.
///
/// `aggregate`: pure MAE math over resolved rows, reading per-arm predictions from the arm store.
/// `metricsReport`: thin orchestration exposing the Phase-24 ShadowMetrics (calibration, Spearman,
/// paired-MAE-difference CI) per arm/outcome — all math delegated to the pure `ShadowMetrics`.
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
    /// `completionHistory` is recent per-day adherence indicators (0/1). The would-be modifier
    /// effects are captured from the Plan 02 helpers but NOT applied.
    ///
    /// Phase 24: predictions for every registered arm are written through the generic
    /// `ShadowArmPrediction` store; the legacy columns are written in parallel for the two existing
    /// arms only (migration safety). The arm store is the source of truth for aggregation.
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
        horizonDays: Int = 1,
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

        // History series per outcome (feature cutoff already enforced at the pipeline boundary).
        func series(for outcome: ShadowPredictor.Outcome) -> [Double] {
            switch outcome {
            case .recovery:   return recoveryHistory
            case .wellness:   return wellnessHistory
            case .completion: return completionHistory
            case .pain:       return painHistory
            }
        }

        let arms = ShadowPredictor.registeredArms()

        let repo = CyclePredictionLogRepository(modelContext: modelContext)
        try repo.upsertPrediction(predictionDate: .now, horizonDays: horizonDays, athlete: athlete) { row in
            row.estimatedPhase = phase
            row.phaseBucketRaw = bucketRaw
            row.confidence = context.confidence
            row.hadExclusion = context.hasExclusion

            // Generic per-arm store (D-11/D-12): one child row per (arm × outcome).
            // Re-running the same day: clear prior arm rows so we don't accumulate duplicates.
            for old in row.armPredictions {
                modelContext.delete(old)
            }
            row.armPredictions.removeAll()
            for arm in arms {
                for outcome in ShadowPredictor.Outcome.allCases {
                    guard let predicted = arm.predict(outcome, series(for: outcome), context) else { continue }
                    let child = ShadowArmPrediction(armId: arm.id, outcome: outcome, predicted: predicted)
                    child.log = row
                    modelContext.insert(child)
                }
            }

            // Legacy columns (parallel, migration safety) for the two existing arms.
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

    /// Fill in observed actuals for unresolved rows whose **target** day is before `asOf`'s day.
    /// Idempotent — already-resolved rows are not refetched (the repo filters `resolvedAt == nil`),
    /// and a row is only marked resolved once its **targetDate**'s observations are joined (D-03).
    @discardableResult
    static func resolveOutcomes(
        athlete: Athlete,
        asOf: Date = .now,
        modelContext: ModelContext
    ) throws -> Int {
        let repo = CyclePredictionLogRepository(modelContext: modelContext)
        let recoveryRepo = RecoveryRepository(modelContext: modelContext)
        let workoutRepo = WorkoutRepository(modelContext: modelContext)

        let unresolved = try repo.fetchUnresolved(targetBefore: asOf, athlete: athlete)
        guard !unresolved.isEmpty else { return 0 }

        let calendar = Calendar.current

        // Pull observation windows once, keyed by start-of-day. Window spans the earliest
        // targetDate through asOf so every row's target day is covered.
        let earliestTarget = unresolved.map(\.targetDate).min() ?? asOf
        let lookbackDays = max(1, (calendar.dateComponents([.day],
            from: earliestTarget, to: asOf).day ?? 1) + 1)
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
            startDay: calendar.startOfDay(for: earliestTarget),
            athlete: athlete, modelContext: modelContext
        )

        var resolvedCount = 0
        for row in unresolved {
            // D-03 (bug fix): join ALL actuals on the TARGET day, never the prediction day.
            let day = calendar.startOfDay(for: row.targetDate)

            if let rec = recoveryByDay[day] { row.recoveryActual = rec }
            if let w = wellnessByDay[day] {
                row.wellnessActual = w.wellness
                row.painActual = Double(w.soreness)
            }
            // Adherence actual: 1 if a session was logged on the target day, else 0 (always observable).
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

    // MARK: - Aggregation (pure MAE over the arm store)

    /// Mean absolute error of the `"baseline"` vs `"cycleAware"` arms per outcome over resolved
    /// rows, reading predictions from the generic `ShadowArmPrediction` store. Rows missing an
    /// outcome's actual (or an arm's prediction) are excluded from that outcome's MAE only. Pure —
    /// no I/O. Reproduces the Phase-20 MAE numbers through the new unified path (D-13).
    static func aggregate(resolvedRows: [CyclePredictionLog]) -> [ShadowPredictor.Outcome: OutcomeMAE] {
        var result: [ShadowPredictor.Outcome: OutcomeMAE] = [:]

        func actual(_ outcome: ShadowPredictor.Outcome, _ row: CyclePredictionLog) -> Double? {
            switch outcome {
            case .recovery:   return row.recoveryActual
            case .wellness:   return row.wellnessActual
            case .completion: return row.completionActual
            case .pain:       return row.painActual
            }
        }

        for outcome in ShadowPredictor.Outcome.allCases {
            var baseSum = 0.0, cycleSum = 0.0, n = 0
            for row in resolvedRows {
                guard let b = row.armPrediction(armId: "baseline", outcome: outcome),
                      let c = row.armPrediction(armId: "cycleAware", outcome: outcome),
                      let a = actual(outcome, row) else { continue }
                baseSum += ShadowPredictor.absoluteError(predicted: b, actual: a)
                cycleSum += ShadowPredictor.absoluteError(predicted: c, actual: a)
                n += 1
            }
            guard n > 0 else { continue }
            result[outcome] = OutcomeMAE(baselineMAE: baseSum / Double(n), cycleAwareMAE: cycleSum / Double(n), n: n)
        }

        return result
    }
}
