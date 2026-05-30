import XCTest
@testable import workload_management

/// Phase 28 Wave 1 (28-01) — pure `ReadinessFusionEngine` guard battery.
///
/// Covers: oracle vs hand-computed logistic, sign-constraint monotonicity, zone boundaries,
/// confidence decomposition (confidence reported separately, never folded into the scalar),
/// missing-signal weight renormalization (no mean-imputation), and the PRSActivation default.
final class ReadinessFusionEngineTests: XCTestCase {

    private let tol = 1e-6

    // MARK: - Oracle (fixed coefficients → known logistic output)

    func test_oracle_allCoreSignals_matchesHandComputedLogistic() {
        // logit = b0(0) + 0.9·hrvZ + 0.7·sleepZ + 0.6·rhrZ
        //       = 0.9·1.0 + 0.7·0.5 + 0.6·(-0.5) = 0.9 + 0.35 - 0.30 = 0.95
        // readiness = 100 · logistic(0.95)
        let input = ReadinessFusionEngine.ReadinessInput(
            hrvZ: 1.0, rhrZ: -0.5, sleepZ: 0.5, subjectiveTrendSlope: nil, confidence: 0.8
        )
        let result = ReadinessFusionEngine.compute(input)

        let expectedLogit = 0.95
        let expected = 100.0 * (1.0 / (1.0 + exp(-expectedLogit)))
        XCTAssertEqual(result.readiness, expected, accuracy: 1e-6)
        XCTAssertFalse(result.missingSignals)
    }

    func test_oracle_allBaseline_isFifty() {
        // Every z == 0 ⇒ logit = b0 = 0 ⇒ logistic(0) = 0.5 ⇒ Readiness 50.
        let input = ReadinessFusionEngine.ReadinessInput(hrvZ: 0, rhrZ: 0, sleepZ: 0)
        let result = ReadinessFusionEngine.compute(input)
        XCTAssertEqual(result.readiness, 50.0, accuracy: 1e-9)
        XCTAssertEqual(result.zone, .moderate)
    }

    func test_logistic_isStableForLargeMagnitudes() {
        XCTAssertEqual(ReadinessFusionEngine.logistic(50), 1.0, accuracy: 1e-9)
        XCTAssertEqual(ReadinessFusionEngine.logistic(-50), 0.0, accuracy: 1e-9)
        XCTAssertEqual(ReadinessFusionEngine.logistic(0), 0.5, accuracy: 1e-12)
    }

    // MARK: - Sign constraint (monotonicity)

    func test_signConstraint_increasingHRVZ_neverDecreasesReadiness() {
        var prev = -Double.infinity
        for hrv in stride(from: -3.0, through: 3.0, by: 0.25) {
            let r = ReadinessFusionEngine.compute(
                .init(hrvZ: hrv, rhrZ: 0, sleepZ: 0)
            ).readiness
            XCTAssertGreaterThanOrEqual(r, prev - 1e-12, "HRV z=\(hrv) decreased Readiness")
            prev = r
        }
    }

    func test_signConstraint_increasingSleepZ_neverDecreasesReadiness() {
        var prev = -Double.infinity
        for s in stride(from: -3.0, through: 3.0, by: 0.25) {
            let r = ReadinessFusionEngine.compute(.init(hrvZ: 0, rhrZ: 0, sleepZ: s)).readiness
            XCTAssertGreaterThanOrEqual(r, prev - 1e-12)
            prev = r
        }
    }

    func test_signConstraint_worseRHR_lowersReadiness() {
        // RHR z is "+z = better" (BaselineEngine already inverted raw RHR). A WORSE raw reading is a
        // NEGATIVE z, which must LOWER Readiness vs a neutral z.
        let neutral = ReadinessFusionEngine.compute(.init(hrvZ: 0, rhrZ: 0, sleepZ: 0)).readiness
        let worse = ReadinessFusionEngine.compute(.init(hrvZ: 0, rhrZ: -1.0, sleepZ: 0)).readiness
        XCTAssertLessThan(worse, neutral)
    }

    // MARK: - Zone boundaries

    func test_zoneBoundaries_areInclusiveAsDocumented() {
        // < 40 ⇒ low; [40,65) ⇒ moderate; >= 65 ⇒ high.
        XCTAssertEqual(ReadinessFusionEngine.zone(for: 39.999), .low)
        XCTAssertEqual(ReadinessFusionEngine.zone(for: 40.0), .moderate)
        XCTAssertEqual(ReadinessFusionEngine.zone(for: 64.999), .moderate)
        XCTAssertEqual(ReadinessFusionEngine.zone(for: 65.0), .high)
        XCTAssertEqual(ReadinessFusionEngine.zone(for: 100.0), .high)
        XCTAssertEqual(ReadinessFusionEngine.zone(for: 0.0), .low)
    }

    // MARK: - Confidence is decomposable (separate, not folded into the scalar)

