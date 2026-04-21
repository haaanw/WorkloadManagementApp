import Foundation

/// Computes recovery impact percentages for behavior tags.
/// Pure struct with static methods -- no state, no side effects.
struct BehaviorCorrelationEngine {

    // MARK: - Types

    struct TagCorrelation {
        let tagName: String
        let recoveryWithTag: Double
        let recoveryWithoutTag: Double
        let impactPercentage: Double
        let sampleCountWith: Int
        let sampleCountWithout: Int
        let isSufficient: Bool
    }

    struct SufficiencyInfo {
        let tagName: String
        let daysWithTag: Int
        let daysWithoutTag: Int
        let neededWith: Int
        let neededWithout: Int
    }

    // MARK: - Correlation Computation (INTEL-07, D-09)

    /// Compute recovery impact for each behavior tag.
    /// Only returns correlations where BOTH with-tag and without-tag groups
    /// have >= `minimumSamplesPerGroup` samples (default 5).
    static func computeCorrelations(
        tags: [BehaviorTag],
        recoverySnapshots: [RecoverySnapshot],
        minimumSamplesPerGroup: Int = 5
    ) -> [TagCorrelation] {
        let calendar = Calendar.current

        // Build date-indexed recovery scores
        var dailyRecovery: [Date: Double] = [:]
        for snapshot in recoverySnapshots {
            let day = calendar.startOfDay(for: snapshot.date)
            dailyRecovery[day] = snapshot.recoveryScore
        }

        guard !dailyRecovery.isEmpty else { return [] }

        // Determine analysis window: all dates that have recovery scores
        let allRecoveryDates = Set(dailyRecovery.keys)

        // Group tags by name
        var tagsByName: [String: [BehaviorTag]] = [:]
        for tag in tags {
            tagsByName[tag.tagName, default: []].append(tag)
        }

        var correlations: [TagCorrelation] = []

        for (tagName, tagInstances) in tagsByName {
            // Dates where tag was active
            let activeDates: Set<Date> = Set(
                tagInstances
                    .filter(\.isActive)
                    .map { calendar.startOfDay(for: $0.date) }
            )

            // Dates without tag (within analysis window)
            let inactiveDates = allRecoveryDates.subtracting(activeDates)

            // Collect recovery scores for each group
            let withTagScores = activeDates.compactMap { dailyRecovery[$0] }
            let withoutTagScores = inactiveDates.compactMap { dailyRecovery[$0] }

            let isSufficient = withTagScores.count >= minimumSamplesPerGroup
                && withoutTagScores.count >= minimumSamplesPerGroup

            // Only return correlation if both groups have enough samples
            guard isSufficient else { continue }

            let meanWith = withTagScores.reduce(0, +) / Double(withTagScores.count)
            let meanWithout = withoutTagScores.reduce(0, +) / Double(withoutTagScores.count)

            let impact: Double = meanWithout > 0
                ? ((meanWith - meanWithout) / meanWithout * 100).rounded(toPlaces: 1)
                : 0

            correlations.append(TagCorrelation(
                tagName: tagName,
                recoveryWithTag: meanWith,
                recoveryWithoutTag: meanWithout,
                impactPercentage: impact,
                sampleCountWith: withTagScores.count,
                sampleCountWithout: withoutTagScores.count,
                isSufficient: true
            ))
        }

        return correlations.sorted { abs($0.impactPercentage) > abs($1.impactPercentage) }
    }

    // MARK: - Sufficiency Check

    /// Check how many more days of data are needed per tag before correlations can be computed.
    static func checkSufficiency(
        tags: [BehaviorTag],
        minimumSamplesPerGroup: Int = 5
    ) -> [SufficiencyInfo] {
        let calendar = Calendar.current
        var tagsByName: [String: [BehaviorTag]] = [:]
        for tag in tags {
            tagsByName[tag.tagName, default: []].append(tag)
        }

        return tagsByName.map { tagName, tagInstances in
            let activeDays = Set(
                tagInstances
                    .filter(\.isActive)
                    .map { calendar.startOfDay(for: $0.date) }
            ).count

            let inactiveDays = Set(
                tagInstances
                    .filter { !$0.isActive }
                    .map { calendar.startOfDay(for: $0.date) }
            ).count

            return SufficiencyInfo(
                tagName: tagName,
                daysWithTag: activeDays,
                daysWithoutTag: inactiveDays,
                neededWith: max(0, minimumSamplesPerGroup - activeDays),
                neededWithout: max(0, minimumSamplesPerGroup - inactiveDays)
            )
        }.sorted { $0.tagName < $1.tagName }
    }
}

// MARK: - Double Extension

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
