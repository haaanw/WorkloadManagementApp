# Phase 1: App Store Launch - Context

**Gathered:** 2026-04-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Finalize remaining App Store submission tasks and ship Tonus v1.0 to the App Store. This phase covers: bundle identifier change, screenshot generation with marketing frames, GitHub Pages URL verification, App Store Connect setup, and TestFlight submission. No new features — purely shipping existing functionality.

</domain>

<decisions>
## Implementation Decisions

### Bundle Identifier
- **D-01:** Bundle identifier is `com.tonus.app` (brand-forward format)
- **D-02:** Deep links remain on GitHub Pages for now — no associated domain setup needed at launch
- **D-03:** Must update all references from `H.workload-management` to `com.tonus.app` (Xcode project, entitlements, Keychain access group if any)

### Screenshot Strategy
- **D-04:** Marketing-style screenshots with device frames + headline text overlays (not plain simulator captures)
- **D-05:** Feature top 4 screens only: Dashboard, Recovery, Workload, ActiveWorkout
- **D-06:** Two device sizes: 6.7" (iPhone 15 Pro Max) and 6.1" (iPhone 15 Pro)
- **D-07:** Headlines should communicate value proposition (e.g., "Know Your Readiness", "Track Training Load")

### Pricing & Availability
- **D-08:** Two-tier subscription pricing (replaces current single-tier):
  - Athlete Pro: $6.99/mo, $59.99/yr (~29% annual discount)
  - Coach Pro: $9.99/mo, $89.99/yr (~26% annual discount)
- **D-09:** Requires new RevenueCat product IDs and updated UpgradeSheet to present both tiers
- **D-10:** US + Canada launch only (soft launch in English-speaking markets, expand later)

### Claude's Discretion
- **Free trial:** Claude recommends 7-day free trial for both tiers — standard for fitness apps, lets users experience premium features before committing. Configure in RevenueCat.
- **Screenshot headline copy:** Claude picks concise value-prop headlines for each of the 4 screens

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### App Store Metadata
- `AppStoreMetadata.md` — Full App Store Connect metadata (name, subtitle, keywords, description, URLs)

### Legal & Privacy
- `docs/privacy.html` — Privacy policy (GitHub Pages)
- `docs/terms.html` — Terms of service (GitHub Pages)
- `docs/support.html` — Support page (GitHub Pages)

### Screenshot Automation
- `workload management/ScreenshotTests/ScreenshotTests.swift` — Existing XCUITest screenshot framework with SCREENSHOT_MODE bypass

### Subscription Config
- `WorkloadApp/Services/SubscriptionService.swift` — Current subscription service (needs update for two-tier)
- `WorkloadApp/Views/Shared/UpgradeSheet.swift` — Current paywall (needs update for tier selection)

### Design System
- `DESIGN.md` — Visual design constraints (0pt corners, DM Sans, 8pt grid, no shadows)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ScreenshotTests.swift`: XCUITest framework already captures 6 screens with SCREENSHOT_MODE launch argument
- `MockDataSeeder.swift`: Seeds realistic mock data for screenshot captures
- `AppStoreMetadata.md`: Full metadata draft ready for App Store Connect entry
- `PrivacyInfo.xcprivacy`: Privacy manifest already comprehensive

### Established Patterns
- `SubscriptionService` uses RevenueCat SDK with `isPro` and `isCoach` entitlement flags — two-tier separation already exists in code
- `UpgradeSheet` has annual/monthly toggle — needs extension for tier selection
- SCREENSHOT_MODE bypasses auth but not subscription gating (known bug in CONCERNS.md)

### Integration Points
- Bundle ID change touches: Xcode project settings, entitlements file, Keychain access group
- Pricing change touches: RevenueCat dashboard config, SubscriptionService product IDs, UpgradeSheet UI
- Screenshots: Run ScreenshotTests on simulators, extract with xcparse, add marketing frames

</code_context>

<specifics>
## Specific Ideas

- Marketing frames should match the app's flat design aesthetic (no rounded device mockups with shadows — keep it clean)
- Screenshot headlines in DM Sans Medium to maintain brand consistency

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-app-store-launch*
*Context gathered: 2026-04-20*
