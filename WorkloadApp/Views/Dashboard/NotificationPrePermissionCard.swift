import SwiftUI

/// One-time inline card prompting user to enable weekly notification summaries.
/// Shown on first dashboard visit when notification authorization is .notDetermined.
/// Disappears permanently after either button is tapped (per D-07, research pitfall #4).
struct NotificationPrePermissionCard: View {
    let onEnable: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("notificationCard.title")
                .font(.Tokens.micro)
                .tracking(0.9)
                .foregroundStyle(ColorTokens.text3)
                .padding(.bottom, Spacing.xs)

            Text("notificationCard.subtitle")
                .font(.Tokens.sectionHead)
                .foregroundStyle(ColorTokens.text1)

            Text("notificationCard.body")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
                .padding(.top, Spacing.xs)
                .padding(.bottom, Spacing.sm)

            HStack(spacing: Spacing.xs) {
                Button {
                    Haptics.tap()
                    onEnable()
                } label: {
                    Text("notificationCard.action.enable")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.xs)
                        .background(ColorTokens.surfaceEl2, in: RoundedRectangle(cornerRadius: CornerTokens.control))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerTokens.control)
                                .stroke(ColorTokens.dividerStrong, lineWidth: 0.5)
                        )
                }
                .buttonStyle(.pressable)

                Button {
                    Haptics.tap()
                    onDismiss()
                } label: {
                    Text("notificationCard.action.dismiss")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.xs)
                        .background(ColorTokens.surfaceEl2, in: RoundedRectangle(cornerRadius: CornerTokens.control))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerTokens.control)
                                .stroke(ColorTokens.dividerStrong, lineWidth: 0.5)
                        )
                }
                .buttonStyle(.pressable)
            }
        }
        .cardStyle()
        .accessibilityElement(children: .contain)
    }
}
