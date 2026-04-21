# Multi-Coach Access & Session Attribution Design

**Date:** 2026-03-25
**Project:** WorkloadApp (iOS, SwiftUI + SwiftData)
**Scope:** Multiple coaches per athlete, session type categorisation, soft attribution, workout_sessions sync

---

## Overview

An athlete may have multiple coaches simultaneously — for example a basketball team coach, a skill coach, and a strength & conditioning coach. All accepted coaches share full read access to the athlete's training history regardless of who supervised which session. Sessions carry a structured type label (strength, skill, cardio, match, recovery) that both coaches and the athlete can use to filter history. A soft attribution field records which coach (if any) logged each session.

**Builds on:** Phase 3a (coach_athlete_relationships, RLS policies, InviteService). No changes to relationship or invite flows.

**In scope:**
- `SessionType` enum with five cases
- `sessionType` and `loggedByCoachId` fields on `WorkoutSession`
- Supabase `workout_sessions` table sync (header only — no exercises or sets)
- RLS policies on `workout_sessions` for athlete owner access and coach read/insert
- Session type picker in `ActiveWorkoutSheet` (athlete) and `CoachWorkoutEntrySheet` (coach)
- Session type filter bar in `WorkoutLogView` (athlete) and `ClientDetailView` (coach)
- Soft attribution label in `ClientDetailView` session rows

**Out of scope:**
- Syncing `exercise_entries` or `set_records` (deferred to a later phase)
- Coach-to-coach visibility controls (all accepted coaches see everything)
- Push notifications when a coach logs a session

---

## Architecture

Three layers of change:

1. **Model layer** — `SessionType` enum + two new fields on `WorkoutSession`
2. **Sync layer** — `WorkoutSessionRow` Codable struct + four new `SyncService` methods
3. **UI layer** — session type picker in log entry sheets; filter bar in history views; attribution label in coach view

The `coach_athlete_relationships` schema and `is_coach_for()` RLS helper from Phase 3a are reused without modification.

---

## Data Model

### New enum: `SessionType`

Added to `WorkloadApp/Models/Enums.swift`:

```swift
enum SessionType: String, Codable, CaseIterable, Identifiable {
    case strength
    case skill
    case cardio
    case match
    case recovery

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .strength: "Strength"
        case .skill:    "Skill"
        case .cardio:   "Cardio"
        case .match:    "Match"
        case .recovery: "Recovery"
        }
    }
}
```

### `WorkoutSession` model additions

File: `WorkloadApp/Models/WorkoutSession.swift`

```swift
var sessionType: SessionType = .strength
var loggedByCoachId: UUID?          // nil = athlete logged it themselves
```

Both fields added to the SwiftData `@Model`. `loggedByCoachId` is optional; `nil` means the athlete self-logged. The field is set once at creation and never updated.

---

## Supabase Schema

### Manual steps (Supabase Dashboard → SQL Editor)

**Step 1 — Add columns to `workout_sessions`:**
```sql
ALTER TABLE workout_sessions
  ADD COLUMN IF NOT EXISTS session_type text NOT NULL DEFAULT 'strength',
  ADD COLUMN IF NOT EXISTS logged_by_coach_id uuid REFERENCES athletes(id);
```

**Step 2 — Enable RLS on `workout_sessions`:**
```sql
ALTER TABLE workout_sessions ENABLE ROW LEVEL SECURITY;
```

**Step 3 — Add athlete owner policies** (athlete can read/write their own sessions — required for self-sync):
```sql
CREATE POLICY "athlete_read_own_workout_sessions"
ON workout_sessions FOR SELECT
USING (athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid()));

CREATE POLICY "athlete_insert_own_workout_sessions"
ON workout_sessions FOR INSERT
WITH CHECK (athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid()));

CREATE POLICY "athlete_update_own_workout_sessions"
ON workout_sessions FOR UPDATE
USING (athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid()))
WITH CHECK (athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid()));
```

**Step 4 — Add coach read policy:**
```sql
CREATE POLICY "coach_read_workout_sessions"
ON workout_sessions FOR SELECT
USING (is_coach_for(athlete_id));
```

**Step 5 — Add coach insert policy (logging on behalf of athlete):**
```sql
CREATE POLICY "coach_insert_workout_sessions"
ON workout_sessions FOR INSERT
WITH CHECK (is_coach_for(athlete_id));
```

All policies are additive. Supabase combines multiple SELECT policies with OR.

---

## Sync Layer

### `WorkoutSessionRow` Codable struct

Added to `SyncService.swift` alongside the other Row types. Carries header fields only — no exercises or sets. Maps model properties 1:1 without conversion:

