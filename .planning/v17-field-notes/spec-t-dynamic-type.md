# Spec T — Dynamic Type adoption for `Font.Tokens`

**Lane:** Session T (Wave 3, v1.7 "Field Notes")
**Status:** IMPLEMENTED 2026-07-31 (Phase 2). **Sections 1–7 below are the Phase 1 proposal and are partly WRONG — read the PHASE 2 ADDENDUM at the end first; it supersedes them.**
**Author:** Session T, 2026-07-30
**Scope of writes if approved:** `WorkloadApp/Utilities/FontTokens.swift` + the DESIGN.md
Dynamic Type section. Everything else in this doc is a *request* to another lane.

---

## 0. The problem, stated precisely

`Font.Tokens.*` builds every font through two private helpers:

```swift
private static func cascaded(size: CGFloat, weight: UIFont.Weight) -> Font {
    ...
    let descriptor = UIFontDescriptor(name: primaryName, size: size)
        .addingAttributes([.cascadeList: [UIFontDescriptor(fontAttributes: [.name: cjkName])]])
    return Font(UIFont(descriptor: descriptor, size: size))   // ← fixed points, forever
}
```

`Font(_: UIFont)` wraps a **resolved, fixed-point** UIFont. Nothing in the chain consults
`UIContentSizeCategory`. Every token is additionally a `static let`, so it is built **once**
per process. The app therefore renders identically at "Small" and at "AX5". That is the
whole bug. There is no `.dynamicTypeSize`, `@ScaledMetric`, `UIFontMetrics`, or `relativeTo:`
anywhere in `WorkloadApp/` (verified: `grep -rn "dynamicTypeSize\|ScaledMetric\|UIFontMetrics\|relativeTo" WorkloadApp/ --include="*.swift"` returns only unrelated `RelativeDateTimeFormatter` hits).

Surface area: **492 `.font(.Tokens.*)` call sites across 80 files**, plus the annotation
chokepoint (`AnnotationSize.font` in `CardStyle.swift`) and one `Canvas`-internal use
(`TickScale.swift:255`).

---

## 1. The token → `Font.TextStyle` map

Principle used: **map each token to the text style whose *default* (Large) size is closest
to the token's own size**, so the token rides a growth curve calibrated for text of that
magnitude. Deviations from that rule are justified per row.

iOS's Dynamic Type curves are deliberately non-uniform — small styles grow ~3.6×
from Large→AX5, large styles ~1.8×. Consequence, stated honestly: **hierarchy is preserved
as ordering, not as ratio.** At AX5 the ramp compresses (hero:body goes from 3.8× to 2.1×).
That is Apple's intended behaviour and the alternative — mapping everything to one style —
would put `heroScore` at 200pt. I am proposing ordering-preservation, and §1.2 verifies it.

### 1.1 The table

Sizes below are computed from the standard iOS Dynamic Type point table
(`UIFontMetrics` scaling of the token's own base size by the style's curve).
**These must be re-derived empirically in Phase 2** (see §4) — they are here so the
proposal is arguable, not as trusted constants.

