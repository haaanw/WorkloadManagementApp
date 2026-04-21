# Multi-Coach Session Attribution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `SessionType` categorisation and soft coach attribution to `WorkoutSession`, sync session headers to Supabase so all accepted coaches see an athlete's full history, and expose a filter bar in `WorkoutLogView` (athlete) and `ClientDetailView` (coach).

**Architecture:** Three-layer change: (1) `SessionType` enum + two new fields on `WorkoutSession`; (2) `WorkoutSessionRow` Codable struct + four new `SyncService` methods that sync session headers (no exercises/sets); (3) session type picker added to `ActiveWorkoutSheet` and the `SessionTypeFilterBar` component added to `WorkoutLogView`. Coach-side additions (`CoachWorkoutEntrySheet` picker, `ClientDetailView` filter + attribution) are marked as Tasks 6–7 and should be applied when Phase 3b views are implemented.

**Tech Stack:** SwiftUI, SwiftData, Supabase Swift SDK, XCTest

---

## File Map

| File | Change |
|---|---|
| `WorkloadApp/Models/Enums.swift` | Add `SessionType` enum |
| `WorkloadApp/Models/WorkoutSession.swift` | Add `sessionType: SessionType` and `loggedByCoachId: UUID?` |
| `WorkloadApp/Services/SyncService.swift` | Add `WorkoutSessionRow` struct + 4 methods; update `pushAll` / `pullAll`; update `pullAthleteSnapshots` |
| `WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift` | Add `@State var sessionType` + `SessionType` picker; pass to `saveSession()` |
| `WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift` | Add `SessionTypeFilterBar` component + filter state; filter session list in-memory |
| `WorkloadApp/Views/Coach/CoachWorkoutEntrySheet.swift` | *(Phase 3b)* Add `sessionType` picker; set `loggedByCoachId` on save |
| `WorkloadApp/Views/Coach/ClientDetailView.swift` | *(Phase 3b)* Add `SessionTypeFilterBar` + attribution label to session rows |
| `WorkloadAppTests/SessionTypeTests.swift` | **Create** — enum + Row mapping tests |

---

## Task 1: Supabase Schema (Manual)

**Files:** None — Supabase Dashboard → SQL Editor only.

- [ ] **Step 1: Add columns to `workout_sessions`**

```sql
ALTER TABLE workout_sessions
  ADD COLUMN IF NOT EXISTS session_type text NOT NULL DEFAULT 'strength',
  ADD COLUMN IF NOT EXISTS logged_by_coach_id uuid REFERENCES athletes(id);
```

- [ ] **Step 2: Enable RLS**

```sql
ALTER TABLE workout_sessions ENABLE ROW LEVEL SECURITY;
```

- [ ] **Step 3: Add athlete owner policies**

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

- [ ] **Step 4: Add coach read + insert policies**

```sql
CREATE POLICY "coach_read_workout_sessions"
ON workout_sessions FOR SELECT
USING (is_coach_for(athlete_id));

CREATE POLICY "coach_insert_workout_sessions"
ON workout_sessions FOR INSERT
WITH CHECK (is_coach_for(athlete_id));
```

`is_coach_for()` was created in Phase 3a. These policies are additive alongside the athlete owner policies above.

- [ ] **Step 5: Verify in Supabase Table Editor**

Confirm `workout_sessions` shows both new columns and the shield icon (RLS enabled).

---

## Task 2: `SessionType` Enum + `WorkoutSession` Model

**Files:**
- Modify: `WorkloadApp/Models/Enums.swift`
- Modify: `WorkloadApp/Models/WorkoutSession.swift`
- Create: `WorkloadAppTests/SessionTypeTests.swift`

- [ ] **Step 1: Write failing tests**

Create `WorkloadAppTests/SessionTypeTests.swift`:

