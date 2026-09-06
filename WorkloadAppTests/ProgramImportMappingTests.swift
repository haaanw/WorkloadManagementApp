import XCTest
import SwiftData
@testable import workload_management

/// v1.7.3 feature 6, batch 2 — program-mode import mapping: the duration ladder's
/// read-vs-ask rung, and `buildProgram`'s week/day → model graph (cycling a short file
/// across a longer chosen duration, per-day templates flagged `isProgramDay`, RPE→RIR).
@MainActor
final class ProgramImportMappingTests: XCTestCase {

    private typealias Response = WorkoutLLMImportService.ParsedProgramResponse
    private typealias Exercise = WorkoutLLMImportService.ParsedWorkoutResponse.ParsedExercise
    private typealias ParsedSet = WorkoutLLMImportService.ParsedWorkoutResponse.ParsedSet

    private func makeExercise(name: String = "Back squat", rpe: Double? = nil) -> Exercise {
        Exercise(
            exercise_name: name,
            exercise_category: "compound",
            muscle_group: "quads",
            sets: [
                ParsedSet(target_reps: 5, target_weight_kg: 140, target_duration_seconds: nil,
                          target_rpe: rpe, is_warmup: false)
            ]
        )
    }

    private func makeResponse(
        durationWeeks: Int?,
        weekCount: Int,
        daysPerWeek: Int = 2,
        phases: [Response.ParsedPhase] = []
    ) -> Response {
        let weeks = (1...weekCount).map { week in
            Response.ParsedWeek(
                week_number: week,
                days: (1...daysPerWeek).map { day in
                    Response.ParsedDay(
                        day_number: day,
                        title: "W\(week) day \(day)",
                        exercises: [makeExercise(rpe: 8.0)]
                    )
                }
            )
        }
        return Response(
            program_name: "In-season strength",
            sport_type: "lifting",
            session_type: "strength",
            duration_weeks: durationWeeks,
            phases: phases,
            weeks: weeks
        )
    }

    // MARK: - Duration ladder: read vs ask

    func test_statedDuration_readsExplicitField() {
        let response = makeResponse(durationWeeks: 8, weekCount: 1)
        XCTAssertEqual(WorkoutLLMImportService.statedDurationWeeks(of: response), 8)
    }

    func test_statedDuration_readsMultiWeekStructure() {
        let response = makeResponse(durationWeeks: nil, weekCount: 6)
        XCTAssertEqual(WorkoutLLMImportService.statedDurationWeeks(of: response), 6)
    }

    func test_statedDuration_singleWeekSilentFile_mustBeAsked() {
        let response = makeResponse(durationWeeks: nil, weekCount: 1)
        XCTAssertNil(WorkoutLLMImportService.statedDurationWeeks(of: response),
                     "a silent one-week file is ASKED, never guessed")
    }

    // MARK: - buildProgram

    func test_buildProgram_oneWeekFileCyclesAcrossChosenDuration() {
        let response = makeResponse(durationWeeks: nil, weekCount: 1, daysPerWeek: 3)
        let built = WorkoutLLMImportService.buildProgram(
            from: response, durationWeeks: 8, durationSource: .asked,
            athleteId: UUID(), source: .pdf
        )
        XCTAssertEqual(built.program.durationWeeks, 8)
        XCTAssertEqual(built.program.durationSource, .asked)
        XCTAssertEqual(built.program.days.count, 24, "3 days × 8 weeks, content cycled")
        XCTAssertEqual(built.dayTemplates.count, 24)
        XCTAssertEqual(Set(built.program.days.map(\.weekNumber)), Set(1...8))
    }

    func test_buildProgram_dayTemplatesAreProgramDayFlaggedAndLinked() {
        let response = makeResponse(durationWeeks: 2, weekCount: 2)
        let athleteId = UUID()
        let built = WorkoutLLMImportService.buildProgram(
            from: response, durationWeeks: 2, durationSource: .readFromFile,
            athleteId: athleteId, source: .text
        )
        XCTAssertTrue(built.dayTemplates.allSatisfy { $0.isProgramDay })
        XCTAssertTrue(built.dayTemplates.allSatisfy { $0.isAthleteOwned && $0.athleteId == athleteId })
        let templateIds = Set(built.dayTemplates.map(\.id))
        XCTAssertTrue(built.program.days.allSatisfy { day in
            day.templateId.map(templateIds.contains) == true
        }, "every program day references its content template")
    }

    func test_buildProgram_mapsRPEIntoBothRPEAndRIRSlots() {
        let response = makeResponse(durationWeeks: 1, weekCount: 1)
        let built = WorkoutLLMImportService.buildProgram(
            from: response, durationWeeks: 1, durationSource: .readFromFile,
            athleteId: UUID(), source: .photo
        )
        let set = built.dayTemplates.first?.sortedGroups.first?.sortedExercises.first?.sortedSets.first
        XCTAssertEqual(set?.targetRPE, 8.0)
        XCTAssertEqual(set?.targetRIR, 2)
        XCTAssertEqual(set?.targetWeightKg, 140)
    }

    func test_buildProgram_phasesClampToChosenDuration() {
        let phases = [
            Response.ParsedPhase(name: "Build", start_week: 1, end_week: 4),
            Response.ParsedPhase(name: "Peak", start_week: 5, end_week: 9)
        ]
        let response = makeResponse(durationWeeks: 6, weekCount: 6, phases: phases)
        let built = WorkoutLLMImportService.buildProgram(
            from: response, durationWeeks: 6, durationSource: .readFromFile,
            athleteId: UUID(), source: .pdf
        )
        XCTAssertEqual(built.program.sortedPhases.count, 2)
        XCTAssertEqual(built.program.sortedPhases.last?.endWeek, 6, "phase end clamps to the block")
        XCTAssertEqual(built.program.phase(forWeek: 3)?.name, "Build")
        XCTAssertEqual(built.program.phase(forWeek: 6)?.name, "Peak")
    }
}
