---
phase: 25-soreness-tweak-self-log
plan: 01
subsystem: data-model
tags: [swiftdata, local-only, niggle, soreness, privacy]
requires: []
provides:
  - SorenessLog @Model (local-only)
  - NiggleType enum
  - SorenessLogRepository (@MainActor)
affects:
  - Plan 02 (.niggleSeverity shadow outcome)
  - Plan 03 (fatigue-input derivation)
  - Phase 27 (localized Strain-Risk channel)
tech-stack:
  added: []
  patterns:
    - "Local-only @Model by omission (no Codable, absent from SyncService) — mirrors CyclePredictionLog/ShadowArmPrediction"
    - "Date-windowed FetchDescriptor + Swift-side athlete filter (avoids iOS 26.1 optional-relationship #Predicate trap)"
key-files:
  created:
    - WorkloadApp/Models/SorenessLog.swift
    - WorkloadApp/Repositories/SorenessLogRepository.swift
    - WorkloadAppTests/SorenessLogModelTests.swift
  modified:
    - WorkloadApp/Models/Enums.swift
    - WorkloadApp/App/WorkloadApp.swift
    - workload management/workload management.xcodeproj/project.pbxproj
decisions:
  - "insert(...) self-saves (try? modelContext.save() inside the repo) — caller need not save"
  - "fetchRecent returns newest-first (descending date)"
  - "Region stored as MuscleGroup.rawValue (33-case taxonomy), not MuscleRegion/BodyRegion"
metrics:
  duration: "~10 min"
  completed: 2026-05-30
---

# Phase 25 Plan 01: Soreness Self-Log Data Foundation Summary

Local-only `SorenessLog` SwiftData @Model (region + niggle type + 0–10 severity + limited-training flag + optional note), a `NiggleType` domain enum, and a thin `@MainActor` `SorenessLogRepository` — the never-synced on-device source of localized breakdown signal for Phase 27, built green via real xcodebuild with correct `.pbxproj` target membership.

## What Was Built

**Task 1 — NiggleType enum + local-only SorenessLog @Model + schema registration** (commit `97fd47e`)
- `NiggleType: String, Codable, CaseIterable, Identifiable { soreness, pain, tweak }` added to `Enums.swift`, mirroring the `PRType` style. RawValues `"soreness"/"pain"/"tweak"` are a permanent serialization contract; `id` + localized `displayName` provided. (The enum is `Codable` — only the @Model avoids it.)
- `SorenessLog.swift` — local-only `@Model final class` copied in shape from `ShadowArmPrediction`/`CyclePredictionLog`: leading "Local-only — never syncs to Supabase (P25 D-01)" doc-comment; fields `@Attribute(.unique) var id: UUID`, `var date: Date` (real timestamp, not start-of-day), `var regionRaw: String` (a `MuscleGroup.rawValue`), `var typeRaw: String` (a `NiggleType.rawValue`), `var severity: Int` (0–10), `var limitedTraining: Bool` (required, default `false` — D-03), `var note: String?`, `var updatedAt: Date`, and a bare `var athlete: Athlete?` inverse (no `[SorenessLog]` array on `Athlete`). Memberwise init with `limitedTraining: Bool = false` and `note: String? = nil` defaults. NO Codable, no encoder, no `*Row` DTO.
- `SorenessLog.self` registered in the app `Schema([...])` (`WorkloadApp.swift`) — additive, SwiftData lightweight migration, no MigrationPlan (matches the ShadowArmPrediction precedent).
- `SorenessLogModelTests.swift` — in-memory `ModelContainer` whose schema includes `SorenessLog.self`; 4 tests: field-fidelity round-trip, NiggleType rawValue stability (3 cases, exact rawValues), nil-note + limitedTraining-default fidelity, MuscleGroup rawValue reconstruction. Tests use fetch-all + Swift filter (no optional-relationship `#Predicate`) to dodge the iOS 26.1 in-memory trap. **4/4 pass.**

