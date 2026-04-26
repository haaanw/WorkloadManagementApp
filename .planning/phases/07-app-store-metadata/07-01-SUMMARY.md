---
phase: 07-app-store-metadata
plan: 01
subsystem: auth
tags: [apple-sign-in, google-oauth, supabase-auth, social-login, ASWebAuthenticationSession]

# Dependency graph
requires:
  - phase: 02-analytics-export
    provides: Supabase Auth with email/password, AuthService, LoginView, SignUpView
provides:
  - Apple Sign-In via Supabase signInWithIdToken
  - Google Sign-In via Supabase OAuth with ASWebAuthenticationSession
  - SocialLoginButtons reusable component
  - OAuth callback URL handling in AppRouter
  - COACH_MODE screenshot launch argument support
affects: [07-app-store-metadata, app-store-review]

# Tech tracking
tech-stack:
  added: [AuthenticationServices (SignInWithAppleButton, ASWebAuthenticationSession)]
  patterns: [social auth bootstrap mirrors email auth flow, OAuth callback via onOpenURL]

key-files:
  created:
    - WorkloadApp/Views/Auth/SocialLoginButtons.swift
  modified:
    - WorkloadApp/Services/AuthService.swift
    - WorkloadApp/Views/Auth/LoginView.swift
    - WorkloadApp/Views/Auth/SignUpView.swift
    - WorkloadApp/App/AppRouter.swift
    - workload management/workload management/workload management.entitlements
    - workload management/workload-management-Info.plist
    - workload management/workload management.xcodeproj/project.pbxproj

key-decisions:
  - "Used Supabase signInWithIdToken for Apple (server-side token validation) and signInWithOAuth for Google (browser-based OAuth flow)"
  - "Social auth bootstrap uses same pattern as email sign-in (not sign-up) since Supabase auto-creates accounts for social providers"
  - "COACH_MODE is a sub-flag of SCREENSHOT_MODE -- both must be present for coach screenshot automation"

patterns-established:
  - "Social auth bootstrap: authenticate -> check local athletes -> bootstrap from Supabase if needed -> pullAll -> setAuthenticated"
  - "OAuth callback: onOpenURL checks invite deep link first, then falls through to Supabase session(from:)"

requirements-completed: []

# Metrics
duration: 6min
completed: 2026-04-26
---

# Phase 7 Plan 1: Social Auth Summary

**Apple Sign-In and Google Sign-In via Supabase Auth with SocialLoginButtons component and COACH_MODE screenshot support**

## Performance

- **Duration:** 6 min
- **Started:** 2026-04-26T09:03:49Z
- **Completed:** 2026-04-26T09:10:09Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- AuthService extended with signInWithApple (ID token) and signInWithGoogle (OAuth) methods
- SocialLoginButtons component renders Apple and Google sign-in buttons per design system (0pt corners, ColorTokens, 8pt grid)
- LoginView and SignUpView both integrate social login with identical bootstrap flow as email auth
- AppRouter handles Google OAuth callback and COACH_MODE launch argument for screenshot automation
- Entitlements and Info.plist configured for Apple Sign-In capability and OAuth URL scheme

## Task Commits

Each task was committed atomically:

1. **Task 1: Add social auth methods to AuthService + config files + COACH_MODE support** - `665524d` (feat)
2. **Task 2: Create SocialLoginButtons component and update LoginView + SignUpView** - `399f96a` (feat)

## Files Created/Modified
- `WorkloadApp/Services/AuthService.swift` - signInWithApple, signInWithGoogle methods, noIdentityToken/socialSignInFailed error cases
- `WorkloadApp/Views/Auth/SocialLoginButtons.swift` - Reusable Apple + Google sign-in buttons with OR divider
- `WorkloadApp/Views/Auth/LoginView.swift` - Social login integration with handleAppleSignIn/handleGoogleSignIn
- `WorkloadApp/Views/Auth/SignUpView.swift` - Social login integration (same bootstrap as sign-in)
- `WorkloadApp/App/AppRouter.swift` - OAuth callback in onOpenURL, COACH_MODE in SCREENSHOT_MODE block
- `workload management/workload management/workload management.entitlements` - com.apple.developer.applesignin
- `workload management/workload-management-Info.plist` - CFBundleURLTypes with com.tonus.app scheme
- `workload management/workload management.xcodeproj/project.pbxproj` - SocialLoginButtons.swift added to Auth group

## Decisions Made
- Used Supabase signInWithIdToken for Apple (server validates token) and signInWithOAuth for Google (browser OAuth flow) -- no new SPM dependencies needed
- Social auth from SignUpView uses the sign-in bootstrap pattern (not the sign-up pattern) because Supabase automatically creates accounts for social providers
- Apple fullName capture uses try? since it only arrives on first sign-in and is non-critical
- Created separate SignUpSocialError enum in SignUpView to avoid cross-file dependency on LoginView's private AuthBootstrapError

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added SocialLoginButtons.swift to Xcode project file**
- **Found during:** Task 2
- **Issue:** Plan did not specify pbxproj changes -- new Swift file would not compile without project membership
- **Fix:** Added PBXBuildFile, PBXFileReference, Auth group membership, and Sources build phase entry
- **Files modified:** workload management/workload management.xcodeproj/project.pbxproj
- **Verification:** xcodebuild succeeds
- **Committed in:** 399f96a (Task 2 commit)

**2. [Rule 2 - Missing Critical] Created SignUpSocialError enum for SignUpView**
- **Found during:** Task 2
- **Issue:** AuthBootstrapError is private to LoginView.swift -- SignUpView cannot reference it
- **Fix:** Created parallel SignUpSocialError enum with same cases in SignUpView.swift
- **Files modified:** WorkloadApp/Views/Auth/SignUpView.swift
- **Verification:** xcodebuild succeeds
- **Committed in:** 399f96a (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 missing critical)
**Impact on plan:** Both fixes necessary for compilation. No scope creep.

## Issues Encountered
- Simulator name changed from "iPhone 16 Pro Max" to "iPhone 17 Pro Max" -- adjusted xcodebuild destination accordingly

## User Setup Required
External services require manual configuration before social auth works at runtime:
- **Apple Developer Portal:** Enable Sign in with Apple capability for app ID
- **Supabase Dashboard:** Enable Apple and Google auth providers, add redirect URL
- **Google Cloud Console:** Create OAuth 2.0 client ID for iOS

## Next Phase Readiness
- Social auth UI is wired and compiles -- ready for Plans 02/03 (screenshots, metadata)
- COACH_MODE launch argument enables Plan 02 to capture coach roster screenshots
- Runtime testing requires Supabase provider configuration (see User Setup above)

---
*Phase: 07-app-store-metadata*
*Completed: 2026-04-26*
