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

    private(set) var isAuthenticated = false

    var currentMode: AppMode = {
        let stored = UserDefaults.standard.string(forKey: "appMode") ?? AppMode.athlete.rawValue
        return AppMode(rawValue: stored) ?? .athlete
    }()

    func setMode(_ mode: AppMode) {
        currentMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "appMode")
    }

    init() {
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

        // Subscribe to session-loss events only.
        // Sign-in/sign-up transitions set isAuthenticated manually (after sync completes).
        Task {
            do {
                for await (event, _) in client.auth.authStateChanges {
                    switch event {
                    case .signedOut, .passwordRecovery:
                        self.isAuthenticated = false
                    default:
                        break
                    }
                }
            } catch {
                print("Auth state listener error: \(error)")
            }
        }
    }

    /// Called by LoginView and SignUpView after auth + sync complete.
    func setAuthenticated(_ value: Bool) {
        isAuthenticated = value
    }

    /// Sign out: clear Supabase session + wipe local SwiftData via cascade delete.
    /// modelContext is passed from the calling view.
    func signOut(modelContext: ModelContext) async throws {
        try await authService.signOut()
        // Cascade delete: Athlete has deleteRule: .cascade on all relationships
        let athletes = try modelContext.fetch(FetchDescriptor<Athlete>())
        for athlete in athletes {
            modelContext.delete(athlete)
        }
        try modelContext.save()
        isAuthenticated = false
    }
}
