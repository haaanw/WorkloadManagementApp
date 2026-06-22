# Phase 40: UX Wave 3 — Dashboard primary-action CTA + value-ranked card stack - Context

**Gathered:** 2026-06-02
**Status:** Ready for planning
**Mode:** Smart discuss (autonomous) — spec V152-UX-SPEC.md §C + 2 user decisions

<domain>
## Phase Boundary
Two UX improvements to the Dashboard/Home tab (DashboardView.swift). UX/flow + ordering only — NO algorithm/flag/engine change (dormant v1.6 PRS card stays flag-gated/EmptyView; do not touch PRSActivation flag). Spec: .planning/v1.5-audit/V152-UX-SPEC.md §C.
- C.1 Surface the primary action under the hero (recommendation-aware CTA below readiness score).
- C.2 Value-rank the card stack for the no-coach user (context-aware demotion).
Scope = DashboardView.swift (body order + new CTA), possibly a small CTA subview, Localizable.xcstrings (en+zh). Last phase of v1.5.2.
</domain>

<decisions>
## Locked decisions

### C.1 Primary-action CTA — RECOMMENDATION-AWARE LABEL (user-chosen)
- Add a visible primary-action CTA element DIRECTLY BELOW the readiness score (within or immediately after HeroReadinessCard, above the rest of the stack). Today "Log Workout" is only a `.primaryAction` toolbar button → setting `showActiveWorkout = true` → `ActiveWorkoutSheet()`. The body CTA triggers the SAME action (present ActiveWorkoutSheet).
- CTA LABEL adapts to the existing `viewModel.recommendation` (AutoregulationEngine.TrainingRecommendation) — e.g. a train-day label ("Start session" / "Log workout") vs a lighter/rest-day variant. Read the EXISTING recommendation only — derive the label from its existing fields (headline / intensity / zone, whatever the type exposes). NO new recommendation logic, NO engine change. If recommendation is nil (cold-start / no data), fall back to a neutral default label ("Log Workout"). The action (open ActiveWorkoutSheet) is always available regardless of label — logging is never blocked.
- STYLE: DESIGN.md reserves accent for the hero score number ONLY. The CTA must NOT use accent. Use a filled text1 / divider treatment (same grammar as Phase 38's dominant "Finish workout" button: text1 fill + bg-color label, or equivalent dominant non-accent style). 0pt corners, no shadow, Font.Tokens, 8pt grid.
- Keep the toolbar "Log Workout" button OR remove it if the body CTA fully replaces it — planner discretion, but do not break existing entry points (WelcomeActionCard's own Log button stays).

### C.2 Value-rank card stack — CONTEXT-AWARE DEMOTE (user-chosen)
- Target ordering for the ESTABLISHED no-coach user (viewModel.hasRealData == true): readiness (hero) → primary CTA → recommendation → today's load context (TrainingLoadSection ACWR/ATL/CTL/TSB) + FatigueAttentionBanner near top → core metrics (MetricsStrip) → WeeklySummary → RecentSessions. DEMOTE below the fold: WelcomeActionCard, TrainingProfileCard, cycle prompt, CycleStatusStrip, NotificationPrePermissionCard (setup/prompt/empty cards).
- CONTEXT-AWARE: when the user has NO real data yet (hasRealData == false / cold-start), the relevant setup/connect prompt (HealthKit EmptyStateCard / HealthKitNoDataCard, TrainingProfileCard, WelcomeActionCard) must STAY PROMINENT — do not bury the connect/setup affordance the new user actually needs. Only demote these once the user is established. Implement via the existing render guards (hasRealData, connectionState, trainingProfiles.isEmpty, recentSessions/checkins empty) to decide placement.
- Recommendation: currently the rec headline lives inside HeroReadinessCard footer. Keeping it there (right under the score, above/with the CTA) satisfies "recommendation up top" — do not necessarily build a separate rec card. Planner discretion on whether rec stays in hero footer or becomes its own element, as long as it reads right under readiness.
- Niggle log button stays at the bottom (on-demand affordance, no nag).
- PRSDualRunCard: leave flag-gated exactly as-is (dormant). Do not reorder it into prominence or touch its flag.
</decisions>

<canonical_refs>
## Canonical References (read before implementing)
- `.planning/v1.5-audit/V152-UX-SPEC.md` §C — authoritative spec
- `DESIGN.md` — 0pt corners (Rectangle), no .shadow, Font.Tokens (no .system), 8pt grid (Spacing.*), **accent = hero readiness score ONLY** (CTA must not use accent), dark+light
- `WorkloadApp/Views/Dashboard/DashboardView.swift` — main scroll VStack (~51-229) current order; HeroReadinessCard (295-406, score line ~317 accent, recommendation footer ~355-359); toolbar Log Workout (~238-246); sheets (~247-258); TrainingLoadSection (531-588); EmptyStateCard (410-434), HealthKitNoDataCard (438-449)
- `WorkloadApp/ViewModels/DashboardViewModel.swift` — exposes recoveryScore, recoveryZone, recommendation (AutoregulationEngine.TrainingRecommendation?), acwr/atl/ctl/tsb, fatigueIndex/fatigueZone, hasRealData, weeklySummary
- `WorkloadApp/Services/AutoregulationEngine.swift` — TrainingRecommendation type (read its fields to derive CTA label; DO NOT modify)
- `WorkloadApp/Components/CardStyle.swift` — Spacing, .cardStyle, SectionContainer, SectionHeader
- `WorkloadApp/Components/WelcomeActionCard.swift` (its own Log button), `WorkloadApp/App/AppRouter.swift` MainTabView (tabs; tab.log = WorkoutLogView)
- `WorkloadApp/Resources/Localizable.xcstrings` — en + zh-Hans; tab.* / dashboard.* prefixes
- Phase 38 SetEntry finish-bar (ActiveWorkoutSheet) — reference for dominant non-accent text1-fill CTA style
</canonical_refs>

<code_context>
## Existing Code Insights
- Current top-to-bottom: HeroReadinessCard → PRSDualRunCard(flag/EmptyView) → WelcomeActionCard(cond) → TrainingProfileCard(cond) → HealthKit empty/no-data(cond) → cycle prompt(cond) → CycleStatusStrip(cond) → MetricsStrip → WeeklySummary+NotifCard(cond) → first-week/cold-start fallback → FatigueAttentionBanner(cond) → TrainingLoadSection → RecentSessionsSection → Niggle button.
- recommendation already surfaced as `viewModel.recommendation.headline` in hero footer (line ~356). CTA can sit just below.
- Log Workout action = `showActiveWorkout = true` → `.sheet` ActiveWorkoutSheet() (line ~248). Reuse this for the body CTA.
- hasRealData gate (VM ~134-143) is the key signal for context-aware demotion. connectionState (.notRequested/.requestedNoData/.connected) drives which empty-state shows.
- AutoregulationEngine.TrainingRecommendation: inspect actual fields (headline, and any intensity/zone/training-vs-rest signal) to map → CTA label. Do not invent new fields.
</code_context>

<specifics>
## Specifics
- Build gate: xcodebuild -project "workload management/workload management.xcodeproj", sim iPhone 17 Pro id CAF84E71-BB64-491D-87C8-875A0143B26D. Incremental build every 3-5 files. SERIAL. Trust xcodebuild over SourceKit phantom diagnostics. rtk mangles multi-file rg — per-file grep.
- Regression gate INVENTORY §5 rules 1-7 clean on edited files: no accent (CRITICAL — CTA must not use accent), 0pt corners, no shadow, 8pt grid, Font.Tokens.
- All new visible strings localized en + zh-Hans.
- DashboardView is large — reordering risk. Verify each conditional card's render guard is preserved after reorder; do not drop any card or its condition.
</specifics>

<deferred>
## Deferred
- Consolidating conditional cards into fewer; literal one-line "today" summary (out of scope per spec).
- Fusing recovery scores / any algorithm change (v1.6, dormant).
- PRS dual-run card promotion (flag-gated dormant).
</deferred>
