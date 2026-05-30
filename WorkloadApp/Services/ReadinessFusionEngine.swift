import Foundation

/// Pure, deterministic **Readiness** fusion (Phase 28, Wave 1 — PRS-v1).
///
/// Fuses the Phase-26 prequential **personal z-scores** (HRV / RHR / sleep, plus an optional
/// subjective-trend slope) into a single **Readiness** scalar (0–100), a categorical
/// `ReadinessZone`, ranked human-readable factors, and a 0–1 confidence — via a FIXED,
/// sign-constrained, glass-box **logistic** fusion.
///
/// ## What this is (and is NOT)
/// Readiness answers "how recovered / ready to train is this athlete today". It is a SEPARATE
/// channel from the Phase-27 Strain-Risk load-tolerance flag (GA-1): a recovered athlete carrying
/// dangerous load is the most important case to surface, and blending the two would hide it.
///
/// The fusion is `100 · logistic(b0 + Σ wₛ·zₛ + w_trend·slope)`. Coefficients are FIXED named
/// constants, **sign-locked** (positive-is-good signals get positive weights; the z's themselves
/// already carry the sign convention via `BaselineEngine.SignalConfig.higherIsBetter`, so every
/// input z is "+z = better" and every fusion weight is POSITIVE). There is NO per-user weight
/// learning and NO unconstrained optimization (codex CRITICAL #2 §305 — per-user logistic weights
/// on ~60 days of autocorrelated consumer data are statistically bogus).
///
/// ## Honesty / never injury prediction
/// No factor label or zone copy frames this as injury prediction (GA-11, grep-guarded).
///
/// ## Isolation (Phase 28 Wave 1)
/// This engine does NOT call or modify `StrainRiskEngine`, `RecoveryScoreEngine`, or
/// `AutoregulationEngine`. It is a NEW, separate output. It holds NO persisted SwiftData state
/// (GA-7) — it is a pure recompute from z-inputs supplied by the caller.
///
/// ## Missingness (no mean-imputation — research §2.2 / codex §314)
/// A `nil` z is EXCLUDED and the remaining weights are renormalized PROPORTIONALLY over the
/// present signals (carrying a `missingSignals` flag). We never mean-impute an absent signal.
///
/// ## Confidence is reported SEPARATELY (not folded into the scalar)
/// `confidence` (0–1, from Phase-26 valid-sample count / staleness, passed in) is reported in the
/// result but does NOT scale the Readiness number — a low-confidence input yields the SAME scalar,
/// only flagged as less certain (decomposition asserted by tests).
struct ReadinessFusionEngine {

    // MARK: - Input

    /// One Readiness fusion input bundle. All z-scores are Phase-26 prequential personal z's
    /// ("+z = better", already sign-corrected by `BaselineEngine`). The engine does NOT recompute
    /// baselines — it accepts z-scores as inputs. A `nil` z means the signal is absent (cold-start /
    /// gap) and is excluded with weight renormalization (NOT imputed).
    struct ReadinessInput {
        /// HRV personal z (+z = better). `nil` ⇒ absent.
        let hrvZ: Double?
        /// Resting-HR personal z (+z = better; BaselineEngine already inverted the raw sign). `nil` ⇒ absent.
        let rhrZ: Double?
        /// Sleep personal z (+z = better). `nil` ⇒ absent.
        let sleepZ: Double?
        /// Optional subjective / wellness trend slope (+ = improving). `nil` ⇒ absent.
        let subjectiveTrendSlope: Double?
        /// Phase-26 composite confidence (0–1). Reported separately; never folded into the scalar.
        let confidence: Double

        init(
            hrvZ: Double?,
            rhrZ: Double?,
            sleepZ: Double?,
            subjectiveTrendSlope: Double? = nil,
            confidence: Double = 0.0
        ) {
            self.hrvZ = hrvZ
            self.rhrZ = rhrZ
            self.sleepZ = sleepZ
            self.subjectiveTrendSlope = subjectiveTrendSlope
            self.confidence = confidence
        }
    }

    // MARK: - Output contracts

    /// One ranked Readiness factor, decomposable to its source signal + z + weighted contribution.
    struct ReadinessFactor: Equatable {
        let label: String
        /// The signal's "+z = better" z-score (or the trend slope), as supplied.
        let z: Double
        /// This factor's signed contribution to the logit (renormalized weight × z). A more
        /// negative contribution depresses Readiness; more positive raises it. Ranked by magnitude.
        let contribution: Double
    }

    struct ReadinessResult: Equatable {
        let readiness: Double      // 0…100
        let zone: ReadinessZone
        let factors: [ReadinessFactor]   // ranked desc by |contribution|, top-N
        let confidence: Double     // 0…1 (reported separately, NOT folded into `readiness`)
        /// True when at least one signal z was absent (excluded with weight renormalization).
        let missingSignals: Bool
    }

