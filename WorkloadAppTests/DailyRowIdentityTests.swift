import XCTest
import SwiftData
@testable import workload_management

/// v1.7.2 codebase audit — findings M5 (daily-row identity) and M3 (behavior tags).
///
/// M5: recovery snapshots, workload snapshots and wellness check-ins are derived from a
/// calendar DAY, so their real identity is (athlete, day) — the row id belongs to whichever
/// device wrote them first. Nothing enforced that, so a second row for the same day could
/// appear and the hero recovery score depended on which one a fetch happened to return.
///
/// Toolchain note (mirrors `VerdictEventRepositoryTests`): `@MainActor` repositories are
/// held as stored properties and released in a plain, non-throwing `tearDown`.
@MainActor
final class DailyRowIdentityTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var recovery: RecoveryRepository!
    private var workload: WorkloadRepository!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema([
            Athlete.self, WorkoutSession.self, ExerciseEntry.self, SetRecord.self,
            WorkloadSnapshot.self, RecoverySnapshot.self, MenstrualCycleSnapshot.self,
            CyclePredictionLog.self, ShadowArmPrediction.self, SorenessLog.self,
            BaselineState.self, WellnessCheckIn.self, PersonalRecord.self,
            CoachAthleteRelationship.self, WorkoutTemplate.self, ExerciseGroup.self,
            TemplateExercise.self, TemplateSet.self, PrescribedWorkout.self,
            CustomExercise.self, BehaviorTag.self, TrainingProfile.self,
            SyncTombstone.self
        ])
        container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
        recovery = RecoveryRepository(modelContext: context)
        workload = WorkloadRepository(modelContext: context)
    }

    override func tearDown() {
        recovery = nil
        workload = nil
        context = nil
        container = nil
        super.tearDown()
    }

    private func makeAthlete() -> Athlete {
        let athlete = Athlete(displayName: "Test", sportType: .teamSport)
        context.insert(athlete)
        return athlete
    }

    // MARK: - M5: the upsert key is the day, not the instant

    /// The pipeline's upsert used to key on `date == startOfDay(now)`. A row written with an
    /// unfloored date — MockDataSeeder did exactly that under SCREENSHOT_MODE — did not
    /// match, so the upsert inserted a SECOND row for the same day.
    func testRecoveryUpsertFindsAnUnflooredSameDayRow() throws {
        let athlete = makeAthlete()
        let middayToday = Date().addingTimeInterval(0)
        let unfloored = RecoverySnapshot(date: middayToday, recoveryScore: 41)
        unfloored.athlete = athlete
        context.insert(unfloored)
        try context.save()

        try recovery.upsertRecoverySnapshot(
            hrvSDNN: 55, restingHR: 50, sleepDurationMinutes: 470,
            bodyTemp: nil, vo2Max: nil, recoveryScore: 88, athlete: athlete
        )

        let all = try context.fetch(FetchDescriptor<RecoverySnapshot>())
        XCTAssertEqual(all.count, 1, "The upsert forked today into two rows (audit M5)")
        XCTAssertEqual(all.first?.recoveryScore, 88)
    }

    func testWorkloadUpsertFindsAnUnflooredSameDayRow() throws {
        let athlete = makeAthlete()
        let unfloored = WorkloadSnapshot(snapshotDate: Date(), acuteLoad: 1, chronicLoad: 1,
                                         acwr: 1, tsb: 0, weeklyVolume: 0, loadSource: .srpe)
        unfloored.athlete = athlete
        context.insert(unfloored)
        try context.save()

        try workload.upsertSnapshot(
            WorkloadCalculator.WorkloadResult(date: .now, atl: 42, ctl: 40, acwr: 1.05, tsb: -2),
            weeklyVolume: 1200, loadSource: .srpe, athlete: athlete
        )

        let all = try context.fetch(FetchDescriptor<WorkloadSnapshot>())
        XCTAssertEqual(all.count, 1, "The upsert forked today into two rows (audit M5)")
        XCTAssertEqual(all.first?.acuteLoad, 42)
    }

    /// With two rows already present for today, the hero score must be a FUNCTION of the
    /// data rather than of fetch order: the most recently updated row wins, every time.
    func testTodaySnapshotIsDeterministicWhenADayHoldsTwoRows() throws {
        let athlete = makeAthlete()
        let today = Calendar.current.startOfDay(for: .now)

        let older = RecoverySnapshot(date: today, recoveryScore: 30)
        older.athlete = athlete
        older.updatedAt = Date(timeIntervalSince1970: 1_000)
        let newer = RecoverySnapshot(date: today.addingTimeInterval(3600), recoveryScore: 77)
        newer.athlete = athlete
        newer.updatedAt = Date(timeIntervalSince1970: 2_000)
        context.insert(older)
        context.insert(newer)
        try context.save()

        for _ in 0..<5 {
            XCTAssertEqual(
                try recovery.fetchTodaySnapshot(athlete: athlete)?.recoveryScore, 77,
                "fetchTodaySnapshot returned an arbitrary row (audit M5)"
            )
        }
    }

    // MARK: - M5: DailyRowIndex

    func testDailyRowIndexMatchesByIdThenByDay() throws {
        let athlete = makeAthlete()
        let today = Calendar.current.startOfDay(for: .now)
        let local = RecoverySnapshot(date: today, recoveryScore: 60)
        local.athlete = athlete
        context.insert(local)
        try context.save()

        let index = DailyRowIndex<RecoverySnapshot>(athlete: athlete, dayKey: \.date, in: context)

        XCTAssertIdentical(index.match(id: local.id, day: today), local)
        XCTAssertIdentical(
            index.match(id: UUID(), day: today.addingTimeInterval(45_000)), local,
            "A server row with a different id for the SAME day must resolve to the local row (audit M5)"
        )
        XCTAssertNil(index.match(id: UUID(), day: today.addingTimeInterval(-86_400)))
    }

    func testDailyRowIndexIgnoresAnotherAthletesRows() throws {
        let mine = makeAthlete()
        let theirs = makeAthlete()
        let today = Calendar.current.startOfDay(for: .now)
        let other = RecoverySnapshot(date: today, recoveryScore: 12)
        other.athlete = theirs
        context.insert(other)
        try context.save()

        let index = DailyRowIndex<RecoverySnapshot>(athlete: mine, dayKey: \.date, in: context)
        XCTAssertNil(index.match(id: UUID(), day: today))
    }

    func testDailyRowIndexRegistersRowsCreatedDuringAPull() throws {
        let athlete = makeAthlete()
        let today = Calendar.current.startOfDay(for: .now)
        var index = DailyRowIndex<RecoverySnapshot>(athlete: athlete, dayKey: \.date, in: context)
        XCTAssertNil(index.match(id: UUID(), day: today))

        let created = RecoverySnapshot(date: today, recoveryScore: 55)
        created.athlete = athlete
        context.insert(created)
        index.register(created)

        XCTAssertIdentical(
            index.match(id: UUID(), day: today), created,
            "Two server rows for one day must collapse onto one local row (audit M5)"
        )
    }

    // MARK: - M3: behavior tags keep their identity

    /// The check-in sheet used to delete every tag and re-create the set with fresh UUIDs on
    /// each save, so every re-open stranded the previous set on the server.
    func testCheckInSaveDoesNotMintNewTagIds() {
        let source = readSource("WorkloadApp/Views/Recovery/MorningCheckInSheet.swift")
        XCTAssertFalse(source.isEmpty)
        XCTAssertFalse(
            source.contains("for old in checkIn.behaviorTags {"),
            "The check-in save deletes and re-creates its tags again — the server accumulates orphans (audit M3)"
        )
        XCTAssertTrue(source.contains("var carriedOver = Dictionary("))
        XCTAssertTrue(
            source.contains("entity: .behaviorTags"),
            "A tag removed from the custom list must be tombstoned, not silently dropped"
        )
    }

    /// The pull dropped the check-in link, so a restored device saw every check-in with an
    /// empty tag set.
    func testBehaviorTagRowCarriesItsCheckInLink() {
        let athlete = makeAthlete()
        let checkIn = WellnessCheckIn(date: .now)
        checkIn.athlete = athlete
        let tag = BehaviorTag(date: .now, tagName: "Alcohol", isActive: true)
        tag.athlete = athlete
        tag.wellnessCheckIn = checkIn
        context.insert(checkIn)
        context.insert(tag)

        let row = BehaviorTagRow(from: tag, athleteId: athlete.id)
        XCTAssertEqual(row.wellnessCheckInId, checkIn.id)

        let source = readSource("WorkloadApp/Services/SyncService.swift")
        XCTAssertTrue(
            source.contains("tag.wellnessCheckIn = try? context"),
            "The behavior-tag pull no longer restores the check-in link (audit M3)"
        )
    }

    // MARK: - Helpers

    private func readSource(_ relativePath: String, file: StaticString = #filePath) -> String {
        let root = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appendingPathComponent(relativePath)
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("Fence could not resolve source at \(url.path)")
            return ""
        }
        return contents
    }
}
