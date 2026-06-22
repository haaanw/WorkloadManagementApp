---
title: Coach re-enters as plan author + data reviewer
trigger_condition: User engages a real skill or S&C coach (founder's stated future), OR coach-side demand appears from plan-aware positioning
planted_date: 2026-06-12
---

# Coach as Plan Author

v1.5 self-coached reset stripped coach roster/invite/prescribe UI (models kept — no migration needed). When coaching relationships return, do NOT rebuild roster-management. New shape, aligned with plan-aware core:

- **Coach = plan author.** Coach's program (spreadsheet/PDF/text) ingested via plan-ingestion pipeline (PLAN-01); Tuwa modulates within it exactly as with self-authored plans.
- **Coach = data reviewer.** Coach sees adherence (planned vs executed), readiness trends, modulation history (what Tuwa adjusted and why, what athlete accepted/declined).
- Athlete stays owner of data + subscription; coach view is a lens, not a tier (re-evaluate two-tier model only if real demand).
- Tuwa's verdicts become a shared language between athlete and coach — "Tuwa flagged amber Thursday, I cut the back-offs" — replacing the wellness-questionnaire emails pro teams use.

Existing assets: CoachAthleteRelationship model, InviteService, TemplateSharingService, PrescribedWorkout model — all dormant but compilable.
