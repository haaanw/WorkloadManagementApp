# Phase 39: UX Wave 2 — Recovery quick mode + two-score clarity - Context

**Gathered:** 2026-06-02
**Status:** Ready for planning
**Mode:** Smart discuss (autonomous) — spec V152-UX-SPEC.md §B + 2 user decisions

<domain>
## Phase Boundary
Two UX improvements on the Recovery tab + morning check-in. UX/flow + labeling only — NO algorithm/flag/engine change (dormant v1.6 PRS stays dormant; do NOT fuse scores in code). Spec: .planning/v1.5-audit/V152-UX-SPEC.md §B.
- B.1 Quick mode for returning users.
- B.2 Clarify the two 0-100 scores (NO fusion — labeling/UX only).
Scope = MorningCheckInSheet.swift (pre-fill) + RecoveryView.swift (score labels/clarity) + Localizable.xcstrings (en+zh). Full 5-section form stays available.
</domain>

<decisions>
## Locked decisions

### B.1 Quick mode — PRE-FILL EXISTING SHEET (user-chosen)
- When a prior WellnessCheckIn exists, seed MorningCheckInSheet's @State (sleepQuality, soreness, energy, stress, selectedTags) from the MOST RECENT prior check-in so returning users edit only deltas, then save. Notes intentionally NOT carried (day-specific). 
- Use RecoveryRepository to fetch the latest prior check-in (e.g. fetchLatestWellnessCheckIn or fetchRecoveryHistory) — NOT today's (today's is the "edit today" case; if today's exists already that's the existing edit path). If today's check-in already exists, seed from it (editing today); else seed from most recent prior.
- Show a subtle hint when pre-filled (e.g. "Prefilled from your last check-in — edit what changed"), in text3/label tier, dismissible-by-editing (no modal). Localized en+zh.
- Full form unchanged — no separate quick screen. Lowest-risk reuse of the existing sheet.
- First-ever check-in (no prior): defaults stay at 3 (current behavior), no hint.

### B.2 Two-score clarity — HONEST BLEND FRAMING (user-chosen)
- IMPORTANT REALITY: the top "Recovery Score" (RecoverySnapshot/RecoveryScoreEngine) is ALREADY a composite that blends HRV/RHR/sleep (75%) AND the subjective wellness check-in (25%). The "wellness check-in" score (WellnessCheckIn.wellnessScore) is the how-you-feel part ALONE. They are NOT independent — copy must be honest about this.
- Add a clear label/subtitle to the Recovery Score card explaining it blends wearable signals + how-you-feel. Example copy (final wording at planner discretion, must be honest + localized): "Blends your wearable signals (HRV, resting HR, sleep) with how you feel."
- Surface today's subjective wellness check-in score ON the Recovery tab as a distinct, clearly-labeled element (today it only appears in the form preview + history). Label it as the "how you feel" score, visually distinct from the composite Recovery Score (different label tier / placement — NOT a second zone-badge hero; avoid two competing 0-100 heroes).
- Add a short "why these differ" note: recovery = wearable + how-you-feel combined; wellness check-in = the how-you-feel part on its own. Concise, localized, low-emphasis (info line, not a hero).
- NO code fusion, NO engine change, NO new score computation. Wellness already feeds recovery in the engine — do not duplicate that logic in the view.
</decisions>

<canonical_refs>
## Canonical References (read before implementing)
- `.planning/v1.5-audit/V152-UX-SPEC.md` §B — authoritative spec for this phase
- `DESIGN.md` — 0pt corners (Rectangle, no RoundedRectangle/.cornerRadius), no .shadow, Font.Tokens (no .system), 8pt grid (Spacing.*), accent Dashboard-hero-ONLY (none here), dark+light
- `WorkloadApp/Views/Recovery/RecoveryView.swift` — RecoveryScoreCard (~294-385), WellnessHistorySection (~407-442), MorningCheckInPrompt (~267-290)
- `WorkloadApp/Views/Recovery/MorningCheckInSheet.swift` — 5 WellnessSlider sections, behaviors, notes, score preview, save() (~194-223)
- `WorkloadApp/Repositories/RecoveryRepository.swift` — fetchTodayWellnessCheckIn (146-161), fetchRecoveryHistory (92-108), fetchLatestSnapshot (130-144); add a "latest prior wellness check-in" fetch if none exists (read-only query, no schema change)
- `WorkloadApp/Models/WellnessCheckIn.swift` — model + wellnessScore computed
- `WorkloadApp/Services/RecoveryScoreEngine.swift` — confirms 25% wellness weight (DO NOT modify)
- `WorkloadApp/Components/CardStyle.swift` — .cardStyle, SectionContainer, SectionHeader, Spacing, RowSeparator
- `WorkloadApp/Resources/Localizable.xcstrings` — en + zh-Hans; recovery.* / morning.* prefixes
</canonical_refs>

<code_context>
## Existing Code Insights
- Two scores live in different places today: composite Recovery Score = RecoveryScoreCard (top of Recovery tab, has ZoneBadge). Subjective wellness score = only in MorningCheckInSheet preview (line ~145) + WellnessHistorySection list (relative-date rows). Today's wellness score is NOT surfaced as a labeled element on the Recovery tab.
- WellnessCheckIn fields: sleepQuality/soreness/energy/stress (Int 1-5), notes, behaviorTags. wellnessScore = sum/20*100.
- RecoveryScoreEngine pulls today's WellnessCheckIn.wellnessScore at 25% — this is the existing partial coupling. Honest copy must reflect it.
- MorningCheckInSheet uses @State with default 3 for each slider; behaviors as Set<String>. Pre-fill = set these from a fetched prior check-in in .onAppear / init.
</code_context>

<specifics>
## Specifics
- Build gate: xcodebuild -project "workload management/workload management.xcodeproj", sim iPhone 17 Pro id CAF84E71-BB64-491D-87C8-875A0143B26D. Incremental build every 3-5 files. SERIAL. Trust xcodebuild over SourceKit phantom diagnostics. rtk mangles multi-file rg — per-file grep.
- Regression gate INVENTORY §5 rules 1-7 clean on edited files: no accent, 0pt corners, no shadow, 8pt grid, Font.Tokens.
- All new visible strings localized en + zh-Hans.
</specifics>

<deferred>
## Deferred
- Daily prompt/notification, slider-count reduction (out of scope per spec).
- Fusing the two scores in code = v1.6 PRS, dormant.
- Cross-session carry-forward of workout set values = Phase 38 deferred item, not this phase.
- Dashboard = Phase 40.
</deferred>
