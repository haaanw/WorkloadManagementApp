import SwiftUI

/// Dashboard CTA card prompting the athlete to complete the cold-start questionnaire.
/// Shown when no TrainingProfile exists for the current athlete.
/// Follows the WelcomeActionCard pattern exactly.
struct TrainingProfileCard: View {
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TRAINING PROFILE")
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Text("Set up your training profile")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
                .padding(.horizontal, 16)

            Text("Answer a few questions about your training to get estimated workload data right away.")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 16)

            Button(action: onComplete) {
                Text("Complete Profile")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .overlay(
                        Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5)
                    )
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
