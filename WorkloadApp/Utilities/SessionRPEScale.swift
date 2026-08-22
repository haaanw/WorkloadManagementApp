import SwiftUI

/// Verbal anchors for the session-RPE reading (v1.7.2, HAN 2026-08-22).
///
/// **Why the words exist.** The logging demos proposed replacing the 1–10 slider with four
/// buttons, on the true observation that an athlete answers a WORD more accurately than a bare
/// number. That was declined for a measured reason: session RPE is not a display value. It
/// feeds `WorkoutSession.internalLoad`, then `WorkloadCalculator.srpeLoad`, then the unified
/// daily-load series in `LoadDistributionEngine`, then `CrossModalFatigueEngine` — which drives
/// the verdict. Four buckets would inject up to ±1 RPE of error into a verdict input, and for a
/// sport-primary athlete most sessions are ones where sRPE *is* the load. So the scale keeps its
/// resolution and gains the anchors instead, which is what the standard instrument does anyway:
/// Borg's CR-10 is a 0–10 scale WITH verbal anchors, not a set of buttons.
///
/// **Provenance, stated rather than invented.** The anchors are Foster's session-RPE table
/// (1998): 1 very easy, 2 easy, 3 moderate, 4 somewhat hard, 5 hard, 7 very hard, 10 maximal.
/// 6, 8 and 9 are **blank on the published instrument** — the gaps are part of it. Rather than
/// invent words to fill them, a value between anchors shows the nearest anchor AT OR BELOW it,
/// which is how the printed chart is read: 6 sits above "hard" and below "very hard", and the
/// numeral carries the finer distinction the word cannot.
///
/// This is why two adjacent values can show the same word. That is the instrument, not a defect.
enum SessionRPEScale {

    /// A published anchor point on the CR-10 session-RPE scale.
    enum Anchor: Int, CaseIterable {
        case veryEasy = 1
        case easy = 2
        case moderate = 3
        case somewhatHard = 4
        case hard = 5
        case veryHard = 7
        case maximal = 10

        var labelKey: LocalizedStringKey {
            switch self {
            case .veryEasy: "rpe.anchor.veryEasy"
            case .easy: "rpe.anchor.easy"
            case .moderate: "rpe.anchor.moderate"
            case .somewhatHard: "rpe.anchor.somewhatHard"
            case .hard: "rpe.anchor.hard"
            case .veryHard: "rpe.anchor.veryHard"
            case .maximal: "rpe.anchor.maximal"
            }
        }
    }

    /// The anchor a reading is read against: the highest published anchor at or below it.
    /// Values under 1 clamp to the lowest anchor, since the app's slider floors at 1.
    static func anchor(for rpe: Int) -> Anchor {
        Anchor.allCases
            .filter { $0.rawValue <= rpe }
            .max(by: { $0.rawValue < $1.rawValue })
            ?? .veryEasy
    }

    /// Convenience for a call site holding the slider's `Double`.
    static func anchor(for rpe: Double) -> Anchor {
        anchor(for: Int(rpe.rounded()))
    }
}
