# Session C — adoption lane status (Workload + WorkoutLog)

Lane: `WorkloadApp/Views/Workload/` + `WorkloadApp/Views/WorkoutLog/`. Branch `v1.7-field-notes`.
No commits, no staging, no git writes of any kind (ground rule 2). Build DerivedData: `~/.tonus-dd-claude-c`.

---

## 2026-07-30T17:55 · Wave 2 adoption pass — 19 of 24 files adopted, 5 deliberately untouched

**Verification status up front, stated plainly:** my last *completed* verification was a green
BUILD. I ran the full unit suite and it reported `** TEST SUCCEEDED **` with 762 passed / 0 failed,
but I did **not** finish the follow-up verification I had queued (skip-count confirmation and the
fence suite in isolation) — that command was killed by the stall watchdog. Full details and exact
commands in §6. The orchestrator is re-running verification serially and centrally; nothing below
should be read as a completed test sign-off from me.

---

## 1. Per-file changes

### `WorkloadApp/Views/Workload/` (2 of 2 files)

**`WorkloadView.swift`** — the lane's headline surface.
- `ACWRGaugeCard` hero reading `snapshot.acwr`: `ColorTokens.accent` → **`ColorTokens.metricLoad`**
  (v6 Reading Color Rule — ACWR is the training-load metric). Doc comment rewritten to record that
  this supersedes the v5 travertine hero and that the TickScale needle *stays* accent.
- `ACWRGaugeCard` metric key: `Text("workload.section.acwr")` micro-caps → `AnnotationLabel` in
  **`metricLoad`** plus a `●` state dot (`accessibilityHidden`), matching this card's own specimen
  in `design-system/ui_kits/ios-app/LoadScreen.jsx` (`ACWR ●` in `--metric-load`). Wrapped in
  `.annotationReveal()`.
- `ACWRGaugeCard` zone label: micro-caps sans → `AnnotationLabel` keeping
  `ColorTokens.acwrZoneColor(zone)`, `.annotationReveal(index: 1)`. Still text-label-first; the
  colour is still supplementary. Sits on the RAISED CARD plane, satisfying rule 7.
- `LoadTrendChartView`: series hues, `chartGrid` axis grid + ticks, annotation-face axis labels,
  and a new mono series key (see §2). Header doc comment added recording the mapping.
- `PRHistorySection`: the `+%.1f` improvement figure → `AnnotationLabel` (a signed delta is
  marginalia), keeping `zoneOptimal`, on a card plane.
- **Left in ink deliberately:** the three `MetricCell` values (ATL/CTL/TSB). See §5 contradiction A.

**`RecoveryLoadChart.swift`** — recovery LineMark re-hued, `chartGrid` grid, annotation-face axis
labels, header doc comment recording why the BarMark stayed warm ink. Details in §2.

### `WorkoutApp/Views/WorkoutLog/` (17 of 22 files)

**`TodayVerdictCard.swift`**
- Header line → annotation voice on both ends: the `TODAY'S PLAN · <EXERCISE>` stamp
  (`AnnotationLabel`, `text3`) and the verdict state key (`AnnotationLabel`, **`text2`** per rule 7
  — annotation the athlete must not miss takes the stronger ink). Both keep 12pt so the two ends of
  the header still read as one rule, which is why the original code matched their cap heights.
- `fromPlannedCaption` (the `↓ from 140 kg` planned reference) → `AnnotationLabel`. It is a delta.
- `zoneCaption` (`IN TODAY'S ZONE`) → `AnnotationLabel`. It is an axis caption under an instrument.
- `.annotationReveal(index: 0…3)` on the four, so the card settles and *then* the scientist labels it.
- **Untouched by design:** the reason line, the confidence note, today's number, every key label and
  the decision row. Annotation never speaks a sentence; the nocebo guard and equal-weight `KeyRow`
  grammar are byte-unchanged. The verdict number stays INK — it is a lift target, not one of the
  five metrics, so no metric hue applies.
