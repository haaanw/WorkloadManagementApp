# v1.7.2 — session distribution prompts (2026-08-21)

Three parallel lanes. Paste one prompt per fresh Claude Code session, opened in
`/Users/hanwen/dev/Tonus`. The project CLAUDE.md loads automatically; each
prompt only sets the lane, its boundaries, and its gate.

**Collision rules (all lanes):**
- Lane A owns `WorkloadApp/Views/WorkoutLog/` + `Components/SetEntryFields.swift`
  AFTER its demo gate; before the gate it writes only `.design-explorations/`.
- Lane B owns everything else in app code, but must NOT touch
  `Views/WorkoutLog/` while Lane A is past its gate — file WorkoutLog findings
  to Lane A instead (via `.planning/v172/AUDIT-HANDOFF.md`).
- Lane C writes only `.planning/asc/`, `appstore screenshots/`,
  `scripts/frame_screenshots.swift`, `ScreenshotTests`, and seed data behind
  `SCREENSHOT_MODE`.
- `.pbxproj`: serialize — a lane edits it only in a turn where HAN confirms no
  other lane is mid-commit.
- Nobody pushes; nobody touches App Store Connect. HAN ships.

---

## Lane A — Objective 1: logging UI/UX overhaul (demo-first)

```
v1.7.2 Objective 1 — workout-logging UI/UX overhaul. Read
.planning/v172/SCOPE.md Objective 1 first.

You are the design lane. Work demo-first, exactly like the Session W /
set-entry-v2 pattern: build interactive HTML demos in
.design-explorations/logging-v3-demo/ (untracked, zero app-code changes, zero
commits) and publish them to me as a private artifact for review. I gate the
direction before any Swift is written.

Opening item, non-negotiable: the ALWAYS-VISIBLE SCRUB SCALE. My standing
critique of the current well scrub: you cannot know where a swipe lands before
touching it. The value landscape must be visible at rest, not only mid-drag.
Study the current implementation in Components/SetEntryFields.swift and
ActiveWorkoutSheet first — rounds 1–8 of the 1.7.1 UAT are recorded in
.planning/v171-hotfix/ and the pair board history; do not re-propose anything
those rounds already killed (radial wheel, reps tape, per-set RPE UI).

After the scrub scale, the broader mandate: exercise cards, set-list density,
finish flow, template interplay, one-handed reach. Multiple variants per demo,
first-time vs has-history states, DESIGN.md v6 tokens throughout (read
DESIGN.md and design-system/ before drawing anything).

After I pick a direction: port it into the app. You then own
WorkloadApp/Views/WorkoutLog/ and Components/SetEntryFields.swift. Voice
logging (LogCaptureSheet, VoiceDictationCard) shipped in this release — the
redesign must keep both entry points working. Suite green + design fences green
before any commit. No push, no ASC.
```

---

## Lane B — Objective 2: codebase audit

```
v1.7.2 Objective 2 — codebase review/audit. Read .planning/v172/SCOPE.md
Objective 2 first, then .planning/v171-hotfix/AUDIT-2026-08-05.md in full.

Mandate: find bugs, simplify, optimize structure. Work the standing debt in
this order:

1. The 31 ranked findings from AUDIT-2026-08-05.md — highest first: deletion
   resurrection (needs tombstones + schema migration), athlete-field pull gaps,
   bootstrapAthlete zombie sign-out. Verify each finding still reproduces in
   source before fixing it; some may have been fixed in the eight 1.7.1 UAT
   rounds.
2. HealthKit protocol seam so pipeline tests are hermetic (the
   VerdictSurfaceActivationTests timing fragility is the motivating incident —
   see pair board C-v171g-002).
3. Views/Coach/ deletion (compiles unmounted; its gating condition passed) plus
   retired-UIKit leftovers and unused strings/keys.
4. ScreenshotTests defensive launch-retry (boot flake, 3 sightings).
5. Bodyweight option C: athlete body mass via HealthKit read → true total-load
   math (today 0 kg = BW by convention, external-only volume).

Constraints: batch fixes in small commits with tests; run the full suite before
each commit (xcodebuild, -derivedDataPath ~/.tonus-dd-claude). Do NOT touch
WorkloadApp/Views/WorkoutLog/ — a parallel session owns it; write any WorkoutLog
findings to .planning/v172/AUDIT-HANDOFF.md instead of fixing them. Serialize
.pbxproj edits through me. Schema changes ship as a new numbered file in
Supabase/migrations/ (I run SQL; give me a labeled copy-paste block). No push,
no ASC.
```

---

## Lane C — Objective 3: ASO + App Store screenshots

```
v1.7.2 Objective 3 — ASO + App Store screenshot optimization. Read
.planning/v172/SCOPE.md Objective 3 first. The current listing is a basic
version; make it a considered one.

Current state: listing texts in .planning/asc/ (promo, description, What's New;
en + zh-Hans). Screenshot pipeline: ScreenshotTests + SCREENSHOT_MODE seed data
+ scripts/frame_screenshots.swift for framed captions; last sets shot for v1.7.
Positioning canon: CLAUDE.md Project section, CONTEXT.md vocabulary,
docs/adr/0001 (beachhead: amateur competitive basketball players who also
strength-train). Marketing flags: sleep score v2 is HAN-designated flagship
messaging BUT the engine is unshipped — claims must grade to engine status
(design-system §10 claim rails); voice logging IS shipping in 1.7.2 and should
lead the What's New.

Deliverables, all drafts for my review — nothing goes to ASC without me:
1. Keyword/metadata audit: title, subtitle, keyword field, en + zh-Hans.
   Research the actual competitive ASO landscape (Whoop, Bevel, TrainingPeaks,
   generic gym loggers) before proposing keywords.
2. Rewritten description + promo text, en + zh-Hans, claim-graded. The EULA
   link MUST stay in the description body (App Review rejection lesson —
   twice). NSHealthUpdateUsageDescription stays; demo account stays in review
   notes.
3. Screenshot story pass: proposed shot order + captions per screen (en +
   zh-Hans), then regenerate the sets — improve the seeded data if it reads
   fake or thin. A voice-logging shot joins the set.
4. A short A/B rationale: what each change is expected to move (impressions vs
   conversion) so we can judge it after release.

Write drafts to .planning/asc/v172-draft/. You own .planning/asc/,
"appstore screenshots/", scripts/frame_screenshots.swift, ScreenshotTests, and
SCREENSHOT_MODE seed code — nothing else. No push, no ASC mutation.
```
