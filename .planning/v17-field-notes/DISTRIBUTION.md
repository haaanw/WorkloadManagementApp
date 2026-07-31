# v1.7 "Field Notes" (v6) — Work Distribution Plan

Orchestrator: this session (CLAUDE, Fable). Source spec: `~/Downloads/tuwa1.7HANDOFF.md`.
Design-system source of truth: `/Users/hanwen/dev/Tonus/design-system/` — **canonical,
in-repo, versioned on branch `v1.7-field-notes`** (extracted 2026-07-30 from
`~/Downloads/Tuwa Design System.zip`; structure verified — SKILL.md, readme.md, tokens/,
guidelines/, components/, ui_kits/{ios-app,website}, templates/). A byte-identical spare
snapshot sits at `~/dev/tuwa-design-system/`; on any future zip re-import, refresh the
in-repo copy first — it is the one sessions read.

## Ground rules (bind every session)

1. **Read first, in order:** `/Users/hanwen/dev/Tonus/design-system/SKILL.md` → `readme.md` → `tokens/` →
   your lane's brief below. For iOS lanes also `DESIGN.md` (post-v6 rewrite) and `CLAUDE.md`.
2. **Git: no session ever commits.** All commits go through the orchestrator after
   verification (preserves the pair-protocol sole-committer rule and prevents cross-session
   races). Work lands on branch `v1.7-field-notes`, not `main` — v1.6 build 17 is in App
   Store review and `main` must stay hotfix-clean.
3. **`.pbxproj` is Session A only.** Any other session needing a file added to the target
   writes it in its status file and stops that thread; the orchestrator routes it to A.
4. **Builds:** each iOS session uses its own DerivedData:
   `-derivedDataPath ~/.tonus-dd-claude-<lane>` (a, b, c, d). Never in-repo `build/`,
   never a shared path.
5. **Status reporting:** each session appends to its own file
   `.planning/v17-field-notes/status-<lane>.md` (one writer per file — no append races).
   Entry format: timestamp, what changed, verification result (actual command + outcome),
   open blockers. A "done" without a build/test result is invalid.
6. **Design law:** v6 is an overlay on v5 Pavilion, not a replacement. Unchanged and still
   binding: CornerTokens (12/8/pill), no shadows (relief system), 8pt grid, light-only,
   sentence case, zone-states-never-color-alone (nocebo guard), one ink-filled pill CTA
   max, Motion tokens only. Changed by v6: metric hues (five), re-tuned zone colors,
   Fragment Mono annotation layer (≤12pt, uppercase, +0.05em tracking — annotation ONLY,
   never body/headline), annotation choreography (40ms stagger after surface settle).
   **Nobody edits `DESIGN.md` except Session A in Wave 1, and that rewrite gates on HAN's
   sign-off before Wave 2 starts.**
7. **Pair board:** `.pair/` is live protocol. The orchestrator posts the v1.7 CLAIM set on
   `.pair/claude.md` at kickoff so a waking CODEX sees ownership. Sessions do not write to
   `.pair/`.

## Wave 0 — Preconditions (HAN + orchestrator, before any session)

- [x] **Field Notes folder delivered** — canonical copy extracted into the repo at
      `/Users/hanwen/dev/Tonus/design-system/` (2026-07-30, HAN-directed), so it is
      versioned with the app and every session finds it. Spare snapshot at
      `~/dev/tuwa-design-system/`.
- [x] **Website lane owner: Claude Session E under CLAIM** (HAN decision 2026-07-30,
      precedent C-007).
- [ ] **Fragment Mono TTF is NOT in the zip** — `fonts/` ships only `Alpino-Variable.ttf`;
      Fragment Mono is CDN-imported in `tokens/fonts.css`. Session A downloads it from
      Google Fonts (Fragment Mono, by Wei Huang, SIL OFL — embedding permitted; keep the
      OFL.txt alongside the TTF), and Session E self-hosts the woff2 for the site.
- [ ] Orchestrator: create branch `v1.7-field-notes` from current `main`; post CLAIM on
      the pair board.

## Wave 1 — Foundation (serial: Session A alone)

**Session A — iOS tokens, fonts, chokepoints.** The only session alive in Wave 1.

