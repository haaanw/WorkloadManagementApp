---
status: partial
phase: 23-multi-language-in-app-support-simplified-chinese
source: [23-05-PLAN.md, 23-05-SUMMARY.md, 23-04-SUMMARY.md]
started: 2026-05-27
updated: 2026-05-27
---

## Current Test

[awaiting human action]

## Tests

### 1. Render zh-Hans App Store screenshots
expected: 6+ PNGs at 1320×2868 captured via `Screenshots-zhHans` scheme on iPhone 17 Pro Max simulator, named `01-dashboard.png` ... `08-onboarding-frequency-step.png`, committed under `.planning/phases/23-multi-language-in-app-support-simplified-chinese/screenshots-zhHans/`. No English fallback strings visible.
result: [pending]

### 2. Enter zh-Hans metadata in App Store Connect
expected: Simplified Chinese localization added under both App Information and the current App Store version. App Name, Subtitle, Promotional Text, Description, Keywords, What's New populated from `asc-metadata-zhHans.md`. Saved (not submitted).
result: [pending]

### 3. Upload zh-Hans screenshots to ASC
expected: All zh-Hans PNGs uploaded to the 6.9" Display slot for the zh-Hans localization. Order matches `screenshots-zhHans/README.md`.
result: [pending]

### 4. Visual audit on zh-Hans build
expected: Native zh-Hans reviewer sign-off on 13-item Visual Acceptance Checklist inside `23-04-SUMMARY.md`. Capture en + zh-Hans screenshots for dashboard / workload / recovery / profile / onboarding step 0 / paywall. Verify live-switch (Profile → Language → 中文 (简体)) shows 150ms crossfade, no restart. Verify hybrid term rendering (ACWR / HRV / RHR full hybrid at first occurrence).
result: [pending]

### 5. HealthKit consent zh-Hans verification
expected: iOS Settings → Tuwa → Health on zh-Hans simulator shows the UI-SPEC consent string verbatim.
result: [pending]

### 6. RevenueCat product display-name follow-up
expected: Acknowledged that English product titles remain inside zh-Hans UpgradeSheet. RC dashboard zh-Hans display names deferred post-ship.
result: [pending]

## Summary

total: 6
passed: 0
issues: 0
pending: 6
skipped: 0
blocked: 0

## Gaps