    // MARK: - Fixed sign-constrained logistic coefficients (named constants — NOT fitted)

    /// FIXED, sign-locked population-prior weights. Every weight is POSITIVE because every input z
    /// is already "+z = better" (BaselineEngine sign convention). HRV is the strongest physiological
    /// readiness signal, sleep next, RHR a corroborating cardiovascular signal; the subjective trend
    /// is a light nudge. These are NOT per-user learned (GA-2).
    enum Weights {
        /// HRV — strongest autonomic-recovery signal.
        static let hrv: Double = 0.9
        /// Sleep — primary recovery driver.
        static let sleep: Double = 0.7
        /// Resting HR — corroborating cardiovascular signal.
        static let rhr: Double = 0.6
        /// Subjective / wellness trend slope — light directional nudge.
        static let subjectiveTrend: Double = 0.3
    }

    enum Constants {
        /// Logistic intercept. b0 = 0 ⇒ all-baseline (every z == 0) maps to logistic(0) = 0.5 →
        /// Readiness 50 (a neutral "at your baseline" day).
        static let intercept: Double = 0.0
        /// Zone cut on the 0…100 Readiness scale: below ⇒ `.low`.
        static let zoneLowCut: Double = 40.0
        /// Zone cut on the 0…100 Readiness scale: at/above ⇒ `.high`.
        static let zoneHighCut: Double = 65.0
        /// Number of ranked factors surfaced.
        static let topFactorCount: Int = 4
    }

    // MARK: - Fusion

    static func compute(_ input: ReadinessInput) -> ReadinessResult {
        // Present components: (label, z, fixed weight). Absent (nil) z's are simply not appended →
        // their weight is renormalized away by the proportional sum below (NO mean-imputation).
        var components: [(label: String, z: Double, weight: Double)] = []
        var missing = false

        if let z = input.hrvZ {
            components.append(("Heart Rate Variability", z, Weights.hrv))
        } else { missing = true }

        if let z = input.sleepZ {
            components.append(("Sleep", z, Weights.sleep))
        } else { missing = true }

        if let z = input.rhrZ {
            components.append(("Resting Heart Rate", z, Weights.rhr))
        } else { missing = true }

        if let slope = input.subjectiveTrendSlope {
            components.append(("Subjective Trend", slope, Weights.subjectiveTrend))
        }
        // Note: the subjective trend is genuinely optional (not one of the 3 core signals), so its
        // absence does NOT set `missingSignals` — that flag tracks the core HRV/RHR/sleep triad.

        // Renormalize the present weights so the logit scale is comparable regardless of how many
        // core signals are present. Fixed reference = the sum of all core weights (HRV+sleep+RHR);
        // the subjective trend rides on top of the renormalized core (small additive nudge).
        let coreReference = Weights.hrv + Weights.sleep + Weights.rhr
        let presentCoreWeight = components
            .filter { $0.label != "Subjective Trend" }
            .reduce(0.0) { $0 + $1.weight }

        var logit = Constants.intercept
        var factors: [ReadinessFactor] = []

        if presentCoreWeight > 0 {
            for c in components {
                let normWeight: Double
                if c.label == "Subjective Trend" {
                    // Additive nudge — not part of the core renormalization.
                    normWeight = c.weight
                } else {
                    normWeight = c.weight / presentCoreWeight * coreReference
                }
                let contribution = normWeight * c.z
                logit += contribution
                factors.append(ReadinessFactor(label: c.label, z: c.z, contribution: contribution))
            }
        }

        let readiness = 100.0 * logistic(logit)

        let ranked = factors
            .sorted { abs($0.contribution) > abs($1.contribution) }
            .prefix(Constants.topFactorCount)

        return ReadinessResult(
            readiness: readiness,
            zone: zone(for: readiness),
            factors: Array(ranked),
            confidence: clamp01(input.confidence),
            missingSignals: missing
        )
    }

    // MARK: - Zone mapping

    /// Boundary convention: `< zoneLowCut` ⇒ .low; `[zoneLowCut, zoneHighCut)` ⇒ .moderate;
    /// `>= zoneHighCut` ⇒ .high.
    static func zone(for readiness: Double) -> ReadinessZone {
        switch readiness {
        case ..<Constants.zoneLowCut: return .low
        case Constants.zoneLowCut..<Constants.zoneHighCut: return .moderate
        default: return .high
        }
    }

    // MARK: - Helpers

    /// Numerically stable standard logistic `1 / (1 + e^{-x})`.
    static func logistic(_ x: Double) -> Double {
        if x >= 0 {
            return 1.0 / (1.0 + exp(-x))
        } else {
            let e = exp(x)
            return e / (1.0 + e)
        }
    }

    private static func clamp01(_ x: Double) -> Double {
        Swift.min(1.0, Swift.max(0.0, x))
    }
}
