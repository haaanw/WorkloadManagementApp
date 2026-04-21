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

        if healthKitService.isAuthorized {
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
        }

        let staleness = HealthKitStaleness(lastHRVDate: hrvDate, lastSleepDate: sleepDate, lastRHRDate: rhrDate)

        // 2. Fetch 7-day history for baselines
        let recoveryHistory = try recoveryRepo.fetchRecoveryHistory(days: 7)
        let hrvValues = recoveryHistory.compactMap(\.hrvSDNN)
        let rhrValues = recoveryHistory.compactMap(\.restingHR)
        let hrvBaseline = RecoveryScoreEngine.computeBaseline(values: hrvValues)
        let rhrBaseline = RecoveryScoreEngine.computeBaseline(values: rhrValues)

        // 3. Fetch today's wellness check-in
        let todayCheckIn = try recoveryRepo.fetchTodayWellnessCheckIn()
        let wellnessScore = todayCheckIn?.wellnessScore

        // 4. Compute recovery score
        let input = RecoveryScoreEngine.RecoveryInput(
            hrvSDNN: hrv,
            restingHR: rhr,
            sleepDurationMinutes: sleep,
            wellnessScore: wellnessScore,
            hrvBaseline: hrvBaseline,
            restingHRBaseline: rhrBaseline
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
            restingHRBaseline: rhrBaseline
        )

        // 6. Link snapshot to athlete
        let today = Calendar.current.startOfDay(for: .now)
        let predicate = #Predicate<RecoverySnapshot> { $0.date == today }
        let descriptor = FetchDescriptor<RecoverySnapshot>(predicate: predicate)
        if let snapshot = try modelContext.fetch(descriptor).first {
            snapshot.athlete = athlete
            try modelContext.save()
        }

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
