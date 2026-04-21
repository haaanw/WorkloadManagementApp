# Phase 1: App Store Launch - Research

**Researched:** 2026-04-20
**Domain:** iOS App Store submission, Xcode distribution, RevenueCat pricing, marketing screenshots
**Confidence:** HIGH

## Summary

This phase ships an existing, fully functional iOS app to the App Store. No new features are built -- the work is entirely about submission readiness: bundle identifier cleanup, marketing screenshot generation, pricing updates, and App Store Connect configuration.

The codebase is substantially ready. The main bundle ID is already `com.tonus.app` (only test targets retain the old `H.*` prefix). GitHub Pages URLs for privacy, terms, and support all resolve (HTTP 200 verified). The UpgradeSheet already supports two-tier selection with tier tabs and annual/monthly toggle. The primary code changes are: (1) updating fallback prices and savings badge to match the new pricing decision, (2) fixing SCREENSHOT_MODE to bypass subscription gating so screenshots show premium features, and (3) generating marketing-framed screenshots.

**Primary recommendation:** Treat this as three workstreams -- code fixes (bundle ID cleanup, pricing, screenshot mode fix), screenshot production (capture + frame), and App Store Connect setup (manual steps with clear instructions).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Bundle identifier is `com.tonus.app` (brand-forward format)
- **D-02:** Deep links remain on GitHub Pages for now -- no associated domain setup needed at launch
- **D-03:** Must update all references from `H.workload-management` to `com.tonus.app` (Xcode project, entitlements, Keychain access group if any)
- **D-04:** Marketing-style screenshots with device frames + headline text overlays (not plain simulator captures)
- **D-05:** Feature top 4 screens only: Dashboard, Recovery, Workload, ActiveWorkout
- **D-06:** Two device sizes: 6.7" (iPhone 15 Pro Max) and 6.1" (iPhone 15 Pro)
- **D-07:** Headlines should communicate value proposition (e.g., "Know Your Readiness", "Track Training Load")
- **D-08:** Two-tier subscription pricing: Athlete Pro $6.99/mo, $59.99/yr (~29% annual discount); Coach Pro $9.99/mo, $89.99/yr (~26% annual discount)
- **D-09:** Requires new RevenueCat product IDs and updated UpgradeSheet to present both tiers
- **D-10:** US + Canada launch only (soft launch in English-speaking markets, expand later)

### Claude's Discretion
- **Free trial:** 7-day free trial for both tiers -- standard for fitness apps, lets users experience premium features before committing. Configure in RevenueCat.
- **Screenshot headline copy:** Claude picks concise value-prop headlines for each of the 4 screens
- **Marketing frames:** Flat design aesthetic consistent with app's International Style Minimalism (no rounded device mockups with shadows -- keep it clean)

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| STORE-01 | Finalize bundle identifier (reverse-domain format replacing `H.workload-management`) | Main target already `com.tonus.app` in pbxproj. Test targets (`H.ScreenshotTests`, `H.WorkloadAppTests`) still need update. No Keychain access group in entitlements -- only HealthKit. |
| STORE-02 | Generate App Store screenshots for 6.7" and 6.1" device sizes | Existing `ScreenshotTests.swift` captures 6 screens via XCUITest + SCREENSHOT_MODE. Known bug: subscription gating not bypassed in screenshot mode. Screenshots need marketing frames added post-capture. |
| STORE-03 | Verify GitHub Pages URLs for privacy, terms, support are live and accessible | All three URLs verified HTTP 200: privacy.html, terms.html, support.html at `haaanw.github.io/WorkloadManagementApp/` |
| STORE-04 | Create app record in App Store Connect with metadata from AppStoreMetadata.md | Full metadata document exists with name, subtitle, keywords, description, promotional text, URLs. Manual App Store Connect steps documented below. |
| STORE-05 | Complete age rating questionnaire and set pricing/availability | Age rating: no violent/adult content. Pricing: D-08 defines two-tier pricing. Availability: US + Canada only (D-10). |
| STORE-06 | Archive build, upload to TestFlight, submit for App Store review | Requires Xcode archive + Upload to App Store Connect. Distribution signing must be configured. |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Bundle ID update | Xcode Project Config | -- | Build setting change in pbxproj |
| Screenshot capture | XCUITest / Simulator | -- | Automated UI tests on simulator devices |
| Screenshot framing | Build Script / CLI Tool | -- | Post-processing of PNG images with overlays |
| Pricing update | Client App (UpgradeSheet) | RevenueCat Dashboard | Fallback prices in code; actual prices from RevenueCat offerings |
| SCREENSHOT_MODE fix | Client App (SubscriptionService) | -- | Bypass subscription gating in DEBUG builds |
| App Store metadata | App Store Connect (manual) | -- | Entered via Apple's web portal |
| Build archive + upload | Xcode / CLI | -- | xcodebuild archive + altool/Transporter |

