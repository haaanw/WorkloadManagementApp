import XCTest
@testable import workload_management

/// Phase 20 Plan 02 — FatigueIndexEngine luteal dampening (D-10) cycle overload tests.
final class FatigueIndexEngineCycleTests: XCTestCase {

    /// Input with a declining recovery trend so the recoveryTrend component is well above
    /// neutral (0.5) — making the dampening effect observable.
    private func decliningInput() -> FatigueIndexEngine.FatigueInput {
        FatigueIndexEngine.FatigueInput(
            recentSessionTSS: [120, 130, 140, 150],
            baselineSessionTSS: 100,
            sessionsIn14Days: 10,
            baselineSessionsIn14Days: 7,
            trainingStreakDays: 6,
            daysSinceRestPeriod: 12,
            recentRecoveryScores: [80, 72, 64, 56, 48],  // steep decline → high recoveryTrend fatigue
            recentWellnessScores: [70, 68, 66, 64, 62],
            softTissueInjuryCount: 0,
            daysSinceLastInjury: nil
        )
    }

    private func luteal() -> CycleContext {
        CycleContext(
            phase: .lateLuteal, confidence: 0.8, cycleDay: 24, cycleLength: 28,
            isOnHormonalContraceptive: false, isPregnant: false, isLactating: false
        )
    }

    private func follicular() -> CycleContext {
        CycleContext(
            phase: .lateFollicular, confidence: 0.8, cycleDay: 10, cycleLength: 28,
            isOnHormonalContraceptive: false, isPregnant: false, isLactating: false
        )
    }

    /// D-12: nil context identical to base compute(input:).
    func test_nilContext_identicalToBase() {
        let inp = decliningInput()
        let base = FatigueIndexEngine.compute(input: inp)
        let cycle = FatigueIndexEngine.compute(input: inp, cycleContext: nil, cyclesObserved: 5)
        XCTAssertEqual(base.index, cycle.index, accuracy: 0.0001)
        XCTAssertEqual(base.recoveryTrend, cycle.recoveryTrend, accuracy: 0.0001)
    }

    /// D-10: would-be dampened index is LOWER than base in luteal with a declining trend
    /// (dampening pulls the elevated recoveryTrend component toward neutral).
    func test_lutealWouldDampen_lowersIndex() {
        let inp = decliningInput()
        let baseIndex = FatigueIndexEngine.compute(input: inp).index
        let damped = FatigueIndexEngine.lutealDampenedIndex(input: inp, cycleContext: luteal())
        XCTAssertLessThan(damped, baseIndex)
    }

    /// Non-luteal (follicular) → would-be dampened index equals base (phase contributes nothing).
    func test_follicular_wouldNotDampen() {
        let inp = decliningInput()
        let baseIndex = FatigueIndexEngine.compute(input: inp).index
        let damped = FatigueIndexEngine.lutealDampenedIndex(input: inp, cycleContext: follicular())
        XCTAssertEqual(damped, baseIndex, accuracy: 0.0001)
    }

    /// D-06: returned index is UNCHANGED this phase (activation off), even in luteal.
    func test_lutealReturnedIndexUnchanged_activationOff() {
        let inp = decliningInput()
        let base = FatigueIndexEngine.compute(input: inp)
        let cycle = FatigueIndexEngine.compute(input: inp, cycleContext: luteal(), cyclesObserved: 5)
        XCTAssertEqual(base.index, cycle.index, accuracy: 0.0001)
    }
}