```swift
import XCTest
@testable import WorkloadApp

final class SessionTypeTests: XCTestCase {

    func test_sessionType_rawValues() {
        XCTAssertEqual(SessionType.strength.rawValue, "strength")
        XCTAssertEqual(SessionType.skill.rawValue,    "skill")
        XCTAssertEqual(SessionType.cardio.rawValue,   "cardio")
        XCTAssertEqual(SessionType.match.rawValue,    "match")
        XCTAssertEqual(SessionType.recovery.rawValue, "recovery")
    }

    func test_sessionType_displayNames() {
        XCTAssertEqual(SessionType.strength.displayName, "Strength")
        XCTAssertEqual(SessionType.skill.displayName,    "Skill")
        XCTAssertEqual(SessionType.cardio.displayName,   "Cardio")
        XCTAssertEqual(SessionType.match.displayName,    "Match")
        XCTAssertEqual(SessionType.recovery.displayName, "Recovery")
    }

    func test_sessionType_allCases_count() {
        XCTAssertEqual(SessionType.allCases.count, 5)
    }

    func test_workoutSession_defaultSessionType_isStrength() {
        let session = WorkoutSession()
        XCTAssertEqual(session.sessionType, .strength)
    }

    func test_workoutSession_defaultLoggedByCoachId_isNil() {
        let session = WorkoutSession()
        XCTAssertNil(session.loggedByCoachId)
    }
}
```

Run ⌘U in Xcode. Expected: compile error — `SessionType` does not exist yet.

- [ ] **Step 2: Add `SessionType` to `Enums.swift`**

In `WorkloadApp/Models/Enums.swift`, add at the bottom under `// MARK: - Coach / Role Enums`:

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

- [ ] **Step 3: Add fields to `WorkoutSession`**

In `WorkloadApp/Models/WorkoutSession.swift`, add after `var notes: String?`:

```swift
var sessionType: SessionType = .strength
var loggedByCoachId: UUID?          // nil = athlete self-logged
```

No changes to `init` required — both fields have defaults (`.strength` and `nil`).

- [ ] **Step 4: Run tests (⌘U)**

Expected: all `SessionTypeTests` pass.

- [ ] **Step 5: Build (⌘B)**