## Current State Analysis

### Bundle Identifier Status
- **Main app target:** Already `com.tonus.app` in both Debug and Release build configurations [VERIFIED: pbxproj grep]
- **ScreenshotTests target:** Still `H.ScreenshotTests` (Debug + Release) [VERIFIED: pbxproj grep]
- **WorkloadAppTests target:** Still `H.WorkloadAppTests` (Debug + Release) [VERIFIED: pbxproj grep]
- **Entitlements:** Only HealthKit capability -- no Keychain access group, no associated domains [VERIFIED: entitlements file]
- **Keychain usage:** Supabase SDK manages its own Keychain storage for auth sessions -- uses SDK defaults, not a custom access group [VERIFIED: AuthService.swift grep]

### GitHub Pages URLs
All three URLs return HTTP 200 [VERIFIED: curl]:
- `https://haaanw.github.io/WorkloadManagementApp/privacy.html`
- `https://haaanw.github.io/WorkloadManagementApp/terms.html`
- `https://haaanw.github.io/WorkloadManagementApp/support.html`

### Subscription Code Status
- `SubscriptionService.swift`: Two-tier architecture already in place (`isPro`, `isCoach` entitlements, `fetchOffering(for:)` with tier parameter) [VERIFIED: source code]
- `UpgradeSheet.swift`: Tier selector tabs (ATHLETE PRO / COACH), annual/monthly toggle, feature lists -- all functional [VERIFIED: source code]
- **Pricing mismatch:** Current fallback prices are $4.99/$39.99 (athlete) and $9.99/$79.99 (coach). Decision D-08 specifies $6.99/$59.99 (athlete) and $9.99/$89.99 (coach) [VERIFIED: source code vs CONTEXT.md]
- **Savings badge:** Currently shows "SAVE 33%". With new pricing: athlete annual ~29% savings, coach annual ~26% savings [VERIFIED: source code]
- **Monthly equivalent text:** Currently "$3.33" (athlete) and "$6.67" (coach). Needs update to ~"$5.00" and ~"$7.50" [VERIFIED: source code]

### Screenshot Infrastructure
- `ScreenshotTests.swift`: Captures 6 screens (Dashboard, WorkoutLog, ActiveWorkout, Recovery, Workload, Profile) [VERIFIED: source code]
- Decision D-05 narrows to 4 screens: Dashboard, Recovery, Workload, ActiveWorkout
- `MockDataSeeder.swift`: Seeds realistic data for screenshot mode [VERIFIED: exists]
- **Known bug:** SCREENSHOT_MODE bypasses auth but NOT subscription gating -- premium features may appear locked [VERIFIED: CONCERNS.md + AppRouter.swift]
- `xcparse` is NOT installed (needed to extract screenshots from xcresult bundles) [VERIFIED: command check]

## Standard Stack

### Core (Already in Project)
| Library | Purpose | Status |
|---------|---------|--------|
| SwiftUI + SwiftData | App framework | In use |
| RevenueCat SDK | Subscription management | In use, needs product ID update in dashboard |
| XCTest / XCUITest | Screenshot automation | In use via ScreenshotTests target |
| Xcode 26.1.1 | Build + archive + upload | Available [VERIFIED: xcodebuild -version] |

