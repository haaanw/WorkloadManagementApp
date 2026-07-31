import SwiftUI

/// Dashboard CTA card prompting the athlete to complete the cold-start questionnaire.
/// Shown when no TrainingProfile exists for the current athlete.
/// Follows the WelcomeActionCard pattern exactly.
struct TrainingProfileCard: View {
    let onComplete: () -> Void

    // Micro-caps are Latin-only typography (DESIGN.md v6: "micro-caps only at micro size,
    // Latin locales only"; zh-Hans takes no case transform and no added tracking). The
    // eyebrow below applied 0.9pt tracking unconditionally, so Chinese was being tracked.
    @Environment(\.locale) private var locale
    private var isLatin: Bool { locale.language.languageCode?.identifier != "zh" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("trainingProfile.card.header")
                .font(.Tokens.micro)
                .tracking(isLatin ? 0.9 : 0)
                .textCase(isLatin ? .uppercase : nil)
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
                    .background(ColorTokens.surfaceEl2, in: RoundedRectangle(cornerRadius: CornerTokens.control))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerTokens.control)
                            .stroke(ColorTokens.dividerStrong, lineWidth: 0.5)
                    )
            }
            .buttonStyle(.pressable)
        }
        .cardStyle()
    }
}
