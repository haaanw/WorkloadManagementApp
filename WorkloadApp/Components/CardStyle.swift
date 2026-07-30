import SwiftUI
import UIKit

/// Design-system primitives — the single reusable set of card / section / control / motion /
/// haptic building blocks. See DESIGN.md "Elevation Ladder", "Separator Grammar",
/// "Card Pattern", and "Motion". Every grouped surface and every interaction is built from
/// these instead of hand-rolling background + overlay + animation per screen.
///
/// v6 "Field Notes" additions (2026-07-30) — the annotation layer's two primitives live here,
/// beside Motion, because this file is the primitives chokepoint:
/// - `AnnotationLabel` — the mono marginalia label. Owns the uppercase transform, +0.05em
///   tracking, tertiary ink, tabular digits, and the CJK guard, so a call site cannot violate
///   the annotation law by passing the wrong modifiers.
/// - `.annotationReveal(index:)` — the 40ms-staggered reveal that fires AFTER the surface
///   settles. The single implementation; Wave-2 screens consume it and never reimplement it.
///
/// The card/relief surfaces below needed no v6 edit: they read `ColorTokens` semantically, and
/// v6's card spec (`surface-el` fill, 0.5pt `divider` hairline, 12pt radius, 16/24 padding) plus
/// its emphasis spec (`surface-el-2` + `divider-strong`) are byte-for-byte what they already
/// draw. The v6 palette reaches them through the token layer.
///
/// Hard constraints (enforced here so call sites can't drift):
/// - Corners come from `CornerTokens` only (DESIGN.md v6, unchanged from v5): grouped surfaces
///   (plates, rails, cards) wear `CornerTokens.card` (12pt), controls wear
///   `CornerTokens.control` (8pt), and the ONE primary CTA per screen is an ink-filled
///   `Capsule()` (`CornerTokens.pill`). Never a hand-typed radius literal.
/// - No shadows — elevation is plane (stone card planes) + 0.5pt hairline border + relief only.
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

// MARK: - Motion scale (DESIGN.md v4.2 "Machined" — Spring Motion Law D16, 2026-07-21)

/// The single motion language. v4.2's Spring Motion Law (D16) moves the tokens off fixed
/// timing curves and onto NON-BOUNCY springs: interruptible and velocity-preserving, so a
/// re-target mid-flight blends instead of restarting, yet critically damped (`bounce: 0`) so
/// nothing overshoots. This is Emil Kowalski's spring model — physical, not decorative. The
/// premium-fast band is preserved: presses attack ~85–100ms, state settles ≤250ms, screen
/// transitions ≤300ms, the hero count-up ≤400ms. Route ALL animations through these tokens —
/// never a bare `withAnimation { }` (it silently uses SwiftUI's default *bouncy* spring).
///
/// Two carriers keep timing curves rather than springs, by design:
/// - `tickSpring` — the single sanctioned OVERSHOOT (Console tab tick only, v4.1 D12). The
///   `y2 > 1` control point is the "thrown needle" settle; it is the one place bounce is legal.
/// - `exit` — removals leave on a fast ease-out; a spring release on a disappearing view is
///   wasted (it is already gone before the tail matters).
///
/// Asymmetric press (pick 4-A): a key depresses fast (`pressIn`, ~85ms) and releases slow on a
/// ~300ms non-bouncy spring (`keyReliefRelease`). That asymmetry — quick bite, unhurried
/// return — is the machined press feel; `ReliefPressButtonStyle` reads both tokens.
enum Motion {
    /// A non-bouncy spring of the given perceived duration. `bounce: 0` is critically damped —
    /// zero overshoot — and iOS 17's spring is interruptible + velocity-preserving by
    /// construction, so a value that re-targets mid-animation blends from its current velocity.
    /// This one helper is the whole Spring Motion Law; every token below is an instance of it.
    private static func snap(_ duration: Double) -> Animation {
        .spring(duration: duration, bounce: 0)
    }