### Supporting (Needed for Screenshots)
| Tool | Purpose | When to Use |
|------|---------|-------------|
| xcparse | Extract screenshots from xcresult bundles | After running XCUITest, before framing |
| Swift script or SwiftUI preview | Add marketing frames + headlines to raw screenshots | Post-capture processing |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| xcparse for extraction | `xcrun xcresulttool` | xcparse is simpler CLI; xcresulttool is built-in but more verbose |
| Custom Swift framing script | Figma / Photoshop manual | Automated approach is repeatable; manual is one-time but error-prone |
| fastlane snapshot + frameit | Manual XCUITest + custom framing | fastlane is heavyweight dependency for a single launch; existing XCUITest infra is already built |

## Architecture Patterns

### Screenshot Production Pipeline

```
XCUITest (simulator) --> xcresult bundle --> xcparse extract --> raw PNGs
    --> framing script (add device bezel + headline text) --> final App Store PNGs
```

### Pattern 1: SCREENSHOT_MODE Subscription Bypass
**What:** Extend the existing SCREENSHOT_MODE flag to also mock subscription entitlements
**When to use:** During automated screenshot capture so all premium features display unlocked
**Example:**
```swift
// In AppRouter.swift, within the SCREENSHOT_MODE block (after container.setAuthenticated(true)):
#if DEBUG
if ProcessInfo.processInfo.arguments.contains("SCREENSHOT_MODE") {
    container.subscriptionService.overrideForScreenshots(isPro: true, isCoach: false)
}
#endif
```
This requires adding a `overrideForScreenshots` method to `SubscriptionService` that directly sets `isPro` and `isCoach` without touching RevenueCat SDK. Guard it with `#if DEBUG`. [ASSUMED]

### Pattern 2: Marketing Frame Generation
**What:** Overlay device bezels and headline text onto raw simulator screenshots
**When to use:** After XCUITest capture, before App Store upload
**Approach options:**
1. **SwiftUI preview-based generator** -- Create a SwiftUI view that composites the screenshot image inside a device frame with headline text, render to PNG via ImageRenderer. Runs as a macOS command-line tool or playground.
2. **Manual in design tool** -- Use Figma/Sketch to place screenshots into frames. Less repeatable but faster for one-time.

Given the flat design aesthetic (no rounded mockups, no shadows per D-04 specifics), simple rectangular frames with headline text above are appropriate. No need for photorealistic device chrome. [ASSUMED]

### Anti-Patterns to Avoid
- **Do not add fastlane** for this phase. The existing XCUITest infrastructure is sufficient. Adding fastlane introduces a Ruby dependency and significant configuration overhead for a one-time screenshot run.
- **Do not hardcode prices in UpgradeSheet.** The fallback prices are only shown when RevenueCat offerings fail to load. Real prices come from RevenueCat. Update fallbacks to match D-08, but the source of truth is RevenueCat dashboard configuration.
- **Do not create a separate screenshot app target.** SCREENSHOT_MODE with the existing test target is the established pattern.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Screenshot extraction from xcresult | Manual file traversal | `xcparse screenshots` CLI | xcresult internal format is undocumented and changes between Xcode versions |
| App Store metadata entry | Automated API scripts | App Store Connect web portal | One-time setup; API automation is overengineering |
| Subscription pricing configuration | Code-only pricing | RevenueCat dashboard + App Store Connect | Pricing must be configured in Apple's system; code fallbacks are secondary |
| Device frame overlays | Pixel-level Core Graphics code | Simple SwiftUI ImageRenderer or design tool | Compositing a rectangle + text + image is trivial in SwiftUI |

## Common Pitfalls

### Pitfall 1: Subscription Gating in Screenshots
**What goes wrong:** App Store screenshots show paywalled content (locked features, upgrade banners) instead of the premium experience
**Why it happens:** SCREENSHOT_MODE bypasses auth but not subscription state. SubscriptionService still reports isPro=false.
**How to avoid:** Add a DEBUG-only override method to SubscriptionService that sets isPro/isCoach directly. Call it from AppRouter's SCREENSHOT_MODE block.
**Warning signs:** Screenshots showing "X weeks of training data locked" banner or upgrade prompts

### Pitfall 2: Wrong Simulator Device for Screenshot Sizes
**What goes wrong:** Screenshots captured on wrong simulator don't match App Store required dimensions
**Why it happens:** App Store requires exact pixel dimensions: 6.7" = 1290x2796, 6.1" = 1179x2556
**How to avoid:** Run ScreenshotTests on "iPhone 15 Pro Max" (6.7") and "iPhone 15 Pro" (6.1") simulators specifically. Verify output dimensions before framing.
**Warning signs:** App Store Connect rejects screenshots with wrong dimensions

