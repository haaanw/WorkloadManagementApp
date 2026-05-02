import SwiftUI
import SwiftData
import UIKit

@main
struct WorkloadApp: App {
    let container: ModelContainer

    init() {
        #if DEBUG
        assert(
            UIFont(name: "DMSans-Regular", size: 15) != nil,
            "DMSans-Regular font not found. Add DMSans-Regular.ttf to the project and UIAppFonts in Info.plist."
        )
        assert(
            UIFont(name: "DMSans-Medium", size: 15) != nil,
            "DMSans-Medium font not found. Add DMSans-Medium.ttf to the project and UIAppFonts in Info.plist."
        )
        #endif

        do {
            let schema = Schema([
                Athlete.self,
                WorkoutSession.self,
                ExerciseEntry.self,
                SetRecord.self,
                WorkloadSnapshot.self,
                RecoverySnapshot.self,
                WellnessCheckIn.self,
                PersonalRecord.self,
                CoachAthleteRelationship.self,
                WorkoutTemplate.self,
                ExerciseGroup.self,
                TemplateExercise.self,
                TemplateSet.self,
                PrescribedWorkout.self,
                CustomExercise.self,
                BehaviorTag.self,
                TrainingProfile.self,
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRouter()
        }
        .modelContainer(container)
    }
}
