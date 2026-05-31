# Tuwa 1.4 — submission guide (the human steps)

Code is done + on origin/main, version 1.4 (build 12), edge function deployed. Below is everything left, in order. Artifacts: release notes → `release-notes-1.4.md`; listing copy → `asc-listing-1.4.md`.

---

## 1. Screenshots (per locale, per device size)

App Store Connect needs screenshots for at least the **6.9"/6.7" iPhone** slot (others optional/auto-scaled). You need both **English** and **简体中文** sets.

How they're generated here (XCUITest `ScreenshotTests`, 6 screens: Dashboard, Workload, Recovery, WorkoutLog, CoachRoster, PDFExport):

```
# English
xcodebuild test -project "workload management/workload management.xcodeproj" \
  -scheme "workload management" \
  -destination 'platform=iOS Simulator,id=<iPhone 17 Pro Max id>' \
  -only-testing:ScreenshotTests \
  -resultBundlePath /tmp/shots-en.xcresult

# Simplified Chinese
xcodebuild test ... -only-testing:ScreenshotTests \
  -testLanguage zh-Hans -testRegion CN \
  -resultBundlePath /tmp/shots-zh.xcresult
```

Extract PNGs from the result bundle:
```
xcrun xcresulttool export attachments --path /tmp/shots-zh.xcresult --output-path /tmp/shots-zh-out
```
(If that yields an empty manifest, open the .xcresult in Xcode → Report navigator → the test → attachments → drag the images out. Or use the `xcparse` tool: `brew install chargepoint/xcparse/xcparse` then `xcparse screenshots /tmp/shots-zh.xcresult /tmp/shots-zh-out`.)

Notes:
- The tests run in `SCREENSHOT_MODE` (seeded mock data, auth bypassed) — clean marketing data.
- Recommended ordering for the 6 store slots: Dashboard (readiness) → Recovery → Workload (load/ACWR) → WorkoutLog → CoachRoster → PDFExport.
- Capture on the largest sim you have (iPhone 17 Pro Max) for the 6.9" slot; ASC accepts that size and down-scales for smaller required sizes if you don't supply them.

---

## 2. zh-Hans human review (BLOCKING for a Chinese release)
- Native-speaker pass on brand/marketing strings: `auth.brand.wordmark`, `auth.brand.tagline`, `auth.signup.subhead`, and the App Store description/keywords in `asc-listing-1.4.md`.
- Verify the 4 muscle terms render naturally: hipRotators, tibialisAnterior, transverseAbdominis, erectors.
- Eyeball CJK font cascade on a zh-Hans device (General Sans Latin + the CJK fallback) — check no tofu boxes, line breaks look right.

---

## 3. Device UAT (real iPhone, not just sim)
- Phase 21 radial gesture picker: long-press → ring appears, drag selects, release confirms; haptics feel right.
- Phase 19 cycle UI: opt-in flow, dashboard cycle indicator, recovery card phase context (only if you have Apple Health cycle data).
- Spot-check core flows in both English and 简体中文 (switch device language): log a workout, view recovery, view load.

---

## 4. Archive + upload (Xcode — you)
1. Select destination **Any iOS Device (arm64)** (not a simulator).
2. Confirm signing: your team, automatic signing, release provisioning.
3. **Product → Archive**.
4. In the Organizer: **Validate App** first (catches most rejections), then **Distribute App → App Store Connect → Upload**.
5. Confirm version **1.4**, build **12** in the uploaded build.

Pre-archive sanity: `RevenueCatConfig.swift` present (gitignored) and real keys in place; `SupabaseConfig.swift` correct; HealthKit + IAP capabilities on; PrivacyInfo.xcprivacy present.

---

## 5. App Store Connect (you)
1. Create the **1.4** version.
2. Paste **What's New** (release-notes-1.4.md) — EN + 简体中文.
3. Listing: subtitle / promo / keywords / description from `asc-listing-1.4.md` for **en-US** and add the **简体中文** localization.
4. Upload screenshots: EN set to en-US, 中文 set to zh-Hans.
5. Select the uploaded build (1.4 / 12).
6. Privacy / export compliance / content rights answers (carry over from 1.3 unless changed).
7. Review notes: mention SCREENSHOT_MODE is debug-only; HealthKit is read-only, raw data never leaves device; if a reviewer needs a demo account, provide one.

---

## 6. Submit
Your call. I will not auto-submit ([[feedback_asc_caution]]). Recommend "Manually release this version" so you control go-live after approval.

---

## What is NOT in this release (deliberately)
- The v1.6 readiness/strain "algorithm moat" ships **dormant** (flags FALSE) — no user-visible change, no store copy about it. Collecting shadow data for a future activation release. Don't mention "injury prediction" anywhere.
