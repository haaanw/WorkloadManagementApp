import XCTest
@testable import workload_management

/// v1.7.3 UAT round 2, U13 — the program parser's COMPACT output contract.
///
/// A program read used to cost 30-40 seconds per block because the model wrote every
/// week out in full, repeats included. It now sends a repeated week as a pointer
/// (`repeat_of_week`) with no days. These tests hold the two halves of that bargain:
/// the wire format still decodes when the key is absent, and expansion rebuilds exactly
/// the graph a fully-written response produced — the athlete's program must not change.
@MainActor
final class ProgramImportDecodingTests: XCTestCase {

    private typealias Response = WorkoutLLMImportService.ParsedProgramResponse

    // MARK: - Fixtures

    /// One week, one day, one exercise — enough to tell weeks apart by content.
    private func fullWeekJSON(number: Int, exercise: String, includeRepeatKey: Bool) -> String {
        let repeatKey = includeRepeatKey ? #""repeat_of_week": null, "# : ""
        return """
        {
          "week_number": \(number),
          \(repeatKey)"days": [
            {
              "day_number": 1,
              "title": "W\(number) upper",
              "exercises": [
                {
                  "exercise_name": "\(exercise)",
                  "exercise_category": "compound",
                  "muscle_group": "quads",
                  "sets": [
                    { "target_reps": 5, "target_weight_kg": 100, "target_duration_seconds": null, "target_rpe": 8, "is_warmup": false }
                  ]
                }
              ]
            }
          ]
        }
        """
    }

    private func repeatWeekJSON(number: Int, repeatOf: Int) -> String {
        """
        { "week_number": \(number), "repeat_of_week": \(repeatOf), "days": [] }
        """
    }

    private func programJSON(weeks: [String], durationWeeks: Int?) -> String {
        let duration = durationWeeks.map(String.init) ?? "null"
        return """
        {
          "program_name": "In-season strength",
          "sport_type": "lifting",
          "session_type": "strength",
          "duration_weeks": \(duration),
          "phases": [],
          "weeks": [\(weeks.joined(separator: ","))]
        }
        """
    }

    private func decode(_ json: String) throws -> Response {
        try JSONDecoder().decode(Response.self, from: Data(json.utf8))
    }

    private func exerciseNames(inWeekOrder weeks: [Response.ParsedWeek]) -> [String] {
        weeks.flatMap { week in
            week.days.flatMap { $0.exercises.map(\.exercise_name) }
        }
    }

    // MARK: - (a) Repeats expand to the weeks they stand for

    func test_expandedWeeks_alternatingRepeatsRestoreEveryWeeksContent() throws {
        let response = try decode(programJSON(
            weeks: [
                fullWeekJSON(number: 1, exercise: "Back squat", includeRepeatKey: true),
                repeatWeekJSON(number: 2, repeatOf: 1),
                fullWeekJSON(number: 3, exercise: "Front squat", includeRepeatKey: true),
                repeatWeekJSON(number: 4, repeatOf: 3)
            ],
            durationWeeks: 4
        ))

        let expanded = WorkoutLLMImportService.expandedWeeks(of: response)

        XCTAssertEqual(expanded.map(\.week_number), [1, 2, 3, 4])
        XCTAssertEqual(
            exerciseNames(inWeekOrder: expanded),
            ["Back squat", "Back squat", "Front squat", "Front squat"],
            "week 2 carries week 1's content, week 4 carries week 3's"
        )
        XCTAssertEqual(expanded.map { $0.days.first?.title },
                       ["W1 upper", "W1 upper", "W3 upper", "W3 upper"],
                       "a repeat restores the source week's day titles verbatim")
        XCTAssertTrue(expanded.allSatisfy { $0.repeat_of_week == nil },
                      "an expanded week is a full week — no pointer survives expansion")
    }

