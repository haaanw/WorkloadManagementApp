# Spec H — rich chart detail views (glance / zoom split)

**Session H, Wave 3, v1.7 "Field Notes". Phase 1 spec, AMENDED for the Phase 2 build.**
Written 2026-07-30T23:56; amended 2026-07-31T01:40 after HAN's ruling and the Round 1
adversarial review. Branch `v1.7-field-notes`.

> ## AMENDMENTS — these override the body of this spec wherever they disagree
>
> **A. The sleep target is 6 h floor + 7.5 h target, APP-WIDE (HAN, 2026-07-31).** §7's
> recommendation (S-1: plot 6 h + 7 h) was heard and **overruled**. Implemented in full, not
> half-way: the glance `SleepTrendChart` rule moved 7 → 7.5 (the freeze is lifted for that
> value only), the three legend keys became `<6h` / `6–7.5h` / `7.5h+` in en + zh-Hans,
> `sleep.chart.annotation` became `7.5h target` / `7.5 小时目标`, `sleep.detail.explanation`
> was rewritten in both locales, and **`RecoveryScoreEngine.sleepDurationToScore`'s 70-point
> knee moved 7 h → 7.5 h**. The number is now declared ONCE, as
> `RecoveryScoreEngine.sleepTargetHours`, and both charts read it. Everything §7.3 and §7.4
> argue is superseded; §7 is retained as the record of what was argued and rejected.
>
> **B. Round 1 review corrections, all applied to this spec and to the build:**
>
> 1. `RecoveryScoreEngine.slope(of:)` **does not exist**. The real function is
>    `static func computeSlope(values:)` (`RecoveryScoreEngine.swift:197`), already public and
>    already called cross-file by `ShadowPredictor` and `FatigueIndexEngine`. §5.3's
>    "six lines recomputed locally is not a duplicated abstraction" allowance is **deleted**;
>    `HRVDetailView.trendToken` calls `computeSlope(values:)`.
> 2. §8's string rule was unsatisfiable for its own key #16. Restated: **the requirement is
>    locale-pinned resolution, not a particular initializer.** `AnnotationLabel(key:)` is the
>    preferred route and cannot carry format arguments, so multi-argument annotation resolves
>    through `String(format: LocalePinnedStrings.localized(…, locale: locale), …)`
>    (`WorkloadApp/Utilities/LocalePinnedStrings.swift:8-12`). A bare `String(localized:)`
>    reads the PROCESS locale and is still banned — that is the actual defect the rule guards.
> 3. The three-swatch key's middle cell **keys nothing the plot draws**, so it ships with
>    **no swatch glyph** — only the range and state words. `ChartKeyCell.swatch` is optional
>    for exactly this reason. Cells 1 and 3 key the two rules that ARE drawn.
> 4. **The 7.5 h rule is `ColorTokens.text3` in BOTH the glance and the detail chart.** Picked
>    text3 because it is what the glance already ships, so the freeze stays a value-only change.
>    The 6 h floor is `zoneDanger` with a finer dash, and is the only zone-coloured rule.
> 5. The About disclosure rows use the compliant **Row** primitive —
>    `.buttonStyle(.rowWell(cornerRadius:))` (`CardStyle.swift:1449-1476`, `Motion.rowWell`) —
>    **not** `.pressable(scale: 1, opacity: 0.6)`. §3.4's "follow the in-repo precedent" reasoning
>    is withdrawn: `WeeklySummaryCard`'s opacity dip is a known deviation and propagating it
>    into new code makes it harder to fix at its source.
> 6. Citation fix: **`LoadTrendChartView` lives in `WorkloadView.swift`**, not in a file of its
>    own. §9's "FROZEN" list already had this right; §7.3's prose did not.
> 7. Both detail views applied `.tracking(0.9)` to their About eyebrow with **no `isLatin`
>    guard** (`HRVDetailView.swift:85`, `SleepDetailView.swift:69` as reviewed) — a zh-Hans
>    violation routed over by lane P. Fixed at the source: the new `SectionEyebrow` primitive
>    guards both tracking and case, and both screens use it.
> 8. `Localizable.xcstrings` was re-read immediately before editing (1017 keys in the working
>    tree vs 1097 at HEAD — 82 orphans removed by another lane, 2 keys added, 3 values changed).
>    All three legend keys were verified present before reuse.
>
> **C. Orchestrator rulings taken as given, not re-argued:** Q3 no haptics while scrubbing ·
> Q4 all ink, no fill · Q5 machine keys stay English in zh-Hans · Q6 new files · Q7 grant
> (Recovery now routes into both detail views) · Q8 all collapsed · Q9 keep the stats band ·
> **crosshair is `ColorTokens.accent`, not a metric hue** (DESIGN.md:185 gives accent exclusive
> territory over active/selected marks), which overrides §4.1/§5.1's mark tables where they
> imply otherwise.
>
> **D. One behaviour dropped from §4.3 deliberately.** "Tap the already-selected day to clear"
> is **not** built. Implementing it needs either a second parameter on `ChartTooltipGesture`
> (the grant was for `clearsOnEnd` only) or a proxy binding that would toggle repeatedly as a
> drag passes over the selected day. Instead the well always reads something: scrubbing to the
> most recent day stamps it `● NOW`, which is the state a "clear" would have returned to.

Design law of record: `DESIGN.md` v6.2 + `design-system/` (`readme.md`, `tokens/`,
`guidelines/`, `ui_kits/ios-app/`). Every element below cites the clause that licenses it.
Where the law does not clearly permit something, it is written as an **open question**, not
assumed.

---

## 0. Executive summary

| | |
|---|---|
| **Glance charts** (`HRVTrendChart`, `SleepTrendChart`, `LoadTrendChartView`) | **ZERO DIFF.** Contractual. They are shared components mounted on Recovery/Load; any edit changes the glance. |
| **Detail charts** | Two NEW components (`SleepDetailChart`, `HRVDetailChart`) mounted only by the two detail views. |
| **New files** | 3 (need `.pbxproj` registration in Phase 2) |
| **Modified files** | 4 (2 detail views, xcstrings, pbxproj) + 1 conditional |
| **New strings** | **16 keys** (en + zh-Hans given below); 3 orphaned keys reused verbatim |
| **7.5 h question** | Recommendation: **do not plot 7.5 h.** Plot 6 h + 7 h; put the 7–9 h sleep-science range in the expandable explanation copy. Full argument + fair alternative in §7. **HAN decides.** |

---

## 1. What exists today (verified against code, not memory)

### 1.1 Mount points

`DashboardView.swift:253-258` is the **only** navigation into either detail view:

```swift
.navigationDestination(for: TrendDestination.self) { dest in
    switch dest {
    case .hrv:   HRVDetailView(data: viewModel.hrv28Days)
    case .sleep: SleepDetailView(snapshots: viewModel.recentSnapshots)
    }
}
```

Reached from Dashboard factor rows via `trendDestination(for:)` (`DashboardView.swift:542`).
**`RecoveryView` shows both glance charts but has no route into either detail view**
(`RecoveryView.swift:62`, `:69`). See open question **Q7**.

