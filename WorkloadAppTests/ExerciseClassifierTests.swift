import XCTest
@testable import workload_management

final class ExerciseClassifierTests: XCTestCase {
    func testRepresentativeMovementVocabulary() {
        let cases: [(String, ExerciseCategory, MuscleGroup?)] = [
            ("Barbell back squat", .compound, .quads),
            ("Romanian deadlift", .compound, .hamstrings),
            ("Bench press", .compound, .chest),
            ("One-arm dumbbell row", .compound, .back),
            ("Power clean", .compound, .fullBody),
            ("Hang snatch", .compound, .fullBody),
            ("Hammer curl", .isolation, .biceps),
            ("Lateral raise", .isolation, .lateralDelts),
            ("Leg extension", .isolation, .quads),
            ("Cable fly", .isolation, .chest),
            ("Lat pulldown", .isolation, .lats),
            ("Easy run", .cardio, .fullBody),
            ("Bike erg", .cardio, .legs),
            ("Row-erg", .cardio, .fullBody),
            ("Pool swim", .cardio, .fullBody),
            ("Copenhagen plank", .bodyweight, .rectusAbdominis),
            ("Push-up", .bodyweight, .chest),
            ("Pull-up", .bodyweight, .lats),
            ("Parallel bar dip", .bodyweight, .chest),
            ("Shooting drill", .drill, .fullBody),
            ("Ball-handling and dribbling", .drill, .fullBody),
            ("Agility ladder", .drill, .legs),
            ("Mystery movement", .isolation, nil)
        ]

        for (name, expectedCategory, expectedMuscle) in cases {
            let result = ExerciseClassifier.classify(name)
            XCTAssertEqual(result.category, expectedCategory, "Unexpected category for \(name)")
            XCTAssertEqual(result.muscleGroup, expectedMuscle, "Unexpected muscle for \(name)")
        }
    }

    func testClassificationIsCaseAndHyphenInsensitive() {
        XCTAssertEqual(
            ExerciseClassifier.classify("PULL-UP"),
            ExerciseClassifier.Classification(category: .bodyweight, muscleGroup: .lats)
        )
        XCTAssertEqual(
            ExerciseClassifier.classify("DeFeNsIvE-SlIdE"),
            ExerciseClassifier.Classification(category: .drill, muscleGroup: .legs)
        )
    }
}
