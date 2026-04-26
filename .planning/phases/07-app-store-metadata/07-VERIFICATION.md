---
phase: 07-app-store-metadata
verified: 2026-04-26T12:00:00Z
status: gaps_found
score: 2/4
overrides_applied: 0
gaps:
  - truth: "Marketing screenshots with benefit-oriented captions exist for 6.7\" and 6.5\" device sizes"
    status: failed
    reason: "Screenshot tests are written and ready, but the tests have not been executed on the required simulators (iPhone 15 Pro Max for 6.7\", iPhone 11 Pro Max for 6.5\"). No composed marketing images with captions exist. The existing appstore screenshots directory contains 4 old framed screenshots (Dashboard, Recovery, Workload, ActiveWorkout) that predate Phase 7's 6-screen spec and lack the caption overlay required by ASO-03."
    artifacts:
      - path: "workload management/ScreenshotTests/ScreenshotTests.swift"
        issue: "Tests are code-complete and correct, but they must be executed to produce screenshot assets"
      - path: "appstore screenshots/6\"7/"
        issue: "Contains 4 old framed screenshots (Dashboard_framed.png, Recovery_framed.png, Workload_framed.png, ActiveWorkout_framed.png) -- not the 6-screen marketing spec with captions"
    missing:
      - "Run screenshot tests on iPhone 15 Pro Max simulator (6.7\") and iPhone 11 Pro Max simulator (6.5\")"
      - "Extract screenshots from xcresult bundle using xcparse"
      - "Compose 6 marketing images per APP_STORE_METADATA.md composition spec (caption overlay, subcaption, 1290x2796px and 1284x2778px)"
  - truth: "App Store title, subtitle, and keyword field are populated with targeted terms in App Store Connect"
    status: failed
    reason: "The metadata document (APP_STORE_METADATA.md) is complete with correct copy (title 28/30 chars, subtitle 27/30 chars, keywords 97/100 chars), but Plan 03 Task 2 was a checkpoint:human-verify gate explicitly left as 'awaiting human action'. There is no evidence that the metadata has been entered in App Store Connect."
    artifacts:
      - path: ".planning/phases/07-app-store-metadata/APP_STORE_METADATA.md"
        issue: "Document exists and is correct -- entry in App Store Connect not yet confirmed"
    missing:
      - "User must enter title, subtitle, and keywords in App Store Connect Version page"
      - "User must confirm all fields saved"
  - truth: "App Store categories and age rating are configured correctly in App Store Connect"
    status: failed
    reason: "Categories (Health & Fitness primary, Sports secondary) and age rating (4+) are specified in APP_STORE_METADATA.md, but as with the other metadata fields, the human-verify checkpoint (Plan 03 Task 2) was not completed. No App Store Connect entry confirmed."
    artifacts:
      - path: ".planning/phases/07-app-store-metadata/APP_STORE_METADATA.md"
        issue: "Specifies correct categories and age rating -- entry in App Store Connect not confirmed"
    missing:
      - "User must set Primary Category to Health & Fitness in App Store Connect"
      - "User must set Secondary Category to Sports"
      - "User must complete age rating questionnaire (all None for 4+)"
human_verification:
  - test: "Confirm App Store Connect metadata entry"
    expected: "Title 'Tonus: Training Load Tracker', subtitle 'Recovery, ACWR & Readiness', and 97-char keyword field are saved in the App Store Connect version page for the production app"
    why_human: "App Store Connect is an external portal — cannot be verified programmatically"
  - test: "Confirm categories and age rating are set"
    expected: "Primary Category is Health & Fitness, Secondary Category is Sports, Age Rating is 4+"
    why_human: "App Store Connect configuration is not inspectable from the codebase"
  - test: "Confirm 6 composed marketing screenshots are uploaded for 6.7\" and 6.5\" sizes"
    expected: "App Store Connect shows 6 screenshots per device size, each with a caption overlay following the composition spec in APP_STORE_METADATA.md"
    why_human: "Screenshot upload state in App Store Connect cannot be verified from the codebase; image composition requires human execution of the screenshot commands"
---

# Phase 7: App Store Metadata Verification Report

