import Foundation

/// Detects the athlete's current training phase from load history.
/// Pure struct with static methods -- no state, no side effects.
struct PeriodizationEngine {

    // MARK: - Types

    enum TrainingPhase: String, Codable {
        case building    // Volume increasing, intensity stable/moderate
        case pushing     // Intensity increasing, volume stable/decreasing
        case tapering    // Both volume and intensity decreasing
        case maintaining // Stable load, no clear trend
    }

    struct PhaseResult {
        let phase: TrainingPhase
        let confidence: Double
        let weeksSinceTransition: Int

        var displayLabel: String {
            switch phase {
            case .building:    return String(localized: "trainingPhase.building", defaultValue: "Building")
            case .pushing:     return String(localized: "trainingPhase.pushing", defaultValue: "Pushing")
            case .tapering:    return String(localized: "trainingPhase.tapering", defaultValue: "Tapering")
            case .maintaining: return String(localized: "trainingPhase.maintaining", defaultValue: "Maintaining")
            }
        }
    }

    struct SufficiencyResult {
        let isSufficient: Bool
        let weeksAvailable: Int
        let weeksRequired: Int
        let avgSessionsPerWeek: Double
    }

    // MARK: - Data Sufficiency (INTEL-03)

    /// Check whether enough training history exists for phase detection.
    /// Requires at least `minimumWeeks` (default 8) and `minimumSessionsPerWeek` (default 3.0).
    static func checkSufficiency(
        sessions: [WorkoutSession],
        minimumWeeks: Int = 8,
        minimumSessionsPerWeek: Double = 3.0
    ) -> SufficiencyResult {
        guard let earliest = sessions.map(\.sessionDate).min() else {
            return SufficiencyResult(
                isSufficient: false,
                weeksAvailable: 0,
                weeksRequired: minimumWeeks,
                avgSessionsPerWeek: 0
            )
        }

        let daysSinceEarliest = Calendar.current.dateComponents(
            [.day], from: earliest, to: .now
        ).day ?? 0
        let weeksAvailable = max(1, daysSinceEarliest / 7)
        let avgPerWeek = Double(sessions.count) / Double(weeksAvailable)

        return SufficiencyResult(
            isSufficient: weeksAvailable >= minimumWeeks && avgPerWeek >= minimumSessionsPerWeek,
            weeksAvailable: weeksAvailable,
            weeksRequired: minimumWeeks,
            avgSessionsPerWeek: avgPerWeek
        )
    }

    // MARK: - Phase Detection (INTEL-01)

    /// Detect the current training phase from volume and intensity trends.
    /// Returns nil if data is insufficient or recent window is a rest week.
    /// T-03-03 mitigation: limits analysis to last 90 days max.
    static func detectPhase(
        workloadSnapshots: [WorkloadSnapshot],
        sessions: [WorkoutSession],
        windowWeeks: Int = 6
    ) -> PhaseResult? {
        // T-03-03: limit to 90 days max
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: .now)!
        let recentSessions = sessions.filter { $0.sessionDate >= cutoff }

        guard recentSessions.count >= 6 else { return nil }

        // Group sessions into weekly buckets
        let weeklyBuckets = groupByWeek(sessions: recentSessions, weeks: windowWeeks)
        guard weeklyBuckets.count >= windowWeeks else { return nil }

        // Split into recent (last 3 weeks) and previous (3 weeks before that)
        let recentWindow = Array(weeklyBuckets.suffix(3))
        let previousWindow = Array(weeklyBuckets.dropLast(3).suffix(3))

        guard previousWindow.count == 3 else { return nil }

        // Guard: rest week detection -- if recent window has < 2 sessions/week average, return nil
        let recentSessionCount = recentWindow.reduce(0) { $0 + $1.count }
        let recentSessionsPerWeek = Double(recentSessionCount) / Double(recentWindow.count)
        guard recentSessionsPerWeek >= 2.0 else { return nil }

        // Compute weekly totals
        let recentVolumes = recentWindow.map { weekSessions in
            weekSessions.reduce(0.0) { $0 + $1.totalVolume }
        }
        let previousVolumes = previousWindow.map { weekSessions in
            weekSessions.reduce(0.0) { $0 + $1.totalVolume }
        }

