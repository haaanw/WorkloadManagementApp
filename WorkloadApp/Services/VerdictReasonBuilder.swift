import Foundation

/// Phase 43 Plan 02 (VERDICT-03) — the pure **one-line verdict reason + separate confidence** assembler.
///
/// Builds the plain-language headline reason for a verdict from the EXISTING
/// `ReasoningEngine.explainDecision` ranked reasons, with two LOCKED guardrails:
///   1. **Cross-modal cause is GATED.** The cross-modal cause line (`CrossModalResult.dominantReason`,
///      e.g. "legs still loaded from recent cross-modal work") is named ONLY when
///      `CrossModalShadowGate.crossModalDrivesVerdict == true` AND cross-modal is the DOMINANT driver
///      for the planned region. While the gate is off, cross-modal is NEVER referenced.
///   2. **Confidence is reported SEPARATELY** — carried in its own `confidence` field, never
///      interpolated into the reason line (research §3.3 "confidence is shown, not folded"). On
///      cold-start / low confidence (`decisionInput == nil` or `deferToPlan == true`) the builder
///      DEFERS to the plan with a fixed defer copy instead of fabricating a trim rationale (the
///      LOCKED honest-confidence guardrail — never trim on a guess).
///
/// ## Pure / Foundation-only
/// Static methods only, no stored state (mirrors `ReasoningEngine`). All user-facing copy via
/// `String(localized:)`, Tuwa voice, and NEVER frames a trim as harm-forecasting (source-grep
/// fenced — the reason copy is a load-tolerance rationale, never a harm claim).
struct VerdictReasonBuilder {

    // MARK: - Public types

    /// The assembled reason + the separately-reported confidence + the cold-start defer marker.
    struct AssembledReason: Equatable {
        /// The single-line plain-language reason (no newlines).
        let reasonLine: String
        /// The readiness confidence (0…1), reported SEPARATELY — never folded into `reasonLine`.
        let confidence: Double
        /// True when the builder deferred to the plan (cold-start / low confidence).
        let deferredToPlan: Bool
    }

    /// Match-proximity context (ADR-0002). Passed ONLY when the engine's proximity rule actually
    /// engaged (a proximity-tightened MODIFY) — the reason line then LEADS with the match:
    /// "Match Saturday — microdose: cap the top set, skip back-offs."
    struct MatchContext: Equatable {
        /// Calendar days to the match: 0 = today, 1 = tomorrow, 2 = the day named by `matchDate`.
        let daysAway: Int
        /// The scheduled match date (start-of-day normalized) — names the actual match day.
        let matchDate: Date
    }

    // MARK: - Tunables

    enum Constants {
        /// A second explainDecision factor is joined onto the headline only when its |contribution|
        /// is within this fraction of the leading factor's (so the line stays single and meaningful).
        static let secondFactorBand: Double = 0.7
    }

    // MARK: - Build

    /// Assemble the one-line reason + separate confidence for a verdict.
    ///
    /// - Parameters:
    ///   - decisionInput: the real `DecisionInput` (readiness + strain + recommendation). `nil` ⇒
    ///     cold-start (the `PRSReadinessInputBuilder.build` returned-nil signal) ⇒ defer.
    ///   - crossModalResult: optional cross-modal carry — its cause is named only under the gate.
    ///   - plannedRegion: the planned lift's region (the cross-modal dominance anchor).
    ///   - deferToPlan: forces the cold-start defer path even when a `decisionInput` is present.
    ///   - matchContext: match-proximity context — pass ONLY when the engine's proximity rule
    ///     engaged; the match then LEADS the line. nil ⇒ behavior exactly unchanged.
    ///   - locale/calendar: for naming the match day ("Saturday" / "周六") — injectable for tests.
    static func build(
        decisionInput: ReasoningEngine.DecisionInput?,
        crossModalResult: CrossModalFatigueEngine.CrossModalResult?,
        plannedRegion: MuscleRegion,
        deferToPlan: Bool,
        matchContext: MatchContext? = nil,
        locale: Locale = .current,
        calendar: Calendar = .current
    ) -> AssembledReason {
        // --- Cold-start defer FIRST (locked honest-confidence guardrail). ---------------------------
        // Never trim on a guess: on cold-start return the defer copy, confidence reported as the
        // readiness confidence if any (else 0), deferredToPlan = true.
        if deferToPlan || decisionInput == nil {
            let deferCopy = String(
                localized: "verdict.reason.defer",
                defaultValue: "Going with your plan — still learning your baseline."
            )
            return AssembledReason(
                reasonLine: deferCopy,
                confidence: decisionInput?.readiness.confidence ?? 0,
                deferredToPlan: true
            )
        }

        let input = decisionInput!   // safe — the guard above returns when nil.

        // --- Headline driver from the ranked explainDecision reasons. -------------------------------
        let reasons = ReasoningEngine.explainDecision(input: input)
        var line = composeHeadline(from: reasons)

        // --- Cross-modal cause, GATED. --------------------------------------------------------------
        // Named ONLY when the gate is on AND cross-modal is the dominant driver for the planned
        // region. While the gate is off, cross-modal is NEVER referenced (the locked rule).
        if CrossModalShadowGate.crossModalDrivesVerdict,
           let cross = crossModalResult,
           let cause = cross.dominantReason,
           crossModalIsDominant(cross, plannedRegion: plannedRegion, against: reasons) {
            // Lead with the cross-modal cause — it is the dominant driver this evaluation.
            line = cause
        }

        // --- Match proximity LEADS (ADR-0002). ------------------------------------------------------
        // When the proximity rule engaged, the athlete's actual job is "arrive fresh for the match" —
        // the match + the microdose shape ARE the reason, so they replace the physiology headline.
        // Never a gate: this is still a suggestion with a reason (the verdict stays suggest-and-confirm).
        if let matchContext {
            line = microdoseLine(for: matchContext, locale: locale, calendar: calendar)
        }

        // Single-line guarantee (collapse any stray newlines).
        line = singleLine(line)

        return AssembledReason(
            reasonLine: line,
            confidence: input.readiness.confidence,   // reported separately, NOT folded in.
            deferredToPlan: false
        )
    }

