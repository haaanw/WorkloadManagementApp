import Foundation

/// Daily training autoregulation engine.
/// Combines recovery status, ACWR zone, subjective wellness, and training history
/// to produce actionable training recommendations.
///
/// Based on Gabbett's training-injury prevention framework and
/// the Daily Training Load Decision Matrix.
struct AutoregulationEngine {

    struct DailyInput {
        let recoveryZone: RecoveryZone
        let recoveryScore: Double       // 0-100
        let acwrZone: ACWRZone
        let acwr: Double
        let wellnessScore: Double?       // 0-100
        let daysSinceLastRest: Int
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

            var message: String {
                switch self {
                case .acwrDanger:
                    "ACWR > 1.5 — High injury risk. Significantly reduce load."
                case .acwrCaution:
                    "ACWR 1.3-1.5 — Elevated risk. Monitor closely."
                case .recoveryRed:
                    "Recovery score is low. Prioritize rest and parasympathetic activities."
                case .consecutiveTrainingDays(let days):
                    "\(days) consecutive training days. Consider scheduling a rest day."
                case .lowWellness:
                    "Subjective wellness is low. Listen to your body."
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

        // Decision matrix: recovery zone × ACWR zone
        let result: (cap: Double, vol: Double, type: TrainingRecommendation.RecommendedSessionType, headline: String, detail: String)

        switch (input.recoveryZone, input.acwrZone) {

        // RED recovery — always limit
        case (.red, .danger), (.red, .caution):
            result = (5.0, 0.0, .rest,
                      "Full Rest Day",
                      "Both recovery and load indicators suggest you need complete rest. Focus on sleep, nutrition, and parasympathetic activities (breathing drills, light walking).")

        case (.red, .optimal), (.red, .undertrained), (.red, .noData):
            result = (5.0, 0.5, .activeRecovery,
                      "Active Recovery Only",
                      "Your body needs recovery. Light movement (Zone 1-2 cardio, mobility work, foam rolling) only. Reduce volume by 50% and cap intensity.")

        // YELLOW recovery
        case (.yellow, .danger):
            result = (6.0, 0.5, .activeRecovery,
                      "Light Day — Load Is High",
                      "Your ACWR is elevated and recovery is moderate. Reduce volume by 50% and keep intensity low. Consider this a deload opportunity.")

        case (.yellow, .caution):
            result = (7.0, 0.75, .conditioning,
                      "Moderate Day — Stay Controlled",
                      "Recovery is fair but load is building. Maintain volume at 75% and cap RPE at 7. Avoid max effort sets.")

        case (.yellow, .optimal):
            result = (8.0, 0.75, .hypertrophy,
                      "Moderate Training OK",
                      "Recovery is moderate. Train at 75% volume, cap RPE at 8. Good day for hypertrophy or moderate conditioning work.")

        case (.yellow, .undertrained), (.yellow, .noData):
            result = (8.0, 1.0, .strength,
                      "Build Load Gradually",
                      "Your chronic load is low. Use today to progressively build capacity, but don't push past RPE 8 given moderate recovery.")

        // GREEN recovery
        case (.green, .danger):
            result = (7.0, 0.75, .conditioning,
                      "Feeling Good, But Load Is High",
                      "Recovery is great, but your ACWR is elevated. Don't let good recovery mask accumulated fatigue. Train at 75% volume, stay controlled.")

        case (.green, .caution):
            result = (8.0, 0.85, .strength,
                      "Train Smart — Approaching Threshold",
                      "You're recovered and your load is building. Good day for quality work, but avoid massive volume spikes. Stay at ~85% planned volume.")

        case (.green, .optimal):
            result = (10.0, 1.0, .power,
                      "Go Zone — Full Send",
                      "Recovery is high and load is in the sweet spot. Ideal day for PR attempts, high-intensity intervals, plyometrics, or max effort training.")

        case (.green, .undertrained), (.green, .noData):
            result = (9.0, 1.0, .strength,
                      "Build Your Base",
                      "You're fresh and your chronic load is low. Great opportunity to progressively build training capacity. Push toward RPE 9.")
        }

        // Override for excessive consecutive training days
        var finalType = result.type
        var finalHeadline = result.headline
        var finalDetail = result.detail
        if input.daysSinceLastRest >= 7 && input.recoveryZone != .green {
            finalType = .rest
            finalHeadline = "Rest Day Recommended"
            finalDetail = "You've trained \(input.daysSinceLastRest) consecutive days without rest. Schedule a recovery day to maintain long-term training quality."
        }

        return TrainingRecommendation(
            intensityCap: result.cap,
            volumeModifier: result.vol,
            sessionType: finalType,
            warnings: warnings,
            headline: finalHeadline,
            detail: finalDetail
        )
    }
}
