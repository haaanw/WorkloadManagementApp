import SwiftUI
import SwiftData
import UIKit

@main
struct WorkloadApp: App {
    let container: ModelContainer

    init() {
        #if DEBUG
        assert(
            UIFont.familyNames.contains(where: { $0.localizedCaseInsensitiveContains("general") }),
            "General Sans font not found. Add GeneralSans-Variable.ttf to the project and UIAppFonts in Info.plist."
        )
        assert(
            UIFont.familyNames.contains(where: { $0.localizedCaseInsensitiveContains("noto sans sc") }),
            "Noto Sans SC not registered. Add NotoSansSC-Regular.otf + NotoSansSC-Medium.otf and UIAppFonts entries."
        )
        // One-shot DEBUG print: exact PostScript names iOS resolves for the Noto Sans SC family.
        // Cascade descriptors in FontTokens.swift MUST use these exact PostScript names (RESEARCH Pitfall 3).
        print("Noto family fonts: \(UIFont.fontNames(forFamilyName: "Noto Sans SC"))")

        // Assert the exact PostScript names FontTokens.cascaded(...) requires.
        // If any of these miss, UIFont silently falls back to system font with no CJK cascade (WR-05).
        let requiredPostScriptNames = [
            "GeneralSans-Regular",
            "GeneralSans-Medium",
            "NotoSansSC-Regular",
            "NotoSansSC-Medium"
        ]
        for name in requiredPostScriptNames {
            assert(
                UIFont(name: name, size: 12) != nil,
                "Missing font PostScript name: \(name). Cascade in FontTokens.swift will silently fall back to system font."
            )
        }
        #endif

        do {
            let schema = Schema([
                Athlete.self,
                WorkoutSession.self,
                ExerciseEntry.self,
                SetRecord.self,
                WorkloadSnapshot.self,
                RecoverySnapshot.self,
                MenstrualCycleSnapshot.self,
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
