# Wave 2 — orchestrator verification record

Branch `v1.7-field-notes`. Lanes B/C/D (app surfaces) + E (website). Verification run by the
orchestrator independently, never inherited from a lane summary (ground rule: re-run, don't trust).

---

## Outcome

**Wave 2 gate: PASSED**, with four defects found and fixed by the orchestrator and three
design-law questions escalated to HAN (below). 54 lane-modified files + 4 orchestrator-modified.

### Independent verification (actual commands, from `workload management/`)

```
xcodebuild test -scheme "workload management" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -derivedDataPath ~/.tonus-dd-claude -only-testing:WorkloadAppTests
```
→ `** TEST SUCCEEDED **`, **762 passed / 0 failed**, zero compile errors. Exact parity with the
Wave 1 baseline (762/0/2), correct for a restyle that adds no tests. Re-run three times: after the
lanes' edits, after the locale fix, and after the chart fixes. Green each time.

**Design-system fence suite: 17/17 green**, including all six new v6 fences and
`noHardcodedColors` / `noSystemFonts` / `noShadowModifiers` / `cornerRadii` / `faceName` /
`alpinoBanned` / both spacing-grid fences. These subsume the manual law sweep I had started, and
are stronger evidence than grepping.

**Frozen-file boundary: clean.** Verified per-file with `git diff --quiet`: `CardStyle.swift`,
`ColorTokens.swift`, `FontTokens.swift`, `DesignSystemFenceTests.swift`, `DESIGN.md`, `CLAUDE.md`,
`AGENTS.md`, `.pbxproj` — all untouched by the lanes. Zero violations across three concurrent
writers. (`CardStyle.swift` was later edited by the **orchestrator** for the locale fix below.)

**Functional, not just structural — `ScreenshotTests` 13/13 passed.** The app launches, navigates
all five tabs, and opens sheets (active workout, exercise picker, movement bank, template picker).
No lane achieved this; all three died before their visual pass.

**Website (Session E), re-verified independently:** `npm run build` → **66 pages** (matches);
`npx astro check` → **0 errors / 0 warnings / 0 hints** (147 files). Legal-route content parity
proved the hard way — built the pre-change tree in a git worktree at `bfed11f` and diffed rendered
text: **`/terms`, `/zh/terms`, `/fr/terms`, `/privacy`, `/support` all TEXT IDENTICAL.** This
mattered because E *did* modify `SupportPage.astro` and `LegalPageLayout.astro`, so a
source-level argument would not have been sufficient. Website commit `b4d2f25` is local and
**unpushed** (`origin/main...main` = `0 1`, no remote branch contains it); parent-repo reflog head
still `90ca129`, confirming E ran no git write in the shared app tree.

---

## Orchestrator's own error — recorded because it cost the lane reports

I told all three iOS lanes to run the full `xcodebuild test` suite as their final step. Three
concurrent xcodebuild invocations plus three simulator clones on one machine starved each other
past the 600s stall watchdog and **all three lanes were killed at that exact point.** Their edits
survived; their reports did not. C and D were resumed and wrote their files. **Session B's
transcript was unrecoverable**, so `status-b.md` is my reconstruction from the diff and cannot
state B's intent — notably whether its four untouched files were deliberate or unreached.

**Rule for Wave 3: lanes do not run the full suite. The orchestrator verifies serially, once.**

---

## Defects found and fixed by the orchestrator

### 1. zh-Hans live-switching regression (~21 sites) — flagged independently by BOTH C and D

`AnnotationLabel` accepted only a resolved `String`, which pushed call sites into
`String(localized:)`. That reads the **process** locale, while the app pins its language with
`.environment(\.locale, localeManager.activeLocale)` (`AppRouter.swift:46`) — so strings that were
`Text("key")` before Wave 2 stopped following an in-app language switch. Not theoretical: the
codebase already documents this exact trap in three places (`SpikeAlertBanner.swift:10`,
`SyncStatusView.swift:10`, `MovementBankView.swift:674`) and uses `LocalePinnedStrings` to avoid it.
29 environment-observing `Text("key")` sites were converted during the wave; D correctly rescued 8
via `LocalePinnedStrings`, leaving ~21 regressed.

Fixed at the chokepoint rather than per-call-site: added **`AnnotationLabel(key: LocalizedStringKey)`**,
which renders via `Text(key)` and so observes the pinned locale. The label is explicit (`key:`)
rather than an overload **on purpose** — with an unlabeled overload a bare string literal resolves
to `String` (the default literal type) and would silently render the raw key text. Migrated 16
sites to `key:`; verified the 3 `WeeklySummaryCard` keys carry en + zh-Hans in `Localizable.xcstrings`
before dropping their redundant `defaultValue:`. Sites with a genuine `defaultValue:` that were
*already* `String(localized:)` before the wave were left alone — not regressions.

This is the one change the plan would have routed to Session A. A was launched in an earlier session
and is not resumable, so the orchestrator made it rather than ship a known zh-Hans regression.

### 2. `LoadTrendChartView` — CTL series never rendered (PRE-EXISTING, exposed by v6)

Two `LineMark`s over the same x-values with **no `series:` discriminator** collapse into one Swift
Charts series. Charts connected ATL→CTL→ATL→CTL and drew a single zigzag; the ochre CTL line
rendered nowhere. **This predates v6** — confirmed at `HEAD`, where the same structure shipped with
the warm-ink `chartATL`/`chartCTL` pair, two near-identical inks that made the artifact easy to
miss. It ships in v1.6 today.

v6 made it consequential twice over: distinct rust/ochre hues make the absence conspicuous, and
C's new series key **advertised a `● CTL` line that did not exist** — a false legend this wave
introduced. Fixed by naming both series. Verified visually: rust ATL above, smooth ochre CTL below,
zigzag gone. Sweeping every multi-`LineMark` chart found this to be the only affected site.

### 3 + 4. Trend-chart axis labels bypassed the annotation law (`HRVTrendChart`, `SleepTrendChart`)

Both used bare `AxisValueLabel()` with only `.font(.Tokens.annoSmall)`. That buys the Fragment Mono
*face* but not the uppercase transform, the tracking, or the zh-Hans guard — which DESIGN.md rule 3
requires come from the token/modifier, never the call site. Result: Recovery rendered `Jul 5` while
C's Load charts rendered `JUL 5`, so the same axis spoke in two cases on adjacent tabs. Fixed by
hosting `AnnotationLabel` inside the label closure (C's pattern, now uniform). Verified visually.

---

## Escalated to HAN — design-law questions no lane should decide

### A. `DESIGN.md` contradicts itself on metric-hue annotation, and the canonical kit contradicts both

- **Line 182** permits metric hues on "**Metric-hue annotation** (a `● READINESS` key)".
- **Line 188** says "at most **one colored text element per screen** — the hero reading."

A colored annotation key is licensed by the first and forbidden by the second. Visible consequence:
**Home renders three green text elements** (the `READINESS · THU, JUL 30` stamp, the `71` reading,
and the `GO` zone label); Recovery renders one, because B inked everything but the score there.
Both screens cite DESIGN.md.

Decisive new evidence: the design system's **own** iOS specimen
`design-system/ui_kits/ios-app/LoadScreen.jsx:14-19` puts **three** colored text elements on one
card — `ACWR ●` in `--metric-load`, `1.23` in `--metric-load`, `LOAD STEADY` in `--zone-optimal` —
so the strict one-element reading is contradicted by the reference kit itself. C reported the same
conflict from the tiles (the kit hues all three metric tiles). Recommended resolution: budget one
colored **reading** per screen and state that a metric-hue annotation key does not consume it —
i.e. reword line 188 and keep line 182. The alternative (ink the stamps) needs line 182 struck,
since nothing could then use it.

### B. Needle hue: DESIGN.md and the kit disagree outright

DESIGN.md: "a metric hue never takes a live-state mark", "a needle is never a metric hue".
`LoadScreen.jsx:19` passes `hue="var(--metric-load)"` to `TickScale`. **C and B both followed
DESIGN.md** (needles stay travertine), which I endorse — but the kit will keep re-raising this until
one of the two documents is corrected.

### C. The kit fills the TSB area with `metric-sleep` at 14%

A hue-as-surface wash, which DESIGN.md's hard prohibition forbids, and semantically wrong (TSB is
not sleep). C followed DESIGN.md and kept `chartTSB`. Endorsed; flagging so the kit gets fixed.

---

## Open items carried into Wave 3

- **Lane leftovers, honestly listed.** C: most of `ActiveWorkoutSheet` (4 regions of 1,718 lines),
  one region of `ExercisePickerView`, off-token spacing in `TemplatePickerSheet`. D: `RadialPicker`
  still uses the `== "en"` idiom rather than `isLatin`. B: four files untouched with **intent
  unknown** (transcript lost) — re-inspect, do not assume complete.
- **D's judgment calls needing HAN's eye:** `SleepTrendChart`'s three-swatch zone legend was deleted
  (bars went uniform `metricSleep`), so the 6 h boundary is no longer stated — 3 xcstrings keys now
  unreferenced, reversible in ~10 lines. `DeltaIndicator`'s unfavourable colour moved
  `zoneDanger` → `zoneCaution`, softening semantics on B's `WeeklySummaryCard`.
- **D's filed requests:** REQ-D2 (`ScreenHeader.context` applies unconditional `.textCase(.uppercase)`
  — a zh violation; latent, no caller passes `context:`), REQ-D3 (`StatusBadge` unbacked, same
  contrast class as `ZoneBadge`, appears dead). Also `WeeklyZoneBadge`
  (`WeeklySummaryCard.swift:91`) may need `ZoneBadge`'s card-plane treatment.
