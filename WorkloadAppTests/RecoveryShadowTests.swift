import XCTest
import SwiftData
@testable import workload_management

/// The v2 recovery arm and its shadow record. The arm must be honest about what it does not
/// know, must differ from v1 ONLY in the HRV/RHR estimator, and must never reach the live path.
final class RecoveryShadowTests: XCTestCase {

    // MARK: - The arm holds its opinion until it has earned one

    func test_evaluate_withNoPriorHistory_producesNoComponent() {
        // BaselineEngine returns a nil z below its cold-start gate, and v2 propagates that
        // rather than inventing a number.
        let outcome = RecoveryShadowEngine.evaluate(today: 55, priorDays: [], config: .hrv)
        XCTAssertNil(outcome.z)
        XCTAssertNil(outcome.component)
    }

    func test_evaluate_withNoReadingToday_producesNoComponent() {
        let priors = Array(repeating: 50.0, count: 20)
        let outcome = RecoveryShadowEngine.evaluate(today: nil, priorDays: priors, config: .hrv)
        XCTAssertNil(outcome.component)
        XCTAssertNotNil(outcome.mu, "the baseline still exists even when today has no reading")
    }

    func test_evaluate_neutralReadingScoresTheSameNeutralAsV1() {
        // A reading exactly at the personal baseline must score 70 — v1's ratio-1.0 value.
        // Holding the anchor fixed is what makes the divergence attributable to the estimator.
        let priors = Array(repeating: 50.0, count: 20)
        let outcome = RecoveryShadowEngine.evaluate(today: 50, priorDays: priors, config: .hrv)
        guard let component = outcome.component else {
            return XCTFail("expected a component with 20 prior days")
        }
        XCTAssertEqual(component, RecoveryShadowEngine.neutralScore, accuracy: 0.5)
    }

    func test_evaluate_higherHRVScoresAboveNeutral_lowerBelow() {
        let priors: [Double] = (0..<20).map { _ in 50.0 } + [46, 54, 48, 52]
        let high = RecoveryShadowEngine.evaluate(today: 70, priorDays: priors, config: .hrv)
        let low = RecoveryShadowEngine.evaluate(today: 32, priorDays: priors, config: .hrv)
        guard let highComponent = high.component, let lowComponent = low.component else {
            return XCTFail("expected components")
        }
        XCTAssertGreaterThan(highComponent, RecoveryShadowEngine.neutralScore)
        XCTAssertLessThan(lowComponent, RecoveryShadowEngine.neutralScore)
    }

    func test_evaluate_restingHRSignIsInverted_lowerIsBetter() {
        // A LOWER resting heart rate is a better state, so its z must come out positive.
        let priors: [Double] = (0..<20).map { _ in 55.0 } + [53, 57, 54, 56]
        let outcome = RecoveryShadowEngine.evaluate(today: 48, priorDays: priors, config: .rhr)
        guard let z = outcome.z, let component = outcome.component else {
            return XCTFail("expected a scored RHR")
        }
        XCTAssertGreaterThan(z, 0, "a low resting HR must read as better, not worse")
        XCTAssertGreaterThan(component, RecoveryShadowEngine.neutralScore)
    }

    // MARK: - Composite

    func test_composite_isNilWhenNeitherPhysiologicalArmScored() {
        // With only sleep and wellness left, v2 is contributing nothing to test.
        let score = RecoveryShadowEngine.compositeScore(
            hrvComponent: nil, rhrComponent: nil,
            sleepComponent: 80, wellnessComponent: 60
        )
        XCTAssertNil(score)
    }

    func test_composite_renormalizesOverPresentComponents() {
        // HRV alone present ⇒ the composite is that component, not a diluted version of it.
        let score = RecoveryShadowEngine.compositeScore(
            hrvComponent: 90, rhrComponent: nil,
            sleepComponent: nil, wellnessComponent: nil
        )
        XCTAssertEqual(score ?? 0, 90, accuracy: 0.001)
    }

    func test_composite_weightsMatchTheLiveEngineExactly() {
        // The two arms must differ ONLY in how HRV/RHR are derived.
        XCTAssertEqual(RecoveryShadowEngine.Weights.hrv, 0.30)
        XCTAssertEqual(RecoveryShadowEngine.Weights.rhr, 0.20)
        XCTAssertEqual(RecoveryShadowEngine.Weights.sleep, 0.25)
        XCTAssertEqual(RecoveryShadowEngine.Weights.wellness, 0.25)
    }

    func test_composite_isClampedToTheScoreRange() {
        let score = RecoveryShadowEngine.compositeScore(
            hrvComponent: 100, rhrComponent: 100,
            sleepComponent: 100, wellnessComponent: 100
        )
        XCTAssertEqual(score ?? 0, 100, accuracy: 0.001)
    }

    // MARK: - Sync fence

    func test_syncFence_recoveryShadowDayAbsentFromSyncService() throws {
        // Local-only by omission, like SleepShadowNight / VerdictEvent / BaselineState. If the
        // type name ever appears in SyncService, someone has started uploading it.
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // WorkloadAppTests
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("WorkloadApp/Services/SyncService.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        XCTAssertFalse(
            source.contains("RecoveryShadowDay"),
            "RecoveryShadowDay must never be synced — it is device-local shadow evidence"
        )
    }

    func test_shadowArmIsNeverConsultedByTheLiveEngine() throws {
        // The live score must not read the shadow arm back. Guards against the failure mode
        // where a "shadow" quietly starts driving the number.
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("WorkloadApp/Services/RecoveryScoreEngine.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        XCTAssertFalse(source.contains("RecoveryShadowEngine"))
        XCTAssertFalse(source.contains("RecoveryShadowDay"))
    }
}
