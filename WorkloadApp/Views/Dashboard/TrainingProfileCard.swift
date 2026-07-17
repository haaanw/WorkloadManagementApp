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
                .padding(.bottom, Spacing.xs)

            Text("trainingProfile.card.title")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)

            Text("trainingProfile.card.body")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
                .padding(.top, Spacing.xs)
                .padding(.bottom, Spacing.sm)

            Button {
                Haptics.tap()
                onComplete()
            } label: {
                Text("trainingProfile.card.action")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xs)
                    .overlay(
                        Capsule().stroke(ColorTokens.divider, lineWidth: 0.5)
                    )
            }
            .buttonStyle(.pressable)
        }
        .cardStyle()
    }
}
