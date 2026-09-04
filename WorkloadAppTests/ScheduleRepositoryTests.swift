import XCTest
import SwiftData
@testable import workload_management

/// v1.7.3 feature 6, batch 1 — `ScheduleRepository` editing laws from the gated demo:
/// cancel = recorded + undoable, reschedule = struck source + provenance-carrying
/// destination, the earliest future match maintains `Athlete.nextMatchDate`, and the
/// ledger lists exactly the changed rows.
@MainActor
final class ScheduleRepositoryTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var repo: ScheduleRepository!
    private var athlete: Athlete!

    private let calendar = Calendar.current

    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema([
            Athlete.self, TrainingProgram.self, ProgramPhase.self, ProgramDay.self,
            ScheduleEntry.self, SyncTombstone.self
        ])
        container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
        repo = ScheduleRepository(modelContext: context)
        athlete = Athlete(displayName: "Test", sportType: .teamSport)
        context.insert(athlete)
        try context.save()
    }

    override func tearDown() {
        repo = nil
        athlete = nil
        context = nil
        container = nil
        super.tearDown()
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: .now))!
    }

    private func makePlanned(on date: Date, title: String = "Lower") throws -> ScheduleEntry {
        let entry = ScheduleEntry(
            athleteId: athlete.id, date: date, kind: .programSession, title: title,
            programId: UUID(), programDayId: UUID()
        )
        try repo.insert([entry])
        return entry
    }

    func test_cancel_isRecordedAndUndoable() throws {
        let entry = try makePlanned(on: day(2))
        try repo.cancel(entry)
        XCTAssertEqual(entry.status, .canceled)
        XCTAssertNotNil(entry.canceledAt)
        XCTAssertEqual(repo.entries(on: day(2), athleteId: athlete.id).count, 1,
                       "a canceled session stays visible on its day")

        try repo.restore(entry)
        XCTAssertEqual(entry.status, .planned)
        XCTAssertNil(entry.canceledAt)
    }

    func test_reschedule_strikesSourceAndCarriesProvenance() throws {
        let entry = try makePlanned(on: day(2), title: "Upper")
        let destination = try repo.reschedule(entry, to: day(5))

        XCTAssertEqual(entry.status, .moved)
        XCTAssertEqual(entry.movedToDate, day(5))
        XCTAssertEqual(destination.status, .planned)
        XCTAssertEqual(destination.date, day(5))
        XCTAssertEqual(destination.movedFromDate, day(2))
        XCTAssertEqual(destination.title, "Upper")
        XCTAssertEqual(destination.programDayId, entry.programDayId)
        XCTAssertEqual(repo.entries(on: day(2), athleteId: athlete.id).map(\.id), [entry.id],
                       "the source day keeps the struck record")
    }

    func test_matchEntries_maintainNextMatchDate() throws {
        _ = try repo.addAdHoc(kind: .match, on: day(6), athleteId: athlete.id)
        XCTAssertEqual(athlete.nextMatchDate, day(6))

        // An earlier match wins.
        let nearer = try repo.addAdHoc(kind: .match, on: day(3), athleteId: athlete.id)
        XCTAssertEqual(athlete.nextMatchDate, day(3))

        // Canceling it falls back to the later one.
        try repo.cancel(nearer)
        XCTAssertEqual(athlete.nextMatchDate, day(6))

        // A scrimmage never moves protection.
        _ = try repo.addAdHoc(kind: .scrimmage, on: day(1), athleteId: athlete.id)
        XCTAssertEqual(athlete.nextMatchDate, day(6))
    }

    func test_removeMatch_clearsNextMatchDateAndTombstones() throws {
        let match = try repo.addAdHoc(kind: .match, on: day(4), athleteId: athlete.id)
        XCTAssertEqual(athlete.nextMatchDate, day(4))

        try repo.remove(match)
        XCTAssertNil(athlete.nextMatchDate)
        XCTAssertTrue(SyncTombstone.deletedRowIds(entity: .scheduleEntries, in: context).contains(match.id))
        XCTAssertTrue(repo.entries(on: day(4), athleteId: athlete.id).isEmpty)
    }

    func test_ledger_listsExactlyTheChangedRows() throws {
        let untouched = try makePlanned(on: day(1))
        let canceled = try makePlanned(on: day(2))
        try repo.cancel(canceled)
        let moved = try makePlanned(on: day(3))
        let movedDest = try repo.reschedule(moved, to: day(4))
        let adHoc = try repo.addAdHoc(kind: .pickup, on: day(5), athleteId: athlete.id)

        let changes = repo.changes(from: day(0), to: day(7), athleteId: athlete.id)
        let ids = Set(changes.map(\.id))
        XCTAssertTrue(ids.contains(canceled.id))
        XCTAssertTrue(ids.contains(moved.id))
        XCTAssertTrue(ids.contains(movedDest.id))
        XCTAssertTrue(ids.contains(adHoc.id))
        XCTAssertFalse(ids.contains(untouched.id))
    }

    func test_deletePlannedProgramEntries_sparesDecidedStates() throws {
        let programId = UUID()
        let planned = ScheduleEntry(athleteId: athlete.id, date: day(2), kind: .programSession,
                                    title: "D1", programId: programId)
        let canceled = ScheduleEntry(athleteId: athlete.id, date: day(3), kind: .programSession,
                                     title: "D2", programId: programId)
        try repo.insert([planned, canceled])
        try repo.cancel(canceled)

        try repo.deletePlannedProgramEntries(programId: programId, from: day(0), athleteId: athlete.id)

        let remaining = repo.entries(from: day(0), to: day(7), athleteId: athlete.id)
        XCTAssertEqual(remaining.map(\.id), [canceled.id],
                       "canceled/moved/completed entries are records and stay")
    }

    func test_plannedProgramEntry_ignoresCanceledAndOtherKinds() throws {
        let entry = try makePlanned(on: day(0))
        _ = try repo.addAdHoc(kind: .pickup, on: day(0), athleteId: athlete.id)
        XCTAssertEqual(repo.plannedProgramEntry(on: day(0), athleteId: athlete.id)?.id, entry.id)
        try repo.cancel(entry)
        XCTAssertNil(repo.plannedProgramEntry(on: day(0), athleteId: athlete.id))
    }
}
