import SwiftUI

/// Phase 44 Plan 02 — the **suggest-and-confirm verdict card**. The nocebo-safe, autonomy-respecting
/// surface the whole v2.0 validation hinges on.
///
/// Presentational ONLY: it takes a `TodayVerdictDisplay` + the athlete's `weightUnit` + a
/// `canStartWorkout` gate + four callbacks (`onAccept` / `onKeepPlan` / `onFeel` / `onStartWorkout`).
/// All data logic lives in `TodayVerdictViewModel`.
///
/// Anti-nocebo / autonomy invariants (DESIGN-fenced by `TodayVerdictCardGuardTests`):
///  - Leads with the ACTION on the plan + one-line reason — never a bare readiness number (SC4).
///  - Accept and Keep-my-plan are EQUAL visual weight via one shared button builder (SC1).
///  - A hold/low verdict reads as a number + reason, never a red gate (SC2): the verdict state is a
///    TEXT LABEL + at most a DESATURATED hairline strip — never the danger-zone token, never the
///    reserved hero color.
///  - Keep-my-plan is one tap, no confirmation nag, no guilt copy (SC3).
///  - Confidence is shown quietly and separately when present (SC4).
///
/// DESIGN.md (hard): 0pt corners (Rectangle only), no shadows, `Font.Tokens.*`, 8pt grid, light-only
/// via `ColorTokens`. Tuwa v2: this is the screen's primary decision surface, so it sits on the
/// emphasis plane (`.emphasisCardStyle()` — `surfaceEl2` + `dividerStrong` + 2pt accent top rule).
/// The accent (now the "live / actionable" semantic) is allowed ONLY on the strike-zone FILL and the
/// emphasis rule — NEVER on the verdict state (that stays a text label + desaturated zone strip) and
/// NEVER on today's number. en defaults inline; zh-Hans in the catalog.
struct TodayVerdictCard: View {

    let display: TodayVerdictDisplay
    let weightUnit: WeightUnit
    /// Whether a resolved workout can actually be produced (the ViewModel's `canStartResolvedWorkout`,
    /// derived from the persisted decision state). The Start CTA renders ONLY when this is true, so it
    /// can never appear and then no-op. Defaults true so existing callers/tests are unaffected.
    var canStartWorkout: Bool = true
    var onAccept: () -> Void
    var onKeepPlan: () -> Void
    var onFeel: (FeelOverride) -> Void
    /// Start the resolved workout once a decision has been made. nil ⇒ no start affordance (e.g. tests
    /// or surfaces that don't own a launch path). Never fires while the decision is still pending —
    /// Accept itself never auto-launches.
    var onStartWorkout: (() -> Void)? = nil

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {

            // 1. Header label (micro-caps — NOT a readiness number).
            Text(String(localized: "verdictCard.title", defaultValue: "TODAY'S PLAN"))
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)