Scope, in order:
1. `DESIGN.md` v5→v6 rewrite (overlay semantics per ground rule 6) + sync the changed
   facts into `CLAUDE.md` **and** `AGENTS.md` same turn (hand-synced twins).
2. Port `tokens/colors.css` → `ColorTokens` (five metric hues, re-tuned zone colors;
   stone planes / ink ramp mostly identical to v5 — diff before rewriting).
3. Bundle Fragment Mono TTF: font file into Resources, `UIAppFonts` in
   `workload management/workload-management-Info.plist`, `.pbxproj` registration, font
   assertion in `WorkloadApp.swift` (matches existing Instrument Sans pattern).
4. Add `Font.Tokens.anno` (≤12pt cap, uppercase + tracking handled at the token/modifier
   level so call sites can't violate it).
5. Update the chokepoint `WorkloadApp/Components/CardStyle.swift` so surfaces inherit v6.
6. Extend `WorkloadAppTests/DesignSystemFenceTests.swift`: metric-hue tokens exist and
   are the only new colors; anno size cap; Fragment Mono sanctioned for annotation only;
   IBMPlexMono / SourceSerif4 stay banned.
7. Annotation choreography primitive: one reusable modifier implementing the 40ms-stagger
   fade-in on the existing non-bouncy spring grammar — Wave 2 consumes it, nobody
   reimplements it per screen.

**Gate to Wave 2:** full suite green (`xcodebuild test`, 782+ tests), fence tests
extended and green, orchestrator visual check of one retrofitted reference surface
against `/Users/hanwen/dev/Tonus/design-system/ui_kits/`, HAN signs off on the DESIGN.md v6 rewrite.

## Wave 2 — Parallel adoption (Sessions B, C, D, E concurrently)

Disjoint file ownership; shared files (`Components/`, `ColorTokens`, `CardStyle`,
fence tests) are **frozen** — change requests route through the orchestrator to A's
follow-up queue.

- **Session B — Dashboard + Recovery.** `Views/Dashboard/`, `Views/Recovery/`. Hero
  readings take their metric's hue; marginalia (units, deltas, timestamps, reason trees
  `├─ └─`) via `Font.Tokens.anno`; choreography via A's primitive. Nocebo guard
  unchanged: zone states stay label-first.
- **Session C — Workload + Log.** `Views/Workload/`, `Views/WorkoutLog/`. Chart axis
  labels and dots take metric hues; Charts-framework axis marks move to anno face.
- **Session D — Profile + Onboarding + Auth + shared components.** `Views/Profile/`,
  `Views/Onboarding/`, `Views/Auth/`, plus `Components/` (MetricTile, ZoneBadge,
  HRVTrendChart, SleepTrendChart) — D owns `Components/` in Wave 2 so B/C don't race it;
  B/C consume, never edit.
- **Session E — Website** (`tuwa-website/`, separate repo — zero collision with B/C/D).
  Replace the custom-property block in `src/styles/global.css` with `tokens/*.css`
  values (names map 1:1 by intent); **self-host Fragment Mono** (it is CDN-imported in
  `tokens/fonts.css` — the site has a no-CDN law, so this is mandatory, not optional);
  wire `--font-display` Alpino + display ramp from `tokens/typography.css`
  (marketing-only); map `ui_kits/website/motion.js` scene-for-scene onto
  `src/scripts/homeMotion.ts` — existing scenes (hero scrub, showcase, zone scrub, fans,
  ghosts) retune only; the **section-04 self-drawing chart is the one new scene**.
  Keep Lottie/Lenis as-is. **Release-gated routes: `/terms`, `/zh/terms`, `/fr/terms`,
  `/privacy`, `/support` are cited in the live App Store listing — restyle must not
  change their content or break their builds.** Verify: `npm run build` (66 pages) +
  `npx astro check` clean + orchestrator visual pass.

**Gate to Wave 3:** full suite green on the merged branch, orchestrator cross-screen
visual sweep (every tab, sim screenshots vs `ui_kits/` references), no fence violations,
website build clean + legal routes byte-diffed for content parity.

## Wave 3 — Derivative surfaces (after the app look is locked)

