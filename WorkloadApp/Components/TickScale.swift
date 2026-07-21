import SwiftUI

/// TickScale — the retained instrument grammar, re-inked for DESIGN.md v5 "Pavilion".
///
/// A linear measuring scale in the B&O grammar:
/// - Two-weight tick marks in warm grays: minor 1px (`tickMinor`) / major 1.5px (`tickMajor`).
/// - Optional tick numerals (`Font.Tokens.micro`, 11pt, `text3`-toned) at the major ticks;
///   digits are tabular via `.monospacedDigit()` (v5 numeral law).
/// - Optional ink zone band (theme-driven).
/// - A 1.5px ACCENT needle (`ColorTokens.accent`, travertine) at the current value — a
///   sanctioned live-state accent mark (Accent Rule).
/// - Optional faint ghost mark (planned/previous value) at 0.55 opacity of the numeral ink.
///
/// Two variants:
/// - `.scale` — the full instrument scale (tick field + numerals; hero panel readings).
/// - `.micro` — the compact inline scale (single 1px baseline band + zone band + needle +
///   ghost; verdict-card strike zone).
///
/// Values are generic `Double` units (score points, kilograms, ratios); the component only
/// maps them linearly onto the track. Colors come from `ColorTokens` exclusively via
/// `TickScale.Theme`. Decorative internals are hidden from accessibility: the whole scale is
/// ONE combined element carrying a caller-supplied label (same approach as the verdict
/// card's strike-zone bar).
///
/// Motion (v4 Stage 3″ / v4.1 sweep policy): the view is `Animatable` on `value`, so needle
/// position changes sweep mechanically under whatever `Motion` token the call site's
/// transaction carries (`Motion.state` snap-settle for readings; the Home hero inherits
/// `Motion.scoreCountUp` so the needle sweeps in sync with the counting digits). No
/// transaction (Reduce Motion → `Motion.resolved` returns nil) = the needle settles instantly
/// on the value.
///
/// **Sweep policy (v4.1 D13(d)/(e)) — needles never return to zero.** Because the needle is a
/// pure `Animatable` function of `value`, a value change interpolates DIRECTLY current→new
/// (79→42 travels straight down, never via 0). TickScale itself holds no zero-reset path:
/// sweep-from-zero happens ONLY when the *call site's* bound value genuinely starts at the
/// range floor on first appearance (the sanctioned Home-hero count-up: `displayedScore`
/// animates 0→score once). Callers must not re-seed their bound value to the floor on
/// re-measure — animate the stored reading current→new instead. Minor updates settle under
/// `Motion.state` (a real transaction), not a re-sweep.
///
/// **Detent haptics are opt-in** (v4.1 D13 restricts them to the Home hero). Pass
/// `detents: true` and a `zone` to get one `Haptics.select()` click each time the animated
/// needle crosses a zone-band boundary (max one per frame, never on first render). Default
/// off: the verdict microscale and the Load ACWR scale render silently.
struct TickScale: View, Animatable {

    // MARK: Theme

    /// Tick-scale colors. All values route through `ColorTokens` (v5 warm grays).
    struct Theme {
        let tickMinor: Color
        let tickMajor: Color
        let numeral: Color
        let zoneBand: Color
        let ghost: Color
        /// The `.micro` variant's 1px baseline band.
        let baseline: Color

        /// On the stone card surfaces: warm-gray ticks, INK zone band. The one v5 theme —
        /// every surface is ink-on-stone (Hero Law: no dark surfaces).
        static let light = Theme(
            tickMinor: ColorTokens.tickMinor,
            tickMajor: ColorTokens.tickMajor,
            numeral: ColorTokens.tickNumeral,
            zoneBand: ColorTokens.text1,
            ghost: ColorTokens.tickNumeral,
            baseline: ColorTokens.dividerStrong
        )
    }

    // MARK: Variant

    enum Variant {
        /// Full scale: 11pt two-weight tick field, zone band, needle, numerals row.
        case scale
        /// Compact inline scale: 1px baseline band, zone band, needle, ghost. No ticks/numerals.
        case micro
    }

    // MARK: API

