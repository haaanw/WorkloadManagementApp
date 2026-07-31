# Session H — rich chart detail views (glance / zoom split)

Wave 3, branch `v1.7-field-notes`. One writer per file; entries appended in order.

---

## 2026-07-30T23:56 — PHASE 1 COMPLETE (spec written), STOPPED for HAN approval

### Status: `awaiting-han`

### What changed

**One file written:** `.planning/v17-field-notes/spec-h-charts.md` (~600 lines), plus this
status file.

**No Swift file, no `.pbxproj`, no `.xcstrings`, no simulator, no build, no commit.** That was
the Phase-1 instruction and it was followed literally.

### What the spec contains

1. **A verified audit of the current code** — mount points (`DashboardView.swift:253-258` is the
   only route into either detail view), the two detail views as shipped, the three glance charts,
   and the existing `ChartTooltipGesture`.
2. **The glance-freeze contract** — `HRVTrendChart.swift` and `SleepTrendChart.swift` end Phase 2
   with a clean `git diff`. They are shared components mounted on Recovery *and* inside the
   detail views, so any edit changes the glance. Detail charts are therefore new files.
3. **A shared detail-screen structure** — context stamp, stats band (unchanged), zone/reference
   keys above the plot, 224pt scrubbable chart, persistent debossed readout well, reason-tree
   condition section, three expandable About rows.
4. **Full per-chart specs** for `SleepDetailChart` (6 h + 7 h rules, restored three-swatch zone
   key, scrub) and `HRVDetailChart` (baseline ±1SD as bounds not a fill, open-circle crosshair,
   `HRV_BASELINE: TRUE` reason tree).
5. **The 6 h / 7 h / 7.5 h reconciliation** with a recommendation and two fairly-stated
   alternatives (§7).
6. **A complete string table** — 16 new keys with en + zh-Hans values, 7 reused verbatim.
7. **A law-citation index** (§10) mapping every element to the DESIGN.md v6.2 clause that
   licenses it.
8. **The file list** with NEW vs MODIFIED and the four-edit `.pbxproj` recipe (§9).
9. **Nine open questions** (§12) and **six requests to other lanes** (§13).

### Three findings that changed the spec

**(a) The `7D AVG: 51 MS` overlap nit is already fixed — no action needed.**
`status-orchestrator-wave2.md` lists it as open. It was fixed afterwards in commit `3993bd1`
("chart keys out of the plot", v6.1): `HRVTrendChart.swift:42-48` and
`SleepTrendChart.swift:48-52` now render their keys above the plot. Working tree clean for both.
The spec converts this into a binding rule for the detail charts (no in-plot `RuleMark`
annotations).

**(b) 7.5 h has no basis anywhere in Tuwa.** `RecoveryScoreEngine.sleepDurationToScore`
(`RecoveryScoreEngine.swift:224-234`) is a 6/7/8/9 curve — 7 h is the 70-point knee, 6 h ends
the steep segment. The shipping (already-translated) `sleep.detail.explanation` names 6 and 7
explicitly. The three orphaned legend keys name 6 and 7. `grep` for `7.5` returns nothing
sleep-related. So the framing "target = goal line, bands = physiology" produces no conflict
here — the target and the physiology knee are the same number, and what the glance is actually
*missing* is the 6 h floor. Recommendation: plot 6 h + 7 h, and put the 7–9 h sleep-science
range in the About prose instead of on the plot. The alternative HAN literally asked for (S-2)
is specced and costed honestly in §7.4.

**(c) `RecoverySnapshot.sleepScore` is nil in production.** Written only by `MockDataSeeder`
and by sync pull; `RecoveryPipeline` never sets it. Nothing in the spec reads it — which is why
`SCORE_CONTRIB` needs a visibility change on the engine (Q2) rather than a field read.

### Verification (actual commands, actual output)

No build was run — Phase 1 produced no code. The verification that *was* run is the evidence
gathering the spec rests on:

