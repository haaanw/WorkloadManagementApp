---
phase: 34
title: UI Wave 3 — Elevation ladder, remaining screens
type: enforce-pass
autonomous: true
wave: 3
depends_on: [31, 32, 33]
requirements: []
---

# Phase 34 Plan — UI Wave 3 (Elevation ladder, remaining screens)

## Objective
Apply the `surfaceEl` elevation ladder + two-tier section grammar (SectionHeader / row
hairline) + CTA dominance across every screen not covered by Waves 0–2: Recovery, Profile,
Coach, Auth, Onboarding, Subscription (UpgradeSheet), Export. Consume the fixed primitives
from Phases 31–33; do not re-edit them or Dashboard / Workout Log.

Authoritative work list: `.planning/v1.5-audit/INVENTORY.md` §2.A, §3, §6 Wave 3.

## Hard rules (enforced)
- 0pt corners, no shadows, no `.system` text fonts, no hardcoded colors.
- No accent anywhere (Dashboard-hero-only).
- `Font.Tokens.*` only, 8pt grid.
- Do NOT amend ColorTokens. Do NOT touch algorithm / dormant flags.

## Tasks (executed serially, build gate every screen group)

1. **Recovery** — BehaviorCorrelationRow (both variants) + MorningCheckIn slider rows
   `.surface`→`surfaceEl`; RecoveryScoreCard + BEHAVIORS / WELLNESS micro-cap labels →
   sectionHead. (InsightCard already `.cardStyle()` — no change.)
2. **Auth** — Login / SignUp field groups `.surface`→`surfaceEl`; Sign In / Create Account
   CTA → dominant text1 fill + background label (bodyMedium); field/section micro-caps →
   sectionHead; SignUp sport chips unselected `.background`→`surfaceEl`.
3. **Onboarding** — frequency + experience tiles unselected `.background`→`surfaceEl`
   (selected `.surface`); primary CTAs → dominant text1 fill / background label.
4. **UpgradeSheet** — HistoryTeaserBanner (tappable) → `.cardStyle()`; add SectionHeader
   above the plan toggle (new i18n key en + zh-Hans).
5. **Coach** — ClientDetail 6 section heads → sectionHead; recoveryHero `.surface`→`surfaceEl`;
   remove accent on client score (trivially-adjacent Wave-4 fix) → text1; Roster ClientCard
   listRowBackground → surfaceEl; TemplateList rows + New Template → surfaceEl; CoachWorkoutEntry
   field rows → surfaceEl + labels sectionHead + submit CTA dominant; Prescribe labels sectionHead
   + template selector → surfaceEl.
6. **Profile** — lift settings rows onto `surfaceEl` plane (row helpers + inline toggle / nav
   rows); destructive Delete gets a distinct emphasis tier (Sign Out demoted to neutral, Delete
   kept zoneDanger + bodyMedium); invite sub-sheet field groups → surfaceEl; SyncStatusView +
   TrainingProfileSheet micro-cap headers → SectionHeader.
7. **Export** — extract shared `RangeChip` (selectable surfaceEl/surface), group date-range chips
   in `.cardStyle()` for both CoachExportSheet & PDFGenerationSheet; snap PDFGen chip 44→48.

## Deferred (NOT in this wave)
- Wave 4 (35): `.roundedBorder` field fix (Prescribe / TemplateEditor), `.system(size:)` icon
  glyph swaps (SignUp sport icon, TrainingProfileSheet chevrons/checkmarks), `.red`→zoneDanger
  (UpgradeSheet), bodyMedium CTA (ShareImportPreviewSheet).
- Wave 5 (36): residual off-grid spacing sweep.
- Wave 6 (37): motion.

## Build gate
`xcodebuild -project "workload management/workload management.xcodeproj" -scheme "workload management"
-destination 'platform=iOS Simulator,id=CAF84E71-BB64-491D-87C8-875A0143B26D' build`
Must report BUILD SUCCEEDED. Trust xcodebuild over SourceKit phantom diagnostics.
