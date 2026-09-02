# App-wide reorientation audit — v1.7.3 feature 7, phase 1

**GATE PASSED (HAN, 2026-09-02): "all passed — proceed with your
recommendation."** Execution follows §4.3's own sequencing: slice 1 builds
first (R2 + R3, Dashboard-lane files only); slices 2–4 stay demo-gated behind
feature 6's direction lock (HAN's multiple-rounds mandate keeps that open);
tab Option A rides the slice-3 demos. Slice-1 build status is recorded at the
end of this file.

**Written 2026-09-02.** Mandate: HAN's ruling of 2026-09-02 (SCOPE.md feature 7)
— logging and the daily adjustment are the product's spine; re-examine every
surface against that center. This document is the phase-1 deliverable: an
experience audit plus an IA proposal, ranked so HAN can approve a slice.

**Method.** Full walk of the shipped app in the simulator (SCREENSHOT_MODE
seeded data, iPhone 17 Pro Max, all 13 ScreenshotTests green this session) plus
a source-level map of every tab, sheet, menu, and empty state. Every claim
below carries a `file:line` citation or a capture. No app code was changed.

**The center, restated (U2, DOGFOOD-2026-09-01):** import your program once →
Tuwa proposes each day's workout from program position → check-in + fatigue
adjust the numbers → voice-led capture against that plan. The daily loop is
**check-in → proposal → log**.

---

## 1. What each tab's first screen says the product is

| Tab | First screen says | Loop steps present |
|---|---|---|
| **Home** (default at launch, `AppRouter.swift:299`) | "Here is a readiness score." Hero readout + generic Start session pill. | None fully. Proposal appears only as a one-line recommendation headline inside the hero's supporting card. |
| **Log** | "Here is today's adjusted plan — and your history." `TodayVerdictCard` with plan name, adjusted kg, reason, *Start adjusted workout*, *I feel strong / I feel rough*. | Proposal ✓, log ✓. This screen IS the spine surface today. |
| **Recovery** | "Here is the same score again, with charts." Duplicate 71/GO hero + HRV/sleep trends. | Check-in ✓ (the prompt row lives here, third tab). |
| **Load** | "Here are ACWR and load charts." Zero actions, zero navigation depth. | None. |
| **Profile** | Settings. | None (correct). |

The conclusion the walk forces: **the app already contains the spine, but it is
split across three tabs in the wrong order.** The proposal lives on tab 2, the
check-in that feeds it lives on tab 3, and the tab the user lands on carries
neither — it carries a readout plus a CTA that bypasses the plan entirely.

## 2. The daily loop, measured (established user, plan imported)

| Loop step | Where it lives today | Cost from launch |
|---|---|---|
| Morning check-in | Recovery tab prompt row (`RecoveryView.swift:78-86`) — only surface after first run | 3 taps + knowing which tab holds it |
| See today's proposal | Log tab, `TodayVerdictCard` (`WorkoutLogView.swift:138-162`) | 1 tap (tab switch) |
| Start the adjusted workout | "Start adjusted workout" on that card (`:147-157`) | 1 more tap |
| What Home offers instead | "Start session" ink pill → `ActiveWorkoutSheet()` blank | 1 tap into an **unplanned** session |