**Phase Goal:** App Store listing is optimized for discoverability and conversion with polished screenshots and copy
**Verified:** 2026-04-26T12:00:00Z
**Status:** gaps_found
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | App Store title (28 chars), subtitle (27 chars), and keyword field (97 chars) are populated with targeted terms | FAILED | Copy is complete in APP_STORE_METADATA.md but Plan 03 Task 2 (human-verify checkpoint) was not completed — no confirmation of App Store Connect entry |
| 2 | App Store description clearly communicates the recovery + load tracking value proposition | VERIFIED | APP_STORE_METADATA.md contains complete description from "Train smarter. Recover better." through "Only composite scores sync to your account." — all required sections present (DAILY READINESS SCORE, TRAINING LOAD MONITORING, WORKOUT LOGGING, AUTOREGULATION, COACH MODE, PDF REPORTS) |
| 3 | Marketing screenshots with benefit-oriented captions exist for 6.7" and 6.5" device sizes | FAILED | Screenshot tests are code-complete (6 test methods in ScreenshotTests.swift) but have not been run. Existing appstore screenshots directory contains 4 old framed screenshots from before Phase 7 — not the 6-screen spec with caption overlays |
| 4 | App Store categories and age rating are configured correctly in App Store Connect | FAILED | Correctly specified in APP_STORE_METADATA.md (Health & Fitness primary, Sports secondary, 4+) but human-verify checkpoint was not completed |

**Score:** 2/4 truths verified (SC-2 fully met in the document artifact; SC-1 and SC-4 blocked on App Store Connect entry; SC-3 blocked on screenshot execution and composition)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `WorkloadApp/Services/AuthService.swift` | signInWithApple and signInWithGoogle methods | VERIFIED | Contains `func signInWithApple(credential: ASAuthorizationAppleIDCredential)`, `func signInWithGoogle()`, `noIdentityToken` and `socialSignInFailed` error cases, `signInWithIdToken`, `signInWithOAuth(provider: .google` |
| `WorkloadApp/Views/Auth/SocialLoginButtons.swift` | Reusable Apple + Google sign-in button component | VERIFIED | Contains `SignInWithAppleButton`, `.clipShape(Rectangle())`, `ColorTokens.surface`, `ColorTokens.divider`, `Font.Tokens.body` — no `RoundedRectangle`, no `.system(` |
| `WorkloadApp/Views/Auth/LoginView.swift` | Login view with social login buttons below email form | VERIFIED | Contains `SocialLoginButtons(mode: .signIn`, `handleAppleSignIn`, `handleGoogleSignIn`, `isSocialLoading`, `container.setAuthenticated(true)`, `bootstrapAthlete` |
| `WorkloadApp/Views/Auth/SignUpView.swift` | Sign-up view with social login buttons | VERIFIED | Contains `SocialLoginButtons(mode: .signUp`, `handleAppleSignIn`, `handleGoogleSignIn`, separate `SignUpSocialError` enum |
| `WorkloadApp/App/AppRouter.swift` | Google OAuth callback and COACH_MODE screenshot support | VERIFIED | Contains `session(from: url)` in `.onOpenURL`, `return` after invite code handling, `COACH_MODE` check, `container.setMode(isCoachMode ? .coach : .athlete)`, `overrideForScreenshots(isPro: true, isCoach: isCoachMode)` |
| `workload management/workload management/workload management.entitlements` | Sign in with Apple entitlement | VERIFIED | Contains `com.apple.developer.applesignin` with `Default` value |
| `workload management/workload-management-Info.plist` | URL scheme for OAuth callback | VERIFIED | Contains `CFBundleURLTypes` with `com.tonus.app` scheme |
| `workload management/ScreenshotTests/ScreenshotTests.swift` | 6 screenshot test methods | VERIFIED | Contains exactly 6 test methods: test01_Dashboard through test06_PDFExport; SCREENSHOT_MODE and COACH_MODE launch arguments; saveScreenshot helper with XCTAttachment |
| `.planning/phases/07-app-store-metadata/APP_STORE_METADATA.md` | Complete App Store Connect metadata | VERIFIED | Contains title (28 chars), subtitle (27 chars), keyword field (97 chars), full description, all 6 screenshot captions with subcaptions, composition spec with pixel dimensions, categories, age rating |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `LoginView.swift` | `AuthService.swift` | `container.authService.signInWithApple(credential:)` | WIRED | `handleAppleSignIn` calls `container.authService.signInWithApple(credential: credential)` at line 200 |
| `LoginView.swift` | `AuthService.swift` | `container.authService.signInWithGoogle()` | WIRED | `handleGoogleSignIn` calls `container.authService.signInWithGoogle()` at line 227 |
| `AppRouter.swift` | Supabase Auth | `container.supabase.auth.session(from: url)` | WIRED | `.onOpenURL` falls through to `Task { try? await container.supabase.auth.session(from: url) }` when URL is not an invite deep link |
| `AppRouter.swift` | AppContainer | COACH_MODE sets coach mode + subscription override | WIRED | `container.setMode(isCoachMode ? .coach : .athlete)` and `overrideForScreenshots(isPro: true, isCoach: isCoachMode)` both present |
| `ScreenshotTests.swift` | `AppRouter.swift` | SCREENSHOT_MODE and COACH_MODE launch arguments | WIRED | `test05_CoachRoster` uses `app.launchArguments = ["SCREENSHOT_MODE", "COACH_MODE"]` which AppRouter handles in `.task` block |

