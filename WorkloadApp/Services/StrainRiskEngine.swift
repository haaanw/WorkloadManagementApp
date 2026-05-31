import Foundation

/// Pure, deterministic **Strain-Risk** fusion (Phase 27, Wave 3).
///
/// Fuses the Phase-27 substrate — strength-load elevation (Wave 1 `StrengthLoadEngine`),
/// gated Foster monotony/strain (Wave 2 `LoadDistributionEngine`), endurance-load elevation
/// vs personal baseline (`BaselineEngine`, supplied precomputed), the `FatigueIndexEngine`
/// composite, soft-tissue memory + same-region recurrence (`NiggleInjuryDeriver` via the
/// fatigue path + `StrengthLoadEngine.recurrenceFlags`), and rest-debt — into a single 0–1
/// Strain-Risk score, a categorical `StrainRiskZone`, ranked human-readable factors, and a
/// 0–1 confidence.
///
/// ## What this is (and is NOT)
/// An HONEST heuristic **load-tolerance / overreaching-caution** flag (D-27-01, codex §301).
/// It is a FIXED sign-constrained **glass-box** weighted sum — NOT a logistic model, NOT
/// fitted, NOT per-user tuned (that is Readiness, Phase 28). It is NEVER injury prediction:
/// no factor label or zone copy contains injury-prediction language (string-audit tested).
///
/// ## Phase-27 isolation invariant
/// Display/shadow context ONLY this phase. Its output does NOT reach the live
/// `AutoregulationEngine` recommendation or `RecoveryScoreEngine` (grep-verified == 0).
///
/// ## Purity + redistribution (mirrors FatigueIndexEngine, lines 169–238)
/// Pure static struct, Foundation-only. Each component is clamped 0…1 and multiplied by its
/// FIXED named weight; when a component is absent its weight is redistributed PROPORTIONALLY
/// over the present components (NO mean-imputation). Every component contributes
/// non-negatively toward risk (sign-constrained): raising any single risk input never lowers
/// the score.
struct StrainRiskEngine {

    // MARK: - Output contracts

    struct StrainRiskFactor: Equatable {
        let label: String
        /// This factor's contribution to the 0…1 score (weight-after-redistribution × value).
        let contribution: Double
    }

    struct StrainRiskResult: Equatable {
        let score: Double          // 0…1
        let zone: StrainRiskZone
        let factors: [StrainRiskFactor]   // ranked desc by contribution, top-N
        let confidence: Double     // 0…1
    }

    /// One fusion input bundle. All upstream results are passed in — the engine performs NO
    /// SwiftData fetches and calls no stateful service.
    struct Input {
        let strengthLoad: StrengthLoadEngine.StrengthLoadResult
        let loadDistribution: LoadDistributionEngine.LoadDistributionResult
        /// Precomputed FatigueIndexEngine result (its `index`, `restDebt`, `softTissueRisk`).
        let fatigue: FatigueIndexEngine.FatigueResult
        /// Endurance-load elevation vs personal baseline, 0…1 (from BaselineEngine z),
        /// `nil` when the personal baseline is not yet usable (component then absent).
        let enduranceLoadElevation: Double?
        /// BaselineEngine composite confidence for the endurance baseline (nil ⇒ treated as 0).
        let baselineConfidence: Double?

        init(
            strengthLoad: StrengthLoadEngine.StrengthLoadResult,
            loadDistribution: LoadDistributionEngine.LoadDistributionResult,
            fatigue: FatigueIndexEngine.FatigueResult,
            enduranceLoadElevation: Double? = nil,
            baselineConfidence: Double? = nil
        ) {
            self.strengthLoad = strengthLoad
            self.loadDistribution = loadDistribution
            self.fatigue = fatigue
            self.enduranceLoadElevation = enduranceLoadElevation
            self.baselineConfidence = baselineConfidence
        }
    }

    // MARK: - Fixed sign-constrained weights (named constants — NOT fitted, NOT logistic)

    /// Every weight is POSITIVE (sign-constrained): each component pushes the score UP only.
    enum Weights {
        /// Strength-load elevation — the structural moat input (competitive §3.1), highest weight.
        static let strengthLoadElevation: Double = 0.30
        /// Endurance-load elevation vs personal baseline.
        static let enduranceLoadElevation: Double = 0.15
        /// FatigueIndexEngine composite (FEA lineage).
        static let fatigueIndex: Double = 0.20
        /// Gated Foster monotony/strain (full weight when computed; reduced when fallback).
        static let monotonyStrain: Double = 0.15
        /// Reduced weight applied to the fallback load signal when the monotony gate fell back.
        static let monotonyStrainFallback: Double = 0.07
        /// Soft-tissue memory (single source = FatigueResult.softTissueRisk) + recurrence bonus.
        static let softTissue: Double = 0.12
        /// Rest debt (FatigueIndexEngine only, D-27-05).
        static let restDebt: Double = 0.08
    }

