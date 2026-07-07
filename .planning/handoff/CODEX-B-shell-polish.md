# CODEX-B — Shell polish: mechanical fixes from the on-sim visual audit

**Run ONLY after CODEX-A's work is committed** (same file: AppShell.swift). Baseline will be the post-A commit.

## Ground rules
Same as CODEX-A: work in tree, no git mutations, edit only AppShell.swift / AppShellUIKitPrimitives.swift / Localizable.xcstrings (surgical) / new test files; never pbxproj; service layer read-only. Read `DESIGN.md` first (light-only, 0pt corners, no shadows, accent rules).

## Fixes (all verified by an on-sim visual audit, screenshots in /tmp/track2-audit/ if still present)

1. **Segmented control separator stretching (most broken element in the app):** `AppShellUIKitPrimitives.swift:370–386` (`InstrumentSegmentedControlUIKit.setup`) — `stack.distribution = .fillEqually` stretches the vertical hairline separators to full segment width, rendering grey slabs. Fix: fixed-width (hairline) separators; buttons share remaining width equally. Affects Insights en+zh.
2. **Primary CTA outline is dividerStrong, should be accent:** DESIGN.md Accent Rule #4 sanctions "primary CTA as an accent outline". Start Session / Start Workout / Sign In / Continue currently grey, indistinguishable from secondary. Fix in the shared primary-button builder — one change, verify Login hierarchy improves (Sign In vs Create account vs Google must differ).
3. **Trailing values/actions ragged:** row builders place trailing text a fixed gap after the title so the value column wanders (Train "Start" at x≈493/570/491/524; Insights trend values misaligned). Session Settings and Paywall rows already right-align correctly — converge the shared row builders on right-aligned-before-chevron.
4. **Pluralization bug:** Train rows "Skill · 1 exercises" — use proper singular/plural (stringsdict-style or conditional key) en+zh.
5. **Raw state labels leak:** a card reading "Idle" on Login, "Ready" on the paywall — hide the plate when idle or give human copy.
6. **iOS 26 glass "Cancel" capsule** on sheet nav bars (ActiveWorkout/Upgrade sheets in the shell): rounded pill + glass violates 0pt/no-shadow rules — style bar buttons explicitly (plain text button appearance).
7. **zh-Hans gaps on Insights-Load:** mixed string "负荷平稳 · Updated 今天"; untranslated "LOAD" kicker, "Load balance", "Volume", "Acute/Chronic/Balance" captions. Add the missing zh-Hans values (xcstrings surgical).
8. **ActiveWorkout format drift:** "0 / 2 sets done" (spaced) vs "0/2 sets" (unspaced) — pick one (unspaced) both places.

## Gate
Build + full `WorkloadAppTests` (same commands as CODEX-A), 0 failures. Report exact counts + per-fix file:line summary.
