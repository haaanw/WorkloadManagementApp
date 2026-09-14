import XCTest
import SwiftData
@testable import workload_management

/// One morning sheet, probe first (v1.7.3 · UAT round 3 · U19).
///
/// HAN met two sheets on one morning, both titled "Morning check", and read them as
/// duplicates. They are the opposite: the wellness ratings are 25% of the readiness composite,
/// while the 1–10 probe is HELD-OUT evidence no scoring engine may read
/// (`MorningReadinessProbeTests`). So they merged rather than one being deleted, and the merge
/// has exactly one rule that cannot bend — the probe comes FIRST.
///
/// Why first: `wasBlinded` records only whether the DASHBOARD had already drawn a score
/// (VALIDATION-PROTOCOL §blinding), and non-blinded rows are excluded from every criterion. A
/// ratings-first sheet carries its own wellness preview score, so it would put a number in
/// front of the athlete and still stamp the answer blinded.
@MainActor
final class MorningCheckInFlowTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: MorningProbeRecorder.skippedDayKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: MorningProbeRecorder.skippedDayKey)
        super.tearDown()
    }

    // MARK: - Step order

    func test_probeIsStepOne_wheneverItIsDue() {
        XCTAssertEqual(MorningCheckInFlow.initialStep(probeBlinding: true), .probe)
        XCTAssertEqual(
            MorningCheckInFlow.initialStep(probeBlinding: false), .probe,
            "an UNBLINDED probe is still asked — the answer is kept as data and excluded later"
        )
    }

    func test_probeNotDue_opensTheRatingsAlone() {
        // The `MorningCheckInPrompt` row's path on an ordinary morning.
        XCTAssertEqual(MorningCheckInFlow.initialStep(probeBlinding: nil), .ratings)
    }

    func test_bothAnsweringAndSkippingLandOnTheRatings() {
        // A skipped probe is still a morning check-in; the flow never dead-ends on step 1.
        XCTAssertEqual(MorningCheckInFlow.stepAfterProbe(), .ratings)
    }

    func test_probeRowIsWrittenOnlyWhenTheProbeWasDueAndAnswered() {
        XCTAssertTrue(MorningCheckInFlow.writesProbeRow(probeBlinding: true, probeAnswered: true))
        XCTAssertFalse(
            MorningCheckInFlow.writesProbeRow(probeBlinding: true, probeAnswered: false),
            "a skip writes no row — an unanswered morning is absence, not a value"
        )
        XCTAssertFalse(
            MorningCheckInFlow.writesProbeRow(probeBlinding: nil, probeAnswered: true),
            "no probe was due, so there is nothing to write however the state got set"
        )
    }

    func test_skipStampsTheDaySoTheProbeIsNotReAsked() {
        XCTAssertFalse(MorningProbeRecorder.isSkippedToday())
        MorningProbeRecorder.stampSkippedToday()
        XCTAssertTrue(
            MorningProbeRecorder.isSkippedToday(),
            "re-asking after an explicit 'not today' is what gets the toggle turned off"
        )
        XCTAssertFalse(
            MorningProbeRecorder.isSkippedToday(
                now: Calendar.current.date(byAdding: .day, value: 1, to: .now)!
            ),
            "tomorrow asks fresh"
        )
    }

    // MARK: - One Save, both rows

    func test_oneSave_writesTheProbeRowAndTheWellnessRow() throws {
        let context = try makeContext()
        let athlete = makeAthlete(in: context)

        MorningCheckInRecorder.save(
            ratings: .init(sleepQuality: 4, soreness: 2, energy: 5, stress: 3, notes: "slept late"),
            tags: .init(selected: ["Caffeine"], defaults: defaultTags, custom: []),
            probe: .init(
                readiness: 8,
                gripText: "47.5",
                gripHand: .right,
                includeGrip: true,
                wasBlinded: true
            ),
            athlete: athlete,
            modelContext: context
        )

        let checkIns = try context.fetch(FetchDescriptor<WellnessCheckIn>())
        XCTAssertEqual(checkIns.count, 1)
        XCTAssertEqual(checkIns.first?.sleepQuality, 4)
        XCTAssertEqual(checkIns.first?.energy, 5)

        let probes = try context.fetch(FetchDescriptor<MorningReadinessProbe>())
        XCTAssertEqual(probes.count, 1, "the same Save writes the probe row")
        XCTAssertEqual(probes.first?.perceivedReadiness, 8)
        XCTAssertEqual(probes.first?.gripStrengthKg, 47.5)
        XCTAssertEqual(probes.first?.gripHand, .right)
        XCTAssertTrue(
            probes.first?.wasBlinded ?? false,
            "the blinding stamp travels with the answer, it is never re-derived at write time"
        )
    }

    func test_ratingsOnlySave_writesNoProbeRow() throws {
        let context = try makeContext()
        let athlete = makeAthlete(in: context)

        MorningCheckInRecorder.save(
            ratings: .init(sleepQuality: 3, soreness: 3, energy: 3, stress: 3, notes: ""),
            tags: .init(selected: [], defaults: defaultTags, custom: []),
            probe: nil,
            athlete: athlete,
            modelContext: context
        )

        XCTAssertEqual(try context.fetch(FetchDescriptor<WellnessCheckIn>()).count, 1)
        XCTAssertTrue(
            try context.fetch(FetchDescriptor<MorningReadinessProbe>()).isEmpty,
            "the prompt row's path must not fabricate a probe answer nobody gave"
        )
    }

    func test_reopeningTheSameDay_upsertsRatherThanAccumulating() throws {
        let context = try makeContext()
        let athlete = makeAthlete(in: context)

        for readiness in [5, 9] {
            MorningCheckInRecorder.save(
                ratings: .init(sleepQuality: 3, soreness: 3, energy: 3, stress: 3, notes: ""),
                tags: .init(selected: [], defaults: defaultTags, custom: []),
                probe: .init(
                    readiness: readiness,
                    gripText: "",
                    gripHand: .right,
                    includeGrip: false,
                    wasBlinded: false
                ),
                athlete: athlete,
                modelContext: context
            )
        }

        XCTAssertEqual(try context.fetch(FetchDescriptor<WellnessCheckIn>()).count, 1)
        let probes = try context.fetch(FetchDescriptor<MorningReadinessProbe>())
        XCTAssertEqual(probes.count, 1, "one probe per day — a re-answer CORRECTS the day")
        XCTAssertEqual(probes.first?.perceivedReadiness, 9)
    }

    // MARK: - The fences the merge must not break

    func test_todayMountsExactlyOneMorningSheet_andAsksBeforeItLoads() throws {
        let dashboard = try readSource("WorkloadApp/Views/Dashboard/DashboardView.swift")

        XCTAssertFalse(
            dashboard.contains("MorningProbeSheet("),
            "U19: the probe no longer presents itself — it is step 1 of the one morning sheet"
        )
        XCTAssertEqual(
            dashboard.components(separatedBy: "MorningCheckInSheet(").count - 1, 1,
            "exactly one morning sheet is mounted on Today"
        )

        XCTAssertTrue(
            dashboard.contains("presentMorningCheckInIfProbeDue()\n                await loadData()"),
            "BLINDING: the probe is presented before the load that draws a score, in the same .task"
        )
        XCTAssertTrue(
            dashboard.contains("morningProbeBlinding = !viewModel.hasLoadedOnce"),
            "blinding stays RECORDED, not assumed (VALIDATION-PROTOCOL §blinding)"
        )
    }

    func test_theTwoStepsNoLongerReadAlike() throws {
        let catalog = try readSource("WorkloadApp/Resources/Localizable.xcstrings")
        // Both titles used to render "Morning check", which is what made them look like
        // duplicates. The merged sheet keeps "Morning check-in"; the probe step is renamed.
        XCTAssertTrue(catalog.contains("\"Before you look\""))
        XCTAssertTrue(catalog.contains("\"Morning check-in\""))
        XCTAssertFalse(
            catalog.contains("\"value\" : \"Morning check\"\n"),
            "the colliding title is gone"
        )

        let sheet = try readSource("WorkloadApp/Views/Recovery/MorningCheckInSheet.swift")
        XCTAssertTrue(sheet.contains("title: \"probe.nav.title\""), "the probe step names itself")
        XCTAssertTrue(sheet.contains("title: \"morning.nav.title\""), "the ratings step keeps the sheet's name")
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
