import XCTest
@testable import workload_management

final class MuscleGroupTaxonomyTests: XCTestCase {

    // MARK: - Backward compat: old rawValues still decode (D-03)

    func test_originalCoarseRawValues_stillDecode() {
        XCTAssertEqual(MuscleGroup(rawValue: "chest"), .chest)
        XCTAssertEqual(MuscleGroup(rawValue: "back"), .back)
        XCTAssertEqual(MuscleGroup(rawValue: "legs"), .legs)
        XCTAssertEqual(MuscleGroup(rawValue: "shoulders"), .shoulders)
        XCTAssertEqual(MuscleGroup(rawValue: "arms"), .arms)
        XCTAssertEqual(MuscleGroup(rawValue: "core"), .core)
        XCTAssertEqual(MuscleGroup(rawValue: "fullBody"), .fullBody)
    }

    func test_unknownRawValue_decodesToNil_neverCrashes() {
        XCTAssertNil(MuscleGroup(rawValue: "notAMuscle"))
        XCTAssertNil(MuscleGroup(rawValue: ""))
    }

    // MARK: - New specific cases present

    func test_newSpecificCases_present() {
        let raws = Set(MuscleGroup.allCases.map(\.rawValue))
        let expectedNew: Set<String> = [
            "quads", "hamstrings", "glutes", "calves", "hipFlexors", "psoas",
            "adductors", "hipRotators", "tibialisAnterior",
            "lats", "trapsUpper", "trapsMid", "trapsLower", "rhomboids", "erectors",
            "pecsUpper", "pecsLower",
            "anteriorDelts", "lateralDelts", "posteriorDelts",
            "biceps", "triceps", "forearms",
            "rectusAbdominis", "obliques", "transverseAbdominis"
        ]
        XCTAssertTrue(expectedNew.isSubset(of: raws), "Missing new cases: \(expectedNew.subtracting(raws))")
        // 7 retained + 26 new
        XCTAssertEqual(MuscleGroup.allCases.count, 33)
    }

    func test_allCases_rawValueRoundTrips() {
        for group in MuscleGroup.allCases {
            XCTAssertEqual(MuscleGroup(rawValue: group.rawValue), group)
            XCTAssertEqual(group.id, group.rawValue)
        }
    }

    // MARK: - Region totality

    func test_region_totality_representativeSpread() {
        XCTAssertEqual(MuscleGroup.legs.region, .legs)
        XCTAssertEqual(MuscleGroup.quads.region, .legs)
        XCTAssertEqual(MuscleGroup.hamstrings.region, .legs)
        XCTAssertEqual(MuscleGroup.tibialisAnterior.region, .legs)
        XCTAssertEqual(MuscleGroup.lats.region, .back)
        XCTAssertEqual(MuscleGroup.erectors.region, .back)
        XCTAssertEqual(MuscleGroup.pecsUpper.region, .chest)
        XCTAssertEqual(MuscleGroup.pecsLower.region, .chest)
        XCTAssertEqual(MuscleGroup.lateralDelts.region, .shoulders)
        XCTAssertEqual(MuscleGroup.triceps.region, .arms)
        XCTAssertEqual(MuscleGroup.biceps.region, .arms)
        XCTAssertEqual(MuscleGroup.obliques.region, .core)
        XCTAssertEqual(MuscleGroup.rectusAbdominis.region, .core)
        XCTAssertEqual(MuscleGroup.fullBody.region, .fullBody)
    }

    func test_everyMuscle_hasARegion_andEveryRegionHasMembers() {
        // Totality: iterating allCases never traps (exhaustive switch guarantees a region)
        var byRegion: [MuscleRegion: Int] = [:]
        for group in MuscleGroup.allCases {
            byRegion[group.region, default: 0] += 1
        }
        for region in MuscleRegion.allCases {
            XCTAssertGreaterThan(byRegion[region] ?? 0, 0, "Region \(region) has no members")
        }
    }

    // MARK: - suggestedSpecific mapping (D-05)

    func test_suggestedSpecific_coarseDefaults() {
        XCTAssertEqual(MuscleGroup.suggestedSpecific(for: .legs), .quads)
        XCTAssertEqual(MuscleGroup.suggestedSpecific(for: .chest), .pecsLower)
        XCTAssertEqual(MuscleGroup.suggestedSpecific(for: .back), .lats)
        XCTAssertEqual(MuscleGroup.suggestedSpecific(for: .shoulders), .lateralDelts)
        XCTAssertEqual(MuscleGroup.suggestedSpecific(for: .arms), .biceps)
        XCTAssertEqual(MuscleGroup.suggestedSpecific(for: .core), .rectusAbdominis)
        XCTAssertEqual(MuscleGroup.suggestedSpecific(for: .fullBody), .fullBody)
    }

    func test_suggestedSpecific_isIdempotentForSpecificValues() {
        let specifics: [MuscleGroup] = [
            .quads, .hamstrings, .glutes, .calves, .lats, .trapsUpper,
            .pecsUpper, .pecsLower, .anteriorDelts, .lateralDelts,
            .biceps, .triceps, .forearms, .rectusAbdominis, .obliques
        ]
        for muscle in specifics {
            XCTAssertEqual(MuscleGroup.suggestedSpecific(for: muscle), muscle)
        }
    }

    // MARK: - Non-empty labels / symbols

    func test_everyMuscle_hasNonEmptyDisplayNameAndSystemImage() {
        for group in MuscleGroup.allCases {
            XCTAssertFalse(group.displayName.isEmpty, "\(group) has empty displayName")
            XCTAssertFalse(group.systemImage.isEmpty, "\(group) has empty systemImage")
        }
    }

    func test_everyRegion_hasNonEmptyLabelsAndIsIdentifiable() {
        for region in MuscleRegion.allCases {
            XCTAssertFalse(region.displayName.isEmpty, "\(region) has empty displayName")
            XCTAssertFalse(region.systemImage.isEmpty, "\(region) has empty systemImage")
            XCTAssertEqual(region.id, region.rawValue)
        }
    }
}
