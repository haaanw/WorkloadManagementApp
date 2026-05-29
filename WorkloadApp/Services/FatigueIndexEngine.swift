import Foundation

/// Computes a cumulative Fatigue Accumulation Index (0-100) from evidence-based
/// training stress primitives. Unlike ACWR (which is invalidated as a predictor,
/// per Impellizzeri 2020-21), this uses primitives with independent evidentiary
/// support: cumulative load, session density, rest debt, recovery trajectory,
/// subjective wellness trend, and soft-tissue injury history.
///
/// Pure struct with static methods — no state, no dependencies.
///
/// Weights (Codex-reviewed, 2026-04-30):
///   Load elevation:      0.20
///   Session density:     0.20
///   Recovery trend:      0.20
///   Rest debt / streak:  0.15
///   Wellness trend:      0.15
///   Soft-tissue flag:    0.10
struct FatigueIndexEngine {

    // MARK: - Types

    struct FatigueInput {
        /// Recent session TSS values (last 14 days, newest last)
        let recentSessionTSS: [Double]
        /// Personal average session TSS (from longer history, e.g. 90 days)
        let baselineSessionTSS: Double?
        /// Number of training sessions in last 14 days
        let sessionsIn14Days: Int
        /// Personal average sessions per 14-day window
        let baselineSessionsIn14Days: Double?
        /// Consecutive training days without rest (0 = rested today)
        let trainingStreakDays: Int
        /// Days since last rest period (2+ consecutive rest days)
        let daysSinceRestPeriod: Int?
        /// Recovery scores for last 7 days (oldest first) for trend
        let recentRecoveryScores: [Double]
        /// Wellness scores for last 7 days (oldest first) for trend
        let recentWellnessScores: [Double]
        /// Number of soft-tissue injuries in last 12 months
        let softTissueInjuryCount: Int
        /// Days since most recent soft-tissue injury (nil = none)
        let daysSinceLastInjury: Int?
    }

    struct FatigueResult {
        let index: Double           // 0-100 (higher = more fatigued)
        let zone: FatigueZone
        let loadElevation: Double   // 0-1 component score
        let sessionDensity: Double  // 0-1 component score
        let recoveryTrend: Double   // 0-1 component score
        let restDebt: Double        // 0-1 component score
        let wellnessTrend: Double   // 0-1 component score
        let softTissueRisk: Double  // 0-1 component score
    }

    enum FatigueZone: String {
        case low        // < 35: baseline fatigue
        case elevated   // 35-55: schedule modification advisable
        case high       // 55-75: individual workload management warranted
        case saturation // > 75: rotate or rest

        static func classify(index: Double) -> FatigueZone {
            switch index {
            case ..<35: return .low
            case 35..<55: return .elevated
            case 55..<75: return .high
            default: return .saturation
            }
        }

        var displayName: String {
            switch self {
            case .low: "Low"
            case .elevated: "Elevated"
            case .high: "High"
            case .saturation: "Very High"
            }
        }
    }

    // MARK: - Weights

    private static let loadWeight: Double = 0.20
    private static let densityWeight: Double = 0.20
    private static let recoveryWeight: Double = 0.20
    private static let restDebtWeight: Double = 0.15
    private static let wellnessWeight: Double = 0.15
    private static let softTissueWeight: Double = 0.10

    // MARK: - Compute

    /// Fraction of the recoveryTrend component's contribution retained in the luteal
    /// bucket when dampening is active (D-10). 0.5 = halve the residual cyclic variance
    /// that the Phase 18 same-phase recovery baseline has not already removed.
    private static let lutealRecoveryTrendRetention: Double = 0.5

    /// Cycle-aware overload (Phase 20, D-10). Additive and non-breaking: `cycleContext == nil`
    /// returns output byte-identical to `compute(input:)` (D-12).
    ///
    /// Hypothesis (D-10, double-counting): luteal progesterone suppresses HRV / raises RHR,
    /// which the Phase 18 same-phase recovery baseline already corrects in the recovery
    /// component — but `recoveryTrend` consumes recovery scores that may carry residual
    /// cyclic variance, inflating fatigue in the luteal bucket. When eligible AND activated
    /// AND the phase buckets to luteal, the recoveryTrend contribution is dampened.
    ///
    /// Because `CycleModifierActivation.isEnabled` is false this phase, `shouldApply` is
    /// false → the returned index is UNCHANGED. The would-be dampened index is computable
    /// via `lutealDampenedIndex(input:cycleContext:)` for shadow logging.
    static func compute(
        input: FatigueInput,
        cycleContext: CycleContext?,
        cyclesObserved: Int = 0
    ) -> FatigueResult {
        let base = compute(input: input)

        guard let cycleContext,
              CycleModifierGate.shouldApply(context: cycleContext, cyclesObserved: cyclesObserved),
              RecoveryScoreEngine.bucket(for: cycleContext.phase) == .luteal else {
            return base  // nil context / ineligible / not luteal → identical (D-12 / D-06)
        }

        return dampenedResult(from: base, input: input)
    }