    /// Press feedback for scale-only presses on light chrome (icon buttons, tab items,
    /// segments) — the quick non-bouncy settle used by `PressableButtonStyle`. Keys proper
    /// use the asymmetric relief press below, not this.
    static let press = snap(0.16)
    /// Asymmetric press ATTACK — the fast ~85ms depress of a machined key (pick 4-A: "keys
    /// press in ~85ms"). Paired on release with `keyReliefRelease`. Used by `ReliefPressButtonStyle`.
    static let pressIn = snap(0.09)
    /// Asymmetric press RELEASE — the ~300ms non-bouncy spring the key rides back up on
    /// (pick 4-A). The unhurried return is what makes the press feel sprung rather than clicked.
    static let keyReliefRelease = snap(0.30)
    /// Row touch-down well — the Row primitive's background settle (v4.1 Five-Primitive
    /// Interaction Law: Row = ~110ms well, no scale). Used by `RowWellButtonStyle`.
    static let rowWell = snap(0.14)
    /// Detent digit-roll — the value-swap on a stepper/scrubber/dial cell (v4.1 D13(b):
    /// "digit roll faster/subtler, ~100ms, small travel"). Pairs with
    /// `.contentTransition(.numericText())` in `DialValueCell` and the controls.
    static let digitRoll = snap(0.12)
    /// The ONE sanctioned overshoot curve in the whole app — the Console tab tick's springy
    /// throw only (v4.1 D12, kept in v5). cubic-bezier(0.3, 1.15, 0.4, 1): the y2 > 1 control
    /// point is the slight overshoot that makes the accent tick "settle" onto the
    /// newly-selected tab like a thrown needle. NOT a general motion personality — every other
    /// transition stays on a non-bouncy spring. Reserved for `InkTabBar`'s active-tab tick.
    static let tickSpring = Animation.timingCurve(0.3, 1.15, 0.4, 1, duration: 0.22)
    /// Quick state settle — toggles, selection, needle position, the tab well glide, value
    /// swaps. Non-bouncy spring, ≤250ms perceived; interruptible so a rapid re-select blends.
    static let state = snap(0.22)
    /// Screen / nav-level transition (route swaps, disclosure reveals). Non-bouncy, ≤300ms.
    static let screen = snap(0.26)
    /// Entrance of cards / rows / banners — the rise+fade reveal. A non-bouncy spring gives the
    /// upward glide a physical decelerate without any bounce (D16 retires the flat ease-out).
    static let entrance = snap(0.34)
    /// Exit / removal — a fast ease-out (NOT a spring): a disappearing view is gone before a
    /// spring tail would matter, so the cheap curve is correct here. `exit` never overshoots.
    static let exit = Animation.easeOut(duration: 0.15)
    /// The layered tab handoff — incoming content rises + fades OVER the still-present outgoing
    /// (D16: no content may pass through full invisibility). Non-bouncy, brisk (~200ms) because
    /// tab switches are frequent. Used by `TabCrossfadeModifier`.
    static let tabSwitch = snap(0.20)
    /// Hero readiness count-up sweep — the one sanctioned longer moment (D16: settles ≤400ms).
    /// A non-bouncy spring so the digits and the needle decelerate onto the reading together.
    static let scoreCountUp = snap(0.40)
    /// Section choreography step — law: stagger 30–80ms. Kept here so screens never
    /// inline timing literals. Also the v6 annotation stagger (`--anno-stagger: 40ms`) — the
    /// two are the same 40ms step by design, not by coincidence.
    static let staggerStep: Double = 0.04
    /// v6 "Field Notes" annotation fade (`--dur-anno: 180ms`) — the mono marginalia settling in
    /// AFTER the surface it labels. Deliberately shorter than `entrance`: the card is the event,
    /// the label is the footnote. Consumed only by `AnnotationRevealModifier`.
    static let anno = snap(0.18)
    /// The delay before annotation choreography begins — the surface must SETTLE first
    /// ("the card exists, then the scientist labels it"). Matches `entrance`'s perceived
    /// duration so labels never race the plane they annotate.
    static let annoSurfaceSettle: Double = 0.34
    /// Long lists stop staggering after this many steps so useful rows never wait seconds to appear.
    static let maxStaggerSteps = 8
    /// The rise distance for the entrance reveal and the tab handoff — content glides up this
    /// far as it fades in (D16 layered handoff / rise entrance). One 8pt-grid-adjacent unit.
    static let riseOffset: CGFloat = 6

    // UI rebuild v3 aliases (names retained; press is now its own faster token).
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
            // Rise + fade (D16): the section glides up `riseOffset` as it fades in, riding the
            // non-bouncy `entrance` spring — a physical settle, not the old scale-up pop.
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : Motion.riseOffset)
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
    /// Reveals a top-level section once using the design-system entrance curve (`Motion.entrance`).
    func entranceReveal(index: Int = 0, enabled: Bool = true) -> some View {
        modifier(EntranceRevealModifier(index: index, enabled: enabled))
    }
}

/// Layered rise+fade handoff for tab content when its tab becomes selected (D16 Spring Motion
/// Law: the v4.0/4.1 dip-crossfade is BANNED — no content may pass through full invisibility).
/// Driven by the SELECTION value (not `onAppear`), so navigation pops and sheet dismissals
/// inside a tab never re-trigger it, and the first render of each tab stays with
/// `entranceReveal` choreography (`onChange` does not fire on initial appearance).
///
/// **How it guarantees no empty frame.** On becoming selected the incoming content lands its
/// pre-handoff state — opacity `handoffFloor` (a VISIBLE floor, never 0) plus a `riseOffset`
/// rise — in one update cycle, then springs to rest (opacity 1, offset 0) in the next. Because
/// the floor is well above zero, every rendered frame shows substantial content: the incoming
/// rises into place OVER the outgoing rather than blinking in from black. Failure mode is safe:
/// if the change never fires, content simply sits at rest, fully visible. Reduced Motion snaps.
private struct TabCrossfadeModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// `true` = at rest (opacity 1, offset 0). Starts settled so the first paint is never faded.
    @State private var settled = true

    let isSelected: Bool

    /// The incoming content NEVER dips below this opacity — the whole point of D16's ban on the
    /// dip-crossfade. High enough that a single frame at the floor is provably not an empty
    /// frame (verified by frame extraction), low enough that the rise+fade still reads.
    private static let handoffFloor: Double = 0.5

    func body(content: Content) -> some View {
        content
            .opacity(settled ? 1 : Self.handoffFloor)
            .offset(y: settled ? 0 : Motion.riseOffset)
            .onChange(of: isSelected) { _, selected in
                guard selected, !reduceMotion else {
                    settled = true
                    return
                }
                // Two-phase so the pre-handoff state (floor + rise) and the animated settle land
                // in separate update cycles (a single-cycle write would diff rest → rest and
                // never animate). The un-animated first write floors opacity to 0.5, NOT 0 — so
                // the one frame it produces is visible, not blank.
                settled = false
                DispatchQueue.main.async {
                    withAnimation(Motion.tabSwitch) {
                        settled = true
                    }
                }
            }
    }
}

