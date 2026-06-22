---
phase: 34
plan: 34
subsystem: ui-design-system
title: UI Wave 3 — Elevation ladder, remaining screens
tags: [design-system, elevation-ladder, section-grammar, cta-dominance, i18n]
wave: 3
depends_on: [31, 32, 33]
provides:
  - surfaceEl elevation ladder applied to Recovery/Profile/Coach/Auth/Onboarding/UpgradeSheet/Export
  - section-grammar (SectionHeader) on those screens' true section heads
  - CTA dominance (text1 fill / background label) on Auth/Onboarding/Coach primary actions
  - shared RangeChip primitive for export sheets
key-files:
  created: []
  modified:
    - WorkloadApp/Views/Recovery/BehaviorCorrelationRow.swift
    - WorkloadApp/Views/Recovery/MorningCheckInSheet.swift
    - WorkloadApp/Views/Recovery/RecoveryView.swift
    - WorkloadApp/Views/Auth/LoginView.swift
    - WorkloadApp/Views/Auth/SignUpView.swift
    - WorkloadApp/Views/Onboarding/OnboardingView.swift
    - WorkloadApp/Views/Subscription/UpgradeSheet.swift
    - WorkloadApp/Views/Coach/ClientDetailView.swift
    - WorkloadApp/Views/Coach/CoachRosterView.swift
    - WorkloadApp/Views/Coach/TemplateListView.swift
    - WorkloadApp/Views/Coach/CoachWorkoutEntrySheet.swift
    - WorkloadApp/Views/Coach/PrescribeWorkoutSheet.swift
    - WorkloadApp/Views/Profile/ProfileView.swift
    - WorkloadApp/Views/Profile/SyncStatusView.swift
    - WorkloadApp/Views/Profile/TrainingProfileSheet.swift
    - WorkloadApp/Views/Export/CoachExportSheet.swift
    - WorkloadApp/Views/Export/PDFGenerationSheet.swift
    - WorkloadApp/Resources/Localizable.xcstrings
metrics:
  files-modified: 18
  build: green
  completed: 2026-06-02
---

# Phase 34 Plan 34: UI Wave 3 (Elevation ladder, remaining screens) Summary

Applied the `surfaceEl` elevation ladder, two-tier section grammar (19pt `SectionHeader`
vs row hairline), and primary-CTA dominance across the seven remaining screen clusters
(Recovery, Auth, Onboarding, UpgradeSheet, Coach, Profile, Export) — lifting grouped/tappable
surfaces off the page plane and promoting buried section heads and primary actions, the
top-2 readability root causes per the v1.5 audit.

## What changed, by screen

**Recovery** — BehaviorCorrelationRow (both sufficient/insufficient variants) and the
MorningCheckIn WellnessSlider rows moved `.surface`→`surfaceEl`; the BEHAVIORS, WELLNESS SCORE,
and RECOVERY SCORE 12pt micro-cap labels promoted to 19pt `sectionHead`. InsightCard already
used `.cardStyle()` — left as-is (already correct).

**Auth** — Login & SignUp field groups lifted to `surfaceEl`; the Sign In / Create Account CTA
now reads as the dominant plane (`text1` fill + `background` label, `bodyMedium`) when enabled,
falling back to `surface`/`text3` when disabled; field/section micro-caps → `sectionHead`; SignUp
sport chips lifted to `surfaceEl` resting / `surface` selected. SocialLoginButtons left unchanged
(the Google button intentionally stays `surface` as subordinate to the dominant CTA).

**Onboarding** — frequency & experience option tiles lifted to `surfaceEl` resting (`surface`
selected); the Continue button and the HealthKit Connect/Continue CTAs promoted to the dominant
`text1` fill / `background` label treatment, distinct from the selected-tile surface treatment.

**UpgradeSheet** — HistoryTeaserBanner (tappable) converted from a hand-rolled `.surface` box to
`.cardStyle()`; added a "Choose your plan" `SectionHeader` above the plan toggle with new
catalog keys (en "Choose your plan" / zh-Hans "选择方案").

**Coach** — ClientDetail's 6 section heads promoted to `sectionHead`; recoveryHero `.surface`→
`surfaceEl`; the accent on the coach's client recovery score removed → `text1` (the trivially-
adjacent Wave-4 violation, fixed here per CONTEXT discretion); Log/Prescribe actions lifted to
`surfaceEl` + `bodyMedium`. Roster ClientCard `listRowBackground` → `surfaceEl`. TemplateList rows
+ New Template button → `surfaceEl`. CoachWorkoutEntry field rows → `surfaceEl`, labels →
`sectionHead`, submit CTA → dominant `text1` fill. Prescribe field labels → `sectionHead`, template
selector → `surfaceEl`.

