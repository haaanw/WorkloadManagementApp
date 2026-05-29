import XCTest
@testable import workload_management

final class AutoregulationEngineTests: XCTestCase {

    private func input(
        recovery: RecoveryZone,
        recoveryScore: Double = 70,
        acwr: ACWRZone,
        acwrValue: Double = 1.0,
        wellness: Double? = nil,
        daysSinceRest: Int = 0
    ) -> AutoregulationEngine.DailyInput {
        AutoregulationEngine.DailyInput(
            recoveryZone: recovery,
            recoveryScore: recoveryScore,
            acwrZone: acwr,
            acwr: acwrValue,
            wellnessScore: wellness,
            daysSinceLastRest: daysSinceRest
        )
    }

    // MARK: - 12 Decision Matrix Cells

    func test_greenOptimal_fullSend() {
        let rec = AutoregulationEngine.recommend(input: input(recovery: .green, acwr: .optimal))
        XCTAssertEqual(rec.sessionType, .power)
        XCTAssertEqual(rec.volumeModifier, 1.0)
        XCTAssertEqual(rec.intensityCap, 10.0)
    }

    func test_greenCaution_strength85pct() {
        let rec = AutoregulationEngine.recommend(input: input(recovery: .green, acwr: .caution))
        XCTAssertEqual(rec.sessionType, .strength)
        XCTAssertEqual(rec.volumeModifier, 0.85)
    }

    func test_greenDanger_conditioning75pct() {
        let rec = AutoregulationEngine.recommend(input: input(recovery: .green, acwr: .danger))
        XCTAssertEqual(rec.sessionType, .conditioning)
        XCTAssertEqual(rec.volumeModifier, 0.75)
        XCTAssertEqual(rec.intensityCap, 7.0)
    }

    func test_greenUndertrained_buildBase() {
        let rec = AutoregulationEngine.recommend(input: input(recovery: .green, acwr: .undertrained))
        XCTAssertEqual(rec.sessionType, .strength)
        XCTAssertEqual(rec.volumeModifier, 1.0)
    }

    func test_yellowOptimal_hypertrophy75pct() {
        let rec = AutoregulationEngine.recommend(input: input(recovery: .yellow, acwr: .optimal))
        XCTAssertEqual(rec.sessionType, .hypertrophy)
        XCTAssertEqual(rec.volumeModifier, 0.75)
    }

    func test_yellowCaution_conditioning75pct() {
        let rec = AutoregulationEngine.recommend(input: input(recovery: .yellow, acwr: .caution))
        XCTAssertEqual(rec.sessionType, .conditioning)
        XCTAssertEqual(rec.volumeModifier, 0.75)
    }

    func test_yellowDanger_activeRecovery() {
        let rec = AutoregulationEngine.recommend(input: input(recovery: .yellow, acwr: .danger))
        XCTAssertEqual(rec.sessionType, .activeRecovery)
        XCTAssertEqual(rec.volumeModifier, 0.5)
    }

    func test_yellowUndertrained_gradualBuild() {
        let rec = AutoregulationEngine.recommend(input: input(recovery: .yellow, acwr: .undertrained))
        XCTAssertEqual(rec.sessionType, .strength)
        XCTAssertEqual(rec.volumeModifier, 1.0)
        XCTAssertEqual(rec.intensityCap, 8.0)
    }

    func test_redOptimal_activeRecoveryOnly() {
        let rec = AutoregulationEngine.recommend(input: input(recovery: .red, acwr: .optimal))
        XCTAssertEqual(rec.sessionType, .activeRecovery)
        XCTAssertEqual(rec.volumeModifier, 0.5)
        XCTAssertEqual(rec.intensityCap, 5.0)
    }

    func test_redCaution_fullRest() {
        let rec = AutoregulationEngine.recommend(input: input(recovery: .red, acwr: .caution))
        XCTAssertEqual(rec.sessionType, .rest)
        XCTAssertEqual(rec.volumeModifier, 0.0)
    }

