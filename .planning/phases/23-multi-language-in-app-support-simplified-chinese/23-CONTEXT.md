# Phase 23: Multi-language in-app support (Simplified Chinese) - Context

**Gathered:** 2026-05-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Add Simplified Chinese (zh-Hans) localization to Tonus alongside the existing English (en) baseline. Covers every user-facing string in the iOS app (core UI, errors, paywall, legal, push notifications) plus App Store metadata for the CN/zh-Hans storefront. Introduces the i18n infrastructure the project does not yet have: string catalog, locale-aware formatters, CJK font handling, and an in-app language picker.

In scope: extracting hardcoded strings, building a zh-Hans translation set, locale switching UX, CJK font bundling, App Store zh-Hans metadata/screenshots.

Out of scope: additional languages beyond zh-Hans (Traditional Chinese, Japanese, Korean, etc.), right-to-left layout support, machine-translation of dynamic user-entered content, re-recording App Store screenshots for any non-zh-Hans locale.

</domain>

<decisions>
## Implementation Decisions

### Scope of Localization
- **D-01:** Localize core UI strings — every `Text`, `Label`, button title, tab name, alert, empty state, onboarding copy across all Views.
- **D-02:** Localize error + paywall + legal copy — auth/sync error messages, `UpgradeSheet`, privacy policy and ToS pages.
- **D-03:** Localize push notifications — streak, reminder, and coach-invite notification copy chosen by device locale at send/format time.
- **D-04:** Localize App Store metadata — app name, subtitle, description, keywords, and screenshots for the zh-Hans storefront. Treat as part of this phase (planned + executed here even though work happens in ASC).
- **D-05:** Dynamic user content (custom exercise names, template names, athlete notes, coach comments) is stored as-entered and never translated. No locale tagging, no mismatch warning. Coaches and athletes are assumed to share a working language.

### Terminology Policy
- **D-06:** Render technical training terms as **hybrid — Chinese + parenthetical English acronym**. Examples:
  - ACWR → 训练负荷比 (ACWR)
  - HRV → 心率变异性 (HRV)
  - TSS → 训练压力评分 (TSS)
  - RHR → 静息心率 (RHR)
  - EWMA → 指数加权移动平均 (EWMA)
  - CTL → 慢性训练负荷 (CTL)
  - ATL → 急性训练负荷 (ATL)
- **D-07:** First introduction of each term in a screen uses the hybrid form; subsequent occurrences in the same surface may use Chinese only if layout demands it. Educational onboarding/glossary copy always uses hybrid.
- **D-08:** Researcher must propose final Chinese glossary as part of RESEARCH.md — terms above are anchors, not final wording.

### String Catalog Technology
- **D-09:** Adopt **Xcode 15 `.xcstrings` String Catalog** as the single source of truth. Migrate all hardcoded strings into one root `Localizable.xcstrings`.
- **D-10:** Use `LocalizedStringKey` / `String(localized:)` everywhere in SwiftUI. No `NSLocalizedString` legacy calls, no `.strings` files. Pluralization handled via the catalog's native plural variations (English source only — Chinese has no plural form).
- **D-11:** Strings that already live in nested types (`AuthService.AuthError.errorDescription`, enum `displayName` properties) move to the catalog via `String(localized:)`.

### Locale Switching UX
- **D-12:** Provide an **in-app language picker in Profile** with **live switch** (no restart required).
- **D-13:** Implement live switch by exposing a `LocaleManager` (or equivalent) in `AppContainer` that publishes the active `Locale`, set on the root view via `.environment(\.locale, …)`. Persist selection in `UserDefaults`.
- **D-14:** Views that read `Locale.current` directly (date helpers, weight formatter) must switch to reading the injected environment locale so live switch propagates.
- **D-15:** Default on first launch: **match system locale silently**. If iOS = zh-Hans, app comes up in Chinese with no prompt.
- **D-16:** Onboarding flow exposes the language picker as one of its steps so first-launch users (and existing users seeing the updated onboarding/tip) can change away from the system default before continuing.