### Data-Flow Trace (Level 4)

Social auth flow data path:
- `SocialLoginButtons` calls `onAppleCredential` / `onGoogleTap` closures (not stub — callbacks passed at call site with real handlers)
- `LoginView.handleAppleSignIn` → `AuthService.signInWithApple` → `client.auth.signInWithIdToken` (real Supabase call, not hardcoded)
- `LoginView.handleGoogleSignIn` → `AuthService.signInWithGoogle` → `client.auth.signInWithOAuth` (real Supabase call)
- Bootstrap flow: `bootstrapAthlete` → `pullAll` → `setAuthenticated(true)` — identical to email auth flow

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `SocialLoginButtons.swift` | `onAppleCredential`, `onGoogleTap` | Closures from caller | Yes — LoginView/SignUpView pass real async handlers | FLOWING |
| `LoginView.swift` | `isSocialLoading`, `errorMessage` | Social auth handlers | Yes — set from real auth calls and errors | FLOWING |
| `AppRouter.swift` | `isCoachMode` | `ProcessInfo.processInfo.arguments.contains("COACH_MODE")` | Yes — reads actual process arguments | FLOWING |

### Behavioral Spot-Checks

Step 7b: Screenshot test execution requires running the iOS simulator — skipped (cannot run simulator tests without active simulator environment and signing).

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| APP_STORE_METADATA.md contains title | `grep -c "Tonus: Training Load Tracker" APP_STORE_METADATA.md` | Present | PASS |
| ScreenshotTests has 6 test methods | Count of `func test0` patterns | 6 methods (test01-test06) | PASS |
| Entitlements has Apple Sign-In | `grep "applesignin" entitlements` | Present | PASS |
| Info.plist has URL scheme | `grep "com.tonus.app" Info.plist` | Present | PASS |
| AppRouter handles COACH_MODE | `grep "COACH_MODE" AppRouter.swift` | Present, with correct logic | PASS |
| No RoundedRectangle in auth views | Pattern search across Auth/ | None found | PASS |
| No .system( font usage in SocialLoginButtons | Pattern search | None found | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| ASO-01 | 07-03-PLAN.md | App Store listing has optimized title (30 chars), subtitle (30 chars), and keyword field (100 chars) | PARTIAL | Copy is complete in APP_STORE_METADATA.md — entry in App Store Connect not confirmed |
| ASO-02 | 07-03-PLAN.md | App Store description communicates core value proposition | SATISFIED | APP_STORE_METADATA.md has complete, substantive description with all required sections |
| ASO-03 | 07-02-PLAN.md, 07-03-PLAN.md | Marketing screenshots with benefit-oriented captions for 6.7" and 6.5" device sizes | BLOCKED | Screenshot tests are code-complete but not executed; no composed marketing images exist |
| ASO-04 | 07-03-PLAN.md | App Store categories and age rating configured correctly | PARTIAL | Specified in document — App Store Connect entry not confirmed |

Note: The REQUIREMENTS.md traceability table maps ASO-01 through ASO-04 to Phase 7. No orphaned requirements for this phase.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `WorkloadApp/Views/Auth/SocialLoginButtons.swift` | 61 | `Text("G")` used as Google logo placeholder | Info | Google "G" logo is plain text, not a branded icon. Functional for App Store submission but not the polished Google brand treatment. Does not block submission. |

No blocking anti-patterns found. The `Text("G")` is noted by the plan itself as a placeholder for the branded asset but it is functional. The `.system(size: 20)` in SignUpView.swift's sport icon grid is pre-existing code (not introduced by Phase 7).

### Human Verification Required

#### 1. App Store Connect Metadata Entry

**Test:** Open App Store Connect, navigate to the Tonus app version page, and verify that the following fields contain the values from APP_STORE_METADATA.md:
- App name: "Tonus: Training Load Tracker"
- Subtitle: "Recovery, ACWR & Readiness"
- Keywords: "training load,ACWR,recovery score,HRV tracking,workout log,overtraining,readiness,coach athlete"
- Description: opens with "Train smarter. Recover better."
- Promotional text present

**Expected:** All fields populated with correct copy from APP_STORE_METADATA.md
**Why human:** App Store Connect is an external portal inaccessible to automated verification

#### 2. App Store Categories and Age Rating

**Test:** In App Store Connect > App Information, confirm:
- Primary Category: Health & Fitness
- Secondary Category: Sports
- Age Rating: 4+ (questionnaire all set to None)

**Expected:** Categories and age rating match ASO-04 specification
**Why human:** App Store Connect configuration state is not inspectable from the codebase

#### 3. Marketing Screenshots Execution and Upload

**Test:** Run the following commands, then compose and upload 6 marketing images per APP_STORE_METADATA.md composition spec:

```bash
# 6.7-inch (iPhone 15 Pro Max)
xcodebuild test \
  -project "workload management/workload management.xcodeproj" \
  -scheme "ScreenshotTests" \
  -destination "platform=iOS Simulator,name=iPhone 15 Pro Max" \
  -resultBundlePath /tmp/screenshots-6.7.xcresult

# 6.5-inch (iPhone 11 Pro Max)
xcodebuild test \
  -project "workload management/workload management.xcodeproj" \
  -scheme "ScreenshotTests" \
  -destination "platform=iOS Simulator,name=iPhone 11 Pro Max" \
  -resultBundlePath /tmp/screenshots-6.5.xcresult

# Extract
xcparse screenshots /tmp/screenshots-6.7.xcresult ~/Desktop/AppStoreScreenshots/6.7
xcparse screenshots /tmp/screenshots-6.5.xcresult ~/Desktop/AppStoreScreenshots/6.5
```

After extraction, compose 6 images per device size with captions from APP_STORE_METADATA.md screenshot table, then upload to App Store Connect.

**Expected:** 6 screenshots per device size uploaded in App Store Connect, each with caption overlay as specified
**Why human:** Screenshot test execution requires active simulators; image composition is a manual/scripted step outside codebase verification; upload to App Store Connect requires human action

### Gaps Summary

Three of four roadmap success criteria are not yet met. The phase produced all preparatory codebase artifacts (social auth, screenshot automation, metadata document) but the terminal deliverables — App Store Connect entries and actual marketing screenshot images — require human action that was gated by Plan 03's `checkpoint:human-verify` task (Task 2), which was explicitly documented as "awaiting human action."

**SC-2 (App Store description)** is verified via APP_STORE_METADATA.md — the document artifact satisfies this criterion directly since description copy is its complete deliverable.

**SC-1 (title/subtitle/keywords) and SC-4 (categories/age rating)** require the user to complete the App Store Connect entry checklist in APP_STORE_METADATA.md. This is a 15-minute manual task.

**SC-3 (marketing screenshots)** requires:
1. Running ScreenshotTests on both simulators (commands in APP_STORE_METADATA.md)
2. Composing raw screenshots with caption overlays per composition spec
3. Uploading to App Store Connect

The existing `appstore screenshots/` directory contains 4 old framed screenshots from before Phase 7 and does not satisfy ASO-03.

---

_Verified: 2026-04-26T12:00:00Z_
_Verifier: Claude (gsd-verifier)_
