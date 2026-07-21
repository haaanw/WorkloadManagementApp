import Foundation

/// Locale-pinned localization helpers for copy rendered in an explicitly chosen locale
/// (alert/view-state text built off the main rendering path, zh-Hans paywall variants,
/// previews). Formerly `UIKitStrings` in the retired UIKit shell's primitives; promoted
/// to a shared utility when the shell was deleted (v1.6 launch cleanup, 2026-07-21).
enum LocalePinnedStrings {
    static func localized(_ key: String.LocalizationValue, locale: Locale) -> String {
        var resource = LocalizedStringResource(key)
        resource.locale = locale
        return String(localized: resource)
    }

    static func localized(
        _ key: StaticString,
        defaultValue: String.LocalizationValue,
        locale: Locale
    ) -> String {
        String(localized: key, defaultValue: defaultValue, locale: locale)
    }
}
