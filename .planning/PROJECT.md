# Tonus

## What This Is

Athlete workload management iOS app that combines recovery scoring (HRV, sleep, RHR) with training load tracking (ACWR, EWMA) to give athletes a daily readiness picture and long-term overtraining prevention. Supports both individual athletes and coach-athlete relationships with two-tier subscriptions.

## Core Value

The combination of recovery and load tracked over time — giving athletes long-term insight into how their body responds to training, so they can train smarter and avoid injury.

## Requirements

### Validated

- ✓ EWMA workload calculation with ACWR zones — Phase 1
- ✓ Recovery scoring from HealthKit (HRV, RHR, sleep) with individual baselines — Phase 1
- ✓ Autoregulation recommendations based on recovery + load — Phase 1
- ✓ PR detection across exercises — Phase 1
- ✓ Supabase auth (email/password) with session persistence — Phase 2
- ✓ Bidirectional sync (workouts, snapshots, wellness, PRs) — Phase 2
- ✓ Coach-athlete relationships with invite codes, email, NFC — Phase 3
- ✓ Coach dashboard with athlete roster and snapshot viewing — Phase 3
- ✓ Session attribution (self vs coach-logged) — Phase 3
- ✓ RevenueCat two-tier subscriptions (Athlete Pro + Coach) — Phase 4
- ✓ Feature gating (history, custom exercises, coach mode) — Phase 4
- ✓ Privacy policy, Terms of Service, support pages — Phase 5
- ✓ PrivacyInfo.xcprivacy manifest — Phase 5
- ✓ Screenshot automation framework — Phase 5
- ✓ App icon and launch screen — Phase 5
- ✓ Periodization detection (Building/Pushing/Tapering/Maintaining) — Phase 3 (post-launch)
- ✓ Fatigue pattern analysis (recovery dip lag correlation) — Phase 3 (post-launch)
- ✓ Behavior tagging with recovery impact correlation — Phase 3 (post-launch)
- ✓ Data sufficiency gating for intelligence features — Phase 3 (post-launch)

### Active

- [ ] Finalize bundle identifier for App Store
- [ ] Generate App Store screenshots for required device sizes
- [ ] Verify GitHub Pages URLs are live
- [ ] App Store Connect setup and submission
- ✓ First-run guidance (welcome card with workout/wellness CTAs) — Phase 4 (post-launch)
- ✓ Sport/training preference setup during onboarding — Phase 4 (post-launch)
- [ ] Data export (PDF reports or CSV for athletes and coaches)

### Out of Scope

- Real-time chat between coach and athlete — high complexity, not core to training insight
- Social/sharing features — focus on individual athlete value first
- Video analysis — different product category
- Android — iOS-first, revisit after establishing market fit
- Apple Watch companion app — defer until core iOS experience is polished

## Context

- App is functionally complete through all post-launch phases (local wiring → Supabase → coach/athlete → subscriptions → training intelligence → onboarding)
- Phase 5 (App Store readiness) is ~80% done — legal pages, privacy manifest, screenshot framework exist
- Remaining Phase 5 work is mostly manual (App Store Connect setup, TestFlight, submission)
- Post-launch milestone v1.0 complete: analytics, training intelligence, and onboarding all shipped
- HealthKit provides raw biometric data; app computes composite scores locally (never uploads raw HealthKit data)
- Design system enforced: 0pt border radius, no shadows, DM Sans font, accent only on readiness score

## Constraints

- **Platform**: iOS 17+ only, SwiftUI + SwiftData
- **HealthKit**: Read-only access, raw data must never leave device (only composite scores sync)
- **Subscriptions**: RevenueCat handles StoreKit; API keys gitignored
- **Backend**: Supabase PostgreSQL with RLS; no local fallback for sync
- **Design**: Must follow DESIGN.md — 0pt corners, no shadows, DM Sans, 8pt grid

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| SwiftData over CoreData | Modern persistence, better SwiftUI integration | ✓ Good |
| Pure struct engines | Testable business logic, no state contamination | ✓ Good |
| EWMA over rolling average | Better responsiveness to training load changes | ✓ Good |
| Supabase over Firebase | PostgreSQL + RLS, Swift SDK, lower vendor lock-in | ✓ Good |
| RevenueCat over StoreKit 2 direct | Faster integration, cross-platform potential, analytics | ✓ Good |
| Two-tier subscription (Pro + Coach) | Separate value props for different user types | ✓ Good |
| Depth-first post-launch | Power user analytics before onboarding polish | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-22 after Phase 4 completion*