### Pitfall 3: RevenueCat Product ID Mismatch
**What goes wrong:** UpgradeSheet shows offerings but purchase fails, or offerings return nil
**Why it happens:** Product IDs in RevenueCat dashboard don't match App Store Connect product IDs, or products aren't in "Ready to Submit" state
**How to avoid:** Create products in App Store Connect first, then configure RevenueCat offerings to reference those exact product IDs. Test in sandbox before submission.
**Warning signs:** `fetchOffering` returns nil; fallback prices display instead of real prices

### Pitfall 4: Missing App Store Connect Prerequisites
**What goes wrong:** Build upload succeeds but submission is blocked
**Why it happens:** Missing: app icon in all sizes, privacy manifest, age rating, or pricing not set
**How to avoid:** Complete all metadata fields before attempting submission. Use App Store Connect's built-in checklist.
**Warning signs:** "Missing compliance" or "Missing metadata" warnings in App Store Connect

### Pitfall 5: Bundle ID Change Breaks Existing Installs
**What goes wrong:** Users with debug builds lose Keychain-stored auth sessions after bundle ID change
**Why it happens:** Keychain items are scoped to the app's bundle ID by default
**How to avoid:** This is acceptable for pre-release builds. Production users won't be affected since this is the first App Store release. Document that existing TestFlight users may need to re-authenticate.
**Warning signs:** "Session expired" after updating from old bundle ID build

### Pitfall 6: PrivacyInfo.xcprivacy Missing Required Declarations
**What goes wrong:** App Store review rejects the build for missing privacy manifest entries
**Why it happens:** Apple requires declaring all API usage reasons (UserDefaults, file timestamp, etc.) since Spring 2024
**How to avoid:** PrivacyInfo.xcprivacy already exists in the project. Verify it declares all required API categories used by the app and its dependencies (RevenueCat, Supabase SDK).
**Warning signs:** Build processing warning emails from Apple about missing privacy declarations

## Code Examples

### Subscription Override for Screenshot Mode
```swift
// Add to SubscriptionService.swift
#if DEBUG
/// Force subscription state for screenshot capture.
/// Call ONLY from SCREENSHOT_MODE bootstrap in AppRouter.
func overrideForScreenshots(isPro override: Bool, isCoach coachOverride: Bool) {
    self.isPro = override
    self.isCoach = coachOverride
}
#endif
```
Source: Based on existing SCREENSHOT_MODE pattern in AppRouter.swift [ASSUMED]

### Updated Fallback Pricing (D-08)
```swift
// In SubscriptionTier enum (UpgradeSheet.swift)
var fallbackAnnualPrice: String {
    switch self {
    case .athletePro: return "$59.99/yr"
    case .coach: return "$89.99/yr"
    }
}

var fallbackMonthlyPrice: String {
    switch self {
    case .athletePro: return "$6.99/mo"
    case .coach: return "$9.99/mo"
    }
}

var monthlyEquivalent: String {
    switch self {
    case .athletePro: return "$5.00"
    case .coach: return "$7.50"
    }
}
```

### Test Target Bundle ID Update
```
// In project.pbxproj, update four occurrences:
H.ScreenshotTests  -->  com.tonus.app.ScreenshotTests
H.WorkloadAppTests  -->  com.tonus.app.WorkloadAppTests
```

### Screenshot Test Run Commands
```bash
# 6.7" screenshots (iPhone 15 Pro Max)
xcodebuild test \
  -project "workload management/workload management.xcodeproj" \
  -scheme "ScreenshotTests" \
  -destination "platform=iOS Simulator,name=iPhone 15 Pro Max" \
  -resultBundlePath /tmp/Screenshots_6_7.xcresult

# 6.1" screenshots (iPhone 15 Pro)
xcodebuild test \
  -project "workload management/workload management.xcodeproj" \
  -scheme "ScreenshotTests" \
  -destination "platform=iOS Simulator,name=iPhone 15 Pro" \
  -resultBundlePath /tmp/Screenshots_6_1.xcresult

# Extract screenshots
xcparse screenshots /tmp/Screenshots_6_7.xcresult ~/Desktop/AppStoreScreenshots/6_7
xcparse screenshots /tmp/Screenshots_6_1.xcresult ~/Desktop/AppStoreScreenshots/6_1
```
[ASSUMED: scheme name "ScreenshotTests" -- may differ based on Xcode project setup]

