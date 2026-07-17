import Foundation

/// Phase 28, Wave 4 — the FLAGGED dual-run "method updated" surface + real-workout adjustment.
///
/// Pure, deterministic, Foundation-only. ALL behavior here is gated by `PRSActivation.isEnabled`
/// (GA-6/GA-8): with the flag OFF (the default) every entry point returns `nil` / a no-op, so the
/// live UI and any real planned/logged workout are BYTE-UNCHANGED. With the flag ON it produces the
/// dual-run messaging payload and applies the new recommendation to a REAL workout.
///
/// This is the load-bearing, testable core of Wave 4; the SwiftUI treatment (`PRSDualRunCard`) is a
/// thin renderer over `DualRunMessage` and is FLAGGED for human visual review (visuals NOT final).
///
/// Copy is "Tuwa"-only and NEVER says "injury prediction" (GA-11, grep-guarded). It honors the
/// honest "method updated" transition framing (research §289) — it shows BOTH the legacy and the new
/// recommendation during the dual-run window so the change is transparent.
enum PRSDualRunSurface {

    /// The dual-run messaging payload (only produced when the flag is ON).
    struct DualRunMessage: Equatable {
        /// Short "method updated" headline.
        let title: String
        /// One-line explanation that the recommendation method changed.
        let explanation: String
        /// The PREVIOUS (legacy recovery×ACWR) recommendation headline, shown side-by-side.
        let previousHeadline: String
        /// The NEW (readiness×strain-risk) recommendation headline.
        let updatedHeadline: String
    }

    /// Build the dual-run message, or `nil` when the flag is OFF (default → nothing renders).
    static func dualRunMessage(
        legacy: AutoregulationEngine.TrainingRecommendation,
        updated: AutoregulationEngine.TrainingRecommendation
    ) -> DualRunMessage? {
        guard VerdictSurfaceActivation.isEnabled || PRSActivation.isEnabled else { return nil }
        return DualRunMessage(
            title: String(localized: "prs.dualRun.title", defaultValue: "Guidance method updated"),
            explanation: String(localized: "prs.dualRun.explanation",
                defaultValue: "Tuwa now reads your daily readiness and accumulated training strain together. During this transition we show both your previous and updated guidance."),
            previousHeadline: legacy.headline,
            updatedHeadline: updated.headline
        )
    }

    /// The result of adjusting a real planned/logged workout (only when the flag is ON).
    struct WorkoutAdjustment: Equatable {
        let newTargetRPE: Double
        let newTargetVolume: Double?
    }

    /// Apply the (flag-on) recommendation to a REAL `PrescribedWorkout` (GA-9): cap the target RPE
    /// at the recommendation's `intensityCap` and scale the target volume by `volumeModifier`. With
    /// the flag OFF this returns `nil` and MUST NOT mutate anything (caller no-ops). With the flag ON
    /// it MUTATES the supplied workout in place AND returns the applied adjustment for display.
    ///
    /// Does NOT fabricate a workout — the caller passes a workout that actually exists for the day
    /// (else the next logged-session context). RPE is only ever capped DOWNWARD (never raised above
    /// an existing lower target).
    @discardableResult
    static func adjust(
        prescribedWorkout workout: PrescribedWorkout,
        with recommendation: AutoregulationEngine.TrainingRecommendation,
        now: Date = .now
    ) -> WorkoutAdjustment? {
        // KEEP FIRST — with BOTH flags OFF this returns nil and mutates NOTHING (DualRunFlagFence
        // no-op stays byte-identical: false-OR-false ⇒ nil). Everything below runs flag-ON only.
        guard VerdictSurfaceActivation.isEnabled || PRSActivation.isEnabled else { return nil }

        // RPE: cap downward at the recommendation's intensity cap.
        let cappedRPE: Double
        if let existing = workout.targetRPE {
            cappedRPE = Swift.min(existing, recommendation.intensityCap)
        } else {
            cappedRPE = recommendation.intensityCap
        }

        // Volume (Finding 6 / GA-30-F): a normal first-time PrescribedWorkout has
        // `targetVolume == nil` (the initializer / sync-pull never populate it). Previously the
        // else branch set newVolume = nil, silently DISCARDING a 50%-volume / rest recommendation.
        // Now: when there is no existing target, derive an effective base from the prescription's
        // template so the modifier is applied, not lost. The modifier is exact for an existing
        // target (byte-identical to before) and yields a real reduction (or 0.0 rest) when derived.
        let effectiveBase = workout.targetVolume ?? derivedBaseVolume(workout)
        let newVolume = effectiveBase * recommendation.volumeModifier

        workout.targetRPE = cappedRPE
        workout.targetVolume = newVolume
        workout.updatedAt = now   // bump on any mutation (deterministic via injected `now`)
        return WorkoutAdjustment(newTargetRPE: cappedRPE, newTargetVolume: newVolume)
    }

    /// Derive an effective base volume for a prescription whose `targetVolume` is nil, from the
    /// frozen template snapshot (`allExercises` → `TemplateSet`s). Volume proxy = Σ target reps
    /// across NON-warmup sets; if no reps are specified, the count of non-warmup working sets; if
    /// nothing is derivable (empty / warmup-only template), a NEUTRAL base of 1.0 so the modifier
    /// becomes the fraction-of-full (e.g. 0.5 → 0.5, rest 0.0 → 0.0) instead of being discarded.
    static func derivedBaseVolume(_ workout: PrescribedWorkout) -> Double {
        var totalReps = 0
        var workingSetCount = 0
        for exercise in workout.allExercises {
            for set in exercise.sortedSets where !set.isWarmup {
                workingSetCount += 1
                if let reps = set.targetReps { totalReps += reps }
            }
        }
        if totalReps > 0 { return Double(totalReps) }
        if workingSetCount > 0 { return Double(workingSetCount) }
        return 1.0   // neutral base — modifier becomes the fraction of full
    }
}
