import Foundation

/// Pure analytics computation engine. No state, no side effects.
/// Computes weekly summaries with week-over-week deltas for the analytics dashboard.
struct AnalyticsEngine {

    // MARK: - Data Types

    enum TrendDirection: String {
        case increasing
        case decreasing
        case stable
    }

    struct WeeklySummary {
        let sessionCount: Int
        let totalVolume: Double
        let avgRecoveryScore: Double
        let loadTrendDirection: TrendDirection
        let acwrZoneDistribution: [ACWRZone: Int]
        let sessionCountDelta: Double   // percentage vs previous week (+12.0 = +12%)
        let volumeDelta: Double         // percentage vs previous week
        let recoveryDelta: Double       // percentage vs previous week
    }

    // MARK: - Weekly Summary (ANLYT-02, ANLYT-03)

    /// Compute weekly summary comparing current 7-day window to previous 7-day window.
    static func computeWeeklySummary(
        currentWeekSessions: [WorkoutSession],
        previousWeekSessions: [WorkoutSession],
        currentWeekRecoverySnapshots: [RecoverySnapshot],
        previousWeekRecoverySnapshots: [RecoverySnapshot],
        currentWeekWorkloadSnapshots: [WorkloadSnapshot]
    ) -> WeeklySummary {
        let sessionCount = currentWeekSessions.count
        let totalVolume = currentWeekSessions.reduce(0.0) { $0 + $1.totalVolume }
        let avgRecovery = currentWeekRecoverySnapshots.isEmpty ? 0 :
            currentWeekRecoverySnapshots.reduce(0.0) { $0 + $1.recoveryScore } / Double(currentWeekRecoverySnapshots.count)

        // Load trend: compare first half vs second half of current week snapshots
        let loadTrend: TrendDirection = {
            guard currentWeekWorkloadSnapshots.count >= 4 else { return .stable }
            let sorted = currentWeekWorkloadSnapshots.sorted { $0.snapshotDate < $1.snapshotDate }
            let mid = sorted.count / 2
            let firstHalf = sorted.prefix(mid).map(\.acuteLoad).reduce(0, +) / Double(mid)
            let secondHalf = sorted.suffix(from: mid).map(\.acuteLoad).reduce(0, +) / Double(sorted.count - mid)
            if secondHalf > firstHalf * 1.05 { return .increasing }
            if secondHalf < firstHalf * 0.95 { return .decreasing }
            return .stable
        }()

        // Zone distribution from workload snapshots
        var zoneDistribution: [ACWRZone: Int] = [:]
        for snapshot in currentWeekWorkloadSnapshots {
            zoneDistribution[snapshot.zone, default: 0] += 1
        }

        // Week-over-week deltas (ANLYT-03)
        let prevSessionCount = previousWeekSessions.count
        let prevVolume = previousWeekSessions.reduce(0.0) { $0 + $1.totalVolume }
        let prevAvgRecovery = previousWeekRecoverySnapshots.isEmpty ? 0 :
            previousWeekRecoverySnapshots.reduce(0.0) { $0 + $1.recoveryScore } / Double(previousWeekRecoverySnapshots.count)

        let sessionDelta = prevSessionCount > 0 ? ((Double(sessionCount) - Double(prevSessionCount)) / Double(prevSessionCount)) * 100 : 0
        let volumeDelta = prevVolume > 0 ? ((totalVolume - prevVolume) / prevVolume) * 100 : 0
        let recoveryDelta = prevAvgRecovery > 0 ? ((avgRecovery - prevAvgRecovery) / prevAvgRecovery) * 100 : 0

        return WeeklySummary(
            sessionCount: sessionCount,
            totalVolume: totalVolume,
            avgRecoveryScore: avgRecovery,
            loadTrendDirection: loadTrend,
            acwrZoneDistribution: zoneDistribution,
            sessionCountDelta: sessionDelta,
            volumeDelta: volumeDelta,
            recoveryDelta: recoveryDelta
        )
    }
}

