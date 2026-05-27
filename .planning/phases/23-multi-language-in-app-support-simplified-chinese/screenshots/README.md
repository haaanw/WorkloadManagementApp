# Phase 23 — zh-Hans Density Audit Screenshots

This directory holds before/after screenshots for the zh-Hans density audit (Plan 23-04, Task 2 / Task 3 reviewer gate).

## Required surfaces

Per 23-04-PLAN.md Task 2 acceptance criteria, the reviewer needs paired en + zh-Hans captures for:

- dashboard-en.png + dashboard-zh.png (hero readiness card, metric strip, ACWR section)
- workload-en.png + workload-zh.png (Chart axis labels — verifies `.id(locale)` + `.locale(locale)` rebuild)
- recovery-en.png + recovery-zh.png (HRV/sleep trend charts)
- profile-en.png + profile-zh.png (language picker row)
- onboarding-step0-zh.png (language step in zh-Hans)
- paywall-zh.png (UpgradeSheet in zh-Hans — confirms RC product titles remain English; that limitation is the post-ship follow-up)

## Capture procedure

These screenshots are produced manually during Task 3 reviewer sign-off. The existing `ScreenshotTests` UITest target captures English only; extending it to drive both locales (via `-AppleLanguages "(zh-Hans)"` launch arg) is out of scope for this plan — the catalog ship gate matters more than the audit artifact format.

Recommended manual capture (iPhone 17 Pro Max simulator):

1. Build + install the app once with `xcodebuild` (already done — `5a475e3` build green).
2. Launch the simulator app from Xcode with the scheme's launch arguments set to:
   - `-AppleLanguages (zh-Hans)`
   - `-AppleLocale zh_Hans_CN`
   - `SCREENSHOT_MODE` (so auth is bypassed and mock data is seeded)
3. Navigate to each surface and press Cmd+S in the simulator (or use `xcrun simctl io booted screenshot`) to capture.
4. Switch language via Profile → Language → English and repeat for the en counterparts.
5. Drop both into this directory with the names above.

If any surface truncates or shows PingFang fallback on Chinese glyphs (instead of Noto Sans SC), file as a regression and return to Task 2 to fix before approving Task 3.

## Visual acceptance checklist sign-off

The reviewer signs off the 13 checklist items from 23-UI-SPEC.md lines 340-354 inside 23-04-SUMMARY.md.
