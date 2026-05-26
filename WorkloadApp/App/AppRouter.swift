import SwiftUI
import SwiftData
import Supabase
import GoogleSignIn

struct PendingInvite: Identifiable {
    let id = UUID()
    let code: String
}

struct PendingShareCode: Identifiable {
    let id = UUID()
    let code: String
}

struct AppRouter: View {
    @State private var container = AppContainer()
    @State private var isCheckingSession = true
    @State private var pendingInviteCode: PendingInvite?
    @State private var pendingShareCode: PendingShareCode?
    @State private var deferredShareCode: String?
    @State private var needsOnboarding = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if isCheckingSession {
                ProgressView("Loading...")
            } else if !container.isAuthenticated {
                LoginView()
            } else if needsOnboarding {
                OnboardingView(onComplete: { needsOnboarding = false })
            } else {
                MainTabView()
            }
        }
        .environment(container)
        .environment(\.locale, container.localeManager.activeLocale)
        .animation(.linear(duration: 0.15), value: container.localeManager.activeLocale)
        .onOpenURL { url in
            // Google Sign-In callback
            if GIDSignIn.sharedInstance.handle(url) { return }

            if let code = InviteService.handleDeepLink(url) {
                pendingInviteCode = PendingInvite(code: code)
                return
            }
            // Template share universal link: tuwa.app/t/{code} or workload://template?code={code}
            if let code = TemplateSharingService.handleDeepLink(url) {
                if container.isAuthenticated {
                    pendingShareCode = PendingShareCode(code: code)
                } else {
                    deferredShareCode = code
                }
                return
            }
            // Supabase OAuth callback fallback
            Task {
                try? await container.supabase.auth.session(from: url)
            }
        }
        .sheet(item: $pendingInviteCode) { pending in
            InviteConfirmationSheet(code: pending.code, mode: .athleteAccepting)
                .environment(container)
        }
        .sheet(item: $pendingShareCode) { pending in
            ShareImportSheet(prefillCode: pending.code)
                .environment(container)
        }
        .onChange(of: container.isAuthenticated) { _, isAuth in
            guard isAuth else { return }
            // Link RevenueCat identity on fresh sign-in/sign-up
            Task {
                if let userId = await container.authService.currentUserId() {
                    await container.subscriptionService.logIn(userId: userId)
                }
            }
            // Process deferred share code from deep link received before auth
            if let code = deferredShareCode {
                deferredShareCode = nil
                pendingShareCode = PendingShareCode(code: code)
            }
            // Re-evaluate onboarding after fresh signup (D-06)
            let athletes = (try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []
            if let a = athletes.first {
                needsOnboarding = (a.trainingFrequency == nil || a.experienceLevel == nil)
            }
        }
        .task {
            #if DEBUG
            // Screenshot mode: bypass auth, seed mock data, show app immediately
            if ProcessInfo.processInfo.arguments.contains("SCREENSHOT_MODE") {
                // Check for coach mode BEFORE setting default athlete mode
                let isCoachMode = ProcessInfo.processInfo.arguments.contains("COACH_MODE")
                container.setMode(isCoachMode ? .coach : .athlete)

                // SCREENSHOT_MODE locale override: belt-and-braces with Bundle resolution.
                // Honors `-AppleLanguages (zh-Hans)` launch arg for zh-Hans screenshot runs.
                let args = ProcessInfo.processInfo.arguments
                if let idx = args.firstIndex(of: "-AppleLanguages"),
                   idx + 1 < args.count,
                   args[idx + 1].contains("zh-Hans") {
                    container.localeManager.setLocale(Locale(identifier: "zh-Hans"))
                }

                let athletes = (try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []
                if athletes.isEmpty {
                    let athlete = Athlete(displayName: "Alex", sportType: .lifting)
                    modelContext.insert(athlete)
                    try? modelContext.save()
                    MockDataSeeder.seed(modelContext: modelContext, athlete: athlete)
                } else if let athlete = athletes.first {
                    athlete.isCoachOnly = isCoachMode
                    try? modelContext.save()
                    MockDataSeeder.seed(modelContext: modelContext, athlete: athlete)
                }
                container.setAuthenticated(true)
                needsOnboarding = false
                container.subscriptionService.overrideForScreenshots(
                    isPro: true,
                    isCoach: isCoachMode
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
}

struct MainTabView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var athletes: [Athlete]
    private let syncStore = SyncTimestampStore.shared  // Required for @Observable tracking

    private var athlete: Athlete? { athletes.first }

    /// Coach-only users always see coach mode — no toggle needed.
    /// Falls back to athlete mode if the coach subscription has expired.
    private var effectiveMode: AppMode {
        let requested = athlete?.isCoachOnly == true ? .coach : container.currentMode
        if requested == .coach && !container.subscriptionService.isCoach {
            return .athlete
        }
        return requested
    }

    var body: some View {
        TabView {
            if effectiveMode == .coach {
                CoachRosterView()
                    .tabItem { Label("tab.roster", systemImage: "person.2.fill") }
                NavigationStack {
                    TemplateListView()
                }
                    .tabItem { Label("tab.templates", systemImage: "doc.text.fill") }
                ProfileView()
                    .tabItem { Label("tab.profile", systemImage: "person.fill") }
                    .overlay(alignment: .topTrailing) {
                        if syncStore.hasAnyFailure {
                            Circle()
                                .fill(ColorTokens.zoneCaution)
                                .frame(width: 8, height: 8)
                                .offset(x: 8, y: -8)
                                .transition(.opacity.animation(.linear(duration: 0.15)))
                                .accessibilityLabel("Sync issues detected")
                                .accessibilityAddTraits(.updatesFrequently)
                        }
                    }
            } else {
                DashboardView()
                    .tabItem { Label("tab.home", systemImage: "house.fill") }
                WorkoutLogView()
                    .tabItem { Label("tab.log", systemImage: "list.bullet.clipboard.fill") }
                RecoveryView()
                    .tabItem { Label("tab.recovery", systemImage: "heart.fill") }
                WorkloadView()
                    .tabItem { Label("tab.load", systemImage: "chart.line.uptrend.xyaxis") }
                ProfileView()
                    .tabItem { Label("tab.profile", systemImage: "person.fill") }
                    .overlay(alignment: .topTrailing) {
                        if syncStore.hasAnyFailure {
                            Circle()
                                .fill(ColorTokens.zoneCaution)
                                .frame(width: 8, height: 8)
                                .offset(x: 8, y: -8)
                                .transition(.opacity.animation(.linear(duration: 0.15)))
                                .accessibilityLabel("Sync issues detected")
                                .accessibilityAddTraits(.updatesFrequently)
                        }
                    }
            }
        }
        .onAppear {
            // Coach-only users: ensure mode is always .coach
            if athlete?.isCoachOnly == true, container.currentMode != .coach {
                container.setMode(.coach)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await container.subscriptionService.refreshEntitlementAsync()
                guard container.syncService.shouldForegroundSync else { return }
                if effectiveMode == .coach, let id = athlete?.id {
                    await container.syncService.pullLinkedAthletes(context: modelContext)
                    let rels = (try? modelContext.fetch(FetchDescriptor<CoachAthleteRelationship>())) ?? []
                    for rel in rels where rel.coachId == id && rel.status == .accepted {
                        await container.syncService.pullAthleteSnapshots(
                            athleteId: rel.athleteId, context: modelContext
                        )
                    }
                } else {
                    await container.syncService.pushAll(context: modelContext)
                    await container.syncService.pullAll(context: modelContext)
                }
            }
        }
        .onChange(of: container.currentMode) { _, newMode in
            guard newMode == .coach, container.syncService.shouldForegroundSync,
                  let id = athlete?.id else { return }
            Task {
                await container.syncService.pullLinkedAthletes(context: modelContext)
                let rels = (try? modelContext.fetch(FetchDescriptor<CoachAthleteRelationship>())) ?? []
                for rel in rels where rel.coachId == id && rel.status == .accepted {
                    await container.syncService.pullAthleteSnapshots(
                        athleteId: rel.athleteId, context: modelContext
                    )
                }
            }
        }
    }
}
