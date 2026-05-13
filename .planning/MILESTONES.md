# Milestones

## v1.3 LLM Import, Sharing & Polish (Shipped: 2026-05-13)

**Phases completed:** 4 phases, 10 plans, 14 tasks

**Key accomplishments:**

- Per-entity sync isolation with structured do/catch, Bool return signals, and SyncTimestampStore for independent timestamp tracking per entity type
- TemplateSharingService with 8-char share codes, Supabase shared_templates table with RLS/pg_cron, and Associated Domains for tuwa.app universal links
- ShareCodeSheet with 8-char code display, clipboard copy, and ShareLink universal link sharing wired through template context menu
- 1. [Rule 3 - Blocking] Added Identifiable conformance to SharedTemplateResponse

---

## v1.2 Training Onboarding & Templates (Shipped: 2026-05-10)

**Phases completed:** 4 phases, 11 plans, 15 tasks

**Key accomplishments:**

- 1. [Rule 3 - Blocking] Copied gitignored config files for build verification
- Commit:
- Commit:
- Commit:

---

## v1.0 Post-Launch (Shipped: 2026-04-22)

**Phases completed:** 4 phases, 14 plans
**Timeline:** 2026-03-24 → 2026-04-22 (29 days)
**Codebase:** ~15,700 LOC Swift

**Key accomplishments:**

- App Store launch readiness — screenshots, legal pages, privacy manifest, bundle ID hardening
- Multi-week trend charts (CTL/ATL/TSB), weekly training summaries, recovery-load correlation view
- CSV export with HealthKit-compliant composite-only data
- Training intelligence — periodization detection, fatigue pattern analysis, behavior tagging with recovery correlation
- Post-signup onboarding flow capturing training frequency and experience level
- Dashboard welcome card guiding new users to first workout or wellness check-in

**Known gaps at close:**

- REQUIREMENTS.md traceability table was not auto-updated during execution (all 22 requirements implemented but checkboxes left unchecked)
- D-15 (HealthKit re-prompt on Recovery tab if skipped during onboarding) not implemented — existing EmptyStateCard covers general case

---

## v1.1 App Store Launch (Shipped: 2026-04-30)

**Phases completed:** 4 phases (5-8), 9+ plans
**Timeline:** 2026-04-22 → 2026-04-30
**Codebase:** ~17,000+ LOC Swift

**Key accomplishments:**

- Streak tracking (consecutive week counting) on dashboard
- Weekly local push notifications with training summary
- PDF report export (athlete + coach) with subscription gating
- App Store metadata (title, subtitle, keywords, description, screenshots)
- Social authentication (Apple Sign-In + Google Sign-In)
- Evidence-based fatigue tracking system (FatigueIndexEngine, 6-component model replacing ACWR as primary risk signal)
- App Store submission (v1.0 build submitted 2026-04-30)

**Known gaps at close:**

- App Store submission pending review / rejected — fix being addressed in parallel session
- v1.1 traceability checkboxes not updated during execution

---
