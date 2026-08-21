import XCTest
@testable import workload_management

/// Hermetic, network-free tests for `WorkoutVoiceLogService`'s decoding contract and its pure
/// `mapToParsedSessionDraft` mapper. Fixtures are decoded from inline JSON strings so the
/// snake_case wire contract (mirroring `Supabase/functions/parse-workout/index.ts`'s
/// `LoggedWorkout` in `mode: "log"`) is locked by the test, not just assumed.
final class WorkoutVoiceLogServiceTests: XCTestCase {

    private func decode(_ json: String) throws -> WorkoutVoiceLogService.ParsedLoggedWorkoutResponse {
        try JSONDecoder().decode(
            WorkoutVoiceLogService.ParsedLoggedWorkoutResponse.self,
            from: Data(json.utf8)
        )
    }

    // MARK: - 1. Full en narrative: draft shape, isDone, RPE preserved (not RIR)

    func test_enNarrative_mapsToDraftWithDoneSetsAndPreservedRPE() throws {
        let json = """
        {
          "workout_name": "Push Day",
          "sport_type": "lifting",
          "session_type": "strength",
          "session_rpe": 7,
          "session_duration_minutes": 52,
          "groups": [
            {
              "group_name": "Main",
              "exercises": [
                {
                  "exercise_name": "incline dumbbell press",
                  "exercise_category": "compound",
                  "muscle_group": "chest",
                  "sets": [
                    {"reps": 8, "weight_kg": 24.0, "duration_seconds": null, "rpe": 7.5, "is_warmup": false},
                    {"reps": 6, "weight_kg": 26.0, "duration_seconds": null, "rpe": 8.0, "is_warmup": false},
                    {"reps": 12, "weight_kg": null, "duration_seconds": null, "rpe": null, "is_warmup": true}
                  ]
                },
                {
                  "exercise_name": "triceps pushdown",
                  "exercise_category": "isolation",
                  "muscle_group": "triceps",
                  "sets": [
                    {"reps": 12, "weight_kg": 20.0, "duration_seconds": null, "rpe": 9.0, "is_warmup": false}
                  ]
                }
              ]
            }
          ]
        }
        """
        let response = try decode(json)

        let draft = WorkoutVoiceLogService.mapToParsedSessionDraft(
            response,
            transcript: "push day, incline dumbbell press...",
            catalogExercises: [],
            customExercises: []
        )

        XCTAssertEqual(draft.sessionName, "Push Day")
        XCTAssertEqual(draft.sportType, .lifting)
        XCTAssertEqual(draft.sessionType, .strength)
        XCTAssertEqual(draft.sessionRPE, 7)
        XCTAssertEqual(draft.durationMinutes, 52)
        XCTAssertEqual(draft.transcript, "push day, incline dumbbell press...")
        XCTAssertEqual(draft.entries.count, 2)

        // Every non-empty parsed set is a logged actual: isDone must be true.
        for entry in draft.entries {
            for set in entry.sets {
                XCTAssertTrue(set.isDone)
            }
        }

        let firstExerciseSets = draft.entries[0].sets
        XCTAssertEqual(firstExerciseSets.count, 3)
        XCTAssertEqual(firstExerciseSets[0].reps, 8)
        XCTAssertEqual(firstExerciseSets[0].weightKg, 24.0)
        // RPE stays RPE — never converted to RIR (that lossy conversion is plan-mode-only).
        XCTAssertEqual(firstExerciseSets[0].rpe, 7.5)
        XCTAssertNil(firstExerciseSets[0].rir)
        XCTAssertFalse(firstExerciseSets[0].isWarmup)
        XCTAssertTrue(firstExerciseSets[2].isWarmup)
        XCTAssertNil(firstExerciseSets[2].rpe)

        // Single group in the response -> no synthetic groupName tag.
        XCTAssertNil(draft.entries[0].groupName)
    }

    // MARK: - 2. zh-Hans-named exercise: resolver miss lands in unresolvedExerciseNames

