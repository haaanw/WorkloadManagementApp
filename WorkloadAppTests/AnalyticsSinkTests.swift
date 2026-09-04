import XCTest
@testable import workload_management

/// Batch-4 contracts: `UXAnalyticsService` stays the ONLY egress — a registered sink
/// receives events strictly AFTER the sanitizer, so no health-shaped property can reach
/// a vendor SDK; and the OnboardingV2 event names match the GROWTH-STACK §1.2 spec.
///
/// @MainActor with ONE statically-held service: `UXAnalyticsService` is MainActor-
/// isolated under the target's default isolation, and a transient instance deallocating
/// inside a test SIGABRTs in `swift_task_deinitOnExecutorMainActorBackDeploy`
/// (malloc report in `TaskLocal::StopLookupScope` — the C-wdg-002 trap family, read
/// from the crash report). Production never deallocates the service (AppContainer owns
/// it for the process lifetime); the tests mirror that instead of fighting the runtime.
@MainActor
final class AnalyticsSinkTests: XCTestCase {

    private final class SpySink: AnalyticsSink {
        var received: [(event: UXAnalyticsEvent, properties: [String: String])] = []
        func send(_ event: UXAnalyticsEvent, properties: [String: String]) {
            received.append((event, properties))
        }
    }

    /// Held for the process lifetime, like AppContainer's instance. Spies registered by
    /// individual tests only observe events tracked after their registration, so the
    /// shared instance cannot leak assertions across tests.
    private static let service = UXAnalyticsService()

    override func tearDown() {
        MainActor.assumeIsolated {
            Self.service.clear()
        }
        super.tearDown()
    }

    func test_sinkReceivesSanitizedPropertiesOnly() {
        let spy = SpySink()
        Self.service.register(sink: spy)

        Self.service.track(.revealRendered, properties: [
            "branch": "real",
            "confidence": "partial",
            "hrv_baseline": "62.4",        // forbidden fragment: hrv
            "raw_score": "74",             // forbidden fragment: raw
            "sleep_minutes": "412",        // forbidden fragment: sleep
            "heartRateToday": "51"         // forbidden fragment: heart
        ])

        XCTAssertEqual(spy.received.count, 1)
        let delivered = spy.received[0]
        XCTAssertEqual(delivered.event, .revealRendered)
        XCTAssertEqual(delivered.properties, ["branch": "real", "confidence": "partial"])
    }

    func test_sinkReceivesEveryTrackedEvent() {
        let spy = SpySink()
        Self.service.register(sink: spy)

        Self.service.track(.onboardingStarted)
        Self.service.track(.paywallShown, properties: ["gate": "hard"])

        XCTAssertEqual(spy.received.map(\.event), [.onboardingStarted, .paywallShown])
    }

    func test_track_recordsLocallyRegardlessOfSinks() {
        Self.service.clear()
        Self.service.track(.onboardingCompleted, properties: ["gate": "soft"])
        XCTAssertEqual(Self.service.recentRecords().last?.name, .onboardingCompleted)
    }

    /// The wire names are the funnel contract (GROWTH-STACK §1.2) — a rename breaks
    /// every dashboard; pin them.
    func test_onboardingEventWireNames_matchGrowthStackSpec() {
        XCTAssertEqual(UXAnalyticsEvent.onboardingStarted.rawValue, "onboarding_started")
        XCTAssertEqual(UXAnalyticsEvent.onboardingScreenViewed.rawValue, "onboarding_screen_viewed")
        XCTAssertEqual(UXAnalyticsEvent.onboardingScreenAdvanced.rawValue, "onboarding_screen_advanced")
        XCTAssertEqual(UXAnalyticsEvent.onboardingQuizAnswered.rawValue, "onboarding_quiz_answered")
        XCTAssertEqual(UXAnalyticsEvent.onboardingAbandoned.rawValue, "onboarding_abandoned")
        XCTAssertEqual(UXAnalyticsEvent.hkPromptShown.rawValue, "hk_prompt_shown")
        XCTAssertEqual(UXAnalyticsEvent.hkPromptCompleted.rawValue, "hk_prompt_completed")
        XCTAssertEqual(UXAnalyticsEvent.revealRendered.rawValue, "reveal_rendered")
        XCTAssertEqual(UXAnalyticsEvent.accountCreated.rawValue, "account_created")
        XCTAssertEqual(UXAnalyticsEvent.paywallShown.rawValue, "paywall_shown")
        XCTAssertEqual(UXAnalyticsEvent.trialStarted.rawValue, "trial_started")
        XCTAssertEqual(UXAnalyticsEvent.purchaseCompleted.rawValue, "purchase_completed")
        XCTAssertEqual(UXAnalyticsEvent.paywallDismissIntent.rawValue, "paywall_dismiss_intent")
        XCTAssertEqual(UXAnalyticsEvent.exitOfferShown.rawValue, "exit_offer_shown")
        XCTAssertEqual(UXAnalyticsEvent.exitOfferAccepted.rawValue, "exit_offer_accepted")
        XCTAssertEqual(UXAnalyticsEvent.onboardingCompleted.rawValue, "onboarding_completed")
    }

    /// No event name may carry a forbidden fragment itself — a sink logs the NAME too.
    func test_eventNames_carryNoForbiddenFragments() {
        let forbidden = ["raw", "healthkit", "hrv", "rhr", "heart", "sleep", "temperature", "vo2", "biometric"]
        for event in UXAnalyticsEvent.allCases {
            let name = event.rawValue.lowercased()
            for fragment in forbidden {
                XCTAssertFalse(name.contains(fragment), "\(event.rawValue) contains \(fragment)")
            }
        }
    }
}
