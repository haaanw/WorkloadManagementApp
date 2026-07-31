# Wave 3 — orchestrator verification record

Branch `v1.7-field-notes`. Lanes F (screenshots), G (brand), H (chart detail views),
P (punch list), T (Dynamic Type). Run as three rounds, each lane adversarially reviewed by a
read-only agent that re-ran the lane's claims against the repo. Ground rule held throughout:
**re-run, don't trust** — no lane summary was accepted as evidence.

---

## Outcome

**Wave 3 gate: PASSED**, with one lane dropped by HAN, three blockers and eleven majors found
and fixed, and two decisions escalated that reversed the wave's own briefs.

The adversarial reviewers were the load-bearing part of this wave. Every lane self-reported
`complete` at least once while a reviewer found, with file:line evidence, that it was not.
Three of those were defects that would have shipped.

---

## Round structure and why

| Round | Lanes | Builders |
|---|---|---|
| 1 | F, G, H (spec), P, T (proposal) | P only |
| 2 | H (build), G, F ‖ then T alone | H, then T |
| 3 | app-source fixes, G, F | app only |

Wave 2's post-mortem recorded three concurrent `xcodebuild` runs starving each other and
killing all three lanes. Wave 3 never ran two app builders at once, and every simulator task
was serialized to the orchestrator at the end. No lane was lost to resource contention.

---

## HAN's rulings, and what each cost

1. **Sleep target 6 h floor / 7.5 h target, APP-WIDE** — overruled Session H's evidence-based
   counter-proposal (6 h + 7 h, grounded in the engine curve, the shipped translated copy, and
   the three orphaned legend keys). Implemented as one constant,
   `RecoveryScoreEngine.sleepTargetHours`, with three consumers: the glance rule, the detail
   rules, and the scoring curve's 70-point knee. The freeze on the glance charts was lifted for
   that one value only — verified by diffing `SleepTrendChart.swift` and confirming the change
   is `RuleMark(y: .value("Target", 7))` → the constant, plus comments, and nothing else.
2. **Dynamic Type: brief amended, then DROPPED.** The brief prescribed
   `Font.custom(_:size:relativeTo:)`; that API cannot carry the `UIFontDescriptor` pinning the
   Noto Sans SC cascade, so the route was changed to `UIFontMetrics` under a hard gate: prove
   SwiftUI reflows on a live content-size change. **The gate failed** — `UIFontMetrics` reads
   the process-wide category and creates no environment dependency, so `InkTabBar` reflowed
   while the surrounding type did not. That is worse than today's consistent non-adoption, and
   HAN dropped the lane. Reverted to HEAD: `FontTokens.swift`, `InkTabBar.swift`,
   `TickScale.swift`, `DesignSystemFenceTests.swift`, `DESIGN.md` (**design system stays
   v6.2, not v6.3**).
3. **The ≤12pt annotation cap** was to become a specification cap — moot once Dynamic Type was
   dropped, and reverted with it.
4. **`docs/*.html` → canonical redirects**, reaffirmed by HAN after counter-evidence (below).

---

## Blockers found by review, all fixed

1. **The screenshot pipeline corrupted the store set on re-run** (lane F). Nothing purged the
   output dir, and plates are named by the *current* run's index — so framing nine screens then
   re-running with three left twelve files, a stale `03_Dashboard` beside a fresh `01_Dashboard`
   and a plate reading `/09` next to one reading `/03`, at `0 error(s)` and exit 0. It would
   have fired the first time a lane changed how many surfaces are captured, which is the reason
   the pipeline exists.
2. **The privacy redirect pointed at an older, less complete policy** (lane G). See below.
3. **Dynamic Type geometry rode a different curve than its type** (lane T) — moot after the drop.

### The orchestrator's own error, recorded

Fixing blocker 1, I first used `FileManager.replaceItemAt`, assuming it was atomic. Testing
showed it performs the swap and *then* throws while discarding its own backup — leaving the new
set live while the run printed `NOT PUBLISHED … left unchanged`. **A report that contradicts the
filesystem is worse than the bug it describes.** Replaced with an explicit park-and-restore
(rename aside → rename in → restore on throw), with un-removable leftovers reported as a note
rather than a false failure. Four invariants then verified by reproduction, not by reading:
stale plates purged; a failed publish leaves the previous set byte-identical; litter swept;
`--all` exits non-zero when it publishes nothing.

---

## The finding that mattered most: `docs/*.html` are live

