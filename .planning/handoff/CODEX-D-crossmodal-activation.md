# CODEX-D — Activate cross-modal so it actually drives the verdict (+ make it a dogfood objective)

**Why:** the flagship story ("last night's game hammered your legs, today's squat is down, your bench is fine") is Tuwa's core differentiator vs Garmin, and it's on the website + ASO copy — but `CrossModalShadowGate.crossModalDrivesVerdict` ships `false`, so cross-modal is computed and then FORBIDDEN from changing the verdict. Decision (2026-07-08): flip it on and let the founder's n=1 dogfood validate it live. Nothing publishes until the dogfood gate passes, so shipping the flip in this build is safe.

## Ground rules
- **RUN NO GIT COMMANDS AT ALL** (not status/diff/add/commit/reset). The orchestrator owns git. Leave edits in the working tree, report.
- **Do NOT edit `WorkloadApp/App/AppShell.swift`** — another session (CODEX-B) is editing it concurrently. If you find the shell does NOT pass the cross-modal result into the verdict evaluation and a shell edit is genuinely required, STOP and report that precisely instead of editing AppShell.
- Do NOT read `~/.claude/`, `.claude/skills/`, `agents/`.
- Edit scope: `WorkloadApp/Services/` (CrossModalShadowGate, TodayVerdictService, TodayVerdictEngine, VerdictReasonBuilder as needed), `WorkloadApp/Resources/Localizable.xcstrings` (surgical insertion-only, en+zh-Hans, if new reason keys are needed), NEW test files in `WorkloadAppTests/`, and the doc `.planning/notes/dogfood-protocol-n1.md`. Never touch pbxproj.

## Read first
`CONTEXT.md` (Carry, Verdict, Microdose), `CLAUDE.md`, `docs/adr/0002-match-proximity-not-forecast.md`, `.planning/notes/dogfood-protocol-n1.md`, and the audit `../tuwa-website/.planning/CLAIM-AUDIT.md` (the inflated cross-modal claims this makes true). Then trace the FULL chain: `CrossModalFatigueEngine` → `TodayVerdictService.evaluate*` (where the cross-modal result is computed) → `TodayVerdictEngine.evaluate(...)` (where `if CrossModalShadowGate.crossModalDrivesVerdict` applies `cross.exerciseAdjustment(forRegion:)` to `effectiveFactor`, re-clamped to the −10% ceiling) → `VerdictReasonBuilder` (the reason line).

## Tasks
1. **Verify the chain is live before flipping.** Confirm the cross-modal result is actually COMPUTED and PASSED into the engine `evaluate()` in the path the running app uses (`evaluateAndWrite`). If it is computed but not passed (so flipping the flag would do nothing), fix the Services-layer wiring so the real result flows in. If the ONLY missing link is in AppShell, STOP and report (see ground rules).
2. **Flip the gate:** `CrossModalShadowGate.crossModalDrivesVerdict` → `true` as the shipped default. Keep the flag (don't delete it) so it remains revertible. Document at the flag: activated 2026-07-08 for n=1 dogfood validation; revert if the dogfood shows cross-modal misfires.
3. **Preserve all existing bounds:** cross-modal may only tighten (never loosen) the number; the −10% hard ceiling stays; cold-start still defers rather than trimming on a guess; anti-nocebo (never →HOLD from cross-modal). If any of these aren't already enforced on the gate-on path, enforce them.
4. **Reason line:** when cross-modal materially drove the trim, the one-line reason should say so in plain language (e.g. "Yesterday's game loaded your legs — easing today's squat"). Region-aware (legs vs upper). Reuse existing reason keys if present; add new ones en+zh-Hans surgically only if needed. Keep it a single calm line; when match-proximity ALSO fires, match-proximity/microdose framing takes precedence (don't stack two clauses).
5. **Dogfood protocol update:** add a criterion to `.planning/notes/dogfood-protocol-n1.md` — cross-modal validation: over the window, on days where cross-modal drove the difference, the felt-right signal must support it (e.g. ≥60% of cross-modal-driven trims felt right, and no systematic wrong-direction pattern). If it fails, the action is: revert the gate to false + soften the website/ASO cross-modal copy (the (b) fallback). Keep the pre-registered spirit — this is a real, falsifiable objective, not a rubber stamp.

## Tests
- Gate-on: a cross-modal leg penalty tightens a squat verdict; spares an upper-body lift (region attribution). Gate-off (flag false) reproduces the exact prior numbers (regression — prove the flip is the only behavioral change).
- Bounds: cross-modal can't push below −10%; can't loosen; can't force HOLD; cold-start still defers.
- Reason line reflects cross-modal when it drove the trim; yields to microdose framing when a match is near.

## Gate (run yourself, report exact numbers)
`xcodebuild build …` then `xcodebuild test … -only-testing:WorkloadAppTests -derivedDataPath /tmp/dd-codexD` on `platform=iOS Simulator,name=iPhone 17 Pro Max`, project `"workload management/workload management.xcodeproj"`, scheme `"workload management"`. 0 failures (2 pre-existing skips OK). If the sandbox blocks xcodebuild, say so — do not claim green without running.

## Report
What the chain looked like before (was cross-modal reaching the engine?); exactly what you changed to make the flag meaningful; the bounds you verified; new vs reused reason keys; the dogfood criterion added; exact gate counts; whether any AppShell edit was needed (and if so, what you STOPPED on).
