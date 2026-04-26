# Phase 7: App Store Metadata - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-26
**Phase:** 07-app-store-metadata
**Areas discussed:** App Store copy, Keyword strategy, Screenshot content, Categories & rating, Login methods

---

## App Store Copy

| Option | Description | Selected |
|--------|-------------|----------|
| Data-driven athlete | Technical, performance-focused. "Track ACWR, recovery scores, periodization." | ✓ |
| Approachable wellness | Friendly, accessible. "Train smarter, recover better." | |
| Coach-forward | Lead with coach-athlete features. | |

**User's choice:** Data-driven athlete
**Notes:** User wants technical credibility for serious athletes.

### Metric Specificity

| Option | Description | Selected |
|--------|-------------|----------|
| Name the metrics | Mention ACWR/HRV/EWMA directly | |
| Benefits only | No jargon, outcome-focused | |
| Mix — benefits first, metrics in detail | Lead with outcomes, metrics lower down | |

**User's choice:** "your choice" — Claude's discretion
**Notes:** Recommended mix approach.

---

## Keyword Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Workload management | "training load", "ACWR", "overtraining prevention" | ✓ |
| Recovery tracking | "recovery score", "HRV tracking", "readiness" | |
| Workout tracker+ | "workout tracker", "strength training" | |

**User's choice:** Workload management
**Notes:** Niche but high-intent audience.

### Competitor Names

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — include them | Captures comparison shoppers | |
| No — own terms only | Avoids keyword dilution | |

**User's choice:** "your choice" — Claude's discretion

---

## Screenshot Content

| Option | Description | Selected |
|--------|-------------|----------|
| 6 screens (Recommended) | Dashboard, Workload, Recovery, Workout log, Coach roster, PDF export | ✓ |
| 4 screens (minimal) | Core athlete flow only | |
| 8+ screens (full coverage) | All features including onboarding, profile | |

**User's choice:** 6 screens

### Caption Style

| Option | Description | Selected |
|--------|-------------|----------|
| Benefit-oriented | Outcome focused, what user gains | ✓ |
| Feature labels | Descriptive, tells what screen shows | |
| Mixed | Benefit headline + feature subtitle | |

**User's choice:** Benefit-oriented

---

## Categories & Rating

| Option | Description | Selected |
|--------|-------------|----------|
| Health & Fitness | Largest relevant audience, HealthKit natural fit | ✓ |
| Sports | More niche, less competition | |

**User's choice:** Health & Fitness

---

## Login Methods

| Option | Description | Selected |
|--------|-------------|----------|
| Apple Sign-In | Required by App Review. Supabase has built-in provider. | ✓ |
| Google Sign-In | Popular option, Supabase supports it. | ✓ |
| Email stays as-is | Keep existing email/password. | ✓ |

**User's choice:** All three — Apple + Google + email
**Notes:** Social logins supplement existing email auth, don't replace it.

---

## Claude's Discretion

- Metric specificity in App Store description (mix approach recommended)
- Competitor name targeting in keywords
- Secondary App Store category
- Screenshot caption exact wording
- Social login button ordering/styling

## Deferred Ideas

None
