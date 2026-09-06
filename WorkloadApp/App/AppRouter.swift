import SwiftUI
import SwiftData
import Supabase
import GoogleSignIn
import UIKit

struct AppRouter: View {
    @State private var container = AppContainer()
    @State private var isCheckingSession = true
    @State private var needsOnboarding = false
    /// True while the deferred launch pull (v1.7.3 B3) is running behind first paint.
    /// Drives the quiet sync indicator over the main shell — nothing else.
    @State private var isDeferredSyncRunning = false
    /// Set when the deferred zombie check finds the athlete store emptied under a live
    /// session. Surfaces an alert; never signs out, never wipes (LaunchRoutingEngine).
    @State private var showDeferredSessionFault = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// True while the OnboardingV2 flow owns the screen (flag-gated; BUILD-PLAN §5).
    /// Set only from the launch decision — the flow itself clears it via its completion
    /// closures, and while the flag is OFF this can never become true.
    @State private var showOnboardingV2 = false
    /// Relaunch-while-paywall-pending (BUILD-PLAN §3): the flow reopens AT screen 11.
    @State private var onboardingV2ResumesAtPaywall = false
    /// Day-7 soft-paywall re-ask (spec §4) — presented once over the main shell.
    @State private var showSoftReask = false

    /// The root routing state — a single Equatable value so the loading → login →
    /// onboarding → tabs hand-offs cross-fade (`Motion.screen`) instead of snapping.
    private enum Route: Equatable {
        case loading, login, onboarding, onboardingV2, main
    }

    private var route: Route {
        if isCheckingSession { return .loading }
        if showOnboardingV2 { return .onboardingV2 }
        if !container.isAuthenticated { return .login }
        if needsOnboarding { return .onboarding }
        return .main
    }