enum UXAnalyticsEvent: String, Codable, CaseIterable {
    case athleteTabViewed = "athlete_tab_viewed"
    case primaryActionTapped = "primary_action_tapped"
    case todayRecommendationOpened = "today_recommendation_opened"
    case todayPlanDecisionMade = "today_plan_decision_made"
    case workoutStarted = "workout_started"
    case workoutResumed = "workout_resumed"
    case workoutFinished = "workout_finished"
    case programStarted = "program_started"
    case workoutImportStarted = "workout_import_started"
    case insightsSectionViewed = "insights_section_viewed"
    case insightDetailOpened = "insight_detail_opened"
    case permissionCTATapped = "permission_cta_tapped"
    case profileDestinationOpened = "profile_destination_opened"
    case coachContextSwitched = "coach_context_switched"
    case uiErrorPresented = "ui_error_presented"

    // OnboardingV2 funnel (GROWTH-STACK §1.2). Property discipline: every numeric is a
    // BUCKET (`confidence: floor|partial|full`, `readiness_band: low|mid|high`), never a
    // value; quiz answers are low-cardinality choice IDs. `hk_granted`/`hk_denied` are
    // deliberately absent — READ denial is unobservable (C3), so the truthful event is
    // `hk_prompt_completed{outcome: data_found|no_data}`.
    case onboardingStarted = "onboarding_started"
    case onboardingScreenViewed = "onboarding_screen_viewed"
    case onboardingScreenAdvanced = "onboarding_screen_advanced"
    case onboardingQuizAnswered = "onboarding_quiz_answered"
    case onboardingAbandoned = "onboarding_abandoned"
    case hkPromptShown = "hk_prompt_shown"
    case hkPromptCompleted = "hk_prompt_completed"
    case revealRendered = "reveal_rendered"
    case accountCreated = "account_created"
    case paywallShown = "paywall_shown"
    case trialStarted = "trial_started"
    case purchaseCompleted = "purchase_completed"
    case paywallDismissIntent = "paywall_dismiss_intent"
    case exitOfferShown = "exit_offer_shown"
    case exitOfferAccepted = "exit_offer_accepted"
    case onboardingCompleted = "onboarding_completed"
}

/// A downstream receiver of sanitized analytics events. `UXAnalyticsService` is the ONLY
/// egress: sinks receive events strictly AFTER `sanitized(_:)` has run, so nothing
/// health-shaped can reach a vendor SDK. Views never talk to a sink directly.
protocol AnalyticsSink: AnyObject {
    func send(_ event: UXAnalyticsEvent, properties: [String: String])
}

struct UXAnalyticsRecord: Codable, Equatable {
    let name: UXAnalyticsEvent
    let timestamp: Date
    let properties: [String: String]
}

/// Local UX-funnel instrumentation for UI validation.
/// Stores high-level interaction events only; raw HealthKit or biometric values are rejected.
final class UXAnalyticsService {
    private let storageKey = "uxAnalytics.records"
    private let maxRecords = 200
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Registered sinks (e.g. PostHog behind the OnboardingV2 flag). Receive
    /// SANITIZED properties only — registration order is delivery order.
    private var sinks: [AnalyticsSink] = []

    func register(sink: AnalyticsSink) {
        sinks.append(sink)
    }

    func track(_ event: UXAnalyticsEvent, properties: [String: String] = [:]) {
        let clean = sanitized(properties)
        let record = UXAnalyticsRecord(
            name: event,
            timestamp: Date(),
            properties: clean
        )
        var records = recentRecords()
        records.append(record)
        if records.count > maxRecords {
            records.removeFirst(records.count - maxRecords)
        }
        if let data = try? encoder.encode(records) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        for sink in sinks {
            sink.send(event, properties: clean)
        }
    }

    func recentRecords() -> [UXAnalyticsRecord] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let records = try? decoder.decode([UXAnalyticsRecord].self, from: data) else {
            return []
        }
        return records
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    private func sanitized(_ properties: [String: String]) -> [String: String] {
        properties.filter { key, _ in
            let normalized = key.lowercased()
            return forbiddenPropertyFragments.contains { normalized.contains($0) } == false
        }
    }

    private var forbiddenPropertyFragments: [String] {
        [
            "raw",
            "healthkit",
            "hrv",
            "rhr",
            "heart",
            "sleep",
            "temperature",
            "vo2",
            "biometric"
        ]
    }
}
