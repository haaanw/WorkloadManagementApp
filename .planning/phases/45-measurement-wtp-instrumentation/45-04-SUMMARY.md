---
phase: 45-measurement-wtp-instrumentation
plan: 04
subsystem: measurement
tags: [sean-ellis, wtp, revenuecat, paywall-reuse, local-only, design-system, localization, deferred-external]

requires:
  - phase: 45-measurement-wtp-instrumentation
    provides: VerdictEventRepository.fetchAll count (45-01); WorkoutLog verdict host (45-02/03)
  - phase: 04-subscriptions
    provides: UpgradeSheet + SubscriptionService (RevenueCat) — reused, not modified
provides:
  - SeanEllisStore (local-only, injectable disappointment persistence + deterministic trigger)
  - SeanEllisPromptSheet (very/somewhat/not equal-weight prompt)
  - WorkoutLog trigger mount + very-disappointed → existing RevenueCat paywall (WTP/card-on-file)
affects: []

tech-stack:
  added: []
  patterns:
    - "Local-only UserDefaults store, injectable for deterministic tests (no .standard, no baked .now in the gate)"
    - "Reuse existing paywall (UpgradeSheet(trigger: .athletePro)) for the revealed-WTP hop — no new paywall code"
    - "Deferred-external flagged in-source for RevenueCat dashboard trial→paid config"

key-files:
  created:
    - WorkloadApp/Services/SeanEllisStore.swift
    - WorkloadApp/Views/Profile/SeanEllisPromptSheet.swift
    - WorkloadAppTests/SeanEllisStoreTests.swift
  modified:
    - WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift
    - WorkloadApp/Resources/Localizable.xcstrings
    - "workload management/workload management.xcodeproj/project.pbxproj"

key-decisions:
  - "Trigger threshold = 5 logged verdict events; re-qualifies only after another full threshold of new events"
  - "Eligibility is a pure read of injected defaults + passed-in count; .now only stamps the recorded answer"
  - "very → existing UpgradeSheet(trigger: .athletePro); UpgradeSheet/SubscriptionService untouched"
  - "RevenueCat dashboard offering config + real charges = deferred-external (flagged in-source comment)"

patterns-established:
  - "Injectable local store for deterministic gate tests via UserDefaults(suiteName:)"
  - "Stated proxy (Sean-Ellis) → revealed signal (card-on-file paywall hop)"

requirements-completed: [METRIC-03]

duration: 25min
completed: 2026-06-14
---

# Phase 45 Plan 04: Sean-Ellis + WTP Instrumentation Summary

**Captured the Sean-Ellis disappointment signal (very/somewhat/not) in a local-only, deterministically-gated store and routed the strongest answer ("very disappointed") into the EXISTING RevenueCat paywall — the revealed willingness-to-pay / card-on-file hop — without adding any new paywall code. The RevenueCat dashboard trial→paid offering config is flagged deferred-external in-source.**

## Performance

- **Duration:** ~25 min
- **Tasks:** 2
- **Files created:** 3 (1 service, 1 view, 1 test)
- **Files modified:** 3 (WorkoutLogView, xcstrings, pbxproj)

## Accomplishments
- `SeanEllisStore`: a `struct` backed by an INJECTED `UserDefaults` (default `.standard`) — local-only, never Codable-to-Supabase, never networked. `recordAnswer`, `shouldPrompt(verdictEventCount:threshold:)`, `lastAnswer`. The gate is a pure read (no baked `.now`).
- `SeanEllisPromptSheet`: the single neutral question with three equal-weight choices via ONE shared `choiceButton` builder — DESIGN-compliant (Rectangle, no shadow, Font.Tokens.*, no accent), en+zh-Hans, no guilt/upsell in the question.
- `WorkoutLogView` mounts the trigger in `.task(id:)`: reads `fetchAll(athlete:).count`, gates via `SeanEllisStore().shouldPrompt(...)`, presents the prompt, records the answer locally, and on `.very` presents the existing `UpgradeSheet(trigger: .athletePro)`.
- `SeanEllisStoreTests`: isolated `UserDefaults(suiteName:)` — proves below-threshold quiet, at-threshold fire (never answered), immediate post-answer quiet, and re-qualification after another threshold of new events.

