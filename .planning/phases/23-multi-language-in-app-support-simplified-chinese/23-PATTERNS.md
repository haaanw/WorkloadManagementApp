# Phase 23: Multi-language in-app support (Simplified Chinese) — Pattern Map

**Mapped:** 2026-05-26
**Files analyzed:** 13 new/modified files
**Analogs found:** 13 / 13

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `WorkloadApp/Services/LocaleManager.swift` (NEW) | service (@Observable) | event-driven / pub-sub | `WorkloadApp/Services/SubscriptionService.swift` | exact (Observable @MainActor service in AppContainer with UserDefaults persistence) |
| `WorkloadApp/App/AppContainer.swift` (MOD) | DI container | wiring | self (existing `subscriptionService`, `notificationService` lines) | exact |
| `WorkloadApp/App/AppRouter.swift` (MOD) | root view / router | request-response | self (existing `.environment(container)` line 37) | exact |
| `WorkloadApp/App/WorkloadApp.swift` (MOD) | app entry point | startup assertion | self (lines 11-15 General Sans assertion) | exact |
| `WorkloadApp/Utilities/FontTokens.swift` (MOD) | utility (typography) | transform / config | self (existing 7 `Font.custom` tokens) | exact |
| `WorkloadApp/Utilities/DateHelpers.swift` (MOD) | utility (formatter) | transform | self (existing `shortString`/`relativeString` lines 25-36) | exact |
| `WorkloadApp/Utilities/WeightFormatter.swift` (MOD) | utility (formatter) | transform | self (existing `display(_:unit:)` lines 9-16) | exact |
| `WorkloadApp/Views/Profile/ProfileView.swift` (MOD) | view | request-response | self (existing `editablePicker("Weight Unit", …)` line 156-159) | exact |
| `WorkloadApp/Views/Profile/LanguagePickerView.swift` (NEW) | view | request-response | `WorkloadApp/Views/Onboarding/OnboardingView.swift` (selection-row pattern lines 102-138) | role-match (selection list with checkmark) |
| `WorkloadApp/Views/Onboarding/OnboardingView.swift` (MOD) | view | request-response | self (existing `frequencyStep` / `experienceStep` private vars) | exact |
| `WorkloadApp/Models/Enums.swift` (MOD) | model | transform | self (15 `displayName` properties, lines 16/45/66/79/105…) | exact |
| `WorkloadApp/Services/AuthService.swift` (MOD) | service | error | self (`AuthError.errorDescription` lines 116-127) | exact |
| `WorkloadApp/Services/NotificationService.swift` (MOD) | service | event-driven | self (existing `scheduleWeeklySummary` lines 32-55) | exact |
| `WorkloadApp/Components/MetricTile.swift` + `ZoneBadge` (MOD) | component | render | self (lines 10-33 and 38-54) | exact |
| `WorkloadApp/Resources/Localizable.xcstrings` (NEW) | resource | static | none in repo (greenfield) | none |
| `WorkloadApp/Resources/InfoPlist.xcstrings` (NEW) | resource | static | none in repo (greenfield) | none |
| `WorkloadApp/Resources/Fonts/NotoSansSC-{Regular,Medium}.otf` (NEW) | resource | static binary | `WorkloadApp/Resources/Fonts/GeneralSans-Variable.ttf` (existing) | exact |
| `workload management/workload-management-Info.plist` (MOD) | config | static | self (lines 28-31 `UIAppFonts`) | exact |

---

## Pattern Assignments

### `Services/LocaleManager.swift` (service, @Observable @MainActor)

**Analog:** `WorkloadApp/Services/SubscriptionService.swift` (lines 1-31) + AppContainer pattern.

**Class-shape pattern** (SubscriptionService.swift lines 1-19):
```swift
import Foundation
import RevenueCat   // → replace with `import SwiftUI`

@MainActor
@Observable
final class SubscriptionService {
    private(set) var isPro: Bool = false
    private(set) var isCoach: Bool = false
    private var isConfigured = false

    init() {
        // …configure, then refreshEntitlement()
    }
}
```

LocaleManager mirrors this shape exactly: `@MainActor @Observable final class`, exposes a `private(set) var activeLocale: Locale`, has an `init()` that reads UserDefaults and falls back to `Locale.preferredLanguages.first`, and exposes `func setLocale(_:)` that writes UserDefaults — same pattern as `AppContainer.setMode(_:)` below.

