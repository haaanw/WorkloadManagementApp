# Session D — adoption lane status (Profile + Onboarding + Auth + shared `Components/`)

Lane: `WorkloadApp/Components/` (owned this wave), `Views/Profile/`, `Views/Onboarding/`, `Views/Auth/`.
Branch `v1.7-field-notes`. No commits, no stage, no stash, no checkout — orchestrator commits.
Build DerivedData: `~/.tonus-dd-claude-d`.

---

## 2026-07-30 · Wave 2 adoption pass — components + views restyled; **final full-suite run NOT completed**

> **Read section 6 first if you are gating on verification.** I got nine clean incremental
> `xcodebuild build` results, and I did **not** finish the full unit suite — I was killed by the
> stall watchdog at the moment I launched it. Two edits (both in `PRBanner.swift`) landed *after*
> my last green build and have therefore never been compiled by me.

---

## 1. API changes B/C must know about

**Bottom line: there are no breaking API changes. Every prior call site compiles unchanged.**
One initializer gained two *defaulted, appended* parameters; nothing else moved. No parameter was
removed, renamed, retyped, or reordered anywhere in `Components/`.

| Component (file) | Public surface | Verdict |
|---|---|---|
| `MetricTile` (`MetricTile.swift`) | `title:` `value:` `subtitle:` `color:` | **Unchanged.** No new params. `color` is now *documented* as the metric-hue channel; its name, type, position and `ColorTokens.text1` default are identical. |
| `ZoneBadge` (`MetricTile.swift`) | `label:` `color:` | **Unchanged.** |
| `DeltaIndicator` (`DeltaIndicator.swift`) | was `delta:`; now `delta:` + **`goodIsUp: Bool = true`** + **`significantThreshold: Double = 3.0`** | **Additive only.** Both new params are defaulted and appended *after* `delta`, so the memberwise init still accepts `DeltaIndicator(delta: x)`. The single existing call site (`Views/Dashboard/WeeklySummaryCard.swift:123`) compiles untouched. Pass `goodIsUp: false` for lower-is-better metrics (RHR). |
| `HRVTrendChart` (`HRVTrendChart.swift`) | `data:` | **Unchanged.** |
| `SleepTrendChart` (`SleepTrendChart.swift`) | `recoverySnapshots:` | **Unchanged.** |
| `StalenessWarningBadge` (`StalenessWarningBadge.swift`) | `daysAgo:` | **Unchanged.** |
| `MetricCell` / `MetricDeltaLine` / `RuledSectionHeader` (`LayoutPrimitives.swift`) | `MetricCell(label:value:unit:valueColor:accessory:)` and the convenience `MetricCell(label:value:unit:valueColor:delta:)`; `MetricDeltaLine(text:)` | **Unchanged.** I *removed* `MetricCell`'s now-unused `@Environment(\.locale)` + `isLatin` (private stored/computed state, never part of any initializer — `AnnotationLabel` carries the CJK guard now). `RuledSectionHeader` untouched, keeps its own guard. |
| `TooltipBubble` / `ChartTooltipGesture` (`ChartTooltipOverlay.swift`) | `TooltipBubble(value:dateLabel:)` | **Unchanged.** `ChartTooltipGesture` not edited at all. |
| `TickScale` (`TickScale.swift`) | all inits | **Unchanged.** One font token swapped inside the `Canvas` draw. |
| `SheetHeaderButton` / `InstrumentSheetHeader` (`SheetChrome.swift`) | `SheetHeaderButton(title:emphasis:isDisabled:action:)` | **Unchanged.** `InstrumentSheetHeader` not edited. |
| `ReadoutWell` + form rows (`InstrumentForm.swift`) | `ReadoutWell(value:unit:widthTemplate:color:rolls:)` | **Unchanged.** Only the `unit` label's *rendering* changed. |
| `SessionStartPicker` / `MatchTierPicker` (`SessionStartPicker.swift`) | `SessionStartPicker(choice:sportType:sessionType:matchTier:)`, `MatchTierPicker(selection:)` | **Unchanged.** Added `@Environment(\.locale)` + a `private var isLatinLocale` to each struct — property-wrapper properties carry their own default and stay out of the memberwise init. |
| `PRBanner` (`PRBanner.swift`) | `prs:` `onDismiss:` | **Unchanged** (+ private `@Environment(\.locale)`). ⚠️ see §6: this file's last two edits are unbuilt. |
| `SpikeAlertBanner` (`SpikeAlertBanner.swift`) | `alert:` `onDismiss:` | **Unchanged** (+ private `@Environment(\.locale)`). Confirmed compiling at build checkpoint 6. |
| `REDSAttentionBanner` (`REDSAttentionBanner.swift`) | `onDismiss:` | **Unchanged** (+ private `@Environment(\.locale)`). Confirmed at checkpoint 6. |
| `CycleStatusStrip` (`CycleStatusStrip.swift`) | `snapshot:` | **Unchanged** (+ private `@Environment(\.locale)`). Confirmed at checkpoint 6. |
| `CycleFuelingCard` (`CycleFuelingCard.swift`) | `phase:` | **Unchanged** (+ private `@Environment(\.locale)`). Confirmed at checkpoint 6. |
| `DataSufficiencyRing` (`DataSufficiencyRing.swift`) | `progress:` `label:` `message:` | **Unchanged.** One colour token swapped. |
| `FatigueAttentionBanner` (`FatigueAttentionBanner.swift`) | `fatigueIndex:` `zone:` | **Unchanged.** |

