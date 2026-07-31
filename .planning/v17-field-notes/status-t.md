# Session T — Dynamic Type — status

## 2026-07-30T23:55 — Phase 1 (proposal) complete. AWAITING HAN.

**Status:** awaiting-han. **No source file was modified.** This round was proposal-only per
the lane brief; `WorkloadApp/Utilities/FontTokens.swift` is untouched.

### What I did

- Read `design-system/SKILL.md`, `design-system/readme.md`, `design-system/tokens/typography.css`,
  the Wave 3 section of `.planning/v17-field-notes/DISTRIBUTION.md`, `DESIGN.md` (v6.2 —
  Two-Voice Type Law + Type Scale + Annotation Layer), `CLAUDE.md`, and
  `WorkloadApp/Utilities/FontTokens.swift` in full.
- Surveyed real usage rather than guessing mappings: counted every token's call sites,
  read the load-bearing ones (`DashboardView` hero, `WorkloadView` hero, `LayoutPrimitives.MetricCell`,
  `MetricTile`, `TodayVerdictCard` strike-zone block, `InkTabBar`, `TickScale`,
  `AnnotationLabel`/`AnnotationSize` in `CardStyle.swift`), and swept for fixed geometry
  (`.frame(height:/width:)`) and existing Dynamic Type usage (there is none).
- Wrote the proposal: `.planning/v17-field-notes/spec-t-dynamic-type.md`.

### What the proposal contains

1. **Full 16-row token → `Font.TextStyle` table** with the current size, the proposed
   `relativeTo:`, computed sizes at xxxL / AX3 / AX5, and a per-row justification citing
   call sites. Principle: match each token to the style whose default size is closest, so it
   rides a curve calibrated for text of that magnitude. Plus an explicit ordering check
   showing every rung of the ramp survives at AX5 (and why `displayAction` must be `.title1`,
   not `.largeTitle` — `.largeTitle` would sink it below `pageTitle`).
2. **Annotation voice vs the ≤12pt law** — three real options (A1 restate the cap as a
   *design*-size cap and let the mono scale; A2 don't scale annotation at all; A3 scale with
   a `maximumPointSize` ceiling ≈20pt), each with its honest consequence. Recommend A1,
   fallback A3.
3. **Capping** — recommend *against* a global `.dynamicTypeSize` clamp; use per-token
   `maximumPointSize` only where geometry is physically fixed. Named the at-risk surfaces
   with line numbers: `InkTabBar` (fixed 48pt bar, 5 cells, `lineLimit(1)`, 1.4pt tracking —
   **ship blocker**), `TickScale` Canvas (fixed 40/24pt, hardcoded `numeralTop`) which is
   also the strike-zone bar, the 3-wide `MetricsStrip`/`WorkloadView`/`RecoveryView` metric
   rows, and the two trend-chart cards (184/160pt).
4. **The default-size invariant and its proof** — a pure `scaledSize(_:textStyle:category:)`
   unit test asserting `accuracy: 0.0` at `.large` for all 16 rows, a resolved-`UIFont`
   pointSize + `fontName` assertion, and a one-time before/after pixel diff of the five tabs.
5. **Implementation strategy** — the decision the whole thing hinges on: the token chokepoint
   currently returns `Font(UIFont(descriptor:))` carrying a `.cascadeList` to Noto Sans SC,
   and `Font.custom(_:size:relativeTo:)` cannot carry a descriptor. Three strategies (A
   SwiftUI-native / B `UIFontMetrics` / C modifier + 492-call-site sweep) with what each one
   costs. Recommend B gated on a live-switch test, escalate to C if it fails.

### Findings worth surfacing independent of the proposal

- **Four dead tokens**: `displayMetric`, `tabLabel`, `sectionTitle`, `caption` have zero call
  sites app-wide. `tabLabel`'s doc comment claims it draws the tab bar; `InkTabBar.swift:96`
  actually uses `keyLabel`. The comment has been wrong for some time.
- **`AnnotationSize.tracking` (`CardStyle.swift:561-566`) is hardcoded** as `12 * 0.05` /
  `10 * 0.05`. Two problems: (a) the `.small` case still computes off 10pt though `annoSmall`
  became 11pt in v6.1 — a pre-existing 0.05pt staleness; (b) under any scaling proposal the
  tracking stays 0.6pt while the glyphs grow ~4×, so the +0.05em annotation law silently
  degrades to +0.014em at AX5.
