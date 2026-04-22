# Phase 5: Streaks & Notifications - Context

**Gathered:** 2026-04-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Athletes can track training consistency via weekly workout streaks and receive weekly local push notification summaries that reinforce engagement. Covers streak calculation, dashboard display, notification scheduling, pre-permission UX, and notification settings.

</domain>

<decisions>
## Implementation Decisions

### Streak Display & Placement
- **D-01:** Streak count appears as a row inside the existing WeeklySummaryCard — no standalone badge or new component
- **D-02:** When streak is 0 (no sessions this week or brand new user), hide the streak row entirely — don't show "0 weeks" or a CTA
- **D-03:** Streak unit is weeks (consecutive weeks with 1+ logged session) — already decided at milestone level to avoid punishing rest days

### Notification Content & Timing
- **D-04:** Default notification day/time is Sunday 7 PM — end-of-week reflection before new week starts
- **D-05:** User can change day and time in Profile settings (NOTF-03)

### Claude's Discretion
- **D-06:** Notification content density — Claude decides what data to include in the weekly notification body. AnalyticsEngine.WeeklySummary already provides sessions, PRs, and deltas; use what fits naturally in a notification without being noisy.
- **D-07:** Pre-permission screen design — Claude decides format (full-screen sheet vs inline card) based on existing patterns in the codebase and DESIGN.md constraints. Must appear on first dashboard visit (not after first workout, not during onboarding).
- **D-08:** Notification settings section placement in ProfileView — Claude decides whether to create a new NOTIFICATIONS section or add within existing PREFERENCES section, based on section density and design guidelines.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Design System
- `DESIGN.md` — All visual decisions (0pt corners, no shadows, DM Sans, 8pt grid, accent rules)

### Requirements
- `.planning/REQUIREMENTS.md` — STRK-01, STRK-02, NOTF-01, NOTF-02, NOTF-03 acceptance criteria

### Existing Components
- `WorkloadApp/Views/Dashboard/WeeklySummaryCard.swift` — Integration point for streak display (D-01)
- `WorkloadApp/Services/AnalyticsEngine.swift` — WeeklySummary struct to reuse for notification content (D-06)
- `WorkloadApp/Views/Profile/ProfileView.swift` — Integration point for notification settings (D-08)
- `WorkloadApp/Views/Dashboard/DashboardView.swift` — Pre-permission screen trigger point (D-07)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **AnalyticsEngine.WeeklySummary**: Already computes sessions count, PRs, and week-over-week deltas — notification content can source from this
- **WeeklySummaryCard**: Existing dashboard card where streak row will be added
- **WorkoutRepository.fetchSessions(from:to:)**: Can power streak calculation by querying sessions per week
- **WelcomeActionCard**: Pattern for conditional dashboard cards — reference for pre-permission card if that approach is chosen
- **MetricTile, DeltaIndicator**: Reusable component patterns if streak needs visual treatment

### Established Patterns
- Pure struct engines with static methods for business logic — streak calculation should follow this pattern (e.g., `StreakEngine.computeStreak()`)
- `@Observable` ViewModels orchestrate pipeline calls — DashboardViewModel.load() will need to include streak computation
- ProfileView uses section-based layout with `sectionHeader()`, `divider()`, `editablePicker()` helpers
- UNCalendarNotificationTrigger for local scheduling — already decided at milestone level, no APNs needed

### Integration Points
- DashboardViewModel.load() — add streak calculation call
- WeeklySummaryCard body — add conditional streak row
- ProfileView body — add notification settings section
- DashboardView — add pre-permission screen trigger (show once on first visit)
- AppContainer or similar — notification scheduling service initialization

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 05-streaks-notifications*
*Context gathered: 2026-04-22*
