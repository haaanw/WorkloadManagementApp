import Foundation

/// Produces human-readable reasoning factors from recovery and workload inputs.
/// Explains *why* the readiness score is what it is, ranked by impact.
///
/// Pure struct with static methods — no state, no dependencies.
struct ReasoningEngine {

    struct Input {
        let recoveryResult: RecoveryScoreEngine.RecoveryResult
        let workloadSnapshot: WorkloadSnapshot?
        let rawHRV: Double?
        let rawRHR: Double?
        let hrvBaseline: Double?
        let rhrBaseline: Double?
        let sleepMinutes: Double?
        let daysSinceRest: Int
    }

    struct Factor {
        let label: String       // "Heart Rate Variability"
        let deltaText: String   // "14% below baseline" / "38 min below average"
        let impact: Double      // 0–1, used for ranking (higher = more impactful)
        let direction: Direction

        enum Direction { case positive, neutral, negative }
    }

    /// Returns factors ranked by impact (highest first), max 3 for hero card display.
    static func summarize(input: Input) -> [Factor] {
        var factors: [Factor] = []

        // HRV — higher than baseline is better
        if let hrv = input.rawHRV, let baseline = input.hrvBaseline, baseline > 0 {
            let delta = (hrv - baseline) / baseline * 100
            let abs = Swift.abs(delta)
            let direction: Factor.Direction = delta > 5 ? .positive : delta < -5 ? .negative : .neutral
            let text = delta >= 0
                ? String(format: String(localized: "delta.aboveBaseline", defaultValue: "%.0f%% above baseline"), abs)
                : String(format: String(localized: "delta.belowBaseline", defaultValue: "%.0f%% below baseline"), abs)
            factors.append(Factor(
                label: String(localized: "factor.heartRateVariability", defaultValue: "Heart Rate Variability"),
                deltaText: text,
                impact: min(abs / 30, 1.0),
                direction: direction
            ))
        }

        // Resting HR — lower than baseline is better (direction inverted)
        if let rhr = input.rawRHR, let baseline = input.rhrBaseline, baseline > 0 {
            let delta = (rhr - baseline) / baseline * 100
            let abs = Swift.abs(delta)
            let direction: Factor.Direction = delta > 5 ? .negative : delta < -5 ? .positive : .neutral
            let text = delta >= 0
                ? String(format: String(localized: "delta.aboveBaseline", defaultValue: "%.0f%% above baseline"), abs)
                : String(format: String(localized: "delta.belowBaseline", defaultValue: "%.0f%% below baseline"), abs)
            factors.append(Factor(
                label: String(localized: "factor.restingHeartRate", defaultValue: "Resting Heart Rate"),
                deltaText: text,
                impact: min(abs / 30, 1.0),
                direction: direction
            ))
        }

        // Sleep — measured against the app-wide target, `RecoveryScoreEngine.sleepTargetHours`
        // (7.5 h, HAN 2026-07-31; previously a hard-typed 420 min here). Reading the constant
        // rather than a literal is what keeps this row and `SleepDetailView` — which the Dashboard
        // row navigates INTO — from reporting the same night against two different references.
        //
        // The copy names the target too: "above/below average" named neither the athlete's
        // baseline nor the target, so a 435-min night read "15 min above average" on Home and sat
        // below the target one tap later.
        if let sleep = input.sleepMinutes {
            let targetMinutes = RecoveryScoreEngine.sleepTargetHours * 60
            let delta = sleep - targetMinutes
            let abs = Swift.abs(delta)
            let direction: Factor.Direction = delta >= 30 ? .positive : delta <= -30 ? .negative : .neutral
            let text: String
            if delta >= 0 {
                text = String(localized: "delta.minAboveTarget", defaultValue: "\(Int(delta)) min above target")
            } else {
                text = String(localized: "delta.minBelowTarget", defaultValue: "\(Int(abs)) min below target")
            }
            factors.append(Factor(
                label: String(localized: "factor.sleepDuration", defaultValue: "Sleep Duration"),
                deltaText: text,
                impact: min(abs / 90, 1.0),  // 90 min deviation = max impact
                direction: direction
            ))
        }

        // Consecutive training days — flags accumulating fatigue
        if input.daysSinceRest >= 4 {
            let days = input.daysSinceRest
            factors.append(Factor(
                label: String(localized: "factor.trainingStreak", defaultValue: "Training Streak"),
                deltaText: String(localized: "reason.consecutiveTrainingDays", defaultValue: "\(days) consecutive training days"),
                impact: min(Double(days - 3) / 4.0, 1.0),
                direction: .negative
            ))
        }

        return factors.sorted { $0.impact > $1.impact }.prefix(3).map { $0 }
    }

    // MARK: - Decision explanation (Phase 28, Wave 2 — ADDITIVE, GA-11)