extension View {
    /// Layered rise+fade handoff for tab content on tab REVISITS (`Motion.tabSwitch`). The
    /// incoming rises `Motion.riseOffset` + fades from a visible floor to rest — never through
    /// full invisibility (D16). Apply to each tab root in the main TabView, passing whether its
    /// tab is selected.
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

/// The emphasis card: a slightly raised light surface (a selected card, the screen's primary
/// decision surface). `surfaceEl2` plane + the stronger `dividerStrong` border. No shadow —
/// same as `CardStyle`. No decorative accent rule (Accent Rule: accent is the hero score and
/// live-state marks only); emphasis is just "slightly raised".
struct EmphasisCardStyle: ViewModifier {
    var horizontalPadding: CGFloat = Spacing.sm
    var verticalPadding: CGFloat = Spacing.md

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(ColorTokens.surfaceEl2, in: RoundedRectangle(cornerRadius: CornerTokens.card))
            .overlay(RoundedRectangle(cornerRadius: CornerTokens.card).stroke(ColorTokens.dividerStrong, lineWidth: 0.5))
    }
}

extension View {
    /// Apply the emphasis card plane (`surfaceEl2` + `dividerStrong` border — no accent rule in v4).
    func emphasisCardStyle(
        horizontalPadding: CGFloat = Spacing.sm,
        verticalPadding: CGFloat = Spacing.md
    ) -> some View {
        modifier(EmphasisCardStyle(
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding
        ))
    }
}

// MARK: - Relief (DESIGN.md v4.2 "Machined" — Relief Law)

/// RAISED — the milled plate (tuning-board pick 1-B, re-materialized in stone for v5):
/// vertical `surfaceEl2→surfaceEl` gradient, `dividerStrong` outer hairline, and a 1px
/// top-highlight line INSIDE the shape (the cut stone edge). No `.shadow()` — relief is
/// strokes + gradients only, so the
/// no-shadow law holds. Every machined surface in the app is either `.raised` or `.debossed`;
/// flat is reserved for the base plane and text.
struct RaisedStyle: ViewModifier {
    var cornerRadius: CGFloat = CornerTokens.card

    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    colors: [ColorTokens.surfaceEl2, ColorTokens.surfaceEl],
                    startPoint: .top, endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: cornerRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .inset(by: 0.75)
                    .stroke(
                        LinearGradient(
                            colors: [ColorTokens.reliefHighlight, .clear],
                            startPoint: .top, endPoint: .center
                        ),
                        lineWidth: 1
                    )
            )
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(ColorTokens.dividerStrong, lineWidth: 0.5))
    }
}

/// DEBOSSED — the readout pocket (tuning-board pick 2-B): `wellTop→wellBottom` gradient,
/// a 1.5px inner top shade (the cut edge) and a 1px bottom inner highlight closing the
/// pocket. Values, fields-in-focus, option channels, and toggle tracks live in pockets.
struct DebossedStyle: ViewModifier {
    var cornerRadius: CGFloat = CornerTokens.control

    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    colors: [ColorTokens.wellTop, ColorTokens.wellBottom],
                    startPoint: .top, endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: cornerRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .inset(by: 0.75)
                    .stroke(
                        LinearGradient(
                            colors: [ColorTokens.reliefShade, .clear],
                            startPoint: .top, endPoint: .center
                        ),
                        lineWidth: 1.5
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .inset(by: 0.75)
                    .stroke(
                        LinearGradient(
                            colors: [.clear, ColorTokens.reliefHighlightSoft],
                            startPoint: .center, endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(ColorTokens.dividerStrong, lineWidth: 0.5))
    }
}

extension View {
    /// Milled raised plate (Relief Law). See `RaisedStyle`.
    func raised(cornerRadius: CGFloat = CornerTokens.card) -> some View {
        modifier(RaisedStyle(cornerRadius: cornerRadius))
    }
    /// Debossed pocket (Relief Law). See `DebossedStyle`.
    func debossed(cornerRadius: CGFloat = CornerTokens.control) -> some View {
        modifier(DebossedStyle(cornerRadius: cornerRadius))
    }
}

// MARK: - Annotation layer (DESIGN.md v6 "Field Notes")

/// The two sanctioned annotation sizes. There is no third, and no way to ask for a larger one:
/// `Font.Tokens.annoCascaded` clamps at `annoSizeCap` (12pt).
enum AnnotationSize {
    /// 12pt — the standard marginalia size: units, deltas, machine keys, reason trees.
    case standard
    /// 10pt — axis labels and timestamps.
    case small

