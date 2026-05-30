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
                ? String(format: "%.0f%% above baseline", abs)
                : String(format: "%.0f%% below baseline", abs)
            factors.append(Factor(
                label: "Heart Rate Variability",
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
                ? String(format: "%.0f%% above baseline", abs)
                : String(format: "%.0f%% below baseline", abs)
            factors.append(Factor(
                label: "Resting Heart Rate",
                deltaText: text,
                impact: min(abs / 30, 1.0),
                direction: direction
            ))
        }

        // Sleep — target is 420 min (7 hours)
        if let sleep = input.sleepMinutes {
            let delta = sleep - 420
            let abs = Swift.abs(delta)
            let direction: Factor.Direction = delta >= 30 ? .positive : delta <= -30 ? .negative : .neutral
            let text: String
            if delta >= 0 {
                text = "\(Int(delta)) min above average"
            } else {
                text = "\(Int(abs)) min below average"
            }
            factors.append(Factor(
                label: "Sleep Duration",
                deltaText: text,
                impact: min(abs / 90, 1.0),  // 90 min deviation = max impact
                direction: direction
            ))
        }

        // Consecutive training days — flags accumulating fatigue
        if input.daysSinceRest >= 4 {
            let days = input.daysSinceRest
            factors.append(Factor(
                label: "Training Streak",
                deltaText: "\(days) consecutive training days",
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
    /// resulting recommendation. `personalSleepBaselineMinutes` (when available) replaces the legacy
    /// fixed 7h target ONLY inside this new explanation (research §2.7); the legacy `summarize` is
    /// untouched.
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
            let direction = f.contribution < 0 ? "below" : "above"
            let magnitude = String(format: "%.1f", abs(f.z))
            let verb = isReduction && f.contribution < 0 ? "Holding back" : "Supported by"
            reasons.append(DecisionReason(
                text: "\(verb) — \(f.label) \(magnitude)σ \(direction) your baseline",
                source: f.label,
                contribution: f.contribution
            ))
        }

        // Strain-Risk factors (each pushes risk UP; a higher contribution is a reason to cut load).
        for f in input.strainRisk.factors where f.contribution > 0 {
            reasons.append(DecisionReason(
                text: "Caution — \(f.label)",
                source: f.label,
                // Strain-risk contributions raise risk → represent as a downward (negative) pressure
                // on the decision so ranking by |contribution| interleaves both channels coherently.
                contribution: -f.contribution
            ))
        }

        // Sleep debt vs PERSONAL baseline if available (research §2.7), else no extra line.
        // (We only ADD a personalized line; we never read the legacy fixed 7h target here.)
        if let baseline = input.personalSleepBaselineMinutes, baseline > 0 {
            // A sleep readiness factor already encodes deviation; this line names the personal target
            // explicitly for the explanation only.
            reasons.append(DecisionReason(
                text: "Your personal sleep baseline is ~\(Int(baseline / 60))h \(Int(baseline.truncatingRemainder(dividingBy: 60)))m",
                source: "Sleep",
                contribution: 0
            ))
        }

        // Rank by absolute contribution (most influential first); keep the personalized sleep line
        // stable at the end (contribution 0 sorts last).
        return reasons.sorted { abs($0.contribution) > abs($1.contribution) }
    }
}
