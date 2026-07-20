# WS3 · Sheet Chrome + Controls + Charts — Report

Date: 2026-07-20. Workstream WS3 of the Tuwa v4.1 polish round. Repo `/Users/hanwen/dev/Tonus`, canonical checkout, no branches/worktrees. All work left UNCOMMITTED for the orchestrator. Ran the sanctioned **build** only (never `test`, never `git`).

## Summary

Killed the last stock-iOS chrome leaks on the app's sheets, ran the ratified detent pass across the six numeric/selection controls, and retuned the chart palette off the olive/moss zone aliases to aluminum-compatible instrument traces. Foundation (`SheetChrome.swift` + chart tokens) authored by hand; the mechanical per-file application fanned out to four parallel sub-agents on disjoint files (no concurrent builds), then verified by a single whole-module build + on-sim renders.

## Build

`xcodebuild … -destination id=8E872500-703D-4292-9758-38ADFCCFB126 -derivedDataPath ~/.tonus-dd build`

```
** BUILD SUCCEEDED **
```

Zero warnings/errors in any WS3-owned file. Build compiled the whole module including WS1 (CardStyle/TickScale/InkTabBar/DESIGN.md) and WS2 (LayoutPrimitives + tab views) concurrent work — all three lanes were compatible at build time. `pgrep -fl xcodebuild` was clear before building; other lanes had been quiet ~2–4 min (settled) when I built.

## 1 · SheetChrome.swift (new foundation — my file)

