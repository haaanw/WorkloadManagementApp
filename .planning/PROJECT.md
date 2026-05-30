# Tuwa

> Product name is **Tuwa** (Tonus/Faros are dead names; repo dir stays `Tonus/`, bundle ID `com.tonus.app`).

## Core Target Users (narrowed 2026-05-30)

**Amateur serious trainers and part-time athletes who train hard but have no access to professional coaching, physiotherapy, or sports-science support.** They want pro-grade readiness, load, and injury-risk guidance that a coach/physio would otherwise provide. That absence of professional support is the defining need. Previously the audience was a more generic "athletes" group — deliberately narrowed. Every algorithm, UX, and copy decision optimizes for this group, and the core algorithm must be measurably better than generic competitor apps (Whoop/Oura/Garmin/TrainingPeaks/etc.) for them specifically.

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
- ✓ Streak tracking for training consistency (consecutive week counting) — v1.1 Phase 5
- ✓ Weekly local push notifications with training summary — v1.1 Phase 5
- ✓ Notification pre-permission card and profile settings — v1.1 Phase 5
- ✓ Cold-start questionnaire with ATL/CTL seeding — v1.2 Phase 10
- ✓ Perceptual bias measurement (estimated vs actual at 8 weeks) — v1.2 Phase 10
- ✓ TrainingProfile model with Supabase sync — v1.2 Phase 9
- ✓ Athlete-owned training templates (reuse coach template models) — v1.2 Phase 9
- ✓ Manual template creation with exercise group structure — v1.2 Phase 11
- ✓ Save-as-template from completed sessions — v1.2 Phase 11
- ✓ Template selection UX (dashboard cards + picker) — v1.2 Phase 12
- ✓ HealthKit workout → template matching — v1.2 Phase 12
- ✓ Schedule-aware template suggestions (TemplateSuggestionEngine) — v1.2 Phase 12
- ✓ Dynamic template targets (last-used + ProgressionEngine overlay) — v1.2 Phase 12
- ✓ Template management (edit, duplicate, archive, favorite, delete) — v1.2 Phase 11
- ✓ Template sharing between users/coaches via link/code — v1.3 Phase 15

- ✓ LLM-powered workout import (PDF/image/text → templates) — v1.3 Phase 16
- ✓ Alpino font replacement (DM Sans → Alpino from FontShare) — v1.3 Phase 13
- ✓ SyncService pull-side `try?` hardening (silent failure fix) — v1.3 Phase 14
- ✓ Rounded border fix (`.roundedBorder` → 0pt corners per design system) — v1.3 Phase 13

### Active
- [ ] Cycle data foundation: CycleTrackingService reading HealthKit menstrual data from existing apps
- [ ] Same-phase recovery baselines with confidence gating (measurement correction, not modifier)
- [ ] Cycle context UI: dashboard phase indicator, recovery card explanations, fueling prompts
- [ ] RED-S cycle irregularity monitoring with clinician-referral language
- [ ] Shadow-mode cycle analytics validating prediction improvement before algorithmic modifiers

## Current Milestone: v1.3 LLM Import, Sharing & Polish

**Goal:** Enable AI-powered workout import from any format, let users share templates, rebrand typography to Alpino, and harden remaining tech debt from code review.

**Target features:**
- LLM-powered workout import (PDF/image/text → templates)
- Template sharing between users/coaches via link/code
- Alpino font replacement (DM Sans → Alpino from FontShare)
- SyncService pull-side `try?` hardening (silent failure fix)
- Rounded border fix (`.roundedBorder` → 0pt corners per design system)

### Out of Scope

- Real-time chat between coach and athlete — high complexity, not core to training insight
- Video analysis — different product category
- Android — iOS-first, revisit after establishing market fit
- Apple Watch companion app — defer until core iOS experience is polished
- Manual mesocycle/ATP planner — TrainingPeaks owns this space; Tonus's value is automated detection
- AI chatbot / conversational coach — LLM cost + liability; keep autoregulation rule-based
- LLM-powered file/image workout import — promoted to v1.3
- Template sharing between users/coaches — promoted to v1.3
- Perceptual bias continuous calibration — deferred, needs research on longitudinal sRPE adjustment
- Injury-aware loading management — deferred, needs deep longitudinal data + dedicated research
- Cycle-driven algorithmic modifiers (AutoregulationEngine, FatigueIndex, ProgressionEngine volume overrides) — deferred to v1.4 Wave 2 pending shadow-mode validation; ship context/baselines first

## Context

- v1.0 Post-Launch milestone complete (4 phases, 14 plans shipped 2026-04-22)
- v1.1 App Store Launch milestone complete (4 phases shipped 2026-04-30)
- v1.2 Training Onboarding & Templates complete (4 phases, 11 plans shipped 2026-05-10)
- v1.4 Female Athlete Optimization planned — research complete (696 lines, 60+ sources), Claude-Codex adversarial review completed, 4 phases scoped
- Evidence-based fatigue tracking system shipped (FatigueIndexEngine, 6 components, replaces ACWR as primary risk signal)
- Coach template system exists: WorkoutTemplate → ExerciseGroup → TemplateExercise → TemplateSet
- HealthKit workout import exists: WorkoutImportBanner + WorkoutImportService (pull-based, no background delivery)
- ProgressionEngine exists for recovery-aware overload suggestions (Pro-gated)
- HealthKit provides raw biometric data; app computes composite scores locally (never uploads raw HealthKit data)
- Template model battle-tested across v1.2 (WorkoutTemplate → ExerciseGroup → TemplateExercise → TemplateSet)
- Design system enforced: 0pt border radius, no shadows, DM Sans font (switching to Alpino in v1.3), accent only on readiness score

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
| Parallel data tracks for cold-start | Keep estimated ATL/CTL separate from real for bias comparison | Pending |
| Hybrid switchover threshold (3wk + 8 sessions) | ATL needs 3 weeks to stabilize, 8 sessions for density | Pending |
| Standalone TrainingProfile model | Keep Athlete model clean, preserve raw answers for bias analysis | ✓ Good — Phase 9 |
| Reuse coach template models for athletes | WorkoutTemplate + ExerciseGroup already model the right structure | ✓ Good — Phase 9 |
| Templates free, intelligence Pro-gated | Friction reduction for all users, smarts as upgrade path | Pending |
| Dynamic targets: last-used + ProgressionEngine | Template evolves with athlete, recovery-aware suggestions overlay | Pending |
| Defer LLM import + sharing to v1.3 | Battle-test template model first, LLM needs model research | ✓ Good — template model validated in v1.2, now building v1.3 |
| CycleContext over CycleModifier for v1.4 Wave 1 | Codex adversarial review: phase modifiers double-count since luteal effects already flow through HRV/RHR/sleep; ship context + corrected baselines first | Pending |
| Same-phase baseline is measurement correction, not modifier | Claude-Codex consensus after Round 2: 7-day rolling baseline is male-normative bias for cycling women; same-phase comparison removes predictable variance | Pending |
| Zero-friction cycle data via HealthKit | Read existing data from Clue/Flo/Apple Cycle Tracking — never ask user to re-enter; reduces adoption friction | Pending |
| RED-S alerts use clinician-referral language only | Missed periods have many causes (pregnancy, OC, PCOS, perimenopause); never imply diagnosis | Pending |

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
*Last updated: 2026-05-10 — Milestone v1.3 LLM Import, Sharing & Polish started*
