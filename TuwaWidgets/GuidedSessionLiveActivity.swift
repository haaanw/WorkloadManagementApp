import ActivityKit
import SwiftUI
import WidgetKit

/// The guided session's lock-screen Live Activity (v1.7.3 feature 9 batch 2, tier 1).
///
/// **Read-only, and deliberately so.** Tier 1 shows the set in front of you and what follows it;
/// it has no buttons (tier 2's `LiveActivityIntent` needs the draft in a store the extension can
/// reach) and takes no pushes. The two clocks are `Text(timerInterval:)`, which the system ticks
/// on its own — so the app updates this card only when something actually happened: a log, a skip,
/// an advance, the finish.
///
/// **The 160 pt card** (round-2 gate: "lock screen bigger" — Apple's cap): a row of annotation
/// stamps, then two columns — NOW (the move, its target in large numerals, its set blocks) and
/// NEXT (what follows, and the SINCE SET clock in a well) — over a segmented bar of every set in
/// the session.
///
/// **Never a body number.** The content state carries no score, no HRV, no sleep, no heart rate —
/// see the composite-only law on `GuidedSessionActivityAttributes`. The lock screen is public.
struct GuidedSessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GuidedSessionActivityAttributes.self) { context in
            GuidedSessionLockScreenView(
                sessionName: context.attributes.sessionName,
                state: context.state
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .activityBackgroundTint(ActivityPlane.background)
            .activitySystemActionForegroundColor(ColorTokens.text1)
        } dynamicIsland: { context in
            GuidedSessionIsland.configuration(
                sessionName: context.attributes.sessionName,
                state: context.state
            )
        }
    }
}

// MARK: - Geometry

/// The card's micro-geometry.
///
/// `CornerTokens`' scale stops at `control` (8pt), which is right for a well and wrong for a 12pt
/// set block or a 6pt bar segment — an 8pt radius on a 12pt block is a lozenge, not a block. These
/// two values are the sanctioned 4pt baseline pair and its half, named ONCE here so the card's call
/// sites never type a radius. (`Spacing.baselinePair` itself lives in `CardStyle.swift`, which
/// carries app-only dependencies and does not join this target.)
private enum ActivityGeometry {
    /// 4pt — the baseline-pair step, as the set block's radius.
    static let blockCorner: CGFloat = 4
    /// 2pt — half the baseline pair, for the session bar's 6pt segments.
    static let barCorner: CGFloat = 2
    static let blockHeight: CGFloat = 12
    static let barHeight: CGFloat = 6
    /// The NEXT column. Fixed rather than proportional so the move name in NOW keeps the room it
    /// needs on a narrow lock screen.
    static let nextColumnWidth: CGFloat = 116
}

// MARK: - Lock screen

struct GuidedSessionLockScreenView: View {
    let sessionName: String
    let state: GuidedSessionActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            stampRow
            if state.isComplete {
                completionColumns
            } else {
                liveColumns
            }
            SessionBar(states: state.sessionStates)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Row 1 — the stamps

