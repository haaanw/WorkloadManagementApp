import XCTest
@testable import workload_management

final class REDSRiskEngineTests: XCTestCase {

    // Helper to build an input with sensible non-excluded defaults.
    private func makeInput(
        recentCycleLengths: [Int] = [],
        medianCycleLength: Int? = nil,
        daysSinceLastCycleStart: Int? = nil,
        hasSnapshotData: Bool = true,
        isPregnant: Bool = false,
        isLactating: Bool = false,
        isOnHormonalContraceptive: Bool = false,
        hasPCOS: Bool = false,
        isPerimenopausal: Bool = false
    ) -> REDSRiskEngine.CycleHistoryInput {
        REDSRiskEngine.CycleHistoryInput(
            recentCycleLengths: recentCycleLengths,
            medianCycleLength: medianCycleLength,
            daysSinceLastCycleStart: daysSinceLastCycleStart,
            hasSnapshotData: hasSnapshotData,
            isPregnant: isPregnant,
            isLactating: isLactating,
            isOnHormonalContraceptive: isOnHormonalContraceptive,
            hasPCOS: hasPCOS,
            isPerimenopausal: isPerimenopausal
        )
    }

    // MARK: - Long-cycle rule (D-10)

    func test_longCycleRule_threeLongCycles_returnsMonitor() {
        let input = makeInput(recentCycleLengths: [38, 41, 37], medianCycleLength: 38)
        XCTAssertEqual(REDSRiskEngine.classify(input: input), .monitor)
    }

    func test_longCycleRule_usesMostRecentThree_returnsMonitor() {
        // Older normal cycles, then three consecutive long ones.
        let input = makeInput(recentCycleLengths: [28, 27, 36, 40, 39], medianCycleLength: 30)
        XCTAssertEqual(REDSRiskEngine.classify(input: input), .monitor)
    }

    func test_longCycleRule_onlyTwoLong_returnsNone() {
        // Most recent three are [29, 38, 41] — not all > 35.
        let input = makeInput(recentCycleLengths: [38, 41, 29], medianCycleLength: 30)
        XCTAssertEqual(REDSRiskEngine.classify(input: input), .none)
    }

    func test_longCycleRule_exactly35_isNotLong_returnsNone() {
        // 35 is not > 35.
        let input = makeInput(recentCycleLengths: [35, 35, 35], medianCycleLength: 35)
        XCTAssertEqual(REDSRiskEngine.classify(input: input), .none)
    }

    func test_longCycleRule_fewerThanThreeLengths_returnsNone() {
        let input = makeInput(recentCycleLengths: [40, 41], medianCycleLength: 40)
        XCTAssertEqual(REDSRiskEngine.classify(input: input), .none)
    }

    // MARK: - Missed-period rule (D-10)

    func test_missedPeriodRule_overThreeXMedian_returnsMonitor() {
        // 3 * 28 = 84, floor 90 -> threshold 90; 95 >= 90.
        let input = makeInput(
            recentCycleLengths: [28, 27, 29],
            medianCycleLength: 28,
            daysSinceLastCycleStart: 95
        )
        XCTAssertEqual(REDSRiskEngine.classify(input: input), .monitor)
    }

    func test_missedPeriodRule_threeXMedianAboveFloor_returnsMonitor() {
        // 3 * 35 = 105 > floor 90; 110 >= 105.
        let input = makeInput(
            recentCycleLengths: [34, 35, 33],
            medianCycleLength: 35,
            daysSinceLastCycleStart: 110
        )
        XCTAssertEqual(REDSRiskEngine.classify(input: input), .monitor)
    }

    func test_missedPeriodRule_belowFloor_returnsNone() {
        // 3 * 28 = 84, floor 90 -> threshold 90; 60 < 90.
        let input = makeInput(
            recentCycleLengths: [28, 27, 29],
            medianCycleLength: 28,
            daysSinceLastCycleStart: 60
        )
        XCTAssertEqual(REDSRiskEngine.classify(input: input), .none)
    }

    func test_missedPeriodRule_missingDaysSince_returnsNone() {
        let input = makeInput(
            recentCycleLengths: [28, 27, 29],
            medianCycleLength: 28,
            daysSinceLastCycleStart: nil
        )
        XCTAssertEqual(REDSRiskEngine.classify(input: input), .none)
    }

    // MARK: - Regular cycles (negative case)

    func test_regularCycles_returnsNone() {
        let input = makeInput(
            recentCycleLengths: [27, 28, 29],
            medianCycleLength: 28,
            daysSinceLastCycleStart: 14
        )
        XCTAssertEqual(REDSRiskEngine.classify(input: input), .none)
    }

    // MARK: - Exclusions short-circuit first (D-11)

    func test_exclusion_pregnant_forcesNone_evenWithMonitorPattern() {
        let input = makeInput(
            recentCycleLengths: [38, 41, 37],
            medianCycleLength: 38,
            daysSinceLastCycleStart: 200,
            isPregnant: true
        )
        XCTAssertEqual(REDSRiskEngine.classify(input: input), .none)
    }

    func test_exclusion_lactating_forcesNone() {
        let input = makeInput(
            recentCycleLengths: [38, 41, 37],
            medianCycleLength: 38,
            isLactating: true
        )
        XCTAssertEqual(REDSRiskEngine.classify(input: input), .none)
    }

    func test_exclusion_onHormonalContraceptive_forcesNone() {
        let input = makeInput(
            recentCycleLengths: [38, 41, 37],
            medianCycleLength: 38,
            isOnHormonalContraceptive: true
        )
        XCTAssertEqual(REDSRiskEngine.classify(input: input), .none)
    }

    func test_exclusion_hasPCOS_forcesNone() {
        let input = makeInput(
            recentCycleLengths: [38, 41, 37],
            medianCycleLength: 38,
            hasPCOS: true
        )
        XCTAssertEqual(REDSRiskEngine.classify(input: input), .none)
    }

    func test_exclusion_isPerimenopausal_forcesNone() {
        let input = makeInput(
            recentCycleLengths: [38, 41, 37],
            medianCycleLength: 38,
            isPerimenopausal: true
        )
        XCTAssertEqual(REDSRiskEngine.classify(input: input), .none)
    }

    // MARK: - Sparse / no data (D-14)

    func test_noSnapshotData_returnsNone() {
        let input = makeInput(
            recentCycleLengths: [38, 41, 37],
            medianCycleLength: 38,
            daysSinceLastCycleStart: 200,
            hasSnapshotData: false
        )
        XCTAssertEqual(REDSRiskEngine.classify(input: input), .none)
    }

    func test_emptyHistory_returnsNone() {
        let input = makeInput()
        XCTAssertEqual(REDSRiskEngine.classify(input: input), .none)
    }
}