    // MARK: - Match microdose line (ADR-0002 / CONTEXT.md "Microdose")

    /// "Match Saturday — microdose: cap the top set, skip back-offs." — the match phrase uses the
    /// athlete's actual relative day (today / tomorrow) or the match day's weekday name.
    private static func microdoseLine(
        for context: MatchContext,
        locale: Locale,
        calendar: Calendar
    ) -> String {
        let dayPhrase: String
        switch context.daysAway {
        case 0:
            dayPhrase = String(localized: "verdict.match.today", defaultValue: "Match today")
        case 1:
            dayPhrase = String(localized: "verdict.match.tomorrow", defaultValue: "Match tomorrow")
        default:
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.locale = locale
            formatter.setLocalizedDateFormatFromTemplate("EEEE")
            let dayName = formatter.string(from: context.matchDate)
            dayPhrase = String(
                format: String(localized: "verdict.match.onDay", defaultValue: "Match %@"),
                dayName
            )
        }
        return String(
            format: String(
                localized: "verdict.match.microdose",
                defaultValue: "%@ — microdose: cap the top set, skip back-offs."
            ),
            dayPhrase
        )
    }

    // MARK: - Headline composition

    /// Take `prefix(1)` as the headline; optionally join a `prefix(2)` second factor when its
    /// |contribution| is within `secondFactorBand` of the first (so the line stays single + meaningful).
    private static func composeHeadline(from reasons: [ReasoningEngine.DecisionReason]) -> String {
        guard let first = reasons.first else {
            // No ranked reasons (e.g. all-neutral) — a neutral plan-as-written line, Tuwa voice.
            return String(
                localized: "verdict.reason.planAsWritten",
                defaultValue: "Your signals look steady — training the plan as written."
            )
        }
        guard reasons.count > 1 else { return singleLine(first.text) }

        let second = reasons[1]
        let leadMag = abs(first.contribution)
        let secondMag = abs(second.contribution)
        if leadMag > 0, secondMag >= leadMag * Constants.secondFactorBand, secondMag > 0 {
            let joiner = String(localized: "verdict.reason.joiner", defaultValue: ", and ")
            return singleLine(first.text + joiner + second.text)
        }
        return singleLine(first.text)
    }

    // MARK: - Cross-modal dominance

    /// Whether cross-modal is the DOMINANT down-pressure for `plannedRegion`: its 0…1 region
    /// elevation (the "how loaded is this region from other modalities" signal) exceeds the
    /// magnitude of the leading readiness/strain reason. `.fullBody` uses the max region elevation
    /// (it cannot spare itself). Elevation is already a 0…1 above-personal-normal signal — the
    /// directly-comparable cross-modal down-pressure proxy (research §3.2 dominance check). It
    /// out-presses the leading reason ⇒ the cross-modal cause leads the line.
    private static func crossModalIsDominant(
        _ cross: CrossModalFatigueEngine.CrossModalResult,
        plannedRegion: MuscleRegion,
        against reasons: [ReasoningEngine.DecisionReason]
    ) -> Bool {
        let elevation: Double
        if plannedRegion == .fullBody {
            elevation = cross.perRegionElevation.values.max() ?? 0
        } else {
            elevation = cross.perRegionElevation[plannedRegion] ?? 0
        }
        guard elevation > 0 else { return false }
        let leadingPressure = reasons.map { abs($0.contribution) }.max() ?? 0
        // Cross-modal must out-press the leading readiness/strain factor to lead the line.
        return elevation > leadingPressure
    }

    // MARK: - Helpers

    private static func singleLine(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }
}
