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
                    "Go Zone — Full Send",
                    "Recovery is high and load is in the sweet spot. Ideal day for PR attempts, high-intensity intervals, plyometrics, or max effort training.")

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
