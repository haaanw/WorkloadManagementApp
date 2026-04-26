# Phase 7: App Store Metadata - Research

**Researched:** 2026-04-26
**Domain:** App Store optimization (ASO), social authentication (Apple + Google via Supabase), screenshot automation
**Confidence:** HIGH

## Summary

Phase 7 spans two distinct work streams: (1) App Store listing optimization -- title, subtitle, keywords, description, screenshots, categories, and age rating; and (2) social login integration -- Apple Sign-In (mandatory per App Review) and Google Sign-In via Supabase Auth. The UI spec is already approved with complete copy, screenshot compositions, and component specs.

The authentication work is the technically significant part. Apple Sign-In uses the native `AuthenticationServices` framework (already an Apple framework, no SPM addition) with Supabase's `signInWithIdToken`. Google Sign-In uses Supabase's `signInWithOAuth(provider: .google)` which leverages `ASWebAuthenticationSession` -- also no new SPM package, consistent with the v1.1 "zero new SPM packages" decision. Both require Supabase dashboard configuration and Xcode project changes (entitlements, URL schemes).

The screenshot work builds on the existing `ScreenshotTests.swift` XCUITest infrastructure and `SCREENSHOT_MODE` launch argument. The tests need updating to capture the 6 specific screens defined in the UI spec, and must run on two simulator sizes (6.7" and 6.5"). Screenshot composition (adding captions to raw captures) is a separate post-processing step.

**Primary recommendation:** Implement Apple Sign-In first (it touches entitlements and is an App Review requirement), then Google Sign-In (simpler OAuth redirect), then update screenshot tests, and finally prepare the App Store Connect metadata as the last task.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- D-01: Data-driven athlete tone -- technical, performance-focused. Target serious lifters, runners, and coaches who recognize training load terminology.
- D-02: Claude's discretion on metric specificity -- recommended approach: lead with benefits/outcomes, mention ACWR/HRV/EWMA in feature detail section for credibility.
- D-03: Primary keyword focus is workload management -- "training load", "ACWR", "overtraining prevention", "workload tracking". Niche but high-intent athletes.
- D-04: Claude's discretion on competitor name targeting in keyword field.
- D-05: 6 screenshots -- Dashboard (hero readiness), Workload charts, Recovery view, Workout log, Coach roster, PDF export.
- D-06: Benefit-oriented captions -- outcome-focused phrases.
- D-07: Screenshots for both 6.7" and 6.5" device sizes.
- D-08: Primary category: Health & Fitness. Secondary category: Claude's discretion (Sports likely).
- D-09: Age rating: 4+ (no objectionable content).
- D-10: Add Apple Sign-In -- mandatory per App Review. Use Supabase Auth Apple provider.
- D-11: Add Google Sign-In -- use Supabase Auth Google provider. Requires GoogleService-Info.plist.
- D-12: Keep existing email/password authentication -- social logins supplement, don't replace.
- D-13: Login/SignUp views need updating to show all three auth options.

