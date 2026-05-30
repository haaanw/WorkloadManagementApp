import XCTest
import SwiftData
@testable import workload_management

/// Phase 30 Wave 4 (30-04) — NON-fence coverage for `PRSDualRunSurface.adjust` Finding 6
/// (GA-30-F): a flag-ON first-time `PrescribedWorkout` with `targetVolume == nil` must APPLY the
/// volume modifier to a derived effective base instead of silently discarding it, and any mutation
/// must bump `updatedAt`. The flag-OFF no-op and the existing-targetVolume flag-ON path stay
/// byte-identical (those invariants live in DualRunFlagFenceTests, which is NOT touched).
@MainActor
final class PRSDualRunSurfaceTests: XCTestCase {

    // MARK: - Builders

    /// A first-time prescription with `targetVolume` left nil (the real default — initializer
    /// never sets it). No template exercises → derivedBaseVolume falls back to the neutral 1.0.
    private func makeNilVolumeWorkout() -> PrescribedWorkout {
        PrescribedWorkout(
            coachId: UUID(), athleteId: UUID(),
            scheduledDate: Date(), templateName: "First-time"
        )
    }

    /// A prescription whose frozen template snapshot has working sets, so derivedBaseVolume can
    /// derive a non-neutral base (Σ target reps over non-warmup sets).
    private func makeTemplateBackedWorkout(reps: [Int]) -> PrescribedWorkout {
        let w = PrescribedWorkout(
            coachId: UUID(), athleteId: UUID(),
            scheduledDate: Date(), templateName: "Template-backed"
        )
        let group = ExerciseGroup(groupName: "A", orderIndex: 0)
        let exercise = TemplateExercise(exerciseName: "Back Squat", muscleGroup: .quads, orderIndex: 0)
        exercise.sets = reps.enumerated().map { idx, r in
            TemplateSet(setIndex: idx, targetReps: r, isWarmup: false)
        }
        group.exercises = [exercise]
        w.groups = [group]
        return w
    }

    private func rec(intensityCap: Double, volumeModifier: Double) -> AutoregulationEngine.TrainingRecommendation {
        AutoregulationEngine.TrainingRecommendation(
            intensityCap: intensityCap, volumeModifier: volumeModifier, sessionType: .activeRecovery,
            warnings: [], headline: "Light Day", detail: "Updated."
        )
    }

    // MARK: - Flag OFF: nil-volume no-op (fence invariant, re-checked here)

    func test_flagOff_nilVolume_noOp() {
        XCTAssertFalse(PRSActivation.isEnabled, "precondition: flag defaults false")
        let w = makeNilVolumeWorkout()
        let beforeUpdatedAt = w.updatedAt
        let result = PRSDualRunSurface.adjust(prescribedWorkout: w, with: rec(intensityCap: 6, volumeModifier: 0.5))
        XCTAssertNil(result, "adjust must return nil with flag off")
        XCTAssertNil(w.targetVolume, "targetVolume must stay nil with flag off")
        XCTAssertNil(w.targetRPE, "targetRPE must stay nil with flag off")
        XCTAssertEqual(w.updatedAt, beforeUpdatedAt, "updatedAt must NOT bump with flag off")
    }

    // MARK: - Flag ON: nil-volume now applies the modifier (Finding 6 fix)

    func test_flagOn_nilVolume_appliesModifierToDerivedBase() {
        // No template → neutral base 1.0; modifier 0.5 → 0.5 (NOT nil / discarded).
        let w = makeNilVolumeWorkout()
        let result = PRSActivation.withEnabled(true) {
            PRSDualRunSurface.adjust(prescribedWorkout: w, with: rec(intensityCap: 6, volumeModifier: 0.5))
        }
        XCTAssertNotNil(result)
        XCTAssertEqual(w.targetVolume, 0.5)
        XCTAssertEqual(result?.newTargetVolume, 0.5)
    }

