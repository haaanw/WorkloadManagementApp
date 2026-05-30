import Foundation

/// Daily training autoregulation engine.
/// Combines recovery status, ACWR zone, fatigue accumulation index, subjective
/// wellness, and training history to produce actionable training recommendations.
///
/// The decision matrix (recovery zone × ACWR zone) provides guardrails.
/// The fatigue index continuously modulates intensity cap and volume within
/// those guardrails — no hard jumps between zones.
struct AutoregulationEngine {

    struct DailyInput {
        let recoveryZone: RecoveryZone
        let recoveryScore: Double       // 0-100
        let acwrZone: ACWRZone
        let acwr: Double
        let wellnessScore: Double?       // 0-100
        let daysSinceLastRest: Int
        /// Fatigue Accumulation Index (0-100). Nil = not yet computed / shadow mode.
        let fatigueIndex: Double?

        init(
            recoveryZone: RecoveryZone,
            recoveryScore: Double,
            acwrZone: ACWRZone,
            acwr: Double,
            wellnessScore: Double?,
            daysSinceLastRest: Int,
            fatigueIndex: Double? = nil
        ) {
            self.recoveryZone = recoveryZone
            self.recoveryScore = recoveryScore
            self.acwrZone = acwrZone
            self.acwr = acwr
            self.wellnessScore = wellnessScore
            self.daysSinceLastRest = daysSinceLastRest
            self.fatigueIndex = fatigueIndex
        }
    }

    struct TrainingRecommendation {
        let intensityCap: Double         // Max RPE (1-10)
        let volumeModifier: Double       // 1.0 = full, 0.5 = half
        let sessionType: RecommendedSessionType
        let warnings: [Warning]
        let headline: String             // Short user-facing summary
        let detail: String               // Longer explanation

        enum RecommendedSessionType: String {
            case power = "Power / Speed"
            case strength = "Strength"
            case hypertrophy = "Hypertrophy"
            case conditioning = "Conditioning"
            case activeRecovery = "Active Recovery"
            case rest = "Full Rest"
        }

        enum Warning {
            case acwrDanger
            case acwrCaution
            case recoveryRed
            case consecutiveTrainingDays(Int)
            case lowWellness
            case fatigueHigh
            case fatigueSaturation

            var message: String {
                switch self {
                case .acwrDanger:
                    "Recent load is well above your baseline. Consider reducing volume."
                case .acwrCaution:
                    "Load is building relative to your baseline. Stay controlled."
                case .recoveryRed:
                    "Recovery score is low. Prioritize rest and parasympathetic activities."
                case .consecutiveTrainingDays(let days):
                    "\(days) consecutive training days. Consider scheduling a rest day."
                case .lowWellness:
                    "Subjective wellness is low. Listen to your body."
                case .fatigueHigh:
                    "Accumulated fatigue is high. Consider a lighter session or extra recovery."
                case .fatigueSaturation:
                    "Body stress is very elevated. A rest day or active recovery is strongly recommended."
                }
            }
        }
    }

    // MARK: - Compute Recommendation

    /// Cycle-aware overload (Phase 20, D-07/D-08/D-09). Additive and non-breaking:
    /// `cycleContext == nil` produces output byte-identical to `recommend(input:)` (D-12),
    /// so all existing call sites keep their exact behavior.
    ///
    /// The soft volume modifier (downward-only, 5–15%) is applied ONLY when:
    ///   - `input.recoveryZone == .yellow` (never green or red — criterion 2),
    ///   - the base recommendation is not `.rest`/`.activeRecovery` (never overrides — criterion 2),
    ///   - a same-direction NON-phase signal corroborates (D-09: no reduction from phase alone),
    ///   - AND `CycleModifierGate.shouldApply` is true (double-gate: eligible AND activated).
    ///
    /// Because `CycleModifierActivation.isEnabled` is false this phase, `shouldApply` is
    /// always false → the returned recommendation is UNCHANGED in every case. The would-be
    /// factor is still computable via `cycleVolumeFactor(input:cycleContext:)` for shadow logging.
    static func recommend(
        input: DailyInput,
        cycleContext: CycleContext?,
        cyclesObserved: Int = 0
    ) -> TrainingRecommendation {
        let base = recommend(input: input)

        guard let cycleContext,
              CycleModifierGate.shouldApply(context: cycleContext, cyclesObserved: cyclesObserved) else {
            // nil context OR not eligible/activated → identical to base (D-12 / D-06).
            return base
        }

        let factor = cycleVolumeFactor(input: input, cycleContext: cycleContext)
        guard factor < 1.0 else { return base }

        return TrainingRecommendation(
            intensityCap: base.intensityCap,
            volumeModifier: base.volumeModifier * factor,  // downward-only (factor <= 1.0)
            sessionType: base.sessionType,
            warnings: base.warnings,
            headline: base.headline,
            detail: base.detail
        )
    }

