# Phase 19 — Plan 02 Summary (Wave 2: Dashboard indicator + recovery-card context)

**Status:** Complete
**Build:** GREEN (exit 0)

## What was built

The two primary read surfaces for cycle context (CYCLE-06: SC1, SC2, SC5, SC6).

### Files modified
- `WorkloadApp/Components/CycleStatusStrip.swift` (NEW) — flat opt-in cycle day/phase indicator styled on the MetricStripCell vocabulary. Micro-caps "CYCLE" label + "Day N" + phase displayName. `showsPhase` gate = `confidence >= 0.7 && phase != .unknown && !exclusion` (D-03/D-04); below the gate shows day only. Flat `ColorTokens.surface`, 0.5pt bottom divider, no accent, no icon, no RoundedRectangle, no shadow. Combined accessibility label.
- `WorkloadApp/Views/Dashboard/DashboardView.swift` — added `latestCycleSnapshot` (newest by date, D-02); inserted `CycleStatusStrip` directly above `MetricsStrip`, gated by `latestCycleSnapshot != nil` (invisible without snapshots, SC6/D-01). HeroReadinessCard, soft-prompt block, and MetricsStrip untouched (D-06).
- `WorkloadApp/Views/Recovery/RecoveryView.swift` — added `@Query cycleSnapshots`, athlete-scoped `scopedCycleSnapshots`/`latestCycleSnapshot`, and a `cycleGatePasses` helper (D-03). `RecoveryScoreCard` gained `var cycleSnapshot: MenstrualCycleSnapshot? = nil`; the call site passes `latestCycleSnapshot`. Inside the card's data branch (after the HRV/RHR/sleep rows) a gated readiness-first phase-context line renders `CyclePhase.contextCopyKey` -> localized follicular/luteal copy, separated by a 0.5pt divider, secondary text (`Font.Tokens.label`, `ColorTokens.text2`), wraps fully. No accent/border emphasis; score/zone/component rows unchanged.

## Verification
- `xcodebuild build` exits 0.
- DESIGN grep on CycleStatusStrip (`RoundedRectangle|.shadow(|ColorTokens.accent`) -> empty.
- All visible strings are localized keys (`cycle.indicator.*`) + `CyclePhase.displayName`/`contextCopyKey` — no literals.
- With zero snapshots, neither the Dashboard strip nor the recovery-card line renders (both guarded by `latestCycleSnapshot != nil` / the D-03 gate).
- HeroReadinessCard unchanged; accent stays only on the hero score number.