| Token | Now | Wt | Proposed `relativeTo:` | xxxL | AX3 | AX5 | Justification (call sites) |
|---|---|---|---|---|---|---|---|
| `heroScore` | 64 | 400 | `.largeTitle` | 75 | 98 | 113 | The one giant number. `DashboardView.swift:387` (readiness score), `WorkloadView.swift:315` (ACWR `1.12`). `.largeTitle` has the **slowest** curve (1.76× at AX5) — correct for the element with the least horizontal headroom. Still needs a cap (§3). |
| `displayMetric` | 64 | 400 | *(alias of `heroScore`)* | — | — | — | **0 call sites.** Dead token — see §6. |
| `displayAction` | 32 | 400 | `.title1` | 39 | 55 | 66 | `LayoutPrimitives.swift:66` (MetricCell value — 3 across a row), `TodayVerdictCard.swift:83` (today's lift number), `RecoveryView.swift:278`. `.title1`'s 2.07× keeps it above `pageTitle`; `.largeTitle` (1.76×) would sink it *below* `body` at AX5. |
| `pageTitle` / `screenTitle` | 28 | 400 | `.title1` | 34 | 48 | 58 | 16 + 2 sites (every screen header, `CardStyle.swift:804`, `SheetChrome.swift:79`). `.title1`'s default **is** 28pt — the exact-match row. |
| `sectionHead` / `sectionTitle` | 17 | 500 | `.headline` | 23 | 40 | 53 | 36 sites. `.headline` is 17pt/semibold by definition — this token is a headline in everything but the weight token used. |
| `body` | 17 | 400 | `.body` | 23 | 40 | 53 | 132 sites — the ramp's anchor. Identity mapping. |
| `bodyMedium` | 17 | 500 | `.body` | 23 | 40 | 53 | 15 sites. Same size ⇒ same curve as `body`, so the weight step stays the *only* difference at every size. Deliberately **not** `.headline` (identical curve anyway, but `.body` states the intent). |
| `label` | 15 | 400 | `.subheadline` | 21 | 36 | 49 | 191 sites — the single most-used token. `.subheadline` default is 15pt. Exact match. |
| `labelMedium` | 15 | 500 | `.subheadline` | 21 | 36 | 49 | 7 sites. Pairs with `label`. |
| `smallLabel` / `caption` | 13 | 400 | `.footnote` | 19 | 34 | 47 | 43 sites (`TodayVerdictCard.swift:96,127` confidence + action captions). `.footnote` default is 13pt. Exact match. |
| `smallLabelMedium` | 13 | 500 | `.footnote` | 19 | 34 | 47 | 14 sites — notably `MetricTile.swift:31`, the tile's **value**. Pairs with `smallLabel`. |
| `micro` | 12 | 400 | `.caption1` | 18 | 32 | 44 | 41 sites (`RuledSectionHeader`, `ZoneBadge`, the HRV TREND / LOAD TREND heads). `.caption1` default is 12pt — exact match after the v6.2 11→12 raise. |
| `keyLabel` | 11 | 500 | `.caption2` | 17 | 29 | 40 | 2 sites, but load-bearing: `InkTabBar.swift:96` (the tab bar) and `CardStyle.swift:904` (decision-key cells). `.caption2` default is 11pt. **This row is the layout blocker — see §3.1.** |
| `tabLabel` | 11 | 500 | `.caption2` | 17 | 29 | 40 | **0 call sites** — the tab bar uses `keyLabel` instead. Dead token, §6. |
| `headerAction` | 10 | 500 | `.caption2` | 15 | 27 | 36 | 2 sites (`CardStyle.swift:808`, `SheetChrome.swift:34` — the header's trailing action, a tap target). Below `.caption2`'s 11pt default; no smaller style exists. |
| `anno` | 12 | 400 | `.caption1` | 18 | 32 | 44 | Reached via `AnnotationLabel` (`AnnotationSize.standard`), ~40 render sites. Same style as `micro` **on purpose**: the two 12pt voices must stay in lockstep or the working/annotation pair drifts apart at large sizes. **Subject to §2.** |
| `annoSmall` | 11 | 400 | `.caption2` | 17 | 29 | 40 | `AnnotationSize.small` — axis labels in `HRVTrendChart`/`SleepTrendChart`, `MetricTile` keys, `TickScale.swift:255`. In lockstep with `keyLabel`. **Subject to §2 and §3.2.** |

### 1.2 Ordering check (the "hierarchy preserved" claim)

At AX5, descending: hero 113 > displayAction 66 > pageTitle 58 > sectionHead/body 53 >
label 49 > smallLabel 47 > micro/anno 44 > keyLabel/annoSmall 40 > headerAction 36.
Every step in today's ramp survives, in the same order, with no ties across tiers.
Two intentional ties remain (`micro`≡`anno`, `keyLabel`≡`annoSmall`) — they are ties at
Large today too.

The near-miss worth naming: `displayAction` on `.largeTitle` would be 56pt at AX5,
**below** `pageTitle`'s 58pt — an inversion. That is why the two big tokens do not both
take `.largeTitle`.

---

## 2. The annotation voice vs. the ≤12pt law

This is the genuine conflict and I will not paper over it.

**The law today** (DESIGN.md v6 §Typography, `FontTokens.annoSizeCap`, and fence test
`test_annotationSizeCap_isEnforcedAndNotBypassed`): Fragment Mono **never renders above
12pt**, enforced by clamping inside `annoCascaded` so that "a mono at display size" is
unrepresentable. That clamp is the memorial to the retired v4 IBM Plex Mono dial voice.

**The accessibility need:** the annotation layer carries units (`62 MS`), signed deltas
(`▲ +4`), chart axis labels, timestamps, and the entire reason tree (`├─ HRV AT BASELINE`).
A user at AX3 sees body copy at 40pt and this at 11pt. That content is not decorative; a
low-vision user needs the delta more than the sentence.

### Option A1 — the cap becomes a *specification* cap, not a *rendered* cap **(recommended)**

Reword the law: *"Fragment Mono is specified at ≤12pt at the default (Large) content size,
and scales with Dynamic Type on the same curve as the working voice's equivalent tier.
The cap is a cap on the design size."*

- Implementation: keep `min(size, annoSizeCap)` — it clamps the **base** — then scale.
  `annoCascaded(size:)` stays the only route to the face, and no token can declare > 12pt.
- Consequence, stated plainly: at AX5 a Fragment Mono glyph renders at ~44pt. Somebody
  reading the fence test will see the v4 dial voice reincarnated. It is not — the *relation*
  is intact (body 53 vs anno 44; annotation is still subordinate at every size) — but the
  literal sentence "never above 12pt" becomes false and must be rewritten in DESIGN.md,
  in `FontTokens.swift`'s doc comment, and in the fence test's rationale.
- Why I recommend it: "marginalia" is a *relative* property. A law that reads as absolute
  points but means proportion should be restated as proportion rather than defended into an
  accessibility failure.

### Option A2 — annotation does not scale at all

- Implementation: `anno`/`annoSmall` keep `Font(UIFont(...))` with no metrics.
- Consequence: at AX3+ the annotation layer becomes the **only** unreadable text in the app,
  and it is the layer carrying the numbers. Hierarchy also inverts in feel: annotation
  shrinks relative to everything, becoming decorative texture rather than information.
- Honest verdict: this satisfies the letter of the law by failing the users the change is
  for. I recommend against it, but it is the zero-risk option for layout (charts, `TickScale`
  and the tab bar all stop being at risk — see §3).

### Option A3 — annotation scales, with its own lower ceiling

- Implementation: `UIFontMetrics(forTextStyle:).scaledFont(for: base, maximumPointSize: N)`.
  Suggested N = 20pt (≈ AX1 for `.caption1`).
- Consequence: annotation stays readable through xxxL/AX1 (the sizes most users actually
  choose) and stops growing at the accessibility tail, where the working voice keeps going —
  so subordination *strengthens*. A genuine AX5 user gets 20pt mono against 53pt body: an
  improvement on today, still short of their setting.
- This is the honest middle. If HAN is unwilling to reword the ≤12pt law, **A3 is the
  option I would take over A2** — it keeps a hard numeric ceiling in the code, just a
  different number.

**Recommendation: A1**, with A3 as the fallback if the law must keep a hard rendered ceiling.

---

## 3. Capping — and the four screens that force the question

**I recommend against a global `.dynamicTypeSize(...DynamicTypeSize.accessibility3)` clamp
at the app root.** It is a single line and it silently overrides a user's stated OS-level
preference across the whole product; Apple's guidance is to fix the layout. It is also
worth naming that a global clamp is *incompatible* with implementation Strategy B (§5) —
a UIKit-metrics token does not observe SwiftUI's clamp.

Instead: **per-token `maximumPointSize`, applied only where geometry is physically fixed**,
plus geometry fixes requested from the lanes that own those files.

### 3.1 `InkTabBar` — the hard blocker

`InkTabBarMetrics.height = 48` (fixed), five full-width cells, label at
`.Tokens.keyLabel` + `.tracking(1.4)` + `.lineLimit(1)` (`InkTabBar.swift:71,96-99`).
On a 393pt-wide device each cell is ~78pt. At AX5 the label is 40pt tall inside a 48pt bar
and "Recovery" at 40pt + 1.4pt tracking is ~200pt wide in a 78pt cell. `lineLimit(1)` with
no `minimumScaleFactor` means it truncates to nothing legible.

Options, in order of my preference:
1. **Fix the bar** (preferred): `@ScaledMetric` height, `minimumScaleFactor(0.7)`,
   and drop the 1.4pt tracking above xxxL. *This is not my file* — see §7 request R1.
2. **Cap `keyLabel`** at ~16pt via `maximumPointSize`. Cheap, but `keyLabel` also draws the
   decision-key cells (`CardStyle.swift:904`) which are CTA-adjacent text that *should*
   scale — capping punishes them for the tab bar's rigidity.
3. Ship Dynamic Type with the tab bar clamped locally
   (`.dynamicTypeSize(...DynamicTypeSize.xxxLarge)` on `InkTabBar` only). Scoped, honest,
   also not my file.

**Until one of these lands, Dynamic Type should not ship.** The tab bar is on every screen.

### 3.2 `TickScale` — Canvas with hardcoded geometry

`TickScale.swift` draws into a `Canvas` at `Metrics.scaleHeight = 40` / `microHeight = 24`,
with numerals resolved at `.font(.Tokens.annoSmall)` (line 255) and placed at
`numeralTop = 21`. The comment at line 148 records that the canvas was grown 36→40 when the
numerals went 9→11pt. Canvas-resolved `Text` **does** pick up the font it is given, so under
A1 the numerals grow ~4× while the canvas stays 40pt: they will clip.

This is the strike-zone bar (`TodayVerdictCard.swift:99-108`, `.frame(height: 28)`) and the
Home hero band. `TickScale.swift` is unowned in Wave 3 — request R2.

### 3.3 The dense metric rows

`MetricsStrip` (`DashboardView.swift:629-647`) is a 3-wide `HStack` of `MetricCell`, each
with a `displayAction` (32pt) value carrying `minimumScaleFactor(0.6)`
(`LayoutPrimitives.swift:70`). At AX5 that is 66pt shrinking to a floor of 40pt in a ~120pt
cell — "1234" won't fit. `WorkloadView.swift:102-114` and `RecoveryView.swift:347-353` have
the same shape. Mitigation is a layout change (`ViewThatFits` → vertical stack above xxxL),
not a font change.

### 3.4 The chart cards

`HRVTrendChart.swift:68` `.frame(height: 184)` and `SleepTrendChart.swift:67`
`.frame(height: 160)` with `annoSmall` axis labels inside. Under A1 the axis labels grow but
the plot does not. **Session H owns these files this wave** — request R3, and H should
build the new detail views with scaled heights from the start rather than retrofitting.

---

## 4. The invariant, and how it gets proved

**Invariant:** at `UIContentSizeCategory.large` (the default), every token must resolve to
**exactly** its current point size — 64 / 32 / 28 / 17 / 17 / 17 / 15 / 15 / 13 / 13 / 12 /
11 / 11 / 10 for the working voice, 12 / 11 for annotation.

`UIFontMetrics` is defined so that its scale factor at `.large` is 1.0 for every text style,
so this *should* hold by construction — but "should" is not proof, and floating-point noise
in `scaledValue` is a real possibility. Three checks, in Phase 2:

**P1 — a pure unit test, no simulator UI, no rendering.** Refactor the size computation into
an internal, testable function:

```swift
static func scaledSize(_ base: CGFloat,
                       textStyle: UIFont.TextStyle,
                       category: UIContentSizeCategory) -> CGFloat
```

then assert, for the full 16-row token table:

```swift
XCTAssertEqual(Font.Tokens.scaledSize(17, textStyle: .body, category: .large), 17, accuracy: 0.0)
```

`accuracy: 0.0` on purpose — "byte-identical" means byte-identical. This is one test file
addition (`WorkloadAppTests/`), which I do not own → request R4.

**P2 — the resolved-font assertion.** For each token, resolve to `UIFont` at `.large` via
`compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)` and assert
`pointSize` equals the table **and** `fontName` still equals the expected PostScript name
(this is what catches an accidental loss of the Instrument Sans / Fragment Mono face, which
is the failure mode of Strategy A in §5).

**P3 — a pixel diff.** Capture the five tabs at the default setting before and after the
change with the same seeded `SCREENSHOT_MODE` data and diff the PNGs. Non-zero diff at
default = the change is wrong, full stop. (Simulator work — must be scheduled into the
orchestrator's serialized simulator round, not run in a lane.)

Note P1/P2 are the ones that make the invariant *cheap to re-verify* on every future token
edit; P3 is the one-time proof.

---

## 5. Implementation strategy — the part that actually needs HAN's decision

The current chokepoint returns `Font(UIFont(descriptor:size:))` with a **`.cascadeList`
attribute pointing at Noto Sans SC**. That cascade is what gives mixed Latin+CJK strings
glyph-by-glyph harmony (`FontTokens.swift:149-158`, phase-23 pitfall 3). Dynamic Type and
that cascade pull in opposite directions:

### Strategy A — SwiftUI-native: `Font.custom(name, size:, relativeTo:)`

- ✅ Environment-correct: respects `.dynamicTypeSize` overrides, previews, per-view clamps,
  and composes with `@ScaledMetric`. Live-switches with certainty.
- ✅ Zero call-site sweep — `.font(.Tokens.body)` keeps working.
- ✅ Makes §3's per-view clamp options (3.1 opt 3) actually possible.
- ❌ **Loses the Noto Sans SC cascade.** `Font.custom` takes a *name*; there is no SwiftUI
  API that accepts a `UIFontDescriptor`. CJK glyphs would fall to the system fallback
  (PingFang SC) instead of the bundled Noto. That is a real zh-Hans rendering change and it
  quietly makes `NotoSansSC-*.otf` dead weight in the bundle.

### Strategy B — UIKit metrics: `UIFontMetrics(forTextStyle:).scaledFont(for: cascadedFont)`

- ✅ **Keeps the cascade intact** — metrics scale the descriptor-built font.
- ✅ Zero call-site sweep. Gives `maximumPointSize:` for free (§2 A3, §3).
- ⚠️ Tokens must become `static var` (computed) instead of `static let`, or they freeze at
  first access.
- ❌ Not environment-correct: it reads the **process-wide** preferred content size category,
  not the view's. `.dynamicTypeSize(...)` overrides and preview traits would be ignored.
  Stress-testing still works (`xcrun simctl ui booted content_size accessibility-extra-large`
  changes the process setting), but previews get worse.
- ❌ **Unverified risk:** a view whose body reads no environment key may not be re-evaluated
  by SwiftUI on a content-size-category change, meaning text would not reflow until the app
  relaunches. I believe the `UIHostingController` trait change forces a root rebuild, but I
  have not proved it and will not assert it. **Phase 2 must test this first** — change the
  size in Settings with the app foregrounded and confirm reflow. If it fails, B is dead.

### Strategy C — a `.tokenFont(.body)` view modifier reading `@Environment(\.dynamicTypeSize)`

- ✅ Keeps the cascade **and** is fully environment-correct. No compromise.
- ❌ Requires sweeping **492 call sites across 80 files** — mechanical
  (`.font(.Tokens.X)` → `.tokenFont(.X)`, one `sed`) but it touches nearly every file in the
  app, i.e. every other Wave 3 lane's files. The kickoff brief explicitly says *"do not sweep
  call sites this wave"*.

**My recommendation:** **B for Phase 2, gated on the live-switch test passing**, because
losing the deterministic CJK cascade is a v6 design-law regression in a shipped locale and
Dynamic Type should not be bought with it. If the live-switch test fails, escalate to **C in
a dedicated wave** (not a shared one) rather than falling back to A. Strategy A should only
be chosen if HAN decides PingFang SC is an acceptable — or preferable — Chinese face, which
is a legitimate call I am not authorised to make.

---

## 6. Dead tokens found while surveying

Zero call sites app-wide (`grep -rnE "Tokens\.<name>\b" WorkloadApp/ --include="*.swift"`,
excluding `FontTokens.swift`): **`displayMetric`, `tabLabel`, `sectionTitle`, `caption`**.
`tabLabel` is the notable one — its doc comment claims it draws the tab bar, but
`InkTabBar.swift:96` uses `keyLabel`. The doc comment is wrong and has been misleading every
reader of the file. Recommend deleting all four (or at minimum correcting `tabLabel`'s
comment) as part of Phase 2, since I am touching the file anyway. Needs HAN's yes.

---

## 7. Collisions and cross-lane requests

**Grid / geometry collisions (all real, all outside my file):**

- **R1 — `InkTabBar.swift`:** fixed 48pt height + `lineLimit(1)` + 1.4pt tracking on a
  scaling label. **Ship blocker.** §3.1.
- **R2 — `TickScale.swift`:** `Canvas` at fixed 40pt/24pt with `annoSmall` numerals at a
  hardcoded `numeralTop: 21`; the strike-zone bar (`TodayVerdictCard.swift:105`,
  `.frame(height: 28)`) inherits it. §3.2.
- **R3 — `HRVTrendChart` (184pt) / `SleepTrendChart` (160pt):** Session H's files this wave;
  new detail views should be built with `@ScaledMetric` heights now rather than retrofitted.
- **R4 — `WorkloadAppTests/DesignSystemFenceTests.swift`:** two problems.
  (a) The fence asserts **literal source text** —
  `text.contains("static let anno = annoCascaded(size: 12)")` and
  `text.contains("min(size, Tokens.annoSizeCap)")` (lines 336, 344-347). Any Phase-2 edit to
  `FontTokens.swift` — `static let` → `static var`, a changed helper signature — **breaks the
  fence suite**. The fence must be updated in the same commit.
  (b) The P1/P2 invariant tests belong in that target. I own neither.
- **R5 — `CardStyle.swift` (`AnnotationSize.tracking`, lines 561-566):** tracking is a
  hardcoded `12 * 0.05` / `10 * 0.05`. Under A1 the font grows ~4× but tracking stays 0.6pt,
  so the annotation's +0.05em law silently becomes +0.014em at AX5 — the mono's engraved
  texture dissolves at exactly the sizes where it is most visible. Tracking must be derived
  from the *resolved* size. (Also note the `.small` case computes `10 * 0.05` but `annoSmall`
  has been 11pt since v6.1 — a pre-existing 0.05pt staleness, unrelated to my lane but worth
  someone's attention.)
- **8pt grid:** `Spacing.*` constants do not scale, so at AX5 a 53pt line of body sits in
  16pt padding — the grid stops reading as a grid. I am **not** proposing scaled spacing
  (that multiplies the blast radius and the 8pt law is explicit). Naming it as an accepted
  consequence: at accessibility sizes the app becomes type-dense within a fixed grid.
- **`monospacedDigit()` / readout wells:** the design law says "values sit in fixed-width
  debossed readout wells — digits change, the stone never resizes". `.monospacedDigit()`
  itself survives Dynamic Type on both strategies (it is a font-feature modifier), but any
  well sized by a hardcoded `.frame(width:)`/`minWidth:` (e.g. `RepScrubber.swift:144,161`
  `minWidth: 28`, `InstrumentForm.swift:202` `width: 24`) will be overrun. Those need
  `@ScaledMetric`. Not my files.

---

## 8. What Phase 2 would actually change in `FontTokens.swift`

For the record, so the diff is predictable:

1. `cascaded(size:weight:)` gains a `textStyle: UIFont.TextStyle` parameter and returns a
   metrics-scaled font (Strategy B) or a `Font.custom(..., relativeTo:)` (Strategy A).
2. `annoCascaded(size:)` likewise; the `min(size, annoSizeCap)` clamp **stays** and keeps
   clamping the base size (this is what preserves the fence's intent under A1).
3. Every `static let` token becomes a `static var` (B only) with its `relativeTo:` argument.
4. `annoSizeCap`'s doc comment is rewritten to say *design size*, not *rendered size*.
5. A new internal `scaledSize(_:textStyle:category:)` for P1/P2 to test against.
6. Optional: delete the four dead tokens (§6).

No call site changes. No other file.

---

# PHASE 2 ADDENDUM — 2026-07-31 (implemented)

HAN ruled on §2 and §5. This addendum records what changed, and **corrects four things this
document got wrong in Phase 1.** Where Phase 1 and this addendum disagree, this addendum wins.

## A. Corrections to Phase 1

1. **§1.1's whole grid was wrong, and so was the ordering proof in §1.2.** The numbers were
   computed from the published iOS Dynamic Type point table. That table describes what each
   *style* renders at; it does not describe what `UIFontMetrics` returns for a *custom base
   size* on that style's curve, and it gave no way to see that the curves are not mutually
   monotone. The measured grid is now `.planning/v17-field-notes/dynamic-type-grid.txt`
   (regenerated on every fence-suite run). Two facts it exposed that §1.1 could not:
   - `.caption2` **floors at 11pt** (it does not shrink at XS/S/M) and then **jumps +4pt at
     XL**. An 11pt `keyLabel` on `.caption2` therefore *overtakes* a 12pt `micro` on
     `.caption1` from XL upward — measured 15 vs 14 at XL, 41 vs 38 at AX5. §1.2's claim that
     "every step in today's ramp survives, in the same order, with no ties across tiers" was
     **false** under its own proposed mapping.
   - `.headline` and `.body` agree at every category **except AX4**, where a 17pt base gives
     39pt vs 43pt. §1.1's `sectionHead → .headline` row would have split the weight-only
     `sectionHead`/`body` pair by 4pt at exactly one text size.
   The style-matched mapping was therefore **abandoned**, not tuned. See §B.
2. **The annotation blast radius in §1.1 (`anno`, "~40 render sites") was less than a third of
   the real number.** Measured: **139 `AnnotationLabel(` call sites** outside `CardStyle.swift`
   (92 standard + **47** `size: .small`), plus **3** `.annotation(` modifier uses and 8 direct
   `Font.Tokens.anno`/`.annoSmall` references. Round 1's review said 120/34; the true counts are
   139/47. Nothing about the implementation depends on this number — it is the size of the
   surface HAN's cap ruling governs, and it was understated.
3. **§1.1's `displayAction` row contradicted §1.2.** The row said `.largeTitle` "would sink it
   *below* `body` at AX5"; that is arithmetically false (56.5 vs 53 on its own numbers). §1.2's
   version — below **`pageTitle`** — was the true one. Moot now: both title tiers share
   `.title1`, so their ratio is fixed at every size by construction.
4. **§5's "Strategy B risk" was real and it fired.** See §D.

## B. The mapping actually implemented — three curves, derived from ONE measured table

| Token | Base | Curve | AX5 (measured) |
|---|---|---|---|
| `heroScore` | 64 | `.largeTitle` | 109 |
| `displayAction` | 32 | `.title1` | 64 |
| `pageTitle` / `screenTitle` | 28 | `.title1` | 56 |
| `sectionHead` | 17 | `.body` | 48 |
| `body` / `bodyMedium` | 17 | `.body` | 48 |
| `label` / `labelMedium` | 15 | `.body` | 42 |
| `smallLabel` / `smallLabelMedium` | 13 | `.body` | 37 |
| `micro` | 12 | `.body` | 34 |
| `keyLabel` / `tabLabel` | 11 | `.body` | 31 |
| `headerAction` | 10 | `.body` | 28 |
| `anno` | 12 | `.body` | 34 |
| `annoSmall` | 11 | `.body` | 31 |

Rationale: **within one style, `UIFontMetrics` scales proportionally to the base size**
(measured: `displayAction` 32→64 and `pageTitle` 28→56 at AX5, both exactly 2.0×). So tokens
sharing a curve **cannot invert**. Cross-curve pairs are the only ones that can, and there are
only two boundaries left (hero↔title, title↔body), both verified at all twelve categories by
`test_dynamicType_measuredGrid_andOrderingSurvives`, which asserts the universal property
"specified larger ⇒ never renders smaller" over every pair in `Font.Tokens.allSpecs`.

**Honest cost, stated rather than buried:** small tokens now grow on the body curve (2.82× at
AX5) instead of the faster curve iOS gives captions (≈3.7×). `headerAction` reaches 28pt at AX5
where a caption-matched mapping would have reached 37pt. The app's own hierarchy survives
exactly; iOS's convention of letting small text catch up does not.

**Rung collisions, recorded not hidden:** rounding ties the 12pt and 11pt tiers together at XS
(both 10pt) and M (both 11pt) — i.e. only *below* the default size, in the shrink direction.
No ties at or above `Large`. The list is printed into the grid file on every run.

## C. The ≤12pt law — A1 as ruled

The cap is now a **specification** cap. `min(size, Tokens.annoSizeCap)` stays and clamps the
declared base size, so no token can declare a mono above 12pt; scaling applies on top.
Reworded in `DESIGN.md` (type-scale table, the paragraph under it, implementation rule 3,
the retired-concepts row, a new Dynamic Type section, changelog v6.3), in `FontTokens.swift`'s
`annoSizeCap` doc comment, and in the fence test's rationale.

## D. §5's unproven risk fired — the live-switch gate FAILED

Recorded in full in `status-t.md`. Summary: `UIFontMetrics` reads the process-wide category and
creates no SwiftUI environment dependency, so on a live text-size change SwiftUI re-evaluates
only the bodies that read `\.dynamicTypeSize` themselves. Launching at any size is fully
correct; changing size mid-session is not. Escalated to HAN, per the ruling.

## E. Dead tokens (§6) — three deleted, one resurrected

`displayMetric`, `sectionTitle`, `caption` are **deleted** (0 references in `WorkloadApp/`,
`WorkloadAppTests/`, `workload management/ScreenshotTests/`, or `design-system/`; the three
`sectionTitle` grep hits are an unrelated `AppShellContracts` property).

`tabLabel` is **kept and made real**: `InkTabBar` now uses it instead of `keyLabel`. This is a
deliberate deviation from the Round 1 review's "delete all four", on two grounds — (a) its doc
comment claimed it drew the tab bar, and pointing the tab bar at it makes the comment true
instead of deleting the evidence of the discrepancy; (b) DESIGN.md's Type Scale table has a
`tabLabel` row, and deleting the token would have created doc drift in a section this lane does
not own. It also un-blocks §3.1's real objection: the tab bar is the app's one piece of fixed
geometry, and it now has a token that can be tuned without dragging the decision-key cells
(`CardStyle.swift:904`) along with it.
