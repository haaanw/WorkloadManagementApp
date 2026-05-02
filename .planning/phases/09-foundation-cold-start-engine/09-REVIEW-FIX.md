---
phase: 09-foundation-cold-start-engine
fixed_at: 2026-05-02T18:55:00Z
review_path: .planning/phases/09-foundation-cold-start-engine/09-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase 9: Code Review Fix Report

**Fixed at:** 2026-05-02T18:55:00Z
**Source review:** .planning/phases/09-foundation-cold-start-engine/09-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 4
- Fixed: 4
- Skipped: 0

## Fixed Issues

### CR-01: BehaviorTagRow CodingKeys conflict with global keyDecodingStrategy

**Files modified:** `WorkloadApp/Services/SyncService.swift`
**Commit:** de2c2e4
**Applied fix:** Removed the explicit `CodingKeys` enum from `BehaviorTagRow`. The global `.convertFromSnakeCase` / `.convertToSnakeCase` decoder strategy configured in `AppContainer` handles the camelCase-to-snake_case mapping automatically, matching the pattern used by all other Row types in the file.

### WR-01: TrainingProfile createdAt not preserved on pull from Supabase

**Files modified:** `WorkloadApp/Services/SyncService.swift`
**Commit:** 8bb27fa
**Applied fix:** Added `profile.createdAt = row.createdAt` in the new-insert branch of `pullTrainingProfile`, immediately after constructing the `TrainingProfile` instance and before other property assignments. This preserves the original remote `createdAt` timestamp on fresh-device pulls, preventing incorrect values from overwriting the Supabase record on the next push.

### WR-02: SignUpView allows form submission with arbitrarily short password

**Files modified:** `WorkloadApp/Views/Auth/SignUpView.swift`
**Commit:** 315d9ed
**Applied fix:** Changed `isFormValid` from `!password.isEmpty` to `password.count >= 8`, matching the placeholder text "Min. 8 characters" and the Supabase server-side constraint. The Create Account button is now disabled until the password meets the minimum length requirement.

### WR-03: ColdStartEngine does not validate negative input values

**Files modified:** `WorkloadApp/Services/ColdStartEngine.swift`
**Commit:** 9cc8046
**Applied fix:** Added `let clampedWeeks = max(1, input.weeksAtLevel)` before the ramp factor calculation, replacing direct use of `input.weeksAtLevel`. This ensures negative or zero values for `weeksAtLevel` produce a valid ramp factor (minimum 0.3 floor). Updated the doc comment to document all three validation rules. Note: `sessionsPerWeek` and `avgDurationMinutes` negative values were already handled by the existing `> 0` guard.

---

_Fixed: 2026-05-02T18:55:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
