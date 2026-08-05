import Foundation

/// The v2 recovery arm: the same four components and the same weights as the live engine, but
/// HRV and RHR scored from a **personal z against the robust baseline** instead of from a ratio
/// to a flat 7-value mean. Pure, dateless, and never consulted by the live path.
///
/// ## The one deliberate design constraint: same anchor, different estimator
///
/// v2 maps `z = 0` to exactly **70** — the score v1 gives at `ratio = 1.0`. That is not a
/// cosmetic choice. If v2 also re-anchored the neutral point, the two arms would differ for two
/// reasons at once and the shadow could not attribute the divergence. Holding the anchor fixed
/// means any gap between v1 and v2 comes from what is actually under test: **what "normal" is,
/// and how far from normal today sits.**
///
/// Sensitivity is stated rather than tuned: `pointsPerSigma`. One robust σ of deviation moves
/// the component 15 points, so ±2σ spans roughly 40–100. v1's ratio line is far steeper for a
/// low-variability athlete (a 1σ move can be worth ~25 points when σ is small relative to the
/// mean), which is precisely the over-reaction to ordinary day-to-day noise the robust scale is
/// meant to remove — expect v2 to be calmer, and check that in the divergence report rather
/// than assuming it.
///
/// ## Honest silence
///
/// `BaselineEngine.score` returns a nil z until it has earned an opinion (too few observations,
/// or a scale it cannot yet estimate). v2 propagates that: the component is nil and the score
/// renormalizes over what remains, exactly as v1 does for a missing signal. It never fills a
/// gap with a guess.
struct RecoveryShadowEngine {

    /// Component points per robust σ of deviation from the personal baseline.
    static let pointsPerSigma: Double = 15.0

    /// The neutral component score, held identical to v1's `ratio = 1.0` value so the arms
    /// differ only in their estimator.
    static let neutralScore: Double = 70.0

    /// One signal's v2 evaluation.
    struct SignalOutcome {
        /// 0–100 component score; nil when the estimator declined to hold an opinion.
        let component: Double?
        /// Personal z (sign-corrected so positive is always "better"); nil likewise.
        let z: Double?
        /// The robust baseline level the fold settled on.
        let mu: Double?
        /// 0–1 confidence in that baseline.
        let confidence: Double
    }

    /// Fold the prior days into a robust baseline, then score today against it.
    ///
    /// Prequential by construction: the state is built from `priorDays` ONLY — the day being
    /// scored never contributes to the baseline it is measured against.
    ///
    /// - Parameter today: today's daily value, or nil when the day has no reading.
    /// - Parameter priorDays: strictly-earlier daily values, oldest first.
    /// - Parameter config: the per-signal `BaselineEngine.SignalConfig` (half-life, σ floor,
    ///   and the direction that decides the sign of z).
    static func evaluate(
        today: Double?,
        priorDays: [Double],
        config: BaselineEngine.SignalConfig
    ) -> SignalOutcome {
        var state = BaselineEngine.SignalState()
        for value in priorDays {
            state = BaselineEngine.step(
                state: state,
                observation: value,
                config: config,
                bucketedDate: nil
            )
        }
        let confidence = BaselineEngine.confidence(state: state, daysSinceLastBucket: 0)
        guard let today else {
            return SignalOutcome(component: nil, z: nil, mu: state.mu, confidence: confidence)
        }
        let scored = BaselineEngine.score(state: state, observation: today, config: config)
        guard let z = scored.z else {
            return SignalOutcome(component: nil, z: nil, mu: state.mu, confidence: confidence)
        }
        let component = clamp(neutralScore + z * pointsPerSigma)
        return SignalOutcome(component: component, z: z, mu: state.mu, confidence: confidence)
    }

    /// The v2 composite, pre-trend, over whatever components are present.
    ///
    /// Sleep and wellness are reused from the live arm unchanged: this experiment is about the
    /// HRV/RHR estimator, and re-deriving the other two would let a second difference leak into
    /// the comparison. Returns nil when NEITHER physiological arm produced a component — with
    /// only sleep and wellness left there is nothing v2 is contributing to test.
    static func compositeScore(
        hrvComponent: Double?,
        rhrComponent: Double?,
        sleepComponent: Double?,
        wellnessComponent: Double?
    ) -> Double? {
        guard hrvComponent != nil || rhrComponent != nil else { return nil }
        var parts: [(score: Double, weight: Double)] = []
        if let hrvComponent { parts.append((hrvComponent, Weights.hrv)) }
        if let rhrComponent { parts.append((rhrComponent, Weights.rhr)) }
        if let sleepComponent { parts.append((sleepComponent, Weights.sleep)) }
        if let wellnessComponent { parts.append((wellnessComponent, Weights.wellness)) }
        guard !parts.isEmpty else { return nil }
        let totalWeight = parts.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return nil }
        let weighted = parts.reduce(0.0) { $0 + $1.score * ($1.weight / totalWeight) }
        return clamp(weighted)
    }

    /// Mirrors `RecoveryScoreEngine`'s weights exactly — the arms must differ ONLY in how the
    /// two physiological components are derived.
    enum Weights {
        static let hrv: Double = 0.30
        static let rhr: Double = 0.20
        static let sleep: Double = 0.25
        static let wellness: Double = 0.25
    }

    private static func clamp(_ value: Double) -> Double {
        Swift.min(100, Swift.max(0, value))
    }
}
