# Tuwa v1.5.1 UI Audit — INVENTORY

Generated 2026-06-02. Synthesizes 8 drift-class scans + 11 per-screen hierarchy reviews against `DESIGN.md`.
Tokens reference: `WorkloadApp/Utilities/ColorTokens.swift`, `FontTokens.swift`; card primitive `WorkloadApp/Components/CardStyle.swift` (`cardStyle()` = surfaceEl + 0.5pt divider + 16/24 pad; `Spacing` = xs8/sm16/md24/lg32/xl48; `SectionHeader` = 19pt Medium text1; `SectionContainer` = 32pt topGap).

---

## 1. EXECUTIVE SUMMARY

**Total findings: 222** — 158 drift-scan entries + 64 per-screen review issues across 11 screens.
- Drift breakdown: rounded-corners 0, shadows 0, non-token-fonts 14, accent-misuse 1, off-grid-spacing 112, surface-ladder-misuse 14, handrolled-cards 16, hardcoded-color 1.
- Screen reviews flagged 64 issues (10 screens scored; Analytics is an empty dir, score 0).
- Mean screen score 4.9/10; worst cluster: Auth 3.5, Coach 3.5, Profile 5.0, Workout Log 4.5, Dashboard 5.5.

**Top 3 root causes by readability impact**
1. **Elevation-ladder / surface misuse (~30+ findings, mostly HIGH).** Grouped/tappable cards across Dashboard, Workout Log, Recovery, Coach, Auth, Profile, paywall fill with `ColorTokens.surface` (inline-strip plane) or hand-roll the box instead of `.cardStyle()` / `surfaceEl`. Result: cards sit on the same plane as the page canvas and "blend in." This is the #1 readability killer — it flattens every screen into one plane.
2. **Hierarchy / section-grammar drift (broad, HIGH on Auth/Coach/Workout Log/Profile).** Section titles rendered as 12pt micro-caps (`.Tokens.micro` + `tracking(1.2)` + text3) instead of the 19pt Medium `SectionHeader`; no 32pt `SectionContainer` breaks; primary CTAs styled identically to selectable chips / field rows. The eye cannot find the section structure or the primary action in 2 seconds.
3. **Off-grid spacing (112 findings).** Pervasive 12 / 10 / 6 / 4 / 2 pt literals (de-facto row padding `12`, half-step stack `4`, `2`), incl. shared primitives (`MetricTile`, `SharpTextFieldStyle`, `DesignToggleStyle`) that propagate drift app-wide.

**Single highest-leverage first fix:** Fix the **surface→surfaceEl elevation ladder at the source recipes** — `MetricTile.swift`, `InsightCard.swift`, `CycleFuelingCard.swift`, the three attention banners, and the five Dashboard cards — by routing them through `.cardStyle()` (or swapping `.surface`→`.surfaceEl`). Because `MetricTile` and the `InsightCard` recipe are copied everywhere, fixing the shared primitives plus the Dashboard card set lifts plane separation across the entire app in one wave and directly addresses the "components blend in" complaint.

---

## 2. ROOT-CAUSE GROUPS

### A. Elevation-ladder / surface misuse  (surface-ladder-misuse: 14 + handrolled-cards: 16 + screen-review plane issues; ~40 findings)
Severity: predominantly HIGH; a few MED (banners, tooltip).
The single biggest group. `.surface` (inline-strip token, `0x161615`/`0xEDEAE6`) used where `surfaceEl` (`0x1F1F1D`/`0xE4E0DB`) belongs, and/or boxes hand-rolled instead of `.cardStyle()`.
**Affected files (cards/strips):**
- Shared primitives: `Components/MetricTile.swift:29`, `Components/CycleFuelingCard.swift:51`, `Components/FatigueAttentionBanner.swift:70`, `Components/REDSAttentionBanner.swift:44`, `Components/SpikeAlertBanner.swift:70`, `Components/ChartTooltipOverlay.swift:51` (correct token, hand-rolled — LOW)
- Dashboard: `WeeklySummaryCard.swift:99`, `WelcomeActionCard.swift:57`, `TrainingProfileCard.swift:44`, `PRSDualRunCard.swift:50` (also lineWidth:1 vs 0.5), `NotificationPrePermissionCard.swift:58`
- Recovery: `InsightCard.swift:20`, `BehaviorCorrelationRow.swift:41 & 67`, `MorningCheckInSheet.swift:290` (slider rows)
- Workout Log: `PrescribedWorkoutCard.swift:90`, `TemplateCarouselSection.swift:247`, `TemplatePickerSheet.swift:139`, `ActiveWorkoutSheet.swift:803 & 990`, `SessionDetailView.swift:27 & 188`
- Workload: `WorkloadView.swift:384` (PRHistorySection on `.background`)
- Coach: `ClientDetailView.swift:152`, `CoachRosterView.swift:93` (listRowBackground), `TemplateListView.swift:99`, `CoachWorkoutEntrySheet.swift`, `PrescribeWorkoutSheet.swift:51`, `TemplateEditorSheet.swift:254`
- Auth: `LoginView.swift:79/102/136`, `SignUpView.swift:108/155`, `SocialLoginButtons.swift:73`
- Profile: `ProfileView.swift` (whole list on `.background`, only InviteCoachCard carded), `EnterInviteCodeSheet/EmailInviteSheet:924/978`, `TrainingProfileSheet.swift:404`
- Paywall: `UpgradeSheet.swift:215/421` (HistoryTeaserBanner tappable on `.surface`)
- Onboarding: `OnboardingView.swift:130-134, 181-185` (option tiles on `.background`)
**Fix:** route through `.cardStyle()`; reserve `.surface` strictly for selected inline controls; selected-state = surface, resting tappable card = surfaceEl.

