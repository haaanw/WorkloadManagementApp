import SwiftUI

/// Corner-radius law — DESIGN.md v5 "Pavilion" (2026-07-21).
///
/// Corners are SOFT PRECISION — the v3 scale restored by user decision (v5 carry-over):
/// stone with eased edges, not a machined near-square body. Every nonzero radius in the
/// app MUST come from this enum — the design-fence tests reject
/// `RoundedRectangle(cornerRadius:)` / `.cornerRadius(` in any file that does not
/// reference `CornerTokens`.
///
/// The scale:
/// - Cards / plates / grouped surfaces / sheets → `card` (12pt)
/// - Controls (inputs, cells, steppers, wells, small interactive plates) → `control` (8pt)
/// - `pill` — chips, badges, and the ONE primary CTA per screen (ink-filled capsule)
///
/// Unchanged laws that corners do NOT relax:
/// - Hairline borders stay (0.5pt `divider` / `dividerStrong` strokes).
/// - Still NO shadows — elevation remains plane + hairline + relief only.
enum CornerTokens {
    /// 12pt — cards, plates, grouped surfaces (metrics strip, session rows, sheets).
    static let card: CGFloat = 12

    /// 8pt — controls: text inputs, cells, steppers, pickers, readout wells, small plates.
    static let control: CGFloat = 8

    /// Pill — chips, status badges, and the primary CTA (ink-filled `Capsule()`).
    static let pill: CGFloat = .infinity
}