    enum Constants {
        /// Normaliser for monotony when the gate computed it (typical Foster monotony 1…3+).
        static let monotonyNormaliser: Double = 3.0
        /// Each same-region recurrence flag adds this to the soft-tissue component (clamped).
        static let recurrenceBonusPerRegion: Double = 0.15
        /// Zone thresholds on the 0…1 score.
        static let zoneModerateCut: Double = 0.25
        static let zoneElevatedCut: Double = 0.50
        static let zoneHighCut: Double = 0.70
        /// Number of ranked factors surfaced.
        static let topFactorCount: Int = 4
    }

    // MARK: - Fusion (Task 2)

    static func fuse(_ input: Input) -> StrainRiskResult {
        // Each present component: (label, value 0…1, weight). Absent components are simply
        // not appended → their weight is redistributed by the normalising sum below.
        var components: [(label: String, value: Double, weight: Double)] = []

        // 1. Strength-load elevation — max per-muscle elevation (highest weight).
        let maxStrengthElevation = input.strengthLoad.perMuscle.values.map(\.elevation).max() ?? 0
        components.append(("Per-muscle strength-load elevation", clamp01(maxStrengthElevation), Weights.strengthLoadElevation))

        // 2. Endurance-load elevation (absent when nil ⇒ weight redistributed).
        if let endurance = input.enduranceLoadElevation {
            components.append(("Endurance-load above personal baseline", clamp01(endurance), Weights.enduranceLoadElevation))
        }

        // 3. FatigueIndex composite — but EXCLUDING its internal soft-tissue + rest-debt
        //    contributions (Finding 1 / GA-30-A). The composite `index` folds softTissueRisk
        //    (internal w 0.10) and restDebt (internal w 0.15); components 5 and 6 below re-add
        //    those standalone, so consuming the full `index` here double-counts them. Re-derive
        //    a "fatigue without soft-tissue / rest-debt" value from the exposed component fields
        //    so each underlying signal contributes exactly once.
        components.append(("Accumulated fatigue", fatigueExcludingSoftTissueRestDebt(input.fatigue), Weights.fatigueIndex))

        // 4. Monotony/strain — gated. Computed WITH monotony → normalized monotony at full
        //    weight; fell back (or W2 defence: computed-but-nil monotony) → fallbackLoadSignal at
        //    reduced weight, honestly labeled.
        switch input.loadDistribution.gateState {
        case .computed:
            // W2 (Wave-5) defence: after the single-series fix .computed ⇒ monotony non-nil, but
            // if a residual .computed-with-nil ever arrives, degrade to the SAME reduced-weight
            // fallback as .fellBack — never read 0-at-full-weight (zero-monotony-at-high-confidence).
            if let m = input.loadDistribution.monotony {
                components.append(("Training-load monotony", clamp01(m / Constants.monotonyNormaliser), Weights.monotonyStrain))
            } else {
                components.append(("Load distribution: limited data — using fallback",
                                   clamp01(input.loadDistribution.fallbackLoadSignal),
                                   Weights.monotonyStrainFallback))
            }
        case .fellBack:
            components.append(("Load distribution: limited data — using fallback",
                               clamp01(input.loadDistribution.fallbackLoadSignal),
                               Weights.monotonyStrainFallback))
        }

        // 5. Soft-tissue (SINGLE source: FatigueResult.softTissueRisk) + same-region recurrence bonus.
        let recurrenceBonus = Double(input.strengthLoad.recurrenceFlags.count) * Constants.recurrenceBonusPerRegion
        let softTissue = clamp01(input.fatigue.softTissueRisk + recurrenceBonus)
        components.append(("Soft-tissue memory", softTissue, Weights.softTissue))

        // 6. Rest debt (FatigueIndexEngine only).
        components.append(("Rest debt", clamp01(input.fatigue.restDebt), Weights.restDebt))

        // Weighted sum, renormalized over PRESENT components (redistribution, not imputation).
        let totalWeight = components.reduce(0) { $0 + $1.weight }
        let score: Double
        var factors: [StrainRiskFactor] = []
        if totalWeight > 0 {
            var acc = 0.0
            for c in components {
                let normWeight = c.weight / totalWeight
                let contribution = c.value * normWeight
                acc += contribution
                factors.append(StrainRiskFactor(label: c.label, contribution: contribution))
            }
            score = clamp01(acc)
        } else {
            score = 0
        }

        // Rank factors desc by contribution, top-N.
        let ranked = factors
            .sorted { $0.contribution > $1.contribution }
            .prefix(Constants.topFactorCount)

        return StrainRiskResult(
            score: score,
            zone: zone(for: score),
            factors: Array(ranked),
            confidence: confidence(input)
        )
    }

