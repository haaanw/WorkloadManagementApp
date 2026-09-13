import XCTest
import SwiftData
@testable import workload_management

/// v1.7.3 feature 6, batch 1 — `ProgramScheduleService` mapping laws: ISO-Monday anchoring,
/// weekday-slot placement with overflow, materialization from the position cursor forward
/// only, and re-materialization that spares decided states.
@MainActor
final class ProgramScheduleServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var programRepo: ProgramRepository!
    private var scheduleRepo: ScheduleRepository!

    private let iso = Calendar(identifier: .iso8601)

    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema([
            Athlete.self, WorkoutTemplate.self, ExerciseGroup.self, TemplateExercise.self,
            TemplateSet.self, TrainingProgram.self, ProgramPhase.self, ProgramDay.self,
            ScheduleEntry.self, SyncTombstone.self
        ])
        container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
        programRepo = ProgramRepository(modelContext: context)
        scheduleRepo = ScheduleRepository(modelContext: context)
    }

    override func tearDown() {
        programRepo = nil
        scheduleRepo = nil
        context = nil
        container = nil
        super.tearDown()
    }

    private func makeProgram(weeks: Int = 3, daysPerWeek: Int = 3) -> TrainingProgram {
        let program = TrainingProgram(
            athleteId: UUID(),
            name: "Block",
            source: .text,
            durationWeeks: weeks,
            durationSource: .asked
        )
        for week in 1...weeks {
            for day in 1...daysPerWeek {
                program.days.append(ProgramDay(weekNumber: week, dayNumber: day, title: "W\(week)D\(day)"))
            }
        }
        context.insert(program)
        return program
    }

    private func isoWeekday(_ date: Date) -> Int {
        // Convert Apple weekday (1=Sun...7=Sat) to ISO (1=Mon...7=Sun).
        let appleWeekday = iso.component(.weekday, from: date)
        return appleWeekday == 1 ? 7 : appleWeekday - 1
    }

    func test_defaultWeekdays_coverCommonFrequencies() {
        XCTAssertEqual(ProgramScheduleService.defaultWeekdays(daysPerWeek: 3), [1, 3, 5])
        XCTAssertEqual(ProgramScheduleService.defaultWeekdays(daysPerWeek: 4), [1, 2, 4, 5])
        XCTAssertEqual(ProgramScheduleService.defaultWeekdays(daysPerWeek: 7).count, 7)
    }

    func test_dateMapping_placesSlotsOnTrainingWeekdays() {
        let anchor = ProgramScheduleService.weekAnchor(containing: .now)
        XCTAssertEqual(isoWeekday(anchor), 1, "the anchor is a Monday")

        let d1 = ProgramScheduleService.date(
            forWeek: 1, day: 2, anchorMonday: anchor, anchorWeek: 1, trainingWeekdays: [1, 3, 5]
        )
        XCTAssertEqual(isoWeekday(d1!), 3, "slot 2 of Mon/Wed/Fri is Wednesday")

        let nextWeek = ProgramScheduleService.date(
            forWeek: 2, day: 1, anchorMonday: anchor, anchorWeek: 1, trainingWeekdays: [1, 3, 5]
        )
        XCTAssertEqual(iso.dateComponents([.day], from: anchor, to: nextWeek!).day, 7)
    }

    func test_dateMapping_overflowLandsAfterLastSlotCappedAtSunday() {
        let anchor = ProgramScheduleService.weekAnchor(containing: .now)
        let overflow = ProgramScheduleService.date(
            forWeek: 1, day: 4, anchorMonday: anchor, anchorWeek: 1, trainingWeekdays: [1, 3, 5]
        )
        XCTAssertEqual(isoWeekday(overflow!), 6, "4th session of a 3-slot week lands Saturday")

        let capped = ProgramScheduleService.date(
            forWeek: 1, day: 9, anchorMonday: anchor, anchorWeek: 1, trainingWeekdays: [1, 3, 5]
        )
        XCTAssertEqual(isoWeekday(capped!), 7, "overflow never spills past Sunday")
    }

    func test_materialization_startsAtPositionCursorAndSkipsThePast() {
        let program = makeProgram(weeks: 3, daysPerWeek: 3)
        program.positionWeek = 2
        program.positionDay = 2
        program.startDate = ProgramScheduleService.weekAnchor(containing: .now)
        program.trainingWeekdays = [1, 3, 5]

        // As-of the anchor Monday: W2D2, W2D3 and all of W3 remain = 5 entries.
        let entries = ProgramScheduleService.materializedEntries(
            for: program, asOf: program.startDate!
        )
        XCTAssertEqual(entries.count, 5)
        XCTAssertEqual(entries.map(\.title).sorted(),
                       ["W2D2", "W2D3", "W3D1", "W3D2", "W3D3"].sorted())
        XCTAssertTrue(entries.allSatisfy { $0.kind == .programSession && $0.status == .planned })
        XCTAssertTrue(entries.allSatisfy { $0.programId == program.id })
    }

    func test_activate_materializesAndArchivesPredecessorsPlans() throws {
        let athleteId = UUID()
        let old = makeProgram(weeks: 2, daysPerWeek: 2)
        old.athleteId = athleteId
        try ProgramScheduleService.activate(
            old, startDate: .now, programRepo: programRepo, scheduleRepo: scheduleRepo
        )
        let horizon = iso.date(byAdding: .day, value: 60, to: .now)!
        let oldCount = scheduleRepo.entries(from: .now, to: horizon, athleteId: athleteId).count
        XCTAssertGreaterThan(oldCount, 0)

        let new = makeProgram(weeks: 2, daysPerWeek: 2)
        new.athleteId = athleteId
        try ProgramScheduleService.activate(
            new, startDate: .now, programRepo: programRepo, scheduleRepo: scheduleRepo
        )

        let remaining = scheduleRepo.entries(from: .now, to: horizon, athleteId: athleteId)
        XCTAssertTrue(remaining.allSatisfy { $0.programId == new.id },
                      "the old block's future plans dissolve on replacement")
        XCTAssertTrue(old.isArchived)
    }

    // MARK: - Where a block starts (UAT round 2 · U15)

    /// A fixed Sunday and the Monday that follows it — no dependence on the day the suite runs.
    private func sunday() -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 13          // Sunday
        return iso.date(from: components)!
    }

    private func monday() -> Date {
        iso.date(byAdding: .day, value: 1, to: sunday())!
    }

    func test_defaultAnchor_sundayStartsTheNextMonday() {
        let anchor = ProgramScheduleService.defaultAnchor(for: sunday(), calendar: iso)
        XCTAssertEqual(isoWeekday(anchor), 1)
        XCTAssertEqual(anchor, iso.startOfDay(for: monday()),
                       "a Sunday import opens week 1 on the NEXT Monday, never the one behind it")
    }

    func test_defaultAnchor_mondayStartsThatMonday() {
        let anchor = ProgramScheduleService.defaultAnchor(for: monday(), calendar: iso)
        XCTAssertEqual(anchor, iso.startOfDay(for: monday()),
                       "today IS the start of a week — it is not pushed a week out")
    }

    func test_sundayImport_materializesEveryDayOfWeekOne() throws {
        let athleteId = UUID()
        let program = makeProgram(weeks: 2, daysPerWeek: 3)
        program.athleteId = athleteId
        let anchor = ProgramScheduleService.defaultAnchor(for: sunday(), calendar: iso)

        try ProgramScheduleService.activate(
            program, startDate: anchor, programRepo: programRepo, scheduleRepo: scheduleRepo
        )

        let horizon = iso.date(byAdding: .day, value: 60, to: anchor)!
        let entries = scheduleRepo.entries(from: anchor, to: horizon, athleteId: athleteId)
        let weekOne = entries.filter { ["W1D1", "W1D2", "W1D3"].contains($0.title) }
        XCTAssertEqual(weekOne.count, 3, "the imported block's first week is not amputated")
        XCTAssertEqual(program.startDate, anchor)
        XCTAssertTrue(entries.allSatisfy { $0.date >= anchor },
                      "nothing lands in the week the athlete already spent")
    }

    func test_mondayImport_anchorsOnThatMonday() throws {
        let athleteId = UUID()
        let program = makeProgram(weeks: 2, daysPerWeek: 3)
        program.athleteId = athleteId
        let anchor = ProgramScheduleService.defaultAnchor(for: monday(), calendar: iso)

        try ProgramScheduleService.activate(
            program, startDate: anchor, programRepo: programRepo, scheduleRepo: scheduleRepo
        )

        XCTAssertEqual(program.startDate, iso.startOfDay(for: monday()))
        let entries = ProgramScheduleService.materializedEntries(for: program, asOf: anchor)
        XCTAssertEqual(entries.filter { $0.title.hasPrefix("W1") }.count, 3)
        XCTAssertEqual(isoWeekday(entries.first!.date), 1, "W1D1 is the anchor Monday itself")
    }

    func test_startToday_onASunday_keepsTheCurrentWeekWithItsPastDays() throws {
        let athleteId = UUID()
        let program = makeProgram(weeks: 2, daysPerWeek: 3)
        program.athleteId = athleteId
        let today = iso.startOfDay(for: sunday())

        // The explicit "Starts today" cell: the CURRENT week counts as week 1.
        try ProgramScheduleService.activate(
            program, startDate: today, programRepo: programRepo, scheduleRepo: scheduleRepo
        )

        let currentMonday = ProgramScheduleService.weekAnchor(containing: today)
        let horizon = iso.date(byAdding: .day, value: 60, to: today)!
        let entries = scheduleRepo.entries(from: currentMonday, to: horizon, athleteId: athleteId)
        let weekOne = entries.filter { $0.title.hasPrefix("W1") }
        XCTAssertEqual(weekOne.count, 3, "week 1 is whole — the days already behind today stay")
        XCTAssertTrue(weekOne.contains { $0.date < today },
                      "the point of 'starts today' is that the week's earlier days count")
        XCTAssertEqual(program.startDate, today)
    }

    func test_activate_isIdempotent_soAStartChoiceCanBeChanged() throws {
        let athleteId = UUID()
        let program = makeProgram(weeks: 2, daysPerWeek: 3)
        program.athleteId = athleteId
        let nextMonday = ProgramScheduleService.defaultAnchor(for: sunday(), calendar: iso)
        let today = iso.startOfDay(for: sunday())

        try ProgramScheduleService.activate(
            program, startDate: nextMonday, programRepo: programRepo, scheduleRepo: scheduleRepo
        )
        try ProgramScheduleService.activate(
            program, startDate: today, programRepo: programRepo, scheduleRepo: scheduleRepo
        )

        let horizon = iso.date(byAdding: .day, value: 90, to: today)!
        let all = scheduleRepo.entries(from: .distantPast, to: horizon, athleteId: athleteId)
        XCTAssertEqual(all.count, 6, "re-activating the same block rebuilds, never duplicates")
        XCTAssertFalse(program.isArchived, "a block is never its own archived predecessor")
    }

    /// A position move is "I am here NOW", so the block stays on the CURRENT week — a
    /// Wednesday move must not empty the week being worked, and the Monday and Tuesday of
    /// that week stay materialized as planned days (past, not deleted).
    func test_movePosition_onAWednesday_keepsTheCurrentWeekWithAllItsDays() throws {
        let athleteId = UUID()
        let program = makeProgram(weeks: 3, daysPerWeek: 3)
        program.athleteId = athleteId
        try ProgramScheduleService.activate(
            program, startDate: monday(), programRepo: programRepo, scheduleRepo: scheduleRepo
        )

        let currentMonday = iso.startOfDay(for: monday())
        let wednesday = iso.date(byAdding: .day, value: 2, to: currentMonday)!
        XCTAssertEqual(isoWeekday(wednesday), 3)

        try ProgramScheduleService.movePosition(
            program, toWeek: 2, day: 1, asOf: wednesday,
            programRepo: programRepo, scheduleRepo: scheduleRepo
        )

        XCTAssertEqual(program.startDate, currentMonday,
                       "the block re-anchors on THIS week's Monday, never the next one")

        let horizon = iso.date(byAdding: .day, value: 90, to: currentMonday)!
        let entries = scheduleRepo.entries(from: currentMonday, to: horizon, athleteId: athleteId)
        let positionWeek = entries.filter { $0.title.hasPrefix("W2") }
        XCTAssertEqual(Set(positionWeek.map(\.title)), ["W2D1", "W2D2", "W2D3"],
                       "the position week is retained whole on the current week")
        XCTAssertEqual(positionWeek.count, 3, "no day is duplicated by the rebuild")
        XCTAssertTrue(positionWeek.contains { $0.date < wednesday },
                      "Monday and Tuesday of the current week survive the move")
        XCTAssertTrue(positionWeek.allSatisfy { $0.date >= currentMonday },
                      "nothing lands before the week the athlete is working")
    }

    func test_inferredWeekdays_readTheBlocksOwnStructure() {
        let program = makeProgram(weeks: 2, daysPerWeek: 4)
        XCTAssertEqual(ProgramScheduleService.inferredWeekdays(for: program), [1, 2, 4, 5])
    }
}
