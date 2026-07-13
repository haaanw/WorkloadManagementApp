import SwiftUI
import UIKit

/// Design-system primitives — the single reusable set of card / section / control / motion /
/// haptic building blocks. See DESIGN.md "Elevation Ladder", "Separator Grammar",
/// "Card Pattern", and "Motion". Every grouped surface and every interaction is built from
/// these instead of hand-rolling background + overlay + animation per screen.
///
/// Hard constraints (enforced here so call sites can't drift):
/// - Corners come from `CornerTokens` only (DESIGN.md v3 "Ink & Grain"): grouped surfaces
///   (plates, rails, cards) wear `CornerTokens.card`, controls (inputs, segments, icon
///   buttons, toggles) wear `CornerTokens.control`, and CTAs/chips are `Capsule()` pills.
///   Never a hand-typed radius literal.
/// - No shadows — elevation is plane (surfaceEl / surfaceEl2) + 0.5pt divider border only.
/// - Structural spacing on the 8pt grid, with a single 4pt `baselinePair` typography gap.
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

// MARK: - Geometry roles
// The corner-radius scale lives in `CornerTokens` (Utilities/CornerTokens.swift) as of
// DESIGN.md v3 "Ink & Grain" (2026-07-14). The old zero-valued `GeometryTokens` enum
// (never referenced) was removed with the 0pt law it encoded.

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
    /// Light section choreography step. Kept here so screens never inline timing literals.
    static let staggerStep: Double = 0.05
    /// Long lists stop staggering after this many steps so useful rows never wait seconds to appear.
    static let maxStaggerSteps = 8

    // UI rebuild v3 aliases.
    static let press = state
    static let selection = state
    static let contentChange = entrance
    static let navigation = screen
    static let presentation = entrance
    static let dismissal = exit
    static let metricUpdate = scoreCountUp

    /// reduceMotion-aware resolver: returns nil (no animation) when reduced motion is requested.
    static func resolved(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}

/// A first-render-only section entrance. The state belongs to the section instance, so switching
/// tabs does not replay choreography while the tab hierarchy remains alive. Reduced Motion makes
/// the content visible immediately, with no transform or delayed work.
private struct EntranceRevealModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    let index: Int
    let enabled: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.98)
            .onAppear {
                guard !isVisible else { return }
                guard enabled, !reduceMotion else {
                    isVisible = true
                    return
                }
                let staggerIndex = min(index, Motion.maxStaggerSteps)
                withAnimation(Motion.entrance.delay(Double(staggerIndex) * Motion.staggerStep)) {
                    isVisible = true
                }
            }
    }
}

extension View {
    /// Reveals a top-level section once using the design-system entrance spring.
    func entranceReveal(index: Int = 0, enabled: Bool = true) -> some View {
        modifier(EntranceRevealModifier(index: index, enabled: enabled))
    }
}

/// Cross-fades a tab's content in when its tab becomes selected. Driven by the SELECTION value
/// (not `onAppear`), so navigation pops and sheet dismissals inside a tab never re-trigger the
/// fade, and the first render of each tab stays with `entranceReveal` choreography (`onChange`
/// does not fire on initial appearance). Failure mode is safe: if the change never fires, the
/// content simply stays fully visible. Reduced Motion shows the tab immediately.
private struct TabCrossfadeModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var contentOpacity: Double = 1

    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .opacity(contentOpacity)
            .onChange(of: isSelected) { _, selected in
                guard selected, !reduceMotion else {
                    contentOpacity = 1
                    return
                }
                // Two-phase so the reset to 0 and the animated return to 1 land in separate
                // update cycles (a single-cycle write would diff 1 → 1 and never animate).
                contentOpacity = 0
                DispatchQueue.main.async {
                    withAnimation(Motion.screen) {
                        contentOpacity = 1
                    }
                }
            }
    }
}

extension View {
    /// Screen-level cross-fade for tab content on tab REVISITS (`Motion.screen`).
    /// Apply to each tab root in the main TabView, passing whether its tab is selected.
    func tabCrossfade(isSelected: Bool) -> some View {
        modifier(TabCrossfadeModifier(isSelected: isSelected))
    }
}

// MARK: - Data plate

