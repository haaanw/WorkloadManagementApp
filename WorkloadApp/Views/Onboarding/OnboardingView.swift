import SwiftUI
import SwiftData

/// 4-step paged onboarding flow: language, training frequency, experience level, HealthKit permission.
/// Presented after signup for new users whose `trainingFrequency` or `experienceLevel` is nil.
/// Step 0 (language) pre-selects the system-resolved locale; tapping a row live-switches the app.
struct OnboardingView: View {
    let onComplete: () -> Void

    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var athletes: [Athlete]

    @State private var currentStep = 0
    @State private var selectedFrequency: TrainingFrequency?
    @State private var selectedLevel: ExperienceLevel?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                languageStep
                    .opacity(currentStep == 0 ? 1 : 0)
                frequencyStep
                    .opacity(currentStep == 1 ? 1 : 0)
                experienceStep
                    .opacity(currentStep == 2 ? 1 : 0)
                healthKitStep
                    .opacity(currentStep == 3 ? 1 : 0)
            }
            .animation(Motion.resolved(Motion.screen, reduceMotion: reduceMotion), value: currentStep)

            // MARK: Dot indicators + Continue button

            VStack(spacing: 24) {
                dotIndicators

                if currentStep < 3 {
                    continueButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 48)
        }
        .background(ColorTokens.background)
    }

    // MARK: - Step 0: Language

    private var languageStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(
                title: "onboarding.language.title",
                subtitle: "onboarding.language.subtitle"
            )

            VStack(spacing: 0) {
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                ForEach(container.localeManager.supportedLocales, id: \.identifier) { locale in
                    languageRow(for: locale)
                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 32)

            Spacer()
        }
    }

    @ViewBuilder
    private func languageRow(for locale: Locale) -> some View {
        Button {
            Haptics.select()
            container.localeManager.setLocale(locale)
        } label: {
            HStack {
                if container.localeManager.activeLocale.identifier == locale.identifier {
                    Image(systemName: "checkmark")
                        .frame(width: 24)
                        .foregroundStyle(ColorTokens.text1)
                } else {
                    Color.clear.frame(width: 24, height: 1)
                }
                Text(languageAutonym(for: locale))
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text1)
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable(scale: 1, opacity: 0.6))
    }

    private func languageAutonym(for locale: Locale) -> String {
        switch locale.identifier {
        case "zh-Hans": return "中文(简体)"
        default:        return "English"
        }
    }

    // MARK: - Step 1: Training Frequency

    private var frequencyStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(
                title: "onboarding.frequency.title",
                subtitle: "onboarding.frequency.subtitle"
            )

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 8
            ) {
                ForEach(TrainingFrequency.allCases) { freq in
                    Button {
                        Haptics.select()
                        selectedFrequency = freq
                    } label: {
                        Text(freq.displayName)
                            .font(selectedFrequency == freq ? .Tokens.bodyMedium : .Tokens.body)
                            .foregroundStyle(
                                selectedFrequency == freq
                                    ? ColorTokens.accent
                                    : ColorTokens.text2
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .background(
                                selectedFrequency == freq
                                    ? ColorTokens.accentSubtle
                                    : ColorTokens.surfaceEl
                            )
                            .overlay(
                                Rectangle().stroke(
                                    selectedFrequency == freq
                                        ? ColorTokens.accent
                                        : ColorTokens.divider,
                                    lineWidth: selectedFrequency == freq ? 1.0 : 0.5
                                )
                            )
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.horizontal, 16)

            Spacer()
        }
    }

    // MARK: - Step 2: Experience Level

    private var experienceStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(
                title: "onboarding.experience.title",
                subtitle: "onboarding.experience.subtitle"
            )

            VStack(spacing: 8) {
                ForEach(ExperienceLevel.allCases) { level in
                    Button {
                        Haptics.select()
                        selectedLevel = level
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(level.displayName)
                                .font(.Tokens.body)
                                .foregroundStyle(
                                    selectedLevel == level
                                        ? ColorTokens.accent
                                        : ColorTokens.text2
                                )
                            Text(level.subtitle)
                                .font(.Tokens.label)
                                .foregroundStyle(ColorTokens.text2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 24)
                        .background(
                            selectedLevel == level
                                ? ColorTokens.accentSubtle
                                : ColorTokens.surfaceEl
                        )
                        .overlay(
                            Rectangle().stroke(
                                selectedLevel == level
                                    ? ColorTokens.accent
                                    : ColorTokens.divider,
                                lineWidth: selectedLevel == level ? 1.0 : 0.5
                            )
                        )
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.horizontal, 16)

            Spacer()
        }
    }

    // MARK: - Step 3: HealthKit Permission

    private var healthKitStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(
                title: "onboarding.healthkit.title",
                subtitle: "onboarding.healthkit.subtitle"
            )

            VStack(spacing: 24) {
                healthKitItem(
                    icon: "heart.text.square",
                    label: "onboarding.healthkit.item.hrv"
                )
                healthKitItem(
                    icon: "heart.fill",
                    label: "onboarding.healthkit.item.rhr"
                )
                healthKitItem(
                    icon: "bed.double.fill",
                    label: "onboarding.healthkit.item.sleep"
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Spacer()

            // Route the primary action on the LIVE HealthKit connection state. A legacy/returning
            // user who already granted access (.requestedNoData / .connected) should not be asked
            // to "Connect" again — show a connected affirmation + Continue. Only .notRequested
            // actually presents the system authorization sheet.
            switch container.healthKitService.connectionState {
            case .notRequested:
                // Connect Health button
                Button {
                    Task {
                        try? await container.healthKitService.requestAuthorization()
                        completeOnboarding()
                    }
                } label: {
                    Text("onboarding.healthkit.connect")
                        .font(.Tokens.bodyMedium)
                        .foregroundStyle(ColorTokens.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(ColorTokens.text1)
                        .overlay(
                            Rectangle().stroke(ColorTokens.accent, lineWidth: 1)
                        )
                }
                .buttonStyle(.pressable)
                .padding(.horizontal, 16)

                // Skip for now
                Button {
                    completeOnboarding()
                } label: {
                    Text("onboarding.skipForNow")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.pressable)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            case .requestedNoData, .connected:
                // Already connected — affirm and continue without re-prompting.
                Text("onboarding.healthkit.connected")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                Button {
                    completeOnboarding()
                } label: {
                    Text("action.continue")
                        .font(.Tokens.bodyMedium)
                        .foregroundStyle(ColorTokens.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(ColorTokens.text1)
                        .overlay(
                            Rectangle().stroke(ColorTokens.accent, lineWidth: 1)
                        )
                }
                .buttonStyle(.pressable)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Shared Components

    private func stepHeader(title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.Tokens.pageTitle)
                .foregroundStyle(ColorTokens.text1)
            Text(subtitle)
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 64)
        .padding(.bottom, 32)
    }

    private func healthKitItem(icon: String, label: LocalizedStringKey) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text2)
                .frame(width: 24)
            Text(label)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dotIndicators: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(index == currentStep ? ColorTokens.text1 : ColorTokens.divider)
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var continueButton: some View {
        Button {
            Haptics.tap()
            withAnimation(Motion.resolved(Motion.screen, reduceMotion: reduceMotion)) {
                currentStep += 1
            }
        } label: {
            Text(continueLabelKey)
                .font(.Tokens.bodyMedium)
                .foregroundStyle(isContinueEnabled ? ColorTokens.background : ColorTokens.text3)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isContinueEnabled ? ColorTokens.text1 : ColorTokens.surface)
                .overlay(
                    Rectangle().stroke(
                        isContinueEnabled ? ColorTokens.accent : ColorTokens.divider,
                        lineWidth: isContinueEnabled ? 1 : 0.5
                    )
                )
        }
        .buttonStyle(.pressable)
        .disabled(!isContinueEnabled)
    }

    /// Step 0 ("Continue to Setup" / "继续设置") uses a longer label per UI-SPEC line 215;
    /// subsequent steps use the single-verb "Continue" / "继续".
    private var continueLabelKey: LocalizedStringKey {
        currentStep == 0 ? "onboarding.continue.toSetup" : "action.continue"
    }

    private var isContinueEnabled: Bool {
        switch currentStep {
        case 0: true   // language always pre-selected via LocaleManager init
        case 1: selectedFrequency != nil
        case 2: selectedLevel != nil
        default: true
        }
    }

    // MARK: - Save and Complete

    private func completeOnboarding() {
        guard let athlete = athletes.first,
              let freq = selectedFrequency,
              let level = selectedLevel else {
            // Cannot proceed without selections — should not be reachable in normal flow
            assertionFailure("completeOnboarding called without required selections")
            return  // Do NOT call onComplete — stay on screen
        }
        athlete.trainingFrequency = freq
        athlete.experienceLevel = level
        athlete.updatedAt = .now
        try? modelContext.save()
        Task { await container.syncService.pushAthlete(athlete) }
        Haptics.success()
        onComplete()
    }
}