    func test_flagOn_nilVolume_derivesFromTemplate() {
        // Working sets 5 + 5 + 3 reps → base 13; modifier 0.5 → 6.5.
        let w = makeTemplateBackedWorkout(reps: [5, 5, 3])
        XCTAssertEqual(PRSDualRunSurface.derivedBaseVolume(w), 13.0, accuracy: 1e-9)
        let result = PRSActivation.withEnabled(true) {
            PRSDualRunSurface.adjust(prescribedWorkout: w, with: rec(intensityCap: 6, volumeModifier: 0.5))
        }
        XCTAssertEqual(w.targetVolume, 6.5)
        XCTAssertEqual(result?.newTargetVolume, 6.5)
    }

    func test_flagOn_nilVolume_restModifierZero() {
        // A rest recommendation (modifier 0.0) → 0.0 (a real rest signal, not nil/discarded).
        let w = makeNilVolumeWorkout()
        let result = PRSActivation.withEnabled(true) {
            PRSDualRunSurface.adjust(prescribedWorkout: w, with: rec(intensityCap: 5, volumeModifier: 0.0))
        }
        XCTAssertEqual(w.targetVolume, 0.0)
        XCTAssertEqual(result?.newTargetVolume, 0.0)
    }

    // MARK: - Flag ON: existing-targetVolume path byte-identical to legacy

    func test_flagOn_existingVolume_byteIdentical() {
        let w = makeNilVolumeWorkout()
        w.targetVolume = 100.0
        w.targetRPE = 9.0
        let result = PRSActivation.withEnabled(true) {
            PRSDualRunSurface.adjust(prescribedWorkout: w, with: rec(intensityCap: 6, volumeModifier: 0.5))
        }
        // 100 * 0.5 = 50 (matches the legacy existing-volume behavior).
        XCTAssertEqual(w.targetVolume, 50.0)
        XCTAssertEqual(result?.newTargetVolume, 50.0)
        XCTAssertEqual(w.targetRPE, 6.0) // capped downward 9 -> 6
    }

    // MARK: - updatedAt bump (deterministic via injected now)

    func test_flagOn_anyMutation_bumpsUpdatedAt() {
        let w = makeNilVolumeWorkout()
        let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertNotEqual(w.updatedAt, fixedNow, "precondition: updatedAt differs from the injected now")
        _ = PRSActivation.withEnabled(true) {
            PRSDualRunSurface.adjust(prescribedWorkout: w, with: rec(intensityCap: 6, volumeModifier: 0.5), now: fixedNow)
        }
        XCTAssertEqual(w.updatedAt, fixedNow, "updatedAt must bump to the injected now on mutation")
    }

    // MARK: - derivedBaseVolume fallbacks

    func test_derivedBaseVolume_neutralFallbackWhenNoWorkingSets() {
        let w = makeNilVolumeWorkout() // no groups/exercises
        XCTAssertEqual(PRSDualRunSurface.derivedBaseVolume(w), 1.0, accuracy: 1e-9)
    }

    func test_derivedBaseVolume_setCountWhenNoReps() {
        // Two working sets with no targetReps → base = working-set count (2).
        let w = PrescribedWorkout(coachId: UUID(), athleteId: UUID(), scheduledDate: Date(), templateName: "NoReps")
        let group = ExerciseGroup(groupName: "A", orderIndex: 0)
        let exercise = TemplateExercise(exerciseName: "Plank", orderIndex: 0)
        exercise.sets = [
            TemplateSet(setIndex: 0, targetDurationSeconds: 60, isWarmup: false),
            TemplateSet(setIndex: 1, targetDurationSeconds: 60, isWarmup: false),
            TemplateSet(setIndex: 2, isWarmup: true) // warmup excluded
        ]
        group.exercises = [exercise]
        w.groups = [group]
        XCTAssertEqual(PRSDualRunSurface.derivedBaseVolume(w), 2.0, accuracy: 1e-9)
    }
}
