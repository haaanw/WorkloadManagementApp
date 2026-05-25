---
phase: 18-cycle-aware-recovery-baselines
audited: 2026-05-25
auditor: gsd-security-auditor
threats_total: 7
threats_closed: 7
threats_open: 0
status: SECURED
asvs_level: default
---

# Phase 18: Cycle-Aware Recovery Baselines — Security Audit

Verification of each declared threat mitigation against implemented code. Implementation
files were treated as read-only; every disposition was confirmed by grep/source inspection,
not by documentation or intent.

## Threat Verification

| Threat ID | Category | Disposition | Status | Evidence |
|-----------|----------|-------------|--------|----------|
| T-18-01 | Information Disclosure | mitigate | CLOSED | `RecoveryScoreEngine.swift:1` imports only `Foundation` (no HealthKit/SwiftData). `RecoveryInput` (lines 20-64) carries only `Double?` baseline values; no `MenstrualCycleSnapshot`/cycle-date/raw-record types. `samePhaseBaseline(readings:)` (line 292) accepts `[Double]` only. |
| T-18-02 | Information Disclosure | accept | CLOSED | New fields `samePhaseHRVBaseline`/`samePhaseRestingHRBaseline` are `let Double?` on the `RecoveryInput` value type (lines 36-37, 51-52). Never persisted: `RecoveryPipeline.upsertRecoverySnapshot` (lines 133-143) passes no same-phase value; SyncService has zero references (grep). Documented in accepted-risk log below. |
| T-18-03 | Tampering | accept | CLOSED | Tests added to existing `WorkloadAppTests/RecoveryScoreEngineTests.swift` (already in target). `tech-stack.added: []` in both summaries; no package installs. Documented in accepted-risk log below. |
| T-18-04 | Information Disclosure | mitigate | CLOSED | `RecoveryPipeline.run` upsert (lines 133-143) and `pushRecoveryAndWellness` call (line 148) pass no cycle-derived field. `grep samePhase\|estimatedPhase\|CycleContext\|MenstrualCycleSnapshot\|CyclePhase` over `SyncService.swift` returns 0 matches. |
| T-18-05 | Information Disclosure | mitigate | CLOSED | `CycleSnapshotRepository.swift` imports only `Foundation`+`SwiftData` (lines 1-2); no `import Supabase`, no encoder, no upload. `fetchCycleSnapshots` (line 28) is an in-memory `FetchDescriptor` read. `MenstrualCycleSnapshot` (model line 5) is local-only, has no `Codable`/encode. |
| T-18-06 | Tampering | mitigate | CLOSED | `grep -c CycleSnapshotRepository project.pbxproj` = 4 (PBXBuildFile, PBXFileReference, group child, Sources phase — lines 51/212/452/907). Build verified BUILD/TEST SUCCEEDED per summaries. |
| T-18-07 | Information Disclosure | accept | CLOSED | Engine boundary receives only aggregate `Double` means: `RecoveryPipeline` (lines 110-111) passes the output of `samePhaseBaseline(readings:)` (a mean `Double?`); no raw reading or record crosses into `RecoveryInput`. Documented in accepted-risk log below. |

**Score: 7/7 threats closed. 0 open.**

## Out-of-Band Finding Verification (CR-01)

Code review CR-01 and phase verification identified a privacy leak NOT in the plan-time
register: reproductive-health flags (`isOnHormonalContraceptive`, `isPregnant`,
`isLactating`) — the inputs to the Phase 18 cycle gate via `CycleContext.hasExclusion` —
were synced to the Supabase `athletes` table. This is on the Phase 18 feature surface and
directly relevant to T-18-04's intent (no cycle/reproductive-derived field leaves the device
via sync). Fix (commit b5510e9) verified present and complete:

| Check | Status | Evidence |
|-------|--------|----------|
| Fields removed from `AthleteRow` | CONFIRMED | `SyncService.swift:808-826` — struct has 12 non-reproductive fields; only a PRIVACY comment (lines 821-823) names the three flags. |
| Removed from `pushAthlete` | CONFIRMED | `SyncService.swift:217-240` — `AthleteRow(...)` initializer contains no reproductive field. |
| Removed from `pullAthlete` | CONFIRMED | `SyncService.swift:242-272` — writes back only display/profile/timestamp fields. |
| Kept local on `Athlete` @Model | CONFIRMED | `Athlete.swift:21-23` retains `isOnHormonalContraceptive/isPregnant/isLactating: Bool?`; model has no `Codable`/encode. Gate driver intact. |
| Server-side column drop migration | CONFIRMED (not yet applied to prod) | `migrations/drop_reproductive_health_fields_from_athletes.sql` — three `ALTER TABLE athletes DROP COLUMN IF EXISTS` statements. |

**Residual action (not a blocker for code audit):** the DROP COLUMN migration must be applied
to the production Supabase project before the next App Store release to complete server-side
cleanup. Existing rows retain the data until then. Tracked as an operational follow-up
(also flagged WR-04 in 18-VERIFICATION.md).

## Accepted Risks Log

- **T-18-02** — New `RecoveryInput` same-phase fields are transient in-memory `Double?` on a
  value type, never persisted or encoded. Accepted: no persistence/sync path touches them
  (verified: not present in `upsertRecoverySnapshot` args nor in `SyncService`).
- **T-18-03** — Test additions to the existing `WorkloadAppTests` target with no new package
  installs. Accepted: no new dependency or build-config attack surface introduced.
- **T-18-07** — Engine receives only aggregate `Double` means at its input boundary. Accepted:
  low residual risk; no raw menstrual record can cross the boundary by construction (the
  `samePhaseBaseline` contract returns a single mean `Double?`).

## Unregistered Flags

None. Both summaries' Threat Surface sections declare "No threat flags / No new security
surface" (no new network endpoints, auth paths, or schema additions). The one new attack
surface that did appear during implementation — the reproductive-flag sync leak — was caught
by code review (CR-01), is mapped to the intent of T-18-04, and has been verified fixed above.

## Conclusion

All 7 declared threats are CLOSED. The plan-time register's privacy posture (no
cycle/menstrual/reproductive data leaves the device via Supabase) holds end-to-end in code,
including the gate-input flags that the register itself did not enumerate. Phase may ship from
a code-security standpoint, contingent on applying the DROP COLUMN migration to production
before release.
