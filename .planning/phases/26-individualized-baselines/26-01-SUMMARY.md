---
phase: 26-individualized-baselines
plan: 01
subsystem: database
tags: [swiftdata, model, baseline, ewma, welford, mad, local-only, privacy]

# Dependency graph
requires:
  - phase: 25-localized-niggle
    provides: SorenessLog local-only @Model template (no-Codable, bare athlete inverse, privacy-by-omission)
provides:
  - "Local-only never-synced BaselineState @Model: ONE row per athlete, flattened HRV/RHR/sleep sub-states (mu?, welfordMean, m2, count, madBuffer:[Double], lastBucketedDate?, cvRatio?, cvLevelRaw, confidence)"
  - "BaselineState.self registered in app Schema + test ModelContainer schema (additive lightweight migration)"
  - "Persistence + Optional-fidelity + sync-omission + cvLevel-default test coverage"
affects: [26-02-baseline-engine, 26-03-day-bucketer, 26-04-convergence-report, phase-28]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Stateless-engine / stateful-carrier split: the @Model holds running state, no math lives in it"
    - "Flattened multi-signal sub-states (hrv*/rhr*/sleep* prefixes) instead of one row per signal"
    - "Local-only privacy-by-omission (no Codable, absent from SyncService) carried forward from SorenessLog"

key-files:
  created:
    - WorkloadApp/Models/BaselineState.swift
    - WorkloadAppTests/BaselineStateModelTests.swift
  modified:
    - WorkloadApp/App/WorkloadApp.swift
    - workload management/workload management.xcodeproj/project.pbxproj

key-decisions:
  - "Open-question #2 RESOLVED by decision: ONE BaselineState row per athlete with three flattened signal sub-states (NOT three per-signal rows)"
  - "[Double] MAD buffer persisted natively in SwiftData — packed-scalar fallback NOT needed (A7 cleared by round-trip test)"
  - "EWMA mu kept Optional (nil = no fold yet) and SEPARATE from the Welford running mean (different estimators, §1.2)"

patterns-established:
  - "Stateful carrier @Model + stateless engine value-mirror (§6.3): the model is a dumb carrier, BaselineEngine (Plan 02) owns all statistics"
  - "Flattened prefixed sub-state fields where SwiftData can't nest a Codable sub-struct"

requirements-completed: [P26-MODEL, P26-SCHEMA, P26-LOCALONLY]

# Metrics
duration: 4min
completed: 2026-05-30
---

# Phase 26 Plan 01: Individualized-Baseline State Model Summary

**Local-only never-synced `BaselineState` SwiftData @Model — ONE row per athlete with flattened HRV/RHR/sleep running state (EWMA μ, Welford mean/M2/count, [Double] MAD buffer, monotonic last-bucketed-date, CV hysteresis, confidence) — registered in app + test schemas, build + 4 tests green.**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-05-30T09:37:21Z
- **Completed:** 2026-05-30T09:40:30Z
- **Tasks:** 1
- **Files modified:** 4 (2 created, 2 modified)

## Accomplishments
- Created `BaselineState.swift` as a local-only `@Model final class` — one row per athlete, three flattened signal sub-states (`hrv*` / `rhr*` / `sleep*`), each carrying `mu: Double?` (Optional EWMA μ), `welfordMean`, `m2`, `count`, `madBuffer: [Double]`, `lastBucketedDate: Date?`, `cvRatio: Double?`, `cvLevelRaw: String`, `confidence: Double`, plus `@Attribute(.unique) id`, bare `athlete: Athlete?` inverse, and `updatedAt`.
- Registered `BaselineState.self` in the app `ModelContainer` Schema (`WorkloadApp.swift`, immediately after `SorenessLog.self`) AND in the `BaselineStateModelTests` in-memory `ModelContainer` schema.
- Added the 4 standard app-target entries to `project.pbxproj` (PBXBuildFile + PBXFileReference + Models group child + app PBXSourcesBuildPhase), mirroring SorenessLog. Test file lands in the synchronized `WorkloadAppTests` group (no pbxproj edit needed).
- Wrote 4 tests — all pass via real `xcodebuild test` on iPhone 17 Pro Max sim.