            // 2. Action-on-the-plan hero — NUMBER-LED with a strike-zone bar (lead with today's
            //    number + where it lands in today's productive zone; never a bare readiness score).
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: display.headlineExerciseName)
                        .font(.Tokens.bodyMedium)
                        .foregroundStyle(ColorTokens.text1)
                    Spacer()
                    // Verdict state as a TEXT LABEL (the primary state channel — never color alone).
                    Text(stateLabel)
                        .font(.Tokens.micro)
                        .tracking(1.2)
                        .foregroundStyle(ColorTokens.text2)
                }

                // Today's number leads (the lift target, NOT a readiness score → accent stays off it).
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text(WeightFormatter.display(display.adjustedTopSetKg, unit: weightUnit, locale: locale))
                        .font(.Tokens.pageTitle)
                        .monospacedDigit()
                        .foregroundStyle(ColorTokens.text1)
                    if display.hasAdjustment {
                        Text(fromPlannedCaption)
                            .font(.Tokens.smallLabel)
                            .monospacedDigit()
                            .foregroundStyle(ColorTokens.text3)
                    }
                }

                if display.kind == .deferred {
                    Text(actionCaption)
                        .font(.Tokens.smallLabel)
                        .foregroundStyle(ColorTokens.text2)
                } else {
                    // Compact strike-zone bar: the zone (today's productive band), the in-zone dot
                    // (today's number), and — when trimmed — a faint planned reference above the zone.
                    StrikeZoneBar(
                        planned: display.plannedTopSetKg,
                        adjusted: display.adjustedTopSetKg,
                        hasAdjustment: display.hasAdjustment
                    )
                    .frame(height: 28)
                    .padding(.top, Spacing.baselinePair)
                    Text(zoneCaption)
                        .font(.Tokens.micro)
                        .tracking(1.4)
                        .foregroundStyle(ColorTokens.text3)
                }
            }

            // 3. Reason line — the one-line why.
            Text(verbatim: display.reasonLine)
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text1)
                .fixedSize(horizontal: false, vertical: true)

            // 4. Confidence — quiet + separate, never alarm-colored.
            if let note = display.confidenceNote {
                Text(verbatim: note)
                    .font(.Tokens.smallLabel)
                    .foregroundStyle(ColorTokens.text3)
            }

            // 5. Decision row (equal weight) — or a quiet confirmed line once decided.
            decisionArea

            // 6. Feel-override — first-class, obvious, logged input.
            feelRow
        }
        .onAppear { Haptics.prepare() }
        // Primary decision surface → the emphasis plane (surfaceEl2 + dividerStrong + 2pt accent
        // top rule). The accent rule lives inside the primitive, so it never lands on the verdict
        // state or today's number.
        .emphasisCardStyle()
        // Supplementary DESATURATED hairline strip (text label above is the primary channel).
        // zoneCaution for an adjustment, zoneLow for a learning defer, none when training as planned.
        // NEVER the danger-zone token (no red gate), NEVER the reserved hero color.
        .overlay(alignment: .leading) {
            if let stripColor {
                Rectangle()
                    .fill(stripColor)
                    .frame(width: 2)
            }
        }
    }

    // MARK: - Number-led captions (the "from planned" reference + the zone caption)

    /// "↓ from 140 kg" — the planned reference shown beside today's number when trimmed.
    private var fromPlannedCaption: String {
        let planned = WeightFormatter.display(display.plannedTopSetKg, unit: weightUnit, locale: locale)
        return String(format: String(localized: "verdictCard.fromPlanned", defaultValue: "↓ from %@"), planned)
    }

    /// The micro-caps line under the strike-zone bar (text label — the zone state, never color alone).
    private var zoneCaption: String {
        switch display.kind {
        case .adjusted:  return String(localized: "verdictCard.zone.in", defaultValue: "IN TODAY'S ZONE")
        case .asPlanned: return String(localized: "verdictCard.zone.right", defaultValue: "RIGHT IN YOUR ZONE")
        case .deferred:  return ""
        }
    }

    // MARK: - Decision area (SC1 equal weight, SC3 one-tap keep)

    @ViewBuilder
    private var decisionArea: some View {
        if display.appliedState != .pending {
            // Quiet confirmed line — no nag to re-decide — then the start affordance: the verdict's
            // resolved numbers become the workout the athlete starts (closing the loop).
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(confirmedLine)
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                // Start CTA only when a resolved plan can actually be produced (no render-then-no-op).
                if canStartWorkout, let onStartWorkout {
                    decisionButton(startLabel, action: onStartWorkout)
                }
            }
        } else if display.kind == .asPlanned {
            // Nothing to accept/decline — a single friction-free acknowledge.
            decisionButton(
                String(localized: "verdictCard.action.gotIt", defaultValue: "Got it"),
                action: onKeepPlan
            )
        } else {
            HStack(spacing: Spacing.xs) {
                decisionButton(
                    String(localized: "verdictCard.action.accept", defaultValue: "Use this"),
                    action: onAccept
                )
                decisionButton(
                    String(localized: "verdictCard.action.keep", defaultValue: "Keep my plan"),
                    action: onKeepPlan
                )
            }
        }
    }

    // MARK: - Feel-override row (SC2 first-class, obvious)

    private var feelRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(String(localized: "verdictCard.feel.prompt", defaultValue: "Not how you feel?"))
                .font(.Tokens.smallLabel)
                .foregroundStyle(ColorTokens.text2)
            HStack(spacing: Spacing.xs) {
                feelPill(
                    String(localized: "verdictCard.feel.strong", defaultValue: "I feel strong"),
                    action: { onFeel(.feelingStrong) }
                )
                feelPill(
                    String(localized: "verdictCard.feel.rough", defaultValue: "I feel rough"),
                    action: { onFeel(.feelingRough) }
                )
            }
        }
    }

    // MARK: - Shared button builders (equal-weight guarantee lives here)

    /// The ONE decision-button builder — Accept and Keep-my-plan are provably identical in
    /// size/treatment (same font, padding, frame, fill, border); they differ ONLY in label/action.
    private func decisionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: { Haptics.tap(); action() }) {
            Text(verbatim: title)
                .font(.Tokens.bodyMedium)
                .foregroundStyle(ColorTokens.text1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xs)
                .background(ColorTokens.surface)
                .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))
        }
        .buttonStyle(.pressable)
    }

    /// The feel pills — same shared treatment, slightly smaller type than the decision buttons.
    private func feelPill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: { Haptics.select(); action() }) {
            Text(verbatim: title)
                .font(.Tokens.smallLabel)
                .foregroundStyle(ColorTokens.text1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xs)
                .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))
        }
        .buttonStyle(.pressable)
    }

    // MARK: - Copy + state derivations

    private var stateLabel: String {
        switch display.kind {
        case .adjusted:
            // v2.1 (ADR-0002): a match-proximity adjustment reads as a MICRODOSE — still a
            // suggestion with a reason (same equal-weight decision row), never a gate.
            return display.isMicrodose
                ? String(localized: "verdictCard.state.microdose", defaultValue: "Microdose")
                : String(localized: "verdictCard.state.adjust", defaultValue: "Adjust")
        case .asPlanned: return String(localized: "verdictCard.state.steady", defaultValue: "Steady")
        case .deferred: return String(localized: "verdictCard.state.learning", defaultValue: "Learning")
        }
    }

    private var actionCaption: String {
        switch display.kind {
        case .adjusted: return String(localized: "verdictCard.action.adjusted", defaultValue: "Suggested adjustment")
        case .asPlanned: return String(localized: "verdictCard.action.asPlanned", defaultValue: "Train as planned")
        case .deferred: return String(localized: "verdictCard.action.deferred", defaultValue: "Going with your plan")
        }
    }

    private var confirmedLine: String {
        switch display.appliedState {
        case .accepted: return String(localized: "verdictCard.state.accepted", defaultValue: "Using the adjustment")
        case .keptPlan: return String(localized: "verdictCard.state.kept", defaultValue: "Training your plan")
        case .pending: return ""
        }
    }

    /// The start CTA label — reflects WHAT will be started: the accepted adjustment, the kept plan
    /// (after declining a real suggestion), or simply the workout (when there was nothing to adjust).
    private var startLabel: String {
        switch display.appliedState {
        case .accepted:
            return String(localized: "verdictCard.start.adjusted", defaultValue: "Start adjusted workout")
        case .keptPlan:
            return display.kind == .adjusted
                ? String(localized: "verdictCard.start.plan", defaultValue: "Start my plan")
                : String(localized: "verdictCard.start.workout", defaultValue: "Start workout")
        case .pending:
            return ""
        }
    }

    /// Desaturated zone strip — supplementary only. Never the danger-zone token, never the hero color.
    private var stripColor: Color? {
        switch display.kind {
        case .adjusted: return ColorTokens.zoneCaution
        case .deferred: return ColorTokens.zoneLow
        case .asPlanned: return nil
        }
    }
}

