import Foundation

/// Identifies recurring recovery dips correlated with training load spikes.
/// Pure struct with static methods -- no state, no side effects.
struct FatiguePatternEngine {

    // MARK: - Types

    struct Insight {
        let text: String
        let confidence: Double
        let sampleSize: Int
    }

    // MARK: - Pattern Detection (INTEL-04, INTEL-05)

    /// Detect lag-correlated recovery dips following high-load training days.
    /// Returns up to 5 insights sorted by confidence descending.
    static func detectPatterns(
        workloadSnapshots: [WorkloadSnapshot],
        recoverySnapshots: [RecoverySnapshot],
        sessions: [WorkoutSession],
        minimumSamples: Int = 5
    ) -> [Insight] {
        // T-03-03 mitigation: limit to 90 days
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: .now)!
        let recentSnapshots = workloadSnapshots.filter { $0.snapshotDate >= cutoff }

        // Build date-indexed dictionaries
        let calendar = Calendar.current
        var dailyTSS: [Date: Double] = [:]
        var dailyRecovery: [Date: Double] = [:]

        for snapshot in recentSnapshots {
            let day = calendar.startOfDay(for: snapshot.snapshotDate)
            dailyTSS[day] = snapshot.acuteLoad
        }

        // If we have sessions with trainingStress, use that as TSS source too
        for session in sessions.filter({ $0.sessionDate >= cutoff }) {
            let day = calendar.startOfDay(for: session.sessionDate)
            dailyTSS[day, default: 0] += session.trainingStress
        }

        for snapshot in recoverySnapshots.filter({ $0.date >= cutoff }) {
            let day = calendar.startOfDay(for: snapshot.date)
            dailyRecovery[day] = snapshot.recoveryScore
        }

        guard dailyTSS.count >= 14, dailyRecovery.count >= 14 else { return [] }

        // Compute rolling 14-day mean TSS
        let sortedDates = dailyTSS.keys.sorted()
        var rollingMean: [Date: Double] = [:]
        for (index, date) in sortedDates.enumerated() {
            let windowStart = max(0, index - 13)
            let window = sortedDates[windowStart...index]
            let windowValues = window.compactMap { dailyTSS[$0] }
            if !windowValues.isEmpty {
                rollingMean[date] = windowValues.reduce(0, +) / Double(windowValues.count)
            }
        }

        // Identify high-load days: TSS > 1.5x rolling 14-day mean
        let highLoadDays = sortedDates.filter { date in
            guard let tss = dailyTSS[date], let mean = rollingMean[date], mean > 0 else { return false }
            return tss > mean * 1.5
        }

        let nonHighLoadDays = Set(sortedDates).subtracting(Set(highLoadDays))

        var insights: [Insight] = []

        // Check lag of 1, 2, 3 days
        for lag in 1...3 {
            let highLoadDeltas = collectRecoveryDeltas(
                days: highLoadDays, lag: lag, dailyRecovery: dailyRecovery, calendar: calendar
            )
            let nonHighLoadDeltas = collectRecoveryDeltas(
                days: Array(nonHighLoadDays), lag: lag, dailyRecovery: dailyRecovery, calendar: calendar
            )

            guard highLoadDeltas.count >= minimumSamples,
                  nonHighLoadDeltas.count >= minimumSamples else { continue }

            let highLoadMeanDelta = highLoadDeltas.reduce(0, +) / Double(highLoadDeltas.count)
            let nonHighLoadMeanDelta = nonHighLoadDeltas.reduce(0, +) / Double(nonHighLoadDeltas.count)
            let deltaDifference = highLoadMeanDelta - nonHighLoadMeanDelta

            // If high-load mean delta is worse by > 5 points
            if deltaDifference < -5 {
                let dropAmount = abs(highLoadMeanDelta)
                let confidence = computeConfidence(
                    sampleSize: highLoadDeltas.count,
                    deltaDifference: abs(deltaDifference)
                )
                let dayWord = lag == 1 ? "day" : "days"
                insights.append(Insight(
                    text: "Recovery typically drops \(Int(dropAmount)) points \(lag) \(dayWord) after high-volume sessions",
                    confidence: confidence,
                    sampleSize: highLoadDeltas.count
                ))
            }
        }

        // Check by sport type if sessions have that info
        let sportTypeInsights = detectSportTypePatterns(
            sessions: sessions.filter { $0.sessionDate >= cutoff },
            highLoadDays: Set(highLoadDays),
            dailyRecovery: dailyRecovery,
            calendar: calendar,
            minimumSamples: minimumSamples
        )
        insights.append(contentsOf: sportTypeInsights)

        // Sort by confidence, cap at 5
        return Array(insights.sorted { $0.confidence > $1.confidence }.prefix(5))
    }

    // MARK: - Private Helpers

    /// Collect recovery score deltas at a given lag from a set of days.
    private static func collectRecoveryDeltas(
        days: [Date],
        lag: Int,
        dailyRecovery: [Date: Double],
        calendar: Calendar
    ) -> [Double] {
        var deltas: [Double] = []
        for day in days {
            guard let lagDate = calendar.date(byAdding: .day, value: lag, to: day),
                  let baseScore = dailyRecovery[day],
                  let lagScore = dailyRecovery[calendar.startOfDay(for: lagDate)] else { continue }
            deltas.append(lagScore - baseScore)
        }
        return deltas
    }

    /// Detect sport-type-specific fatigue patterns.
    private static func detectSportTypePatterns(
        sessions: [WorkoutSession],
        highLoadDays: Set<Date>,
        dailyRecovery: [Date: Double],
        calendar: Calendar,
        minimumSamples: Int
    ) -> [Insight] {
        var insights: [Insight] = []

        // Group high-load sessions by sport type
        var sportGroupedDays: [SportType: [Date]] = [:]
        for session in sessions {
            let day = calendar.startOfDay(for: session.sessionDate)
            guard highLoadDays.contains(day) else { continue }
            sportGroupedDays[session.sportType, default: []].append(day)
        }

        for (sportType, days) in sportGroupedDays {
            guard days.count >= minimumSamples else { continue }
            let uniqueDays = Array(Set(days))

            for lag in 1...3 {
                let deltas = collectRecoveryDeltas(
                    days: uniqueDays, lag: lag, dailyRecovery: dailyRecovery, calendar: calendar
                )
                guard deltas.count >= minimumSamples else { continue }

                let meanDelta = deltas.reduce(0, +) / Double(deltas.count)
                if meanDelta < -5 {
                    let dropAmount = abs(meanDelta)
                    let confidence = computeConfidence(
                        sampleSize: deltas.count,
                        deltaDifference: abs(meanDelta)
                    )
                    let dayWord = lag == 1 ? "day" : "days"
                    insights.append(Insight(
                        text: "Recovery typically drops \(Int(dropAmount)) points \(lag) \(dayWord) after high-volume \(sportType.displayName) sessions",
                        confidence: confidence,
                        sampleSize: deltas.count
                    ))
                }
            }
        }

        return insights
    }

    /// Compute confidence from sample size and delta magnitude.
    /// Confidence = min(1.0, sampleSize / 15.0) * (deltaDifference / 20.0), clamped 0.3-1.0.
    private static func computeConfidence(sampleSize: Int, deltaDifference: Double) -> Double {
        let sizeFactor = min(1.0, Double(sampleSize) / 15.0)
        let deltaFactor = deltaDifference / 20.0
        return min(1.0, max(0.3, sizeFactor * deltaFactor))
    }
}
