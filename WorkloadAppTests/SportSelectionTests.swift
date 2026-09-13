import XCTest
@testable import workload_management

/// The multi-sport field's one invariant (v1.7.3 · U6 + U10): `athlete.sportType` is the FIRST
/// element of the ordered list every writer derives from `SportSelection`. These pin the
/// ordering rules that make that invariant hold across a legacy row, a toggle, and a deselect
/// of the primary itself.
final class SportSelectionTests: XCTestCase {

    // MARK: - Reading

    func test_noStoredSports_readsAsThePrimaryAlone() {
        XCTAssertEqual(SportSelection.sports(movementTypes: nil, primary: .teamSport), [.teamSport])
        XCTAssertEqual(SportSelection.sports(movementTypes: [], primary: .teamSport), [.teamSport])
    }

    func test_primaryLeads_evenWhenTheStoredArrayPutsItLater() {
        // A legacy row: the cold-start sheet wrote the set without touching the athlete's
        // sport. The athlete's sport still leads, and the stored order follows.
        let sports = SportSelection.sports(
            movementTypes: ["lifting", "running", "teamSport"],
            primary: .teamSport
        )
        XCTAssertEqual(sports, [.teamSport, .lifting, .running])
    }

    func test_primaryMissingFromTheStoredArray_isPrepended() {
        let sports = SportSelection.sports(movementTypes: ["lifting"], primary: .teamSport)
        XCTAssertEqual(sports, [.teamSport, .lifting])
    }

    func test_unknownRawValues_areDropped() {
        let sports = SportSelection.sports(
            movementTypes: ["lifting", "pickleball", "cycling"],
            primary: .lifting
        )
        XCTAssertEqual(sports, [.lifting, .cycling])
    }

    // MARK: - Toggling

    func test_addingSports_keepsThePrimaryAndAppendsInCaseOrder() {
        let next = SportSelection.ordered(
            current: [.teamSport, .lifting],
            selected: [.teamSport, .lifting, .cycling, .running]
        )
        // `running` precedes `cycling` in SportType.allCases, so the additions land that way.
        XCTAssertEqual(next, [.teamSport, .lifting, .running, .cycling])
        XCTAssertEqual(next.first, .teamSport)
    }

    func test_removingASecondarySport_leavesThePrimaryAlone() {
        let next = SportSelection.ordered(
            current: [.teamSport, .lifting, .running],
            selected: [.teamSport, .running]
        )
        XCTAssertEqual(next, [.teamSport, .running])
    }

    func test_deselectingThePrimary_promotesTheNextSport() {
        // The one case where the primary moves: the athlete took it out themselves.
        let next = SportSelection.ordered(
            current: [.teamSport, .lifting],
            selected: [.lifting]
        )
        XCTAssertEqual(next, [.lifting])
    }

    func test_emptySelection_isRefused() {
        // An athlete always has a sport. Clearing the last cell is a no-op, not a nil write.
        let current: [SportType] = [.teamSport]
        XCTAssertEqual(SportSelection.ordered(current: current, selected: []), current)
    }

    func test_orderIsStableUnderRepeatedApplication() {
        let once = SportSelection.ordered(current: [.lifting], selected: [.lifting, .teamSport])
        let twice = SportSelection.ordered(current: once, selected: Set(once))
        XCTAssertEqual(once, twice)
    }

    // MARK: - Injury history codec

    func test_injuryHistory_roundTrips() {
        let data = TrainingProfile.encodeInjuryHistory(regions: [.knee, .back], notes: "  left side  ")
        let decoded = TrainingProfile.decodeInjuryHistory(data)
        XCTAssertEqual(decoded.regions, [.knee, .back])
        XCTAssertEqual(decoded.notes, "left side")
    }

    func test_injuryHistory_noRegions_encodesNil() {
        XCTAssertNil(TrainingProfile.encodeInjuryHistory(regions: [], notes: "text with no region"))
    }

    func test_injuryHistory_bytesAreOrderIndependent() {
        // The field syncs; two devices answering the same thing must produce the same row.
        let a = TrainingProfile.encodeInjuryHistory(regions: [.knee, .shoulder, .ankle], notes: "")
        let b = TrainingProfile.encodeInjuryHistory(regions: [.ankle, .knee, .shoulder], notes: "")
        XCTAssertEqual(a, b)
    }

    func test_injuryHistory_unreadableData_readsAsEmpty() {
        let decoded = TrainingProfile.decodeInjuryHistory(Data("not json".utf8))
        XCTAssertTrue(decoded.regions.isEmpty)
        XCTAssertEqual(decoded.notes, "")
    }
}
