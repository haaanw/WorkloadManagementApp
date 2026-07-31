# Session F — App Store screenshot pipeline (Wave 3)

## 2026-07-31T00:00 — Field Notes v6.2 restyle of the framing pipeline. DONE (no new captures this round, per instruction).

### What changed

**`scripts/frame_screenshots.swift`** — restyled from v5 "Pavilion" to v6.2 "Field Notes".
Extended the existing font-registration + CJK-cascade machinery rather than replacing it.

1. **Fragment Mono annotation layer added.** New `annotation(_:points:scale:color:alignment:)`
   is the *single* route to Fragment Mono. It applies the UPPERCASE transform and the
   +0.05em tracking itself — copy sites pass natural-case strings and never decide either,
   mirroring how `Font.Tokens.anno` behaves in the app. A `precondition(points <= 12.0)`
   makes the ≤12pt cap a hard failure rather than a review nit. CJK-containing strings get
   neither the case transform nor the tracking (v6 i18n law).
2. **Annotation strip** — a real card plane (`--surface-el` fill, 0.5pt `--divider`
   hairline, 12pt `CornerTokens.card` radius) across the top of the frame, carrying
   `● READINESS` (left, metric hue) and `TUWA · 01/06` (right, plate number).
3. **Metric hues wired in.** New `Metric` enum + `metricColors` (the five v6 hues exactly:
   `#2E7D4F / #1D7189 / #52589E / #A8442D / #8A6810`). Each screen declares its owning
   metric in the new `ScreenSpec` table. Hues appear **only** as the annotation key and its
   `●` state dot — never a fill, never decorative.
