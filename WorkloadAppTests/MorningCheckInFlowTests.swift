import XCTest
import SwiftData
@testable import workload_management

/// The morning check-in: ONE sheet, ONE step (v1.7.3 · UAT round 3 · U19, resolved 2026-09-15).
///
/// UAT round 3 met two morning sheets — the wellness ratings and a blinded 1–10 readiness
/// probe, both titled "Morning check" — and read them as duplicates. They were not: the
/// ratings are 25% of the readiness composite, the probe was held-out evidence no scoring
/// engine may read. HAN's ruling went past de-duplication and REMOVED the probe: a question in
/// front of the reading every morning is a cost the athlete pays daily for evidence only the
/// developer reads.
///
/// What this file pins is that the removal was an UNMOUNT. The morning surface asks one thing
/// and writes one row, the app never presents a question ahead of the reading — and the model
/// and its outcome fence survive untouched, so nothing migrates and a future re-mount is still
/// possible.
@MainActor
final class MorningCheckInFlowTests: XCTestCase {

    // MARK: - One step

    func test_theMorningSheetHasNoStepMachine() throws {
        let sheet = try readSource("WorkloadApp/Views/Recovery/MorningCheckInSheet.swift")
        XCTAssertFalse(
            sheet.contains("enum MorningCheckInStep"),
            "the sheet is single-step: a step machine with one step is a state nobody can be in"
        )
        XCTAssertFalse(sheet.contains("MorningProbeFields"))
        XCTAssertFalse(sheet.contains("MorningProbeRecorder"))
        XCTAssertTrue(
            sheet.contains("title: \"morning.nav.title\""),
            "and it keeps its one title"
        )
    }