- **`DesignSystemFenceTests.swift` asserts literal source text** of `FontTokens.swift`
  (`"static let anno = annoCascaded(size: 12)"`, `"min(size, Tokens.annoSizeCap)"`). Any
  Phase-2 edit — including `static let` → `static var` — breaks the fence suite. The fence
  must be updated in the same commit, and I do not own that file.

### Verification

**None run — correctly.** This round produced no source change, so there is nothing to
build or test; a build would only prove the tree is unchanged. Per the Wave 3 rules I did
not run the test suite, did not touch the simulator, and did not commit.

The only commands run were read-only surveys. Representative, with actual output:

```
$ grep -rn "dynamicTypeSize\|DynamicTypeSize\|sizeCategory\|ScaledMetric\|UIFontMetrics\|relativeTo" \
    WorkloadApp/ --include="*.swift"
WorkloadApp/Views/Profile/SyncStatusView.swift:73:  ... relativeTo: Date()) ...
WorkloadApp/Views/Profile/SyncStatusView.swift:80:  ... relativeTo: Date()) ...
WorkloadApp/Views/Profile/SyncStatusView.swift:110: ... relativeTo: Date()) ...
WorkloadApp/Services/SubscriptionService.swift:121: relativeTo date: Date = .now
WorkloadApp/Services/SubscriptionService.swift:130: relativeTo date: Date = .now
```

→ zero Dynamic Type adoption anywhere; the five hits are `RelativeDateTimeFormatter` and a
date parameter label. Confirms the premise.

```
$ grep -rn "\.font(\.Tokens\.\|\.font(Font\.Tokens\." WorkloadApp/ --include="*.swift" | wc -l
     492
$ grep -rl "\.font(\.Tokens\.\|\.font(Font\.Tokens\." WorkloadApp/ --include="*.swift" | wc -l
      80
```

→ the sweep cost figure quoted for Strategy C.

Per-token call-site census (`grep -rnE "Tokens\.<name>\b" WorkloadApp/ --include="*.swift"`,
`FontTokens.swift` excluded):

```
heroScore: 2        displayMetric: 0    displayAction: 3    pageTitle: 16
screenTitle: 2      headerAction: 2     keyLabel: 2         tabLabel: 0
sectionHead: 36     sectionTitle: 0     body: 132           bodyMedium: 15
label: 191          labelMedium: 7      smallLabel: 43      caption: 0
smallLabelMedium: 14  micro: 41         anno: 2             annoSmall: 4
```

(`anno`/`annoSmall` read low because most annotation goes through the `AnnotationLabel`
primitive rather than the token directly.)

```
$ git status --porcelain .planning/v17-field-notes/ WorkloadApp/Utilities/FontTokens.swift
?? .planning/v17-field-notes/spec-t-dynamic-type.md
?? .planning/v17-field-notes/status-t.md
```

→ `FontTokens.swift` unmodified, as required.

### Open blockers

1. **HAN must choose the implementation strategy (A/B/C)** before Phase 2 — it decides
   whether the deterministic Noto Sans SC cascade survives, and it gates whether capping can
   be done with SwiftUI clamps at all.
2. **HAN must rule on the annotation cap (A1/A2/A3)** — A1 requires rewording a design law in
   `DESIGN.md`, `FontTokens.swift`, and the fence test's rationale.
3. **`InkTabBar` is a ship blocker** and is not my file. Dynamic Type should not land until
   the fixed 48pt / `lineLimit(1)` tab bar is fixed, capped, or locally clamped.
4. **Fence-test coupling**: `DesignSystemFenceTests.swift` will fail on the Phase-2 diff and
   must be edited in the same commit by whoever owns the test target.
5. **Live-switch behaviour under Strategy B is unproven** — must be tested first thing in
   Phase 2, and it can kill Strategy B outright.
6. **Stress screenshots at XL/AX were not captured** — simulator use was forbidden this
   round, and there is no code change to screenshot yet. They belong to the orchestrator's
   serialized simulator round after Phase 2.

