import XCTest
import SwiftData
@testable import workload_management

/// v1.7.3 feature 6, batch 1 — `ProgramRepository` lifecycle laws: one active program,
/// archive-on-replace with history intact, clamped position moves, tombstoned deletion.
///
/// Stored-property container/repo per the iOS 26.1 `@MainActor` deinit-safety note
/// (see PlannedSessionRepositoryTests).
@MainActor
final class ProgramRepositoryTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var repo: ProgramRepository!
    private var templateRepo: TemplateRepository!
    private let athleteId = UUID()

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
        repo = ProgramRepository(modelContext: context)
        templateRepo = TemplateRepository(modelContext: context)
    }

    override func tearDown() {
        templateRepo = nil
        repo = nil
        context = nil
        container = nil
        super.tearDown()
    }

    private func makeProgram(name: String = "In-season strength", weeks: Int = 6) -> TrainingProgram {
        let program = TrainingProgram(
            athleteId: athleteId,
            name: name,
            source: .pdf,
            durationWeeks: weeks,
            durationSource: .readFromFile
        )
        for week in 1...weeks {
            for day in 1...3 {
                program.days.append(ProgramDay(weekNumber: week, dayNumber: day, title: "D\(day)"))
            }
        }
        return program
    }

    func test_activate_archivesPredecessorWithHistoryIntact() throws {
        let old = makeProgram(name: "Old block")
        try repo.save(old)
        try repo.activate(old, startDate: .now, trainingWeekdays: [1, 3, 5])

        let new = makeProgram(name: "New block")
        try repo.save(new)
        let predecessor = try repo.activate(new, startDate: .now, trainingWeekdays: [1, 3, 5])

        XCTAssertEqual(predecessor?.id, old.id)
        XCTAssertTrue(old.isArchived)
        XCTAssertFalse(old.isActive)
        XCTAssertNotNil(old.archivedAt)
        XCTAssertEqual(old.days.count, 18, "archive keeps the block's structure")
        XCTAssertEqual(repo.fetchActiveProgram(athleteId: athleteId)?.id, new.id)
        XCTAssertEqual(repo.fetchArchivedPrograms(athleteId: athleteId).map(\.id), [old.id])
    }

    func test_activate_selfIsNotItsOwnPredecessor() throws {
        let program = makeProgram()
        try repo.save(program)
        try repo.activate(program, startDate: .now, trainingWeekdays: [1, 3, 5])
        let predecessor = try repo.activate(program, startDate: .now, trainingWeekdays: [1, 3, 5])
        XCTAssertNil(predecessor)
        XCTAssertTrue(program.isActive)
        XCTAssertFalse(program.isArchived)
    }

    func test_movePosition_clampsToBlockBounds() throws {
        let program = makeProgram(weeks: 6)
        try repo.save(program)

        try repo.movePosition(program, toWeek: 4, day: 2)
        XCTAssertEqual(program.positionWeek, 4)
        XCTAssertEqual(program.positionDay, 2)

        try repo.movePosition(program, toWeek: 99, day: 99)
        XCTAssertEqual(program.positionWeek, 6)
        XCTAssertEqual(program.positionDay, 3)

        try repo.movePosition(program, toWeek: 0, day: 0)
        XCTAssertEqual(program.positionWeek, 1)
        XCTAssertEqual(program.positionDay, 1)
    }

    func test_delete_tombstonesProgramAndDayTemplates() throws {
        let program = makeProgram()
        let template = WorkoutTemplate(coachId: athleteId, templateName: "W1 D1")
        template.isAthleteOwned = true
        template.athleteId = athleteId
        template.isProgramDay = true
        context.insert(template)
        program.sortedDays[0].templateId = template.id
        try repo.save(program)

        try repo.delete(program)

        let programTombs = SyncTombstone.deletedRowIds(entity: .trainingPrograms, in: context)
        let templateTombs = SyncTombstone.deletedRowIds(entity: .templates, in: context)
        XCTAssertTrue(programTombs.contains(program.id))
        XCTAssertTrue(templateTombs.contains(template.id))
        XCTAssertNil(repo.fetchProgram(id: program.id))
    }

    func test_phaseLookup_bandsWeeks() throws {
        let program = makeProgram(weeks: 6)
        program.phases = [
            ProgramPhase(name: "Intro", startWeek: 1, endWeek: 1, orderIndex: 0),
            ProgramPhase(name: "Build", startWeek: 2, endWeek: 4, orderIndex: 1),
            ProgramPhase(name: "Peak + deload", startWeek: 5, endWeek: 6, orderIndex: 2)
        ]
        try repo.save(program)
        XCTAssertEqual(program.phase(forWeek: 1)?.name, "Intro")
        XCTAssertEqual(program.phase(forWeek: 3)?.name, "Build")
        XCTAssertEqual(program.phase(forWeek: 6)?.name, "Peak + deload")
        XCTAssertNil(program.phase(forWeek: 7))
    }

    func test_templateListFilter_excludesProgramDayTemplates() throws {
        let standalone = WorkoutTemplate(coachId: athleteId, templateName: "My own day")
        standalone.isAthleteOwned = true
        standalone.athleteId = athleteId
        context.insert(standalone)

        let programDay = WorkoutTemplate(coachId: athleteId, templateName: "W1 D1")
        programDay.isAthleteOwned = true
        programDay.athleteId = athleteId
        programDay.isProgramDay = true
        context.insert(programDay)
        try context.save()

        let listed = try templateRepo.fetchAthleteTemplates(athleteId: athleteId)
        XCTAssertEqual(listed.map(\.id), [standalone.id])
    }
}
