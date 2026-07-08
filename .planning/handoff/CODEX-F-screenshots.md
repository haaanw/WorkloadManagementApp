# CODEX-F — App Store screenshots: seed + capture the v2.1 basketball surfaces

**Run in the APP repo** (`/Users/hanwen/Desktop/Tonus`). Prep-only; screenshots publish only after the dogfood gate.

## Ground rules
- **RUN NO GIT COMMANDS AT ALL** (status/diff/add/commit/reset). Orchestrator owns git.
- Do NOT read `~/.claude/`, `.claude/skills/`, `agents/`.
- Edit scope: the SCREENSHOT_MODE seed path (find it — `AppRouter.swift` seeds mock data under the `SCREENSHOT_MODE` launch arg), the ScreenshotTests XCUI target (`WorkloadAppTests`/`ScreenshotTests` — whatever hosts the existing capture flow), and `scripts/frame_screenshots.swift` only if framing needs adjustment. Do NOT touch production app logic, Services, or AppShell beyond what seeding requires. Never pbxproj.

## Read first
`CLAUDE.md`, `CONTEXT.md`, `DESIGN.md`, `.planning/store/screenshot-copy.md` (the overlay copy already drafted — 6 frames), and study the EXISTING screenshot pipeline: how `SCREENSHOT_MODE` seeds data (`AppRouter.swift`), how `ScreenshotTests` drives the UIKit shell and captures (there IS a working `ScreenshotTests-Runner` — a prior audit ran it via `xcodebuild test-without-building`), and how `scripts/frame_screenshots.swift` frames the raw captures.

## The gap to close
The current seed does NOT surface the new v2.1 basketball surfaces. Extend the SCREENSHOT_MODE seed so the running UIKit shell shows, in a basketball scenario:
1. **Today verdict card** in a MODIFY/microdose state — adjusted top-set number, strike-zone bar, one-line reason. Requires: a seeded planned strength session (a squat day) + a scheduled next match ≤2 days out so proximity fires the microdose, + enough recovery/HRV history that the engine produces a real (non-deferred) verdict.
2. **Next-match row** in the set state ("Match in 2 days").
3. **Cross-modal** visible: seed a recent hard basketball `.match` session so the verdict reason reflects game→legs carry (cross-modal now drives the verdict as of 2026-07-08).
4. **Match-tier logging**, **Insights/load**, **readiness** — the existing screens with basketball-flavored data (a hoop athlete profile, match sessions in history).

Keep the seed DEBUG-only and SCREENSHOT_MODE-gated (never affects real users). Follow the existing seed's patterns.

## Capture + frame
Drive the existing ScreenshotTests flow to capture the 6 frames mapped in `.planning/store/screenshot-copy.md` (both light — app is light-only — and produce the zh-Hans locale set too if the pipeline already supports locale switching). Frame them via `scripts/frame_screenshots.swift`. Output raw + framed PNGs to a clearly-named folder under the repo (e.g. `Tuwa-v2.1-AppStoreScreens/`).

## Verify + report
Build must succeed; the ScreenshotTests capture run must pass. Report: seed changes made (file:line), which of the 6 frames were successfully captured (and any that couldn't be reached + why), output folder path, exact test/capture result. If a surface can't be seeded into view, say so honestly rather than shipping a blank frame.
