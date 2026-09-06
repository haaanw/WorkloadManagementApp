import SwiftUI

/// OnboardingV2 coordinator (BUILD-PLAN §2/§6 batch 1) — the ≤12-screen flow behind
/// `OnboardingV2Flag`, one file per screen, this file owning only sequencing, the answer
/// store, the step dots, and the back affordance. Screens 6–7 (training frequency,
/// experience level) are NOT here by amendment 8 — they live in Profile. The reveal,
/// account, paywall, exit-offer, import-moment, and tutorial steps arrive in batches 2–6.
struct OnboardingV2Flow: View {
    /// The flow finished (all persisted gate state already written; the flow flips
    /// `isAuthenticated` itself once an account exists — BUILD-PLAN §3: the flow, not
    /// the auth flag, decides when `.main` renders).
    let onComplete: () -> Void
    /// The screen-1 "log in" affordance (C5): an existing customer reinstalling must
    /// reach `LoginView` without answering a quiz.
    let onShowLogin: () -> Void
    /// Relaunch-while-pending resume (BUILD-PLAN §3): an account exists and the wall
    /// was never resolved — the flow opens AT the paywall.
    let resumeAtPaywall: Bool

    init(
        onComplete: @escaping () -> Void,
        onShowLogin: @escaping () -> Void,
        resumeAtPaywall: Bool = false
    ) {
        self.onComplete = onComplete
        self.onShowLogin = onShowLogin
        self.resumeAtPaywall = resumeAtPaywall
        _step = State(initialValue: resumeAtPaywall ? .paywall : .coldOpen)
    }

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
    private static let builtFrontier: Step = .tutorial

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
                if step == .account {
                    AccountScreen(
                        splitChoiceID: answers.splitChoiceID,
                        onCreated: accountCreated
                    )
                }
                if step == .paywall {
                    OnboardingPaywallScreen(
                        variant: OnboardingV2Gate().branch == .real ? .hard : .soft,
                        onPurchased: paywallResolved,
                        onSoftDeclined: softDeclined
                    )
                }
                if step == .importMoment {
                    ImportMomentScreen(onDone: advance)
                }
                if step == .tutorial {
                    TutorialScreen(onDone: advance)
                }
            }
            .animation(Motion.resolved(Motion.screen, reduceMotion: reduceMotion), value: step)

            VStack(spacing: Spacing.md) {
                stepDots

                // Screens that own their CTAs render no shared pill (one ink pill per
                // screen): HK connect, account, paywall, and the import moment.
                if ![.healthConnect, .account, .paywall, .importMoment, .tutorial].contains(step) {
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
        .onAppear {
            guard !resumeAtPaywall else { return }
            container.uxAnalyticsService.track(.onboardingStarted, properties: [
                "locale": Locale.current.identifier
            ])
        }
        .onChange(of: step) { _, newStep in
            container.uxAnalyticsService.track(.onboardingScreenViewed, properties: [
                "index": String(newStep.rawValue + 1),
                "screen_id": String(describing: newStep)
            ])
        }
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
            let branch: OnboardingV2Gate.Branch = outcome.isRealBranch ? .real : .degraded
            OnboardingV2Gate().branch = branch
            // C3: the truthful outcome — data found or not; grant/deny is unobservable.
            container.uxAnalyticsService.track(.hkPromptCompleted, properties: [
                "outcome": outcome.observedPriorHRVDays > 0 ? "data_found" : "no_data"
            ])
            container.uxAnalyticsService.track(.revealRendered, properties: [
                "branch": branch.rawValue,
                "confidence": outcome.confidenceBucket.rawValue
            ])
            isComputingReveal = false
            withAnimation(Motion.resolved(Motion.screen, reduceMotion: reduceMotion)) {
                step = .reveal
            }
        }
    }

    // MARK: - Screens 10–12 resolution (BUILD-PLAN §3)

    /// Account exists → the wall goes pending BEFORE the paywall renders, so a relaunch
    /// mid-wall resumes at screen 11 (the wall is the product boundary).
    private func accountCreated() {
        let gate = OnboardingV2Gate()
        gate.paywallPending = true
        container.uxAnalyticsService.track(.accountCreated)
        container.uxAnalyticsService.track(.paywallShown, properties: [
            "gate": gate.branch == .real ? "hard" : "soft",
            "branch": gate.branch?.rawValue ?? "degraded"
        ])
        withAnimation(Motion.resolved(Motion.screen, reduceMotion: reduceMotion)) {
            step = .paywall
        }
    }

    /// Entitlement arrived (purchase, trial, restore, or the exit offer).
    private func paywallResolved() {
        OnboardingV2Gate().paywallPending = false
        withAnimation(Motion.resolved(Motion.screen, reduceMotion: reduceMotion)) {
            step = .importMoment
        }
    }

    /// Soft branch "not now": free tier, day-7 clock starts, flow continues — the
    /// import moment applies to free athletes too (amendment 6: asked before the
    /// flow ends, skippable).
    private func softDeclined() {
        let gate = OnboardingV2Gate()
        gate.paywallPending = false
        gate.softPaywallShownAt = .now
        withAnimation(Motion.resolved(Motion.screen, reduceMotion: reduceMotion)) {
            step = .importMoment
        }
    }

    // MARK: - Sequencing

    private func advance() {
        trackQuizAnswerIfLeavingQuiz()
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

    /// Quiz answers leave the device only as low-cardinality choice IDs (C7).
    private func trackQuizAnswerIfLeavingQuiz() {
        let payload: (String, String?)? = switch step {
        case .quizProblem: ("q1_problem", answers.problemChoiceID)
        case .quizSplit: ("q2_split", answers.splitChoiceID)
        case .quizFatigue: ("q3_fatigue", answers.fatigueChoiceID)
        default: nil
        }
        guard let payload, let choiceID = payload.1 else { return }
        container.uxAnalyticsService.track(.onboardingQuizAnswered, properties: [
            "question_id": payload.0,
            "choice_id": choiceID
        ])
    }

    private func back() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        withAnimation(Motion.resolved(Motion.screen, reduceMotion: reduceMotion)) {
            step = previous
        }
    }

    private func finish() {
        let gate = OnboardingV2Gate()
        gate.completed = true
        gate.paywallPending = false
        container.uxAnalyticsService.track(.onboardingCompleted, properties: [
            "reached_index": String(step.rawValue + 1),
            "gate": gate.branch == .real ? "hard" : "soft"
        ])
        // An account exists by the time the flow can finish (screens 10+ gate it), so
        // authenticating here is what routes `.main` — the flow decides the moment.
        container.setAuthenticated(true)
        Haptics.success()
        onComplete()
    }
}
