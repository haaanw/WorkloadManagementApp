import XCTest
@testable import workload_management

/// The `▲ PR` landmark's value resolution (v1.7.2 logging overhaul).
///
/// The load-bearing case is `test_takesTheHeaviest_notTheFirst`: `PRDetector` appends a new
/// record every time a lift is beaten instead of updating the existing one, so the athlete's
/// records hold a HISTORY of `.maxWeight` rows per movement. Taking the first would print an
/// old number on the rule as if it were the record.
final class PersonalRecordLookupTests: XCTestCase {

    private func record(
        _ name: String,
        _ type: PRType,
        _ value: Double
    ) -> PersonalRecord {
        PersonalRecord(exerciseName: name, recordType: type, value: value)
    }

    func test_noRecords_isNil() {
        XCTAssertNil(
            PersonalRecordLookup.bestMaxWeightKg(exerciseName: "Trap Bar Deadlift", in: [])
        )
    }

    func test_takesTheHeaviest_notTheFirst() {
        // Ordered so that `.first` would return the oldest, lowest record.
        let records = [
            record("Trap Bar Deadlift", .maxWeight, 140),
            record("Trap Bar Deadlift", .maxWeight, 170),
            record("Trap Bar Deadlift", .maxWeight, 155)
        ]
        XCTAssertEqual(
            PersonalRecordLookup.bestMaxWeightKg(exerciseName: "Trap Bar Deadlift", in: records),
            170
        )
    }

    func test_ignoresOtherRecordTypes() {
        // A max-VOLUME record is a much larger number (kg × reps) and would dominate the rule
        // if the type filter were dropped.
        let records = [
            record("Split Squat", .maxVolume, 1680),
            record("Split Squat", .maxReps, 20),
            record("Split Squat", .maxWeight, 60)
        ]
        XCTAssertEqual(
            PersonalRecordLookup.bestMaxWeightKg(exerciseName: "Split Squat", in: records),
            60
        )
    }

    func test_ignoresOtherExercises() {
        let records = [
            record("Barbell Back Squat", .maxWeight, 142.5),
            record("Trap Bar Deadlift", .maxWeight, 170)
        ]
        XCTAssertEqual(
            PersonalRecordLookup.bestMaxWeightKg(exerciseName: "Barbell Back Squat", in: records),
            142.5
        )
    }

    func test_nameMatchIsExact() {
        // Exercise identity is the name string, and `PRDetector` compares it exactly. A fuzzy
        // match here would draw a PR that detection will never update.
        let records = [record("Trap Bar Deadlift", .maxWeight, 170)]
        XCTAssertNil(
            PersonalRecordLookup.bestMaxWeightKg(exerciseName: "trap bar deadlift", in: records)
        )
        XCTAssertNil(
            PersonalRecordLookup.bestMaxWeightKg(exerciseName: "Trap Bar Deadlift ", in: records)
        )
    }

    func test_onlyMaxWeightRecords_absentType_isNil() {
        let records = [record("Plank", .maxReps, 120)]
        XCTAssertNil(
            PersonalRecordLookup.bestMaxWeightKg(exerciseName: "Plank", in: records)
        )
    }
}
