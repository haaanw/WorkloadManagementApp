---
phase: 18-cycle-aware-recovery-baselines
verified: 2026-05-25T15:00:00Z
status: passed
score: 7/7 success criteria verified
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 6/7
  gaps_closed:
    - "CR-01 — reproductive-health flags (isOnHormonalContraceptive, isPregnant, isLactating) removed from AthleteRow, pushAthlete, and pullAthlete in SyncService.swift (commit b5510e9). Server-side columns dropped via migrations/drop_reproductive_health_fields_from_athletes.sql."
  gaps_remaining: []
  regressions: []
---

# Phase 18: Cycle-Aware Recovery Baselines — Verification Report

**Phase Goal:** Replace the male-normative 7-day rolling HRV/RHR baseline with a confidence-gated same-phase baseline that removes predictable within-athlete cyclic variance, preserving genuine fatigue detection while eliminating false warnings during normal luteal-phase HRV suppression.
**Verified:** 2026-05-25T15:00:00Z
**Status:** passed
**Re-verification:** Yes — after CR-01 gap closure (commit b5510e9)

---

## Goal Achievement

### Observable Truths (Success Criteria from ROADMAP.md)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | RecoveryScoreEngine accepts cycle/same-phase context as optional input; nil/unknown behaves identically to current engine | VERIFIED | `RecoveryInput` has `samePhaseHRVBaseline: Double? = nil` and `samePhaseRestingHRBaseline: Double? = nil`. `compute()` uses `??` to fall back to 7-day baselines when nil. `test_samePhaseNil_identicalToOriginalBehavior` passes (xcodebuild TEST SUCCEEDED). |
| 2 | When cycle confidence is high (3+ regular cycles), HRV and RHR baselines use same-phase historical average from prior cycles as denominator | VERIFIED | `RecoveryPipeline.run` (pipeline.swift:74-112): gate `confidence >= 0.7 && !hasExclusion && phase != .unknown` passes → fetches ~3-cycle window, joins by `startOfDay`, buckets, passes same-bucket readings to `samePhaseBaseline(readings:)`. |
| 3 | When cycle confidence is low (<3 cycles, irregular, anovulatory), engine falls back to existing 7-day rolling baseline | VERIFIED | Gate at pipeline.swift:79 fails if `ctx.confidence < 0.7`; same-phase fields remain nil; engine falls back via `??`. Also `samePhaseBaseline(readings:)` itself returns nil for `count < 4`. |
| 4 | OC users always use 7-day baseline | VERIFIED | Gate uses `!ctx.hasExclusion`. `CycleContext.hasExclusion` (MenstrualCycleSnapshot.swift:67-69) computes `isOnHormonalContraceptive || isPregnant || isLactating` from values populated locally by `CycleTrackingService` from the SwiftData `Athlete` model fields. No sync path involved. |
| 5 | Consistent same-phase luteal HRV scores normally during luteal (not "declining recovery") — check worked-example test | VERIFIED | `test_workedExample5_samePhaseHRV_scoresNormalNotDecline`: hrvSDNN=35 with samePhaseHRVBaseline=35 → ratio 1.0 → HRV contribution 68 (±0.5). xcodebuild TEST SUCCEEDED. |
| 6 | Genuine low HRV vs same-phase average still triggers fatigue detection — check worked-example test | VERIFIED | `test_workedExample6_genuineLutealDrop_stillDetectsFatigue`: hrvSDNN=28 vs samePhaseHRVBaseline=36 → depressed contribution; both assertions on contribution and final score pass. xcodebuild TEST SUCCEEDED. |
| 7 | RecoveryPipeline.run() queries CycleTrackingService and passes context to engine | VERIFIED | `RecoveryPipeline.run` accepts `cycleTrackingService: CycleTrackingService? = nil`. When non-nil, calls `await cycleTrackingService.run(...)`, derives same-phase baselines, passes into `RecoveryScoreEngine.RecoveryInput`. `AppContainer` owns `CycleTrackingService`; DashboardView and RecoveryView pass `container.cycleTrackingService` at call sites. |

**Score:** 7/7 success criteria verified

---

### Phase Privacy Invariant Assessment

**Invariant:** Raw cycle/menstrual data (including reproductive-health exclusion flags) must never persist to or sync via Supabase — only composite scores.

**Status:** RESOLVED (commit b5510e9)

**Verification of fix:**

1. **AthleteRow struct** (SyncService.swift lines 808-826): `isOnHormonalContraceptive`, `isPregnant`, and `isLactating` are absent. A PRIVACY comment at lines 821-823 explicitly documents the intentional exclusion:
   > `// PRIVACY: reproductive-health flags (isOnHormonalContraceptive, isPregnant, // isLactating) are intentionally NOT synced — they stay device-local per the // cycle-data privacy invariant. Do not add them to this row. (Phase 18 / CR-01)`

