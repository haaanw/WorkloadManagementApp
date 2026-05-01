---
gsd_state_version: 1.0
milestone: v1.2
milestone_name: Training Onboarding & Templates
status: defining_requirements
stopped_at: null
last_updated: "2026-05-01T00:00:00.000Z"
last_activity: 2026-05-01 -- Milestone v1.2 started
progress:
  total_phases: 0
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-01)

**Core value:** Recovery + load tracked over time -- long-term insight into how the body responds to training
**Current focus:** Defining requirements for v1.2

## Current Position

Phase: Not started (defining requirements)
Plan: —
Status: Defining requirements
Last activity: 2026-05-01 — Milestone v1.2 started

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**

- Total plans completed: 20 (v1.0)
- Average duration: carried from v1.0
- Total execution time: carried from v1.0

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| v1.0 phases 1-4 | 14/14 | — | — |
| 05 | 3 | - | - |
| 06 | 3 | - | - |

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [v1.0]: Depth-first post-launch strategy -- analytics before onboarding polish
- [v1.0]: @Query over relationship arrays for welcome card visibility
- [v1.1]: Weekly streaks (not daily) to avoid punishing rest days
- [v1.1]: Local-only notifications via UNCalendarNotificationTrigger -- no APNs needed
- [v1.1]: UIGraphicsPDFRenderer for PDF export -- vector quality, no new SPM deps
- [v1.1]: Zero new SPM packages for v1.1 -- all Apple-native frameworks

### Pending Todos

None yet.

### Blockers/Concerns

- ASO keyword selection needs product owner input before Phase 7
- Demo account seeding strategy needs definition during Phase 8 planning

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

Last session: 2026-04-26T07:10:57.575Z
Stopped at: Phase 7 UI-SPEC approved
Resume file: .planning/phases/07-app-store-metadata/07-UI-SPEC.md