Expected: clean build. SwiftData will pick up the new fields via automatic migration (new fields with defaults don't require a migration plan).

- [ ] **Step 6: Commit**

```bash
git add WorkloadApp/Models/Enums.swift \
        WorkloadApp/Models/WorkoutSession.swift \
        WorkloadAppTests/SessionTypeTests.swift
git commit -m "feat: add SessionType enum and sessionType/loggedByCoachId to WorkoutSession"
```

---

## Task 3: `WorkoutSessionRow` + `SyncService` Methods

**Files:**
- Modify: `WorkloadApp/Services/SyncService.swift`
- Modify: `WorkloadAppTests/SessionTypeTests.swift` (add Row mapping tests)

- [ ] **Step 1: Write failing Row mapping tests**

Add to `WorkloadAppTests/SessionTypeTests.swift`:

```swift
final class WorkoutSessionRowTests: XCTestCase {

    func test_row_mapsSessionType() {
        let session = WorkoutSession(sessionDate: .now, durationSeconds: 3600)
        session.sessionType = .skill
        let row = WorkoutSessionRow(from: session, athleteId: UUID())
        XCTAssertEqual(row.sessionType, "skill")
    }

    func test_row_mapsLoggedByCoachId_whenNil() {
        let session = WorkoutSession()
        let row = WorkoutSessionRow(from: session, athleteId: UUID())
        XCTAssertNil(row.loggedByCoachId)
    }

    func test_row_mapsLoggedByCoachId_whenSet() {
        let coachId = UUID()
        let session = WorkoutSession()
        session.loggedByCoachId = coachId
        let row = WorkoutSessionRow(from: session, athleteId: UUID())
        XCTAssertEqual(row.loggedByCoachId, coachId)
    }

    func test_row_mapsDurationSeconds_directly() {
        let session = WorkoutSession(durationSeconds: 5400)
        let row = WorkoutSessionRow(from: session, athleteId: UUID())
        XCTAssertEqual(row.durationSeconds, 5400)
    }
}
```

Run ⌘U. Expected: compile error — `WorkoutSessionRow` does not exist yet.

- [ ] **Step 2: Add `WorkoutSessionRow` to `SyncService.swift`**

In `WorkloadApp/Services/SyncService.swift`, add after `PersonalRecordRow` and before the `// MARK: - Coach Rows` block:

```swift
struct WorkoutSessionRow: Codable {
    let id: UUID
    let athleteId: UUID
    let date: Date
    let sessionName: String?
    let sportType: String?
    let durationSeconds: Int?
    let sessionRpe: Double?
    let sessionType: String
    let loggedByCoachId: UUID?
    let notes: String?
    let updatedAt: Date

    init(from model: WorkoutSession, athleteId: UUID) {
        self.id = model.id
        self.athleteId = athleteId
        self.date = model.sessionDate
        self.sessionName = model.sessionName
        self.sportType = model.sportType.rawValue
        self.durationSeconds = model.durationSeconds
        self.sessionRpe = model.sessionRPE
        self.sessionType = model.sessionType.rawValue
        self.loggedByCoachId = model.loggedByCoachId
        self.notes = model.notes
        self.updatedAt = model.updatedAt
    }
}
```

Note: `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase` is already configured on the `SupabaseClient` in `AppContainer.init()`. No custom `CodingKeys` needed — Swift property names map automatically (e.g. `sessionRpe` ↔ `session_rpe`).

- [ ] **Step 3: Run Row mapping tests (⌘U)**

Expected: all `WorkoutSessionRowTests` pass.

- [ ] **Step 4: Add `pushWorkoutSessions` to `SyncService`**

Inside the `SyncService` struct, after `pushRecoveryAndWellness`, add:

```swift
func pushWorkoutSessions(context: ModelContext, athleteId: UUID) async {
    guard let sessions = try? context.fetch(FetchDescriptor<WorkoutSession>()) else { return }
    let rows = sessions.map { WorkoutSessionRow(from: $0, athleteId: athleteId) }
    _ = try? await client.from("workout_sessions").upsert(rows).execute()
}
```

- [ ] **Step 5: Add `pullWorkoutSessions` to `SyncService`**

Inside the `SyncService` struct, in the `// MARK: - Pull helpers` section:

```swift
private func pullWorkoutSessions(context: ModelContext, athlete: Athlete) async {
    guard let rows: [WorkoutSessionRow] = try? await client
        .from("workout_sessions")
        .select()
        .eq("athlete_id", value: athlete.id)
        .execute()
        .value
    else { return }

    for row in rows {
        let pred = #Predicate<WorkoutSession> { $0.id == row.id }
        let existing = try? context.fetch(FetchDescriptor(predicate: pred)).first
        if let existing, existing.updatedAt > row.updatedAt { continue }
        let session = existing ?? WorkoutSession(
            id: row.id,
            sessionDate: row.date,
            sessionName: row.sessionName,
            sportType: SportType(rawValue: row.sportType ?? "") ?? .custom,
            durationSeconds: row.durationSeconds ?? 0,
            sessionRPE: row.sessionRpe,
            notes: row.notes
        )
        session.sessionType = SessionType(rawValue: row.sessionType) ?? .strength
        session.loggedByCoachId = row.loggedByCoachId
        session.updatedAt = row.updatedAt
        session.athlete = athlete
        if existing == nil { context.insert(session) }
    }
    try? context.save()
}
```

- [ ] **Step 6: Add `pushCoachWorkoutSession` to `SyncService`**

In the `// MARK: - Coach push methods` section (already exists from Phase 3a):

```swift
func pushCoachWorkoutSession(_ session: WorkoutSession, for athleteId: UUID) async {
    let row = WorkoutSessionRow(from: session, athleteId: athleteId)
    _ = try? await client.from("workout_sessions").upsert(row).execute()
}
```

- [ ] **Step 7: Wire into `pushAll`, `pullAll`, and `pullAthleteSnapshots`**

In `pushAll`, after `pushPersonalRecords(...)`:
```swift
await pushWorkoutSessions(context: context, athleteId: athlete.id)
```

In `pullAll`, after `pullPersonalRecords(...)`:
```swift
await pullWorkoutSessions(context: context, athlete: athlete)
```

In `pullAthleteSnapshots`, after the existing pull calls:
```swift
await pullWorkoutSessions(context: context, athlete: linkedAthlete)
```

- [ ] **Step 8: Build (⌘B)**

Expected: clean build.

- [ ] **Step 9: Commit**

```bash
git add WorkloadApp/Services/SyncService.swift \
        WorkloadAppTests/SessionTypeTests.swift
git commit -m "feat: add WorkoutSessionRow and SyncService workout_sessions sync"
```

---

## Task 4: `ActiveWorkoutSheet` — Session Type Picker

**Files:**
- Modify: `WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift`

The current sheet has a `SportType` picker. Add a `SessionType` picker directly below it. `loggedByCoachId` is always `nil` from this sheet (athlete self-logging).

- [ ] **Step 1: Add `sessionType` state variable**

In `ActiveWorkoutSheet`, add after `@State private var sportType: SportType = .lifting`:

```swift
@State private var sessionType: SessionType = .strength
```

- [ ] **Step 2: Add session type picker to the body**

In the `// Session info` VStack, after the `SportType` picker block, add:

```swift
Picker("Session Type", selection: $sessionType) {
    ForEach(SessionType.allCases) { type in
        Text(type.displayName).tag(type)
    }
}
.pickerStyle(.segmented)
```

- [ ] **Step 3: Pass `sessionType` in `saveSession()`**

In `saveSession()`, update the `WorkoutSession` initialiser to include the new field:

```swift
let session = WorkoutSession(
    sessionDate: startTime,
    sessionName: sessionName.isEmpty ? nil : sessionName,
    sportType: sportType,
    durationSeconds: Int(elapsed),
    sessionRPE: sessionRPE
)
session.sessionType = sessionType
// loggedByCoachId remains nil (athlete self-log)
```

- [ ] **Step 4: Build (⌘B)**

Expected: clean build.

- [ ] **Step 5: Manual smoke test**

In Simulator: open Workout Log → tap `+` → confirm the session type picker appears between the sport type picker and the timer. Select "Skill" → finish session → confirm session appears in log.

- [ ] **Step 6: Commit**

```bash
git add WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift
git commit -m "feat: add session type picker to ActiveWorkoutSheet"
```

---

## Task 5: `WorkoutLogView` — Session Type Filter Bar

**Files:**
- Modify: `WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift`

Add a `SessionTypeFilterBar` reusable component and wire it into `WorkoutLogView`. The bar is also used in `ClientDetailView` (Phase 3b) — define it here so it's available to both.

- [ ] **Step 1: Add `SessionTypeFilterBar` component**

At the bottom of `WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift`, add:

```swift
struct SessionTypeFilterBar: View {
    @Binding var selectedType: SessionType?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                FilterChip(label: "All", isSelected: selectedType == nil) {
                    selectedType = nil
                }
                ForEach(SessionType.allCases) { type in
                    FilterChip(label: type.displayName, isSelected: selectedType == type) {
                        selectedType = type
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 40)
        .background(ColorTokens.background)
    }
}

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                if isSelected {
                    Rectangle()
                        .fill(ColorTokens.text1)
                        .frame(width: 1)
                }
                Text(label)
                    .font(isSelected ? .custom("DMSans-Medium", size: 13) : .custom("DMSans-Regular", size: 13))
                    .foregroundStyle(isSelected ? ColorTokens.text1 : ColorTokens.text2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Add filter state to `WorkoutLogView`**

In `WorkoutLogView`, add after `@State private var showActiveWorkout = false`:

```swift
@State private var selectedSessionType: SessionType? = nil
```

- [ ] **Step 3: Add computed filtered sessions property**

In `WorkoutLogView`, add after the `sessions` `@Query`:

```swift
private var filteredSessions: [WorkoutSession] {
    guard let type = selectedSessionType else { return sessions }
    return sessions.filter { $0.sessionType == type }
}
```

- [ ] **Step 4: Wire filter bar and filtered list into body**

Replace the `ScrollView { VStack { ForEach(sessions, ...) } }` block with:

```swift
VStack(spacing: 0) {
    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
    SessionTypeFilterBar(selectedType: $selectedSessionType)
    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
    if filteredSessions.isEmpty {
        // Filter produced zero results from a non-empty session list
        VStack(spacing: 8) {
            Text("No \(selectedSessionType?.displayName ?? "") sessions yet.")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.background)
    } else {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(filteredSessions, id: \.id) { session in
                    NavigationLink(value: session.id) {
                        SessionRow(session: session)
                    }
                    .buttonStyle(.plain)

                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)
                }
            }
        }
        .background(ColorTokens.background)
    }
}
.background(ColorTokens.background)
```

- [ ] **Step 5: Build (⌘B)**

Expected: clean build.

- [ ] **Step 6: Manual smoke test**

Log two sessions with different types (e.g. Strength and Skill). In Workout Log, tap "Skill" chip → only the skill session appears. Tap "All" → both appear.

- [ ] **Step 7: Commit**

```bash
git add WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift
git commit -m "feat: add session type filter bar to WorkoutLogView"
```

---

## Task 6: `CoachWorkoutEntrySheet` — Session Type Picker *(Phase 3b)*

**Files:**
- Modify: `WorkloadApp/Views/Coach/CoachWorkoutEntrySheet.swift`

> **Prerequisite:** Phase 3b must be implemented first. `CoachWorkoutEntrySheet` is created in the Phase 3b plan. Apply these changes to that view after it exists.

- [ ] **Step 1: Add `sessionType` state**

In `CoachWorkoutEntrySheet`, add:
```swift
@State private var sessionType: SessionType = .strength
```

- [ ] **Step 2: Add picker before the sRPE slider**

```swift
Picker("Session Type", selection: $sessionType) {
    ForEach(SessionType.allCases) { type in
        Text(type.displayName).tag(type)
    }
}
.pickerStyle(.segmented)
```

- [ ] **Step 3: Set `sessionType` and `loggedByCoachId` when saving**

When the coach saves the session, set:
```swift
session.sessionType = sessionType
session.loggedByCoachId = coachAthleteId   // the coach's own Athlete.id
```

Then call `await container.syncService.pushCoachWorkoutSession(session, for: athleteId)`.

- [ ] **Step 4: Build (⌘B) and commit**

```bash
git add WorkloadApp/Views/Coach/CoachWorkoutEntrySheet.swift
git commit -m "feat: add session type picker and attribution to CoachWorkoutEntrySheet"
```

---

## Task 7: `ClientDetailView` — Filter Bar + Attribution *(Phase 3b)*

**Files:**
- Modify: `WorkloadApp/Views/Coach/ClientDetailView.swift`

> **Prerequisite:** Phase 3b must be implemented first.

- [ ] **Step 1: Add filter state**

In `ClientDetailView`:
```swift
@State private var selectedSessionType: SessionType? = nil
```

- [ ] **Step 2: Add `SessionTypeFilterBar` above the sessions list**

```swift
SessionTypeFilterBar(selectedType: $selectedSessionType)
Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
```

- [ ] **Step 3: Filter sessions in-memory**

```swift
private var filteredSessions: [WorkoutSession] {
    guard let type = selectedSessionType else { return sessions }
    return sessions.filter { $0.sessionType == type }
}
```

Use `filteredSessions` in the `ForEach` instead of `sessions`.

- [ ] **Step 4: Add attribution label to each session row**

Below the session date/name in each row, add:

```swift
Text(attributionLabel(for: session))
    .font(.custom("DMSans-Regular", size: 12))
    .foregroundStyle(ColorTokens.text3)
