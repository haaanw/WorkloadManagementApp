import Foundation
import SwiftData

/// Orchestrates recovery data flow: HealthKit fetch → baseline computation → score → snapshot upsert.
@MainActor
struct RecoveryPipeline {

    struct RecoveryResult {
        let score: Double
        let zone: RecoveryZone
        let snapshot: RecoveryScoreEngine.RecoveryResult
        let staleness: HealthKitStaleness
        /// Current cycle context, surfaced so the Dashboard can pass it into the Plan 02
        /// engine overloads without a second cycle query. `.none` when no cycle service ran.
        let cycleContext: CycleContext
        /// Number of observed cycle boundaries in the recent window (for CycleModifierGate).
        let cyclesObserved: Int
    }

    /// Run on app launch and after wellness check-in.
    ///
    /// `cycleTrackingService` is an **optional** dependency (defaults to nil) so existing
    /// callers compile unchanged. When nil, run() is byte-identical to the pre-cycle
    /// 7-day pipeline — the same-phase branch is fully guarded by `if let cycleTrackingService`.
    static func run(
        athlete: Athlete,
        healthKitService: HealthKitService,
        modelContext: ModelContext,
        syncService: SyncService? = nil,
        cycleTrackingService: CycleTrackingService? = nil
    ) async throws -> RecoveryResult {
        let recoveryRepo = RecoveryRepository(modelContext: modelContext)

        // 1. Fetch HealthKit data (staleness-aware)
        var hrv: Double?
        var rhr: Double?
        var sleep: Double?
        var bodyTemp: Double?
        var vo2Max: Double?
        var hrvDate: Date?
        var rhrDate: Date?
        var sleepDate: Date?

        // Attempt reads whenever HealthKit is available AND the user has requested access.
        // Absence of data is treated as "no recent data" downstream, never as "unauthorized".
        if healthKitService.isAvailable && healthKitService.hasRequestedAccess {
            let hrvResult = try? await healthKitService.fetchLatestHRVWithDate()
            hrv = hrvResult?.value
            hrvDate = hrvResult?.date

            let rhrResult = try? await healthKitService.fetchLatestRestingHRWithDate()
            rhr = rhrResult?.value
            rhrDate = rhrResult?.date

            let sleepResult = try? await healthKitService.fetchLastNightSleepWithDate()
            sleep = sleepResult?.value
            sleepDate = sleepResult?.date

            bodyTemp = try? await healthKitService.fetchLatestBodyTemp()
            vo2Max = try? await healthKitService.fetchLatestVO2Max()

            // Live data confirms connection → upgrade state from .requestedNoData to .connected.
            if hrv != nil || rhr != nil || sleep != nil {
                healthKitService.noteObservedData()
            }
        }

        let staleness = HealthKitStaleness(lastHRVDate: hrvDate, lastSleepDate: sleepDate, lastRHRDate: rhrDate)

        // 2. Fetch 7-day history for baselines
        let recoveryHistory = try recoveryRepo.fetchRecoveryHistory(days: 7, athlete: athlete)
        let hrvValues = recoveryHistory.compactMap(\.hrvSDNN)
        let rhrValues = recoveryHistory.compactMap(\.restingHR)
        let hrvBaseline = RecoveryScoreEngine.computeBaseline(values: hrvValues)
        let rhrBaseline = RecoveryScoreEngine.computeBaseline(values: rhrValues)

        // 3. Fetch today's wellness check-in
        let todayCheckIn = try recoveryRepo.fetchTodayWellnessCheckIn(athlete: athlete)
        let wellnessScore = todayCheckIn?.wellnessScore

        // 3b. Cycle-aware same-phase baselines (D-04/D-05/D-06/D-07).
        // Only runs when a CycleTrackingService is injected. When nil, both same-phase
        // fields stay nil → the engine uses the 7-day baselines (identical-behavior path).
        var samePhaseHRVBaseline: Double?
        var samePhaseRestingHRBaseline: Double?
        // Surfaced to the Dashboard (Phase 20) so it can call the Plan 02 engine overloads.
        // Defaults to `.none` / 0 so the nil-service path leaves them inert and run() byte-identical.
        var cycleContextForResult: CycleContext = .none
        var cyclesObservedForResult = 0
        if let cycleTrackingService {
            let ctx = await cycleTrackingService.run(athlete: athlete, context: modelContext)
            cycleContextForResult = ctx

            // Count observed cycle boundaries in a ~1-year window for the CycleModifierGate's
            // 3+ usable cycles requirement (D-05). isCycleStart rows mark cycle boundaries;
            // this never recounts regularity (confidence already encodes it — Phase 17/18).
            let cycleSnaps = (try? CycleSnapshotRepository(modelContext: modelContext)
                .fetchCycleSnapshots(days: 365, athlete: athlete)) ?? []
            cyclesObservedForResult = cycleSnaps.filter { $0.isCycleStart }.count

            // D-04 gate: confident, non-excluded, known phase.
            // D-05: OC / pregnant / lactating users (hasExclusion) always fall through to 7-day.
            let gatePasses = ctx.confidence >= 0.7 && !ctx.hasExclusion && ctx.phase != .unknown
            if gatePasses, let currentBucket = RecoveryScoreEngine.bucket(for: ctx.phase) {
                // ~3-cycle window for same-phase grouping (D-02).
                let span = min((ctx.cycleLength ?? 28) * 3 + 10, 365)
                let recoveryWindow = try recoveryRepo.fetchRecoveryHistory(days: span, athlete: athlete)
                let cycleWindow = (try? CycleSnapshotRepository(modelContext: modelContext)
                    .fetchCycleSnapshots(days: span, athlete: athlete)) ?? []

                // Read-time join: map each day's start to its estimated phase bucket.
                let calendar = Calendar.current
                var bucketByDay: [Date: RecoveryScoreEngine.PhaseBucket] = [:]
                for snap in cycleWindow {
                    guard let phase = snap.estimatedPhase,
                          let bucket = RecoveryScoreEngine.bucket(for: phase) else { continue }
                    bucketByDay[calendar.startOfDay(for: snap.date)] = bucket
                }

                // Collect same-bucket readings, using only days with actual readings
                // (compactMap) so partial days do not inflate the 4-reading minimum (D-03).
                var sameBucketHRV: [Double] = []
                var sameBucketRHR: [Double] = []
                for snap in recoveryWindow {
                    let key = calendar.startOfDay(for: snap.date)
                    guard bucketByDay[key] == currentBucket else { continue }
                    if let v = snap.hrvSDNN { sameBucketHRV.append(v) }
                    if let v = snap.restingHR { sameBucketRHR.append(v) }
                }

                // D-06 per-bucket fallback + D-03 minimum: samePhaseBaseline returns nil
                // below 4 readings, so each component independently falls back to 7-day.
                // D-07 hard switch: engine's `??` selects exactly one source per component.
                samePhaseHRVBaseline = RecoveryScoreEngine.samePhaseBaseline(readings: sameBucketHRV)
                samePhaseRestingHRBaseline = RecoveryScoreEngine.samePhaseBaseline(readings: sameBucketRHR)
            }
        }

        // 4. Compute recovery score (with trend from recent history)
        let recentScores = recoveryHistory
            .sorted { $0.date < $1.date }
            .map(\.recoveryScore)
        let input = RecoveryScoreEngine.RecoveryInput(
            hrvSDNN: hrv,
            restingHR: rhr,
            sleepDurationMinutes: sleep,
            wellnessScore: wellnessScore,
            hrvBaseline: hrvBaseline,
            restingHRBaseline: rhrBaseline,
            recentScores: recentScores,
            samePhaseHRVBaseline: samePhaseHRVBaseline,
            samePhaseRestingHRBaseline: samePhaseRestingHRBaseline
        )
        let result = RecoveryScoreEngine.compute(input: input)

        // 5. Upsert recovery snapshot (including baselines for ReasoningEngine)
        try recoveryRepo.upsertRecoverySnapshot(
            hrvSDNN: hrv,
            restingHR: rhr,
            sleepDurationMinutes: sleep,
            bodyTemp: bodyTemp,
            vo2Max: vo2Max,
            recoveryScore: result.score,
            hrvBaseline: hrvBaseline,
            restingHRBaseline: rhrBaseline,
            athlete: athlete
        )

        if let syncService {
            let athleteId = athlete.id
            Task {
                await syncService.pushRecoveryAndWellness(context: modelContext, athleteId: athleteId)
            }
        }

        // 6. Shadow-mode logging (Phase 20, D-03). Local-only — runs ONLY when a cycle
        //    service is injected, so the nil-service path is byte-identical (D-12). No cycle
        //    or shadow field is added to upsertRecoverySnapshot or the syncService push (D-13).
        if cycleTrackingService != nil {
            // Stage 2 first: resolve yesterday-and-earlier rows against observed outcomes.
            try? ShadowAnalyticsService.resolveOutcomes(athlete: athlete, asOf: .now, modelContext: modelContext)

            // Stage 1: write today's prediction row (predictions are about tomorrow).
            // Build recent series from already-fetched / cheap reads. Completion = 1/0 per day.
            let calendar = Calendar.current
            let sortedHistory = recoveryHistory.sorted { $0.date < $1.date }
            let recoverySeries = sortedHistory.map(\.recoveryScore)

            let workoutRepo = WorkoutRepository(modelContext: modelContext)
            let recentSessions = (try? workoutRepo.fetchSessions(last: 7, athlete: athlete)) ?? []
            let sessionDays = Set(recentSessions.map { calendar.startOfDay(for: $0.sessionDate) })
            var completionSeries: [Double] = []
            for offset in stride(from: 6, through: 0, by: -1) {
                let day = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -offset, to: .now)!)
                completionSeries.append(sessionDays.contains(day) ? 1.0 : 0.0)
            }

