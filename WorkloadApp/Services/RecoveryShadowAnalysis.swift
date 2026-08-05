import Foundation

/// Reads `RecoveryShadowDay` rows and reports **how far apart the two recovery arms actually
/// are**. Report-only: nothing here flips a flag, and no caller may treat its output as a
/// decision (the `CrossModalShadowGate.validationSummary` discipline).
///
/// ## Why divergence, and not "which one is right"
///
/// Answering "which arm is better" needs an OUTCOME to grade both against, and no honest one
/// exists yet. The obvious candidates are already inside the thing being tested:
///
/// - **The wellness check-in is 25% of BOTH scores.** Grading either arm against wellness
///   rewards whichever arm leans on wellness hardest, no matter what its physiology does.
/// - **A subjective post-session rating is contaminated by the app itself** — an athlete told
///   this morning that they are recovered is primed to report feeling recovered. The sleep-v2
///   review rejected exactly this proxy for exactly this reason.
///
/// A fair outcome must be neither an input to the scores nor influenced by seeing them, and
/// defining one is its own piece of work. Until it exists, this type answers the question the
/// data CAN answer honestly: **if the estimator were swapped, how much would the athlete's
/// numbers move, and on which days would the two disagree?** That is what makes a flip
/// decision informed rather than blind — and if the arms barely differ, the flip is
/// low-stakes regardless of which is theoretically better.
struct RecoveryShadowAnalysis {

    /// One reading of the divergence between the arms.
    struct Divergence: Equatable {
        /// Days where BOTH arms produced a score (the only comparable ones).
        let pairedDayCount: Int
        /// Days recorded in total, including those v2 declined to score.
        let recordedDayCount: Int
        /// Mean absolute difference in score points.
        let meanAbsoluteDifference: Double?
        /// Largest single-day difference in score points.
        let maxAbsoluteDifference: Double?
        /// Signed mean (v2 − v1): positive means v2 reads higher on average.
        let meanSignedDifference: Double?
        /// Rank agreement between the arms, −1…1. High rho with a non-zero mean difference
        /// means the arms ORDER days the same way but sit at different levels — a very
        /// different (and much safer) situation than genuine disagreement about which days
        /// were good.
        let rankCorrelation: Double?
        /// Days where the two arms fall in different recovery zones — the operationally
        /// meaningful disagreements, because the zone is what drives a recommendation.
        let zoneDisagreementCount: Int
    }

    /// Compute the divergence over the supplied rows.
    ///
    /// - Parameter rows: shadow days, any order. Rows whose v2 arm declined to score are
    ///   counted in `recordedDayCount` but excluded from every paired statistic — a day the
    ///   estimator honestly had no opinion on is not evidence of agreement.
    static func divergence(rows: [RecoveryShadowDay]) -> Divergence {
        let paired: [(v1: Double, v2: Double)] = rows.compactMap { row in
            guard let v2 = row.v2BaseScore else { return nil }
            return (row.v1BaseScore, v2)
        }
        guard !paired.isEmpty else {
            return Divergence(
                pairedDayCount: 0,
                recordedDayCount: rows.count,
                meanAbsoluteDifference: nil,
                maxAbsoluteDifference: nil,
                meanSignedDifference: nil,
                rankCorrelation: nil,
                zoneDisagreementCount: 0
            )
        }

        let differences = paired.map { $0.v2 - $0.v1 }
        let absolute = differences.map { Swift.abs($0) }
        let zoneDisagreements = paired.filter {
            RecoveryZone.classify(score: $0.v1) != RecoveryZone.classify(score: $0.v2)
        }.count

        return Divergence(
            pairedDayCount: paired.count,
            recordedDayCount: rows.count,
            meanAbsoluteDifference: absolute.reduce(0, +) / Double(absolute.count),
            maxAbsoluteDifference: absolute.max(),
            meanSignedDifference: differences.reduce(0, +) / Double(differences.count),
            rankCorrelation: paired.count >= 3
                ? ShadowMetrics.spearmanRho(pairs: paired.map { (predicted: $0.v2, actual: $0.v1) })
                : nil,
            zoneDisagreementCount: zoneDisagreements
        )
    }
}