    func test_confidence_isReportedSeparately_doesNotChangeScalar() {
        let low = ReadinessFusionEngine.compute(.init(hrvZ: 1.0, rhrZ: 0, sleepZ: 0, confidence: 0.1))
        let high = ReadinessFusionEngine.compute(.init(hrvZ: 1.0, rhrZ: 0, sleepZ: 0, confidence: 0.95))
        XCTAssertEqual(low.readiness, high.readiness, accuracy: tol,
                       "Confidence must NOT scale the Readiness number")
        XCTAssertEqual(low.confidence, 0.1, accuracy: tol)
        XCTAssertEqual(high.confidence, 0.95, accuracy: tol)
    }

    func test_confidence_isClampedTo01() {
        XCTAssertEqual(ReadinessFusionEngine.compute(.init(hrvZ: 0, rhrZ: 0, sleepZ: 0, confidence: 5)).confidence, 1.0, accuracy: tol)
        XCTAssertEqual(ReadinessFusionEngine.compute(.init(hrvZ: 0, rhrZ: 0, sleepZ: 0, confidence: -2)).confidence, 0.0, accuracy: tol)
    }

    // MARK: - Missing-signal renormalization (no mean-imputation)

    func test_missingSignal_excludedAndRenormalized_notImputed() {
        // Only HRV present, z = 1.0. Renormalized core weight = coreReference (2.2) since presentCore
        // = 0.9 ⇒ normWeight = 0.9 / 0.9 * 2.2 = 2.2. logit = 2.2 ⇒ readiness = 100·logistic(2.2).
        let result = ReadinessFusionEngine.compute(.init(hrvZ: 1.0, rhrZ: nil, sleepZ: nil))
        let expected = 100.0 * (1.0 / (1.0 + exp(-2.2)))
        XCTAssertEqual(result.readiness, expected, accuracy: 1e-6)
        XCTAssertTrue(result.missingSignals)
        XCTAssertEqual(result.factors.count, 1)
        XCTAssertEqual(result.factors.first?.label, "Heart Rate Variability")
    }

    func test_missingSignal_aPresentSignalAtZeroBaselineGivesFifty() {
        // HRV missing, sleep+RHR present at z=0 ⇒ logit 0 ⇒ Readiness 50, missing flag set.
        let result = ReadinessFusionEngine.compute(.init(hrvZ: nil, rhrZ: 0, sleepZ: 0))
        XCTAssertEqual(result.readiness, 50.0, accuracy: 1e-9)
        XCTAssertTrue(result.missingSignals)
    }

    func test_allCoreSignalsMissing_doesNotCrash_returnsBaseline() {
        let result = ReadinessFusionEngine.compute(.init(hrvZ: nil, rhrZ: nil, sleepZ: nil))
        XCTAssertEqual(result.readiness, 50.0, accuracy: 1e-9) // logit stays at intercept 0
        XCTAssertTrue(result.missingSignals)
        XCTAssertTrue(result.factors.isEmpty)
    }

    // MARK: - Ranked factors decompose to the logit

    func test_factors_sumToLogitMinusIntercept() {
        let input = ReadinessFusionEngine.ReadinessInput(hrvZ: 1.0, rhrZ: -0.5, sleepZ: 0.5)
        let result = ReadinessFusionEngine.compute(input)
        let logitFromFactors = result.factors.reduce(0.0) { $0 + $1.contribution }
        // Reconstruct readiness from the decomposed contributions + intercept.
        let reconstructed = 100.0 * ReadinessFusionEngine.logistic(
            ReadinessFusionEngine.Constants.intercept + logitFromFactors
        )
        XCTAssertEqual(reconstructed, result.readiness, accuracy: 1e-6)
    }

    func test_factors_rankedByAbsoluteContribution() {
        let result = ReadinessFusionEngine.compute(.init(hrvZ: 0.2, rhrZ: 0.0, sleepZ: 2.0))
        // Sleep contribution (0.7·2.0=1.4) > HRV (0.9·0.2=0.18) > RHR (0).
        XCTAssertEqual(result.factors.first?.label, "Sleep")
    }

    // MARK: - PRSActivation default

    func test_PRSActivation_defaultsFalse() {
        XCTAssertFalse(PRSActivation.isEnabled)
    }

    func test_PRSActivation_overrideRestoresPriorState() {
        XCTAssertFalse(PRSActivation.isEnabled)
        PRSActivation.withEnabled(true) {
            XCTAssertTrue(PRSActivation.isEnabled)
        }
        XCTAssertFalse(PRSActivation.isEnabled)
    }

    // MARK: - ReadinessZone enum hygiene

    func test_readinessZone_hasThreeCases_withDisplayNames() {
        XCTAssertEqual(ReadinessZone.allCases.count, 3)
        for zone in ReadinessZone.allCases {
            XCTAssertFalse(zone.displayName.isEmpty)
            XCTAssertFalse(zone.systemImage.isEmpty)
        }
    }

    func test_readinessZone_copyNeverImpliesInjuryPrediction() {
        let forbidden = ["injury prediction", "injury risk", "predicts injury", "will get injured"]
        for zone in ReadinessZone.allCases {
            let lower = zone.displayName.lowercased()
            for phrase in forbidden {
                XCTAssertFalse(lower.contains(phrase), "ReadinessZone copy contains '\(phrase)'")
            }
        }
    }
}
