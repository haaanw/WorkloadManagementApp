# Phase 4: Onboarding & Polish - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-22
**Phase:** 04-onboarding-polish
**Areas discussed:** Onboarding flow structure, First-action guidance, Training profile fields, HealthKit permission timing

---

## Onboarding Flow Structure

| Option | Description | Selected |
|--------|-------------|----------|
| Post-signup screens | Multi-step OnboardingView after account creation, before Dashboard. Sport type stays in SignUpView. | ✓ |
| Extend SignUpView | Add frequency and experience fields directly to SignUpView. Fewer screens but long form. | |
| Dashboard first-launch overlay | Go to Dashboard first, show modal sheet on first visit. | |

**User's choice:** Post-signup screens
**Notes:** Clean separation — signup = account creation, onboarding = profile setup.

| Option | Description | Selected |
|--------|-------------|----------|
| All required | Training frequency and experience required. HealthKit has "Skip for now". | ✓ |
| All skippable | Every step has skip button. | |
| You decide | Claude picks. | |

**User's choice:** All required

| Option | Description | Selected |
|--------|-------------|----------|
| Paged with dots | Horizontal page-style with dot indicators, Continue button, no back button. | ✓ |
| Stacked with back | NavigationStack with push transitions and back button. | |
| You decide | Claude picks. | |

**User's choice:** Paged with dots

| Option | Description | Selected |
|--------|-------------|----------|
| Show onboarding again | If profile fields missing, show onboarding. Data syncs to Supabase. | ✓ |
| Skip, use defaults | Use sensible defaults if fields empty. | |
| You decide | Claude picks. | |

**User's choice:** Show onboarding again

---

## First-Action Guidance

| Option | Description | Selected |
|--------|-------------|----------|
| Action card on Dashboard | Prominent card at top with two CTAs: Log workout / Wellness check-in. | ✓ |
| Full-screen choice | Dedicated full-screen view after onboarding. | |
| Tab highlight hints | Badge dots on tabs + small banner. | |

**User's choice:** Action card on Dashboard

| Option | Description | Selected |
|--------|-------------|----------|
| After first action | Card disappears after first workout OR check-in. Persistent until then. | ✓ |
| Manual dismiss | X button to dismiss without completing action. | |
| After both actions | Stays until both workout AND check-in completed. | |

**User's choice:** After first action

---

## Training Profile Fields

| Option | Description | Selected |
|--------|-------------|----------|
| Range buckets | 4 chips: 1–2, 3–4, 5–6, 7+ days/week. | ✓ |
| Exact number picker | Stepper or wheel for 1-7+. | |
| You decide | Claude picks. | |

**User's choice:** Range buckets

| Option | Description | Selected |
|--------|-------------|----------|
| 3 tiers | Beginner / Intermediate / Advanced with subtitles. | ✓ |
| 4 tiers | Adds Elite tier. | |
| Years of experience | Numeric input. | |

**User's choice:** 3 tiers

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, in Profile | Add to Profile tab settings alongside sport type. | ✓ |
| Set once, locked | Onboarding sets permanently. | |

**User's choice:** Yes, in Profile

---

## HealthKit Permission Timing

| Option | Description | Selected |
|--------|-------------|----------|
| Onboarding step 3 | Final step with explanation of why HRV/RHR/sleep matter. "Skip for now" available. | ✓ |
| Keep on Recovery tab | Don't change current behavior. Prompted on first Recovery tab visit. | |
| Both (onboarding + fallback) | Ask in onboarding, re-prompt on Recovery tab if skipped. | |

**User's choice:** Onboarding step 3

| Option | Description | Selected |
|--------|-------------|----------|
| On Recovery tab visit | If skipped in onboarding, show inline prompt on first Recovery tab visit. | ✓ |
| No re-prompt | Respect skip, user finds it in Profile. | |
| You decide | Claude picks. | |

**User's choice:** On Recovery tab visit

---

## Claude's Discretion

- Welcome card copy and visual styling
- Onboarding step header/body copy
- HealthKit explanation copy refinement
- Enum raw values and Supabase column naming
- Profile settings section layout
- HealthKit "Skip for now" button style

## Deferred Ideas

None — discussion stayed within phase scope.
