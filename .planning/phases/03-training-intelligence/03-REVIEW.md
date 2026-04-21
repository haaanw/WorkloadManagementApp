---
phase: 03-training-intelligence
reviewed: 2026-04-21T12:00:00Z
depth: standard
files_reviewed: 19
files_reviewed_list:
  - workload management/workload management.xcodeproj/project.pbxproj
  - WorkloadApp/App/WorkloadApp.swift
  - WorkloadApp/Components/BehaviorTagChip.swift
  - WorkloadApp/Components/DataSufficiencyRing.swift
  - WorkloadApp/Models/Athlete.swift
  - WorkloadApp/Models/BehaviorTag.swift
  - WorkloadApp/Models/WellnessCheckIn.swift
  - WorkloadApp/Repositories/BehaviorTagRepository.swift
  - WorkloadApp/Services/BehaviorCorrelationEngine.swift
  - WorkloadApp/Services/FatiguePatternEngine.swift
  - WorkloadApp/Services/PeriodizationEngine.swift
  - WorkloadApp/Services/SyncService.swift
  - WorkloadApp/ViewModels/DashboardViewModel.swift
  - WorkloadApp/ViewModels/RecoveryViewModel.swift
  - WorkloadApp/Views/Dashboard/DashboardView.swift
  - WorkloadApp/Views/Recovery/BehaviorCorrelationRow.swift
  - WorkloadApp/Views/Recovery/InsightCard.swift
  - WorkloadApp/Views/Recovery/MorningCheckInSheet.swift
  - WorkloadApp/Views/Recovery/RecoveryView.swift
findings:
  critical: 0
  warning: 3
  info: 2
  total: 5
status: issues_found
---

# Phase 03: Code Review Report

**Reviewed:** 2026-04-21T12:00:00Z
**Depth:** standard
**Files Reviewed:** 19
**Status:** issues_found

## Summary

Phase 03 (Training Intelligence) adds periodization detection, fatigue pattern analysis, behavior tagging with correlation analysis, and supporting UI. The code follows project conventions well: engines are pure structs with static methods, repositories are `@MainActor final class`, and views use the established design system. The Xcode project file includes all new source files correctly.

Three warnings were found: a logic bug in `BehaviorCorrelationEngine.checkSufficiency` that miscounts "days without tag", a silent save error in `BehaviorTagRepository.upsertTag`, and an edge case in `PeriodizationEngine.detectPhase` where division by zero is possible on RPE averages. Two informational items were noted regarding code quality.

## Warnings

### WR-01: checkSufficiency counts "days without tag" incorrectly

**File:** `WorkloadApp/Services/BehaviorCorrelationEngine.swift:120-123`
**Issue:** `checkSufficiency` computes `inactiveDays` by filtering for tags where `!$0.isActive` and counting unique dates. This only counts days where an explicit inactive `BehaviorTag` record exists. Days where no `BehaviorTag` record exists at all are not counted. This differs from `computeCorrelations` (line 68) which correctly uses `allRecoveryDates.subtracting(activeDates)` to count all recovery dates without an active tag. The mismatch causes `checkSufficiency` to report inaccurate "days without tag" counts, potentially misleading users about how much data they still need.
**Fix:** Align the logic with `computeCorrelations` by accepting recovery snapshots and computing inactive days as the complement of active tag days within the recovery date window:

```swift
static func checkSufficiency(
    tags: [BehaviorTag],
    recoverySnapshots: [RecoverySnapshot],
    minimumSamplesPerGroup: Int = 5
) -> [SufficiencyInfo] {
    let calendar = Calendar.current
    let allRecoveryDates = Set(recoverySnapshots.map { calendar.startOfDay(for: $0.date) })

    var tagsByName: [String: [BehaviorTag]] = [:]
    for tag in tags {
        tagsByName[tag.tagName, default: []].append(tag)
    }

    return tagsByName.map { tagName, tagInstances in
        let activeDays = Set(
            tagInstances
                .filter(\.isActive)
                .map { calendar.startOfDay(for: $0.date) }
        )
        let inactiveDays = allRecoveryDates.subtracting(activeDays).count

        return SufficiencyInfo(
            tagName: tagName,
            daysWithTag: activeDays.count,
            daysWithoutTag: inactiveDays,
            neededWith: max(0, minimumSamplesPerGroup - activeDays.count),
            neededWithout: max(0, minimumSamplesPerGroup - inactiveDays)
        )
    }.sorted { $0.tagName < $1.tagName }
}
```