- **Session F — App Store screenshot pipeline.** Restyle `scripts/frame_screenshots.swift`
  output with Field Notes framing + mono annotations; regenerate en + zh-Hans sets.
  Depends on Wave 2 because screenshots capture the real app.
- **Session G — brand batch (single session, low priority):** docs pages
  (`docs/privacy.html`, `support.html`, `terms.html` — legacy copies; content frozen,
  tokens/type only), OG images (`tuwa-website/public/og/*` — stone plane, mono
  annotation strip, metric-hue accent), pitch deck from
  `/Users/hanwen/dev/Tonus/design-system/templates/pitch-deck` (swap placeholder market figures —
  orchestrator supplies real ones from `docs/market-intelligence/`), transactional email
  template. Nothing here gates the release.

- **Session H — rich chart detail views (glance/zoom split).** HAN direction 2026-07-30.
  The two-tier model: **glance charts** (the trend cards on Dashboard / Recovery / Load)
  stay exactly as they now are — clean, minimal, reference keys above the plot, no
  legend. **Zoomed detail views** (existing `HRVDetailView` / `SleepDetailView` are the
  mount points) become the rich analytical surface: for sleep, the 6 h boundary and the
  7.5 h recommended baseline plus the restored three-swatch zone legend (the 3
  unreferenced xcstrings keys from Wave 2 still exist for exactly this); day
  scrub/selection via `chartOverlay` gesture with a selected-day annotation readout;
  expandable explanations; the full Field Notes annotation register (reason trees,
  machine keys) — the detail view is where the annotation voice earns its keep; a rich
  breakdown of the recovery condition. Reconcile the glance chart's 7 h target with the
  6 h / 7.5 h physiology bands (proposed frame: target = athlete-facing goal line, bands
  = physiology; session proposes, HAN decides). All inside v6 law: Five-Primitive
  interaction, Motion tokens, zone-coloured text on card planes only. Sequence: written
  per-chart spec against `design-system/guidelines/` first → HAN approves → build.
  Gate: HAN visual review on simulator.

Explicitly deferred: product videos / App Store previews (Remotion), watchOS/widgets.

## Post-1.7 — Session W: website homepage rebuild to the ui_kit layout

HAN direction 2026-07-31: Wave 2's website lane replaced tokens but kept the old layout.
HAN wants the LAYOUT of `design-system/ui_kits/website/index.html` (+ `motion.js`,
`motion-iterations.html`, `motion-addons-demo.html`). Demo structure, in order: line-reveal
hero ("Your plan. Made safe and optimal.", hero score count-up) → "One decision, every
day" (verdict) → "One fatigue budget" (zone, surface band) → "The whole system, one
gesture" (showcase) → "Your baselines, drawn daily" (self-drawing chart) → ghost-numerals
band → "Your data stays on your phone" (privacy, surface band) → footer.

Constraints: Astro + i18n stays (en/zh/fr through the locale files — the demo is en-only,
every string ports through i18n); no-CDN law (vendored Lottie/Lenis exist at
`design-system/assets/vendor/`); legal routes + [...seoGeo] pages untouched;
reduced-motion guard on every scene; `npm run build` + `npx astro check` clean.

**HAN clarifications (2026-08-01), binding:**
1. **Demo-first, zero commits.** Session W builds a standalone visual demo, NOT repo
   changes. No commit lands in tuwa-website (or anywhere) for this work. HAN compares the
   demo against the live site, orders refinements, and iterates. Only after HAN locks the
   direction does anyone scope the real Astro port (a later, separate brief).
2. **The kit demo is the layout basis, not a contract.** Adapt content dynamically to what
   the product is NOW. Explicitly invited: a science/methodology section presenting the
   sleep-score algorithm's uniqueness (context-conditional, personalized-need, open
   hypothesis registry — `.planning/v17-field-notes/research-sleep-score.md` §9–§10).
   HARD RAIL: the engine is not built; every claim follows the §10 ladder — present it as
   transparent methodology under development, never as a live or validated feature.

