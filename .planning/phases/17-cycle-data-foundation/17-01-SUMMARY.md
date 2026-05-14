---
phase: 17-cycle-data-foundation
plan: 01
subsystem: models
tags: [cycle-data, data-model, enum, sync, migration]
dependency_graph:
  requires: []
  provides: [CyclePhase, MenstrualCycleSnapshot, CycleContext, athlete-cycle-fields]
  affects: [RecoveryScoreEngine, AutoregulationEngine, CycleTrackingService]
tech_stack:
  added: []
  patterns: [one-row-per-day-snapshot, cascade-relationship, codable-enum]
key_files:
  created:
    - WorkloadApp/Models/MenstrualCycleSnapshot.swift
    - migrations/add_cycle_fields_to_athletes.sql
  modified:
    - WorkloadApp/Models/Enums.swift
    - WorkloadApp/Models/Athlete.swift
    - WorkloadApp/Services/SyncService.swift
    - WorkloadApp/App/WorkloadApp.swift
decisions:
  - "CyclePhase uses 6-case enum matching sport science literature phases"
  - "MenstrualCycleSnapshot is local-only (D-12 privacy) -- never synced to Supabase"
  - "Athlete cycle exclusion fields sync via existing AthleteRow push/pull"
  - "Athlete init() not modified -- new fields use implicit nil defaults"
metrics:
  duration: 109s
  completed: 2026-05-14T12:29:22Z
  tasks: 2
  files: 6
---

# Phase 17 Plan 01: Cycle Data Foundation - Models & Types Summary

CyclePhase enum (6 cases), MenstrualCycleSnapshot @Model (local-only per D-12), CycleContext struct, and Athlete model extensions with AthleteRow sync for 3 exclusion fields

## Task Results

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | CyclePhase enum, CycleContext struct, MenstrualCycleSnapshot model | d1cf6c2 | Enums.swift, MenstrualCycleSnapshot.swift |
| 2 | Athlete model, AthleteRow sync, schema registration, migration SQL | 9095f5b | Athlete.swift, SyncService.swift, WorkloadApp.swift, add_cycle_fields_to_athletes.sql |

## What Was Built

### CyclePhase Enum (Enums.swift)
- 6 cases: earlyFollicular, lateFollicular, ovulatory, earlyLuteal, lateLuteal, unknown
- Conforms to String, Codable, CaseIterable, Identifiable (matches existing enum patterns)
- displayName computed property for UI labels

### MenstrualCycleSnapshot Model (MenstrualCycleSnapshot.swift)
- @Model with @Attribute(.unique) id, date, cycleDay, estimatedPhase, confidence, cycleLength, wristTempDeviation, flowIntensity, isCycleStart, exclusion flags, updatedAt
- Follows RecoverySnapshot one-row-per-day pattern exactly
- Local-only: no SyncService integration (D-12 privacy constraint enforced)
- Relationship: var athlete: Athlete?

### CycleContext Struct (MenstrualCycleSnapshot.swift)
- Lightweight value type for engine consumption
- hasExclusion computed property (contraceptive || pregnant || lactating)
- static let none sentinel for non-cycle-tracking athletes

### Athlete Model Extensions (Athlete.swift)
- 3 new optional Bool fields: isOnHormonalContraceptive, isPregnant, isLactating
- @Relationship(deleteRule: .cascade) to MenstrualCycleSnapshot array
- init() signature NOT modified (fields default to nil)

### AthleteRow Sync (SyncService.swift)
- AthleteRow struct extended with 3 new Bool? fields
- pushAthlete maps athlete fields to row
- pullAthlete merges with nil-coalescing (preserves local if remote is nil)

### Schema Registration (WorkloadApp.swift)
- MenstrualCycleSnapshot.self added to schema array

### SQL Migration (migrations/add_cycle_fields_to_athletes.sql)
- 3 ALTER TABLE statements adding nullable boolean columns
- No defaults, no backfill required

## Deviations from Plan

None - plan executed exactly as written.

## D-12 Compliance Verification

MenstrualCycleSnapshot appears in: MenstrualCycleSnapshot.swift, Athlete.swift, WorkloadApp.swift
MenstrualCycleSnapshot does NOT appear in: SyncService.swift (confirmed via grep)

## Known Stubs

None. All types are fully implemented with complete field sets and init methods.

## Self-Check: PASSED
