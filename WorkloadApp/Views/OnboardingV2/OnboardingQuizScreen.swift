import SwiftUI

/// OnboardingV2 screens 2/4/5 — the three quiz screens HAN kept (amendment 9: conversion
/// architecture — self-diagnosis, the beachhead split, the commitment device). One
/// generic view, three configs; answers are in-memory choice IDs only (C7), never schema.
struct OnboardingQuizScreen: View {
    struct Config {
        let titleKey: LocalizedStringKey
        let subtitleKey: LocalizedStringKey
        let options: [(id: String, label: String)]
    }

    let config: Config
    @Binding var selectedID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(config.titleKey)
                    .font(.Tokens.pageTitle)
                    .foregroundStyle(ColorTokens.text1)
                    .fixedSize(horizontal: false, vertical: true)
                Text(config.subtitleKey)
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.sm)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.lg)

            VStack(spacing: Spacing.xs) {
                ForEach(config.options, id: \.id) { option in
                    MachinedOptionCell(
                        label: option.label,
                        isSelected: selectedID == option.id
                    ) {
                        selectedID = option.id
                    }
                }
            }
            .padding(.horizontal, Spacing.sm)

            Spacer()
        }
    }
}

// MARK: - The three configs (copy from the gated demo)

extension OnboardingQuizScreen.Config {

    /// Q1 — what breaks your training (screen 2).
    static let problem = OnboardingQuizScreen.Config(
        titleKey: "onboardingV2.quiz.problem.title",
        subtitleKey: "onboardingV2.quiz.problem.subtitle",
        options: [
            ("injuries", String(localized: "onboardingV2.quiz.problem.injuries", defaultValue: "Little injuries that keep coming back")),
            ("stalling", String(localized: "onboardingV2.quiz.problem.stalling", defaultValue: "Progress stalls for weeks")),
            ("tired", String(localized: "onboardingV2.quiz.problem.tired", defaultValue: "Always tired, never sure why")),
            ("guessing", String(localized: "onboardingV2.quiz.problem.guessing", defaultValue: "Guessing how hard to go today"))
        ]
    )

    /// Q2 — the week's split (screen 4). Personalizes the reveal copy in memory.
    static let split = OnboardingQuizScreen.Config(
        titleKey: "onboardingV2.quiz.split.title",
        subtitleKey: "onboardingV2.quiz.split.subtitle",
        options: [
            ("basketballLifting", String(localized: "onboardingV2.quiz.split.basketball", defaultValue: "Basketball, plus serious lifting")),
            ("sportLifting", String(localized: "onboardingV2.quiz.split.sport", defaultValue: "Another sport, plus lifting")),
            ("strength", String(localized: "onboardingV2.quiz.split.strength", defaultValue: "Mostly strength work")),
            ("everything", String(localized: "onboardingV2.quiz.split.everything", defaultValue: "A bit of everything, hard"))
        ]
    )

    /// Q3 — the lived outcome (screen 5). The only screen allowed injury-adjacent copy,
    /// and it references the user's own history, never a threat (no prevention claim).
    static let fatigue = OnboardingQuizScreen.Config(
        titleKey: "onboardingV2.quiz.fatigue.title",
        subtitleKey: "onboardingV2.quiz.fatigue.subtitle",
        options: [
            ("missedWeeks", String(localized: "onboardingV2.quiz.fatigue.missedWeeks", defaultValue: "Missed weeks of training")),
            ("naggingJoint", String(localized: "onboardingV2.quiz.fatigue.naggingJoint", defaultValue: "A joint that still nags")),
            ("flatGame", String(localized: "onboardingV2.quiz.fatigue.flatGame", defaultValue: "A flat game or a bad meet")),
            ("nothingYet", String(localized: "onboardingV2.quiz.fatigue.nothingYet", defaultValue: "Nothing yet"))
        ]
    )
}
