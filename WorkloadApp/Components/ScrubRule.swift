import SwiftUI

/// ScrubRule — the always-visible value landscape (v1.7.2, HAN-gated variant B "Bench").
///
/// `TickScale` maps a whole domain across the available width and moves the needle inside it.
/// A scrub control needs the inverse: the needle is FIXED at the centre and the domain
/// translates underneath it at a constant pitch, so a value that is three detents away is
/// always the same number of points away on screen. That is the property HAN's standing
/// critique asked for — "you cannot know where a swipe lands before touching it" — and it is
/// why this is a sibling component rather than a variant of `TickScale`.
///
/// The grammar is `TickScale`'s, unchanged: two-weight tick marks in warm grays
/// (`tickMinor` / `tickMajor`), numerals in the annotation voice (`Font.Tokens.annoSmall`,
/// tabular), and a 1.5pt **accent** needle — a needle is a live-state mark, which is accent's
/// exclusive territory, never a metric hue.
///
/// Above the ticks sits a **landmark band**: the values that already mean something to this
/// athlete — `●` last session, `○` the suggestion. Marginalia in the margin, never over the
/// data. Labels are allocated by importance and dropped where two would collide; the glyph
/// always survives, because the position is the information and the word is the courtesy.
///
/// The view is pure drawing. It holds no gesture and no state: the call site owns the drag,
/// the detent arithmetic, and the round-7 cancellation guard, and passes the result down as
/// `value` plus a sub-detent `fraction`. That keeps one copy of the gesture law in
/// `SetEntryFields` rather than two.
struct ScrubRule: View {

    // MARK: Landmark

    /// A value on the rule that already means something. Drawn as a glyph in the band above
    /// the ticks, with its label when there is room for it.
    struct Landmark: Identifiable {
        let id = UUID()
        /// Position, in the rule's units.
        let value: Double
        /// One glyph from the v6 annotation set — `●` measured, `○` proposed.
        let glyph: String
        /// Short uppercase word. Localized by the call site: this component draws, it does not
        /// resolve strings.
        let label: String
        /// Lower wins the label when two landmarks collide. Ties break on order.
        let priority: Int
    }

    // MARK: API

    /// The rule's domain, in the caller's units.
    let range: ClosedRange<Double>
    /// One detent.
    let step: Double
    /// The detent currently under the needle.
    let value: Double
    /// Sub-detent remainder in STEPS, clamped to [−0.5, 0.5]. Slides the rule continuously with
    /// the finger so the next numeral visibly APPROACHES rather than teleporting — the round-7
    /// law, carried over from the retired preview tape.
    var fraction: CGFloat = 0
    /// Points of travel per detent. The one number worth re-tuning on device: it trades control
    /// against how much landscape is visible at rest.
    var pitch: CGFloat = 30
    /// A major tick (taller, heavier, numbered) every N detents.
    var majorEvery: Int = 2
    /// Phase for the majors, in detents from the range floor. A reps rule starts at 1 and wants
    /// its numerals on the even values, which is offset 1.
    var majorOffset: Int = 0
    var landmarks: [Landmark] = []
    /// Narrow rules draw glyphs only — there is no room for a word beside them.
    var showsLandmarkLabels: Bool = true
    /// Numeral formatting for a major tick.
    var numeralText: (Double) -> String = { String(Int($0.rounded())) }
    /// The ONE accessibility label for the combined element, phrased in the caller's domain.
    /// Every internal mark is decorative to VoiceOver; the call site exposes the adjustable
    /// action.
    let accessibilityLabel: Text

    /// The annotation voice's case + tracking law is applied HERE, not at the call site — this
    /// view is the modifier for canvas-drawn marginalia, the same way `AnnotationLabel` is for
    /// laid-out marginalia. A `Canvas` resolves a `Text`, so `.textCase` (a View modifier) is
    /// unavailable and the transform has to be done on the string; the locale gate is the same
    /// one `AnnotationLabel` uses, because uppercase is meaningless in zh-Hans and tracking
    /// harms CJK.
    @Environment(\.locale) private var locale
    private var isLatin: Bool { locale.language.languageCode?.identifier != "zh" }

    // MARK: Metrics (component-internal geometry)

    private enum Metrics {
        /// 48 = landmark band 16 + tick band 16 + numeral band 16, all on the 8pt grid.
        static let height: CGFloat = 48
        static let landmarkBaseline: CGFloat = 11
        static let tickTop: CGFloat = 18
        static let minorHeight: CGFloat = 7
        static let majorHeight: CGFloat = 13
        static let numeralTop: CGFloat = 34
        /// The needle OVERHANGS the tick field at both ends (`TickScale` does the same). Without
        /// the overhang a 1.5pt accent line inside a field of 1.5pt major ticks reads as one more
        /// tick — measured on device, and worst exactly where it matters most, at a value that
        /// sits on a major.
        static let needleTop: CGFloat = 12
        static let needleHeight: CGFloat = 25
        static let minorWidth: CGFloat = 1
        static let majorWidth: CGFloat = 1.5
        static let needleWidth: CGFloat = 1.5
        /// Minimum horizontal gap between two landmark LABELS before the lower-priority one
        /// gives its word up.
        static let labelClearance: CGFloat = 56
    }

