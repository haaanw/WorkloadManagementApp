import SwiftUI

/// Corner-radius law — DESIGN.md v3 "Ink & Grain" (2026-07-14).
///
/// The v1/v2 "0pt everywhere" rule is RETIRED. Corners are now a three-step token scale,
/// and every nonzero radius in the app MUST come from this enum — the design-fence tests
/// reject `RoundedRectangle(cornerRadius:)` / `.cornerRadius(` in any file that does not
/// reference `CornerTokens`.
///
/// The scale (locked spec, user decision 2026-07-14):
/// - Cards / plates / grouped surfaces → `card` (12pt)
/// - Controls (inputs, segmented cells, steppers, small interactive plates) → `control` (8pt)
/// - Primary CTAs and chips → `pill` (capsule geometry)
///
/// Unchanged laws that corners do NOT relax:
/// - Hairline borders stay (0.5pt `divider` / `dividerStrong` strokes).
/// - Still NO shadows — elevation remains plane + hairline only.
enum CornerTokens {
    /// 12pt — cards, plates, grouped surfaces (hero card, metrics strip, session rows, sheets).
    static let card: CGFloat = 12

    /// 8pt — controls: text inputs, segmented cells, steppers, pickers, small interactive plates.
    static let control: CGFloat = 8

    /// Pill — primary CTAs and chips. Prefer `Capsule()` as the canonical shape; when a
    /// radius literal is required, this resolves to capsule geometry at any control height.
    static let pill: CGFloat = .infinity
}
