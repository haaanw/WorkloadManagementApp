# Screenshot story pass — 1.7.2

Drafted 2026-08-22. The framed sets are regenerated in
`appstore screenshots/1.7-{en,zh-Hans}/framed/`.

## What was wrong with the 1.7 set

Found by reading the nine published plates, not by reading the pipeline:

1. **Three of the nine plates were the same screen.** `test07_VerdictCard` called
   `saveScreenshot` twice in a row with no state change between the two calls, so plate 1
   (`VerdictMicrodose`) and plate 2 (`StrikeZone`) were the same pixels under different
   captions — and `test03_WorkoutLog` shot the same scroll position again for plate 6. The
   App Store shows the first three plates in search results, and two of those three were
   duplicates of the first.
2. **Plate 7 was an empty workout.** The caption read "Log every rep · Capture strength work
   without friction" over a blank session: `0m` elapsed, no exercises, a session-type picker.
   `test08` started a *blank* workout — correct as a smoke test, wrong as marketing.
3. **Plate 3 showed the app waiting.** The Dashboard carried "3 of 8 weeks — keep logging,
   periodization insights unlock after 8 weeks of consistent training", because the seed laid
   down 28 days and `PeriodizationEngine` needs 56.
4. **Plate 8 read "1 EXERCISES" three times.** Every seeded template held exactly one
   exercise, and half the screen was empty.
5. **No voice-logging plate** — the 1.7.2 headline feature was not in the store set at all.
6. **No plate carried the sleep hue.** Four of the five metric identities appeared; sleep did
   not.
7. **The two locales did not show the same data.** The seed used `Double.random`, so the en
   and zh-Hans runs produced different chart shapes, ACWR and durations for the same plate.

## The set as it now stands

Nine plates, under the App Store's ten-per-device-size limit. All five metric hues appear.
No two plates are the same surface.

| # | Screen | Hue | Machine key | Why it is here |
|---|---|---|---|---|
| 1 | Verdict / microdose | readiness | `match_proximity: aware` | The wedge. Adjusted number, reason line, strike-zone bar, equal-weight decision row — all in one capture. |
| 2 | Log capture (voice / text) | strain | `input: voice · text · dictation` | The 1.7.2 news, and the strongest reason for an existing logger to switch. In the first three, so it shows in search results. |
| 3 | Dashboard hero | readiness | `inputs: hrv · rhr · sleep` | The daily reading. Now with 12 weeks behind it, so no sufficiency nag. |
| 4 | Recovery signals | recovery | `baseline: 28d rolling` | HRV / RHR / sleep tiles and the HRV trend against a personal baseline. |
| 5 | Sleep detail | **sleep** | `sleep_target: 7.5 h` | New. Completes the five hues, and shows the fixed 7.5-hour target line — the honest, shipped version of the sleep story. |
| 6 | Load & progress | load | `acwr: acute 7d / chronic 28d` | ACWR, ATL/CTL/TSB, the load trend. The "one fatigue budget" claim, shown. |
| 7 | Active workout | strain | `logged: sets · reps · load` | Now started **from a template** ("RIR Strength"), scrolled past the setup chrome, so it shows real exercises and target sets. |
| 8 | Templates | load | `templates: user-authored` | "Your plan stays yours", shown as user-authored templates with real exercise counts. |
| 9 | Movement bank | strain | `catalog: 1,324 movements` | Depth. Answers "will it have my lift?" |

**Dropped from the store set** (their harness attachments are kept — they are useful
navigation smoke, they just no longer occupy store slots):

- `StrikeZone` — duplicate of plate 1; the strike-zone bar is inside plate 1.
- `WorkoutLog` — duplicate of plate 1; same surface, same scroll position.

Both are now `.excluded(reason:)` in `scripts/frame_screenshots.swift`, so the run prints the
reason instead of silently shipping them.

## Captions

Headline in Instrument Sans, subline under it, machine key in Fragment Mono — the existing
`FrameCopy` structure. Only the two new screens needed new copy; the rest are unchanged from
the 1.7 set.

| # | EN headline | EN subline | zh-Hans headline | zh-Hans subline |
|---|---|---|---|---|
| 1 | Microdose before match day | Cap the top set. Skip back-offs. | 比赛前，先做微量训练来找到状态 | 封顶最重组，跳过减重组。 |
| 2 | **Say the session. Keep the sets.** | **Speak it or type it — Tuwa writes the log.** | **说一句，训练就记好了** | **开口说或直接打字，Tuwa 帮你填好每一组。** |
| 3 | Know today's readiness | Recovery and load in one daily read. | 了解今天的准备度 | 恢复与负荷，一眼读懂。 |
| 4 | Recovery, decoded | See the signals behind today's state. | 恢复，看得懂 | 看清今天状态背后的信号。 |
| 5 | **Every night, against the target** | **Four weeks of nights on a 7.5-hour line.** | **每一晚，都对照目标** | **四周的每一晚，画在 7.5 小时这条线上。** |
| 6 | Track training load | Watch acute and chronic load move. | 追踪训练负荷 | 急性与慢性负荷尽在掌握。 |
| 7 | Log every rep | Capture strength work without friction. | 每一组都记下 | 顺手记录力量训练。 |
| 8 | Start from your own template | Your plan, ready to log. | 用你自己的模板开始 | 你的计划，随时开练。 |
| 9 | Search the movement bank | Find the lift, or add your own. | 搜索动作库 | 找到动作，或自己添加。 |

