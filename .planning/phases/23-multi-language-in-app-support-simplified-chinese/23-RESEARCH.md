# Phase 23: Multi-language in-app support (Simplified Chinese) — Research

**Researched:** 2026-05-26
**Domain:** iOS i18n — String Catalogs, live locale switching, CJK font cascade, App Store Connect zh-Hans metadata
**Confidence:** HIGH on infra (String Catalog, env locale, cascadeList, Info.plist localization) — MEDIUM on font byte counts and final glossary wording (translator review required) — LOW on push-notification compose-time guarantee under all iOS versions.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01 / D-02 / D-03 / D-04:** Localize core UI, errors, paywall, legal, push notifications, App Store metadata.
- **D-05:** Dynamic user content (custom exercises, athlete notes, coach comments) NEVER translated — stored as entered, no locale tags, no mismatch warning.
- **D-06 / D-07:** Hybrid format `中文 (ACRONYM)` for technical terms; first occurrence in a screen uses hybrid, later occurrences may drop the acronym if layout demands; educational/glossary copy always hybrid.
- **D-08:** Researcher proposes final Chinese glossary in this RESEARCH.md (terms in D-06 are anchors).
- **D-09 / D-10 / D-11:** Adopt Xcode 15 `Localizable.xcstrings` as single source of truth. `LocalizedStringKey` / `String(localized:)` everywhere. NO `NSLocalizedString`, NO `.strings` files. `AuthError.errorDescription` and enum `displayName` move into the catalog. Pluralization handled by catalog plural variations on the English source; Chinese has no plural form.
- **D-12 / D-13 / D-14:** In-app language picker in Profile + onboarding step. Live switch via `LocaleManager` (Observable) in `AppContainer`, persisted in `UserDefaults`, propagated through `.environment(\.locale, …)` at the root. ANY view reading `Locale.current` directly must switch to the injected environment locale.
- **D-15 / D-16:** First launch silently defaults to system locale. Onboarding includes a language step (per UI-SPEC, step 1 of 4).
- **D-17 / D-18:** Bundle a CJK font shipping Regular (400) + Medium (500) only. Per UI-SPEC, **Noto Sans SC** is selected. Cascade via `UIFontDescriptor.cascadeList`.
- **D-19:** Bundle size budget +8 MB for both CJK weights. Subset before falling back to system PingFang SC.
- **D-20:** Audit dashboard / metric-tile hairline layouts in zh-Hans for CJK density; respect 8pt grid.
- **D-21:** Translation workflow = LLM-drafted, human-reviewed in Xcode String Catalog editor. No automated commits of unreviewed translations.
- **D-22:** Marketing-tone copy (App Store description, onboarding hero, paywall headline) gets a second translator pass for Chinese fitness-culture conventions.

### Claude's Discretion (research scope)
- Choose between Noto Sans SC and Source Han Sans SC → **Noto Sans SC** (confirmed by UI-SPEC).
- Propose canonical Chinese glossary entries → done below (`## Canonical zh-Hans Glossary`).
- Planner decides phase split (infra → catalog migration → translation → font → ASC metadata) vs single phase.

### Deferred Ideas (OUT OF SCOPE)
- Traditional Chinese (zh-Hant), Japanese, Korean, Spanish — separate per-locale phases later.
- Locale tagging on user-entered content with cross-locale display warnings.
- Automated MT of dynamic content (custom exercises, notes).
- RTL language support (Arabic, Hebrew).
- Font subsetting toolchain — only invoked as fallback if Noto Sans SC overshoots +8 MB.
- Alpino font swap from v1.3 backlog — don't bundle two new font families simultaneously.
</user_constraints>

## Project Constraints (from CLAUDE.md)
- iOS 17+ only, SwiftUI + SwiftData. No third-party UI frameworks.
- **0pt border radius everywhere** — use `Rectangle()`, never `RoundedRectangle`.
- **No shadows** — hairline borders only.
- **Accent color appears ONLY on the hero readiness score number.** Never on language picker rows, checkmarks, onboarding chrome.
- **General Sans Regular + Medium only**, via `Font.Tokens.*`. Phase 23 ADDS Noto Sans SC Regular + Medium via cascade — never as a primary face on Latin-only views.
- **All spacing multiples of 8pt.** UI-SPEC introduces zero magic numbers.
- **Both dark and light mode** via `ColorTokens` semantic tokens; never hardcode hex.
- **iOS/Swift verification:** After modifying Swift files, verify `.pbxproj` includes new sources (LocaleManager, LanguagePickerView, Localizable.xcstrings, InfoPlist.xcstrings, NotoSansSC-Regular.otf, NotoSansSC-Medium.otf); SPM dependencies unchanged. Pause to `xcodebuild` every 3-5 file changes (CLAUDE.md "Incremental Build Verification").
- **Never commit RevenueCat keys** (unrelated to this phase but standing rule).
- **HealthKit raw data never leaves device** — `NSHealthShareUsageDescription` zh-Hans copy must say so (UI-SPEC line 291 already drafts it).

## Summary

Greenfield i18n in a 17+ codebase with zero existing `.strings` / `.xcstrings` / `Localizable` artifacts. The phase reduces to six concrete workstreams: (1) bootstrap two String Catalogs — `Localizable.xcstrings` for app strings and `InfoPlist.xcstrings` for the HealthKit consent + display name — and enable Xcode's "Use Compiler to Extract Swift Strings" so future hardcoded `String(localized:)` and `LocalizedStringKey` literals auto-populate the catalog; (2) introduce a `LocaleManager` `@Observable` service in `AppContainer`, drive `.environment(\.locale, …)` at the `AppRouter` root, and refactor `DateHelpers` + `WeightFormatter` to take an injected `Locale` (today they implicitly use `Calendar.current` / `Locale.current`); (3) extend `FontTokens.swift` so every `Font.Tokens.*` token resolves through a `UIFontDescriptor.cascadeList` chain — General Sans primary, Noto Sans SC fallback — yielding seamless mixed-script rendering for `训练负荷比 (ACWR)`; (4) migrate every `displayName` on enums in `Models/Enums.swift` and every `AuthError.errorDescription` to `String(localized:)`; (5) add `CFBundleLocalizations` (`en`, `zh-Hans`), localize `NSHealthShareUsageDescription` through `InfoPlist.xcstrings`, and confirm `CFBundleDevelopmentRegion=en`; (6) add zh-Hans App Store metadata (name 30 / subtitle 30 / keywords 100 / description 4000) and re-render screenshots with `-AppleLanguages "(zh-Hans)"` injected into the existing `SCREENSHOT_MODE` scheme.

**Primary recommendation:** Plan as **5 sub-plans** in this order — (P1) infra (LocaleManager + env locale + Localizable.xcstrings + InfoPlist.xcstrings + Info.plist `CFBundleLocalizations`); (P2) string migration (every Text/Label/button → `String(localized:)`, enum displayNames + AuthError into catalog, formatters take injected locale); (P3) font cascade (bundle Noto Sans SC Regular + Medium, register in Info.plist `UIAppFonts`, rewrite `FontTokens` to cascade descriptors, add launch assertion); (P4) translation pass (LLM-draft zh-Hans values, human review in Xcode catalog editor, density/layout audit per UI-SPEC); (P5) ASC zh-Hans storefront (metadata + zh-Hans screenshots via SCREENSHOT_MODE + `-AppleLanguages`). Plans P1, P2, P3 can land in parallel after the catalog skeleton exists; P4 must wait on P2+P3; P5 must wait on P4 for screenshots.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| String catalog storage | Resources (bundle) | Build system (Xcode catalog → .strings/.stringsdict compile output) | Catalog is a resource consumed by `Bundle.main`; backward-compatible compile output is automatic [CITED: developer.apple.com/videos/play/wwdc2023/10155]. |
| Active locale state | Services / DI (`LocaleManager` in `AppContainer`) | UserDefaults (persistence) | Mirrors the established pattern of `SubscriptionService`, `NotificationService`, `CycleTrackingService` already on `AppContainer`. |
| Environment locale propagation | Views (root injection in `AppRouter`) | SwiftUI runtime (descendant `Text` / `LocalizedStringKey` resolution) | `.environment(\.locale, …)` is the documented SwiftUI mechanism [CITED: developer.apple.com/documentation/swiftui/environmentvalues/locale]. |
| Locale-aware formatting | Utilities (`DateHelpers`, `WeightFormatter`) | Views (pass `@Environment(\.locale)` as parameter) | Pure helpers must NOT read `Locale.current` (D-14); they take a `Locale` argument. |
| CJK font cascade | Utilities (`FontTokens`) | UIKit (`UIFontDescriptor` resolution at draw time) | Single point of font policy already exists; extend in place. |
| Push notification localization | Services (`NotificationService`) | iOS runtime (`localizedUserNotificationString(forKey:)` resolves at deliver time) | Compose-time `String(localized:)` snapshots the locale at scheduling; deliver-time `localizedUserNotificationString` reads device preferred language at fire time — the right choice for repeating triggers [CITED: developer.apple.com/documentation/usernotifications/unmutablenotificationcontent]. |
| HealthKit consent string | Resources (`InfoPlist.xcstrings`) | iOS Settings UI | Apple resolves `NSHealthShareUsageDescription` from the localized InfoPlist before showing the system prompt [CITED: developer.apple.com/documentation/bundleresources/information-property-list/nshealthshareusagedescription]. |
| App Store metadata | App Store Connect (cloud config) | n/a | Lives outside the binary; updated independently of releases [CITED: developer.apple.com/help/app-store-connect/reference/app-information/app-store-localizations/]. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---|---|---|---|
| Xcode String Catalog (`.xcstrings`) | Xcode 15+ (Tonus targets iOS 17+ so safe) | Single-source localized strings + plurals + comments + translation state | Apple's official path since WWDC23; backward-compatible compile output preserves support for any deployment target [CITED: developer.apple.com/videos/play/wwdc2023/10155]. |
| SwiftUI `\.locale` environment | iOS 13+ | Propagate active `Locale` through view tree | Documented entry point for runtime locale override without restart [CITED: developer.apple.com/documentation/swiftui/environmentvalues/locale]. |
| `String(localized:)` / `LocalizedStringKey` | Swift 5.5+ | Mark strings for extraction; resolve via `Bundle.localizedString(forKey:)` at render time | Compiler extraction (the only path the catalog auto-discovers) requires these initializers [CITED: belief-driven-design.com/xcode-string-catalogs-101-672f5/]. |
| `UIFontDescriptor.cascadeList` | iOS 7+ | Glyph-by-glyph fallback to CJK font | Standard CoreText cascade mechanism — single descriptor handles mixed-script strings without per-character splitting [CITED: sarunw.com/posts/how-to-use-different-fonts-for-different-languages-in-ios-application/]. |
| `UNNotificationContent.localizedUserNotificationString` | iOS 10+ | Defer notification string resolution until fire time | Repeating UNCalendarNotificationTrigger fires across days; deliver-time localization matches current iOS Settings language [CITED: useyourloaf.com/blog/local-notifications-with-ios-10/]. |
| `InfoPlist.xcstrings` | Xcode 15+ | Localize `NSHealthShareUsageDescription`, `CFBundleDisplayName`, etc. | Replaces legacy `InfoPlist.strings`; Xcode auto-populates known Info keys [CITED: developer.apple.com/forums/thread/743218]. |