```
$ python3 -c "... json.load('WorkloadApp/Resources/Localizable.xcstrings') ..."
== sleep.chart.legend.excellent | en '7h+' translated | zh-Hans '7 小时+' translated
== sleep.chart.legend.good      | en '6–7h' translated | zh-Hans '6–7 小时' translated
== sleep.chart.legend.poor      | en '<6h' translated  | zh-Hans '<6 小时' translated
locales present across the catalog: ['en', 'zh-Hans']   sourceLanguage en   1017 keys
```
→ **All three orphaned keys verified present and translated.** Named exactly in spec §1.4.

```
$ git log --oneline -3 -- WorkloadApp/Components/HRVTrendChart.swift
3993bd1 fix(v1.7): v6.1 readability — drop the one-colour cap, 11pt annotation, chart keys out of the plot
6788e3b feat(v1.7): Field Notes v6 adoption across app surfaces (Wave 2)
ebdbdcb feat(ui): app-wide elevation pass on non-logging screens (Lane C)

$ git status --porcelain WorkloadApp/Components/ WorkloadApp/Views/Dashboard/
(no output)
```
→ Finding (a) confirmed: the fix is committed and the tree is clean.

```
$ grep -c "PBXFileSystemSynchronizedRootGroup" ".../project.pbxproj"   → 4 matches
$ sed -n 424,436p ".../project.pbxproj"
  → the two synchronized groups are ScreenshotTests and ../WorkloadAppTests ONLY
$ grep -n "HRVTrendChart.swift" ".../project.pbxproj"
  71: PBXBuildFile · 260: PBXFileReference · 504: Components group child · 1104: Sources phase
```
→ App sources need **explicit four-part registration**; the three new files cannot be added by
dropping them on disk. `Components` group id = `62324BE72F66CB0E00A9C2BE` (line 498).

```
$ grep -rn "SleepDetailView\|HRVDetailView" WorkloadApp --include="*.swift"
  DashboardView.swift:255-256 are the only mounts; RecoveryView has no route (Q7).
```

**Ownership boundary proof (run at end of round):**

```
$ git diff --quiet -- WorkloadApp/Components/HRVTrendChart.swift \
    WorkloadApp/Components/SleepTrendChart.swift \
    WorkloadApp/Components/ChartTooltipOverlay.swift \
    WorkloadApp/Views/Dashboard/HRVDetailView.swift \
    WorkloadApp/Views/Dashboard/SleepDetailView.swift \
    WorkloadApp/Views/Workload/WorkloadView.swift \
    "workload management/workload management.xcodeproj/project.pbxproj"
H-OWNED SOURCE FILES: UNTOUCHED (exit 0)
```

(Other Swift files show as modified in `git status` — `CardStyle.swift`, `RadialPicker.swift`,
`WeeklySummaryCard.swift`, `ActiveWorkoutSheet.swift`, `TemplatePickerSheet.swift`,
`Localizable.xcstrings`, etc. Those are concurrent lanes P and T, not H. H wrote zero source.)

### Files changed this round

- `.planning/v17-field-notes/spec-h-charts.md` (new)
- `.planning/v17-field-notes/status-h.md` (new — this file)

### What I did NOT do

- No Swift written, no build, no test, no simulator, no screenshot, no commit — Phase 1 only.
- **`LoadTrendChartView` gets no change**, though it is in H's ownership list: it is a glance
  chart under HAN's freeze, has no detail view to zoom into, and its real defect (the missing
  `series:` discriminator) was already fixed by the orchestrator in Wave 2. A Load detail view
  is separate, larger work — flagged, not started.
- Did not verify the zone-key row's zh-Hans layout (three cells in one `HStack` at `annoSmall`
  is the overflow risk) — that needs the simulator, which is serialized to a later round.
- Did not resolve Q1/Q2 by acting: both need files outside H's ownership
  (`ChartTooltipOverlay.swift`, `RecoveryScoreEngine.swift`). Filed as requests in spec §13.

### Blockers

**Q0 (the 7.5 h decision) blocks Phase 2 on the sleep chart** — it determines the plot furniture,
whether two shipped legend keys get rewritten in two locales, and whether the shipped
`sleep.detail.explanation` copy has to change. Everything else can proceed on the
recommendations, but Q1 and Q2 change the file list, so an answer to those before Phase 2 avoids
rework.

**Awaiting HAN on the nine open questions in spec §12.**

---

## Session H — PHASE 2 (build) — 2026-07-31T01:52

