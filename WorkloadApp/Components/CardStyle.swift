import SwiftUI
import UIKit

/// Design-system primitives — the single reusable set of card / section / control / motion /
/// haptic building blocks. See DESIGN.md "Elevation Ladder", "Separator Grammar",
/// "Card Pattern", and "Motion". Every grouped surface and every interaction is built from
/// these instead of hand-rolling background + overlay + animation per screen.
///
/// Hard constraints (enforced here so call sites can't drift):
/// - 0pt corners — Rectangle only, never RoundedRectangle.
/// - No shadows — elevation is plane (surfaceEl / surfaceEl2) + 0.5pt divider border only.
/// - Spacing on the 8pt grid.
/// - Motion goes through the `Motion` tokens — never a bare `withAnimation { }` (which falls
///   back to SwiftUI's default spring) and never a hand-typed duration literal.

// MARK: - Spacing scale (DESIGN.md Spacing table)

enum Spacing {
    /// 4pt — DOCUMENTED sub-grid baseline pair ONLY. The single sanctioned off-8pt
    /// step: the tight gap between a micro/caption label and the value it labels
    /// (e.g. MetricTile title→value, stat-cell label→number). Use NOWHERE else;
    /// all structural spacing stays on the 8pt grid (xs+). Adopted in Wave 5 to
    /// tokenize the recurring `spacing: 4` label-value rhythm instead of churning it
    /// to 8 (which would break the typographic pairing — that is redesign, not hygiene).
    static let baselinePair: CGFloat = 4
    /// 8pt — icon-label gaps, tight inline spacing
    static let xs: CGFloat = 8
    /// 16pt — card horizontal padding, small gaps
    static let sm: CGFloat = 16
    /// 24pt — card vertical padding, standard gaps
    static let md: CGFloat = 24
    /// 32pt — section gaps (the section-break step)
    static let lg: CGFloat = 32
    /// 48pt — major section breaks
    static let xl: CGFloat = 48
}

// MARK: - Motion scale (DESIGN.md Motion — "more life" revision 2026-06-17)

/// The single motion language. Tuwa v2 relaxes the old no-spring rule: gentle springs are
/// permitted for state settle and entrances (low overshoot — alive, not bouncy), while
/// screen/exit transitions stay on easing curves. The hero score count-up keeps its 0.4s
/// easeOut personality. Route ALL animations through these tokens — never a bare
/// `withAnimation { }` (it silently uses SwiftUI's default spring).
enum Motion {
    /// Quick state settle — toggles, selection, press release. Gentle spring, minimal overshoot.
    static let state = Animation.spring(response: 0.30, dampingFraction: 0.86)
    /// Entrance of cards / rows / banners / sheets — a touch more life.
    static let entrance = Animation.spring(response: 0.42, dampingFraction: 0.82)
    /// Screen / nav-level easing where a spring would feel heavy.
    static let screen = Animation.easeOut(duration: 0.28)
    /// Exit / removal.
    static let exit = Animation.easeIn(duration: 0.20)
    /// Hero readiness score count-up — the one sanctioned moment of personality.
    static let scoreCountUp = Animation.easeOut(duration: 0.40)

    /// reduceMotion-aware resolver: returns nil (no animation) when reduced motion is requested.
    static func resolved(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}

// MARK: - Card

/// The one reusable card container: `surfaceEl` fill + 0.5pt `divider` hairline border,
/// 16pt horizontal / 24pt vertical padding, 0pt corners. Use for any grouped, elevated,
/// or tappable container so it reads as a distinct plane lifted off the page.
struct CardStyle: ViewModifier {
    var horizontalPadding: CGFloat = Spacing.sm
    var verticalPadding: CGFloat = Spacing.md

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(ColorTokens.surfaceEl)
            .overlay(
                Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5)
            )
    }
}

extension View {
    /// Apply the standard card plane (`surfaceEl` + 0.5pt divider border, square corners).
    func cardStyle(
        horizontalPadding: CGFloat = Spacing.sm,
        verticalPadding: CGFloat = Spacing.md
    ) -> some View {
        modifier(CardStyle(horizontalPadding: horizontalPadding, verticalPadding: verticalPadding))
    }
}

// MARK: - Emphasis card

/// The emphasis card: the most important / active surface on a screen (hero readiness, a
/// selected card). Uses the raised `surfaceEl2` plane + the stronger `dividerStrong` border +
/// a 2pt accent top rule. This is one of the sanctioned places the accent appears beyond the
/// hero number (accent = "live / actionable"). 0pt corners, no shadow — same as `CardStyle`.
struct EmphasisCardStyle: ViewModifier {
    var horizontalPadding: CGFloat = Spacing.sm
    var verticalPadding: CGFloat = Spacing.md
    var accentRule: Bool = true

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(ColorTokens.surfaceEl2)
            .overlay(Rectangle().stroke(ColorTokens.dividerStrong, lineWidth: 0.5))
            .overlay(alignment: .top) {
                if accentRule {
                    Rectangle()
                        .fill(ColorTokens.accent)
                        .frame(height: 2)
                        .accessibilityHidden(true)
                }
            }
    }
}