Round 1's lane-G reviewer established that these are **not** dead legacy copies:
`WorkloadApp/Views/Subscription/UpgradeSheet.swift:184-189` opens
`haaanw.github.io/WorkloadManagementApp/{terms,privacy}.html` from the **shipping build 17
paywall**, and `AppStoreMetadata.md:129-131` says do not retire them. They had already drifted:
`docs/terms.html` carried 11 sections dated June 5 while `tuwa-website/src/pages/terms.astro`
carried 12 including **"11. Apple App Store terms" — the exact EULA section the build-17
rejection was about**.

Round 2's reviewer then reversed the premise for the other two pages: tuwa.app/privacy is dated
**March 27** and lacks the Data Sharing section `docs/privacy.html` carries, and tuwa.app/support
has **no account-deletion answer** while `docs/support.html` gives one (App Review 5.1.1(v)
expects a discoverable deletion path). HAN was shown this and **reaffirmed all three redirects**;
it is a recorded, accepted risk, not an oversight. The content gaps are filed to CODEX with the
exact source text to port.

---

## Independent verification

```
cd "workload management"
xcodebuild test -scheme "workload management" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -derivedDataPath ~/.tonus-dd-claude -only-testing:WorkloadAppTests
```
→ `** TEST SUCCEEDED **`, **763 passed / 0 failed**, **17/17 design-system fence cases green**.

**Correction, recorded because the number was already published.** The first two runs of this
wave reported **762**, and I described that as "exact parity with the Wave 1 and Wave 2
baselines". A later run in the same DerivedData reported **763**, and diffing the executed test
sets showed the difference is
`SessionStartMapperTests.testSelectionRederivationAfterTemplateHydration()` — a test that has
existed since commit `045a944`. It did not execute in the earlier runs because the incremental
test binary in `~/.tonus-dd-claude` was stale; edits that forced a deeper rebuild picked it up.
So **762 was an under-count, and the Wave 2 baseline it "matched" was very likely stale in the
same way**. No test failed in any run — the correction is to the evidence, not to the result.
The lesson generalises: *a test count from an incremental build is not proof of coverage.*

**Settled by a clean-DerivedData run** (`~/.tonus-dd-clean`, built from scratch), which is the
authoritative figure and additionally proves the three new components' `.pbxproj` registration
from scratch rather than from cache:

| Run | Passed | Failed | Fence |
|---|---|---|---|
| **clean DerivedData** | **763** | 0 | 17/17 |
| incremental, after a deep rebuild | 763 | 0 | 17/17 |
| the two earlier incremental runs | 762 | 0 | 17/17 |

**Three of my own measurement errors, recorded because each one produced a number I published:**
1. A run piped through `tail -60` truncated my own log, so the count could not be shown. Re-run
   with a full log.
2. A stale incremental test binary omitted one test case; I read 762 as "parity with baseline"
   when it was an under-count.
3. Counting with `^Test case '…'` under-reported the clean run by one, because interleaved
   xcodebuild output had eaten the leading `Test ` on a line. A tolerant `case '…' (passed|failed)`
   match reconciles all four runs.

None of the three changed the outcome — nothing ever failed — but all three were cases of the
measurement, not the software, being wrong. Worth remembering: on this project the log is a
noisy channel, and a count is a claim that needs the same scrutiny as any other.

**`.pbxproj`:** each of the three new components carries the full four-part registration
(PBXBuildFile, PBXFileReference, group child, Sources phase), and all three compiled in a
DerivedData that had never seen them — so registration is proven by a real compile, not cache.

**Dynamic Type revert:** `git diff` empty for all five reverted files; repo-wide grep for
`UIFontMetrics|ScaledMetric|dynamicTypeSize|relativeTo:` returns zero hits in app source.

**Process-locale regressions:** `grep -rn "AnnotationLabel(String(localized"` returns only the
anti-pattern docstring in `CardStyle.swift`. Zero call sites. One further instance
(`TodayVerdictCard.swift:66`) was hidden from that grep by string interpolation and was fixed
separately — worth remembering: **the grep that proves a class is closed can be blind to
interpolation.**

---

## Open — needs HAN

- **Sleep curve shape.** The knee move makes the slope ladder non-monotonic: across 6–7 / 7–8 /
  8–9 h it was 30 / 20 / 10 pts-h (diminishing returns) and is now **20 / 40 / 10** — the half
  hour past the target is worth double the hour before it. Restoring a smooth shape means
  dropping the 8 h anchor from 90 to 80, an unordered score cut for well-slept athletes. The
  one-line alternative is recorded at `RecoveryScoreEngine.swift:251`.
