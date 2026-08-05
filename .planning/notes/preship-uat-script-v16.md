---
title: Pre-Ship UAT Script — v1.6 build 17 (the six deferred items, one pass)
date: 2026-07-26
owner: HAN (device + judgment required; no agent can run this)
context: Consolidates the six deferred visual-UAT items carried in .planning/STATE.md:6 into a single ordered on-device pass. Established via CLAUDE⇄CODEX pair review (.pair/claude.md C-008).
status: unrun
---

# Pre-ship UAT — v1.6 build 17

## Why this exists

The v2.0 plan-aware verdict wedge — the thing that makes Tuwa defensible rather
than another readiness score — is built, green, pushed, and **live in the
production dashboard path** (`DashboardViewModel.swift:406` opts the surface in
unconditionally; cross-modal has driven the verdict since 2026-07-08). All of it
is inside build 17, in App Store review.

No human has looked at any of it on a device. Six visual-UAT items have been
deferred since Phase 41.

**There is now a free window to close that gap.** Build 17 was rejected
2026-07-25 (no Terms of Use EULA link in the metadata description body — second
rejection of that class; fix landed at `AppStoreMetadata.md:63` / `:103`). The
build is unchanged and resubmittable, which means this pass can run *before* the
resubmit at no cost to the timeline. Confirm the ASC state first — no agent can
see it.

The test suite cannot cover what matters most here. A green `TodayVerdictEngine`
test proves the adjusted number is bounded and plate-rounded. It proves nothing
about the two failure modes the validation corpus explicitly named:

- **Nocebo** — "a pre-session hold can poison the session." The verdict must read
  as *a number and a reason*, never a red don't-train gate.
- **Autonomy/identity** — experienced self-coached athletes prize "I autoregulate
  myself." The verdict must read as suggest-and-confirm and feel overridable.

Both are properties of pixels and copy. Only a person can check them.

## How to run

One pass, in order — later steps depend on state the earlier ones create. Budget
~30 minutes. For each item: the **action**, what **must be true**, and the
**failure that justifies pulling or hot-fixing the release**.

Record outcomes inline (`PASS` / `FAIL` + note). A `FAIL` on any item marked
**SHIP-BLOCKING** means build 17 should not go live as-is.

---

### 1 — Dual-run "method updated" card (from 41-01)

**Action.** Open the app to Dashboard on an account with ≥7 days of history.

**Must be true.**
- The dual-run card appears only when the new method actually differs from legacy.
- Copy explains *that the method changed*, not that the athlete did something wrong.
- With thin/cold-start data the card is **absent**, not showing a fabricated number
  (honest-confidence deferral — `PRSReadinessInputBuilder` returns nil).

**Ship-blocking failure.** A number displayed on cold-start data. That is
fabrication, and it is the one thing this project has repeatedly refused to do.

---

### 2 — Cross-modal gate acknowledgement (from 41-03)

**Action.** Log a hard conditioning/running session. Next day, open Dashboard.

**Must be true.**
- Yesterday's run visibly influences today's leg-region reading, and *not* the
  upper-body reading. This is the run-hits-squat-not-bench behaviour — the single
  differentiator against Garmin, now that Garmin owns TrainingPeaks + TrainHeroic
  (see `docs/market-intelligence/commoditization-clock-2026-07-26.md`).
- The magnitude reads plausible to you as the reference athlete. The research
  grades this model LOW confidence; your judgment is the validation criterion.

**Ship-blocking failure.** A run that penalizes bench as much as squat. That
collapses the differentiator into a generic whole-body fatigue score.

**If magnitude feels wrong but direction is right:** not ship-blocking. Revert
`CrossModalShadowGate.crossModalDrivesVerdict` to `false` — it is a plain default
kept revertible for exactly this outcome — and the channel returns to shadow-only.

---

### 3 — Plan Today input (from 42-03)

**Action.** Designate today's planned session both ways: load a `WorkoutTemplate`,
then discard and enter a one-off manual lift with target weight/reps/RPE.

**Must be true.**
- Both paths reach a designated planned session.
- The **authored template is never mutated** — reopen the source template and
  confirm it is untouched. The verdict writes only to the prescription's frozen
  copy. "Never writes the program" is the product's core promise.
- Targets are editable before any verdict is applied.

**Ship-blocking failure.** The source template shows adjusted numbers. That breaks
the central promise, and an athlete who notices it will not trust the app again.

---

### 4 — Verdict write + adjusted number (from 43)

**Action.** With a planned session designated and a genuinely compromised recovery
day (or wait for one — do not fake it if you want the read to mean anything), open
the verdict.

**Must be true.**
- One of go / modify / hold, with a concrete adjusted top-set number or volume cut.
- Adjustment stays inside bounds: −5% default, −10% ceiling, volume-cut preferred
  over load-cut, plate-rounded to something loadable.
- The reason is one plain line citing the driving signal ("HRV 2 days below your
  baseline" — not a dashboard of z-scores).
- On a "hold": **read it out loud.** Does it sound like a coach adjusting a number,
  or like a doctor forbidding you? Nocebo check.

**Ship-blocking failure.** Unloadable weights (e.g. 82.3 kg), an adjustment past
the −10% ceiling, or a hold that reads as a prohibition.

---

### 5 — Suggest-and-confirm surface (from 44-02)

**Action.** Exercise all three responses to a differing verdict: accept, decline,
keep-as-written. Then override the suggestion and train your own number.

**Must be true.**
- Accept / decline / keep are **equal-weight** cells. Not one bright CTA and two
  greyed escapes — that is a nocebo guard and a DESIGN.md law (decision rows are
  butted equal-weight cells).
- Declining is frictionless: no confirmation interrogation, no warning, no guilt copy.
- Your override is recorded as **input**, not as non-compliance.
- No red gate anywhere in the flow.

**Ship-blocking failure.** Any copy that shames an override, or a visual hierarchy
that pushes you toward accepting. This is the autonomy crack the corpus flagged as
one of only two real ones, in the exact population Tuwa targets.

---

### 6 — Measurement + WTP surfaces (from 45)

**Action.** Complete a session against a differing verdict, then answer the outcome
sheet. Visit Profile → Validation. Generate 5 `VerdictEvent`s to trip the
Sean-Ellis prompt.

**Must be true.**
- `VerdictOutcomeSheet` reads no-guilt: right / wrong / unsure as equal options.
- `VerdictMeasurementView` shows honest nil-states before there is signal
  ("still learning" / "too early"), never a fabricated rate.
- Sean-Ellis prompt fires at 5 events; "very disappointed" routes to `UpgradeSheet`.
- **This chain is the only source of WTP evidence the project has.** If it does not
  fire, the validation gate cannot ever clear.

**Ship-blocking failure.** None strictly — but a broken chain here means shipping
blind with no ability to learn from it, which wastes the release.

**Known external gap, not a UAT failure:** RevenueCat dashboard trial→paid
offering on `athlete_pro` is unconfigured (`RevenueCatConfig` is gitignored). The
"very disappointed" → paywall hop will surface but cannot take money. Configure it
before treating any WTP read as real.

---

## After the pass

- Any ship-blocking `FAIL` → do not let build 17 go live; report which item.
- All `PASS` → the moat ships verified, and **item 6 becomes the live instrument**.
  From that point the founder dogfood window (`.planning/notes/dogfood-protocol-n1.md`)
  is generating the only first-party evidence in the project. Nothing about the
  five-athlete WTP gate can start before that.
- Either way, update `.planning/STATE.md` — its deferred-UAT list and its
  "~190 unpushed commits" figure are both stale as of 2026-07-21.