    var font: Font {
        switch self {
        case .standard: .Tokens.anno
        case .small:    .Tokens.annoSmall
        }
    }

    /// +0.05em, resolved to points (DESIGN.md v6; `HANDOFF.md` and the distribution plan both
    /// specify 0.05em — the `guidelines/*.card.html` specimens' .04em is illustrative).
    var tracking: CGFloat {
        switch self {
        case .standard: 12 * 0.05  // 0.6pt
        case .small:    10 * 0.05  // 0.5pt
        }
    }
}

/// **The annotation primitive.** A single mono marginalia label — the visible signature of v6.
///
/// Use this instead of hand-assembling `Text(...).font(.Tokens.anno)`: the uppercase transform,
/// the +0.05em tracking, the tertiary ink, tabular digits, and the CJK guard are all part of the
/// annotation LAW, not call-site choices. Passing a string is the whole API surface, which is
/// what makes the law unviolatable.
///
/// **What belongs here:** units (`62 MS`), deltas (`+4`, `▲`), timestamps and cycle position
/// (`MON 07.28 · WK 31`, `D-028`), axis labels, machine keys (`HRV_BASELINE: TRUE`), reason-tree
/// rows (`├─ HRV AT BASELINE`).
///
/// **What does NOT:** anything the app *says*. Body copy, verdict sentences, headlines, CTA
/// labels, tab labels, screen titles. The annotation voice annotates; it never speaks a
/// sentence. A sentence in mono is a design-law failure, not a style choice.
///
/// **i18n:** zh-Hans takes NO case transform and NO added tracking (uppercase is meaningless for
/// CJK and tracking harms it) — decided here, per the established `isLatin` idiom, so no call
/// site has to remember.
struct AnnotationLabel: View {
    private let text: String
    private let size: AnnotationSize
    private let color: Color

    @Environment(\.locale) private var locale
    private var isLatin: Bool { locale.language.languageCode?.identifier != "zh" }

    /// - Parameters:
    ///   - text: the annotation content. Terse and machine-flavored; never a sentence.
    ///   - size: `.standard` (12pt) or `.small` (10pt, axes/timestamps).
    ///   - color: defaults to `text3`. Per DESIGN.md rule 7, annotation carrying information the
    ///     athlete must not miss uses `text2` or a metric hue on a card plane — and `text3`
    ///     annotation must never sit on a debossed well (2.84:1, below the contrast floor).
    init(_ text: String, size: AnnotationSize = .standard, color: Color = ColorTokens.text3) {
        self.text = text
        self.size = size
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(size.font)
            .monospacedDigit()
            .tracking(isLatin ? size.tracking : 0)
            .textCase(isLatin ? .uppercase : nil)
            .foregroundStyle(color)
    }
}

/// **The annotation choreography primitive** — the one implementation of v6's staggered
/// marginalia reveal. Wave-2 screens consume this; nobody reimplements a stagger per screen.
///
/// The grammar: the surface settles first, THEN its labels arrive, 40ms apart — "the card exists,
/// then the scientist labels it". Riding `Motion.anno` (a 180ms non-bouncy spring) keeps it on
/// the existing spring law: no ease-in, no bounce, and the label fades from a floor of zero
/// opacity only because it has no prior state to preserve (the no-dip-to-invisible ban governs
/// content *transitions*, not first appearance).
///
/// `index` is the label's position in its group, so a reason tree reveals top-to-bottom. Stagger
/// is capped by `Motion.maxStaggerSteps` so a long annotation list never waits seconds.
///
/// Reduced Motion shows annotation immediately — no transform, no delayed work, no timer.
private struct AnnotationRevealModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    let index: Int
    let enabled: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                guard !isVisible else { return }
                guard enabled, !reduceMotion else {
                    isVisible = true
                    return
                }
                let staggerIndex = min(index, Motion.maxStaggerSteps)
                let delay = Motion.annoSurfaceSettle + Double(staggerIndex) * Motion.staggerStep
                withAnimation(Motion.anno.delay(delay)) {
                    isVisible = true
                }
            }
    }
}

extension View {
    /// Reveal mono annotation on the v6 choreography: after the surface settles, 40ms-staggered
    /// by `index`. See `AnnotationRevealModifier`. Honors Reduce Motion.
    func annotationReveal(index: Int = 0, enabled: Bool = true) -> some View {
        modifier(AnnotationRevealModifier(index: index, enabled: enabled))
    }
}

// MARK: - Attention banner

