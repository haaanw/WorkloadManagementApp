---
phase: 05
slug: streaks-notifications
status: secured
threats_open: 0
threats_total: 7
threats_closed: 7
audited: 2026-04-25
---

# Security: Phase 05 — Streaks & Notifications

## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| App → UNUserNotificationCenter | System notification API — trusted system service |
| User input → @AppStorage | Day/time preferences stored locally |
| System Settings → app state | User can revoke notification permission externally |

## Threat Register

| Threat ID | Category | Component | Disposition | Status | Evidence |
|-----------|----------|-----------|-------------|--------|----------|
| T-05-01 | Information Disclosure | NotificationService.buildNotificationBody | accept | CLOSED | Body contains only aggregate counts (sessions, streak, PRs, volume delta). No PII, no raw HealthKit data. |
| T-05-02 | Tampering | @AppStorage notification preferences | accept | CLOSED | Per-device UserDefaults. Tampering affects only user's own schedule. No security impact. |
| T-05-03 | Denial of Service | UNCalendarNotificationTrigger | accept | CLOSED | System-managed delivery. Failed notification = no data loss or security impact. |
| T-05-04 | Spoofing | NotificationPrePermissionCard | accept | CLOSED | Card appears once per device. No auth data involved. Dismissal permanent via @AppStorage. |
| T-05-05 | Information Disclosure | Notification body content | accept | CLOSED | Aggregate counts only. Lock screen visibility acceptable for non-sensitive data. |
| T-05-06 | Repudiation | Notification toggle state | accept | CLOSED | @AppStorage per-device. No audit trail needed for notification preferences. |
| T-05-07 | Denial of Service | scheduleNotification rapid calls | accept | CLOSED | Each call cancels previous via identifier "weekly-summary". No resource exhaustion risk. |

## Accepted Risks

All 7 threats accepted with documented rationale:
- **Notification content on lock screen**: Only aggregate training counts visible. No PII, no raw HealthKit data. Compliant with Apple HealthKit data handling guidelines.
- **UserDefaults tampering**: Per-device only, affects user's own notification preferences. No cross-user impact.
- **Notification delivery failure**: System-managed, no data integrity risk on failure.

## Audit Trail

### Security Audit 2026-04-25

| Metric | Count |
|--------|-------|
| Threats found | 7 |
| Closed | 7 |
| Open | 0 |

All threats have `accept` disposition with documented rationale. No implementation-level mitigations required — phase operates within iOS system security boundaries (UNUserNotificationCenter, @AppStorage).
