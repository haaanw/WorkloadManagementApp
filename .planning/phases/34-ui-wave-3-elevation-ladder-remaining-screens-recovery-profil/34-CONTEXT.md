# Phase 34: UI Wave 3 — Elevation ladder, remaining screens - Context

**Gathered:** 2026-06-02
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped; spec locked in INVENTORY.md)

<domain>
## Phase Boundary
Apply the surfaceEl elevation ladder + section grammar across ALL remaining screens not covered by Waves 0-2. Per INVENTORY.md §2.A/§3 + §6 Wave 3. This is the broadest wave (worst-scoring screens: Auth 3.5, Coach 3.5, Profile 5.0).

IN SCOPE: Recovery, Profile, Coach, Auth, Onboarding, Subscription (UpgradeSheet), Export screens. Shared primitives + Dashboard + Workout Log already done — do not re-edit them.
OUT OF SCOPE: corner/font/color hard violations (Wave 4/35), pure spacing sweep (Wave 5/36), motion (Wave 6/37). Fix ladder/section-grammar here; leave the §2.D/E/F/G hard violations + residual spacing for their dedicated waves UNLESS trivially adjacent.
</domain>

<decisions>
## Locked (per INVENTORY §3 per-screen)
- Recovery: InsightCard + BehaviorCorrelationRow (both variants) + MorningCheckIn slider rows on `.surface` → surfaceEl/.cardStyle(); RecoveryScoreCard + BEHAVIORS/WELLNESS micro-cap labels → SectionHeader.
- Profile: entire settings list is flat on `.background` → group each section in .cardStyle(); SyncStatusView + TrainingProfileSheet micro-cap headers → SectionHeader; destructive Delete should not read same weight as benign rows (emphasis tier).
- Coach: ClientDetail 6 section heads micro-caps → SectionHeader/SectionContainer; recoveryHero + Roster ClientCard (listRowBackground .surface) + CoachWorkoutEntry form/submit + Prescribe + TemplateList → surfaceEl.
- Auth: Login/SignUp form → .cardStyle(); Sign In CTA must gain dominance (text1 fill / background label, distinct from fields/Google/links); micro-cap field/section labels → SectionHeader; sport chips off .surface flat.
- Onboarding: frequency + experience option tiles fill .background unselected → surfaceEl resting / surface selected; primary CTA differentiated from selected-tile treatment.
- UpgradeSheet: HistoryTeaserBanner (tappable) → .cardStyle(); add SectionHeader/SectionContainer.
- Export sheets (CoachExportSheet/PDFGenerationSheet): chips group → cardStyle container; extract shared RangeChip if cheap.
- DESIGN.md hard rules; accent stays Dashboard-hero-only. Do NOT amend ColorTokens. Do NOT touch algorithm/flags.

## Claude's Discretion
Per-screen section structure + emphasis tiers. RangeChip extraction optional if low-risk. If a screen needs a §2.D/E/F/G hard-violation fix that's trivially in the same edit (e.g. an accent removal at ClientDetailView:138), doing it here is fine — note it; otherwise leave for Wave 4.
</decisions>

<code_context>
## Existing Code Insights
- Spec + file:line targets: INVENTORY.md §2.A (affected files list), §3 (Auth/Coach/Profile/Recovery/Onboarding/UpgradeSheet/Export per-screen), §6 Wave 3.
- Primitives: WorkloadApp/Components/CardStyle.swift. Screens under WorkloadApp/Views/{Recovery,Profile,Coach,Auth,Onboarding,Subscription,Export}/.
- App fully zh-Hans localized — any new visible strings need catalog keys (note INVENTORY flags hardcoded EN micro-caps in InviteConfirmationSheet).
</code_context>

<specifics>
## Specifics
Build gate: xcodebuild sim id iPhone 17 Pro `CAF84E71-BB64-491D-87C8-875A0143B26D` via `-project "workload management/workload management.xcodeproj"`. Incremental build every 3-5 files (this wave touches many files — build often). INVENTORY §5 regression-gate on edited files. SERIAL. SourceKit phantom diagnostics expected — trust xcodebuild. rtk hook mangles multi-file rg — use per-file grep.
</specifics>

<deferred>
## Deferred
§2.D/E/F/G hard violations (roundedBorder fields, bodyMedium CTA, icon glyphs, .red→zoneDanger, accent) = Wave 4 (35) unless trivially adjacent. Residual spacing sweep = Wave 5 (36). Motion = Wave 6 (37).
</deferred>