        // Note: When no sessions have RPE, weekly RPE averages default to 0.
        // This causes intensityChange to be 0 (meanPreviousRPE <= 0 guard below),
        // so phase classification relies solely on volume trends.
        // This is intentional -- volume-only detection is valid.
        let recentRPEs = recentWindow.map { weekSessions -> Double in
            let rpeSessions = weekSessions.compactMap(\.sessionRPE)
            return rpeSessions.isEmpty ? 0 : rpeSessions.reduce(0, +) / Double(rpeSessions.count)
        }
        let previousRPEs = previousWindow.map { weekSessions -> Double in
            let rpeSessions = weekSessions.compactMap(\.sessionRPE)
            return rpeSessions.isEmpty ? 0 : rpeSessions.reduce(0, +) / Double(rpeSessions.count)
        }

        let meanRecentVolume = recentVolumes.reduce(0, +) / Double(recentVolumes.count)
        let meanPreviousVolume = previousVolumes.reduce(0, +) / Double(previousVolumes.count)
        let meanRecentRPE = recentRPEs.reduce(0, +) / Double(recentRPEs.count)
        let meanPreviousRPE = previousRPEs.reduce(0, +) / Double(previousRPEs.count)

        // Calculate change percentages
        let volumeChange: Double = meanPreviousVolume > 0
            ? (meanRecentVolume - meanPreviousVolume) / meanPreviousVolume * 100
            : 0

        let intensityChange: Double = meanPreviousRPE > 0
            ? (meanRecentRPE - meanPreviousRPE) / meanPreviousRPE * 100
            : 0

        // Classify phase
        let phase: TrainingPhase
        let dominantSignal: Double

        if volumeChange > 10 && intensityChange < 10 {
            phase = .building
            dominantSignal = abs(volumeChange)
        } else if intensityChange > 10 && volumeChange < 10 {
            phase = .pushing
            dominantSignal = abs(intensityChange)
        } else if volumeChange < -10 && intensityChange < -10 {
            phase = .tapering
            dominantSignal = max(abs(volumeChange), abs(intensityChange))
        } else {
            phase = .maintaining
            dominantSignal = max(abs(volumeChange), abs(intensityChange))
        }

        // Confidence = magnitude of dominant signal, clamped 0.5 to 1.0
        let confidence = min(1.0, max(0.5, dominantSignal / 30.0))

        // Estimate weeks since transition (simplified: look for when trend direction changed)
        let weeksSinceTransition = estimateTransitionWeeks(
            weeklyBuckets: weeklyBuckets,
            currentPhase: phase
        )

        return PhaseResult(
            phase: phase,
            confidence: confidence,
            weeksSinceTransition: weeksSinceTransition
        )
    }

    // MARK: - Private Helpers

    /// Group sessions into weekly buckets, most recent last.
    private static func groupByWeek(
        sessions: [WorkoutSession],
        weeks: Int
    ) -> [[WorkoutSession]] {
        let calendar = Calendar.current
        let now = Date.now
        var buckets: [[WorkoutSession]] = Array(repeating: [], count: weeks)

        for session in sessions {
            let daysBefore = calendar.dateComponents(
                [.day], from: session.sessionDate, to: now
            ).day ?? 0
            let weekIndex = weeks - 1 - (daysBefore / 7)
            if weekIndex >= 0 && weekIndex < weeks {
                buckets[weekIndex].append(session)
            }
        }
        return buckets
    }

    /// Estimate how many weeks ago the current trend started.
    private static func estimateTransitionWeeks(
        weeklyBuckets: [[WorkoutSession]],
        currentPhase: TrainingPhase
    ) -> Int {
        let weeklyVolumes = weeklyBuckets.map { weekSessions in
            weekSessions.reduce(0.0) { $0 + $1.totalVolume }
        }

        guard weeklyVolumes.count >= 3 else { return 1 }

        // Walk backwards from most recent week looking for when the trend changed
        var consecutiveWeeks = 1
        for i in stride(from: weeklyVolumes.count - 2, through: 0, by: -1) {
            let current = weeklyVolumes[i + 1]
            let previous = weeklyVolumes[i]
            let trendUp = current > previous * 1.05
            let trendDown = current < previous * 0.95

            let matchesCurrent: Bool
            switch currentPhase {
            case .building:    matchesCurrent = trendUp
            case .tapering:    matchesCurrent = trendDown
            case .pushing:     matchesCurrent = !trendDown
            case .maintaining: matchesCurrent = !trendUp && !trendDown
            }

            if matchesCurrent {
                consecutiveWeeks += 1
            } else {
                break
            }
        }
        return consecutiveWeeks
    }
}
