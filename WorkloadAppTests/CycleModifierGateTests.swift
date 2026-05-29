import XCTest
@testable import workload_management

/// Phase 20 Plan 02 — CycleModifierGate (D-05 five-part guard) + CycleModifierActivation (D-06).
final class CycleModifierGateTests: XCTestCase {

    private func ctx(
        phase: CyclePhase = .lateLuteal,
        confidence: Double = 0.8,
        oc: Bool = false,
        pregnant: Bool = false,
        lactating: Bool = false
    ) -> CycleContext {
        CycleContext(
            phase: phase, confidence: confidence, cycleDay: 24, cycleLength: 28,
            isOnHormonalContraceptive: oc, isPregnant: pregnant, isLactating: lactating
        )
    }

    // MARK: - All-pass

    func test_allConditionsPass_eligibleWithExplanation() {
        let e = CycleModifierGate.eligibility(context: ctx(), cyclesObserved: 3)
        XCTAssertTrue(e.isEligible)
        XCTAssertNotNil(e.explanation)
        XCTAssertFalse(e.explanation?.isEmpty ?? true)
    }

    // MARK: - Each condition independently gates

    func test_lowConfidence_ineligible() {
        XCTAssertFalse(CycleModifierGate.eligibility(context: ctx(confidence: 0.69), cyclesObserved: 5).isEligible)
    }

    func test_confidenceAtThreshold_eligible() {
        XCTAssertTrue(CycleModifierGate.eligibility(context: ctx(confidence: 0.7), cyclesObserved: 5).isEligible)
    }

    func test_exclusion_oc_ineligible() {
        XCTAssertFalse(CycleModifierGate.eligibility(context: ctx(oc: true), cyclesObserved: 5).isEligible)
    }

    func test_exclusion_pregnant_ineligible() {
        XCTAssertFalse(CycleModifierGate.eligibility(context: ctx(pregnant: true), cyclesObserved: 5).isEligible)
    }

    func test_exclusion_lactating_ineligible() {
        XCTAssertFalse(CycleModifierGate.eligibility(context: ctx(lactating: true), cyclesObserved: 5).isEligible)
    }

    func test_unknownPhase_ineligible() {
        XCTAssertFalse(CycleModifierGate.eligibility(context: ctx(phase: .unknown), cyclesObserved: 5).isEligible)
    }

    func test_fewerThan3Cycles_ineligible() {
        XCTAssertFalse(CycleModifierGate.eligibility(context: ctx(), cyclesObserved: 2).isEligible)
    }

    func test_exactly3Cycles_eligible() {
        XCTAssertTrue(CycleModifierGate.eligibility(context: ctx(), cyclesObserved: 3).isEligible)
    }

    func test_noneContext_ineligible() {
        let e = CycleModifierGate.eligibility(context: .none, cyclesObserved: 5)
        XCTAssertFalse(e.isEligible)
        XCTAssertNil(e.explanation)
    }

    // MARK: - shouldApply double-gate (D-06: activation false this phase)

    func test_activationIsOff_thisPhase() {
        XCTAssertFalse(CycleModifierActivation.isEnabled)
    }

    func test_shouldApply_falseWhenActivationOff_evenIfEligible() {
        // Eligible context, 5 cycles → eligible true, but activation off → shouldApply false.
        XCTAssertTrue(CycleModifierGate.eligibility(context: ctx(), cyclesObserved: 5).isEligible)
        XCTAssertFalse(CycleModifierGate.shouldApply(context: ctx(), cyclesObserved: 5))
    }

    func test_shouldApply_falseWhenIneligible() {
        XCTAssertFalse(CycleModifierGate.shouldApply(context: .none, cyclesObserved: 5))
    }
}