The advertised path (the screen's single ink pill) and the correct path
diverge at the first tap. That is the whole reorientation problem in one row.

---

## 3. Findings, ranked

Severity scale: **Critical** = fights the center on the primary daily path.
**High** = fights the center on a frequent or first-run path. **Medium** =
misallocates structure or attention. **Low** = hygiene.

### R1 · CRITICAL · Home — the day's proposal is not where the day starts
The `TodayVerdictCard` (plan · adjusted numbers · reason · start · feel-check)
renders only on the Log tab (`WorkoutLogView.swift:138-162`). Home's hero is a
readiness *readout* (`DashboardView.swift:370-607`); the proposal surfaces
there only as `viewModel.recommendation.headline` — one sentence, no numbers,
no plan, no start affordance (`DashboardView.swift:494-544`). The product's
strongest screen is one tab away from where every session begins.
**Proposal:** the day's proposal becomes Home's centerpiece. Either the verdict
card moves onto Home above the fold (readiness becomes its supporting input),
or Home is rebuilt as a "Today" surface (see §4). Note: `TodayVerdictCard.swift`
sits in `Views/WorkoutLog/` — the feature-6 lane's directory — so the *move* is
a cross-lane change; sequence it with feature 6 (§5).

### R2 · CRITICAL · Home — the one ink pill starts an unplanned session
Both Home CTAs (header "Log Workout" and the primary pill) call
`ActiveWorkoutSheet()` with no arguments (`DashboardView.swift:248-249`), and
that init hard-sets `resolvedPlan = nil` (`ActiveWorkoutSheet.swift:74-76`).
Only the Log tab's verdict card ever calls `init(resolvedPlan:)`
(`WorkoutLogView.swift:308-312`). So a user who obeys the app's most prominent
CTA trains *outside* the plan the app just adjusted for them. The pill even
reads the recommendation to pick its label (`DashboardView.swift:339-366`) —
it knows about the adjustment and still discards it.
**Proposal:** when a resolved plan exists for today, Home's CTA routes through
the same `resolvedPlan` path (or opens the proposal, which then starts the
workout). Blank stays as the fallback, never the default. Small change at the
Dashboard call site; no WorkoutLog file needs to move.

### R3 · HIGH · The check-in that adjusts today's numbers is off the daily path
`MorningCheckInSheet` is reachable from exactly two places: the Recovery tab's
prompt row (`RecoveryView.swift:78-86`) and Home's `WelcomeActionCard` — which
renders only before the first session/check-in exists (`DashboardView.swift:31-34`).
After day 1, the loop's *first* step lives on the *third* tab. The opt-in
`MorningProbeSheet` auto-presents on Home (`DashboardView.swift:263-274`), but
that is the validation instrument, not the input.
**Proposal:** when today's check-in is missing, Home shows the check-in prompt
at the top of the proposal surface ("How are you feeling today?" → sheet →
proposal re-resolves). Recovery keeps the history list and trends.

### R4 · HIGH · Three advisory voices speak on one screen; two engines disagree by design
Home simultaneously renders: the zone word on the hero ("GO"), the
`AutoregulationEngine` headline ("Go Zone — Recovery Is High",
`DashboardView.swift:536-544`), and — *below* the Start pill — the
`FatigueAttentionBanner` ("FATIGUE ELEVATED · Consider lighter sessions or
extra recovery", `DashboardView.swift:87-124`). The seeded capture shows all
three at once: GO above, caution below the button. Meanwhile the Log tab's
`TodayVerdictCard` (TodayVerdictService) is the actual verdict. Two engines,
two tabs, plus a banner — the user cannot tell which voice is the app's answer.
**Proposal:** one daily proposal voice. The verdict (plan-aware) is the answer;
readiness, fatigue, and recovery become *inputs shown as reasons* on the
proposal card, never parallel advice. Any caution reads *above* the start
affordance, not under it. (Engine consolidation is an engineering decision that
touches feature-6 surfaces — flag to HAN + that lane, do not build here.)

### R5 · HIGH · Import is buried, fragmented, and paywalled at the door (U1, quantified)
For a product whose core is "bring YOUR plan," the plan's doors are: an
ellipsis menu (2 taps) holding four flat entries — "Plan Today", "Import
Workout (AI)", "My Programs", "Import Program (Text)"
(`WorkoutLogView.swift:79-102`). Two importers with unclear names; PDF exists
only as a tab *inside* the AI sheet, invisible until 2 taps deep
(`WorkoutImportSheet.swift:36-58`); "Import Program (Text)" bounces free users
to the paywall at the menu itself (`WorkoutLogView.swift:94-102`). The word
"program" never appears on any first screen.
**Proposal:** one door, one name — "Bring your program" — first-class and
visible (Log tab header today; the Today surface once R1 lands), unifying
text / PDF / photo / voice behind one sheet. The Log-tab door itself is
feature-6 territory (U1 rides that lane); this audit adds the IA half: the
door must also exist at first-run (R6, R10) and on the Today surface.

### R6 · HIGH · Empty states sell template creation, not the spine
Inventory of what a fresh account is told to do:
- Log tab main empty state: "Tap the mic and say what you did."
  (`workoutLog.empty.bodyCapture`) — **already correct.**
- Template carousel: "Create your first template to speed up workout logging."
  + Create Template pill (`TemplateCarouselSection.swift:66-96`) — sells
  authoring, the one thing the product swears it never asks you to do.
- My Programs: "Create reusable strength programs you can start with one tap."
  (`TemplateListView.swift:26-36`) — same.
- Template picker: "Create a template from the Templates tab, or start a blank
  workout." (`empty.noTemplates.hint`) — **names a "Templates tab" that does
  not exist** in the five-tab app. Stale copy, shipped today.
- Home `WelcomeActionCard`: "Track your first activity…" — log or check-in,
  no mention of bringing a program (`WelcomeActionCard.swift`).
**Proposal:** every template/program empty state leads with "Bring your
program" (import) and offers voice as the zero-setup alternative; creation
becomes the last option. Fix the phantom-tab string in the same pass.

### R7 · MEDIUM · Two of five tabs are read-only exhibits that duplicate Home
Recovery re-renders the identical recovery hero (71 / GO) Home just showed
(`RecoveryView.swift:297-437` vs `DashboardView.swift:370-607`); Load
re-renders ACWR/ATL/CTL/TSB that Home's `TrainingLoadSection` already shows
(`WorkloadView.swift:97-133` vs `DashboardView.swift:757-775`). Load has zero
data-changing actions and zero navigation depth; Recovery has one action (the
check-in, R3). Full duplication table in §6. 40% of the tab bar is spent
restating Home with charts — while the spine has no tab presence at all.
**Proposal:** merge Recovery + Load into one "Trends" (or "Body") tab of
detail/history surfaces. This frees a slot and is the enabler for §4.

### R8 · MEDIUM · "Home/Dashboard" framing: the label, hero, and default tab say "score app"
The screen titles itself "Dashboard", leads with a score, and its supporting
card reads like an appendix. Home earns first position only if it carries the
loop; today it is a Whoop-shaped screen in a plan-led product — exactly the
anti-positioning (`scores without your plan`) the thesis rejects.
**Proposal:** Home becomes **Today**: check-in prompt (when due) → today's
proposal with adjusted numbers → start → readiness/fatigue as cited reasons.
The score does not disappear; it becomes evidence for the proposal.

### R9 · MEDIUM · No cross-tab plumbing exists for any of this
There is no programmatic tab switch anywhere — `selectedTab` is private to
`MainTabView` and set only by `InkTabBar`'s tap handler (`AppRouter.swift:299`,
`InkTabBar.swift:89-92`); every cross-feature entry opens a sheet in place.
Any IA change that hands off between tabs needs a small router seam.
**Constraint:** `AppRouter.swift` is the launch-fix lane's until its commit
lands (SCOPE.md collision rules). Sequence any router seam after that.

### R10 · MEDIUM · No surface ever asks for the plan on day 0
Shipped onboarding is language → frequency → experience → HealthKit
(`OnboardingView.swift:52-218`) — it never mentions a program. The approved
v1.8 flow *sells* the gap on screen 3 ("everyone who modulates owns your
program…", `ONBOARDING.md` §2) but its screen map contains no import moment
either; the user exits the paywall onto a Home with no plan and no ask.
**Proposal (flag, not a spec change — the v1.8 spec is approved):** HAN
decides where the day-0 "bring your program" moment lives: a post-paywall
screen in the v1.8 flow, or the first-run Today surface (R6's rewritten empty
state). One of the two must exist, or the spine starts empty for every new
user.

### R11 · LOW · "Plan Today" authoring is a menu item
Designating today's session lives 2 taps inside the ellipsis menu
(`WorkoutLogView.swift:79-83`). Feature 6 owns the program→proposal
connection; noted here only so the IA reserves a visible place for it on the
Today surface.

### R12 · LOW · Hygiene found during the walk
- `NiggleLogSheet.swift` has no call site — dead code (`Views/Recovery/`).
- `MorningProbeSheet` lives in `Views/Recovery/` but is presented only from
  Home; `SeanEllisPromptSheet` lives in `Views/Profile/` but is presented from
  the Log tab (`WorkoutLogView.swift:490`). Folder ≠ mount point, twice.
- `TrainingProfileSheet` is double-mounted (Home + Profile) — acceptable, but
  it is the only cross-tab duplicate *surface* (not just reading).
- Coach-era Profile section keys (`profile.section.myAthletes` etc.) are dead
  strings in the catalog.
- `workload.chart.insufficientData` ("7+ days") gates two different
  thresholds (`count > 1` and `count < 7`) — one of the two lies.
- Dead alternate string `workoutLog.empty.body` ("Tap + …") superseded by the
  voice copy — prune with the localization-key sweep (SCOPE.md audit leftovers).

---

## 4. IA proposal

### 4.1 Home hierarchy (Slices 1–2, no tab change required)

Target order for the Today surface, top to bottom:

1. **Check-in prompt** — only when today's check-in is missing (R3).
2. **Today's proposal card** — plan name, adjusted numbers, reason line,
   *Start adjusted workout*, feel-check chips (R1). When no plan exists:
   the card offers **Bring your program** + *Start unplanned* (R5/R6).
3. **Readiness as evidence** — the hero reading, compressed, feeding the
   proposal's reason tree; fatigue caution reads above the start affordance,
   never below it (R4).
4. Load strip, metrics, weekly summary, recent sessions — unchanged order.

The Log tab then sheds the verdict card and becomes what its name says:
capture (mic, +) and history. Its header keeps the import door (feature 6).

### 4.2 Tab structure (Slice 3)

Three options, ranked:

- **Option A (recommended): 4 tabs — Today · Log · Trends · Profile.**
  Recovery + Load merge into Trends (R7). Today carries the loop. Every tab
  name is now a verb-adjacent answer to "why open this."
  Cost: one merged-screen design; navigation-stack consolidation; the
  Recovery check-in prompt moves to Today (already required by R3).
- **Option B: 5 tabs — Today · Log · Plan · Trends · Profile.** The freed slot
  becomes a Plan tab (program, calendar position, next match, Plan Today).
  Stronger statement of the thesis, but feature 6 has not yet locked what the
  program surface looks like — building a Plan tab now forks that lane's
  design space. Defer until feature 6 locks; A does not preclude B later.
- **Option C: keep 5 tabs, reorder/reframe only** (Today first, Recovery and
  Load unchanged). Cheapest, but leaves the duplication (R7) and teaches the
  old model with new labels. Listed for completeness; not recommended.

### 4.3 Approval slices, ranked by value-per-risk

| Slice | Contents | Findings closed | Risk / dependency |
|---|---|---|---|
| **1** | Home CTA plan-awareness + check-in prompt on Home | R2, R3 | Small, Dashboard-lane files only; verdict card stays on Log until slice 2 |
| **2** | Proposal card onto Home; Home → "Today"; one advisory voice; caution above CTA | R1, R4, R8 | Cross-lane: card component + verdict service touch feature-6 surfaces; sequence after its direction locks |
| **3** | Trends merge (Option A); router seam for handoffs | R7, R9 | AppRouter waits for the launch-fix commit |
| **4** | Empty-state rewrite (import-first) + phantom-tab string + day-0 import decision (R10) | R5 (IA half), R6, R10 | Copy + placement; Log-tab door itself rides feature 6; R10 needs a HAN ruling |
| **5** | Hygiene sweep | R12 | Fold into the standing audit-leftovers lane |

Slice 1 is shippable independently and is the single highest value-per-line
change in this document: after it, the advertised first tap and the correct
first tap are the same tap.

---

## 5. Lane collisions (declared, per SCOPE.md 2026-09-02 rules)

- `Views/WorkoutLog/**` (incl. `TodayVerdictCard.swift`, import sheets, capture
  surfaces) — **feature 6's lane.** Slices 2 and 4 touch it; this audit
  proposes, that lane disposes. Phase 2 demos must match its locked language.
- `AppRouter.swift` — **launch-fix lane** owns it until their commit lands.
  Slices 1–3 need it only for the router seam (R9); slice 1 can land without.
- `Localizable.xcstrings` — carries an unidentified session's WIP; no appends
  (SCOPE.md). All copy changes here are proposals only.
- v1.8 onboarding — approved spec, untouched; R10 is a flag for HAN, not an
  amendment.

## 6. Appendix — reading duplication map

| Reading | Home | Recovery | Load |
|---|---|---|---|
| Recovery score + zone | Hero | Hero (duplicate) | Line series (Pro chart) |
| ACWR / ATL / CTL / TSB | Stat cells | — | Hero + grid + chart |
| HRV / RHR / Sleep | MetricsStrip + factor rows | Hero grid + trend charts | — |
| HRV/Sleep detail pushes | ✓ (own data path) | ✓ (own data path) | — |

Both tabs reach `HRVDetailView`/`SleepDetailView` through independently
fetched data arrays (`DashboardViewModel` vs `RecoveryViewModel`) — two query
paths for one screen, a maintenance cost the Trends merge retires.

---

*Phase 2 (demos in `.design-explorations/reorientation-demo/`) opens only
after HAN gates this audit AND feature 6's direction locks.*

---

## 7. Build record

**Slice 1 BUILT 2026-09-02** (post-gate, this session). R2: Home's primary
pill starts the decided plan through the same `resolvedPlan` path as the Log
tab's card ("Start adjusted workout" / "Start my plan", keys shared with the
card); undecided and no-plan keep the blank path. R3: `MorningCheckInPrompt`
mounts above the hero when today's check-in is missing; a save re-runs the
pipeline. The glance (`DashboardViewModel.deriveTodayPlanCTA`) is a pure
read — no verdict-slot writes, no `VerdictEvent`; the decision seam stays
single-surfaced on the card. Verification: units 1099/0/2 (9 new
`DashboardTodayPlanCTATests`), ScreenshotTests 16/16, Home capture inspected
by eye — the seeded accepted plan renders the pill as "Start adjusted
workout". Slices 2–5 remain open; 2–4 wait on feature 6's direction lock.
