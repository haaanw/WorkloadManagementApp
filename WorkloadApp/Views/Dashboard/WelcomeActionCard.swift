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
                .tracking(0.9)
                .foregroundStyle(ColorTokens.text3)
                .padding(.bottom, Spacing.xs)

            Text("welcome.card.title")
                .font(.Tokens.sectionHead)
                .foregroundStyle(ColorTokens.text1)

            Text("welcome.card.body")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
                .padding(.top, Spacing.xs)
                .padding(.bottom, Spacing.sm)

            HStack(spacing: Spacing.xs) {
                Button {
                    Haptics.tap()
                    onLogWorkout()
                } label: {
                    Text("dashboard.action.logWorkout")
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
                    onWellnessCheckIn()
                } label: {
                    Text("welcome.card.action.checkIn")
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
    }
}