    /// The would-be soft volume factor in `[0.85, 1.0]` (0–15% reduction). Pure and always
    /// computable so Plan 03 can shadow-log it regardless of activation.
    ///
    /// Returns exactly `1.0` (no reduction) unless ALL hold:
    ///   - recovery zone is `.yellow`,
    ///   - the base session type is not `.rest`/`.activeRecovery`,
    ///   - the cycle phase buckets to `.luteal` (phase contributes direction only),
    ///   - a corroborating NON-phase negative signal exists (D-09). The magnitude scales
    ///     with that corroboration (D-08): stronger downward signal → larger reduction,
    ///     capped at 15%. No corroboration → 1.0 (no reduction from phase alone, D-09).
    static func cycleVolumeFactor(input: DailyInput, cycleContext: CycleContext) -> Double {
        // Yellow-zone only.
        guard input.recoveryZone == .yellow else { return 1.0 }

        // Never override rest / active recovery (use the base recommendation's type).
        let baseType = recommend(input: input).sessionType
        guard baseType != .rest, baseType != .activeRecovery else { return 1.0 }

        // Phase contributes DIRECTION only: must be luteal bucket.
        guard RecoveryScoreEngine.bucket(for: cycleContext.phase) == .luteal else { return 1.0 }

        // D-09: corroboration from a same-direction NON-phase signal.
        // Yellow recovery zone spans ~[40, 70). "Lower part of yellow" (closer to 40) and
        // low wellness / high soreness each independently corroborate a downward nudge.
        // corroboration in [0, 1]; 0 → no reduction (no phase-alone change).
        var corroboration = 0.0

        // (a) recovery score in the lower part of the yellow band
        if input.recoveryScore < 70 {
            let depth = (60.0 - input.recoveryScore) / 20.0  // 0 at 60, 1 at 40
            corroboration = max(corroboration, min(1.0, max(0.0, depth)))
        }
        // (b) low subjective wellness
        if let wellness = input.wellnessScore, wellness < 50 {
            let depth = (50.0 - wellness) / 30.0  // 0 at 50, ~1 at 20
            corroboration = max(corroboration, min(1.0, max(0.0, depth)))
        }

        guard corroboration > 0 else { return 1.0 }  // D-09 no phase-alone reduction

        // D-08: scale 5–15% reduction by corroboration strength.
        let reduction = 0.05 + 0.10 * corroboration   // [0.05, 0.15]
        return 1.0 - reduction                          // [0.85, 0.95]
    }

    // MARK: - PRS-v1 readiness × strain-risk path (Phase 28, FLAGGED — GA-4/GA-5)

    /// Input bundle for the NEW (flagged) `(readinessZone × strainRiskZone)` decision path.
    /// ACWR is demoted to a context-LABEL only (`acwrContextLabel`) — it never enters the decision
    /// or any warning (GA-4). The existing fatigue / consecutive-day / wellness signals are kept so
    /// the explainable warning shell is preserved (research §3).
    struct ReadinessInput {
        let readinessZone: ReadinessZone
        let readiness: Double            // 0-100 (for continuity / display)
        let strainRiskZone: StrainRiskZone
        let wellnessScore: Double?
        let daysSinceLastRest: Int
        let fatigueIndex: Double?
        /// ACWR rendered as a context label only (e.g. "Load Steady"). NEVER a decision input.
        let acwrContextLabel: String

        init(
            readinessZone: ReadinessZone,
            readiness: Double,
            strainRiskZone: StrainRiskZone,
            wellnessScore: Double?,
            daysSinceLastRest: Int,
            fatigueIndex: Double? = nil,
            acwrContextLabel: String
        ) {
            self.readinessZone = readinessZone
            self.readiness = readiness
            self.strainRiskZone = strainRiskZone
            self.wellnessScore = wellnessScore
            self.daysSinceLastRest = daysSinceLastRest
            self.fatigueIndex = fatigueIndex
            self.acwrContextLabel = acwrContextLabel
        }
    }

