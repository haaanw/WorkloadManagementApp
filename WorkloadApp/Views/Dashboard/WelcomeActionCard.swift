import SwiftUI

/// First-run guidance card shown on Dashboard when the athlete has no sessions or wellness check-ins.
/// Disappears reactively once either action is completed (via @Query on Athlete relationships).
struct WelcomeActionCard: View {
    let onLogWorkout: () -> Void
    let onWellnessCheckIn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("GET STARTED")
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Text("Welcome to Tutrice")
                .font(.Tokens.sectionHead)
                .foregroundStyle(ColorTokens.text1)
                .padding(.horizontal, 16)

            Text("Track your first activity to start building your training profile.")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 16)

            HStack(spacing: 8) {
                Button(action: onLogWorkout) {
                    Text("Log Workout")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .overlay(
                            Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5)
                        )
                }

                Button(action: onWellnessCheckIn) {
                    Text("Wellness Check-In")
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