### B. Hierarchy / section-grammar  (screen-review issues; HIGH on Auth/Coach/Workout Log/Profile)
Severity: HIGH on hero/core screens.
Micro-caps section titles instead of `SectionHeader`; no 32pt breaks; primary CTAs indistinguishable from chips/fields; flat text tiers (load stats, session rows, roster status at same weight as captions).
**Affected files:** `DashboardView.swift` (TrainingLoadSection inline head, micro-cap card titles, flat load stats), `WorkoutLogView.swift:108-115` + `TemplateCarouselSection.swift:100-107` (micro-caps), `SessionDetailView.swift` (no headers), `RecoveryView.swift:311-314`, `MorningCheckInSheet.swift:93/149`, `ClientDetailView.swift:128-309` (all 6 heads micro-caps), `CoachWorkoutEntrySheet.swift`, `PrescribeWorkoutSheet.swift:132`, `CoachExportSheet.swift`/`PDFGenerationSheet.swift`, `SyncStatusView.swift:14-21`, `TrainingProfileSheet.swift:205-214`, `InviteConfirmationSheet.swift:42-45` (hardcoded EN micro-caps), `SignUpView.swift:88/337`, `LoginView.swift`, `UpgradeSheet.swift:69-116`.
**Fix:** `SectionHeader` + `SectionContainer` for true sections; promote primary CTAs to a dominant filled plane (text1 fill / background label) distinct from chips; introduce one emphasis tier per row.

