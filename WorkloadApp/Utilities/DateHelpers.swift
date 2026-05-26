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