**Profile** — settings rows lifted onto the `surfaceEl` plane via the row helpers
(profileRow / editableTextField / editablePicker / actionButton) plus the inline cycle, notification,
and coach toggle rows and the Language / HealthKit / Sync nav rows and LinkedParty rows; row
paddings on lifted rows snapped 12→16. In Account, Sign Out is demoted to neutral `text1` and Delete
keeps `zoneDanger` + `bodyMedium` so the destructive action is a distinct emphasis tier rather than
equal weight. Invite sub-sheet field groups → `surfaceEl`. SyncStatusView micro-cap header →
`SectionHeader` and its entity rows carded on `surfaceEl` + hairline border. TrainingProfileSheet
REQUIRED/OPTIONAL micro-cap headers → `SectionHeader`; picker/movement/injury rows → `surfaceEl`.

**Export** — extracted a shared `RangeChip` (selectable: `surfaceEl` resting / `surface` selected,
0.5pt hairline, `label` type, 48pt min height) used by both CoachExportSheet and PDFGenerationSheet;
their date-range chip rows are now grouped in a `.cardStyle()` container. This unifies the previously
divergent chip typography (`.micro` caps vs `.label`) and snaps PDFGen's off-grid 44 minHeight to 48.
Placed `RangeChip` in CoachExportSheet.swift (same module) to avoid a new pbxproj file entry.

## Build status
**GREEN.** Every screen group was built incrementally against the known-alive sim
(`CAF84E71-BB64-491D-87C8-875A0143B26D`); all 7 builds reported `** BUILD SUCCEEDED **`.

## Regression result (INVENTORY §5, rules 1–5 on edited files)
No NEW forbidden patterns introduced. The 7 pre-existing hits found are all explicitly
Wave-4-deferred items, untouched by this wave:
- `SignUpView:98` `.system(size:20)` sport icon — Wave 4 glyph.
- `UpgradeSheet:151` `.foregroundStyle(.red)` — Wave 4 §2.E (line shifted from 146 by the added SectionHeader).
- `PrescribeWorkoutSheet:95` `.textFieldStyle(.roundedBorder)` — Wave 4 §2.G corner violation.
- `TrainingProfileSheet:258/305/341/373` `.system(size:10/14)` chevron/checkmark glyphs — Wave 4 §2.D.

## Deviations from Plan
- **[Rule 2 — missing critical functionality] i18n key added.** UpgradeSheet's new plan
  SectionHeader required a visible string; added `upgrade.section.choosePlan` (en + zh-Hans) to
  the catalog to keep the app fully localized. Expected xcstrings build-churn was absent; real
  change kept.
- **Accent removal at ClientDetailView done here** (not deferred to Wave 4) — it was trivially
  adjacent to the recoveryHero micro-cap→sectionHead edit, per CONTEXT discretion.
- **Profile "group each section in cardStyle"** was implemented by lifting the row helpers and
  inline rows onto the `surfaceEl` plane rather than wrapping each section in a discrete
  `SectionContainer{ ... }.cardStyle()` block. Rationale: the 1184-line ProfileView emits sections
  as a flat row run interleaved with `divider()`/`sectionDivider()`; restructuring into per-section
  card containers is a high-risk structural rewrite. Lifting the rows to `surfaceEl` (with the
  existing SectionHeader breaks + row hairlines, both already correct) delivers the same plane
  separation against the page canvas with far lower regression risk. Full per-section card wrapping
  can be revisited in a polish pass if the audit re-flags it.

## What was deferred to Wave 4 / 5
- Wave 4 (35): `.roundedBorder` field fix (Prescribe :95, TemplateEditor), `.system(size:)` icon
  glyphs (SignUp sport icon, TrainingProfileSheet chevrons/checkmarks), `.red`→zoneDanger
  (UpgradeSheet :151), `.Tokens.bodyMedium` CTA (ShareImportPreviewSheet).
- Wave 5 (36): residual off-grid spacing sweep (remaining 12/10/6/4/2 literals, sub-grid tokens).
- Wave 6 (37): motion.

## Already-correct / skipped (honest notes)
- InsightCard already routed through `.cardStyle()` — untouched.
- SocialLoginButtons Google button left on `surface` by design (subordinate to dominant CTA).
- Profile's `sectionHeader` helper already used the 19pt `SectionHeader` primitive — unchanged.
- TrainingProfileSheet `sectionHeader` now wraps the already-localized String via
  `LocalizedStringKey`; displays verbatim (REQUIRED/OPTIONAL) — correct, no key lookup needed.

## Commits
- 68a90a7 feat(34): Recovery elevation ladder + section grammar
- 739d147 feat(34): Auth form elevation + CTA dominance + section grammar
- ac275ea feat(34): Onboarding tile elevation + CTA dominance
- 1de2975 feat(34): UpgradeSheet HistoryTeaserBanner cardStyle + plan section header (+ i18n)
- c6c7ee3 feat(34): Coach elevation ladder + section grammar + CTA dominance
- aeb5ee3 feat(34): Profile elevation ladder + section grammar + destructive tier
- 938723f feat(34): Export sheets shared RangeChip + cardStyle grouping