2. **pushAthlete** (lines 217-239): The `AthleteRow` initializer contains no reproductive-health fields. Grep for `isOnHormonalContraceptive\|isPregnant\|isLactating` across all of `SyncService.swift` returns only the two privacy-comment lines — zero functional references.

3. **pullAthlete** (lines 242-271): Does not read or write any reproductive-health field to the local `Athlete`.

4. **Gate still works:** `CycleTrackingService.swift` reads `athlete.isOnHormonalContraceptive`, `athlete.isPregnant`, and `athlete.isLactating` directly from the SwiftData `Athlete` model (local device only) to populate `CycleContext`. `CycleContext.hasExclusion` (MenstrualCycleSnapshot.swift:67-69) computes the boolean locally. The privacy gate is fully functional through local reads — no Supabase round-trip.

5. **Server-side cleanup:** `migrations/drop_reproductive_health_fields_from_athletes.sql` drops `is_on_hormonal_contraceptive`, `is_pregnant`, and `is_lactating` columns from the Supabase `athletes` table with `ALTER TABLE athletes DROP COLUMN IF EXISTS`.

6. **Athlete model retains fields:** `Athlete.swift` lines 21-23 still declare `var isOnHormonalContraceptive: Bool?`, `var isPregnant: Bool?`, `var isLactating: Bool?` as local SwiftData properties. The gate driver is intact.

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `WorkloadApp/Services/RecoveryScoreEngine.swift` | Same-phase baseline computation, bucket mapping, RecoveryInput extension, baseline source selection | VERIFIED | `PhaseBucket` enum, `bucket(for:)`, `samePhaseBaseline(readings:)`, `samePhaseHRVBaseline`/`samePhaseRestingHRBaseline` fields, `??` selection in `compute()`. Pure struct, no HealthKit/SwiftData imports. |
| `WorkloadAppTests/RecoveryScoreEngineTests.swift` | Worked-example unit tests + identical-behavior regression + per-bucket-minimum tests | VERIFIED | All required tests present and substantive. xcodebuild TEST SUCCEEDED (confirmed by user). |
| `WorkloadApp/Services/RecoveryPipeline.swift` | Gated same-phase baseline derivation, CycleTrackingService query, engine wiring | VERIFIED | `cycleTrackingService: CycleTrackingService? = nil` parameter (line 25), full gate + read-time join + engine wiring (lines 74-112). `upsertRecoverySnapshot` contains no cycle-derived fields. |
| `WorkloadApp/Repositories/CycleSnapshotRepository.swift` | Date-windowed MenstrualCycleSnapshot reads | VERIFIED | `@MainActor final class CycleSnapshotRepository` with `init(modelContext:)` and `fetchCycleSnapshots(days:athlete:)`. Athlete-scoped `FetchDescriptor`. No Supabase import. |
| `WorkloadApp/App/AppContainer.swift` | CycleTrackingService declared and instantiated | VERIFIED | `let cycleTrackingService: CycleTrackingService` (line 16), initialized as `CycleTrackingService()` (line 55). |
| `WorkloadApp/Services/SyncService.swift` | AthleteRow MUST NOT contain reproductive-health fields | VERIFIED (re-verified) | Three fields absent from AthleteRow, pushAthlete, and pullAthlete. Privacy comment installed at line 821-823. Only mentions are in comment text, zero functional references. |
| `migrations/drop_reproductive_health_fields_from_athletes.sql` | DROP COLUMN migration for three columns | VERIFIED | File exists, contains three `ALTER TABLE athletes DROP COLUMN IF EXISTS` statements for `is_on_hormonal_contraceptive`, `is_pregnant`, `is_lactating`. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `RecoveryPipeline.run` | `CycleTrackingService.run` | optional injected service parameter | VERIFIED | `if let cycleTrackingService { let ctx = await cycleTrackingService.run(...) }` (pipeline.swift:74-75) |
| `RecoveryPipeline.run` | `RecoveryScoreEngine.samePhaseBaseline` | read-time join, bucket filter, passed as RecoveryInput same-phase fields | VERIFIED | Lines 84-111: fetches both histories, joins by `startOfDay`, collects same-bucket readings, calls `RecoveryScoreEngine.samePhaseBaseline(readings:)`, assigns to `samePhaseHRVBaseline`/`samePhaseRestingHRBaseline` |
| `CycleTrackingService` | `Athlete` (SwiftData, local) | direct property read | VERIFIED | CycleTrackingService.swift reads `athlete.isOnHormonalContraceptive`, `isPregnant`, `isLactating` from local SwiftData model — NOT from Supabase |
| `CycleContext.hasExclusion` | `RecoveryPipeline.run` gate | computed Bool on local CycleContext struct | VERIFIED | MenstrualCycleSnapshot.swift:67-69 computes locally; pipeline.swift:79 uses `!ctx.hasExclusion` |
| `DashboardView` | `DashboardViewModel.load` | `container.cycleTrackingService` | VERIFIED | DashboardView.swift:242 passes `container.cycleTrackingService` |
| `RecoveryView` | `RecoveryViewModel.onWellnessCheckInSaved` | `container.cycleTrackingService` | VERIFIED | RecoveryView.swift:195 passes `container.cycleTrackingService` |
| `CycleSnapshotRepository` | `project.pbxproj` | file registered in app target | VERIFIED | pbxproj contains 4 references to `CycleSnapshotRepository.swift` |

