# zh-Hans Screenshots for App Store Connect

**Target resolution:** 1320 × 2868 (iPhone 17 Pro Max portrait — required by ASC; smaller display classes scale down from this).

**Render scheme:** `Screenshots-zhHans` (defined at `workload management/workload management.xcodeproj/xcshareddata/xcschemes/Screenshots-zhHans.xcscheme`).

The scheme injects these launch arguments to force the app into Simplified Chinese while reusing the existing `SCREENSHOT_MODE` seed path in `AppRouter.swift`:

```
SCREENSHOT_MODE
-AppleLanguages
(zh-Hans)
-AppleLocale
zh_Hans_CN
```

## Capture procedure (run on your dev machine — Xcode required)

1. Open `workload management/workload management.xcodeproj` in Xcode.
2. Select the **Screenshots-zhHans** scheme and the **iPhone 17 Pro Max** simulator.
3. Run the `ScreenshotTests` UI test target (Product → Test, or `⌘U` while the scheme is selected). The test drives each tab/sheet and saves screenshots into the test's xcresult bundle.
4. Extract PNGs from the xcresult:

   ```bash
   # if xcparse is installed
   xcparse screenshots <path/to/xcresult-bundle> ./screenshots-zhHans/

   # or via Xcode → Report Navigator → right-click each attached screenshot → Export
   ```

5. Rename to the canonical filenames below and place them in this directory.

## Required files (minimum 6, ideally 8)

| Filename                              | Surface                                   |
| ------------------------------------- | ----------------------------------------- |
| `01-dashboard.png`                    | Dashboard hero readiness + metrics strip  |
| `02-workload.png`                     | Workload tab (ACWR chart, EWMA history)   |
| `03-recovery.png`                     | Recovery tab (HRV + sleep trends)         |
| `04-workout-log.png`                  | Workout Log (session list + active sheet) |
| `05-profile.png`                      | Profile tab                               |
| `06-paywall.png`                      | UpgradeSheet paywall                      |
| `07-onboarding-language-step.png`     | Onboarding language step (optional)       |
| `08-onboarding-frequency-step.png`    | Onboarding frequency step (optional)      |

## Per-file resolution check

```bash
for f in .planning/phases/23-multi-language-in-app-support-simplified-chinese/screenshots-zhHans/*.png; do
  h=$(sips -g pixelHeight "$f" 2>/dev/null | awk '/pixelHeight/ {print $2}')
  w=$(sips -g pixelWidth  "$f" 2>/dev/null | awk '/pixelWidth/  {print $2}')
  [ "$h" = "2868" ] && [ "$w" = "1320" ] && echo "OK   $f ($w x $h)" || echo "FAIL $f ($w x $h)"
done
```

## Visual sanity audit

While rendering, scan each screenshot for:

- **English fallback strings.** Any visible English label means a key is missing from `Localizable.xcstrings` zh-Hans values — capture the key + screen, then translate in catalog (Plan 23-04 work) before re-rendering.
- **Glyph fallback (squares / Latin-style ideographs).** Means Noto Sans SC cascade (Plan 23-03) isn't loading. Confirm font registration in `WorkloadApp.swift`.
- **Layout overflow.** ZoneBadge / MetricTile horizontal padding is locale-conditional (zh-Hans:16, en:10) — confirm via Plan 23-02 audit.

## Upload to App Store Connect

Once all PNGs validate at 1320 × 2868 and pass the visual audit, upload them through the human-verify checkpoint described in `23-05-PLAN.md` Task 3. Claude never uploads to ASC autonomously (memory `feedback_asc_caution.md`).