struct DataPlateStyle: ViewModifier {
    var horizontalPadding: CGFloat = Spacing.sm
    var verticalPadding: CGFloat = Spacing.sm

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(ColorTokens.plate, in: RoundedRectangle(cornerRadius: CornerTokens.card))
            .overlay(RoundedRectangle(cornerRadius: CornerTokens.card).stroke(ColorTokens.hairline, lineWidth: 0.5))
    }
}

extension View {
    func dataPlate(
        horizontalPadding: CGFloat = Spacing.sm,
        verticalPadding: CGFloat = Spacing.sm
    ) -> some View {
        modifier(DataPlateStyle(horizontalPadding: horizontalPadding, verticalPadding: verticalPadding))
    }
}

// MARK: - Surfaces

struct InstrumentHero<Content: View>: View {
    @ViewBuilder var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .emphasisCardStyle()
    }
}

struct MetricRail<Content: View>: View {
    @ViewBuilder var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .background(ColorTokens.recessed, in: RoundedRectangle(cornerRadius: CornerTokens.card))
        .overlay(RoundedRectangle(cornerRadius: CornerTokens.card).stroke(ColorTokens.hairline, lineWidth: 0.5))
    }
}

struct StatusRail: View {
    let title: String
    var detail: String?
    var statusColor: Color = ColorTokens.statusNeutral

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Rectangle()
                .fill(statusColor)
                .frame(width: 2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                Text(title)
                    .font(.Tokens.labelMedium)
                    .foregroundStyle(ColorTokens.textPrimary)
                if let detail {
                    Text(detail)
                        .font(.Tokens.smallLabel)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .dataPlate()
    }
}

struct ControlTray<Content: View>: View {
    @ViewBuilder var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            content
        }
        .dataPlate(verticalPadding: Spacing.md)
    }
}

struct DisclosureRow: View {
    let title: String
    var subtitle: String?
    var trailingText: String?

    var body: some View {
        HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                Text(title)
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.Tokens.smallLabel)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Spacing.sm)
            if let trailingText {
                Text(trailingText)
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            Image(systemName: "chevron.right")
                .font(.Tokens.smallLabel)
                .foregroundStyle(ColorTokens.textTertiary)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

// MARK: - Card

/// The one reusable card container: `surfaceEl` fill + 0.5pt `divider` hairline border,
/// 16pt horizontal / 24pt vertical padding, `CornerTokens.card` corners (v3 Corner Law).
/// Use for any grouped, elevated, or tappable container so it reads as a distinct plane
/// lifted off the page.
struct CardStyle: ViewModifier {
    var horizontalPadding: CGFloat = Spacing.sm
    var verticalPadding: CGFloat = Spacing.md

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(ColorTokens.surfaceEl, in: RoundedRectangle(cornerRadius: CornerTokens.card))
            .overlay(
                RoundedRectangle(cornerRadius: CornerTokens.card).stroke(ColorTokens.divider, lineWidth: 0.5)
            )
    }
}

extension View {
    /// Apply the standard card plane (`surfaceEl` + 0.5pt divider border, `CornerTokens.card` corners).
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
/// a 2pt accent top rule. `CornerTokens.card` corners — the fill, accent rule, and (optional)
/// halftone are clipped by the card shape; the hairline strokes the same rounded shape.
/// No shadow — same as `CardStyle`.
struct EmphasisCardStyle: ViewModifier {
    var horizontalPadding: CGFloat = Spacing.sm
    var verticalPadding: CGFloat = Spacing.md
    var accentRule: Bool = true
    /// The one sanctioned texture (DESIGN.md v3 Halftone Law): the accent dot signature,
    /// ≈130×130pt anchored top-trailing, behind content, clipped by the card shape.
    /// HERO PLANE ONLY — enable exclusively on the hero readiness card, never elsewhere;
    /// at most one halftone surface per screen (fenced).
    var halftoneSignature: Bool = false

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background {
                ZStack(alignment: .top) {
                    ColorTokens.surfaceEl2
                    if halftoneSignature {
                        HalftoneField()
                            .frame(width: 130, height: 130)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                    if accentRule {
                        Rectangle()
                            .fill(ColorTokens.accent)
                            .frame(height: 2)
                            .accessibilityHidden(true)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: CornerTokens.card))
            }
            .overlay(RoundedRectangle(cornerRadius: CornerTokens.card).stroke(ColorTokens.dividerStrong, lineWidth: 0.5))
    }
}

extension View {
    /// Apply the emphasis card plane (`surfaceEl2` + `dividerStrong` border + 2pt accent top rule).
    /// `halftoneSignature` is HERO-PLANE-ONLY per the v3 Halftone Law — pass `true` exclusively
    /// from the hero readiness card.
    func emphasisCardStyle(
        horizontalPadding: CGFloat = Spacing.sm,
        verticalPadding: CGFloat = Spacing.md,
        accentRule: Bool = true,
        halftoneSignature: Bool = false
    ) -> some View {
        modifier(EmphasisCardStyle(
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            accentRule: accentRule,
            halftoneSignature: halftoneSignature
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
/// green, which violates the accent rule. This style uses `--text-1` for the on-track and
/// `--surface` for off; track and knob wear `CornerTokens.control` per the v3 Corner Law.
struct DesignToggleStyle: ToggleStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: CornerTokens.control)
                    .fill(configuration.isOn ? ColorTokens.text1 : ColorTokens.surface)
                    .frame(width: 48, height: 32)
                    .overlay(RoundedRectangle(cornerRadius: CornerTokens.control).stroke(ColorTokens.divider, lineWidth: 0.5))
                RoundedRectangle(cornerRadius: CornerTokens.control)
                    .fill(configuration.isOn ? ColorTokens.background : ColorTokens.text2)
                    .frame(width: 24, height: 24)
                    .padding(Spacing.baselinePair)
            }
        }
        .buttonStyle(.pressable)
        .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: configuration.isOn)
        .accessibilityAddTraits(configuration.isOn ? [.isButton, .isSelected] : .isButton)
    }
}