    /// FLAGGED dispatch (Phase 28, GA-5/GA-6). When `PRSActivation.isEnabled == false` (the
    /// default), this returns the LEGACY `(recoveryZone × acwrZone)` recommendation BYTE-IDENTICAL
    /// to pre-Phase-28 — the `legacyInput` path is reached verbatim. When the flag is on, it returns
    /// the NEW `(readinessZone × strainRiskZone)` recommendation.
    ///
    /// This is the single switch the live call site uses once Phase 28 ships; with the flag off the
    /// `readinessInput` is computed but NEVER consulted (shadow-safe), guaranteeing byte-identical
    /// live behavior (machine-enforced by `AutoregulationFlagFenceTests`).
    static func recommendFlagged(
        legacyInput: DailyInput,
        readinessInput: ReadinessInput
    ) -> TrainingRecommendation {
        guard PRSActivation.isEnabled else {
            // FLAG OFF (default): byte-identical legacy path.
            return recommend(input: legacyInput)
        }
        // FLAG ON: new readiness × strain-risk path.
        return recommendReadiness(input: readinessInput)
    }

    /// The NEW `(readinessZone × strainRiskZone)` decision matrix (3×3 — GA-3), mirroring the
    /// legacy matrix authoring style and output shape. ACWR is NOT consulted; it is emitted only as
    /// a context label appended to `detail`. The cycle double-gate is preserved via the separate
    /// `recommendReadiness(input:cycleContext:)` overload. Fatigue modulation + consecutive-day
    /// override are kept (the explainable shell, research §3).
    ///
    /// NOTE: no warning case references ACWR in this path (GA-4 — asserted by tests). The legacy
    /// `.acwrDanger`/`.acwrCaution` warnings are intentionally NOT emitted here.
    static func recommendReadiness(input: ReadinessInput) -> TrainingRecommendation {
        var warnings: [TrainingRecommendation.Warning] = []

        // Collect warnings — NO ACWR warning in the flag-on path (GA-4: ACWR is context-label only).
        if input.readinessZone == .low { warnings.append(.recoveryRed) }
        if input.daysSinceLastRest >= 5 { warnings.append(.consecutiveTrainingDays(input.daysSinceLastRest)) }
        if let wellness = input.wellnessScore, wellness < 40 { warnings.append(.lowWellness) }
        if let fi = input.fatigueIndex {
            if fi >= 75 {
                warnings.append(.fatigueSaturation)
            } else if fi >= 55 {
                warnings.append(.fatigueHigh)
            }
        }

        // Decision matrix: readiness zone × strain-risk zone (guardrails).
        // Rows = readiness (low/moderate/high); within each row, escalating strain-risk pulls
        // volume/intensity DOWN. A recovered athlete (high readiness) carrying high strain-risk is
        // the key case the two-channel design surfaces (GA-1): cap volume even when readiness is high.
        let base: (cap: Double, vol: Double, type: TrainingRecommendation.RecommendedSessionType, headline: String, detail: String)

        switch (input.readinessZone, input.strainRiskZone) {

        // LOW readiness — always limit, regardless of strain-risk.
        case (.low, .high), (.low, .elevated):
            base = (5.0, 0.0, .rest,
                    "Full Rest Day",
                    "Readiness is low and accumulated strain is high. Prioritize sleep, nutrition, and parasympathetic recovery.")
        case (.low, .moderate), (.low, .low):
            base = (5.0, 0.5, .activeRecovery,
                    "Active Recovery Only",
                    "Readiness is low. Keep to light movement (Zone 1-2, mobility, foam rolling). Reduce volume by 50%.")

        // MODERATE readiness.
        case (.moderate, .high):
            base = (6.0, 0.5, .activeRecovery,
                    "Light Day — Strain Is High",
                    "Readiness is moderate and accumulated strain is high. Reduce volume by 50% and keep intensity low — a deload opportunity.")
        case (.moderate, .elevated):
            base = (7.0, 0.75, .conditioning,
                    "Moderate Day — Stay Controlled",
                    "Readiness is fair and strain is building. Hold volume near 75%, cap RPE at 7, avoid max-effort sets.")
        case (.moderate, .moderate):
            base = (8.0, 0.75, .hypertrophy,
                    "Moderate Training OK",
                    "Readiness is moderate. Train at 75% volume, cap RPE at 8 — good for hypertrophy or moderate conditioning.")
        case (.moderate, .low):
            base = (8.0, 1.0, .strength,
                    "Build Gradually",
                    "Readiness is moderate and accumulated strain is low. Progressively build capacity, but don't push past RPE 8.")

        // HIGH readiness — the two-channel case: high strain still caps volume (GA-1).
        case (.high, .high):
            base = (7.0, 0.75, .conditioning,
                    "Feeling Good, But Strain Is High",
                    "Readiness is high, but accumulated strain is high relative to your tolerance. Don't let good readiness mask it — train at 75% volume, stay controlled.")
        case (.high, .elevated):
            base = (8.0, 0.85, .strength,
                    "Train Smart — Strain Building",
                    "You're recovered and strain is building. Good day for quality work; avoid big volume spikes. Hold ~85% planned volume.")
        case (.high, .moderate):
            base = (9.0, 1.0, .strength,
                    "Strong Day",
                    "Readiness is high and strain is moderate. Push quality work toward RPE 9.")
        case (.high, .low):
            base = (10.0, 1.0, .power,
                    "Go Zone — Fully Ready",
                    "Readiness is high and accumulated strain is low. Great day for PR attempts, high-intensity intervals, plyometrics, or max-effort training.")
        }

        // Apply continuous fatigue modulation within guardrails (same as legacy shell).
        var finalCap = base.cap
        var finalVol = base.vol
        var finalType = base.type
        var finalHeadline = base.headline
        var finalDetail = base.detail

        if let fi = input.fatigueIndex {
            let (modCap, modVol) = fatigueModulation(baseCap: base.cap, baseVol: base.vol, fatigueIndex: fi)
            finalCap = modCap
            finalVol = modVol
            if finalVol <= 0.3 && base.type != .rest && base.type != .activeRecovery {
                finalType = .activeRecovery
                finalHeadline = "Fatigue Is Elevated — Go Light"
                finalDetail = "Accumulated training stress suggests lighter work today. Active recovery will help you come back stronger."
            }
        }

        // Consecutive-day override (kept from the legacy shell).
        if input.daysSinceLastRest >= 7 && input.readinessZone != .high {
            finalType = .rest
            finalHeadline = "Rest Day Recommended"
            finalDetail = "You've trained \(input.daysSinceLastRest) consecutive days without rest. Schedule a recovery day to maintain long-term quality."
        }

        // GA-4: ACWR appears ONLY as a context label appended to detail — never a decision input.
        if !input.acwrContextLabel.isEmpty {
            finalDetail += " (Load context: \(input.acwrContextLabel).)"
        }

        return TrainingRecommendation(
            intensityCap: finalCap,
            volumeModifier: finalVol,
            sessionType: finalType,
            warnings: warnings,
            headline: finalHeadline,
            detail: finalDetail
        )
    }