Round 2. HAN's override implemented, Round 1 review findings fixed in the spec **and** the
build, three new files registered in `.pbxproj`, build green, targeted engine test green.
Nothing committed, staged or stashed; no full suite run.

### The sleep target migration (HAN override — 6 h floor + 7.5 h target, app-wide)

Implemented as one constant with three consumers, so it cannot half-migrate again:

| Site | Before | After |
|---|---|---|
| `RecoveryScoreEngine.sleepTargetHours` | did not exist | `7.5` (new `static let`, beside the curve) |
| `RecoveryScoreEngine.sleepDeficitFloorHours` | did not exist | `6` (new `static let`) |
| `RecoveryScoreEngine.sleepDurationToScore` | `private`, knee at 7 h | **non-private**, knee at 7.5 h |
| `SleepTrendChart` (glance) `RuleMark` | `.value("Target", 7)` | `.value("Target", RecoveryScoreEngine.sleepTargetHours)` |
| `SleepDetailChart` (new) | — | same constant, same `text3`, plus a 6 h `zoneDanger` floor rule |
| `sleep.chart.legend.good` | `6–7h` / `6–7 小时` | `6–7.5h` / `6–7.5 小时` |
| `sleep.chart.legend.excellent` | `7h+` / `7 小时+` | `7.5h+` / `7.5 小时+` |
| `sleep.chart.legend.poor` | `<6h` / `<6 小时` | unchanged |
| `sleep.chart.annotation` | `7h target` / `7 小时目标` | `7.5h target` / `7.5 小时目标` |
| `sleep.detail.explanation` | "…The 7-hour target line is your minimum threshold…" | rewritten, en + zh-Hans |

**The new curve**, and the judgement call inside it:

```
<5h            → 10
5h  ..< 6h     → 10 + (h-5)*30      // 6h  = 40   (unchanged)
6h  ..< 7.5h   → 40 + (h-6)*20      // 7.5h = 70  (THE KNEE — was 7h)
7.5h..< 9h     → 70 + (h-7.5)*20    // 9h  = 100  (unchanged)
9h+            → 100
```

Keeping the old `8h = 90` anchor alongside a 7.5 h knee would have required a 40 pts/h segment
immediately above the target — steeper than the segment below it, i.e. a cliff that rewards the
half-hour *after* the target more than the hour *before* it. I kept the slope monotonic instead.
**Consequence HAN should know: 8 h now scores 80 where it previously scored 90.** 5 h, 6 h and
9 h are unchanged; the composite is only 25% sleep, so the practical shift is ≤2.5 points at 8 h.

### Remaining 7-hour assumptions — NOT fixed, outside my ownership (REPORTED)

Grepped the whole app (`WorkloadApp`, Swift + xcstrings, en + zh-Hans). All localized copy is
clean. Exactly two code sites remain, both outside my file list:

1. **`WorkloadApp/Services/ReasoningEngine.swift:65-67`** —
   `// Sleep — target is 420 min (7 hours)` / `let delta = sleep - 420`. This drives the
   Dashboard's **user-facing** sleep factor row ("90 min below average") and its
   positive/negative direction. It is the one genuinely half-migrated site: the Dashboard will
   call a 7 h night "on target" while the chart and the score call it short. **Needs 420 → 450
   plus the comment.** Its test comment `WorkloadAppTests/ReasoningEngineTests.swift:139`
   ("5.5h = 90 min below 7h target") becomes wrong at the same moment — the assertion itself
   only checks `.negative`, so it will still pass, which is exactly why it needs a human to look.
