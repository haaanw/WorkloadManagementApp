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
        if let stored = UserDefaults.standard.string(forKey: defaultsKey) {
            if whitelist.contains(stored) {
                self.activeLocale = Locale(identifier: stored)
                return
            }
            // Invalid stored value (e.g. rolled-back locale from a future build):
            // clear it proactively so the picker shows a clean state next pass.
            #if DEBUG
            print("LocaleManager: dropping invalid stored locale identifier \"\(stored)\" (not in whitelist)")
            #endif
            UserDefaults.standard.removeObject(forKey: defaultsKey)
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
    ///
    /// Accepts both exact-identifier matches and language-code/script normalized
    /// matches (e.g. `Locale(identifier: "zh-Hans_US")` resolves to "zh-Hans"),
    /// so deep-link handlers and screenshot-mode callers can pass loosely-formed
    /// locales without falling through to no-op.
    func setLocale(_ locale: Locale) {
        // 1. Exact-identifier fast path (picker passes one of supportedLocales).
        if let match = supported.first(where: { $0.identifier == locale.identifier }) {
            activeLocale = match
            UserDefaults.standard.set(match.identifier, forKey: defaultsKey)
            return
        }
        // 2. Language-code + script normalization (handles zh-Hans_CN, zh-Hans_US, etc).
        let lang = locale.language.languageCode?.identifier
        let script = locale.language.script?.identifier
        if lang == "zh" && script == "Hans" {
            if let match = supported.first(where: { $0.identifier == "zh-Hans" }) {
                activeLocale = match
                UserDefaults.standard.set(match.identifier, forKey: defaultsKey)
                return
            }
        }
        if lang == "en" {
            if let match = supported.first(where: { $0.identifier == "en" }) {
                activeLocale = match
                UserDefaults.standard.set(match.identifier, forKey: defaultsKey)
                return
            }
        }
        // Unsupported locale: silently ignore.
    }
}
