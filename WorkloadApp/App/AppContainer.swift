import Foundation
import SwiftData
import Supabase

/// Central dependency container.
/// Owns the SupabaseClient, AuthService, SyncService, and HealthKitService.
@MainActor
@Observable
final class AppContainer {
    let subscriptionService: SubscriptionService
    let supabase: SupabaseClient
    let authService: AuthService
    let healthKitService: HealthKitService
    let syncService: SyncService
    let notificationService: NotificationService
    let localeManager: LocaleManager
    let uxAnalyticsService: UXAnalyticsService

    private(set) var isAuthenticated = false
    private(set) var currentMode: AppContext

    private static let appContextKey = "appContext"

    init() {
        if let rawContext = UserDefaults.standard.string(forKey: Self.appContextKey),
           let storedContext = AppContext(rawValue: rawContext) {
            self.currentMode = storedContext
        } else {
            self.currentMode = .athlete
        }

        self.subscriptionService = SubscriptionService()

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        // Note: `PostgrestClientOptions` is the correct type in supabase-swift ≥ 2.x.
        // If it doesn't compile, check the SDK version — older releases use `SupabaseClientOptions.DatabaseOptions`.
        let client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey,
            options: SupabaseClientOptions(
                db: .init(encoder: encoder, decoder: decoder)
            )
        )
        self.supabase = client
        self.authService = AuthService(client: client)
        self.healthKitService = HealthKitService()
        self.syncService = SyncService(client: client)
        self.notificationService = NotificationService()
        self.localeManager = LocaleManager()
        self.uxAnalyticsService = UXAnalyticsService()

        // Phase 23 P2: Cancel any legacy weekly-summary pending requests so the next
        // schedule call reissues with deliver-time localization. Idempotent: stamps
        // UserDefaults with the current schema version on first run.
        self.notificationService.migrateWeeklySummaryIfNeeded()

        // Subscribe to session-loss events only.
        // Sign-in/sign-up transitions set isAuthenticated manually (after sync completes).
        Task {
            for await (event, _) in client.auth.authStateChanges {
                switch event {
                case .signedOut, .passwordRecovery:
                    self.isAuthenticated = false
                default:
                    break
                }
            }
        }
    }

    /// Called by LoginView and SignUpView after auth + sync complete.
    func setAuthenticated(_ value: Bool) {
        isAuthenticated = value
    }

    func setMode(_ mode: AppContext) {
        currentMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: Self.appContextKey)
        uxAnalyticsService.track(.coachContextSwitched, properties: ["context": mode.rawValue])
    }

    /// Sign out: clear Supabase session + wipe local SwiftData via cascade delete.
    /// modelContext is passed from the calling view.
    func signOut(modelContext: ModelContext) async throws {
        try await authService.signOut()
        SyncTimestampStore.shared.clearAll()  // Clear sync timestamps on sign-out
        // Cascade delete: Athlete has deleteRule: .cascade on all relationships
        let athletes = try modelContext.fetch(FetchDescriptor<Athlete>())
        for athlete in athletes {
            modelContext.delete(athlete)
        }
        // ExerciseOverride is local-only and NOT athlete-scoped (keyed by exercise name),
        // so it survives the cascade — purge explicitly or the next signed-in user
        // inherits the previous user's hidden/remapped exercises (codex P2, 2026-07-18).
        let overrides = try modelContext.fetch(FetchDescriptor<ExerciseOverride>())
        for override in overrides { modelContext.delete(override) }
        try modelContext.save()
        isAuthenticated = false
    }

    /// Permanently deletes the user's account (Supabase auth + all data) then signs out locally.
    func deleteAccount(modelContext: ModelContext) async throws {
        try await authService.deleteAccount()
        SyncTimestampStore.shared.clearAll()  // Clear sync timestamps on account deletion
        // Clear all local SwiftData — Athlete cascade covers most, but some models
        // reference by raw UUID and won't cascade. Delete them explicitly.
        let athletes = try modelContext.fetch(FetchDescriptor<Athlete>())
        for athlete in athletes { modelContext.delete(athlete) }
        let relationships = try modelContext.fetch(FetchDescriptor<CoachAthleteRelationship>())
        for rel in relationships { modelContext.delete(rel) }
        let templates = try modelContext.fetch(FetchDescriptor<WorkoutTemplate>())
        for tmpl in templates { modelContext.delete(tmpl) }
        let prescribed = try modelContext.fetch(FetchDescriptor<PrescribedWorkout>())
        for pw in prescribed { modelContext.delete(pw) }
        let profiles = try modelContext.fetch(FetchDescriptor<TrainingProfile>())
        for p in profiles { modelContext.delete(p) }
        let overrides = try modelContext.fetch(FetchDescriptor<ExerciseOverride>())
        for override in overrides { modelContext.delete(override) }
        try modelContext.save()
        isAuthenticated = false
    }
}
