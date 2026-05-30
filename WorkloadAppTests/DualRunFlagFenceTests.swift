import XCTest
import SwiftData
@testable import workload_management

/// Phase 28 Wave 4 (28-04) — flag-fence for the dual-run surface + real-workout adjustment.
///
/// Proves: with `PRSActivation.isEnabled == false` (default) the dual-run message is ABSENT and the
/// real-workout adjustment is a NO-OP (the workout is byte-unchanged); with the flag ON the message
/// renders and the adjustment targets a REAL PrescribedWorkout (GA-9). Also re-asserts the
/// no-prediction-copy guard on the dual-run copy (GA-11).
@MainActor
final class DualRunFlagFenceTests: XCTestCase {

    private func makeWorkout() -> PrescribedWorkout {
        let w = PrescribedWorkout(
            coachId: UUID(), athleteId: UUID(),
            scheduledDate: Date(), templateName: "Test"
        )
        w.targetRPE = 9.0
        w.targetVolume = 100.0
        return w
    }

    private func legacyRec() -> AutoregulationEngine.TrainingRecommendation {
        AutoregulationEngine.TrainingRecommendation(
            intensityCap: 10, volumeModifier: 1.0, sessionType: .power,
            warnings: [], headline: "Go Zone", detail: "Legacy headline."
        )
    }

    private func updatedRec() -> AutoregulationEngine.TrainingRecommendation {
        AutoregulationEngine.TrainingRecommendation(
            intensityCap: 6, volumeModifier: 0.5, sessionType: .activeRecovery,
            warnings: [], headline: "Light Day", detail: "Updated headline."
        )
    }

    // MARK: - Flag OFF (default): nothing renders, nothing mutates

    func test_flagOff_dualRunMessage_isNil() {
        XCTAssertFalse(PRSActivation.isEnabled, "precondition: flag defaults false")
        let msg = PRSDualRunSurface.dualRunMessage(legacy: legacyRec(), updated: updatedRec())
        XCTAssertNil(msg, "no dual-run surface may render with flag off")
    }

    func test_flagOff_adjust_isNoOp_workoutByteUnchanged() {
        let w = makeWorkout()
        let beforeRPE = w.targetRPE
        let beforeVol = w.targetVolume
        let result = PRSDualRunSurface.adjust(prescribedWorkout: w, with: updatedRec())
        XCTAssertNil(result, "adjust must return nil with flag off")
        XCTAssertEqual(w.targetRPE, beforeRPE, "workout RPE must be unchanged with flag off")
        XCTAssertEqual(w.targetVolume, beforeVol, "workout volume must be unchanged with flag off")
    }

    // MARK: - Flag ON: message renders + adjusts a real workout

    func test_flagOn_dualRunMessage_showsBothRecommendations() {
        let msg = PRSActivation.withEnabled(true) {
            PRSDualRunSurface.dualRunMessage(legacy: legacyRec(), updated: updatedRec())
        }
        let m = try? XCTUnwrap(msg)
        XCTAssertNotNil(m)
        XCTAssertEqual(m?.previousHeadline, "Go Zone")
        XCTAssertEqual(m?.updatedHeadline, "Light Day")
        XCTAssertFalse(m?.title.isEmpty ?? true)
        XCTAssertFalse(m?.explanation.isEmpty ?? true)
    }

    func test_flagOn_adjust_mutatesRealWorkout_capsRPE_scalesVolume() {
        let w = makeWorkout() // targetRPE 9, targetVolume 100
        let result = PRSActivation.withEnabled(true) {
            PRSDualRunSurface.adjust(prescribedWorkout: w, with: updatedRec()) // cap 6, vol 0.5
        }
        let r = try? XCTUnwrap(result)
        XCTAssertNotNil(r)
        // RPE capped downward 9 -> 6.
        XCTAssertEqual(w.targetRPE, 6.0)
        XCTAssertEqual(r?.newTargetRPE, 6.0)
        // Volume scaled 100 * 0.5 = 50.
        XCTAssertEqual(w.targetVolume, 50.0)
        XCTAssertEqual(r?.newTargetVolume, 50.0)
    }

    func test_flagOn_adjust_neverRaisesRPEAboveExistingLowerTarget() {
        let w = makeWorkout()
        w.targetRPE = 5.0 // already lower than the recommendation cap of 6
        _ = PRSActivation.withEnabled(true) {
            PRSDualRunSurface.adjust(prescribedWorkout: w, with: updatedRec())
        }
        XCTAssertEqual(w.targetRPE, 5.0, "RPE is only capped downward, never raised")
    }

    // MARK: - No-prediction-copy guard (GA-11)

    func test_dualRunCopy_neverSaysInjuryPrediction() {
        let msg = PRSActivation.withEnabled(true) {
            PRSDualRunSurface.dualRunMessage(legacy: legacyRec(), updated: updatedRec())
        }
        guard let m = msg else { return XCTFail("expected message with flag on") }
        let blob = (m.title + " " + m.explanation + " " + m.previousHeadline + " " + m.updatedHeadline).lowercased()
        for phrase in ["injury prediction", "injury risk", "predicts injury", "will get injured"] {
            XCTAssertFalse(blob.contains(phrase), "dual-run copy contains '\(phrase)'")
        }
    }

    func test_dualRunCopy_usesTuwaNotDeadNames() {
        let msg = PRSActivation.withEnabled(true) {
            PRSDualRunSurface.dualRunMessage(legacy: legacyRec(), updated: updatedRec())
        }
        guard let m = msg else { return XCTFail("expected message with flag on") }
        let blob = (m.title + " " + m.explanation).lowercased()
        for dead in ["faros", "tonus", "tutrice"] {
            XCTAssertFalse(blob.contains(dead), "dual-run copy uses dead product name '\(dead)'")
        }
    }
}
