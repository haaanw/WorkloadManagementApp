---
gsd_state_version: 1.0
milestone: v1.2
milestone_name: Training Onboarding & Templates
status: executing
stopped_at: Phase 11 context gathered
last_updated: "2026-05-09T02:40:30.853Z"
last_activity: 2026-05-08
progress:
  total_phases: 4
  completed_phases: 2
  total_plans: 6
  completed_plans: 6
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-01)

**Core value:** Recovery + load tracked over time -- long-term insight into how the body responds to training
**Current focus:** Phase 10 — cold-start-questionnaire

## Current Position

Phase: 11
Plan: Not started
Status: Executing Phase 10
Last activity: 2026-05-08

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**

- Total plans completed: 26 (v1.0: 14, v1.1: 6+)
- Average duration: carried from v1.1
- Total execution time: carried from v1.1

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| v1.0 phases 1-4 | 14/14 | -- | -- |
| v1.1 phases 5-8 | 9+ | -- | -- |
| 09 | 3 | - | - |
| 10 | 3 | - | - |

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [v1.2]: Parallel data tracks for cold-start -- estimated ATL/CTL on TrainingProfile only, never WorkloadSnapshot
- [v1.2]: Hybrid switchover threshold (3wk + 8 sessions) -- ATL needs 3 weeks to stabilize, 8 sessions for density
- [v1.2]: Standalone TrainingProfile model -- keep Athlete model clean, preserve raw answers for bias analysis
- [v1.2]: Reuse coach template models for athletes -- WorkoutTemplate + ExerciseGroup already model the right structure
- [v1.2]: Templates free, intelligence Pro-gated -- friction reduction for all users, smarts as upgrade path
- [v1.2]: Defer LLM import + sharing to v1.3 -- battle-test template model first

### Pending Todos

None yet.

### Blockers/Concerns

- EWMA contamination prevention: estimated ATL/CTL must never touch WorkloadSnapshot
- Supabase RLS must be updated BEFORE any template sync code (silent failure risk via try?)
- SwiftData additive-only changes required (no field renames on existing models)
- ProgressionEngine overlay UX design needs decision before Phase 12 (template baseline vs modifier visual layering)

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 260420-qax | Fix App Store rejection: harden launch path, remove NFC | 2026-04-20 | f41845b | [260420-qax-fix-app-store-rejection-harden-launch-pa](./quick/260420-qax-fix-app-store-rejection-harden-launch-pa/) |
| 260426-jnx | Remove NFC functionality to resolve App Store rejection | 2026-04-26 | 29bf733 | [260426-jnx-remove-nfc-functionality-to-resolve-app-](./quick/260426-jnx-remove-nfc-functionality-to-resolve-app-/) |

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| *(none)* | | | |

## Session Continuity

Last session: 2026-05-09T02:40:30.850Z
Stopped at: Phase 11 context gathered
Resume file: .planning/phases/11-template-management-creation/11-CONTEXT.md
