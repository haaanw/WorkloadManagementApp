import XCTest
import SwiftData
@testable import workload_management

/// v1.7.3 feature 6, batch 4 — `ProgramInsightEngine` honesty rules: planned tonnage
/// arithmetic, the eased entry trims back-offs and never top sets, the transition
/// comparison offers easing only on a real step, adherence counts only due days, and
/// the duration suggestion stays bounded advice.
@MainActor
final class ProgramInsightEngineTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

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
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    /// One exercise: top set 140×5 + two back-offs 120×5.
    private func makeTemplate(topKg: Double = 140, backoffKg: Double = 120) -> WorkoutTemplate {
        let template = WorkoutTemplate(coachId: UUID(), templateName: "Day")
        let group = ExerciseGroup(groupName: "Main", orderIndex: 0)
        let exercise = TemplateExercise(exerciseName: "Back squat", orderIndex: 0)
        exercise.sets = [
            TemplateSet(setIndex: 0, targetReps: 5, targetWeightKg: topKg),
            TemplateSet(setIndex: 1, targetReps: 5, targetWeightKg: backoffKg),
            TemplateSet(setIndex: 2, targetReps: 5, targetWeightKg: backoffKg)
        ]
        group.exercises = [exercise]
        template.groups = [group]
        context.insert(template)
        return template
    }

    private func makeProgram(weeks: Int, template: WorkoutTemplate) -> TrainingProgram {
        let program = TrainingProgram(
            athleteId: UUID(), name: "Block", source: .pdf,
            durationWeeks: weeks, durationSource: .readFromFile
        )
        for week in 1...weeks {
            program.days.append(ProgramDay(
                weekNumber: week, dayNumber: 1, title: "D1", templateId: template.id
            ))
        }
        context.insert(program)
        return program
    }

    func test_plannedVolume_sumsWorkingSetsOnly() {
        let template = makeTemplate()
        // 140×5 + 120×5 + 120×5 = 1900
        XCTAssertEqual(ProgramInsightEngine.plannedVolume(of: template), 1900, accuracy: 0.01)

        let warmup = TemplateSet(setIndex: 3, targetReps: 5, targetWeightKg: 60, isWarmup: true)
        template.groups[0].exercises[0].sets.append(warmup)
        XCTAssertEqual(ProgramInsightEngine.plannedVolume(of: template), 1900, accuracy: 0.01,
                       "warmups never count toward tonnage")
    }

    func test_easedVolume_trimsOneBackoffNeverTheTopSet() {
        let template = makeTemplate()
        let program = makeProgram(weeks: 1, template: template)
        let templates = [template.id: template]
        // Trim one 120×5 back-off: 1900 − 600 = 1300; the 140 top set survives.
        XCTAssertEqual(
            ProgramInsightEngine.easedWeekVolume(program: program, week: 1, templates: templates),
            1300, accuracy: 0.01
        )
    }

    func test_transition_suggestsEasingOnlyOnARealStep() {
        let template = makeTemplate()
        let program = makeProgram(weeks: 1, template: template)
        let templates = [template.id: template]
        let calendar = Calendar.current

        // Chronic ≈ opening: no easing offered.
        let steadyHistory: [(date: Date, volume: Double)] = (1...8).map { day in
            (calendar.date(byAdding: .day, value: -day * 3, to: .now)!, 950.0)
        }
        let steady = ProgramInsightEngine.transitionComparison(
            program: program, templates: templates, sessions: steadyHistory
        )
        XCTAssertFalse(steady.suggestsEasedEntry)

        // Opening (1900) far above chronic (~500/wk): easing offered, step positive.
        let lightHistory: [(date: Date, volume: Double)] = (1...4).map { week in
            (calendar.date(byAdding: .day, value: -week * 7 + 1, to: .now)!, 500.0)
        }
        let jump = ProgramInsightEngine.transitionComparison(
            program: program, templates: templates, sessions: lightHistory
        )
        XCTAssertTrue(jump.suggestsEasedEntry)
        XCTAssertGreaterThan(jump.openingStepFraction ?? 0, 0.10)
        XCTAssertLessThan(jump.easedWeekVolume, jump.openingWeekVolume)
    }

    func test_transition_noHistoryMeansNoStepAndNoNagging() {
        let template = makeTemplate()
        let program = makeProgram(weeks: 1, template: template)
        let comparison = ProgramInsightEngine.transitionComparison(
            program: program, templates: [template.id: template], sessions: []
        )
        XCTAssertNil(comparison.openingStepFraction)
        XCTAssertFalse(comparison.suggestsEasedEntry)
    }

    func test_adherence_countsOnlyDueDaysAndExcludesCanceled() {
        let template = makeTemplate()
        let program = makeProgram(weeks: 3, template: template)
        program.positionWeek = 3
        program.positionDay = 1
        let days = program.sortedDays  // W1D1, W2D1, W3D1

        func entry(_ day: ProgramDay, status: ScheduleEntryStatus) -> ScheduleEntry {
            let entry = ScheduleEntry(
                athleteId: program.athleteId, date: .now, kind: .programSession,
                title: day.title, programId: program.id, programDayId: day.id
            )
            entry.status = status
            return entry
        }
        let entries = [
            entry(days[0], status: .completed),   // W1: trained
            entry(days[1], status: .canceled),    // W2: canceled — leaves the denominator
            entry(days[2], status: .planned)      // W3: not due yet (cursor is there)
        ]
        let adherence = ProgramInsightEngine.adherence(program: program, entries: entries)
        XCTAssertEqual(adherence.trained, 1)
        XCTAssertEqual(adherence.planned, 1)
    }

    func test_durationSuggestion_staysBoundedAndNamesInputs() {
        let template = makeTemplate()
        let program = makeProgram(weeks: 1, template: template)
        let suggestion = ProgramInsightEngine.suggestDuration(
            program: program, templates: [template.id: template], historyWeeks: 16
        )
        XCTAssertTrue((4...12).contains(suggestion.weeks))
        XCTAssertEqual(suggestion.historyWeeks, 16)

        let thin = ProgramInsightEngine.suggestDuration(
            program: program, templates: [template.id: template], historyWeeks: 3
        )
        XCTAssertEqual(thin.weeks, 6, "thin history argues for a shorter block")
    }
}