**Both initializer signatures stay unchanged** — `HRVDetailView(data: [(date: Date, value:
Double)])` and `SleepDetailView(snapshots: [RecoverySnapshot])`. That is what keeps
`DashboardView.swift` (not H's file) out of this change entirely. Everything specced below is
derivable from those two inputs; nothing new is threaded through the ViewModel.

### 1.2 Current detail views (as shipped on this branch)

Both are the same skeleton: header → hairline → stats band (`surfaceEl`) → hairline → glance
chart → hairline → "About" block (`.Tokens.micro` tracked-caps eyebrow + `.Tokens.label`
body). ~110 lines each. `SleepDetailView` has 2 stat cells, `HRVDetailView` has 3.

Both already comply with v6: `AnnotationLabel` for machine keys, `.annotationReveal(index:)`
choreography, principal reading in its metric hue on a card plane, `Spacing.*` throughout.
**This spec extends that skeleton; it does not replace it.**

### 1.3 The glance charts, and why they are frozen

`HRVTrendChart` and `SleepTrendChart` are each mounted **twice** — once as the glance card on
Recovery (`RecoveryView.swift:62`, `:69`, inside `RuledSection` + `.cardStyle()`) and once
inside the detail view. HAN's direction is "glance charts stay EXACTLY as they are". Therefore:

> **Contract: `WorkloadApp/Components/HRVTrendChart.swift` and
> `WorkloadApp/Components/SleepTrendChart.swift` end Phase 2 with `git diff --quiet`
> returning 0.** The detail charts are new files. Verification command in §11.

This costs some duplication (axis-mark closures are ~14 lines each and will be near-identical
in the detail charts). That is a deliberate trade: the alternative — a `variant:` parameter on
the shared component — puts a branch inside the exact code path HAN asked not to change, and
Wave 2 already produced one regression class (the two-case axis divergence) from editing shared
chart code. Duplication that is *provably inert* on the glance beats a conditional that is not.
See open question **Q6** if HAN prefers the parameterised form.

### 1.4 The three orphaned xcstrings keys — VERIFIED PRESENT

All three still exist in `WorkloadApp/Resources/Localizable.xcstrings`, translated, state
`translated`, en + zh-Hans (the app ships two locales only; `fr` is website-side):

| Key (exact) | en | zh-Hans |
|---|---|---|
| `sleep.chart.legend.poor` | `<6h` | `<6 小时` |
| `sleep.chart.legend.good` | `6–7h` | `6–7 小时` |
| `sleep.chart.legend.excellent` | `7h+` | `7 小时+` |

They are referenced by no Swift file today (deleted from `SleepTrendChart` in Wave 2 by
Session D). **This spec reuses all three verbatim** — no rename, no value change. The key names
(`poor`/`good`/`excellent`) do not match their values (ranges); that mismatch is cosmetic, and
renaming would cost a migration for zero user-visible gain. Left as-is, deliberately.

Note also `sleep.detail.label.sevenDayAvg` is orphaned (the view uses the shared
`detail.label.sevenDayAvg`). Out of scope; flagged only so a future audit does not
re-discover it as new.

### 1.5 The `7D AVG: 51 MS` overlap nit — ALREADY FIXED, no action

`status-orchestrator-wave2.md` lists "the `7D AVG: 51 MS` baseline annotation overlaps the HRV
data dots (pre-existing `RuleMark` annotation placement)" as an unfixed visual nit. **It was
fixed after that file was written**, in commit `3993bd1` ("chart keys out of the plot", v6.1):
`HRVTrendChart.swift:42-48` now renders the baseline key **above the plot** in a `VStack`, and
`SleepTrendChart.swift:48-52` does the same for the 7 h target key. `git log` confirms
`3993bd1` is the tip commit touching both files and the working tree is clean for them.

**Binding consequence for this spec:** the detail charts must not reintroduce in-plot
`.annotation(position:)` on a `RuleMark`. Reference keys go **above** the plot; the dashed rule
alone carries the position. This is DESIGN.md's v6.1 decision-log entry, not a preference.

### 1.6 The scrub gesture that already exists

`WorkloadApp/Components/ChartTooltipOverlay.swift` contains `ChartTooltipGesture` (a
`.chartOverlay` `DragGesture(minimumDistance: 0)` that snaps to the nearest date and writes a
`Binding<Date?>`) and `TooltipBubble`. It is used by `WorkloadView.swift:438` and
`RecoveryLoadChart.swift:84`.

`ChartTooltipGesture` clears the selection on `.onEnded` (`selectedDate = nil`). The detail
view needs the selection to **persist** after the finger lifts. See §4.3 and **Q1**.

### 1.7 The sleep scoring curve — the load-bearing fact for §7

`RecoveryScoreEngine.sleepDurationToScore` (`RecoveryScoreEngine.swift:224-234`), verbatim:

```
<5h  → 10
5–6h → 10…40
6–7h → 40…70     ← 6 h is where the steep segment ends
7–8h → 70…90     ← 7 h is the 70-point knee
8–9h → 90…100
9h+  → 100
```

`sleepDurationToScore` is **`private static`**. Sleep contributes 25% of the composite recovery
score (`sleepWeight = 0.25`).

Three independent artefacts already agree on **6 and 7** as the boundaries and **none**
mentions 7.5:

1. the engine curve above;
2. the shipping explanation copy `sleep.detail.explanation` — *"Sleep below 6 hours
   significantly reduces recovery score. The 7-hour target line is your minimum threshold for a
   green readiness score contribution."* (already translated to zh-Hans);
3. the three orphaned legend keys — `<6h` / `6–7h` / `7h+`.

`grep -rn "7\.5" WorkloadApp` returns nothing sleep-related. **7.5 h appears nowhere in Tuwa.**

`RecoverySnapshot.sleepScore` exists as a model field but is **populated only by
`MockDataSeeder` and by sync pull** — `RecoveryPipeline` never writes it. It is `nil` in
production. Nothing in this spec may read it.

---

## 2. The two-tier model, stated precisely

| | **Glance** (Dashboard / Recovery / Load cards) | **Detail** (pushed screen) |
|---|---|---|
| Job | Is this normal? | Why, and what changed on which day? |
| Furniture | one reference key above the plot, one dashed rule, axes | zone key, two-to-three reference rules, scrub crosshair, persistent readout well, reason tree, expandable explanations |
| Height | 160–184pt | 224pt |
| Interaction | none (the whole card is a nav Row) | Detent-control scrub |
| Annotation register | minimal (axes, one key) | **full** — reason trees `├─ └─`, machine keys, band keys, day stamps |
| Files | frozen | new |

DESIGN.md licence: *Layout* — "Progressive disclosure: score → reasons → trends. The dashboard
is a reading, not a data dump." The detail screen is where the data dump is legal.

---

## 3. Shared detail-screen structure (both screens, top → bottom)

Both detail views keep their existing full-bleed hairline-separated stack (no card gutters —
that is the current grammar and it is correct for a pushed analytical screen). New sections
slot in.

```
┌ context stamp        ANNOTATION  28D · JUL 03 – JUL 30            (NEW)
│ page title           .Tokens.pageTitle, sentence case             (exists)
│ subtitle             .Tokens.label, text2                         (exists)
├───────────────────────────────────────────── 0.5pt divider
│ stats band           2–3 cells on surfaceEl                       (exists, unchanged)
├───────────────────────────────────────────── 0.5pt divider
│ zone key row         ▒ <6H · DEFICIT   ▒ 6–7H · MARGINAL  …   (NEW, sleep only)
│ reference key        7D BASELINE 51 MS · ±1SD 46–56           (NEW, HRV; sleep: 7H TARGET)
│ DETAIL CHART         224pt, scrubbable                            (NEW)
│ readout well         debossed, fixed-width, always present        (NEW)
├───────────────────────────────────────────── 0.5pt divider
│ condition section    section head + reason tree ├─ └─             (NEW)
├───────────────────────────────────────────── 0.5pt divider
│ About                3 disclosure rows                            (extends existing)
└
```

### 3.1 Context stamp (NEW, both screens)

DESIGN.md *Layout*: "Screen top: context line above a 28pt sentence-case page title. In v6 that
context line is the natural home of an **annotation** stamp." The detail screens have no
context line today.

```swift
AnnotationLabel(windowStamp, size: .small)      // 11pt Fragment Mono, text3
    .annotationReveal()
```

`windowStamp` = `"28D · " + first.formatted(.dateTime.month(.abbreviated).day().locale(locale))
+ " – " + last.formatted(…)` → renders `28D · JUL 03 – JUL 30`.

**No new localizable string**: `28D` is a machine token (same register as `ATL`/`ACWR`, which
`LoadTrendChartView` — which lives in `WorkloadView.swift:457-459`, not in a file of its own
(amendment B6) — already prints untranslated), and the dates are formatted
through `.locale(locale)` so zh-Hans renders `7月3日 – 7月30日` with no case transform
(`AnnotationLabel` applies `isLatin` guards). Placed **above** the title, `Spacing.baselinePair`
gap, inside the existing header `VStack` (change its `spacing:` from `Spacing.xs` to `0` and
apply explicit gaps, all grid-legal).

Law: annotation = timestamps/cycle position (DESIGN.md §Annotation Layer); `text3` on the base
plane is the annotation default (rule 7, ≥3:1 met — this is a `bg` plane, and `text3` on `bg`
is the existing micro-label case already used app-wide).

### 3.2 The readout well (NEW, both screens) — Primitive 3

**Five-Primitive Law, primitive 3 "Detent control (discrete values) — mechanical snap, ~100ms
digit-roll, fixed-width readout wells, reduced haptics."** A day-by-day chart scrub is a
discrete detent traverse, so the readout is a well and the digit change rides `Motion.digitRoll`.

```swift
HStack(alignment: .lastTextBaseline, spacing: Spacing.xs) {
    AnnotationLabel(dayStamp, size: .small, color: ColorTokens.text2)   // "SUN 07.27" or "● NOW"
    Spacer(minLength: 0)
    Text(valueString).font(.Tokens.body).monospacedDigit()
        .foregroundStyle(ColorTokens.text1)
    AnnotationLabel(deltaString, size: .small, color: ColorTokens.text2) // "▲ +13.7% VS BASE"
}
.padding(.horizontal, Spacing.sm)
.padding(.vertical, Spacing.xs)
.debossed(cornerRadius: CornerTokens.control)
.animation(Motion.resolved(Motion.digitRoll, reduceMotion: reduceMotion), value: selectedDate)
```

**Binding details:**

- **Always present.** With no selection it reads the most recent day, stamped `● NOW` (the
  filled state dot is a sanctioned glyph; DESIGN.md glyph table `● ○ = state dots`). During and
  after a scrub it reads the selected day. It never appears/disappears — DESIGN.md relief law:
  "digits change, the stone never resizes."
- **Fixed width.** Value strings are zero-padded to a constant glyph count: sleep `"%dh %02dm"`
  (`7h 42m`), HRV `"%d ms"` with `.monospacedDigit()` on the working-voice `Text` and tabular
  figures inherent to `AnnotationLabel`.
- **Colour, and why nothing here is hued:** the well is `wellTop→wellBottom`, **not a card
  plane**. DESIGN.md rule 7: metric-hue/zone text below 24pt lives on **card planes only**, and
  `text3` annotation must never sit on a well (2.84:1). So the well's reading is `text1` ink and
  its annotation is `text2` (7.04:1 class). **The hue lives on the key above the plot and on the
  series itself, never inside the well.** Promoting the reading to ≥32pt to make a hue legal
  would create a second hero on a screen that already has a stats band — rejected (Hero Law).
- **No haptic.** DESIGN.md: "Detent haptics stay Home-hero-only", and Haptics is "commit-only +
  limit/toggle detents + Home hero count-up detents. Never decorative." A per-day scrub tick
  would be decorative. **Open question Q3** if HAN wants `Haptics.select()` at the two zone
  boundary crossings only.
- **No `TooltipBubble`.** The floating bubble is the Load-screen grammar for a transient drag.
  The detail screens use a persistent well instead, which is the primitive the law names.

### 3.3 The reason-tree section (NEW, both screens)

DESIGN.md *Annotation Layer*: reason trees (`├─ HRV AT BASELINE` / `└─ LOAD_HEADROOM: 0.23`)
and machine keys (`HRV_BASELINE: TRUE`) are exactly what annotation is for. This is the section
where "the annotation voice earns its keep".

Structure:

```swift
VStack(alignment: .leading, spacing: Spacing.xs) {
    Text("<section head key>")              // working voice — a head the app SAYS
        .font(.Tokens.micro).tracking(0.9)
        .foregroundStyle(ColorTokens.text3)
    VStack(alignment: .leading, spacing: Spacing.baselinePair) {
        ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
            AnnotationLabel(row, size: .standard, color: ColorTokens.text2)
                .annotationReveal(index: i)
        }
    }
}
.padding(.horizontal, Spacing.sm).padding(.vertical, Spacing.sm)
.background(ColorTokens.surfaceEl)      // CARD PLANE — required, see below
```

- The section head is **working voice** (`.Tokens.micro` tracked caps, the existing
  `sleep.detail.section.about` pattern) because a head is something the app *says*. The tree
  rows are annotation. That split is DESIGN.md rule 9 and the existing views already honour it.
- Rows are `text2`, not `text3`: rule 7 — "annotation that carries information the athlete must
  not miss uses `text2`". A reason tree is the reasoning; it is not marginalia-about-marginalia.
- The tree renders **contiguously in one `VStack`** with no interleaved headings. The Wave-2
  report flags that Home's `├─`/`└─` stems are separated by working-voice headings and so read
  as two fragments. This spec avoids that failure by construction: one unbroken stem per tree.
- The whole block sits on `surfaceEl` so any hued token inside it would be legal — though as
  specced, nothing in the tree is hued (**Q4**).
- Stagger index runs top-to-bottom so the tree draws itself downward — the choreography
  primitive's documented intent.

**Machine keys stay untranslated in both locales.** `SLEEP_DEBT_7D`, `NIGHTS_BELOW_6H`,
`HRV_BASELINE`, `CV_7D`, `TREND_7D` are machine identifiers in the register DESIGN.md
sanctions (`LOAD_HEADROOM: 0.23`), and the in-repo precedent is `LoadTrendChartView`'s
`ATL`/`CTL`/`TSB` key, whose comment states: "the same untranslated scientific abbreviations the
metric grid above already prints verbatim, so this adds no new localizable copy." The *values*
are numbers and are locale-formatted. The `TRUE`/`FALSE` and `RISING`/`FALLING`/`FLAT` tokens
are also machine literals — deliberately untranslated. **Q5** records this for HAN, because it
is the single most debatable i18n call in the spec.

### 3.4 The About section — expandable (NEW behaviour, existing copy preserved)

Replaces the single static explanation block with **three disclosure rows**. Each row:

```swift
Button {
    Haptics.tap()
    withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
        expanded[i].toggle()
    }
} label: {
    HStack {
        Text(titleKey).font(.Tokens.label).foregroundStyle(ColorTokens.text1)
        Spacer()
        Image(systemName: "chevron.down").font(.Tokens.micro)
            .foregroundStyle(ColorTokens.text3)
            .rotationEffect(.degrees(expanded[i] ? 0 : -180))
    }
    .padding(.horizontal, Spacing.sm).padding(.vertical, Spacing.sm)
}
.buttonStyle(.rowWell(cornerRadius: CornerTokens.control))   // amendment B5
if expanded[i] {
    Text(bodyKey).font(.Tokens.label).foregroundStyle(ColorTokens.text2)
        .padding(.horizontal, Spacing.sm).padding(.bottom, Spacing.sm)
}
```

Five-Primitive classification: **primitive 2, Row** (no scale, discloses rather than commits),
so it takes the canonical Row carrier — `RowWellButtonStyle` (`CardStyle.swift:1449-1476`): a
`text1`@6% background well on `Motion.rowWell`, no scale. The Phase 1 draft copied
`WeeklySummaryCard`'s opacity-dip grammar on the argument that following an in-repo precedent
beats inventing a third one. **Withdrawn (amendment B5):** that precedent is a known deviation
from the Five-Primitive Law, and new code that repeats it makes the deviation harder to fix
where it belongs. The gesture, haptic, `Motion.state` and `chevron.down` rotation are unchanged
from that precedent — only the press carrier differs.

- All three rows **collapsed by default**, not persisted (`@State private var expanded: [Bool]`,
  no `@AppStorage`). Progressive disclosure: the chart and the tree answer the question; the
  prose is for the curious. **Q8** if HAN wants the first row open by default.
- Bodies are **working voice**, `.Tokens.label`, `text2`, sentence case. Never annotation
  (DESIGN.md rule 9: annotation is never a sentence).
- The existing `sleep.detail.explanation` / `hrv.detail.explanation` strings are **reused
  verbatim** as the body of row 1 — no re-translation, no content churn on already-shipped copy.
- The existing `sleep.detail.section.about` / `hrv.detail.section.about` keys stay as the
  section eyebrow above the three rows.

### 3.5 Motion budget for the whole screen

| Moment | Token | Notes |
|---|---|---|
| Screen entrance | existing `.entranceReveal()` on the chart | unchanged |
| Annotation arrival | `.annotationReveal(index:)` | 340ms settle + 40ms steps, capped at 8 |
| Scrub readout digits | `Motion.digitRoll` (0.12) | primitive 3's "~100ms digit-roll" |
| Selection rule appear/move | `Motion.state` (0.22) | |
| Disclosure expand | `Motion.state` (0.22) | matches `WeeklySummaryCard` |

No hand-typed curve anywhere; `test_animationCurveLiterals_onlyInCardStyle` bans `.animation(.`
and `.spring(` outside `CardStyle.swift`, and `test_noBareWithAnimation` bans bare
`withAnimation {`. Every call above passes `Motion.resolved(_:reduceMotion:)`.

---

## 4. `SleepDetailChart` — full spec

**New file: `WorkloadApp/Components/SleepDetailChart.swift`**

```swift
struct SleepDetailChart: View {
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let recoverySnapshots: [RecoverySnapshot]
    @Binding var selectedDate: Date?
}
```

### 4.1 Marks

| Mark | Spec | Law |
|---|---|---|
| Bars | `BarMark(x: .value(_, date, unit: .day), y: .value(_, hours))`, `.foregroundStyle(ColorTokens.metricSleep)` — **uniform indigo, exactly as the glance** | "Each metric owns a hue" (DESIGN.md §Metric identities). Duration-coded bar colour is explicitly **rejected** — see §7.4 |
| 7 h target rule | `RuleMark(y: 7)`, `ColorTokens.zoneOptimal`, `lineWidth: 1`, `dash: [5, 3]` | Marks are unrestricted at the 3:1 graphical floor (contrast rule 3). Dashed baselines are the chart grammar (`guidelines/charts.card.html`) |
| 6 h deficit rule | `RuleMark(y: 6)`, `ColorTokens.zoneDanger`, `lineWidth: 1`, `dash: [2, 4]` (finer dash = subordinate) | same |
| Selection rule | `RuleMark(x: .value(_, selectedDate, unit: .day))`, `ColorTokens.accent`, `lineWidth: 1.5` | **Reading Color Rule:** "`--accent` may colour live-state marks — progress fills, **active/selected marks**…". A selection is live state, so it is travertine and **not** a metric hue |
| Grid | `AxisGridLine().foregroundStyle(ColorTokens.chartGrid)` | v6 chart token |
| Height | `.frame(height: 224)` | 8×28 |

**No `.annotation()` on any `RuleMark`.** §1.5.

### 4.2 Keys above the plot

Rendered in a `VStack(alignment: .leading, spacing: Spacing.xs)` above the `Chart`, exactly the
structure `SleepTrendChart.swift:43-53` uses today.

**Row A — the zone key (the restored three-swatch legend).** Three cells, `HStack(spacing:
Spacing.sm)` + trailing `Spacer(minLength: 0)`:

```
▒ <6H · DEFICIT        6–7.5H · MARGINAL      ▒ 7.5H+ · SUFFICIENT
```

**The middle cell carries NO swatch (amendment B3).** The plot draws two rules and no fills, so
a swatch on the middle cell would key a mark that does not exist — the exact defect this spec
cites in Wave 2's `LoadTrendChartView` (a series key for a series never drawn). `swatch` is
therefore `Color?` on `ChartKeyCell`. Cell 1's swatch is `zoneDanger` (the 6 h floor rule) and
cell 3's is `text3` (the 7.5 h target rule) — each is the literal colour of the mark it keys.

Per cell:

```swift
HStack(spacing: Spacing.baselinePair) {
    AnnotationLabel("\u{2592}", size: .small, color: zoneColor)   // ▒
        .accessibilityHidden(true)
    AnnotationLabel(key: rangeKey, size: .small)                  // text3
    AnnotationLabel("\u{00B7}", size: .small)                     // ·
    AnnotationLabel(key: stateKey, size: .small)                  // text3
}
.annotationReveal(index: i)
```

- The **swatch glyph carries the colour; the text stays `text3`**. This is the
  `LoadTrendChartView.seriesKey` precedent verbatim (`WorkloadView.swift:467-474`: hue on the
  dot, `text3` on the label) and it means the legend needs no card-plane contrast exemption for
  coloured text.
- `▒` and `·` are both in DESIGN.md's sanctioned glyph table (`░ ▒` fills/sufficiency, `·`
  separator). No icon font, no emoji.