Demo mechanics: self-contained HTML (the kit's own form) in
`tuwa-website/.design-explorations/website-v2-demo/` (untracked scratch space, precedent:
v16-motion-demos). Real Tuwa copy, vendored assets copied in (no CDN), reduced-motion
guarded, viewable by `open`ing the file or a local server. Deliver beside it a
side-by-side comparison (demo screenshots vs live tuwa.app captures, section by section).

### Session W kickoff prompt (demo-first revision)

```
You are Session W (homepage demo) for Tuwa. Your deliverable is a STANDALONE VISUAL DEMO —
you make ZERO git commits anywhere, and you never push (tuwa.app deploys on push and is
live). Build in tuwa-website/.design-explorations/website-v2-demo/ (untracked scratch).
Read /Users/hanwen/dev/Tonus/design-system/SKILL.md, readme.md, tokens/, then
ui_kits/website/index.html + motion.js + motion-iterations.html + motion-addons-demo.html
(your layout basis), then .planning/v17-field-notes/DISTRIBUTION.md section "Post-1.7 —
Session W" including HAN's 2026-08-01 clarifications (they bind you), and
.planning/v17-field-notes/research-sleep-score.md §9-§10 (for the algorithm section's
content and its claim rails). Build the demo with the kit's structure adapted to the
current product; include the algorithm/science section under the §10 claim ladder; use
real copy from the live site where sections map. Then produce a section-by-section
side-by-side (demo vs live tuwa.app screenshots) into the same folder and STOP for HAN's
review. Report to .planning/v17-field-notes/status-w.md. Do not touch app-repo source,
website src/, or legal routes.
```

## Orchestrator protocol (this session)

Per wave: (1) issue prompts; (2) poll `status-*.md`; (3) on each DONE, independently
re-run the session's stated verification (never trust the summary), diff-review against
the spec cards in `/Users/hanwen/dev/Tonus/design-system/guidelines/`, run the full suite with orchestrator
DerivedData, visual-QA on the iPhone 17 Pro Max sim; (4) commit the wave with a
conventional message on `v1.7-field-notes`; (5) open the next wave. Merge to `main` and
any push: HAN's explicit go only. ASC untouched (build 17 in review).

Failure handling: a session that reports green but fails orchestrator re-verification
gets the failing output pasted back verbatim and re-runs; two failures → orchestrator
takes the lane over serially.

## Session kickoff prompts

Substitute `/Users/hanwen/dev/Tonus/design-system` everywhere. Give each session its prompt verbatim.

### Session A (paste after Wave 0 clears)

```
You are Session A (foundation lane) for Tuwa v1.7 "Field Notes". Read, in order:
/Users/hanwen/dev/Tonus/design-system/SKILL.md, /Users/hanwen/dev/Tonus/design-system/readme.md, /Users/hanwen/dev/Tonus/design-system/tokens/,
then .planning/v17-field-notes/DISTRIBUTION.md (your scope = "Session A", ground rules
bind you), then DESIGN.md and CLAUDE.md. Work on branch v1.7-field-notes. Do NOT
commit — the orchestrator commits. Build with -derivedDataPath ~/.tonus-dd-claude-a.
Report progress by appending to .planning/v17-field-notes/status-a.md (timestamp, change,
actual verification output, blockers). Execute your seven scope items in order; stop and
report after item 1 (DESIGN.md v6 rewrite) for HAN sign-off before continuing.
```

### Session B / C / D (paste when Wave 1 gate clears; identical except lane letter)

```
You are Session <B|C|D> (adoption lane) for Tuwa v1.7 "Field Notes". Read, in order:
/Users/hanwen/dev/Tonus/design-system/SKILL.md, /Users/hanwen/dev/Tonus/design-system/readme.md,
/Users/hanwen/dev/Tonus/design-system/guidelines/, then .planning/v17-field-notes/DISTRIBUTION.md (your
scope = "Session <B|C|D>", ground rules bind you), then DESIGN.md (now v6) and CLAUDE.md.
Branch v1.7-field-notes. Do NOT commit; do NOT touch .pbxproj, Components/CardStyle.swift,
ColorTokens, or fence tests — needed changes there go in your status file as a request.
[D only: you DO own Components/ this wave.] Build with
-derivedDataPath ~/.tonus-dd-claude-<b|c|d>. Report to
.planning/v17-field-notes/status-<b|c|d>.md with real build/test output. Apply metric
hues, Fragment Mono marginalia (Font.Tokens.anno), and the annotation choreography
primitive to your screens only. Zone states stay label-first. After each 3-5 files,
build before continuing.
```

### Session E (website; paste when Wave 1 gate clears, if HAN assigns to Claude)

```
You are Session E (website lane) for Tuwa v1.7 "Field Notes", working in tuwa-website/
(its own repo). First append a CLAIM entry to .pair/claude.md per .pair/PROTOCOL.md §4
naming your files. Read /Users/hanwen/dev/Tonus/design-system/SKILL.md, readme.md, tokens/,
ui_kits/website/, then .planning/v17-field-notes/DISTRIBUTION.md (scope = "Session E").
Constraints: no-CDN law (self-host Fragment Mono), Alpino stays marketing-only,
/terms /zh/terms /fr/terms /privacy /support are App-Review-gated — token/type restyle
only, zero content change, verify they build. You may commit in tuwa-website (CODEX
convention) but never push — HAN publishes. Verify with npm run build + npx astro check;
report to .planning/v17-field-notes/status-e.md.
```

### Wave 3 kickoff prompts (opened 2026-07-30, HAN's go)

Wave 3 runs five lanes: F, G, H, P (punch list), T (Dynamic Type). Two rules learned in
Wave 2, binding on every lane: (1) **never run the full test suite** — three concurrent
xcodebuild runs starved each other and killed all three lanes; build your own target
(`xcodebuild build`) or run a single targeted test at most, and the orchestrator
verifies serially at the gate; (2) commits are the orchestrator's only.

File ownership (disjoint; a needed change outside your list goes in your status file):
- **F:** `scripts/frame_screenshots.swift`, screenshot output dirs. No app source.
- **G:** `docs/*.html` (content frozen, tokens/type only), `tuwa-website/public/og/*`,
  `design-system/templates/pitch-deck` output, email template (new file under
  `design-system/templates/`). No app source.
- **H:** `Views/Dashboard/SleepDetailView.swift`, `HRVDetailView.swift`, new detail-view
  files, chart components (`HRVTrendChart`, `SleepTrendChart`, `LoadTrendChartView`),
  **`.pbxproj` (H is the sole Wave 3 toucher — back it up first)**, xcstrings additions.
- **P:** `ActiveWorkoutSheet`, `ExercisePickerView`, `TemplatePickerSheet`,
  `RadialPicker`, `ScreenHeader`, `StatusBadge`, `WeeklySummaryCard`/`WeeklyZoneBadge`,
  Session B's four files, zh screenshot capture. NOT the chart components (H's).
