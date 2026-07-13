import SwiftUI

/// The "Ink & Grain" halftone signature — an accent-colored dot grid with a 135° fade mask
/// (DESIGN.md v3, locked spec 2026-07-14; reference render `tuwa-c3-vs-d1.html`, middle column).
///
/// LAW (fenced by the design-fence tests):
/// - **Hero plane only.** At most ONE halftone surface per screen — the hero readiness card.
///   Never decorative elsewhere: not on metrics, rows, sheets, banners, or empty states.
/// - The dots are one of the four sanctioned accent appearances (Accent Rule v3).
/// - Always non-interactive and invisible to accessibility.
///
/// Defaults implement the locked spec: dot radius ≈ 1.2pt on an 8pt grid, 0.45 opacity,
/// fading out along the 135° diagonal (top-leading ink → bottom-trailing clear at 72%).
/// Size the field via `.frame(...)` at the call site (reference render uses 130×130,
/// anchored to the hero card's top-trailing corner, clipped by the card).
struct HalftoneField: View {
    /// Dot radius in points (spec ≈ 1.2).
    var dotRadius: CGFloat = 1.2
    /// Grid spacing in points (spec = 8, matching the spacing grid).
    var spacing: CGFloat = 8
    /// Field opacity (spec ≈ 0.45).
    var opacity: Double = 0.45
    /// Where the 135° fade reaches fully clear, as a fraction of the diagonal (spec ≈ 0.72).
    var fadeEnd: CGFloat = 0.72
    /// Dot color — the accent, per Accent Rule v3. Override only for previews/tests.
    var color: Color = ColorTokens.accent

    var body: some View {
        Canvas { context, size in
            var y = spacing / 2
            while y <= size.height {
                var x = spacing / 2
                while x <= size.width {
                    let dot = CGRect(
                        x: x - dotRadius,
                        y: y - dotRadius,
                        width: dotRadius * 2,
                        height: dotRadius * 2
                    )
                    context.fill(Path(ellipseIn: dot), with: .color(color))
                    x += spacing
                }
                y += spacing
            }
        }
        .opacity(opacity)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .clear, location: fadeEnd)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