**UserDefaults read+write pattern** (AppContainer.swift lines 20-28):
```swift
var currentMode: AppMode = {
    let stored = UserDefaults.standard.string(forKey: "appMode") ?? AppMode.athlete.rawValue
    return AppMode(rawValue: stored) ?? .athlete
}()

func setMode(_ mode: AppMode) {
    currentMode = mode
    UserDefaults.standard.set(mode.rawValue, forKey: "appMode")
}
```

Apply verbatim with key `"selectedLocaleIdentifier"`. **Do NOT persist on the first-launch system-default** — only on user pick (per RESEARCH.md line 241-244).

---

### `App/AppContainer.swift` (DI container)

**Self-analog** for service registration (lines 10-15 + lines 30-55):
```swift
let subscriptionService: SubscriptionService
let supabase: SupabaseClient
let authService: AuthService
let healthKitService: HealthKitService
let syncService: SyncService
let notificationService: NotificationService
let cycleTrackingService: CycleTrackingService
// → ADD: let localeManager: LocaleManager

init() {
    self.subscriptionService = SubscriptionService()
    // …
    self.notificationService = NotificationService()
    self.cycleTrackingService = CycleTrackingService()
    // → ADD: self.localeManager = LocaleManager()
}
```

Single-line insert above the `Task { … authStateChanges … }` block at line 59. No init ordering dependencies — `LocaleManager.init()` has no cross-service references.

---

### `App/AppRouter.swift` (root view)

**Self-analog** for environment injection (line 37):
```swift
.environment(container)
```

**Add right below:**
```swift
.environment(\.locale, container.localeManager.activeLocale)
.animation(.linear(duration: 0.15), value: container.localeManager.activeLocale)
```

The 150ms linear duration is the UI-SPEC line 172 contract — DESIGN.md "state change" motion duration.

**SCREENSHOT_MODE awareness** (lines 88-114): The `task` block already special-cases SCREENSHOT_MODE. Add a `setLocale(Locale(identifier: "zh-Hans"))` call inside that block when `ProcessInfo.processInfo.arguments.contains("-AppleLanguages")` is true AND the value matches `zh-Hans` — belt-and-braces with Bundle resolution (RESEARCH.md lines 642-647).

---

### `App/WorkloadApp.swift` (app entry point)

**Self-analog font assertion** (lines 10-15):
```swift
#if DEBUG
assert(
    UIFont.familyNames.contains(where: { $0.localizedCaseInsensitiveContains("general") }),
    "General Sans font not found. Add GeneralSans-Variable.ttf to the project and UIAppFonts in Info.plist."
)
#endif
```

**Add a second assertion below** for Noto Sans SC:
```swift
#if DEBUG
assert(
    UIFont.familyNames.contains(where: { $0.localizedCaseInsensitiveContains("noto sans sc") }),
    "Noto Sans SC not registered. Add NotoSansSC-Regular.otf + NotoSansSC-Medium.otf and UIAppFonts entries."
)
#endif
```

---

### `Utilities/FontTokens.swift` (typography)

**Self-analog** (lines 11-48): Every token is `Font.custom("General Sans", size: N).weight(.regular|.medium)`. The cascade rewrite per UI-SPEC lines 43-48 + RESEARCH.md Pattern 2 (lines 273-296) replaces each `Font.custom(...)` call with a helper that builds a `UIFontDescriptor` cascade:

```swift
private static func cascaded(size: CGFloat, weight: UIFont.Weight) -> Font {
    let cjk = UIFontDescriptor(fontAttributes: [.family: "Noto Sans SC"])
        .addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]])
    let primary = UIFontDescriptor(name: weight == .medium ? "GeneralSans-Medium" : "GeneralSans-Regular",
                                   size: size)
        .addingAttributes([UIFontDescriptor.AttributeName.cascadeList: [cjk]])
    return Font(UIFont(descriptor: primary, size: size))
}
```

Each existing token (`heroScore`, `pageTitle`, `sectionHead`, `body`, `bodyMedium`, `label`, `labelMedium`, `smallLabel`, `smallLabelMedium`, `micro`) becomes a call to `cascaded(size: N, weight: .regular|.medium)`. Token names and sizes are unchanged — every call site in the app continues to read `.font(.Tokens.body)`.