- **Zone Color Rule satisfied:** the state is named in words (`DEFICIT` / `MARGINAL` /
  `SUFFICIENT`), the colour is supplementary, and the swatch colours key the two coloured rules
  actually drawn on the plot. Never colour alone.
- Cells wrap in a `ViewThatFits`-free simple `HStack`; if zh-Hans overflows at the narrowest
  device the row falls back to two lines. **Must be checked on the zh simulator in Phase 2** —
  listed in §11.
- `zoneColor`: `ColorTokens.zoneDanger` / `.zoneCaution` / `.zoneOptimal`.

**Row B — the target key.** `AnnotationLabel(key: "sleep.chart.annotation", size: .small)`
(`7h target` / `7 小时目标`) — reused verbatim from the glance so the two screens say the same
thing about the same rule.

### 4.3 Scrub

`.chartOverlay { proxy in … }` hosting a drag that snaps to the nearest day and **persists**.

Behaviour:

| Event | Result |
|---|---|
| Drag/press anywhere in the plot | `selectedDate` = nearest day; selection rule + readout update on `Motion.state`/`Motion.digitRoll` |
| Finger lifts | selection **stays** |
| Tap on the already-selected day | clears to `nil` → readout returns to `● NOW` |
| Leaving the screen | state is local `@State`, discarded |