## App Store Connect Manual Steps

These steps cannot be automated and must be performed by the user in App Store Connect:

### 1. Create App Record
- Log into App Store Connect
- My Apps > "+" > New App
- Platform: iOS
- Name: "Tonus"
- Primary Language: English (US)
- Bundle ID: Select `com.tonus.app` (must match provisioning profile)
- SKU: `tonus-ios` (any unique identifier)

### 2. App Information
- Subtitle: "Training Load & Recovery"
- Category: Health & Fitness
- Content Rights: "Does not contain third-party content"
- Age Rating: Complete questionnaire (no violence, no adult content, medical/health info: yes)

### 3. Pricing and Availability
- Select territories: United States, Canada only (D-10)
- Configure in-app purchases (see RevenueCat section below)

### 4. In-App Purchases (App Store Connect)
Create four products:
| Product ID | Reference Name | Type | Price |
|------------|---------------|------|-------|
| `tonus_athlete_pro_monthly` | Athlete Pro Monthly | Auto-Renewable | $6.99 |
| `tonus_athlete_pro_annual` | Athlete Pro Annual | Auto-Renewable | $59.99 |
| `tonus_coach_monthly` | Coach Pro Monthly | Auto-Renewable | $9.99 |
| `tonus_coach_annual` | Coach Pro Annual | Auto-Renewable | $89.99 |

Each product needs: display name, description, subscription group, and free trial configuration (7 days).

### 5. RevenueCat Dashboard
- Create/update products matching the App Store Connect product IDs above
- Configure two offerings: `athlete_pro` and `coach` (these match existing code in SubscriptionService.swift)
- Each offering has annual and monthly packages
- Enable 7-day free trial (introductory offer) for both tiers
- Verify sandbox testing works before submission

### 6. App Store Metadata Entry
- Copy all content from `AppStoreMetadata.md` into App Store Connect
- Upload screenshots (after framing)
- Set privacy URL, support URL, terms URL from AppStoreMetadata.md
- What's New: "Initial release -- training load tracking, recovery scoring, coach-athlete sync, prescribed workouts, and subscription tiers."

[ASSUMED: Product ID naming convention -- user should confirm preferred format]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Xcode Organizer manual upload | Xcode Organizer or `xcodebuild -exportArchive` + Transporter | Stable | Either works for first submission |
| fastlane snapshot for screenshots | XCUITest + xcparse (lightweight) | Project choice | Avoids Ruby dependency |
| App Store Connect API for metadata | Web portal for first submission | N/A | API is overkill for one-time setup |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | SubscriptionService can be extended with a DEBUG-only override method without breaking RevenueCat SDK behavior | Code Examples | LOW -- `isPro`/`isCoach` are simple bools on an @Observable class; setting them directly is safe |
| A2 | iPhone 15 Pro Max and iPhone 15 Pro simulators are available on Xcode 26.1.1 | Common Pitfalls | LOW -- these are standard simulators; may need to download runtime |
| A3 | Screenshot test scheme is named "ScreenshotTests" | Code Examples | MEDIUM -- scheme name may differ; verify in Xcode before running |
| A4 | Simple rectangular marketing frames (no photorealistic device chrome) are acceptable for App Store | Architecture Patterns | LOW -- Apple does not require device frames; many top apps use flat frames |
| A5 | Product IDs `tonus_athlete_pro_monthly` etc. are the preferred naming convention | App Store Connect Steps | LOW -- any unique string works; user can choose their own convention |
| A6 | xcparse works with Xcode 26.1.1 xcresult format | Standard Stack | MEDIUM -- xcresult format evolves; xcrun xcresulttool is the fallback |

## Open Questions

1. **RevenueCat API key and dashboard access**
   - What we know: `RevenueCatConfig.swift` is gitignored, API key exists
   - What's unclear: Does the user have RevenueCat dashboard access to create/update product offerings?
   - Recommendation: Provide step-by-step instructions; user confirms they can access the dashboard