    var body: some View {
        Group {
            switch route {
            case .loading:
                LaunchLoadingView()
                    .transition(.opacity)
            case .login:
                LoginView()
                    .transition(.opacity)
            case .onboarding:
                OnboardingView(onComplete: { needsOnboarding = false })
                    .transition(.opacity)
            case .onboardingV2:
                OnboardingV2Flow(
                    onComplete: { showOnboardingV2 = false },
                    onShowLogin: { showOnboardingV2 = false },
                    resumeAtPaywall: onboardingV2ResumesAtPaywall
                )
                .transition(.opacity)
            case .main:
                MainTabView()
                    .transition(.opacity)
                    .overlay(alignment: .top) {
                        if isDeferredSyncRunning {
                            DeferredSyncIndicator()
                                .padding(.top, Spacing.xs)
                                .transition(.opacity)
                        }
                    }
                    .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: isDeferredSyncRunning)
                    // Day-7 soft re-ask (spec §4): once, over the shell, dismissible.
                    .sheet(isPresented: $showSoftReask) {
                        OnboardingPaywallScreen(
                            variant: .soft,
                            onPurchased: { showSoftReask = false },
                            onSoftDeclined: { showSoftReask = false }
                        )
                    }
            }
        }
        // Deferred zombie surface (v1.7.3 B3): the background pull found no local athlete
        // under a live session. The athlete is already inside the app, so nothing is wiped
        // and nobody is signed out — the fault is stated, and sign-out stays behind the
        // user-confirmed Profile path with its push-risk wipe guard. Verbatim strings:
        // Localizable.xcstrings carries another session's WIP (flagged for follow-up).
        .alert(Text(verbatim: "Account data unavailable"), isPresented: $showDeferredSessionFault) {
            Button {
                showDeferredSessionFault = false
            } label: {
                Text(verbatim: "OK")
            }
        } message: {
            Text(verbatim: "Your training data could not be matched to your account. Nothing on this device was changed. To switch accounts, sign out from Profile.")
        }
        .animation(Motion.resolved(Motion.screen, reduceMotion: reduceMotion), value: route)
        .environment(container)
        .environment(\.locale, container.localeManager.activeLocale)
        .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: container.localeManager.activeLocale)
        .onOpenURL { url in
            // Google Sign-In callback
            if GIDSignIn.sharedInstance.handle(url) { return }

            // Supabase OAuth callback fallback
            Task {
                try? await container.supabase.auth.session(from: url)
            }
        }
        .onChange(of: container.isAuthenticated) { _, isAuth in
            guard isAuth else { return }
            // Link RevenueCat identity on fresh sign-in/sign-up — and on the fast-path
            // launch (v1.7.3 B3), which relies on this block for RevenueCat + the HealthKit
            // probe so neither blocks first paint. `logIn` is a background round-trip;
            // entitlements meanwhile come from RevenueCat's cached CustomerInfo.
            Task {
                if let userId = await container.authService.currentUserId() {
                    await container.subscriptionService.logIn(userId: userId)
                }
            }
            // Non-blocking HealthKit liveness probe on fresh sign-in/sign-up.
            Task.detached(priority: .utility) {
                await container.healthKitService.runMigrationProbe()
            }
            // Re-evaluate onboarding after fresh signup (D-06). Sentinel re-keyed per
            // amendment 8: V2 removes the frequency/experience screens, so completion is
            // an explicit marker; with the marker false this reduces to the legacy check.
            let athletes = (try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []
            if let a = athletes.first {
                needsOnboarding = OnboardingV2Routing.needsLegacyOnboarding(
                    trainingFrequencySet: a.trainingFrequency != nil,
                    experienceLevelSet: a.experienceLevel != nil,
                    v2Completed: OnboardingV2Gate().completed
                )
            }
        }
        .task {
            #if DEBUG && targetEnvironment(simulator)
            let args = ProcessInfo.processInfo.arguments

            if args.contains("SCREENSHOT_LOADING_MODE") {
                applyScreenshotLocaleOverride(arguments: args)
                container.setMode(.athlete)
                container.setAuthenticated(false)
                needsOnboarding = false
                return
            }

            if args.contains("SCREENSHOT_AUTH_MODE") {
                applyScreenshotLocaleOverride(arguments: args)
                container.setMode(.athlete)
                container.setAuthenticated(false)
                needsOnboarding = false
                isCheckingSession = false
                return
            }

            if args.contains("SCREENSHOT_ONBOARDING_MODE") {
                applyScreenshotLocaleOverride(arguments: args)
                container.setMode(.athlete)
                let athlete = resetScreenshotData(isCoachScreenshot: false)
                athlete.trainingFrequency = nil
                athlete.experienceLevel = nil
                try? modelContext.save()
                container.setAuthenticated(true)
                needsOnboarding = true
                isCheckingSession = false
                return
            }

            // Screenshot mode: bypass auth, seed mock data, show app immediately
            if ProcessInfo.processInfo.arguments.contains("SCREENSHOT_MODE") {
                // SCREENSHOT_MODE locale override: belt-and-braces with Bundle resolution.
                // Honors `-AppleLanguages (zh-Hans)` launch arg for zh-Hans screenshot runs.
                applyScreenshotLocaleOverride(arguments: args)
                let isCoachScreenshot = args.contains("SCREENSHOT_COACH_MODE")
                let isCoachPaywallScreenshot = args.contains("SCREENSHOT_COACH_PAYWALL_MODE")
                let isCoachAccountScreenshot = isCoachScreenshot || isCoachPaywallScreenshot

                let athlete = resetScreenshotData(
                    isCoachScreenshot: isCoachAccountScreenshot
                )
                try? modelContext.save()
                MockDataSeeder.seed(modelContext: modelContext, athlete: athlete)
                prepareCoachScreenshotRosterIfNeeded(coach: athlete)
                container.setMode(isCoachScreenshot ? .coach : .athlete)
                container.setAuthenticated(true)
                needsOnboarding = false
                container.subscriptionService.overrideForScreenshots(
                    isPro: !isCoachPaywallScreenshot,
                    isCoach: isCoachScreenshot
                )
                isCheckingSession = false
                return
            }
            #endif

            // v1.7.3 B3 — optimistic local-first launch. The decision lives in
            // LaunchRoutingEngine; this task only executes it. The session check is the
            // LOCAL one on purpose: Supabase's `auth.session` refreshes an expired token
            // over the network, and an expired-every-morning token was half of the ~10 s
            // "Preparing Tuwa" stall.
            let localAthletes = (try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []
            switch LaunchRoutingEngine.decide(
                hasLocalSession: container.authService.hasLocalSession,
                hasLocalAthlete: !localAthletes.isEmpty
            ) {
            case .showLogin:
                // Fresh install (no session, no athlete): the flag routes it to the V2
                // flow's pre-auth stretch (C5 — a returning user with a session can never
                // reach this branch, and the screen-1 "log in" link exits to LoginView).
                showOnboardingV2 = OnboardingV2Routing.presentsFreshFlow(
                    flagEnabled: OnboardingV2Flag.isEnabled(),
                    hasLocalSession: false,
                    hasLocalAthlete: !localAthletes.isEmpty,
                    completed: OnboardingV2Gate().completed
                )
                isCheckingSession = false

            case .routeImmediately:
                // Relaunch while the hard wall was pending and no entitlement arrived:
                // resume AT the paywall (BUILD-PLAN §3 — the wall is the product
                // boundary, not a UI accident). Entitlements read RevenueCat's cached
                // CustomerInfo; Restore on the wall resolves a stale false.
                if OnboardingV2Routing.resumesAtPaywall(
                    flagEnabled: OnboardingV2Flag.isEnabled(),
                    paywallPending: OnboardingV2Gate().paywallPending,
                    isPro: container.subscriptionService.isPro,
                    completed: OnboardingV2Gate().completed
                ) {
                    onboardingV2ResumesAtPaywall = true
                    showOnboardingV2 = true
                }
                // Returning user: paint the app NOW. needsOnboarding is set before
                // isAuthenticated so the route lands once, without a .main → .onboarding
                // flash. RevenueCat logIn and the HealthKit probe ride the isAuthenticated
                // onChange above (already non-blocking); only the pull needs a home here.
                if let a = localAthletes.first {
                    needsOnboarding = OnboardingV2Routing.needsLegacyOnboarding(
                        trainingFrequencySet: a.trainingFrequency != nil,
                        experienceLevelSet: a.experienceLevel != nil,
                        v2Completed: OnboardingV2Gate().completed
                    )
                }
                container.setAuthenticated(true)
                isCheckingSession = false
                await runDeferredLaunchSync()

            case .blockingBootstrap:
                // Fresh install (or reinstall) with a session: there is no local Athlete to
                // paint, so blocking is the only honest launch. This chain encodes the
                // zombie and H7 incidents — do not weaken it.
                if let userId = await container.authService.currentUserId() {
                    switch await container.syncService.bootstrapAthlete(
                        context: modelContext,
                        userId: userId
                    ) {
                    case .created:
                        break
                    case .notFound:
                        // A genuine zombie: the session is valid but the account owns no
                        // athlete row. Signing out is the only way forward.
                        try? await container.authService.signOut()
                        isCheckingSession = false
                        return
                    case .failed:
                        // The server was unreachable — we know NOTHING about whether a
                        // profile exists (v1.7.2 / audit H7). Keep the Keychain session so
                        // the next launch retries; land on the login screen rather than
                        // destroying a valid session because the plane had no wifi.
                        isCheckingSession = false
                        return
                    }
                }
                // First pull, still pre-paint: a bootstrapped athlete has no history yet.
                if container.syncService.shouldForegroundSync {
                    await container.syncService.pullAll(context: modelContext)
                    // Sign-up resilience: if still no athlete after pull, sign out (zombie account)
                    let athletesAfterSync = try? modelContext.fetch(FetchDescriptor<Athlete>())
                    if athletesAfterSync?.isEmpty == true {
                        try? await container.authService.signOut()
                        isCheckingSession = false
                        return
                    }
                }
                // Link RevenueCat identity to Supabase user
                if let userId = await container.authService.currentUserId() {
                    await container.subscriptionService.logIn(userId: userId)
                }

                container.setAuthenticated(true)

                // Non-blocking HealthKit migration / liveness probe. Runs AFTER auth UI is up,
                // detached so it never blocks launch or dashboard routing. Migrates legacy v1.3
                // users who granted Health access before the persisted flag existed.
                Task.detached(priority: .utility) {
                    await container.healthKitService.runMigrationProbe()
                }

                // Check if onboarding is needed (D-06; amendment-8 re-key)
                let onboardingAthletes = try? modelContext.fetch(FetchDescriptor<Athlete>())
                if let a = onboardingAthletes?.first {
                    needsOnboarding = OnboardingV2Routing.needsLegacyOnboarding(
                        trainingFrequencySet: a.trainingFrequency != nil,
                        experienceLevelSet: a.experienceLevel != nil,
                        v2Completed: OnboardingV2Gate().completed
                    )
                }

                isCheckingSession = false
            }
        }
    }

    // MARK: - Deferred launch sync (v1.7.3 B3)

    /// The background half of the fast path: pull when the sync clock says stale, then run
    /// the deferred zombie check. Runs AFTER first paint — it must never block routing and
    /// it must never sign the athlete out. Identity faults inside the pull are already
    /// surfaced by SyncService's identity guard (SyncStatusView banner); the one outcome
    /// handled here is the athlete store emptying under a live session, which is SURFACED
    /// via alert and acted on only by the user through the guarded Profile sign-out.
    private func runDeferredLaunchSync() async {
        guard container.syncService.shouldForegroundSync else { return }
        isDeferredSyncRunning = true
        await container.syncService.pullAll(context: modelContext)
        isDeferredSyncRunning = false

        let athletesAfterPull = (try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []
        let action = LaunchRoutingEngine.deferredZombieAction(
            athleteCountAfterPull: athletesAfterPull.count
        )
        if action == .surfaceFault {
            showDeferredSessionFault = true
        }

        await presentSoftReaskIfDue()
    }

    /// Day-7 soft-paywall re-ask (spec §4): the clock half is a pure decision; the data
    /// half — "the app now has ≥ floor observed HRV mornings" — reuses the reveal math.
    /// Runs behind first paint on the deferred launch path; fires at most once ever
    /// (`reaskDone` stamps when presented, not when answered).
    private func presentSoftReaskIfDue() async {
        let gate = OnboardingV2Gate()
        guard OnboardingV2Routing.softReaskIsDue(
            now: .now,
            flagEnabled: OnboardingV2Flag.isEnabled(),
            softShownAt: gate.softPaywallShownAt,
            reaskDone: gate.reaskDone,
            isPro: container.subscriptionService.isPro
        ) else { return }

        let reveal = await OnboardingRevealService.compute(
            healthKitService: container.healthKitService
        )
        guard reveal.observedPriorHRVDays >= BaselineEngine.BaselineConstants.confFloorDays else {
            return
        }
        gate.reaskDone = true
        showSoftReask = true
    }

    #if DEBUG && targetEnvironment(simulator)
    private func applyScreenshotLocaleOverride(arguments: [String]) {
        if let idx = arguments.firstIndex(of: "-AppleLanguages"),
           idx + 1 < arguments.count,
           arguments[idx + 1].contains("zh-Hans") {
            container.localeManager.setLocale(Locale(identifier: "zh-Hans"))
            return
        }
        container.localeManager.setLocale(Locale(identifier: "en"))
    }

    private func resetScreenshotData(isCoachScreenshot: Bool) -> Athlete {
        deleteAllScreenshotRows()
        let athlete = Athlete(
            displayName: isCoachScreenshot ? "Coach Alex" : "Alex",
            sportType: .lifting
        )
        configureScreenshotAthlete(athlete, isCoachScreenshot: isCoachScreenshot)
        modelContext.insert(athlete)
        return athlete
    }

    private func deleteAllScreenshotRows() {
        try? deleteAll(Athlete.self)
        try? deleteAll(CoachAthleteRelationship.self)
        try? deleteAll(WorkoutTemplate.self)
        try? deleteAll(PrescribedWorkout.self)
        try? deleteAll(TrainingProfile.self)
        try? deleteAll(VerdictEvent.self)
        try? modelContext.save()
    }

    private func deleteAll<T: PersistentModel>(_ modelType: T.Type) throws {
        let rows = try modelContext.fetch(FetchDescriptor<T>())
        for row in rows {
            modelContext.delete(row)
        }
    }

    private func configureScreenshotAthlete(_ athlete: Athlete, isCoachScreenshot: Bool) {
        athlete.isCoach = isCoachScreenshot
        athlete.isCoachOnly = false
        athlete.displayName = isCoachScreenshot ? "Coach Alex" : "Alex"
        athlete.trainingFrequency = athlete.trainingFrequency ?? .threeToFour
        athlete.experienceLevel = athlete.experienceLevel ?? .intermediate
    }

    private func prepareCoachScreenshotRosterIfNeeded(coach: Athlete) {
        guard coach.isCoach else { return }

        let athletes = (try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []
        let client = athletes.first { $0.displayName == "Jordan Lee" && $0.id != coach.id } ?? {
            let client = Athlete(displayName: "Jordan Lee", sportType: .running)
            client.trainingFrequency = .fiveToSix
            client.experienceLevel = .advanced
            modelContext.insert(client)
            return client
        }()

        let relationships = (try? modelContext.fetch(FetchDescriptor<CoachAthleteRelationship>())) ?? []
        if relationships.contains(where: { $0.coachId == coach.id && $0.athleteId == client.id }) == false {
            modelContext.insert(CoachAthleteRelationship(
                coachId: coach.id,
                athleteId: client.id,
                status: .accepted
            ))
        }
        try? modelContext.save()
    }
    #endif
}

// MARK: - Main tab shell (SwiftUI rehost, Stage R)

/// The four athlete tabs (v1.7.3 reorientation slice 3, APP-REORIENTATION §4.2 Option A:
/// the read-only Recovery and Load exhibits merged into Trends).
enum AppTab: Hashable, CaseIterable {
    case home, log, trends, profile
}

/// The R9 router seam: `selectedTab` used to be private to `MainTabView`, so no
/// cross-feature entry could hand off between tabs — every such entry opened a sheet in
/// place. Any view under the shell can now read this from the environment and set
/// `selection` to switch tabs programmatically. It is a seam, not a policy: it carries
/// no navigation stack state and no deep-link grammar — those stay with each tab.
@MainActor
@Observable
final class TabRouter {
    var selection: AppTab = .home
}

/// The live app shell: four athlete tabs over the SwiftUI tree.
/// Coach mode is intentionally NOT represented here — the self-coached reset is product
/// intent; the UIKit AppShell carrying coach tabs was the deviation (orchestration D3/R6).
/// Mirrors the UIKit shell's scenePhase-active foreground sync (entitlement refresh +
/// push/pull when stale) so rehosting loses no sync behavior.
struct MainTabView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    /// Selection lives on the router (R9) so cross-tab handoffs are possible; holding the
    /// router in `@State` here keeps the existing behavior — tab REVISITS cross-fade
    /// content in via `tabCrossfade` (`Motion.tabSwitch` — near-instant; tab switches are
    /// frequent actions) instead of snapping; first renders stay with each screen's
    /// `entranceReveal` choreography.
    @State private var router = TabRouter()

    private var selectedTab: AppTab { router.selection }

    /// Stage 4a: the stock tab bar stays in the LAYOUT (its UIKit safe-area contribution is
    /// what keeps tab roots and pushed screens clear of the custom bar) but must draw
    /// NOTHING — a transparent appearance removes the liquid-glass pill, its shadow halo,
    /// and the scroll-edge effect that would otherwise peek above the opaque InkTabBar.
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    /// Stage 4a — items for the custom Ink & Grain bar (text-forward, no glyphs in the
    /// primary direction). Accessibility IDs are the Stage-4b test contract.
    private var tabItems: [InkTabBar<AppTab>.Item] {
        [
            // Slice 2 (R8): the first tab is "Today" — it carries the daily loop. The
            // accessibility ID stays `tab.home` (the UI-test contract is ID-stable).
            .init(tab: .home, title: "tab.today", accessibilityID: "tab.home"),
            .init(tab: .log, title: "tab.log", accessibilityID: "tab.log"),
            .init(tab: .trends, title: "tab.trends", accessibilityID: "tab.trends"),
            .init(tab: .profile, title: "tab.profile", accessibilityID: "tab.profile")
        ]
    }

    var body: some View {
        TabView(selection: Bindable(router).selection) {
            DashboardView()
                .inkTabChild(isSelected: selectedTab == .home)
                .tag(AppTab.home)

            WorkoutLogView()
                .inkTabChild(isSelected: selectedTab == .log)
                .tag(AppTab.log)

            TrendsView()
                .inkTabChild(isSelected: selectedTab == .trends)
                .tag(AppTab.trends)

            ProfileView()
                .inkTabChild(isSelected: selectedTab == .profile)
                .tag(AppTab.profile)
        }
        // R9: the router rides the environment so any tab child can hand off to another
        // tab (e.g. a future "see the trend" row switching to Trends) without a sheet.
        .environment(router)
        // Stage 4a (D6): the stock tab bar is hidden per tab (inkTabChild); the app renders
        // its own Ink & Grain bar as a bottom safe-area inset. The TabView hosts its tabs in
        // UIKit, so the inset does NOT reach their safe areas — each child carries a matching
        // `.safeAreaPadding(.bottom, InkTabBarMetrics.height)` (also in inkTabChild) so scroll
        // content clears the bar (fixes the stock-chrome bottom clipping). Selection state and
        // `tabCrossfade` behavior are unchanged.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            InkTabBar(items: tabItems, selection: Bindable(router).selection)
        }
        // Native parity: the bar stays pinned at the screen bottom and the keyboard covers
        // it (without this the safe-area inset rides on top of the keyboard). Tab content
        // keeps its own keyboard avoidance.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        // Status-bar cap: with the stock nav bars hidden on the tab roots (editorial
        // in-content headers, Stage 4a) scrolled content would collide with the clock. A
        // flat opaque page-plane cap — never a blur/material — keeps the status region
        // legible; it is invisible at scroll-top because it matches the page color.
        .overlay(alignment: .top) {
            ColorTokens.background
                .frame(height: 0)
                .background(ColorTokens.background.ignoresSafeArea(edges: [.top, .horizontal]))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        // Content tint stays text1, never accent (DESIGN.md — accent is a live-state semantic).
        .tint(ColorTokens.text1)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await container.subscriptionService.refreshEntitlementAsync()
                guard container.syncService.shouldForegroundSync else { return }
                await container.syncService.pushAll(context: modelContext)
                await container.syncService.pullAll(context: modelContext)
            }
        }
    }
}