## WTP / card-on-file path (as implemented)
```
.sheet(isPresented: $showSeanEllis) {
    SeanEllisPromptSheet { answer in
        SeanEllisStore().recordAnswer(answer, atEventCount: seanEllisEventCount, on: .now)
        showSeanEllis = false
        if answer == .very { showWTPUpgrade = true }   // revealed-intent hop
    }
}
// DEFERRED-EXTERNAL: RevenueCat dashboard trial→paid offering config + real-charge testing (human)
.sheet(isPresented: $showWTPUpgrade) {
    UpgradeSheet(trigger: .athletePro).environment(container)   // REUSE — no new paywall code
}
```

## RevenueCat reuse + deferred-external
- **Reused as-is:** `UpgradeSheet(trigger: .athletePro)` + `SubscriptionService` — both files UNCHANGED (verified via `git status`). The "Start Free Trial" CTA already appears when the package has an `introductoryDiscount`.
- **Deferred-external (not a blocker):** the RevenueCat dashboard OFFERING config (intro-trial product on the `athlete_pro` offering) + real-charge testing. `RevenueCatConfig` is gitignored; the CODE path is live and buildable here. Flagged with an in-source `DEFERRED-EXTERNAL` comment at the presentation site.

## Task Commits

1. **Task 1: SeanEllisStore + SeanEllisPromptSheet + store test** — `b88ae0d` (feat)
2. **Task 2: Mount trigger + very → existing paywall** — `e51bc58` (feat)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Transient zeroing of InfoPlist.xcstrings during concurrent build**
- **Found during:** final verification (not a task edit)
- **Issue:** Running an `xcodebuild build` concurrently with a `grep`/read over the Resources dir left `WorkloadApp/Resources/InfoPlist.xcstrings` momentarily zero-length on disk (git still reported it clean / 777 bytes via the cached stat), causing `** BUILD FAILED **` with "isn't in the correct format". The file is NOT part of this phase's edits.
- **Fix:** `rm` + `git checkout HEAD -- WorkloadApp/Resources/InfoPlist.xcstrings` restored the committed 777-byte valid-JSON file (byte-identical to HEAD). Subsequent serial build is green.
- **Files modified:** none committed (restored to HEAD state).
- **Verification:** `python3 -m json.tool` validates; `** BUILD SUCCEEDED **` on the serial re-run.

---

**Total deviations:** 1 auto-fixed (1 blocking, environment/tooling — no source change).
**Impact on plan:** No production change; a transient on-disk corruption of an unrelated, untouched file, restored from HEAD. No scope creep.

## Issues Encountered
- The transient InfoPlist.xcstrings zeroing above. Lesson for the phase: do not run `xcodebuild` concurrently with reads/greps over `Resources/` — the build system holds xcstrings open.

## User Setup Required
- **RevenueCat (deferred-external/human):** Configure the trial→paid offering (intro-trial product) on the `athlete_pro` offering so the reused `UpgradeSheet` can start a trial. Location: RevenueCat Dashboard → Offerings → athlete_pro. Real charges tested by a human. UI may differ from these notes — confirm what you see before proceeding.

## Next Phase Readiness
- METRIC-01/02/03 + SC4 are all instrumented and green. The verdict surface can now reach validation users with measurement live.

## Self-Check: PASSED
- WorkloadApp/Services/SeanEllisStore.swift — FOUND
- WorkloadApp/Views/Profile/SeanEllisPromptSheet.swift — FOUND
- WorkloadAppTests/SeanEllisStoreTests.swift — FOUND
- Commit b88ae0d — FOUND
- Commit e51bc58 — FOUND

---
*Phase: 45-measurement-wtp-instrumentation*
*Completed: 2026-06-14*
