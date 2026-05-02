---
phase: 09-foundation-cold-start-engine
reviewed: 2026-05-02T18:45:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - WorkloadApp/Models/TrainingProfile.swift
  - WorkloadApp/Models/WorkoutTemplate.swift
  - WorkloadApp/Models/Enums.swift
  - WorkloadApp/App/WorkloadApp.swift
  - WorkloadApp/Services/ColdStartEngine.swift
  - WorkloadApp/Repositories/TemplateRepository.swift
  - WorkloadApp/Services/SyncService.swift
  - Supabase/migrations/006_v1.2_foundation.sql
findings:
  critical: 1
  warning: 3
  info: 3
  total: 7
status: issues_found
---

# Phase 9: Code Review Report

**Reviewed:** 2026-05-02T18:45:00Z
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

Reviewed the Phase 9 foundation and cold-start engine additions: the `TrainingProfile` SwiftData model, `ColdStartEngine` pure computation struct, `TemplateRepository` for athlete-owned templates, new template management fields on `WorkoutTemplate`, enum additions (`BodyRegion`, `InjuryEntry`, `SessionType`), the `TrainingProfile` sync integration in `SyncService`, and the corresponding Supabase migration.

Overall the code is well-structured and follows project conventions. The `ColdStartEngine` is clean, deterministic, and properly delegates to `WorkloadCalculator.sessionTSS`. The `TrainingProfile` model correctly uses a UUID foreign key (not a `@Relationship`) as documented. The SQL migration has proper RLS policies and indexes.

Key concerns: one potential CodingKeys conflict in `BehaviorTagRow` that may cause sync failures, a data integrity gap on pull where `createdAt` is not preserved, and missing input validation on sign-up.

## Critical Issues

### CR-01: BehaviorTagRow CodingKeys conflict with global keyDecodingStrategy

**File:** `WorkloadApp/Services/SyncService.swift:529-537`
**Issue:** `BehaviorTagRow` defines explicit `CodingKeys` that map camelCase properties to snake_case strings (e.g., `case athleteId = "athlete_id"`). However, `AppContainer` configures the `SupabaseClient` decoder with `.convertFromSnakeCase` (line 37 of `AppContainer.swift`). When both are active, the decoder first converts the JSON key `"athlete_id"` to `"athleteId"`, then tries to match against CodingKeys whose stringValue is `"athlete_id"` -- potentially causing a mismatch. This pattern is fragile and differs from every other Row type in the file (which all rely solely on the automatic strategy without explicit CodingKeys).

If this code currently works, it is because Swift's implementation may have a fallback path, but it is an undocumented behavior that could break with a Swift or Supabase SDK update. All other Row types (`WorkloadSnapshotRow`, `RecoverySnapshotRow`, `TrainingProfileRow`, etc.) correctly rely on the automatic strategy alone.

**Fix:** Remove the explicit `CodingKeys` from `BehaviorTagRow` to match the pattern used by all other Row types. The global `.convertFromSnakeCase` / `.convertToSnakeCase` strategies handle the mapping automatically:
```swift
struct BehaviorTagRow: Codable {
    let id: UUID
    let athleteId: UUID
    let date: Date
    let tagName: String
    let isActive: Bool
    let isCustom: Bool
    let createdAt: Date
    let updatedAt: Date

    // CodingKeys removed -- handled by global keyDecodingStrategy

    init(from tag: BehaviorTag, athleteId: UUID) {
        self.id = tag.id
        self.athleteId = athleteId
        self.date = tag.date
        self.tagName = tag.tagName
        self.isActive = tag.isActive
        self.isCustom = tag.isCustom
        self.createdAt = tag.createdAt
        self.updatedAt = tag.updatedAt
    }
}
```

## Warnings

### WR-01: TrainingProfile createdAt not preserved on pull from Supabase

**File:** `WorkloadApp/Services/SyncService.swift:791-817`
**Issue:** When `pullTrainingProfile` creates a new local `TrainingProfile` from a remote row (fresh device scenario), the `createdAt` timestamp defaults to `.now` (set in `TrainingProfile.init`) rather than using `row.createdAt`. This means after a pull on a new device, the local `createdAt` will differ from the remote value. On the next `pushAll`, the incorrect `createdAt` will overwrite the correct value in Supabase (since push is a full upsert). This affects data integrity for audit/analytics use cases.

