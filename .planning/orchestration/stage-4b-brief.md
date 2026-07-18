# Stage 4b Brief — ScreenshotTests Rewrite (SwiftUI surface)

Lane contract for the Stage 4b test-rewrite worker. Orchestrator verifies + commits. Prerequisites: Stages R…4a (`36747b8`…`be760cd`). Read `.planning/orchestration/2026-07-14-v16-ui-polish.md` (Stage 4b, D7) first.

## Mission
The 49 XCUITests in `ScreenshotTests/` assert the retired UIKit shell's identifiers and fail by design since the Stage R rehost. Rewrite them against the live SwiftUI surface so (a) the UI test suite is green again and (b) the ASO screenshot harness (App Store captures) works for v1.6 visuals.

## Ground truth
- Launch path: `SCREENSHOT_MODE` launch argument bypasses auth + seeds data (AppRouter DEBUG block). Loading surface keeps `app.loading` IDs.
- New stable IDs from Stage 4a: tab bar container `tabbar.ink`; items `tab.home`, `tab.log`, `tab.recovery`, `tab.load`, `tab.profile`. Known surviving IDs: `workoutLog.startWorkout`, `export.workoutData`. Discover the rest by reading the Views — and where a test genuinely needs an anchor that doesn't exist, ADD a minimal `accessibilityIdentifier` to the SwiftUI view (additive only, no layout/behavior changes, note each addition in the report).
- The movement-bank surfaces (ExercisePickerView, ExerciseDetailSheet, MovementBankView) are NEW since the old tests — cover picker open + search minimally if the old suite covered exercise selection; do not gold-plate.
- Old tests' ASO capture flow (framed screenshots per locale, if present) must keep working: preserve the capture entry points / naming scheme so the marketing pipeline can be re-run for v1.6. If the old harness hardcoded shell flows, port the flow, keep the output contract.

## Execution rules
- You MAY run the UI tests, but ONLY scoped: `xcodebuild … -derivedDataPath ~/.tonus-dd test -only-testing:ScreenshotTests` (destination `id=8E872500-703D-4292-9758-38ADFCCFB126`, project/scheme per stage-1-brief.md). NEVER the full suite (orchestrator's job), NEVER plain `test`.
- Before every xcodebuild run: `pgrep -fl xcodebuild` — if another build is running (a parallel session exists in this checkout), WAIT and retry; never run concurrently.
- NO git commands. Test files under ScreenshotTests/ auto-sync (no pbxproj edits needed for them); any APP file you touch (a11y IDs only) must stay fence-clean.
- If a test's old assertion has no meaningful SwiftUI equivalent (e.g. coach-mode shell screens), DELETE it and record why — don't port dead surfaces. Coach mode is intentionally absent from the SwiftUI app.
- Do not weaken the suite into screenshot-only smoke: keep at least the depth of assertions the old tests had (element exists / label text), adapted to the new chrome.

## Deliverable
Report: final test count (was 49) with per-group disposition (ported / rewritten / deleted+why); every app-file a11y-ID addition; ASO harness status + how to run it; verbatim tail of your last `-only-testing:ScreenshotTests` run (must be green); flaky tests if any with mitigation.