`InstrumentSheetHeader<Leading,Trailing>` + `SheetHeaderButton`:
- Centered UPPERCASE micro-caps title (`Font.Tokens.screenTitle`, 13pt Medium, locale-aware tracking 2.6 — a hair tighter than `ScreenHeader`'s 3.6 so a centered title between two slots never collides; `minimumScaleFactor(0.72)` guards long localized strings; zh gets no tracking/case).
- Flat OPAQUE aluminum plane (`ColorTokens.background`), 0.5pt `divider` bottom hairline, 56pt bar height (8pt grid). Sits at the TOP of the sheet's content VStack (not overlaying scroll content) so the plane stays flat — no material blur, no large-title chrome.
- `SheetHeaderButton`: quiet caps action slot (`headerAction` 10pt Medium, uppercase). `emphasis:` renders the primary/confirm slot in ink (`text1`), the dismissive slot in `text2` — a two-tier quiet hierarchy, never a filled key, never the red index. Press via the shared `.pressable` Key grammar (scale 0.97); one commit-only `Haptics.tap()` on press. 44pt hit target; `isDisabled` carries the confirm-button disabled/loading state.

Pattern applied to each sheet: replace `.navigationTitle` + `.navigationBarTitleDisplayMode(.inline)` + any `.toolbarBackground(…)` + `.toolbar { ToolbarItem(.cancellationAction/.confirmationAction) }` with `InstrumentSheetHeader` at the top of a wrapping `VStack(spacing:0)`, and `.toolbar(.hidden, for: .navigationBar)` on the stack. Every action closure, binding, disabled state, presentation modifier (`.sheet`/`.alert`/`.presentationDetents`/`.interactiveDismissDisabled`/`.onAppear`) and a11y ID preserved verbatim. Where a moved closure began with a duplicate `Haptics.tap()`, it was dropped (the header button already taps).

## 2 · Sheets restyled (12 owned; 1 intentional skip)

| Sheet | Title key | Leading | Trailing | Notes |
|---|---|---|---|---|
| ActiveWorkoutSheet | `nav.workout` | `action.cancel`→dismiss | `action.finish` (ink)→showFinishConfirmation | biggest leak; dropped dup Haptics.tap |
| FinishWorkoutSheet | `nav.finishWorkout` | `action.keepEditing`→dismiss | `action.finish` (ink)→onFinish();dismiss | `.interactiveDismissDisabled`/`.onAppear` kept on stack |
| TemplatePickerSheet | `nav.templates` | `action.cancel`→dismiss | — | removed 2 `.toolbarBackground`; `templatePicker.startBlank` intact |
| PlanTodaySheet | `planToday.chooser.navTitle` | `action.cancel`→dismiss | — | both `.sheet` presenters kept |
| WorkoutImportSheet | `nav.importWorkout` | `action.cancel`→dismiss | — | ZStack content nested under header |
| TextTemplateImportSheet | `nav.importProgram` | `action.cancel`→dismiss | `action.saveAll` (ink, isDisabled: empty‖saving)→saveTemplates | disabled cond carried |
| ShareImportSheet | `nav.importTemplate` | `action.close`→dismiss | — | title extracted from dropped `.principal` item; `.presentationDetents([.medium])` kept |
| ShareImportPreviewSheet | `nav.importTemplate` | `action.close`→dismiss | — | reused step-1 title (no distinct key exists — see deferrals); `[.medium,.large]` kept |
| MorningCheckInSheet (main) | `morning.nav.title` | `action.cancel`→dismiss | `action.save` (ink, isDisabled: athlete==nil)→save | `Haptics.success()` inside save() preserved |
| MorningCheckInSheet (nested tags) | `tags.nav.title` | — | `action.done` (ink)→dismiss | second header on `CustomTagManagementSheet` |
| NiggleLogSheet | `niggle.nav.title` | `action.cancel`→dismiss | `action.save` (ink)→save | `.onAppear { Haptics.prepare() }` kept |
| TrainingProfileSheet | `profile.trainingProfile.navTitle` | `action.discardChanges`→dismiss | `action.saveProfile` (ink, isDisabled: !isFormValid)→save | `.interactiveDismissDisabled(hasChanges)` kept |
| **UpgradeSheet** | — | — | — | **INTENTIONAL SKIP** — bespoke paywall, no NavigationStack / no stock chrome to replace; own hero layout + drag-handle dismissal. Not forced. |

## 3 · Controls detent pass (6 files)

Ratified law D13: per-tap haptics SILENT; haptic only at min/max limits + true detents; digit-roll ~100ms subtle via `.contentTransition(.numericText())` on `Motion.digitRoll` (existing token, 100ms strong-ease-out — no new token needed); fixed-width value cells that never resize with digit count; `.pressable` press states.

- **SetStepper** (Double+Int): stripped the per-step `Haptics.select()` from `stepUp`/`stepDown`; added `Haptics.limit()` **only** when a decrement is rejected at the floor (`next == base`). Value fields are editable `TextField`s (can't drive `.numericText` on a live field) but are `.frame(maxWidth:.infinity)` centered so width is already digit-stable. ± keys → `.pressable(scale: 0.94)` (deeper stepper depress per demo).
- **WeightBlockPicker**: kept the single `Haptics.select()` on tile-commit (a genuine snap detent — sanctioned exception). Live readout → `.frame(minWidth: 56, alignment:.leading)` (reserves "999.5") + `.animation(Motion.digitRoll, value: centerDisplay)` driving its `.numericText`. The 3 tiles are fixed 48×48 (numerals never resize).
- **RepScrubber**: stripped the per-crossed-integer `UISelectionFeedbackGenerator` buzz (+ its `lastHapticInt` gate); replaced with a limit-only medium impact firing once when the scrub newly lands on 1 or 30. Non-focus readout got `.frame(minWidth:28)` + `Motion.digitRoll` on `.numericText`.
- **SessionStartPicker** (+MatchTierPicker): kept `Haptics.select()` as genuine discrete selections but gated on `!isSelected` (re-tapping the current choice is now silent); normalized `choiceButton` from `.tap()`→`.select()`. Adjust disclosure keeps its toggle `.tap()`. No numeric readouts.
- **TimeRangeSegmentedControl**: kept `Haptics.select()` (true detent, already `guard selected != range`). Incidental fence fix: two spacing literals → `Spacing.xs`/`Spacing.sm`.
- **RadialPicker**: UNCHANGED — audited compliant (all 3 haptics are open/select/commit detents already gated on change; no per-tick noise, no numeric readouts).

Motion-token deferrals: **none**. All motion routes through `Motion.digitRoll`/`Motion.state` via `Motion.resolved(…)`; no animation/timing literal added in any control file (fence held).

## 4 · Chart palette retune (ColorTokens chart* tokens only)

Retuned off the olive/moss zone aliases (which read as alarms on aluminum) to instrument traces — cool-neutral inks graded by lightness + ONE muted supporting hue. Dedicated hex literals; semantic pairing preserved; ≥3:1 inter-series separation on the co-plotted load chart.

| Token | v4.0 (alias) | v4.1 hex | Role |
|---|---|---|---|
| chartATL | zoneCaution (amber) | `#33383D` dark cool ink | acute load — prominent |
| chartCTL | zoneLow (slate) | `#8B9096` light cool ink | chronic base — quiet backbone |
| chartTSB | zoneOptimal (green) | `#4E7A74` muted teal | form — the one supporting hue |
| chartVolume | text2 | `#6E757B` mid cool ink | volume bars |
| chartHRV | zoneOptimal (green) | `#4E7A74` muted teal | HRV — positive physiology |
| chartSleep | zoneLow (slate) | `#5A6066` mid-dark cool ink | sleep |

## Verification artifacts (`/tmp/ws3-shots/`)

- `04-activeworkout-header.png` — ActiveWorkoutSheet with the new `InstrumentSheetHeader` (CANCEL · WORKOUT · FINISH, flat opaque plane, bottom hairline). The headline deliverable ("biggest leak").
- `06-trainingprofile-header.png` — TrainingProfileSheet header (DISCARD CHANGES · TRAINING PROFILE · SAVE PROFILE). Confirms header consistency AND the `isDisabled: !isFormValid` state — SAVE PROFILE renders visibly dimmed.
- `05-entry-steppers.png` — WeightBlockPicker (fixed-width "70 kg" readout + 67.5/70/72.5 tiles + keypad affordance) and the RepScrubber track, inside the restyled sheet.
- `10-load-charts.png` — Load tab: LOAD TREND renders the ATL line in dark cool ink `#33383D`, recovery-vs-load area beneath (retuned palette, no olive/moss).
- `11-recovery-hrv-chart.png` — Recovery tab: HRV TREND renders in the muted teal `#4E7A74` supporting hue.
- `activeworkout.mp4` (1.29 MB) — ActiveWorkoutSheet stepper interaction + one-unit dismiss motion.

Two sheet-header renders (ActiveWorkout, TrainingProfile) plus steppers/charts/video cover the WS3 surface classes. The remaining 10 sheet headers use the identical `InstrumentSheetHeader` component and are build- + code-verified; MorningCheckInSheet's trigger is not reachable in SCREENSHOT_MODE (check-in seeded complete), so it was not rendered live.

## Ownership compliance

`git status` touched only WS3-owned paths (SheetChrome.swift, the 12 listed sheets, the 6 controls, ColorTokens chart tokens). No edits to CardStyle/TickScale/InkTabBar/DESIGN.md (WS1), LayoutPrimitives or tab views (WS2), pbxproj, or Localizable.xcstrings.

## Deferrals

- **ShareImportPreviewSheet title**: no distinct "preview/shared-plan" localized key exists; reused `nav.importTemplate` (accurate — step 2 of the same enter-code→preview→import flow). A dedicated key would need a new `Localizable.xcstrings` entry (out of WS3 chrome scope) — flagged for the orchestrator.
- **SetStepper / RepScrubber focus-branch readouts** are editable `TextField`s, so `.numericText` digit-roll can't drive them; width is stable structurally. The roll applies to the non-editing display readouts.
