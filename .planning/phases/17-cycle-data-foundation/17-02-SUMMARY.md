---
phase: 17-cycle-data-foundation
plan: 02
subsystem: cycle-tracking
tags: [healthkit, menstrual-cycle, phase-estimation, confidence-scoring]
dependency_graph:
  requires: [17-01]
  provides: [CycleTrackingService, HealthKit-menstrual-readTypes]
  affects: [RecoveryPipeline, DashboardViewModel]
tech_stack:
  added: []
  patterns: [gap-based-fallback, metadata-cycle-detection, fixed-luteal-model, biphasic-shift-detection]
key_files:
  created:
    - WorkloadApp/Services/CycleTrackingService.swift
  modified:
    - WorkloadApp/Services/HealthKitService.swift
    - workload management/workload management.xcodeproj/project.pbxproj
decisions:
  - "OC users get .unknown phase -- skip phase estimation (D-04)"
  - "Minimum 2 period starts required for any phase estimation (D-05)"
  - "Irregular cycles (CV > 0.20) penalized with -0.20 confidence (D-06)"
  - "Wrist temp biphasic shift is optional confidence booster, never required"
  - "Gap-based fallback uses 14+ day gap threshold for third-party app compatibility"
metrics:
  duration: 154s
  completed: 2026-05-14
  tasks: 2
  files: 3
---

# Phase 17 Plan 02: CycleTrackingService Summary

HealthKit menstrual flow reader with metadata+gap-based cycle detection, 14-day fixed luteal phase estimator, and multi-factor confidence scorer producing CycleContext for downstream engines.

## Completed Tasks

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Extend HealthKitService readTypes with menstrual category types | 8dfbb42 | HealthKitService.swift |
| 2 | Create CycleTrackingService with HealthKit reader, phase estimator, confidence scorer | 815c3cc | CycleTrackingService.swift, project.pbxproj |

## Implementation Details

### Task 1: HealthKitService readTypes Extension

Added 6 menstrual HKCategoryType entries to the existing `readTypes` computed property:
- `menstrualFlow` -- core cycle tracking data
- `contraceptive` -- OC detection
- `pregnancy` -- pregnancy exclusion
- `lactation` -- lactation exclusion
- `irregularMenstrualCycles` -- irregularity detection
- `ovulationTestResult` -- ovulation data

Single permission sheet covers all health + menstrual types via existing `requestAuthorization()`.

### Task 2: CycleTrackingService

Created `@MainActor final class CycleTrackingService` with the full cycle tracking pipeline:

1. **Exclusion check** -- pregnancy/lactation return `.unknown` immediately
2. **HealthKit fetch** -- reads menstrual flow samples (365 days) with `HKMetadataKeyMenstrualCycleStart` metadata
3. **Cycle start detection** -- metadata-based primary, gap-based fallback (14+ day gap) for third-party apps
4. **Cycle length computation** -- from consecutive start dates with median + coefficient of variation
5. **Phase estimation** -- 14-day fixed luteal model with 5 phases (earlyFollicular, lateFollicular, ovulatory, earlyLuteal, lateLuteal)
6. **Confidence scoring** -- multi-factor: completed cycles (0.4/0.6/0.7 base), regularity CV bonus/penalty, optional wrist temp biphasic shift (+0.15)
7. **Snapshot persistence** -- upserts daily `MenstrualCycleSnapshot`
8. **CycleContext production** -- lightweight struct for downstream engine consumption

## Deviations from Plan

None -- plan executed exactly as written.

## Threat Surface Scan

No new network endpoints, auth paths, or sync paths introduced. CycleTrackingService is local-only (no SyncService imports). Verified: `grep -rn "SyncService" WorkloadApp/Services/CycleTrackingService.swift` returns no matches.

## Known Stubs

None -- all methods are fully implemented with real HealthKit queries.

## Self-Check: PASSED

- [x] WorkloadApp/Services/CycleTrackingService.swift exists (FOUND)
- [x] WorkloadApp/Services/HealthKitService.swift contains 6 menstrual types (FOUND)
- [x] Commit 8dfbb42 exists (FOUND)
- [x] Commit 815c3cc exists (FOUND)
- [x] No SyncService references in CycleTrackingService (VERIFIED)
- [x] CycleTrackingService added to Xcode project (4 pbxproj references)
