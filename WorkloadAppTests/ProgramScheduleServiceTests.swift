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

    func test_inferredWeekdays_readTheBlocksOwnStructure() {
        let program = makeProgram(weeks: 2, daysPerWeek: 4)
        XCTAssertEqual(ProgramScheduleService.inferredWeekdays(for: program), [1, 2, 4, 5])
    }
}