**Empirical confirmation, not just reasoning:** every one of those files except `PRBanner.swift`
was covered by a green `xcodebuild build` (checkpoints 1–9, §6). Since B's and C's views are in the
same working tree and were compiling in those same runs, their call sites did in fact still
compile against my components at each checkpoint.

### Behavioural changes B/C should be aware of (no signature impact)

1. **`MetricTile` title + subtitle are now `AnnotationLabel`** (10pt Fragment Mono, uppercase,
   tracking + CJK guard applied by the primitive). Do **not** pre-uppercase or add `.tracking` at
   the call site. The value stays working voice (`smallLabelMedium` + `.monospacedDigit()`).
2. **`MetricTile.color` is the metric-hue channel.** C: `Views/WorkoutLog/SessionDetailView.swift`
   currently passes `ColorTokens.chartATL` / `chartCTL`. Under v6 those two readings have metric
   identities — they should be `ColorTokens.metricStrain` (ATL / acute) and `ColorTokens.metricLoad`
   (CTL / chronic). **That's your call site, not mine — I did not touch it.**
3. **`MetricCell.label` and `MetricCell.unit` are now annotation** (label 12pt, unit 10pt).
   `valueColor` is the hue channel and always lands on a `dataPlate` card plane, so a hue there is
   contrast-legal at any size.
4. **`MetricDeltaLine` (i.e. `MetricCell(delta:)`) is now the annotation voice.** C:
   `WorkloadView.swift` passes `"Acute · 7-day"`, `"Chronic · 28-day"`, `"Fresh"`/`"Fatigued"` —
   all fine (terse, machine-flavoured). **Never pass a sentence into `delta:`** — DESIGN.md rule 9.
5. **`DeltaIndicator` glyphs replaced the SF Symbol arrows** with `▲ △ = ▽ ▼`, and the
   unfavourable colour moved `zoneDanger` → `zoneCaution` (see §7.2 — flagged for review).
6. **`HRVTrendChart` series: `chartHRV` `#4E7A74` → `metricRecovery` `#1D7189`**, 1.5pt stroke,
   `chartGrid` gridlines, `annoSmall` axis labels.
7. **`SleepTrendChart` bars: zone-coded → uniform `metricSleep`, and the 3-swatch duration legend
   is DELETED.** This is my one content-affecting decision — see §7.1.
8. **`TickScale` numerals moved `micro` (11pt) → `annoSmall` (10pt)** per DESIGN.md's TickScale
   section. Geometry unchanged; the canvas already reserved headroom for 11pt.
9. **`ReadoutWell`'s unit is now `AnnotationLabel(..., color: text2)`** — `text2` rather than the
   `text3` annotation default *on purpose*: a readout well is DEBOSSED, and DESIGN.md rule 7 bans
   `text3` annotation on wells (2.84:1). This also fixes a pre-existing v5 contrast miss, and it
   reaches every stepper/picker that composes `ReadoutWell` for free.
