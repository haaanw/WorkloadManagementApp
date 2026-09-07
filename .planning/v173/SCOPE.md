# v1.7.3 — scope + release checklist (HAN, 2026-08-24)

One release, shipped when ALL of it is done (HAN ruling 2026-08-24: no thin
metadata release; the missed ASO fields wait for the full version).

## Release checklist — DO NOT SUBMIT 1.7.3 WITHOUT THESE

1. **The version-locked ASO fields (missed in the 1.7.2 submission).**
   Store still serves lowercase `tuwa` + old subtitle + old keywords in
   both storefronts. At submission time: **App Information** page → Name +
   Subtitle; **version page** → Keywords. Paste source:
   `.planning/asc/v172-draft/8-fields-paste-ready.txt`
   (`Tuwa: Training Readiness` / `Tuwa - 准备度与训练负荷`).
2. Demo account in review notes; EULA link stays in the description body;
   `NSHealthUpdateUsageDescription` stays.
3. Version is already bumped in-repo to 1.7.3 (21), commit `f12284f`,
   code-identical to live 1.7.2 today. Build number may advance with the
   feature work; the marketing version stands.

## Work queued for 1.7.3 (gathered; HAN prioritizes at kickoff)

- **Marketing lane** — `.planning/v173/MARKETING.md`: Twitter-first launch
  content (voice logging spearhead), SEO audit, GEO.
- **Science series** — `.planning/v173/SCIENCE-SERIES.md`: weekly cadence,
  three articles live on site; X + Substack editions in
  `tuwa-website/drafts/science-series/` await HAN's posting.
- **Audit leftovers deferred from 1.7.2** (`.planning/v172/AUDIT-HANDOFF.md`
  resolution log): localization-key prune (§3.3), L9 two-"week"s copy call
  (§3.5), L6 stage clipping (gated on the sleep-v2 shadow window closing),
  L8 push watermark (sync-contract design), L7 (female-athlete milestone).
- **Post-release validation on official 1.7.2** (can run any time, not
  gated on 1.7.3): `.planning/v172/VOICE-UAT.md` sections 1–3 + 5 on
  device; watch the first ReviewPromptGate ratings arrive; note the ASC
  baseline before the new listing fields land (for `10-ab-rationale.md`).
## App features — NAMED at kickoff (HAN, 2026-08-30)

1. **Voice logging round 2 — dogfood first.** HAN tries the shipped 1.7.2
   voice input on the official build (`.planning/v172/VOICE-UAT.md` is the
   script); his findings become the fix list. The improvement lane opens on
   his report, not before.
2. **Voice section UI redesign.** The capture surfaces (LogCaptureSheet,
   VoiceDictationCard) get a design pass. Demo-first per house style; folds
   in whatever round 1 dogfood surfaces, so it runs behind item 1.
3. **iOS home-screen widgets (WidgetKit).** New widget extension target —
   `.pbxproj` is CLAUDE-only and target creation is the big serialization
   point. Needs an App Group so the widget can read shared data; HealthKit
   raw data stays out of the shared container (composite scores only, same
   law as sync). Candidate widgets: today's readiness reading + verdict;
   training-load strip. Light-only, v6 tokens, no shadows — DESIGN.md binds
   widgets exactly as it binds the app.
4. **The onboarding journey — the approved v1.8 spec rides into this
   release** (HAN 2026-08-30). Spec: `.planning/v18/ONBOARDING.md` (APPROVED
   2026-08-24) + `.planning/v18/GROWTH-STACK.md`. ≤12 screens ending in the
   HealthKit-conditional hard paywall after a real readiness reveal,
   card-gated Apple trial, account creation at screen 10, PostHog behind
   UXAnalyticsService. GATE PASSED 2026-09-01 with amendments
   (BUILD-PLAN.md). **Version RULED (HAN 2026-09-03): ships as 1.7.3,
   final.** The ASO fields in checklist item 1 ride 1.7.3.

Added at kickoff round 2 (HAN, 2026-09-02), from the dogfood report
(`DOGFOOD-2026-09-01.md`):

5. **Launch fix — optimistic local-first open.** Cold open < 1 s for a
   returning user; pullAll / RevenueCat / pipelines move off the paint
   path. Background-freshness follow-on (HK background delivery +
   BGAppRefresh) after the optimistic launch ships.
6. **Plan-led logging round 2** — features 1+2 absorbed into the U2
   mandate: program in → today's proposal → check-in-adjusted numbers →
   voice-led capture. Demo-first, MULTIPLE directions, several rounds.
   Carries the B1 PDF fixes, B2 narrative capture (no silence stop), R1
   transcript quality, U1 import prominence.
7. **App-wide reorientation around easy logging (NEW, HAN 2026-09-02).**
   The whole app's UI/UX re-examined against the new center: logging and
   the daily adjustment are the product's spine, and every surface (Home
   hierarchy, tab priorities, navigation, empty states, import placement)
   should make that spine obvious and effortless. Phase 1 = experience
   audit + IA proposal (starts now); phase 2 = demos, after feature 6's
   direction locks so the two design languages cannot fork.

