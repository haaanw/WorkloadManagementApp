import XCTest
@testable import workload_management

/// Phase 24 Plan 02 — ShadowMetrics pure-function tests.
/// Worked examples for calibration slope, Spearman ρ (with ties), blocked/purged CV partitioning,
/// and the deterministic moving-block-bootstrap paired-MAE-difference CI.
final class ShadowMetricsTests: XCTestCase {

    // MARK: - Calibration slope

    func test_calibrationSlope_perfectlyCalibrated_isOne() {
        let pairs = [(predicted: 40.0, actual: 40.0), (50.0, 50.0), (60.0, 60.0), (70.0, 70.0)]
        XCTAssertEqual(ShadowMetrics.calibrationSlope(pairs: pairs)!, 1.0, accuracy: 1e-9)
    }

    func test_calibrationSlope_doubleActual_isTwo() {
        // actual == 2 * predicted (positive predictor variance) → slope 2.0.
        let pairs = [(predicted: 10.0, actual: 20.0), (20.0, 40.0), (30.0, 60.0)]
        XCTAssertEqual(ShadowMetrics.calibrationSlope(pairs: pairs)!, 2.0, accuracy: 1e-9)
    }

    func test_calibrationSlope_constantPredicted_isNil() {
        let pairs = [(predicted: 50.0, actual: 40.0), (50.0, 60.0), (50.0, 55.0)]
        XCTAssertNil(ShadowMetrics.calibrationSlope(pairs: pairs))  // var(predicted) == 0
    }

    func test_calibrationSlope_insufficient_isNil() {
        XCTAssertNil(ShadowMetrics.calibrationSlope(pairs: []))
        XCTAssertNil(ShadowMetrics.calibrationSlope(pairs: [(predicted: 1, actual: 2)]))
    }

    // MARK: - Spearman ρ

    func test_spearman_monotoneIncreasing_isOne() {
        let pairs = [(predicted: 1.0, actual: 10.0), (2.0, 20.0), (3.0, 25.0), (4.0, 100.0)]
        XCTAssertEqual(ShadowMetrics.spearmanRho(pairs: pairs)!, 1.0, accuracy: 1e-9)
    }

    func test_spearman_reversed_isMinusOne() {
        let pairs = [(predicted: 1.0, actual: 100.0), (2.0, 40.0), (3.0, 20.0), (4.0, 5.0)]
        XCTAssertEqual(ShadowMetrics.spearmanRho(pairs: pairs)!, -1.0, accuracy: 1e-9)
    }

    func test_spearman_tieHandling_averageRanks() {
        // predicted has a tie at the two largest values → average ranks; actual strictly increasing.
        // predicted [1,2,2,3] → ranks [1, 2.5, 2.5, 4]; actual [10,20,30,40] → ranks [1,2,3,4].
        // Pearson of those rank vectors is well-defined and < 1 (because of the tie mismatch).
        let pairs = [(predicted: 1.0, actual: 10.0), (2.0, 20.0), (2.0, 30.0), (3.0, 40.0)]
        let rho = ShadowMetrics.spearmanRho(pairs: pairs)!
        XCTAssertGreaterThan(rho, 0.9)
        XCTAssertLessThan(rho, 1.0)  // tie prevents a perfect 1.0
    }

    func test_spearman_insufficient_isNil() {
        XCTAssertNil(ShadowMetrics.spearmanRho(pairs: [(predicted: 1, actual: 2), (3, 4)]))  // n < 3
    }

    // MARK: - Blocked / purged CV splitter

    func test_blockedCV_partitionsIntoContiguousBlocks_withPurge() {
        let folds = ShadowMetrics.blockedCVSplits(count: 20, folds: 4, purge: 1)
        XCTAssertEqual(folds.count, 4)
        // Four contiguous 5-wide test blocks covering 0..<20.
        XCTAssertEqual(folds.map(\.test), [0..<5, 5..<10, 10..<15, 15..<20])

        // A middle block (5..<10): train excludes the block AND a 1-index purge gap on each side
        // → indices 4 and 10 are purged.
        let mid = folds[1]
        XCTAssertFalse(mid.train.contains(4), "lower purge gap excluded")
        XCTAssertFalse(mid.train.contains(10), "upper purge gap excluded")
        XCTAssertFalse(mid.train.contains(where: { (5..<10).contains($0) }), "test block excluded from train")
        XCTAssertTrue(mid.train.contains(3))
        XCTAssertTrue(mid.train.contains(11))
        // Train is time-ordered (ascending), no shuffle.
        XCTAssertEqual(mid.train, mid.train.sorted())
    }

