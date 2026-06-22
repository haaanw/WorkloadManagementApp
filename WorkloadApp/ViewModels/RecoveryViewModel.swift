import Foundation
import SwiftData

/// ViewModel for the Recovery tab.
/// Manages recovery history, HRV trends, and wellness check-in triggers.
@MainActor
@Observable
final class RecoveryViewModel {
    var recoveryHistory: [RecoverySnapshot] = []
    var hrvHistory: [(date: Date, value: Double)] = []

    // Fatigue insights (INTEL-04, INTEL-05)
    var fatigueInsights: [FatiguePatternEngine.Insight] = []

    // Behavior correlations (INTEL-07)
    var behaviorCorrelations: [BehaviorCorrelationEngine.TagCorrelation] = []
    var behaviorSufficiency: [BehaviorCorrelationEngine.SufficiencyInfo] = []

    var isLoading = false

    func load(
        athlete: Athlete,
        healthKitService: HealthKitService,
        modelContext: ModelContext
    ) async {
        isLoading = true

        let recoveryRepo = RecoveryRepository(modelContext: modelContext)

        // Fetch 28-day recovery history
        recoveryHistory = (try? recoveryRepo.fetchRecoveryHistory(days: 28, athlete: athlete)) ?? []

        // Fetch HRV history from HealthKit
        if healthKitService.isAuthorized {
            hrvHistory = (try? await healthKitService.fetchHRVHistory(days: 28)) ?? []
        }
        #if DEBUG
        // SCREENSHOT_MODE: HealthKit unauthorized — derive HRV trend from seeded snapshots
        if hrvHistory.isEmpty,
           ProcessInfo.processInfo.arguments.contains("SCREENSHOT_MODE") {
            hrvHistory = recoveryHistory
                .compactMap { snap in snap.hrvSDNN.map { (date: snap.date, value: $0) } }
                .sorted { $0.date < $1.date }
        }
        #endif

        // Fatigue pattern detection (INTEL-04, INTEL-05)
        let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: .now)!
        let workloadRepo = WorkloadRepository(modelContext: modelContext)
        let workoutRepo = WorkoutRepository(modelContext: modelContext)
        let workloadSnapshots = (try? workloadRepo.fetchSnapshots(from: ninetyDaysAgo, to: .now, athlete: athlete)) ?? []
        let sessions = (try? workoutRepo.fetchSessions(from: ninetyDaysAgo, to: .now, athlete: athlete)) ?? []
        let recoverySnaps = (try? recoveryRepo.fetchSnapshots(from: ninetyDaysAgo, to: .now, athlete: athlete)) ?? []

        fatigueInsights = FatiguePatternEngine.detectPatterns(
            workloadSnapshots: workloadSnapshots,
            recoverySnapshots: recoverySnaps,
            sessions: sessions
        )

        // Behavior correlation (INTEL-07)
        let behaviorTagRepo = BehaviorTagRepository(modelContext: modelContext)
        let allTags = (try? behaviorTagRepo.fetchAllTags(days: 90, athlete: athlete)) ?? []
        if !allTags.isEmpty {
            behaviorCorrelations = BehaviorCorrelationEngine.computeCorrelations(
                tags: allTags,
                recoverySnapshots: recoverySnaps
            )
            behaviorSufficiency = BehaviorCorrelationEngine.checkSufficiency(tags: allTags, recoverySnapshots: recoverySnaps)
        }

        isLoading = false
    }

    /// Re-trigger recovery pipeline after wellness check-in.
    func onWellnessCheckInSaved(
        athlete: Athlete,
        healthKitService: HealthKitService,
        modelContext: ModelContext
    ) async {
        _ = try? await RecoveryPipeline.run(
            athlete: athlete,
            healthKitService: healthKitService,
            modelContext: modelContext
        )
        await load(
            athlete: athlete,
            healthKitService: healthKitService,
            modelContext: modelContext
        )
    }
}
