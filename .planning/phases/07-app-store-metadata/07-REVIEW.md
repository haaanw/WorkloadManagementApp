---
phase: 07-app-store-metadata
reviewed: 2026-04-26T12:00:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - WorkloadApp/Services/AuthService.swift
  - WorkloadApp/Views/Auth/SocialLoginButtons.swift
  - WorkloadApp/Views/Auth/LoginView.swift
  - WorkloadApp/Views/Auth/SignUpView.swift
  - WorkloadApp/App/AppRouter.swift
  - workload management/ScreenshotTests/ScreenshotTests.swift
  - workload management/workload management/workload management.entitlements
  - workload management/workload-management-Info.plist
  - workload management/workload management.xcodeproj/project.pbxproj
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
---

# Phase 07: Code Review Report

**Reviewed:** 2026-04-26T12:00:00Z
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Reviewed auth flow (AuthService, LoginView, SignUpView, SocialLoginButtons), the app router, screenshot tests, entitlements, Info.plist, and pbxproj. The code is well-structured and follows project conventions. No critical security issues found. The OAuth redirect URL scheme is consistent between Info.plist and AuthService. The entitlements correctly declare HealthKit and Sign in with Apple capabilities. The pbxproj includes all reviewed source files.

Three warnings relate to missing client-side password validation, a silently swallowed OAuth callback error, and a design system font violation. Three info items cover code duplication and dead code.

## Warnings

### WR-01: No Client-Side Password Length Validation on Sign Up

**File:** `WorkloadApp/Views/Auth/SignUpView.swift:164-165`
**Issue:** The `isFormValid` computed property only checks `!password.isEmpty`, but the UI placeholder text says "Min. 8 characters". Supabase enforces a minimum password length server-side, but the user will see a raw Supabase error message instead of a clear, localized validation message. This creates a poor user experience and could be flagged in App Store review for misleading UI.
**Fix:**
```swift
private var isFormValid: Bool {
    !displayName.isEmpty && !email.isEmpty && password.count >= 8
}
```
Also consider showing an inline validation message when `password.count < 8 && !password.isEmpty`.

### WR-02: OAuth Callback Error Silently Swallowed

**File:** `WorkloadApp/App/AppRouter.swift:36-38`
**Issue:** The `.onOpenURL` handler uses `try?` when extracting the OAuth session from the callback URL. If Supabase fails to parse the session (e.g., expired token, malformed URL), the error is silently discarded and the user sees no feedback -- they remain on the login screen with no indication of what went wrong.
**Fix:**
```swift
Task {
    do {
        try await container.supabase.auth.session(from: url)
    } catch {
        print("OAuth callback error: \(error)")
        // Optionally surface to user via a published error state
    }
}
```

### WR-03: System Font Used in SignUpView Sport Picker

**File:** `WorkloadApp/Views/Auth/SignUpView.swift:79`
**Issue:** `.font(.system(size: 20))` is used for the sport icon, violating the DESIGN.md rule: "No system fonts (`.system()`, `.headline`, etc.)". All text must use `Font.custom("DMSans-...", size:)` via `Font.Tokens`. While this applies to an SF Symbol icon (where DM Sans would not render), the modifier should still follow the project convention or be explicitly documented as an exception.
**Fix:** For SF Symbols where the custom font does not apply, use a sized Image modifier instead:
```swift
Image(systemName: sport.systemImage)
    .imageScale(.medium)
    .frame(width: 24, height: 24)
    .foregroundStyle(selectedSport == sport ? ColorTokens.text1 : ColorTokens.text2)
```

## Info

### IN-01: Duplicated Social Auth Bootstrap Logic

**File:** `WorkloadApp/Views/Auth/LoginView.swift:196-247` and `WorkloadApp/Views/Auth/SignUpView.swift:202-252`
**Issue:** The `handleAppleSignIn` and `handleGoogleSignIn` methods are nearly identical across LoginView and SignUpView (and also duplicate the bootstrap logic in `signIn()`). This is four copies of the same fetch-athlete-or-bootstrap-then-sync flow.
**Fix:** Extract a shared helper method (e.g., on `AppContainer` or as a free function) that encapsulates the bootstrap + pullAll + setAuthenticated flow, and call it from all four locations.

### IN-02: Unused Error Case `socialSignInFailed`

**File:** `WorkloadApp/Services/AuthService.swift:84`
**Issue:** `AuthError.socialSignInFailed(String)` is defined but never thrown anywhere in the codebase. This is dead code.
**Fix:** Remove the case if it is not planned for future use, or add a `// TODO:` comment if it is intentionally reserved.

### IN-03: Duplicate Error Enum Definitions

**File:** `WorkloadApp/Views/Auth/LoginView.swift:250-259` and `WorkloadApp/Views/Auth/SignUpView.swift:255-264`
**Issue:** `AuthBootstrapError` and `SignUpSocialError` are separate private enums with identical cases (`noUserId`, `athleteNotFound`) and identical error descriptions. This duplication increases maintenance burden.
**Fix:** Define a single shared error enum (e.g., `SocialAuthError`) accessible to both views.

---

_Reviewed: 2026-04-26T12:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