### C. Off-grid spacing  (off-grid-spacing: 112)
Severity: HIGH on core Dashboard/Profile/shared primitives; mostly MED/LOW.
Recurring offenders: `12` de-facto row padding (Profile, WorkoutLog, Coach, Auth, sheets), half-step `4` stack spacing, `2`/`6`/`10` literals, off-grid frames (44, 180, 28, 20, 36×4 grabber, 5).
**Highest-priority files:** `SharpTextFieldStyle.swift:9` (app-wide field pad 12), `MetricTile.swift:11/52/53`, `CardStyle.swift:126/130/131` (toggle 28/20/4), `DashboardView.swift:360/496/501/589/635`, `ProfileView.swift` (≈10× `vertical,12`), `WorkoutLogView.swift`, `ActiveWorkoutSheet.swift`, `UpgradeSheet.swift`, `PDFGenerationSheet.swift:93` (minHeight 44 vs Coach's 48).
**Fix:** snap to `Spacing.*`; 12→8/16, 4→8, 44→48, 180→176/184; allow documented sub-grid only for true hairlines/indicators (0.5/1/2/3pt rules).

### D. Non-token fonts  (non-token-fonts: 14)
Severity: 1 HIGH, 13 LOW.
- HIGH/real: `ShareImportPreviewSheet.swift:138` — `.Tokens.body` + system `.fontWeight(.medium)` on primary CTA → should be `.Tokens.bodyMedium`.
- LOW/borderline (SF Symbol glyph sizing via `.system(size:)`, no Font.Tokens icon equiv): `SignUpView.swift:99`, `TemplatePickerSheet.swift:118`, `TemplateCarouselSection.swift:172/193/226/346`, `ContextSwitcher.swift:34`, `WeeklySummaryCard.swift:27/42`, `TrainingProfileSheet.swift:263/309/344/375`.
**Fix:** replace CTA fontWeight with token; replace icon `.system(size:)` with a Font.Tokens token or `imageScale`; off-grid sizes (10/14/20) also fail grid.

### E. Hardcoded color  (hardcoded-color: 1)
`UpgradeSheet.swift:146` `.foregroundStyle(.red)` on purchase-error text → `ColorTokens.zoneDanger`. MED.

### F. Accent misuse  (accent-misuse: 1)
`ClientDetailView.swift:138` `ColorTokens.accent` on coach's client recovery score — accent is reserved for the single athlete Dashboard hero (`DashboardView.swift:314`). MED → use text1/text2.

### G. Corner radius / shadow
Drift scans: **0 / 0** — clean.
**Exception found in screen review:** `TemplateEditorSheet.swift:330/335/340` + header fields use `.textFieldStyle(.roundedBorder)`, which renders rounded corners — a 0pt-corner violation the regex scan missed. HIGH. Fix with a square custom field style.

---

## 3. PER-SCREEN RANKING (worst → best)

### Analytics — 0/10
Empty directory (`Views/Analytics/` has no `.swift`). Not a screen. **Action:** confirm intended path (likely lives under Workload/Dashboard); no fix needed unless a screen is planned.

### Auth (Login/SignUp/SocialLoginButtons) — 3.5/10  [primaryAction NOT findable, no plane sep, no header grammar]
Top issues:
- HIGH: Sign In CTA has zero dominance — same `.surface` + 17pt body as fields/Google/links. → fill `text1` / label `background`, or `bodyMedium` + surfaceEl.
- HIGH: only two planes (surface + background); no surfaceEl/cardStyle anywhere. → form in `.cardStyle()`, CTA on distinct plane.
- HIGH: micro-caps field/section labels; no 32pt breaks. → `SectionHeader`/`SectionContainer`.
- MED: SignUp sport chips & Google button `.surface` flat; sport icon `.system(size:20)`.

### Coach (Roster/ClientDetail/Templates/Prescribe/WorkoutEntry/TemplateEditor/ContextSwitcher) — 3.5/10
Top issues:
- HIGH: all 6 ClientDetail section heads are 12pt micro-caps; sections split by hairlines only, no 32pt breaks. → SectionHeader/SectionContainer.
- HIGH: ClientDetail recoveryHero, Roster ClientCard (`listRowBackground(.surface)`), CoachWorkoutEntry form & submit all on `.surface` → surfaceEl/cardStyle.
- HIGH: `TemplateEditorSheet` `.roundedBorder` text fields = corner violation; GroupEditorCard `.surface`; 10pt pad.
- MED: primary coach actions (Log/Prescribe) buried, equal-weight `.surface`; ContextSwitcher `.system(size:12)`; accent on client score (`:138`).

### Workout Log (★ codex-named highest-leverage) — 4.5/10
Top issues:
- HIGH: micro-caps section labels (Prescribed / My Templates / Watch) — replace with SectionHeader in SectionContainer.
- HIGH: no 32pt section breaks; whole tab is one VStack(spacing:0) divided by hairlines → wrap blocks in SectionContainer.
- HIGH: tappable cards on `.surface` — `PrescribedWorkoutCard:90`, `TemplateCarouselSection:247` (the primary "start a workout" entry), `ActiveWorkoutSheet` ExerciseEntryCard:803 → surfaceEl.
- MED: flat SessionRow hierarchy; off-grid 12/10; hardcoded EN column headers (SET/WEIGHT/REPS/RPE) + `.system(size:)` icons.

### Profile (ProfileView/SyncStatus/TrainingProfileSheet/LanguagePicker/InviteConfirmation) — 5.0/10  [primaryAction NOT findable]
Top issues:
- HIGH: entire settings list flat on `.background`, only InviteCoachCard carded → group each section in `.cardStyle()`.
- HIGH: SyncStatusView + TrainingProfileSheet micro-caps headers smaller than the rows they label → SectionHeader.
- MED: no dominant element; destructive Delete same weight as benign rows; off-grid 12pt row pad (≈10 sites) + inconsistent divider insets (16/40/52); `.system(size:10/14)` glyphs; hardcoded EN micro-caps in InviteConfirmation; confirm CTA only 13pt.

### Dashboard (★ codex-named highest-leverage) — 5.5/10
Top issues:
- HIGH: 5 cards (Welcome/TrainingProfile/Notification/WeeklySummary/PRSDualRun) on `.surface` while Hero/cycle/firstWeek prompts use `.cardStyle()` → two card planes stacked; standardize ALL on surfaceEl/cardStyle.
- HIGH: `WeeklySummaryCard` `.system(size:12/13)` on chevron/flame → Font.Tokens.
- MED: section-grammar inconsistency (TrainingLoadSection inline 19pt head, card titles as micro-caps); flat load stats (ACWR/ATL/CTL/TSB at 15pt label vs MetricStrip sectionHead); off-grid 4/2 spacing literals at 360/496/501/589/635.
- PRSDualRunCard border lineWidth:1 vs 0.5 hairline.

### UpgradeSheet (paywall) + HistoryTeaserBanner — 5.5/10
- HIGH: HistoryTeaserBanner (tappable Button) on `.surface` → cardStyle.
- MED: no SectionHeader/SectionContainer (12pt micro tabs/labels carry structure); whole sheet flat on `.background`; off-grid 12/10/6/4/2; `.red` error color (`:146`).
- LOW: flat 8-item feature list; low-emphasis price/SAVE% badge (text3 12pt).

### Profile note + Export sheets (CoachExportSheet/PDFGenerationSheet) — 6.5/10
- MED: PDFGenerationSheet chips `minHeight:44` off-grid (Coach uses 48) → 48; no plane sep (chips on `.surface`, group on background) → cardStyle container; section title inline `.sectionHead` not SectionHeader, no 32pt break/header on range section.
- MED: per-row hierarchy inverted (zone label 12pt micro-caps muted, smaller than name); chip typography differs between the two sheets (`.micro` vs `.label`) → extract shared RangeChip.

### Recovery (RecoveryView/MorningCheckIn/NiggleLog/InsightCard/BehaviorCorrelationRow) — 6.5/10
- HIGH: InsightCard + BehaviorCorrelationRow (both variants) on `.surface` inside SectionContainers → cardStyle.
- MED: MorningCheckIn slider rows `.surface` flat; RecoveryScoreCard + BEHAVIORS/WELLNESS labels micro-caps → SectionHeader.
- LOW: off-grid 4/3; literal 16/24 instead of Spacing tokens; flat 15pt secondary metric tier.

### Onboarding (4-step paged) — 7.0/10  [no plane sep]
- HIGH: frequency + experience option tiles fill `.background` (unselected) → no plane; tappable cards must be surfaceEl resting, surface selected.
- MED: primary CTA shares exact selected-tile treatment (surface + 1pt text3) → differentiate (text1 fill / background label).
- LOW: flat frequency text; inconsistent tap-target heights (24/16/56).

### Workload / Load tab (WorkloadView/RecoveryLoadChart) — 7.5/10  [best; header grammar & plane sep OK]
- MED: PRHistorySection renders on `.background` bracketed by rules instead of `.cardStyle()` — only section that recedes → card it.
- LOW: literal spacing (16/8) instead of Spacing tokens; 4pt baseline gaps; segmented control floats outside the chart card; ATL/CTL/TSB strip competes with ACWR hero (no eyebrow/break).

**Hero-screen callout (codex):** Dashboard (5.5) and Workout Log (4.5) are the highest-leverage targets — both fail plane separation AND header grammar, both are core daily screens, and both depend on the same shared primitives (`MetricTile`, cards). Fix these two screens + the shared recipes first for maximum perceived-quality lift.

---

## 4. AMEND-CANDIDATES

Screens/components where the elevation ladder is **already correctly applied** (`surfaceEl`/`.cardStyle()`) yet the review still flags blend/low-contrast — i.e. the only places that could justify tuning `ColorTokens` (e.g. raising surfaceEl/background luminance delta) rather than an enforce-fix:

**none — enforce-first fully sufficient.**

Every flagged blend/low-contrast issue traces to a *misused token* (`.surface` where `surfaceEl` belongs) or a hand-rolled box, not to a correctly-applied ladder reading too flat. The lone correctly-tokened example, `ChartTooltipOverlay.swift:51` (surfaceEl + 0.5pt), reads fine and was flagged only for not routing through `.cardStyle()` (cosmetic). Recommendation: complete the enforce pass first; re-audit contrast only after surfaceEl is applied everywhere. (Note for later: dark `background 0x0B0B0A` / `surface 0x161615` / `surfaceEl 0x1F1F1D` give ~10/20 luminance steps — likely adequate once correctly applied; the soft `text1 0xC2BEB7` raised in Auth review is a separate text-contrast question, not a ladder amend.)

---

## 5. REGRESSION GATE (run from repo root)

```bash
#!/usr/bin/env bash
# Tuwa DESIGN.md regression gate. Exits non-zero if any forbidden pattern reappears.
# Run from repo root. Scans WorkloadApp/ (excludes tokens/primitive definition files).
set -uo pipefail
SCOPE="WorkloadApp"
RG="rg --line-number --no-heading"
FAIL=0
fail(){ echo "VIOLATION: $1"; FAIL=1; }

# 1. Rounded corners (incl. SwiftUI rounded text fields)
$RG -n 'RoundedRectangle|\.cornerRadius|\.roundedBorder' $SCOPE && fail "rounded corners / .roundedBorder"

# 2. Shadows
$RG -n '\.shadow\(' $SCOPE && fail "shadow modifier"

# 3. System / semantic fonts (allow icon glyphs only if you choose; this gate is strict)
$RG -n '\.font\(\.system\(' $SCOPE && fail ".system() font"
$RG -n '\.font\(\.(headline|subheadline|body|title|title2|title3|largeTitle|caption|caption2|footnote|callout)\b' $SCOPE && fail "semantic system text style"
# system fontWeight stacked on a token font (e.g. ShareImportPreviewSheet:138)
$RG -nU '\.font\(\.Tokens\.[A-Za-z]+\)\s*\n\s*\.fontWeight\(' $SCOPE && fail "system fontWeight on token font (use .Tokens.*Medium)"

# 4. Accent outside the single Dashboard hero score (DashboardView is the only allowed file)
$RG -n 'ColorTokens\.accent' $SCOPE | grep -v 'WorkloadApp/Views/Dashboard/DashboardView.swift' && fail "ColorTokens.accent outside Dashboard hero"

# 5. Hardcoded colors in views
$RG -n 'Color\(red:|Color\(\.sRGB|\.foregroundStyle\(\.(red|green|blue|orange|yellow|purple|pink)\)|\.foregroundColor\(\.(red|green|blue|orange|yellow)\)' $SCOPE && fail "hardcoded / system semantic color"
$RG -n '0x[0-9A-Fa-f]{6}' "$SCOPE/Views" "$SCOPE/Components" && fail "hardcoded hex in Views/Components"

# 6. Surface-ladder: .surface on tappable/grouped cards must be surfaceEl.
#    Heuristic gate — flags hand-rolled card recipe (manual divider stroke) so reviewers re-check.
$RG -nU '\.background\(ColorTokens\.surface\)\s*\n\s*\.overlay\(\s*Rectangle\(\)\.stroke' $SCOPE && fail "hand-rolled card box on .surface (use .cardStyle()/surfaceEl)"

# 7. Off-8pt-grid spacing. Flags common off-grid literals in padding/spacing/frame.
#    Wave 5 (Phase 36) cleared all residual off-grid spacing across Views+Components.
#    Adopted ONE documented sub-grid token: `Spacing.baselinePair` (4pt) — the sanctioned
#    label-value baseline pairing step (MetricTile title→value, stat cells, picker value+chevron,
#    badge insets). Because 4pt is now a named token, `4` is DROPPED from the stack-spacing list
#    (rule 7b) — bare `spacing: 4` literals are still caught only via the padding/frame lists below.
#    Allowed sub-grid exceptions (do NOT flag): hairline/indicator widths&heights 0.5/1/2/3 and
#    divider 0.5 (zone-indicator bars, severity bars `height: 4`, value-unit baseline `spacing: 2`).
$RG -n '\.padding\((\.[a-z]+,\s*)?(2|6|10|12|14|18|20|22|26|28|36|44|52)\)' $SCOPE && fail "off-grid .padding literal"
$RG -n '(VStack|HStack|LazyVGrid|LazyHGrid|Grid)\([^)]*spacing:\s*(6|10|12|14|18|20)\b' $SCOPE && fail "off-grid stack spacing"
$RG -n '\.frame\([^)]*(height|width|minHeight):\s*(10|14|20|28|36|44|180)\b' $SCOPE && fail "off-grid frame dimension"

if [ "$FAIL" -ne 0 ]; then echo "DESIGN.md regression gate FAILED"; exit 1; fi
echo "DESIGN.md regression gate passed"
```

> Tuning notes: rules 6 and 7 are heuristic and may catch intentional sub-grid hairlines (0.5/1/2/3pt rules).
> **Wave 5 status (Phase 36, 2026-06-02):** off-grid sping sweep COMPLETE — rules 7a/7b/7c are CLEAN across
> `WorkloadApp/Views` + `WorkloadApp/Components` (zero residual). A documented 4pt token `Spacing.baselinePair`
> was adopted for the recurring label-value baseline pairing; consequently `4` was dropped from rule 7b. The only
> non-8pt values that intentionally remain are documented sub-grid hairlines/indicators: zone-indicator bar
> `frame(width: 3)` (CoachRosterView), severity bars `frame(height: 4)` (NiggleLogSheet), value-unit baseline
> `HStack(spacing: 2)` kerns, divider strokes `lineWidth: 0.5`, and the plan price `VStack(spacing: 2)`. Rules 1–5
> stay strict (zero tolerance) and remain CLEAN (the only rule-5 hits are `UIColor(red:…)` constants in
> `Services/PDFReportEngine.swift`, a justified PDFKit-rendering exception outside Views/Components scope).

---

## 6. SUGGESTED WAVE PLAN (GSD execution)

Batched by root cause, hero screens first, motion/polish last. Each wave = one GSD phase with a build gate.

**Cautions for every wave (from MEMORY):**
- Run executors **serial**, not parallel — parallel-executor self-branches and corrupts the phase dir.
- The workflow build-gate **invents fake simulator ids** — always pass a known-alive sim id (e.g. an iPhone 17 Pro Max UDID confirmed via `xcrun simctl list devices available`).
- After Swift edits, verify the `.pbxproj` includes any new files and run an incremental build every 3–5 files; discard xcstrings build-churn.
- Watch for stale SourceKit; clean if errors look phantom.

**Wave 0 — Shared primitives + ladder source recipes (highest leverage).**
`MetricTile.swift`, `InsightCard.swift`, `CycleFuelingCard.swift`, `Fatigue/REDS/SpikeAlertBanner.swift`, `SharpTextFieldStyle.swift`, `CardStyle.swift` toggle dims. Route to `.cardStyle()`/`surfaceEl`; fix `SharpTextFieldStyle` 12→16 (app-wide grid win). Build gate. This single wave lifts plane separation everywhere downstream depends on these.

**Wave 1 — Dashboard (hero).** Standardize all 5 cards on `.cardStyle()`; fix WeeklySummaryCard `.system` fonts; PRSDualRunCard border 1→0.5; promote load stats to sectionHead; section-grammar (SectionHeader/SectionContainer); snap off-grid 4/2. Build gate.

**Wave 2 — Workout Log (hero).** SectionContainer + SectionHeader for all sections; 32pt breaks; tappable cards → surfaceEl (PrescribedWorkoutCard, TemplateCarousel, ExerciseEntryCard); SessionRow hierarchy; replace `.system` icons; localize SET/WEIGHT/REPS column headers; snap 12/10. Build gate.

**Wave 3 — Elevation ladder, remaining screens.** Recovery (InsightCard/BehaviorCorrelationRow/sliders), Profile (card each section group), Coach (ClientDetail heads + recoveryHero, Roster listRowBackground→surfaceEl, TemplateList, WorkoutEntry, Prescribe), Auth (form card + CTA dominance), Onboarding tiles, UpgradeSheet (HistoryTeaserBanner + section grammar), Export sheets (RangeChip extraction). Build gate.

**Wave 4 — Corner / font / color hard violations.** `TemplateEditorSheet` `.roundedBorder` → square custom style (CORNER violation); `ShareImportPreviewSheet:138` → `.Tokens.bodyMedium`; remaining `.system(size:)` icon glyphs → tokens; `UpgradeSheet:146` `.red` → `zoneDanger`; `ClientDetailView:138` accent → text1/2. Build gate.

**Wave 5 — Remaining off-grid spacing sweep.** All residual 12/10/6/4/2 padding & spacing → `Spacing.*`; off-grid frames (44→48, 180→176/184, toggle 28/20, grabber 36/4); decide on a documented sub-grid token for true hairlines/indicators. Build gate. Tighten the regression-gate off-grid lists to match.

**Wave 6 — Hierarchy/text-weight polish + motion last.** Per-row emphasis tiers (roster status, export zone labels, detail-view stat numbers, paywall price/SAVE% badge), CTA dominance fine-tuning, then any motion/transition tuning. Final build gate + run the regression-gate script in CI.

**Out of scope / verify-first:** Analytics empty directory — confirm intended path before any work.
