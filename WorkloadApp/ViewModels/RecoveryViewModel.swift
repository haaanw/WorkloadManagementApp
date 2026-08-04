import Foundation
import SwiftData

/// ViewModel for the Recovery tab.
/// Manages recovery history, HRV trends, and wellness check-in triggers.
@MainActor
@Observable
final class RecoveryViewModel {
    var recoveryHistory: [RecoverySnapshot] = []
    var hrvHistory: [(date: Date, value: Double)] = []
    /// 90-day HRV series for the pinch-zoomable detail screen (v1.7.1); `hrvHistory`
    /// stays the glance chart's 28-day window and derives from this.
    var hrvHistoryExtended: [(date: Date, value: Double)] = []

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

        // Fetch HRV history from HealthKit: one 90-day fetch, 28-day glance window derived.
        let cutoff28 = Calendar.current.date(
            byAdding: .day, value: -28,
            to: Calendar.current.startOfDay(for: .now)
        )!
        if healthKitService.isAuthorized {
            hrvHistoryExtended = (try? await healthKitService.fetchHRVHistory(days: 90)) ?? []
        }
        #if DEBUG
        // SCREENSHOT_MODE: HealthKit unauthorized — derive HRV trend from seeded snapshots
        if hrvHistoryExtended.isEmpty,
           ProcessInfo.processInfo.arguments.contains("SCREENSHOT_MODE") {
            hrvHistoryExtended = recoveryHistory
                .compactMap { snap in snap.hrvSDNN.map { (date: snap.date, value: $0) } }
                .sorted { $0.date < $1.date }
        }
        #endif
        hrvHistory = hrvHistoryExtended.filter { $0.date >= cutoff28 }

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
