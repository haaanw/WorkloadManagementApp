import SwiftUI
import SwiftData

/// The ONE fetch path into the zoomed trend screens (v1.7.3 reorientation slice 3,
/// APP-REORIENTATION R7 / appendix §6).
///
/// Before the Trends merge, Home and the Recovery tab each ran their OWN 90-day HRV +
/// snapshot fetches (`DashboardViewModel.hrv90Days` / `RecoveryViewModel.hrvHistoryExtended`)
/// whose only consumers were these pushes — two query paths for one screen. Every
/// `TrendDestination` now lands here, and the screens own their data; the pure rendering
/// views (`HRVDetailView` / `SleepDetailView`) keep their data-in initializers untouched.
struct HRVDetailScreen: View {
    @Environment(AppContainer.self) private var container
    @Query private var athletes: [Athlete]
    @Query(sort: \RecoverySnapshot.date, order: .reverse)
    private var recoverySnapshots: [RecoverySnapshot]

    /// 90 days of DAILY morning-window values (`HRVDailyStats`), matching the pinch
    /// window's maximum — the same series both retired paths built.
    @State private var data: [(date: Date, value: Double)] = []
    @State private var rawSampleCount = 0

    var body: some View {
        HRVDetailView(data: data, rawSampleCount: rawSampleCount)
            .task { await load() }
    }

    private func load() async {
        // Day-bucket to the morning window BEFORE anything reads it: a Watch writes
        // several SDNN samples a day, so raw-sample statistics called ~1–2 days of
        // data "7-day" (v1.7.1). See `HRVDailyStats` for the reduction and its limits.
        let rawSamples = (try? await container.healthKitService.fetchHRVHistory(days: 90)) ?? []
        rawSampleCount = rawSamples.count
        data = HRVDailyStats
            .dailyValues(samples: rawSamples, days: 90)
            .map { (date: $0.date, value: $0.value) }
        #if DEBUG
        // SCREENSHOT_MODE: HealthKit unauthorized — derive the series from seeded
        // snapshots, which are already one value per day (no bucketing needed).
        if data.isEmpty,
           ProcessInfo.processInfo.arguments.contains("SCREENSHOT_MODE") {
            let athleteId = athletes.first?.id
            data = recoverySnapshots
                .filter { $0.athlete?.id == athleteId }
                .compactMap { snap in snap.hrvSDNN.map { (date: snap.date, value: $0) } }
                .sorted { $0.date < $1.date }
            rawSampleCount = data.count
        }
        #endif
    }
}

/// `SleepDetailView` fetches its own HealthKit nights already; what callers were
/// duplicating was the 90-day snapshot FALLBACK window (pre-fix persisted values, used
/// only when HealthKit has no nights). That window is now built here, once, reactively.
struct SleepDetailScreen: View {
    @Query private var athletes: [Athlete]
    @Query(sort: \RecoverySnapshot.date, order: .reverse)
    private var recoverySnapshots: [RecoverySnapshot]

    /// Oldest-first 90-day window — the same shape `RecoveryView.sleepWindowExtended`
    /// and `DashboardViewModel.recentSnapshots90` used to build in parallel.
    private var snapshots90: [RecoverySnapshot] {
        guard let athleteId = athletes.first?.id else { return [] }
        return Array(
            recoverySnapshots
                .filter { $0.athlete?.id == athleteId }
                .prefix(90)
                .reversed()
        )
    }

    var body: some View {
        SleepDetailView(snapshots: snapshots90)
    }
}
