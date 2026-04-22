import SwiftUI
import SwiftData

/// 3-step paged onboarding flow: training frequency, experience level, HealthKit permission.
/// Presented after signup for new users whose `trainingFrequency` or `experienceLevel` is nil.
struct OnboardingView: View {
    let onComplete: () -> Void

    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Query private var athletes: [Athlete]

    @State private var currentStep = 0
    @State private var selectedFrequency: TrainingFrequency?
    @State private var selectedLevel: ExperienceLevel?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentStep) {
                frequencyStep
                    .tag(0)

                experienceStep
                    .tag(1)

                healthKitStep
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .gesture(DragGesture())

            // MARK: Dot indicators + Continue button

            VStack(spacing: 24) {
                dotIndicators

                if currentStep < 2 {
                    continueButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 48)
        }
        .background(ColorTokens.background)
    }

    // MARK: - Step 1: Training Frequency

    private var frequencyStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(
                title: "How often do you train?",
                subtitle: "This helps us calibrate your training load expectations."
            )

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 8
            ) {
                ForEach(TrainingFrequency.allCases) { freq in
                    Button {
                        selectedFrequency = freq
                    } label: {
                        Text(freq.displayName)
                            .font(.Tokens.body)
                            .foregroundStyle(
                                selectedFrequency == freq
                                    ? ColorTokens.text1
                                    : ColorTokens.text2
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .background(
                                selectedFrequency == freq
                                    ? ColorTokens.surface
                                    : ColorTokens.background
                            )
                            .overlay(
                                Rectangle().stroke(
                                    selectedFrequency == freq
                                        ? ColorTokens.text3
                                        : ColorTokens.divider,
                                    lineWidth: selectedFrequency == freq ? 1.0 : 0.5
                                )
                            )
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
                title: "What's your training experience?",
                subtitle: "We'll adjust insights based on your background."
            )

            VStack(spacing: 8) {
                ForEach(ExperienceLevel.allCases) { level in
                    Button {
                        selectedLevel = level
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(level.displayName)
                                .font(.Tokens.body)
                                .foregroundStyle(
                                    selectedLevel == level
                                        ? ColorTokens.text1
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
                                ? ColorTokens.surface
                                : ColorTokens.background
                        )
                        .overlay(
                            Rectangle().stroke(
                                selectedLevel == level
                                    ? ColorTokens.text3
                                    : ColorTokens.divider,
                                lineWidth: selectedLevel == level ? 1.0 : 0.5
                            )
                        )
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
                title: "Connect Health Data",
                subtitle: "Tonus uses your HRV, resting heart rate, and sleep data to calculate your daily recovery score."
            )

            VStack(spacing: 24) {
                healthKitItem(
                    icon: "heart.text.square",
                    label: "Heart Rate Variability"
                )
                healthKitItem(
                    icon: "heart.fill",
                    label: "Resting Heart Rate"
                )
                healthKitItem(
                    icon: "bed.double.fill",
                    label: "Sleep Analysis"
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Spacer()

            // Connect Health button
            Button {
                Task {
                    try? await container.healthKitService.requestAuthorization()
                    completeOnboarding()
                }
            } label: {
                Text("Connect Health")
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(ColorTokens.surface)
                    .overlay(
                        Rectangle().stroke(ColorTokens.text3, lineWidth: 1.0)
                    )
            }
            .padding(.horizontal, 16)

            // Skip for now
            Button {
                completeOnboarding()
            } label: {
                Text("Skip for now")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Shared Components

    private func stepHeader(title: String, subtitle: String) -> some View {
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

    private func healthKitItem(icon: String, label: String) -> some View {
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
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index == currentStep ? ColorTokens.text1 : ColorTokens.divider)
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var continueButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.25)) {
                currentStep += 1
            }
        } label: {
            Text("Continue")
                .font(.Tokens.body)
                .foregroundStyle(isContinueEnabled ? ColorTokens.text1 : ColorTokens.text3)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(ColorTokens.surface)
                .overlay(
                    Rectangle().stroke(
                        isContinueEnabled ? ColorTokens.text3 : ColorTokens.divider,
                        lineWidth: isContinueEnabled ? 1.0 : 0.5
                    )
                )
        }
        .disabled(!isContinueEnabled)
    }

    private var isContinueEnabled: Bool {
        switch currentStep {
        case 0: selectedFrequency != nil
        case 1: selectedLevel != nil
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
        onComplete()
    }
}
