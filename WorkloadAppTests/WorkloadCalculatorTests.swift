import XCTest
@testable import workload_management

final class WorkloadCalculatorTests: XCTestCase {

    private let epsilon = 0.0001

    // MARK: - sessionTSS

    func test_sessionTSS_oneHourRPE5() {
        let tss = WorkloadCalculator.sessionTSS(durationSeconds: 3600, sessionRPE: 5)
        XCTAssertEqual(tss, 2.5, accuracy: epsilon)
    }

    func test_sessionTSS_oneHourRPE10() {
        let tss = WorkloadCalculator.sessionTSS(durationSeconds: 3600, sessionRPE: 10)
        XCTAssertEqual(tss, 10.0, accuracy: epsilon)
    }

    func test_sessionTSS_halfHourRPE6() {
        let tss = WorkloadCalculator.sessionTSS(durationSeconds: 1800, sessionRPE: 6)
        XCTAssertEqual(tss, 1.8, accuracy: epsilon)
    }

    func test_sessionTSS_zeroDuration() {
        let tss = WorkloadCalculator.sessionTSS(durationSeconds: 0, sessionRPE: 8)
        XCTAssertEqual(tss, 0)
    }

    func test_sessionTSS_zeroRPE() {
        let tss = WorkloadCalculator.sessionTSS(durationSeconds: 3600, sessionRPE: 0)
        XCTAssertEqual(tss, 0)
    }

    // MARK: - srpeLoad

    func test_srpeLoad_sixtyMinRPE7() {
        let load = WorkloadCalculator.srpeLoad(durationSeconds: 3600, sessionRPE: 7)
        XCTAssertEqual(load, 420.0, accuracy: epsilon)
    }

    func test_srpeLoad_ninetyMinRPE5() {
        let load = WorkloadCalculator.srpeLoad(durationSeconds: 5400, sessionRPE: 5)
        XCTAssertEqual(load, 450.0, accuracy: epsilon)
    }

    // MARK: - trimp

    func test_trimp_zone1Only() {
        let t = WorkloadCalculator.trimp(zoneDurationsMinutes: [10, 0, 0, 0, 0])
        XCTAssertEqual(t, 10.0, accuracy: epsilon)
    }

    func test_trimp_zone2Only() {
        let t = WorkloadCalculator.trimp(zoneDurationsMinutes: [0, 10, 0, 0, 0])
        XCTAssertEqual(t, 15.0, accuracy: epsilon)
    }

    func test_trimp_zone5Only() {
        let t = WorkloadCalculator.trimp(zoneDurationsMinutes: [0, 0, 0, 0, 10])
        XCTAssertEqual(t, 50.0, accuracy: epsilon)
    }

    func test_trimp_allZones() {
        // weights: [1.0, 1.5, 2.0, 3.0, 5.0] × 10 = 125
        let t = WorkloadCalculator.trimp(zoneDurationsMinutes: [10, 10, 10, 10, 10])
        XCTAssertEqual(t, 125.0, accuracy: epsilon)
    }

    func test_trimp_allZeros() {
        let t = WorkloadCalculator.trimp(zoneDurationsMinutes: [0, 0, 0, 0, 0])
        XCTAssertEqual(t, 0)
    }

    // MARK: - hrZone

    func test_hrZone_zone1() {
        XCTAssertEqual(WorkloadCalculator.hrZone(heartRate: 110, maxHR: 200), 1)
    }

    func test_hrZone_zone2() {
        XCTAssertEqual(WorkloadCalculator.hrZone(heartRate: 130, maxHR: 200), 2)
    }

    func test_hrZone_zone3() {
        XCTAssertEqual(WorkloadCalculator.hrZone(heartRate: 150, maxHR: 200), 3)
    }

    func test_hrZone_zone4() {
        XCTAssertEqual(WorkloadCalculator.hrZone(heartRate: 170, maxHR: 200), 4)
    }

