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
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Text("notificationCard.subtitle")
                .font(.Tokens.sectionHead)
                .foregroundStyle(ColorTokens.text1)
                .padding(.horizontal, 16)

            Text("notificationCard.body")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 16)

            HStack(spacing: 8) {
                Button(action: onEnable) {
                    Text("notificationCard.action.enable")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .overlay(
                            Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5)
                        )
                }

                Button(action: onDismiss) {
                    Text("notificationCard.action.dismiss")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .overlay(
                            Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5)
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(ColorTokens.surface)
        .overlay(
            Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5)
        )
        .accessibilityElement(children: .contain)
    }
}