- **T:** `FontTokens.swift` only (plus DESIGN.md Dynamic Type section) — everyone reads
  it, only T writes it.

#### Session F

```
You are Session F (App Store screenshots) for Tuwa v1.7 "Field Notes", branch
v1.7-field-notes. Read /Users/hanwen/dev/Tonus/design-system/SKILL.md, readme.md,
guidelines/, then .planning/v17-field-notes/DISTRIBUTION.md (scope = Session F + the
Wave 3 rules). Restyle the scripts/frame_screenshots.swift pipeline output with Field
Notes framing + Fragment Mono annotations (stone plane frames, mono annotation strip,
metric-hue accents); regenerate en + zh-Hans sets. You may run ScreenshotTests (it is
one target, allowed) with -derivedDataPath ~/.tonus-dd-claude-f. Do NOT commit; do NOT
touch app source — if a capture exposes an app defect, report it in
.planning/v17-field-notes/status-f.md. Note: if lanes H/P later change a captured
surface, the pipeline re-runs — build it so re-running is one command.
```

#### Session G

```
You are Session G (brand batch) for Tuwa v1.7 "Field Notes", branch v1.7-field-notes.
Read /Users/hanwen/dev/Tonus/design-system/SKILL.md, readme.md, tokens/, templates/,
then .planning/v17-field-notes/DISTRIBUTION.md (scope = Session G + Wave 3 rules).
Four deliverables: (1) docs/privacy.html, support.html, terms.html — Field Notes
tokens/type ONLY, byte-identical text content (these are legal pages); (2) regenerate
tuwa-website/public/og/* in Field Notes (stone plane, mono annotation strip, metric-hue
accent); (3) pitch deck from design-system/templates/pitch-deck — real market figures
come from docs/market-intelligence/, flag any placeholder you cannot ground; (4) a
transactional-email HTML template (stone surfaces, ink pill CTA) as a new file in
design-system/templates/email/. Do NOT commit. Report to
.planning/v17-field-notes/status-g.md.
```

