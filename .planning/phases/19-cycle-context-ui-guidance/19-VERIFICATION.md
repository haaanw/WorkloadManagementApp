# Phase 19 — Verification: Cycle Context UI & Guidance

**Verified:** 2026-05-30
**Build:** `xcodebuild build` exits **0** (GREEN). Only pre-existing warnings (InviteService try?, AppContainer catch, totalEnergyBurned deprecation) — no new warnings, no errors.
**Requirements:** CYCLE-06, CYCLE-07, CYCLE-08 — delivered.

## ROADMAP Success Criteria (all 6 confirmed)

| SC | Criterion | Status | Evidence |
|----|-----------|--------|----------|
| SC1 | Dashboard shows unobtrusive cycle day/phase indicator when data available (opt-in) | PASS | `CycleStatusStrip` rendered above `MetricsStrip` in DashboardView, gated by `latestCycleSnapshot != nil`. Flat, no accent/icon. |
| SC2 | Recovery card includes phase context when cycle influences interpretation | PASS | `RecoveryScoreCard` renders `CyclePhase.contextCopyKey` line (luteal/follicular) when the D-03 gate passes. Copy matches research §9.9 + readiness anchor. |
| SC3 | Fueling/recovery prompts (fasted-avoidance, 45-min protein, luteal hydration/cooling) | PASS | `CycleFuelingCard` on the Recovery tab: always `fasted`+`protein`; luteal adds `lutealHeat`+`lutealNutrition`. Suggestion-only. |
| SC4 | RED-S alert on 3+ missed periods OR >35d cycles, clinician-referral + exclusions | PASS | `REDSRiskEngine.classify` (long-cycle + missed-period rules) drives `REDSAttentionBanner`; exclusions (pregnancy/lactation/OC/PCOS/perimenopause) short-circuit first. Copy is non-diagnostic. |
| SC5 | Cycle context never prescribes (no "deload because luteal") — readiness-first | PASS | All copy is explanatory ("…your readiness score already accounts for this"); no deload/rest/go-hard wording anywhere. Fueling is "Aim for…/You may…". |
| SC6 | All cycle UI 100% optional, invisible without HealthKit menstrual permission | PASS | Every surface gated on snapshot presence (`latestCycleSnapshot`/`hasSnapshotData`). Zero `MenstrualCycleSnapshot` rows -> nothing renders. |

## Locked-decision compliance

- **D-01/D-02:** all cycle UI gated on `!cycleSnapshots.isEmpty` via latest-snapshot computed props; mirrors the Phase 17 opt-in pattern.
- **D-03/D-04:** interpretation gate `confidence >= 0.7 && phase != .unknown && !exclusion` applied identically in CycleStatusStrip, RecoveryScoreCard, and the fueling gate — consistent with the Phase 18 engine gate. OC users (phase `.unknown` by design) get day-only, no interpretation, no fueling, no RED-S.
- **D-05:** `CyclePhase.contextCopyKey` 2-bucket readiness-first copy; no prescription words.
- **D-06:** HeroReadinessCard unchanged; accent remains only on the hero score number.
- **D-07:** CycleStatusStrip styled on MetricStripCell vocabulary, flat, no accent/icon.
- **D-08/D-09:** CycleFuelingCard phase-bucket content, suggestion phrasing, InsightCard-style flat card.
- **D-10/D-11/D-11a/D-12/D-14:** pure `REDSRiskEngine`; exclusions first; non-diagnostic copy; display-state only (no score, no diagnosis); additive local-only `hasPCOS`/`isPerimenopausal`.
- **D-13:** RED-S banner = caution (not danger) border + text label; dismissible; per-month `@AppStorage` so it does not nag daily but re-surfaces next cycle.
- **D-15:** all new strings in `Localizable.xcstrings` with EN + zh-Hans; no literals in views.

## Privacy / sync guardrail (Phase 18 CR-01)
- `grep "hasPCOS|isPerimenopausal" SyncService.swift` -> **empty**. New flags are local-only @Model fields; not in AthleteRow/pushAthlete/pullAthlete. `MenstrualCycleSnapshot` remains local-only. No raw menstrual data off-device.

## DESIGN.md compliance
- `grep "RoundedRectangle|.shadow(|ColorTokens.accent"` on CycleStatusStrip + CycleFuelingCard + REDSAttentionBanner -> **empty**. 0pt corners (Rectangle only), no shadow, `Font.Tokens.*`, `ColorTokens` only, 8pt grid, caution conveyed via text label + supplementary border.

## Engine purity
- `grep "import HealthKit|import SwiftData" REDSRiskEngine.swift` -> **empty** (Foundation only). All cycle math done in the view layer; engine receives plain Ints + Bools.

## Tests
- `WorkloadAppTests/REDSRiskEngineTests.swift` — 17 cases (both monitor rules, all 5 exclusions individually, sparse/no-data, regular-cycle, exactly-35 boundary, below-floor, mostRecent-3 selection).
- **Test-host blocker (NOT a regression):** the unit-test host crashes on launch due to the pre-existing `#if DEBUG` font `assertionFailure` in `App/WorkloadApp.swift` (confirmed Phases 21+22; WorkloadApp.swift intentionally not modified). `xcodebuild test` therefore cannot bootstrap the host.
- **Mitigation:** RED-S logic validated via a standalone Swift program that mirrors the engine + test cases exactly — **17/17 PASS, exit 0**.

## Files changed
**Plan 01:** Athlete.swift, Enums.swift, REDSRiskEngine.swift (new), REDSRiskEngineTests.swift (new), Localizable.xcstrings, REQUIREMENTS.md, project.pbxproj.
**Plan 02:** CycleStatusStrip.swift (new), DashboardView.swift, RecoveryView.swift.
**Plan 03:** CycleFuelingCard.swift (new), REDSAttentionBanner.swift (new), ProfileView.swift, RecoveryView.swift.

No file outside the planned `files_modified` sets was changed (pbxproj registration of the new sources is expected and required).
