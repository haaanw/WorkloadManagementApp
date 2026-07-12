# CODEX-H — Fix the tab-switch content collapse (keep the glass rail, keep data refresh)

**Run AFTER CODEX-G's exercise work is committed** (same shell files). Baseline = the post-G commit.

## Bug
Switching bottom tabs makes the incoming tab's CONTENT visibly collapse into the top-left corner then re-expand. The liquid-glass tab-rail switch itself is liked — keep it. Only the content collapse is wrong.

## Root cause (confirmed)
`WorkloadApp/App/AppShellUIKitPrimitives.swift:543-546` — `InstrumentScrollViewController.viewWillAppear` calls `rebuild()` on every appearance. `rebuild()` → `clearContent()` (line ~556) removes ALL arranged subviews from `contentStack`, so the stack momentarily has zero intrinsic size, then re-expands as sections are re-added. That empty→full Auto Layout pass, happening during the tab-bar's animated transition, renders as the collapse-to-corner-then-reopen. The content VC is REUSED (cached in `AppTabBarController`), not recreated.

## The fix — DO NOT use "only rebuild if empty"
An earlier analysis suggested `if contentStack.arrangedSubviews.isEmpty { rebuild() }`. **REJECT that** — the tabs rebuild on appear specifically to show FRESH data (updated verdict, new sessions, new aggregates). Skipping rebuild when content exists would show STALE content when returning to a tab. Not acceptable.

Instead, keep rebuilding for freshness but make the content swap ATOMIC and non-animated so there is no visible zero-size flash:

1. In the rebuild path (either `viewWillAppear` around the `rebuild()` call, or inside `rebuild()`/`clearContent()`+re-add — pick the tightest single site), wrap the clear + re-add of sections in `UIView.performWithoutAnimation { … }` and force a synchronous `contentStack.layoutIfNeeded()` (or the scroll view's) at the end, so the incoming view is fully laid out BEFORE the tab transition captures/renders it.
2. Ensure this doesn't fight the tab-bar transition: the goal is that when the glass transition brings the new tab's view in, that view is ALREADY complete — the rebuild's layout must be committed synchronously and unanimated within `viewWillAppear`, not deferred.
3. If `performWithoutAnimation` alone isn't enough (some implicit CoreAnimation still leaks), also disable UIView animations explicitly around the arranged-subview mutations (`UIView.setAnimationsEnabled(false) … true`) or rebuild into a detached state before inserting. Choose the minimal combination that eliminates the flash.

Verify the fix preserves: (a) data still refreshes on every tab return (switch away, change nothing vs change data, come back — content reflects current state), (b) the liquid-glass rail switch animation is untouched, (c) reduce-motion path still works.

## Ground rules
- **RUN NO GIT COMMANDS AT ALL.** Orchestrator owns git.
- Edit only `AppShellUIKitPrimitives.swift` (and `AppShell.swift` only if the tightest fix truly requires it). Never pbxproj. Services untouched.
- DESIGN.md compliant; no behavior change beyond removing the collapse.

## Test + gate
Add a guard/unit test if the change is unit-testable (e.g. a helper that asserts rebuild happens but within a non-animated transaction — source-grep guard is acceptable given this is UIKit animation timing). Build + `xcodebuild test … -only-testing:WorkloadAppTests -derivedDataPath /tmp/dd-codexH`, 0 failures (pre-existing skips OK).

## Report
Exact site changed (file:line), how you made the swap atomic, how you verified refresh is preserved (not the rejected empty-check), gate counts.
