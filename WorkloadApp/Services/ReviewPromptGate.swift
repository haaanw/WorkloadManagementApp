import Foundation

/// Decides when the App Store review prompt may fire (ASO lane, 2026-08-23: the listing has
/// zero ratings, and at the current organic volume it cannot earn any without asking).
///
/// The prompt is allowed only at the positive moment right after a workout save:
/// - the athlete has a real history (`minimumSessions`), so a first impression is never begged;
/// - the sheet dismissal being reacted to actually FOLLOWED a save (`freshSaveWindowSeconds`,
///   measured against the newest session's `createdAt` — `sessionDate` can be backdated by
///   voice logging), so a cancelled sheet never prompts;
/// - at most once per `cooldownDays` from this gate. Apple additionally caps the system
///   prompt at three per rolling year, and may show nothing at all.
struct ReviewPromptGate {

    static let minimumSessions = 5
    static let cooldownDays = 60
    static let freshSaveWindowSeconds: TimeInterval = 180

    /// UserDefaults key for the last time this gate allowed a prompt.
    static let lastPromptedAtKey = "reviewPrompt.lastRequestedAt"

    static func shouldPrompt(
        completedSessionCount: Int,
        latestSessionCreatedAt: Date?,
        lastPromptedAt: Date?,
        now: Date = .now
    ) -> Bool {
        guard completedSessionCount >= minimumSessions else { return false }

        guard let created = latestSessionCreatedAt else { return false }
        let sinceSave = now.timeIntervalSince(created)
        guard sinceSave >= 0, sinceSave <= freshSaveWindowSeconds else { return false }

        if let last = lastPromptedAt,
           now.timeIntervalSince(last) < TimeInterval(cooldownDays) * 86_400 {
            return false
        }
        return true
    }
}