**zh-Hans body line-height override** (UI-SPEC lines 92-96): line-height 1.7 in zh-Hans vs 1.6 in en. Locale-conditional — the planner decides whether this lives in a `Locale`-parameterized helper or is applied at call sites via a `.lineSpacing(…)` modifier wrapped by an env-locale check.

---

### `Utilities/DateHelpers.swift` (formatter)

**Self-analog before** (lines 25-36):
```swift
var shortString: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d"
    return formatter.string(from: self)
}

var relativeString: String {
    if isToday { return "Today" }
    if isYesterday { return "Yesterday" }
    return shortString
}
```

**After (Locale-injected, per CONTEXT D-14):**
```swift
func shortString(locale: Locale) -> String {
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.setLocalizedDateFormatFromTemplate("MMMd")  // en "May 26" / zh "5月26日"
    return formatter.string(from: self)
}

func relativeString(locale: Locale) -> String {
    if isToday { return String(localized: "date.today", defaultValue: "Today") }
    if isYesterday { return String(localized: "date.yesterday", defaultValue: "Yesterday") }
    return shortString(locale: locale)
}
```

Note: every call site now passes the injected `@Environment(\.locale)` value. Planner must inventory call sites (`git grep -n "\.shortString\|\.relativeString" WorkloadApp/`) and update them all in P2.

