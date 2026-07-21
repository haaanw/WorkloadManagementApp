import SwiftUI

/// Phase 28, Wave 4 — FLAGGED "method updated" dual-run surface, restyled to design-system
/// restraint (Stage 4a): one quiet label-voice line on a standard plate, with the
/// previous/updated comparison behind an expandable disclosure. No accent, no emphasis
/// plane — this is an administrative note, not a decision moment.
///
/// Renders only when `PRSDualRunSurface.dualRunMessage(...)` returns non-nil (i.e. the master
/// flag `PRSActivation.isEnabled` is ON). With the flag OFF (default), the parent passes
/// `message == nil` and this view renders `EmptyView()` — the Dashboard is BYTE-UNCHANGED.
/// Flag gate + all message data untouched.
struct PRSDualRunCard: View {
    let message: PRSDualRunSurface.DualRunMessage?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false

    var body: some View {
        if let message {
            VStack(alignment: .leading, spacing: 0) {
                // The one quiet line — tappable to disclose the comparison.
                Button {
                    withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Text(message.title)
                            .font(Font.Tokens.label)
                            .foregroundStyle(ColorTokens.text1)
                        Spacer(minLength: Spacing.xs)
                        Image(systemName: "chevron.down")
                            .font(Font.Tokens.micro)
                            .foregroundStyle(ColorTokens.text3)
                            .rotationEffect(.degrees(isExpanded ? -180 : 0))
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressable(scale: 1, opacity: 0.6))
                .accessibilityAddTraits(isExpanded ? [.isButton, .isSelected] : .isButton)

                if isExpanded {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(message.explanation)
                            .font(Font.Tokens.smallLabel)
                            .foregroundStyle(ColorTokens.text2)
                            .fixedSize(horizontal: false, vertical: true)

                        // Previous vs updated, side-by-side. The superseded "Previous"
                        // guidance is de-emphasized (text2); "Updated" is primary (text1) —
                        // hierarchy via semantic tokens only, no accent (DESIGN.md).
                        HStack(alignment: .top, spacing: Spacing.sm) {
                            column(
                                title: String(localized: "prs.dualRun.previous", defaultValue: "Previous"),
                                value: message.previousHeadline,
                                muted: true
                            )
                            Rectangle()
                                .fill(ColorTokens.divider)
                                .frame(width: 0.5)
                            column(
                                title: String(localized: "prs.dualRun.updated", defaultValue: "Updated"),
                                value: message.updatedHeadline,
                                muted: false
                            )
                        }
                    }
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, Spacing.xs)
                    .transition(.opacity)
                }
            }
            .dataPlate(verticalPadding: 0)
            .padding(.horizontal, Spacing.sm)
            // 32pt section break below the hero block (only when the surface renders; flag-off
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
