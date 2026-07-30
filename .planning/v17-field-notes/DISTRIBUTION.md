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

### Session F / G — prompts issued by the orchestrator when Wave 3 opens (scope above).