    func test_zhHansExerciseName_unresolvedLandsInUnresolvedList() throws {
        let json = """
        {
          "workout_name": "\u{5065}\u{8eab}",
          "sport_type": "lifting",
          "session_type": "strength",
          "session_rpe": null,
          "session_duration_minutes": null,
          "groups": [
            {
              "group_name": "Main",
              "exercises": [
                {
                  "exercise_name": "\u{5367}\u{63a8}",
                  "exercise_category": "compound",
                  "muscle_group": "chest",
                  "sets": [
                    {"reps": 5, "weight_kg": 40.0, "duration_seconds": null, "rpe": null, "is_warmup": false}
                  ]
                }
              ]
            }
          ]
        }
        """
        let response = try decode(json)

        let draft = WorkoutVoiceLogService.mapToParsedSessionDraft(
            response,
            transcript: "\u{5367}\u{63a8} wu ci wu ge, sishi gongjin",
            catalogExercises: [],
            customExercises: []
        )

        XCTAssertEqual(draft.unresolvedExerciseNames, ["\u{5367}\u{63a8}"])
        XCTAssertEqual(draft.entries.count, 1)
        // Miss path: spoken name kept verbatim, LLM category mapped.
        XCTAssertEqual(draft.entries[0].exerciseName, "\u{5367}\u{63a8}")
        XCTAssertEqual(draft.entries[0].exerciseCategory, .compound)
        XCTAssertEqual(draft.entries[0].muscleGroup, .chest)
    }

    // MARK: - 3. Catalog hit: canonical name wins, matchedCatalogName populated

    func test_catalogHit_usesCanonicalNameNotSpokenVariant() throws {
        let json = """
        {
          "workout_name": "Bench Day",
          "sport_type": "lifting",
          "session_type": "strength",
          "session_rpe": null,
          "session_duration_minutes": null,
          "groups": [
            {
              "group_name": "Main",
              "exercises": [
                {
                  "exercise_name": "bench press",
                  "exercise_category": "compound",
                  "muscle_group": "chest",
                  "sets": [
                    {"reps": 5, "weight_kg": 80.0, "duration_seconds": null, "rpe": 8.0, "is_warmup": false}
                  ]
                }
              ]
            }
          ]
        }
        """
        let response = try decode(json)
        let catalog = [
            ExerciseDefinition(name: "Barbell Bench Press", category: .compound, muscleGroup: .chest)
        ]

        let draft = WorkoutVoiceLogService.mapToParsedSessionDraft(
            response,
            transcript: "bench press, five reps, eighty kilos",
            catalogExercises: catalog,
            customExercises: []
        )

        XCTAssertEqual(draft.entries.count, 1)
        XCTAssertEqual(draft.entries[0].exerciseName, "Barbell Bench Press")
        XCTAssertTrue(draft.unresolvedExerciseNames.isEmpty)
    }

    func test_matchedCatalogName_populatedOnHitNilOnMiss() {
        let hit = WorkoutLLMImportService.resolveLocalExercise(
            name: "bench press",
            sportType: .lifting,
            catalogExercises: [
                ExerciseDefinition(name: "Barbell Bench Press", category: .compound, muscleGroup: .chest)
            ],
            customExercises: []
        )
        XCTAssertEqual(hit?.matchedCatalogName, "Barbell Bench Press")

        let miss = WorkoutLLMImportService.resolveLocalExercise(
            name: "Zorb Ball Sprints",
            sportType: .lifting,
            catalogExercises: [],
            customExercises: []
        )
        XCTAssertNil(miss)

        // LLM-sourced resolutions carry no canonical catalog name either.
        let llmResolved = try? WorkoutLLMImportService.resolveLLMExercise(
            .init(exerciseName: "Copenhagen Plank", exerciseCategoryRaw: "bodyweight", muscleGroupRaw: "adductors"),
            requestedName: "Copenhagen plank",
            sportType: .lifting
        )
        XCTAssertNil(llmResolved?.matchedCatalogName)
    }

    // MARK: - 4. session_rpe / session_duration_minutes propagation + clamping

    func test_sessionRPEAndDuration_propagate() throws {
        let json = """
        {
          "workout_name": "Leg Day",
          "sport_type": "lifting",
          "session_type": "strength",
          "session_rpe": 8,
          "session_duration_minutes": 45,
          "groups": [{"group_name": "Main", "exercises": []}]
        }
        """
        let response = try decode(json)
        let draft = WorkoutVoiceLogService.mapToParsedSessionDraft(
            response, transcript: "", catalogExercises: [], customExercises: []
        )
        XCTAssertEqual(draft.sessionRPE, 8)
        XCTAssertEqual(draft.durationMinutes, 45)
    }