### Claude's Discretion
- Metric specificity in description (D-02)
- Competitor names in keywords (D-04)
- Secondary App Store category (D-08)
- Screenshot caption exact wording
- Social login button ordering and styling (follow Apple HIG for Sign in with Apple placement)

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ASO-01 | App Store listing has optimized title (30 chars), subtitle (30 chars), and keyword field (100 chars) | UI spec provides final copy: "Tonus: Training Load Tracker" (28 chars), "Recovery, ACWR & Readiness" (27 chars), keyword field at 97 chars. All within limits. |
| ASO-02 | App Store description communicates core value proposition | UI spec contains full description copy. Benefits-first structure with technical detail (ACWR, EWMA) for credibility. |
| ASO-03 | Marketing screenshots with benefit-oriented captions for 6.7" and 6.5" device sizes | Existing ScreenshotTests.swift needs updating for 6 specific screens. Caption composition is a post-processing step using the UI spec's exact copy and layout. |
| ASO-04 | App Store categories and age rating configured correctly | Health & Fitness primary, Sports secondary, 4+ age rating. Manual configuration in App Store Connect. |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Apple Sign-In | API / Backend (Supabase Auth) | Client (AuthenticationServices UI) | Supabase validates the Apple ID token server-side; the client only collects the credential |
| Google Sign-In | API / Backend (Supabase Auth) | Client (ASWebAuthenticationSession) | Supabase handles the full OAuth redirect flow; the client presents the web auth session |
| Auth UI (social buttons) | Browser / Client | -- | SwiftUI views render buttons, delegate to AuthService |
| Auth callback routing | Browser / Client | -- | AppRouter.onOpenURL handles deep link callback from Google OAuth |
| Screenshot capture | Browser / Client | -- | XCUITest runs in simulator, captures screens |
| Screenshot composition | Build tooling (offline) | -- | Post-processing adds captions to raw screenshots (can be done manually or scripted) |
| App Store metadata | CDN / Static (App Store Connect) | -- | Title, subtitle, keywords, description entered in App Store Connect portal |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| AuthenticationServices | iOS 17+ | Native Sign in with Apple button + credential | Apple framework, mandatory for compliant Apple Sign-In UI [VERIFIED: Apple SDK] |
| Supabase Swift SDK | >= 2.5.1 | `signInWithIdToken` (Apple), `signInWithOAuth` (Google) | Already in project, handles all auth server-side [VERIFIED: pbxproj] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| XCTest / XCUITest | Xcode bundled | Screenshot automation | Capture app screens for App Store marketing [VERIFIED: existing ScreenshotTests.swift] |
| xcparse | brew install | Extract screenshots from xcresult | CLI tool to pull images from test results [ASSUMED] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Supabase OAuth for Google | GoogleSignIn-iOS SDK (native) | Native SDK gives a smoother UX but adds a new SPM dependency -- violates v1.1 "zero new SPM packages" decision |
| xcparse for extraction | xcrun xcresulttool | xcresulttool is Apple-native but more complex CLI; xcparse is simpler but external |

**No new SPM packages required.** AuthenticationServices is an Apple framework (just needs `import`). Google Sign-In uses Supabase's `signInWithOAuth` which delegates to `ASWebAuthenticationSession` (also Apple framework). [VERIFIED: Supabase docs]

## Architecture Patterns

### System Architecture Diagram

```
                    LoginView / SignUpView
                         |
              +----------+----------+
              |          |          |
        Email/Pass   Apple SI   Google SI
              |          |          |
              v          v          v
         AuthService  AuthService  AuthService
         .signIn()   .signInWith  .signInWith
                      Apple()     Google()
              |          |          |
              v          v          v
         Supabase    Supabase    Supabase
         Auth        Auth        Auth
         (email)     (idToken)   (OAuth)
              |          |          |
              +----------+----------+
                         |
                    Auth Session
                         |
                    AppRouter
                    (bootstrap Athlete,
                     sync, navigate)
```

### Recommended Changes to Existing Files

```
WorkloadApp/
  Services/
    AuthService.swift        # ADD: signInWithApple(), signInWithGoogle()
  Views/Auth/
    LoginView.swift          # ADD: social login buttons below email form
    SignUpView.swift          # ADD: social login buttons below create account
    SocialLoginButtons.swift # NEW: shared Apple + Google button components
  App/
    AppRouter.swift          # ADD: .onOpenURL handler for Google OAuth callback
                             # ADD: COACH_MODE launch argument handler for screenshots
    AppContainer.swift       # No changes needed (AuthService already injected)

workload management/
  workload management/
    workload management.entitlements  # ADD: Sign in with Apple capability
  workload-management-Info.plist      # ADD: CFBundleURLTypes for OAuth callback
  ScreenshotTests/
    ScreenshotTests.swift             # UPDATE: 6 specific screens per UI spec
```

### Pattern 1: Apple Sign-In via Supabase signInWithIdToken
**What:** Use `ASAuthorizationAppleIDProvider` to get an Apple ID credential, extract the identity token, pass it to Supabase's `signInWithIdToken`
**When to use:** Sign in with Apple button tap
**Example:**
```swift
// Source: https://supabase.com/docs/guides/auth/social-login/auth-apple
import AuthenticationServices

func signInWithApple() async throws {
    // 1. Request Apple credential (via ASAuthorizationController)
    let appleIDCredential = try await performAppleSignIn()

    // 2. Extract identity token
    guard let identityTokenData = appleIDCredential.identityToken,
          let idToken = String(data: identityTokenData, encoding: .utf8) else {
        throw AuthError.noIdentityToken
    }

    // 3. Pass to Supabase
    try await client.auth.signInWithIdToken(
        credentials: .init(provider: .apple, idToken: idToken)
    )

    // 4. Save user metadata (Apple only provides name on first sign-in)
    if let fullName = appleIDCredential.fullName {
        let name = [fullName.givenName, fullName.familyName]
            .compactMap { $0 }.joined(separator: " ")
        if !name.isEmpty {
            try await client.auth.update(
                user: UserAttributes(data: ["display_name": .string(name)])
            )
        }
    }
}
```