    /// The would-be dampened fatigue index (0–100), computable regardless of activation
    /// so Plan 03 can shadow-log it. Returns the unchanged index when the phase does not
    /// bucket to luteal (phase contributes nothing outside the luteal half).
    static func lutealDampenedIndex(input: FatigueInput, cycleContext: CycleContext) -> Double {
        let base = compute(input: input)
        guard RecoveryScoreEngine.bucket(for: cycleContext.phase) == .luteal else {
            return base.index
        }
        return dampenedResult(from: base, input: input).index
    }

    /// Recompute the weighted index with the recoveryTrend component dampened toward the
    /// neutral 0.5 by `lutealRecoveryTrendRetention`. Re-uses the existing component scores
    /// and weight set so only the recoveryTrend contribution changes.
    private static func dampenedResult(from base: FatigueResult, input: FatigueInput) -> FatigueResult {
        // Dampen residual cyclic variance: pull recoveryTrend toward neutral (0.5).
        let dampenedRecoveryTrend = 0.5 + (base.recoveryTrend - 0.5) * lutealRecoveryTrendRetention

        let components: [(score: Double, weight: Double)] = [
            (base.loadElevation, loadWeight),
            (base.sessionDensity, densityWeight),
            (dampenedRecoveryTrend, recoveryWeight),
            (base.restDebt, restDebtWeight),
            (base.wellnessTrend, wellnessWeight),
            (base.softTissueRisk, softTissueWeight)
        ]
        let totalWeight = components.reduce(0) { $0 + $1.weight }
        let rawIndex = components.reduce(0.0) { $0 + $1.score * ($1.weight / totalWeight) }
        let index = clamp(rawIndex * 100, min: 0, max: 100)

        return FatigueResult(
            index: index,
            zone: FatigueZone.classify(index: index),
            loadElevation: base.loadElevation,
            sessionDensity: base.sessionDensity,
            recoveryTrend: dampenedRecoveryTrend,
            restDebt: base.restDebt,
            wellnessTrend: base.wellnessTrend,
            softTissueRisk: base.softTissueRisk
        )
    }

    /// Compute fatigue accumulation index from available inputs.
    /// Missing components are redistributed proportionally.
    static func compute(input: FatigueInput) -> FatigueResult {
        var components: [(score: Double, weight: Double)] = []

        // 1. Load elevation: recent load vs personal baseline
        let loadScore = computeLoadElevation(
            recentTSS: input.recentSessionTSS,
            baseline: input.baselineSessionTSS
        )
        components.append((loadScore, loadWeight))

        // 2. Session density: sessions in 14 days vs personal baseline
        let densityScore = computeSessionDensity(
            sessionsIn14Days: input.sessionsIn14Days,
            baseline: input.baselineSessionsIn14Days
        )
        components.append((densityScore, densityWeight))

        // 3. Recovery trend: declining recovery = more fatigue
        let recoveryTrendScore: Double
        if input.recentRecoveryScores.count >= 3 {
            recoveryTrendScore = computeRecoveryTrendFatigue(scores: input.recentRecoveryScores)
            components.append((recoveryTrendScore, recoveryWeight))
        } else {
            recoveryTrendScore = 0.5  // neutral if insufficient data
            components.append((recoveryTrendScore, recoveryWeight))
        }

        // 4. Rest debt / training streak (combined)
        let restDebtScore = computeRestDebt(
            streakDays: input.trainingStreakDays,
            daysSinceRestPeriod: input.daysSinceRestPeriod
        )
        components.append((restDebtScore, restDebtWeight))

        // 5. Wellness trend: declining wellness = more fatigue
        let wellnessTrendScore: Double
        if input.recentWellnessScores.count >= 3 {
            wellnessTrendScore = computeWellnessTrendFatigue(scores: input.recentWellnessScores)
            components.append((wellnessTrendScore, wellnessWeight))
        } else {
            wellnessTrendScore = 0.5
            components.append((wellnessTrendScore, wellnessWeight))
        }

        // 6. Soft-tissue injury flag (time-decayed)
        let softTissueScore = computeSoftTissueRisk(
            injuryCount: input.softTissueInjuryCount,
            daysSinceLastInjury: input.daysSinceLastInjury
        )
        components.append((softTissueScore, softTissueWeight))

        // Weighted sum
        let totalWeight = components.reduce(0) { $0 + $1.weight }
        let rawIndex = components.reduce(0.0) { sum, c in
            sum + c.score * (c.weight / totalWeight)
        }

        let index = clamp(rawIndex * 100, min: 0, max: 100)

        return FatigueResult(
            index: index,
            zone: FatigueZone.classify(index: index),
            loadElevation: loadScore,
            sessionDensity: densityScore,
            recoveryTrend: recoveryTrendScore,
            restDebt: restDebtScore,
            wellnessTrend: wellnessTrendScore,
            softTissueRisk: softTissueScore
        )
    }