/// The attention-banner plane shared by PR / spike / fatigue / cycle banners: a standard
/// card (`CornerTokens.card` corners, 0.5pt divider hairline, no shadow) carrying a 2pt
/// zone-colored leading rule clipped inside the card shape. The zone state is always
/// communicated by the text label first — the colored rule is supplementary (never color
/// alone, DESIGN.md rule 5).
struct AttentionBannerStyle: ViewModifier {
    let ruleColor: Color
    var fill: Color = ColorTokens.surfaceEl

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack(alignment: .leading) {
                    fill
                    Rectangle()
                        .fill(ruleColor)
                        .frame(width: 2)
                        .accessibilityHidden(true)
                }
                .clipShape(RoundedRectangle(cornerRadius: CornerTokens.card))
            }
            .overlay(RoundedRectangle(cornerRadius: CornerTokens.card).stroke(ColorTokens.divider, lineWidth: 0.5))
    }
}

extension View {
    /// Apply the attention-banner plane (zone-colored leading rule inside a standard card).
    func attentionBannerStyle(ruleColor: Color, fill: Color = ColorTokens.surfaceEl) -> some View {
        modifier(AttentionBannerStyle(ruleColor: ruleColor, fill: fill))
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

// MARK: - Screen header (v5 editorial header — v1 style restored)

/// The in-content screen header (DESIGN.md v5 "Pavilion" / v1 editorial style): an optional
/// context/date line in micro-caps (11pt `micro`, uppercase, ~0.9pt tracking, `--text-3`)
/// ABOVE the sentence-case title (28pt Regular `screenTitle`, `--text-1`), with a quiet
/// trailing action slot (10pt Medium `headerAction`, `--text-2`, micro-caps) on the title
/// baseline. The v4 wide-tracked micro-caps titlebar is retired: the title itself carries
/// NO case transform and NO tracking. Micro-caps case/tracking on the context line and
/// action slot are locale-aware (Chinese gets none — they are Latin-only typography).
/// Same API and IDs as the Stage-4a header (`context:` is additive, defaulted); spacing
/// unchanged (8pt above, 24pt below, on the grid).
struct ScreenHeader<Trailing: View>: View {
    let title: LocalizedStringKey
    var context: LocalizedStringKey?
    @ViewBuilder var trailing: Trailing

    @Environment(\.locale) private var locale

    init(
        title: LocalizedStringKey,
        context: LocalizedStringKey? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.context = context
        self.trailing = trailing()
    }

    init(title: LocalizedStringKey, context: LocalizedStringKey? = nil) where Trailing == EmptyView {
        self.init(title: title, context: context) { EmptyView() }
    }

    private var isLatinLocale: Bool {
        locale.language.languageCode?.identifier != "zh"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.baselinePair) {
            if let context {
                Text(context)
                    .font(.Tokens.micro)
                    .tracking(isLatinLocale ? 0.9 : 0)
                    .textCase(.uppercase)
                    .foregroundStyle(ColorTokens.text3)
            }
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                Text(title)
                    .font(.Tokens.screenTitle)
                    .foregroundStyle(ColorTokens.text1)
                Spacer(minLength: 0)
                trailing
                    .font(.Tokens.headerAction)
                    .textCase(.uppercase)
                    .foregroundStyle(ColorTokens.text2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.sm)
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.md)
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
            // A toggle flip is one of the sanctioned v4.1 discrete-commit haptics (D13(a)).
            Haptics.tap()
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

// MARK: - Key grammar (v5 CTA & Key Row Law — butted decision cells)

/// The shared key/CTA label: `keyLabel` (11pt Medium), sentence case (DESIGN.md v5 — the
/// v4 micro-caps case transform and wide tracking are retired). Shared by `KeyRow`,
/// `PrimaryActionButton`, `SecondaryActionButton` so every key in the app is provably the
/// same engraving.
private struct KeyCellLabel: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.Tokens.keyLabel)
            .lineLimit(1)
    }
}

/// Butted key row — the decision grammar (DESIGN.md v5 CTA & Key Row Law): flex cells of
/// equal weight inside ONE `CornerTokens.card` container with a 0.5pt `dividerStrong`
/// border, separated by interior 0.5pt hairlines — no gaps. The CTA key is an ink-filled
/// cell (`text1` fill, `inkInverse` label) — never accent (the accent never fills a CTA).
/// Equal visual weight between cells is the nocebo guard: identical size, type, and press
/// treatment; only the fill differs, and only when a role is explicit.
struct KeyRow: View {
    struct Key: Identifiable {
        enum Role {
            /// Card-filled cell (`surfaceEl`), ink label.
            case standard
            /// Ink-filled CTA cell (`text1` fill, `inkInverse` label).
            case cta
        }

        let title: LocalizedStringKey
        var role: Role = .standard
        var accessibilityID: String? = nil
        let action: () -> Void

        var id: String { accessibilityID ?? String(describing: title) }
    }

    let keys: [Key]