- Header doc comment rewritten v5 → v6 recording exactly which strings are which voice.
- `TodayVerdictCardGuardTests` bans `.shadow` / `.system(` / `.zoneDanger` / raw red+green and the
  nocebo phrase list — I introduced none of those.

**`WorkoutLogView.swift`**
- `SessionRow` meta line (duration · volume `kg` · RPE) → three `AnnotationLabel`s at `text2`; the
  shared `.font/.monospacedDigit/.foregroundStyle` on the parent HStack removed (the primitive owns
  all three). Session date on the right → `AnnotationLabel` at the `text3` default (it was already
  `text3`).
- `ImportRPESheet` meta line (relative date · duration · `km`) → `AnnotationLabel` at `text2`.
- `ImportRPESheet` slider end labels (`Easy` / `Maximal`) → `AnnotationLabel(size: .small)` — they
  are axis labels on an instrument.
- **Untouched:** `SessionFilterChip` labels (nav-ish selection labels, never annotation), the RPE
  prompt and value, the empty state.

**`SessionDetailView.swift`**
- Session date → `AnnotationLabel` at `text2`.
- Set-table column headers (`SET / WEIGHT / REPS / RPE / VOL`) → `AnnotationLabel(size: .small)`,
  fixed column `.frame(width:)` preserved. Verified the widths still fit at 10pt mono +0.5pt
  tracking (longest, `VOLUME`→`VOL`, ~47pt in a 56pt column).
- `ExerciseDetailCard` muscle-group tag → `AnnotationLabel` at `text2`.
- Token hygiene on the lines I was already editing: `spacing: 8` → `Spacing.xs`,
  `.padding(.horizontal, 16)` / `.padding(.vertical, 16)` → `Spacing.sm`.
- **Untouched:** the set-row values and set indices (they are the table's DATA, not marginalia — see
  the rule I applied in §5), and the `MetricTile` colours (§5 contradiction A).

**`ActiveWorkoutSheet.swift`** (77K — I read and edited only the regions listed, no wholesale rewrite)
- `setHeaderRow` → annotation voice at `.small`. **Signature changed** `columns: [(LocalizedStringKey, CGFloat)]`
  → `[(String, CGFloat)]` because `AnnotationLabel` takes a `String`; all four call sites
  (`weightReps` / `repsOnly` / `distanceDuration` / `durationOnly`) now resolve with
  `String(localized:)`. This is the churn that the frozen-file request in §4.1 would remove.
- Exercise-card muscle-group tag → `AnnotationLabel` at `text2`.
- `exercise.label.prefilledFromLast` provenance stamp → `AnnotationLabel`.
- `collapsedSummary` warmup flag → `AnnotationLabel`.
- **Untouched:** the elapsed-time readout (`pageTitle`, a hero-ish value), `summaryText`
  (`body` — dropping a completed set's primary readout 17pt → 12pt is a legibility/layout change,
  not a restyle), the set index, every form label, and the whole logging interaction.

**`ExerciseDetailSheet.swift`**
- `metadataRow` caption → `AnnotationLabel`. **Signature changed** `LocalizedStringKey` → `String`;
  the four call sites now pass `String(localized:)`.
- Instruction step ordinals → `AnnotationLabel` (machine index), fixed `.frame(width: Spacing.md)` kept.

**`ExercisePickerView.swift`** (40K — one region only)
- Result-row taxonomy line (muscle · equipment · custom) → `AnnotationLabel`s including the two `·`
  separators. Dropped the call-site `.capitalized` on equipment: the primitive uppercases for Latin
  and correctly skips it for CJK, which `.capitalized` could not.

**`FeltRightPromptRow.swift`** — `YESTERDAY'S CALL` stamp → `AnnotationLabel` + `.annotationReveal()`.
The planned→adjusted number line stays working voice (it is data).

**`NextMatchSection.swift`** — the match date → `AnnotationLabel` at `text2`. The days-out line
(`Match today` / `In 3 days`) deliberately stays working voice: it is a phrase the app *says*.

