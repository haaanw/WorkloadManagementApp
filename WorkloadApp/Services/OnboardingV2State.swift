import Foundation

// MARK: - Feature flag (BUILD-PLAN §5)

/// `OnboardingV2` gate — read once at router level. Default **true** since 2026-09-14
/// (HAN's explicit go, v1.7.3 UAT round 2): a fresh install routes through the 12-screen
/// flow. A stored `false` under `key` turns it back off — the kill switch keeps working
/// without a build. Flipping ON is also the moment the BUILD-PLAN §4 release gate applies:
/// ASC privacy label reconciled and PostHog disclosed before the archive is submitted.
///
/// Was default **false** from 3e6bdb8 (2026-09-03) until this flip; while off, the shipped
/// 4-step `OnboardingView` and the login-first route were behaviorally identical to 1.7.2.
enum OnboardingV2Flag {
    static let key = "flag.onboardingV2"
    static let defaultValue = true

    static func isEnabled(
        defaults: UserDefaults = .standard,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Bool {
        #if DEBUG
        // Launch argument for demos, screenshots, and UAT — DEBUG builds only.
        if arguments.contains("ONBOARDING_V2") { return true }
        #endif
        if let stored = defaults.object(forKey: key) as? Bool { return stored }
        return defaultValue
    }
}

// MARK: - In-memory quiz answers (C7: no schema change)

/// Quiz answers live in memory for the whole pre-auth stretch of the flow. Q1–Q3 are
/// segmentation, not physiology — they never reach `Athlete`, and they leave the device
/// only as low-cardinality `choice_id`s on `onboarding_quiz_answered` (batch 4).
struct OnboardingAnswers: Equatable {
    var problemChoiceID: String?
    var splitChoiceID: String?
    var fatigueChoiceID: String?
}

// MARK: - Persisted gate state (BUILD-PLAN §3)

/// The paywall-gate state machine's persisted half. All keys namespaced `onboardingV2.`,
/// UserDefaults-backed with an injectable suite so tests never touch the standard domain.
/// `paywallPending` survives relaunch by design: an account exists at that point and the
/// wall is the product boundary, not a UI accident.
struct OnboardingV2Gate {
    enum Branch: String {
        case real
        case degraded
    }

    static let completedKey = "onboardingV2.completed"
    static let branchKey = "onboardingV2.branch"
    static let paywallPendingKey = "onboardingV2.paywallPending"
    static let exitOfferShownKey = "onboardingV2.exitOfferShown"
    static let softPaywallShownAtKey = "onboardingV2.softPaywallShownAt"
    static let reaskDoneKey = "onboardingV2.reaskDone"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var completed: Bool {
        get { defaults.bool(forKey: Self.completedKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.completedKey) }
    }

    var branch: Branch? {
        get { defaults.string(forKey: Self.branchKey).flatMap(Branch.init(rawValue:)) }
        nonmutating set { defaults.set(newValue?.rawValue, forKey: Self.branchKey) }
    }

    var paywallPending: Bool {
        get { defaults.bool(forKey: Self.paywallPendingKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.paywallPendingKey) }
    }

    var exitOfferShown: Bool {
        get { defaults.bool(forKey: Self.exitOfferShownKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.exitOfferShownKey) }
    }

    var softPaywallShownAt: Date? {
        get { defaults.object(forKey: Self.softPaywallShownAtKey) as? Date }
        nonmutating set { defaults.set(newValue, forKey: Self.softPaywallShownAtKey) }
    }

    var reaskDone: Bool {
        get { defaults.bool(forKey: Self.reaskDoneKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.reaskDoneKey) }
    }
}

// MARK: - Pure routing decisions

/// Router-level decisions as pure functions, so the flag-off contract ("routing identical
/// to today") and the amendment-8 sentinel re-key are unit-testable without SwiftUI.
enum OnboardingV2Routing {

    /// Fresh-install entry: the flow presents pre-auth only when the flag is on, no
    /// Keychain session exists (a returning user must never see it — C5), no local
    /// athlete exists, and the flow has not already completed on this install.
    static func presentsFreshFlow(
        flagEnabled: Bool,
        hasLocalSession: Bool,
        hasLocalAthlete: Bool,
        completed: Bool
    ) -> Bool {
        flagEnabled && !hasLocalSession && !hasLocalAthlete && !completed
    }

    /// Relaunch-during-hard-paywall resume (BUILD-PLAN §3): an account exists, the wall
    /// was pending, and no entitlement arrived — resume AT the paywall.
    static func resumesAtPaywall(
        flagEnabled: Bool,
        paywallPending: Bool,
        isPro: Bool,
        completed: Bool
    ) -> Bool {
        flagEnabled && paywallPending && !isPro && !completed
    }

    /// Day-7 soft-paywall re-ask, time-and-flags half (BUILD-PLAN §3). The data half —
    /// "the app now has observed HRV days ≥ floor" — is asynchronous and checked at the
    /// call site via the same reveal math, so this stays a pure clock decision.
    static func softReaskIsDue(
        now: Date,
        flagEnabled: Bool,
        softShownAt: Date?,
        reaskDone: Bool,
        isPro: Bool
    ) -> Bool {
        guard flagEnabled, !reaskDone, !isPro, let shownAt = softShownAt else { return false }
        return now.timeIntervalSince(shownAt) >= 7 * 86_400
    }

    /// Amendment 8 sentinel re-key. The legacy sentinel keyed on
    /// `trainingFrequency == nil || experienceLevel == nil`; V2 removes those screens, so
    /// a V2 completer would loop into legacy onboarding forever without the explicit
    /// marker. With the marker false (every existing install), the expression reduces to
    /// the legacy one exactly — flag-off behavior is unchanged.
    static func needsLegacyOnboarding(
        trainingFrequencySet: Bool,
        experienceLevelSet: Bool,
        v2Completed: Bool
    ) -> Bool {
        !v2Completed && (!trainingFrequencySet || !experienceLevelSet)
    }
}
