import SwiftData
import Foundation

/// In-memory ModelContainer and sample data for Xcode Previews
@MainActor
enum PreviewData {
    static var container: ModelContainer {
        let schema = Schema([
            Athlete.self,
            WorkoutSession.self,
            ExerciseEntry.self,
            SetRecord.self,
            WorkloadSnapshot.self,
            RecoverySnapshot.self,
            WellnessCheckIn.self,
            PersonalRecord.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])

        // Insert sample data
        let context = container.mainContext
        let athlete = sampleAthlete
        context.insert(athlete)

        let session = sampleSession
        session.athlete = athlete
        context.insert(session)

        let snapshot = sampleWorkloadSnapshot
        snapshot.athlete = athlete
        context.insert(snapshot)

        let recovery = sampleRecoverySnapshot
        recovery.athlete = athlete
        context.insert(recovery)

        return container
    }

    static var sampleAthlete: Athlete {
        Athlete(
            displayName: "Alex Thompson",
            sportType: .lifting,
            weightUnit: .kg,
            acwrMethod: .ewma
        )
    }

    static var sampleSession: WorkoutSession {
        let session = WorkoutSession(
            sessionDate: .now,
            sessionName: "Upper Body Push",
            sportType: .lifting,
            durationSeconds: 3600,
            sessionRPE: 7
        )

        let bench = ExerciseEntry(
            exerciseName: "Barbell Bench Press",
            exerciseCategory: .compound,
            muscleGroup: .chest,
            orderIndex: 0
        )
        bench.sets = [
            SetRecord(setIndex: 0, reps: 5, weightKg: 100, isWarmup: false),
            SetRecord(setIndex: 1, reps: 5, weightKg: 100, isWarmup: false),
            SetRecord(setIndex: 2, reps: 4, weightKg: 100, isWarmup: false),
        ]
        session.exerciseEntries.append(bench)
        session.recalculateDerivedFields()
        return session
    }

    static var sampleWorkloadSnapshot: WorkloadSnapshot {
        WorkloadSnapshot(
            snapshotDate: .now,
            acuteLoad: 320,
            chronicLoad: 300,
            acwr: 1.07,
            tsb: -20,
            weeklyVolume: 15000,
            loadSource: .srpe
        )
    }

    static var sampleRecoverySnapshot: RecoverySnapshot {
        RecoverySnapshot(
            date: .now,
            hrvSDNN: 52,
            restingHR: 58,
            sleepDurationMinutes: 430,
            recoveryScore: 78,
            dataSource: .healthKit
        )
    }

    static var sampleWellnessCheckIn: WellnessCheckIn {
        WellnessCheckIn(
            date: .now,
            sleepQuality: 4,
            soreness: 3,
            energy: 4,
            stress: 4
        )
    }
}