4. **The travertine accent rule was DELETED.** v5 drew a 32×2pt accent bar above the
   headline. Under the v6 Reading Color Rule the accent is live-state-marks-only and
   "never decorative" — a marketing frame has no live state, so that bar was a violation.
   The metric-hue annotation key replaces it (sanctioned use #3 of a metric hue).
5. **v6 type ramp.** Headline 30 → **32pt** Instrument Sans Medium (display step),
   subline 16 → **17pt** Regular (body step), annotation 12pt Fragment Mono. Working voice
   stays sentence case; only the annotation voice is uppercase.
6. **Machine-key annotation line** under the subline (e.g. `INPUTS: HRV · RHR · SLEEP`,
   `ACWR: ACUTE 7D / CHRONIC 28D`). These describe the *mechanism*, deliberately never a
   reading — a frame must not assert a number the capture does not show.
7. **Contrast handling.** Metric-hue annotation is below 24pt, so per DESIGN.md it must sit
   on a card plane — that is *why* the strip is a card, not loose text on `--bg`. The
   base-plane machine key uses `--text-2` (6.6:1), not `--text-3` (≈3.1:1 there).
   **Deliberate deviation, flagged for HAN:** the plate number also uses `--text-2` rather
   than the in-app annotation default `--text-3`; text-3 is ≈3.3:1 on a card plane and App
   Store thumbnails are viewed at roughly 1/6 size. Say the word and I'll put it back.
8. **Glyph-coverage guard.** `hasGlyph()` checks every annotation scalar against Fragment
   Mono and prints a loud warning + falls back to the system monospace instead of silently
   rendering a different face. (See the finding below — this guard is not theoretical.)
9. **Device panel** — corner radius 16 → **12pt** (Corner Law: card 12), border now
   `--divider-strong` 1pt, relief highlight now `--surface-el-2` instead of 55%-white.
10. **Spacing** all 8pt-grid: top 64 / strip 40 / strip→headline 24 / headline→subline 8 /
    subline→machine key 16 / machine key→device 40 / margins 32, device margins 40.
11. **Re-run is one command** (see below). Added a `frameJobs` table, `--all` mode,
    plate numbering, and `NN_Screen_framed.png` output names so App Store upload order =
    filename order. Missing input dirs are skipped with a message, so `--all` is safe to
    re-run at any time.

**`appstore screenshots/README.md`** (new) — documents the command, the dir convention,
and how to add a screen. Note: `appstore screenshots/` is gitignored (`.gitignore:54`), so
this README and all rendered PNGs are local-only; the pipeline itself is what's committed.

### THE RE-RUN COMMAND

```
swift scripts/frame_screenshots.swift --all
```

Run from the repo root. Job table (in the script):
`appstore screenshots/1.7-en/raw` → `.../1.7-en/framed` (en) and
`appstore screenshots/1.7-zh-Hans/raw` → `.../1.7-zh-Hans/framed` (zh-Hans).
When lanes H/P change a captured surface: re-capture into the `raw/` dirs, run that one
command. Ad-hoc form for previews:
`swift scripts/frame_screenshots.swift <input_dir> <output_dir> [en|zh-Hans]`.

### Verification — actual commands, actual output

No simulator, no xcodebuild, no test suite (Wave 3 rules). Verified by compiling and
running the script against the EXISTING captures, output to scratch/preview dirs only —
`1.4-en/` and `1.4-zh-Hans/` were not written to.

```
$ swift scripts/frame_screenshots.swift "appstore screenshots/1.4-en" "$SCRATCH/en" en
Skipping 05_CoachRoster_en.png (not a recognized screen)
Skipping 06_PDFExport_en.png (not a recognized screen)

[en] appstore screenshots/1.4-en → .../framed-preview/en  (3 screens)
  01 Dashboard (1320x2868) · readiness — "Know today's readiness"
     → .../framed-preview/en/01_Dashboard_framed.png
  02 Workload (1320x2868) · load — "Track training load"
     → .../framed-preview/en/02_Workload_framed.png
  03 Recovery (1320x2868) · recovery — "Recovery, decoded"
     → .../framed-preview/en/03_Recovery_framed.png

Framed 3 screenshots to .../framed-preview/en
```

```
$ swift scripts/frame_screenshots.swift "appstore screenshots/1.4-zh-Hans" "$SCRATCH/zh" zh-Hans
Skipping 04_WorkoutLog_zh.png (not a recognized screen)
Skipping 05_CoachRoster_zh.png (not a recognized screen)
Skipping 06_PDFExport_zh.png (not a recognized screen)

[zh-Hans] appstore screenshots/1.4-zh-Hans → .../framed-preview/zh  (3 screens)
  01 Dashboard (1320x2868) · readiness — "了解今天的准备度"
  02 Workload (1320x2868) · load — "追踪训练负荷"
  03 Recovery (1320x2868) · recovery — "恢复，看得懂"

Framed 3 screenshots to .../framed-preview/zh
```

`--all` exercised end-to-end in an isolated scratch copy of the repo layout (so the real
tree stayed clean), with three captures staged into the 1.7 `raw/` dirs:

```
$ cd $SCRATCH/allrun && swift .../scripts/frame_screenshots.swift --all
[en] appstore screenshots/1.7-en/raw → appstore screenshots/1.7-en/framed  (2 screens)
  01 Dashboard (1320x2868) · readiness — "Know today's readiness"
     → appstore screenshots/1.7-en/framed/01_Dashboard_framed.png
  02 Workload (1320x2868) · load — "Track training load"
     → appstore screenshots/1.7-en/framed/02_Workload_framed.png

[zh-Hans] appstore screenshots/1.7-zh-Hans/raw → appstore screenshots/1.7-zh-Hans/framed  (1 screens)
  01 Recovery (1320x2868) · recovery — "恢复，看得懂"
     → appstore screenshots/1.7-zh-Hans/framed/01_Recovery_framed.png

Framed 3 screenshots across 2 job(s).
```

And with the real (not yet existing) input dirs, from the repo root:

```
$ swift scripts/frame_screenshots.swift --all
Skipping job: no input dir at 'appstore screenshots/1.7-en/raw'
Skipping job: no input dir at 'appstore screenshots/1.7-zh-Hans/raw'

Framed 0 screenshots across 2 job(s).
Nothing framed — capture raw screenshots into the job input dirs first.
```

Zero warnings printed at any point — i.e. all five fonts registered and every annotation
glyph used (`● · / :` and Latin) exists in Fragment Mono.

### Visual judgement — I looked at these, at native 1320px resolution

Previews live at `appstore screenshots/_preview-v6/{en,zh-Hans}/` (gitignored, disposable —
they use the stale v1.4 captures purely to judge the *framing*, not the app UI).

- `_preview-v6/en/01_Dashboard_framed.png` — verdant-green `● READINESS` + `TUWA · 01/03`
  on the card strip; Instrument Sans Medium headline; Fragment Mono `INPUTS: HRV · RHR ·
  SLEEP`. Matches `design-system/guidelines/mono-annotation.card.html` (uppercase, tracked,
  terse, hue on the key) and `type-scale.card.html` (size ramp + one weight step).
- `_preview-v6/en/03_Recovery_framed.png` — teal `● RECOVERY`; the two voices are
  unmistakably distinct at thumbnail size, which was the point of the exercise.
- `_preview-v6/zh-Hans/01_Dashboard_framed.png` — CJK headline/subline route to Noto Sans
  SC Medium/Regular; the Latin machine key stays Fragment Mono uppercase. No case transform
  or tracking is applied to any CJK run.
- `_preview-v6/zh-Hans/02_Workload_framed.png` — ochre `● LOAD`.
- Verified programmatically that the canvas above the strip is a single uniform
  `#F0EFEC` — no stray artifacts (decoded the PNG and sampled the top 190 rows: 1 distinct
  color, `b'\xf0\xef\xec'`).

Honest nit I did not "fix": at 40pt tall with a 12pt radius the annotation strip reads
close to a pill. It is on-law (card radius 12) and I left it, but HAN may prefer a
54pt-tall strip or a plain hairline-ruled band. Cheap change either way.

### FINDING FOR OTHER LANES — Fragment Mono is missing the box-drawing / block glyphs

Not a screenshot issue; an app issue. I dumped the `cmap` of
`WorkloadApp/Resources/Fonts/FragmentMono-Regular.ttf`:

| Glyph | Codepoint | In Fragment Mono |
|---|---|---|
| `●` `○` `·` `▲` `▼` | U+25CF/25CB/00B7/25B2/25BC | **yes** |
| `├` `└` `─` | U+251C/2514/2500 | **NO** |
| `░` `▒` | U+2591/2592 | **NO** |
| `▁` `█` | U+2581/2588 | **NO** |

DESIGN.md v6 sanctions `├─ └─` for reason trees and `▁▂▃▄▅▆▇█` for spark bars, and
`design-system/guidelines/glyphs.card.html` shows both. **Any app surface that renders
those through `Font.Tokens.anno` will silently cascade to a different face** — the
annotation voice breaks exactly where it is most visible (the verdict's "why"). Affects
Session H (reason trees / annotation register in the detail views) and anyone who adopted
the tree glyphs in Waves 1–2. Options: substitute an available glyph, bundle a second
mono for the box-drawing range, or drop those two rows from the sanctioned glyph set.
I did not touch app source. Flagging only.

### Also for the orchestrator

- The frames' `machineKey` strings are my copy, not HAN-approved. They are deliberately
  mechanism-descriptive, never a reading. Worth a copy pass before submission.
- Six of the ten `ScreenSpec` entries (VerdictMicrodose, StrikeZone, NextMatch, MatchTier,
  ReadinessSignals, PlanInput) have never had a real capture — they are v2.1 beachhead
  screens carried over from the v5 script. They will be skipped harmlessly until captured.
- `05_CoachRoster` / `06_PDFExport` from the 1.4 sets are correctly unrecognized — coach
  mode was dropped in v1.6 and must not appear in a v1.7 set.

### Open blockers / not done

- **No new captures.** Per the round instruction, the simulator was not used, so there is
  no `1.7-en` / `1.7-zh-Hans` set yet. The pipeline is ready and waits on captures.
- The framed output has therefore only been judged against **v1.4-era** app screenshots.
  The *frame* is verified; the *composite* (v6 app UI inside a v6 frame) is not.
- Session P is capturing zh screenshots to `.planning/v17-field-notes/zh-pass/` for a
  different purpose (visual review). If those captures are full-screen and clean, they
  could seed `1.7-zh-Hans/raw` and save a round.

---

## 2026-07-31T01:16 — ROUND 2. All six Round-1 findings fixed. No simulator (orchestrator instruction), so still no 1.7 captures.

For the record, since a reviewer flagged it as unverifiable: **"do not use the simulator"
was a real orchestrator instruction to this lane in Round 1, and it was repeated verbatim
in the Round 2 brief** ("No app source. No simulator this round — lanes H and T are
actively changing the surfaces you would capture, so the orchestrator runs capture
serially afterwards"). It is not a self-imposed limit.

### Finding 1 — `detectScreenName` silently dropped half the harness output. FIXED.

The harness saves twelve attachments; the old matcher recognised six. `04_WorkoutLog`
(the Log tab, which shipped in the 1.4 zh set), `05_Profile`, `06_SessionStart`,
`08_ExercisePicker`, `09_MovementBank` and `10_TemplatePicker` all fell through to a
one-line "not a recognized screen" and vanished. Now:

* `screenPatterns` is a single ordered table (most specific first: `activeworkout` before
  `workoutlog`) covering all twelve, plus the two retired 1.4 surfaces (`CoachRoster`,
  `PDFExport`) so historical sets classify instead of erroring.
* `ScreenSpec` gained `inclusion: .store(rank:) | .excluded(reason:)`. Every screen is one
  or the other; there is no third "unknown" state that renders as silence.
* Store order is now the declared **rank**, not filename order. Filename order was actively
  wrong: ASCII sorts digits before letters, so `AppStore_v21_01_VerdictMicrodose` — the
  hero shot — sorted *last*. It is now plate 01.
* Every job prints `Summary [lang]: N capture(s) in · N framed · N excluded · N error(s)`
  followed by one line per excluded file **with its reason** and one per error.
* **Unrecognized capture ⇒ exit 1.** So is a store screen with no `FrameCopy` for the run's
  language (previously a silent skip).
* New `verifyHarnessCoverage()` parses `saveScreenshot("…")` straight out of
  `workload management/ScreenshotTests/ScreenshotTests.swift` on every run and fails if the
  harness emits a name the script cannot classify. That is the actual guard against this
  defect recurring — the table above can no longer drift from the harness in silence.

New store set (nine screens, all from real harness attachments), and the three deliberate
exclusions, are documented in `appstore screenshots/README.md` with reasons:

| Rank | Attachment | Screen | Metric |
|---|---|---|---|
| 1 | `AppStore_v21_01_VerdictMicrodose` | VerdictMicrodose | readiness |
| 2 | `AppStore_v21_02_StrikeZone` | StrikeZone | load |
| 3 | `01_Dashboard` | Dashboard | readiness |
| 4 | `03_Recovery` | Recovery | recovery |
| 5 | `02_Workload` | Workload | load |
| 6 | `04_WorkoutLog` | WorkoutLog | readiness |
| 7 | `07_ActiveWorkout` | ActiveWorkout | strain |
| 8 | `10_TemplatePicker` | TemplatePicker | load |
| 9 | `09_MovementBank` | MovementBank | strain |

Out of the store set, deliberately: **`05_Profile`** (settings surface, no marketing
value), **`06_SessionStart`** (the same surface as `10_TemplatePicker` — test08 shoots the
template picker before the tap, test12 after), **`08_ExercisePicker`** (mid-flow search UI,
unreadable at store thumbnail size). New en+zh copy was written for WorkoutLog,
TemplatePicker and MovementBank. **This curation is my proposal, not a HAN ruling** — one
word (`.excluded` ↔ `.store`) flips any of them.

### Finding 2 — metric key and plate number drew into the identical rect. FIXED.

They now get reserved columns: the plate is measured, right-aligned in a column of exactly
its own width at the strip's trailing padding; the metric key gets
`stripTextWidth − plateWidth − 16pt gutter`. A `precondition` fails the run if they cannot
both fit, with the measured widths in the message. Proved by running a copy of the script
with a deliberately long metric key (see verification below) — it aborts instead of
overprinting.

### Finding 3 — documented plate format was wrong. FIXED (docs changed, not the code).

I kept the denominator as **the number of plates framed in this run** and corrected the
header comment and the README. Rationale: a run that produced 3 captures should read
`01/03 … 03/03`, not promise `/06` of a set that does not exist. The README now states
this explicitly under "Plate numbering". The old `TUWA · 01/06` example is gone.

### Finding 4 — hand-transcribed tokens. FIXED by parsing the CSS at run time.

`loadColorTokens()` parses `--name:#RRGGBB;` out of `design-system/tokens/colors.css` on
every run; `token(_:)` is the only route to a color and hard-fails on an unknown name.
There is no palette literal left in the script. Missing file ⇒ explicit "must be run from
the repo root" error, exit 1. Proved by running against a modified copy of colors.css
(`--bg:#FF00FF`) and reading the rendered pixel back. README documents it.

### Finding 5 — unreachable `text3Color` fallback. FIXED by removal.

`metricColors[spec.metric] ?? text3Color` is gone; `metricColor(_:)` is a total function
over `Metric` via `metric.tokenName`, so there is no dead branch. `text3Color` is deleted;
its contrast rationale survives as a comment where the decision is actually made.

### Finding 6 — contrast figure on the wrong plane. FIXED.

Every contrast number in the script and README is now plane-labelled and exact
(recomputed against the v6.2 palette):

| | on `--bg` | on `--surface-el` |
|---|---|---|
| `text-1` | 15.13:1 | 16.24:1 |
| `text-2` | **6.56:1** | **7.04:1** |
| `text-3` | 3.11:1 | 3.34:1 |
| metric hues (lo→hi) | 4.39–5.62:1 | 4.71–6.03:1 |

So: the plate number sits on the **card** plane at 7.04:1 (not 6.56 — that is the base
plane figure, which is the one that belongs to the machine key). Both are now stated
against their own plane. The conclusion is unchanged: `text-2` for both store annotations,
because `text-3` is 3.34:1 / 3.11:1 and store thumbnails are viewed at ~1/6 size. Still
flagged as a deliberate deviation from the in-app annotation default for HAN.

### Verification — actual commands, actual output

No simulator, no `xcodebuild`, no test suite. Everything below ran the real script over the
existing `1.4-*` captures into scratch/preview dirs; `1.4-en/` and `1.4-zh-Hans/` were not
written to.

**1. en over the 1.4 set** (`$S` = scratch):

```
$ swift scripts/frame_screenshots.swift "appstore screenshots/1.4-en" "$S/en" en ; echo EXIT=$?
Harness coverage: 12 attachment(s) in workload management/ScreenshotTests/ScreenshotTests.swift — 9 in the store set, 3 excluded, 0 unmapped.
  excluded: 05_Profile → Profile (excluded: settings surface — no marketing value)
  excluded: 06_SessionStart → SessionStart (excluded: same surface as TemplatePicker (test08 vs test12))
  excluded: 08_ExercisePicker → ExercisePicker (excluded: mid-flow search UI — unreadable at store thumbnail size)

[en] appstore screenshots/1.4-en → …/en  (3 screens)
  01 Dashboard (1320x2868) · readiness — "Know today's readiness"
  02 Recovery (1320x2868) · recovery — "Recovery, decoded"
  03 Workload (1320x2868) · load — "Track training load"
  Summary [en]: 5 capture(s) in · 3 framed · 2 excluded · 0 error(s)
    excluded: 05_CoachRoster_en.png — CoachRoster — retired — coach mode dropped in v1.6
    excluded: 06_PDFExport_en.png — PDFExport — retired — not produced by the v1.7 harness

Framed 3 screenshots to …/en; 0 error(s).
EXIT=0
```

**2. zh-Hans over the 1.4 set — the Round-1 gap, closed.** `04_WorkoutLog_zh.png` used to
print "not a recognized screen"; it now frames as plate 04:

```
$ swift scripts/frame_screenshots.swift "appstore screenshots/1.4-zh-Hans" "$S/zh" zh-Hans ; echo EXIT=$?
[zh-Hans] appstore screenshots/1.4-zh-Hans → …/zh  (4 screens)
  01 Dashboard (1320x2868) · readiness — "了解今天的准备度"
  02 Recovery (1320x2868) · recovery — "恢复，看得懂"
  03 Workload (1320x2868) · load — "追踪训练负荷"
  04 WorkoutLog (1320x2868) · readiness — "先给结论，再看记录"
  Summary [zh-Hans]: 6 capture(s) in · 4 framed · 2 excluded · 0 error(s)
    excluded: 05_CoachRoster_zh.png — CoachRoster — retired — coach mode dropped in v1.6
    excluded: 06_PDFExport_zh.png — PDFExport — retired — not produced by the v1.7 harness
EXIT=0
```

**3. Negative: unrecognized capture must fail the run.**

```
$ cp .../01_Dashboard_en.png "$S/neg/in/99_MysterySurface_en.png"
$ swift scripts/frame_screenshots.swift "$S/neg/in" "$S/neg/out" en ; echo EXIT=$?
  Summary [en]: 1 capture(s) in · 0 framed · 0 excluded · 1 error(s)
    ERROR: 99_MysterySurface_en.png: no `screenPatterns` entry matches this filename
EXIT=1
```

**4. Negative: harness drift guard.** Fake repo root whose harness saves an attachment the
script does not know:

```
$ printf '... saveScreenshot("01_Dashboard") saveScreenshot("13_SleepDetail") ...' > "$R/workload management/ScreenshotTests/ScreenshotTests.swift"
$ cd "$R" && swift .../frame_screenshots.swift --all ; echo EXIT=$?
Error: the screenshot harness saves attachment(s) this script cannot classify:
  13_SleepDetail
Add a pattern to `screenPatterns` and a `ScreenSpec` (store or excluded-with-reason).
Harness coverage: 2 attachment(s) … 1 in the store set, 0 excluded, 1 unmapped.
EXIT=1
```

**5. Negative: store screen with no copy for the run's language** (zh `WorkoutLog` copy
deleted in a scratch copy of the script — previously this was a silent skip):

```
$ swift "$S/nocopy.swift" "appstore screenshots/1.4-zh-Hans" "$S/nocopy-out" zh-Hans ; echo EXIT=$?
  Summary [zh-Hans]: 6 capture(s) in · 3 framed · 2 excluded · 1 error(s)
    ERROR: 04_WorkoutLog_zh.png: WorkoutLog is in the store set but has no 'zh-Hans' FrameCopy
EXIT=1
```

**6. Negative: strip column overflow** (scratch copy of the script with an absurdly long
metric key) — the two columns abort instead of overprinting:

```
$ swift "$S/overflow.swift" "appstore screenshots/1.4-en" "$S/overflow-out" en ; echo EXIT=$?
overflow.swift:749: Precondition failed: Annotation strip overflow: metric key (1588px) + gutter + plate (289px) exceeds the strip's 1032px. Shorten the metric key or widen the strip — do not let the two columns overlap.
EXIT=133
```

**7. Negative: not run from the repo root / tokens unreadable.**

```
$ cd "$S/norepo" && swift .../frame_screenshots.swift --all ; echo EXIT=$?
Error: cannot read 'design-system/tokens/colors.css'.
frame_screenshots.swift reads the canonical design tokens at run time and must be
run from the repo root:  swift scripts/frame_screenshots.swift --all
EXIT=1
```

**8. Proof the tokens are actually read, not transcribed.** Scratch repo mirror with
`--bg:#F0EFEC` rewritten to `#FF00FF`, framed one capture, decoded the PNG:

```
$ sed 's/--bg:#F0EFEC;/--bg:#FF00FF;/' design-system/tokens/colors.css > "$R/design-system/tokens/colors.css"
$ cd "$R" && swift .../frame_screenshots.swift in out en ; echo EXIT=$?
EXIT=0
$ python3 -c "from PIL import Image; print(Image.open('out/01_Dashboard_framed.png').convert('RGB').getpixel((4,4)))"
(255, 0, 255)
```

**9. `--all` end-to-end** in a scratch mirror with five en + one zh capture staged into the
`1.7-*/raw` dirs (including an excluded `05_Profile`), confirming rank ordering puts the
hero first:

```
$ cd "$R" && swift .../frame_screenshots.swift --all ; echo EXIT=$?
[en] appstore screenshots/1.7-en/raw → appstore screenshots/1.7-en/framed  (4 screens)
  01 VerdictMicrodose (1320x2868) · readiness — "Microdose before match day"
  02 Dashboard (1320x2868) · readiness — "Know today's readiness"
  03 Recovery (1320x2868) · recovery — "Recovery, decoded"
  04 Workload (1320x2868) · load — "Track training load"
  Summary [en]: 5 capture(s) in · 4 framed · 1 excluded · 0 error(s)
    excluded: 05_Profile.png — Profile — settings surface — no marketing value

[zh-Hans] appstore screenshots/1.7-zh-Hans/raw → appstore screenshots/1.7-zh-Hans/framed  (1 screens)
  01 WorkoutLog (1320x2868) · readiness — "先给结论，再看记录"
  Summary [zh-Hans]: 1 capture(s) in · 1 framed · 0 excluded · 0 error(s)

Framed 5 screenshots across 2 job(s); 0 error(s).
EXIT=0
```

**10. Real repo, real job dirs (which do not exist yet) — still a clean no-op:**

```
$ swift scripts/frame_screenshots.swift --all ; echo EXIT=$?
Skipping job: no input dir at 'appstore screenshots/1.7-en/raw'
Skipping job: no input dir at 'appstore screenshots/1.7-zh-Hans/raw'

Framed 0 screenshots across 2 job(s); 0 error(s).
Nothing framed — capture raw screenshots into the job input dirs first.
EXIT=0
```

Zero font/glyph warnings in every run above — all five faces registered and every
annotation scalar used (`● · / : × -` and Latin) exists in Fragment Mono.

### I read the rendered PNGs back

Regenerated `appstore screenshots/_preview-v6/{en,zh-Hans}/` (gitignored, disposable — v1.4
captures inside a v6.2 frame, so judge the FRAME, not the app UI), cropped the top 760px
and decoded them.

- `_preview-v6/en/01_Dashboard_framed.png` — verdant `● READINESS` hard left on the card
  strip, `TUWA · 01/03` hard right, wide clear gap between: the reserved columns are
  visibly separate, not merely non-crashing. Instrument Sans Medium headline in ink,
  Regular subline in text-2, `INPUTS: HRV · RHR · SLEEP` in tracked uppercase Fragment
  Mono. Two voices unmistakable.
- `_preview-v6/zh-Hans/04_WorkoutLog_framed.png` — **the screen Round 1 was dropping.**
  CJK headline/subline route to Noto Sans SC Medium/Regular with no case transform and no
  added tracking; the Latin machine key `VERDICT: PLAN × READINESS` stays Fragment Mono
  uppercase. The `×` renders in Fragment Mono (no fallback warning).
- `_preview-v6/en/03_Workload_framed.png` at 1/4 scale (≈ store thumbnail): ochre `● LOAD`
  and the plate stay legible; the headline carries at thumbnail size.

### THE COMMANDS FOR THE ORCHESTRATOR

Once lanes H and T settle and you run capture serially, the framing step is exactly one
line, from the repo root:

```
swift scripts/frame_screenshots.swift --all
```

It exits non-zero on any unclassified capture or missing copy — treat a non-zero exit as a
blocker, not a warning.

Capture side (my suggestion — **not run this round, no simulator**; the raw PNGs must land
flat in `appstore screenshots/1.7-{en,zh-Hans}/raw/`):

```
xcodebuild test -project "workload management/workload management.xcodeproj" \
  -scheme "workload management" -only-testing:ScreenshotTests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -derivedDataPath ~/.tonus-dd-claude-f \
  -resultBundlePath /tmp/tuwa-shots-en.xcresult
xcparse screenshots /tmp/tuwa-shots-en.xcresult /tmp/tuwa-shots-en
find /tmp/tuwa-shots-en -name '*.png' -exec cp {} "appstore screenshots/1.7-en/raw/" \;
```

and the same with `TEST_RUNNER_SCREENSHOT_LANG=zh-Hans` into `1.7-zh-Hans/raw/`
(the harness reads `SCREENSHOT_LANG`; `Screenshots-zhHans.xcscheme` is the GUI equivalent).
`xcparse` nests by test method — the `find`/`cp` flattens it. Filenames keep the attachment
names, and `screenPatterns` matches on substrings, so prefixes/suffixes are harmless.

### Still open / NOT done

- **No 1.7 captures exist.** Simulator was off-limits again this round by instruction. The
  pipeline is verified end-to-end against staged inputs; the *composite* (v6.2 app UI
  inside a v6.2 frame) has still never been seen.
- **`machineKey` strings and the three new screens' copy are mine, not HAN-approved.**
  `MovementBank`'s machine key asserts `catalog: 1,324 movements` — factual per CLAUDE.md,
  but it is a marketing claim and deserves a look.
- **No store screen carries the `sleep` hue.** Four of five metric identities appear.
  Session H's sleep detail view is the natural fifth if HAN wants the full set represented.
- The 40pt strip at 12pt radius still reads close to a pill. On-law; unchanged from Round 1.
- The Fragment Mono box-drawing/block gap reported in Round 1 (`├ └ ─ ░ ▒ ▁ █` absent) is
  unchanged and is still an **app** issue for Session H, not a screenshot one.

---

# Round 3 — FIX session (2026-07-31 10:06 CST)

Adversarial review returned nine findings against Round 2. All nine verified against the
current file, all nine fixed. **Status: PARTIAL — blocked on capture** (finding 4).
No git write. No simulator. Files touched: `scripts/frame_screenshots.swift`,
`appstore screenshots/README.md`, and the disposable `appstore screenshots/_preview-v6/`.

## Finding 1 (BLOCKER) — re-run corrupts the store set — FIXED

**Verified before fixing.** Two runs into one dir, the reviewer's exact scenario:

```
$ swift scripts/frame_screenshots.swift $SC/in9 $SC/out en   # 9 eligible captures
  Summary [en]: 6 capture(s) in · 4 framed · 2 excluded · 0 error(s)
$ swift scripts/frame_screenshots.swift $SC/in3 $SC/out en   # then 3
  Summary [en]: 3 capture(s) in · 3 framed · 0 excluded · 0 error(s)
EXIT=0
$ ls $SC/out
01_Dashboard_framed.png  02_Dashboard_framed.png  02_Recovery_framed.png
03_Recovery_framed.png   03_Workload_framed.png   04_Workload_framed.png
```

Six files from a three-plate run, mixed `/04` and `/03` denominators, exit 0. Confirmed.

**Fix** — `runJob` renders into a sibling staging dir `<outputDir>.staging-<pid>` and
publishes in one step via the new `publish(stagingDir:outputDir:)`: delete every
`*_framed.png` in the output dir, then move the staged plates in. Publication happens only
when `result.errors.isEmpty && result.framed > 0` — so an error leaves the previous good
set untouched (also fixes finding 5's "partly-written output dir"), and an accidentally
empty `raw/` cannot delete a good set. `defer` removes the staging dir on every path. The
summary line now ends `PUBLISHED (output dir replaced)` or
`NOT PUBLISHED (<why>) — '<dir>' left unchanged`.

**Verified after fixing** — same two runs, same dir:

```
### 1. clean 9-plate run
  Summary [en]: 9 capture(s) in · 9 framed · 0 excluded · 0 error(s) · PUBLISHED (output dir replaced)
01_VerdictMicrodose_framed.png 02_StrikeZone_framed.png 03_Dashboard_framed.png
04_Recovery_framed.png 05_Workload_framed.png 06_WorkoutLog_framed.png
07_ActiveWorkout_framed.png 08_TemplatePicker_framed.png 09_MovementBank_framed.png
### 2. re-run 3-plate set INTO THE DIRTY DIR
  Summary [en]: 3 capture(s) in · 3 framed · 0 excluded · 0 error(s) · PUBLISHED (output dir replaced)
01_Dashboard_framed.png 02_Recovery_framed.png 03_Workload_framed.png
count=3
### 3. no staging left behind
none
```

README's "(output, regenerated)" replaced with "(output, REPLACED per run)" plus a new
"Output is replaced, never merged" section stating the three outcomes.

## Finding 2 (MAJOR) — missing font silently degrades the type law — FIXED

`registerBundledFonts()` now iterates a `requiredFonts` table (path + expected PostScript
name), and a missing file, a failed `CTFontManagerRegisterFontsForURL`, or a PostScript
name that does not resolve is a hard failure **before any job runs**. `loadFont` lost its
`fallback:` parameter entirely; `NSFont.systemFont` and `NSFont.monospacedSystemFont` no
longer appear anywhere in the script except in the comments explaining why. A glyph
Fragment Mono cannot render is collected in `annotationGlyphMisses` and turned into a
per-plate framing **error** instead of a system-mono substitution.

Verified in a synthetic repo root with `FragmentMono-Regular.ttf` absent:

```
$ env -C $FAKEROOT swift .../frame_screenshots.swift $SC/in3 $SC/outfake en
Error: the bundled marketing faces did not load. Nothing was framed.
  missing file: WorkloadApp/Resources/Fonts/FragmentMono-Regular.ttf
DESIGN.md's Two-Voice Type Law admits no fallback face in shipped artwork —
this is a hard failure, not a warning. ...
EXIT=1
$ ls $SC/outfake
ls: .../outfake: No such file or directory
```

## Finding 3 (MAJOR) — zh-Hans frames broke the annotation law — FIXED

Confirmed the divergence: `CardStyle.swift:607` `isLatin = locale.language.languageCode?
.identifier != "zh"`, consumed at `:652-653` `.tracking(isLatin ? size.tracking : 0)` /
`.textCase(isLatin ? .uppercase : nil)`. The script decided from string content.

`annotation()` now takes `isLatin:` and `frameScreenshot()` takes `language:`; the new
`isLatinAnnotation(language:)` gates on the job's language. The per-scalar CJK → Noto Sans
SC mapping stays content-driven — that is the font *cascade*, not the case/tracking law,
and the comment at the head of `annotation()` now says exactly that instead of the wrong
claim it carried.

Read back from the exact plate the reviewer cited,
`_preview-v6/zh-Hans/04_WorkoutLog_framed.png`, regenerated with the fixed script:

- annotation strip left: `● readiness` (was `● READINESS`)
- annotation strip right: `tuwa · 04/04` (was `TUWA · 04/04`)
- machine key: `verdict: plan × readiness` (was `VERDICT: PLAN × READINESS`)
- no added tracking on any of the three

en plates are byte-for-byte unaffected in behaviour — `_preview-v6/en/03_Workload_framed.png`
still reads `● LOAD` / `TUWA · 03/03` / `ACWR: ACUTE 7D / CHRONIC 28D`, uppercase, tracked,
ochre `--metric-load` key.

**Consequence HAN should see:** the law makes Latin annotation on a zh plate render in the
source string's own case, i.e. lowercase. That is precisely what `Annotation` does in-app
under a zh locale, so the frames now match the product. If HAN wants zh plates to read
`● READINESS` anyway, that is a DESIGN.md change, not a script change.

## Finding 4 (MAJOR) — status honesty — CORRECTED

Round 2's "complete" was wrong. **This round reports PARTIAL / blocked on capture.**
`appstore screenshots/1.7-en/raw/` and `1.7-zh-Hans/raw/` do not exist:

```
$ swift scripts/frame_screenshots.swift --all
Skipping job: no input dir at 'appstore screenshots/1.7-en/raw'
Skipping job: no input dir at 'appstore screenshots/1.7-zh-Hans/raw'
Framed 0 screenshots across 2 job(s); 0 set(s) published; 0 error(s).
Nothing framed — capture raw screenshots into the job input dirs first.
EXIT=0
```

The composite — v6.2 app UI inside a v6.2 frame — has still never been rendered. Everything
verified this round used the historical `1.4-*` captures, which show the v6 *frame* around
a v1.4 *app*. The one-liner the orchestrator runs once captures land in the two `raw/` dirs,
from the repo root:

```
swift scripts/frame_screenshots.swift --all
```

A "Current state (2026-07-31)" section saying this now heads
`appstore screenshots/README.md`.

## Finding 5 (MINOR) — strip overflow SIGTRAPped — FIXED

`frameScreenshot` returns a new `FrameOutcome` (`.rendered` / `.failed(String)`); the
overflow `precondition` became a `guard … else { return .failed(...) }` that restores
`NSGraphicsContext.current` first. `CGContext` and `makeImage` failures return `.failed`
too, and PNG encoding failure is now distinguished from framing failure.

Verified by setting `--space-lg:200px` in a synthetic `spacing.css` (which also proves
finding 9 — the layout genuinely reads the token file now):

```
  Summary [en]: 3 capture(s) in · 0 framed · 0 excluded · 3 error(s) · NOT PUBLISHED (3 error(s)) — '.../outfake' left unchanged
    ERROR: 01_Dashboard_en.png: annotation strip overflow: metric key (265px) + gutter + plate (289px) exceeds the strip's 24px. ...
    ERROR: 03_Recovery_en.png: annotation strip overflow: ...
    ERROR: 02_Workload_en.png: annotation strip overflow: ...
EXIT=1
```

All three plates were attempted (no mid-run abort), exit 1 not 133, and the pre-existing
`99_Stale_framed.png` in the output dir survived untouched.

## Finding 6 (MINOR) — harness drift guard failed OPEN — FIXED

`verifyHarnessCoverage()` returned `true` when the harness file could not be read, and a
regex-compile failure did the same. Both now return `false` with an explicit stderr message.
Going further than the finding asked: `main()` now **aborts before framing** when a startup
guard fails, rather than running the jobs and exiting 1 afterwards — exiting non-zero after
replacing the store artwork is not a guard.

```
$ env -C $FAKEROOT swift .../frame_screenshots.swift $SC/in3 $SC/outfake en   # harness deleted
Error: cannot read the screenshot harness at 'workload management/ScreenshotTests/ScreenshotTests.swift'.
The capture-coverage guard cannot be skipped — run from the repo root: ...
Aborted before framing: a startup guard failed. Nothing was written.
EXIT=1
$ ls $SC/outfake
ls: .../outfake: No such file or directory
```

## Finding 7 (MINOR) — duplicate screens both framed — FIXED

Reproduced on the pre-fix script by putting `01_Dashboard_en.png` and `01_Dashboard_zh.png`
in one input dir: it emitted `01_Dashboard_framed.png` **and** `02_Dashboard_framed.png`
at `0 error(s)`, exit 0.

`runJob` now keeps a `seenScreens` map and errors on the second claim. Rank uniqueness is
enforced separately by the new `verifyScreenSpecs()`, which also proves every `.store`
screen has `FrameCopy` in every job language — both up front, both fail-closed.

```
    ERROR: 01_Dashboard_zh.png: resolves to Dashboard, already claimed by 01_Dashboard_en.png
    — two captures of one screen would ship as duplicate plates. Remove one, or give it its
    own `screenPatterns` entry.
  ... NOT PUBLISHED (1 error(s))
```

## Finding 8 (MINOR) — coverage guard only checked harness→script — FIXED

The four v2.1 beachhead screens claiming `.store(rank: 10…13)` with no attachment behind
them were a declared store set that could never be shot. Added a third `Inclusion` case,
`.plannedNotCaptured(note:)`, and moved all four to it — the intent is now in the type, not
in a comment. `verifyHarnessCoverage()` gained the reverse direction: a `.store(rank:)`
screen with no harness attachment is an error, and (the forcing function in the other
direction) a capture appearing for a `.plannedNotCaptured` screen is also an error telling
you to promote it.

Verified by replacing exactly one line in a copy of the harness:

```
$ python3 -c "...replace('saveScreenshot(\"09_MovementBank\")', '// removed for guard test')..."
$ env -C $FAKEROOT swift .../frame_screenshots.swift $SC/in3 $SC/outfake en
Error: screen(s) declared `.store(rank:)` that NO harness attachment produces:
  MovementBank
A store screen that cannot be captured is not a store screen. Either add the
attachment to workload management/ScreenshotTests/ScreenshotTests.swift, or declare it `.plannedNotCaptured(note:)`.
Aborted before framing: a startup guard failed. Nothing was written.
EXIT=1
```

Normal runs now print the planned set explicitly:

```
  planned, not captured (4) — specced with copy, no harness attachment yet:
    MatchTier — v2.1 beachhead — no harness attachment yet
    NextMatch — v2.1 beachhead — no harness attachment yet
    PlanInput — v2.1 beachhead — no harness attachment yet
    ReadinessSignals — v2.1 beachhead — no harness attachment yet
```

## Finding 9 (MINOR) — token-drift fix was colour-only — FIXED

Added `loadNumericTokens(path:)` + `metric(_:)` reading `design-system/tokens/spacing.css`
(`--name:12px;`), same hard-fail contract as `token(_:)`. Every layout value in
`frameScreenshot` now composes from those tokens:

| layout value | token |
|---|---|
| `margin` | `--space-lg` |
| `topPadding` | `--space-2xl` |
| `stripHeight`, `deviceGap`, `deviceMargin` | `--space-lg + --space-xs` (40, on-grid) |
| `stripPadding`, `stripGutter`, `machineGap` | `--space-sm` |
| `stripGap` | `--space-md` |
| `sublineGap` | `--space-xs` |
| `cardRadius` | `--radius-card` |
| `hairline` | `--hairline` |

`borderWidth` stays a 1.0 literal, deliberately and with a comment: the Relief Law
specifies the raised top highlight as a 1px line and `spacing.css` canonicalises only the
0.5px hairline. Proven live by the `--space-lg:200px` experiment under finding 5 — the
frames' geometry moved, so the file is genuinely being read.

## Commands actually run

```
swift scripts/frame_screenshots.swift <in> <out> [en|zh-Hans]   # ~12 scratch-dir runs
swift scripts/frame_screenshots.swift --all                     # → skips both jobs, exit 0
env -C <synthetic repo root> swift .../frame_screenshots.swift  # 4 negative-path runs
swift scripts/frame_screenshots.swift "appstore screenshots/1.4-en" \
      "appstore screenshots/_preview-v6/en" en                  # 3 framed, PUBLISHED
swift scripts/frame_screenshots.swift "appstore screenshots/1.4-zh-Hans" \
      "appstore screenshots/_preview-v6/zh-Hans" zh-Hans         # 4 framed, PUBLISHED
```

`_preview-v6/` was regenerated with the fixed script, so the on-disk artifacts match the
fixed pipeline (the previous en set had 3 files and the zh set 4 — an artifact of exactly
the finding-1 defect). No app source touched, no `xcodebuild`, no simulator, no git write.

## Still NOT done, this round

- **The 1.7 capture set.** Blocked by instruction — the orchestrator runs capture serially
  at the end. Nothing about the composite has been seen.
- **`machineKey` strings and the store-set curation are still a Session F proposal**, not a
  HAN ruling. `MovementBank`'s `catalog: 1,324 movements` is a marketing claim.
- **No store screen carries the `sleep` hue.** Four of five metric identities appear.
- **The zh-Hans lowercase consequence of finding 3 is a design call HAN has not made.**
  The frames now match the app; whether the app's own rule reads well on a marketing plate
  is a separate question.
- **The `--all` job table's output dirs are never pruned of non-`*_framed.png` files.**
  Publication deletes only `*_framed.png`; a stray file of another name in a framed dir
  survives. Deliberate — deleting arbitrary files out of a directory is worse.
