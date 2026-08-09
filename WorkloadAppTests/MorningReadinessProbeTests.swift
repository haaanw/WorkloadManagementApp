import XCTest
import SwiftData
@testable import workload_management

/// The held-out outcome layer. Its whole value rests on two properties that are easy to lose
/// silently, so both are pinned here: nothing scored may read these measurements, and a
/// non-blinded answer must be distinguishable from a blinded one.
@MainActor
final class MorningReadinessProbeTests: XCTestCase {

    // MARK: - Blinding is recorded, not assumed

    func test_probe_defaultsToNotBlinded() {
        // Fail closed: an unstamped probe must not be mistaken for evidence.
        let probe = MorningReadinessProbe(date: Date())
        XCTAssertFalse(probe.wasBlinded)
    }

    func test_probe_recordsBlindingExplicitly() {
        let blinded = MorningReadinessProbe(date: Date(), perceivedReadiness: 7, wasBlinded: true)
        XCTAssertTrue(blinded.wasBlinded)
        XCTAssertEqual(blinded.perceivedReadiness, 7)
    }

    // MARK: - Grip

    func test_grip_isOptional_andAbsentByDefault() {
        // Equipment-bound, so absence is the normal case and must never look like a zero.
        let probe = MorningReadinessProbe(date: Date(), perceivedReadiness: 6)
        XCTAssertNil(probe.gripStrengthKg)
        XCTAssertNil(probe.gripHand)
        XCTAssertNil(probe.gripAttemptCount)
    }

    func test_grip_roundTripsHandAndAttempts() {
        // A series that silently switches hands is not one series, so the hand is stored.
        let probe = MorningReadinessProbe(
            date: Date(),
            gripStrengthKg: 48.5,
            gripHandRaw: MorningReadinessProbe.GripHand.left.rawValue,
            gripAttemptCount: 3
        )
        XCTAssertEqual(probe.gripStrengthKg, 48.5)
        XCTAssertEqual(probe.gripHand, .left)
        XCTAssertEqual(probe.gripAttemptCount, 3)
    }

    func test_readinessScale_isWiderThanTheWellnessRatings() {
        // Deliberately 1–10 while the four wellness INPUTS are 1–5: finer resolution for rank
        // correlation, and visibly not one of the ratings that feed the score.
        XCTAssertEqual(MorningReadinessProbe.readinessMin, 1)
        XCTAssertEqual(MorningReadinessProbe.readinessMax, 10)
    }

    // MARK: - The fences that keep an outcome an outcome

    func test_noScoringEngineReadsTheProbe() throws {
        // If a scoring engine ever consumes this, it stops being held-out evidence and the
        // whole comparison becomes circular.
        for file in [
            "WorkloadApp/Services/RecoveryScoreEngine.swift",
            "WorkloadApp/Services/RecoveryShadowEngine.swift",
            "WorkloadApp/Services/ReadinessFusionEngine.swift",
            "WorkloadApp/Services/BaselineEngine.swift",
        ] {
            let source = try readSource(file)
            XCTAssertFalse(
                source.contains("MorningReadinessProbe"),
                "OUTCOME FENCE BREACH: \(file) reads the held-out probe — an outcome that is also an input cannot grade what it feeds"
            )
            XCTAssertFalse(source.contains("outcomePerceivedReadiness"))
            XCTAssertFalse(source.contains("outcomeGripStrengthKg"))
        }
    }

    func test_respiratoryRateIsReadButNeverScored() throws {
        // Collected purely as evidence. The moment a score consumes it, it stops being usable
        // as an independent check.
        let healthKit = try readSource("WorkloadApp/Services/HealthKitService.swift")
        XCTAssertTrue(
            healthKit.contains("fetchOvernightRespiratoryRate"),
            "the outcome must actually be collected"
        )
        for file in [
            "WorkloadApp/Services/RecoveryScoreEngine.swift",
            "WorkloadApp/Services/RecoveryShadowEngine.swift",
        ] {
            XCTAssertFalse(try readSource(file).contains("espiratory"))
        }
    }

    func test_wristTemperatureIsStillUnscored() throws {
        // It was already collected and scored by nothing, which is exactly what qualifies it
        // as evidence. Guard against someone "improving" the score by adding it.
        for file in [
            "WorkloadApp/Services/RecoveryScoreEngine.swift",
            "WorkloadApp/Services/RecoveryShadowEngine.swift",
        ] {
            XCTAssertFalse(try readSource(file).contains("bodyTemp"))
            XCTAssertFalse(try readSource(file).contains("wristTemp"))
        }
    }

    // MARK: - Shadow record carries the evidence

    func test_shadowDay_storesOutcomesAlongsideBothArms() {
        let row = RecoveryShadowDay(
            date: Calendar.current.startOfDay(for: Date()),
            v1BaseScore: 62,
            v2BaseScore: 58,
            outcomeWristTempC: 34.6,
            outcomeRespiratoryRate: 14.2,
            outcomePerceivedReadiness: 4,
            outcomeGripStrengthKg: 47.0,
            outcomeGripHandRaw: "right",
            outcomeWasBlinded: true
        )
        XCTAssertEqual(row.outcomePerceivedReadiness, 4)
        XCTAssertEqual(row.outcomeGripStrengthKg, 47.0)
        XCTAssertEqual(row.outcomeRespiratoryRate ?? 0, 14.2, accuracy: 0.001)
        XCTAssertEqual(row.outcomeWristTempC ?? 0, 34.6, accuracy: 0.001)
        XCTAssertTrue(row.outcomeWasBlinded)
    }

    func test_shadowDay_outcomesDefaultToAbsentAndUnblinded() {
        let row = RecoveryShadowDay(date: Date(), v1BaseScore: 60)
        XCTAssertNil(row.outcomePerceivedReadiness)
        XCTAssertNil(row.outcomeGripStrengthKg)
        XCTAssertFalse(row.outcomeWasBlinded)
    }

    // MARK: - Helper

    private func readSource(_ relativePath: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