    func test_hrZone_zone5() {
        XCTAssertEqual(WorkloadCalculator.hrZone(heartRate: 190, maxHR: 200), 5)
    }

    func test_hrZone_boundary60pct() {
        // Exactly 60% → zone 2 (boundary belongs to upper zone)
        XCTAssertEqual(WorkloadCalculator.hrZone(heartRate: 120, maxHR: 200), 2)
    }

    func test_hrZone_boundary90pct() {
        // Exactly 90% → zone 5 (boundary belongs to upper zone)
        XCTAssertEqual(WorkloadCalculator.hrZone(heartRate: 180, maxHR: 200), 5)
    }

    // MARK: - efficiencyIndex

    func test_efficiencyIndex_normal() {
        let ei = WorkloadCalculator.efficiencyIndex(externalLoad: 100, internalLoad: 50)
        XCTAssertNotNil(ei)
        XCTAssertEqual(ei!, 2.0, accuracy: epsilon)
    }

    func test_efficiencyIndex_zeroInternal() {
        let ei = WorkloadCalculator.efficiencyIndex(externalLoad: 100, internalLoad: 0)
        XCTAssertNil(ei)
    }

    func test_efficiencyIndex_zeroExternal() {
        let ei = WorkloadCalculator.efficiencyIndex(externalLoad: 0, internalLoad: 50)
        XCTAssertEqual(ei, 0)
    }

    // MARK: - stepEWMA

    func test_stepEWMA_fromZeroWithZeroTSS() {
        let result = WorkloadCalculator.stepEWMA(previousATL: 0, previousCTL: 0, todayTSS: 0)
        XCTAssertEqual(result.atl, 0)
        XCTAssertEqual(result.ctl, 0)
        XCTAssertEqual(result.acwr, 0)
        XCTAssertEqual(result.tsb, 0)
    }

    func test_stepEWMA_fromZeroWithTSS100_atlCtl() {
        let result = WorkloadCalculator.stepEWMA(previousATL: 0, previousCTL: 0, todayTSS: 100)
        XCTAssertEqual(result.atl, 100.0 / 7.0, accuracy: epsilon)
        XCTAssertEqual(result.ctl, 100.0 / 28.0, accuracy: epsilon)
    }

    func test_stepEWMA_fromZeroWithTSS100_acwr() {
        let result = WorkloadCalculator.stepEWMA(previousATL: 0, previousCTL: 0, todayTSS: 100)
        XCTAssertEqual(result.acwr, 4.0, accuracy: epsilon)
    }

    func test_stepEWMA_fromZeroWithTSS100_tsbNegative() {
        let result = WorkloadCalculator.stepEWMA(previousATL: 0, previousCTL: 0, todayTSS: 100)
        XCTAssertLessThan(result.tsb, 0)
    }

    func test_stepEWMA_equalLoadMaintainsACWR() {
        let result = WorkloadCalculator.stepEWMA(previousATL: 50, previousCTL: 50, todayTSS: 50)
        XCTAssertEqual(result.acwr, 1.0, accuracy: epsilon)
    }

    func test_stepEWMA_atlDecaysFasterThanCtl() {
        let atlStart = 80.0
        let ctlStart = 80.0
        let result = WorkloadCalculator.stepEWMA(previousATL: atlStart, previousCTL: ctlStart, todayTSS: 0)
        XCTAssertLessThan(result.atl, result.ctl)
        XCTAssertEqual(result.atl, atlStart * (6.0 / 7.0), accuracy: epsilon)
        XCTAssertEqual(result.ctl, ctlStart * (27.0 / 28.0), accuracy: epsilon)
    }

    func test_stepEWMA_tsbDefinition() {
        let result = WorkloadCalculator.stepEWMA(previousATL: 60, previousCTL: 80, todayTSS: 50)
        XCTAssertEqual(result.tsb, result.ctl - result.atl, accuracy: epsilon)
    }

