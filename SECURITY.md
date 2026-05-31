# Security Audit Report

**Project:** Tonus (WorkloadApp)
**Phase:** 07 — App Store Metadata
**ASVS Level:** 1
**Audit Date:** 2026-04-26
**Auditor:** gsd-security-auditor

---

## Summary

**Threats Closed:** 8/8
**Threats Open:** 0/8
**Unregistered Flags:** None

All mitigations are implemented and all accepted risks are documented below. Phase 07 is SECURED.

---

## Threat Verification

| Threat ID | Category | Disposition | Status | Evidence |
|-----------|----------|-------------|--------|----------|
| T-07-01 | Spoofing | mitigate | CLOSED | `AuthService.swift:55` — Apple ID token passed directly to `client.auth.signInWithIdToken(credentials: .init(provider: .apple, idToken: idToken))`; no client-side trust, Supabase validates nonce/signature/issuer server-side |
| T-07-02 | Spoofing | mitigate | CLOSED | `AuthService.swift:73` — Google sign-in uses `client.auth.signInWithOAuth(provider: .google, ...)` via Supabase SDK; no custom token parsing; PKCE and state managed by Supabase |
| T-07-03 | Information Disclosure | mitigate | CLOSED | `AuthService.swift:49-68` — identity token extracted from `credential.identityToken`, passed immediately to `signInWithIdToken`, never assigned to a stored property, never logged or cached |
| T-07-04 | Elevation of Privilege | mitigate | CLOSED | `AppRouter.swift:30-38` — `onOpenURL` passes callback URL to `container.supabase.auth.session(from: url)`; Supabase validates state parameter; URL scheme `com.tonus.app://` registered in `workload-management-Info.plist` |
| T-07-05 | Spoofing | accept | CLOSED | See Accepted Risks log below |
| T-07-06 | Denial of Service | accept | CLOSED | See Accepted Risks log below |
| T-07-07 | Information Disclosure | accept | CLOSED | See Accepted Risks log below |
| T-07-08 | Tampering | accept | CLOSED | See Accepted Risks log below |

---

## Accepted Risks Log

### T-07-05 — Account Linking (Spoofing)
**Component:** Supabase account auto-linking
**Risk:** Supabase auto-links accounts sharing the same verified email address. An attacker who controls a social identity provider account sharing an email with an existing Tonus user could gain access to that account.
**Rationale for acceptance:** Email verification is required by Supabase before linking. The risk is low because: (1) the attacker must control a verified social provider account for the target email, (2) social provider email verification is a prerequisite enforced by Apple/Google, not by Tonus. This is standard industry practice for social login.
**Owner:** Supabase Auth (transfer of responsibility to provider)
**Review trigger:** If Supabase changes its auto-link behavior or a linking bypass is disclosed.

### T-07-06 — Social Login Rate Limiting (Denial of Service)
**Component:** SocialLoginButtons (Apple/Google auth buttons)
**Risk:** A bot or adversarial client could hammer the social login endpoints.
**Rationale for acceptance:** Rate limiting for Apple Sign-In and Google OAuth is enforced at the provider level (Apple servers, Google OAuth servers). The app does not control these limits. No additional app-side rate limiting is required at ASVS Level 1.
**Owner:** Apple / Google auth infrastructure
**Review trigger:** If provider-level rate limits are removed or if app-side abuse patterns emerge.

### T-07-07 — Screenshot Test Data Exposure (Information Disclosure)
**Component:** `ScreenshotTests/ScreenshotTests.swift`
**Risk:** Automated screenshot tests could capture or expose real user data if run against a live environment.
**Rationale for acceptance:** Screenshot tests use the `SCREENSHOT_MODE` launch argument, which is gated behind `#if DEBUG` in `AppRouter.swift`. In `SCREENSHOT_MODE`, `MockDataSeeder` seeds entirely synthetic data and real authentication is bypassed (`container.setAuthenticated(true)` without a Supabase session). No real user data is ever accessible in this code path. The `ScreenshotTests` target is never included in a distribution build.
**Evidence:** `AppRouter.swift:53-80` — full SCREENSHOT_MODE block within `#if DEBUG`; `ScreenshotTests.swift:16-22` — `launchArguments = ["SCREENSHOT_MODE"]`
**Owner:** Development team (build configuration)
**Review trigger:** If the ScreenshotTests target is accidentally added to the distribution scheme, or if SCREENSHOT_MODE behavior is modified to accept real credentials.

### T-07-08 — App Store Metadata Tampering (Tampering)
**Component:** App Store Connect metadata (`.planning/phases/07-app-store-metadata/APP_STORE_METADATA.md`)
**Risk:** Marketing copy in App Store Connect could be modified by an unauthorized party or contain misleading claims.
**Rationale for acceptance:** App Store metadata is public-facing marketing copy with no security implications for data confidentiality, integrity of user data, or system access. All submitted metadata is reviewed by Apple before publication. Unauthorized modification requires App Store Connect account compromise, which is outside the app's threat surface.
**Owner:** Apple App Store review process
**Review trigger:** If App Store Connect account credentials are compromised.

---

## Unregistered Threat Flags

None. No `## Threat Flags` sections were present in any Phase 07 SUMMARY files (07-01-SUMMARY.md, 07-02-SUMMARY.md, 07-03-SUMMARY.md).

---

## Notes

- This audit covers Phase 07 (App Store Metadata) only. Prior phases (01–06) are not re-evaluated here.
- ASVS Level 1 applies. No penetration testing or level 2/3 controls were evaluated.
- The four `mitigate` threats (T-07-01 through T-07-04) were verified by direct inspection of implementation files. No gaps were found.
