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

        let hasPrimaryFace = UIFont.familyNames.contains(where: { $0.localizedCaseInsensitiveContains("instrument sans") })
        let hasNotoSansSC = UIFont.familyNames.contains(where: { $0.localizedCaseInsensitiveContains("noto sans sc") })
        // v6 "Field Notes": the annotation voice. A missing annotation face degrades to the
        // system monospaced font (FontTokens.annoCascaded), which reads as *almost* right —
        // exactly the silent-fallback class this assertion exists to catch.
        let hasAnnotationFace = UIFont.familyNames.contains(where: { $0.localizedCaseInsensitiveContains("fragment mono") })

        // Assert the exact PostScript names FontTokens requires (list owned by the chokepoint —
        // Font.Tokens.requiredPostScriptNames — so font-name literals stay in FontTokens.swift).
        // If any of these miss, UIFont silently falls back to system font with no CJK cascade (WR-05).
        let requiredPostScriptNames = Font.Tokens.requiredPostScriptNames
        let missingPostScriptNames = requiredPostScriptNames.filter { UIFont(name: $0, size: 12) == nil }

        // One-shot DEBUG prints (all launch paths, incl. SCREENSHOT_MODE): exact PostScript
        // names iOS resolves for the bundled families. Descriptors in FontTokens.swift MUST
        // use these exact PostScript names (RESEARCH Pitfall 3 / phase-14 lesson).
        print("Noto family fonts: \(UIFont.fontNames(forFamilyName: "Noto Sans SC"))")
        for family in UIFont.familyNames
        where family.localizedCaseInsensitiveContains("instrument")
            || family.localizedCaseInsensitiveContains("fragment") {
            print("\(family) family fonts: \(UIFont.fontNames(forFamilyName: family))")
        }

        if isRunningUnderTest {
            // Non-fatal: fonts aren't bundled into the test host; just log.
            if !hasPrimaryFace {
                print("[font-check] Instrument Sans not found (test host — non-fatal).")
            }
            if !hasAnnotationFace {
                print("[font-check] Fragment Mono not found (test host — non-fatal).")
            }
            if !hasNotoSansSC {
                print("[font-check] Noto Sans SC not registered (test host — non-fatal).")
            }
            if !missingPostScriptNames.isEmpty {
                print("[font-check] Missing font PostScript names (test host — non-fatal): \(missingPostScriptNames)")
            }
        } else {
            assert(
                hasPrimaryFace,
                "Instrument Sans not found. Add the two static Instrument Sans TTFs (see Font.Tokens.requiredPostScriptNames) and their UIAppFonts entries."
            )
            assert(
                hasAnnotationFace,
                "Fragment Mono not found. Add the static Fragment Mono TTF (see Font.Tokens.requiredPostScriptNames) and its UIAppFonts entry — the v6 annotation layer silently degrades to the system mono without it."
            )
            assert(
                hasNotoSansSC,
                "Noto Sans SC not registered. Add NotoSansSC-Regular.otf + NotoSansSC-Medium.otf and UIAppFonts entries."
            )
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
                ShadowArmPrediction.self,
                SorenessLog.self,
                VerdictEvent.self,
                BaselineState.self,
                SleepShadowNight.self,
                RecoveryShadowDay.self,
                MorningReadinessProbe.self,
                WellnessCheckIn.self,
                PersonalRecord.self,
                CoachAthleteRelationship.self,
                WorkoutTemplate.self,
                ExerciseGroup.self,
                TemplateExercise.self,
                TemplateSet.self,
                PrescribedWorkout.self,
                CustomExercise.self,
                ExerciseOverride.self,
                BehaviorTag.self,
                TrainingProfile.self,
                SyncTombstone.self,
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
                .preferredColorScheme(.light)
        }
        .modelContainer(container)
    }
}