extension View {
    /// Apply the emphasis card plane (`surfaceEl2` + `dividerStrong` border + 2pt accent top rule).
    func emphasisCardStyle(
        horizontalPadding: CGFloat = Spacing.sm,
        verticalPadding: CGFloat = Spacing.md,
        accentRule: Bool = true
    ) -> some View {
        modifier(EmphasisCardStyle(
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            accentRule: accentRule
        ))
    }
}

// MARK: - Section header

/// 19pt Medium `sectionHead` header in `--text-1`. This is the real section header per
/// DESIGN.md:27 — NOT 12pt micro-caps `--text-3` (that drift is what flattened hierarchy).
struct SectionHeader: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.Tokens.sectionHead)
            .foregroundStyle(ColorTokens.text1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.sm)
    }
}

// MARK: - Section container

/// Wraps a top-level section: applies the 32pt section-break gap above the content and
/// (optionally) a 19pt Medium header. The break is the heavy tier of the separator
/// grammar — never a bare 8pt spacer.
struct SectionContainer<Content: View>: View {
    var header: LocalizedStringKey?
    var topGap: CGFloat = Spacing.lg
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: topGap)
            if let header {
                SectionHeader(title: header)
                Spacer().frame(height: Spacing.sm)
            }
            content
        }
    }
}

// MARK: - Row separator

/// The light tier of the separator grammar: a 0.5pt `divider` hairline inset 16pt from the
/// leading edge, used between sibling rows inside one section.
struct RowSeparator: View {
    var inset: CGFloat = Spacing.sm

    var body: some View {
        Rectangle()
            .fill(ColorTokens.divider)
            .frame(height: 0.5)
            .padding(.leading, inset)
    }
}

// MARK: - Toggle style (neutral — no Apple green)

/// A deliberately neutral toggle. The default system `Toggle` paints its "on" track Apple
/// green, which violates the accent-only rule (accent lives only on the hero score). This
/// style uses `--text-1` for the on-track and `--surface` for off, with a square 0pt knob —
/// consistent with the instrument aesthetic.
struct DesignToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Rectangle()
                    .fill(configuration.isOn ? ColorTokens.text1 : ColorTokens.surface)
                    .frame(width: 48, height: 32)
                    .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))
                Rectangle()
                    .fill(configuration.isOn ? ColorTokens.background : ColorTokens.text2)
                    .frame(width: 24, height: 24)
                    .padding(Spacing.baselinePair)
            }
        }
        .buttonStyle(.plain)
        .animation(.linear(duration: 0.15), value: configuration.isOn)
        .accessibilityAddTraits(configuration.isOn ? [.isButton, .isSelected] : .isButton)
    }
}

extension ToggleStyle where Self == DesignToggleStyle {
    /// Neutral design-system toggle (no Apple green). Use everywhere instead of the default.
    static var design: DesignToggleStyle { DesignToggleStyle() }
}

// MARK: - Menu picker chevron

/// The trailing chevron for a `Menu`-backed picker, styled to the system: a small caret in
/// `--text-3`, drawn with SF Symbols sizing that matches the type scale (no `.system()` font).
struct MenuChevron: View {
    var body: some View {
        Image(systemName: "chevron.up.chevron.down")
            .font(.Tokens.micro)
            .foregroundStyle(ColorTokens.text3)
    }
}

// MARK: - Pressable button style (tactile feedback — "more life" revision 2026-06-17)

/// Tactile press feedback for any tappable surface (rows, cards, CTAs). Scales to 0.97 and
/// dims to 0.7 on press, springing back via `Motion.state`. No color shift, no shadow — it
/// respects the instrument aesthetic while making controls feel alive. Replace
/// `.buttonStyle(.plain)` with `.buttonStyle(.pressable)` on interactive rows / cards / CTAs.
struct PressableButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.97
    var pressedOpacity: Double = 0.7

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .opacity(configuration.isPressed ? pressedOpacity : 1)
            .animation(Motion.state, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    /// Tactile press feedback (scale + fade, springs back). Use on interactive rows/cards/CTAs.
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
    /// Tactile press with custom press depth (e.g. subtler `opacity:` for large surfaces).
    static func pressable(scale: CGFloat = 0.97, opacity: Double = 0.7) -> PressableButtonStyle {
        PressableButtonStyle(pressedScale: scale, pressedOpacity: opacity)
    }
}

// MARK: - Haptics (commit-only feedback — "more life" revision 2026-06-17)

/// Centralized haptic feedback, fired on meaningful commits only — never decoratively.
/// Call `Haptics.prepare()` in `onAppear` (or at the start of a latency-sensitive action) to
/// warm the generators. All calls happen from SwiftUI actions on the main actor.
enum Haptics {
    private static let impactLight = UIImpactFeedbackGenerator(style: .light)
    private static let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    /// Light tap — the per-set done toggle and other small, frequent commits.
    static func tap() { impactLight.impactOccurred() }
    /// Medium tap — a heavier discrete action.
    static func impact() { impactMedium.impactOccurred() }
    /// Selection change — pickers, segmented controls, scrubber detents.
    static func select() { selection.selectionChanged() }
    /// Success — workout saved, PR detected.
    static func success() { notification.notificationOccurred(.success) }
    /// Warning — spike / caution alert surfaced.
    static func warning() { notification.notificationOccurred(.warning) }

    /// Warm the generators ahead of a latency-sensitive moment.
    static func prepare() {
        impactLight.prepare()
        impactMedium.prepare()
        selection.prepare()
        notification.prepare()
    }
}
