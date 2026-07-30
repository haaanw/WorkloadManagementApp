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

            // Machined option channel (v4.2): raised cells with drilled dots in a debossed bay.
            VStack(spacing: Spacing.baselinePair) {
                ForEach(container.localeManager.supportedLocales, id: \.identifier) { locale in
                    languageRow(for: locale)
                }
            }
            .padding(Spacing.xs)
            .debossed(cornerRadius: CornerTokens.control)
            .padding(.horizontal, 16)
            .padding(.top, 32)

            Spacer()
        }
    }

    @ViewBuilder
    private func languageRow(for locale: Locale) -> some View {
        MachinedOptionCell(
            label: languageAutonym(for: locale),
            isSelected: container.localeManager.activeLocale.identifier == locale.identifier
        ) {
            container.localeManager.setLocale(locale)
        }
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
                    // Machined option cell (v4.2): raised plate + drilled selection dot.
                    MachinedOptionCell(
                        label: freq.displayName,
                        isSelected: selectedFrequency == freq
                    ) {
                        selectedFrequency = freq
                    }
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
                    // Machined option cell (v4.2): raised plate + drilled selection dot.
                    MachinedOptionCell(
                        label: level.displayName,
                        subtitle: level.subtitle,
                        isSelected: selectedLevel == level
                    ) {
                        selectedLevel = level
                    }
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
                // Connect Health — shared ink-filled pill primary CTA (v5 CTA Law; never accent).
                PrimaryActionButton(title: "onboarding.healthkit.connect") {
                    Task {
                        try? await container.healthKitService.requestAuthorization()
                        completeOnboarding()
                    }
                }
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

                PrimaryActionButton(title: "action.continue") {
                    completeOnboarding()
                }
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
            // v6 Reading Color Rule: the active step dot is an active/selected mark, which is
            // travertine's exclusive territory. Marks are unrestricted by the contrast rule
            // (3:1 graphical floor), and this is Onboarding's one live-state mark — the rest of
            // the flow is prose and CTAs, which take no annotation and no colour.
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(index == currentStep ? ColorTokens.accent : ColorTokens.divider)
                    .frame(width: 8, height: 8)
            }
        }
    }

    /// Shared ink-filled pill primary CTA (v5 CTA Law). Disabled state is
    /// the shared 50%-opacity treatment from `PrimaryActionButton`.
    private var continueButton: some View {
        PrimaryActionButton(title: continueLabelKey, isDisabled: !isContinueEnabled) {
            withAnimation(Motion.resolved(Motion.screen, reduceMotion: reduceMotion)) {
                currentStep += 1
            }
        }
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