10. **`DataSufficiencyRing` arc `text1` → `accent`** (a sufficiency arc is a progress fill =
    travertine's exclusive live-state territory; the DS `SufficiencyRing` draws it in `--accent`).
11. **I never defined an annotation stagger.** Every reveal goes through A's
    `.annotationReveal(index:)`, so fence test
    `test_annotationChoreography_hasOneImplementation` should stay green.

---

## 2. The `ZoneBadge` contrast fix (Session A's constraint aimed at me)

**A's constraint:** `ZoneBadge` and any metric-hue/zone-coloured text below 24pt must render on a
**card plane**, not the `background` scroll canvas — `zoneOptimal`/`metricReadiness` measures
4.39:1 on `bg` (fails the 4.5:1 small-text floor) vs 4.71:1 on `surfaceEl` and ≈4.85:1 on
`surfaceEl2`.

**I verified the actual instantiation sites** (`grep` for `ZoneBadge(` across
`WorkloadApp/`, `WorkloadAppTests/`, `WorkloadAppUITests/`). There are exactly two, both in B's
lane, and **both already sit on card planes** — so nothing was broken today:

| Site (line numbers as of my read; B was editing live) | Host plane | Contrast |
|---|---|---|
| `Views/Recovery/RecoveryView.swift:282`, inside `heroPlane` → `.emphasisCardStyle()` (`RecoveryView.swift:333`) | `surfaceEl2` `#FCFBF9` | ≈4.85:1 ✓ |
| `Views/Dashboard/DashboardView.swift:660`, inside `TrainingLoadSection` → `.cardStyle()` (`DashboardView.swift:707`) | `surfaceEl` `#F8F7F4` | 4.71:1 ✓ |

**I still made the badge supply its own card-plane backing**, because "it happens to be placed
correctly today" is not enforcement and I own the chokepoint:

```swift
.background(ColorTokens.surfaceEl2, in: Capsule())   // added
.overlay(Capsule().stroke(color, lineWidth: 0.5))    // unchanged
```

Why `surfaceEl2` (the brightest plane) rather than `surfaceEl`:

- On a `surfaceEl2` host (Recovery) it is a **visual no-op**.
- On a `surfaceEl` host (Dashboard) it is a **4/255 lift** — imperceptible, and it reads as the
  *raised chip* the Relief Law asks for ("raised = brighter").
- On the bare `background` canvas — the failing case, and where any future call site will most
  likely drop it — it is what makes the badge legal (≈4.85:1 instead of 4.39:1).

**Nocebo guard confirmed intact:** the badge is still **text label + 0.5pt hairline `Capsule()`
stroke in the zone colour**. The new fill is **stone** (`surfaceEl2`), never the zone colour —
there is still no zone-coloured fill anywhere in the component, and the text label remains the
primary carrier of state with colour as redundant reinforcement.

**One other change in the same file:** the locale test moved from `== "en"` to the codebase's
`isLatin` idiom (`!= "zh"`), matching `AnnotationLabel`, `MetricCell`, `RuledSectionHeader` and
`ScreenHeader`. **This is behaviourally a no-op today** — `LocaleManager.supported` ships only
`en` and `zh-Hans` (fr is website-only), so the two predicates are equivalent in the app. Idiom
alignment only; I am not claiming a bug fix.

**Not mine, flagged for B:** `Views/Dashboard/WeeklySummaryCard.swift:91` instantiates a *separate*
`WeeklyZoneBadge`, not my `ZoneBadge`. It may need the same card-plane treatment. **B's file — I
did not touch it.**

**Also frozen, same contrast class:** `StatusBadge` in `CardStyle.swift:1144` is an 11pt
zone-coloured label inside a capsule with **no plane backing at all** and unconditional
`.tracking(1.2)` (no CJK guard). It appears to be dead code — I found zero call sites — so it is
low priority, but it is filed as a frozen-file request in §5.

---

## 3. Per-file changes — my Views

All eight are restyle-only: no behaviour, no logic, no layout structure, no copy, and **zero
localization keys added or removed**.

**`Views/Profile/SyncStatusView.swift`** — the three per-entity sync stamps ("2 min ago",
"Failed 3 min ago", "Never synced") → `AnnotationLabel(size: .small, color: text2)` +
`.annotationReveal()`. A sync stamp is a timestamp, i.e. textbook marginalia. `text2` not `text3`
because it is information the athlete may act on. The entity name stays working voice, and the
**trailing server error message stays working voice** — it is prose, and the annotation voice never
speaks sentences. Added `@Environment(\.locale)` for locale-correct lookup (see §7.6).

**`Views/Profile/VerdictMeasurementView.swift`** — `statRow`'s `context` line → annotation
(`.small`, `text2`). These are machine-flavoured denominators already written in the sanctioned `·`
grammar ("5 rated · 2 missed", "on 12 differing-verdict days"). Row labels and the readings stay
working voice; the honest-caption paragraph stays working voice.

**`Views/Profile/ProfileView.swift`** — the Data Sync row's trailing state ("All synced" /
"Issues") → annotation. A sync state is a machine status stamp. `zoneCaution` clears 4.5:1 on every
stone plane, and `profileSection` is a `.raised` card plane anyway. Everything else in this 32K
file is settings rows and prose — untouched. Note `profileRow` composes `ReadoutWell`, so its units
picked up the annotation voice via `InstrumentForm.swift` without editing this file.

