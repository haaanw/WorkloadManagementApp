import SwiftUI

/// Dashboard CTA card prompting the athlete to complete the cold-start questionnaire.
/// Shown when no TrainingProfile exists for the current athlete.
/// Follows the WelcomeActionCard pattern exactly.
struct TrainingProfileCard: View {
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("trainingProfile.card.header")
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Text("trainingProfile.card.title")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
                .padding(.horizontal, 16)

            Text("trainingProfile.card.body")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 16)

            Button(action: onComplete) {
                Text("trainingProfile.card.action")
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
