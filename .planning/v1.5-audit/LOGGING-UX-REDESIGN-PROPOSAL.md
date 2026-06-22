# Logging UX Redesign Proposal — Suggestion-Centered Set Entry

**Status:** PROPOSAL (precedes GSD discuss/plan). This is a design contract, not a task plan.
**Scope:** UX-only. No change to RecoveryScoreEngine, AutoregulationEngine, WorkloadCalculator, ProgressionEngine math, or feature flags. All suggestion logic is presentation-layer reads of existing data.

> ## LOCKED DECISIONS (user, 2026-06-04)
> 1. **Persist-untouched bug → FIX NOW, STANDALONE** (its own GSD quick/phase before the redesign; see §13).
> 2. **v1 scope = LEAN** — ghost/commit fix + 3-tile WeightBlockPicker only. Reps stays on existing stepper + keypad. DEFER reps detent-scrubber, cardio ghosting, double-progression nudge, one-tap whole-row confirm.
> 3. **Selected-center cue = ELEVATION LADDER** — center tile `surfaceEl`, side tiles `surface`, value readout above + "current" micro-label. No accent.
> 4. **Commit model = COMMIT-ON-TAP** — tapping center/side writes immediately (matches shipped stepper). Requires unmistakable committed state + an undo/back affordance (since a side-tap from a ghost source writes).
> Deferred-but-noted: inline PR/spike banners already shipped (phase 38) — NOT rebuilt. "last non-warmup set" needs an `isWarmup` field added to the history lookup (SetHistoryRecord/ProgressionEngine).
**Constraint baseline:** Tuwa DESIGN.md hard rules (0pt corners / no shadow / General Sans via Font.Tokens / 8pt grid / accent only on Dashboard hero readiness score / zone via text+border never color-alone / dark+light / en+zh). iOS 17 SwiftUI + SwiftData. Weight stored in kg always.

---

## 1. Problem & Goal

Logging a single straight set today (per the codebase MAP) costs **5–7 taps + 6–7 keystrokes + 2 keyboard pops** in the common `weightReps` path. The two keyboard pops (weight `.decimalPad`, reps `.numberPad` in `SetEntryRow`) are the dominant friction: the system keypad occludes the set grid mid-rest, and the user must dismiss/re-summon between fields.

Phase 38 already shipped **Variant A** — always-visible `SetStepperDouble`/`SetStepperInt` with ghost baselines (`targetWeightKg`/`targetReps` rendered at `text3`) and a tap-to-keypad escape hatch. That is a solid, regression-clean, accessibility-cheap baseline. **This proposal does not re-open or discard Variant A.** It is an *additive evolution* of the same row: it keeps the native-composable stepper architecture and grafts a suggestion-centered presentation layer plus an optional drag affordance.

**Goal:** For the dominant "same as last time / one increment up" case, drive set entry toward **1 tap, zero keyboard pops**, while protecting the ACWR/PR/EWMA data pipeline from silently-committed fabricated values, and degrading gracefully for first-ever exercises and all four input modes.

**Target user reminder:** amateur serious / part-time athletes with **no coach**. They are frequently *new to a lift* (cold-start is a real, common case, not an edge case) and rely on the app for load-authority. A confidently-displayed fabricated number is worse than an honest blank.

---

## 2. Chosen Direction + Why

**Adopt the user-requested 3-block weight picker (center = suggested working weight, sides = one-increment lighter / heavier) and a reps detent-scrubber, built as an evolution of the locked Variant A stepper row — NOT a replacement of it — with three non-negotiable safety corrections grafted from the critiques: (a) suggestions render as non-persisted GHOSTS, never pre-cloned real `SetRecord`s; (b) committing requires an explicit per-field touch (no single blanket confirm that writes an unverified weight+reps pair); (c) selection state changes use `linear` motion per DESIGN.md, never `easeOut`.** This direction wins because the 3-block picker maps 1:1 to the only three decisions a lifter makes set-to-set (repeat / back off / progress), it is fully buildable inside the 0pt/hairline/Font.Tokens/8pt/no-accent system using `Rectangle` tiles distinguished by type-weight and border (the Braun ET66 "one deliberate deviation" lesson re-expressed in monochrome), and every data input it needs (template targets, last-session working sets, in-memory progression suggestions) **already exists** — zero engine, flag, or (ideally) schema change.