    // MARK: - computeHistoryEWMA

    private func makeDailyLoads(tss: Double, days: Int, startingFrom base: Date = .now) -> [WorkloadCalculator.DailyLoad] {
        (0..<days).map { i in
            let date = Calendar.current.date(byAdding: .day, value: i, to: base)!
            return WorkloadCalculator.DailyLoad(date: date, tss: tss)
        }
    }

    func test_computeHistoryEWMA_emptyInput() {
        let results = WorkloadCalculator.computeHistoryEWMA(loads: [])
        XCTAssertTrue(results.isEmpty)
    }

    func test_computeHistoryEWMA_singleRestDay() {
        let loads = [WorkloadCalculator.DailyLoad(date: .now, tss: 0)]
        let results = WorkloadCalculator.computeHistoryEWMA(loads: loads)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].atl, 0)
        XCTAssertEqual(results[0].ctl, 0)
        XCTAssertEqual(results[0].acwr, 0)
    }

    func test_computeHistoryEWMA_singleDay() {
        let loads = [WorkloadCalculator.DailyLoad(date: .now, tss: 100)]
        let results = WorkloadCalculator.computeHistoryEWMA(loads: loads)
        XCTAssertEqual(results[0].atl, 100.0 / 7.0, accuracy: epsilon)
        XCTAssertEqual(results[0].ctl, 100.0 / 28.0, accuracy: epsilon)
    }

    func test_computeHistoryEWMA_outputCountMatchesInput() {
        let loads = makeDailyLoads(tss: 50, days: 14)
        let results = WorkloadCalculator.computeHistoryEWMA(loads: loads)
        XCTAssertEqual(results.count, 14)
    }

    func test_computeHistoryEWMA_convergence() {
        let tss = 80.0
        let loads = makeDailyLoads(tss: tss, days: 60)
        let results = WorkloadCalculator.computeHistoryEWMA(loads: loads)
        XCTAssertGreaterThan(results.last!.atl, tss * 0.9)
        XCTAssertGreaterThan(results.last!.ctl, tss * 0.8)
    }

    func test_computeHistoryEWMA_restAfterTraining_positiveTSB() {
        var loads = makeDailyLoads(tss: 100, days: 14)
        let baseDate = Calendar.current.date(byAdding: .day, value: 14, to: .now)!
        loads += makeDailyLoads(tss: 0, days: 7, startingFrom: baseDate)
        let results = WorkloadCalculator.computeHistoryEWMA(loads: loads)
        let last = results.last!
        XCTAssertGreaterThan(last.tsb, 0)
        XCTAssertLessThan(last.atl, last.ctl)
    }

    func test_computeHistoryEWMA_noDivisionByZero() {
        let loads = makeDailyLoads(tss: 0, days: 10)
        let results = WorkloadCalculator.computeHistoryEWMA(loads: loads)
        for result in results {
            XCTAssertEqual(result.acwr, 0)
        }
    }

    func test_computeHistoryEWMA_highACWR() {
        var loads = makeDailyLoads(tss: 50, days: 28)
        let spikeBase = Calendar.current.date(byAdding: .day, value: 28, to: .now)!
        loads += makeDailyLoads(tss: 200, days: 7, startingFrom: spikeBase)
        let results = WorkloadCalculator.computeHistoryEWMA(loads: loads)
        XCTAssertGreaterThan(results.last!.acwr, 1.0)
    }

    // MARK: - computeRollingACWR

    func test_rollingACWR_emptyInput() {
        let result = WorkloadCalculator.computeRollingACWR(dailyLoads: [])
        XCTAssertEqual(result.acwr, 0)
    }

    func test_rollingACWR_constantSevenDays() {
        let loads = Array(repeating: 50.0, count: 7)
        let result = WorkloadCalculator.computeRollingACWR(dailyLoads: loads)
        XCTAssertEqual(result.acwr, 1.0, accuracy: epsilon)
    }

    func test_rollingACWR_constantTwentyEightDays() {
        let loads = Array(repeating: 80.0, count: 28)
        let result = WorkloadCalculator.computeRollingACWR(dailyLoads: loads)
        XCTAssertEqual(result.acwr, 1.0, accuracy: epsilon)
    }

    func test_rollingACWR_spike() {
        let base = Array(repeating: 50.0, count: 21)
        let spike = Array(repeating: 150.0, count: 7)
        let result = WorkloadCalculator.computeRollingACWR(dailyLoads: base + spike)
        XCTAssertGreaterThan(result.acwr, 1.0)
    }

    func test_rollingACWR_tsbDefinition() {
        let loads = Array(repeating: 60.0, count: 14)
        let result = WorkloadCalculator.computeRollingACWR(dailyLoads: loads)
        XCTAssertEqual(result.tsb, result.ctl - result.atl, accuracy: epsilon)
    }

    // MARK: - Session Spike Detection

    func test_spikeDetection_moderateSpike() {
        // Average TSS = 3.0, session = 5.0 → ratio ≈ 1.67 → moderate
        let recent = [2.0, 3.0, 4.0, 3.0, 3.0]
        let result = WorkloadCalculator.detectSessionSpike(sessionTSS: 5.0, recentSessionTSSValues: recent)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.ratio, 5.0 / 3.0, accuracy: epsilon)
        XCTAssertEqual(result!.averageTSS, 3.0, accuracy: epsilon)
        XCTAssertEqual(result!.sessionTSS, 5.0, accuracy: epsilon)
        switch result!.severity {
        case .moderate: break // expected
        case .high: XCTFail("Expected moderate severity")
        }
    }

    func test_spikeDetection_highSpike() {
        // Average TSS = 2.0, session = 5.0 → ratio = 2.5 → high
        let recent = [1.0, 2.0, 3.0, 2.0]
        let result = WorkloadCalculator.detectSessionSpike(sessionTSS: 5.0, recentSessionTSSValues: recent)
        XCTAssertNotNil(result)
        XCTAssertGreaterThanOrEqual(result!.ratio, 2.0)
        switch result!.severity {
        case .high: break // expected
        case .moderate: XCTFail("Expected high severity")
        }
    }

    func test_spikeDetection_noSpikeBelowThreshold() {
        // Average TSS = 3.0, session = 4.0 → ratio ≈ 1.33 → below 1.5x threshold
        let recent = [2.0, 3.0, 4.0, 3.0]
        let result = WorkloadCalculator.detectSessionSpike(sessionTSS: 4.0, recentSessionTSSValues: recent)
        XCTAssertNil(result)
    }

    func test_spikeDetection_insufficientData_fewerThan3Sessions() {
        let recent = [3.0, 4.0]  // Only 2 prior sessions
        let result = WorkloadCalculator.detectSessionSpike(sessionTSS: 20.0, recentSessionTSSValues: recent)
        XCTAssertNil(result)
    }

    func test_spikeDetection_insufficientData_noSessions() {
        let result = WorkloadCalculator.detectSessionSpike(sessionTSS: 10.0, recentSessionTSSValues: [])
        XCTAssertNil(result)
    }

    func test_spikeDetection_zeroSessionTSS() {
        let recent = [3.0, 4.0, 5.0]
        let result = WorkloadCalculator.detectSessionSpike(sessionTSS: 0, recentSessionTSSValues: recent)
        XCTAssertNil(result)
    }

    func test_spikeDetection_exactlyAtThreshold() {
        // Average = 2.0, session = 3.0 → ratio = 1.5 → exactly at threshold → spike
        let recent = [1.0, 2.0, 3.0]
        let result = WorkloadCalculator.detectSessionSpike(sessionTSS: 3.0, recentSessionTSSValues: recent)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.ratio, 1.5, accuracy: epsilon)
    }
}
