import Foundation

/// Phase 43 Plan 01 (VERDICT-01 / VERDICT-02) — the pure **TODAY verdict CORE**.
///
/// Collapses the EXISTING `AutoregulationEngine.TrainingRecommendation` (already produced by the
/// Phase-41-activated readiness × strain-risk pipeline) into a **go / modify / hold** trichotomy
/// (VERDICT-01) and computes a concrete, evidence-bounded, plate-rounded **adjusted top-set number /
/// back-off volume cut** (VERDICT-02). It is a DERIVED engine — a pure function of the recommendation,
/// NEVER a new decision model. It does NOT call `recommendReadiness`; it RECEIVES a recommendation.
///
/// ## Pure / Foundation-only / dateless-by-injection
/// Static methods only, no stored state, no `Date.now` / `Calendar.current` (mirrors the
/// `AutoregulationEngine` / `CrossModalFatigueEngine` convention). Same input → identical output.
///
/// ## The bounds (LOCKED — research §2.2/§2.3/§3.1)
/// - LOAD cut is bounded to **−5% default / −10% ceiling** (`Constants.defaultLoadTrim` /
///   `Constants.maxLoadTrim`). No path can over-trim: `loadFactor` is hard-clamped to
///   `≥ (1 − maxLoadTrim)`.
/// - **Volume-cut is PREFERRED over load-cut**: when the recommendation is only mildly down, the
///   top-set load is kept and a back-off set is cut instead (`volumeCutSets`).
/// - The adjusted weight is rounded to a loadable plate step via `WeightFormatter.snapToIncrement`
///   and is **never rounded UP past the planned weight** when trimming (the guardrail). The only
///   number out is a plate-snapped kg weight — NEVER a fractional percent.
/// - A sub-increment delta collapses to **GO** (no false-precision micro-change).
/// - **HOLD carries the number** (planned top set held, no progression) — never a nil / "don't train"
///   (the nocebo guard).
///
/// ## Cross-modal stays gate-controlled (this ship = ZERO effect)
/// Cross-modal is read THROUGH `CrossModalShadowGate.crossModalDrivesVerdict` (default FALSE). While
/// the gate is off OR the `CrossModalResult` is nil, cross-modal multiplies by EXACTLY 1.0 —
/// contributing zero to the number. Flipping the gate later lights up the existing wiring with no
/// re-architecture. (The gate-off-identical test machine-enforces the zero-influence default.)
///
/// ## Honesty
/// This engine emits no user-facing copy at all (the reason string is assembled separately by
/// `VerdictReasonBuilder`); it never frames a trim as harm-forecasting. Source-grep fenced.
struct TodayVerdictEngine {

    // MARK: - Public types

    /// The TODAY verdict trichotomy (VERDICT-01).
    enum Verdict {
        /// Train the plan as written.
        case go
        /// Trim the number and/or cut a back-off set (a bounded adjustment).
        case modify
        /// The recommendation calls for rest / active recovery — hold the planned number, no progression.
        case hold
    }

    /// The planned top set the verdict adjusts. `plannedTopSetKg` is in kg (storage unit).
    struct PlannedTopSet {
        let exerciseName: String
        let region: MuscleRegion
        let plannedTopSetKg: Double
        let plannedReps: Int?
        let plannedRPE: Double?
    }

    /// The verdict CORE output. `adjustedTopSetKg` is a plate-snapped kg weight; `volumeCutSets`
    /// is nil when no back-off cut applies; `loadFactor` is the applied multiplier in `[0.90, 1.00]`.
    struct VerdictResult: Equatable {
        let verdict: Verdict
        let adjustedTopSetKg: Double
        let volumeCutSets: Int?
        let loadFactor: Double
    }

    // MARK: - Tunable constants (the SINGLE home — mirrors CrossModalFatigueEngine.Constants)

    enum Constants {
        /// Default LOAD trim magnitude (−5%). Applied at the modify boundary (mildly clearly-down).
        static let defaultLoadTrim: Double = 0.05
        /// Maximum LOAD trim magnitude (−10% ceiling). `loadFactor` is hard-clamped to `≥ 1 − maxLoadTrim`.
        static let maxLoadTrim: Double = 0.10
        /// Loadable plate step (kg). The adjusted weight is always a multiple of this.
        static let plateStepKg: Double = 2.5

        /// volumeModifier at/above this ⇒ no reduction (GO candidate).
        static let goVolumeThreshold: Double = 0.95
        /// volumeModifier in `[volumeCutFloor, goVolumeThreshold)` ⇒ volume-cut-preferred (keep top set).
        static let volumeCutFloor: Double = 0.85
        /// Number of back-off sets a full reduction (volumeModifier → volumeCutFloor) implies.
        static let backoffSetsAtFullCut: Double = 3.0
    }