### Pattern 2: Google Sign-In via Supabase signInWithOAuth
**What:** Use Supabase's built-in OAuth flow which opens `ASWebAuthenticationSession` for Google login
**When to use:** Sign in with Google button tap
**Example:**
```swift
// Source: https://supabase.com/docs/reference/swift/auth-signinwithoauth
func signInWithGoogle() async throws {
    try await client.auth.signInWithOAuth(
        provider: .google,
        redirectTo: URL(string: "com.tonus.app://login-callback")
    ) { (session: ASWebAuthenticationSession) in
        session.prefersEphemeralWebBrowserSession = false
    }
}
```

### Pattern 3: ASAuthorizationController Delegate in SwiftUI
**What:** Bridge Apple's delegate-based `ASAuthorizationController` to async/await for use in AuthService
**When to use:** Wrapping the Apple Sign-In credential request
**Example:**
```swift
// Source: Apple AuthenticationServices documentation [ASSUMED]
// Use a Coordinator or continuation pattern to bridge delegate to async
func performAppleSignIn() async throws -> ASAuthorizationAppleIDCredential {
    try await withCheckedThrowingContinuation { continuation in
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        let delegate = AppleSignInDelegate(continuation: continuation)
        controller.delegate = delegate
        controller.performRequests()
    }
}
```

### Anti-Patterns to Avoid
- **Storing Apple identity token locally:** The identity token is single-use for Supabase auth. Never cache it. Supabase manages the session after sign-in.
- **Using GoogleSignIn-iOS SDK:** Adds unnecessary SPM dependency when Supabase's OAuth flow handles Google natively via web session.
- **Skipping name capture on Apple Sign-In:** Apple only provides the user's full name on the FIRST sign-in. If you miss it, you can never get it again without the user revoking and re-authorizing.
- **Hardcoding Google "G" logo colors:** The UI spec says use `ColorTokens.surface` background with design system colors, not Google brand colors. The logo asset itself is the official Google "G" but the button frame follows the app's design system.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Apple Sign-In token exchange | Custom JWT parsing | `client.auth.signInWithIdToken(provider: .apple)` | Supabase handles nonce validation, token verification, user creation |
| Google OAuth flow | Custom OAuth redirect handling | `client.auth.signInWithOAuth(provider: .google)` | Supabase manages state, PKCE, token exchange via ASWebAuthenticationSession |
| Screenshot extraction from xcresult | Manual Finder navigation | `xcparse screenshots` CLI | xcresult bundles have complex internal structure |
| App Store screenshot composition | Photoshop/manual layout | SwiftUI preview or simple script | Captions on screenshots can be automated but manual is acceptable for 12 images |

**Key insight:** Both social login flows are handled almost entirely by Supabase Auth server-side. The client-side work is minimal: collect credential (Apple) or trigger OAuth (Google), then call one Supabase method. The heavy lifting (token validation, user account creation/linking, session management) happens server-side.

## Common Pitfalls

### Pitfall 1: Apple Sign-In entitlement missing
**What goes wrong:** App crashes or Apple Sign-In button doesn't appear
**Why it happens:** "Sign in with Apple" capability must be added to both the Xcode project entitlements file AND enabled in the Apple Developer portal for the App ID
**How to avoid:** Add `com.apple.developer.applesignin` to entitlements plist AND enable the capability in Apple Developer > Certificates, Identifiers & Profiles > App ID
**Warning signs:** Build succeeds but Apple button does nothing at runtime

### Pitfall 2: Apple only provides user name once
**What goes wrong:** User's display name is empty/nil on subsequent sign-ins
**Why it happens:** Apple sends `fullName` only on the FIRST authorization. After that, it sends nil.
**How to avoid:** Capture and store the name in Supabase user metadata immediately during the first sign-in. The code example above shows this pattern.
**Warning signs:** New user's displayName is nil after social sign-in

