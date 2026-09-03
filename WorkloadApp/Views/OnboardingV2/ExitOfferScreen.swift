import SwiftUI
import RevenueCat

/// OnboardingV2 screen 12 — the exit offer. Fires only on a hard-paywall dismiss intent,
/// once per install (the caller stamps `exitOfferShown` before presenting). Shows the
/// `onboarding_exit` offering's annual package; if the caller had no such offering this
/// screen is never presented (C6 graceful absence). Decline returns to the paywall.
struct ExitOfferScreen: View {
    let offering: Offering?
    let onAccepted: () -> Void
    let onDeclined: () -> Void

    @Environment(AppContainer.self) private var container

    @State private var isPurchasing = false
    @State private var errorMessage: String?

    private var package: Package? {
        offering?.availablePackages.first { $0.packageType == .annual }
            ?? offering?.availablePackages.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            Text("onboardingV2.exit.title")
                .font(.Tokens.pageTitle)
                .foregroundStyle(ColorTokens.text1)

            Text("onboardingV2.exit.subtitle")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.xs)

            if let package {
                VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                    AnnotationLabel(key: "onboardingV2.exit.anno", size: .small)
                    Text(package.localizedPriceString)
                        .font(.Tokens.displayAction)
                        .monospacedDigit()
                        .foregroundStyle(ColorTokens.text1)
                    AnnotationLabel(key: "onboardingV2.exit.terms", size: .small)
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

            if let errorMessage {
                Text(errorMessage)
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.zoneDanger)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.sm)
            }

            Spacer()

            PrimaryActionButton(
                title: "onboardingV2.exit.accept",
                isLoading: isPurchasing,
                isDisabled: package == nil
            ) {
                guard let package else { return }
                Task { await purchase(package) }
            }

            Button {
                onDeclined()
            } label: {
                Text("onboardingV2.exit.decline")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("onboardingV2.exit.decline")
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.bottom, Spacing.md)
        .background(ColorTokens.background)
    }

    private func purchase(_ package: Package) async {
        isPurchasing = true
        errorMessage = nil
        do {
            try await container.subscriptionService.purchase(package: package)
            if container.subscriptionService.isPro {
                Haptics.success()
                onAccepted()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isPurchasing = false
    }
}