### Supporting
| Library | Version | Purpose | When to Use |
|---|---|---|---|
| Noto Sans SC (Google Fonts SIL OFL) | static OTF Regular + Medium | CJK glyph face for cascade fallback | Bundled OTFs registered in `UIAppFonts` and asserted on launch [CITED: fonts.adobe.com/fonts/noto-sans-sc]. |
| `Locale(identifier:)` | Foundation | Construct `en` and `zh-Hans` locales for LocaleManager | Required to override `\.locale` and to bridge `Bundle` localization lookup. |
| `Bundle.localizedString(forKey:value:table:)` | Foundation | Manual catalog lookup for non-View code paths (e.g., `AuthError.errorDescription` when the throwing context lacks an environment) | Use `String(localized:bundle:locale:)` to read a specific locale rather than the current process locale. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|---|---|---|
| Xcode String Catalog | Legacy `Localizable.strings` + `.stringsdict` | Locked OUT by D-09. Even on the merits, catalog wins: built-in pluralization, comments, state tracking, no key-collision drift. |
| Noto Sans SC | Source Han Sans SC | Same upstream typeface; UI-SPEC picked Noto for cleaner SC-only file packaging and smaller bundle. Final-final decision confirmed: Noto Sans SC. |
| Noto Sans SC | System `PingFang SC` (no bundling) | Avoids the +6.2 MB bundle cost but breaks the General Sans visual contract — system PingFang is a different optical weight + metrics, so mixed-script lines look mismatched. Use only as the documented fallback if subsetting fails to land under +8 MB. |
| `LocaleManager` (custom) | `Bundle.main.setLocalizations` swizzling | Swizzling is fragile, App Store-rejection-prone, and unnecessary when `\.environment(\.locale, …)` works natively in iOS 13+. |
| `.environment(\.locale, …)` | Restart-required language switch (rewrite `AppleLanguages` UserDefault) | Violates D-12 ("live switch, no restart"). |

**Installation:**

Noto Sans SC OTFs are downloaded once from `https://fonts.google.com/noto/specimen/Noto+Sans+SC` (SIL OFL 1.1 license — same redistribution terms as General Sans). No package manager dependency added. Drop into `WorkloadApp/Resources/Fonts/`, add to target, register in Info.plist `UIAppFonts`.

**Version verification:** No Swift packages added. Font files are static binaries — pin the SHA-256 of the OFL license file and each OTF in the plan, verified at install.

## Package Legitimacy Audit

> Not applicable — this phase adds no Swift packages, npm dependencies, or remote services. The two binary additions (`NotoSansSC-Regular.otf`, `NotoSansSC-Medium.otf`) are static font files from Google Fonts under SIL OFL 1.1. Vetting:
>
> - Source: `https://fonts.google.com/noto/specimen/Noto+Sans+SC` (Google-hosted, signed CDN).
> - License: SIL OFL 1.1, identical to General Sans's ITF FFL (both permit embedding + redistribution).
> - No executable content. No network calls. No postinstall hooks (not a package format).
> - Vetting gate: download the OTF + LICENSE, capture SHA-256 of each file in PLAN.md, attach to commit.

## Architecture Patterns

### System Architecture Diagram

```
                          ┌────────────────────────┐
   iOS Settings           │  AppleLanguages        │
   language preference  ──▶  preference (system)   │
                          └───────────┬────────────┘
                                      │ (first launch only — silent default)
                                      ▼
   UserDefaults[          ┌────────────────────────┐
     "selectedLocale"  ◀──┤  LocaleManager         │  @Observable
   ]                      │  .activeLocale: Locale │  in AppContainer
                          │  .setLocale(_:)        │
                          └───────────┬────────────┘
                                      │ publishes
                                      ▼
                          ┌────────────────────────┐
                          │  AppRouter (root view) │
                          │  .environment(\.locale,│
                          │      localeManager     │
                          │        .activeLocale)  │
                          └───────────┬────────────┘
                                      │ propagates via SwiftUI env
                  ┌───────────────────┼────────────────────┐
                  ▼                   ▼                    ▼
         Text("dashboard.    DateHelpers.short      WeightFormatter.
              ready") via   (date, locale: loc)     display(kg, unit,
         LocalizedString-                            locale: loc)
              Key in        (helpers take Locale     (helpers take
         Localizable.        as parameter — no       Locale as parameter)
         xcstrings           Locale.current)
                  │
                  │ Bundle.localizedString lookup,
                  │ resolved per active locale
                  ▼
         ┌─────────────────────────────────────────┐
         │ Rendered Text + DateFormatter + numbers │
         │ ──────────────────────────────────────  │
         │ FontTokens cascade:                     │
         │   primary: General Sans (Latin runs)    │
         │   .cascadeList: Noto Sans SC (CJK runs) │
         │ → seamless "训练负荷比 (ACWR)"          │
         └─────────────────────────────────────────┘

  ── separately ───────────────────────────────────────────────────────
  NotificationService.scheduleWeeklySummary(...)
       │
       └─▶ UNMutableNotificationContent
              .title = .localizedUserNotificationString(forKey: "notif.weekly.title")
              .body  = .localizedUserNotificationString(forKey: "notif.weekly.body",
                                                       arguments: [...])
              → iOS resolves at delivery time, picks user's CURRENT language
                even if it changed since scheduling.

  ── separately ───────────────────────────────────────────────────────
  Info.plist + InfoPlist.xcstrings
       NSHealthShareUsageDescription[en]    "..."
       NSHealthShareUsageDescription[zh-Hans] "Tonus 读取..."
       → iOS Settings + first-time permission prompt resolve from this.

  ── separately ───────────────────────────────────────────────────────
  App Store Connect (cloud, not in binary)
       App Store Localizations → add "Simplified Chinese"
       fields: name(30), subtitle(30), keywords(100), description(4000),
       what's new, promotional text, screenshots per device family.
```

### Recommended Project Structure (additions only)

```
WorkloadApp/
├── App/
│   └── AppContainer.swift           # add `let localeManager: LocaleManager`
├── Services/
│   └── LocaleManager.swift          # NEW — @Observable, UserDefaults-backed
├── Resources/
│   ├── Localizable.xcstrings        # NEW — single string catalog
│   ├── InfoPlist.xcstrings          # NEW — Info.plist localization
│   └── Fonts/
│       ├── NotoSansSC-Regular.otf   # NEW
│       └── NotoSansSC-Medium.otf    # NEW
├── Utilities/
│   ├── FontTokens.swift             # MODIFIED — cascade descriptor
│   ├── DateHelpers.swift            # MODIFIED — takes Locale
│   └── WeightFormatter.swift        # MODIFIED — takes Locale
└── Views/
    ├── Onboarding/OnboardingView.swift            # MODIFIED — +languageStep
    └── Profile/
        ├── ProfileView.swift                       # MODIFIED — +language row
        └── LanguagePickerView.swift                # NEW
workload management/
└── workload-management-Info.plist   # MODIFIED — +CFBundleLocalizations
```

### Pattern 1: `LocaleManager` service

```swift
// Source: synthesizes existing AppContainer pattern + Apple env locale docs.
import SwiftUI

@MainActor
@Observable
final class LocaleManager {
    private let defaultsKey = "selectedLocaleIdentifier"
    private let supported: [Locale] = [
        Locale(identifier: "en"),
        Locale(identifier: "zh-Hans"),
    ]

    private(set) var activeLocale: Locale

    init() {
        if let stored = UserDefaults.standard.string(forKey: defaultsKey) {
            self.activeLocale = Locale(identifier: stored)
        } else {
            // D-15: silent default to system locale.
            // Use Locale.preferredLanguages.first — falls back to en if absent.
            let system = Locale.preferredLanguages.first ?? "en"
            // Match coarse — Locale.preferredLanguages returns BCP-47 ("zh-Hans-US"),
            // collapse to base supported tag.
            let resolved: Locale
            if system.hasPrefix("zh") {
                resolved = Locale(identifier: "zh-Hans")
            } else {
                resolved = Locale(identifier: "en")
            }
            self.activeLocale = resolved
            // NOTE: don't persist on first launch — keep "track-system" semantics
            // until the user actively picks. If you persist immediately, system
            // changes won't propagate. Decision deferred to plan: persist-on-pick
            // is the recommended path (matches UI-SPEC live switch).
        }
    }

    func setLocale(_ locale: Locale) {
        activeLocale = locale
        UserDefaults.standard.set(locale.identifier, forKey: defaultsKey)
    }

    var supportedLocales: [Locale] { supported }
}
```