extension ToggleStyle where Self == DesignToggleStyle {
    /// Neutral design-system toggle (no Apple green). Use everywhere instead of the default.
    static var design: DesignToggleStyle { DesignToggleStyle() }
}

// MARK: - Controls

/// Primary CTA — Accent Rule v3: a FILLED accent pill (`Capsule()`, accent fill, light
/// `surfaceEl2` label). This supersedes the v2 outline-only CTA treatment.
struct PrimaryActionButton: View {
    let title: LocalizedStringKey
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: Spacing.xs) {
                if isLoading {
                    ProgressView()
                        .tint(ColorTokens.surfaceEl2)
                }
                Text(title)
                    .font(.Tokens.bodyMedium)
            }
            .foregroundStyle(ColorTokens.surfaceEl2)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, Spacing.sm)
            .background(ColorTokens.accent, in: Capsule())
        }
        .buttonStyle(.pressable)
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.5 : 1)
    }
}

/// Secondary CTA — an OUTLINED pill (hairline stroke, control fill); never accent-filled.
struct SecondaryActionButton: View {
    let title: LocalizedStringKey
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(title)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, Spacing.sm)
                .background(ColorTokens.control, in: Capsule())
                .overlay(Capsule().stroke(ColorTokens.hairline, lineWidth: 0.5))
        }
        .buttonStyle(.pressable)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
}

struct QuietActionButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(title)
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.textSecondary)
                .frame(minHeight: 44)
                .padding(.horizontal, Spacing.sm)
        }
        .buttonStyle(.pressable)
    }
}

struct IconButton: View {
    let systemImage: String
    let accessibilityLabel: LocalizedStringKey
    var isSelected: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.Tokens.body)
                .foregroundStyle(isSelected ? ColorTokens.textPrimary : ColorTokens.textSecondary)
                .frame(width: 44, height: 44)
                .background(isSelected ? ColorTokens.active : ColorTokens.control, in: RoundedRectangle(cornerRadius: CornerTokens.control))
                .overlay(RoundedRectangle(cornerRadius: CornerTokens.control).stroke(isSelected ? ColorTokens.hairlineStrong : ColorTokens.hairline, lineWidth: 0.5))
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

