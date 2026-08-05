import Foundation

/// One relative-time renderer for every "N ago" stamp in the app.
///
/// **Why this exists (v1.7.1).** `RelativeDateTimeFormatter` rounds an interval to its
/// largest unit and only then chooses tense, so anything under half a second is phrased in
/// the FUTURE: a row that just synced read "in 0 sec", and a template card saved a moment
/// ago read "Last used in 0 seconds". Three call sites had three copies of the same bug.
///
/// The floor is on `abs(interval)`, not the signed value: a timestamp slightly in the
/// future — clock skew, a server stamp written ahead — is also "just now" rather than a
/// nonsense forward count. Genuinely future dates beyond the floor still render as future,
/// which is correct for anything scheduled.
///
/// `now` is injected so the behaviour is unit-testable at −60 / 0 / +60 seconds.
enum RelativeTimeStamp {

    /// Interval (seconds) inside which a stamp reads as "just now" in either direction.
    static let justNowFloorSeconds: TimeInterval = 60

    /// Localized relative stamp, floored to "just now" near the present.
    ///
    /// - Parameter date: the instant being described.
    /// - Parameter now: reference instant (inject in tests; pass the TimelineView tick in views).
    /// - Parameter locale: the app's pinned locale — `String(localized:)` reads the PROCESS
    ///   locale and would keep the launch language through an in-app language switch.
    static func string(for date: Date, now: Date = .now, locale: Locale) -> String {
        if abs(now.timeIntervalSince(date)) < justNowFloorSeconds {
            return LocalePinnedStrings.localized("time.justNow", locale: locale)
        }
        return formatter.localizedString(for: date, relativeTo: now)
    }

    /// True when the stamp would render as "just now" — for call sites that need the
    /// decision rather than the string.
    static func isJustNow(_ date: Date, now: Date = .now) -> Bool {
        abs(now.timeIntervalSince(date)) < justNowFloorSeconds
    }

    private static let formatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()
}
