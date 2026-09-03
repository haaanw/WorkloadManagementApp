import XCTest
@testable import workload_management

/// OnboardingV2 batch-1 contracts: the flag default, the pure routing decisions (flag-off
/// routing identical to today), the amendment-8 sentinel re-key, and the persisted gate
/// state round-trip in an isolated defaults suite.
final class OnboardingV2RoutingTests: XCTestCase {

    private var suite: UserDefaults!
    private let suiteName = "test.onboardingV2.routing"

    override func setUp() {
        super.setUp()
        suite = UserDefaults(suiteName: suiteName)
        suite.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        suite.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Flag

    func test_flagDefaultsOff() {
        XCTAssertFalse(OnboardingV2Flag.isEnabled(defaults: suite, arguments: []))
    }

    func test_flagReadsUserDefaults() {
        suite.set(true, forKey: OnboardingV2Flag.key)
        XCTAssertTrue(OnboardingV2Flag.isEnabled(defaults: suite, arguments: []))
    }

    #if DEBUG
    func test_debugLaunchArgumentEnables() {
        XCTAssertTrue(OnboardingV2Flag.isEnabled(defaults: suite, arguments: ["ONBOARDING_V2"]))
    }
    #endif

    // MARK: - Fresh-flow presentation

    func test_flagOff_neverPresents() {
        XCTAssertFalse(OnboardingV2Routing.presentsFreshFlow(
            flagEnabled: false, hasLocalSession: false, hasLocalAthlete: false, completed: false
        ))
    }

    func test_flagOn_freshInstall_presents() {
        XCTAssertTrue(OnboardingV2Routing.presentsFreshFlow(
            flagEnabled: true, hasLocalSession: false, hasLocalAthlete: false, completed: false
        ))
    }

    func test_returningUserWithSession_neverPresents() {
        XCTAssertFalse(OnboardingV2Routing.presentsFreshFlow(
            flagEnabled: true, hasLocalSession: true, hasLocalAthlete: true, completed: false
        ))
    }

    func test_localAthleteWithoutSession_neverPresents() {
        // Logged-out returning user: the login screen, not the quiz (C5).
        XCTAssertFalse(OnboardingV2Routing.presentsFreshFlow(
            flagEnabled: true, hasLocalSession: false, hasLocalAthlete: true, completed: false
        ))
    }

    func test_completedInstall_neverPresentsAgain() {
        XCTAssertFalse(OnboardingV2Routing.presentsFreshFlow(
            flagEnabled: true, hasLocalSession: false, hasLocalAthlete: false, completed: true
        ))
    }

    // MARK: - Paywall resume (state machine; consumed from batch 3)

    func test_resume_firesOnlyWhilePendingAndUnentitled() {
        XCTAssertTrue(OnboardingV2Routing.resumesAtPaywall(
            flagEnabled: true, paywallPending: true, isPro: false, completed: false
        ))
        XCTAssertFalse(OnboardingV2Routing.resumesAtPaywall(
            flagEnabled: true, paywallPending: true, isPro: true, completed: false
        ))
        XCTAssertFalse(OnboardingV2Routing.resumesAtPaywall(
            flagEnabled: true, paywallPending: false, isPro: false, completed: false
        ))
        XCTAssertFalse(OnboardingV2Routing.resumesAtPaywall(
            flagEnabled: false, paywallPending: true, isPro: false, completed: false
        ))
    }

    // MARK: - Amendment-8 sentinel re-key

    func test_sentinel_markerFalse_reducesToLegacyExpression() {
        // Existing installs (marker false): exactly today's behavior.
        XCTAssertTrue(OnboardingV2Routing.needsLegacyOnboarding(
            trainingFrequencySet: false, experienceLevelSet: false, v2Completed: false
        ))
        XCTAssertTrue(OnboardingV2Routing.needsLegacyOnboarding(
            trainingFrequencySet: true, experienceLevelSet: false, v2Completed: false
        ))
        XCTAssertFalse(OnboardingV2Routing.needsLegacyOnboarding(
            trainingFrequencySet: true, experienceLevelSet: true, v2Completed: false
        ))
    }

    func test_sentinel_v2Completer_neverLoopsIntoLegacyOnboarding() {
        // The amendment-8 defect this re-key exists to prevent: V2 skips screens 6–7,
        // so both fields stay nil — the marker must break the loop.
        XCTAssertFalse(OnboardingV2Routing.needsLegacyOnboarding(
            trainingFrequencySet: false, experienceLevelSet: false, v2Completed: true
        ))
    }

    // MARK: - Day-7 soft re-ask (clock half; batch 3)

    func test_softReask_firesAfterSevenDays_once() {
        let shown = Date(timeIntervalSince1970: 1_760_000_000)
        let sixDays = shown.addingTimeInterval(6 * 86_400)
        let eightDays = shown.addingTimeInterval(8 * 86_400)

        XCTAssertFalse(OnboardingV2Routing.softReaskIsDue(
            now: sixDays, flagEnabled: true, softShownAt: shown, reaskDone: false, isPro: false
        ))
        XCTAssertTrue(OnboardingV2Routing.softReaskIsDue(
            now: eightDays, flagEnabled: true, softShownAt: shown, reaskDone: false, isPro: false
        ))
        XCTAssertFalse(OnboardingV2Routing.softReaskIsDue(
            now: eightDays, flagEnabled: true, softShownAt: shown, reaskDone: true, isPro: false
        ), "the re-ask fires once, ever")
        XCTAssertFalse(OnboardingV2Routing.softReaskIsDue(
            now: eightDays, flagEnabled: true, softShownAt: shown, reaskDone: false, isPro: true
        ), "an entitled user is never re-asked")
        XCTAssertFalse(OnboardingV2Routing.softReaskIsDue(
            now: eightDays, flagEnabled: false, softShownAt: shown, reaskDone: false, isPro: false
        ))
        XCTAssertFalse(OnboardingV2Routing.softReaskIsDue(
            now: eightDays, flagEnabled: true, softShownAt: nil, reaskDone: false, isPro: false
        ), "no soft paywall was ever shown — nothing to re-ask")
    }

    // MARK: - Gate state round-trip

    func test_gateState_roundTrips() {
        let gate = OnboardingV2Gate(defaults: suite)
        XCTAssertFalse(gate.completed)
        XCTAssertNil(gate.branch)
        XCTAssertFalse(gate.paywallPending)
        XCTAssertFalse(gate.exitOfferShown)
        XCTAssertNil(gate.softPaywallShownAt)
        XCTAssertFalse(gate.reaskDone)

        gate.completed = true
        gate.branch = .degraded
        gate.paywallPending = true
        gate.exitOfferShown = true
        let stamp = Date(timeIntervalSince1970: 1_760_000_000)
        gate.softPaywallShownAt = stamp
        gate.reaskDone = true

        let reread = OnboardingV2Gate(defaults: suite)
        XCTAssertTrue(reread.completed)
        XCTAssertEqual(reread.branch, .degraded)
        XCTAssertTrue(reread.paywallPending)
        XCTAssertTrue(reread.exitOfferShown)
        XCTAssertEqual(reread.softPaywallShownAt, stamp)
        XCTAssertTrue(reread.reaskDone)
    }

    func test_gateKeys_areNamespaced() {
        for key in [
            OnboardingV2Gate.completedKey, OnboardingV2Gate.branchKey,
            OnboardingV2Gate.paywallPendingKey, OnboardingV2Gate.exitOfferShownKey,
            OnboardingV2Gate.softPaywallShownAtKey, OnboardingV2Gate.reaskDoneKey
        ] {
            XCTAssertTrue(key.hasPrefix("onboardingV2."), "un-namespaced gate key: \(key)")
        }
    }
}
