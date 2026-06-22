---
phase: 39-ux-wave-2-recovery-quick-mode-two-score-clarity-pre-fill-ret
reviewed: 2026-06-02T00:00:00Z
depth: deep
files_reviewed: 4
files_reviewed_list:
  - WorkloadApp/Repositories/RecoveryRepository.swift
  - WorkloadApp/Views/Recovery/MorningCheckInSheet.swift
  - WorkloadApp/Views/Recovery/RecoveryView.swift
  - WorkloadApp/Resources/Localizable.xcstrings
findings:
  critical: 1
  warning: 2
  info: 3
  total: 6
status: issues_found
---

# Phase 39: Code Review Report

**Reviewed:** 2026-06-02
**Depth:** deep
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Phase 39 delivers the recovery quick-mode pre-fill (B.1) and the two-score honest-blend clarity (B.2). The two-score work is clean and well-executed: the engine (`RecoveryScoreEngine.swift`) and model (`WellnessCheckIn.swift`) are confirmed byte-for-byte unchanged (empty git diff), exactly one `ZoneBadge` remains in `RecoveryScoreCard`, the "how you feel" element is genuinely subordinate (label tier, not a second hero), no score math/fusion happens in the view, and all new strings are localized in both `en` and `zh-Hans`. Copy is honest about the 25% coupling.

The pre-fill feature has one real correctness defect: it now seeds from **today's** existing check-in (the "editing today" path mandated by CONTEXT.md decision B.1), but `save()` was left unchanged and always **inserts a brand-new** `WellnessCheckIn`. Editing today's check-in therefore produces a duplicate same-day record rather than updating the existing one. Two secondary issues (hint copy mismatch when editing today; `@Query`-timing of the athlete during seeding) are also noted.

## Critical Issues

### CR-01: Editing today's check-in creates a duplicate same-day WellnessCheckIn (no upsert)

**File:** `WorkloadApp/Views/Recovery/MorningCheckInSheet.swift:228-257` (interacts with `seedFromPriorCheckIn` 209-226)
**Issue:**
The pre-fill precedence intentionally seeds from today's check-in first (`fetchTodayWellnessCheckIn ?? fetchLatestWellnessCheckIn`, line 214-215) — this is the CONTEXT.md "editing today" case. But `save()` unconditionally constructs and inserts a *new* `WellnessCheckIn(date: .now, ...)` (lines 229-238) plus a fresh set of `BehaviorTag` rows. It never fetches or mutates the existing today record. Result: every time a user re-opens the sheet on a day they've already checked in and taps Save, a **second** `WellnessCheckIn` for the same calendar day is persisted (and another full set of behavior tags).

Downstream this is non-deterministic / corrupting:
- `RecoveryRepository.fetchTodayWellnessCheckIn` (lines 146-161) returns `.first` of an **unordered** predicate fetch → with two same-day rows it picks an arbitrary one. `RecoveryPipeline` (line 79) and `RecoveryScoreEngine` (25% wellness input) consume that arbitrary row, so the composite recovery score can silently use the stale check-in instead of the edited one.
- `RecoveryView.todayCheckIn` (line 32) picks the newest by query sort, so the UI and the engine can disagree about "today's" wellness.
- `BehaviorTagRepository` active-tag queries (date >= start, isActive) will now double-count today's tags, skewing behavior-correlation insights.

This is a data-integrity / data-loss-of-intent bug: the user's edit does not replace today's data, it shadows it.

