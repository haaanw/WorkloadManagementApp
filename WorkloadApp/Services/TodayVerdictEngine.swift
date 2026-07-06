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
/// ## Match proximity (ADR-0002 — one date, one rule, NO trajectory math)
/// An optional `matchDaysAway` input (derived from `Athlete.nextMatchDate` via `matchDaysAway(...)`)
/// tightens the verdict to the MICRODOSE shape when the next scheduled match is ≤2 calendar days
/// away (see `Constants.matchProximityDays` for the exact day-boundary semantics). Proximity can
/// only move GO → MODIFY — never HOLD (anti-nocebo). nil / expired / >2 days ⇒ EXACTLY unchanged.
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
    /// `matchProximity` is true exactly when the match-proximity rule (ADR-0002) engaged AND the
    /// verdict is `.modify` — the microdose shape. It drives the "microdose" framing downstream;
    /// it never changes the numbers by itself.
    struct VerdictResult: Equatable {
        let verdict: Verdict
        let adjustedTopSetKg: Double
        let volumeCutSets: Int?
        let loadFactor: Double
        let matchProximity: Bool

        init(
            verdict: Verdict,
            adjustedTopSetKg: Double,
            volumeCutSets: Int?,
            loadFactor: Double,
            matchProximity: Bool = false
        ) {
            self.verdict = verdict
            self.adjustedTopSetKg = adjustedTopSetKg
            self.volumeCutSets = volumeCutSets
            self.loadFactor = loadFactor
            self.matchProximity = matchProximity
        }
    }

    // MARK: - Tunable constants (the SINGLE home — mirrors CrossModalFatigueEngine.Constants)

    enum Constants {
        /// Default LOAD trim magnitude (−5%). Applied at the modify boundary (mildly clearly-down).
        static let defaultLoadTrim: Double = 0.05
        /// Maximum LOAD trim magnitude (−10% ceiling). `loadFactor` is hard-clamped to `≥ 1 − maxLoadTrim`.
        static let maxLoadTrim: Double = 0.10
        /// Loadable plate step (kg). The adjusted weight is always a multiple of this.
        static let plateStepKg: Double = 2.5

        /// Match proximity window in CALENDAR DAYS (ADR-0002 — one date, one rule, no trajectory
        /// math). "≤48h" is deliberately measured in start-of-day calendar days, mirroring the
        /// Stage-1 `Athlete.nextMatchDate` start-of-day normalization: the rule engages on match
        /// day itself (`daysAway == 0`) and the 2 calendar days before it (`1`, `2`) — e.g. a
        /// Saturday match tightens Thursday, Friday, and Saturday. A match 3 calendar days out has
        /// ZERO effect. Time-of-day never matters (both sides are start-of-day normalized).
        static let matchProximityDays: Int = 2

        /// volumeModifier at/above this ⇒ no reduction (GO candidate).
        static let goVolumeThreshold: Double = 0.95
        /// volumeModifier in `[volumeCutFloor, goVolumeThreshold)` ⇒ volume-cut-preferred (keep top set).
        static let volumeCutFloor: Double = 0.85
        /// Number of back-off sets a full reduction (volumeModifier → volumeCutFloor) implies.
        static let backoffSetsAtFullCut: Double = 3.0
    }

    // MARK: - Match proximity (ADR-0002 — one date, one rule, NO trajectory math)

    /// Calendar-day distance from `asOf` to the next scheduled match, or nil when there is no
    /// effective match: `nextMatchDate == nil` OR the date is strictly before today (expired).
    /// Mirrors the Stage-1 convention — an expired date is treated as ABSENT; the engine is pure
    /// and never mutates the model (the UI clears expired dates on section appear). Both sides are
    /// start-of-day normalized, so time-of-day never shifts the boundary.
    static func matchDaysAway(
        nextMatchDate: Date?,
        asOf: Date,
        calendar: Calendar
    ) -> Int? {
        guard let nextMatchDate else { return nil }
        let today = calendar.startOfDay(for: asOf)
        let match = calendar.startOfDay(for: nextMatchDate)
        guard let days = calendar.dateComponents([.day], from: today, to: match).day,
              days >= 0 else { return nil }   // strictly-before-today ⇒ absent (never mutate)
        return days
    }

    /// The ONE proximity predicate: the next scheduled match is on today or within the next
    /// `Constants.matchProximityDays` calendar days. nil (no match / expired) ⇒ never near.
    static func isMatchNear(daysAway: Int?) -> Bool {
        guard let daysAway else { return false }
        return daysAway >= 0 && daysAway <= Constants.matchProximityDays
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
    ///   - matchDaysAway: calendar days to the next scheduled match (from `matchDaysAway(...)`);
    ///     nil ⇒ no match scheduled / expired ⇒ behavior EXACTLY unchanged.
    ///   - plannedWorkingSetCount: the exercise's working-set count, so the microdose can cut ALL
    ///     back-offs (`count − 1`); nil falls back to `Constants.backoffSetsAtFullCut`.
    static func evaluate(
        recommendation: AutoregulationEngine.TrainingRecommendation,
        plannedTopSet: PlannedTopSet,
        crossModalResult: CrossModalFatigueEngine.CrossModalResult?,
        plateStepKg: Double = Constants.plateStepKg,
        matchDaysAway: Int? = nil,
        plannedWorkingSetCount: Int? = nil
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

        // --- Match-proximity TIGHTEN (ADR-0002: one date, one rule, no trajectory math). -----------
        // When the next scheduled match is near (see `Constants.matchProximityDays`), the verdict
        // tightens to the MICRODOSE shape (CONTEXT.md): keep the athlete's planned movements, cap
        // the top set — the existing bound logic, preferring the STRONGER trim (at least the −5%
        // default; more if the body already said more, still hard-capped at −10%) — and cut ALL
        // back-off sets (~20-min session character). Anti-nocebo: proximity can only move
        // GO → MODIFY (tighter numbers); it NEVER produces HOLD (the rest-like HOLD path above
        // returns before this and is untouched by proximity).
        let proximityActive = isMatchNear(daysAway: matchDaysAway)
        if proximityActive {
            // Cap the top set: prefer the stronger of (the recommendation's trim, the −5% default),
            // re-clamped to the −10% ceiling.
            effectiveFactor = Swift.min(effectiveFactor, 1.0 - Constants.defaultLoadTrim)
            effectiveFactor = Swift.max(1.0 - Constants.maxLoadTrim, effectiveFactor)
            // Cut ALL back-offs: count − 1 when the working-set count is known (nil when there are
            // no back-offs to cut), else the full-cut convention.
            let microCut = plannedWorkingSetCount.map { Swift.max($0 - 1, 0) }
                ?? Int(Constants.backoffSetsAtFullCut)
            let merged = Swift.max(volumeCutSets ?? 0, microCut)
            volumeCutSets = merged > 0 ? merged : nil
        }

        // --- Compute + plate-round the adjusted weight. --------------------------------------------
        let rawAdjusted = planned * effectiveFactor
        var adjusted = WeightFormatter.snapToIncrement(rawAdjusted, to: plateStepKg)
        // NEVER round UP past the plan when trimming (research §2.3 guardrail).
        if effectiveFactor < 1.0, adjusted > planned {
            adjusted = planned
        }

        // --- Collapse to the verdict (research §3.1). ----------------------------------------------
        // Sub-increment delta + no back-off cut ⇒ GO (no false-precision micro-change). This also
        // holds under match proximity: a microdose with no back-offs to cut and a sub-plate-step
        // trim changes literally nothing — forcing MODIFY there would be false precision.
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
            loadFactor: effectiveFactor,
            matchProximity: proximityActive
        )
    }
}