#### Session H

```
You are Session H (rich chart detail views) for Tuwa v1.7 "Field Notes", branch
v1.7-field-notes. Read /Users/hanwen/dev/Tonus/design-system/SKILL.md, readme.md,
guidelines/, ui_kits/ios-app/, then DESIGN.md (v6.2) and
.planning/v17-field-notes/DISTRIBUTION.md (scope = "Session H" in Wave 3 + the Wave 3
rules). The model: glance charts stay exactly as they are; the zoomed detail views
(SleepDetailView / HRVDetailView mounts) become the rich analytical surface — for
sleep: 6h boundary, 7.5h recommended baseline, restored three-swatch zone legend (3
orphaned xcstrings keys exist), day scrub/selection with a selected-day annotation
readout, expandable explanations, full annotation register. Reconcile the glance 7h
target with the physiology bands (propose; HAN decides). PHASE 1: write a per-chart
spec to .planning/v17-field-notes/spec-h-charts.md and STOP for HAN approval. PHASE 2
(after approval): build. You own .pbxproj this wave — back it up before editing. Build
with -derivedDataPath ~/.tonus-dd-claude-h; never run the full suite; do NOT commit.
Report to .planning/v17-field-notes/status-h.md.
```

#### Session P

```
You are Session P (punch list) for Tuwa v1.7 "Field Notes", branch v1.7-field-notes.
Read DESIGN.md (v6.2), .planning/v17-field-notes/DISTRIBUTION.md (Wave 3 rules +
your file list), and .planning/v17-field-notes/status-orchestrator-wave2.md (your work
items live in its "Open items" section). Items: (1) re-inspect Session B's four
untouched files (transcript lost — verify v6 adoption is complete or finish it);
(2) C's leftovers: ActiveWorkoutSheet remaining regions, ExercisePickerView region,
TemplatePickerSheet off-token spacing; (3) D's leftovers: RadialPicker =="en" idiom →
isLatin; (4) REQ-D2: ScreenHeader.context unconditional uppercase (zh violation, fix
at source); (5) REQ-D3: StatusBadge — determine dead or alive, then card-plane
treatment or removal request; (6) WeeklyZoneBadge card-plane check; (7) zh-Hans visual
pass: capture zh screenshots of all five tabs + key sheets to
.planning/v17-field-notes/zh-pass/ for HAN review. Do NOT touch chart components
(Session H owns them). Build with -derivedDataPath ~/.tonus-dd-claude-p; never run the
full suite; do NOT commit. Report to .planning/v17-field-notes/status-p.md.
```

#### Session T

```
You are Session T (Dynamic Type) for Tuwa v1.7 "Field Notes", branch v1.7-field-notes.
Read DESIGN.md (v6.2), WorkloadApp/Utilities/FontTokens.swift, and
.planning/v17-field-notes/DISTRIBUTION.md (Wave 3 rules). Goal: the app currently
ignores the iOS system text-size setting; convert Font.Tokens to scale with it
(.custom(_:size:relativeTo:) with sensible textStyle mappings) so the whole ramp
follows Dynamic Type with hierarchy preserved. Decisions to propose in your status
file BEFORE implementing: which textStyle each token maps to; whether/how the
annotation voice scales (the ≤12pt law is a design law — propose how it interacts
with accessibility sizes rather than silently breaking either); whether to cap at an
accessibility size to protect layouts. Then implement FontTokens.swift ONLY — do not
sweep call sites this wave. At the default (Large) setting every size must be
byte-identical to today: verify by building and confirming no visual change at
default. Stress-screenshot 2-3 screens at XL/AX sizes for HAN. Build with
-derivedDataPath ~/.tonus-dd-claude-t; never run the full suite; do NOT commit.
Report to .planning/v17-field-notes/status-t.md.
```