The existing update path (lines 772-789) correctly preserves the remote `updatedAt` but the new-insert path does not preserve `createdAt`.

**Fix:** After creating the new `TrainingProfile`, set `createdAt` from the row:
```swift
let profile = TrainingProfile(
    id: row.id,
    athleteId: row.athleteId,
    sessionsPerWeek: row.sessionsPerWeek,
    avgDurationMinutes: row.avgDurationMinutes,
    typicalSRPE: row.typicalSrpe,
    weeksAtLevel: row.weeksAtLevel,
    seededATL: row.seededAtl,
    seededCTL: row.seededCtl,
    seededAt: row.seededAt
)
profile.createdAt = row.createdAt  // <-- add this line
// ... rest of property assignments
```

### WR-02: SignUpView allows form submission with arbitrarily short password

**File:** `WorkloadApp/Views/Auth/SignUpView.swift:164-166`
**Issue:** The `isFormValid` computed property only checks `!password.isEmpty`, but the placeholder text says "Min. 8 characters" (line 57). While Supabase enforces a minimum password length server-side and will return an error, this creates a poor user experience: the user can tap "Create Account" with a 1-character password, wait for the network round-trip, and only then see an error. Client-side validation should match the server constraint.

**Fix:** Add minimum length check:
```swift
private var isFormValid: Bool {
    !displayName.isEmpty && !email.isEmpty && password.count >= 8
}
```

### WR-03: ColdStartEngine does not validate negative input values

**File:** `WorkloadApp/Services/ColdStartEngine.swift:58-93`
**Issue:** `computeSeed` clamps RPE to `[1, 10]` and guards against zero sessions/duration, but does not handle negative values for `sessionsPerWeek`, `avgDurationMinutes`, or `weeksAtLevel`. A negative `sessionsPerWeek` (e.g., -1) passes the `> 0` guard but produces a negative `dailyTSS`, which cascades into negative `seededATL` and `seededCTL`. The ramp factor with a negative `weeksAtLevel` would be `max(0.3, min(1.0, negativeValue / 6.0))` = 0.3, so it is partially protected, but the overall result would still be negative and semantically invalid.

While the UI questionnaire should prevent negative input, the engine is a pure struct that may be called from tests or future code paths.

**Fix:** Clamp or guard against negative values:
```swift
guard input.sessionsPerWeek > 0, input.avgDurationMinutes > 0 else {
    return SeedResult(seededATL: 0, seededCTL: 0, dailyTSS: 0, sessionTSS: 0)
}
let clampedWeeks = max(1, input.weeksAtLevel)
// ... use clampedWeeks instead of input.weeksAtLevel
```

## Info

### IN-01: Redundant SCREENSHOT_MODE check in AppRouter

**File:** `WorkloadApp/App/AppRouter.swift:120-126`
**Issue:** Lines 120-126 check for `SCREENSHOT_MODE` again inside the `if hasSession` block. However, the earlier `SCREENSHOT_MODE` block (lines 54-79) already returns from the `.task` closure, so this code is unreachable when `SCREENSHOT_MODE` is active. This is dead code.

**Fix:** Remove the inner `SCREENSHOT_MODE` check (lines 120-126) since it can never execute.

### IN-02: SignUpSocialError.athleteNotFound is unused

**File:** `WorkloadApp/Views/Auth/SignUpView.swift:278`
**Issue:** The `SignUpSocialError.athleteNotFound` case is declared but never thrown anywhere in the file. The social sign-in flows create a new athlete when bootstrap returns nil rather than throwing this error.

**Fix:** Remove the unused case or add a comment explaining its intended future use.

### IN-03: TrainingProfile.injuryHistory stored as raw Data instead of typed array

**File:** `WorkloadApp/Models/TrainingProfile.swift:29`
**Issue:** `injuryHistory` is declared as `Data?` while the `InjuryEntry` struct (defined in `Enums.swift:372-376`) is `Codable`. Storing as `Data` loses type safety and requires manual encode/decode at every call site. The `SyncService` converts between `Data` and `String` (lines 780, 1056), adding fragility. Consider using `[InjuryEntry]?` directly -- SwiftData supports `Codable` array properties via `@Attribute(.transformable)` or automatic JSON encoding.

**Fix:** This is a design consideration for a future refactor. The current approach works but adds boilerplate and risk of deserialization errors at each usage site.

---

_Reviewed: 2026-05-02T18:45:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