## Task Commits

1. **Task 1: Create local-only BaselineState @Model + register in app & test schemas** — `7dd592d` (feat)

_Single-task TDD plan; model + test committed together (the test file cannot compile without the type, so the RED→GREEN split collapses into one green commit)._

## Files Created/Modified
- `WorkloadApp/Models/BaselineState.swift` — local-only @Model carrier (created)
- `WorkloadAppTests/BaselineStateModelTests.swift` — persistence/Optional/sync-omission/cvLevel tests (created)
- `WorkloadApp/App/WorkloadApp.swift` — added `BaselineState.self` to app Schema (modified)
- `workload management/workload management.xcodeproj/project.pbxproj` — 4 app-target entries (modified)

## Final Field Names (as shipped)

Per signal, prefixed `hrv` / `rhr` / `sleep`:
`<p>Mu: Double?`, `<p>WelfordMean: Double`, `<p>M2: Double`, `<p>Count: Int`, `<p>MadBuffer: [Double]`, `<p>LastBucketedDate: Date?`, `<p>CvRatio: Double?`, `<p>CvLevelRaw: String`, `<p>Confidence: Double`. Plus `id: UUID`, `athlete: Athlete?`, `updatedAt: Date`. Init zero-inits every accumulator (μ/date/ratio → nil, mean/M2/confidence → 0.0, count → 0, buffer → [], cvLevelRaw → "normal").

## Decisions Made
- **Open-question #2 resolved by decision: ONE row, flattened.** A single `BaselineState` row per athlete embeds all three signal sub-states as prefixed scalar fields (not three per-signal rows) — fewer rows, atomic upsert, mirrors `CyclePredictionLog`'s parallel-column shape.
- **`[Double]` MAD buffer persisted natively** — the A7 round-trip test (`hrvMadBuffer = [-1.0, 2.0, -0.5]` etc.) passed on first run. The packed-scalar (`madSlot0..N`) fallback was NOT needed.
- **EWMA μ is Optional and separate from the Welford running mean** (§1.2 — different estimators); "no fold yet" (nil) is distinguishable from "μ == 0".

## Deviations from Plan
None - plan executed exactly as written.

## Issues Encountered
None. No simulator flake; no xcstrings churn (the build did not rewrite `Localizable.xcstrings` / `InfoPlist.xcstrings`, so nothing needed discarding). The two "Codable" matches in `BaselineState.swift` are doc-comment text only (explaining the absence of Codable) — no conformance.

## Privacy / Local-Only Verification
- `grep "BaselineState" WorkloadApp/Services/SyncService.swift` → 0 matches (privacy-by-omission, mirrors SorenessLog/CyclePredictionLog).
- No `Codable` conformance, no encoder, no `*Row` DTO, no `import Supabase`, no push/pull helper.
- T-26-01 (Information Disclosure) and T-26-02 (Tampering / migration) threat dispositions satisfied: additive standalone model with bare optional `athlete?` inverse → SwiftData lightweight migration, no MigrationPlan.

## Next Phase Readiness
- Shape is locked for Plan 02 (`BaselineEngine`, stateless, operates on a `SignalState` value mirror of these fields) and Plan 03 (day-bucketer writing `lastBucketedDate`).
- No statistics math lives in the model — engine-stateless invariant (§6.3) intact.
- This plan is the sole pbxproj writer in Wave 1; Plans 02/03 are later waves to avoid concurrent pbxproj edits.

## Self-Check: PASSED
- `WorkloadApp/Models/BaselineState.swift` — FOUND
- `WorkloadAppTests/BaselineStateModelTests.swift` — FOUND
- `.planning/phases/26-individualized-baselines/26-01-SUMMARY.md` — FOUND
- Commit `7dd592d` — FOUND
- `BaselineState.self` in app Schema AND test schema — confirmed
- 4 app-target entries in project.pbxproj — confirmed
- `BaselineState` absent from SyncService.swift — confirmed
- 4/4 tests passed via xcodebuild on iPhone 17 Pro Max sim

---
*Phase: 26-individualized-baselines*
*Completed: 2026-05-30*