Note: The call site in `RecoveryViewModel.swift:69` must also pass `recoverySnapshots: recoverySnaps`.

### WR-02: upsertTag silently swallows save errors

**File:** `WorkloadApp/Repositories/BehaviorTagRepository.swift:47`
**Issue:** `try? modelContext.save()` silently discards any persistence error. If the save fails (e.g., due to a unique constraint violation on the tag's `id`), the caller has no way to know. The tag would appear inserted in the in-memory context but not persisted, leading to data loss on app restart.
**Fix:** Propagate the error to the caller:

```swift
func upsertTag(_ tag: BehaviorTag) throws {
    tag.tagName = String(tag.tagName.trimmingCharacters(in: .whitespaces).prefix(20))
    tag.updatedAt = .now
    modelContext.insert(tag)
    try modelContext.save()
}
```

### WR-03: Division by zero possible when all sessions lack RPE

**File:** `WorkloadApp/Services/PeriodizationEngine.swift:109-116`
**Issue:** When computing `recentRPEs` and `previousRPEs`, if `rpeSessions` is empty the closure returns `0`. Later (lines 120-121), the means are computed by dividing the sum by `recentRPEs.count` / `previousRPEs.count`. These counts are always 3 (the window size), so division by zero does not occur. However, the computed `meanRecentRPE` and `meanPreviousRPE` will both be `0`, making `intensityChange` = `0` (because `meanPreviousRPE > 0` is false on line 128). This means the intensity signal is silently dropped when no sessions have RPE data, which could misclassify phases. Consider returning `nil` from `detectPhase` when RPE data is insufficient, or documenting this as intentional behavior where phase detection relies solely on volume when RPE is absent.
**Fix:** Add a guard or comment documenting the intent:

```swift
// Note: When no sessions have RPE, intensityChange defaults to 0
// and phase classification relies solely on volume trends.
// This is intentional -- volume-only detection is valid.
```

## Info

### IN-01: Every check-in creates BehaviorTag records for all available tags

**File:** `WorkloadApp/Views/Recovery/MorningCheckInSheet.swift:212-223`
**Issue:** The `save()` function creates a `BehaviorTag` for every tag name (both default and custom), including unselected ones with `isActive: false`. Over time this creates a large number of records (e.g., 4 default tags + N custom tags per check-in). While this design enables the correlation engine to distinguish "tag existed but was not active" from "tag did not exist", it could be more efficient to only persist active tags and treat absence as "not active."
**Fix:** This is a design choice rather than a bug. If storage growth becomes a concern, consider only persisting active tags and updating the correlation engine to treat missing tags as inactive.

### IN-02: BehaviorTagRow has explicit CodingKeys while other Row types do not

**File:** `WorkloadApp/Services/SyncService.swift:499-507`
**Issue:** `BehaviorTagRow` is the only Codable row struct with explicit `CodingKeys` mapping to snake_case. All other row types (AthleteRow, WorkloadSnapshotRow, etc.) rely on implicit key derivation. This inconsistency is not a bug if the Supabase Swift SDK or a shared JSONDecoder configuration handles the conversion, but it makes the new code harder to maintain because developers must remember different conventions for different row types.
**Fix:** Either add `CodingKeys` to all row types for consistency, or remove them from `BehaviorTagRow` if the SDK handles snake_case conversion automatically.

---

_Reviewed: 2026-04-21T12:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
