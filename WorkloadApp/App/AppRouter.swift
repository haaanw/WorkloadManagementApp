import SwiftUI
import SwiftData
import Supabase
import GoogleSignIn

struct AppRouter: View {
    @State private var container = AppContainer()
    @State private var isCheckingSession = true
    @State private var needsOnboarding = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if isCheckingSession {
                UIKitLoadingController(
                    title: "Preparing Tuwa",
                    message: "Checking your account, local data, and training context."
                )
            } else if !container.isAuthenticated {
                UIKitAuthFlowController(
                    container: container,
                    modelContext: modelContext,
                    locale: container.localeManager.activeLocale
                )
            } else if needsOnboarding {
                UIKitOnboardingFlowController(
                    container: container,
                    modelContext: modelContext,
                    locale: container.localeManager.activeLocale,
                    onComplete: { needsOnboarding = false }
                )
            } else {
                AppShell()
            }
        }
        .environment(container)
        .environment(\.locale, container.localeManager.activeLocale)
        .animation(Motion.state, value: container.localeManager.activeLocale)
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
