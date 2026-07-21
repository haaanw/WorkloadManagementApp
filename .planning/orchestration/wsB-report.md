# WS-B · Machined Form System — Report

Date: 2026-07-21. Workstream WS-B of the Tuwa v4.2 "Machined" round. Repo `/Users/hanwen/dev/Tonus`,
canonical checkout (no worktree/branch). **Left uncommitted for the orchestrator** (coordination rule 1).

## Outcome

The machined form system is built on the pre-committed `.raised` / `.debossed` Relief primitives and
deployed across every owned surface. **Build green** (`** BUILD SUCCEEDED **`, sim `8E872500…`,
`-derivedDataPath ~/.tonus-dd`). Every stock `Menu` in the owned files is dead. No `.shadow()`, no
numeric-literal corners, no `.system(`, no bare `withAnimation {`, animation only through `Motion.*`.

## 1. InstrumentForm.swift — the six components (built)

All on `.raised` / `.debossed` (never hand-rolled relief), tokens only, motion via `Motion.*`:

| Component | What it is |
|---|---|
| `TickChevron` | Drawn 1.5px caret (a `Shape`, not an SF Symbol); rotates 180° on `Motion.state` when its row opens. |
| `ReadoutWell` | Fixed-width **debossed** value pocket — mono `dialSmall` value + micro-caps unit; reserves the widest reading (`widthTemplate`) so the metal never resizes; digits roll via `Motion.digitRoll`. |
| `InstrumentFormRow` | 56pt label(+subtitle) + trailing content row; `.rowWell` press when actionable; optional rotating tick-chevron. |
| `MachinedOptionCell` | A `.raised` option cell with a **drilled selection dot** (ink ring → fills ink when selected). Shared by the selects and the onboarding pickers. |
| `InlineOptionList` / `InlineMultiOptionList` | **The stock-`Menu` replacement.** The row opens a **debossed channel** of machined cells inline; single-select updates the readout + auto-collapses (~220ms, `asyncAfter` — not an animation curve), multi-select toggles in place with a running count. Two inits: `Binding<T>` and `Binding<T?>`+placeholder. |
| `FormField` | Right-aligned text field, quiet at rest, grows a **debossed focus well + 1pt ink border** while editing (`Motion.state`); `axis: .vertical` for notes. |
| `MachinedToggleStyle` (`.machined`) | Round polished knob (a raised disc) riding a **debossed channel** that turns ink when on, with an engraved index tick; one `Haptics.tap()` per flip. A `ToggleStyle`, so sites swap `.design` → `.machined`. |
| `DestructiveFormRow` | Quiet zone-danger row (`.rowWell` press, no alarm fill). |

## 2–4. App-wide sweep (owned files only)

- **ProfileView** — `editableTextField`→`FormField`; every `editablePicker` (Sport / Training Frequency /
  Experience / Weight Unit / notification Day / Time) → `InlineOptionList` (**all stock `Menu`s dead**);
  training-profile summary rows → `ReadoutWell`; Weekly-Summary `Toggle` → `.machined`; Sign out →
  machined row; Delete account → `DestructiveFormRow`. Section plates are now **`.raised`** milled
  plates with transparent rows. `profile.movementBank` a11y ID and all bindings/save paths preserved.
- **TrainingProfileSheet** — `pickerRow`(Menu)→`InlineOptionList` (optional binding + placeholder);
  `movementTypesRow`(multi-Menu)→`InlineMultiOptionList`; injury body-regions → `MachinedOptionCell`s
  in a debossed channel; injury notes → `FormField`. Section plates → `.raised`. `userHasEdited`
  dirty-tracking preserved via `onSelect`/`onToggle`.
- **NiggleLogSheet** — region `Menu`→`InlineOptionList` (with `systemImageFor`); limited-training
  `Toggle` .design→.machined (dropped the now-double `onChange` haptic); note field → `FormField`.
- **MorningCheckInSheet** — notes field → `FormField`; the WellnessSlider `\(value)/5` and the
  `\(Int(wellnessScore))/100` readouts → `ReadoutWell` (fixed-width). No `Menu`s here.
- **OnboardingView** — frequency grid, experience list, and language rows → `MachinedOptionCell`
  (raised cells + drilled dots); language step wrapped in a debossed channel. Paged flow unchanged.
- **SetStepper** (both variants) — restructured from butted control to **raised ± keys flanking a
  debossed readout well** (the editable value now sits in a `.debossed` pocket). Step/detent logic and
  the v4.1 limit-only haptic policy are byte-for-byte unchanged.
- **WeightBlockPicker** — the live value readout above the tile cluster → `ReadoutWell` (`999.5`
  template). Tile commit/snap logic and `Haptics.select()` policy unchanged.

Haptic-doubling avoided throughout: components own their commit haptic (`select`/`tap`), so wrapper
call sites no longer re-fire it.

## 5. Menu audit — deferrals (files NOT in the WS-B sweep list; left untouched)

