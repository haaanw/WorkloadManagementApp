# v1.7.2 App Store listing — drafts for HAN

Written 2026-08-22 by the Objective 3 lane. **Nothing here has been sent to App Store
Connect.** No push, no ASC mutation.

Read in this order:

| File | What it is |
|---|---|
| `1-keyword-metadata-audit.md` | The research and the reasoning. Measured competitive landscape (US + CN), the three defects in the live listing, recommended fields with alternates, and the claim-grading table. **Start here.** |
| `8-fields-paste-ready.txt` | Name / subtitle / keywords / promo text for both locales, with character counts, ready to paste. |
| `2-promo-en.txt`, `3-promo-zh-Hans.txt` | Promotional text. Changeable at any time without review. |
| `4-description-en.txt`, `5-description-zh-Hans.txt` | Full descriptions. EULA link is at the foot of both — do not remove it. |
| `4b-optional-sleep-v2-block.md` | The sleep-score-v2 paragraph, graded to engine status. **Not** in the default descriptions; HAN's call whether it goes in. |
| `6-whatsnew-en.txt`, `7-whatsnew-zh-Hans.txt` | What's New, led by voice logging. Both contain a placeholder line for the other two lanes' shipped items — fill it before submission. |
| `9-screenshot-story.md` | What was wrong with the 1.7 set, the new nine-plate order, captions in both locales, and the seed/harness changes behind them. |
| `10-ab-rationale.md` | What each change should move, the baseline to capture before submitting, and how to attribute the result. |

## The three things worth deciding first

1. **The App Store name is `tuwa` — four characters out of thirty, lowercase.** It is the
   highest-weighted indexed field and it carries no keyword at all. Every competitor spends
   all thirty. Recommendation: `Tuwa: Training Readiness`. Name, subtitle and keywords are
   version-locked, so they ride 1.7.2 or wait for 1.8.
2. **The China listing has no Chinese in its name.** Recommendation:
   `Tuwa - 准备度与训练负荷`. `准备度` is a query Tuwa already surfaces for and no strong
   competitor holds.
3. **Sleep score v2 is not in the descriptions — settled 2026-08-22.** The engine *is* built
   (`SleepScoreEngine.swift`, 662 lines, run nightly by `RecoveryPipeline`), but it is dark:
   its output goes to local `SleepShadowNight` rows that no view reads, and the live recovery
   score still uses the fixed 7.5-hour target. An athlete gets nothing from it, so it stays
   out. `4b-` holds the graded paragraph for the release that wires it up.

## The baseline says one thing very loudly

ASC Analytics, 90 days to 2026-08-20: **787 impressions → 127 page views → 12 downloads.**

- 16.1% impression → page view is **healthy**. The icon and current subtitle are not broken.
- 9.4% page view → download is **weak** against a 25–35% category norm. That is the
  screenshots and the empty ratings bar.
- ~8.7 impressions a day is the binding constraint. The listing is not losing a competition;
  it is not in one. Which is exactly why the 4-character name field is change #1.

**The app has 0 ratings**, and at 12 downloads a quarter it cannot earn any. An in-app review
prompt is app code and belongs to another lane, but it is the highest-leverage item left.

One correction to an earlier draft of `10-`: **Product Page Optimization is not viable at this
traffic** and should not be scheduled for four weeks after launch. It needs roughly 50+
installs a month to say anything. Fix impressions first.

## Files this lane changed outside `.planning/asc/`

- `WorkloadApp/Utilities/MockDataSeeder.swift` — `SCREENSHOT_MODE` seed only, `#if DEBUG`.
- `workload management/ScreenshotTests/ScreenshotTests.swift` — capture harness.
- `scripts/frame_screenshots.swift` — screen specs, plate order, caption copy.
- `appstore screenshots/1.7-{en,zh-Hans}/{raw,framed}/` — gitignored output.

Nothing else. `.pbxproj` untouched.