    static func recommend(input: DailyInput) -> TrainingRecommendation {
        var warnings: [TrainingRecommendation.Warning] = []

        // Collect warnings
        if input.acwrZone == .danger { warnings.append(.acwrDanger) }
        if input.acwrZone == .caution { warnings.append(.acwrCaution) }
        if input.recoveryZone == .red { warnings.append(.recoveryRed) }
        if input.daysSinceLastRest >= 5 { warnings.append(.consecutiveTrainingDays(input.daysSinceLastRest)) }
        if let wellness = input.wellnessScore, wellness < 40 { warnings.append(.lowWellness) }

        // Fatigue index warnings
        if let fi = input.fatigueIndex {
            if fi >= 75 {
                warnings.append(.fatigueSaturation)
            } else if fi >= 55 {
                warnings.append(.fatigueHigh)
            }
        }

        // Decision matrix: recovery zone × ACWR zone (guardrails)
        let base: (cap: Double, vol: Double, type: TrainingRecommendation.RecommendedSessionType, headline: String, detail: String)

        switch (input.recoveryZone, input.acwrZone) {

        // RED recovery — always limit
        case (.red, .danger), (.red, .caution):
            base = (5.0, 0.0, .rest,
                    "Full Rest Day",
                    "Recovery is low and recent load is elevated. Focus on sleep, nutrition, and parasympathetic activities (breathing drills, light walking).")

        case (.red, .optimal), (.red, .undertrained), (.red, .noData):
            base = (5.0, 0.5, .activeRecovery,
                    "Active Recovery Only",
                    "Your body needs recovery. Light movement (Zone 1-2 cardio, mobility work, foam rolling) only. Reduce volume by 50% and cap intensity.")

        // YELLOW recovery
        case (.yellow, .danger):
            base = (6.0, 0.5, .activeRecovery,
                    "Light Day — Load Is High",
                    "Recent load is elevated and recovery is moderate. Reduce volume by 50% and keep intensity low. Consider this a deload opportunity.")

        case (.yellow, .caution):
            base = (7.0, 0.75, .conditioning,
                    "Moderate Day — Stay Controlled",
                    "Recovery is fair but load is building. Maintain volume at 75% and cap RPE at 7. Avoid max effort sets.")

        case (.yellow, .optimal):
            base = (8.0, 0.75, .hypertrophy,
                    "Moderate Training OK",
                    "Recovery is moderate. Train at 75% volume, cap RPE at 8. Good day for hypertrophy or moderate conditioning work.")

        case (.yellow, .undertrained), (.yellow, .noData):
            base = (8.0, 1.0, .strength,
                    "Build Load Gradually",
                    "Your chronic load is low. Use today to progressively build capacity, but don't push past RPE 8 given moderate recovery.")

        // GREEN recovery
        case (.green, .danger):
            base = (7.0, 0.75, .conditioning,
                    "Feeling Good, But Load Is High",
                    "Recovery is great, but recent load is elevated relative to your baseline. Don't let good recovery mask accumulated fatigue. Train at 75% volume, stay controlled.")

        case (.green, .caution):
            base = (8.0, 0.85, .strength,
                    "Train Smart — Load Building",
                    "You're recovered and your load is building. Good day for quality work, but avoid massive volume spikes. Stay at ~85% planned volume.")

        case (.green, .optimal):
            base = (10.0, 1.0, .power,
                    "Go Zone — Recovery Is High",
                    "Recovery is high and your load is steady relative to baseline. Good day for PR attempts, high-intensity intervals, plyometrics, or max effort training.")

        case (.green, .undertrained), (.green, .noData):
            base = (9.0, 1.0, .strength,
                    "Build Your Base",
                    "You're fresh and your chronic load is low. Great opportunity to progressively build training capacity. Push toward RPE 9.")
        }

        // Apply continuous fatigue modulation within guardrails
        var finalCap = base.cap
        var finalVol = base.vol
        var finalType = base.type
        var finalHeadline = base.headline
        var finalDetail = base.detail

        if let fi = input.fatigueIndex {
            let (modCap, modVol) = fatigueModulation(
                baseCap: base.cap,
                baseVol: base.vol,
                fatigueIndex: fi
            )
            finalCap = modCap
            finalVol = modVol

            // If fatigue pushed volume below 0.3, recommend active recovery or rest
            if finalVol <= 0.3 && base.type != .rest && base.type != .activeRecovery {
                finalType = .activeRecovery
                finalHeadline = "Fatigue Is Elevated — Go Light"
                finalDetail = "Accumulated training stress suggests your body needs lighter work today. Active recovery will help you come back stronger."
            }
        }

        // Override for excessive consecutive training days
        if input.daysSinceLastRest >= 7 && input.recoveryZone != .green {
            finalType = .rest
            finalHeadline = "Rest Day Recommended"
            finalDetail = "You've trained \(input.daysSinceLastRest) consecutive days without rest. Schedule a recovery day to maintain long-term training quality."
        }

        return TrainingRecommendation(
            intensityCap: finalCap,
            volumeModifier: finalVol,
            sessionType: finalType,
            warnings: warnings,
            headline: finalHeadline,
            detail: finalDetail
        )
    }

