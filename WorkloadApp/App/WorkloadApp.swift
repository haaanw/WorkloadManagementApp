import SwiftUI
import SwiftData
import UIKit

@main
struct WorkloadApp: App {
    let container: ModelContainer

    init() {
        #if DEBUG
        // Under the XCTest host, the test bundle's resources (fonts) are NOT
        // loaded into the host app's bundle, so these assertions would fire and
        // crash the host on launch — taking down the ENTIRE unit-test suite
        // before any test runs. Downgrade to non-fatal logging in that case;
        // keep the hard assertions for normal DEBUG app runs so real font-bundle
        // regressions are still caught by developers.
        // UI (screenshot) tests launch the app as a SEPARATE process with no XCTest
        // injected, so the env/class checks below are both false there. SCREENSHOT_MODE
        // is the marker for that automated-launch path — treat it like the test host so
        // the font assertions stay non-fatal (the test host doesn't bundle the fonts and
        // the assert would otherwise trap the app on launch, failing all screenshots).
        let isRunningUnderTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
            || ProcessInfo.processInfo.arguments.contains("SCREENSHOT_MODE")

        let hasGeneralSans = UIFont.familyNames.contains(where: { $0.localizedCaseInsensitiveContains("general") })
        let hasNotoSansSC = UIFont.familyNames.contains(where: { $0.localizedCaseInsensitiveContains("noto sans sc") })

        // Assert the exact PostScript names FontTokens.cascaded(...) requires.
        // If any of these miss, UIFont silently falls back to system font with no CJK cascade (WR-05).
        let requiredPostScriptNames = [
            "GeneralSans-Regular",
            "GeneralSans-Medium",
            "NotoSansSC-Regular",
            "NotoSansSC-Medium"
        ]
        let missingPostScriptNames = requiredPostScriptNames.filter { UIFont(name: $0, size: 12) == nil }

        if isRunningUnderTest {
            // Non-fatal: fonts aren't bundled into the test host; just log.
            if !hasGeneralSans {
                print("[font-check] General Sans font not found (test host — non-fatal).")
            }
            if !hasNotoSansSC {
                print("[font-check] Noto Sans SC not registered (test host — non-fatal).")
            }
            if !missingPostScriptNames.isEmpty {
                print("[font-check] Missing font PostScript names (test host — non-fatal): \(missingPostScriptNames)")
            }
        } else {
            assert(
                hasGeneralSans,
                "General Sans font not found. Add GeneralSans-Variable.ttf to the project and UIAppFonts in Info.plist."
            )
            assert(
                hasNotoSansSC,
                "Noto Sans SC not registered. Add NotoSansSC-Regular.otf + NotoSansSC-Medium.otf and UIAppFonts entries."
            )
            // One-shot DEBUG print: exact PostScript names iOS resolves for the Noto Sans SC family.
            // Cascade descriptors in FontTokens.swift MUST use these exact PostScript names (RESEARCH Pitfall 3).
            print("Noto family fonts: \(UIFont.fontNames(forFamilyName: "Noto Sans SC"))")
            assert(
                missingPostScriptNames.isEmpty,
                "Missing font PostScript name(s): \(missingPostScriptNames). Cascade in FontTokens.swift will silently fall back to system font."
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
                CyclePredictionLog.self,
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