**Wire-up at root (`AppRouter.body`):**

```swift
// Source: synthesized from SwiftUI env locale docs.
.environment(\.locale, container.localeManager.activeLocale)
.animation(.linear(duration: 0.15), value: container.localeManager.activeLocale)  // UI-SPEC line 172
```

### Pattern 2: Cascading `FontTokens`

```swift
// Source: sarunw.com/posts/how-to-use-different-fonts-for-different-languages-in-ios-application/
// + Apple UIFontDescriptor docs.
import SwiftUI
import UIKit

extension Font {
    enum Tokens {
        static func body() -> Font {
            cascadedFont(generalSans: "GeneralSans-Regular",
                         cjk: "NotoSansSC-Regular",
                         size: 17)
        }
        // ... one per token; keep static lets only if you accept that the
        // cascade is computed once per launch (acceptable — descriptors are
        // immutable). For dynamic-type accessibility, compute per use.
    }

    private static func cascadedFont(generalSans: String, cjk: String, size: CGFloat) -> Font {
        let cjkDescriptor = UIFontDescriptor(fontAttributes: [
            .name: cjk
        ])
        let primary = UIFontDescriptor(name: generalSans, size: size)
            .addingAttributes([
                UIFontDescriptor.AttributeName.cascadeList: [cjkDescriptor]
            ])
        let uiFont = UIFont(descriptor: primary, size: size)
        return Font(uiFont)
    }
}
```

> Cascade-order rule per Sarunw: list smaller-glyph-set fonts first; CoreText walks the cascade until a glyph is found. General Sans (Latin only) → Noto Sans SC (CJK + Latin) is correct.

### Pattern 3: Localized enum `displayName`

```swift
// BEFORE
var displayName: String {
    switch self {
    case .lifting: "Lifting"
    case .running: "Running"
    // ...
    }
}

// AFTER
var displayName: String {
    switch self {
    case .lifting: String(localized: "sport.lifting", defaultValue: "Lifting")
    case .running: String(localized: "sport.running", defaultValue: "Running")
    // ...
    }
}
```

> The compiler extracts every `String(localized:)` call into the catalog automatically when "Use Compiler to Extract Swift Strings" is YES in Build Settings [CITED: belief-driven-design.com/xcode-string-catalogs-101-672f5/]. Stable, namespaced keys (`sport.lifting`) are better than autogenerated keys from raw English when you anticipate copy churn.

### Pattern 4: Push-notification deferred localization

```swift
// BEFORE
content.title = "Your Week in Review"
content.body = body  // body built with locale-aware NotificationService.buildNotificationBody

// AFTER
content.title = .localizedUserNotificationString(
    forKey: "notif.weekly.title",
    arguments: nil
)
content.body = .localizedUserNotificationString(
    forKey: "notif.weekly.body",
    arguments: [sessionCount, streak, prCount, Int(abs(volumeDelta))]
)
```

> `.localizedUserNotificationString(forKey:arguments:)` defers resolution until the system delivers the notification — so a notification scheduled in English fires in Chinese after the user switches the device language [CITED: useyourloaf.com/blog/local-notifications-with-ios-10/]. The arguments slot in via `%@` / `%d` format specifiers in the catalog value.

### Anti-Patterns to Avoid

- **Calling `Locale.current` anywhere in Views, ViewModels, or Utilities** — breaks live switch (D-14). Pass the injected `\.locale` env value as a parameter to any helper that needs it.
- **Building `NSLocalizedString("…", comment:")` calls** — locked out by D-10, but also: the compiler extractor does pick those up, so mixing the two styles will work but produces a noisy catalog with inconsistent key formats. Stick to `String(localized:)`.
- **Setting `AppleLanguages` UserDefault directly** — would change the bundle resolution for the whole process and require a restart. The env-locale path is the documented live-switch mechanism.
- **Bundling the full Noto Sans CJK OTF** — that's ~17 MB per weight; only the SC-subset matters here. Verify file sizes before commit.
- **CJK full-width parens `（ ）` instead of ASCII `( )`** — UI-SPEC line 226 makes this explicit. The cascade renders ASCII parens from General Sans, matching Latin run optical metrics.
- **Truncating localized strings with ellipsis on dashboard / onboarding** — UI-SPEC line 82 forbids. Wrap to a second line and grow the container along the 8pt grid.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| String storage + plural rules | Custom dictionary keyed by locale | `Localizable.xcstrings` | Built-in plural variations, automatic extraction, free state tracking (translated / needs-review), backward-compat compile to .strings [CITED: developer.apple.com/videos/play/wwdc2023/10155]. |
| Live language switching | `Bundle` swizzling / `AppleLanguages` mutation | `\.environment(\.locale, …)` | Apple-blessed path; no restart, no rejection risk [CITED: developer.apple.com/documentation/swiftui/environmentvalues/locale]. |
| Mixed-script font rendering | Per-character `Text` splitting | `UIFontDescriptor.cascadeList` | Single descriptor; CoreText handles glyph routing automatically [CITED: sarunw.com/posts/how-to-use-different-fonts-for-different-languages-in-ios-application/]. |
| Push-notification language | Reschedule on every locale change | `localizedUserNotificationString(forKey:)` | iOS resolves at fire time from device preferred language; survives language changes between scheduling and delivery [CITED: useyourloaf.com/blog/local-notifications-with-ios-10/]. |
| Date formatting per locale | Manual `DateFormatter` per region | `DateFormatter` with `formatter.locale = injectedLocale` + `setLocalizedDateFormatFromTemplate("yMMMd")` | `setLocalizedDateFormatFromTemplate` produces locale-appropriate ordering (en `May 26, 2026` / zh `2026年5月26日`) without hand-rolling per-locale formats. |
| Number / weight formatting | String-format `%.1f` + appended unit | `MeasurementFormatter` with locale OR `NumberFormatter` with locale + localized unit string from catalog | UI-SPEC line 262 already specifies "82.5 公斤" — locale-aware unit + grouping. |

**Key insight:** Tonus already has a single-point-of-config for fonts (`FontTokens.swift`), colors (`ColorTokens`), and DI (`AppContainer`). i18n piggybacks on these patterns — every workstream is one file extended, not a new architecture.

## Runtime State Inventory

> This phase is partial rename/migration of every user-facing string. Audit:

| Category | Items Found | Action Required |
|---|---|---|
| Stored data | None. zh-Hans does NOT change any persisted string. Athlete `displayName`, custom exercise names, template names stay as-entered per D-05. Athlete `sportType` is stored as enum raw (e.g., `lifting`), not as the localized label — safe. | None. |
| Live service config | None. Supabase rows store enum raw values, not localized labels. RevenueCat product titles are read from RC dashboard (not from this codebase); RC dashboard supports per-locale display text and can be updated separately. ASC metadata is live service config and is the work of Plan 5 below. | ASC metadata pass (Plan 5). RC dashboard zh-Hans titles are out of scope unless user opts in. |
| OS-registered state | UNUserNotificationCenter has pending requests with stored content. Existing `weekly-summary` requests scheduled before this phase have hardcoded English title/body. | On first launch after this phase ships, `NotificationService` MUST cancel and reschedule any existing pending notifications so they pick up the new `localizedUserNotificationString` path. |
| Secrets / env vars | None — no key changes. | None. |
| Build artifacts | After registering Noto Sans SC OTFs, prior dSYM / .ipa artifacts are stale but auto-rebuilt. Existing screenshot snapshots (en-only) are stale once new screenshots are taken; CI / Fastlane screenshot output goes to a different path so no manual cleanup. | Re-run screenshot scheme for `en` + `zh-Hans`. |

## Migration Strategy (String Catalog bootstrap)

This is the answer to research question #1.

### Step 1 — Add Localizable.xcstrings to the project

In Xcode: **File → New → File → iOS → Resource → String Catalog**. Name `Localizable.xcstrings`. Save under `WorkloadApp/Resources/`. Add to the `workload management` target. Xcode 15 auto-adds languages as you check them in the catalog editor; start with `en` (development region) and `zh-Hans` (Simplified Chinese).

### Step 2 — Enable compiler extraction

Project → Build Settings → Localization → **Use Compiler to Extract Swift Strings → YES** [CITED: belief-driven-design.com/xcode-string-catalogs-101-672f5/]. This auto-pulls every `String(localized:)`, `LocalizedStringKey(…)`, and `LocalizedStringResource(…)` call into the catalog on each build. Plain string literals are NOT extracted — they must be converted manually (see Step 4).

### Step 3 — Add `CFBundleLocalizations` to Info.plist

```xml
<key>CFBundleDevelopmentRegion</key>
<string>en</string>
<key>CFBundleLocalizations</key>
<array>
    <string>en</string>
    <string>zh-Hans</string>
</array>
```

Without `CFBundleLocalizations`, iOS may pick a different fallback resolution path for some users [CITED: developer.apple.com/forums/thread/684498].

### Step 4 — String migration sweep

