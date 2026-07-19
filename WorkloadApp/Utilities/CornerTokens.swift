import SwiftUI

/// Corner-radius law — DESIGN.md v4 "Instrument" (2026-07-20).
///
/// Corners are NEAR-SQUARE: the geometry of a machined instrument body, not a rounded app.
/// Every nonzero radius in the app MUST come from this enum — the design-fence tests
/// reject `RoundedRectangle(cornerRadius:)` / `.cornerRadius(` in any file that does not
/// reference `CornerTokens`.
///
/// The scale (v4, retuned from v3's 12/8/pill):
/// - Cards / plates / grouped surfaces → `card` (5pt)
/// - The black instrument panel → `panel` (5pt)
/// - Controls (inputs, segmented cells, steppers, small interactive plates) → `control` (4pt)
/// - `pill` remains defined but is DEMOTED: chips/badges only. CTAs are NOT pills in v4 —
///   they are butted key-row cells (see DESIGN.md Key Row law).
///
/// Unchanged laws that corners do NOT relax:
/// - Hairline borders stay (0.5pt `divider` / `dividerStrong` strokes).
/// - Still NO shadows — elevation remains plane + hairline only.
enum CornerTokens {
    /// 5pt — cards, plates, grouped surfaces (metrics strip, session rows, sheets).
    static let card: CGFloat = 5

    /// 5pt — the black instrument panel (the one hero surface per screen).
    static let panel: CGFloat = 5

    /// 4pt — controls: text inputs, segmented cells, steppers, pickers, small interactive plates.
    static let control: CGFloat = 4

    /// Pill — DEMOTED in v4: chips and status badges only, never CTAs (CTAs are butted
    /// key cells). Prefer `Capsule()` as the canonical chip shape; when a radius literal is
    /// required, this resolves to capsule geometry at any control height.
    static let pill: CGFloat = .infinity
}