    // MARK: - Evaluate

    /// Derive the verdict + adjusted number for one planned top set from an EXISTING recommendation.
    ///
    /// - Parameters:
    ///   - recommendation: the already-produced `TrainingRecommendation` (the SOLE decision input).
    ///   - plannedTopSet: today's planned top set (weight in kg).
    ///   - crossModalResult: optional cross-modal carry — applied ONLY when the shadow gate is on
    ///     (zero effect at the shipped default).
    ///   - plateStepKg: loadable plate step in kg (default `Constants.plateStepKg`).
    static func evaluate(
        recommendation: AutoregulationEngine.TrainingRecommendation,
        plannedTopSet: PlannedTopSet,
        crossModalResult: CrossModalFatigueEngine.CrossModalResult?,
        plateStepKg: Double = Constants.plateStepKg
    ) -> VerdictResult {
        let planned = plannedTopSet.plannedTopSetKg
        let vol = recommendation.volumeModifier
        let sessionType = recommendation.sessionType
        let isRestLike = sessionType == .rest || sessionType == .activeRecovery

        // --- HOLD path: rest / active recovery → hold the planned number, no progression. ----------
        // HOLD is "the number" (planned top set held), never a nil / "don't train" (nocebo guard).
        if isRestLike {
            return VerdictResult(
                verdict: .hold,
                adjustedTopSetKg: planned,
                volumeCutSets: nil,
                loadFactor: 1.0
            )
        }

        // --- Derive loadFactor + the volume-cut decision from the recommendation. ------------------
        var loadFactor = 1.0
        var volumeCutSets: Int? = nil

        if vol >= Constants.goVolumeThreshold {
            // Candidate GO: full intensity / volume.
            loadFactor = 1.0
        } else if vol >= Constants.volumeCutFloor {
            // VOLUME-CUT-PREFERRED: keep the top-set load, cut a back-off set instead (research §2.1
            // bottom-line — "keep the top set, cut a back-off set"). loadFactor stays 1.0.
            loadFactor = 1.0
            // Round the implied back-off cut; at minimum 1 when below the GO threshold.
            let raw = (1.0 - vol) / (1.0 - Constants.volumeCutFloor) * Constants.backoffSetsAtFullCut
            volumeCutSets = Swift.max(1, Int(raw.rounded()))
        } else {
            // Clearly down → LOAD trim. Interpolate the trim between the default (−5%, at the
            // volumeCutFloor boundary) and the ceiling (−10%, at volumeModifier 0). NEVER below
            // `1 − maxLoadTrim` (the −10% bound — hard clamp).
            let belowFloor = (Constants.volumeCutFloor - vol) / Constants.volumeCutFloor  // 0…1
            let trim = Constants.defaultLoadTrim
                + (Constants.maxLoadTrim - Constants.defaultLoadTrim) * Swift.max(0, Swift.min(1, belowFloor))
            loadFactor = Swift.max(1.0 - Constants.maxLoadTrim, 1.0 - trim)
        }

        // --- Cross-modal as a multiplicative factor on loadFactor — GATE-GUARDED. ------------------
        // Applied ONLY when `crossModalDrivesVerdict == true` AND a result is present. Off OR nil ⇒
        // multiply by exactly 1.0 (cross-modal contributes ZERO this ship — the locked default).
        var effectiveFactor = loadFactor
        if CrossModalShadowGate.crossModalDrivesVerdict, let cross = crossModalResult {
            effectiveFactor = loadFactor * cross.exerciseAdjustment(forRegion: plannedTopSet.region)
            // Re-clamp to the −10% ceiling so the future gate-on path can never over-trim either.
            effectiveFactor = Swift.max(1.0 - Constants.maxLoadTrim, effectiveFactor)
        }

        // --- Compute + plate-round the adjusted weight. --------------------------------------------
        let rawAdjusted = planned * effectiveFactor
        var adjusted = WeightFormatter.snapToIncrement(rawAdjusted, to: plateStepKg)
        // NEVER round UP past the plan when trimming (research §2.3 guardrail).
        if effectiveFactor < 1.0, adjusted > planned {
            adjusted = planned
        }

        // --- Collapse to the verdict (research §3.1). ----------------------------------------------
        // Sub-increment delta + no back-off cut ⇒ GO (no false-precision micro-change).
        if (planned - adjusted) < plateStepKg, volumeCutSets == nil {
            return VerdictResult(
                verdict: .go,
                adjustedTopSetKg: planned,
                volumeCutSets: nil,
                loadFactor: 1.0
            )
        }

        return VerdictResult(
            verdict: .modify,
            adjustedTopSetKg: adjusted,
            volumeCutSets: volumeCutSets,
            loadFactor: effectiveFactor
        )
    }
}