    func test_expandedWeeks_chainedRepeatResolvesThroughTheAlreadyResolvedWeek() throws {
        let response = try decode(programJSON(
            weeks: [
                fullWeekJSON(number: 1, exercise: "Back squat", includeRepeatKey: true),
                repeatWeekJSON(number: 2, repeatOf: 1),
                repeatWeekJSON(number: 3, repeatOf: 2)
            ],
            durationWeeks: 3
        ))

        let expanded = WorkoutLLMImportService.expandedWeeks(of: response)

        XCTAssertEqual(expanded.count, 3)
        XCTAssertEqual(exerciseNames(inWeekOrder: expanded),
                       ["Back squat", "Back squat", "Back squat"])
    }

    func test_buildProgram_compactResponseMatchesFullyWrittenResponse() throws {
        let compact = try decode(programJSON(
            weeks: [
                fullWeekJSON(number: 1, exercise: "Back squat", includeRepeatKey: true),
                repeatWeekJSON(number: 2, repeatOf: 1),
                fullWeekJSON(number: 3, exercise: "Front squat", includeRepeatKey: true),
                repeatWeekJSON(number: 4, repeatOf: 3)
            ],
            durationWeeks: 4
        ))
        let written = try decode(programJSON(
            weeks: [
                fullWeekJSON(number: 1, exercise: "Back squat", includeRepeatKey: true),
                fullWeekJSON(number: 2, exercise: "Back squat", includeRepeatKey: true),
                fullWeekJSON(number: 3, exercise: "Front squat", includeRepeatKey: true),
                fullWeekJSON(number: 4, exercise: "Front squat", includeRepeatKey: true)
            ],
            durationWeeks: 4
        ))

        let athleteId = UUID()
        let fromCompact = WorkoutLLMImportService.buildProgram(
            from: compact, durationWeeks: 4, durationSource: .readFromFile,
            athleteId: athleteId, source: .pdf
        )
        let fromWritten = WorkoutLLMImportService.buildProgram(
            from: written, durationWeeks: 4, durationSource: .readFromFile,
            athleteId: athleteId, source: .pdf
        )

        // Day titles differ by design between the two fixtures (a repeat restores its
        // SOURCE week's title), so the equivalence that matters is structure + content.
        XCTAssertEqual(fromCompact.program.days.map(\.weekNumber),
                       fromWritten.program.days.map(\.weekNumber))
        XCTAssertEqual(fromCompact.program.days.map(\.dayNumber),
                       fromWritten.program.days.map(\.dayNumber))
        XCTAssertEqual(fromCompact.dayTemplates.count, fromWritten.dayTemplates.count)

        let compactExercises = fromCompact.dayTemplates.flatMap { template in
            template.sortedGroups.flatMap { $0.sortedExercises.map(\.exerciseName) }
        }
        let writtenExercises = fromWritten.dayTemplates.flatMap { template in
            template.sortedGroups.flatMap { $0.sortedExercises.map(\.exerciseName) }
        }
        XCTAssertEqual(compactExercises, writtenExercises,
                       "the athlete ends up with the same program either way")
        XCTAssertEqual(compactExercises,
                       ["Back squat", "Back squat", "Front squat", "Front squat"])
    }

    // MARK: - (b) Backward compatibility: no repeat_of_week key at all

    func test_decode_responseWithoutRepeatKeyDecodesAsFullWeeks() throws {
        let response = try decode(programJSON(
            weeks: [
                fullWeekJSON(number: 1, exercise: "Back squat", includeRepeatKey: false),
                fullWeekJSON(number: 2, exercise: "Front squat", includeRepeatKey: false)
            ],
            durationWeeks: 2
        ))

        XCTAssertEqual(response.weeks.count, 2)
        XCTAssertTrue(response.weeks.allSatisfy { $0.repeat_of_week == nil },
                      "an absent key is a full week, not a decode failure")

        let expanded = WorkoutLLMImportService.expandedWeeks(of: response)
        XCTAssertEqual(expanded.map(\.week_number), response.weeks.map(\.week_number))
        XCTAssertEqual(exerciseNames(inWeekOrder: expanded), ["Back squat", "Front squat"])

        let built = WorkoutLLMImportService.buildProgram(
            from: response, durationWeeks: 2, durationSource: .readFromFile,
            athleteId: UUID(), source: .text
        )
        XCTAssertEqual(built.program.days.count, 2)
        XCTAssertEqual(built.program.days.map(\.title), ["W1 upper", "W2 upper"])
    }