    // MARK: - Zone mapping

    static func zone(for score: Double) -> StrainRiskZone {
        switch score {
        case ..<Constants.zoneModerateCut: return .low
        case Constants.zoneModerateCut..<Constants.zoneElevatedCut: return .moderate
        case Constants.zoneElevatedCut..<Constants.zoneHighCut: return .elevated
        default: return .high
        }
    }

    // MARK: - De-double-counted fatigue (Finding 1 / GA-30-A)

    /// FatigueIndex internal component weights, re-declared locally because they are `private`
    /// in `FatigueIndexEngine` (cited: FatigueIndexEngine.swift L83-88: load 0.20, density 0.20,
    /// recovery 0.20, restDebt 0.15, wellness 0.15, softTissue 0.10). Re-declaring avoids a
    /// cross-engine API change / blast radius; `FatigueResult` already exposes every field.
    private enum FatigueInternalWeights {
        static let load: Double = 0.20
        static let density: Double = 0.20
        static let recovery: Double = 0.20
        static let wellness: Double = 0.15
        // Excluded from the re-normalisation (counted standalone in comps 5/6):
        // restDebt 0.15, softTissue 0.10.
        /// Sum of the four retained (non-soft-tissue, non-rest-debt) weights.
        static let retainedSum: Double = load + density + recovery + wellness // 0.75
    }

    /// Re-compose a FatigueIndex-style 0…1 value from ONLY the four components that are NOT
    /// soft-tissue or rest-debt, re-normalised over their retained weights (0.75). This is the
    /// "Accumulated fatigue" signal stripped of the soft-tissue (comp 5) and rest-debt (comp 6)
    /// contributions so those are not double-counted (Finding 1 / GA-30-A). The
    /// `FatigueResult.loadElevation/sessionDensity/recoveryTrend/wellnessTrend` fields are each
    /// already 0…1 component scores.
    static func fatigueExcludingSoftTissueRestDebt(_ f: FatigueIndexEngine.FatigueResult) -> Double {
        let weighted = f.loadElevation * FatigueInternalWeights.load
            + f.sessionDensity * FatigueInternalWeights.density
            + f.recoveryTrend * FatigueInternalWeights.recovery
            + f.wellnessTrend * FatigueInternalWeights.wellness
        return clamp01(weighted / FatigueInternalWeights.retainedSum)
    }

    // MARK: - Confidence

    /// Composite 0…1 confidence: baseline confidence (nil ⇒ 0) × monotony-gate factor ×
    /// scored-coverage blend × chronic-baseline-coverage blend. Any one being low pulls the
    /// product down (honest).
    static func confidence(_ input: Input) -> Double {
        let baselineConf = clamp01(input.baselineConfidence ?? 0)

        let gateFactor: Double
        switch input.loadDistribution.gateState {
        case .computed: gateFactor = 1.0
        case .fellBack: gateFactor = 0.5
        }

        // Scored-coverage ratio (Finding 5 / GA-30-E): fraction of working sets that were
        // SCORED (hard + easy) vs unscored. Previously this used only hardSets, so an all-easy
        // fully-scored session reported coverage 0 — now it reports 1.0.
        let hardSets = input.strengthLoad.perMuscle.values.reduce(0) { $0 + $1.hardSetCount }
        let easySets = input.strengthLoad.perMuscle.values.reduce(0) { $0 + $1.easyCount }
        let unscored = input.strengthLoad.perMuscle.values.reduce(0) { $0 + $1.unscoredCount }
        let scored = hardSets + easySets
        let coverageTotal = scored + unscored
        let coverage = coverageTotal > 0 ? Double(scored) / Double(coverageTotal) : 0.0

        // Chronic-baseline coverage (Finding 3 / GA-30-C consumption): fraction of contributing
        // muscles that have an established chronic-exclusive baseline. A heavy session made up
        // entirely of new exercises (no chronic baseline) reads as LOW-confidence — not silently
        // safe, not high-strain. Blended the same shape as coverage so a present baseline is
        // never zeroed but a missing one pulls honestly downward.
        let muscleCount = input.strengthLoad.perMuscle.count
        let withBaseline = input.strengthLoad.perMuscle.values.filter { $0.hasChronicBaseline }.count
        let baselineCoverage = muscleCount > 0 ? Double(withBaseline) / Double(muscleCount) : 0.0

        // Blend so a present baseline dominates but coverage, gate, and baseline-coverage modulate it.
        let raw = baselineConf * gateFactor * (0.5 + 0.5 * coverage) * (0.5 + 0.5 * baselineCoverage)
        return clamp01(raw)
    }

    // MARK: - Helpers

    private static func clamp01(_ x: Double) -> Double {
        Swift.min(1.0, Swift.max(0.0, x))
    }
}
