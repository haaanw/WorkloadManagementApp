import SwiftUI
import SwiftData
import Supabase
import GoogleSignIn

struct AppRouter: View {
    @State private var container = AppContainer()
    @State private var isCheckingSession = true
    @State private var needsOnboarding = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The root routing state — a single Equatable value so the loading → login →
    /// onboarding → tabs hand-offs cross-fade (`Motion.screen`) instead of snapping.
    private enum Route: Equatable {
        case loading, login, onboarding, main
    }

    private var route: Route {
        if isCheckingSession { return .loading }
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
            case .main:
                MainTabView()
                    .transition(.opacity)
            }
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
            // Link RevenueCat identity on fresh sign-in/sign-up
            Task {
                if let userId = await container.authService.currentUserId() {
                    await container.subscriptionService.logIn(userId: userId)
                }
            }
            // Non-blocking HealthKit liveness probe on fresh sign-in/sign-up.
            Task.detached(priority: .utility) {
                await container.healthKitService.runMigrationProbe()
            }
            // Re-evaluate onboarding after fresh signup (D-06)
            let athletes = (try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []
            if let a = athletes.first {
                needsOnboarding = (a.trainingFrequency == nil || a.experienceLevel == nil)
            }
        }
        .task {
            #if DEBUG
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

            // Check Keychain for existing session
            let hasSession = await container.authService.hasSession()
            if hasSession {
                // Bootstrap local Athlete if missing (fresh install with valid Keychain session)
                let localAthletes = try? modelContext.fetch(FetchDescriptor<Athlete>())
                if localAthletes?.isEmpty != false,
                   let userId = await container.authService.currentUserId() {
                    _ = await container.syncService.bootstrapAthlete(
                        context: modelContext,
                        userId: userId
                    )
                    // If bootstrap failed (no Supabase athlete row), treat as zombie account
                    let athletesAfterBootstrap = try? modelContext.fetch(FetchDescriptor<Athlete>())
                    if athletesAfterBootstrap?.isEmpty == true {
                        try? await container.authService.signOut()
                        isCheckingSession = false
                        return
                    }
                }
                // Session exists — sync if stale, then show app
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

                // Check if onboarding is needed (D-06)
                let onboardingAthletes = try? modelContext.fetch(FetchDescriptor<Athlete>())
                if let a = onboardingAthletes?.first {
                    needsOnboarding = (a.trainingFrequency == nil || a.experienceLevel == nil)
                }

                #if DEBUG
                // Seed mock data only in SCREENSHOT_MODE — prevents masking welcome card for real users
                if ProcessInfo.processInfo.arguments.contains("SCREENSHOT_MODE"),
                   let athlete = (try? modelContext.fetch(FetchDescriptor<Athlete>()))?.first {
                    MockDataSeeder.seed(modelContext: modelContext, athlete: athlete)
                }
                #endif
            }
            isCheckingSession = false
        }
    }

    #if DEBUG
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

/// The live app shell: five athlete tabs over the SwiftUI tree.
/// Coach mode is intentionally NOT represented here — the self-coached reset is product
/// intent; the UIKit AppShell carrying coach tabs was the deviation (orchestration D3/R6).
/// Mirrors the UIKit shell's scenePhase-active foreground sync (entitlement refresh +
/// push/pull when stale) so rehosting loses no sync behavior.
struct MainTabView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    /// The five athlete tabs. Selection is held here so tab REVISITS cross-fade content in
    /// via `tabCrossfade` (`Motion.screen`) instead of snapping; first renders stay with
    /// each screen's `entranceReveal` choreography.
    private enum Tab: Hashable {
        case home, log, recovery, load, profile
    }

    @State private var selectedTab: Tab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabCrossfade(isSelected: selectedTab == .home)
                .tabItem { Label("tab.home", systemImage: "sun.max") }
                .tag(Tab.home)

            WorkoutLogView()
                .tabCrossfade(isSelected: selectedTab == .log)
                .tabItem { Label("tab.log", systemImage: "figure.strengthtraining.traditional") }
                .tag(Tab.log)

            RecoveryView()
                .tabCrossfade(isSelected: selectedTab == .recovery)
                .tabItem { Label("tab.recovery", systemImage: "waveform.path.ecg") }
                .tag(Tab.recovery)

            WorkloadView()
                .tabCrossfade(isSelected: selectedTab == .load)
                .tabItem { Label("tab.load", systemImage: "chart.xyaxis.line") }
                .tag(Tab.load)

            ProfileView()
                .tabCrossfade(isSelected: selectedTab == .profile)
                .tabItem { Label("tab.profile", systemImage: "person.crop.circle") }
                .tag(Tab.profile)
        }
        // Selected-tab tint: text1, never accent (DESIGN.md — accent is reserved for the
        // hero readiness number). Scoped to the tab bar chrome via tabItem rendering.
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