Convert every hardcoded string in Views, ViewModels, Services, and the enum `displayName` properties:

| Before | After | Notes |
|---|---|---|
| `Text("Home")` | `Text("tab.home")` | `Text("…")` literal IS a `LocalizedStringKey` initializer — already extractable. Replace with a namespaced key. |
| `Label("Roster", systemImage: …)` | `Label("tab.roster", systemImage: …)` | Same — first arg is `LocalizedStringKey`. |
| `Button("Save")` | `Button("action.save")` | Same. |
| `case .lifting: "Lifting"` | `case .lifting: String(localized: "sport.lifting", defaultValue: "Lifting")` | Compiler extracts. |
| `return "Sign up succeeded but no user was returned…"` (in `AuthError.errorDescription`) | `return String(localized: "auth.error.noUser", defaultValue: "Sign up succeeded but no user was returned. Please try again.")` | Throwing context — `String(localized:)` reads `Bundle.main` with the current locale. To support live switch in error UI, the caller (`LoginView` / `SignUpView`) must re-render after locale change, which env locale already triggers. |
| `formatter.dateFormat = "MMM d"` (DateHelpers) | `formatter.locale = locale; formatter.setLocalizedDateFormatFromTemplate("MMMd")` | Locale comes from the View's injected env value, passed in. |
| `String(format: "%.1f kg", kg)` (WeightFormatter) | `let mf = MeasurementFormatter(); mf.locale = locale; mf.unitStyle = .medium; return mf.string(from: Measurement(value: kg, unit: UnitMass.kilograms))` | Yields `82.5 kg` / `82.5 公斤` per locale. |

### Step 5 — Verify zero remaining hardcoded user-facing strings

```bash
# Find Text(…) / Label(…) / Button(…) / Alert(…) calls with non-key string literals.
# False positives possible — review by hand.
xcrun --find swift   # confirm toolchain
git grep -nE 'Text\("[A-Z][a-z]' WorkloadApp/Views/ WorkloadApp/Components/
git grep -nE 'Button\("[A-Z][a-z]' WorkloadApp/Views/ WorkloadApp/Components/
git grep -nE '\.alert\("[A-Z]' WorkloadApp/Views/
# Find direct returns of English strings from displayName.
git grep -n 'displayName' WorkloadApp/Models/Enums.swift
# Find Locale.current — must be zero in Views/Components/Utilities.
git grep -n 'Locale.current' WorkloadApp/Views/ WorkloadApp/Components/ WorkloadApp/Utilities/
```

After the migration sweep, Xcode opens the catalog editor — the "State" column should show every key as `New` for `zh-Hans`. Translate, mark `Reviewed` (or `Translated`), and Build to regenerate the compile output.

### Step 6 — Test in both locales

Run the scheme with `-AppleLanguages "(zh-Hans)"` and `-AppleLocale "zh_Hans_CN"` launch arguments — full app should render in Chinese. Then live-switch from Profile → Language to verify env-locale propagation.

### Step 7 — InfoPlist.xcstrings

File → New → String Catalog → name `InfoPlist.xcstrings` → add `en` + `zh-Hans`. On next build, Xcode auto-discovers Info.plist localizable keys (`NSHealthShareUsageDescription`, `CFBundleDisplayName`, etc.) and populates them [CITED: developer.apple.com/forums/thread/743218]. Use UI-SPEC line 291 string for `NSHealthShareUsageDescription[zh-Hans]`.

## CJK Font Choice + Cascade

This answers research question #3.

### Decision: Noto Sans SC

**Rationale:**

- Same upstream typeface as Source Han Sans (Adobe + Google co-development). Visual rendering at body sizes is indistinguishable.
- Google Fonts ships Noto Sans SC as a region-specific subset OTF (SC characters only, not the full CJK Unified Ideographs + JP + KR). Source Han Sans SC's "subset OTFs" are an equivalent path but less convenient to obtain.
- File naming: `NotoSansSC-Regular.otf`, `NotoSansSC-Medium.otf` — no SC/TC/JP/KR family-name collision in `UIFont.familyNames` (a real problem with full Source Han Sans bundles).
- License: SIL OFL 1.1 — same redistribution terms as General Sans's ITF FFL [CITED: fonts.adobe.com/fonts/noto-sans-sc].
- Weight axis at 400/500 visually matches General Sans Regular/Medium x-height per UI-SPEC's visual check.

### File-size math

Authoritative file size per weight is best confirmed by downloading the static OTF from Google Fonts directly (`https://fonts.google.com/noto/specimen/Noto+Sans+SC` → "Download family"). The notofonts/noto-cjk README does not publish a size table per weight, only points to subset OTFs as the recommended path [CITED: github.com/notofonts/noto-cjk/blob/main/Sans/README.md]. The UI-SPEC's 6.2 MB estimate (line 37) is consistent with publicly reported Noto Sans SC subset OTF sizes (typically 3.0–3.4 MB per weight static OTF, SC-only subset). **[ASSUMED — confirm exact bytes when downloading.]**

**Verification step before commit:**

```bash
# After downloading, capture exact sizes.
ls -l WorkloadApp/Resources/Fonts/NotoSansSC-Regular.otf WorkloadApp/Resources/Fonts/NotoSansSC-Medium.otf
# Total must be ≤ 8 MB per D-19.
```

**Subset fallback (if overshoot):**

If both OTFs exceed 8 MB combined, use `pyftsubset` (from `fonttools`) to drop ideographs not appearing in `Localizable.xcstrings`:

```bash
# 1. Extract all unique characters from the catalog (zh-Hans values + glossary).
# 2. Build a unicodes file.
# 3. Subset.
pip install fonttools brotli
pyftsubset NotoSansSC-Regular.otf \
    --text-file=catalog-zhhans-chars.txt \
    --output-file=NotoSansSC-Regular-Subset.otf \
    --no-hinting \
    --layout-features=*
```

Expected post-subset: <1 MB per weight if the catalog uses ~2000 unique CJK characters. **[ASSUMED — confirm via experiment if invoked.]**

**System PingFang SC fallback (last resort, per D-19):**

If subsetting fails or is rejected, drop the Noto Sans SC bundle entirely and add `"PingFang SC"` to the cascadeList instead of the bundled font name. Visual contract breaks (PingFang has different optical metrics than General Sans) but the app still renders Chinese correctly.

### Cascade implementation

Per UI-SPEC lines 44–48 — the contract is already specified. The implementation pattern is in `## Architecture Patterns / Pattern 2: Cascading FontTokens` above. Two iOS-specific gotchas:

1. **Font name vs family name** — `UIFontDescriptor(fontAttributes: [.name: …])` takes the PostScript name. Use `[.family: "Noto Sans SC"]` if matching the family across weights, or `[.name: "NotoSansSC-Regular"]` for a specific PostScript name. Verify the actual name via `UIFont.familyNames` and `UIFont.fontNames(forFamilyName:)` at first launch — the `WorkloadApp.swift` assertion already does this for General Sans; add an equivalent assertion for `NotoSansSC-Regular` / `NotoSansSC-Medium`.
2. **Cascade order matters** — list the SMALLER-glyph-set font first (General Sans), CJK font second [CITED: sarunw.com/posts/how-to-use-different-fonts-for-different-languages-in-ios-application/]. CoreText walks the list until it finds a glyph.

### Font registration in Info.plist

```xml
<key>UIAppFonts</key>
<array>
    <string>GeneralSans-Variable.ttf</string>
    <string>NotoSansSC-Regular.otf</string>
    <string>NotoSansSC-Medium.otf</string>
</array>
```

### Launch assertion in `WorkloadApp.swift`

```swift
#if DEBUG
let cjkLoaded = UIFont.familyNames.contains(where: { $0.localizedCaseInsensitiveContains("noto sans sc") })
assert(cjkLoaded, "Noto Sans SC not registered. Add OTFs + UIAppFonts entries.")
#endif
```

## Canonical zh-Hans Glossary

This answers research question #4. **Terms are anchors per D-08 — translator review pass (D-22) confirms final wording.** Sources: Chinese sports-science vocabulary as established in PRC fitness/training literature, cross-checked against Web search [CITED: sports-today.top/article/load-management-2026-data-driven-approach-preventing-overuse-injuries, rundida.com/tools/training-load/].

