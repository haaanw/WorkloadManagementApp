import Foundation

/// Pure CSV generation engine. No state, no side effects.
/// Excludes raw HealthKit data (HRV, RHR, sleep) per Apple guidelines — only composite scores.
struct CSVExportEngine {

    // MARK: - Session Summary (EXPORT-01)

    /// One row per workout session: date, sport, duration, RPE, volume, load, ATL, CTL, ACWR.
    static func sessionSummaryCSV(sessions: [WorkoutSession]) -> String {
        var lines = ["Date,Sport,Duration (min),RPE,Volume,Load,ATL,CTL,ACWR"]
        for session in sessions.sorted(by: { $0.sessionDate < $1.sessionDate }) {
            let date = ISO8601DateFormatter().string(from: session.sessionDate)
            let sport = escapeCSV(session.sportType.rawValue)
            let rpe = session.sessionRPE.map { String(format: "%.0f", $0) } ?? ""
            let acwr = session.chronicLoad > 0 ? String(format: "%.2f", session.acuteLoad / session.chronicLoad) : ""
            let line = "\(date),\(sport),\(String(format: "%.0f", session.durationMinutes)),\(rpe),\(String(format: "%.1f", session.totalVolume)),\(String(format: "%.1f", session.internalLoad)),\(String(format: "%.1f", session.acuteLoad)),\(String(format: "%.1f", session.chronicLoad)),\(acwr)"
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Detailed Sets (EXPORT-01)

    /// One row per working set: date, exercise, set#, reps, weight, RPE.
    static func detailedSetsCSV(sessions: [WorkoutSession]) -> String {
        var lines = ["Date,Exercise,Set,Reps,Weight (kg),RPE"]
        for session in sessions.sorted(by: { $0.sessionDate < $1.sessionDate }) {
            let date = ISO8601DateFormatter().string(from: session.sessionDate)
            for entry in session.sortedEntries {
                for set in entry.sortedSets where !set.isWarmup {
                    let exercise = escapeCSV(entry.exerciseName)
                    let reps = set.reps.map { String($0) } ?? ""
                    let weight = set.weightKg.map { String(format: "%.1f", $0) } ?? ""
                    let rpe = set.rpe.map { String(format: "%.1f", $0) } ?? ""
                    lines.append("\(date),\(exercise),\(set.setIndex + 1),\(reps),\(weight),\(rpe)")
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    /// RFC 4180: wrap fields containing commas or quotes in double-quotes, escape inner quotes by doubling.
    private static func escapeCSV(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }
}
