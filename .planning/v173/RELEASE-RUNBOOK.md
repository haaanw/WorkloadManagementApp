# v1.7.3 release runbook (written 2026-09-13, for the closure orchestrator + HAN)

The chat-only parts of the archive guide, made durable. SCOPE.md holds the
release checklist; UAT-ROUND1 holds the findings/rulings; this file is the
end-game sequence.

## Remaining build work (two Opus 5 lanes, prompts issued by HAN)

- **Lane A — Log + Trends builds** (U7 option A, U8 demotion, U9 re-scope:
  fatigue history series, RHR detail screen, tap-through wiring).
- **Lane B — Profile completion** (U10 second half per PROFILE-IA.md),
  sports multi-select, background-delivery wiring (entitlement re-add is
  HAN's Xcode step; code = enableBackgroundDelivery + HKObserverQuery at
  launch driving WatchWorkoutImportService).

## Orchestrator duties (the verification layer)

1. Verify every lane claim against source and a FULL suite run — read
   counts from `xcrun xcresulttool get test-results summary`, never from
   truncated console tails (a hidden errors line has burned this project
   once). Baseline at handoff: **1289 passed / 0 failed / 2 skipped**;
   ScreenshotTests/test06_Profile is a known flake — isolate before
   believing a failure.
2. Build with `-derivedDataPath ~/.tonus-dd-claude`, never in-repo.
3. `.pbxproj`: serialize edits across lanes; check `git status` staged
   state before every commit while Xcode is open (Xcode auto-stages its
   template files — it has contaminated a commit once).
4. `cat`/`grep` output is RTK-filtered in this environment — use file
   Read when fidelity matters; negative greps are suspect.
5. Store plates: after Lane A changes Log/Trends shape, re-shoot BOTH
   locales (ScreenshotTests → `xcresulttool export attachments` → install
   into `appstore screenshots/1.7-{en,zh-Hans}/raw/` →
   `swift scripts/frame_screenshots.swift --all`; the guard fails closed —
   if Trends' captured composition changes, update the harness/specs, and
   check captions still tell the truth).
6. Docs: keep CLAUDE.md ⇄ AGENTS.md twins in lockstep for any
   project-wide fact; append lane outcomes to UAT-ROUND1; board entries to
   `.pair/claude.md` per PROTOCOL.md (atomic appends only).
7. No push, no ASC, no deploys without HAN's explicit go, ever.

## End-game sequence

1. Lanes land → orchestrator verifies (suite + spot source checks) →
   commits clean.
2. HAN re-runs the UAT round on device, clean. New findings loop back as
   fixes; clean pass proceeds.
3. HAN decision recap at archive time: `flag.onboardingV2` ON or dark
   (ON ⇒ ASC privacy label reconciled + PostHog disclosed FIRST — binding
   gate, CODEX concession on the board).
4. Push go: HAN says "push" → orchestrator pushes `main`.
5. HAN at ASC (Phase 3): baseline analytics note → archive 1.7.3 (21) →
   upload → create version 1.7.3 → **App Information page**: Name
   `Tuwa: Training Readiness` / `Tuwa - 准备度与训练负荷` + subtitles;
   **version page**: keywords — paste source
   `.planning/asc/v172-draft/8-fields-paste-ready.txt` → What's New from
   `.planning/asc/v173-draft/` (UPDATE both locales if Trends/Log copy
   changed materially) → screenshots: 9 plates per locale, filename order
   → EULA link stays in the description body; demo account
   2583710743@qq.com stays in review notes → select build, submit.
6. Post-approval: website push (if the marketing lane queued one), release
   records, v1.7.4 opens with the MCP research lane
   (`.planning/v174/MCP-CONNECTOR.md`).