**Fix:** Make `save()` an upsert keyed on today's record (mirror the `upsertRecoverySnapshot` pattern already in the repo):
```swift
private func save() {
    let repo = RecoveryRepository(modelContext: modelContext)
    let checkIn = (try? repo.fetchTodayWellnessCheckIn(athlete: athlete)) ?? {
        let c = WellnessCheckIn(date: .now)
        c.athlete = athlete
        modelContext.insert(c)
        return c
    }()

    checkIn.sleepQuality = sleepQuality
    checkIn.soreness = soreness
    checkIn.energy = energy
    checkIn.stress = stress
    checkIn.notes = notes.isEmpty ? nil : notes
    checkIn.updatedAt = .now

    // Replace today's behavior tags rather than appending a second set.
    for old in checkIn.behaviorTags { modelContext.delete(old) }
    checkIn.behaviorTags = []
    let allTagNames = defaultTags + customTagNames
    for tagName in allTagNames {
        let tag = BehaviorTag(
            date: .now,
            tagName: tagName,
            isActive: selectedTags.contains(tagName),
            isCustom: !defaultTags.contains(tagName)
        )
        tag.wellnessCheckIn = checkIn
        tag.athlete = athlete
        modelContext.insert(tag)
    }

    try? modelContext.save()
    onSaved?()
    dismiss()
}
```
If the team prefers to scope phase 39 strictly to pre-fill and treat upsert as out of scope, then the *pre-fill precedence must be reversed* to NOT seed from today's record (seed only from the latest prior), so the sheet never presents itself as "editing today" while save can only append. Either fix closes the inconsistency; the upsert is the correct one given CONTEXT.md B.1 explicitly says "if today's check-in already exists, seed from it (editing today)".

## Warnings

### WR-01: Pre-fill hint copy is wrong when editing today's check-in

**File:** `WorkloadApp/Views/Recovery/MorningCheckInSheet.swift:40-47, 209-226`
**Issue:** `isPrefilled` is set to `true` for **both** seed sources — today's check-in and the latest prior. The hint string is `"Prefilled from your last check-in — edit what changed"` (`morning.prefill.hint`). When the source is *today's* check-in (the editing-today path), the user is shown "from your last check-in," which is factually wrong — they are editing the current day, not carrying forward a prior day. Misleading microcopy in the exact flow B.1 calls out.
**Fix:** Distinguish the two cases. Track which branch seeded and show a context-appropriate string, e.g. add `morning.editing.today.hint` ("Editing today's check-in") and select it when `fetchTodayWellnessCheckIn` was the source:
```swift
private enum SeedSource { case today, prior }
@State private var seedSource: SeedSource? = nil
// ...
if let t = try? repo.fetchTodayWellnessCheckIn(athlete: athlete), ... { seedSource = .today; source = t }
else if let p = ... { seedSource = .prior; source = p }
// hint: seedSource == .today ? "morning.editing.today.hint" : "morning.prefill.hint"
```
(If CR-01 is fixed by reversing precedence so today is never a seed source, this warning is resolved automatically.)

### WR-02: `athlete` may be nil during `.task` seeding due to `@Query` load timing

**File:** `WorkloadApp/Views/Recovery/MorningCheckInSheet.swift:22, 186-192, 209-226`
**Issue:** `seedFromPriorCheckIn()` runs in `.task` and reads `athlete` (`athletes.first` from `@Query`). `@Query` results are not guaranteed populated on the first `.task` tick; if `athletes` is still empty, `fetchTodayWellnessCheckIn(athlete: nil)` / `fetchLatestWellnessCheckIn(athlete: nil)` run **unscoped**, fetching across all athletes (wrong record in a multi-athlete/coach context), and the `didSeed = true` guard then permanently blocks a correct re-seed. In single-athlete use this is usually benign because the query typically resolves before `.task`, but it is a real correctness hazard given the app supports coach+athlete multi-user. Note `seedFromPriorCheckIn` also sets `didSeed = true` *before* it has a valid athlete, so a later valid load cannot recover.
**Fix:** Guard the seed on a resolved athlete and only latch `didSeed` after a successful athlete-scoped attempt:
```swift
private func seedFromPriorCheckIn() {
    guard !didSeed, let athlete else { return }   // wait for @Query to resolve
    didSeed = true
    let repo = RecoveryRepository(modelContext: modelContext)
    let source = (try? repo.fetchTodayWellnessCheckIn(athlete: athlete))
        ?? (try? repo.fetchLatestWellnessCheckIn(athlete: athlete))
    guard let source else { return }
    // ...
}
```
Because the seeding sets `@State`, an empty-then-populated `athletes` will re-render and the `.task` body already re-checks; gating on `let athlete` lets the correct pass win.