    func test_redDanger_fullRest() {
        let rec = AutoregulationEngine.recommend(input: input(recovery: .red, acwr: .danger))
        XCTAssertEqual(rec.sessionType, .rest)
        XCTAssertEqual(rec.volumeModifier, 0.0)
    }

    func test_redUndertrained_activeRecovery() {
        let rec = AutoregulationEngine.recommend(input: input(recovery: .red, acwr: .undertrained))
        XCTAssertEqual(rec.sessionType, .activeRecovery)
    }

    // MARK: - Warning conditions

    func test_acwrDanger_warningPresent() {
        let rec = AutoregulationEngine.recommend(input: input(recovery: .green, acwr: .danger, acwrValue: 1.8))
        let hasWarning = rec.warnings.contains { if case .acwrDanger = $0 { return true }; return false }
        XCTAssertTrue(hasWarning)
    }

    func test_acwrCaution_warningPresent() {
        let rec = AutoregulationEngine.recommend(input: input(recovery: .green, acwr: .caution, acwrValue: 1.4))
        let hasWarning = rec.warnings.contains { if case .acwrCaution = $0 { return true }; return false }
        XCTAssertTrue(hasWarning)
    }

    func test_redRecovery_warningPresent() {
        let rec = AutoregulationEngine.recommend(input: input(recovery: .red, acwr: .optimal))
        let hasWarning = rec.warnings.contains { if case .recoveryRed = $0 { return true }; return false }
        XCTAssertTrue(hasWarning)
    }

    func test_fiveConsecutiveDays_streakWarning() {
        let rec = AutoregulationEngine.recommend(input: input(recovery: .green, acwr: .optimal, daysSinceRest: 5))
        let hasWarning = rec.warnings.contains { if case .consecutiveTrainingDays = $0 { return true }; return false }
        XCTAssertTrue(hasWarning)
    }

    func test_fourConsecutiveDays_noStreakWarning() {
        let rec = AutoregulationEngine.recommend(input: input(recovery: .green, acwr: .optimal, daysSinceRest: 4))
        let hasWarning = rec.warnings.contains { if case .consecutiveTrainingDays = $0 { return true }; return false }
        XCTAssertFalse(hasWarning)
    }

    func test_lowWellness_warningPresent() {
        let rec = AutoregulationEngine.recommend(input: input(recovery: .green, acwr: .optimal, wellness: 30))
        let hasWarning = rec.warnings.contains { if case .lowWellness = $0 { return true }; return false }
        XCTAssertTrue(hasWarning)
    }

    func test_wellnessAbove40_noLowWellnessWarning() {
        let rec = AutoregulationEngine.recommend(input: input(recovery: .green, acwr: .optimal, wellness: 50))
        let hasWarning = rec.warnings.contains { if case .lowWellness = $0 { return true }; return false }
        XCTAssertFalse(hasWarning)
    }

    // MARK: - Consecutive days override

    func test_sevenDays_nonGreenRecovery_overrideToRest() {
        let rec = AutoregulationEngine.recommend(input: input(recovery: .yellow, acwr: .optimal, daysSinceRest: 7))
        XCTAssertEqual(rec.sessionType, .rest)
    }

    func test_sevenDays_greenRecovery_noOverride() {
        let rec = AutoregulationEngine.recommend(input: input(recovery: .green, acwr: .optimal, daysSinceRest: 7))
        XCTAssertEqual(rec.sessionType, .power)
    }

    // MARK: - Phase 20: cycle soft volume modifier (D-07/D-08/D-09)

    private func luteal(confidence: Double = 0.8) -> CycleContext {
        CycleContext(
            phase: .lateLuteal, confidence: confidence, cycleDay: 24, cycleLength: 28,
            isOnHormonalContraceptive: false, isPregnant: false, isLactating: false
        )
    }

