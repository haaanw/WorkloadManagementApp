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

    // Shared date parsers for the Supabase decoder (formatter construction is expensive;
    // the custom strategy runs per date field).
    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let iso = ISO8601DateFormatter()
    private static let postgresDay: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

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
        // Postgres timestamps come back in more shapes than plain `.iso8601` accepts:
        // PostgREST serialises `timestamptz` written by `DEFAULT now()` WITH fractional
        // seconds, and a bare `date` column as "yyyy-MM-dd" — `.iso8601` rejects both and
        // every pull on such a table dies with "Data format error" (v1.7.1 sync repair).
        // Date-only COLUMNS are owned by the `DateOnly` wrapper in SyncService; the bare-
        // date branch here is defense in depth for any field still typed `Date`.
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            if let date = Self.isoFractional.date(from: raw) ?? Self.iso.date(from: raw) {
                return date
            }
            if raw.count == 10, let date = Self.postgresDay.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Unrecognized date string: \(raw)"
            ))
        }

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

        // PostHog rides BEHIND the sanitizer as a sink, and only while the OnboardingV2
        // flag is on (BUILD-PLAN §4; the release gate — ASC privacy label + vendor
        // approval — applies at flag flip). Nil until HAN fills the ingest key.
        if OnboardingV2Flag.isEnabled(), let postHogSink = PostHogAnalyticsSink() {
            uxAnalyticsService.register(sink: postHogSink)
        }

        // Phase 23 P2: Cancel any legacy weekly-summary pending requests so the next
        // schedule call reissues with deliver-time localization. Idempotent: stamps
        // UserDefaults with the current schema version on first run.
        self.notificationService.migrateWeeklySummaryIfNeeded()

        // U18: tell Today when the body reports something new while the app is up.
        registerRecoverySignalObserver()

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

    // MARK: - Recovery-signal observation (v1.7.3 · U18)

    /// Coalesces a burst of HealthKit deliveries into one notice. Cancelled and re-armed on
    /// every delivery, so three types landing together (a watch syncing the night's HRV,
    /// resting heart rate and sleep at once) re-run the pipeline once, not three times.
    /// `@ObservationIgnored` on purpose: this is bookkeeping, not state any view reads, and
    /// re-arming it on every HealthKit delivery must not invalidate the whole tree.
    @ObservationIgnored private var recoverySignalNotice: Task<Void, Never>?

    /// How long a delivery waits for its neighbours before Today is told.
    private static let recoverySignalDebounce: Duration = .seconds(2)

    /// Register the HRV / RHR / sleep observers and post `recoverySignalsChanged`, debounced.
    ///
    /// Foreground-only by design: nothing here asks HealthKit to launch the app for these
    /// types, and no entitlement is added. A reading that lands while the app is not running
    /// is picked up by the next foreground pipeline run, which is soon enough for a number the
    /// athlete only reads when they open the app. Registration lives here rather than in a
    /// view because the container outlives every scene — a view-registered observer would be
    /// re-created on each appearance.
    ///
    /// The completion handler HealthKit passes is called on EVERY path, via `defer`. Three
    /// unacknowledged deliveries and HealthKit stops waking the app until the next launch.
    private func registerRecoverySignalObserver() {
        healthKitService.observeRecoverySignals { [weak self] completion in
            // HealthKit calls back on its own queue; everything below is main-actor work.
            Task { @MainActor in
                defer { completion() }
                guard let self else { return }
                self.scheduleRecoverySignalNotice()
            }
        }
    }

    private func scheduleRecoverySignalNotice() {
        recoverySignalNotice?.cancel()
        recoverySignalNotice = Task { @MainActor in
            try? await Task.sleep(for: Self.recoverySignalDebounce)
            guard !Task.isCancelled else { return }
            NotificationCenter.default.post(name: .recoverySignalsChanged, object: nil)
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
        // Tombstones are sync bookkeeping keyed by athlete id, not an Athlete relationship,
        // so they survive the cascade. Left behind, the next signed-in account inherits
        // them and any row whose id collides would be silently refused on pull (v1.7.2).
        for tombstone in SyncTombstone.all(in: modelContext) { modelContext.delete(tombstone) }
        // The watch-import bookmark is a UserDefaults value, so it survives the cascade the
        // same way the overrides above do. Left behind, the next athlete on this device
        // starts with the previous one's anchor and their first fortnight of workouts is
        // never imported (v1.7.3 · U4).
        WatchWorkoutImportService.resetAnchor()
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
        for tombstone in SyncTombstone.all(in: modelContext) { modelContext.delete(tombstone) }
        // The watch-import bookmark is a UserDefaults value, so it survives the cascade the
        // same way the overrides above do. Left behind, the next athlete on this device
        // starts with the previous one's anchor and their first fortnight of workouts is
        // never imported (v1.7.3 · U4).
        WatchWorkoutImportService.resetAnchor()
        try modelContext.save()
        isAuthenticated = false
    }
}
