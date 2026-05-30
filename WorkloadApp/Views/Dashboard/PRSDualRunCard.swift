import SwiftUI

/// Phase 28, Wave 4 — FLAGGED "method updated" dual-run card (visuals NOT final — human review).
///
/// Renders only when `PRSDualRunSurface.dualRunMessage(...)` returns non-nil (i.e. the master flag
/// `PRSActivation.isEnabled` is ON). With the flag OFF (default), the parent passes `message == nil`
/// and this view renders `EmptyView()` — the Dashboard is BYTE-UNCHANGED.
///
/// DESIGN.md compliance: 0pt corners (`Rectangle`, never `RoundedRectangle`), NO shadows (hairline
/// border instead), General Sans via `Font.Tokens.*`, 8pt-grid spacing, accent reserved for the hero
/// readiness number (NOT used here), semantic `ColorTokens` only. Copy is "Tuwa"-only and never says
/// "injury prediction".
struct PRSDualRunCard: View {
    let message: PRSDualRunSurface.DualRunMessage?

    var body: some View {
        if let message {
            VStack(alignment: .leading, spacing: 8) {
                Text(message.title)
                    .font(Font.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)

                Text(message.explanation)
                    .font(Font.Tokens.smallLabel)
                    .foregroundStyle(ColorTokens.text2)
                    .fixedSize(horizontal: false, vertical: true)

                // Previous vs updated, shown side-by-side during the dual-run window.
                HStack(alignment: .top, spacing: 16) {
                    column(
                        title: String(localized: "prs.dualRun.previous", defaultValue: "Previous"),
                        value: message.previousHeadline
                    )
                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(width: 1)
                    column(
                        title: String(localized: "prs.dualRun.updated", defaultValue: "Updated"),
                        value: message.updatedHeadline
                    )
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ColorTokens.surface)
            .overlay(
                Rectangle()
                    .stroke(ColorTokens.divider, lineWidth: 1)
            )
        } else {
            EmptyView()
        }
    }

    private func column(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Font.Tokens.smallLabel)
                .foregroundStyle(ColorTokens.text2)
            Text(value)
                .font(Font.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