Implementation, **recommended**: add one defaulted parameter to the existing gesture rather
than clone it —

```swift
// ChartTooltipOverlay.swift
struct ChartTooltipGesture: View {
    …
    var clearsOnEnd: Bool = true          // NEW, default preserves both existing call sites
    …
    .onEnded { _ in if clearsOnEnd { selectedDate = nil } }
}
```

`ChartTooltipOverlay.swift` is **not** in H's Wave-3 file list (H's list enumerates
`HRVTrendChart`, `SleepTrendChart`, `LoadTrendChartView`). This is therefore a **written
request**, not an action — see §10 / **Q1**. Fallback if the grant is refused: a
`DayScrubGesture` in the new `ChartDetailPrimitives.swift`, ~14 duplicated lines.

### 4.4 Axes

Identical grammar to the glance (`AxisValueLabel` hosting `AnnotationLabel` so the
uppercase/tracking/zh guard comes from the modifier, per DESIGN.md rule 3 and the Wave-2 defect
#3/#4 fix). Y-axis label `hours` via `.chartYAxisLabel`. `.id(locale)` for live language switch.

### 4.5 Reason tree — "Sleep condition"

Head: new key `sleep.detail.section.condition`. Rows, in order:

```
├─ LAST NIGHT: 7H 42M
├─ 7D AVG: 6H 51M
├─ SLEEP_DEBT_7D: 4.2H
├─ NIGHTS_BELOW_6H: 2 / 7
└─ SCORE_CONTRIB: 74 / 100          ← conditional, see below
```

All derivable from `snapshots` alone except the last:

- `SLEEP_DEBT_7D` = `Σ over last 7 nights of max(0, 7h − actual)`, in hours, 1 decimal. The 7 h
  reference is the same target the plot draws — one number, one meaning, everywhere.
- `NIGHTS_BELOW_6H` = count of the last 7 nights under 6 h, over the number of nights with data
  (so a 5-night week reads `1 / 5`, never a silent lie).
- `SCORE_CONTRIB` needs `RecoveryScoreEngine.sleepDurationToScore`, which is **`private
  static`**. Options: (a) request a one-word visibility change in `Services/` — outside H's
  ownership, filed as a request; (b) **drop the row**. **Duplicating the curve in a view is
  explicitly rejected** — two copies of a scoring function drift, and the view would silently
  disagree with the engine after any tuning. Recommended: (a), and if declined, (b). **Q2.**
- Rows are suppressed individually when their input is missing (no `—` placeholders inside a
  tree — a tree with holes is worse than a shorter tree); the `└─` stem is applied to whichever
  row ends up last.

### 4.6 About rows (sleep)

| # | Title key | Body key | Body source |
|---|---|---|---|
| 1 | `sleep.detail.about.scoring.title` (NEW) | `sleep.detail.explanation` (EXISTS) | reused verbatim |
| 2 | `sleep.detail.about.sixHour.title` (NEW) | `sleep.detail.about.sixHour.body` (NEW) | new copy |
| 3 | `sleep.detail.about.target.title` (NEW) | `sleep.detail.about.target.body` (NEW) | new copy — **this is where the 7–9 h sleep-science range is stated in prose**, per §7 |

---

## 5. `HRVDetailChart` — full spec

**New file: `WorkloadApp/Components/HRVDetailChart.swift`**

```swift
struct HRVDetailChart: View {
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let data: [(date: Date, value: Double)]
    @Binding var selectedDate: Date?
}
```

### 5.1 The baseline band — as bounds, NOT a fill

| Mark | Spec | Law |
|---|---|---|
| Series | `LineMark`, `ColorTokens.metricRecovery` (teal), `lineWidth: 1.5`, `.symbol(Circle())`, `.symbolSize(20)` | HRV owns teal; 1.5pt ink lines are the chart grammar |
| Baseline | `RuleMark(y: baseline7d)`, `ColorTokens.text3`, `1pt`, `dash: [5, 3]` | unchanged from glance |
| Band bounds | **two** `RuleMark`s at `baseline ± 1 SD`, `ColorTokens.text3`, `0.5pt`, `dash: [2, 4]` | hairline 0.5pt; marks unrestricted |
| Band interior | **UNFILLED** | An `AreaMark` in a metric hue is a hue-as-surface wash. DESIGN.md: metric hues "may NEVER be used as plane fills… decorative tints", and the Wave-2 orchestrator explicitly rejected exactly this (kit's `metric-sleep` @14% TSB wash) as forbidden. A `chartHRV`-tinted fill would be *technically* identity-less and therefore arguably legal — **that is open question Q4**, and this spec's default is no fill |
| Selection rule | `RuleMark(x:)`, `ColorTokens.accent`, `1.5pt` | active/selected = accent |
| Crosshair | `PointMark` at the selected datum, **open circle**: `.foregroundStyle(ColorTokens.surfaceEl)` + `.symbol(Circle())` stroked `metricRecovery` | "crosshair markers are open circles (`○`)" — `guidelines/charts.card.html`, `readme.md` §Charts. The circle identifies the *series datum*, so it takes the series hue; the *selection* state is carried by the accent rule. Both laws served, neither violated |
| Height | 224pt | 8×28 |

### 5.2 Key above the plot

`7D BASELINE: 51 MS · ±1SD 46–56` — one `AnnotationLabel(size: .small)`, `text3`,
`.annotationReveal()`. Extends the existing `hrv.chart.annotation` format rather than replacing
it; needs one new key because the format string gains a second clause (§8).

### 5.3 Reason tree — "HRV condition"

Head: new key `hrv.detail.section.condition`. Rows:

```
├─ LATEST: 58 MS
├─ BASELINE_7D: 51 MS
├─ DEVIATION: ▲ +13.7%
├─ HRV_BASELINE: TRUE
├─ CV_7D: 8.4%
└─ TREND_7D: ▲ RISING
```

- `HRV_BASELINE: TRUE` when the latest reading is **at or above** the 7-day baseline — the exact
  machine key DESIGN.md prints as its own example (`HRV_BASELINE: TRUE`). This makes the app's
  own documented specimen real rather than illustrative.
- `CV_7D` = coefficient of variation over the last 7 readings (`SD / mean`, as %). This is the
  stability read — the thing a rising-but-erratic HRV hides. Pure local computation.
- `TREND_7D` = sign of the least-squares slope over the last 7 readings, bucketed
  `RISING` / `FALLING` / `FLAT` (`|slope| < 0.5 ms/day` → `FLAT`), computed by
  **`RecoveryScoreEngine.computeSlope(values:)`** (`RecoveryScoreEngine.swift:197`). It is
  already non-private and already called cross-file by `ShadowPredictor.swift` and
  `FatigueIndexEngine.swift`, so there is nothing to request and nothing to recompute. (The
  Phase 1 draft cited a `slope(of:)` that does not exist and used it to license six duplicated
  lines; both the citation and the allowance are withdrawn — amendment B1.)
- Delta glyphs: `▲` when the deviation exceeds +5%, `▼` below −5%, `=` between — DESIGN.md glyph
  table, "filled = significant, outline = mild, = flat" (`guidelines/glyphs.card.html`). Colour:
  `text2`, **not** a zone colour — an HRV reading below baseline is not a diagnosis, and the
  nocebo guard makes colouring it red an active harm. **Q4** records the alternative.

### 5.4 About rows (HRV)

| # | Title key | Body key | Body source |
|---|---|---|---|
| 1 | `hrv.detail.about.measures.title` (NEW) | `hrv.detail.explanation` (EXISTS) | reused verbatim |
| 2 | `hrv.detail.about.deviation.title` (NEW) | `hrv.detail.about.deviation.body` (NEW) | new copy |
| 3 | `hrv.detail.about.baseline.title` (NEW) | `hrv.detail.about.baseline.body` (NEW) | new copy |

---

## 6. What each detail VIEW changes

### `WorkloadApp/Views/Dashboard/SleepDetailView.swift`

- `@State private var selectedDate: Date?` added.
- Header gains the context stamp (§3.1).
- `SleepTrendChart(recoverySnapshots:)` → `SleepDetailChart(recoverySnapshots:selectedDate:)`.
- Readout well added under the chart.
- "Sleep condition" reason-tree section added.
- About block becomes three disclosure rows.
- Stats band unchanged (2 cells, `lastNight` in `metricSleep` on the `surfaceEl` card plane —
  already legal at 6.03:1).

### `WorkloadApp/Views/Dashboard/HRVDetailView.swift`

Same six changes; `HRVTrendChart(data:)` → `HRVDetailChart(data:selectedDate:)`; stats band
unchanged (3 cells).

**Neither initializer signature changes**, so `DashboardView.swift` is untouched.

---

## 7. The 6 h / 7 h / 7.5 h reconciliation — PROPOSAL, HAN DECIDES

### 7.1 The question as posed

The glance chart draws a **7 h target**. HAN's Wave-3 direction asks the detail view for "the
6 h boundary and the **7.5 h recommended baseline**", and asks me to reconcile the two. The
proposed frame in `DISTRIBUTION.md` is: *target = athlete-facing goal line; bands = physiology.*

### 7.2 What I found that bears on it

§1.7, restated because it is decisive: **Tuwa's own sleep physiology is a 6/7/8/9 curve.** 7 h
is the 70-point knee; 6 h ends the steep segment; 8 h is 90. The shipping explanation string —
already translated and on the App Store — names 6 and 7 explicitly. The three orphaned legend
keys name 6 and 7. **7.5 h exists nowhere in the product.**

So the frame "target = goal, bands = physiology" does not actually produce a conflict here,
because **the target and the physiology knee are the same number**. There is no divergence to
reconcile; there is a *missing* boundary (6 h) that the detail view should add.

### 7.3 RECOMMENDATION — **S-1 + S-3**

**S-1 (plot):** the detail chart draws **two** rules, 6 h and 7 h, and the three-cell zone key
partitions the plot into `<6H DEFICIT` / `6–7H MARGINAL` / `7H+ SUFFICIENT`. The three orphaned
xcstrings keys are reused **verbatim** — zero translation work, zero drift from the shipping
explanation copy. **No 7.5 h rule.**

**S-3 (copy):** the 7–9 h adult sleep-science recommendation goes in About row 3
(`sleep.detail.about.target.body`), in the working voice, where it can be *explained* rather
than asserted as a line the athlete is failing.

Why: plotting 7.5 h would put a number on the chart that the engine never computes with. An
athlete sleeping 7.2 h would see a bar below the "recommended" line while the app's own score
tells them they are green — the app contradicting itself in two adjacent glyphs. That is worse
than an omission, and it is precisely the class of defect (a key advertising something the plot
does not do) that Wave 2 caught in `LoadTrendChartView`. It is also a nocebo problem: a
permanent line most users sit under is exactly the pressure DESIGN.md's nocebo guard exists to
prevent.

**HAN ruled S-2 (2026-07-31) — this recommendation was rejected.** The costs listed under S-2
below were accepted and paid rather than avoided: both legend keys and the shipped
`sleep.detail.explanation` were rewritten in en + zh-Hans, and the engine knee moved with the
line so the app cannot contradict itself. See amendment A. §7.3 is retained as the record of
what was proposed, not as an instruction.

### 7.4 The alternatives, stated fairly

**S-2 — plot 7.5 h as HAN's brief literally asks.** Add a third rule at 7.5 h keyed
`RECOMMENDED`, keep 7 h as the goal line, keep 6 h as the floor.
*Honest case for it:* 7.5 h is well grounded outside Tuwa — the AASM/Sleep Research Society
adult recommendation is ≥7 h with 7–9 h typical, and 7.5 h is five 90-minute cycles, which is
the number most athletes have actually heard. If Tuwa's curve is too lenient, showing the
external standard is the honest move and the *engine* is what should change.
*Costs, stated plainly:* (a) three horizontal rules plus 28 bars in 224pt is dense furniture;
(b) the legend keys must be rewritten — `6–7h`→`6–7.5h`, `7h+`→`7.5h+` — in en **and** zh-Hans,
which forfeits the "reuse the orphaned keys verbatim" win; (c) `sleep.detail.explanation`, a
shipped translated string, would then be wrong and would need rewriting too; (d) the app scores
7.2 h as green while the chart marks it short.
*If HAN picks S-2, my recommendation is to also change the engine knee* — but that is a
Services change and an algorithm change, out of scope for a design wave, and I would schedule
it rather than smuggle it into v1.7.

**S-4 — plot the athlete's own 7-day average as the second rule instead of any fixed number.**
Personal, never wrong, matches the HRV screen's baseline grammar.
*Cost:* it answers "am I consistent?" rather than "am I getting enough?", and a 5-hour sleeper's
baseline would validate a 5-hour night. Rejected for sleep (unlike HRV, sleep has an absolute
external standard), but recorded because it is the most defensible personalised option.

### 7.5 Why the bars stay one colour

An obvious way to "restore the three-swatch legend" is to colour each bar by its band. **This
spec rejects it.** v6's whole thesis is one hue per metric — sleep is indigo. Band-coloured bars
would make the same series speak two colour languages on adjacent screens (indigo on Recovery,
traffic-light in the detail), which is exactly the inconsistency the Wave-2 orchestrator fixed
for axis case. The bands are carried by rules and a key, and the bars stay indigo.

---

## 8. Strings — complete table

`Localizable.xcstrings` v1.0, `sourceLanguage: en`, locales **en + zh-Hans only** (1017 keys
today). Every new key needs both.

### 8.1 Reused verbatim — NO CHANGE (7)

| Key | Where used |
|---|---|
| `sleep.chart.legend.poor` | zone key cell 1 range |
| `sleep.chart.legend.good` | zone key cell 2 range |
| `sleep.chart.legend.excellent` | zone key cell 3 range |
| `sleep.chart.annotation` | target key above the sleep plot |
| `sleep.detail.explanation` | About row 1 body (sleep) |
| `hrv.detail.explanation` | About row 1 body (HRV) |
| `sleep.detail.section.about` / `hrv.detail.section.about` | About section eyebrow |

### 8.2 NEW keys (16)

Values are authored in **natural case**; `AnnotationLabel` applies the uppercase transform for
Latin locales and suppresses it for zh (`isLatin`). Working-voice strings are sentence case per
DESIGN.md.

| # | Key | en | zh-Hans | Voice |
|---|---|---|---|---|
| 1 | `sleep.detail.legend.state.deficit` | `Deficit` | `不足` | annotation |
| 2 | `sleep.detail.legend.state.marginal` | `Marginal` | `勉强` | annotation |
| 3 | `sleep.detail.legend.state.sufficient` | `Sufficient` | `充足` | annotation |
| 4 | `sleep.detail.section.condition` | `Sleep condition` | `睡眠状况` | working (section head) |
| 5 | `sleep.detail.about.scoring.title` | `How sleep affects your score` | `睡眠如何影响你的评分` | working |
| 6 | `sleep.detail.about.sixHour.title` | `What the 6-hour line means` | `6 小时线的含义` | working |
| 7 | `sleep.detail.about.sixHour.body` | `Below 6 hours, sleep pulls your recovery score down steeply — each lost hour costs about three times what it costs between 7 and 8 hours. One short night is recoverable; three in a week is a pattern worth acting on.` | `低于 6 小时，睡眠会显著拉低你的恢复评分——每少睡一小时的代价约是 7 至 8 小时区间的三倍。偶尔一晚睡眠不足可以补回；一周内出现三次则是值得处理的模式。` | working |
| 8 | `sleep.detail.about.target.title` | `Why 7 hours is the target` | `为什么目标是 7 小时` | working |
| 9 | `sleep.detail.about.target.body` | `Seven hours is where sleep stops holding your readiness back. Sleep research generally recommends 7 to 9 hours for adults, and more is better if you can get it — but 7 is the line Tuwa scores against, so that is the line the chart draws.` | `7 小时是睡眠不再拖累你准备度的临界点。睡眠研究普遍建议成年人睡 7 至 9 小时，能睡更久更好——但 7 小时是 Tuwa 评分所依据的标准，所以图表画的是这条线。` | working |
| 10 | `hrv.detail.section.condition` | `HRV condition` | `心率变异性状况` | working (section head) |
| 11 | `hrv.detail.about.measures.title` | `What HRV measures` | `心率变异性测量什么` | working |
| 12 | `hrv.detail.about.deviation.title` | `What a deviation means` | `偏离基线意味着什么` | working |
| 13 | `hrv.detail.about.deviation.body` | `A single reading below baseline is usually noise — alcohol, a late meal, a bad night. Two or three in a row alongside a raised resting heart rate is the pattern that means fatigue, and that is what your readiness score is already weighing.` | `单次低于基线的读数通常只是噪声——饮酒、晚餐过晚、睡得不好。连续两三次并伴随静息心率升高，才是提示疲劳的模式，而这正是你的准备度评分已经在权衡的内容。` | working |
| 14 | `hrv.detail.about.baseline.title` | `Why your baseline is personal` | `为什么基线因人而异` | working |
| 15 | `hrv.detail.about.baseline.body` | `Absolute HRV varies enormously between people — 30 ms can be excellent for one athlete and poor for another. Tuwa compares you only against your own rolling 7-day average, so the number that matters is the deviation, not the reading.` | `不同人的心率变异性绝对值差异极大——30 ms 对一位运动员可能很好，对另一位则偏低。Tuwa 只将你与自己 7 天滚动平均值比较，所以真正重要的是偏离幅度，而不是读数本身。` | working |
| 16 | `hrv.chart.annotation.band` | `7d avg: %1$d ms · ±1SD %2$d–%3$d` | `7 天平均：%1$d ms · ±1SD %2$d–%3$d` | annotation |

Sixteen rows, sixteen distinct new keys. Build against all sixteen.

**Positional format specifiers (`%1$d`) are required** in key 16 because zh-Hans may reorder;
`hrv.chart.annotation` today uses a bare `%d` and is left alone.

**Untranslated machine literals** (no keys, identical in both locales, per §3.3):
`28D`, `SLEEP_DEBT_7D`, `NIGHTS_BELOW_6H`, `SCORE_CONTRIB`, `LATEST`, `BASELINE_7D`,
`DEVIATION`, `HRV_BASELINE`, `TRUE`, `FALSE`, `CV_7D`, `TREND_7D`, `RISING`, `FALLING`, `FLAT`,
`NOW`, `VS BASE`, `MS`, `H`. **Q5.**

**All new annotation strings must be resolved AGAINST THE APP'S PINNED LOCALE.** The defect
this guards is the Wave-2 zh-Hans live-switching regression (`status-orchestrator-wave2.md`
defect #1): `String(localized:)` reads the **process** locale, so a string flattened at the
call site keeps the launch language through an in-app language switch. Two compliant routes,
and only two:

- `AnnotationLabel(key:)` — preferred, and required whenever the string takes no arguments.
- `String(format: LocalePinnedStrings.localized("key", locale: locale), …)` — required when
  the string takes arguments, because `AnnotationLabel(key:)` takes a `LocalizedStringKey`
  and cannot carry them. Key #16 is a three-argument format string, so the Phase 1 rule as
  written was unsatisfiable by its own table (amendment B2). `LocalePinnedStrings` is at
  `WorkloadApp/Utilities/LocalePinnedStrings.swift:8-12` and is the existing precedent —
  `SleepTrendChart.swift:49` already uses it.

Bare `AnnotationLabel(String(localized: …))` remains banned. Working-voice strings use
`Text("key")`, which observes the pinned locale through the environment.

---

## 9. File list

### NEW — require `.pbxproj` registration in Phase 2 (3)

| Path | Contents |
|---|---|
| `WorkloadApp/Components/SleepDetailChart.swift` | §4 |
| `WorkloadApp/Components/HRVDetailChart.swift` | §5 |
| `WorkloadApp/Components/ChartDetailPrimitives.swift` | `ChartReadoutWell`, `ChartZoneKey`, `ReasonTree`, `ExplanationDisclosure` (+ `DayScrubGesture` only if Q1 is refused) |

### MODIFIED (4, +1 conditional)

| Path | Change |
|---|---|
| `WorkloadApp/Views/Dashboard/SleepDetailView.swift` | §6 |
| `WorkloadApp/Views/Dashboard/HRVDetailView.swift` | §6 |
| `WorkloadApp/Resources/Localizable.xcstrings` | 16 new keys, en + zh-Hans |
| `workload management/workload management.xcodeproj/project.pbxproj` | register 3 files |
| `WorkloadApp/Components/ChartTooltipOverlay.swift` | **conditional on Q1** — one defaulted `clearsOnEnd` parameter |

### FROZEN — must end Phase 2 with a clean diff

`HRVTrendChart.swift`, `SleepTrendChart.swift`, `WorkloadView.swift` (incl. `LoadTrendChartView`),
`RecoveryView.swift`, `DashboardView.swift`, `RecoveryLoadChart.swift`, `CardStyle.swift`,
`ColorTokens.swift`, `FontTokens.swift`, `DesignSystemFenceTests.swift`, `DESIGN.md`.

### `.pbxproj` plan (H is the sole Wave-3 toucher)

The project is **not** file-system-synchronized for app sources — only `ScreenshotTests` and
`WorkloadAppTests` are `PBXFileSystemSynchronizedRootGroup`. App sources carry explicit entries,
so each new file needs **four** edits:

1. `PBXBuildFile` entry (`… /* X.swift in Sources */ = {isa = PBXBuildFile; fileRef = …; };`)
2. `PBXFileReference` entry
3. child of the `Components` group — `62324BE72F66CB0E00A9C2BE /* Components */`, line ~498
4. member of the app target's `Sources` build phase (~line 1104 region)

**Backup first**, per the lane brief:
`cp "workload management/workload management.xcodeproj/project.pbxproj" \
   "$SCRATCH/project.pbxproj.pre-h.bak"`
Use hand-authored stable 24-hex IDs in the existing convention (the repo already uses synthetic
IDs like `CC0302010000000000000004`); do **not** open Xcode to add files (it rewrites unrelated
sections and would collide with the orchestrator's diff review).

### Not in scope, deliberately

`LoadTrendChartView` is in H's ownership list but gets **no change this round**. It is a glance
chart under HAN's freeze, it has no detail view to zoom into, and Wave 2 already fixed its real
defect (the missing `series:` discriminator). Building a Load detail view is a separate,
larger piece of work — recorded in §12.

---

## 10. Law citation index

Every element, and the clause that permits it. Anything not on this list is not in the spec.

| Element | Licensing clause |
|---|---|
| Detail chart 224pt, paddings `Spacing.*` | 8pt grid; `test_structuralSpacingLiterals_areOnTheGrid` |
| Bars/lines in metric hue | "Metric hues may be used as: series lines, state dots, chart 'now' markers, hero readings" |
| **No** hue area fill under the HRV band | "Metric hues may NEVER be used as plane fills… decorative tints"; Wave-2 rejection of the kit's TSB wash |
| Selection rule in `accent` | Reading Color Rule — "live-state marks… active/selected marks" is accent's exclusive territory |
| Crosshair as an open circle in the series hue | `readme.md` §Charts, `guidelines/charts.card.html` — "crosshair markers (open circles)" |
| Zone-coloured 6 h / 7 h rules | Contrast rule 3 — "Marks are unrestricted… 3:1 graphical floor on every plane" |
| Zone key: colour on the `▒` glyph, text in `text3` | `LoadTrendChartView.seriesKey` precedent; Zone Color Rule (label first, colour supplementary, never colour alone) |
| `▒ ▲ ▼ = ● ├─ └─ ·` | DESIGN.md annotation glyph table; `guidelines/glyphs.card.html`. No icon font, no emoji |
| All annotation ≤12pt, uppercase, +0.05em applied by the token | Two-Voice Type Law; `Font.Tokens.anno`/`.annoSmall` only; `test_annotationSizeCap_isEnforcedAndNotBypassed` |
| Reason-tree rows in `text2` | Contrast rule 4 — "annotation that carries information the athlete must not miss uses `text2`" |
| Readout well: `text1` reading + `text2` annotation, no hue | Contrast rule 7 — hue/zone text <24pt on card planes only; `text3` never on a well |
| Readout well is debossed, fixed-width, always present | Relief Law — "every displayed value sits in a fixed-width debossed well… digits change, the stone never resizes" |
| Scrub classified as Detent control | Five-Primitive Law #3 — "discrete values, mechanical snap, ~100ms digit-roll, fixed-width readout wells, reduced haptics" |
| Disclosure classified as Row | Five-Primitive Law #2; `WeeklySummaryCard` in-repo precedent |
| `Motion.digitRoll` / `.state` only, via `Motion.resolved` | Motion Law chokepoint; `test_animationCurveLiterals_onlyInCardStyle`, `test_noBareWithAnimation` |
| Annotation appears via `.annotationReveal(index:)` | Annotation choreography — "implemented once… screens consume it and never reimplement a stagger" |
| Reference keys above the plot, never `.annotation()` on a rule | DESIGN.md v6.1 decision-log entry; commit `3993bd1` |
| Section heads in working voice, tree rows in annotation | Rule 9 — "annotation is never a sentence, never a headline" |
| No new CTA anywhere on either screen | "one ink-filled pill max per screen" — this spec adds zero pills |
| No shadows; hairlines 0.5pt; corners via `CornerTokens` | `test_noShadowModifiers`, `test_cornerRadii_onlyViaCornerTokens` |
| No hex literals; `ColorTokens` only | `test_noHardcodedColors_inViewsAndComponents` |
| `.id(locale)` + `AnnotationLabel(key:)` | Wave-2 defect #1 (zh-Hans live switch); `LocalePinnedStrings` precedent |

---

## 11. Phase 2 verification plan (what I will actually run)

Wave-3 rule: **no full suite, no simulator this round, orchestrator verifies serially.**

```bash
# 1. Build only (own DerivedData, per the lane brief)
cd "/Users/hanwen/dev/Tonus/workload management"
xcodebuild build -scheme "workload management" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -derivedDataPath ~/.tonus-dd-claude-h

# 2. The glance-freeze contract — must print nothing and exit 0
git diff --quiet -- \
  WorkloadApp/Components/HRVTrendChart.swift \
  WorkloadApp/Components/SleepTrendChart.swift \
  WorkloadApp/Views/Workload/WorkloadView.swift \
  WorkloadApp/Views/Recovery/RecoveryView.swift \
  WorkloadApp/Views/Dashboard/DashboardView.swift && echo "GLANCE FROZEN: OK"

# 3. Fence suite only — ONE target, allowed under the Wave-3 rule
xcodebuild test -scheme "workload management" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -derivedDataPath ~/.tonus-dd-claude-h \
  -only-testing:WorkloadAppTests/DesignSystemFenceTests

# 4. xcstrings integrity
python3 -c "import json; d=json.load(open('WorkloadApp/Resources/Localizable.xcstrings')); \
  ks=[k for k in d['strings'] if k.startswith(('sleep.detail.','hrv.detail.','hrv.chart.'))]; \
  print(len(ks)); print([k for k in ks if set(d['strings'][k].get('localizations',{}))!={'en','zh-Hans'}])"
```

Deferred to the orchestrator's serial gate (explicitly NOT run by H): full `WorkloadAppTests`,
`ScreenshotTests`, simulator visual QA, **zh-Hans layout check of the three-cell zone key**, and
Reduce-Motion verification of the readout.

---

## 12. Open questions — HAN decides before Phase 2

| # | Question | Options | H's recommendation |
|---|---|---|---|
| **Q0** | **The 7.5 h question** (§7) | S-1+S-3 (plot 6 h + 7 h, 7–9 h in prose) · S-2 (plot 7.5 h too, rewrite 2 legend keys + the shipped explanation, en+zh) · S-4 (plot the personal 7-day average) | **S-1 + S-3.** 7.5 h contradicts the app's own scoring and its shipped copy |
| **Q1** | `ChartTooltipOverlay.swift` is outside H's file list, but the persistent-selection scrub wants a 1-line defaulted parameter there | grant H the file (additive, both existing callers unaffected) · H writes a ~14-line `DayScrubGesture` in the new primitives file | **Grant.** Duplicating a gesture to satisfy a file boundary is the worse artefact |
| **Q2** | `SCORE_CONTRIB` needs `RecoveryScoreEngine.sleepDurationToScore` made non-private (a `Services/` change, outside H) | grant the visibility change · drop the row · duplicate the curve in the view | **Grant, else drop.** Never duplicate a scoring curve |
| **Q3** | Haptic on scrub | none · `Haptics.select()` only when crossing the 6 h / 7 h boundary · per-day tick | **None.** "Detent haptics stay Home-hero-only"; a per-day tick is decorative |
| **Q4** | Should any deviation/delta text wear a zone colour (e.g. HRV −12% in `zoneCaution`)? And may the HRV ±1SD band take a low-opacity **identity-less** `chartHRV` fill? | all ink · zone-coloured deltas · tinted band | **All ink, no fill.** Nocebo guard on the delta; the band fill re-opens the wash question Wave 2 just closed. Both are legal-ish, neither is clearly licensed |
| **Q5** | Machine keys (`SLEEP_DEBT_7D`, `TREND_7D`, `RISING`, `NOW`, `VS BASE`) stay English in zh-Hans | untranslated (precedent: `ATL`/`CTL`/`TSB`, `ACWR`) · add 15 zh keys | **Untranslated.** It is the annotation register's whole conceit — machine output, not speech. But it is the most debatable call here |
| **Q6** | New detail-chart files vs a `variant:` parameter on the frozen glance components | new files (some duplicated axis code) · parameterise | **New files.** A branch inside the frozen path is exactly what HAN's "stay exactly as they are" forbids |
| **Q7** | `RecoveryView`'s glance charts have no route into the detail views — should they get one? | leave as-is · add nav (requires `Views/Recovery/`, **not H's file**) | **Leave as-is this wave**, file as a request. The detail views are richer than Dashboard-only reach justifies, but the file belongs elsewhere |
| **Q8** | About rows default state | all collapsed · first expanded | **All collapsed.** Progressive disclosure; the tree already answers the question |
| **Q9** | Should the detail screens get a proper hero card (`heroScore` 64pt in the metric hue) instead of the 15pt stats band? | keep stats band · promote to hero | **Keep the band.** A hero would be a second hero-class element on a screen whose job is the chart, and 64pt would push the plot below the fold |

---

## 13. Requests to other lanes / the orchestrator

1. **`WorkloadApp/Components/ChartTooltipOverlay.swift`** — grant H write access for one
   additive defaulted parameter (`clearsOnEnd: Bool = true`). Both existing call sites
   (`WorkloadView.swift:438`, `RecoveryLoadChart.swift:84`) keep today's behaviour byte for byte.
   (Q1)
2. **`WorkloadApp/Services/RecoveryScoreEngine.swift`** — change
   `private static func sleepDurationToScore` to `static func sleepDurationToScore`. No behaviour
   change, engine stays a pure struct. Needed only if Q2 resolves to "grant". (Q2)
3. **`WorkloadApp/Views/Recovery/RecoveryView.swift`** — if Q7 resolves to "add nav", the two
   `RuledSection` chart blocks need `NavigationLink(value: TrendDestination.hrv/.sleep)`
   wrappers. Not H's file; route to whichever lane owns `Views/Recovery/`.
4. **Session P** — please do not touch `HRVTrendChart` / `SleepTrendChart` /
   `LoadTrendChartView` (already in P's brief as excluded); also please leave
   `ChartTooltipOverlay.swift` alone this wave.
5. **Session T (Dynamic Type)** — note for the annotation-voice decision: this spec puts a
   three-cell zone key in a single `HStack` at `annoSmall`. If `annoSmall` scales with Dynamic
   Type, that row is the first thing that will overflow on a small device at AX sizes. Worth a
   line in T's proposal.
6. **Orchestrator** — `.pbxproj` backup path and the four-edit recipe are in §9; H will not open
   Xcode.