// MARK: - StrikeZoneBar (the compact "where today's number lands in today's zone" visualization)

/// A presentation-only horizontal bar: a hairline track, the strike ZONE (today's productive band,
/// bracketed by accent hairlines — the "live / actionable" band), the in-zone DOT (today's number),
/// and — when the plan was trimmed — a faint PLANNED reference tick sitting above the zone. No engine
/// math: the zone band is a display tolerance centered on the adjusted number (the engine already
/// placed it in the zone). DESIGN (Tuwa v2): 0pt corners (Rectangle only), no shadow, `ColorTokens`
/// only. The strike-zone FILL is one of the sanctioned accent locations (live/actionable); the verdict
/// state never uses accent (it stays a text label + desaturated zone strip on the card).
private struct StrikeZoneBar: View {
    let planned: Double
    let adjusted: Double
    let hasAdjustment: Bool

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let midY = geo.size.height / 2

            let lo = Swift.min(planned, adjusted)
            let hi = Swift.max(planned, adjusted)
            // Avoid a zero span when there's no adjustment; give the zone a sensible visible width.
            let span = Swift.max(hi - lo, Swift.max(lo, 1) * 0.08)
            // Generous padding so nothing clips the edges.
            let scaleMin = lo - span * 0.7
            let scaleRange = Swift.max((hi + span * 0.7) - scaleMin, 0.0001)
            let x: (Double) -> CGFloat = { v in CGFloat((v - scaleMin) / scaleRange) * w }

            // Zone lane: a display tolerance centered on the adjusted (in-zone) number.
            let zoneLo = adjusted - span * 0.45
            let zoneHi = adjusted + span * 0.45

            ZStack(alignment: .topLeading) {
                // Base track — the full range.
                Rectangle()
                    .fill(ColorTokens.divider)
                    .frame(width: w, height: 1)
                    .position(x: w / 2, y: midY)

                // The strike zone — the live/actionable productive band (accent fill), bracketed at
                // both ends. Accent on the strike-zone FILL is sanctioned in Tuwa v2.
                Rectangle()
                    .fill(ColorTokens.accent)
                    .frame(width: Swift.max(x(zoneHi) - x(zoneLo), 1), height: 3)
                    .position(x: (x(zoneLo) + x(zoneHi)) / 2, y: midY)
                Rectangle()
                    .fill(ColorTokens.accent)
                    .frame(width: 1.5, height: 14)
                    .position(x: x(zoneLo), y: midY)
                Rectangle()
                    .fill(ColorTokens.accent)
                    .frame(width: 1.5, height: 14)
                    .position(x: x(zoneHi), y: midY)

                // Planned reference — a faint tick sitting OUTSIDE the zone (only when trimmed).
                if hasAdjustment {
                    Rectangle()
                        .fill(ColorTokens.text3)
                        .frame(width: 1.5, height: 16)
                        .position(x: x(planned), y: midY)
                }

                // Today's number — the dot, sitting inside the zone lane.
                Circle()
                    .fill(ColorTokens.text1)
                    .frame(width: 8, height: 8)
                    .position(x: x(adjusted), y: midY)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(localized: "verdictCard.zone.a11y", defaultValue: "Today's number sits inside today's training zone")))
    }
}
