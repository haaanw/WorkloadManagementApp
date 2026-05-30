---
gsd_state_version: 1.0
milestone: v1.6
milestone_name: Algorithm Moat (Personal Readiness v1)
status: completed
stopped_at: Phase 26 Plan 01 complete (BaselineState local-only @Model) — resume at Plan 02
last_updated: "2026-05-30T09:42:00.000Z"
last_activity: 2026-05-30 -- Phase 26 Plan 01 executed (BaselineState individualized-baseline state model)
progress:
  total_phases: 14
  completed_phases: 13
  total_plans: 44
  completed_plans: 41
  percent: 93
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-10)

**Core value:** Recovery + load tracked over time -- long-term insight into how the body responds to training
**Current focus:** UAT for v1.4 + v1.5 (Phases 19-22 code-complete, build green)

## Current Position

Phase: 26 (individualized-baselines) IN PROGRESS — Plan 01 of 4 COMPLETE (2026-05-30)
Status: 26-01 persistence foundation shipped — local-only BaselineState @Model (ONE row/athlete, flattened HRV/RHR/sleep sub-states, no Codable, absent from SyncService), registered in app+test schemas, build+tests green (4/4); [Double] MAD buffer round-trips natively (A7 cleared); Wave 1 done, Plans 02/03/04 remain
Last activity: 2026-05-30 -- Phase 26 Plan 01 executed (BaselineState individualized-baseline state model)

Prior: Phase 25 (soreness-tweak-self-log) Plan 01 COMPLETE — local-only SorenessLog @Model + NiggleType enum + SorenessLogRepository (4/4 green); Plans 02/03/04 remain

Prior: Phases 19-22 all COMPLETE (sub-agent team execution 2026-05-30) — pending human UAT; v1.4 (17-20) + v1.5 (21-22) phase-complete; full app build green; modifiers shipped dark

v1.3-live-feedback improvement pass (2026-05-30): HealthKit re-prompt bug FIXED; UI hierarchy upgraded (Dashboard+Profile only — DESIGN.md luminance revised, card/section primitives); invite-coach redesigned; ACWR copy demoted to load-context. Codex-reviewed, 1 P1 + 3 P2 found and fixed, gate PASS, build green. 8 commits local on main. Algorithm redesign DEFERRED to its own milestone (needs user direction).

Outstanding before ship:

- Algorithm v1 — SCOPE LOCKED + user-approved 2026-05-30, BUILD DEFERRED to a later milestone (per-muscle strength load, ACWR-out dual-run, Altini baselines, Readiness+Strain-Risk, honest framing, behind shadow harness). See memory project_algorithm_v1_locked + .planning/research/{algorithm-moat-design,competitive-algorithm-analysis}.md. Do not start until user reactivates.
- Design brand sign-off: luminance bump + DesignToggleStyle need user's eyes in running app
- UI hierarchy pass NOT applied to Recovery + Workload screens yet (bounded per codex)
- Manual deploy: `supabase functions deploy parse-workout` (Phase 22 Edge Function enum expansion)
- Human UAT: Phase 21 gesture feel/haptics (device), Phase 19 cycle UI opt-in flows, Phase 23 zh-Hans
- Pre-existing blocker: #if DEBUG font assertionFailure in App/WorkloadApp.swift crashes XCTest host (whole unit suite unrunnable) — fix to re-enable CI tests
- zh-Hans review: 4 muscle terms (hipRotators, tibialisAnterior, transverseAbdominis, erectors)
- Branding: RESOLVED 2026-05-30 — official name is Tuwa (user-confirmed); CLAUDE.md updated. Faros/Tonus/Tutrice dead; bundle ID stays com.tonus.app

Progress (v1.4+v1.5): [███████████████] 100% (Phases 17-22 complete, pending UAT)

## Performance Metrics

**Velocity:**

- Total plans completed: 54 (v1.0: 14, v1.1: 9+, v1.2: 11)
- Average duration: carried from v1.2
- Total execution time: carried from v1.2

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| v1.0 phases 1-4 | 14/14 | -- | -- |
| v1.1 phases 5-8 | 9+ | -- | -- |
| v1.2 phases 9-12 | 11/11 | -- | -- |
| 13 | 3 | - | - |
| 14 | 2 | - | - |
| 15 | 3 | - | - |
| 16 | 2 | - | - |
| 18 | 2 | - | - |

*Updated after each plan completion*
| Phase 18 P2 | 12min | 3 tasks | 9 files |
| Phase 25 P1 | ~10min | 2 tasks | 5 files |
| Phase 26 P1 | ~4min | 1 task | 4 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [v1.3 Research]: Design polish ships first so all new v1.3 UI inherits correct font/borders
- [v1.3 Research]: 30-day share link expiry, 8-char alphanumeric codes
- [v1.3 Research]: All LLM calls via Supabase Edge Function proxy -- API key never in iOS binary
- [v1.3 Research]: Apple Vision for OCR, PDFKit for PDF extraction -- zero new iOS dependencies
- [v1.3 Research]: gpt-4o-mini with JSON Schema structured output for workout parsing
- [Phase ?]: [Phase 18-02]: Same-phase baselines wired into RecoveryPipeline.run via optional CycleTrackingService; D-04 gate + read-time RecoverySnapshot x MenstrualCycleSnapshot join over ~3-cycle window; nil-service path identical to 7-day

### Pending Todos

None yet.

### Blockers/Concerns

- Alpino PostScript name must be verified with Font Book before writing Font.custom() strings
- AASA file hosting on tutrice.app domain needs verification for universal links (share codes are fallback)
- OCR accuracy on handwritten content is unreliable -- scope Phase 16 as "printed/typed text only"

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 260420-qax | Fix App Store rejection: harden launch path, remove NFC | 2026-04-20 | f41845b | [260420-qax-fix-app-store-rejection-harden-launch-pa](./quick/260420-qax-fix-app-store-rejection-harden-launch-pa/) |
| 260426-jnx | Remove NFC functionality to resolve App Store rejection | 2026-04-26 | 29bf733 | [260426-jnx-remove-nfc-functionality-to-resolve-app-](./quick/260426-jnx-remove-nfc-functionality-to-resolve-app-/) |

### Roadmap Evolution

- Phase 23 added: Multi-language in-app support (Simplified Chinese)

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Template | TMPL-11: HealthKit workout auto-matching | Deferred | v1.2 close |
| Template | TMPL-12: Template folders/organization | Deferred | v1.2 close |
| Algorithm | COLD-08: Continuous perceptual bias calibration | Deferred | v1.2 close |
| Algorithm | COLD-09: Injury-aware loading management | Deferred | v1.2 close |

## Session Continuity

Last session: 2026-05-30T17:42:00.000Z
Stopped at: Phase 26 Plan 01 complete (BaselineState local-only @Model) — resume at Plan 02
Resume file: .planning/phases/26-individualized-baselines/26-02-PLAN.md