### Data-Flow Trace (Level 4)

Not applicable — phase adds algorithmic computation to an existing data pipeline, not a new UI component rendering dynamic data. The pipeline-level data flow is verified via key links above and the read-time join in `RecoveryPipeline.run`.

### Behavioral Spot-Checks

Step 7b is SKIPPED for the engine tests (they require the iOS Simulator and xcodebuild, not a standalone CLI). The user confirmed `xcodebuild test` on iPhone 17 Pro Max simulator returned TEST SUCCEEDED for the full WorkloadAppTests suite (initial verification) and BUILD SUCCEEDED after the CR-01 fix (re-verification). This is accepted as authoritative.

### Probe Execution

No probe scripts declared in PLAN.md or found under `scripts/*/tests/`. SKIPPED.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| CYCLE-04 | 18-01-PLAN.md, 18-02-PLAN.md | Same-phase baseline algorithm: bucket mapping, equal-weight mean, 4-reading minimum, RecoveryInput extension, baseline source selection in compute() | SATISFIED | All algorithm components verified in RecoveryScoreEngine.swift; full unit test suite green |
| CYCLE-05 | 18-02-PLAN.md | Pipeline integration: CycleTrackingService query, confidence-gated derivation, graceful 7-day fallback, AppContainer + ViewModel wiring | SATISFIED | RecoveryPipeline.run implements gate, join, and wiring; AppContainer owns service; both ViewModels thread it through; nil-service path is byte-identical to pre-change |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| _(none)_ | — | — | — | CR-01 resolved. No TBD/FIXME/XXX markers found. No stub patterns. |

**Advisory follow-ups (non-blocking, retained from initial verification):**

- **WR-02** (WARNING): `samePhaseBaseline(readings:)` returns nil for `count < 4` but does not separately guard against a zero-value average (all readings = 0 would produce 0.0, not nil). No practical impact today — HRV/RHR readings are always positive values from HealthKit. Latent correctness gap only.
- **WR-03** (INFO): `CycleSnapshotRepository.fetchCycleSnapshots` does not yet have unit tests of its own; coverage is via integration through RecoveryPipeline tests. Low risk given its simplicity.
- **WR-04** (INFO): The `drop_reproductive_health_fields_from_athletes.sql` migration must be applied to the production Supabase project before the next app store release to complete the server-side privacy cleanup.

### Human Verification Required

None — the phase is algorithm and pipeline only. All behavioral contracts are covered by unit tests. The CR-01 blocker was a code-level privacy issue resolved in code; no UI/UX concern requires human testing.

---

## Re-verification Summary

**Gap closed:** CR-01 (BLOCKER) — reproductive-health fields removed from Supabase sync path.

**Evidence:**
- `AthleteRow` in `SyncService.swift` contains no `isOnHormonalContraceptive`, `isPregnant`, or `isLactating` fields. Only references to these names in the file are two lines of a privacy comment (lines 821-822) documenting the intentional exclusion.
- `pushAthlete` builds `AthleteRow` with 12 fields; none are reproductive-health flags.
- `pullAthlete` writes back only display/profile/timestamp fields; no reproductive-health fields.
- `CycleTrackingService` reads all three booleans from the local SwiftData `Athlete` model directly — the gate driver is intact and functions entirely on-device.
- `migrations/drop_reproductive_health_fields_from_athletes.sql` exists with correct `DROP COLUMN IF EXISTS` statements for all three columns.
- Build status: BUILD SUCCEEDED on iPhone 17 Pro Max (user-confirmed, post-fix).

**Regressions:** None detected. All 7 success criteria remain VERIFIED.

---

_Verified: 2026-05-25T15:00:00Z_
_Verifier: Claude (gsd-verifier)_
_Re-verification of: initial 2026-05-25T14:10:00Z (gaps_found)_
