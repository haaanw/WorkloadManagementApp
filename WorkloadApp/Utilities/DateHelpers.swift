import Foundation

extension Date {
    /// Start of the current day
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// Check if this date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Check if this date is yesterday
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    /// Days ago from now
    func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: self) ?? self
    }

    /// Short date string (e.g., "May 26" / "5月26日") — locale-aware via injected Locale.
    /// Pass `@Environment(\.locale)` from the calling View.
    func shortString(locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: self)
    }

    /// Relative date string (e.g., "Today", "Yesterday", "May 26") — locale-aware.
    func relativeString(locale: Locale) -> String {
        if isToday {
            return String(localized: "date.today", defaultValue: "Today")
        }
        if isYesterday {
            return String(localized: "date.yesterday", defaultValue: "Yesterday")
        }
        return shortString(locale: locale)
    }

    /// Duration string from seconds (e.g., "1h 23m" / "1小时23分钟") — locale-aware via catalog.
    static func durationString(seconds: Int, locale: Locale) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return String(
                format: String(
                    localized: "duration.hoursMinutes",
                    defaultValue: "%lldh %lldm"
                ),
                locale: locale,
                hours,
                minutes
            )
        }
        return String(
            format: String(
                localized: "duration.minutes",
                defaultValue: "%lldm"
            ),
            locale: locale,
            minutes
        )
    }
}

/// Calendar-day arithmetic against an EXPLICIT time zone (v1.7.2 / audit M6).
///
/// The Postgres `DATE` codec used to hold a cached `DateFormatter` whose `timeZone` was
/// resolved once, at first use. A device that crossed a zone boundary — a flight, a DST
/// shift — kept writing snapshot dates against the stale offset until relaunch, which
/// day-shifts every row it touches. Taking the zone as a parameter makes the dependency
/// visible and testable; production passes `.current` and therefore re-reads it per call.
///
/// The calendar identifier is pinned to Gregorian on purpose: a Buddhist or Japanese
/// locale calendar would put the wrong year number into a wire format.
enum CalendarDay {

    static func calendar(in zone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar
    }

    static func startOfDay(for date: Date, in zone: TimeZone) -> Date {
        calendar(in: zone).startOfDay(for: date)
    }

    /// `yyyy-MM-dd`, built from date components rather than a formatter — no shared
    /// mutable state to race on, and no locale to leak digit shapes into a wire format.
    static func string(from date: Date, in zone: TimeZone) -> String {
        let parts = calendar(in: zone).dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Parses `yyyy-MM-dd` into that day's local midnight. Returns nil on anything else.
    static func date(from raw: String, in zone: TimeZone) -> Date? {
        let fields = raw.split(separator: "-")
        guard fields.count == 3,
              fields[0].count == 4,
              let year = Int(fields[0]),
              let month = Int(fields[1]),
              let day = Int(fields[2]) else { return nil }
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = day
        return calendar(in: zone).date(from: parts)
    }
}
