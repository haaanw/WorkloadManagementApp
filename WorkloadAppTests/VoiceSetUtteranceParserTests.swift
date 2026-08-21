import XCTest
@testable import workload_management

final class VoiceSetUtteranceParserTests: XCTestCase {

    private struct Case {
        let utterance: String
        let weightUnit: WeightUnit
        let expected: VoiceSetUtteranceParser.Result
    }

    func testExactParses() {
        let cases: [Case] = [
            Case(
                utterance: "bench press eight reps at eighty",
                weightUnit: .kg,
                expected: .init(
                    exerciseName: "bench press", reps: 8, weightKg: 80.0,
                    durationSeconds: nil, rpe: nil, sameWeight: false, repeatLast: false
                )
            ),
            Case(
                utterance: "squat 8 reps at 100 kilos RPE 8",
                weightUnit: .kg,
                expected: .init(
                    exerciseName: "squat", reps: 8, weightKg: 100.0,
                    durationSeconds: nil, rpe: 8.0, sameWeight: false, repeatLast: false
                )
            ),
            Case(
                utterance: "same weight",
                weightUnit: .kg,
                expected: .init(
                    exerciseName: nil, reps: nil, weightKg: nil,
                    durationSeconds: nil, rpe: nil, sameWeight: true, repeatLast: false
                )
            ),
            Case(
                utterance: "eight reps same weight",
                weightUnit: .kg,
                expected: .init(
                    exerciseName: nil, reps: 8, weightKg: nil,
                    durationSeconds: nil, rpe: nil, sameWeight: true, repeatLast: false
                )
            ),
            Case(
                utterance: "add a set",
                weightUnit: .kg,
                expected: .init(
                    exerciseName: nil, reps: nil, weightKg: nil,
                    durationSeconds: nil, rpe: nil, sameWeight: false, repeatLast: true
                )
            ),
            Case(
                utterance: "another set",
                weightUnit: .kg,
                expected: .init(
                    exerciseName: nil, reps: nil, weightKg: nil,
                    durationSeconds: nil, rpe: nil, sameWeight: false, repeatLast: true
                )
            ),
            Case(
                utterance: "plank one minute",
                weightUnit: .kg,
                expected: .init(
                    exerciseName: "plank", reps: nil, weightKg: nil,
                    durationSeconds: 60, rpe: nil, sameWeight: false, repeatLast: false
                )
            ),
            Case(
                utterance: "八次八十公斤",
                weightUnit: .kg,
                expected: .init(
                    exerciseName: nil, reps: 8, weightKg: 80.0,
                    durationSeconds: nil, rpe: nil, sameWeight: false, repeatLast: false
                )
            ),
            Case(
                utterance: "同样重量",
                weightUnit: .kg,
                expected: .init(
                    exerciseName: nil, reps: nil, weightKg: nil,
                    durationSeconds: nil, rpe: nil, sameWeight: true, repeatLast: false
                )
            ),
            Case(
                utterance: "一样",
                weightUnit: .kg,
                expected: .init(
                    exerciseName: nil, reps: nil, weightKg: nil,
                    durationSeconds: nil, rpe: nil, sameWeight: true, repeatLast: false
                )
            ),
            Case(
                utterance: "再来一组",
                weightUnit: .kg,
                expected: .init(
                    exerciseName: nil, reps: nil, weightKg: nil,
                    durationSeconds: nil, rpe: nil, sameWeight: false, repeatLast: true
                )
            ),
            Case(
                utterance: "再一组",
                weightUnit: .kg,
                expected: .init(
                    exerciseName: nil, reps: nil, weightKg: nil,
                    durationSeconds: nil, rpe: nil, sameWeight: false, repeatLast: true
                )
            ),
            Case(
                utterance: "felt like a nine",
                weightUnit: .kg,
                expected: .init(
                    exerciseName: nil, reps: nil, weightKg: nil,
                    durationSeconds: nil, rpe: 9.0, sameWeight: false, repeatLast: false
                )
            ),
            Case(
                // RPE out of the 1...10 range is dropped, but the rest of the utterance
                // still parses — this is the "rpe nil but rest parses" contract case.
                utterance: "bench press 8 reps RPE 15",
                weightUnit: .kg,
                expected: .init(
                    exerciseName: "bench press", reps: 8, weightKg: nil,
                    durationSeconds: nil, rpe: nil, sameWeight: false, repeatLast: false
                )
            ),
            Case(
                utterance: "62.5 kg",
                weightUnit: .kg,
                expected: .init(
                    exerciseName: nil, reps: nil, weightKg: 62.5,
                    durationSeconds: nil, rpe: nil, sameWeight: false, repeatLast: false
                )
            )
        ]

        for testCase in cases {
            let result = VoiceSetUtteranceParser.parse(testCase.utterance, weightUnit: testCase.weightUnit)
            XCTAssertEqual(result, testCase.expected, "Unexpected parse for \"\(testCase.utterance)\"")
        }
    }

    func testNilParses() {
        let cases: [(utterance: String, weightUnit: WeightUnit)] = [
            ("bench press", .kg),                 // bare exercise name alone is not enough
            ("3 sets of 8 at 80", .kg),            // multi-set shorthand — LLM path expands it
            ("3x8", .kg),                          // multi-set shorthand
            ("8 by 80", .kg),                      // ambiguous sets×reps vs reps×weight
            ("", .kg),                             // empty
            ("   ", .kg),                          // whitespace only
            ("asdkjalksdj qqzxpp", .kg)            // gibberish, no recognizable quantity
        ]

        for testCase in cases {
            let result = VoiceSetUtteranceParser.parse(testCase.utterance, weightUnit: testCase.weightUnit)
            XCTAssertNil(result, "Expected nil for \"\(testCase.utterance)\"")
        }
    }

    func testBareWeightSpokenInAthletePreferenceConvertsToKilograms() {
        // "at eighty" carries no unit word, so it is read in the athlete's lbs preference
        // and converted to kg.
        let result = VoiceSetUtteranceParser.parse("bench press eight reps at eighty", weightUnit: .lbs)
        XCTAssertEqual(result?.exerciseName, "bench press")
        XCTAssertEqual(result?.reps, 8)
        XCTAssertEqual(result?.weightKg ?? -1, 36.29, accuracy: 0.01)
        XCTAssertNil(result?.rpe)
        XCTAssertEqual(result?.sameWeight, false)
        XCTAssertEqual(result?.repeatLast, false)
    }

    func testExplicitSpokenUnitWinsOverAthletePreference() {
        // "pounds" is spoken explicitly, so it wins even though the athlete prefers kg.
        let result = VoiceSetUtteranceParser.parse("185 pounds for 5", weightUnit: .kg)
        XCTAssertNil(result?.exerciseName)
        XCTAssertEqual(result?.reps, 5)
        XCTAssertEqual(result?.weightKg ?? -1, 83.91, accuracy: 0.01)
        XCTAssertEqual(result?.sameWeight, false)
        XCTAssertEqual(result?.repeatLast, false)
    }
}