    init(_ keys: [Key]) {
        self.keys = keys
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(keys.enumerated()), id: \.element.id) { index, key in
                cell(key)
                if index < keys.count - 1 {
                    Rectangle()
                        .fill(ColorTokens.dividerStrong)
                        .frame(width: 0.5)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(minHeight: 44)
        .clipShape(RoundedRectangle(cornerRadius: CornerTokens.card))
        .overlay(RoundedRectangle(cornerRadius: CornerTokens.card).stroke(ColorTokens.dividerStrong, lineWidth: 0.5))
    }

    private func cell(_ key: Key) -> some View {
        Button {
            Haptics.tap()
            key.action()
        } label: {
            KeyCellLabel(title: key.title)
                .foregroundStyle(key.role == .cta ? ColorTokens.inkInverse : ColorTokens.text1)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, Spacing.xs)
                .background(key.role == .cta ? ColorTokens.text1 : ColorTokens.surfaceEl)
                .contentShape(Rectangle())
        }
        // Relief-inversion press (pick 4-A): the cell sinks into a pocket under the finger —
        // no scale (scale-only key presses are retired). Corner 0 because the row clips.
        .buttonStyle(key.role == .cta ? .reliefKey(cornerRadius: 0) : .reliefPress(cornerRadius: 0))
        .accessibilityIdentifier(key.accessibilityID ?? "")
    }
}

// MARK: - Controls

/// Primary CTA — v5 CTA Law: the ONE ink-filled PILL per screen (`text1` fill, `inkInverse`
/// sentence-case label, `Capsule()` geometry — `CornerTokens.pill`). Never accent-filled
/// (the accent never fills a CTA), and it keeps the `.raised` relief + press-inversion feel
/// via the pill-shaped relief key press.
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
                        .tint(ColorTokens.inkInverse)
                }
                KeyCellLabel(title: title)
            }
            .foregroundStyle(ColorTokens.inkInverse)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, Spacing.sm)
            .background(ColorTokens.text1, in: Capsule())
            .overlay(
                // The raised-plate top highlight, tracked to the pill silhouette — the
                // `.raised` milled edge over the ink fill (relief = strokes only, no shadow).
                Capsule()
                    .inset(by: 0.75)
                    .stroke(
                        LinearGradient(
                            colors: [ColorTokens.reliefHighlightSoft, .clear],
                            startPoint: .top, endPoint: .center
                        ),
                        lineWidth: 1
                    )
            )
        }
        // The canonical Key (pick 4-A): the ink face lifts + sinks into a pocket under the
        // finger, fast bite / sprung return — relief inversion, not scale.
        .buttonStyle(.reliefKeyPill)
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.5 : 1)
    }
}

