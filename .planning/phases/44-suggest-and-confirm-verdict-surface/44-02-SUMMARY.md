---
phase: 44-suggest-and-confirm-verdict-surface
plan: 02
subsystem: ui
tags: [swiftui, verdict, nocebo, autonomy, suggest-and-confirm, localization, design-system, workoutlog]

# Dependency graph
requires:
  - phase: 44-01
    provides: TodayVerdictDisplay / FeelOverride value types; TodayVerdictViewModel display + accept/keepPlan/feelOverride
  - phase: 42-plan-input
    provides: WorkoutLogView host + PlanTodaySheet plan-today flow
provides:
  - TodayVerdictCard — anti-nocebo suggest-and-confirm card (action+reason hero, equal-weight accept/keep, feel-override, quiet confidence)
  - WorkoutLog mounting (verdict card above the template carousel only when a today-plan exists)
  - en + zh-Hans verdictCard.* catalog strings (16 keys)
  - TodayVerdictCardGuardTests — source-grep DESIGN + nocebo fence
affects: [45-measurement (the surface whose accept/keep/feel events get logged), future-visual-UAT]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Presentational card takes a display value + 3 callbacks; zero data logic in the view"
    - "One shared button builder ⇒ provably equal-weight Accept / Keep-my-plan (anti-coercion)"
    - "Verdict state via TEXT LABEL + optional DESATURATED hairline strip — never color alone, never a red gate"
    - "Source-grep guard test fences DESIGN + nocebo drift at build time"

key-files:
  created:
    - WorkloadApp/Views/WorkoutLog/TodayVerdictCard.swift
    - WorkloadAppTests/TodayVerdictCardGuardTests.swift
  modified:
    - WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift
    - WorkloadApp/Resources/Localizable.xcstrings
    - workload management/workload management.xcodeproj/project.pbxproj

key-decisions:
  - "Both decision buttons use the identical shared treatment (same fill/border/font/size) — equal visual weight is the hard requirement, so identical beats subtly-different"
  - "Feel-override row stays visible even after a decision (first-class affordance, never a nag) so the athlete can always override with their feel"
  - "Verdict-state hairline strip uses zoneCaution (adjusted) / zoneLow (deferred) / none (as-planned) — never zoneDanger, never accent"
  - "Card refreshes on athlete change AND when the Plan-Today sheet dismisses, so the card appears immediately after planning"

patterns-established:
  - "verdictCard.* string namespace (en + zh-Hans), calm no-guilt tone"

requirements-completed: [MOD-10, MOD-11, MOD-12]

# Metrics
duration: ~30min
completed: 2026-06-14
---

# Phase 44 Plan 02: Suggest-and-Confirm Verdict Card Summary

**An anti-nocebo verdict card mounted at the top of the Workout Log that leads with the action-on-the-plan + one-line reason, offers equal-weight Accept / Keep-my-plan, a first-class feel-override, and quiet separate confidence — DESIGN-clean and grep-fenced against alarm copy and accent/rounded/shadow drift.**

## Performance

- **Duration:** ~30 min
- **Started:** 2026-06-14 (after 44-01)
- **Completed:** 2026-06-14
- **Tasks:** 3 (Task 3 = autonomous guard test + deferred human-verify UAT)
- **Files modified:** 5 (2 created + WorkoutLogView + catalog + pbxproj)