| English | Recommended hybrid form | Catalog key | Notes |
|---|---|---|---|
| ACWR | 训练负荷比 (ACWR) | `term.acwr` | Standard PRC translation; "训练负荷比" appears in mainland sports-medicine literature [CITED]. |
| HRV | 心率变异性 (HRV) | `term.hrv` | Established in PRC clinical literature. |
| RHR | 静息心率 (RHR) | `term.rhr` | Standard. |
| TSS | 训练压力评分 (TSS) | `term.tss` | Direct from TrainingPeaks PRC distribution. |
| EWMA | 指数加权移动平均 (EWMA) | `term.ewma` | Statistical term, no fitness-specific alternative. |
| CTL | 慢性训练负荷 (CTL) | `term.ctl` | Pairs with ATL. |
| ATL | 急性训练负荷 (ATL) | `term.atl` | Pairs with CTL. |
| sRPE | 主观运动强度 (sRPE) | `term.srpe` | Alternative "主观运动自觉强度" is more technical — pick "强度" form for brevity in UI rows. |
| RPE | 主观运动强度 (RPE) | `term.rpe` | Same root term; UI uses 1–10 scale, no per-screen disambiguation needed beyond first hybrid occurrence. |
| PR (personal record) | 个人最佳 (PR) | `term.pr` | "最佳成绩" is more colloquial; "个人最佳" maps better to "personal best" semantics. |
| VO2 Max | 最大摄氧量 (VO2 Max) | `term.vo2max` | Standard. |
| Recovery score | 恢复评分 | `term.recoveryScore` | NO hybrid — Chinese term is unambiguous; standalone. |
| Readiness | 状态评分 (Readiness) | `term.readiness` | "状态" = state/condition; pair with hybrid first occurrence to disambiguate from "recovery score". Alternative "准备度" reads more clinical. |
| Training load | 训练负荷 | `term.trainingLoad` | Standard. |
| Autoregulation | 自我调节 (Autoregulation) | `term.autoregulation` | "自我调节" is the standard PRC sport-science term. |
| Deload | 减载 / 减量周 | `term.deload` | "减量周" if context is a planned week; "减载" if instantaneous. |
| Taper | 减量期 (Taper) | `term.taper` | Standard PRC distance-running term. |
| Wellness check-in | 状态登记 | `term.wellness` | Direct translation "健康打卡" reads as a fitness-app gimmick — "状态登记" is professional. |
| Streak | 连续 N 周 | `term.streak` | Render as "连续 3 周" rather than a noun "streak"; the streak metric should always be inline with count. |
| Paywall | (no localized term needed — paywall is UI surface) | n/a | The localized strings are paywall headline + CTA, not the word "paywall". |
| Athlete | 运动员 | `term.athlete` | Standard. |
| Coach | 教练 | `term.coach` | Standard. |
| Session | 训练课 / 一次训练 | `term.session` | "训练课" for scheduled session; "一次训练" for ad-hoc. UI prefers "训练课". |
| Set | 组 | `term.set` | Standard. |
| Rep | 次 | `term.rep` | Standard. |
| **Sport types** | | | |
| Lifting | 力量训练 | `sport.lifting` | Standard PRC fitness term. |
| Running | 跑步 | `sport.running` | Standard. |
| Cycling | 骑行 | `sport.cycling` | "自行车" is more formal; "骑行" reads better in fitness UI. |
| Swimming | 游泳 | `sport.swimming` | Standard. |
| Team sport | 团队运动 | `sport.teamSport` | Standard. |
| CrossFit | CrossFit / 综合体能 | `sport.crossfit` | Keep brand "CrossFit" as Latin (trademark); subtitle row optional "综合体能". |
| Mixed / Custom | 自定义 | `sport.custom` | Standard. |
| **Zone labels** | | | |
| Optimal | 适宜 | `zone.optimal` | UI-SPEC line 78 anchor. |
| Caution | 注意 | `zone.caution` | UI-SPEC anchor. |
| High Risk / High Load | 高风险 | `zone.danger` | UI-SPEC anchor. |
| Low / Undertrained | 偏低 | `zone.low` | UI-SPEC anchor. |
| **Recovery zones** | | | |
| Rest / Light Only (red) | 休息 / 仅轻量 | `recoveryZone.red` | |
| Cautious (yellow) | 谨慎进行 | `recoveryZone.yellow` | |
| Go (green) | 正常训练 | `recoveryZone.green` | |
| **Cycle phases** | | | |
| Early follicular | 卵泡早期 | `cyclePhase.earlyFollicular` | Standard clinical term. |
| Late follicular | 卵泡晚期 | `cyclePhase.lateFollicular` | |
| Ovulatory | 排卵期 | `cyclePhase.ovulatory` | |
| Early luteal | 黄体早期 | `cyclePhase.earlyLuteal` | |
| Late luteal | 黄体晚期 | `cyclePhase.lateLuteal` | |
| **Frequency** | | | |
| 1-2 days/week | 每周 1-2 天 | `frequency.oneToTwo` | |
| 3-4 days/week | 每周 3-4 天 | `frequency.threeToFour` | |
| 5-6 days/week | 每周 5-6 天 | `frequency.fiveToSix` | |
| 7+ days/week | 每周 7 天以上 | `frequency.sevenPlus` | |
| **Experience** | | | |
| Beginner | 初学者 | `experience.beginner` | |
| Intermediate | 进阶 | `experience.intermediate` | |
| Advanced | 高阶 | `experience.advanced` | |

**Pattern note:** UI-SPEC line 226 mandates ASCII space + ASCII parentheses for hybrid forms — the catalog values MUST use `U+0020` space and `U+0028 U+0029` parens. Do not paste from Chinese IMEs that auto-substitute full-width punctuation. Add a CI lint:

```bash
# zh-Hans values must not contain CJK full-width parens.
grep -nP '（|）|　' WorkloadApp/Resources/Localizable.xcstrings && exit 1 || exit 0
```

## App Store Connect zh-Hans Metadata

This answers research question #5.

### Adding the localization

From memory snapshot `reference_asc_navigation.md` and Apple's docs [CITED: developer.apple.com/help/app-store-connect/manage-app-information/localize-app-information/]:

1. Log in to App Store Connect → My Apps → Tuwa (com.tonus.app).
2. Sidebar → **App Information** → Localizable Information section → click the **language dropdown** at the top → **+ Add Language** → select **Simplified Chinese (zh-Hans)**.
3. ASC creates a new localized form with empty fields for: Name, Subtitle, Privacy Policy URL, Category-specific descriptions.
4. Sidebar → **App Store** → (current version, e.g., v1.4) → language dropdown → **+ Add Language** → **Simplified Chinese**. New form fields: Promotional Text, Description, Keywords, Support URL, Marketing URL, What's New in This Version, App Previews and Screenshots.
5. Fill, save. The zh-Hans storefront takes effect at the next version submission (or immediately for non-version fields like Description on already-released versions, depending on metadata-only vs binary release).

**ASC caution from memory `feedback_asc_caution.md`:** never click submission / "Submit for Review" / "Release" buttons without user confirmation. Plan tasks must explicitly stop at "metadata entered, awaiting user confirmation".

### Character limits (all enforced, all locales)

[CITED: developer.apple.com/help/app-store-connect/reference/app-store-localizations/]

| Field | Limit | Notes |
|---|---|---|
| App Name | 30 chars | Counts Chinese chars as 1 each. Recommended: keep brand "Tonus" + descriptor → e.g., `Tonus · 训练负荷管理` (12 chars). |
| Subtitle | 30 chars | E.g., `恢复 × 训练负荷 智能管理` (14 chars). |
| Promotional Text | 170 chars | Editable without re-review. |
| Description | 4000 chars | Re-review on edit. |
| Keywords | 100 chars (comma-separated) | Mainland-specific: `训练负荷,恢复评分,HRV,心率变异性,ACWR,运动表现,过度训练,周期化,跑步,力量训练`. Note: zh-Hans keywords work on the zh-Hans storefront (China mainland + global users with zh-Hans locale). |
| What's New in This Version | 4000 chars | Per release. |
| Support URL | 255 chars | Reuse existing. |
| Marketing URL | 255 chars | Reuse existing. |

### Screenshot device families

Tonus targets iPhone (iOS 17+). Apple requires screenshots for at least one of the following display sizes; uploading the largest covers the smaller via scaling:

| Display size | Device | Pixel size (portrait) | Required? |
|---|---|---|---|
| 6.9" Display | iPhone 17 Pro Max | 1320 × 2868 | Required (largest) |
| 6.5"–6.7" Display | iPhone 15/16 Pro Max | 1290 × 2796 | Optional (scales from 6.9") |
| 6.1" Display | iPhone 15/16 (non-Pro) | 1179 × 2556 | Optional |

The existing screenshot scheme already renders at iPhone 17 Pro Max simulator — same scheme works for zh-Hans, just pass the locale launch arguments.

### Integrating with SCREENSHOT_MODE

Existing scheme uses `SCREENSHOT_MODE` to bypass auth + seed mock data [code: `AppRouter.swift:90`]. To render zh-Hans screenshots:

1. Duplicate the screenshot scheme → name e.g., `Screenshots-zhHans`.
2. Edit Scheme → Run → Arguments → Arguments Passed On Launch:
   ```
   SCREENSHOT_MODE
   -AppleLanguages
   (zh-Hans)
   -AppleLocale
   zh_Hans_CN
   ```
3. The `-AppleLanguages "(zh-Hans)"` arg overrides `Bundle` localization resolution for the process [CITED: developer.apple.com/documentation/foundation/bundle].
4. Inside `AppRouter.task`, when `SCREENSHOT_MODE` is set, also call `container.localeManager.setLocale(Locale(identifier: "zh-Hans"))` if `AppleLanguages` contains "zh-Hans" — otherwise the env-locale path still reads the user-default `en`. (Belt-and-braces: both `Bundle` resolution AND env-locale resolution see Chinese.)
5. Run UI test → output xcresult → extract via `xcparse` → upload to ASC.

## HealthKit + Info.plist Localization

This answers research question #6.

### Mechanism

`NSHealthShareUsageDescription` lives in `workload-management-Info.plist`. To localize:

1. Add `InfoPlist.xcstrings` (see Migration Step 7 above).
2. After next build, Xcode auto-populates the key based on Info.plist contents [CITED: developer.apple.com/forums/thread/743218].
3. Fill `zh-Hans` value. UI-SPEC line 291 already drafts: `Tonus 读取您的心率、心率变异性和睡眠数据，用于计算每日恢复评分。这些原始数据不会离开您的设备。`
4. Build. iOS Settings → Tonus → Health permission view should now show zh-Hans copy when device language is Chinese.

### Apple review requirements

[CITED: developer.apple.com/documentation/bundleresources/information-property-list/nshealthshareusagedescription]

Apple HIG + App Review Guideline 5.1.1 require the consent string to:

- **Clearly explain** which data types are read.
- **State the purpose** the data is used for.
- **NOT be empty or generic.**
- Be **localized for every supported language**. Apps that ship a `zh-Hans` localization but leave `NSHealthShareUsageDescription` English-only are at higher review-rejection risk.

The UI-SPEC draft satisfies all three: names the data types (心率、心率变异性、睡眠数据), states purpose (用于计算每日恢复评分), and adds the "on-device only" privacy assurance which the existing English string also makes (per CLAUDE.md HealthKit constraint). **Confirm with translator review (D-22) — phrasing is acceptable but a native zh-Hans reviewer should sanity-check tone.**

### Other localizable Info.plist keys

In addition to `NSHealthShareUsageDescription`, the catalog should cover:

- `CFBundleDisplayName` — if Tonus wants the home-screen label in Chinese for zh-Hans users (recommendation: keep `Tonus` Latin; brand should not localize).
- Any future `NSCameraUsageDescription`, `NSLocationWhenInUseUsageDescription`, etc. — not in scope today but the InfoPlist.xcstrings is ready when they're added.

## Push Notification Localization

This answers research question #7.

### Mechanism

For `NotificationService.scheduleWeeklySummary`:

- **Use `.localizedUserNotificationString(forKey:arguments:)`** for both `content.title` and `content.body` [CITED: useyourloaf.com/blog/local-notifications-with-ios-10/].
- iOS resolves the catalog lookup at **delivery time** against the device's current preferred language (from `AppleLanguages`).
- This is critical for `UNCalendarNotificationTrigger(dateMatching:, repeats: true)` — the request is registered once and fires weekly. If the user changes their device language between scheduling and a Sunday 19:00 delivery, the notification fires in the new language without rescheduling.

### Gotcha: in-app live switch vs device language

There's a deliberate mismatch: the in-app language picker writes to `LocaleManager` + UserDefaults + `\.environment(\.locale)`, but `.localizedUserNotificationString` reads the **device** preferred language (iOS Settings → General → Language & Region), not the in-app override. **This is correct behavior for Tonus's UX:** notifications are surfaced by iOS, often outside the app, in a language the user expects from iOS itself.

If the product later requires notifications to track in-app language even when iOS language differs, the path is to schedule with `String(localized: "…", locale: container.localeManager.activeLocale)` at compose time — but then locale changes between scheduling and delivery are lost. Tonus default = device-language is the right call.

### Format-argument plumbing

`buildNotificationBody` currently builds the localized string in Swift. After this phase, it should NOT — the catalog values should carry the format pattern with `%d` / `%@` placeholders:

```jsonc
// Localizable.xcstrings excerpt
{
  "notif.weekly.body.template": {
    "extractionState": "manual",
    "localizations": {
      "en": { "stringUnit": { "value": "%lld sessions logged — %lld week streak. %lld new PRs!" } },
      "zh-Hans": { "stringUnit": { "value": "本周记录 %lld 次训练 — 已连续 %lld 周。新增 %lld 项个人最佳！" } }
    }
  }
}
```

Compose:

```swift
content.body = .localizedUserNotificationString(
    forKey: "notif.weekly.body.template",
    arguments: [sessionCount, streak, prCount]
)
```

Plural variations (English needs them; Chinese doesn't) go in the catalog's plural editor — Xcode catalog UI exposes the `%lld` rule selector.

### Pre-existing notification cleanup

Per Runtime State Inventory above — on first launch after Phase 23 ships, `NotificationService` must:

```swift
center.removePendingNotificationRequests(withIdentifiers: ["weekly-summary"])
// Reschedule with the new localized keys.
```

Implementation: track a `notificationSchemaVersion` int in UserDefaults; if stored version < new version, cancel + reschedule.

## Validation Architecture (per phase requirements; nyquist_validation is OFF in config)

The project disables `nyquist_validation` (`.planning/config.json` line 19). Per RESEARCH.md template, the formal "Validation Architecture" section is omitted. However, the user research-questions list (#8) explicitly asks for a validation enumeration. Providing it as an informal section:

### Build-time validation
- `xcodebuild -scheme "Tonus" -destination "platform=iOS Simulator,name=iPhone 17 Pro Max" build` — must succeed (existing CLAUDE.md "Incremental Build Verification" rule, run every 3-5 files modified).
- `#if DEBUG` font-registration assertions in `WorkloadApp.swift` — extend to assert Noto Sans SC presence (see Cascade → Launch assertion above).
- String Catalog state — all keys for `zh-Hans` must be in `Translated` or `Reviewed` state before merge. Catalog editor surfaces "Stale" / "New" indicators when source English changes; CI lint:
  ```bash
  # Fail build if any zh-Hans value is missing or still in "new" state.
  jq -r '.strings | to_entries[] | select(.value.localizations."zh-Hans".stringUnit.state == "new" or .value.localizations."zh-Hans" == null) | .key' \
      WorkloadApp/Resources/Localizable.xcstrings
  ```

### UI snapshot validation (manual + screenshot)
- Run screenshot scheme in `en` and `zh-Hans` locales (existing iPhone 17 Pro Max simulator).
- Visual acceptance checklist from UI-SPEC §"Visual Acceptance Checklist" (lines 340–354) — every box must check.
- Specifically watch for:
  - MetricTile labels wrapping vs truncating (UI-SPEC line 75 — wrap permitted, truncate forbidden).
  - ZoneBadge horizontal padding adjusted to 16pt in zh-Hans (line 78).
  - micro labels lack `.textCase(.uppercase)` + tracking in zh-Hans (line 93, 96).
  - Live switch crossfade 150ms from Profile → Language → tap "中文(简体)" (line 172).

### Character-limit checks on ASC strings
- Plan task to assert ASC field lengths before the user enters them:
  ```bash
  # Run on the source values stored in /docs or wherever the planner pins them.
  python -c "import sys; v=sys.argv[1]; print(len(v), 'OVER' if len(v) > int(sys.argv[2]) else 'ok')" "$NAME" 30
  python -c "..." "$SUBTITLE" 30
  python -c "..." "$KEYWORDS" 100
  python -c "..." "$DESCRIPTION" 4000
  ```

### Hybrid-terminology lint
- Catalog values for zh-Hans MUST use ASCII parens U+0028/U+0029 and ASCII space U+0020:
  ```bash
  python3 -c "
  import json
  d = json.load(open('WorkloadApp/Resources/Localizable.xcstrings'))
  for k, v in d['strings'].items():
      val = v.get('localizations', {}).get('zh-Hans', {}).get('stringUnit', {}).get('value', '')
      if '（' in val or '）' in val or '　' in val:
          print(f'BAD PUNCT: {k} = {val}'); sys.exit(1)
  "
  ```

### `Locale.current` lint
- Forbidden in Views/Components/Utilities (D-14):
  ```bash
  matches=$(git grep -lE 'Locale\.current' WorkloadApp/Views WorkloadApp/Components WorkloadApp/Utilities)
  [ -z "$matches" ] || { echo "$matches"; exit 1; }
  ```

### Push notification smoke test
- Schedule weekly summary in iOS Simulator with device language `en`; advance simulator clock to fire time; verify English copy.
- Repeat with device language `zh-Hans` → verify Chinese copy on the SAME pending request without re-scheduling.

## Common Pitfalls

### Pitfall 1: Auto-extraction silently misses string-interpolated keys
**What goes wrong:** `String(localized: "session.\(type)")` — compiler extraction does NOT pick up dynamically-built keys.
**Why it happens:** The extractor needs a literal string at the call site.
**How to avoid:** Use enum-resolved keys: `String(localized: type.localizationKey)` where `localizationKey` returns a `LocalizedStringResource` with a literal table+key. Or use a switch over the enum that produces the literal `String(localized: "session.strength")` per case.
**Warning signs:** Catalog editor shows fewer keys than expected after a Build.

### Pitfall 2: env-locale propagation skips DateFormatter / NumberFormatter
**What goes wrong:** A View calls `DateHelpers.shortString(date)` (helper reads `Locale.current` implicitly via `Calendar.current`). Live switch updates `\.environment(\.locale)` for `Text` rendering but the helper output is still in the old locale.
**Why it happens:** Pure helpers in `DateHelpers.swift` and `WeightFormatter.swift` don't see env values — they're not Views.
**How to avoid:** Refactor every helper to take `Locale` as a parameter. The View call site passes `@Environment(\.locale)`. D-14 is explicit about this.
**Warning signs:** Live switch updates labels but leaves dates / weights in English format.

### Pitfall 3: Cascade font name mismatch
**What goes wrong:** Cascade descriptor uses `[.name: "Noto Sans SC"]` (family name, not PostScript name). On some iOS versions the descriptor fails silently and CoreText falls back to system PingFang — visually similar but optical metrics differ.
**Why it happens:** UIKit conflates `.name` (PostScript) and `.family`; passing the wrong key to the wrong attribute can fail without throwing.
**How to avoid:** At launch, log `UIFont.fontNames(forFamilyName: "Noto Sans SC")` once in DEBUG, copy the exact PostScript name into the cascade descriptor. Use `[.name: "NotoSansSC-Regular"]` (PostScript) NOT `[.name: "Noto Sans SC"]` (family).
**Warning signs:** Chinese characters render in a font that doesn't match the General Sans weight when compared side-by-side.

### Pitfall 4: Charts framework using its own locale
**What goes wrong:** Apple's Charts framework (used in `WorkloadView.swift`) auto-formats axis labels via its own locale-sensitive logic. Without explicit configuration, axis date labels may stay in English even after live switch.
**Why it happens:** Charts uses `Locale.current` for default `AxisValueLabel` formatting unless overridden.
**How to avoid:** Pass `@Environment(\.locale)` to chart label closures: `AxisValueLabel { Text(dateValue, format: .dateTime.month(.abbreviated).day().locale(injectedLocale)) }`.
**Warning signs:** Workload chart's month abbreviations stay "May" / "Jun" in zh-Hans live switch.

### Pitfall 5: ASC zh-Hans storefront indexes Chinese keywords only on China-region store
**What goes wrong:** Adding zh-Hans keywords doesn't help discoverability on the US App Store for users whose device is set to Chinese.
**Why it happens:** ASC keyword indexing is per-storefront, not per-localization. Users on the China storefront see zh-Hans keywords; users on the US storefront with Chinese device language still hit US (English) keyword index.
**How to avoid:** Accept the tradeoff. Tonus's primary market entry is China storefront; secondary discoverability via cross-localization (Apple translates select localized metadata across storefronts under "App Store Cross-Localization") [CITED: apptweak.com/en/aso-blog/how-to-benefit-from-cross-localization-on-the-app-store].
**Warning signs:** zh-Hans keywords look strong but install attribution from US store doesn't reflect them.

### Pitfall 6: HealthKit re-prompts in wrong locale
**What goes wrong:** Existing users granted HealthKit permission in English. Switching to zh-Hans and re-requesting auth shows English consent string instead of Chinese.
**Why it happens:** iOS caches the consent screen against the device's language at first prompt. Adding zh-Hans to `InfoPlist.xcstrings` only affects future first-time prompts on devices in zh-Hans.
**How to avoid:** Document this in the v1.4 release notes — existing users will see Chinese consent only if they revoke and re-grant from Settings, OR if iOS re-prompts (rare, only on permission expansion).
**Warning signs:** Beta testers report English HealthKit prompt despite zh-Hans device language. (Not a bug if they had pre-granted permission.)

### Pitfall 7: `String(localized:)` in throwing context locks to scheduling locale
**What goes wrong:** `AuthError.errorDescription` uses `String(localized: "auth.error.noUser")`. The string resolves at throw time using `Bundle.main.localizations` — which honors `AppleLanguages` but NOT the in-app `\.environment(\.locale)`.
**Why it happens:** `String(localized:)` without an explicit `locale:` argument reads the bundle's current localization, which is `AppleLanguages[0]`, not the env locale.
**How to avoid:** When live switch is required for error UI — and per D-14 it IS — pass an explicit locale: `String(localized: "auth.error.noUser", locale: container.localeManager.activeLocale)`. This requires error-producing services to take the LocaleManager (or the active locale) as input. For `AuthError`, simpler: render error in the View by reading `@Environment(\.locale)` and calling `String(localized: error.localizationKey, locale: env.locale)`.
**Warning signs:** Live-switching from English to Chinese while a login error is on-screen leaves the error text in English.

## Code Examples

### Live locale switch from Profile picker

```swift
// LanguagePickerView.swift — synthesized from UI-SPEC §"Surface 1" + LocaleManager pattern.
import SwiftUI

struct LanguagePickerView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
            ForEach(container.localeManager.supportedLocales, id: \.identifier) { locale in
                Button {
                    container.localeManager.setLocale(locale)
                    // Do NOT dismiss — UI-SPEC line 173 forbids auto-pop.
                } label: {
                    HStack(spacing: 0) {
                        // Leading 24pt gutter for checkmark
                        ZStack {
                            if locale == container.localeManager.activeLocale {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12))
                                    .foregroundStyle(ColorTokens.text1)
                            }
                        }
                        .frame(width: 24)
                        Text(autonym(for: locale))
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 56)
                }
                .buttonStyle(.plain)
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
            }
            Spacer().frame(height: 64)  // 2xl
            Text("language.picker.footer")
                .font(.Tokens.smallLabel)
                .foregroundStyle(ColorTokens.text2)
                .padding(.horizontal, 16)
            Spacer()
        }
        .navigationTitle("language.picker.title")
        .navigationBarTitleDisplayMode(.inline)
        .background(ColorTokens.background)
    }

    private func autonym(for locale: Locale) -> String {
        switch locale.identifier {
        case "en": "English"
        case "zh-Hans": "中文(简体)"
        default: locale.identifier
        }
    }
}
```

### Locale-aware DateHelpers

```swift
// DateHelpers.swift — refactored.
import Foundation

extension Date {
    func shortString(locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: self)
    }

    func relativeString(locale: Locale) -> String {
        let cal = Calendar(identifier: .gregorian)
        if cal.isDateInToday(self) {
            return String(localized: "date.today", locale: locale)
        }
        if cal.isDateInYesterday(self) {
            return String(localized: "date.yesterday", locale: locale)
        }
        return shortString(locale: locale)
    }

    static func durationString(seconds: Int, locale: Locale) -> String {
        let formatter = DateComponentsFormatter()
        formatter.calendar = Calendar.autoupdatingCurrent
        formatter.unitsStyle = .abbreviated  // "7h 24m" → for zh: Apple resolves "7小时24分钟" automatically
        formatter.allowedUnits = [.hour, .minute]
        formatter.calendar?.locale = locale
        return formatter.string(from: TimeInterval(seconds)) ?? "0m"
    }
}
```

### Caller passes env locale

```swift
// Any View
@Environment(\.locale) private var locale

var body: some View {
    Text(session.date.shortString(locale: locale))
        .font(.Tokens.smallLabel)
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| `Localizable.strings` + `Localizable.stringsdict` per language | `Localizable.xcstrings` (single catalog file) | WWDC23 / Xcode 15 [CITED: developer.apple.com/videos/play/wwdc2023/10155] | One file vs N. Built-in plural editor. Auto-extraction from `String(localized:)`. Backward-compatible: compiled output still emits .strings/.stringsdict so any deployment target works. |
| `NSLocalizedString("key", comment: "…")` | `String(localized: "key", defaultValue: "…", comment: "…")` | Swift 5.5 / iOS 15 | Type-safe extraction; reads default from source rather than from a stripped comment. |
| Manual `[NSLocalizedString …]` in `errorDescription` | `String(localized:)` in throwing context | Swift 5.7+ | Same call site, integrates with catalog auto-extraction. |
| Restart-required language switch | `\.environment(\.locale, …)` live switch | iOS 13 (mechanism exists); broader adoption from iOS 15 onward | No restart, propagates through SwiftUI tree, picks up `Text(_:LocalizedStringKey)` immediately. |
| Manual font selection per locale (`if isChinese { use PingFang } else { use Latin }`) | `UIFontDescriptor.cascadeList` | iOS 7+ (longstanding) — but underused | Single font descriptor; glyph routing automatic; mixed-script strings render correctly without splitting. |
| `InfoPlist.strings` legacy file | `InfoPlist.xcstrings` | Xcode 15+ | Auto-discovery of known Info keys; same backward-compat compile [CITED: developer.apple.com/forums/thread/743218]. |

**Deprecated/outdated:**
- `NSLocalizedString` — still functions but discouraged for greenfield catalogs.
- `.strings` / `.stringsdict` direct authoring — write to catalog, let Xcode emit them.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | Noto Sans SC static OTF Regular + Medium combined ≤ 8 MB (UI-SPEC estimate ~6.2 MB) | CJK Font / File-size math | Bundle bloat violates D-19; triggers subsetting fallback work. Verifiable in 5 minutes — confirm exact byte count when downloading from Google Fonts. |
| A2 | `pyftsubset` of Noto Sans SC against the ~2000 unique CJK chars in our catalog yields <1 MB per weight | CJK Font / Subset fallback | Subset toolchain proves more complex than anticipated; ship with system PingFang fallback instead. |
| A3 | Glossary terms in the canonical table (e.g., `适宜 / 注意 / 高风险 / 偏低` for zones, `状态评分` for readiness) are idiomatic mainland Chinese fitness vocabulary | Glossary | Translator review (D-22) catches; non-blocking — terms are anchors, not final per D-08. |
| A4 | Existing pending `weekly-summary` notifications scheduled with hardcoded English content cannot be retroactively localized — they must be cancelled and rescheduled | Push Notification Localization | If wrong (i.e., iOS does swap them transparently), the cancel/reschedule logic is just extra work, not a bug. |
| A5 | `Locale.preferredLanguages.first.hasPrefix("zh")` is a sufficient first-launch detection for zh-Hans default | LocaleManager init | A user with iOS set to zh-Hant would be defaulted to our zh-Hans — wrong but recoverable via picker. Refinement: check for "zh-Hans" / "zh-CN" / "zh-Hant" prefixes separately and only default to zh-Hans for the first two; zh-Hant should default to en until Traditional Chinese ships. |
| A6 | The user's existing screenshot scheme uses `xcparse` to extract artifacts from xcresult bundles (per STACK.md) | ASC Screenshot integration | If xcparse is not actually wired, planner adds the install step. STACK.md lists it as "optional". |
| A7 | App Store Connect navigation matches `reference_asc_navigation.md` memory snapshot from 2026-04 | ASC zh-Hans Metadata | ASC UI changes occasionally; confirm with user before clicking through. Per `feedback_asc_caution.md`, the user runs ASC actions interactively anyway. |
| A8 | Charts framework axis labels respect the locale set on the formatter, not `Locale.current`, when explicit `.locale(injectedLocale)` is passed | Pitfall 4 | If Charts ignores the explicit locale on iOS 17, axis labels stay en after live switch — a known historical Apple bug. Workaround: force-rebuild the Chart on locale change via `.id(locale)`. |
| A9 | `setLocalizedDateFormatFromTemplate("MMMd")` produces "5月26日" in zh-Hans and "May 26" in en | DateHelpers refactor | Confirmable via NSDateFormatter docs; widely relied upon. If wrong, fall back to explicit per-locale format dictionaries. |

## Open Questions (RESOLVED)

1. **Should the App Store name change from "Tonus" to a hybrid like "Tonus · 训练负荷管理" for zh-Hans?** *(DEFERRED to user decision at Plan 23-05 Task 3.)*
   - What we know: ASC allows per-localization App Name; many global brands keep Latin brand + add a Chinese descriptor for discoverability on the China storefront.
   - What's unclear: User's brand-equity preference (memory `project_rename_faros.md` is emphatic that the official name is "Tonus" — does that brand purity extend to refusing a Chinese descriptor?).
   - Recommendation: Default to keeping `Tonus` Latin only; add Chinese descriptor in Subtitle (`恢复 × 训练负荷 智能管理`) instead. Confirm with user during translation review pass.

2. **Does Tonus need a zh-Hant phase before launching zh-Hans in mainland China?** *(RESOLVED — zh-Hant deferred per CONTEXT.md Deferred Ideas.)*
   - What we know: zh-Hans and zh-Hant are linguistically distinct; users in Hong Kong, Taiwan, Macau prefer zh-Hant. Mainland and Singapore use zh-Hans.
   - What's unclear: Whether the launch market includes HK/TW or is mainland-only.
   - Recommendation: Out of scope per CONTEXT.md Deferred Ideas. Confirm market scope is mainland-only for this phase.

3. **Are RevenueCat product display names ("Athlete Pro", "Coach") localized in the RC dashboard?** *(DEFERRED — RevenueCat dashboard zh-Hans product titles out of scope for Phase 23; tracked as follow-up.)*
   - What we know: RC supports per-locale display titles for products via the RC dashboard; the iOS SDK reads them based on device locale.
   - What's unclear: Whether the user has already set zh-Hans titles in RC.
   - Recommendation: Plan task to verify in RC dashboard; if missing, the paywall (`UpgradeSheet`) will show English product names even after this phase. Out of scope to set them in this phase, but a `checkpoint:human-verify` task should call this out.

4. **Should the language picker show language names in the active locale or the autonym?** *(RESOLVED — UI-SPEC locks autonym rendering.)*
   - What we know: UI-SPEC line 286 is explicit — "autonyms always render in their own script". So "English" (when active is zh-Hans) and "中文" (when active is en) — never "英语" or "Chinese (Simplified)".
   - What's unclear: Nothing — UI-SPEC is locked.
   - Recommendation: Honor UI-SPEC verbatim.

5. **Does the existing Onboarding flow's step count infrastructure handle 4-step layout cleanly, or does the dot-indicator component need extension?** *(RESOLVED — handled in Plan 23-01 Task 3 (OnboardingView dot indicator parameterization).)*
   - What we know: Existing OnboardingView is 3 steps. UI-SPEC line 184 calls for 4. The dot indicator is a private component inside OnboardingView (per file structure).
   - What's unclear: Whether the indicator is parameterized over step count or hardcoded.
   - Recommendation: Planner task to inspect `OnboardingView.swift` and either parameterize the indicator or extend it. Likely a 2-line change.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---|---|---|
| Xcode 15+ | String Catalog format | Assumed ✓ | Latest | None — catalog format requires 15+. (iOS 17+ target → developer must be on Xcode 15+ already.) |
| Noto Sans SC (downloadable) | CJK font cascade | ✓ via Google Fonts | latest | Source Han Sans SC (functionally identical); last resort: system PingFang SC |
| `pyftsubset` (fonttools) | Optional subsetting if Noto > 8 MB | not installed by default | latest pip | Skip subsetting; ship at original size or fall back to PingFang |
| `xcparse` CLI | Extract screenshots from xcresult bundles | Assumed ✓ per STACK.md | latest | Manual screenshot via Xcode + simulator |
| iPhone 17 Pro Max simulator | Screenshot device family | ✓ per STACK.md | Xcode-bundled | iPhone 16 Pro Max (smaller display class, requires re-render at different resolution) |
| App Store Connect (cloud) | Add zh-Hans localization, upload screenshots, set metadata | ✓ (user-managed) | n/a | None |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** `pyftsubset` — only required IF Noto Sans SC overshoots +8 MB budget AND user opts not to use PingFang SC fallback.

## Security Domain

Phase 23 introduces minimal new attack surface. Brief ASVS scan:

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | no | (no auth changes) |
| V3 Session Management | no | (no session changes) |
| V4 Access Control | no | (no permission changes) |
| V5 Input Validation | yes — minimal | UserDefaults locale identifier read by `LocaleManager.init` — validate against `supportedLocales` whitelist before applying. Otherwise a malformed UserDefaults value (e.g., via debug tooling) could pin the app to an unsupported locale. |
| V6 Cryptography | no | (no crypto) |
| Threat: User-content cross-localization leak | no | D-05 forbids translating user content — coach comments / athlete notes / custom exercise names sync as-entered. No locale mixing of user content. |
| Threat: Catalog injection via dynamic key construction | yes — small | Avoid `String(localized: "session.\(userInput)")`. Catalog keys must be literal — no user-supplied input concatenated into a localization key. |

**Privacy:** No new PII collected. The selected language identifier in UserDefaults is local-only (not synced to Supabase, not sent to RevenueCat). HealthKit consent string remains compliant — UI-SPEC zh-Hans draft restates the "data does not leave device" privacy guarantee in Chinese, matching the English version.

## Sources

### Primary (HIGH confidence)
- Apple — Discover String Catalogs (WWDC23): https://developer.apple.com/videos/play/wwdc2023/10155
- Apple — `\.locale` environment value (SwiftUI): https://developer.apple.com/documentation/swiftui/environmentvalues/locale
- Apple — `UNMutableNotificationContent` reference: https://developer.apple.com/documentation/usernotifications/unmutablenotificationcontent
- Apple — `NSHealthShareUsageDescription` reference: https://developer.apple.com/documentation/bundleresources/information-property-list/nshealthshareusagedescription
- Apple — App Store localizations (ASC): https://developer.apple.com/help/app-store-connect/reference/app-store-localizations/
- Apple — Localize app information (ASC): https://developer.apple.com/help/app-store-connect/manage-app-information/localize-app-information/
- Project — `DESIGN.md`, `CLAUDE.md`, `23-CONTEXT.md`, `23-UI-SPEC.md` (locked decisions + visual contract)
- Codebase — `WorkloadApp/App/AppContainer.swift`, `AppRouter.swift`, `WorkloadApp.swift`, `Utilities/FontTokens.swift`, `DateHelpers.swift`, `WeightFormatter.swift`, `Services/AuthService.swift`, `NotificationService.swift`, `Models/Enums.swift`, `Views/Profile/ProfileView.swift`, `workload management/workload-management-Info.plist`

### Secondary (MEDIUM confidence — verified against Apple docs)
- belief-driven-design.com — Xcode String Catalogs 101: https://belief-driven-design.com/xcode-string-catalogs-101-672f5/
- fline.dev — The Missing String Catalogs FAQ for Localization in Xcode 15: https://www.fline.dev/the-missing-string-catalogs-faq-for-xcode-15/
- Sarunw — How to use different fonts for different languages: https://sarunw.com/posts/how-to-use-different-fonts-for-different-languages-in-ios-application/
- Use Your Loaf — Local Notifications with iOS 10: https://useyourloaf.com/blog/local-notifications-with-ios-10/
- Apple Developer Forums — How to localise Permissions Usage descriptions: https://developer.apple.com/forums/thread/743218
- appcoda — In-App Language Switch in iOS with SwiftUI: https://www.appcoda.com/swiftui-language-switch/
- Apptweak — App Store cross-localization: https://www.apptweak.com/en/aso-blog/how-to-benefit-from-cross-localization-on-the-app-store
- 9to5Mac — App Store Connect adds 11 languages for localized app metadata: https://9to5mac.com/2026/03/31/app-store-connect-adds-11-new-languages-for-localized-app-metadata/
- Adobe Fonts — Noto Sans SC: https://fonts.adobe.com/fonts/noto-sans-sc
- notofonts/noto-cjk README: https://github.com/notofonts/noto-cjk/blob/main/Sans/README.md

### Tertiary (LOW confidence — confirm by hand)
- Chinese sports-science terminology references (mainland fitness terminology): https://sports-today.top/article/load-management-2026-data-driven-approach-preventing-overuse-injuries, https://rundida.com/tools/training-load/ — used to verify glossary anchors but final wording requires native translator review (D-22).

## Metadata

**Confidence breakdown:**
- String Catalog migration: HIGH — Apple WWDC + multiple corroborating sources, codebase confirmed greenfield (zero pre-existing localization files).
- Live env locale switch + LocaleManager: HIGH — documented SwiftUI mechanism, fits existing `AppContainer` pattern verbatim.
- Cascade font choice (Noto Sans SC): HIGH on mechanism, MEDIUM on exact file byte count (verifiable by download).
- Push-notification deferred localization: MEDIUM — `localizedUserNotificationString` is documented and proven, but iOS behavior across `UNCalendarNotificationTrigger` + repeating + language change should be smoke-tested on simulator before treating as guaranteed.
- Canonical glossary: MEDIUM — anchors are sound mainland terminology but D-22 review pass is the gating step.
- ASC zh-Hans metadata flow: MEDIUM — memory snapshot from April 2026 is recent but ASC UI evolves; reconfirm during execution.

**Research date:** 2026-05-26
**Valid until:** 2026-06-25 (30 days for stable infra; Apple may ship Xcode 16+ catalog refinements but the migration path is stable)