2. **`WorkloadApp/Utilities/MockDataSeeder.swift:88`** — `baseSleep = 420.0 + phase * 6`.
   Screenshot/demo data only. With a 7.5 h target the seeded nights now sit just *below* target,
   which will show up in App Store screenshots (Session F's pipeline). Low priority, but it
   changes what the marketing shots say.

### Files changed

**New (3), all registered in `.pbxproj`** (backed up first to
`…/scratchpad/project.pbxproj.pre-h.bak`; hand-authored IDs `DD030101…`/`DD030102…`, four edits
each, Xcode never opened):

- `WorkloadApp/Components/ChartDetailPrimitives.swift` — `SectionEyebrow`, `ChartReadoutWell`,
  `ChartKeyCell`/`ChartPlotKey`, `ReasonTreeSection`, `DetailDisclosureItem`/`DetailDisclosureList`
- `WorkloadApp/Components/SleepDetailChart.swift`
- `WorkloadApp/Components/HRVDetailChart.swift`

**Modified (8):**

- `WorkloadApp/Services/RecoveryScoreEngine.swift` — the two constants, the knee, visibility
- `WorkloadApp/Components/SleepTrendChart.swift` — **value only** (+ two comment lines)
- `WorkloadApp/Components/ChartTooltipOverlay.swift` — `clearsOnEnd: Bool = true`, additive
- `WorkloadApp/Views/Dashboard/SleepDetailView.swift` — rebuilt on the new skeleton
- `WorkloadApp/Views/Dashboard/HRVDetailView.swift` — rebuilt on the new skeleton
- `WorkloadApp/Views/Recovery/RecoveryView.swift` — `NavigationLink` + `.navigationDestination` only
- `WorkloadApp/Resources/Localizable.xcstrings` — 4 values rewritten, 16 keys added
- `WorkloadAppTests/RecoveryScoreEngineTests.swift` — the curve test, re-pinned
- `workload management/workload management.xcodeproj/project.pbxproj` — 3 files × 4 edits

### Round 1 review findings — all eight fixed

1. **`slope(of:)` does not exist.** `HRVDetailView.trendToken` calls
   `RecoveryScoreEngine.computeSlope(values:)` (`:197`). The spec's "six lines recomputed
   locally" allowance is deleted (spec amendment B1, and §5.3 rewritten in place).
2. **§8's string rule was unsatisfiable for its own key #16.** Restated as *locale-pinned
   resolution required*; `HRVDetailChart.baselineKey` uses
   `String(format: LocalePinnedStrings.localized("hrv.chart.annotation.band", locale: locale), …)`.
   No bare `String(localized:)` anywhere in the new code.
3. **Middle key cell keys nothing** → ships with no swatch glyph. `ChartKeyCell.swatch` is
   `Color?`; cells 1 and 3 carry the literal colours of the two rules actually drawn.
4. **Rule colour**: 7.5 h is `ColorTokens.text3` in **both** charts — stated in the spec and in
   both source comments. Picked text3 because it is what the glance already ships, keeping the
   freeze a value-only change. The 6 h floor is the only zone-coloured rule (`zoneDanger`).
5. **Row primitive**: disclosure rows use `.buttonStyle(.rowWell(cornerRadius:))`, not
   `.pressable(scale: 1, opacity: 0.6)`.
6. **Citation**: `LoadTrendChartView` is in `WorkloadView.swift`. Fixed in the spec.
7. **Unguarded micro-caps**: both eyebrows now go through the new `SectionEyebrow`, which guards
   tracking **and** case on `isLatin`. The two sites lane P routed me are gone.
8. **xcstrings re-read before editing**: 1017 keys in the working tree vs 1097 at HEAD (82
   orphans removed by another lane, 2 keys added, 3 values changed by another lane). All three
   legend keys verified present before reuse. **Incident, disclosed in full below.**

### Incident — xcstrings reformat, detected and repaired

My first edit re-emitted the whole file with `json.dump`, which changed the separator style
(`" : "` → `": "`), collapsed Xcode's multi-line empty objects, and re-sorted 1033 keys under
Python's byte ordering instead of Xcode's. Result: a 21,707-line diff. I did **not** try to
`git checkout` the file (forbidden, and it would have destroyed another lane's uncommitted
edits anyway). I reconstructed it textually from `git show HEAD:…` — keeping HEAD's exact
formatting and block order, deleting the 82 orphan blocks the other lane had removed, and
re-emitting only the 7 changed and 18 new blocks in the matching style — then asserted the
parsed content equalled my intended content byte for byte before writing.

**Final diff is 281 insertions / 268 deletions**, and the pre-existing (other lane's) changes
are preserved: `Series`, `Unchanged week over week`, and the three `prs.dualRun.*` values are
all still present with their working-tree values. Nothing was lost — but a reviewer should
still eyeball this file's diff, because the repair is reconstruction rather than an untouched
original.

### What is NOT built

- **`LoadTrendChartView` gets no detail view.** Spec §9 said this; unchanged.
- **"Tap the selected day to clear"** (spec §4.3) is deliberately dropped — it needs either a
  second parameter on `ChartTooltipGesture` (grant was `clearsOnEnd` only) or a proxy binding
  that toggles repeatedly as a drag crosses the selected day. The well always reads something
  instead: scrub to the most recent day and it stamps `● NOW`.
- **No simulator run, no zh-Hans visual check, no Reduce-Motion check.** The three-cell key at
  `annoSmall` in zh-Hans is the most likely overflow; it is wrapped in `ViewThatFits` with a
  vertical fallback, but that has not been seen on a device.
- **Fence suite not run** (the brief allows one targeted test and I spent it on the engine).
  Static self-audit instead: grepped all changed files for every banned pattern in
  `DesignSystemFenceTests` — curve/spring literals, `withAnimation {`, `.shadow(`, hex literals,
  `.system(`, `panelStyle(`, `tickSpring`, `FragmentMono`/`IBMPlexMono`/`SourceSerif4`/`Alpino`,
  hand-typed `cornerRadius:` numerics — **zero hits**. The only `spacing:`/`padding` integer
  literals in the new code are `0`, which is below the fence's ≥4 threshold.

### Verification (actual commands, actual output)

```
$ cd "/Users/hanwen/dev/Tonus/workload management" && xcodebuild build \
    -scheme "workload management" \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
    -derivedDataPath ~/.tonus-dd-claude-h
…
Touch /Users/hanwen/.tonus-dd-claude-h/Build/Products/Debug-iphonesimulator/workload management.app
** BUILD SUCCEEDED **
```

```
$ xcodebuild test -scheme "workload management" \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
    -derivedDataPath ~/.tonus-dd-claude-h \
    -only-testing:WorkloadAppTests/RecoveryScoreEngineTests
** TEST SUCCEEDED **
Test case 'RecoveryScoreEngineTests.test_sevenAndAHalfHourSleep_isTheSeventyPointKnee()' passed …
Test case 'RecoveryScoreEngineTests.test_sleepCurve_anchors()' passed …
Test case 'RecoveryScoreEngineTests.test_missingHRV_weightRedistributed()' passed …
Test case 'RecoveryScoreEngineTests.test_perfectInputs_highScore()' passed …
… 27 cases, all passed, 0 failures
```

Glance-freeze contract:

```
$ git diff --quiet -- WorkloadApp/Components/HRVTrendChart.swift \
    WorkloadApp/Views/Workload/WorkloadView.swift \
    WorkloadApp/Views/Dashboard/DashboardView.swift \
    WorkloadApp/Components/RecoveryLoadChart.swift \
    WorkloadApp/Utilities/ColorTokens.swift WorkloadApp/Utilities/FontTokens.swift \
    DESIGN.md WorkloadAppTests/DesignSystemFenceTests.swift \
    WorkloadApp/Components/InkTabBar.swift
H-FROZEN FILES UNTOUCHED: OK
```

(`CardStyle.swift` IS dirty in the working tree — that is lane P's REQ-D2 `ScreenHeader` fix,
verified by reading the diff. Not mine.)

xcstrings integrity:

```
$ python3 -c "… len(strings) …"
1033   (1017 + 16 new; 4 values rewritten)
```

### Open blockers / requests

1. **`ReasoningEngine.swift:65-67` must move 420 → 450** or the Dashboard's sleep factor row
   contradicts the chart and the score. Not my file. This is the one item that keeps the
   migration half-done.
2. **`MockDataSeeder.swift:88`** — seeded nights now sit below target; affects Session F's
   screenshots.
3. **zh-Hans layout check of the three-cell plot key** at `annoSmall`, plus a Reduce-Motion pass
   on the readout well. Deferred to the orchestrator's serial gate.
4. **Session T**: the three-cell key in a single `HStack` at `annoSmall` is the first thing that
   will overflow at accessibility sizes. `ViewThatFits` gives it a vertical fallback, so it
   degrades rather than clips — worth confirming against T's final scaling decision.

2026-07-31T01:52