## Accomplishments
- `TodayVerdictCard`: header micro-cap (not a score) → action hero (exercise + planned→adjusted number + caption + text state label) → reason line → quiet confidence → equal-weight decision row (single "Got it" when nothing to accept; quiet confirmed line once decided) → first-class feel-override pills. Supplementary desaturated left hairline (zoneCaution/zoneLow/none).
- Mounted in `WorkoutLogView` above the template carousel inside a `SectionContainer`, gated on `vm.display != nil` (no today-plan ⇒ screen byte-unchanged). VM constructed once in `.task`, refreshed on the current athlete and when the Plan-Today sheet dismisses.
- 16 `verdictCard.*` keys added to `Localizable.xcstrings` in en + zh-Hans (calm, non-alarming, no-guilt tone). JSON validated; every referenced key resolves.
- `TodayVerdictCardGuardTests`: DESIGN fence (no RoundedRectangle/.cornerRadius/.shadow/ColorTokens.accent/.system(/.zoneDanger/Color.red/green) + nocebo fence (no don't-train/rest-day gate/are-you-sure/guilt copy).

## Task Commits

1. **Task 1: TodayVerdictCard** - `6f9105e` (feat)
2. **Task 2: mount in WorkoutLog + en/zh-Hans strings** - `9ae5a4c` (feat)
3. **Task 3: source-grep DESIGN/nocebo guard test** - `8a4f000` (test)

## Files Created/Modified
- `WorkloadApp/Views/WorkoutLog/TodayVerdictCard.swift` - the suggest-and-confirm card (AA4403)
- `WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift` - mounts the card + VM lifecycle
- `WorkloadApp/Resources/Localizable.xcstrings` - 16 verdictCard.* keys (en + zh-Hans)
- `WorkloadAppTests/TodayVerdictCardGuardTests.swift` - DESIGN + nocebo source-grep fence

## Decisions Made
- Equal-weight buttons via one shared builder with identical treatment (safest reading of SC1).
- Feel-override remains available post-decision (autonomy affordance, not a nag).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Reworded card doc-comments that contained literal banned tokens**
- **Found during:** Task 1 (TodayVerdictCard)
- **Issue:** Doc comments literally contained `.zoneDanger` and `ColorTokens.accent` (describing what is forbidden). The Task-3 grep guard greps the WHOLE source (including comments), so these literals would have tripped the DESIGN fence.
- **Fix:** Reworded the three comment lines to "the danger-zone token" / "the reserved hero color" so no banned literal appears anywhere in the source.
- **Files modified:** WorkloadApp/Views/WorkoutLog/TodayVerdictCard.swift
- **Verification:** `grep -nE "...|.zoneDanger|ColorTokens.accent|..."` returns zero; guard test green.
- **Committed in:** 6f9105e (Task 1 commit)

**2. [Rule 2 - Missing Critical] Refresh the card when the Plan-Today sheet dismisses**
- **Found during:** Task 2 (WorkoutLog wiring)
- **Issue:** `.task(id: athletes.first?.id)` only re-runs on athlete change, so a freshly-planned session would not surface the card until the tab re-appeared — the feature would read as broken right after planning.
- **Fix:** Added `.onChange(of: showPlanToday)` to `verdictVM?.refresh(athlete:)` when the sheet closes.
- **Files modified:** WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift
- **Verification:** Build green; logically the card appears immediately after planning.
- **Committed in:** 9ae5a4c (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 missing-critical)
**Impact on plan:** Both necessary for correctness (guard would have failed; feature would have read broken). No scope creep.

## Issues Encountered
None beyond the deviations above.

## Deferred — On-device Visual UAT (no human available)
The Task-3 `checkpoint:human-verify` visual judgments cannot run headless. All code-verifiable checks passed (DESIGN + nocebo grep guards green, build green, state transitions unit-tested, equal-weight enforced structurally via the shared builder). Per the project's deferred-on-device-UAT convention this is recorded as **deferred to the human on-device visual UAT batch** and execution PROCEEDED. Items to confirm on device (light + dark):
1. Card sits at the top of the Workout Log, leads with action + reason (not a bare readiness number), reads calm (no red/stop-sign/alarm color, 0pt corners, no shadow, General Sans, 8pt rhythm).
2. Accept and "Keep my plan" read as equal visual weight; keep is one tap, leaves the planned number visibly unchanged, no guilt copy.
3. Accept on an adjusted suggestion shows the adjustment is in use; the authored number is not destroyed.
4. Feel-override ("I feel strong" / "I feel rough") is an obvious affordance and updates the decision.
5. A hold/low verdict reads as number + reason, never a "don't-train"/"rest-day" gate.

## Next Phase Readiness
- Phase 45 (measurement / VerdictEvent / WTP) can log decisions by assigning `verdictVM.onDecisionRecorded` — the surface now emits a `VerdictDecision` for every accept/keep/feel.

## Self-Check
- Created files present: TodayVerdictCard.swift, TodayVerdictCardGuardTests.swift.
- Commits present: 6f9105e, 9ae5a4c, 8a4f000.

---
*Phase: 44-suggest-and-confirm-verdict-surface*
*Completed: 2026-06-14*