---

## 3. Weight 3-Block Picker — Full Spec

### 3.1 Layout & visual (DESIGN.md-compliant)

A single horizontal row of **three equal `Rectangle` tiles**: `[ lighter | CENTER | heavier ]`.

- **Shape:** `Rectangle()` only. 0pt corners. No `.cornerRadius`, no `RoundedRectangle`, no `.shadow()`.
- **Size:** each tile **48×48pt** (8pt multiple, satisfies ≥44pt touch target). Gutter between tiles = `Spacing.xs` (8). Cluster sits in the thumb-reach zone of the row; the live readout sits directly above it (display-over-control, fixed `Spacing.sm` (16) gap).
- **Borders:** each tile bordered by a `0.5pt` hairline `divider` stroke. No fill.
- **Selection signal (exactly ONE coordinated pair, no accent):**
  1. CENTER (selected) numeral = `Font.Tokens` **Medium**, `text1`, `.monospacedDigit()`, largest in ramp.
  2. Side tiles = **Regular**, `text2`, smaller; their border stays `0.5pt`, the center tile gets a stronger inset/double-hairline (`divider`) to read as "current".
  - **NEVER** use `ColorTokens.accent` on any tile, border, or numeral. Accent is Dashboard-hero-only.
- **Numerals:** all values `.monospacedDigit()` at the call site (matching existing `MetricTile`/`SetStepper` convention). **Do NOT** add a tabular-baked `Font.Tokens.numericLarge` token — that fragments the established inline pattern. Lay the center numeral in a fixed-width container so 1↔8 width swaps never shift the row.
- **Unit label:** rendered once, beneath/beside the cluster, `text2`, Regular (e.g. "kg" / "lb" / locale symbol).

### 3.2 Interaction