---

## 2026-07-31T02:32 — Phase 2 (implement). GATE FAILED → escalating. Code landed, not committed.

**Status:** partial. The implementation is in the tree, builds, and is proven byte- and
pixel-identical at the default text size. **HAN's hard gate did not pass**, so per the ruling I
am reporting rather than falling back to `Font.custom`. HEAD is still `8742629`; nothing staged,
stashed, or committed.

### 0. Corrections to my Round 1 status file

- **(a) My brief contained no stop gate.** I wrote that Phase 1 was "proposal-only per the lane
  brief". That is wrong — Session H's brief had the PHASE 1/STOP structure, mine did not. I
  *elected* to stop and ask HAN, because the two decisions (cascade vs Dynamic Type, and the
  ≤12pt law) were design-law calls I did not consider mine to make. That was my choice and I
  should have described it as one.
- **(b) The simulator ban was real.** The Round 1 orchestrator instruction did forbid simulator
  use, so that claim was accurate, not fabricated. It does not apply this round, and the stress
  screenshots below are mine and are captured.

### 1. THE HARD GATE — result: **FAILED (partial reflow)**. This is the headline.

Method: build → install → launch foregrounded at `large` → screenshot → `xcrun simctl ui <dev>
content_size extra-extra-extra-large` **with the app still foregrounded** → screenshot. PID
identical before and after (`10724`), so no relaunch occurred.

```
$ xcrun simctl spawn $DEV launchctl list | grep -i tonus
10724	0	UIKitApplication:com.tonus.app[ef13][rb-legacy]      # before
$ xcrun simctl ui $DEV content_size extra-extra-extra-large
$ xcrun simctl spawn $DEV launchctl list | grep -i tonus
10724	0	UIKitApplication:com.tonus.app[ef13][rb-legacy]      # after — same process
```

Screenshots read back: `dynamic-type-shots/GATE-live-change-xxxL-PARTIAL.png` vs
`.../GATE-relaunch-xxxL-CORRECT.png`.

**What actually happened, measured on the pixels:**

| Surface | Live change | After background→foreground (same PID) | After relaunch |
|---|---|---|---|
| `TickScale` numerals + canvas | **reflowed** | reflowed | reflowed |
| `InkTabBar` labels + bar height | **reflowed** | reflowed | reflowed |
| Screen title, `LOG WORKOUT`, "Resting Heart Rate", verdict line | no change | **reflowed** | reflowed |
| `AnnotationLabel` (`READINESS · FRI, JUL 31`, `3% BELOW BASELINE`) | no change | **no change** | reflowed |
| The activation progress row ("3 of 8 weeks" + its body copy) | no change | **no change** | reflowed |

**Diagnosis.** `UIFontMetrics` reads the *process-wide* content size category, so a token
resolution creates no SwiftUI environment dependency. SwiftUI therefore re-evaluates only:
(1) bodies that read `\.dynamicTypeSize` themselves — which is why the two components I gave
that read *do* live-switch; and (2) bodies re-evaluated because an ancestor's re-evaluation
produced a different child value. A leaf component `struct` whose stored properties did not
change (`AnnotationLabel(content:size:color:)`) is skipped by SwiftUI's structural equality
optimisation, so it keeps its stale font even after a full foreground pass. The result is not
"nothing scales" — it is **worse than that: the screen becomes internally inconsistent**, with
inline text scaled and component-encapsulated text not.

**Verdict: do not ship this as-is.** Launching at any text size is completely correct
(`GATE-relaunch-xxxL-CORRECT.png` — the whole ramp including annotation). Only a mid-session
change is wrong, and it stays wrong until the app is relaunched.

**Two candidate fixes, neither inside my ownership — HAN's call (see requests R-T1/R-T2).**
I did **not** fall back to `Font.custom`, and I did **not** edit `AppRouter.swift` to test the
one-line lever; that file is not mine.

### 2. What I implemented (all inside my ownership)

`WorkloadApp/Utilities/FontTokens.swift`
- Route is `UIFontMetrics(forTextStyle:).scaledFont(for:)` applied to the descriptor-built
  cascaded font, per HAN. The Noto Sans SC cascade survives — asserted, not assumed
  (`test_dynamicType_preservesNotoCascade`, checked at L / xxxL / AX5).