    /// The scale's domain, in the caller's units.
    let range: ClosedRange<Double>
    /// The current reading — marked by the accent needle. `var` (not `let`) because the
    /// animation system writes interpolated values through `animatableData` each frame.
    var value: Double
    /// Optional zone band (e.g. today's productive band), in the caller's units.
    var zone: ClosedRange<Double>? = nil
    /// Optional ghost mark (planned/previous value), in the caller's units.
    var ghost: Double? = nil
    var variant: Variant = .scale
    var theme: Theme = .light
    /// Opt in to zone-band detent haptics (v4.1 D13: restricted to the Home hero). Default off
    /// — the verdict microscale and the Load ACWR scale render without haptics.
    var detents: Bool = false
    /// Render tabular numerals under the major ticks (`.scale` variant only).
    var showsNumerals: Bool = true
    /// Major divisions across the range (4 → major ticks/numerals at 0/25/50/75/100%).
    var majorDivisions: Int = 4
    /// Minor ticks per major division (10 → a minor tick every 2.5% at 4 majors).
    var minorsPerMajor: Int = 10
    /// Numeral formatting for a major-tick value.
    var numeralText: (Double) -> String = { String(Int($0.rounded())) }
    /// The ONE accessibility label for the combined element — supplied by the caller,
    /// phrased in the caller's domain language.
    let accessibilityLabel: Text

    // MARK: Needle motion (Animatable + detent haptics)

    /// The needle position is the animatable channel: state changes to `value` interpolate
    /// per frame (mechanical sweep), driven by the call site's `Motion` token transaction.
    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    /// Reference-type frame memory for detent haptics. The struct is recreated with a fresh
    /// interpolated `animatableData` every animation frame, so the last drawn needle
    /// position must live in `@State`-held reference storage to survive across frames.
    final class DetentTracker {
        var lastValue: Double?
    }

    // NOT private: a private stored property would demote the synthesized memberwise
    // initializer to private and break every call site. Defaulted, so callers ignore it.
    @State var detentTracker = DetentTracker()

    /// Detent haptics (DESIGN.md v4 Motion: detent clicks on scale/needle landings): fire
    /// ONE `Haptics.select()` when the animated needle crosses a zone-band boundary —
    /// evaluated per interpolation frame, at most one click per frame (no haptic spam),
    /// never on the first render. Under Reduce Motion the value lands in a single frame,
    /// so at most one settle click fires (haptics are feedback, not motion).
    private func trackDetents() {
        guard detents, let zone else { return }
        defer { detentTracker.lastValue = value }
        guard let last = detentTracker.lastValue, last != value else { return }
        let crossed = [zone.lowerBound, zone.upperBound].contains { boundary in
            (last < boundary && value >= boundary) || (last > boundary && value <= boundary)
        }
        if crossed { Haptics.select() }
    }

    // MARK: Metrics (component-internal geometry, mockup column D)

    private enum Metrics {
        // .scale — mockup linscale shifted +5 so the needle's overhang stays in-bounds.
        // Height 40 (was 36): the v5 numerals grew 9pt → 11pt (`Font.Tokens.micro`), so the
        // canvas reserves one more 4pt grid step below `numeralTop` so nothing clips.
        static let scaleHeight: CGFloat = 40
        static let tickTop: CGFloat = 5
        static let tickHeight: CGFloat = 11
        static let scaleZoneHeight: CGFloat = 3
        static let needleTop: CGFloat = 0
        static let needleHeight: CGFloat = 22
        static let numeralTop: CGFloat = 21

        // .micro — mockup microscale.
        static let microHeight: CGFloat = 24
        static let microBandY: CGFloat = 9
        static let microZoneTop: CGFloat = 7.5
        static let microZoneHeight: CGFloat = 4
        static let microNeedleTop: CGFloat = 1
        static let microNeedleHeight: CGFloat = 17
        static let microGhostTop: CGFloat = 4
        static let microGhostHeight: CGFloat = 11

        static let minorWidth: CGFloat = 1
        static let majorWidth: CGFloat = 1.5
        static let needleWidth: CGFloat = 1.5
        static let ghostWidth: CGFloat = 1
        static let ghostOpacity: CGFloat = 0.55
    }

    // MARK: Body