    func test_theProbeSurfaceIsGoneFromTheApp() throws {
        // The probe sheet file was DELETED with its project entry (orchestrator, 2026-09-15);
        // its absence is the strongest form of "gone", so a missing file passes.
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("WorkloadApp/Views/Recovery/MorningProbeSheet.swift").path),
            "MorningProbeSheet.swift must stay deleted"
        )
        for file in [
            "WorkloadApp/Views/Dashboard/DashboardView.swift",
            "WorkloadApp/Views/Profile/ProfileView.swift",
        ] {
            let source = try readSource(file)
            XCTAssertFalse(
                source.contains("morningProbeEnabled"),
                "\(file) still offers or reads the removed opt-in"
            )
        }
        let profile = try readSource("WorkloadApp/Views/Profile/ProfileView.swift")
        XCTAssertFalse(
            profile.contains("profile.validation.morningProbe"),
            "the Profile toggle row is removed"
        )
        XCTAssertTrue(
            profile.contains("profile.validation.title"),
            "the section heading stays — the verdict-measurement readout still lives under it"
        )
        XCTAssertTrue(profile.contains("VerdictMeasurementView()"))
    }

    // MARK: - The one Save

    func test_theSaveWritesTodaysWellnessRow() throws {
        let context = try makeContext()
        let athlete = makeAthlete(in: context)

        MorningCheckInRecorder.save(
            ratings: .init(sleepQuality: 4, soreness: 2, energy: 5, stress: 3, notes: "slept late"),
            tags: .init(selected: ["Caffeine"], defaults: defaultTags, custom: []),
            athlete: athlete,
            modelContext: context
        )

        let checkIns = try context.fetch(FetchDescriptor<WellnessCheckIn>())
        XCTAssertEqual(checkIns.count, 1)
        XCTAssertEqual(checkIns.first?.sleepQuality, 4)
        XCTAssertEqual(checkIns.first?.energy, 5)
        XCTAssertEqual(checkIns.first?.notes, "slept late")
        XCTAssertEqual(
            checkIns.first?.behaviorTags.filter(\.isActive).map(\.tagName), ["Caffeine"],
            "the behaviour tags ride the same write"
        )
    }

    func test_theSaveNeverWritesAProbeRow() throws {
        // The probe is unmounted, so the morning surface has nothing to say about it. The
        // MODEL is still here on purpose — this asserts the write path, not the schema.
        let context = try makeContext()
        let athlete = makeAthlete(in: context)

        MorningCheckInRecorder.save(
            ratings: .init(sleepQuality: 3, soreness: 3, energy: 3, stress: 3, notes: ""),
            tags: .init(selected: [], defaults: defaultTags, custom: []),
            athlete: athlete,
            modelContext: context
        )

        XCTAssertEqual(try context.fetch(FetchDescriptor<WellnessCheckIn>()).count, 1)
        XCTAssertTrue(
            try context.fetch(FetchDescriptor<MorningReadinessProbe>()).isEmpty,
            "nothing in the app asks the probe question any more, so nothing may answer it"
        )
    }

    func test_reopeningTheSameDay_upsertsRatherThanAccumulating() throws {
        let context = try makeContext()
        let athlete = makeAthlete(in: context)

        for energy in [2, 5] {
            MorningCheckInRecorder.save(
                ratings: .init(sleepQuality: 3, soreness: 3, energy: energy, stress: 3, notes: ""),
                tags: .init(selected: [], defaults: defaultTags, custom: []),
                athlete: athlete,
                modelContext: context
            )
        }

        let checkIns = try context.fetch(FetchDescriptor<WellnessCheckIn>())
        XCTAssertEqual(
            checkIns.count, 1,
            "one row per day — a duplicate would shadow the edit and feed a stale row to the score"
        )
        XCTAssertEqual(checkIns.first?.energy, 5, "the re-open CORRECTS the day")
    }

    // MARK: - The fences the unmount must not break

    func test_todayMountsOneMorningSheet_andNeverAsksAheadOfTheReading() throws {
        let dashboard = try readSource("WorkloadApp/Views/Dashboard/DashboardView.swift")

        XCTAssertFalse(dashboard.contains("MorningProbeSheet("))
        XCTAssertFalse(
            dashboard.contains("MorningReadinessProbe"),
            "Today no longer queries the probe to decide what to present"
        )
        XCTAssertEqual(
            dashboard.components(separatedBy: "MorningCheckInSheet(").count - 1, 1,
            "exactly one morning sheet is mounted on Today"
        )
        XCTAssertTrue(
            dashboard.contains(".task {\n                await loadData()"),
            "nothing is presented ahead of the load any more — the reading is the first thing"
        )
        XCTAssertTrue(
            dashboard.contains("MorningCheckInPrompt {"),
            "the sheet is reached from the prompt row the athlete taps"
        )
    }

    func test_theProbeModelAndItsOutcomeFenceSurviveTheUnmount() throws {
        // The ruling was an UNMOUNT: no migration, no lost rows, and the fence that keeps an
        // outcome an outcome costs nothing to keep.
        let pipeline = try readSource("WorkloadApp/Services/RecoveryPipeline.swift")
        XCTAssertTrue(
            pipeline.contains("MorningReadinessProbe"),
            "the shadow record still carries the outcome columns"
        )
        XCTAssertTrue(pipeline.contains("outcomeWasBlinded"))

        // The model itself still constructs — so it is still in the graph and nothing migrates.
        let probe = MorningReadinessProbe(date: Date(), perceivedReadiness: 7, wasBlinded: true)
        XCTAssertEqual(probe.perceivedReadiness, 7)
    }

    func test_theRemovedKeysAreGone_andTheReferencedOnesRemain() throws {
        let catalog = try readSource("WorkloadApp/Resources/Localizable.xcstrings")
        for removed in ["probe.nav.title", "morning.action.next", "morning.action.back"] {
            XCTAssertFalse(
                catalog.contains("\"\(removed)\" :"),
                "\(removed) lost its last call site with the probe step"
            )
        }
        XCTAssertTrue(
            catalog.contains("\"morning.nav.title\" :"),
            "the surviving sheet keeps its title"
        )
        for stillUsed in ["probe.grip.hand.left", "probe.grip.hand.right"] {
            XCTAssertTrue(
                catalog.contains("\"\(stillUsed)\" :"),
                "\(stillUsed) is still read by the KEPT MorningReadinessProbe model"
            )
        }
    }

    // MARK: - Store

    private let defaultTags = ["Caffeine", "Alcohol", "Travel", "Stress"]

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Athlete.self,
            WorkoutSession.self,
            ExerciseEntry.self,
            SetRecord.self,
            WorkloadSnapshot.self,
            RecoverySnapshot.self,
            WellnessCheckIn.self,
            BehaviorTag.self,
            PersonalRecord.self,
            MorningReadinessProbe.self,
            SyncTombstone.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    private func makeAthlete(in context: ModelContext) -> Athlete {
        let athlete = Athlete(displayName: "Test", sportType: .lifting)
        context.insert(athlete)
        try? context.save()
        return athlete
    }

    private func readSource(_ relativePath: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