2. **Apple Developer Program enrollment**
   - What we know: App needs to be submitted to App Store
   - What's unclear: Is the user enrolled in the Apple Developer Program ($99/yr)?
   - Recommendation: Verify enrollment before attempting archive/upload

3. **Distribution signing configuration**
   - What we know: Project builds for simulator
   - What's unclear: Are distribution certificates and provisioning profiles configured for `com.tonus.app`?
   - Recommendation: May need to create App ID + provisioning profile in Apple Developer portal before archiving

4. **Existing screenshots test scheme**
   - What we know: ScreenshotTests.swift exists as a file
   - What's unclear: Whether the ScreenshotTests UI test target is properly configured with the correct scheme in Xcode
   - Recommendation: Verify in Xcode before running automated captures

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | Build, archive, upload | Yes | 26.1.1 | -- |
| xcodebuild | CLI screenshot capture | Yes | 26.1.1 | -- |
| xcparse | Screenshot extraction | No | -- | `xcrun xcresulttool` (built-in, more verbose) |
| iOS Simulator (15 Pro Max) | 6.7" screenshots | Unknown | -- | Download runtime via Xcode |
| iOS Simulator (15 Pro) | 6.1" screenshots | Unknown | -- | Download runtime via Xcode |
| App Store Connect access | Submission | Unknown | -- | User must verify enrollment |
| RevenueCat dashboard | Pricing config | Unknown | -- | User must verify access |

**Missing dependencies with no fallback:**
- Apple Developer Program enrollment (if not enrolled, cannot submit)
- Distribution certificate + provisioning profile for `com.tonus.app`

**Missing dependencies with fallback:**
- xcparse: Install via `brew install chargepoint/xcparse/xcparse`, or use `xcrun xcresulttool` as fallback

## Project Constraints (from CLAUDE.md)

- **Platform:** iOS 17+ only, SwiftUI + SwiftData
- **Design system:** Must follow DESIGN.md -- 0pt corners, no shadows, DM Sans fonts, 8pt grid
- **Font usage:** Only `Font.custom("DMSans-Regular/Medium", size:)` -- never system fonts
- **Colors:** All via `ColorTokens` -- never hardcoded hex
- **HealthKit:** Raw data never leaves device -- only composite scores sync
- **RevenueCat:** API keys gitignored -- never commit `RevenueCatConfig.swift`
- **Subscriptions:** `isPro` (athlete_pro OR coach) and `isCoach` (coach only) entitlement model
- **Incremental build verification:** Run build check after every 3-5 files modified
- **SCREENSHOT_MODE:** DEBUG-only launch argument that bypasses auth and seeds mock data

## Sources

### Primary (HIGH confidence)
- Project source code: `SubscriptionService.swift`, `UpgradeSheet.swift`, `ScreenshotTests.swift`, `AppRouter.swift`, `AuthService.swift` -- direct inspection
- `project.pbxproj` -- bundle identifier grep
- `workload management.entitlements` -- capability inspection
- GitHub Pages URLs -- curl HTTP status verification
- `CONCERNS.md` -- known bugs (SCREENSHOT_MODE subscription bypass)
- `AppStoreMetadata.md` -- complete metadata draft
- `DESIGN.md` -- design system constraints
- Xcode version: `xcodebuild -version` output

### Secondary (MEDIUM confidence)
- App Store screenshot dimension requirements (1290x2796 for 6.7", 1179x2556 for 6.1") [ASSUMED -- standard Apple requirements, may have changed]

### Tertiary (LOW confidence)
- xcparse compatibility with Xcode 26.1.1 [ASSUMED -- tool may need update for latest xcresult format]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all tools are already in the project or standard Apple tooling
- Architecture: HIGH -- existing patterns are clear, changes are minimal
- Pitfalls: HIGH -- known bugs documented in CONCERNS.md, common App Store submission issues well-understood
- Pricing/RevenueCat: MEDIUM -- code changes are clear, but dashboard configuration requires user access verification

**Research date:** 2026-04-20
**Valid until:** 2026-05-20 (stable domain -- App Store submission process changes infrequently)