8. **App-wide color / visual-identity pass — MODE CHANGED (HAN 2026-09-03):
   discussion + demo iterations in the CLAUDE session**, replacing
   "HAN drives elsewhere." Process: direction discussion → visual demos
   (iterated like set-entry-v2) → HAN locks → DESIGN.md amendment lands
   FIRST → a carrier lane applies app-wide.
   **DIRECTION GATED (HAN 2026-09-03): A — area identity through the
   existing five metric hues** (low-chroma "area tint" role: hero-plane
   wash, tinted hairlines, section markers; hue = the metric family you
   are standing in). B (new accent family) and C (expressive color)
   REJECTED. No external reference app — develop the palette we own; HAN
   likes the existing accent/metric colors, they are underutilized.
   **LOCKED (HAN 2026-09-06, demo round 1): WARM stone + WHISPER** — the
   cooled ramp is rejected (warm ladder stands), tint role = 4% hero-plane
   wash + 18% hairline tint only; markers/tab-hue/card washes rejected.
   DESIGN.md v6.3 amendment LANDED (doc-first law honored). Remaining: the
   carrier lane applies it app-wide + design-system/tokens gains the two
   formulas. Original framing follows:
   HAN's ruling from the feature-6 round-1 gate: the app reads too
   monocolor-centric. Goal: use more of the brand colors — especially the
   accent — to (1) make the app more visually pleasant and (2) distinguish
   functions and areas by color so the interface is easier to identify and
   understand. HAN drives this himself in another venue; no lane builds it.
   NOTE: this collides with DESIGN.md v6 law (accent = live-state only, five
   metric hues never decorative) — whatever HAN decides lands as a DESIGN.md
   amendment first, code second (code-beats-stale-docs law applies in the
   other direction here: the doc moves before the code).

Feature 6 status (2026-09-02): FOUR demo rounds delivered on one artifact;
HAN gated direction A (calendar spine) with six additions (round 1→2),
refined it (rounds 2→3→4: day-picker reschedule, program screen w/ phases,
duration ladder read/ask/suggest, green logged toggle, first-run-only voice
hint → full-width speak bar, inline set editor; S4 adaptive cells frozen),
then **LOCKED it: "all good now" (2026-09-02) — the BUILD is open**. This
unblocks feature 7 phase 2 (demo lanes may now share the locked language).
Build plan + fix list + phase-0 record:
`.design-explorations/logging-v4-demo/PLAN.md`. Phase 0 (B1 cap+preprocess+
error surfacing, R1 transcript cleaner, B2 generous silence window) built
first — no new strings, xcstrings freeze respected; edge-fn deploy awaits
HAN's go.

Lane collision rules (2026-09-02): the launch-fix lane OWNS
`AppRouter.swift` until its commit lands; the onboarding build starts with
screens and defers its router branch until then. Features 6 and 7 write
only `.design-explorations/` until HAN gates. `Localizable.xcstrings`
still carries an unidentified session's WIP — nobody appends until it
lands or is claimed.

9. **Guided session mode (NEW, HAN 2026-09-07 — the last 1.7.3 feature).**
   The execution surface after "Start this session." Preconditions: an
   imported program + enough history for adjusted numbers (both shipped in
   the plan-led build). The experience: a FOCUSED space showing the current
   move and its logging numbers as the athlete proceeds; finishing a move
   AUTO-advances to the next, with a low "up next" hint bar; supersets
   alternate between the paired moves set-by-set (ExerciseGroup already
   models pairing). The point is total focus: never type from scratch,
   never remember sets/reps/weights, never leave to check what's next —
   the schedule and the adjusted targets drive everything; one tap logs
   the planned set, the scrub corrects, voice stays available. Demo-first
   (HAN's description IS the direction — variants explore layout, not
   concept), then build into ActiveWorkoutSheet's session path.

## CLOSURE PLAN (HAN "close the todos", 2026-09-03)

Three build lanes, hard boundaries; xcstrings WIP is landed (05a770a) so
appends are open again, kept atomic per lane:

- **Lane A — plan-led main build (feature 6) + reorientation slices 2+4.**
  One owner for all WorkoutLog-adjacent surfaces; the audit's slices 2 and
  4 ride the feature-6 build instead of colliding with it. R10 is already
  CLOSED by onboarding amendment 6 (import joins the flow).
  STATUS 2026-09-06: BUILT — batch 1 landed `40d4314`; batches 2–7 (epics
  1–10 + slices 2+4) landed as one commit, suite green. Build record +
  deviation list: `.design-explorations/logging-v4-demo/PLAN.md` §BUILD
  RECORD. HAN actions: run migration 012, deploy parse-workout (new
  program mode), fidelity pass on device.
- **Lane B — onboarding build, batches 1–6** per BUILD-PLAN + amendments
  1–9. AppRouter is free (launch fix landed); the PostHog SPM change stays
  its own flagged commit.
- **Lane C — reorientation slice 3** (Trends merge Option A + router
  seam). HOLDS AppRouter/MainTabView until Lane B's batch-1 router branch
  commits, then proceeds. Slice 5 (hygiene) folds into the standing
  audit-leftovers list, not built here.
- `.pbxproj` serialization: a lane lands its pbxproj edit inside its own
  batch commit and announces it; no two lanes edit it in the same window;
  conflicts resolve in Lane A's favor (largest surface).

Remaining HAN-personal items to close 1.7.3: color-pass direction (lands
as a DESIGN.md amendment first), widgets home-screen visual check, ASO
fields at submission, final on-device UAT of the whole release.

## Standing gates

No push, no ASC action without HAN. Sleep-v2 activation and estimator-v2
flip stay on their own validation clocks (not 1.7.3 items unless their
gates clear).