**Calendar usage in `startOfDay` / `isToday` / `isYesterday`** (lines 4-17): these read `Calendar.current` — `Calendar.current` already respects user locale but is process-wide, not env-locale. For Phase 23 the planner should leave these alone (correctness comes from `Locale.current` already reading the user's iOS region, and `Calendar.current` is correct for week/day boundary math). If live switch must also flip calendar week-start, add a `calendar:` parameter — but `zh-Hans` and `en-US` both use Gregorian, so this is deferred unless QA finds a bug.

**Duration string** (lines 38-46): `"1h 23m"` is hardcoded; per UI-SPEC line 266 zh-Hans must read `"7小时24分钟"`. Migrate to `String(localized: "duration.hoursMinutes", defaultValue: "%lldh %lldm")` with a zh-Hans value template.

---

### `Utilities/WeightFormatter.swift` (formatter)

**Self-analog before** (lines 9-16):
```swift
static func display(_ kg: Double, unit: WeightUnit) -> String {
    switch unit {
    case .kg:
        return String(format: "%.1f kg", kg)
    case .lbs:
        return String(format: "%.1f lbs", kg * kgToLbs)
    }
}
```

**After (Locale-injected; UI-SPEC line 262 contract — `"82.5 公斤"`):**
```swift
static func display(_ kg: Double, unit: WeightUnit, locale: Locale) -> String {
    let measurement: Measurement<UnitMass>
    switch unit {
    case .kg:  measurement = Measurement(value: kg, unit: .kilograms)
    case .lbs: measurement = Measurement(value: kg, unit: .pounds)
    }
    let mf = MeasurementFormatter()
    mf.locale = locale
    mf.unitStyle = .medium
    mf.numberFormatter.maximumFractionDigits = 1
    mf.numberFormatter.minimumFractionDigits = 1
    return mf.string(from: measurement)
}
```

Same pattern for `displayVolume` (lines 35-42). `toKg(_:from:)` and `displayValue(_:unit:)` (lines 19-32) need no locale.

---

### `Views/Profile/ProfileView.swift` (add Language row)

**Self-analog** (lines 155-159) — the "Weight Unit" picker row:
```swift
sectionHeader("PREFERENCES")
editablePicker("Weight Unit", selection: Binding(
    get: { athlete.weightUnit },
    set: { athlete.weightUnit = $0; saveAthlete(athlete) }
), options: WeightUnit.allCases) { $0.displayName }
```

Per UI-SPEC line 134 the new language row is a **`NavigationLink` push row**, not `editablePicker`. Use the existing `NavigationLink` rows at ProfileView lines 272 / 297 as the analog (planner read those before writing). Structure:

```swift
NavigationLink {
    LanguagePickerView()
} label: {
    HStack {
        Text("profile.language.label")  // LocalizedStringKey
            .font(.Tokens.body)
            .foregroundStyle(ColorTokens.text1)
        Spacer()
        Text(container.localeManager.activeLocale.identifier == "zh-Hans" ? "中文" : "English")
            .font(.Tokens.body)
            .foregroundStyle(ColorTokens.text2)
        Image(systemName: "chevron.right")
            .font(.Tokens.smallLabel)
            .foregroundStyle(ColorTokens.text3)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 16)
}
```

Place **above** the "Weight Unit" picker (line 156) inside `sectionHeader("PREFERENCES")`. UI-SPEC line 134 places it in an "App Settings" section, but ProfileView currently uses `"PREFERENCES"` — planner reconciles: rename section header to `"App Settings"` localized key OR keep `"PREFERENCES"` and place the Language row there. Use `"PREFERENCES"` (lower-risk; minimal scope creep).

---

### `Views/Profile/LanguagePickerView.swift` (NEW)

**Closest analog** for selection rows: OnboardingView.swift lines 102-138 (the `experienceStep` `Button` pattern) and OnboardingView.swift lines 48-92 (`frequencyStep` button pattern). Adapt as a `List`-less `VStack` of rows with leading checkmark glyph per UI-SPEC lines 152-167:

```swift
struct LanguagePickerView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
            ForEach(container.localeManager.supportedLocales, id: \.identifier) { locale in
                row(for: locale)
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
            }
            Spacer().frame(height: 64)
            Text("language.picker.footer")
                .font(.Tokens.smallLabel)
                .foregroundStyle(ColorTokens.text2)
                .padding(.horizontal, 16)
            Spacer()
        }
        .background(ColorTokens.background)
        .navigationTitle("language.picker.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(for locale: Locale) -> some View {
        Button {
            container.localeManager.setLocale(locale)
        } label: {
            HStack {
                Image(systemName: container.localeManager.activeLocale.identifier == locale.identifier
                      ? "checkmark" : "")
                    .frame(width: 24)
                    .foregroundStyle(ColorTokens.text1)
                Text(autonym(for: locale))
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text1)
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
        }
    }

    private func autonym(for locale: Locale) -> String {
        switch locale.identifier {
        case "zh-Hans": return "中文(简体)"
        default:        return "English"
        }
    }
}
```

**Design constraints (DESIGN.md / UI-SPEC §Color):** checkmark glyph uses `text1`, NEVER accent color. Background is `Rectangle()`, never `RoundedRectangle`. No shadows.

---

### `Views/Onboarding/OnboardingView.swift` (insert `languageStep`)

**Self-analog** for an onboarding step (lines 48-92 `frequencyStep`, lines 96-143 `experienceStep`):

The new `languageStep` is **step 0** (insert before `frequencyStep`). Required edits:

1. `@State private var currentStep = 0` (line 13) — start at 0 unchanged; the new step becomes index 0, frequency → 1, experience → 2, healthKit → 3.
2. Body ZStack (lines 21-28) — add `languageStep.opacity(currentStep == 0 ? 1 : 0)` and shift the other three opacity bindings up by one.
3. `currentStep < 2` (line 36) → `currentStep < 3` so Continue stays visible through frequency + experience but hides on the HealthKit step (which has its own Connect/Skip buttons).
4. Dot indicators (line 241) — `index == currentStep` for `index in 0..<4` (was `0..<3`).
5. `switch currentStep` (line 270) — extend with case 0 handling Continue.
6. New private var:
```swift
private var languageStep: some View {
    VStack(alignment: .leading, spacing: 0) {
        stepHeader(
            title: "onboarding.language.title",
            subtitle: "onboarding.language.subtitle"
        )
        VStack(spacing: 0) {
            Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
            ForEach(container.localeManager.supportedLocales, id: \.identifier) { locale in
                // Same row component as LanguagePickerView; extract to a private helper.
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 32)
        Spacer()
    }
}
```

**Continue button label is locale-specific** per UI-SPEC line 215 — "Continue to Setup" / "继续设置" only on step 0; subsequent steps keep the single-verb "Continue" / "继续". Planner: parameterize `continueButton` by `currentStep` or expose a computed label.

---

### `Models/Enums.swift` (localize 15 `displayName` properties)

**Self-analog before** (lines 16-26 SportType):
```swift
var displayName: String {
    switch self {
    case .lifting: "Lifting"
    case .running: "Running"
    case .cycling: "Cycling"
    case .teamSport: "Team Sport"
    case .crossfit: "CrossFit"
    case .swimming: "Swimming"
    case .custom: "Custom"
    }
}
```

**After** (RESEARCH.md Pattern 3 lines 313-321):
```swift
var displayName: String {
    switch self {
    case .lifting:   String(localized: "sport.lifting",   defaultValue: "Lifting")
    case .running:   String(localized: "sport.running",   defaultValue: "Running")
    case .cycling:   String(localized: "sport.cycling",   defaultValue: "Cycling")
    case .teamSport: String(localized: "sport.teamSport", defaultValue: "Team Sport")
    case .crossfit:  String(localized: "sport.crossfit",  defaultValue: "CrossFit")
    case .swimming:  String(localized: "sport.swimming",  defaultValue: "Swimming")
    case .custom:    String(localized: "sport.custom",    defaultValue: "Custom")
    }
}
```

Apply uniformly across all 15 `displayName` properties (Enums.swift lines 16, 45, 66, 79, 105, 139, 180, 199, 224, 271, 289, 310, 327, 358, 390). Key namespace from RESEARCH.md glossary: `sport.*`, `weightUnit.*`, `acwrMethod.*`, `loadSource.*`, `zone.*`, `recoveryZone.*`, `frequency.*`, `experience.*`, `cyclePhase.*`. `defaultValue:` parameter is mandatory — provides the en source for catalog extraction.

**Caveat:** `WeightUnit.displayName` returns `"kg"` / `"lbs"`. UI-SPEC line 262 says zh-Hans uses `公斤` inside the formatted measurement (handled by `MeasurementFormatter`), not via this enum's displayName. Keep en values `"kg"` / `"lbs"` if the enum value is shown standalone (e.g., picker rows in en) — but in zh-Hans the catalog renders `公斤` / `磅`. Plan accordingly.

---

### `Services/AuthService.swift` (`AuthError.errorDescription`)

**Self-analog before** (lines 116-127):
```swift
enum AuthError: LocalizedError {
    case noUserReturned
    case noIdentityToken
    case socialSignInFailed(String)
    var errorDescription: String? {
        switch self {
        case .noUserReturned: return "Sign up succeeded but no user was returned. Please try again."
        case .noIdentityToken: return "Apple sign in failed. Could not retrieve identity token."
        case .socialSignInFailed(let message): return message
        }
    }
}
```

**After:**
```swift
var errorDescription: String? {
    switch self {
    case .noUserReturned:
        return String(localized: "auth.error.noUserReturned",
                      defaultValue: "Sign up succeeded but no user was returned. Please try again.")
    case .noIdentityToken:
        return String(localized: "auth.error.noIdentityToken",
                      defaultValue: "Apple sign in failed. Could not retrieve identity token.")
    case .socialSignInFailed(let message):
        return message   // server-side string, not localizable here
    }
}
```

Same approach for any other throwing service that surfaces a user-visible message. Throwing context reads `Bundle.main` with the current process locale — for true live switch, the caller (`LoginView`/`SignUpView`) must re-render its alert when locale changes, which `.environment(\.locale, …)` already triggers.

---

### `Services/NotificationService.swift` (deferred-localization compose)

**Self-analog before** (lines 32-55):
```swift
func scheduleWeeklySummary(weekday: Int, hour: Int, minute: Int, body: String) {
    cancelWeeklySummary()
    let content = UNMutableNotificationContent()
    content.title = "Your Week in Review"
    content.body = body
    content.sound = .default
    // …
}
```

**After** (RESEARCH.md Pattern 4 lines 331-341):
```swift
func scheduleWeeklySummary(weekday: Int, hour: Int, minute: Int,
                            sessionCount: Int, streak: Int, prCount: Int, volumeDelta: Double) {
    cancelWeeklySummary()
    let content = UNMutableNotificationContent()
    content.title = .localizedUserNotificationString(
        forKey: "notif.weekly.title",
        arguments: nil
    )
    content.body = .localizedUserNotificationString(
        forKey: "notif.weekly.body.template",
        arguments: [sessionCount, streak, prCount, Int(abs(volumeDelta))]
    )
    content.sound = .default
    // …
}
```

Catalog value (zh-Hans):
```
"notif.weekly.body.template" → "本周记录 %lld 次训练 — 已连续 %lld 周。新增 %lld 项个人最佳！"
```

`buildNotificationBody(sessionCount:streak:prCount:volumeDelta:)` (lines 66-90) — REMOVE or repurpose. Composition now happens at compose-time inside `scheduleWeeklySummary` via `arguments:`; English plural variations live in the catalog's plural editor.

**Migration of existing pending requests** (RESEARCH.md line 375): on first launch after Phase 23 ships, NotificationService must cancel and reschedule any pending `weekly-summary` request to pick up the new deferred-localization path. Implementation: call `cancelWeeklySummary()` then reschedule (if notifications still enabled per `@AppStorage`).

---

### `Components/MetricTile.swift` + `ZoneBadge` (zh-Hans density audit)

**Self-analog `MetricTile`** (lines 10-33): existing layout uses `.padding(.horizontal, 16) .padding(.vertical, 16)` with a `.frame(maxWidth: .infinity, alignment: .leading)`. Per UI-SPEC line 75, the label MAY wrap to 2 lines in zh-Hans; tile height must remain 8pt-aligned. No code change required IF the existing layout allows multi-line — verify by inspection: `Text(title).font(.Tokens.micro)` has no `.lineLimit(1)` modifier currently, so multi-line wrap is already permitted. Acceptance: take zh-Hans screenshot, confirm no truncation.

**Self-analog `ZoneBadge`** (lines 38-54): per UI-SPEC line 78, horizontal padding bumps from 10 → 16 in zh-Hans to compensate for CJK density inside the hairline rectangle.

```swift
// Locale-conditional padding
.padding(.horizontal, locale.identifier == "zh-Hans" ? 16 : 10)
```

Read locale via `@Environment(\.locale)` inside the badge. Or — cleaner — pass it through `Font.Tokens`-style helper that exposes locale-aware spacing tokens. Planner decides.

**zh-Hans removes `.textCase(.uppercase)` and `.tracking(1.2)`** (UI-SPEC line 76, line 94): Chinese has no case; apply tracking + uppercase only when `locale.languageCode == "en"`.

---

### `workload management/workload-management-Info.plist` (config)

**Self-analog before** (lines 28-31):
```xml
<key>UIAppFonts</key>
<array>
    <string>GeneralSans-Variable.ttf</string>
</array>
```

**After:**
```xml
<key>UIAppFonts</key>
<array>
    <string>GeneralSans-Variable.ttf</string>
    <string>NotoSansSC-Regular.otf</string>
    <string>NotoSansSC-Medium.otf</string>
</array>
<key>CFBundleDevelopmentRegion</key>
<string>en</string>
<key>CFBundleLocalizations</key>
<array>
    <string>en</string>
    <string>zh-Hans</string>
</array>
```

The `NSHealthShareUsageDescription` key itself moves into `InfoPlist.xcstrings` (en value matches the existing English copy; zh-Hans value per UI-SPEC line 291).

---

### `Resources/Localizable.xcstrings` + `Resources/InfoPlist.xcstrings` (NEW)

**No analog** — greenfield. Follow RESEARCH.md §"Migration Strategy" steps 1-7 (lines 383-442). Bootstrap procedure:

1. Xcode → File → New → File → iOS → Resource → String Catalog → `Localizable.xcstrings` under `WorkloadApp/Resources/`. Target = `workload management`.
2. Build Settings → Localization → **Use Compiler to Extract Swift Strings → YES**.
3. After P2 (string migration), Build the project — every `String(localized:)`, `Text("key")`, `Label("key", …)`, `Button("key")` auto-populates the catalog.
4. Add `zh-Hans` language in catalog editor; populate via LLM draft + human review per D-21.
5. Repeat for `InfoPlist.xcstrings` (auto-discovers `NSHealthShareUsageDescription`, `CFBundleDisplayName`).

---

### `Resources/Fonts/NotoSansSC-{Regular,Medium}.otf` (NEW binaries)

**Analog:** `WorkloadApp/Resources/Fonts/GeneralSans-Variable.ttf` (existing — bundled and registered identically).

Vetting per RESEARCH.md "Package Legitimacy Audit" lines 104-111: SIL OFL 1.1 license, capture SHA-256 of OTFs + LICENSE in PLAN.md, no executable content. Verify combined size ≤ 8 MB (D-19) via `ls -l`.

---

## Shared Patterns

### Localized string literal — every user-facing string

**Source pattern (after migration):**
```swift
Text("key.namespaced")                    // SwiftUI Text — first arg is LocalizedStringKey
Label("key.namespaced", systemImage: …)   // first arg is LocalizedStringKey
Button("key.namespaced") { … }            // first arg is LocalizedStringKey
String(localized: "key.namespaced", defaultValue: "English source")  // throwing or non-View context
```

**Apply to:** every View, every Component, every `displayName`, every `errorDescription`, every alert title/body/button.

**Key namespacing** (RESEARCH.md glossary lines 519-582):
- `sport.*`, `zone.*`, `recoveryZone.*`, `cyclePhase.*`, `frequency.*`, `experience.*`, `acwrMethod.*`, `loadSource.*` — enum displayNames
- `term.*` — glossary entries (hybrid forms)
- `tab.*` — tab bar labels
- `action.*` — generic verbs (Save, Cancel, Continue)
- `auth.error.*` — AuthError descriptions
- `notif.*` — notification content
- `onboarding.*` — onboarding strings
- `profile.*` — profile-screen strings
- `language.picker.*` — picker chrome
- `date.*` / `duration.*` — date helpers
- `paywall.*` — UpgradeSheet copy

### Locale injection (no `Locale.current`)

**Forbidden anywhere in Views / Components / Utilities** (CONTEXT D-14):
```swift
Locale.current   // ← DO NOT use
```

**Replacement:**
```swift
@Environment(\.locale) private var locale   // in View
```
…then pass `locale` as a parameter to any helper (`DateHelpers`, `WeightFormatter`).

**Audit command** for verification:
```bash
git grep -n 'Locale.current' WorkloadApp/Views/ WorkloadApp/Components/ WorkloadApp/Utilities/
# must return zero matches after P2
```

### Live-switch crossfade (root)

**Source:** `App/AppRouter.swift` (new lines added below `.environment(container)`):
```swift
.environment(\.locale, container.localeManager.activeLocale)
.animation(.linear(duration: 0.15), value: container.localeManager.activeLocale)
```

**Apply to:** root view only. All descendant views inherit env locale and re-render on change.

### Hybrid term mixed-script formatting

**Source pattern** (UI-SPEC lines 222-228):
- ASCII space U+0020 (never U+3000)
- ASCII parens `(` `)` U+0028/U+0029 (never `（` `）`)
- Latin uppercase acronym

**CI lint** (RESEARCH.md line 586):
```bash
grep -nP '（|）|　' WorkloadApp/Resources/Localizable.xcstrings && exit 1 || exit 0
```

**Apply to:** every catalog value containing a hybrid term. Add as a pre-commit / CI step.

### Incremental build verification (CLAUDE.md global rule)

After every 3-5 file changes (or after Xcode project file mutations for new resources/fonts), pause and run:
```bash
xcodebuild -project "workload management.xcodeproj" -scheme "workload management" \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build
```
Verify `.pbxproj` lists new files (`LocaleManager.swift`, `LanguagePickerView.swift`, `Localizable.xcstrings`, `InfoPlist.xcstrings`, both `.otf` files) and `UIAppFonts` includes both Noto OTFs.

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `WorkloadApp/Resources/Localizable.xcstrings` | resource | static | No existing `.xcstrings`, `.strings`, or `Localizable*` files anywhere in the repo — greenfield (RESEARCH.md line 125 + CONTEXT line 125). Follow RESEARCH.md Migration Strategy Step 1-6. |
| `WorkloadApp/Resources/InfoPlist.xcstrings` | resource | static | Same — greenfield. Follow RESEARCH.md Step 7. |

App Store Connect zh-Hans metadata work (P5) has no codebase analog — follow RESEARCH.md §"App Store Connect zh-Hans Metadata" lines 590-648 + the memory `reference_asc_navigation.md`. Honor `feedback_asc_caution.md` — never click Submit without user confirmation.

---

## Metadata

**Analog search scope:** `WorkloadApp/App/`, `WorkloadApp/Services/`, `WorkloadApp/Utilities/`, `WorkloadApp/Views/Profile/`, `WorkloadApp/Views/Onboarding/`, `WorkloadApp/Components/`, `WorkloadApp/Models/`, `workload management/`.

**Files scanned:** 13 directly read (FontTokens.swift, DateHelpers.swift, WeightFormatter.swift, AppContainer.swift, AppRouter.swift, WorkloadApp.swift, AuthService.swift, Enums.swift, ProfileView.swift, OnboardingView.swift, NotificationService.swift, MetricTile.swift, workload-management-Info.plist) + SubscriptionService.swift for the @Observable service shape.

**Pattern extraction date:** 2026-05-26.
