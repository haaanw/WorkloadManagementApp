---
phase: 01-app-store-launch
plan: 03
status: complete
started: 2026-04-20
completed: 2026-04-20
---

## Summary

App Store Connect record configured, build archived and submitted for review.

## What was done

### Task 1: App Store Connect metadata & configuration (human-action)
- App record already existed from prior submission (March 27)
- Screenshots uploaded (4 screens x 2 sizes, marketing-framed)
- Age rating, pricing (Free + IAP, US/Canada), metadata all confirmed from prior submission
- RevenueCat products confirmed: 4 products under "Tonus" store in Atheletrack project (com.tonus.app.athlete_pro.monthly/annual, com.tonus.app.coach.monthly/annual)
- Medical device declaration: not a regulated medical device
- App Review Information note updated with demo account, NFC explanation, crash root cause

### Task 2: Archive and upload build
- Build number bumped from 1 to 2 (version 1.0(2))
- Archived via Xcode, uploaded to App Store Connect
- Distribution certificate created (Apple Distribution)
- PLA agreement accepted

### Task 3: Submit for review
- Build 1.0(2) selected in App Store Connect
- Submitted for App Store review — status: Waiting for Review

## Previous rejection resolved

**Rejection:** 2.1.0 Performance: App Completeness — crash on launch on iPad Air M3
**Root cause:** RevenueCat sandbox API key shipped in Release build. SDK intentionally aborts via `checkForSimulatedStoreAPIKeyInRelease`.
**Fix:** Production API key (`appl_` prefix) now in RevenueCatConfig.swift. Additionally hardened SubscriptionService and AppContainer init paths.

**NFC demo video request:** Addressed in App Review note — NFC is optional, email/code invite paths are equivalent. Offered to provide demo video if still required.

## Deviations
- Plan 01-03 was partially executed manually by user (ASC/RevenueCat dashboard work) and partially by quick task 260420-qax (crash fix + NFC hardening)
- NFC was temporarily removed then restored after deciding to keep it for submission