## Info

### IN-01: Redundant `?? nil` in seed source resolution

**File:** `WorkloadApp/Views/Recovery/MorningCheckInSheet.swift:214-216`
**Issue:** `(try? a) ?? (try? b) ?? nil` — the trailing `?? nil` is a no-op (the expression is already `WellnessCheckIn?`). Dead/confusing.
**Fix:** Drop the final `?? nil`:
```swift
let source = (try? repo.fetchTodayWellnessCheckIn(athlete: athlete))
    ?? (try? repo.fetchLatestWellnessCheckIn(athlete: athlete))
```

### IN-02: Inconsistent spacing literals vs token scale in MorningCheckInSheet

**File:** `WorkloadApp/Views/Recovery/MorningCheckInSheet.swift:37-38, 102, 137-138, 148-149, 166-167` (and the pre-existing `.padding(.horizontal, 16)` blocks)
**Issue:** The new hint uses `Spacing.sm` (good, per DESIGN.md rule 6), but the surrounding pre-existing code mixes raw `16`/`24` literals with the token scale. The values themselves are valid 8pt multiples (16, 24), so this is not a grid violation — only a consistency/maintainability nit, and it is mostly pre-existing rather than introduced by phase 39. Flagging only because the new code is now adjacent to it.
**Fix:** Optional: migrate the literals in this view to `Spacing.sm` / `Spacing.md` to match the new line. Not blocking.

### IN-03: `selectedTags` may restore tags the athlete no longer has available

**File:** `WorkloadApp/Views/Recovery/MorningCheckInSheet.swift:223, 240-252`
**Issue:** Seeding restores `selectedTags` from the source check-in's active tags, including custom tags. If a custom tag was since deleted (no longer in `defaultTags + customTagNames`), it stays in `selectedTags` but has no chip rendered, and on save it is silently dropped (the save loop iterates only `defaultTags + customTagNames`). Behavior is benign (the stale selection just disappears) but slightly surprising — a seeded selection can vanish with no UI trace.
**Fix:** Optional: intersect the seeded set with currently-available tag names so `selectedTags` never holds unrenderable entries:
```swift
let available = Set(defaultTags + customTagNames)
selectedTags = Set(source.behaviorTags.filter { $0.isActive }.map(\.tagName)).intersection(available)
```
Note `customTagNames` is loaded in the same `.task` before `seedFromPriorCheckIn()`, so it is available at intersect time.

---

## Notes on items verified clean

- `RecoveryScoreEngine.swift` and `WellnessCheckIn.swift`: confirmed unchanged (empty git diff over phase 39 range). No view-side score fusion or new computation introduced.
- `fetchLatestWellnessCheckIn` (RecoveryRepository.swift:166-180): read-only, athlete-scoped, sorted `date` reverse, returns `.first`. Correct. No insert/save.
- Two-score B.2: exactly one `ZoneBadge` (RecoveryView.swift:342); "how you feel" row is label-tier and subordinate (no second hero); `recovery.feel.note` copy is honest about the combined-vs-alone relationship; `wellnessScore` is read-only `Double?` passed in, never recomputed.
- Localization: `morning.prefill.hint`, `recovery.blend.subtitle`, `recovery.feel.label`, `recovery.feel.note` all present and translated in `en` + `zh-Hans`.
- DESIGN.md: new elements use `Rectangle()` (no RoundedRectangle), no `.shadow`, `Font.Tokens.*`, semantic `ColorTokens`, no accent misuse. No real violations in changed lines.
- First-ever (nil source) path keeps slider defaults at 3 and leaves `isPrefilled = false` (no hint) — correct per B.1.
- Notes correctly NOT carried forward (seed leaves `notes` empty; comment documents intent).

---

_Reviewed: 2026-06-02_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_
