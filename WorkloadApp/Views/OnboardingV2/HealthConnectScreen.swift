import SwiftUI

/// OnboardingV2 screen 8 — HealthKit, framed as what the user gets back ("read your last
/// 90 days"), never "grant permission" (spec §3). Keeps the shipped `connectionState`
/// routing: a returning user who already granted must never be asked twice; only
/// `.notRequested` presents the system sheet. This screen owns its own CTA pair — the
/// coordinator's shared pill is hidden here.
struct HealthConnectScreen: View {
    @Environment(AppContainer.self) private var container

    /// Both doors end here: connect (after the system sheet resolves) or skip. The
    /// coordinator computes the reveal and advances; this screen never scores anything.
    let onResolved: () -> Void

    @State private var isRequesting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("onboardingV2.health.title")
                    .font(.Tokens.pageTitle)
                    .foregroundStyle(ColorTokens.text1)
                    .fixedSize(horizontal: false, vertical: true)
                Text("onboardingV2.health.subtitle")
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.sm)
            .padding(.top, Spacing.md)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                signalRow(icon: "waveform.path.ecg", labelKey: "onboardingV2.health.item.hrv", index: 0)
                signalRow(icon: "heart.fill", labelKey: "onboardingV2.health.item.rhr", index: 1)
                signalRow(icon: "bed.double.fill", labelKey: "onboardingV2.health.item.sleep", index: 2)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.top, Spacing.lg)

            Text("onboardingV2.health.privacy")
                .font(.Tokens.smallLabel)
                .foregroundStyle(ColorTokens.text3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.sm)
                .padding(.top, Spacing.md)

            Spacer()

            switch container.healthKitService.connectionState {
            case .notRequested:
                PrimaryActionButton(title: "onboardingV2.health.connect", isLoading: isRequesting) {
                    Task {
                        isRequesting = true
                        try? await container.healthKitService.requestAuthorization()
                        isRequesting = false
                        onResolved()
                    }
                }
                .padding(.horizontal, Spacing.sm)

                Button {
                    onResolved()
                } label: {
                    Text("onboardingV2.health.skip")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("onboardingV2.health.skip")

            case .requestedNoData, .connected:
                // Already granted on this device (re-ask guard) — affirm and continue.
                Text("onboardingV2.health.connected")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.bottom, Spacing.sm)

                PrimaryActionButton(title: "action.continue", isLoading: isRequesting) {
                    isRequesting = true
                    onResolved()
                }
                .padding(.horizontal, Spacing.sm)
            }
        }
        .padding(.bottom, Spacing.xs)
    }

    private func signalRow(icon: String, labelKey: LocalizedStringKey, index: Int) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text2)
                .frame(width: 24)
            Text(labelKey)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .annotationReveal(index: index)
    }
}