    /// `HEAVY LOWER · MOVE 1/4` on the left, `5:23 ELAPSED` on the right. The session name is
    /// annotation here (a key, not a sentence) and the uppercase transform is the component's.
    private var stampRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            WidgetAnnotationLabel(verbatim: leadingStamp, size: .small)
                .lineLimit(1)
            Spacer(minLength: 8)
            HStack(spacing: 4) {
                WidgetAnnotationLabel(text: elapsedTimer, size: .small)
                WidgetAnnotationLabel(key: "activity.elapsed", size: .small)
            }
            .lineLimit(1)
            .fixedSize()
        }
    }

    private var leadingStamp: String {
        if state.isComplete {
            return "\(sessionName) · \(String(localized: "activity.complete", defaultValue: "Complete"))"
        }
        return "\(sessionName) · \(String(localized: "activity.move", defaultValue: "Move")) \(state.movePosition)"
    }

    /// Ticks with no activity update: the system renders the interval, we only hand it a date.
    private var elapsedTimer: Text {
        Text(timerInterval: state.startedAt...Date.distantFuture, countsDown: false)
            .monospacedDigit()
    }

    // MARK: The two columns

    private var liveColumns: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: state.moveName)
                    .font(.Tokens.sectionHead)
                    .foregroundStyle(ColorTokens.text1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(verbatim: state.targetLine)
                    .font(.Tokens.pageTitle)
                    .monospacedDigit()
                    .foregroundStyle(ColorTokens.text1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                SetBlockRow(states: state.setStates)
                    .padding(.top, 4)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            areaRule

            nextColumn
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The tinted hairline between the columns — the strain area's 18% rule, via the extension's
    /// area chokepoint.
    private var areaRule: some View {
        Rectangle()
            .fill(ActivityPlane.hairline)
            .frame(width: 0.5)
            .accessibilityHidden(true)
    }

    private var nextColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            WidgetAnnotationLabel(key: nextKindKey, size: .small)
            Text(verbatim: state.nextMoveName ?? String(localized: "activity.finish", defaultValue: "Finish"))
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text1)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(verbatim: state.nextLine ?? setsLeftLine)
                .font(.Tokens.smallLabel)
                .monospacedDigit()
                .foregroundStyle(ColorTokens.text2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            sinceSetWell
        }
        .frame(width: ActivityGeometry.nextColumnWidth, alignment: .leading)
    }

    private var nextKindKey: LocalizedStringKey {
        switch state.nextKind {
        case .next:   "activity.next"
        case .then:   "activity.then"
        case .finish: "activity.finish"
        }
    }

    private var setsLeftLine: String {
        "\(state.setsLeft) \(String(localized: "activity.left", defaultValue: "left"))"
    }

    /// The rest state, and the only thing on the card that changes while the athlete is not
    /// touching the phone. A debossed well — gradient + hairline, never a shadow.
    private var sinceSetWell: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            WidgetAnnotationLabel(key: "activity.sinceSet", size: .small)
            Spacer(minLength: 4)
            if let last = state.lastLoggedAt {
                WidgetAnnotationLabel(
                    text: Text(timerInterval: last...Date.distantFuture, countsDown: false)
                        .monospacedDigit(),
                    size: .small,
                    color: ColorTokens.text1
                )
            } else {
                // Before the first set lands there is no rest to report.
                WidgetAnnotationLabel(verbatim: "—", size: .small, color: ColorTokens.text1)
            }
        }
        .lineLimit(1)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            LinearGradient(
                colors: [ColorTokens.wellTop, ColorTokens.wellBottom],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: CornerTokens.control)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerTokens.control)
                .stroke(ColorTokens.dividerStrong, lineWidth: 0.5)
        )
    }

    // MARK: Completion face

    /// What the session was. Reached only after a successful save, so SAVED is a fact.
    private var completionColumns: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("activity.sessionComplete", comment: "Live Activity completion headline")
                    .font(.Tokens.sectionHead)
                    .foregroundStyle(ColorTokens.text1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                // The working voice, and the same sentence the in-app completion plate says —
                // "12 sets logged" is a statement, not marginalia, so it is not the mono voice.
                Text(
                    String(
                        format: String(
                            localized: "activity.setsLogged",
                            defaultValue: "%d sets logged"
                        ),
                        state.loggedCount
                    )
                )
                .font(.Tokens.pageTitle)
                .monospacedDigit()
                .foregroundStyle(ColorTokens.text1)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            areaRule

            VStack(alignment: .leading, spacing: 2) {
                WidgetAnnotationLabel(key: "activity.saved", size: .small, color: ColorTokens.zoneOptimal)
                Spacer(minLength: 0)
            }
            .frame(width: ActivityGeometry.nextColumnWidth, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Set blocks

/// The current move's sets, as the plate draws them: logged is a `zone-optimal` block, the current
/// one wears the travertine ring (live state is `accent`'s alone), planned is flat stone, skipped
/// is dashed. No block is ever FILLED with a metric hue — the zone green here is a STATE, the same
/// reading the plate's logged dot carries.
struct SetBlockRow: View {
    let states: [GuidedSessionActivityAttributes.SetState]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(states.enumerated()), id: \.offset) { _, state in
                block(state)
            }
        }
        .frame(height: ActivityGeometry.blockHeight)
    }

    @ViewBuilder private func block(_ state: GuidedSessionActivityAttributes.SetState) -> some View {
        let shape = RoundedRectangle(cornerRadius: ActivityGeometry.blockCorner)
        switch state {
        case .logged:
            shape.fill(ColorTokens.zoneOptimal)
        case .current:
            shape
                .fill(ColorTokens.surfaceEl2)
                .overlay(shape.stroke(ColorTokens.accent, lineWidth: 1.5))
        case .planned:
            shape
                .fill(ColorTokens.surface)
                .overlay(shape.stroke(ColorTokens.divider, lineWidth: 0.5))
        case .skipped:
            shape
                .fill(ColorTokens.surface)
                .overlay(
                    shape.stroke(
                        ColorTokens.divider,
                        style: StrokeStyle(lineWidth: 0.5, dash: [4, 4])
                    )
                )
        }
    }
}

