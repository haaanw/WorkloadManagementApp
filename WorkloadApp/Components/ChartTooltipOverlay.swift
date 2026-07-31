import SwiftUI
import Charts

/// Helper view for gesture handling inside `.chartOverlay` (D-02).
/// Provides tap-scrub interaction to select the nearest data point by date.
struct ChartTooltipGesture: View {
    let proxy: ChartProxy
    let data: [(date: Date, value: Double)]
    @Binding var selectedDate: Date?
    /// Whether lifting the finger drops the selection.
    ///
    /// `true` (the default, and the behaviour both pre-existing call sites keep byte for byte) is
    /// the transient-drag grammar the Load and Recovery glance charts use: a `TooltipBubble`
    /// follows the finger and vanishes with it. The **detail** screens pass `false` because their
    /// reading lives in a persistent readout well — Primitive 3's "fixed-width readout well",
    /// which must not empty out the moment the finger lifts ("digits change, the stone never
    /// resizes"). A defaulted parameter rather than a cloned gesture: duplicating fourteen lines
    /// of snap-to-nearest-day maths to satisfy a file boundary is the worse artefact.
    var clearsOnEnd: Bool = true

    /// Whether the scrub yields the vertical axis to an enclosing `ScrollView`.
    ///
    /// `false` (the default) keeps both glance call sites byte for byte on
    /// `DragGesture(minimumDistance: 0)`: that gesture recognizes on touch-DOWN, before any
    /// translation exists, so the scroll view's pan recognizer never gets a chance to claim the
    /// touch and the plot area stops scrolling. On a ~140pt glance card inside a card stack that
    /// is a small dead zone; on the **detail** screens the plot is 224pt of a scrolling page —
    /// roughly a third of the viewport — and a page that will not scroll under your thumb is a
    /// worse defect than a scrub that needs a few points of travel.
    ///
    /// `true` swaps the drag for the SwiftUI default `minimumDistance` (10pt, the same slop
    /// `UIScrollView`'s pan uses), so a vertical pan resolves to the scroll and a horizontal one
    /// to the scrub. A `SpatialTapGesture` is added alongside it so tap-to-select — which the
    /// zero-distance drag used to provide for free via `onChanged` firing on touch-down — still
    /// works. It is `simultaneousGesture` rather than a composed `.exclusively`, because a tap
    /// and a drag never both complete on one touch.
    var yieldsToScroll: Bool = false

    var body: some View {
        GeometryReader { geometry in
            if yieldsToScroll {
                scrubPlate
                    .gesture(scrubDrag(in: geometry, minimumDistance: 10))
                    .simultaneousGesture(
                        SpatialTapGesture()
                            .onEnded { value in select(at: value.location, in: geometry) }
                    )
            } else {
                scrubPlate
                    .gesture(scrubDrag(in: geometry, minimumDistance: 0))
            }
        }
    }

    private var scrubPlate: some View {
        Rectangle().fill(.clear).contentShape(Rectangle())
    }

    private func scrubDrag(in geometry: GeometryProxy, minimumDistance: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: minimumDistance)
            .onChanged { value in select(at: value.location, in: geometry) }
            .onEnded { _ in
                if clearsOnEnd { selectedDate = nil }
            }
    }

    private func select(at location: CGPoint, in geometry: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let origin = geometry[plotFrame].origin
        let xPosition = location.x - origin.x
        guard let date: Date = proxy.value(atX: xPosition) else { return }
        selectedDate = closestDate(to: date)
    }

    private func closestDate(to target: Date) -> Date? {
        data.min(by: {
            abs($0.date.timeIntervalSince(target)) < abs($1.date.timeIntervalSince(target))
        })?.date
    }
}

/// Tooltip popup view (surfaceEl background, `CornerTokens.control` corners, value + date).
struct TooltipBubble: View {
    let value: String
    let dateLabel: String

    var body: some View {
        VStack(spacing: Spacing.baselinePair) {
            Text(value)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
            // v6: a timestamp is annotation. No `.annotationReveal` here on purpose — this
            // bubble is a transient drag overlay, not a settling surface, so a 340ms
            // settle-then-label delay would read as lag.
            AnnotationLabel(dateLabel, size: .small, color: ColorTokens.text2)
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.baselinePair)
        .background(ColorTokens.surfaceEl, in: RoundedRectangle(cornerRadius: CornerTokens.control))
        .overlay(RoundedRectangle(cornerRadius: CornerTokens.control).stroke(ColorTokens.divider, lineWidth: 0.5))
    }
}