### CJK Font Handling
- **D-17:** Bundle a CJK font — **Noto Sans SC** (or Source Han Sans SC — researcher picks the one whose Regular + Medium weights best match General Sans Variable). Ship Regular (400) and Medium (500) weights only, matching the existing General Sans policy.
- **D-18:** Extend `FontTokens` so each `Font.Tokens.*` token resolves to General Sans for Latin glyphs and Noto Sans SC for CJK glyphs. Use Font Descriptor cascade / `UIFontDescriptor` matrix attribute so a single token works in mixed-script strings (e.g., "训练负荷比 (ACWR)" must render seamlessly).
- **D-19:** Verify bundle size impact stays under +8 MB total for the two CJK weights. If it overshoots, researcher proposes subsetting (drop rare ideographs not used in the catalog) before falling back to system PingFang SC.
- **D-20:** Audit the design system in zh-Hans for hairline-border layouts on the dashboard and metric tiles — CJK characters have higher visual density and may need spacing tweaks; respect 8pt grid.

### Translation Workflow
- **D-21:** LLM-assisted draft, human review. Claude/Codex generates initial zh-Hans for every key in the catalog; user reviews and edits in Xcode's String Catalog editor before commit. No automated commits of unreviewed translations.
- **D-22:** Marketing-tone copy (App Store description, onboarding hero copy, paywall headline) gets a second pass with attention to Chinese fitness/sport culture conventions — direct translation is acceptable as a starting point but the reviewer rewrites for tone where the literal version reads awkwardly.

### Claude's Discretion
- Researcher chooses between Noto Sans SC and Source Han Sans SC based on weight axis fidelity to General Sans.
- Researcher proposes the canonical Chinese term for every technical concept in the glossary; user reviews.
- Planner decides phase split (e.g., infra → catalog migration → translation pass → font work → ASC metadata) and whether to do it as one phase or sub-plans.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project rules
- `CLAUDE.md` — design constraints (General Sans, 0pt corners, no shadows, 8pt grid, `ColorTokens`/`Font.Tokens`), HealthKit/Supabase rules, SCREENSHOT_MODE.
- `DESIGN.md` — design system source of truth; required reading before any visual change.
- `.planning/PROJECT.md` — Tonus value proposition, constraints (iOS 17+, HealthKit read-only, RevenueCat).
- `.planning/REQUIREMENTS.md` — milestone-level requirements (read for v1.4 scope context).
- `.planning/ROADMAP.md` §"Phase 23: Multi-language in-app support (Simplified Chinese)" — phase entry.

### Codebase landmarks (touch points for i18n migration)
- `WorkloadApp/Utilities/FontTokens.swift` — current font policy; site of CJK cascade integration.
- `WorkloadApp/Utilities/ColorTokens.swift` — semantic colors (no changes expected, but check zh-Hans contrast on metric tiles).
- `WorkloadApp/Utilities/DateHelpers.swift` — date formatting; must read injected environment locale.
- `WorkloadApp/Utilities/WeightFormatter.swift` — number formatting; same locale-injection requirement.
- `WorkloadApp/App/AppContainer.swift` — host the new `LocaleManager`.
- `WorkloadApp/App/AppRouter.swift` — wire `.environment(\.locale, …)` at root; handle onboarding language step.
- `WorkloadApp/App/WorkloadApp.swift` — register custom CJK font with `UIFont` assertions on launch.
- `WorkloadApp/Views/Onboarding/` — insert language-picker step.
- `WorkloadApp/Views/Profile/` — add language picker row.
- `WorkloadApp/Services/AuthService.swift` — `AuthError.errorDescription` strings move to catalog.
- `WorkloadApp/Models/Enums.swift` — `displayName` properties for `SportType`, `ACWRZone`, `RecoveryZone`, etc. all become localized.
- `WorkloadApp/Services/SubscriptionService.swift` + `Views/Subscription/UpgradeSheet.swift` — paywall copy.
- `workload management/workload-management-Info.plist` — `CFBundleDevelopmentRegion`, `CFBundleLocalizations`, `NSHealthShareUsageDescription` (the HealthKit consent string is user-facing and must localize).

### Codebase maps
- `.planning/codebase/STRUCTURE.md`, `STACK.md`, `CONVENTIONS.md`, `ARCHITECTURE.md` — orient researcher/planner.

