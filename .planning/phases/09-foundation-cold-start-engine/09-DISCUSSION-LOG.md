# Phase 9: Foundation & Cold-Start Engine - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md -- this log preserves the alternatives considered.

**Date:** 2026-05-01
**Phase:** 09-foundation-cold-start-engine
**Areas discussed:** Template ownership model, Cold-start seeding logic, TrainingProfile field design, Migration & RLS strategy

---

## Template Ownership Model

### Q1: How should athlete ownership work on WorkoutTemplate?

| Option | Description | Selected |
|--------|-------------|----------|
| isAthleteOwned flag | Add isAthleteOwned: Bool + athleteId: UUID? to existing model. coachId stays for coach templates. | ✓ |
| Unified ownerId field | Replace coachId with generic ownerId + ownerType enum. Breaking change, requires migration. | |
| Reuse coachId for both | Set coachId = athleteId when athlete creates. Semantically confusing. | |

**User's choice:** isAthleteOwned flag (Recommended)
**Notes:** Additive only, no breaking changes to existing coach template system.

### Q2: Save-as-template from coach-prescribed session -- preserve coach origin?

| Option | Description | Selected |
|--------|-------------|----------|
| Always athlete-owned | Save-as-template always sets isAthleteOwned=true regardless of session origin. | ✓ |
| Preserve coach origin | Keep coachId link for attribution. | |

**User's choice:** Always athlete-owned (Recommended)
**Notes:** Athlete owns their template library completely.

### Q3: scheduledDays data type

| Option | Description | Selected |
|--------|-------------|----------|
| Int array [1-7] | ISO 8601 weekdays. Simple, compact, easy to query. | ✓ |
| You decide | Claude picks best representation. | |

**User's choice:** Int array [1-7] (Recommended)

---

## Cold-Start Seeding Logic

### Q1: How should ColdStartEngine generate the synthetic EWMA seed?

| Option | Description | Selected |
|--------|-------------|----------|
| Steady-state shortcut | Compute representative daily TSS, calculate convergence values. No synthetic history. | ✓ |
| Synthetic history generation | Generate N days of fake loads, run through EWMA chain. More complex. | |
| You decide | Claude picks. | |

**User's choice:** Steady-state shortcut (Recommended)
**Notes:** Fast, deterministic, matches EWMA math exactly.

### Q2: Factor in weeksAtLevel for CTL discount?

| Option | Description | Selected |
|--------|-------------|----------|
| Discount factor | ramp = max(0.3, min(1.0, weeks/6.0)) applied to CTL only. | ✓ |
| Ignore weeks field | Use only for bias comparison. Simpler but may overestimate. | |
| You decide | Claude picks. | |

**User's choice:** Discount factor (Recommended)
**Notes:** Athletes who recently changed programs get lower CTL seed. ATL unchanged.

---

## TrainingProfile Field Design

### Q1: Bias fields for 8-week perceptual comparison

| Option | Description | Selected |
|--------|-------------|----------|
| Estimated vs actual ATL/CTL snapshot | Store 4 values + capturedAt date. Bias ratio computed. | ✓ |
| Full trajectory comparison | Store weekly snapshots for 8 weeks. Richer but heavier. | |
| You decide | Claude picks minimal viable. | |

**User's choice:** Estimated vs actual ATL/CTL snapshot (Recommended)

### Q2: Injury history structure on TrainingProfile

| Option | Description | Selected |
|--------|-------------|----------|
| JSON-encoded array | Codable [InjuryEntry] with bodyRegion enum + notes + isActive. | ✓ |
| Simple free-text field | Just String?. No structure. | |
| You decide | Claude picks. | |

**User's choice:** JSON-encoded array (Recommended)
**Notes:** BodyRegion enum: shoulder, knee, back, hip, ankle, wrist, elbow, neck.

---

## Migration & RLS Strategy

### Q1: Athlete RLS on workout_templates -- read scope

| Option | Description | Selected |
|--------|-------------|----------|
| Read own + coach-assigned | SELECT allows own + linked coach templates. Mutations restricted to own. | ✓ |
| Read own only | Athletes only see isAthleteOwned=true + athleteId=me. | |
| You decide | Claude picks. | |

**User's choice:** Read own + coach-assigned (Recommended)

### Q2: Migration file approach

| Option | Description | Selected |
|--------|-------------|----------|
| Single migration file | One SQL file covering ALTER TABLE + CREATE TABLE + RLS. | ✓ |
| Split migrations | Separate files per concern. | |

**User's choice:** Single migration file (Recommended)

---

## Claude's Discretion

- TemplateRepository method signatures and internal implementation
- Exact Supabase column types and constraints
- ColdStartEngine struct organization
- SwiftData schema registration order

## Deferred Ideas

None -- discussion stayed within phase scope