**Task 2 — SorenessLogRepository** (commit `cb42732`)
- `@MainActor final class SorenessLogRepository` taking `private let modelContext: ModelContext` in init (mirrors `CyclePredictionLogRepository`).
- `insert(region: MuscleGroup, type: NiggleType, severity: Int, limitedTraining: Bool, note: String?, athlete: Athlete?) -> SorenessLog` — constructs `SorenessLog(date: .now, regionRaw: region.rawValue, typeRaw: type.rawValue, …)`, inserts, **saves inside the repo** (`try? modelContext.save()`), returns the row (`@discardableResult`).
- `fetchRecent(days: Int, athlete: Athlete?) -> [SorenessLog]` — date-windowed `FetchDescriptor` (`date >= Calendar.startOfDay(now - days)`), sorted **newest-first** (`order: .reverse`); `athlete` filtered in Swift after the fetch (no `athlete?.id` predicate). No sync code.

## Decisions Made

- **insert self-saves:** the repository calls `try? modelContext.save()` inside `insert(...)` rather than deferring to the caller. This matches the find-or-create+save convention of `CyclePredictionLogRepository.upsertPrediction`, and gives downstream callers a one-call write. A separate public `save()` is also exposed for batch scenarios.
- **fetchRecent ordering = newest-first** (descending `date`). The Plan 03 derivation helper is order-agnostic; newest-first chosen for UI-friendliness and consistency.
- **Region taxonomy = `MuscleGroup.rawValue`** (the 33-case enum), not `MuscleRegion` (7-case) or `BodyRegion` (joints) — Phase-27-aligned per D-02 / RESEARCH §2.

## Deviations from Plan

**1. [Rule 3 - Project structure] Test file does NOT need a manual `project.pbxproj` edit.**
- **Found during:** Task 1, while inspecting the pbxproj to add the test file.
- **Issue:** The plan's `<action>` instructs adding `SorenessLogModelTests.swift` to the `WorkloadAppTests` target via explicit `PBXBuildFile`/`PBXFileReference`/Sources-phase entries. But the `WorkloadAppTests` target uses a `PBXFileSystemSynchronizedRootGroup` (`path = ../WorkloadAppTests`) — any `.swift` file placed in that directory is automatically a member of the test target. Adding explicit references would have duplicated the file and broken the build.
- **Resolution:** Placed `SorenessLogModelTests.swift` in `WorkloadAppTests/` (auto-included). The app target (`workload management`) does NOT use a synchronized group, so the two new **app** source files (`SorenessLog.swift`, `SorenessLogRepository.swift`) still required the standard four explicit pbxproj entries each — those were added.
- **Verification:** `xcodebuild test -only-testing:WorkloadAppTests/SorenessLogModelTests` discovered and ran all 4 tests (proving the test file is a target member); the app build links `SorenessLog`/`SorenessLogRepository` (proving explicit membership).
- **Files modified:** none beyond plan intent — the net effect matches the plan's goal (all new `.swift` files are members of the correct targets).

No other deviations — both tasks executed as written.

## Verification Results

- **Task 1:** `xcodebuild test ... -only-testing:WorkloadAppTests/SorenessLogModelTests` → **TEST SUCCEEDED**, 4/4 tests passed (`test_niggleType_casesAndRawValues_areStable`, `test_sorenessLog_muscleGroupRawValue_reconstructs`, `test_sorenessLog_nilNote_andLimitedTrainingDefault`, `test_sorenessLog_persistsAndFetchesBack_allFieldsEqual`).
- **Task 2:** `xcodebuild build ...` → **BUILD SUCCEEDED**.
- **Privacy (local-only contract):** `grep -n "Codable\|import Supabase\|encoder" SorenessLog.swift` → only the doc-comment mention (no conformance); `grep -n "SorenessLog" SyncService.swift` → **no matches** (clean, before and after both tasks).
- **Schema registration:** `SorenessLog.self` present in the app `Schema` (WorkloadApp.swift:80) AND the test `ModelContainer` schema (SorenessLogModelTests.swift:20).
- **pbxproj membership:** `SorenessLog.swift` + `SorenessLogRepository.swift` each have PBXBuildFile + PBXFileReference + Models/Repositories group + app-target Sources-phase entries; `SorenessLogModelTests.swift` is a `WorkloadAppTests` member via the synchronized group.

## Self-Check: PASSED

- Files exist: `SorenessLog.swift`, `SorenessLogRepository.swift`, `SorenessLogModelTests.swift`, `Enums.swift` (NiggleType added), `WorkloadApp.swift` (schema updated) — all confirmed.
- Commits exist: `97fd47e` (Task 1), `cb42732` (Task 2) — confirmed in git log.
