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
    }

    /// Run on app launch and after wellness check-in.
    /// v1.5 self-coached path: HRV / RHR / sleep / wellness + ordinary 7-day baselines only.
    static func run(
        athlete: Athlete,
        healthKitService: HealthKitService,
        modelContext: ModelContext,
        syncService: SyncService? = nil
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

            // Reflect the LATEST full read cycle: data present → .connected; nothing returned →
            // .requestedNoData (e.g. access revoked in Settings, or no recent samples). This is an
            // authoritative cycle (all reads attempted), so it may downgrade a stale .connected.
            // hasRequestedAccess stays sticky, so the connect CTA never reappears.
            healthKitService.updateObservedData(hrv != nil || rhr != nil || sleep != nil)
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
            recentScores: recentScores
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

        return RecoveryResult(
            score: result.score,
            zone: result.zone,
            snapshot: result,
            staleness: staleness
        )
    }
}