    func test_statedDuration_countsRepeatWeeksAsWeeksTheFileStates() throws {
        let response = try decode(programJSON(
            weeks: [
                fullWeekJSON(number: 1, exercise: "Back squat", includeRepeatKey: true),
                repeatWeekJSON(number: 2, repeatOf: 1),
                repeatWeekJSON(number: 3, repeatOf: 1)
            ],
            durationWeeks: nil
        ))
        XCTAssertEqual(WorkoutLLMImportService.statedDurationWeeks(of: response), 3,
                       "a compacted 3-week block is still a 3-week block")
    }

    // MARK: - (c) Unsafe pointers

    /// A forward or self pointer is IGNORED, not honoured and not fatal. Following it
    /// would need content that does not exist at that point in the week order, and this
    /// service never invents a program's numbers. The week then carries no days, so it
    /// drops out exactly as an empty week always did, and `buildProgram`'s existing
    /// cycling covers its slot with real parsed content.
    func test_expandedWeeks_forwardAndSelfPointersAreIgnored() throws {
        let response = try decode(programJSON(
            weeks: [
                fullWeekJSON(number: 1, exercise: "Back squat", includeRepeatKey: true),
                repeatWeekJSON(number: 2, repeatOf: 3),   // forward
                repeatWeekJSON(number: 3, repeatOf: 3)    // itself
            ],
            durationWeeks: 3
        ))

        let expanded = WorkoutLLMImportService.expandedWeeks(of: response)

        XCTAssertEqual(expanded.map(\.week_number), [1],
                       "only the week with real content survives")
        XCTAssertEqual(exerciseNames(inWeekOrder: expanded), ["Back squat"])
    }

    func test_buildProgram_forwardPointerStillFillsTheBlockByCycling() throws {
        let response = try decode(programJSON(
            weeks: [
                fullWeekJSON(number: 1, exercise: "Back squat", includeRepeatKey: true),
                repeatWeekJSON(number: 2, repeatOf: 3),
                repeatWeekJSON(number: 3, repeatOf: 3)
            ],
            durationWeeks: 3
        ))

        let built = WorkoutLLMImportService.buildProgram(
            from: response, durationWeeks: 3, durationSource: .readFromFile,
            athleteId: UUID(), source: .pdf
        )

        XCTAssertEqual(built.program.days.map(\.weekNumber), [1, 2, 3],
                       "the block still has three weeks — no gap, no crash")
        XCTAssertEqual(built.dayTemplates.count, 3)
        let names = built.dayTemplates.flatMap { template in
            template.sortedGroups.flatMap { $0.sortedExercises.map(\.exerciseName) }
        }
        XCTAssertEqual(names, ["Back squat", "Back squat", "Back squat"],
                       "cycled from parsed content — nothing invented")
    }

    /// Pathological but cheap to guard: every week a pointer, none resolvable.
    func test_buildProgram_allWeeksUnresolvableYieldsNoDays() throws {
        let response = try decode(programJSON(
            weeks: [
                repeatWeekJSON(number: 1, repeatOf: 1),
                repeatWeekJSON(number: 2, repeatOf: 5)
            ],
            durationWeeks: 2
        ))

        let built = WorkoutLLMImportService.buildProgram(
            from: response, durationWeeks: 2, durationSource: .readFromFile,
            athleteId: UUID(), source: .pdf
        )
        XCTAssertTrue(built.program.days.isEmpty)
        XCTAssertTrue(built.dayTemplates.isEmpty)
    }
}
