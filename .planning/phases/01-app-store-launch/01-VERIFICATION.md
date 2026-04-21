---
phase: 01-app-store-launch
verified: 2026-04-20T12:00:00Z
status: human_needed
score: 3/4
overrides_applied: 0
human_verification:
  - test: "Confirm screenshots are visible in App Store Connect for both display size slots"
    expected: "Uploaded screenshots show in 6.7 inch and either 6.1 or 6.3 inch display slots with no missing screenshot warnings"
    why_human: "App Store Connect dashboard required to confirm accepted display categories for the uploaded 1320x2868 (6.9in) and 1206x2622 (6.3in) screenshots vs ROADMAP SC which specifies 6.7 and 6.1 inch sizes"
  - test: "Confirm Tonus app status in App Store Connect is still in review or approved"
    expected: "Status is Waiting for Review, In Review, or Approved — not Rejected or Metadata Rejected"
    why_human: "01-03-SUMMARY.md confirms submission reached Waiting for Review as of 2026-04-20, but current status cannot be checked programmatically"
---

# Phase 1: App Store Launch — Verification Report

**Phase Goal:** Get Tonus submitted to App Store review with complete metadata, screenshots, and working build.
**Verified:** 2026-04-20T12:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | App has a production bundle identifier and builds cleanly with it | VERIFIED | `com.tonus.app` in project.pbxproj (Debug + Release); zero `H.` prefixes remain; commits 2275fdf and 7732d04 |
| 2 | App Store screenshots exist for 6.7" and 6.1" device sizes showing key screens | PARTIAL | Raw screenshots captured at 1320x2868 (6.9in iPhone 17 Pro Max) and 1206x2622 (6.3in iPhone 17 Pro) — ROADMAP SC specifies 6.1in but 6.3in was used; framed outputs confirmed uploaded to App Store Connect per 01-03 summary; human verification needed to confirm App Store Connect accepted both display slots |
| 3 | Privacy policy, terms of service, and support URLs resolve in a browser | VERIFIED | All three GitHub Pages URLs returned HTTP 200 at verification time: privacy.html, terms.html, support.html |
| 4 | App is submitted to App Store review (TestFlight build uploaded, metadata complete) | VERIFIED | 01-03-SUMMARY.md confirms human-verified status "Waiting for Review" after build 1.0(2) submission on 2026-04-20 |

**Score:** 3/4 truths fully verified (1 partial — screenshot device size deviation)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `workload management/workload management.xcodeproj/project.pbxproj` | Updated test target bundle identifiers | VERIFIED | `com.tonus.app.ScreenshotTests` (2x) and `com.tonus.app.WorkloadAppTests` (2x); zero `H.` prefixes |
| `WorkloadApp/Services/SubscriptionService.swift` | DEBUG-only screenshot subscription override | VERIFIED | `overrideForScreenshots(isPro:isCoach:)` method present at line 115, wrapped in `#if DEBUG` block |
| `WorkloadApp/Views/Subscription/UpgradeSheet.swift` | Updated fallback pricing per D-08 | VERIFIED | `$59.99/yr` (line 335), `annualSavingsBadge` property (line 354), dynamic badge via `selectedTier.annualSavingsBadge` (line 110) |
| `WorkloadApp/App/AppRouter.swift` | Subscription override call in SCREENSHOT_MODE block | VERIFIED | `container.subscriptionService.overrideForScreenshots(isPro: true, isCoach: false)` at line 53, inside `SCREENSHOT_MODE` `#if DEBUG` block |
| `workload management/ScreenshotTests/ScreenshotTests.swift` | Screenshot test targeting 4 required screens | VERIFIED | `SCREENSHOT_MODE` launch argument at line 21; tests for Dashboard (test01), ActiveWorkout (test03), Recovery (test04), Workload (test05) |
| `scripts/frame_screenshots.swift` | Marketing frame generation script | VERIFIED | Exists (9.9KB); uses CoreGraphics (`CGContext`); contains all 4 headline strings; all screen labels present |
| `AppStoreMetadata.md` | Source of truth for App Store Connect metadata fields | VERIFIED | Present in repo root (2.5KB); contains "Training Load & Recovery" subtitle; keywords and description present |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `WorkloadApp/App/AppRouter.swift` | `WorkloadApp/Services/SubscriptionService.swift` | `container.subscriptionService.overrideForScreenshots(isPro: true, isCoach: false)` in SCREENSHOT_MODE block | WIRED | Exact pattern confirmed at AppRouter.swift line 53; method defined at SubscriptionService.swift line 115 |
| `workload management/ScreenshotTests/ScreenshotTests.swift` | `WorkloadApp/App/AppRouter.swift` | SCREENSHOT_MODE launch argument triggers mock data + subscription bypass | WIRED | `app.launchArguments = ["SCREENSHOT_MODE"]` at ScreenshotTests.swift line 21; AppRouter handles at line 38 |
| `AppStoreMetadata.md` | App Store Connect | Manual copy of metadata fields | VERIFIED (human-confirmed) | 01-03-SUMMARY confirms metadata entered from AppStoreMetadata.md |
| RevenueCat Dashboard | App Store Connect In-App Purchases | Matching product IDs | VERIFIED (human-confirmed) | Products confirmed as `com.tonus.app.athlete_pro.monthly/annual` and `com.tonus.app.coach.monthly/annual` per 01-03-SUMMARY; naming differs from plan spec but subscription service uses entitlement IDs ("athlete_pro", "coach") not product IDs directly |

### Data-Flow Trace (Level 4)

Not applicable — this phase produces submission artifacts (code configuration, screenshots, metadata), not data-rendering UI components.

