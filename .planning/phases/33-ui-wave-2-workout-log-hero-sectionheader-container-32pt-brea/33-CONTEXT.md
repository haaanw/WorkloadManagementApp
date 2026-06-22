# Phase 33: UI Wave 2 — Workout Log (hero screen) - Context

**Gathered:** 2026-06-02
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped; spec locked in INVENTORY.md)

<domain>
## Phase Boundary
Fix the Workout Log hero screen (primary input loop) per INVENTORY.md §3 "Workout Log" (4.5/10) + §6 Wave 2. Section grammar, plane separation on tappable cards, row hierarchy, icon tokens, column-header localization, spacing.

IN SCOPE: WorkloadApp/Views/WorkoutLog/* call sites. Shared primitives already fixed (Phase 31) — consume them.
OUT OF SCOPE: other screens (Wave 3 / phase 34), motion (Wave 6).
</domain>

<decisions>
## Locked
- Apply SectionContainer + SectionHeader to Prescribed / My Templates / Watch sections; add 32pt section breaks (whole tab is currently one VStack(spacing:0) divided by hairlines).
- Tappable cards → surfaceEl / .cardStyle(): PrescribedWorkoutCard, TemplateCarouselSection (the primary "start a workout" entry), ActiveWorkoutSheet ExerciseEntryCard.
- Fix flat SessionRow hierarchy (one emphasis tier per row).
- Replace `.system(size:)` icon glyphs with Font.Tokens / imageScale.
- Localize hardcoded EN column headers SET/WEIGHT/REPS/RPE (use existing i18n catalog — match the zh-Hans-complete localization pattern; add keys if missing).
- Snap off-grid 12/10 spacing → Spacing.*.
- DESIGN.md hard rules; no accent (accent is Dashboard-hero-only). Do NOT amend ColorTokens. Do NOT touch algorithm/flags.

## Claude's Discretion
Section structure + which emphasis tier per SessionRow element, guided by INVENTORY §3 Workout Log.
</decisions>

<code_context>
## Existing Code Insights
- Spec + targets: INVENTORY.md §3 Workout Log + §2.B + §6 Wave 2. Named files: WorkoutLogView.swift:108-115, TemplateCarouselSection.swift:100-107/247, PrescribedWorkoutCard.swift:90, ActiveWorkoutSheet.swift:803/990, SessionDetailView.swift.
- Primitives in WorkloadApp/Components/CardStyle.swift (SectionHeader/SectionContainer/.cardStyle()/Spacing).
- i18n: app is fully zh-Hans localized (catalog ~774 keys). Column headers must use Localized string keys, not literals.
</code_context>

<specifics>
## Specifics
Build gate: xcodebuild sim id iPhone 17 Pro `CAF84E71-BB64-491D-87C8-875A0143B26D`. Incremental build every 3-5 files. INVENTORY §5 regression-gate on edited files. SERIAL. SourceKit phantom diagnostics expected — trust xcodebuild. If new i18n keys added, discard xcstrings build-churn noise.
</specifics>

<deferred>
## Deferred
Remaining screens = Wave 3 (34). Corner/font/color hard violations incl. any leftover icon glyphs = Wave 4 (35). Motion = Wave 6 (37).
</deferred>