### Pitfall 3: Google OAuth callback URL not registered
**What goes wrong:** After Google login completes in browser, app doesn't receive the callback
**Why it happens:** The redirect URL scheme must be registered in (a) Info.plist CFBundleURLTypes, (b) Supabase dashboard redirect allow list, and (c) AppRouter's `.onOpenURL` handler
**How to avoid:** Configure all three: Info.plist, Supabase dashboard, and AppRouter
**Warning signs:** Google auth opens browser, user authenticates, but gets stuck on a blank page

### Pitfall 4: Social sign-in creates duplicate accounts
**What goes wrong:** User signs up with email, then later tries Apple/Google sign-in with same email -- gets a different account
**Why it happens:** Supabase can handle automatic linking if configured, but default behavior varies
**How to avoid:** Enable "Automatically confirm email for OAuth sign ups" in Supabase Auth settings. Supabase will link accounts with the same verified email. [ASSUMED -- verify in Supabase dashboard]
**Warning signs:** User reports losing their data after switching sign-in method

### Pitfall 5: Screenshot tests capture wrong screens
**What goes wrong:** Screenshots show empty states, loading spinners, or wrong tabs
**Why it happens:** `SCREENSHOT_MODE` seeds data but async loading may not complete before capture
**How to avoid:** Use explicit `sleep()` waits (already in existing tests) and verify tab bar state before capture. Ensure `MockDataSeeder` provides data for all 6 required screens including coach roster and PDF export views.
**Warning signs:** Screenshots show "No data yet" cards instead of populated views

### Pitfall 6: Missing Athlete bootstrap after social sign-in
**What goes wrong:** User signs in via Apple/Google but app shows empty state or crashes
**Why it happens:** Social sign-in creates a Supabase auth user but no Athlete row in the database
**How to avoid:** After social auth succeeds, run the same bootstrap logic as email sign-in: check for local Athlete, bootstrap from Supabase if missing, run sync.pullAll
**Warning signs:** Auth succeeds but DashboardView shows nothing or crashes on nil Athlete

## Code Examples

### Adding Sign in with Apple Entitlement
```xml
<!-- Source: Apple Developer documentation [VERIFIED: entitlements file structure] -->
<!-- Add to: workload management/workload management/workload management.entitlements -->
<key>com.apple.developer.applesignin</key>
<array>
    <string>Default</string>
</array>
```

### Adding URL Scheme for Google OAuth Callback
```xml
<!-- Source: https://supabase.com/docs/guides/auth/native-mobile-deep-linking [CITED] -->
<!-- Add to: workload management/workload-management-Info.plist -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.tonus.app</string>
        </array>
    </dict>
</array>
```

### AppRouter onOpenURL for Google OAuth Callback
```swift
// Source: Supabase deep linking docs [CITED: supabase.com/docs/guides/auth/native-mobile-deep-linking]
// Add to AppRouter.body, alongside existing .onOpenURL
.onOpenURL { url in
    // Existing invite deep link handling
    if let code = InviteService.handleDeepLink(url) {
        pendingInviteCode = PendingInvite(code: code)
        return
    }
    // Google OAuth callback -- Supabase handles session extraction
    Task {
        try? await container.supabase.auth.session(from: url)
    }
}
```

### SignInWithAppleButton in SwiftUI
```swift
// Source: Apple AuthenticationServices framework [VERIFIED: Apple SDK]
import AuthenticationServices

SignInWithAppleButton(.signIn) { request in
    request.requestedScopes = [.fullName, .email]
} onCompletion: { result in
    switch result {
    case .success(let authorization):
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
        Task { await handleAppleSignIn(credential: credential) }
    case .failure(let error):
        errorMessage = error.localizedDescription
    }
}
.signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
.frame(height: 48)
.clipShape(Rectangle()) // 0pt corner radius per DESIGN.md
```