/// Secondary CTA — a hairline-bordered rectangle (card fill, ink sentence-case label,
/// `CornerTokens.control` corners); never a pill, never accent.
struct SecondaryActionButton: View {
    let title: LocalizedStringKey
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            KeyCellLabel(title: title)
                .foregroundStyle(ColorTokens.text1)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, Spacing.sm)
                .background(ColorTokens.surfaceEl, in: RoundedRectangle(cornerRadius: CornerTokens.control))
                .overlay(RoundedRectangle(cornerRadius: CornerTokens.control).stroke(ColorTokens.dividerStrong, lineWidth: 0.5))
        }
        // Relief-inversion press (pick 4-A): the stone key sinks into a pocket, no scale.
        .buttonStyle(.reliefPress)
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

    /// Focus feedback mirrors SharpTextFieldStyle: the INK hairline thickens to 1pt while
    /// editing (Accent Rule — accent never marks focus), settling via `Motion.state`.
    /// Error keeps priority.
    private var borderColor: Color {
        if isError { return ColorTokens.statusCritical }
        return isFocused ? ColorTokens.text1 : ColorTokens.hairline
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

// MARK: - Dial value cell (fixed-width instrument reading — v4.1 D13(c))

/// A tabular reading whose container NEVER resizes as the digit count changes (v4.1
/// D13(c): "fixed-width value cells — a value container never resizes when digit count
/// changes; reserve width for the widest realistic reading"). A hidden `widthTemplate` (the
/// widest reading the cell will ever show, e.g. `"888.8"`, `"100"`) reserves the width; the
/// live `text` is drawn over it at `alignment`. Because both texts apply
/// `.monospacedDigit()` (the v5 numeral law), the template width equals any same-length
/// reading exactly.
///
/// Digit changes roll subtly via `.contentTransition(.numericText())` on `Motion.digitRoll`
/// (~100ms, small travel — D13(b)); pass `rolls: false` for readings that should snap. Under
/// Reduce Motion the roll resolves to an instant swap. The cell carries the reading itself as
/// its accessibility value (the template is hidden from a11y).
struct DialValueCell: View {
    /// The live reading, already formatted (`"71"`, `"130.0"`, `"7:00"`).
    let text: String
    /// The widest realistic reading this cell will show — reserves the fixed width.
    let widthTemplate: String
    var font: Font = .Tokens.smallLabelMedium
    var color: Color = ColorTokens.text1
    /// Where the reading sits inside the reserved cell (trailing for right-aligned columns).
    var alignment: Alignment = .trailing
    var rolls: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(widthTemplate)
            .font(font)
            .monospacedDigit()
            .foregroundStyle(.clear)
            .accessibilityHidden(true)
            .overlay(alignment: alignment) {
                Text(text)
                    .font(font)
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .animation(
                        rolls ? Motion.resolved(Motion.digitRoll, reduceMotion: reduceMotion) : nil,
                        value: text
                    )
            }
            .accessibilityElement()
            .accessibilityLabel(Text(text))
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

// MARK: - Pressable button style (tactile feedback — v4 mechanical key press)

/// **Primitive 1 · Key** (v4.1 Five-Primitive Interaction Law). Tactile press feedback for
/// anything that commits an action (CTAs, key cells, tab items). Scales to 0.97 on press,
/// settling back via `Motion.press` (120ms strong ease-out — the law's 100–160ms window;
/// mechanical, no spring). Two release channels: `pressedOpacity` (dim, the general default)
/// OR `pressedBrightness` (brighten — the canonical Key spec from the demo: an ink-filled key
/// lightens under the finger). No color shift, no shadow. Replace `.buttonStyle(.plain)` with
/// `.buttonStyle(.pressable)` (dim) or `.buttonStyle(.key)` (brighten) on interactive
/// rows / cards / CTAs.
struct PressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var pressedScale: CGFloat = 0.97
    var pressedOpacity: Double = 0.7
    /// Additive brightness on press (0 = off). The Key spec brightens instead of dimming so an
    /// ink-filled key reads as "lit under the finger" rather than "faded".
    var pressedBrightness: Double = 0

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .opacity(configuration.isPressed ? pressedOpacity : 1)
            .brightness(configuration.isPressed ? pressedBrightness : 0)
            .animation(Motion.resolved(Motion.press, reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    /// Tactile press feedback (scale 0.97 + fade, 120ms mechanical settle). Use on
    /// interactive rows/cards/CTAs.
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
    /// Tactile press with custom press depth (e.g. subtler `opacity:` for large surfaces).
    static func pressable(scale: CGFloat = 0.97, opacity: Double = 0.7) -> PressableButtonStyle {
        PressableButtonStyle(pressedScale: scale, pressedOpacity: opacity)
    }
    /// The canonical **Key** press (scale 0.97 + brighten, 120ms). For ink-filled keys — the
    /// fill lifts toward light under the finger rather than dimming (v4.1 demo §2 "KEY").
    static var key: PressableButtonStyle {
        PressableButtonStyle(pressedScale: 0.97, pressedOpacity: 1, pressedBrightness: 0.12)
    }
}

/// **Primitive 2 · Row** (v4.1 Five-Primitive Interaction Law). Touch-down feedback for
/// anything that NAVIGATES (disclosure rows, list rows). A faint ink "well" fills behind the
/// row on press — NO scale (rows are surfaces, not buttons) — settling via `Motion.rowWell`
/// (~110ms). The well is `text1` at 6% (the demo's `rgba(23,24,26,0.06)`), clipped to
/// `CornerTokens.control` by default so it tucks inside the row's own corners; pass a matching
/// `cornerRadius:` when the row sits in a differently-cornered container.
struct RowWellButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var cornerRadius: CGFloat = CornerTokens.control
    var wellColor: Color = ColorTokens.text1.opacity(0.06)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(configuration.isPressed ? wellColor : Color.clear)
            )
            .animation(Motion.resolved(Motion.rowWell, reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == RowWellButtonStyle {
    /// The **Row** press (touch-down well, no scale). Use on navigating rows.
    static var rowWell: RowWellButtonStyle { RowWellButtonStyle() }
    /// The Row press with the well clipped to a specific corner radius.
    static func rowWell(cornerRadius: CGFloat) -> RowWellButtonStyle {
        RowWellButtonStyle(cornerRadius: cornerRadius)
    }
}

// MARK: - Relief-inversion key press (v4.2 "Machined" — pick 4-A, asymmetric)

/// The machined **Key** press (v4.2 pick 4-A): pressing INVERTS the key's relief — a cut top
/// inner-edge and a lit bottom inner-edge fade in (the surface reads as recessed into a
/// pocket), the key drops 0.5px, and its face lifts in brightness under the finger. Timing is
/// ASYMMETRIC: a fast ~85ms attack (`Motion.pressIn`) and an unhurried ~300ms non-bouncy
/// spring release (`Motion.keyReliefRelease`) — quick bite, sprung return. Scale-only key
/// presses are retired (pick 4-A); this replaces `.pressable`/`.key` on the app's real keys.
///
/// Deliberately an OVERLAY, not a background-owner: the pocket is a tint-neutral
/// shade+highlight pair (no opaque fill), so it inverts the relief correctly over BOTH a
/// stone key and an ink-filled CTA without the style needing to know the resting fill. Keys
/// keep drawing their own resting face; only the press treatment lives here. Pass the key's own
/// `cornerRadius` so the pocket edges track the key corners (0 for a butted `KeyRow` cell that
/// the row already clips), or set `isPill` for the v5 primary-CTA capsule.
struct ReliefPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var cornerRadius: CGFloat = CornerTokens.control
    /// true → the pocket edges track a `Capsule()` (`CornerTokens.pill` — the v5 ink-filled
    /// primary CTA) instead of a rounded rectangle.
    var isPill: Bool = false
    /// Additive brightness on press — the "lit under the finger" lift (pick 4-A). Ink keys sit
    /// dark so they lift more to register; stone keys need only a hair.
    var pressedBrightness: Double = 0.03

    /// The pocket: a dark cut along the top inner edge + a soft lit line along the bottom
    /// inner edge — the exact inner-edge pair `DebossedStyle` draws, minus the opaque fill
    /// and outer border, so it reads as "recessed" over any face colour.
    private func pocket<S: InsettableShape>(_ shape: S) -> some View {
        shape
            .inset(by: 0.75)
            .stroke(
                LinearGradient(colors: [ColorTokens.reliefShade, .clear], startPoint: .top, endPoint: .center),
                lineWidth: 1.5
            )
            .overlay(
                shape
                    .inset(by: 0.75)
                    .stroke(
                        LinearGradient(colors: [.clear, ColorTokens.reliefHighlightSoft], startPoint: .center, endPoint: .bottom),
                        lineWidth: 1
                    )
            )
    }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .brightness(pressed ? pressedBrightness : 0)
            .overlay {
                Group {
                    if isPill {
                        pocket(Capsule())
                    } else {
                        pocket(RoundedRectangle(cornerRadius: cornerRadius))
                    }
                }
                .opacity(pressed ? 1 : 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            // The key sinks into the pocket. Sub-pixel, but it sells the depression.
            .offset(y: pressed ? 0.5 : 0)
            // Asymmetric: fast bite on the way down, sprung return on the way up.
            .animation(
                Motion.resolved(pressed ? Motion.pressIn : Motion.keyReliefRelease, reduceMotion: reduceMotion),
                value: pressed
            )
    }
}

extension ButtonStyle where Self == ReliefPressButtonStyle {
    /// Relief-inversion press for a STONE key (standard key cell, secondary action) — a
    /// hair of brightness lift. Pass the key's corner radius (0 for a butted `KeyRow` cell).
    static var reliefPress: ReliefPressButtonStyle { ReliefPressButtonStyle() }
    static func reliefPress(cornerRadius: CGFloat) -> ReliefPressButtonStyle {
        ReliefPressButtonStyle(cornerRadius: cornerRadius)
    }
    /// Relief-inversion press for an INK-FILLED CTA key — the dark face lifts more in brightness
    /// so the depression registers. Pass the key's corner radius (0 for a butted cell).
    static var reliefKey: ReliefPressButtonStyle { ReliefPressButtonStyle(pressedBrightness: 0.10) }
    static func reliefKey(cornerRadius: CGFloat) -> ReliefPressButtonStyle {
        ReliefPressButtonStyle(cornerRadius: cornerRadius, pressedBrightness: 0.10)
    }
    /// Relief-inversion press for the v5 PRIMARY CTA PILL — the ink-filled `Capsule()`
    /// (`CornerTokens.pill`); the pocket edges track the capsule silhouette.
    static var reliefKeyPill: ReliefPressButtonStyle {
        ReliefPressButtonStyle(isPill: true, pressedBrightness: 0.10)
    }
}

// MARK: - Haptics (commit-only feedback — "more life" revision 2026-06-17)

/// Centralized haptic feedback, fired on meaningful commits only — never decoratively.
/// Call `Haptics.prepare()` in `onAppear` (or at the start of a latency-sensitive action) to
/// warm the generators. All calls happen from SwiftUI actions on the main actor.
///
/// **v4.1 haptic policy (D13(a)) — reduced.** Haptics are now rare and load-bearing. Fire ONLY:
/// - `limit()` — a stepper/scrubber hits its min or max bound (per-STEP taps are silent now).
/// - `tap()` — a toggle flip (the one discrete on/off commit) and set-done commit.
/// - `select()` — a true discrete-detent picker landing (segmented control, session-type
///   picker) where each detent is a distinct choice.
/// - `select()` from `TickScale` — ONLY the Home hero count-up's band detents (opt-in).
/// - `success()` / `warning()` — workout saved, PR, spike alert.
/// Everything else (needle micro-updates, digit rolls, row/key presses) is SILENT — the
/// motion carries the feedback. WS3 strips per-tap control haptics against this policy.
enum Haptics {
    private static let impactLight = UIImpactFeedbackGenerator(style: .light)
    private static let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    /// Light tap — the per-set done toggle, toggle flips, and other small discrete commits.
    static func tap() { impactLight.impactOccurred() }
    /// Medium tap — a heavier discrete action.
    static func impact() { impactMedium.impactOccurred() }
    /// Limit reached — a stepper/scrubber hitting its min or max bound. The ONLY per-adjustment
    /// haptic in v4.1 (D13(a)); ordinary steps in the interior are silent. A firm medium bump.
    static func limit() { impactMedium.impactOccurred() }
    /// Selection change — true discrete-detent pickers/segmented controls, scale-band detents.
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