- **Tap CENTER tile** → commits the centered weight to `SetDraft.weightKg` for that set (an explicit per-field touch — see §8 safety). It commits **weight only**, never reps. Reps is a separate explicit touch on the scrubber.
- **Tap a side tile (lighter/heavier)** → **commit-and-recenter**: the tapped value becomes the new committed center, neighbors recompute (±1 increment). Walking 60→62.5→65 is repeated taps on the heavier tile.
  - *Critique resolution (commit-vs-navigate conflation):* every side-tap **does** write — but because weight commit and reps commit are decoupled, and because all three tiles always show loadable values, a "look then change my mind" is recovered by one tap back the other way. We explicitly accept commit-on-step (matches the shipped stepper's commit-on-±) rather than add a preview-before-commit mode, which would add a second tap to the common path. This is documented as an intentional trade, open for owner review (§10).
- **Tap the CENTER numeral region is NOT a separate target.** To avoid the NN/g split-target anti-pattern (two actions inside one 48pt tile), the **keypad escape hatch is a distinct affordance**: a small `text2` "type" glyph/caret rendered *outside* the three tiles (trailing the cluster, its own ≥44pt target). Tapping it opens `.decimalPad` for big jumps. On keypad dismiss: re-snap the typed value to the nearest legal increment and re-center the three blocks around it.

### 3.3 Center suggestion heuristic (existing data ONLY)

Precedence for the CENTER value (pure presentation read; no writes, no engine call):

1. **Template / prescription target** — `WorkoutTemplate.targetWeightKg` / `PrescribedWorkout` target if this exercise originated from a plan (already surfaced via `loadFromTemplate`).
2. **In-session previous set** — the immediately-prior committed working set in *this* `ExerciseEntry` (straight-set case).
3. **Last-session working set** — most-recent **non-warmup** `SetRecord.weightKg` for the same `exerciseName` across sessions (newest `completedAt` first). Warmups are excluded so progression isn't poisoned.
4. **In-memory progression suggestion (Pro)** — `entry.progressionSuggestions[i].weightKg` if present and `isPro` (already computed; gated behind existing `isPro` read, no flag change).
5. **nil → first-ever behavior** (§3.6).

**Optional double-progression nudge (deferred / templated-only, owner-gated):** if the exercise is templated AND last-session reps ≥ `targetReps` (top of range), the center *may* default to last weight + 1 increment with reps defaulting to bottom-of-range. Because this actively changes the displayed load, it is **ghost-only and must be explicitly confirmed** (never auto-committed) and is proposed as a later sub-phase, not v1 of this redesign.

### 3.4 Lighter / heavier neighbor computation & increments

Computed in the **display unit**, then stored as kg:

```
increment = (unit == .kg) ? 2.5 : 5          // house increment; 2.5kg matches MockDataSeeder
centerDisplay = snapToIncrement(WeightFormatter.displayValue(centerKg, unit: unit), to: increment)
lighterDisplay = max(0, centerDisplay - increment)
heavierDisplay = centerDisplay + increment
// on commit:
draft.weightKg = WeightFormatter.toKg(chosenDisplay, from: unit)
```

Add a pure helper next to `WeightFormatter` (matches existing utility convention):

```swift
static func snapToIncrement(_ value: Double, to step: Double) -> Double {
    (value / step).rounded() * step
}
```

This guarantees kg users see clean 2.5 steps and lb users see clean 5 steps (never `47.6 lb`), while storage stays kg. The increment constant lives in a tokenized location, not inlined as a magic number.

### 3.5 Keypad fallback

Distinct trailing "type" affordance (§3.2) → `.decimalPad`. On dismiss: `snapToIncrement` the typed display value, convert to kg, recenter blocks. The keypad is the **exception path** for big cross-exercise jumps (60kg squat → 20kg curl → 100kg deadlift), which the critiques correctly note are common *across* exercises — so the keypad must remain a first-class, easy-to-reach escape, not buried.

### 3.6 First-set / no-history behavior (honest, no fabrication)

When precedence resolves to nil (new exercise, new user — a **common** case for the target group):

- CENTER tile renders an **explicit unset placeholder**: em-dash or "—" in `text2` (reads as "unset", never a confident number). **Never** fabricate bar weight, a %1RM of an unrelated lift, or any guessed value.
- Side tiles are **disabled** (there is nothing to step from) — rendered at `text3`, non-interactive.
- The trailing "type" affordance is emphasized (`text1`) so the user is guided to the keypad.
- Reps scrubber defaults to a neutral category value (§4.3).

This is the honest cold-start. The headline tap-savings claim is explicitly scoped to the warm-cache case (§7); for first-ever sets, parity-with-keypad is the correct and intended outcome.

---

## 4. Reps Scrubber — Full Spec

### 4.1 Gesture, detents, visual

A horizontal detent-scrub over the bounded reps range **1–30** (legitimate stepper/scrub range; weight's wide range is the keypad's job, not the scrubber's).

- **Track:** a single `0.5pt` hairline `divider` baseline with detent tick marks (`0.5pt` Rectangles) at constant pitch. **Not** a filled rail. No rounded thumb — indicator is a `Rectangle` if any.
- **Live value:** rendered above the track, `Font.Tokens` Medium, `text1`, `.monospacedDigit()`, fixed-width box so 1↔8 never jitters.
- **Drag:** finger position interpolates; committed value **snaps to integers**. Bounded 1–30.

### 4.2 Haptics (iOS 17)

- Use `UISelectionFeedbackGenerator` / iOS-17 `.sensoryFeedback(.selection, trigger:)` fired **once per crossed integer** (not per pixel). `prepare()` on touch-down to kill first-tick latency.
- **Throttle/cap:** suppress haptic if the integer-cross rate exceeds a threshold (fast long drag), to avoid the "buzzy" over-firing the critique flagged. Practically, the 1–30 bound keeps any single drag short.

### 4.3 Default

Precedence: template `targetReps` → in-session previous set reps → last-session reps for `exerciseName` → category neutral (compound 5, isolation 10, bodyweight 10, default 8). A single sensible default — never a computed prescription.

### 4.4 Fallback & "tap = set"

- **Tap a detent / tap the number** → opens `.numberPad` for direct entry (keypad escape, same discipline as weight). On dismiss, clamp to 1–30.
- We **keep tap-to-keypad** rather than the "single tap is a no-op" rule one rival proposed — removing the fastest known-value interaction is a usability tax.
- Drag remains the within-range nudge; keypad remains the big/precise entry.

---

## 5. Group / Exercise / Set Add Friction Cuts

All additive, presentation-layer, no schema/algorithm change:

1. **Exercise-add scaffold from history (GHOST, not cloned rows):** when an exercise is added, build the set scaffold (count + per-set weight/reps) from the last session for that `exerciseName`, but render every prefilled set as a **ghost `SetDraft`** (`isFromHistory`, target* fields) — *not* committed `SetRecord`s. Ghosts are excluded from `validSets`/volume/EWMA/PR until explicitly committed. This kills the cold-start empty grid **without** polluting the pipeline (resolves the clone-on-add data-integrity blocker).
2. **"Add set" duplicates previous set as a ghost:** inserting another set pre-arms it (ghost) from the prior set in the `ExerciseEntry`, so a 3×5 is fast, but each added set still requires its own explicit confirm before it counts.
3. **Collapse completed sets** to a compact one-line `text2` summary to reclaim the vertical height the richer 3-block + scrubber row costs (keeps a 5-set exercise short on small devices).
4. **Inline (not full-screen) PR/spike banners:** replace `PRCelebrationOverlay`/`SpikeAlertBanner` full-screen interrupts with inline dismissible banners using a left zone-color `0.5pt` hairline border **+ text label** (zone via text+border, never color-alone; no accent fill). Banners fire *after* commit and never block sheet close.
5. **Keypad in-flow focus advance:** when the keypad *is* used, `@FocusState` advances weight→reps without dismiss/re-summon; rest timer (existing UI state) auto-starts on commit.

---

## 6. Aesthetic Rules (Braun/Rams + Apple) — Concrete, Buildable

**DO:**
- Earn hierarchy by **type weight + contrast + size**, never fill color (ET66 "one deliberate deviation", re-expressed monochrome): center value = Medium / `text1` / largest; neighbors = Regular / `text2` / smaller.
- Individuate every tile as an honest pressable object: equal `Rectangle` tiles, equal `Spacing.xs` gutters, `0.5pt` hairline borders only.
- Group with **whitespace (8pt multiples)**, not bordered cards. Never wrap the control in a bordered/elevated card.
- Display-over-control: live readout directly above the instrument it drives, fixed `Spacing.sm` (16) gap.
- Tabular numerals via `.monospacedDigit()` at the call site; fixed-width numeral box.
- Motion = functional confirmation only: selection state crossfade **`linear` ~150ms** (DESIGN.md mandate for state changes — NOT `easeOut`), finger-tracking 1:1 with no overshoot, single-frame settle on detent snap.
- One selection haptic per crossed detent; `prepare()` on touch-down.

**DON'T:**
- No `ColorTokens.accent` anywhere in this view (tiles, borders, numerals, banners, confirm).
- No `RoundedRectangle` / `.cornerRadius` / `.shadow()`.
- No spring/bounce/scale-pop/parallax/idle animation.
- No `easeOut` for selection state change (the original proposal's breach — corrected to `linear`).
- No proportional digits on live-changing values.
- No 4+ stacked selection cues; no color-only zone signal.
- No magic spacing (6/10/12) to cram the row; only `Spacing.*` (+`baselinePair` 4 exception).

---

## 7. Tap-by-Tap Flow + New vs Old Count

### Old (per MAP, common `weightReps` straight set)
1. Tap weight field → keypad pops
2. Type weight (≈3 keystrokes)
3. Tap reps field → keypad pops
4. Type reps (≈2 keystrokes)
→ **2 taps + ~5 keystrokes + 2 keyboard pops** per set (plus exercise-add + finish overhead).

### New — warm cache, "same as last time" (3×5 unchanged)
- Exercise add → ghost scaffold appears (0 taps, all sets pre-armed as ghosts).
- Per set: **1 tap on CENTER** to confirm weight + **1 tap on reps** to confirm (or 1 tap if reps default already correct and a single per-row confirm gesture is used — see §8 trade). Realistically **1–2 taps/set, 0 keyboard pops**.

### New — one increment up
- Tap **heavier** tile (commits + recenters) + confirm reps → **1–2 taps, 0 keyboard**.

### New — first-ever exercise (honest cold-start)
- CENTER unset → tap "type" → keypad → enter weight; reps via scrubber or keypad. **Parity with old keypad path** (intentional; no regression, no false data).

**Honest framing:** against the *true* baseline (shipped Variant A stepper, not the legacy text-field strawman), the marginal win is **eliminating residual keyboard pops and collapsing the step+confirm into a single suggestion-centered tap** for the warm case — a real but bounded gain, largest on straight-set within-exercise logging, neutral on first-ever and big cross-exercise jumps.

---

## 8. Data-Model Impact

**Preferred: NO schema change.** `SetRecord` and `SetDraft` already carry everything:

- `SetDraft` has `targetReps` / `targetWeightKg` / `targetRPE` (ghost baselines) and `isFromHistory` — exactly the "provisional/uncommitted" representation needed. **Suggestions and history-prefill render as ghosts on `SetDraft`, which are NON-persisted by definition** and excluded from `validSets`. This resolves the "clone-on-add pollutes the pipeline" blocker *without* a new flag: a ghost is never a `SetRecord` until committed.
- Commit = the explicit per-field touch copies `target*` → the real `reps`/`weightKg`/etc. fields, after which the set enters `validSets`.

**Explicit-commit safety rule (resolves the silent-wrong-data blocker):** there is **no single blanket "confirm row" tap that writes both an unverified weight AND an unverified reps**. Weight commit (center/side tile) and reps commit (scrubber/keypad) are **separate explicit touches**. A reflexive single tap cannot silently persist a fabricated weight+reps pair into the ACWR/PR/EWMA pipeline.
> *Owner decision (open, §10):* if a one-tap "confirm whole row from ghosts" is later desired for speed, it must be visually distinct (e.g. a dedicated confirm affordance) AND only offered when the ghost source is a *real prior actual* (precedence 1–3), never the double-progression nudge (precedence 4/5).

**If schema change is ever justified:** none is required for this redesign. A per-`CustomExercise` increment override or per-athlete plate inventory (plate-math display) would be the only candidates, both **deferred** and out of scope here.

---

## 9. All 4 Input Modes + Cardio + Accessibility

| Mode | Weight 3-block | Reps scrubber | Suggestion source |
|---|---|---|---|
| `.weightReps` (compound/isolation/plyometric) | ✓ | ✓ | template → in-session → last working set → progression(Pro) |
| `.repsOnly` (bodyweight) | **hidden** (or optional "added weight", default unset) | ✓ | last reps / category neutral |
| `.distanceDuration` (cardio/interval) | **swapped** → distance + duration scrubbers/keypad | n/a | last-session `distanceMeters` / `durationSeconds` for same `exerciseName` |
| `.durationOnly` (drill) | **swapped** → duration scrubber/keypad | n/a | last-session `durationSeconds` |

- **Cardio modes get carry-forward too** (resolving the rival proposals' "cardio hand-waved / no ghost support" weakness): distance/duration ghost from last-session same-exercise values, rendered in `text2`, committed by explicit touch. If full ghost styling for cardio is too costly in v1, carry-forward as **committed** values (matching today's `repeatLastSet` behavior) is the honest documented fallback — but the carry-forward itself must exist.
- Branch on `ExerciseInputMode` (maps 1:1 to `Enums.swift` `.weightReps/.repsOnly/.distanceDuration/.durationOnly`).

**Accessibility (HARD GATE — must ship, not "nice to have"):**
- **Prefer composing the native SwiftUI `Stepper`** inside the control so VoiceOver Adjustable trait, value announcement, and increment haptics come for free. Where the 3-block tiles / scrubber are bespoke gesture surfaces, they **MUST** implement:
  - `.accessibilityRepresentation` / `.accessibilityAdjustableAction { direction in }` (swipe up/down increments).
  - `.accessibilityValue` with **full unit words** ("sixty kilograms" / "five reps"), localized en + zh.
  - `.accessibilityLabel` ("Weight, set 2" / "Reps, set 2"), localized.
- **Dynamic Type:** wrap the row in `ViewThatFits` with a vertical fallback at AX sizes so the 3 tiles + scrubber never clip; all tap targets ≥44pt (48pt tiles).
- **Localize en+zh:** all labels ("lighter"/"heavier"/"reps"/"type"/"No history yet"/"unset"/"Add set"/"Repeat last set"), a11y strings, and banner copy. Keep Latin tabular digits in both locales; only unit/label strings localize; numeral box width constant across locales.

---

## 10. Edge Cases, Risks, Open Questions

**Edge cases:**
- First-ever exercise / new user → honest unset placeholder + disabled sides (§3.6).
- Big cross-exercise weight jump → keypad escape (not a scrubber/3-block job).
- Warmup sets → excluded from suggestion source; their own row still logs normally.
- lb users → clean 5-lb steps via display-unit snap; kg stored.
- AX text sizes → `ViewThatFits` vertical fallback.
- Abandoned session with un-confirmed ghosts → ghosts never persisted, pipeline clean.

**Risks:**
- Drag-vs-ScrollView conflict for the reps scrubber inside the sheet → requires `minimumDistance` / `simultaneousGesture` arbitration; **on-device gesture + VoiceOver test is a hard gate before ship**.
- Per-detent SwiftData `@Binding` re-render churn → isolate the live drag value in local `@State`, commit to the draft only on detent/release.
- Commit-on-side-tap accepted as intentional (no preview) → owner sign-off needed (§3.2).
- Vertical height of richer row → mitigated by collapse-completed-sets (§5.3).

**Open questions for the user (top 3):**
1. **Commit-on-step trade:** OK that tapping lighter/heavier *writes* immediately (consistent with today's stepper), with no preview-before-commit? Or do you want a preview/arm-then-confirm step (adds a tap)?
2. **One-tap whole-row confirm:** do you want an optional single "confirm row from ghosts" affordance for speed (restricted to real-prior-actual sources, never the double-progression nudge), or keep strictly per-field explicit commits?
3. **Double-progression nudge:** include the "auto-suggest +1 increment after hitting top of rep range" (templated exercises only, ghost-only, explicit confirm) in v1, or defer to a later sub-phase?

Secondary: should cardio ghost-styling ship in v1 or carry-forward-as-committed (documented fallback)? Should this evolve Variant A in place, or be gated behind a setting for A/B?

---

## 11. Proposed Component Breakdown + Rough Phasing

**New / changed SwiftUI views (names indicative):**
- `WeightBlockPicker` — the 3-tile `[lighter|center|heavier]` control. Inputs: centerKg, unit, increment, onCommit(kg), onKeypad. Pure presentation; native-Stepper-composed where possible for a11y.
- `RepScrubber` — bounded 1–30 detent scrub with per-integer haptic + keypad fallback. Local `@State` drag value, commit on detent/release.
- `SetSuggestion` (pure helper in `Utilities/`, NOT `Services/`, NOT an engine) — `static func suggest(exerciseName:category:templateTarget:inSessionPrev:lastSet:isPro:progression:) -> (centerKg:Double?, reps:Int?, distance:Double?, duration:Int?)`. Deterministic, side-effect-free, reads only existing data.
- `WeightFormatter.snapToIncrement(_:to:)` — pure helper added to existing utility.
- `SetEntryRow` — refactored to host `WeightBlockPicker` + `RepScrubber` per `ExerciseInputMode`, ghost-aware, collapse-when-completed.
- Inline `PRBanner` / `SpikeBanner` — replace full-screen overlays.

**Rough phase shape (outline only — NOT a task plan):**
- **Phase A — Suggestion + snap helpers (no UI):** `SetSuggestion` helper, `snapToIncrement`, last-non-warmup-set lookup, precedence chain. Pure, unit-testable, zero visual change.
- **Phase B — `WeightBlockPicker`:** the 3-block control + keypad escape + first-ever unset state, wired to Phase A, replacing/evolving the weight stepper in `SetEntryRow`. Linear-motion selection.
- **Phase C — `RepScrubber`:** detent scrub + haptics + keypad fallback + Dynamic Type `ViewThatFits`; on-device gesture-conflict + VoiceOver gate.
- **Phase D — Add-friction cuts:** ghost exercise-add scaffold, ghost add-set, collapse-completed-sets, in-flow keypad focus.
- **Phase E — Inline banners + cardio/mode coverage + en/zh localization + a11y audit.** Final regression + DESIGN.md enforcement pass.

(Each phase is independently shippable and keeps Variant A working until its successor lands.)

---

## 12. Codex Second-Opinion Corrections (2026-06-04) — supersedes conflicting claims above

Codex (high-effort, read-only) verified the proposal against the actual code and found the central safety premise FALSE. These corrections override §8 where they conflict.

### [P1] The "ghosts are excluded from validSets / no schema change needed" claim is WRONG
- `saveSession()` (ActiveWorkoutSheet.swift:491) persists EVERY draft set **unfiltered**. The `validSets` filter (line 608) lives ONLY in save-as-template, NOT in session save.
- Worse, this is a **PRE-EXISTING bug, live in the shipped app**: `prefillFromHistory()` (:250), the free-tier last-session fallback (:334), and `loadPrescription()` (:371) all write **concrete** `reps`/`weightKg` (with `isFromHistory: true`) — so a user who opens a templated/prescribed/history-prefilled workout and taps Finish **without touching anything persists fabricated/carried weights as real sets**.
- Impact: pollutes **PR (PRDetector:16), volume (WorkoutSession.recalculateDerivedFields:87), history, and progression**. NOT ACWR/EWMA — those use `trainingStress` from duration/RPE (WorkoutPipeline:168), not set weight. So earlier "pollutes ACWR/EWMA" was overstated; "pollutes PR/volume/history" is real.
- **This also means the phase-38 codex P2-C ("blank carried set persists") was REAL, not a false positive — it was dismissed citing line 608, which is the wrong (template) filter.** A ghost-only carried set with nil reps/weight currently persists.
- **Consequence for redesign:** a true ghost/commit model REQUIRES a change to `saveSession` (filter out untouched sets) and most likely an explicit per-set `isCommitted`/`touched` bit on `SetDraft` (small, justified — NOT "no schema change"). This corrects §8. It also fixes the pre-existing bug as a side effect — arguably do that fix FIRST, standalone, before any UI work.

### [P2] Suggestion precedence only partly buildable as written
- Buildable from existing data: template targets (TemplateSet:157), in-session prev set, last-session via `ProgressionEngine.fetchHistory()` (:446), Pro `progressionSuggestions` (:661).
- NOT buildable as-is: **"last non-warmup set"** — `SetHistoryRecord` has no `isWarmup` field (ProgressionEngine:433). Needs a query/helper change.
- "Template / prescription target" wording sloppy: per-set targets live on `TemplateSet`; `PrescribedWorkout` stores workout-level PRS targets, set targets come via copied groups (PrescribedWorkout:21).

### [P2] SwiftUI build landmines (real, not paper)
- Reps scrubber drags will fight the sheet's vertical `ScrollView` (:48) — gesture arbitration cost; horizontal-only + minimumDistance, on-device test is a hard gate.
- `$set.reps` write per detent re-renders the row/list — MUST use local `@State` drag value, commit on crossed-detent/release.
- `.sensoryFeedback` per integer overfires — use local `UISelectionFeedbackGenerator`, gate on changed-integer + time.
- `ViewThatFits` alone insufficient: the row already packs set# + 2 steppers + RPE chip (:948); 3 tiles + scrubber + type + RPE will clip at AX sizes — row likely must become a **vertical editor** at large Dynamic Type.

### [P2] UX holes
- Commit-on-side-tap from a GHOST source is dangerous — user may read it as "browse one notch" but it writes. If kept, need unmistakable committed state + undo/back (not just "tap the other way").
- Per-field commit leaves a "real weight + ghost reps" half-state — needs a visible **"incomplete / won't count"** indicator or users think a ghosted value counted.
- Aesthetic risk HIGH: 3 same-size outlined tiles distinguished only by Medium-vs-Regular + text1-vs-text2 may not read as "selected", esp. light mode / sweaty thumb. **Use the elevation ladder (non-accent, allowed): center tile on `surfaceEl`, sides on `surface`** + a persistent value readout above + an explicit "current" micro-label. Double-hairline alone is too subtle.

### [P2] Scope cuts for a leaner v1 (codex)
- **Inline PR/spike banners ALREADY exist** (ActiveWorkoutSheet.swift:159, shipped phase 38) — §5.4 is redundant, drop it.
- Cut from v1: reps detent-scrubber, cardio ghosting. Keep reps on the existing stepper + keypad.
- **Leanest correct v1 = (1) fix the persist-untouched bug / ghost-commit model, then (2) the 3-tile weight picker, reps stays on existing stepper/keypad.**
- Missing fast-lifter basics to add: one-tap "complete set" once weight+reps are real, duplicate previous exercise, clear warmup-toggle visibility, keyboard focus-advance (higher value than the scrubber).

### Revised recommendation
Direction (3-tile suggestion-centered weight picker) is sound and on-brand. But: (a) the ghost/commit safety needs real save-logic + a small schema bit — and that doubles as fixing a live data-integrity bug, do it first/standalone; (b) drop the reps scrubber + cardio ghosting + redundant inline-banner work from v1; (c) use `surfaceEl`/`surface` elevation (not accent) for the selected-center cue; (d) "last non-warmup" suggestion needs a history-helper change. Re-scope phasing: **Phase A = ghost-commit save fix (bug fix, no new UI) → Phase B = SetSuggestion + snap helpers → Phase C = WeightBlockPicker → (defer scrubber/cardio/extras).**

---

## 13. Standalone bug-fix spec — "untouched prefilled sets persist as performed" (do FIRST)

**Bug (verified):** `saveSession()` (ActiveWorkoutSheet.swift:473, set loop :491) maps every `SetDraft`→`SetRecord` with NO validity filter. `prefillFromHistory()` (:250), free last-session fallback (:334), and `loadPrescription()` (:371) write **concrete** `reps`/`weightKg` (`isFromHistory: true`). → opening a templated/prescribed/history workout and tapping Finish untouched logs un-performed loads into PR (PRDetector:16) / volume (WorkoutSession:87) / history / progression. Also a fully-blank ghost (carry-forward `addCarriedSet`, all measurement fields nil) persists as a junk empty SetRecord.

**Core tension:** with no explicit "I did this set" control, you cannot distinguish *performed exactly as prescribed, untouched* from *never performed*. So the fix needs a confirm signal.

**Open sub-decision (the one remaining choice for the standalone fix):**
- **Option A — per-set "done" toggle (recommended):** add a square `Rectangle` checkbox (DESIGN-compliant: 0pt, hairline, text label, no accent) at the end of each set row. `saveSession` persists ONLY sets where `isDone == true`. Prefilled/ghost sets start `isDone=false`. Honest, explicit, and forward-compatible — the redesign's commit-on-tap can auto-set `isDone` when the user taps the weight tile. Cheapest correct model. Adds one tap per set today (acceptable; the redesign removes it).
- **Option B — "edited" heuristic:** add `wasEdited: Bool` to `SetDraft` (transient struct, NOT a SwiftData migration), flip true on any field edit; persist only edited (or non-prefilled-with-data) sets. No new UI, but DROPS legitimately-performed-as-prescribed untouched sets → false negatives (user did the prescribed set, it vanishes). Risky.
- **Option C — minimal:** only drop all-nil empty sets (the template filter at :608 applied to saveSession too). Fixes the junk-blank-set case but NOT the concrete-prefilled-untouched case (the bigger pollution). Incomplete.

**LOCKED fix = Option A (user, 2026-06-04).** `SetDraft.isDone` (transient, no migration), a square done-toggle per row, `saveSession` filters `draft.sets.filter { $0.isDone }` (+ drop entries with zero done sets). Prefilled/ghost/carry sets default not-done; user taps done to log. Localize the toggle label en+zh. Build-gate + verify PR/volume no longer counts untouched prescribed sets.
**LOCKED timing = AFTER current 38-40 UAT** (don't disturb the build under UAT).

This is a small, self-contained GSD quick/phase, independently shippable, and becomes Phase A of the redesign.
