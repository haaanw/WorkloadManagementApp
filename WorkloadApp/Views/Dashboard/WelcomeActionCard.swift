import SwiftUI

/// First-run guidance card shown on Dashboard when the athlete has no sessions or wellness check-ins.
/// Disappears reactively once either action is completed (via @Query on Athlete relationships).
struct WelcomeActionCard: View {
    let onLogWorkout: () -> Void
    let onWellnessCheckIn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("welcome.card.header")
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Text("welcome.card.title")
                .font(.Tokens.sectionHead)
                .foregroundStyle(ColorTokens.text1)
                .padding(.horizontal, 16)

            Text("welcome.card.body")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 16)

            HStack(spacing: 8) {
                Button(action: onLogWorkout) {
                    Text("dashboard.action.logWorkout")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .overlay(
                            Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5)
                        )
                }

                Button(action: onWellnessCheckIn) {
                    Text("welcome.card.action.checkIn")
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
    }
}