// MARK: - Session bar

/// Every set of the session in execution order — where the athlete is, in one glance, without
/// reading anything.
struct SessionBar: View {
    let states: [GuidedSessionActivityAttributes.SetState]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(states.enumerated()), id: \.offset) { _, state in
                segment(state)
            }
        }
        .frame(height: ActivityGeometry.barHeight)
    }

    @ViewBuilder private func segment(_ state: GuidedSessionActivityAttributes.SetState) -> some View {
        let shape = RoundedRectangle(cornerRadius: ActivityGeometry.barCorner)
        switch state {
        case .logged:  shape.fill(ColorTokens.zoneOptimal)
        case .current: shape.fill(ColorTokens.accent)
        case .planned: shape.fill(ColorTokens.divider)
        case .skipped: shape.stroke(ColorTokens.text3, style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
        }
    }
}

// MARK: - Dynamic Island

/// Tier 3's compact/expanded/minimal presentations. The compact pair is the smallest honest
/// statement of the mode: which move and where you are in it, and how long since the last set.
enum GuidedSessionIsland {

    static func configuration(
        sessionName: String,
        state: GuidedSessionActivityAttributes.ContentState
    ) -> DynamicIsland {
        DynamicIsland {
            DynamicIslandExpandedRegion(.leading) {
                VStack(alignment: .leading, spacing: 2) {
                    WidgetAnnotationLabel(verbatim: state.moveTag.isEmpty ? sessionName : state.moveTag, size: .small)
                    Text(verbatim: state.isComplete ? "" : state.moveName)
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text1)
                        .lineLimit(1)
                    Text(verbatim: state.targetLine)
                        .font(.Tokens.smallLabel)
                        .monospacedDigit()
                        .foregroundStyle(ColorTokens.text2)
                        .lineLimit(1)
                }
            }
            DynamicIslandExpandedRegion(.trailing) {
                VStack(alignment: .trailing, spacing: 2) {
                    WidgetAnnotationLabel(key: "activity.sinceSet", size: .small)
                    sinceSetText(state, color: ColorTokens.text1)
                        .lineLimit(1)
                }
            }
            DynamicIslandExpandedRegion(.bottom) {
                SessionBar(states: state.sessionStates)
            }
        } compactLeading: {
            HStack(spacing: 4) {
                WidgetAnnotationLabel(verbatim: shortName(state), size: .small)
                WidgetAnnotationLabel(verbatim: state.movePosition, size: .small, color: ColorTokens.text1)
            }
            .lineLimit(1)
        } compactTrailing: {
            sinceSetText(state, color: ColorTokens.text1)
                .lineLimit(1)
        } minimal: {
            sinceSetText(state, color: ColorTokens.accent)
                .lineLimit(1)
        }
    }

    /// The move's first word — a Dynamic Island compact slot fits a word, not a movement name.
    private static func shortName(_ state: GuidedSessionActivityAttributes.ContentState) -> String {
        state.moveName.split(separator: " ").first.map(String.init) ?? state.moveTag
    }

    /// The since-set clock, or the sets still owed before the first log lands.
    @ViewBuilder private static func sinceSetText(
        _ state: GuidedSessionActivityAttributes.ContentState,
        color: Color
    ) -> some View {
        if let last = state.lastLoggedAt {
            WidgetAnnotationLabel(
                text: Text(timerInterval: last...Date.distantFuture, countsDown: false)
                    .monospacedDigit(),
                size: .small,
                color: color
            )
        } else {
            WidgetAnnotationLabel(verbatim: "\(state.setsLeft)", size: .small, color: color)
        }
    }
}