- **Visual nits not fixed:** the `7D AVG: 51 MS` baseline annotation overlaps the HRV data dots
  (pre-existing `RuleMark` annotation placement). Home's `├─`/`└─` reason-tree stems are separated
  by working-voice headings, so the tree reads as two disconnected fragments rather than a tree —
  an aesthetic call for HAN.
- **Session E's open questions:** the DS website kit sets Fragment Mono ghost numerals at **200px**,
  violating the ≤12px mono cap stated in both `readme.md` and DESIGN.md v6 — E held the cap and left
  ghosts on the sans; needs a ruling. `--text-body` collides inside the design system itself
  (`colors.css` aliases it to a colour, `typography.css` to 17px — only import order saves it).
  Accent-as-label debt on ~40 SEO/topic pages predates v6. Not done by E: Chart.js configs in
  `src/components/charts/` may still carry old zone rgba; Instrument Sans ships on the site with no
  licence file.
- **zh-Hans has had no visual pass** in either the app or the website. The locale fix above is
  verified by construction and by a green suite, **not** by looking at a Chinese screen.

## A lane claim that did NOT reproduce — do not propagate

C reported that RTK's `grep` rewrite is lossy ("1 file vs 21"), and warned that any lane scoping
work from a plain `grep` had likely missed files. I tested the exact pattern three ways in that
directory — RTK-rewritten `grep`, `rtk proxy grep`, and `/usr/bin/grep` bypassing `PATH` — and all
three returned the **same 2 files**. The claim does not reproduce, so the alarming conclusion drawn
from it is unfounded. (Unrelated and real: `grep`'s *output formatting* is filtered enough that
piping a file list into `perl` mangled it once in this session — use explicit paths, not
`$(grep -l ...)`.)