Plate 5's subline says **"a 7.5-hour line"**, not "your own target". The shipped engine scores
against a fixed target; the adaptive one is unbuilt. The caption grades to the engine. It also
says **four weeks**, not twelve — the sleep screen's own default window is 28 nights, and a
caption should not promise more than the plate under it shows.

## Seed-data changes behind the plates

All in `WorkloadApp/Utilities/MockDataSeeder.swift`, all behind `SCREENSHOT_MODE`, all
`#if DEBUG`:

- **28 → 84 days of history.** Clears the 8-week periodization gate, and gives the Load tab's
  12W range real data instead of a stub.
- **Deterministic RNG.** A seeded SplitMix64 replaces `Double.random` / `Int.random`, so the
  en and zh-Hans runs produce byte-identical data. Two localizations of one plate now show
  one athlete.
- **Squat progression lands on 140 kg.** The history used to top out near 115 kg while the
  plate advertised a 140 kg planned top set and a 142.5 kg PR. The numbers now agree with
  each other on any plate a reader cross-checks.
- **Templates hold 3–4 exercises each**, so the template plate reads "4 EXERCISES / 3
  EXERCISES / 3 EXERCISES" instead of "1 EXERCISES" three times.
- **Non-negative phase modulo.** `(dayOffset + 28) % 7` went negative once the window passed
  28 days — Swift's `%` keeps the dividend's sign — which would have driven seeded HRV and
  sleep below the floors the surrounding comment promises.

## Harness changes

`workload management/ScreenshotTests/ScreenshotTests.swift`:

- `test07_VerdictCard` saves **one** attachment, not two.
- `test08_StartWorkout_OpensActiveWorkout` keeps the blank-start smoke path but no longer
  produces the store plate.
- `test13_ActiveWorkout_FromTemplate` — new. Starts from "RIR Strength" and scrolls past the
  setup chrome.
- `test14_LogCapture_NarrativeEntry` — new. Types a locale-matched narration, then starts the
  recorder, which makes the editor resign first responder and drops the keyboard, leaving the
  athlete's own words on screen with the live REC stamp. The permission alert is dismissed
  explicitly — the first capture attempt caught it sitting on top of the sheet.
- `test15_SleepDetail_Opens` — new. Matches the sleep-trend card on `7.5`, the one string in
  `sleep.chart.annotation` that survives translation intact. `RecoveryView.swift` belongs to
  another lane, so no accessibility identifier was added to it.

## Capture and framing commands

```
xcodebuild build-for-testing -project "workload management/workload management.xcodeproj" \
  -scheme "workload management" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -derivedDataPath ~/.tonus-dd-claude-aso

# en
xcodebuild test-without-building -project "workload management/workload management.xcodeproj" \
  -scheme "workload management" -only-testing:ScreenshotTests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -derivedDataPath ~/.tonus-dd-claude-aso -resultBundlePath /tmp/shots-en.xcresult

# zh-Hans: same, plus TEST_RUNNER_SCREENSHOT_LANG=zh-Hans

# xcparse is not installed on this machine; xcresulttool does the same job:
xcrun xcresulttool export attachments --path /tmp/shots-en.xcresult --output-path /tmp/att-en
# then copy each attachment to its suggestedHumanReadableName from manifest.json into
# "appstore screenshots/1.7-en/raw/"

swift scripts/frame_screenshots.swift --all
```

## Still open

- **These plates will go stale when the logging-UI lane lands.** Plate 7 already shows that
  lane's work in progress — the set-entry row in the capture carries the new `TARGET` / `LAST`
  scrub rule, which was in the working tree while this ran. Plates 1, 7 and 8 all show
  surfaces that lane owns. **Re-shoot after it merges and before submission**; the commands
  are above and the whole run is about 25 minutes for both locales.
- **The device frame bleeds off the bottom of every plate.** That is the Field Notes marketing
  frame working as designed, but it means roughly the bottom third of each plate is a
  cut-off phone. Worth a look at thumbnail size before shipping — it is a `frame_screenshots`
  layout decision, not a capture problem.
- **6.5" set not re-shot.** Only the 6.9" (iPhone 17 Pro Max, 1320×2868) set exists. App Store
  Connect will scale it for smaller sizes; if HAN wants native 6.5", the same commands run
  against an iPhone 11 Pro Max-class simulator.
- **The nine-plate order is a proposal, not a ruling.** Flip `.store(rank:)` in `screenSpecs`
  to change it.