    func test_outOfRangeSessionRPE_clampsToNil() throws {
        let json = """
        {
          "workout_name": "Leg Day",
          "sport_type": "lifting",
          "session_type": "strength",
          "session_rpe": 14,
          "session_duration_minutes": -5,
          "groups": [{"group_name": "Main", "exercises": []}]
        }
        """
        let response = try decode(json)
        let draft = WorkoutVoiceLogService.mapToParsedSessionDraft(
            response, transcript: "", catalogExercises: [], customExercises: []
        )
        // Server clamps too — belt and braces on the client.
        XCTAssertNil(draft.sessionRPE)
        XCTAssertNil(draft.durationMinutes)
    }

    // MARK: - 5. Empty sets array -> single not-done placeholder

    func test_emptySetsArray_producesSingleNotDonePlaceholder() throws {
        let json = """
        {
          "workout_name": "Quick Log",
          "sport_type": "lifting",
          "session_type": "strength",
          "session_rpe": null,
          "session_duration_minutes": null,
          "groups": [
            {
              "group_name": "Main",
              "exercises": [
                {
                  "exercise_name": "squat",
                  "exercise_category": "compound",
                  "muscle_group": "legs",
                  "sets": []
                }
              ]
            }
          ]
        }
        """
        let response = try decode(json)
        let draft = WorkoutVoiceLogService.mapToParsedSessionDraft(
            response, transcript: "squat", catalogExercises: [], customExercises: []
        )

        XCTAssertEqual(draft.entries.count, 1)
        XCTAssertEqual(draft.entries[0].sets.count, 1)
        XCTAssertFalse(draft.entries[0].sets[0].isDone)
        XCTAssertNil(draft.entries[0].sets[0].reps)
        XCTAssertNil(draft.entries[0].sets[0].weightKg)
    }

    // MARK: - 6. Decoding: nulls + missing optional keys tolerated

    func test_decoding_toleratesMissingOptionalKeysAndNulls() throws {
        let json = """
        {
          "workout_name": "Bodyweight Circuit",
          "sport_type": "lifting",
          "session_type": "strength",
          "groups": [
            {
              "group_name": "Main",
              "exercises": [
                {
                  "exercise_name": "push ups",
                  "exercise_category": "bodyweight",
                  "sets": [
                    {"reps": 20, "is_warmup": false}
                  ]
                }
              ]
            }
          ]
        }
        """
        let response = try decode(json)

        XCTAssertEqual(response.workout_name, "Bodyweight Circuit")
        XCTAssertNil(response.session_rpe)
        XCTAssertNil(response.session_duration_minutes)
        XCTAssertEqual(response.groups.count, 1)
        XCTAssertNil(response.groups[0].exercises[0].muscle_group)
        let set = response.groups[0].exercises[0].sets[0]
        XCTAssertEqual(set.reps, 20)
        XCTAssertNil(set.weight_kg)
        XCTAssertNil(set.duration_seconds)
        XCTAssertNil(set.rpe)
        XCTAssertFalse(set.is_warmup)
    }

    // MARK: - Multi-group tagging

    func test_multipleGroups_tagsEntriesWithGroupName() throws {
        let json = """
        {
          "workout_name": "Full Body",
          "sport_type": "lifting",
          "session_type": "strength",
          "session_rpe": null,
          "session_duration_minutes": null,
          "groups": [
            {
              "group_name": "Upper",
              "exercises": [
                {
                  "exercise_name": "row",
                  "exercise_category": "compound",
                  "muscle_group": "back",
                  "sets": [{"reps": 10, "weight_kg": 50.0, "is_warmup": false}]
                }
              ]
            },
            {
              "group_name": "Lower",
              "exercises": [
                {
                  "exercise_name": "leg press",
                  "exercise_category": "compound",
                  "muscle_group": "legs",
                  "sets": [{"reps": 10, "weight_kg": 100.0, "is_warmup": false}]
                }
              ]
            }
          ]
        }
        """
        let response = try decode(json)
        let draft = WorkoutVoiceLogService.mapToParsedSessionDraft(
            response, transcript: "", catalogExercises: [], customExercises: []
        )

        XCTAssertEqual(draft.entries.count, 2)
        XCTAssertEqual(draft.entries[0].groupName, "Upper")
        XCTAssertEqual(draft.entries[1].groupName, "Lower")
    }
}
