import Foundation
import SwiftData

/// Scans a completed workout session for new Personal Records.
/// Runs synchronously after each session save.
struct PRDetector {

    /// Detect PRs in a completed session by comparing against existing records.
    /// Returns newly created PersonalRecord instances (not yet inserted into context).
    static func detectPRs(
        session: WorkoutSession,
        existingPRs: [PersonalRecord]
    ) -> [PersonalRecord] {
        var newPRs: [PersonalRecord] = []

        for entry in session.exerciseEntries {
            let workingSets = entry.sets.filter { !$0.isWarmup }
            guard !workingSets.isEmpty else { continue }

            // Max Weight PR
            if let maxWeightSet = workingSets.compactMap({ set -> (weight: Double, reps: Int)? in
                guard let w = set.weightKg, w > 0, let r = set.reps, r > 0 else { return nil }
                return (w, r)
            }).max(by: { $0.weight < $1.weight }) {
                let currentPR = existingPRs.first {
                    $0.exerciseName == entry.exerciseName && $0.recordType == .maxWeight
                }
                if currentPR == nil || maxWeightSet.weight > (currentPR?.value ?? 0) {
                    let pr = PersonalRecord(
                        exerciseName: entry.exerciseName,
                        recordType: .maxWeight,
                        value: maxWeightSet.weight,
                        achievedAt: session.sessionDate,
                        sessionId: session.id,
                        previousValue: currentPR?.value
                    )
                    newPRs.append(pr)
                }
            }

            // Max Reps PR (at any weight)
            if let maxRepsSet = workingSets.compactMap({ $0.reps }).max() {
                let currentPR = existingPRs.first {
                    $0.exerciseName == entry.exerciseName && $0.recordType == .maxReps
                }
                if currentPR == nil || Double(maxRepsSet) > (currentPR?.value ?? 0) {
                    let pr = PersonalRecord(
                        exerciseName: entry.exerciseName,
                        recordType: .maxReps,
                        value: Double(maxRepsSet),
                        achievedAt: session.sessionDate,
                        sessionId: session.id,
                        previousValue: currentPR?.value
                    )
                    newPRs.append(pr)
                }
            }

            // Max Volume PR (single set: weight × reps)
            let maxVolume = workingSets.map { $0.volume }.max() ?? 0
            if maxVolume > 0 {
                let currentPR = existingPRs.first {
                    $0.exerciseName == entry.exerciseName && $0.recordType == .maxVolume
                }
                if currentPR == nil || maxVolume > (currentPR?.value ?? 0) {
                    let pr = PersonalRecord(
                        exerciseName: entry.exerciseName,
                        recordType: .maxVolume,
                        value: maxVolume,
                        achievedAt: session.sessionDate,
                        sessionId: session.id,
                        previousValue: currentPR?.value
                    )
                    newPRs.append(pr)
                }
            }
        }

        return newPRs
    }
}
