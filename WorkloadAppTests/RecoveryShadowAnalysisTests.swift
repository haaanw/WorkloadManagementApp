import XCTest
import SwiftData
@testable import workload_management

/// The divergence report — what the shadow rows can honestly answer today: not "which arm is
/// right" (that needs a leak-free outcome we do not have), but "how far apart are they, and
/// where would a swap actually change a decision".
@MainActor
final class RecoveryShadowAnalysisTests: XCTestCase {

    private func makeRow(v1: Double, v2: Double?, dayOffset: Int) -> RecoveryShadowDay {
        let day = Calendar.current.date(
            byAdding: .day, value: dayOffset, to: Calendar.current.startOfDay(for: Date())
        )!
        return RecoveryShadowDay(date: day, v1BaseScore: v1, v2BaseScore: v2)
    }

    func test_noRows_reportsNothingRatherThanZero() {
        let result = RecoveryShadowAnalysis.divergence(rows: [])
        XCTAssertEqual(result.pairedDayCount, 0)
        XCTAssertNil(result.meanAbsoluteDifference)
        XCTAssertNil(result.rankCorrelation)
    }

    func test_daysTheEstimatorDeclinedToScore_areNotCountedAsAgreement() {
        // A day v2 had no opinion on is not evidence the arms agree.
        let rows = [
            makeRow(v1: 70, v2: nil, dayOffset: -2),
            makeRow(v1: 65, v2: nil, dayOffset: -1),
            makeRow(v1: 60, v2: 58, dayOffset: 0)
        ]
        let result = RecoveryShadowAnalysis.divergence(rows: rows)
        XCTAssertEqual(result.recordedDayCount, 3)
        XCTAssertEqual(result.pairedDayCount, 1, "only the scored day is comparable")
    }

    func test_identicalArms_reportZeroDivergence() {
        let rows = (0..<5).map { makeRow(v1: 60 + Double($0), v2: 60 + Double($0), dayOffset: -$0) }
        let result = RecoveryShadowAnalysis.divergence(rows: rows)
        XCTAssertEqual(result.meanAbsoluteDifference ?? -1, 0, accuracy: 0.0001)
        XCTAssertEqual(result.maxAbsoluteDifference ?? -1, 0, accuracy: 0.0001)
        XCTAssertEqual(result.zoneDisagreementCount, 0)
    }

    func test_signedDifferenceShowsWhichArmReadsHigher() {
        let rows = [
            makeRow(v1: 60, v2: 65, dayOffset: -1),
            makeRow(v1: 70, v2: 75, dayOffset: 0)
        ]
        let result = RecoveryShadowAnalysis.divergence(rows: rows)
        XCTAssertEqual(result.meanSignedDifference ?? 0, 5, accuracy: 0.0001)
        XCTAssertEqual(result.meanAbsoluteDifference ?? 0, 5, accuracy: 0.0001)
    }

    func test_offsetButPerfectlyRankedArms_readAsHighAgreementWithALevelShift() {
        // The safe shape: the arms ORDER the days identically and merely sit at different
        // levels. Very different from disagreeing about which days were good.
        let rows = (0..<6).map { makeRow(v1: 50 + Double($0) * 5, v2: 58 + Double($0) * 5, dayOffset: -$0) }
        let result = RecoveryShadowAnalysis.divergence(rows: rows)
        XCTAssertEqual(result.meanSignedDifference ?? 0, 8, accuracy: 0.0001)
        XCTAssertEqual(result.rankCorrelation ?? 0, 1.0, accuracy: 0.0001)
    }

    func test_zoneDisagreementCountsOnlyDecisionChangingDays() {
        // 30 vs 40 crosses red→yellow (the boundary is 34) and would change a recommendation;
        // 80 vs 85 is a bigger raw gap that changes nothing.
        let rows = [
            makeRow(v1: 30, v2: 40, dayOffset: -1),
            makeRow(v1: 80, v2: 85, dayOffset: 0)
        ]
        let result = RecoveryShadowAnalysis.divergence(rows: rows)
        XCTAssertEqual(result.zoneDisagreementCount, 1)
    }

    func test_maxDifferenceSurfacesTheWorstDay() {
        let rows = [
            makeRow(v1: 60, v2: 62, dayOffset: -2),
            makeRow(v1: 60, v2: 85, dayOffset: -1),
            makeRow(v1: 60, v2: 58, dayOffset: 0)
        ]
        let result = RecoveryShadowAnalysis.divergence(rows: rows)
        XCTAssertEqual(result.maxAbsoluteDifference ?? 0, 25, accuracy: 0.0001)
    }

    func test_analysisNeverMutatesTheGate() throws {
        // Report, never decide — the CrossModalShadowGate discipline, enforced at source level.
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("WorkloadApp/Services/RecoveryShadowAnalysis.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        XCTAssertFalse(source.contains("withEnabled"))
        XCTAssertFalse(source.contains("isEnabled ="))
    }
}