```

With helper:
```swift
private func attributionLabel(for session: WorkoutSession) -> String {
    guard let coachId = session.loggedByCoachId else { return "Self" }
    if coachId == viewingCoach.id { return "You" }
    let name = allAthletes.first(where: { $0.id == coachId })?.displayName
    return name ?? "Unknown Coach"
}
```

Where `viewingCoach` is the current user's `Athlete` and `allAthletes` is a `@Query private var allAthletes: [Athlete]`.

- [ ] **Step 5: Build (⌘B) and commit**

```bash
git add WorkloadApp/Views/Coach/ClientDetailView.swift
git commit -m "feat: add session filter bar and attribution to ClientDetailView"
```

---

## Task 8: End-to-End Manual Tests

No code changes. These verify the full flow after Tasks 1–5 are complete (Tasks 6–7 require Phase 3b).

- [ ] **Athlete self-log test**
  - Log a new session with type "Skill" → confirm it appears in Workout Log
  - Tap "Skill" chip → only that session visible
  - Tap "All" → all sessions visible
  - `loggedByCoachId` on the new session is `nil` (visible in SessionDetailView or Xcode debugger)

- [ ] **Sync test**
  - Sign in on two devices (or simulator + device) with the same account
  - Log a session on device A → foreground sync on device B → session appears on device B with correct `sessionType`

- [ ] **Coach attribution test** *(requires Phase 3b)*
  - Coach logs a session for an athlete via `CoachWorkoutEntrySheet` (type: Strength)
  - Athlete opens Workout Log → session appears
  - Coach opens `ClientDetailView` for that athlete → session row shows "You" attribution
  - Second coach opens `ClientDetailView` for same athlete → row shows first coach's display name