private extension View {
    /// Stage 4a tab-child chrome: keeps the Stage-2 `tabCrossfade`. The stock tab bar is NOT
    /// hidden — it stays in the layout so its UIKit safe-area contribution keeps every tab
    /// root AND every pushed detail screen clear of the bottom bar (SwiftUI-side
    /// safeAreaPadding cannot reach the UINavigationController-hosted content). The stock
    /// bar itself is fully covered by the opaque InkTabBar overlay and never receives taps
    /// (the InkTabBar's five full-width buttons absorb the entire bar plane).
    func inkTabChild(isSelected: Bool) -> some View {
        self
            .tabCrossfade(isSelected: isSelected)
            // Hide the stock bar's VISUALS (liquid-glass pill + top glow) while keeping the
            // bar in the layout for its safe-area contribution. Belt-and-braces with the
            // UITabBarAppearance transparent config in MainTabView.init.
            .toolbarBackground(.hidden, for: .tabBar)
    }
}

// MARK: - Deferred sync indicator (v1.7.3 B3)

/// The quiet indicator over the main shell while the deferred launch pull runs: an
/// annotation-voice capsule with a live dot. Accent is the live-state semantic and a running
/// sync is live state; the 8pt dot matches the SyncStatusView status dots. No spinner —
/// the athlete is already using the app, the sync is a footnote. Verbatim string because
/// `Localizable.xcstrings` carries another session's WIP (flagged for follow-up) and the
/// annotation voice is uppercase Latin by law.
private struct DeferredSyncIndicator: View {
    var body: some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(ColorTokens.accent)
                .frame(width: 8, height: 8)
            AnnotationLabel("SYNCING", size: .small, color: ColorTokens.text2)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(Capsule().fill(ColorTokens.surfaceEl))
        .overlay(Capsule().stroke(ColorTokens.hairline, lineWidth: 1))
        .accessibilityIdentifier("app.deferredSync")
    }
}

// MARK: - Launch loading state

/// SwiftUI twin of the shell-era loading screen. Keeps the `app.loading` accessibility
/// identifiers the screenshot/UI harness waits on, and uses verbatim text (matching the
/// old controller's literal strings) so the string catalog is untouched.
private struct LaunchLoadingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Spacer()

            Text(verbatim: "Preparing Tuwa")
                .font(.Tokens.pageTitle)
                .foregroundStyle(ColorTokens.text1)

            Text(verbatim: "Checking your account, local data, and training context.")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text2)

            HStack(spacing: Spacing.xs) {
                ProgressView()
                    .tint(ColorTokens.text2)
                Text(verbatim: "Checking session")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                    .accessibilityIdentifier("app.loading")
            }
            .padding(.top, Spacing.sm)

            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.background)
        .accessibilityIdentifier("app.loading.view")
    }
}
