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
        guard PRSActivation.isEnabled else { return nil }
        return DualRunMessage(
            title: String(localized: "prs.dualRun.title", defaultValue: "Recommendation method updated"),
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
        with recommendation: AutoregulationEngine.TrainingRecommendation
    ) -> WorkoutAdjustment? {
        guard PRSActivation.isEnabled else { return nil }

        // RPE: cap downward at the recommendation's intensity cap.
        let cappedRPE: Double
        if let existing = workout.targetRPE {
            cappedRPE = Swift.min(existing, recommendation.intensityCap)
        } else {
            cappedRPE = recommendation.intensityCap
        }

        // Volume: scale the existing target by the recommendation's volume modifier (if present).
        let newVolume: Double?
        if let existing = workout.targetVolume {
            newVolume = existing * recommendation.volumeModifier
        } else {
            newVolume = nil
        }

        workout.targetRPE = cappedRPE
        workout.targetVolume = newVolume
        return WorkoutAdjustment(newTargetRPE: cappedRPE, newTargetVolume: newVolume)
    }
}