    // MARK: - Continuous Fatigue Modulation

    /// Modulate intensity cap and volume modifier based on fatigue index.
    /// Uses smooth interpolation rather than hard zone boundaries.
    ///
    /// - fatigueIndex 0-35 (low): no adjustment
    /// - fatigueIndex 35-55 (elevated): reduce cap by up to 1, volume by up to 15%
    /// - fatigueIndex 55-75 (high): reduce cap by up to 2, volume by up to 30%
    /// - fatigueIndex 75-100 (saturation): reduce cap by up to 3, volume by up to 50%
    ///
    /// Floors: cap never below 4.0, volume never below 0.0
    private static func fatigueModulation(
        baseCap: Double,
        baseVol: Double,
        fatigueIndex: Double
    ) -> (cap: Double, vol: Double) {
        guard fatigueIndex > 35 else {
            return (baseCap, baseVol)
        }

        // Normalized fatigue above threshold: 0 at 35, 1 at 100
        let normalizedFatigue = (fatigueIndex - 35.0) / 65.0

        // Smooth reduction using squared curve (gentle at first, stronger at high fatigue)
        let capReduction = normalizedFatigue * normalizedFatigue * 3.0
        let volReduction = normalizedFatigue * normalizedFatigue * 0.5

        let modCap = max(4.0, baseCap - capReduction)
        let modVol = max(0.0, baseVol - volReduction)

        return (modCap, modVol)
    }
}