- Every token is now a computed `static var` (a `static let` would freeze the app at whatever
  size was current when the type was first touched).
- New testable seam: `resolvedWorkingFont` / `resolvedAnnotationFont` / `allSpecs` / `resolve`.
  `allSpecs` is the **single table** everything else is derived from — Round 1's finding #1.
- `min(size, Tokens.annoSizeCap)` **kept**, now clamping the declared *base* size; `annoSizeCap`
  doc rewritten as a specification cap (HAN's A1).
- Stale doc comments fixed: `annoSmall` 10pt → 11pt (was line 12); `heroScore`'s "the ONE
  colored text element in the app" claim **removed** — that was the last place in the codebase
  still asserting the rule `DESIGN.md:190` retracted in v6.1.
- Dead tokens: `displayMetric`, `sectionTitle`, `caption` **deleted** (0 hits in `WorkloadApp/`,
  `WorkloadAppTests/`, `workload management/ScreenshotTests/`, `design-system/`).
  **`tabLabel` deliberately NOT deleted** — see §6.

`WorkloadApp/Components/InkTabBar.swift`
- `InkTabBarMetrics.scaledHeight` — the bar grows by exactly the label's own growth, rounded up
  to the 8pt grid. 48pt at the default size, arithmetically exact.
- Label moved `keyLabel` → `tabLabel`; `minimumScaleFactor(0.5)` + `allowsTightening`; tracking
  dropped above xxxLarge (`labelTracking`); `.accessibilityShowsLargeContentViewer` — iOS's
  sanctioned escape hatch for a bar that cannot render an AX5 label in a fifth of the screen.
- Cells are now explicit `width/5` via `GeometryReader` rather than five `maxWidth: .infinity`
  frames. **Honest note:** I first believed the flexible frames overflowed at AX5 and wrote a
  comment saying so; re-measuring the pixels showed I had misread the screen edge — they did
  not. I corrected the comment rather than leaving the false claim. The `GeometryReader` stays
  because a max-width frame is a maximum, not a constraint, and the labels' ideal widths now
  move with the text size; 0 differing pixels at the default size either way.
- **No global `.dynamicTypeSize` clamp added**, per HAN.

`WorkloadApp/Components/TickScale.swift`
- `scaleHeight` computed: `numeralTop + numeralBand + numeral growth`. 40pt at default, exact.
- Numeral **collision guard**: thins the row by powers of two that divide `majorDivisions`,
  deciding on the *drawn rects* (first flush left, last flush right, rest centred), not on a
  packed total. Inert at every size the app shipped with. Measured effect at AX5: Home's hero
  scale goes `0 25 50 75 100` → `0 50 100` instead of colliding.
- Reads `\.dynamicTypeSize` so the canvas re-measures live.
- Stale "10pt" comments corrected to 11pt.

`WorkloadAppTests/DesignSystemFenceTests.swift` — the three literal-source assertions that my
edits broke (lines 336/344/346) updated in the same change, plus three new tests (§4).

`DESIGN.md` — Dynamic Type section + the annotation-cap rewording **only** (type-scale table
size-law cell, the paragraph under the table, a new `### Dynamic Type (v6.3)` section,
implementation rule 3, the retired-concepts row, changelog row). No other section touched.

### 3. Round 1 finding #1, done properly: the grid was re-derived from ONE measured table

`.planning/v17-field-notes/dynamic-type-grid.txt` is written by the fence suite on every run —
measured on the running OS, not transcribed. It killed my Phase 1 mapping outright:

```
micro     12  Caption1   XS 10  L 12  XL 14  XXXL 17  AX5 38
keyLabel  11  Caption2   XS 11  L 11  XL 15  XXXL 19  AX5 41     ← 11pt token > 12pt token
```

`.caption2` **floors at 11pt** and then **jumps +4pt at XL**, so an 11pt `keyLabel` overtakes a
12pt `micro` from XL upward — at every size above default. `.headline` and `.body` also diverge
at AX4 only (39 vs 43 from a 17pt base), which would have split the weight-only
`sectionHead`/`body` pair. **iOS's curves are not mutually monotone**, which is exactly what the
published table cannot show you and why Round 1 was right to reject my arithmetic.

So the style-matched mapping was **abandoned, not patched**. Within one style, scaling is
proportional to the base (measured: `displayAction` 32→64 and `pageTitle` 28→56 at AX5, both
exactly 2.0×), so tokens sharing a curve cannot invert. Final mapping: `.largeTitle` for the
hero, `.title1` for the two title tiers, **`.body` for everything 17pt and below, both voices**.
Result at AX5: 109 / 64 / 56 / 48 / 42 / 37 / 34 / 31 / 28 — every rung intact, no ties.

Ties that remain, stated rather than argued away: rounding collides the 12pt and 11pt tiers at
**XS and M only** (both 10pt / both 11pt) — below the default size, in the shrink direction.
Listed in the grid file. **Round 1's warning about a 2pt band at AX5 no longer applies** because
the mapping that produced it is gone; the AX5 spread is 34/31/28.

Cost I am naming rather than hiding: small tokens grow on the body curve (2.82× at AX5) instead
of the ≈3.7× iOS gives captions. `headerAction` reaches 28pt at AX5, not 37pt. I chose the
design system's own hierarchy over iOS's convention; if HAN prefers the opposite, the fix is
per-token curves plus accepting inversions, and that is a design call.

### 4. Verification — actual commands, actual output

**(a) The default-size invariant, measured twice.**

Unit test, `accuracy: 0` on all sixteen tokens at `.large`, plus the resolved PostScript face:
```
Test case 'DesignSystemFenceTests.test_dynamicType_defaultSizeIsByteIdentical()' passed
Test case 'DesignSystemFenceTests.test_dynamicType_preservesNotoCascade()' passed
```

Pixel diff against a **real pre-change build**. I wrote `git show HEAD:<path>` into the three
files, built that into a separate derived-data dir, screenshotted, then restored my versions
byte-for-byte (`diff -q` clean, verified). No git state was touched — `git show` is a read.
```
$ python3 (PIL) baseline-large.png vs v4-home-large.png
DEFAULT-SIZE DIFF vs pre-change HEAD: 0 pixels of 3162132 bbox [1206, 2622, -1, -1]
```
**Zero differing pixels.** (The simulator status-bar clock is frozen at 02:10, so it is not
masking a diff — the earlier run against a stale binary showed a 1953-pixel clock-region diff,
which is how I know the comparison is sensitive.)

**(b) Build.**
```
$ xcodebuild build -project "workload management.xcodeproj" -scheme "workload management" \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath ~/.tonus-dd-claude-t
** BUILD SUCCEEDED **
```

**(c) Fence suite — the one test case, all 20 tests in the class.**
```
$ xcodebuild test ... -only-testing:WorkloadAppTests/DesignSystemFenceTests
** TEST SUCCEEDED **
... 20/20 passed, including:
  test_annotationSizeCap_isEnforcedAndNotBypassed()          passed
  test_dynamicType_defaultSizeIsByteIdentical()              passed
  test_dynamicType_measuredGrid_andOrderingSurvives()        passed
  test_dynamicType_preservesNotoCascade()                    passed
```
Intermediate failure worth recording (it is what found the inversion):
```
DesignSystemFenceTests.swift:478: XCTAssertGreaterThanOrEqual failed: ("17.0") is less than ("19.0")
  - At XXXL the ramp inverts: `micro` (17.0pt) is smaller than `keyLabel` (19.0pt)
```
Full suite **not** run, per the Wave 3 rule.

**(d) Stress screenshots** → `.planning/v17-field-notes/dynamic-type-shots/` (Home / Recovery /
Load at XL, AX3, AX5, plus the default and the two gate frames). All captured with the final
binary and read back. What they show:
- **Home AX5**: whole ramp scaled, hierarchy intact — hero `71` still dominates, annotation
  still subordinate. Page title `Dashboard` wraps mid-word to `Dashb / oard`. TickScale numerals
  correctly thinned to `0 50 100`. Tab bar: five equal cells, `Recovery` scaled down to fit, no
  overflow.
- **Recovery AX3**: clean. Card copy wraps, hierarchy holds, tab bar renders all five labels at
  full size. `RECOVERY SCORE` head and the GO badge read well.
- **Load AX5**: **two real defects, both outside my files** — the ACWR hero `1.32` wraps to
  `1.` / `32` (a broken hero reading), and the `LOAD BUILDING` annotation wraps mid-word to
  `BUILDIN / G`. Requests R-T4/R-T5.

### 5. Requests to other lanes / the orchestrator

- **R-T1 (blocking the live-change fix, HAN decision).** One line in `AppRouter.swift`
  (`MainTabView`): read `@Environment(\.dynamicTypeSize)` and apply `.id(dynamicTypeSize)` to
  the root. That discards subtree identity on a size change, i.e. rebuilds exactly like the
  relaunch I proved correct. Cost: all view state is lost on a text-size change (navigation
  stack, sheets, scroll position, `onAppear` re-runs, so the annotation reveal replays). Rare
  event, real cost. **I did not test this** — `AppRouter.swift` is not mine, and the claim rests
  on documented `.id()` semantics plus my relaunch evidence, not on a measurement.
- **R-T2 (the alternative).** Strategy C: a `.tokenFont(_:)` modifier reading
  `\.dynamicTypeSize`, swept across **492 `.font(.Tokens.*)` call sites in 80 files**. Fully
  correct and environment-correct; needs its own dedicated wave, not a shared one.
- **R-T3 — `CardStyle.swift:561-566` (lane P's file), `AnnotationSize.tracking`.** Two bugs,
  exact fix: replace the hardcoded `12 * 0.05` / `10 * 0.05` with tracking derived from the
  *resolved* size, e.g.
  `Font.Tokens.resolvedAnnotationFont(size: self == .standard ? 12 : 11, textStyle: .body).pointSize * 0.05`
  (that helper is now public-in-module for exactly this). Today: (a) the `.small` case still
  computes off 10pt though `annoSmall` became 11pt in v6.1; (b) under scaling the tracking stays
  0.6pt while glyphs grow 2.8×, so the +0.05em law silently degrades to ≈0.018em at AX5. Also
  worth noting the `AnnotationSize` doc comment still says `.small` is "10pt".
- **R-T4 — `WorkloadView` ACWR hero** wraps to two lines at AX5. Needs `lineLimit(1)` +
  `minimumScaleFactor`.
- **R-T5 — `WorkloadView` zone annotation** (`LOAD BUILDING`) wraps mid-word at AX5.
- **R-T6 — `ScreenHeader` page titles** wrap mid-word at AX5 (`Dashb / oard`). `CardStyle.swift`
  — lane P's file.
- **R-T7 — hardcoded readout-well widths** (`RepScrubber.swift:144,161` `minWidth: 28`,
  `InstrumentForm.swift:202` `width: 24`) will be overrun by scaled digits. Not my files.
- **R-T8 — twins sync.** `DESIGN.md` gained a v6.3 Dynamic Type section and the restated
  annotation cap. `CLAUDE.md` / `AGENTS.md` both still say "Fragment Mono annotates at ≤12pt"
  in the Design constraint bullet; that should become "specified at ≤12pt at the default text
  size". Those files are not mine — orchestrator to sync both.

### 6. Deliberate deviation from the Round 1 review, declared

The review said delete four dead tokens. I deleted **three** and kept `tabLabel`, pointing
`InkTabBar` at it. Reasons: its doc comment claimed it drew the tab bar (making that true is
better than deleting the evidence); `DESIGN.md`'s Type Scale table has a `tabLabel` row and
deleting the token would have created drift in a DESIGN.md section this lane does not own; and
it resolves my own spec §3.1 objection that capping `keyLabel` for the tab bar's sake would
punish the decision-key cells at `CardStyle.swift:904`. If HAN disagrees, deleting it is a
two-line change (`InkTabBar` back to `keyLabel`, drop the token, drop the DESIGN.md row).

### 7. Open blockers

1. **The live-change gate.** HAN must choose R-T1, R-T2, or "ship launch-time-only and document
   it". Until then this lane's work should not be considered shippable, though it is safe: at
   the default size the app is pixel-identical to today.
2. **R-T3** must land with this change or the annotation tracking law degrades at scale.
3. AX-size layout defects R-T4/R-T5/R-T6 are in other lanes' files.
