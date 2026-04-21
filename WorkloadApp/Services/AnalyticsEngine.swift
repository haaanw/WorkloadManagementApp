import Foundation

/// Pure analytics computation engine. No state, no side effects.
/// Computes weekly summaries with week-over-week deltas for the analytics dashboard.
struct AnalyticsEngine {

    // MARK: - Data Types

    enum TrendDirection: String {
        case increasing
        case decreasing
        case stable
    }

    struct WeeklySummary {
        let sessionCount: Int
        let totalVolume: Double
        let avgRecoveryScore: Double
        let loadTrendDirection: TrendDirection
        let acwrZoneDistribution: [ACWRZone: Int]
        let sessionCountDelta: Double   // percentage vs previous week (+12.0 = +12%)
        let volumeDelta: Double         // percentage vs previous week
        let recoveryDelta: Double       // percentage vs previous week
    }

    // MARK: - Weekly Summary (ANLYT-02, ANLYT-03)

    /// Compute weekly summary comparing current 7-day window to previous 7-day window.
    static func computeWeeklySummary(
        currentWeekSessions: [WorkoutSession],
        previousWeekSessions: [WorkoutSession],
        currentWeekRecoverySnapshots: [RecoverySnapshot],
        previousWeekRecoverySnapshots: [RecoverySnapshot],
        currentWeekWorkloadSnapshots: [WorkloadSnapshot]
    ) -> WeeklySummary {
        let sessionCount = currentWeekSessions.count
        let totalVolume = currentWeekSessions.reduce(0.0) { $0 + $1.totalVolume }
        let avgRecovery = currentWeekRecoverySnapshots.isEmpty ? 0 :
            currentWeekRecoverySnapshots.reduce(0.0) { $0 + $1.recoveryScore } / Double(currentWeekRecoverySnapshots.count)

        // Load trend: compare first half vs second half of current week snapshots
        let loadTrend: TrendDirection = {
            guard currentWeekWorkloadSnapshots.count >= 4 else { return .stable }
            let sorted = currentWeekWorkloadSnapshots.sorted { $0.snapshotDate < $1.snapshotDate }
            let mid = sorted.count / 2
            let firstHalf = sorted.prefix(mid).map(\.acuteLoad).reduce(0, +) / Double(mid)
            let secondHalf = sorted.suffix(from: mid).map(\.acuteLoad).reduce(0, +) / Double(sorted.count - mid)
            if secondHalf > firstHalf * 1.05 { return .increasing }
            if secondHalf < firstHalf * 0.95 { return .decreasing }
            return .stable
        }()

        // Zone distribution from workload snapshots
        var zoneDistribution: [ACWRZone: Int] = [:]
        for snapshot in currentWeekWorkloadSnapshots {
            zoneDistribution[snapshot.zone, default: 0] += 1
        }

        // Week-over-week deltas (ANLYT-03)
        let prevSessionCount = previousWeekSessions.count
        let prevVolume = previousWeekSessions.reduce(0.0) { $0 + $1.totalVolume }
        let prevAvgRecovery = previousWeekRecoverySnapshots.isEmpty ? 0 :
            previousWeekRecoverySnapshots.reduce(0.0) { $0 + $1.recoveryScore } / Double(previousWeekRecoverySnapshots.count)

        let sessionDelta = prevSessionCount > 0 ? ((Double(sessionCount) - Double(prevSessionCount)) / Double(prevSessionCount)) * 100 : 0
        let volumeDelta = prevVolume > 0 ? ((totalVolume - prevVolume) / prevVolume) * 100 : 0
        let recoveryDelta = prevAvgRecovery > 0 ? ((avgRecovery - prevAvgRecovery) / prevAvgRecovery) * 100 : 0

        return WeeklySummary(
            sessionCount: sessionCount,
            totalVolume: totalVolume,
            avgRecoveryScore: avgRecovery,
            loadTrendDirection: loadTrend,
            acwrZoneDistribution: zoneDistribution,
            sessionCountDelta: sessionDelta,
            volumeDelta: volumeDelta,
            recoveryDelta: recoveryDelta
        )
    }
}
