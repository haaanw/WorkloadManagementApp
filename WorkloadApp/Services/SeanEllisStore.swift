import Foundation

/// Phase 45 Plan 04 (METRIC-03) — local-only persistence + trigger eligibility for the Sean-Ellis
/// disappointment question ("How would you feel if you could no longer use Tuwa?").
///
/// ## Local-only contract
/// The answer is stored ONLY in the injected `UserDefaults` (default `.standard`). It is NEVER
/// Codable-to-Supabase, never networked, never synced — mirroring the project's never-leave-device
/// posture for self-reported signals. No SwiftData model, no DTO.
///
/// ## Deterministic eligibility
/// `shouldPrompt` is a pure read of the injected defaults + the passed-in `verdictEventCount`; it does
/// NOT bake `.now` into the decision (the recording timestamp is injected by the caller). This makes
/// the gate fully unit-testable with an isolated `UserDefaults(suiteName:)`.
struct SeanEllisStore {

    enum Disappointment: String {
        case very
        case somewhat
        case not
    }

    private let defaults: UserDefaults

    /// Namespaced keys so the store never collides with other UserDefaults consumers.
    private enum Key {
        static let lastAnswerRaw = "seanEllis.lastAnswerRaw"
        static let lastAnsweredAt = "seanEllis.lastAnsweredAt"
        static let lastPromptedAtCount = "seanEllis.lastPromptedAtCount"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The last recorded answer, if any.
    var lastAnswer: Disappointment? {
        guard let raw = defaults.string(forKey: Key.lastAnswerRaw) else { return nil }
        return Disappointment(rawValue: raw)
    }

    /// The event count at the time of the last answer (`nil` if never answered).
    private var lastAnsweredEventCount: Int? {
        // `object(forKey:)` distinguishes "never set" (nil) from a stored 0.
        defaults.object(forKey: Key.lastPromptedAtCount) as? Int
    }

    /// Persist the raw answer + the answering date + the event count at answer time.
    func recordAnswer(_ answer: Disappointment, atEventCount eventCount: Int, on date: Date) {
        defaults.set(answer.rawValue, forKey: Key.lastAnswerRaw)
        defaults.set(date, forKey: Key.lastAnsweredAt)
        defaults.set(eventCount, forKey: Key.lastPromptedAtCount)
    }

    /// True only when:
    ///   - `verdictEventCount >= threshold`, AND
    ///   - the athlete has never answered, OR enough NEW events have accrued since the last answer to
    ///     re-qualify (≥ `threshold` more events than the count at the last answer).
    /// Pure read of the injected defaults — no `.now` inside the decision.
    func shouldPrompt(verdictEventCount: Int, threshold: Int = 5) -> Bool {
        guard verdictEventCount >= threshold else { return false }
        guard let lastCount = lastAnsweredEventCount else {
            // Never answered, and at/over threshold → prompt.
            return true
        }
        // Re-qualify only after another full threshold's worth of new events.
        return verdictEventCount - lastCount >= threshold
    }
}