    func test_blockedCV_degenerate_singleFullFold() {
        XCTAssertEqual(ShadowMetrics.blockedCVSplits(count: 10, folds: 1).map(\.test), [0..<10])
        // count < folds → single full-data fold.
        XCTAssertEqual(ShadowMetrics.blockedCVSplits(count: 3, folds: 5).map(\.test), [0..<3])
        XCTAssertTrue(ShadowMetrics.blockedCVSplits(count: 0, folds: 4).isEmpty)
    }

    // MARK: - Block-bootstrap paired-MAE-difference CI

    private func pairs(_ preds: [Double], _ actuals: [Double]) -> [(predicted: Double, actual: Double)] {
        zip(preds, actuals).map { (predicted: $0.0, actual: $0.1) }
    }

    func test_bootstrap_deterministicUnderSeed() {
        let a = pairs([10, 12, 14, 16, 18, 20, 22, 24], [10, 12, 14, 16, 18, 20, 22, 24])
        let b = pairs([11, 13, 15, 17, 19, 21, 23, 25], [10, 12, 14, 16, 18, 20, 22, 24])
        let ci1 = ShadowMetrics.pairedMAEDifferenceBlockBootstrapCI(
            armA: a, armB: b, blockLength: 2, resamples: 500, seed: 42)!
        let ci2 = ShadowMetrics.pairedMAEDifferenceBlockBootstrapCI(
            armA: a, armB: b, blockLength: 2, resamples: 500, seed: 42)!
        XCTAssertEqual(ci1.lower, ci2.lower, accuracy: 1e-12)
        XCTAssertEqual(ci1.upper, ci2.upper, accuracy: 1e-12)
        XCTAssertEqual(ci1.point, ci2.point, accuracy: 1e-12)
    }

    func test_bootstrap_uniformlyBetterArm_CIExcludesZero() {
        // armB error 0 everywhere; armA error 5 everywhere → d = errA - errB = 5 > 0 always.
        let actuals: [Double] = Array(repeating: 50, count: 12)
        let a = pairs(Array(repeating: 55, count: 12), actuals)  // |55-50| = 5
        let b = pairs(actuals, actuals)                          // 0
        let ci = ShadowMetrics.pairedMAEDifferenceBlockBootstrapCI(
            armA: a, armB: b, blockLength: 3, resamples: 800, seed: 7)!
        XCTAssertEqual(ci.point, 5.0, accuracy: 1e-9)
        XCTAssertGreaterThan(ci.lower, 0.0, "uniformly-better armB → CI for (errA-errB) strictly above 0")
    }

    func test_bootstrap_noise_CIStraddlesZero() {
        // Symmetric alternating advantage → mean difference ~0, CI straddles 0.
        let actuals: [Double] = Array(repeating: 50, count: 12)
        var aPred: [Double] = [], bPred: [Double] = []
        for i in 0..<12 {
            // Alternate which arm is closer by the same magnitude → d alternates +2 / -2.
            if i % 2 == 0 { aPred.append(52); bPred.append(50) }  // d = 2 - 0 = +2
            else          { aPred.append(50); bPred.append(52) }  // d = 0 - 2 = -2
        }
        let a = pairs(aPred, actuals)
        let b = pairs(bPred, actuals)
        let ci = ShadowMetrics.pairedMAEDifferenceBlockBootstrapCI(
            armA: a, armB: b, blockLength: 2, resamples: 800, seed: 99)!
        XCTAssertEqual(ci.point, 0.0, accuracy: 1e-9)
        XCTAssertLessThanOrEqual(ci.lower, 0.0)
        XCTAssertGreaterThanOrEqual(ci.upper, 0.0)
    }

    func test_bootstrap_insufficient_isNil() {
        let a = pairs([1, 2], [1, 2])
        let b = pairs([1, 2], [1, 2])
        XCTAssertNil(ShadowMetrics.pairedMAEDifferenceBlockBootstrapCI(
            armA: a, armB: b, blockLength: 5, resamples: 100, seed: 1))  // n < blockLength
        XCTAssertNil(ShadowMetrics.pairedMAEDifferenceBlockBootstrapCI(
            armA: pairs([1], [1]), armB: pairs([1], [1]), blockLength: 1, resamples: 100, seed: 1))  // n < 2
    }
}