## Wave 3 — HAN rulings (2026-07-31, after Round 1)

Round 1 delivered all five lanes with no git write (HEAD `8742629`); five adversarial
reviewers returned `needs-work` with file:line evidence. Orchestrator suite run:
`** TEST SUCCEEDED **`, 0 failures. These rulings bind Round 2.

1. **Sleep target = 6 h floor + 7.5 h target, APP-WIDE.** Overrules Session H's
   evidence-based counter-proposal (6 h + 7 h). Scope of the change: the glance
   `SleepTrendChart` rule moves 7 h → 7.5 h (the freeze is lifted for this value only);
   the three legend keys become `<6H` / `6–7.5H` / `7.5H+` in en **and** zh-Hans; the
   shipped `sleep.detail.explanation` string is rewritten in both locales; **and
   `RecoveryScoreEngine.sleepDurationToScore`'s 70-point knee moves 7 h → 7.5 h** so the
   score cannot disagree with the line. This last part is an algorithm change and needs
   its own test update and verification.
2. **Dynamic Type: brief amended by HAN's delegation.** The brief's
   `Font.custom(_:size:relativeTo:)` prescription is **withdrawn** — it cannot carry the
   `UIFontDescriptor` that pins the Noto Sans SC cascade, and losing that is a zh-Hans
   regression. Route is now `UIFontMetrics(forTextStyle:).scaledFont(for:)`, **hard-gated
   on proving SwiftUI reflows on a live content-size change**. If that proof fails, stop
   and escalate — do not fall back to `Font.custom`.
3. **The ≤12pt annotation cap becomes a SPECIFICATION cap.** "Fragment Mono is specified
   at ≤12pt at the default content size and scales on the working voice's curve." The
   `min(size, annoSizeCap)` clamp stays and clamps the **base** size, so no token may
   declare >12pt. DESIGN.md, `FontTokens.swift` and the fence rationale get reworded.
4. **`docs/*.html` become canonical redirects to tuwa.app.** They are NOT dead: build 17's
   paywall (`UpgradeSheet.swift:184-189`) links to them, and `docs/terms.html` is already
   missing "11. Apple App Store terms" — the exact section the build-17 rejection was
   about. Redirecting removes the drift class rather than patching this instance.

## Wave 3 — HAN rulings, round 2 (2026-07-31)

5. **Dynamic Type is DROPPED from v1.7.** Lane T's hard gate failed as written: `UIFontMetrics`
   reads the process-wide content size category and creates no SwiftUI environment dependency,
   so on a live text-size change only views that read `\.dynamicTypeSize` themselves re-render.
   Measured result (`.planning/v17-field-notes/dynamic-type-shots/`): `InkTabBar` reflowed while
   the surrounding type did not — an internally inconsistent screen, i.e. **worse than today's
   consistent non-adoption**. HAN's call: drop it. Reverted to HEAD: `FontTokens.swift`,
   `InkTabBar.swift`, `TickScale.swift`, `DesignSystemFenceTests.swift`, `DESIGN.md` (so the
   design system stays at v6.2, NOT v6.3). **Kept as the record for a future dedicated wave:**
   `spec-t-dynamic-type.md`, `status-t.md`, `dynamic-type-grid.txt`, `dynamic-type-shots/`.
   The measured finding worth carrying forward: iOS's text-style curves are not mutually
   monotone (`.caption2` floors at 11pt then jumps +4pt at XL), so a per-token style mapping
   inverts the ramp — three curves is the shape that works. The next attempt should use the
   `.tokenFont()` modifier reading `@Environment(\.dynamicTypeSize)` (sweeps ~492 call sites).
6. **All three `docs/*.html` redirects ship** — HAN reaffirmed after seeing the counter-evidence
   that tuwa.app/privacy (March 27) lacks the Data Sharing section `docs/privacy.html` (June 5)
   carries, and tuwa.app/support has no account-deletion answer. Filed to CODEX as content gaps
   to close on the website: port Data Sharing into `src/i18n/locales/{en,zh,fr}/privacy.ts` and
   bump `lastUpdated`; add an account-deletion FAQ to the support page (App Review 5.1.1(v)).
