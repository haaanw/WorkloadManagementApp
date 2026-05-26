import Foundation
import SwiftUI

/// Owns the user-selected app language. Live-switches via `.environment(\.locale, ...)`
/// injected at the root of AppRouter. Persists user pick in UserDefaults; on first
/// launch silently follows system locale (no persistence until user explicitly picks).
///
/// Whitelists UserDefaults reads against `supportedLocales` (T-23-01 mitigation).
@MainActor
@Observable
final class LocaleManager {

    private let defaultsKey = "selectedLocaleIdentifier"

    /// Locales the app ships with. Order matters for the picker UI.
    private let supported: [Locale] = [
        Locale(identifier: "en"),
        Locale(identifier: "zh-Hans")
    ]

    /// The currently active locale. Drives `.environment(\.locale, …)` at app root.
    private(set) var activeLocale: Locale

    var supportedLocales: [Locale] { supported }

    init() {
        let whitelist = supported.map(\.identifier)
        if let stored = UserDefaults.standard.string(forKey: defaultsKey),
           whitelist.contains(stored) {
            self.activeLocale = Locale(identifier: stored)
            return
        }
        // First launch (or invalid stored value): silently follow system locale.
        // Per RESEARCH A5: "zh-Hans" / "zh-CN" → zh-Hans; everything else → en (incl. zh-Hant).
        let pref = Locale.preferredLanguages.first ?? "en"
        if pref.hasPrefix("zh-Hans") || pref.hasPrefix("zh-CN") {
            self.activeLocale = Locale(identifier: "zh-Hans")
        } else {
            self.activeLocale = Locale(identifier: "en")
        }
        // Do NOT persist on first-launch system default — only on explicit user pick.
    }

    /// Persist and apply a user-selected locale. Triggers `@Observable` re-render
    /// at every observer of `activeLocale`, including the root env-locale injection.
    func setLocale(_ locale: Locale) {
        guard supported.map(\.identifier).contains(locale.identifier) else { return }
        activeLocale = locale
        UserDefaults.standard.set(locale.identifier, forKey: defaultsKey)
    }
}