### Behavioral Spot-Checks

| Behavior | Evidence | Status |
|----------|----------|--------|
| Zero H. bundle ID prefixes in pbxproj | `grep -c "PRODUCT_BUNDLE_IDENTIFIER = H\."` returns 0 | PASS |
| GitHub Pages privacy URL resolves | `curl` returns HTTP 200 | PASS |
| GitHub Pages terms URL resolves | `curl` returns HTTP 200 | PASS |
| GitHub Pages support URL resolves | `curl` returns HTTP 200 | PASS |
| overrideForScreenshots wired in AppRouter | Pattern confirmed at line 53 | PASS |
| Fallback pricing $59.99/yr in UpgradeSheet | Confirmed at line 335 | PASS |
| annualSavingsBadge dynamic (not hardcoded "SAVE 33%") | `selectedTier.annualSavingsBadge` at line 110 | PASS |
| Frame script contains all 4 headlines | Confirmed lines 26-29 | PASS |
| Framed screenshots in /tmp (6_7_framed, 6_3_framed) | Directories present but empty — /tmp cleared post-execution; upload confirmed in 01-03-SUMMARY | INCONCLUSIVE (see below) |

**Note on framed screenshot /tmp state:** The `/tmp/AppStoreScreenshots/6_7_framed/` and `6_3_framed/` directories exist but are empty. The raw screenshot directories (`6_7/`, `6_3/`) contain named PNGs for all 4 required screens. The 01-02-SUMMARY documents 8 framed outputs and human approval. The 01-03-SUMMARY confirms "Screenshots uploaded (4 screens x 2 sizes, marketing-framed)" to App Store Connect. The empty /tmp state is consistent with normal /tmp cleanup between sessions.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| STORE-01 | 01-01-PLAN.md | Finalize bundle identifier to reverse-domain format | SATISFIED | `com.tonus.app` throughout pbxproj; no `H.` prefixes; com.tonus.app.ScreenshotTests + com.tonus.app.WorkloadAppTests for test targets |
| STORE-02 | 01-02-PLAN.md | Generate App Store screenshots for 6.7" and 6.1" device sizes | PARTIAL | 4 screens captured; framing script exists; human-approved; uploaded to App Store Connect. Device sizes used were 6.9in (1320x2868) and 6.3in (1206x2622) — different from SC-specified 6.7in/6.1in. Submission accepted, but display slot coverage needs human confirmation |
| STORE-03 | 01-01-PLAN.md | Verify GitHub Pages URLs are live | SATISFIED | All three URLs return HTTP 200 |
| STORE-04 | 01-03-PLAN.md | Create App Store Connect record with metadata | SATISFIED (human-confirmed) | 01-03-SUMMARY confirms record existed (March 27) and metadata from AppStoreMetadata.md was entered; screenshots uploaded |
| STORE-05 | 01-03-PLAN.md | Complete age rating questionnaire and set pricing/availability | SATISFIED (human-confirmed) | 01-03-SUMMARY: age rating, Free + IAP pricing, US/Canada availability confirmed from prior submission |
| STORE-06 | 01-03-PLAN.md | Archive build, upload to TestFlight, submit for App Store review | SATISFIED (human-confirmed) | Build 1.0(2) archived in Xcode, uploaded to App Store Connect, status "Waiting for Review" per 01-03-SUMMARY |

### Anti-Patterns Found

| File | Pattern | Severity | Impact |
|------|---------|----------|--------|
| `WorkloadApp/Services/SubscriptionService.swift` | `overrideForScreenshots` inside `#if DEBUG` | Info | Intentional — DEBUG-only bypass, cannot ship in production. T-01-01 mitigation COMPLIANT. |

No blockers or warnings found. No TODO/FIXME/placeholder comments in the 4 modified files.

### Human Verification Required

#### 1. App Store Connect Screenshot Display Slot Coverage

**Test:** Log into App Store Connect, navigate to Tonus > App Store > version in progress, scroll to App Previews and Screenshots section.
**Expected:** Screenshots are present and accepted in at least two device display slots. No error banner stating "Screenshots required for [X] inch display." Specifically check that the 1320x2868 screenshots appear in a display category and the 1206x2622 screenshots appear in another display category.
**Why human:** ROADMAP SC2 specifies "6.7 inch and 6.1 inch" but the plan captured 6.9in (1320x2868, iPhone 17 Pro Max) and 6.3in (1206x2622, iPhone 17 Pro). App Store Connect has distinct display size slots. While the submission reached "Waiting for Review" (suggesting no blocking screenshot errors), the exact display slot coverage cannot be confirmed programmatically.

#### 2. Current Submission Status

**Test:** Log into App Store Connect, navigate to Tonus, check the current App Store review status.
**Expected:** Status is "Waiting for Review," "In Review," or "Approved" — not "Rejected," "Metadata Rejected," or "Developer Rejected."
**Why human:** The 01-03-SUMMARY confirms "Waiting for Review" as of 2026-04-20 (the day of submission), but App Store review is an ongoing process. Phase goal is "submitted to App Store review" which requires the submission to still be in the review pipeline.

### Gaps Summary

No hard blockers found. The primary open item is the device size deviation in STORE-02: screenshots were captured at 6.9in and 6.3in (iPhone 17 series) rather than the ROADMAP-specified 6.7in and 6.1in. This is a naming/categorization question — the submission was accepted and reached "Waiting for Review" which strongly implies App Store Connect accepted the uploaded screenshot dimensions. Two human verification items remain before this phase can be closed as fully passed.

---

_Verified: 2026-04-20T12:00:00Z_
_Verifier: Claude (gsd-verifier)_
