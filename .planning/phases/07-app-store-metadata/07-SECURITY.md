---
phase: 07
slug: app-store-metadata
status: verified
threats_open: 0
asvs_level: 1
created: 2026-04-26
---

# Phase 07 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Client -> Supabase Auth | Social auth credentials cross from device to backend | Apple ID token, Google OAuth code |
| Google OAuth redirect -> App | OAuth callback URL carries session token from browser back to app | Session token via URL scheme |
| Apple credential -> AuthService | Apple identity token is single-use, must not be cached or logged | Apple ID token (PII) |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-07-01 | Spoofing | Apple Sign-In | mitigate | Supabase validates Apple ID token server-side via `signInWithIdToken` — no client-side credential trust | closed |
| T-07-02 | Spoofing | Google Sign-In | mitigate | Supabase SDK owns full PKCE+state flow via `signInWithOAuth` — no custom token parsing | closed |
| T-07-03 | Information Disclosure | AuthService | mitigate | Token extracted and immediately consumed by `signInWithIdToken`; never stored, logged, or cached | closed |
| T-07-04 | Elevation of Privilege | OAuth callback | mitigate | `onOpenURL` passes URL to `container.supabase.auth.session(from:)`; URL scheme registered in Info.plist | closed |
| T-07-05 | Spoofing | Account linking | accept | Supabase auto-links accounts with same verified email — low risk at ASVS L1 | closed |
| T-07-06 | Denial of Service | Social login buttons | accept | Rate limiting handled by Apple/Google auth servers | closed |
| T-07-07 | Information Disclosure | Screenshot tests | accept | SCREENSHOT_MODE gated behind DEBUG builds; mock data only | closed |
| T-07-08 | Tampering | App Store metadata | accept | Public marketing copy; Apple reviews all content | closed |

*Status: open · closed*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-07-01 | T-07-05 | Supabase email-verified auto-link accepted at ASVS L1 | gsd-security-auditor | 2026-04-26 |
| AR-07-02 | T-07-06 | Rate limiting transferred to Apple/Google auth infrastructure | gsd-security-auditor | 2026-04-26 |
| AR-07-03 | T-07-07 | SCREENSHOT_MODE gated behind #if DEBUG; mock data only | gsd-security-auditor | 2026-04-26 |
| AR-07-04 | T-07-08 | Public marketing copy, Apple review process is the control | gsd-security-auditor | 2026-04-26 |

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-04-26 | 8 | 8 | 0 | gsd-security-auditor (sonnet) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-04-26
