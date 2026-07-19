import SwiftUI

/// TickScale — the v4 "Instrument" signature component (DESIGN.md v4, mockup column D).
///
/// A linear measuring scale in the B&O grammar:
/// - Two-weight tick marks: minor 1px (`tickMinor`) / major 1.5px (`tickMajor`).
/// - Optional mono tick numerals (`Font.Tokens.dialTick`, 9pt) at the major ticks.
/// - Optional zone band: ink on light surfaces, `panelInk` on the panel (theme-driven).
/// - A 1.5px red index needle (`ColorTokens.index`) at the current value — one of the only
///   sanctioned index-mark locations (Index Rule).
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
/// Motion (v4 Stage 3″): the view is `Animatable` on `value`, so needle position changes
/// sweep mechanically under whatever `Motion` token the call site's transaction carries
/// (`Motion.state` snap-settle for readings; the Home hero inherits `Motion.scoreCountUp`
/// so the needle sweeps in sync with the counting digits). No transaction (Reduce Motion →
/// `Motion.resolved` returns nil) = the needle settles instantly on the value. Detent
/// haptics: one `Haptics.select()` click each time the animated needle crosses a zone-band
/// boundary (max one per frame, never on first render).
struct TickScale: View, Animatable {

    // MARK: Theme

    /// Tick-scale colors for the two material contexts. All values route through
    /// `ColorTokens` (column D mockup vars, tokenized in Stage 1″).
    struct Theme {
        let tickMinor: Color
        let tickMajor: Color
        let numeral: Color
        let zoneBand: Color
        let ghost: Color
        /// The `.micro` variant's 1px baseline band.
        let baseline: Color

        /// On aluminum/card surfaces: machined dark-gray ticks, INK zone band.
        static let light = Theme(
            tickMinor: ColorTokens.tickMinor,
            tickMajor: ColorTokens.tickMajor,
            numeral: ColorTokens.tickNumeral,
            zoneBand: ColorTokens.text1,
            ghost: ColorTokens.tickNumeral,
            baseline: ColorTokens.dividerStrong
        )

        /// On the black instrument panel: same ticks, `panelInk` zone band, panel grays.
        static let panel = Theme(
            tickMinor: ColorTokens.tickMinor,
            tickMajor: ColorTokens.tickMajor,
            numeral: ColorTokens.panelInk2,
            zoneBand: ColorTokens.panelInk,
            ghost: ColorTokens.panelInk2,
            baseline: ColorTokens.panelHairline
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
    /// The current reading — marked by the red index needle. `var` (not `let`) because the
    /// animation system writes interpolated values through `animatableData` each frame.
    var value: Double
    /// Optional zone band (e.g. today's productive band), in the caller's units.
    var zone: ClosedRange<Double>? = nil
    /// Optional ghost mark (planned/previous value), in the caller's units.
    var ghost: Double? = nil
    var variant: Variant = .scale
    var theme: Theme = .light
    /// Render mono numerals under the major ticks (`.scale` variant only).
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
        guard let zone else { return }
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
        static let scaleHeight: CGFloat = 36
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
        // Warm the selection generator so the first detent click has no latency.
        .onAppear { if zone != nil { Haptics.prepare() } }
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

        // Mono numerals at the majors: first leading, last trailing, middle centered.
        if showsNumerals {
            let span = range.upperBound - range.lowerBound
            for i in 0...majors {
                let unit = Double(i) / Double(majors)
                let value = range.lowerBound + unit * span
                let text = Text(verbatim: numeralText(value))
                    .font(.Tokens.dialTick)
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

        // The red index needle — drawn last, over everything (Index Rule mark).
        fill(
            CGRect(x: x(value, width: w) - Metrics.needleWidth / 2, y: Metrics.needleTop, width: Metrics.needleWidth, height: Metrics.needleHeight),
            ColorTokens.index,
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

        // The red index needle.
        fill(
            CGRect(x: x(value, width: w) - Metrics.needleWidth / 2, y: Metrics.microNeedleTop, width: Metrics.needleWidth, height: Metrics.microNeedleHeight),
            ColorTokens.index,
            in: &context
        )
    }
}