### Updated Screenshot Test Structure
```swift
// Source: Existing ScreenshotTests.swift pattern [VERIFIED: codebase]
// Tests need to capture these 6 screens per UI spec:
// 1. Dashboard (hero readiness) -- tab: Home
// 2. Workload charts -- tab: Load
// 3. Recovery view -- tab: Recovery
// 4. Workout log -- tab: Log
// 5. Coach roster -- requires mode switch to .coach via COACH_MODE launch argument
// 6. PDF export -- requires navigation to export feature
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Google Sign-In required GoogleSignIn-iOS SDK | Supabase `signInWithOAuth` uses ASWebAuthenticationSession | Supabase Swift SDK 2.x | No third-party SDK needed for Google auth |
| Apple Sign-In issuer was `appleid.apple.com` | Issuer changed to `account.apple.com` | Mid-2025 | Supabase Auth v2.177.0+ handles both; ensure Supabase project is updated |
| Screenshot extraction required manual xcresult navigation | `xcparse` CLI extracts directly | Stable since 2023 | Simple one-command extraction |

**Deprecated/outdated:**
- GoogleSignIn-iOS SDK for Supabase projects: unnecessary when using `signInWithOAuth` [CITED: supabase.com/docs/reference/swift/auth-signinwithoauth]
- D-11 mentions "Requires GoogleService-Info.plist" -- this is NOT needed when using Supabase OAuth redirect flow. GoogleService-Info.plist is only required when using the native GoogleSignIn-iOS SDK. [VERIFIED: Supabase docs show OAuth approach needs no Google SDK or plist]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Supabase auto-links accounts with same verified email across providers | Pitfall 4 | Users could end up with duplicate accounts; needs dashboard verification |
| A2 | `ASAuthorizationController` can be bridged to async/await via continuation | Pattern 3 | May need a different delegate pattern; low risk since this is well-documented |
| A3 | xcparse CLI is available or installable via brew | Standard Stack | Could use xcrun xcresulttool as fallback; low impact |
| A4 | Coach roster and PDF export views are accessible in SCREENSHOT_MODE | Pitfall 5 | MockDataSeeder may need updates to seed coach relationships and PDF-related data |
| A5 | Supabase project is running Auth >= v2.177.0 (Apple issuer fix) | State of the Art | Apple Sign-In could fail with OIDC issuer mismatch if Supabase project is on older auth version |

## Open Questions (RESOLVED)

1. **Supabase dashboard: Apple provider configured?**
   - What we know: Apple Sign-In requires the App ID (com.tonus.app) to be registered in Supabase Auth > Providers > Apple
   - What's unclear: Whether this has already been configured in the Supabase project
   - Recommendation: User must verify/configure in Supabase dashboard before implementing
   - RESOLVED: Surfaced as `user_setup` in Plan 01. User will configure Apple provider in Supabase dashboard as a prerequisite before execution. Plan cannot verify this programmatically -- it is a human-action prerequisite.

2. **Supabase dashboard: Google provider configured?**
   - What we know: Google OAuth requires a Google Cloud OAuth client ID in Supabase Auth > Providers > Google, plus redirect URL allowlist
   - What's unclear: Whether Google OAuth credentials exist for this project
   - Recommendation: User must create Google Cloud OAuth client and configure in Supabase dashboard
   - RESOLVED: Surfaced as `user_setup` in Plan 01. User will create Google Cloud OAuth client ID and configure in Supabase dashboard as a prerequisite. Plan cannot verify this programmatically -- it is a human-action prerequisite.

3. **Apple Developer portal: Sign in with Apple capability enabled?**
   - What we know: Entitlements file currently only has HealthKit
   - What's unclear: Whether the App ID has Sign in with Apple enabled in Apple Developer portal
   - Recommendation: User must enable in Certificates, Identifiers & Profiles > App IDs
   - RESOLVED: Surfaced as `user_setup` in Plan 01. Plan 01 Task 1 adds the entitlement to the Xcode project file. User must also enable the capability in Apple Developer portal as a prerequisite.

4. **Coach roster screenshot in SCREENSHOT_MODE**
   - What we know: Current SCREENSHOT_MODE sets athlete mode and seeds athlete data
   - What's unclear: Whether MockDataSeeder creates CoachAthleteRelationship records for the coach roster view
   - Recommendation: May need to extend MockDataSeeder or add a second screenshot run in coach mode
   - RESOLVED: Plan 01 Task 1 adds COACH_MODE launch argument handling to AppRouter.swift. When SCREENSHOT_MODE and COACH_MODE are both present, AppRouter calls `container.setMode(.coach)` and `container.subscriptionService.overrideForScreenshots(isPro: true, isCoach: true)`. Plan 02 screenshot test05_CoachRoster terminates and relaunches with both flags. MockDataSeeder already seeds athlete data; coach roster will show the seeded athlete in the roster view.

5. **GoogleService-Info.plist: NOT needed?**
   - What we know: D-11 in CONTEXT.md mentions GoogleService-Info.plist, but Supabase OAuth flow doesn't require it
   - What's unclear: Whether user specifically wants native Google SDK (which needs plist) or Supabase OAuth (which doesn't)
   - Recommendation: Use Supabase OAuth approach -- no GoogleService-Info.plist, no new SPM package. Aligns with "zero new SPM packages" decision.
   - RESOLVED: Using Supabase `signInWithOAuth(provider: .google)` which delegates to `ASWebAuthenticationSession`. No GoogleService-Info.plist needed, no new SPM package. D-11 mention of GoogleService-Info.plist was based on native SDK approach; Supabase OAuth approach supersedes this. Verified in Supabase docs.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | Build + screenshots | Assumed | -- | -- |
| iPhone 15 Pro Max simulator | 6.7" screenshots | Assumed | -- | Any 6.7" device simulator |
| iPhone 11 Pro Max simulator | 6.5" screenshots | Needs verification | -- | Install via Xcode > Platforms |
| xcparse | Screenshot extraction | Needs install | -- | `xcrun xcresulttool` (more complex) |
| App Store Connect access | Metadata entry | Assumed | -- | -- |
| Apple Developer account | Sign in with Apple capability | Assumed | -- | -- |
| Google Cloud Console | OAuth client ID | Needs verification | -- | Cannot do Google Sign-In without it |

**Missing dependencies with no fallback:**
- Google Cloud OAuth client ID (blocks Google Sign-In implementation)
- Apple Developer portal Sign in with Apple capability (blocks Apple Sign-In)

**Missing dependencies with fallback:**
- xcparse: can use xcrun xcresulttool instead
- iPhone 11 Pro Max simulator: can install via Xcode

## Project Constraints (from CLAUDE.md)

- **Zero new SPM packages for v1.1** -- Google Sign-In MUST use Supabase OAuth, not GoogleSignIn-iOS SDK
- **Design system compliance** -- 0pt border radius, no shadows, DM Sans only, 8pt grid, accent only on hero readiness score
- **Incremental build verification** -- after every 3-5 files, run xcodebuild to verify
- **Xcode project verification** -- after generating Swift files, verify .pbxproj includes them (though with PBXFileSystemSynchronizedRootGroup, new files in existing directories should auto-include)
- **HealthKit raw data never uploaded** -- not directly relevant but important context for any new auth-related data flows
- **External service UI caveat** -- Supabase dashboard and App Store Connect instructions should note UI may differ

## Sources

### Primary (HIGH confidence)
- [Supabase Auth - Apple Sign-In](https://supabase.com/docs/guides/auth/social-login/auth-apple) - signInWithIdToken flow, dashboard config
- [Supabase Auth - Google Sign-In](https://supabase.com/docs/guides/auth/social-login/auth-google) - OAuth flow, nonce skip, client ID config
- [Supabase Swift - signInWithOAuth](https://supabase.com/docs/reference/swift/auth-signinwithoauth) - ASWebAuthenticationSession integration
- [Supabase - Native Mobile Deep Linking](https://supabase.com/docs/guides/auth/native-mobile-deep-linking) - URL scheme setup, callback handling
- Codebase verified: AuthService.swift, LoginView.swift, SignUpView.swift, AppRouter.swift, AppContainer.swift, ScreenshotTests.swift, entitlements file, Info.plist, pbxproj

### Secondary (MEDIUM confidence)
- [Supabase Swift - signInWithIdToken](https://supabase.com/docs/reference/swift/auth-signinwithidtoken) - Apple ID token method signature

### Tertiary (LOW confidence)
- xcparse availability and current version (not verified against brew registry)
- Apple OIDC issuer migration status for this specific Supabase project

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already in project or are Apple frameworks; no new dependencies
- Architecture: HIGH - Auth patterns well-documented by Supabase; existing codebase patterns clear
- Pitfalls: HIGH - Well-known issues with Apple Sign-In name capture, OAuth callbacks, duplicate accounts
- Screenshot automation: MEDIUM - Existing infrastructure works but coach mode + PDF export screenshots may need MockDataSeeder updates

**Research date:** 2026-04-26
**Valid until:** 2026-05-26 (stable domain, Supabase SDK pinned)
