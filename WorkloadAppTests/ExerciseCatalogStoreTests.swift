import XCTest
@testable import workload_management

final class ExerciseCatalogStoreTests: XCTestCase {

    /// The bundled catalog decodes fully and every enum rawValue is valid.
    func testCatalogDecodesFullyWithValidEnumRawValues() {
        let catalog = ExerciseCatalogStore.catalog
        XCTAssertEqual(catalog.count, 1324, "Bundled catalog should contain 1,324 records")
        for exercise in catalog {
            XCTAssertNotNil(
                MuscleGroup(rawValue: exercise.muscleGroup),
                "Unknown muscleGroup rawValue \"\(exercise.muscleGroup)\" on \(exercise.name)"
            )
            XCTAssertNotNil(
                ExerciseCategory(rawValue: exercise.category),
                "Unknown category rawValue \"\(exercise.category)\" on \(exercise.name)"
            )
        }
    }

    /// Token AND-match: "barbell bench" finds "Barbell Bench Press".
    func testSearchTokenAndMatchFindsBarbellBenchPress() {
        let results = ExerciseCatalogStore.search(query: "barbell bench")
        XCTAssertTrue(
            results.contains { $0.name == "Barbell Bench Press" },
            "search(\"barbell bench\") should return \"Barbell Bench Press\""
        )
    }

    /// Case-insensitive name lookup returns instructions for a picked name.
    func testEntryNamedIsCaseInsensitive() {
        let entry = ExerciseCatalogStore.entry(named: "barbell bench press")
        XCTAssertEqual(entry?.name, "Barbell Bench Press")
        XCTAssertFalse(entry?.steps.en.isEmpty ?? true)
    }
}