    /// One ranked, confidence-annotated reason for the DECISION (not just the recovery score).
    /// Each reason decomposes back to a named pre-update factor (signal + magnitude + contribution)
    /// so the prescription is glass-box (research §2.7 / §253).
    struct DecisionReason: Equatable {
        /// Human-readable reason, e.g. "Volume cut — HRV 1.2σ below your baseline".
        let text: String
        /// The named source factor ("Heart Rate Variability", "Per-muscle strength-load elevation", …).
        let source: String
        /// Signed contribution magnitude used for ranking (larger |·| = more influential).
        let contribution: Double
    }

    /// Inputs to the decision explanation: the Readiness factors + Strain-Risk ranked factors + the
    /// resulting recommendation. `personalSleepBaselineMinutes` (when available) replaces the
    /// fixed app-wide target ONLY inside this new explanation (research §2.7); `summarize` is
    /// untouched and keeps reading `RecoveryScoreEngine.sleepTargetHours`.
    struct DecisionInput {
        let readiness: ReadinessFusionEngine.ReadinessResult
        let strainRisk: StrainRiskEngine.StrainRiskResult
        let recommendation: AutoregulationEngine.TrainingRecommendation
        let personalSleepBaselineMinutes: Double?

        init(
            readiness: ReadinessFusionEngine.ReadinessResult,
            strainRisk: StrainRiskEngine.StrainRiskResult,
            recommendation: AutoregulationEngine.TrainingRecommendation,
            personalSleepBaselineMinutes: Double? = nil
        ) {
            self.readiness = readiness
            self.strainRisk = strainRisk
            self.recommendation = recommendation
            self.personalSleepBaselineMinutes = personalSleepBaselineMinutes
        }
    }

    /// Explain the DECISION with ranked, confidence-annotated reasons (e.g. "volume cut because HRV
    /// −x%, high per-muscle hard sets, no rest day"). ADDITIVE: the existing `summarize` signature is
    /// unchanged. Reasons are decomposable to named pre-update factors (glass-box). Copy never says
    /// "injury prediction" / "injury risk" (GA-11 — grep-guarded).
    ///
    /// - Returns: ranked reasons (most influential first) plus the recommendation's `volumeModifier`
    ///   framed as the headline action; the confidence is the Readiness confidence (reported, not
    ///   folded). When the flag is off this is NOT shown to the user (Wave 4 gates the surface).
    static func explainDecision(input: DecisionInput) -> [DecisionReason] {
        var reasons: [DecisionReason] = []

        // Whether the prescription is a reduction (drives the "cut" vs "supports" framing).
        let isReduction = input.recommendation.volumeModifier < 1.0 || input.recommendation.intensityCap < 10.0

        // Readiness factors (each +z = better; a NEGATIVE contribution lowers readiness → a reason
        // to hold back). Surface the depressing factors first when we are reducing.
        for f in input.readiness.factors {
            let direction = f.contribution < 0
                ? String(localized: "reason.direction.below", defaultValue: "below")
                : String(localized: "reason.direction.above", defaultValue: "above")
            let verb = isReduction && f.contribution < 0
                ? String(localized: "reason.verb.holdingBack", defaultValue: "Holding back")
                : String(localized: "reason.verb.supportedBy", defaultValue: "Supported by")
            reasons.append(DecisionReason(
                text: String(localized: "reason.readinessFactor", defaultValue: "\(verb) — \(f.label) \(abs(f.z), specifier: "%.1f")σ \(direction) your baseline"),
                source: f.label,
                contribution: f.contribution
            ))
        }

        // Strain-Risk factors (each pushes risk UP; a higher contribution is a reason to cut load).
        for f in input.strainRisk.factors where f.contribution > 0 {
            reasons.append(DecisionReason(
                text: String(localized: "reason.caution", defaultValue: "Caution — \(f.label)"),
                source: f.label,
                // Strain-risk contributions raise risk → represent as a downward (negative) pressure
                // on the decision so ranking by |contribution| interleaves both channels coherently.
                contribution: -f.contribution
            ))
        }

        // Sleep debt vs PERSONAL baseline if available (research §2.7), else no extra line.
        // (We only ADD a personalized line; we never read the fixed app-wide target here.)
        if let baseline = input.personalSleepBaselineMinutes, baseline > 0 {
            // A sleep readiness factor already encodes deviation; this line names the personal target
            // explicitly for the explanation only.
            reasons.append(DecisionReason(
                text: String(localized: "reason.personalSleepBaseline", defaultValue: "Your personal sleep baseline is ~\(Int(baseline / 60))h \(Int(baseline.truncatingRemainder(dividingBy: 60)))m"),
                source: String(localized: "factor.sleep", defaultValue: "Sleep"),
                contribution: 0
            ))
        }

        // Rank by absolute contribution (most influential first); keep the personalized sleep line
        // stable at the end (contribution 0 sorts last).
        return reasons.sorted { abs($0.contribution) > abs($1.contribution) }
    }
}