**`PrescribedWorkoutCard.swift`**
- Scheduled date → `AnnotationLabel`; session-type tag → `AnnotationLabel` at `text2`.
- Group header: `Text(group.groupName.uppercased())` → `AnnotationLabel(group.groupName)` — the
  manual `.uppercased()` is **deleted**, which is a real i18n fix, not just a face swap: the call
  site was force-casing regardless of locale, the primitive skips it for CJK.
- Set spec (`3 × 5 @ 100kg`) → `AnnotationLabel`.
- **Untouched:** Start / Skip action labels (CTAs are never annotation).

**`ShareCodeSheet.swift`** — the `label.shareCode` caption → `AnnotationLabel`. The **code value
itself stays `body`**: annotation caps at 12pt and a share code has to be read aloud and typed by a
second person. Recorded in the comment.

**`ShareImportPreviewSheet.swift`** — `template.label.shared` overline → `AnnotationLabel`; group
header → `AnnotationLabel` with the manual `.uppercased()` deleted; `.padding(…, 16/8)` literals on
those lines → `Spacing.sm` / `Spacing.xs`.

**`TemplateCarouselSection.swift`**
- `Last used …` → `AnnotationLabel(size: .small)` (a timestamp).
- Weekday initials strip (M T W T F S S) → `AnnotationLabel`; the mono face also puts the seven
  initials on a fixed pitch, which is what that strip wants.
- **Untouched:** the SUGGESTED / RECOVERY-ADJUSTED badge — see §5 contradiction F; badge face is a
  cross-lane decision with Session D's `ZoneBadge`, so I did not pick unilaterally.
- **Untouched:** swipe Archive / Delete labels (actions).

**`TemplatePickerSheet.swift`** — exercise count and last-used timestamp → `AnnotationLabel` at
`text2`. Left behind (honest): the `spacing: 8` and `.padding(.horizontal, 16)` / `.padding(.top, 16)`
off-token literals elsewhere in this file. They pass the fence (multiples of 4) but are not tokens.

**`TemplatePreviewSheet.swift`** — group header → `AnnotationLabel` (manual `.uppercased()` deleted);
set spec → `AnnotationLabel` at `text2`.

**`TextTemplateImportSheet.swift`** — parsed set spec → `AnnotationLabel`.

**`VerdictOutcomeSheet.swift`** — `LOOKING BACK` stamp → `AnnotationLabel` + `.annotationReveal()`.
The question, the three equal-weight choices and the honest-context line all stay working voice; the
shared single choice-button builder is untouched, so the equal-weight guarantee still holds by
construction.

**`WorkoutImportBanner.swift`** — `import.watch.header` stamp → `AnnotationLabel`; suggestion-row
meta (timestamp · duration · `kcal`) → `AnnotationLabel`s at `text2`; `spacing: 8` → `Spacing.xs`.
The Add button and the `xmark` dismiss are untouched.

### The rule I applied, so the next reviewer can check me consistently

> **Stamps, keys, tags, units, deltas, timestamps, counts, axis and column headers → annotation.
> The data itself, sentences, CTAs, form field labels and nav labels → working voice.**

Annotation is marginalia *around* readings; it is never the reading. `design-system/components/forms/`
confirms the second half independently: `TextField.jsx` renders field labels in `--font-sans`, and
only `ReadoutWell.jsx`'s **unit** is `--font-mono`.

---

## 2. Chart hue mapping and axis labels (the item you asked me to be explicit about)

### `LoadTrendChartView` (WorkloadView.swift)