            let wellnessCheckIns = (try? fetchRecentWellness(athlete: athlete, modelContext: modelContext)) ?? []
            let wellnessSeries = wellnessCheckIns.map(\.wellnessScore)
            let painSeries = wellnessCheckIns.map { Double($0.soreness) }

            // Would-be modifier effects (computed, never applied — activation off).
            let zoneForFactor = result.zone
            let autoInput = AutoregulationEngine.DailyInput(
                recoveryZone: zoneForFactor,
                recoveryScore: result.score,
                acwrZone: .noData,
                acwr: 0,
                wellnessScore: wellnessScore,
                daysSinceLastRest: 0
            )
            let wouldBeVolumeFactor = AutoregulationEngine.cycleVolumeFactor(
                input: autoInput, cycleContext: cycleContextForResult
            )

            try? ShadowAnalyticsService.recordPrediction(
                athlete: athlete,
                context: cycleContextForResult,
                cyclesObserved: cyclesObservedForResult,
                recoveryHistory: recoverySeries,
                wellnessHistory: wellnessSeries,
                completionHistory: completionSeries,
                painHistory: painSeries,
                wouldBeVolumeFactor: wouldBeVolumeFactor,
                wouldBeDampenedFatigueIndex: nil,
                wouldBiasProgressionToMaintain: nil,
                modelContext: modelContext
            )
        }

        return RecoveryResult(
            score: result.score,
            zone: result.zone,
            snapshot: result,
            staleness: staleness,
            cycleContext: cycleContextForResult,
            cyclesObserved: cyclesObservedForResult
        )
    }

    /// Recent wellness check-ins (last 7 days, oldest first) for shadow wellness/pain series.
    private static func fetchRecentWellness(
        athlete: Athlete,
        modelContext: ModelContext
    ) throws -> [WellnessCheckIn] {
        let start = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        let athleteId = athlete.id
        let descriptor = FetchDescriptor<WellnessCheckIn>(
            predicate: #Predicate { $0.date >= start && $0.athlete?.id == athleteId },
            sortBy: [SortDescriptor(\.date)]
        )
        return try modelContext.fetch(descriptor)
    }
}
