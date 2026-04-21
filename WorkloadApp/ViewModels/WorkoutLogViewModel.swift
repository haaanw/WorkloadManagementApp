import Foundation
import SwiftData

/// ViewModel for the Workout Log tab.
/// Handles post-save pipeline execution and session deletion with recompute.
@MainActor
@Observable
final class WorkoutLogViewModel {
    var newPRs: [PersonalRecord] = []
    var showPRCelebration = false

    /// Called after a workout is saved from ActiveWorkoutSheet.
    func onSessionSaved(
        session: WorkoutSession,
        athlete: Athlete,
        modelContext: ModelContext,
        syncService: SyncService? = nil
    ) {
        do {
            let result = try WorkoutPipeline.processSession(
                session,
                athlete: athlete,
                modelContext: modelContext,
                syncService: syncService
            )
            if !result.newPRs.isEmpty {
                newPRs = result.newPRs
                showPRCelebration = true
            }
        } catch {
            print("Workout pipeline error: \(error)")
        }
    }

    /// Called after a session is deleted — recompute workload from scratch.
    func onSessionDeleted(
        athlete: Athlete,
        modelContext: ModelContext
    ) {
        do {
            try WorkoutPipeline.recomputeHistory(
                athlete: athlete,
                modelContext: modelContext
            )
        } catch {
            print("Recompute error: \(error)")
        }
    }
}