    /// Floor-modulo. Swift's `%` follows the sign of the dividend, which puts the majors in the
    /// wrong phase for any detent below `majorOffset`.
    private static func phase(_ index: Int, _ span: Int) -> Int {
        let r = index % span
        return r < 0 ? r + abs(span) : r
    }

    // MARK: Body

    var body: some View {
        Canvas { context, size in
            draw(in: &context, size: size)
        }
        .frame(height: Metrics.height)
        .mask(edgeFade)
        .overlay(alignment: .center) {
            // The needle is drawn OUTSIDE the mask: it marks the reading and must never fade.
            Rectangle()
                .fill(ColorTokens.accent)
                .frame(width: Metrics.needleWidth, height: Metrics.needleHeight)
                .offset(y: Metrics.needleTop + Metrics.needleHeight / 2 - Metrics.height / 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    /// Fades the rule into the plane at both ends. Opaque black masks; only the alpha matters.
    private var edgeFade: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0), location: 0),
                .init(color: .black, location: 0.16),
                .init(color: .black, location: 0.84),
                .init(color: .black.opacity(0), location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: Drawing

    /// Screen x for a value: the needle sits at the centre, and the domain translates.
    private func x(_ v: Double, width: CGFloat) -> CGFloat {
        width / 2 + CGFloat((v - value) / step) * pitch - fraction * pitch
    }

    private func fill(_ rect: CGRect, _ color: Color, in context: inout GraphicsContext) {
        context.fill(Path(rect), with: .color(color))
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let width = size.width
        guard width > 0, step > 0, pitch > 0 else { return }

        // Only the detents that can reach the canvas are drawn — a 0…300 kg domain at 2.5 kg
        // is 121 detents and all but a dozen are off-screen every frame.
        let visibleSteps = Int((width / 2 / pitch).rounded(.up)) + 2
        let centreIndex = Int(((value - range.lowerBound) / step).rounded())
        let maxIndex = Int(((range.upperBound - range.lowerBound) / step).rounded())
        let lower = max(0, centreIndex - visibleSteps)
        let upper = min(maxIndex, centreIndex + visibleSteps)
        guard lower <= upper else { return }

        let majorSpan = max(majorEvery, 1)

        for index in lower...upper {
            let v = range.lowerBound + Double(index) * step
            let tickX = x(v, width: width)
            let isMajor = Self.phase(index - majorOffset, majorSpan) == 0
            let markWidth = isMajor ? Metrics.majorWidth : Metrics.minorWidth
            fill(
                CGRect(
                    x: tickX - markWidth / 2,
                    y: Metrics.tickTop,
                    width: markWidth,
                    height: isMajor ? Metrics.majorHeight : Metrics.minorHeight
                ),
                isMajor ? ColorTokens.tickMajor : ColorTokens.tickMinor,
                in: &context
            )

            guard isMajor else { continue }
            let text = Text(verbatim: numeralText(v))
                .font(.Tokens.annoSmall)
                .monospacedDigit()
                .foregroundStyle(ColorTokens.tickNumeral)
            let resolved = context.resolve(text)
            let textSize = resolved.measure(in: CGSize(width: width, height: Metrics.height))
            context.draw(
                resolved,
                in: CGRect(
                    x: tickX - textSize.width / 2,
                    y: Metrics.numeralTop,
                    width: textSize.width,
                    height: textSize.height
                )
            )
        }

        drawLandmarks(in: &context, width: width)
    }

    private func drawLandmarks(in context: inout GraphicsContext, width: CGFloat) {
        guard !landmarks.isEmpty else { return }

        // Allocate the words by IMPORTANCE, not left-to-right, so a crowded band keeps the one
        // that matters. Positions are absolute, so the allocation is stable while scrubbing.
        var claimed: [CGFloat] = []
        var labelled = Set<UUID>()
        if showsLandmarkLabels {
            for landmark in landmarks.sorted(by: { $0.priority < $1.priority }) {
                let px = x(landmark.value, width: width)
                let collides = claimed.contains { abs($0 - px) < Metrics.labelClearance }
                if !collides {
                    claimed.append(px)
                    labelled.insert(landmark.id)
                }
            }
        }

        for landmark in landmarks {
            let px = x(landmark.value, width: width)
            let word = isLatin ? landmark.label.uppercased(with: locale) : landmark.label
            let body = labelled.contains(landmark.id)
                ? "\(landmark.glyph) \(word)"
                : landmark.glyph
            let text = Text(verbatim: body)
                .font(.Tokens.annoSmall)
                .monospacedDigit()
                .tracking(isLatin ? 0.5 : 0)
                .foregroundStyle(ColorTokens.text2)
            let resolved = context.resolve(text)
            let size = resolved.measure(in: CGSize(width: width, height: Metrics.height))
            context.draw(
                resolved,
                in: CGRect(
                    x: px - size.width / 2,
                    y: Metrics.landmarkBaseline - size.height / 2,
                    width: size.width,
                    height: size.height
                )
            )
        }
    }
}
