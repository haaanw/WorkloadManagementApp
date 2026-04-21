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
}
