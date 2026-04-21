---
phase: 01-app-store-launch
plan: 01
subsystem: app-store-prerequisites
tags: [bundle-id, pricing, screenshots, subscription]
dependency_graph:
  requires: []
  provides: [clean-bundle-ids, screenshot-subscription-bypass, updated-pricing]
  affects: [UpgradeSheet, SubscriptionService, AppRouter, project.pbxproj]
tech_stack:
  added: []
  patterns: [DEBUG-only-override, per-tier-computed-property]
key_files:
  created: []
  modified:
    - workload management/workload management.xcodeproj/project.pbxproj
    - WorkloadApp/Services/SubscriptionService.swift
    - WorkloadApp/Views/Subscription/UpgradeSheet.swift
    - WorkloadApp/App/AppRouter.swift
decisions:
  - D-08 pricing applied: athlete $59.99/yr $6.99/mo, coach $89.99/yr $9.99/mo
  - Per-tier savings badges (29% athlete, 25% coach) replace hardcoded 33%
metrics:
  duration: 2m
  completed: 2026-04-20T09:26:31Z
  tasks_completed: 2
  tasks_total: 2
  files_modified: 4
---

# Phase 01 Plan 01: App Store Code Prerequisites Summary

Fixed all code-level prerequisites for App Store submission: cleaned test target bundle identifiers to com.tonus.app prefix, updated fallback subscription pricing per D-08, added DEBUG-only screenshot subscription bypass, and verified GitHub Pages URLs are live.

## Task Results

| Task | Name | Commit | Key Changes |
|------|------|--------|-------------|
| 1 | Update bundle identifiers and verify URLs | 2275fdf | 4 bundle IDs fixed in pbxproj, 3 URLs verified HTTP 200 |
| 2 | Update subscription pricing and screenshot mode bypass | 7732d04 | Pricing updated, annualSavingsBadge added, overrideForScreenshots wired |

## Changes Made

### Task 1: Bundle Identifiers and URL Verification

- Replaced `H.ScreenshotTests` with `com.tonus.app.ScreenshotTests` (2 occurrences: Debug + Release)
- Replaced `H.WorkloadAppTests` with `com.tonus.app.WorkloadAppTests` (2 occurrences: Debug + Release)
- Verified zero remaining `H.` bundle identifier prefixes
- Verified all three GitHub Pages URLs return HTTP 200:
  - privacy.html: 200
  - terms.html: 200
  - support.html: 200

### Task 2: Subscription Pricing and Screenshot Bypass

**Pricing (D-08):**
- Athlete Pro annual: $39.99 -> $59.99/yr
- Athlete Pro monthly: $4.99 -> $6.99/mo
- Athlete Pro monthly equivalent: $3.33 -> $5.00
- Coach annual: $79.99 -> $89.99/yr
- Coach monthly equivalent: $6.67 -> $7.42
- Added `annualSavingsBadge` computed property (athlete: "SAVE 29%", coach: "SAVE 25%")
- Replaced hardcoded "SAVE 33%" badge with `selectedTier.annualSavingsBadge`

**Screenshot Mode (D-09):**
- Added `overrideForScreenshots(isPro:isCoach:)` method to SubscriptionService wrapped in `#if DEBUG`
- Wired `container.subscriptionService.overrideForScreenshots(isPro: true, isCoach: false)` in AppRouter's SCREENSHOT_MODE block

## Threat Model Compliance

- T-01-01 (mitigate): `overrideForScreenshots` is wrapped in `#if DEBUG` -- cannot exist in production builds. COMPLIANT.
- T-01-02 (accept): Fallback prices are publicly visible. ACCEPTED.

## Deviations from Plan

None -- plan executed exactly as written.

## Known Stubs

None.

## Decisions Made

1. Applied D-08 pricing as specified -- no deviation from plan values
2. Per-tier savings badges calculated from actual price ratios (29% and 25%)

## Verification Results

- Bundle ID H. prefix count: 0 (PASS)
- com.tonus.app.ScreenshotTests occurrences: 2 (PASS)
- com.tonus.app.WorkloadAppTests occurrences: 2 (PASS)
- GitHub Pages URLs: all 200 (PASS)
- overrideForScreenshots in SubscriptionService: present (PASS)
- overrideForScreenshots in AppRouter: present (PASS)
- $59.99/yr in UpgradeSheet: present (PASS)
- annualSavingsBadge in UpgradeSheet: present (PASS)
- selectedTier.annualSavingsBadge in UpgradeSheet: present (PASS)

## Self-Check: PASSED

All 4 modified files exist on disk. Both task commits (2275fdf, 7732d04) verified in git log.
