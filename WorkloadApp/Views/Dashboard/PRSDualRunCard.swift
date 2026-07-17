import SwiftUI

/// Phase 28, Wave 4 — FLAGGED "method updated" dual-run card (visuals NOT final — human review).
///
/// Renders only when `PRSDualRunSurface.dualRunMessage(...)` returns non-nil (i.e. the master flag
/// `PRSActivation.isEnabled` is ON). With the flag OFF (default), the parent passes `message == nil`
/// and this view renders `EmptyView()` — the Dashboard is BYTE-UNCHANGED.
///
/// DESIGN.md compliance: corners via `CornerTokens` (v3 Corner Law — `cardStyle` supplies the card
/// plane), NO shadows (hairline border instead), General Sans via `Font.Tokens.*`, 8pt-grid spacing,
/// accent reserved for the hero
/// readiness number (NOT used here), semantic `ColorTokens` only. Copy is "Tuwa"-only and never says
/// "injury prediction".
struct PRSDualRunCard: View {
    let message: PRSDualRunSurface.DualRunMessage?

    var body: some View {
        if let message {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(message.title)
                    .font(Font.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)

                Text(message.explanation)
                    .font(Font.Tokens.smallLabel)
                    .foregroundStyle(ColorTokens.text2)
                    .fixedSize(horizontal: false, vertical: true)

                // Previous vs updated, shown side-by-side during the dual-run window.
                // The superseded "Previous" guidance is de-emphasized (text2) and the new
                // "Updated" guidance is primary (text1) — hierarchy via semantic tokens only,
                // no accent/extra weight (DESIGN.md).
                HStack(alignment: .top, spacing: Spacing.sm) {
                    column(
                        title: String(localized: "prs.dualRun.previous", defaultValue: "Previous"),
                        value: message.previousHeadline,
                        muted: true
                    )
                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(width: 1)
                    column(
                        title: String(localized: "prs.dualRun.updated", defaultValue: "Updated"),
                        value: message.updatedHeadline,
                        muted: false
                    )
                }
            }
            .cardStyle()
            .padding(.horizontal, Spacing.sm)
            // v2: 32pt section break below the hero block (only when the card renders; flag-off
            // path is EmptyView, so the Dashboard stays byte-identical).
            .padding(.top, Spacing.lg)
        } else {
            EmptyView()
        }
    }

    private func column(title: String, value: String, muted: Bool) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(Font.Tokens.smallLabel)
                .foregroundStyle(ColorTokens.text2)
            Text(value)
                .font(Font.Tokens.body)
                .foregroundStyle(muted ? ColorTokens.text2 : ColorTokens.text1)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
