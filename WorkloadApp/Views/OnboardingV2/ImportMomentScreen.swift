import SwiftUI

/// OnboardingV2 — the "bring your program" moment (amendment 6, closing reorientation
/// R10). Placed AFTER account creation because a program needs an athlete to belong to
/// (the C1 law: nothing persists pre-auth), and after the paywall so both purchase
/// outcomes pass through it. Mounts Lane A's `ProgramImportSheet` — the plan-led one
/// door (paste / PDF / photo / say it, duration ladder, transition compare) — never a
/// forked second import UI. Skippable by law.
struct ImportMomentScreen: View {
    /// Called on import success or skip — the flow moves on either way.
    let onDone: () -> Void

    @State private var showImportSheet = false
    @State private var importedTemplateName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("onboardingV2.import.title")
                .font(.Tokens.pageTitle)
                .foregroundStyle(ColorTokens.text1)
                .fixedSize(horizontal: false, vertical: true)

            Text("onboardingV2.import.subtitle")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.xs)

            VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                AnnotationLabel(key: "onboardingV2.import.anno.text", size: .small)
                    .annotationReveal(index: 0)
                AnnotationLabel(key: "onboardingV2.import.anno.pdf", size: .small)
                    .annotationReveal(index: 1)
                AnnotationLabel(key: "onboardingV2.import.anno.photo", size: .small)
                    .annotationReveal(index: 2)
            }
            .padding(.top, Spacing.lg)

            if let importedTemplateName {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "checkmark")
                        .font(.Tokens.micro)
                        .foregroundStyle(ColorTokens.text2)
                    Text(importedTemplateName)
                        .font(.Tokens.bodyMedium)
                        .foregroundStyle(ColorTokens.text1)
                }
                .padding(Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ColorTokens.surfaceEl, in: RoundedRectangle(cornerRadius: CornerTokens.card))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerTokens.card)
                        .stroke(ColorTokens.divider, lineWidth: 0.5)
                )
                .padding(.top, Spacing.lg)
            }

            Spacer()

            if importedTemplateName == nil {
                PrimaryActionButton(title: "onboardingV2.import.cta") {
                    showImportSheet = true
                }

                Button {
                    onDone()
                } label: {
                    Text("onboardingV2.import.skip")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("onboardingV2.import.skip")
            } else {
                PrimaryActionButton(title: "action.continue") {
                    onDone()
                }
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.xs)
        .sheet(isPresented: $showImportSheet) {
            ProgramImportSheet(onActivated: { program in
                importedTemplateName = program.name
            })
        }
    }
}