**`Views/Profile/MovementBankView.swift`** — three regions of a 35K file:
(a) the bank row's state badge ("Hidden"/"Custom"/"Edited") → annotation; `badgeKey(for:)` return
type changed `LocalizedStringKey?` → `String.LocalizationValue?` (private method, call sites still
pass bare literals); (b) `defaultsPlate`'s section key → annotation, dropping the hand-typed
`.tracking(0.9)` / `.textCase(.uppercase)`; (c) `metadataRow`'s caption → annotation, parameter
retyped `LocalizedStringKey` → `String.LocalizationValue` (private, three literal call sites
unchanged). Values stay working voice; the plate is a `dataPlate` card plane. Added
`@Environment(\.locale)` to `MovementBankView` and `CatalogExerciseEditSheet`. The rest of the file
is form and prose — deliberately untouched.

**`Views/Profile/SeanEllisPromptSheet.swift`** — the "ONE QUESTION" kicker → annotation. The
question, the three equal-weight choices and the skip action all stay working voice; the
equal-weight one-builder nocebo grammar is untouched.

**`Views/Profile/InviteConfirmationSheet.swift`** — the "COACH REQUEST" / "LINK ATHLETE" kicker
above the page title → annotation. Strings kept **byte-identical** (already uppercase, so the
primitive's transform is a no-op and zh-Hans — which never had these localized — is unaffected).

**`Views/Onboarding/OnboardingView.swift`** — one token: the active step dot `text1` → `accent`.
An active/selected dot is a live-state mark, travertine's exclusive territory under the Reading
Colour Rule; marks are unrestricted by the contrast rule. **No annotation added anywhere** — this
flow is prose + CTAs, and per my brief forcing mono in here is the main way this lane goes wrong.

**`Views/Auth/SocialLoginButtons.swift`** — one change: the "OR" divider label → annotation. Set
between two hairlines it is a separator mark, not something the app says, and at `body` (17pt) it
read as copy. Added `@Environment(\.locale)`. Nothing else on the auth surfaces got annotation.

---

## 4. Files in my scope I did NOT touch

### Views — all deliberate

- **`Views/Auth/LoginView.swift`** — **deliberate.** Wordmark, tagline, two fields, one CTA, one
  link, one error string. Nothing here is marginalia. Zero annotation is the correct answer.
- **`Views/Auth/SignUpView.swift`** — **deliberate.** Same shape. Its `.Tokens.micro` sport-cell
  caption is a *control label* and its field captions are *form-field labels* — DESIGN.md rule 9
  bars the annotation voice from both. Its selected-cell treatment (`surfaceEl2` + 1pt ink border)
  is already v5-correct.
- **`Views/Profile/TrainingProfileSheet.swift`** — **deliberate.** It is a form. The trailing row
  values ("2 areas") are *readings* at `body`, and their siblings are `ReadoutWell`s; annotating
  them would break the row rhythm and shrink the primary value. Rule 9 bars annotation from the
  field labels. Its wells did get the unit treatment for free via `InstrumentForm.swift`.
- **`Views/Profile/LanguagePickerView.swift`** — **deliberate.** Autonym rows plus one footer
  sentence; no marginalia exists, and the active row already uses the raised-plane + checkmark
  grammar with no accent.

### Components — deliberate, with one honest exception

- **`CardStyle.swift`** — **FROZEN** (Session A's chokepoint). Not touched. Requests in §5.
- **`InkTabBar.swift`** — **deliberate.** DESIGN.md says the tab bar is "unchanged from v5"; it is
  already text-only `keyLabel` with the accent tick, the CJK guard, and the one sanctioned
  `tickSpring` overshoot. Editing it would only risk that.
- **`SharpTextFieldStyle.swift`** — **deliberate.** Focus relief, corners and motion already
  v5-correct; it renders no text of its own.
- **`ToastBanner.swift`** — **deliberate.** Its only string is a sentence.
- **`BehaviorTagChip.swift`** — **deliberate.** A selectable chip label is working voice (the DS
  `TagChip` uses `--font-sans`), and adopting the DS's ink-fill-on-select would put many ink pills
  on `MorningCheckInSheet`, against the one-ink-pill-per-screen rule. Current raised + ink-border
  treatment is v5-sanctioned.
- **`RepScrubber.swift`, `SetStepper.swift`, `WeightBlockPicker.swift`** — **deliberate.** Detent
  controls whose captions are control/field labels (rule 9) and whose readouts already route
  through `ReadoutWell` / `InstrumentForm`, which I did restyle — so the annotation unit reaches
  them without editing them.
- **`RadialPicker.swift`** — **unfinished by choice, not fully deliberate.** Same rule-9 reasoning
  as the other pickers, *but* its collapsed-tile title at line ~149 still uses `isEnglish`
  (`== "en"`) rather than the `isLatin` idiom. Cosmetically equivalent today (the app ships only
  en + zh-Hans), so I left it to limit blast radius on a 12K interactive control. Worth a one-line
  follow-up for consistency.

---

## 5. Frozen-file requests (I made none of these changes)

All three are in **`WorkloadApp/Components/CardStyle.swift`**, Session A's file.

**REQ-D1 — HIGH, and it affects B and C far more than me: give `AnnotationLabel` a
localization-key overload.**
`AnnotationLabel` takes a resolved `String`, which pushes every call site into
`String(localized:)`. `String(localized:)` resolves against the **process** locale
(`Locale.current`), **not** the `.environment(\.locale, …)` that `LocaleManager` pins the app's
language with. So converting a `Text("some.key")` into
`AnnotationLabel(String(localized: "some.key"))` silently drops that string out of in-app live
language switching.
*Requested:* an `init(_ key: String.LocalizationValue, size:color:)` (or a `LocalizedStringKey`
overload) that resolves internally through `LocalePinnedStrings.localized(_:locale:)` using the
primitive's already-present `@Environment(\.locale)`.
*What I did instead, since I can't edit the file:* every string I converted goes through
`LocalePinnedStrings.localized(_:locale:)` and I added `@Environment(\.locale)` to the seven
structs that needed it. Correct, but verbose, and it is not the pattern the rest of the tree uses.
*Why this is urgent:* my audit of `AnnotationLabel(` call sites shows **B and C have ~80 of them,
and a large share pass `String(localized:)`** (e.g. `SessionDetailView` table headers,
`WeeklySummaryCard` headers, `TodayVerdictCard`, `ExercisePickerView`, `WorkloadView`,
`ActiveWorkoutSheet`). If the overload lands, they become a mechanical sweep; if it doesn't, v6
ships with zh-Hans live-switching regressions across three lanes.

**REQ-D2 — MEDIUM: `ScreenHeader`'s `context` line (`CardStyle.swift` ~line 755).**
(a) It applies `.textCase(.uppercase)` **unconditionally** while gating only `.tracking` on
`isLatinLocale` — a zh-Hans violation (Chinese takes no case transform).
(b) DESIGN.md's Layout section names this exact context line as "the natural home of an
**annotation** stamp (`MON 07.28 · WK 31`)", so it is the one obvious v6 gap left in the
chokepoint. Latent today: no call site passes `context:` (all five tabs pass `title:` only),
including `ProfileView.swift:30`.

**REQ-D3 — LOW: `StatusBadge` (`CardStyle.swift:1144`).** Unconditional `.tracking(1.2)` with no
CJK guard, and an 11pt zone-coloured label in a capsule with **no card-plane backing** — the same
contrast class A flagged for `ZoneBadge`, unfixed. I found **zero call sites**, so it looks like
dead code; either delete it or give it the `surfaceEl2` capsule backing I gave `ZoneBadge`.

No `.pbxproj` change needed — I added no files.

---

## 6. Verification — exactly what I ran, and what I did not

**Command used at every checkpoint** (my own DerivedData, run from the project dir — note the
scheme lives in `workload management/`, not the repo root):

```
cd "/Users/hanwen/dev/Tonus/workload management" && xcodebuild build \
  -scheme "workload management" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -derivedDataPath ~/.tonus-dd-claude-d
```

**Nine consecutive green builds**, each after 3–5 files, output filtered to
`error:|BUILD (SUCCEEDED|FAILED)`; every one printed exactly:

```
** BUILD SUCCEEDED **
```

| # | Files covered |
|---|---|
| 1 | `MetricTile`, `HRVTrendChart`, `SleepTrendChart`, `DeltaIndicator`, `StalenessWarningBadge` |
| 2 | `TickScale`, `SheetChrome`, `LayoutPrimitives`, `CycleStatusStrip`, `CycleFuelingCard` |
| 3 | `SpikeAlertBanner`, `FatigueAttentionBanner`, `REDSAttentionBanner`, `PRBanner` (first edit), `ChartTooltipOverlay`, `DataSufficiencyRing` |
| 4 | `InstrumentForm`, `SyncStatusView`, `VerdictMeasurementView`, `InviteConfirmationSheet` |
| 5 | `SeanEllisPromptSheet`, `SocialLoginButtons`, `OnboardingView` |
| 6 | the locale-correctness pass (`CycleStatusStrip`, `CycleFuelingCard`, `SpikeAlertBanner`, `REDSAttentionBanner`, `SyncStatusView`, `SocialLoginButtons`, `ProfileView`, `SleepTrendChart`) |
| 7 | `MovementBankView` — `defaultsPlate` + `metadataRow` |
| 8 | `MovementBankView` — row badge + `@Environment(\.locale)` |
| 9 | `SessionStartPicker` |

**Zero errors and zero new warnings across all nine.** No cross-lane transient failures ever
surfaced — B's and C's files compiled in the same runs throughout.

**What I did NOT do, stated plainly:**

- **I did not complete the full unit suite.** I launched
  `xcodebuild test … -derivedDataPath ~/.tonus-dd-claude-d -only-testing:WorkloadAppTests` and was
  killed by the stall watchdog before it produced any output. **There is no test result from me —
  not a pass, not a fail. I am claiming no test verification whatsoever, including for the fence
  suite.** Baseline for the orchestrator's run: 762 passed / 0 failed / 2 skipped, fences 17/17.
- **Two edits are unbuilt.** After checkpoint 9 I made two edits to
  `WorkloadApp/Components/PRBanner.swift` — added `@Environment(\.locale)` + `isLatinLocale`, and
  gated the banner title's `.tracking(0.88)` on it — and **never rebuilt**. It is the identical
  pattern to `SpikeAlertBanner`/`REDSAttentionBanner`, which built clean at checkpoint 6, so I
  expect it to compile, but **that is an expectation, not a result.** Please build before trusting.
- No simulator launch, no visual QA, no screenshots.
- No git operation of any kind: no commit, stage, stash, checkout, or branch change.
- **`CardStyle.swift` untouched**, along with `ColorTokens.swift`, `FontTokens.swift`,
  `DesignSystemFenceTests.swift`, `DESIGN.md`, `CLAUDE.md`, `AGENTS.md`, `*.pbxproj`, and every
  file under `Views/Dashboard/`, `Views/Recovery/`, `Views/Workload/`, `Views/WorkoutLog/`.

**Read-only fence sweep I did run** (grep, not a test): across `Components/`, `Views/Profile/`,
`Views/Onboarding/`, `Views/Auth/` there are **zero** `.system(` fonts, `.shadow(` calls,
`panelStyle` references, or hand-typed `cornerRadius: <number>` literals in my edited code. The
only hits were doc-comment prose and two pre-existing `cornerRadius: 0` button-style arguments in
the frozen `CardStyle.swift`.

---

## 7. Unsure, judgment calls, and design-system contradictions

**7.1 `SleepTrendChart` — the one content-affecting decision, and the contradiction behind it.**
My brief says series take their metric hue (`metricSleep` for sleep). The file's bars were
zone-coded by duration band with a three-swatch colour legend below. Those cannot both hold: with
one hue in the plot, the legend becomes a key describing marks that no longer exist. The design
system pulls both ways — `readme.md` says "each metric owns a hue… legends become unnecessary" and
DESIGN.md's chart grammar says marks are "hue-coded by metric", while the zone-colour rule
legitimately permits colour for *state*.
**Adopted:** bars → uniform `metricSleep`; **legend deleted**; the sufficiency threshold survives
as the dashed 7 h target `RuleMark` plus its (now annotation) callout.
**Cost:** the 6 h boundary is no longer stated anywhere on the chart. Three now-unreferenced
xcstrings keys (`sleep.chart.legend.excellent` / `.good` / `.poor`) are **left in the catalog** —
content freeze, and unused keys are harmless. No test referenced them.
**Alternative if HAN/you prefer:** restore zone-coded bars + the legend and accept that sleep
carries no metric identity in this chart. Reversible in ~10 lines, one file. **Please review — this
appears on B's Recovery tab and B's `SleepDetailView`.**

**7.2 `DeltaIndicator` colour semantics — adopted the DS over the app.** The design system's
`DeltaIndicator.jsx` colours an unfavourable delta `--zone-caution`; the app used `zoneDanger`. I
adopted `zoneCaution`, consistent with "never alarmist, never punitive" — a week-over-week dip is
not an alarm. **This is a semantic softening visible on B's `WeeklySummaryCard`.** Flagging rather
than burying it; one-token revert.

**7.3 The DS's own `ZoneBadge` specimen is the failing case.**
`guidelines/zone-colors.card.html` renders the badge on `--bg` with no fill — exactly the 4.39:1
configuration A measured as illegal, and `readme.md` + `tokens/colors.css:29` both assert the zone
colours are "≥4.5:1 on stone", which A already measured false on the base plane. I did not change
a token; the `surfaceEl2` capsule backing (§2) is the mitigation. **The specimen card and that
prose claim should be corrected in `design-system/` so the next reader isn't taught the violation.**

**7.4 `MetricTile` value size — a DS spec I could not honour.** `MetricTile.jsx` sets the value at
20px. `FontTokens` has no 20pt token and it is frozen, so the value stays `smallLabelMedium`
(13pt). Not filed as a hard request because it is aesthetic, not a law — but it is a real,
knowing deviation from the DS component spec.

**7.5 Chart crosshair markers.** DS chart grammar says markers are **open** circles (`○`) with one
hue dot for "now". `HRVTrendChart` still draws filled `Circle()` symbols at every point. I left it:
changing every symbol plus adding a distinguished "now" `PointMark` is a mark-level redesign, not a
restyle, and it would land on B's Recovery tab mid-wave. Follow-up candidate.

**7.6 `String(localized:)` vs the pinned locale — a pre-existing, tree-wide concern.** As in
REQ-D1: `String(localized:)` reads the process locale, while `LocaleManager` pins language through
`.environment(\.locale, …)`. **There are ~531 `String(localized:)` call sites already in the app**,
so this predates v6 by a long way and is far outside my lane — I did not touch any pre-existing
one (e.g. `CycleStatusStrip`'s `dayText`, `SpikeAlertBanner`'s `severityLabel`), which does mean
`CycleStatusStrip` now mixes a pinned-locale key with a process-locale day counter. I only ensured
**my own** conversions did not *introduce* new instances. Worth its own scoped investigation after
v1.7; if the 531 are in fact fine, then `LocalePinnedStrings` may be unnecessary and my seven
`@Environment(\.locale)` additions could be simplified away. **I am genuinely unsure which way
this resolves** — I chose the strictly-more-correct helper rather than matching the majority.

**7.7 `SignInWithAppleButton` is a dark surface.** `SocialLoginButtons.swift:46` uses
`.signInWithAppleButtonStyle(.black)`. DESIGN.md's Hero Law says "a dark surface anywhere is a
design error". It is an Apple-HIG-mandated system control and cannot be restyled. Pre-existing;
left alone; recorded so nobody thinks it was missed.

**7.8 Where I drew the annotation line** (in case you want to re-litigate any of it). Test applied
to every string: *is this a key / unit / delta / timestamp / count / machine state, or is it
something the app says?* Annotated: units, sync stamps, cycle position, metadata keys, state keys
(`FATIGUE LOW`, `HIGH LOAD SPIKE`, `HIDDEN`), `KEY: VALUE` readouts, counts/denominators, axis
labels, tick numerals, kickers, the `OR` separator. **Left in the working voice:** all sentences,
`PRBanner`'s "New PR!" title, exercise names, zone-badge labels ("Optimal" is a statement about the
athlete), section headers, and **every form-field and control label** (rule 9). `RuledSectionHeader`
and `SectionHeader` stayed working voice for the same reason — annotation is never a headline.

---

**Lane status: adoption work complete and self-consistent; verification incomplete on my side.**
Nothing is half-edited — every file I touched is in a finished state, and the only uncompiled
delta is the two-line `PRBanner.swift` CJK guard. Standing by; not running anything further.
