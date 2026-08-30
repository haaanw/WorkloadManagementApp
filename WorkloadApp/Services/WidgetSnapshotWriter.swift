import Foundation
import SwiftData
#if canImport(WidgetKit)
import WidgetKit
#endif

/// The app-side publisher: turns pipeline results into the `WidgetSnapshot` the
/// home-screen widgets read, and asks WidgetKit to redraw.
///
/// **Membership: app target ONLY** (the extension never writes).
///
/// Call sites (one per pipeline, per the widget architecture):
/// - `RecoveryPipeline.run` → `publishReadiness` (score + zone; verdict preserved)
/// - `DashboardViewModel.load` → `publishVerdictLine` + `publishLoad` (the one place
///   the autoregulation headline exists)
/// - `WorkoutPipeline.processSession` / `recomputeHistory` → `publishLoad`
///
/// Everything published is COMPOSITE (scores, zones, a verdict sentence, day-total
/// training loads). No raw HealthKit value may pass through here — the on-device
/// raw-data law extends to the App Group container.
@MainActor
struct WidgetSnapshotWriter {

    /// How many day-totals the load sparkline carries.
    static let loadSeriesDays = 7

    // MARK: - Publish

    /// Readiness half: today's recovery score + zone. The verdict line is left as-is —
    /// it arrives separately from the dashboard, which is the only place the
    /// autoregulation headline is computed.
    static func publishReadiness(score: Double, zone: RecoveryZone) {
        guard shouldPublish else { return }
        WidgetSnapshotStore.merge { snapshot in
            snapshot.readinessScore = Int(score.rounded())
            snapshot.readinessZoneKey = zone.rawValue
            snapshot.readinessZoneLabel = zone.displayName
        }
        reloadWidgets()
    }

    /// The verdict sentence beneath the readiness score. nil is a no-op (never blank an
    /// existing verdict because one load pass had no recommendation).
    static func publishVerdictLine(_ line: String?) {
        guard shouldPublish, let line, !line.isEmpty else { return }
        WidgetSnapshotStore.merge { snapshot in
            snapshot.verdictLine = line
        }
        reloadWidgets()
    }

    /// Load half: ACWR + zone from the caller (so a cold-start seeded ACWR publishes the
    /// same number the dashboard shows), and the 7-day day-total series computed here
    /// from logged sessions (sRPE/TSS composites; rest days are honest zeros).
    static func publishLoad(
        acwr: Double?,
        zone: ACWRZone,
        modelContext: ModelContext,
        athlete: Athlete
    ) {
        guard shouldPublish else { return }
        let series = dailyLoadSeries(modelContext: modelContext, athlete: athlete)
        WidgetSnapshotStore.merge { snapshot in
            snapshot.acwr = zone == .noData ? nil : acwr
            snapshot.acwrZoneKey = zone.rawValue
            snapshot.acwrZoneLabel = zone.displayName
            snapshot.dailyLoads = series
        }
        reloadWidgets()
    }

    // MARK: - Helpers

    /// Contiguous day totals for the last `loadSeriesDays` days (oldest → today), same
    /// grouping rule as `WorkoutPipeline.buildDailyLoads` — days without a session are 0.
    static func dailyLoadSeries(
        modelContext: ModelContext,
        athlete: Athlete,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> [WidgetSnapshot.DailyLoad] {
        // Direct fetch, athlete filtered in Swift (the RecoveryRepository idiom — the
        // optional-relationship `#Predicate` is the documented SIGABRT trap). +1 day on
        // the cutoff: `now - N×24h` would drop early-morning sessions on the window's
        // oldest calendar day; days outside the 7-day window are ignored below anyway.
        let windowStart = calendar.date(
            byAdding: .day, value: -(loadSeriesDays + 1), to: now
        ) ?? now
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.sessionDate >= windowStart },
            sortBy: [SortDescriptor(\.sessionDate)]
        )
        let athleteId = athlete.id
        let sessions = ((try? modelContext.fetch(descriptor)) ?? [])
            .filter { $0.athlete?.id == athleteId }

        var dailyTotals: [Date: Double] = [:]
        for session in sessions {
            let day = calendar.startOfDay(for: session.sessionDate)
            dailyTotals[day, default: 0] += session.trainingStress
        }

        let today = calendar.startOfDay(for: now)
        return stride(from: loadSeriesDays - 1, through: 0, by: -1).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return WidgetSnapshot.DailyLoad(day: day, load: dailyTotals[day] ?? 0)
        }
    }

    /// SCREENSHOT_MODE seeds a mock athlete; its numbers must never reach a real
    /// widget. Simulator-only compile guard, mirroring the AppRouter incident guard.
    private static var shouldPublish: Bool {
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("SCREENSHOT_MODE") { return false }
        #endif
        return true
    }

    private static func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
