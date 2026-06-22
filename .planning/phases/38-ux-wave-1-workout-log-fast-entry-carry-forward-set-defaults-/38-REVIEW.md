---
phase: 38-ux-wave-1-workout-log-fast-entry
reviewed: 2026-06-02T00:00:00Z
depth: deep
files_reviewed: 4
files_reviewed_list:
  - WorkloadApp/Components/SetStepper.swift
  - WorkloadApp/Components/PRBanner.swift
  - WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift
  - WorkloadApp/Resources/Localizable.xcstrings
findings:
  critical: 0
  warning: 3
  info: 4
  total: 7
status: issues_found
---

# Phase 38: Code Review Report

**Reviewed:** 2026-06-02
**Depth:** deep (cross-file: PersonalRecord, SpikeAlertBanner, FinishWorkoutSheet, NiggleLogSheet, Spacing, WeightFormatter verified)
**Files Reviewed:** 4
**Status:** issues_found

## Summary

The Phase 38 fast-entry refactor is solid on its core invariants. The commit-first ordering holds: `saveSession()` calls `modelContext.save()` (line 522) before the pipeline runs and before any banner fires, the banners are non-blocking overlays, and the `advancePostSave()` gate correctly waits for BOTH inline banners to dismiss before sequencing the niggle nudge. The deleted `PRCelebrationOverlay` is fully removed with no dangling references; `PRBanner`/`SpikeAlertBanner` signatures match call sites; all referenced tokens (`Spacing.xl/sm/xs`, `Font.Tokens.*`, `WeightFormatter.toKg`) resolve. The new localization keys (`set.action.repeatLast`, `set.rpe.add`) exist with both en + zh-Hans translations and correct format specifiers. No accent-color, corner-radius, or shadow violations were introduced. No SetRecord/schema/algorithm/flag changes.

The findings below are real but none block ship: one localization correctness bug carried over from the deleted overlay into the new PRBanner, one carry-forward feature gap for cardio set rows, and a clamp edge case. The rest are informational.

## Warnings

### WR-01: PR title pluralization injects literal English "s" into all locales

**File:** `WorkloadApp/Components/PRBanner.swift:18`
**Issue:** `String(format: String(localized: "workout.pr.title", ...), prs.count > 1 ? "s" : "")` substitutes a hardcoded English plural marker `"s"` into the `%@` slot. The zh-Hans value is `"新纪录%@！"`, so a multi-PR session renders `新纪录s！` — a literal Latin "s" inside Chinese copy. English-centric pluralization does not localize. (This was carried over verbatim from the deleted `PRCelebrationOverlay`; the new component inherits the defect, and the phase touched this code, so it is in scope.)
**Fix:** Use a `.stringsdict`/xcstrings plural variation keyed on `prs.count`, or split into two flat keys:
```swift
Text(prs.count > 1
    ? String(localized: "workout.pr.title.plural", defaultValue: "New PRs!")
    : String(localized: "workout.pr.title.single", defaultValue: "New PR!"))
```
with proper zh-Hans values (`新纪录！` for both, since Chinese does not inflect for plural).

### WR-02: "Add set" carry-forward drops distance/duration for cardio rows

**File:** `WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift:696-704` (`addCarriedSet`)
**Issue:** `addCarriedSet()` only carries the previous set's `weightKg`, `reps`, and `rpe` forward as ghost baselines. For `.distanceDuration` and `.durationOnly` exercises (running, swimming, etc.) the new row is created with no `distanceMeters`/`durationSeconds` ghost, so the headline "carry-forward set defaults" benefit of this phase silently does not apply to cardio. `repeatLastSet()` (lines 712-713) correctly handles distance/duration, which makes the inconsistency more conspicuous — "Repeat last" carries them, "Add set" does not. Note also that `SetDraft` has no `targetDuration`/`targetDistance` ghost fields, so the SetStepper-less cardio TextFields (lines 960-974) have no ghost-rendering path at all.
**Fix:** Either carry the concrete values forward for cardio in `addCarriedSet`:
```swift
draft.durationSeconds = last.durationSeconds
draft.distanceMeters = last.distanceMeters
```
(accepting that these land as committed, not ghosted, since no target fields exist), or add `targetDuration`/`targetDistance` ghost fields to `SetDraft` and wire cardio TextFields to render them. At minimum document that carry-forward is weight/reps-only by design.

### WR-03: Stepper minus on an empty no-ghost field commits a spurious 0

**File:** `WorkloadApp/Components/SetStepper.swift:39-47, 99-107`
**Issue:** When `value == nil` and `ghostBaseline == nil` (e.g. a fresh cardio-adjacent reps field with no history), pressing "−" computes `base = floor = 0`, then `value = max(0, 0 - increment) = 0`. This commits a concrete `0` into a set that the user may have intended to leave blank, converting an "empty/unentered" set into a "0 reps / 0 kg" set. Empty sets are later filtered out in `saveAsTemplateFromSession` (line 608) on the `!= nil` check, so a spurious `0` will now pass that filter and persist a meaningless set into a saved template, and into the session itself (`saveSession` copies all sets unconditionally, lines 491-503).
**Fix:** Make the first "−" tap a no-op when there is nothing to decrement from, or floor the commit to `nil` when it would land on the floor with no prior value:
```swift
private func stepDown() {
    guard let base = value ?? ghostBaseline else { return } // nothing to step from
    value = max(floor, base - increment)
}
```
("+" is fine — committing the increment from 0 is intentional.)

## Info

### IN-01: `durationOnly` placeholder says "min" but binds to a seconds field

**File:** `WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift:971`
**Issue:** `TextField("min", value: $set.durationSeconds, ...)` labels the field "min" while writing raw entered value into `durationSeconds` with no ×60 conversion — a 30-minute run entered as "30" stores 30 seconds. Verified pre-existing (present in commit e074061 before this phase), so out of Phase 38 scope, but it sits in modified code and is a genuine correctness bug worth a follow-up ticket.
**Fix:** Either change placeholder to "sec", or convert on commit (`durationSeconds = enteredMinutes * 60`).

### IN-02: Silent data loss on save failure with no user feedback

**File:** `WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift:521-527`
**Issue:** If `modelContext.save()` throws, the code `print`s and `dismiss()`es. The FinishWorkoutSheet has already dismissed itself, so the user sees the workout sheet close as if the save succeeded — the entire logged session is silently lost. Consistent with the project's print-logging convention, so informational, but the existing `ToastBanner`/`templateSaveError` machinery already in this file could surface an error toast before dismissing.
**Fix:** Reuse the error-toast path (set an error flag + present toast) instead of dismissing on the save-failure branch, or keep the sheet open so the user can retry.

### IN-03: `defaultSessionType(for: .custom)` reads mutable view state

**File:** `WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift:351`
**Issue:** The `.custom` branch returns `sessionType` (the current `@State`), so switching to `.custom` is a no-op for session type by design. Reading view state inside a helper named like a pure mapping is slightly surprising but behaviorally correct. No fix required; noted for clarity.

### IN-04: `setIndex` recomputed via linear `firstIndex` per row

**File:** `WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift:771`
**Issue:** `entry.sets.firstIndex(where: { $0.id == set.id }) ?? 0` recomputes index per row each render. Functionally correct (stable UUID identity), and performance is out of v1 scope, but `ForEach(Array(entry.sets.enumerated()), ...)` or an index-based `ForEach` would avoid the lookup and the `?? 0` fallback that would silently mis-number a row if identity ever desynced. Informational only.

---

_Reviewed: 2026-06-02_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_
