import SwiftUI

/// OnboardingV2 coordinator (BUILD-PLAN §2/§6 batch 1) — the ≤12-screen flow behind
/// `OnboardingV2Flag`, one file per screen, this file owning only sequencing, the answer
/// store, the step dots, and the back affordance. Screens 6–7 (training frequency,
/// experience level) are NOT here by amendment 8 — they live in Profile. The reveal,
/// account, paywall, exit-offer, import-moment, and tutorial steps arrive in batches 2–6.
struct OnboardingV2Flow: View {
    /// The flow finished (all persisted gate state already written). The router decides
    /// what renders next; the flow never touches `isAuthenticated` directly.
    let onComplete: () -> Void
    /// The screen-1 "log in" affordance (C5): an existing customer reinstalling must
    /// reach `LoginView` without answering a quiz.
    let onShowLogin: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    @State private var answers = OnboardingAnswers()
    @State private var step: Step = .coldOpen
    /// The screen-9 result, computed in memory when screen 8 resolves (C1 — nothing
    /// persists before account creation).
    @State private var reveal: OnboardingRevealService.Reveal?
    @State private var isComputingReveal = false

    /// The full main path, declared now so the dot count is honest to the final design
    /// while batches land. `exitOffer` is deliberately absent — it is a dismiss-intent
    /// overlay on the paywall, not a step on the path.
    enum Step: Int, CaseIterable {
        case coldOpen, quizProblem, gap, quizSplit, quizFatigue
        case healthConnect, reveal, account, paywall
        case importMoment, tutorial
    }

    /// Steps with a built screen this batch. Advancing past the last built step finishes
    /// the flow; each batch extends this frontier.
    private static let builtFrontier: Step = .reveal

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ZStack {
                ColdOpenScreen(onShowLogin: onShowLogin)
                    .opacity(step == .coldOpen ? 1 : 0)
                if step == .quizProblem {
                    OnboardingQuizScreen(config: .problem, selectedID: $answers.problemChoiceID)
                }
                if step == .gap {
                    GapScreen()
                }
                if step == .quizSplit {
                    OnboardingQuizScreen(config: .split, selectedID: $answers.splitChoiceID)
                }
                if step == .quizFatigue {
                    OnboardingQuizScreen(config: .fatigue, selectedID: $answers.fatigueChoiceID)
                }
                if step == .healthConnect {
                    HealthConnectScreen(onResolved: resolveHealthAndReveal)
                }
                if step == .reveal {
                    RevealScreen(
                        reveal: reveal ?? .degraded,
                        splitChoiceID: answers.splitChoiceID
                    )
                }
            }
            .animation(Motion.resolved(Motion.screen, reduceMotion: reduceMotion), value: step)

            VStack(spacing: Spacing.md) {
                stepDots

                // Screen 8 owns its own CTA pair (connect / skip); everywhere else the
                // coordinator's single ink pill advances (one ink pill per screen).
                if step != .healthConnect {
                    PrimaryActionButton(
                        title: continueTitle,
                        isLoading: isComputingReveal,
                        isDisabled: !canAdvance
                    ) {
                        advance()
                    }
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.bottom, Spacing.xl)
        }
        .background(ColorTokens.background)
        .accessibilityIdentifier("onboardingV2.flow")
    }

    // MARK: - Chrome

    /// Back is allowed across the pre-auth stretch (screens 1–8 per the state machine).
    /// The reveal does not offer back — re-running the HealthKit step buys nothing and a
    /// second system sheet can never appear anyway (re-ask guard).
    private var backAllowed: Bool {
        step != .coldOpen && step.rawValue <= Step.healthConnect.rawValue
    }

    private var topBar: some View {
        HStack {
            if backAllowed {
                Button {
                    back()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text2)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(Text("action.back"))
                .accessibilityIdentifier("onboardingV2.back")
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.xs)
        .frame(height: 44)
    }

    /// The flow's one live-state mark (v6 Reading Color Rule) — the active dot takes
    /// travertine, exactly as the shipped `OnboardingView` dots do.
    private var stepDots: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(Step.allCases, id: \.rawValue) { s in
                Circle()
                    .fill(s == step ? ColorTokens.accent : ColorTokens.divider)
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var continueTitle: LocalizedStringKey {
        step == .coldOpen ? "onboardingV2.coldOpen.cta" : "action.continue"
    }

    private var canAdvance: Bool {
        switch step {
        case .coldOpen, .gap:
            return true
        case .quizProblem:
            return answers.problemChoiceID != nil
        case .quizSplit:
            return answers.splitChoiceID != nil
        case .quizFatigue:
            return answers.fatigueChoiceID != nil
        case .reveal:
            return !isComputingReveal
        default:
            return true
        }
    }

    // MARK: - Screen 8 resolution (C1/C2/C3)

    /// Both screen-8 doors land here: compute the reveal in memory, stamp the branch,
    /// advance. The branch is persisted at reveal ENTRY (BUILD-PLAN §3) so the paywall
    /// variant survives relaunch once batch 3's account step exists.
    private func resolveHealthAndReveal() {
        guard !isComputingReveal else { return }
        isComputingReveal = true
        Task {
            let outcome = await OnboardingRevealService.compute(
                healthKitService: container.healthKitService
            )
            reveal = outcome
            OnboardingV2Gate().branch = outcome.isRealBranch ? .real : .degraded
            isComputingReveal = false
            withAnimation(Motion.resolved(Motion.screen, reduceMotion: reduceMotion)) {
                step = .reveal
            }
        }
    }

    // MARK: - Sequencing

    private func advance() {
        if step == Self.builtFrontier {
            finish()
            return
        }
        guard let next = Step(rawValue: step.rawValue + 1) else {
            finish()
            return
        }
        withAnimation(Motion.resolved(Motion.screen, reduceMotion: reduceMotion)) {
            step = next
        }
    }

    private func back() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        withAnimation(Motion.resolved(Motion.screen, reduceMotion: reduceMotion)) {
            step = previous
        }
    }

    private func finish() {
        OnboardingV2Gate().completed = true
        Haptics.success()
        onComplete()
    }
}
