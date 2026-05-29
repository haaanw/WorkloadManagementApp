# Phase 19 — Plan 03 Summary (Wave 2: fueling card + RED-S banner + Profile toggles)

**Status:** Complete
**Build:** GREEN (exit 0)

## What was built

The two guidance surfaces (CYCLE-07 fueling, CYCLE-08 RED-S) plus the PCOS/perimenopause exclusion toggles the RED-S logic requires.

### Files modified
- `WorkloadApp/Components/CycleFuelingCard.swift` (NEW) — `struct CycleFuelingCard: View { let phase: CyclePhase }`. Title `cycle.fueling.title` + two always-on suggestion lines (`fasted`, `protein`); when luteal (`earlyLuteal`/`lateLuteal`) adds `lutealHeat` + `lutealNutrition`. Hanging 2x2pt `Rectangle` markers (no status-colored SF Symbol). Flat surface, 0.5pt border, suggestion-only copy, no prescription, no accent/RoundedRectangle/shadow.
- `WorkloadApp/Components/REDSAttentionBanner.swift` (NEW) — adapted from FatigueAttentionBanner: 2pt `ColorTokens.zoneCaution` left border, micro-caps `cycle.reds.title` (caution-colored text carries the state, DESIGN rule 5), dismiss `xmark` Button with `cycle.reds.dismiss.a11y` label, body `cycle.reds.body` (non-diagnostic clinician-referral). `let onDismiss: () -> Void`. Flat surface, 0.5pt overlay border, no shadow/RoundedRectangle/accent.
- `WorkloadApp/Views/Profile/ProfileView.swift` — extended `showCycleSection` to include `hasPCOS != nil || isPerimenopausal != nil`; added PCOS and Perimenopausal Toggle rows after the lactating row (before `sectionDivider()`), bound to `Athlete.hasPCOS`/`isPerimenopausal` via `Binding(get:set:)` + `saveAthlete`, styling identical to the existing reproductive rows, `profile.row.pcos`/`profile.row.perimenopausal` labels.
- `WorkloadApp/Views/Recovery/RecoveryView.swift` — derived `redsRiskState` by building `CycleHistoryInput` from athlete-scoped snapshots (cycle-start dates -> consecutive-day-diff lengths -> median; `daysSinceLastCycleStart` via Calendar) + athlete exclusion flags, then `REDSRiskEngine.classify`. Added `@AppStorage("redsBannerDismissedPeriod")` + `currentPeriodKey` ("yyyy-M") + `showREDSBanner` (`.monitor && dismissedPeriod != currentPeriodKey`). `REDSAttentionBanner` placed at the very top of the VStack (onDismiss persists the period). `CycleFuelingCard` placed after the RecoveryScoreCard region, gated by `cycleGatePasses`. All cycle math is in the view layer; the engine stays pure (D-14).

## Verification
- `xcodebuild build` exits 0.
- DESIGN grep on CycleFuelingCard + REDSAttentionBanner (`RoundedRectangle|.shadow(|ColorTokens.accent`) -> empty.
- RED-S copy references only `cycle.reds.*` keys; no diagnostic terms in component or catalog copy (only an explanatory code comment).
- Banner shows only when `.monitor` and not dismissed this month; dismissal persists per-period and can re-surface next cycle (D-13). Excluded users (pregnancy/lactation/OC/PCOS/perimenopause) never reach `.monitor` (engine, Plan 01).
- With zero snapshots, neither the fueling card nor the RED-S banner renders (`hasSnapshotData=false` -> `.none`; fueling guarded by `latestCycleSnapshot`).
- ProfileView toggles bind to local-only Athlete flags; SyncService still references neither.
