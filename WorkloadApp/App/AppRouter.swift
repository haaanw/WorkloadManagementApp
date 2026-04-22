import SwiftUI
import SwiftData

struct PendingInvite: Identifiable {
    let id = UUID()
    let code: String
}

struct AppRouter: View {
    @State private var container = AppContainer()
    @State private var isCheckingSession = true
    @State private var pendingInviteCode: PendingInvite?
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
        .onOpenURL { url in
            if let code = InviteService.handleDeepLink(url) {
                pendingInviteCode = PendingInvite(code: code)
            }
        }
        .sheet(item: $pendingInviteCode) { pending in
            InviteConfirmationSheet(code: pending.code, mode: .athleteAccepting)
                .environment(container)
        }
        .onChange(of: container.isAuthenticated) { _, isAuth in
            guard isAuth else { return }
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
                // Force athlete mode (override persisted UserDefaults from prior runs)
                container.setMode(.athlete)
                let athletes = (try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []
                if athletes.isEmpty {
                    let athlete = Athlete(displayName: "Alex", sportType: .lifting)
                    modelContext.insert(athlete)
                    try? modelContext.save()
                    MockDataSeeder.seed(modelContext: modelContext, athlete: athlete)
                } else if let athlete = athletes.first {
                    athlete.isCoachOnly = false
                    try? modelContext.save()
                    MockDataSeeder.seed(modelContext: modelContext, athlete: athlete)
                }
                container.setAuthenticated(true)
                needsOnboarding = false
                container.subscriptionService.overrideForScreenshots(isPro: true, isCoach: false)
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

    private var athlete: Athlete? { athletes.first }

    /// Coach-only users always see coach mode — no toggle needed.
    private var effectiveMode: AppMode {
        athlete?.isCoachOnly == true ? .coach : container.currentMode
    }

    var body: some View {
        TabView {
            if effectiveMode == .coach {
                CoachRosterView()
                    .tabItem { Label("Roster", systemImage: "person.2.fill") }
                NavigationStack {
                    TemplateListView()
                }
                    .tabItem { Label("Templates", systemImage: "doc.text.fill") }
                ProfileView()
                    .tabItem { Label("Profile", systemImage: "person.fill") }
            } else {
                DashboardView()
                    .tabItem { Label("Home", systemImage: "house.fill") }
                WorkoutLogView()
                    .tabItem { Label("Log", systemImage: "list.bullet.clipboard.fill") }
                RecoveryView()
                    .tabItem { Label("Recovery", systemImage: "heart.fill") }
                WorkloadView()
                    .tabItem { Label("Load", systemImage: "chart.line.uptrend.xyaxis") }
                ProfileView()
                    .tabItem { Label("Profile", systemImage: "person.fill") }
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
            container.subscriptionService.refreshEntitlement()
            guard container.syncService.shouldForegroundSync else { return }
            Task {
                if container.currentMode == .coach, let id = athlete?.id {
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
