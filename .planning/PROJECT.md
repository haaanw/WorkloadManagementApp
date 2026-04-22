# Tonus

## What This Is

Athlete workload management iOS app that combines recovery scoring (HRV, sleep, RHR) with training load tracking (ACWR, EWMA) to give athletes a daily readiness picture and long-term overtraining prevention. Includes training intelligence (periodization detection, fatigue patterns, behavior correlation) and guided onboarding. Supports both individual athletes and coach-athlete relationships with two-tier subscriptions.

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
- ✓ HealthKit staleness detection and indicators — v1.0 Phase 2
- ✓ Multi-week trend charts (CTL/ATL/TSB) with time-range picker — v1.0 Phase 2
- ✓ Weekly training summary with week-over-week deltas — v1.0 Phase 2
- ✓ Recovery-load correlation overlay (28-day) — v1.0 Phase 2
- ✓ CSV export with HealthKit-compliant composite-only data — v1.0 Phase 2
- ✓ Periodization detection (Building/Pushing/Tapering/Maintaining) — v1.0 Phase 3
- ✓ Fatigue pattern analysis (recovery dip lag correlation) — v1.0 Phase 3
- ✓ Behavior tagging with recovery impact correlation — v1.0 Phase 3
- ✓ Data sufficiency gating for intelligence features — v1.0 Phase 3
- ✓ First-run guidance (welcome card with workout/wellness CTAs) — v1.0 Phase 4
- ✓ Sport/training preference setup during onboarding — v1.0 Phase 4

### Active

- [ ] Data export (PDF reports or CSV for coaches)
- [ ] Push notifications for weekly summary
- [ ] Streak tracking for training/check-in consistency

### Out of Scope

- Real-time chat between coach and athlete — high complexity, not core to training insight
- Social/sharing features — focus on individual athlete value first
- Video analysis — different product category
- Android — iOS-first, revisit after establishing market fit
- Apple Watch companion app — defer until core iOS experience is polished
- Manual mesocycle/ATP planner — TrainingPeaks owns this space; Tonus's value is automated detection
- AI chatbot / conversational coach — LLM cost + liability; keep autoregulation rule-based

## Context

- v1.0 Post-Launch milestone complete (4 phases, 14 plans shipped 2026-04-22)
- App is functionally complete: auth, sync, subscriptions, analytics, intelligence, onboarding
- ~15,700 LOC Swift across 80+ files
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
| Depth-first post-launch | Power user analytics before onboarding polish | ✓ Good — intelligence features shipped before onboarding |
| ZStack over TabView for onboarding | TabView swipe disable unreliable on iOS 17 | ✓ Good |
| @Query over relationship arrays for welcome card | SwiftData relationships may not resolve on first render | ✓ Good |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition:**
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone:**
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-22 after v1.0 milestone*