### Memory (carries forward)
- `~/.claude/projects/-Users-hanwen-Desktop-Tonus/memory/project_appstore_submission.md` — App Store status (v1.0 submitted 2026-04-30); informs ASC metadata workflow.
- `~/.claude/projects/-Users-hanwen-Desktop-Tonus/memory/reference_asc_navigation.md` — ASC structure for adding the zh-Hans storefront locale.
- `~/.claude/projects/-Users-hanwen-Desktop-Tonus/memory/feedback_asc_caution.md` — never click ASC submission buttons without user confirmation.
- `~/.claude/projects/-Users-hanwen-Desktop-Tonus/memory/project_v13_backlog.md` — Alpino font + rounded-border fix item; coordinate with font work in this phase.

### External docs (researcher to fetch + cite)
- Apple: String Catalogs (`xcstrings`) reference — extraction rules, plural variations, state tracking.
- Apple HIG: Internationalization & Localization, including HealthKit consent string localization rules.
- Noto Sans SC / Source Han Sans SC license + weight axis docs (SIL OFL).
- App Store Connect: adding a new App Localization (zh-Hans), screenshot specs per device family.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `FontTokens` — single point of font configuration; extending here keeps every view's typography correct after CJK cascade is added.
- `ColorTokens` — already locale-agnostic; no work needed beyond zh-Hans contrast spot checks.
- `AppContainer` — established DI pattern; `LocaleManager` slots in next to `SubscriptionService` etc.
- `Enums.swift displayName` pattern — every domain enum already centralizes display strings, so migration to the catalog is mechanical (`String(localized: …)` per case).

### Established Patterns
- All views consume `@Environment(AppContainer.self)` — locale plumbing piggybacks on this.
- Engines and repositories never touch UI strings; localization changes are isolated to Views, ViewModels, and Services that surface errors.
- `SCREENSHOT_MODE` launch argument seeds mock data — zh-Hans App Store screenshots can reuse it by also passing a locale override (`-AppleLanguages "(zh-Hans)"` in the screenshot scheme).
- No existing `.strings`, `.stringsdict`, or `Localizable` files anywhere in the repo — greenfield i18n; xcstrings catalog is uncontested.

### Integration Points
- Custom font registration in `WorkloadApp.swift` already asserts General Sans availability at launch; add Noto/Source Han SC assertions next to it.
- `AppRouter` already injects `AppContainer`; add `.environment(\.locale, …)` here so every navigation destination inherits the active locale.
- HealthKit `NSHealthShareUsageDescription` lives in `workload-management-Info.plist` and must be localized via `InfoPlist.xcstrings`.
- Push notifications: streak/reminder content is composed in-app — localize at compose time using the device's current preferred locale (which already maps to the user's iOS Settings) and persist no English-only copy in payloads.

</code_context>

<specifics>
## Specific Ideas

- Hybrid terminology format pinned to: `中文术语 (ACRONYM)` with a space before the parenthesis and the acronym in Latin letters — this is the visual reference for every glossary entry.
- The language picker in Profile sits as a row alongside subscription / account settings, using the same row style as other profile entries; no nested screen unless researcher finds a stronger pattern.
- "Live switch" means the visible UI re-renders in the chosen locale without an app relaunch — including date strings, numbers, and weight units, all of which must read the injected environment locale.

</specifics>

<deferred>
## Deferred Ideas

- Traditional Chinese (zh-Hant) and other languages (ja, ko, es, etc.) — separate phase per locale family, after zh-Hans validates the i18n infrastructure.
- Locale tagging on user-entered content with cross-locale display warnings — not now; revisit if real coach-athlete language-mismatch reports appear.
- Automated machine translation of dynamic content (exercise names, notes) — out of scope; user content stays as-entered.
- RTL language support (Arabic, Hebrew) — would require layout audits across every View; defer until there is real demand.
- Font subsetting toolchain (if Noto Sans SC bundle proves too large) — only invoked as a fallback; if needed, deserves its own infra phase.
- Alpino font swap (from v1.3 backlog) — coordinate with this phase if it lands first, but don't bundle two new font families simultaneously; defer Alpino unless researcher finds a clean way to combine.

</deferred>

---

*Phase: 23-multi-language-in-app-support-simplified-chinese*
*Context gathered: 2026-05-26*