struct InstrumentSegmentedControl<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: KeyPath<Option, String>

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element) { index, option in
                segment(option)
                if index < options.count - 1 {
                    Rectangle()
                        .fill(ColorTokens.hairline)
                        .frame(width: 0.5)
                }
            }
        }
        .frame(minHeight: 44)
        .background(ColorTokens.control)
        .clipShape(RoundedRectangle(cornerRadius: CornerTokens.control))
        .overlay(RoundedRectangle(cornerRadius: CornerTokens.control).stroke(ColorTokens.hairline, lineWidth: 0.5))
    }

    private func segment(_ option: Option) -> some View {
        let selected = option == selection
        return Button {
            if !selected { Haptics.select() }
            selection = option
        } label: {
            Text(option[keyPath: title])
                .font(selected ? .Tokens.labelMedium : .Tokens.label)
                .foregroundStyle(selected ? ColorTokens.textPrimary : ColorTokens.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(selected ? ColorTokens.active : Color.clear)
                .overlay(alignment: .top) {
                    if selected {
                        Rectangle()
                            .fill(ColorTokens.hairlineStrong)
                            .frame(height: 2)
                    }
                }
        }
        .buttonStyle(.pressable(scale: 1, opacity: 0.7))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

struct InstrumentToggle: View {
    let title: LocalizedStringKey
    @Binding var isOn: Bool

    var body: some View {
        Toggle(title, isOn: $isOn)
            .font(.Tokens.body)
            .foregroundStyle(ColorTokens.textPrimary)
            .toggleStyle(.design)
            .frame(minHeight: 44)
    }
}

struct InstrumentTextField: View {
    let label: LocalizedStringKey
    @Binding var text: String
    var isError: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isFocused: Bool

    /// Focus feedback mirrors SharpTextFieldStyle: accent hairline thickens to 1pt while
    /// editing (accent-as-live-state), settling via `Motion.state`. Error keeps priority.
    private var borderColor: Color {
        if isError { return ColorTokens.statusCritical }
        return isFocused ? ColorTokens.accent : ColorTokens.hairline
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.baselinePair) {
            Text(label)
                .font(.Tokens.smallLabel)
                .foregroundStyle(ColorTokens.textSecondary)
            TextField(label, text: $text)
                .focused($isFocused)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.textPrimary)
                .padding(.horizontal, Spacing.sm)
                .frame(minHeight: 44)
                .background(ColorTokens.control, in: RoundedRectangle(cornerRadius: CornerTokens.control))
                .overlay(RoundedRectangle(cornerRadius: CornerTokens.control).stroke(borderColor, lineWidth: isFocused || isError ? 1 : 0.5))
                .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: isFocused)
        }
    }
}

struct StatusBadge: View {
    let label: String
    var color: Color = ColorTokens.statusNeutral

    var body: some View {
        Text(label)
            .font(.Tokens.micro)
            .tracking(1.2)
            .foregroundStyle(color)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .overlay(Capsule().stroke(color, lineWidth: 0.5))
    }
}

struct SheetScaffold<Content: View, Footer: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    init(
        title: LocalizedStringKey,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.title = title
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        content
                    }
                    .padding(Spacing.sm)
                }
                BottomActionDock {
                    footer
                }
            }
            .background(ColorTokens.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ColorTokens.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

struct BottomActionDock<Content: View>: View {
    @ViewBuilder var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(ColorTokens.hairline)
                .frame(height: 0.5)
            content
                .padding(Spacing.sm)
                .background(ColorTokens.background)
        }
    }
}

/// A calm loading placeholder: a plate-shaped block on the control plane. No shimmer, no
/// pulse — data arrival is a `Motion.state` transition, not a pop. Pair with `.transition(.opacity)`
/// inside an animated container so the swap to real content cross-fades.
struct SkeletonBlock: View {
    var width: CGFloat? = nil
    var height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: CornerTokens.control)
            .fill(ColorTokens.control)
            .frame(width: width, height: height)
            .accessibilityHidden(true)
    }
}

struct LoadingStateView: View {
    let title: LocalizedStringKey

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ProgressView()
            Text(title)
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.background)
    }
}

struct EmptyStateView: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(.Tokens.sectionHead)
                .foregroundStyle(ColorTokens.textPrimary)
            Text(message)
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .dataPlate()
    }
}

struct ErrorStateView: View {
    let title: LocalizedStringKey
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(.Tokens.sectionHead)
                .foregroundStyle(ColorTokens.statusCritical)
            Text(message)
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .dataPlate()
    }
}

struct StaleDataView: View {
    let message: String

    var body: some View {
        StatusRail(
            title: "Data needs refresh",
            detail: message,
            statusColor: ColorTokens.statusAttention
        )
    }
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var pressedScale: CGFloat = 0.97
    var pressedOpacity: Double = 0.7

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .opacity(configuration.isPressed ? pressedOpacity : 1)
            .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: configuration.isPressed)
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
    /// Success — set completed, workout saved, PR detected.
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