    /// D-12: nil context is byte-identical to the base recommend(input:) across representative cells.
    func test_nilContext_identicalToBase() {
        let cells: [(RecoveryZone, ACWRZone)] = [
            (.green, .optimal), (.green, .danger), (.yellow, .optimal),
            (.yellow, .caution), (.yellow, .danger), (.red, .optimal), (.red, .danger)
        ]
        for (rz, az) in cells {
            let inp = input(recovery: rz, acwr: az)
            let base = AutoregulationEngine.recommend(input: inp)
            let cycle = AutoregulationEngine.recommend(input: inp, cycleContext: nil, cyclesObserved: 5)
            XCTAssertEqual(base.volumeModifier, cycle.volumeModifier, accuracy: 0.0001)
            XCTAssertEqual(base.intensityCap, cycle.intensityCap, accuracy: 0.0001)
            XCTAssertEqual(base.sessionType, cycle.sessionType)
        }
    }

    /// Criterion 2: never in green zone.
    func test_greenLuteal_factorIsOne() {
        let inp = input(recovery: .green, recoveryScore: 85, acwr: .optimal)
        XCTAssertEqual(AutoregulationEngine.cycleVolumeFactor(input: inp, cycleContext: luteal()), 1.0, accuracy: 0.0001)
    }

    /// Criterion 2: never in red zone; rest/activeRecovery preserved.
    func test_redLuteal_factorIsOne_andRestPreserved() {
        let inp = input(recovery: .red, recoveryScore: 25, acwr: .danger)
        XCTAssertEqual(AutoregulationEngine.cycleVolumeFactor(input: inp, cycleContext: luteal()), 1.0, accuracy: 0.0001)
        let rec = AutoregulationEngine.recommend(input: inp, cycleContext: luteal(), cyclesObserved: 5)
        XCTAssertEqual(rec.sessionType, .rest)
        XCTAssertEqual(rec.volumeModifier, 0.0, accuracy: 0.0001)
    }

    /// D-07/D-08: yellow + luteal + corroborating low signal → factor in [0.85, 1.0).
    func test_yellowLuteal_lowSignal_factorInRange() {
        let inp = input(recovery: .yellow, recoveryScore: 45, acwr: .optimal, wellness: 30)
        let factor = AutoregulationEngine.cycleVolumeFactor(input: inp, cycleContext: luteal())
        XCTAssertGreaterThanOrEqual(factor, 0.85)
        XCTAssertLessThan(factor, 1.0)
    }

    /// D-06: even with a would-be reduction, returned volume is UNCHANGED (activation off).
    func test_yellowLuteal_lowSignal_returnedVolumeUnchanged_activationOff() {
        let inp = input(recovery: .yellow, recoveryScore: 45, acwr: .optimal, wellness: 30)
        let base = AutoregulationEngine.recommend(input: inp)
        let cycle = AutoregulationEngine.recommend(input: inp, cycleContext: luteal(), cyclesObserved: 5)
        XCTAssertEqual(base.volumeModifier, cycle.volumeModifier, accuracy: 0.0001)
    }

    /// D-09: yellow + luteal + normal recovery/wellness + no soreness → no reduction (phase alone).
    func test_yellowLuteal_noCorroboration_factorIsOne() {
        let inp = input(recovery: .yellow, recoveryScore: 68, acwr: .optimal, wellness: 80)
        XCTAssertEqual(AutoregulationEngine.cycleVolumeFactor(input: inp, cycleContext: luteal()), 1.0, accuracy: 0.0001)
    }

    /// Phase contributes direction only: follicular bucket never reduces.
    func test_yellowFollicular_factorIsOne() {
        let follicular = CycleContext(
            phase: .lateFollicular, confidence: 0.8, cycleDay: 10, cycleLength: 28,
            isOnHormonalContraceptive: false, isPregnant: false, isLactating: false
        )
        let inp = input(recovery: .yellow, recoveryScore: 45, acwr: .optimal, wellness: 30)
        XCTAssertEqual(AutoregulationEngine.cycleVolumeFactor(input: inp, cycleContext: follicular), 1.0, accuracy: 0.0001)
    }
}