- **zh-Hans store plates now render Latin annotation lowercase** (`● readiness`, `tuwa · 04/04`)
  because the pipeline correctly applies the zh no-case-transform law. It matches the app
  exactly; on a store plate it may read as a mistake.
- **Eight new zh-Hans strings are agent translations**, not a native reviewer's.
- **Nothing has been seen on a zh-Hans screen** in any of the three waves.
- Three same-class defects left in unowned files: `InviteConfirmationSheet.swift:49`
  (hard-coded English on a retired coach surface), plus lane-G carry-overs G-3/G-4/G-6/G-7/G-8.
- `og-default.png` is still on the old design and is referenced by 10+ website pages.

## The zh-Hans pass, finally done — and what it found

Captured both locales via `ScreenshotTests` (`TEST_RUNNER_SCREENSHOT_LANG=zh-Hans`), extracted
with `xcresulttool export attachments`, and **looked at the screens**. It found a defect class,
not just instances:

**The annotation voice's uppercase transform hides hard-coded English.** A literal renders
`ACUTE · 7-DAY` in en and reads as deliberate design; zh-Hans suppresses the transform by law,
so the same literal renders `Acute · 7-day` — raw English in title case beside Chinese copy.
The rule that protects Chinese typography is what exposes the bug, and only in the locale
nobody was checking. Anything hard-coded is therefore invisible in en review by construction.

Fixed in `95a9740`, each verified on a re-captured screen: `Sleep` → 睡眠; the sleep tile's
value un-truncated from `7小时36…` to `7小时36分钟` (a zh duration is ~2× the width of its Latin
twin and `minimumScaleFactor(0.6)` had no room); the Load descriptors → 急性 · 7天 /
慢性 · 28天 / 状态良好 / 疲劳; the sleep chart axis `hours` → 小时.

Confirmed working in Chinese: the Dashboard reason tree reads `高于目标 6 分钟` — HAN's sleep
ruling, translated, measured against 450 min, with no case transform and no added tracking.

**Also verified against the font binary, not the docs:** `├` `└` `─` (U+251C/2514/2500) are
**absent from Fragment Mono**, yet they render on the Dashboard — via silent cascade to another
face. The reason tree, the verdict's own "why", is not drawn in the annotation voice. `● ○ · ▲ ▼`
are present. Open for HAN.

## The finding the fence tests structurally cannot make: off-palette PURE WHITE

Sampling pixels across the captured set (rather than reading source) found three screens
rendering on `#FFFFFF` — **not a `ColorTokens` value at all**; the palette's lightest plane is
`surfaceEl2` `#FCFBF9`:

| Screen | white coverage |
|---|---|
| `MovementBankView` | **59.8%** |
| `ExercisePickerView` | **37.9%** |
| `WorkoutLogView` (and both App Store hero plates, same screen) | 9.0% |

Two causes:
1. **`WorkoutLogView`** — `ScreenHeader` and the filter rail live in a `VStack` whose only
   background was on the `ScrollView` *inside* it, so ~90pt of the tab fell through to the
   system default. The four sibling tab roots all set it correctly.
2. **The two `List` screens** — both already applied `.background(ColorTokens.background)`, but
   **a `List` paints its own system backing on top, so that line was inert.** It needs
   `.scrollContentBackground(.hidden)` first. Swept every `List` in the app; all now covered.

**Why three waves of review missed it:** `DesignSystemFenceTests` scans *source* for hardcoded
colours, shadows, radius literals and banned faces. Every one of these files passes — there is
no offending literal to find. The violation exists only in *rendered output*. A source fence
cannot catch a missing background, and no wave had looked at a screenshot.

Both are pre-existing (Movement Bank shipped this way in v1.6), not Wave 3 regressions.

**Worth encoding:** a rendered-pixel check ("no pixel equals `#FFFFFF`" / "every large flat
region is a `ColorTokens` value") would have caught all three, and belongs alongside the source
fences. The same reasoning applies to lane G's independently-discovered `text3`-on-a-well
contrast defect, which also appeared twice after being fixed once.

## Deliberately not done

- **No simulator visual pass, no zh-Hans capture, no App Store set regeneration.** These are
  real gaps, not oversights: they were serialized behind the app work and the wave reached the
  commit gate first. The screenshot pipeline is ready and one command from producing the set —
  it needs captures in `appstore screenshots/1.7-{en,zh-Hans}/raw/`.
- No push, no merge to `main`, no App Store Connect action. Build 17 remains in review.
