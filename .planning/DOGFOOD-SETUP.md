# Dogfood setup — get Tuwa on your iPhone

One-time, ~15 min. No App Store Connect, no TestFlight, no review needed — this is a direct debug build to your own device.

## 0. Prereqs
- Your iPhone + its USB cable (first install is easiest wired; wireless works after).
- Apple Watch (or Oura/Whoop/Garmin) already feeding HRV / resting HR / sleep into Apple Health. The verdict's readiness context needs this.
- You're signed into Xcode with your Apple ID: Xcode → Settings → Accounts → (+) Apple ID. A free account is fine for personal-device installs (7-day resign cadence); your paid developer account avoids the weekly re-sign.

## 1. Open + point at your device
1. Open `workload management/workload management.xcodeproj` in Xcode.
2. Plug in the iPhone. Top toolbar run-destination dropdown → pick your iPhone (not a simulator). First time: "trust this computer" on the phone.

## 2. Signing (one-time)
1. Select the **workload management** target → **Signing & Capabilities**.
2. **Automatically manage signing** = ON. Team = your Apple ID team.
3. If the bundle id `com.tonus.app` collides on a free account, change it to something unique for personal use (e.g. `com.<you>.tuwa`) — but note that changes the identity, so keep it stable across the 6 weeks so your logged data persists.
4. Capabilities to confirm present: **HealthKit** (already configured). Info.plist already has the HealthKit usage strings.

## 3. Run to device
1. Product → Run (⌘R). It builds, installs, launches on your phone.
2. First launch on the phone: Settings → General → VPN & Device Management → trust your developer cert (free-account requirement).
3. **Do NOT pass `SCREENSHOT_MODE`** — that's the seeded demo path for App Store screenshots. For the real dogfood you want the empty real app.

## 4. In-app, day one
1. Grant HealthKit permissions when prompted (HRV, RHR, sleep).
2. Enter your real training plan / today's planned lift on the Train tab.
3. Set your next scheduled match date when you have one.

## Expect on the first few days
- With no logged history yet, the verdict will read **"Learning" / defer** rather than trimming — this is correct, not a bug. It needs a few days of readiness + session data to build your personal baselines before it starts issuing real go/modify/hold numbers.
- Cross-modal (game→legs→squat) only shows once you've logged a hard match within the carry window.

## The 6-week loop
See `.planning/notes/dogfood-protocol-n1.md` for the pre-registered criteria. Daily: read the verdict → accept or keep-as-written (logged) → train → next morning answer "felt right?". Log every session with its tier (pickup/scrimmage/match). Watch the Measurement screen for running aggregates. Hunt for ≥1 clearly-wrong verdict.

## One caveat carried from the build (defer-list item)
Timezone: the next-match date and felt-right eligibility normalize to your *current* device timezone. If you stay in one timezone the whole window (likely), no issue. If you travel across timezones mid-window, dates can shift a day — flagged for a fix, not yet hardened.