    var body: some View {
        let _ = trackDetents()
        return Canvas { context, size in
            switch variant {
            case .scale: drawScale(in: &context, size: size)
            case .micro: drawMicro(in: &context, size: size)
            }
        }
        .frame(height: variant == .scale ? Metrics.scaleHeight : Metrics.microHeight)
        // Warm the selection generator so the first detent click has no latency (opt-in only).
        .onAppear { if detents, zone != nil { Haptics.prepare() } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: Drawing

    private func x(_ v: Double, width: CGFloat) -> CGFloat {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        let unit = (v - range.lowerBound) / span
        return CGFloat(min(max(unit, 0), 1)) * width
    }

    private func fill(_ rect: CGRect, _ color: Color, in context: inout GraphicsContext) {
        context.fill(Path(rect), with: .color(color))
    }

    private func drawScale(in context: inout GraphicsContext, size: CGSize) {
        let w = size.width
        let majors = max(majorDivisions, 1)
        let minors = max(minorsPerMajor, 1)
        let totalTicks = majors * minors

        // Two-weight tick field.
        for i in 0...totalTicks {
            let tickX = CGFloat(i) / CGFloat(totalTicks) * w
            let isMajor = i % minors == 0
            let width = isMajor ? Metrics.majorWidth : Metrics.minorWidth
            fill(
                CGRect(x: tickX - width / 2, y: Metrics.tickTop, width: width, height: Metrics.tickHeight),
                isMajor ? theme.tickMajor : theme.tickMinor,
                in: &context
            )
        }

        // Zone band — just under the tick field.
        if let zone {
            let lo = x(zone.lowerBound, width: w)
            let hi = x(zone.upperBound, width: w)
            fill(
                CGRect(x: lo, y: Metrics.tickTop + Metrics.tickHeight, width: max(hi - lo, 1), height: Metrics.scaleZoneHeight),
                theme.zoneBand,
                in: &context
            )
        }

        // Ghost mark (planned value) — faint, numeral-ink.
        if let ghost {
            fill(
                CGRect(x: x(ghost, width: w) - Metrics.ghostWidth / 2, y: Metrics.tickTop, width: Metrics.ghostWidth, height: Metrics.tickHeight),
                theme.ghost.opacity(Metrics.ghostOpacity),
                in: &context
            )
        }

        // Tabular numerals at the majors: first leading, last trailing, middle centered.
        if showsNumerals {
            let span = range.upperBound - range.lowerBound
            for i in 0...majors {
                let unit = Double(i) / Double(majors)
                let value = range.lowerBound + unit * span
                let text = Text(verbatim: numeralText(value))
                    .font(.Tokens.micro)
                    .monospacedDigit()
                    .foregroundStyle(theme.numeral)
                let resolved = context.resolve(text)
                let textSize = resolved.measure(in: CGSize(width: w, height: Metrics.scaleHeight))
                let anchorX = CGFloat(unit) * w
                let drawX: CGFloat = switch i {
                case 0:      0
                case majors: w - textSize.width
                default:     anchorX - textSize.width / 2
                }
                context.draw(resolved, in: CGRect(x: drawX, y: Metrics.numeralTop, width: textSize.width, height: textSize.height))
            }
        }

        // The accent needle — drawn last, over everything (Accent Rule live-state mark).
        fill(
            CGRect(x: x(value, width: w) - Metrics.needleWidth / 2, y: Metrics.needleTop, width: Metrics.needleWidth, height: Metrics.needleHeight),
            ColorTokens.accent,
            in: &context
        )
    }

    private func drawMicro(in context: inout GraphicsContext, size: CGSize) {
        let w = size.width

        // Baseline band.
        fill(
            CGRect(x: 0, y: Metrics.microBandY, width: w, height: 1),
            theme.baseline,
            in: &context
        )

        // Zone band.
        if let zone {
            let lo = x(zone.lowerBound, width: w)
            let hi = x(zone.upperBound, width: w)
            fill(
                CGRect(x: lo, y: Metrics.microZoneTop, width: max(hi - lo, 1), height: Metrics.microZoneHeight),
                theme.zoneBand,
                in: &context
            )
        }

        // Ghost mark (planned value).
        if let ghost {
            fill(
                CGRect(x: x(ghost, width: w) - Metrics.ghostWidth / 2, y: Metrics.microGhostTop, width: Metrics.ghostWidth, height: Metrics.microGhostHeight),
                theme.ghost.opacity(Metrics.ghostOpacity),
                in: &context
            )
        }

        // The accent needle.
        fill(
            CGRect(x: x(value, width: w) - Metrics.needleWidth / 2, y: Metrics.microNeedleTop, width: Metrics.needleWidth, height: Metrics.microNeedleHeight),
            ColorTokens.accent,
            in: &context
        )
    }
}
