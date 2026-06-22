import Foundation
import RevenueCat

@MainActor
@Observable
final class SubscriptionService {

    /// True when the user holds an active Athlete Pro OR Coach entitlement.
    /// Gates all training-data features (history, overload suggestions, custom exercises, PRs).
    private(set) var isPro: Bool = false

    /// True when the user holds an active Coach entitlement specifically.
    /// Gates coach dashboard, coach mode switching, and coach-only toggle.
    private(set) var isCoach: Bool = false

    /// Whether RevenueCat was configured successfully. When false, all SDK calls are skipped.
    private var isConfigured = false

    init() {
        Purchases.logLevel = .error
        // Purchases.configure can crash with an assertion if the API key is empty
        // or if called multiple times. Guard against empty key.
        let apiKey = RevenueCatConfig.apiKey
        guard !apiKey.isEmpty else {
            print("RevenueCat configuration skipped: empty API key")
            return
        }
        Purchases.configure(withAPIKey: apiKey)
        isConfigured = true
        refreshEntitlement()
    }

    // MARK: - Identity

    /// Associates the RevenueCat anonymous user with the Supabase user ID.
    /// Must be called after authentication is confirmed.
    func logIn(userId: UUID) async {
        guard isConfigured else { return }
        do {
            let (info, _) = try await Purchases.shared.logIn(userId.uuidString)
            apply(info)
        } catch {
            print("RevenueCat logIn error: \(error)")
        }
    }

    // MARK: - Entitlement

    func refreshEntitlement() {
        guard isConfigured else { return }
        Task {
            await refreshEntitlementAsync()
        }
    }

    func refreshEntitlementAsync() async {
        guard isConfigured else { return }
        do {
            let info = try await Purchases.shared.customerInfo()
            apply(info)
        } catch {
            print("RevenueCat entitlement refresh error: \(error)")
        }
    }

    private func apply(_ info: CustomerInfo) {
        isCoach = info.entitlements["coach"]?.isActive == true
        // Athlete Pro OR Coach both unlock pro training features.
        isPro = isCoach || info.entitlements["athlete_pro"]?.isActive == true
    }

    // MARK: - Offerings

    /// Returns the self-coached Tuwa Pro offering (v1.5 is single-tier).
    /// RevenueCat offering identifier: "athlete_pro". A legacy `coach` entitlement is still
    /// recognized as Pro access in `refreshEntitlement`, but the coach OFFERING is no longer fetched.
    /// Falls back to the default current offering if the named one isn't found.
    func fetchOffering(for tier: SubscriptionTier) async throws -> Offering? {
        guard isConfigured else { return nil }
        let offerings = try await Purchases.shared.offerings()
        return offerings.offering(identifier: "athlete_pro") ?? offerings.current
    }

    // MARK: - Purchase

    func purchase(package: Package) async throws {
        guard isConfigured else { return }
        let result = try await Purchases.shared.purchase(package: package)
        apply(result.customerInfo)
    }

    // MARK: - Restore

    func restorePurchases() async throws {
        guard isConfigured else { return }
        let info = try await Purchases.shared.restorePurchases()
        apply(info)
    }

    // MARK: - Pure helpers (static — testable without SDK)

    /// Returns sessions dated within 7 days of `date`, inclusive.
    static func filterSessionsForFree(
        _ sessions: [WorkoutSession],
        relativeTo date: Date = .now
    ) -> [WorkoutSession] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: date)!
        return sessions.filter { $0.sessionDate >= cutoff }
    }

    /// Returns snapshots dated within 7 days of `date`, inclusive.
    static func filterSnapshotsForFree(
        _ snapshots: [WorkloadSnapshot],
        relativeTo date: Date = .now
    ) -> [WorkloadSnapshot] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: date)!
        return snapshots.filter { $0.snapshotDate >= cutoff }
    }

    /// Converts a count of locked daily history entries into approximate weeks.
    /// Returns 0 if nothing is locked.
    static func lockedWeeks(totalSessions: Int, visibleSessions: Int) -> Int {
        let locked = max(0, totalSessions - visibleSessions)
        guard locked > 0 else { return 0 }
        return max(1, locked / 7)
    }

    // MARK: - Screenshot Support

    #if DEBUG
    /// Force subscription state for screenshot capture.
    /// Call ONLY from SCREENSHOT_MODE bootstrap in AppRouter.
    func overrideForScreenshots(isPro override: Bool, isCoach coachOverride: Bool) {
        self.isPro = override
        self.isCoach = coachOverride
    }
    #endif
}
