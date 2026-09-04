import Foundation
import SwiftData

/// Time range options for workload trend charts (ANLYT-01). Moved here from
/// `WorkloadViewModel` with the Trends merge (v1.7.3 reorientation slice 3) — the range
/// control and this enum outlive the retired Load tab.
enum TimeRange: String, CaseIterable, Identifiable {
    case fourWeeks = "4W"
    case twelveWeeks = "12W"
    case sixMonths = "6M"

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .fourWeeks: return 28
        case .twelveWeeks: return 84
        case .sixMonths: return 180
        }
    }
}

/// ViewModel for the merged Trends tab (v1.7.3 reorientation slice 3, APP-REORIENTATION
/// Option A). One owner for everything the retired Recovery and Load tabs fetched for
/// their glance surfaces: the HRV/sleep trend series, the load trend + correlation
/// windows, and the insight engines.
///
/// The zoomed detail screens are NOT fed from here — `HRVDetailScreen` /
/// `SleepDetailScreen` own their fetches (one fetch path for one screen; the audit's
/// appendix §6 found two parallel 90-day fetches whose only consumers were those pushes).
@MainActor
@Observable
final class TrendsViewModel {

    // MARK: Recovery-side glance state (from RecoveryViewModel)

    /// 28-day recovery history — the insights-encouragement guard reads its count.
    var recoveryHistory: [RecoverySnapshot] = []
    /// 28-day HRV glance series: DAILY morning-window values, not raw samples — see
    /// `HRVDailyStats` for the reduction and its limits.
    var hrvGlance: [(date: Date, value: Double)] = []

    // Fatigue insights (INTEL-04, INTEL-05)
    var fatigueInsights: [FatiguePatternEngine.Insight] = []

    // Behavior correlations (INTEL-07)
    var behaviorCorrelations: [BehaviorCorrelationEngine.TagCorrelation] = []
    var behaviorSufficiency: [BehaviorCorrelationEngine.SufficiencyInfo] = []

    // MARK: Load-side trend state (from WorkloadViewModel)

    /// The load chart's data itself derives in the VIEW from its reactive
    /// `@Query` + the free-tier filter (`visibleSnapshots`), exactly as the retired
    /// Load tab built it — a range change re-slices without a fetch.
    var selectedRange: TimeRange = .fourWeeks
    var correlationLoadSnapshots: [WorkloadSnapshot] = []
    var correlationRecoverySnapshots: [RecoverySnapshot] = []

    var isLoading = false

    /// Full load: glance series, trend windows, insight engines. Idempotent — the view
    /// calls it on task, on scene activation, and on day change (the RecoveryView idiom:
    /// `.task` runs once per appearance, so an overnight background otherwise leaves
    /// yesterday rendered as today).
    func load(
        athlete: Athlete,
        healthKitService: any HealthDataProviding,
        modelContext: ModelContext
    ) async {
        isLoading = true

        let recoveryRepo = RecoveryRepository(modelContext: modelContext)
        recoveryHistory = (try? recoveryRepo.fetchRecoveryHistory(days: 28, athlete: athlete)) ?? []

        // (The sleep glance's HealthKit nights are fetched by the VIEW — `fetchSleepNights`
        // is not on the `HealthDataProviding` seam, and the RecoveryView precedent kept
        // that call at the call site.)

        // HRV glance — 28 days of daily morning-window values.
        if healthKitService.isAuthorized {
            let rawSamples = (try? await healthKitService.fetchHRVHistory(days: 28)) ?? []
            hrvGlance = HRVDailyStats
                .dailyValues(samples: rawSamples, days: 28)
                .map { (date: $0.date, value: $0.value) }
        }
        #if DEBUG
        // SCREENSHOT_MODE: HealthKit unauthorized — derive the HRV glance from seeded
        // snapshots (already one value per day, so no bucketing).
        if hrvGlance.isEmpty,
           ProcessInfo.processInfo.arguments.contains("SCREENSHOT_MODE") {
            hrvGlance = recoveryHistory
                .compactMap { snap in snap.hrvSDNN.map { (date: snap.date, value: $0) } }
                .sorted { $0.date < $1.date }
        }
        #endif

        // Correlation windows — always 28 days (the Recovery-vs-Load chart's contract).
        let workloadRepo = WorkloadRepository(modelContext: modelContext)
        correlationLoadSnapshots = (try? workloadRepo.fetchSnapshots(last: 28, athlete: athlete)) ?? []
        correlationRecoverySnapshots = recoveryHistory

        // Fatigue pattern detection (INTEL-04, INTEL-05)
        let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: .now)!
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
}