```swift
struct WorkoutSessionRow: Codable {
    let id: UUID
    let athleteId: UUID
    let date: Date
    let sessionName: String?
    let sportType: String?
    let durationSeconds: Int?       // matches WorkoutSession.durationSeconds directly
    let sessionRpe: Double?
    let sessionType: String
    let loggedByCoachId: UUID?
    let notes: String?
    let updatedAt: Date

    init(from model: WorkoutSession, athleteId: UUID) { ... }
}
```

Snake_case ↔ camelCase mapping is handled by the `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase` configured on the `SupabaseClient` in `AppContainer.init()` — consistent with all other Row types. No custom `CodingKeys` needed.

`pushCoachWorkoutSession` signature: `func pushCoachWorkoutSession(_ session: WorkoutSession, for athleteId: UUID) async` — same pattern as the existing `pushCoachWorkloadSnapshot` and `pushCoachRecoverySnapshot` methods in `SyncService`.

### New `SyncService` methods

| Method | Visibility | Called from |
|---|---|---|
| `pushWorkoutSessions(context:, athleteId:)` | internal | `pushAll` |
| `pullWorkoutSessions(context:, athlete:)` | private | `pullAll` |
| `pushCoachWorkoutSession(_:, for:)` | internal | `CoachWorkoutEntrySheet` |
| `pullAthleteSnapshots` (existing) | internal | gains `pullWorkoutSessions` call |

**Pull upsert logic:** last-write-wins on `updatedAt`, same pattern as all other pull methods. Each upserted session sets `session.athlete = athlete` (consistent with all existing pull methods). Sessions logged by other coaches arrive as local `WorkoutSession` records with their `loggedByCoachId` set — they are inserted but never overwrite a locally-owned session if local `updatedAt` is newer.

---

## UI Changes

### `ActiveWorkoutSheet` — athlete self-logging

A `SessionType` picker (segmented or inline list) is added before the sRPE slider. Defaults to `.strength`. `loggedByCoachId` is always set to `nil` when saving from this sheet.

### `CoachWorkoutEntrySheet` — coach logging on behalf of athlete

Same `SessionType` picker added. When saving, `loggedByCoachId` is set to the coach's own `Athlete.id`. The session is saved to SwiftData and immediately pushed via `pushCoachWorkoutSession`.

### `WorkoutLogView` — athlete history filter

A horizontal filter bar with 6 tappable chips appears above the session list:

```
All  |  Strength  |  Skill  |  Cardio  |  Match  |  Recovery
```

State: `@State private var selectedType: SessionType? = nil` (`nil` = show all).

Filtering is done in-memory on the `@Query` result (no predicate rewrite needed — the full session list is already fetched). Selected chip uses `ColorTokens.text1` for both text and the left border rectangle (1pt wide, full chip height) — this is design-system safe. `ColorTokens.accent` is not used (reserved for hero readiness number only); zone colors are not used (semantically bound to ACWR/recovery state). Unselected chips use `ColorTokens.text2` text with no border.

### `ClientDetailView` — coach view of athlete sessions

Same filter bar in the sessions section. Each session row includes a small attribution label below the session date/type:

- `loggedByCoachId == nil` → label: `"Self"`
- `loggedByCoachId == viewing coach's ID` → label: `"You"`
- `loggedByCoachId == another coach's ID` → label: that coach's `displayName` looked up from local SwiftData (pulled via `pullLinkedAthletes`); falls back to `"Unknown Coach"` if not found — no crash

Attribution is display-only — it does not affect visibility or access.

---

## Error Handling

- If `pushCoachWorkoutSession` fails (network error), the session is already saved locally in SwiftData and will be pushed on the next `pushAll` (foreground sync). No special retry logic needed.
- If a coach pulls sessions and a `loggedByCoachId` references an athlete not in local SwiftData (e.g., a coach who was later removed), attribution falls back to `"Unknown Coach"` — no crash.

---

## Testing

**Unit tests:**
- `SessionType` raw values and `displayName` strings
- `WorkoutSessionRow` init from model correctly maps `sessionType`, `loggedByCoachId`, `durationSeconds`, `sessionName`, `sportType`

**Manual tests:**
- Athlete self-logs a strength session → appears in WorkoutLogView with Strength chip active; `loggedByCoachId` is nil
- S&C coach logs a strength session for athlete → appears in athlete's WorkoutLogView; `"S&C Coach Name"` attribution shown in ClientDetailView
- Skill coach logs a skill session → appears with `"Skill Coach Name"` attribution
- Filter bar set to Skill → only skill sessions shown (athlete and coach side)
- Filter bar set to All → all sessions shown
- Attribution label shows `"You"` when the viewing coach was the one who logged it
- Attribution label shows `"Unknown Coach"` when `loggedByCoachId` is set but coach not in local SwiftData