| Series | Before | After | Why |
|---|---|---|---|
| ATL — acute load | `chartATL` (`#3A3733`) | **`metricStrain`** | Acute load / strain owns rust (brief's explicit mapping) |
| CTL — chronic load | `chartCTL` (`#97928A`) | **`metricLoad`** | Chronic load / ACWR owns ochre |
| TSB — `AreaMark` @ 0.2 | `chartTSB` (`#4E7A74`) | **unchanged `chartTSB`** | TSB is a derived balance with **no metric identity**; and it is an AREA FILL, so a metric hue there would break the "never an area-fill wash" prohibition |
| Grid lines + ticks | Swift Charts default | **`chartGrid`** (`#E4E2DC`) | v6 |

### `RecoveryLoadChart.swift`

| Series | Before | After | Why |
|---|---|---|---|
| Daily load — `BarMark` | `chartVolume` (`#767168`) | **unchanged `chartVolume`** | Judgment call — see below |
| Recovery score — `LineMark` | `chartHRV` (`#4E7A74`) | **`metricReadiness`** | It plots `recoverySnapshot.recoveryScore` — the readiness/recovery score, which owns verdant green. (Not `metricRecovery`: that hue is HRV/recovery *physiology*, and this series is the composite score.) |
| Grid lines + ticks | Swift Charts default | **`chartGrid`** | v6 |

**Why the bars stayed warm ink — flagging rather than burying.** DESIGN.md enumerates the permitted
metric-hue uses as "series lines, state dots, chart 'now' markers, and hero readings". `BarMark` is
not in that list, and 28 solid bars in rust read as a coloured *field*, which is the closest thing in
a chart to the banned "hue dresses a surface". So the bars kept warm ink and the line carries the
hue, which also keeps the two series distinguishable without a legend. **If the orchestrator reads
bars as ordinary series marks, this is a one-line change to `metricStrain`.**

**No "now" marker and no dashed baseline were added.** `LoadScreen.jsx` shows both (an open circle at
the last point, `stroke=metric-load`, and a dashed `text-3` baseline). Both would be new marks, i.e.
new content, so I left them out. They are the obvious next increment for this chart.

### Axis labels — and the CJK guard question

**I used no raw `Font.Tokens.annoSmall` anywhere.** Every axis value label is a View hosting the
primitive:

```swift
AxisValueLabel {
    if let date = value.as(Date.self) {
        AnnotationLabel(date.formatted(.dateTime.month(.abbreviated).day().locale(locale)), size: .small)
    }
}
```

Consequence, which is the answer to your question: **there is no hand-rolled locale guard in my
lane, because there is no raw-font axis label.** The zh-Hans no-uppercase / no-tracking rule is
carried by `AnnotationLabel`'s own `isLatin` check on every single axis label, exactly as on every
other label I touched. Nothing in my lane can drift from the guard.

Two consequences worth knowing:

1. Overriding `AxisValueLabel` content means I had to author the format explicitly (Swift Charts'
   automatic label content cannot be re-fonted while keeping its formatter). I deliberately reused
   the format each chart's own `TooltipBubble` already prints —
   `.dateTime.month(.abbreviated).day().locale(locale)` for X, `String(format: "%.0f", …)` for Y — so
   no new date/number vocabulary enters the app. Tick *density* is untouched (plain `AxisMarks`,
   no `desiredCount:`), but the X label **text** will now read e.g. `JUL 3` where the framework
   default may have printed a bare day number. That is the one place my restyle changes rendered
   glyphs rather than just their dress, and it is unavoidable if axis labels are to be mono.
2. `AnnotationLabel` reads `@Environment(\.locale)`; Charts should propagate environment into axis
   content, but **I did not visually confirm zh-Hans axis labels on the simulator.** Listed in §6 as
   an open verification item.

### The one additive element I introduced (easy to veto)

A mono series key under `LoadTrendChartView`: `● ATL` / `● CTL` / `▒ TSB`, where the **glyph carries
the hue** (a state dot / fill glyph — a sanctioned *mark*) and the **label stays `text3`**, so the
screen still has exactly one coloured *text* element (the ACWR hero). `.annotationReveal(index: 0…2)`.

Justification: `design-system/guidelines/charts.card.html` and `ui_kits/ios-app/LoadScreen.jsx` both
label chart series in Fragment Mono inside the plot (`HRV/RMSSD`, `STRAIN`, `LOAD/AU`, `TSB`), so a
mono series key is the design system's own chart grammar — and without it, hueing the lines gives
the hues no anchor. It uses `ATL`/`CTL`/`TSB` verbatim, the same untranslated scientific
abbreviations the metric grid directly above already prints, so **it adds zero localizable copy**.

**I did NOT add a key to `RecoveryLoadChart`**: it would have needed two new user-facing strings
("LOAD", "RECOVERY") with no zh-Hans translations, and I will not ship untranslated copy. If the
key is wanted there, it needs two catalog entries first — that is a copy request, not code.

Also additive: the `●` state dot on the ACWR hero key label (`ACWR ●`), copied from LoadScreen.jsx.

`.chartLegend(position: .bottom)` on `LoadTrendChartView` was left untouched. Note for the
orchestrator: it is a **no-op today** — Swift Charts only generates legend entries from a
scale-based `.foregroundStyle(by:)`, and this chart uses plain `Color` styles. I did not remove it
because removal is not a restyle, but it is now doubly redundant beside the mono key.

---

## 3. Files in my scope I did NOT touch

**Deliberate — nothing to adopt (5):**

| File | Why |
|---|---|
| `FinishWorkoutSheet.swift` | Contents are a prompt sentence, the RPE display **value** (`pageTitle`), a Slider, a Toggle label and a TextField. All working voice by law; `design-system/components/forms/TextField.jsx` confirms form labels are sans. No marginalia present. |
| `ManualLiftEntrySheet.swift` | Entirely form field labels (`Lift name`, `Target weight`, `Reps`, RPE toggle) + a value readout. Same reason. Field labels are not annotation. |
| `PlanTodaySheet.swift` | A chooser: title + explanatory subtitle rows. Both are sentences the app says. |
| `ShareImportSheet.swift` | A code input field, a submit button, and an error **sentence** in `zoneDanger`. Error copy is speech, never annotation. |
| `WorkoutImportSheet.swift` | Scanned for micro-caps / `smallLabel` / `text3` / unit strings and found none — it is a photo/AI import flow of buttons and status sentences. |

**Unfinished / left behind (honest list):**

1. `TemplatePickerSheet.swift` — off-token spacing literals (`spacing: 8`, `.padding(.horizontal, 16)`,
   `.padding(.top, 16)`) still present. Fence-legal, not tokenised.
2. `ActiveWorkoutSheet.swift` — I covered the four regions listed in §1 out of a 1,718-line file. I
   did **not** audit the rest of it (rest timer, fill buttons, the RPE chip, `SessionStartChooser`,
   the suggestion rationale row, `weightPlaceholder` "kg"/"lb"). In particular the inline
   weight-field unit placeholder is a textbook `ReadoutWell` unit and is a strong annotation
   candidate I did not get to.
3. `ExercisePickerView.swift` — one region of a 968-line file. The filter bar, the region chips, the
   empty/no-results states and the add-custom flow were not audited.
4. `TemplateCarouselSection.swift` — the carousel header/footer region and the pro-gating copy were
   not audited beyond the three edits listed.
5. No chart got the `PointMark` "now" marker or the dashed baseline the reference shows (§2).

---

## 4. Frozen-file requests (I made none of these changes)

**4.1 — highest priority. `AnnotationLabel` needs a `LocalizedStringKey` overload.**
`Components/CardStyle.swift:601` takes only `String`, so every localized call site must resolve via
`String(localized:)`. Two consequences:

- **Churn:** I had to change two helper signatures from `LocalizedStringKey` to `String`
  (`ActiveWorkoutSheet.setHeaderRow`, `ExerciseDetailSheet.metadataRow`) plus 14 call sites.
- **Real behavioural risk, and the reason this is priority 1:** `Text("some.key")` resolves against
  the **view's `@Environment(\.locale)`**, whereas `String(localized:)` resolves against the
  **process/bundle** locale. For strings I moved from the former to the latter, any in-app locale
  override injected through the environment would no longer reach them. Affected keys:
  `workload.section.acwr`, `table.header.*` (both SessionDetailView and ActiveWorkoutSheet),
  `workoutLog.rpe.easy` / `.maximal`, `import.watch.header`, `template.label.shared`,
  `label.shareCode`, `exercise.label.prefilledFromLast`, `exercise.detail.*`, `sport.custom`.
  The pre-existing code already uses `String(localized:)` widely in views (TodayVerdictCard,
  ExercisePickerView), and a launch-arg language override (`-AppleLanguages`, which is how the
  zh-Hans screenshot pipeline works) *does* reach it — so I judged the idiom safe enough to match
  rather than invent something. **But it should be verified in zh-Hans, and the clean fix is the
  overload.** Requested:
  `init(_ key: LocalizedStringKey, size: AnnotationSize = .standard, color: Color = ColorTokens.text3)`.

**4.2 — `Components/LayoutPrimitives.swift` (`MetricCell` / `MetricDeltaLine`), Session D.**
`ui_kits/ios-app/LoadScreen.jsx` renders the metric tile's subtitle as mono uppercase
(`subtitle="ACUTE · 7D"`); ours is `Font.Tokens.micro` sans. The cell **label** ("ATL") is likewise
a machine key. Both should move to `AnnotationLabel`. I could not do it (frozen) and it is the
visible gap on my headline screen: hued chart lines above a sans metric grid.

**4.3 — `Components/ChartTooltipOverlay.swift` (`TooltipBubble`), Session D.**
Its `value` and `dateLabel` are pure marginalia (`ATL: 47 | CTL: 38`, `Jul 3`) and should render via
`AnnotationLabel`. Both my charts present it, so the tooltip is currently the only sans element in
an otherwise mono chart chrome.

**4.4 — `Components/ScreenHeader.swift`, Session D + a HAN content call.**
The reference passes `context="TUE 07.21 · WK 30"` and `meta="D-021"` as mono stamps; DESIGN.md says
"in v6 that context line is the natural home of an annotation stamp". `WorkloadView` and
`WorkoutLogView` call `ScreenHeader(title:)` with no context at all. Two separate decisions: the
component's face (D), and whether to *add* a stamp (new content — HAN).

**4.5 — `Components/TickScale.swift`: a genuine spec conflict, not a request.** See §5-D.

**4.6 — `Components/MetricTile.swift` coordination.** `SessionDetailView` passes
`color: ColorTokens.chartATL` / `chartCTL` into MetricTile. I left those (see §5-A). If D re-points
MetricTile's colour semantics, these two call sites need a joint decision.

**Copy requests (catalog, not code — HAN's call):**

- `verdictCard.fromPlanned` is `↓ from %@` / `↓ 原计划 %@`. `↓` is **not** in the v6 sanctioned glyph
  set — `▼` is. Now that this string renders in Fragment Mono the off-set glyph is more
  conspicuous. Request: `↓` → `▼`, both locales. I did not change copy.
- Several strings are pre-uppercased in the catalog (`TODAY'S PLAN`, `IN TODAY'S ZONE`,
  `RIGHT IN YOUR ZONE`, `SET`/`WEIGHT`/`REPS`, `HISTORY`). `AnnotationLabel` now owns casing, so the
  catalog casing is redundant — and it *defeats the CJK guard's intent* for any locale that supplies
  a pre-cased value. Low priority cleanup: lowercase the catalog values and let the primitive case them.

---

## 5. Unsure / design-system contradictions I hit

I picked DESIGN.md over `design-system/` wherever they disagreed, per DESIGN.md:7 ("this file wins
on iOS enforcement"), and I am flagging each rather than burying it.

**A. The reference hues the metric tiles; DESIGN.md forbids it.**
`LoadScreen.jsx` renders **five** coloured readings on the Load screen: the ACWR hero
(`metric-load`), the zone label (`zone-optimal`), and all three metric tiles
(ATL→`metric-strain`, CTL→`metric-load`, TSB→`metric-sleep`). DESIGN.md rule 4 says "One coloured
text element per screen" and permits metric hues on "hero readings (**by identity**)" — a metric
tile is not a hero reading. **I followed DESIGN.md:** the three `MetricCell` values stay ink, and I
kept the count on my screen at one coloured *text* element (the hero), with the hue-coloured key,
zone label and series-key dots all being marks or explicitly-sanctioned metric-hue annotation.
If HAN wants the reference's look, this is a deliberate rule change, not a lane fix.

**B. The reference uses a metric hue as an area fill, and mis-assigns it.**
`LoadScreen.jsx`: `<path … fill="var(--metric-sleep)" opacity=".14"/>` for the TSB band. That is a
hue as a wash, which DESIGN.md ("never a plane fill … or decorative tint") and my brief ("no
area-fill washes in a metric hue") both forbid — and semantically TSB is not *sleep*. I kept TSB on
`chartTSB`. I think the reference is wrong here, but I am not the one to overrule it.

**C. Reference has one ochre load line; my brief mandates a two-hue split.**
The reference plots a single `metric-load` line. My brief says "acute load/strain → `metricStrain`,
ACWR/chronic load → `metricLoad`". I followed the brief (ATL rust, CTL ochre) because it makes the
two lines distinguishable, which the reference's single line does not have to solve.

**D. The needle: DESIGN.md and the reference flatly contradict each other.**
DESIGN.md TickScale section: "a **1.5px accent needle** (a needle is a live-state mark: accent,
**never** a metric hue)". `LoadScreen.jsx`: `<TickScale value={1.23} … hue="var(--metric-load)"/>`.
`TickScale` is frozen, so I changed nothing — but **whoever resolves this should know the two
sources disagree in the same sentence's worth of meaning**, and my ACWR card's doc comment now
asserts the DESIGN.md reading (needle stays accent) in prose.

**E. Reference annotation renders at 8px, below the system's own smallest token.**
`LoadScreen.jsx` sets chart labels at `fontSize="8"`; the smallest sanctioned iOS token is
`annoSmall` at 10pt, and `annoSizeCap` clamps only the top. I used `.small` (10pt) and placed the
series key *under* the plot rather than inside it — the reference's in-plot corner labels only fit
at 8px. This is a legibility-vs-fidelity trade I made in favour of the token.

**F. Zone-state face is inconsistent inside the design system, and it crosses into D's lane.**
`guidelines/zone-colors.card.html` renders zone badges in **sans** micro-caps (11px, `tracking-caps`,
font-family inherited); `LoadScreen.jsx` renders the hero-adjacent zone label in **mono**. I split
the difference on evidence: the ACWR hero's zone label → mono (matching LoadScreen, which *is* that
exact card), and chip/badge-shaped zone labels → left sans (`TemplateCarouselSection`'s
SUGGESTED / RECOVERY-ADJUSTED capsule). **Session D's `ZoneBadge` decision should be reconciled with
this** — if D moves ZoneBadge to mono, the carousel badge should follow, and that is a one-line
change in my lane.

**Other things I am unsure about, stated as such:**

- Whether the `TodayVerdictCard` **verdict state key** (`ADJUST` / `STEADY` / `MICRODOSE` /
  `LEARNING`) belongs in the annotation voice at all. I moved it, reasoning that it is a one-word
  machine key and the nocebo guard cares about *label-first*, not about which face the label wears.
  The counter-argument is real: DESIGN.md says annotation is never "any string the app *says*", and
  the verdict state is the primary state channel. This is the single edit in my lane I would most
  want a human eye on. Reverting it is a 4-line change.
- Whether tag-shaped strings (muscle group, session type, equipment, category) are marginalia or
  working-voice labels. I treated them as marginalia (`TagChip` exists in the design system's
  `display/` set, and they behave like field-note tags), applied consistently across
  SessionDetailView, ActiveWorkoutSheet, ExercisePickerView, PrescribedWorkoutCard. If that reads
  wrong on device it is wrong in four places at once, which is at least easy to find.
- `RecoveryLoadChart`'s Y axis is the load scale with the recovery series multiplied by
  `scaleFactor`, so the Y annotation labels read as load units and the recovery line has no axis of
  its own. Pre-existing; the mono labels make it slightly more conspicuous that one series is
  unlabelled. Not a v6 issue, but now more visible.

**Process note worth recording for other lanes:** RTK's `grep` rewrite is **lossy** on this repo. A
`grep -n "Tokens.micro" *.swift` in `Views/WorkoutLog/` returned matches in **1 file**; the same
query through `rtk proxy grep` returned matches in **21 files**. I re-ran every survey through
`rtk proxy grep` after catching it. Any lane that scoped its work from a plain `grep` has almost
certainly missed files. (This is the `cat`-is-filtered memory entry generalising to `grep`.)

---

## 6. Verification — exactly what I got, and what I did not finish

**Last completed build, verbatim command and outcome:**

```
cd "/Users/hanwen/dev/Tonus/workload management"
xcodebuild build -scheme "workload management" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -derivedDataPath ~/.tonus-dd-claude-c
→ ** BUILD SUCCEEDED **
```

That was **build checkpoint 5**, run after the last code edit in this entry
(`TextTemplateImportSheet.swift`). So every file listed in §1 is included in a green build. Five
build checkpoints were run in total, after batches of 3, 6, 5, 5 and 1 files respectively — all
`** BUILD SUCCEEDED **`, all in `~/.tonus-dd-claude-c` only, never in-repo `build/`, never a shared
path.

**Test runs — what I actually observed, with the caveat stated:**

```
xcodebuild test -scheme "workload management" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -derivedDataPath ~/.tonus-dd-claude-c -only-testing:WorkloadAppTests
→ ** TEST SUCCEEDED **   (exit 0)
```

I ran this twice. The second run was captured to a log; counting result lines in it gave
**762 `passed on` / 0 `failed on`**, which matches Session A's stated baseline of 762 passed /
0 failed exactly.

**What I did NOT complete — do not read verification into it:**

1. I never confirmed the **2 skips** (the pre-existing `ShadowAnalyticsServiceTests` skips). The
   command that would have counted them is what the watchdog killed.
2. I never ran **`DesignSystemFenceTests` in isolation**, so I cannot claim "fence 17/17". The
   fences were exercised inside the full-suite runs above and nothing failed there, but I did not
   produce the isolated 17/17 figure my brief asked for.
3. The two test runs above overlapped with the other lanes' concurrent simulator runs on this
   machine, which per the orchestrator is exactly the contention that caused the stall. **I would
   not treat my `TEST SUCCEEDED` as authoritative for that reason** — the orchestrator's serial
   re-run is the real gate.
4. **No visual QA at all.** I never installed or launched the app. Specifically unverified on
   device/simulator, and worth a look:
   - Fragment Mono axis labels actually rendering (a missing face falls back **silently**).
   - The `zh-Hans` path end-to-end: the CJK guard on axis labels inside `AxisValueLabel`, and the
     `String(localized:)` locale-resolution risk in §4.1.
   - Set-table column widths at 10pt mono in both locales (I checked the arithmetic, not the pixels).
   - Whether `metricStrain` rust and `metricLoad` ochre are actually separable as two adjacent lines
     on a 160pt-tall chart. On paper they are far apart in hue; on a 160pt plot with overlapping
     lines I do not know.

**Frozen-file boundary:** I edited nothing under `Components/`, nothing in `ColorTokens.swift`,
`FontTokens.swift`, `DesignSystemFenceTests.swift`, `DESIGN.md`, `CLAUDE.md`, `AGENTS.md`, or any
`.pbxproj`, and nothing outside my two directories. I ran no git command that writes.

**Not committed** — orchestrator commits per ground rule 2.