    /// Estimate the athlete's normal 14-day session density from the available history.
    /// Sessions must already be scoped to a single athlete.
    static func baselineSessionsPer14Days(
        sessions: [WorkoutSession],
        asOf now: Date = .now,
        maxHistoryDays: Int = 90
    ) -> Double? {
        guard let earliestSessionDate = sessions.map(\.sessionDate).min() else { return nil }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: earliestSessionDate)
        let end = calendar.startOfDay(for: now)
        let observedDays = (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
        let days = min(maxHistoryDays, max(14, observedDays))

        return Double(sessions.count) / Double(days) * 14.0
    }

    // MARK: - Component Scoring (each returns 0-1, higher = more fatigued)

    /// Load elevation: how much recent load exceeds personal baseline.
    /// Uses percentile-like approach (ratio capped at 2x).
    private static func computeLoadElevation(recentTSS: [Double], baseline: Double?) -> Double {
        guard !recentTSS.isEmpty else { return 0.3 }
        let recentMean = recentTSS.reduce(0, +) / Double(recentTSS.count)
        guard let base = baseline, base > 0 else {
            // No baseline — use absolute heuristic (>100 TSS/session is high)
            return clamp(recentMean / 200.0, min: 0, max: 1)
        }
        // Ratio: 1.0 = normal, 1.5 = elevated, 2.0+ = very high
        let ratio = recentMean / base
        return clamp((ratio - 0.5) / 1.5, min: 0, max: 1)
    }

    /// Session density: training frequency vs personal norm.
    private static func computeSessionDensity(sessionsIn14Days: Int, baseline: Double?) -> Double {
        let sessions = Double(sessionsIn14Days)
        guard let base = baseline, base > 0 else {
            // No baseline: 7 sessions/14d = normal, 10+ = elevated
            return clamp(sessions / 14.0, min: 0, max: 1)
        }
        let ratio = sessions / base
        return clamp((ratio - 0.5) / 1.5, min: 0, max: 1)
    }

    /// Recovery trend fatigue: declining recovery scores = increasing fatigue.
    /// Uses slope from RecoveryScoreEngine.computeSlope.
    private static func computeRecoveryTrendFatigue(scores: [Double]) -> Double {
        guard let slope = RecoveryScoreEngine.computeSlope(values: scores) else {
            return 0.5
        }
        // Negative slope = declining recovery = higher fatigue
        // Slope of -5 pts/day → high fatigue (0.83)
        // Slope of 0 → neutral (0.5)
        // Slope of +5 pts/day → low fatigue (0.17)
        return clamp(0.5 - slope / 6.0, min: 0, max: 1)
    }

    /// Rest debt: combined training streak and days since rest period.
    private static func computeRestDebt(streakDays: Int, daysSinceRestPeriod: Int?) -> Double {
        // Training streak component: 0-3 days = low, 5+ = elevated, 7+ = high
        let streakScore = clamp(Double(streakDays) / 10.0, min: 0, max: 1)

        // Days since rest period: normalized against 21 days (3 weeks without
        // a proper rest period is high fatigue)
        let restPeriodScore: Double
        if let days = daysSinceRestPeriod {
            restPeriodScore = clamp(Double(days) / 21.0, min: 0, max: 1)
        } else {
            restPeriodScore = 0.3  // unknown, assume moderate
        }

        // Blend: 60% streak (more actionable), 40% rest period
        return streakScore * 0.6 + restPeriodScore * 0.4
    }

    /// Wellness trend fatigue: declining wellness = increasing fatigue.
    private static func computeWellnessTrendFatigue(scores: [Double]) -> Double {
        guard let slope = RecoveryScoreEngine.computeSlope(values: scores) else {
            return 0.5
        }
        // Same logic as recovery trend
        return clamp(0.5 - slope / 6.0, min: 0, max: 1)
    }

    /// Soft-tissue injury risk: time-decayed flag based on injury count and recency.
    /// Uses exponential decay: recent injuries matter more.
    private static func computeSoftTissueRisk(injuryCount: Int, daysSinceLastInjury: Int?) -> Double {
        guard injuryCount > 0 else { return 0 }

        // Count-based: 1 - exp(-0.5 * n) from research FEA
        let countScore = 1.0 - exp(-0.5 * Double(injuryCount))

        // Time decay: recent injury amplifies, stale injury dampens
        let recencyMultiplier: Double
        if let days = daysSinceLastInjury {
            // 0-30 days: high (1.0), 90 days: moderate (0.5), 180+: low (0.25)
            recencyMultiplier = exp(-Double(days) / 120.0)
        } else {
            recencyMultiplier = 0.5  // unknown recency
        }

        return clamp(countScore * (0.5 + 0.5 * recencyMultiplier), min: 0, max: 1)
    }

    // MARK: - Helpers

    private static func clamp(_ value: Double, min: Double, max: Double) -> Double {
        Swift.min(max, Swift.max(min, value))
    }
}
