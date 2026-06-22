# v1.5.2 — UX Flow Rework SPEC

Defined 2026-06-02 via /grill-me, grounded in a code flow-map of the 4 core journeys. Scope = behavior/flow, NOT visual styling (v1.5.1 already enforced the visual system). UX-only — must NOT touch algorithm code or feature flags (dormant v1.6 stays dormant, flags FALSE).

Target user: serious amateur / part-time athletes, no pro coaching.

## In scope (3 journeys; onboarding deliberately excluded — it's already clean)

### A. Workout log set-entry (HIGHEST priority — daily input loop, ~15 taps/set today)
1. **Carry-forward defaults** — a new set row pre-fills with the previous set's weight/reps (within the session). Tap a number → keypad for a big change.
2. **Steppers** — ± controls on weight/reps for quick nudges without the keypad. Grid-valid increments (discretion: e.g. weight ±2.5/5, reps ±1).
3. **One-tap "repeat last set"** — clones the previous set entirely; user edits only deltas.
4. **RPE optional/collapsible per-set** — default fast row = weight+reps only; per-set RPE hidden behind a tap. Keep the existing per-session RPE at finish (the per-set field is currently redundant with it).
5. **De-modal interrupts** — PR-celebration + spike-alert are currently full-screen blockers before the sheet can close; make them inline/dismissible so the save flow isn't interrupted. (Session commit already happens before these — keep that.)

### B. Recovery check-in
1. **Quick mode for returning users** — pre-fill yesterday's answers / one-screen fast path; edit only what changed. Full 5-section form stays available.
2. **Clarify the two scores (do NOT fuse)** — the HealthKit recovery score (HRV/RHR/sleep) and the subjective wellness check-in score are both 0-100 and look alike. Make them visually distinct + clearly labeled (what each means) + a short "why these differ" note. FUSION IS EXPLICITLY OUT — that is v1.6 PRS algorithm territory (dormant); duplicating it here would collide. UX/labeling only.

### C. Dashboard info order
1. **Surface the primary action under the hero** — the recommendation / "Log Workout" CTA becomes a visible element right below the readiness score, not just a toolbar button.
2. **Value-rank the card stack** — order by what the no-coach user needs first: readiness → recommendation → today's load context up top; demote setup prompts, empty-states, HealthKit/cycle/training-profile cards below the fold.

## Out of scope (considered, rejected during grilling)
- Onboarding changes (clean).
- Recovery: daily prompt/notification; slider-count reduction.
- Dashboard: consolidating conditional cards into fewer; literal one-line "today" summary.
- Fusing the two recovery scores (= algorithm, v1.6).
- Cross-session carry-forward of set values (history-driven) — within-session only for v1.5.2; cross-session is a later/Pro enhancement.

## Constraints
- DESIGN.md hard rules intact (0pt corners, no shadows, Font.Tokens, 8pt grid, accent Dashboard-hero-only). Do NOT amend ColorTokens. Reuse v1.5.1 primitives (.cardStyle/SectionHeader/SectionContainer/Spacing/steppers if a token exists).
- UX-only: no algorithm/flag/engine changes. Keep dormant v1.6 dormant.
- Any new visible strings localized (en + zh-Hans catalog).
- Build-gate: sim iPhone 17 Pro CAF84E71-BB64-491D-87C8-875A0143B26D, serial executors, incremental builds.

## Proposed phases (38-40, one per journey)
- **Phase 38 — Workout log fast entry**: A.1-A.5 (carry-forward + steppers + repeat-last + optional RPE + de-modal). Highest priority.
- **Phase 39 — Recovery quick mode + score clarity**: B.1-B.2.
- **Phase 40 — Dashboard primary-action + value-rank**: C.1-C.2.

Note: these are INTERACTION changes (more design judgment than v1.5.1's mechanical enforcement) — may warrant a throwaway sketch or interaction review before mass implementation, esp. Phase 38 (stepper/quick-entry layout).