`grep -rn "Menu {" WorkloadApp/Views WorkloadApp/Components` after the sweep:

| File:line | What | Disposition |
|---|---|---|
| `Views/WorkoutLog/WorkoutLogView.swift:67` | Header **overflow-action** menu (Plan Today / LLM Import) — an action menu, not a settings picker | **DEFER.** WorkoutLog root (not a sheet); the matrix grants only WorkoutLog *sheet* Menu replacements. |
| `Views/WorkoutLog/ExercisePickerView.swift:187` | `equipmentMenu` — 28-value **filter facet** with active-accent | **DEFER (flag).** WorkoutLog *sheet*, so technically in the matrix's exception, but a 28-value facet would bloat an inline channel; recommend a dedicated filter treatment, not a naive `InlineOptionList`. |
| `Views/Profile/MovementBankView.swift:217` | `equipmentMenu` — same 28-value filter facet | **DEFER (flag).** Profile/* by header, but a just-shipped feature outside the named sweep + the same 28-value concern. |
| `Views/Profile/MovementBankView.swift:884` | Category picker (`ExerciseCategory`) in add/edit-exercise row — a clean small-enum settings picker (the banned pattern) | **DEFER (recommend).** The one straightforward `InlineOptionList` candidate left; outside the named sweep. Trivial follow-up. |
| `Components/RadialPicker.swift:182` | The **VoiceOver / Reduce-Motion accessibility fallback** (D-14, "Long press to choose") | **KEEP.** A native, accessible affordance — intentionally a system `Menu`, not a style violation. |
| `Views/WorkoutLog/TemplateCarouselSection.swift:306` | `.contextMenu` (long-press), not a settings/picker `Menu` | **N/A.** Context menus aren't the banned pattern. |

Recommendation: a small follow-up can machine `MovementBankView:884` (category) and decide a facet
treatment for the two 28-value equipment menus. None were touched to keep WS-B disjoint and to avoid
destabilizing the just-shipped Movement Bank.

## Verification (SCREENSHOT_MODE, sim 8E872500-703D-4292-9758-38ADFCCFB126)

Screenshots in `/tmp/wsb_*.png`; motion clip `/tmp/wsb_motion.mp4` (Sport open→select→collapse + toggle flip).

- **Profile** — raised section plates; Sport/Frequency/Experience/Weight-Unit/Day/Time as debossed
  readout wells + drawn tick-chevrons; Name as `FormField`; Sign Out machined; **Delete Account** quiet
  zone-danger. ✔
- **Sport `InlineOptionList`** — opens a debossed channel of raised cells; selected "Team Sport" bold
  with a filled drilled dot, others empty rings; chevron rotates up; **selecting collapses the bay**. ✔
- **MachinedToggle** — captured **off** (round knob left, well channel) and **on** (channel turns ink,
  knob slides right, index tick lights). ✔
- **TrainingProfileSheet** — every picker a debossed "Select"/"---" well; opened "Sessions per week"
  (numeric channel 1–14 with drilled dots), selected **4** → readout updated + collapsed; opened
  "Movement types" multi-select channel. ✔
- MorningCheckIn / NiggleLog sheets weren't individually reachable in the seeded SCREENSHOT_MODE state
  (their entry CTAs didn't trigger the sheet under scripted taps), but both are build-verified and reuse
  the identical, already-proven components (`FormField`, `ReadoutWell`, `InlineOptionList`,
  `.machined`). Flagging for the orchestrator's on-device pass.

## Files touched (all within the WS-B ownership row)

```
WorkloadApp/Components/InstrumentForm.swift      (built out the stub)
WorkloadApp/Views/Profile/ProfileView.swift
WorkloadApp/Views/Profile/TrainingProfileSheet.swift
WorkloadApp/Views/Recovery/NiggleLogSheet.swift
WorkloadApp/Views/Recovery/MorningCheckInSheet.swift
WorkloadApp/Views/Onboarding/OnboardingView.swift
WorkloadApp/Components/SetStepper.swift
WorkloadApp/Components/WeightBlockPicker.swift
```

Nothing outside the ownership list was edited (`ColorTokens`, `CardStyle`, `project.pbxproj`,
`Localizable.xcstrings`, AppShell*, Views/Coach/, DESIGN.md, WorkoutLog/*, MovementBankView — all
untouched). No new localized keys were introduced (existing keys reused; already-localized `String`
labels are rendered verbatim through `LocalizedStringKey("\(label)")`).

## Build

```
xcodebuild -project "workload management/workload management.xcodeproj" \
  -scheme "workload management" -destination "id=8E872500-703D-4292-9758-38ADFCCFB126" \
  -derivedDataPath ~/.tonus-dd build
…
** BUILD SUCCEEDED **
```

Per rule 2, `xcodebuild test` was NOT run — the full gate (fence tests + 784 baseline) is the
orchestrator's. A manual fence self-scan of the eight touched files found no violations
(corners via CornerTokens, no `.shadow(`, no `.system(`, no raw animation curves, no `SourceSerif4`).
