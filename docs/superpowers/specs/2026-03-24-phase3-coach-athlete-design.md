# Phase 3: Coach + Athlete Multi-User Design

**Date:** 2026-03-24
**Project:** WorkloadApp (iOS, SwiftUI + SwiftData)
**Scope:** Role system, coach-athlete relationships, invite flows (code, email, NFC), RLS policy updates, coach UI

---

## Overview

Phase 3 adds a coach role to the app. A user can be both an athlete and a coach simultaneously. Personal trainers can manage multiple clients, view their readiness at a glance, and log workouts on their behalf.

**Delivered in two sub-phases:**
- **3a:** Role system + invite flows + Supabase schema + RLS — backend plumbing, no coach UI
- **3b:** Coach UI — context switcher, roster view, client detail view, built on 3a

**In scope:**
- `is_coach` flag on athlete accounts
- Coach-athlete relationship management (invite by code, email, NFC)
- RLS policies granting coaches read/write access to linked athletes' data
- Context switcher (athlete ↔ coach mode)
- Coach roster view and client detail view

**Out of scope (deferred):**
- Sync for `workout_sessions`, `exercise_entries`, `set_records` (Phase 3 uses snapshots only)
- Coach notifications / push alerts
- Group/team management (multiple athletes per session)
- Subscription gating of coach features (Phase 4)

---

## Architecture

Two layers of change:

1. **Backend (3a):** Two new Supabase tables, one column added to `athletes`, RLS policies extended across five tables, `InviteService` on iOS
2. **Frontend (3b):** `ContextSwitcher`, `CoachRosterView`, `ClientDetailView`, `MainTabView` mode switching, `SyncService` additions for coach data fetching

---

## Database Schema

### New column on `athletes`
```sql
ALTER TABLE athletes ADD COLUMN is_coach boolean DEFAULT false;
```

### New table: `coach_athlete_relationships`

Both FK columns use `ON DELETE CASCADE` so that deleting an athlete (e.g. on sign-out) automatically removes all their relationships — both as a coach and as an athlete.

```sql
CREATE TABLE coach_athlete_relationships (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id    uuid REFERENCES athletes(id) ON DELETE CASCADE NOT NULL,
  athlete_id  uuid REFERENCES athletes(id) ON DELETE CASCADE NOT NULL,
  status      text NOT NULL DEFAULT 'pending', -- 'pending' | 'accepted'
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now(),
  UNIQUE(coach_id, athlete_id)
);
```

### New table: `invitations`

`redeemed_by` records which athlete ID accepted the invitation, enabling audit trail and preventing double-redemption via application logic.

Expired invitations are cleaned up by a `pg_cron` scheduled job that runs nightly:
```sql
SELECT cron.schedule(
  'expire-invitations',
  '0 3 * * *',  -- 03:00 UTC daily
  $$UPDATE invitations SET status = 'expired' WHERE status = 'pending' AND expires_at < now()$$
);
```
The `expires_at > now()` check in the `redeem_invitation_by_code` RLS policy already blocks reads on expired rows in real time — the cron job is for data hygiene only and is not a security dependency.

```sql
CREATE TABLE invitations (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inviter_id   uuid REFERENCES athletes(id) ON DELETE CASCADE NOT NULL,
  inviter_role text NOT NULL,  -- 'athlete' (code flow) | 'coach' (email flow)
  code         text UNIQUE,    -- 6-char alphanumeric, code-based flow only
  email        text,            -- email-based flow only
  status       text NOT NULL DEFAULT 'pending', -- 'pending' | 'accepted' | 'expired'
  redeemed_by  uuid REFERENCES athletes(id),    -- set when accepted
  expires_at   timestamptz NOT NULL,
  created_at   timestamptz DEFAULT now()
);
```

---

## RLS Policies

**All Phase 3 policies are additive.** The Phase 2 owner-only policies (`user_id = auth.uid()` / `athlete_id = own`) remain in place unchanged. The new coach policies are added alongside them. Supabase combines multiple SELECT policies with OR, so both the owner and their coach can read the same row.

### Helper function
```sql
-- Returns true if the calling user is an accepted coach for the given athlete_id
CREATE OR REPLACE FUNCTION is_coach_for(target_athlete_id uuid)
RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM coach_athlete_relationships car
    JOIN athletes a ON a.id = car.coach_id
    WHERE a.user_id = auth.uid()
    AND car.athlete_id = target_athlete_id
    AND car.status = 'accepted'
  );
$$ LANGUAGE sql SECURITY DEFINER;
```

### `athletes` table — coach read (added alongside Phase 2 owner policy)
```sql
CREATE POLICY "coach_read_athletes"
ON athletes FOR SELECT
USING (is_coach_for(id));
```

### `workload_snapshots` — coach read + write (added alongside Phase 2 owner policies)
```sql
CREATE POLICY "coach_read_workload_snapshots"
ON workload_snapshots FOR SELECT
USING (is_coach_for(athlete_id));

CREATE POLICY "coach_insert_workload_snapshots"
ON workload_snapshots FOR INSERT
WITH CHECK (is_coach_for(athlete_id));

CREATE POLICY "coach_update_workload_snapshots"
ON workload_snapshots FOR UPDATE
USING (is_coach_for(athlete_id))
WITH CHECK (is_coach_for(athlete_id));
```

### `recovery_snapshots` — coach read + write (added alongside Phase 2 owner policies)
```sql
CREATE POLICY "coach_read_recovery_snapshots"
ON recovery_snapshots FOR SELECT
USING (is_coach_for(athlete_id));

CREATE POLICY "coach_insert_recovery_snapshots"
ON recovery_snapshots FOR INSERT
WITH CHECK (is_coach_for(athlete_id));

CREATE POLICY "coach_update_recovery_snapshots"
ON recovery_snapshots FOR UPDATE
USING (is_coach_for(athlete_id))
WITH CHECK (is_coach_for(athlete_id));
```

### `wellness_check_ins` — coach read only (added alongside Phase 2 owner policy)
```sql
CREATE POLICY "coach_read_wellness_check_ins"
ON wellness_check_ins FOR SELECT
USING (is_coach_for(athlete_id));
```

### `personal_records` — coach read + write (added alongside Phase 2 owner policies)
```sql
CREATE POLICY "coach_read_personal_records"
ON personal_records FOR SELECT
USING (is_coach_for(athlete_id));

CREATE POLICY "coach_insert_personal_records"
ON personal_records FOR INSERT
WITH CHECK (is_coach_for(athlete_id));

CREATE POLICY "coach_update_personal_records"
ON personal_records FOR UPDATE
USING (is_coach_for(athlete_id))
WITH CHECK (is_coach_for(athlete_id));
```

### `coach_athlete_relationships`
```sql
-- Both coach and athlete in a relationship can read it
CREATE POLICY "read_own_relationships"
ON coach_athlete_relationships FOR SELECT
USING (
  coach_id IN (SELECT id FROM athletes WHERE user_id = auth.uid()) OR
  athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid())
);

-- Only the coach side can create a relationship row
CREATE POLICY "coach_insert_relationship"
ON coach_athlete_relationships FOR INSERT
WITH CHECK (
  coach_id IN (SELECT id FROM athletes WHERE user_id = auth.uid())
);

-- Only the athlete side can update (accept/reject)
CREATE POLICY "athlete_update_relationship"
ON coach_athlete_relationships FOR UPDATE
USING (
  athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid())
)
WITH CHECK (
  athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid())
);
```

### `invitations`
```sql
-- Inviter can read their own invitations
CREATE POLICY "inviter_read_invitations"
ON invitations FOR SELECT
USING (inviter_id IN (SELECT id FROM athletes WHERE user_id = auth.uid()));

-- Any authenticated user can look up an invitation by code (for redemption)
-- Narrowed to non-expired, pending invitations only
CREATE POLICY "redeem_invitation_by_code"
ON invitations FOR SELECT
USING (status = 'pending' AND expires_at > now());

-- Only the inviter can insert
CREATE POLICY "insert_own_invitations"
ON invitations FOR INSERT
WITH CHECK (inviter_id IN (SELECT id FROM athletes WHERE user_id = auth.uid()));

-- The redeemer can accept an invitation; enforces caller owns the redeemed_by athlete ID
CREATE POLICY "accept_invitation"
ON invitations FOR UPDATE
USING (status = 'pending' AND expires_at > now())
WITH CHECK (
  status = 'accepted'
  AND redeemed_by IN (SELECT id FROM athletes WHERE user_id = auth.uid())
);
```

---

## Invite & Pairing Flows

All three flows result in a `coach_athlete_relationships` row with `status: 'accepted'`. All flows show an explicit confirmation screen before committing the relationship.

### Code flow (athlete-initiated)
1. Athlete taps "Invite my coach" in Profile → `InviteService.generateInviteCode(for:)` creates an `invitations` row (`inviter_role: 'athlete'`, expires 48h), returns 6-char alphanumeric code
2. Athlete shares the code manually (text, screenshot)
3. Coach taps "Link an athlete" in Profile → enters code → `InviteService.redeemCode(_:coachId:)` looks up invitation via `redeem_invitation_by_code` policy, shows confirmation screen with athlete's display name
4. Coach confirms → `coach_athlete_relationships` row inserted; invitation updated to `status: accepted`, `redeemed_by: coachId`

### Email flow (coach-initiated)
1. Coach taps "Invite an athlete" in Profile → enters athlete's email
2. `InviteService.sendEmailInvite(to:from:)` inserts an `invitations` row (`inviter_role: 'coach'`); Supabase sends email with deep link `workload://invite?code=XXXXXX` (expires 48h)
3. Athlete taps deep link → `AppRouter.onOpenURL` calls `InviteService.handleDeepLink(_:)` → `redeemCode` looks up invitation, shows confirmation screen
4. Athlete confirms → `coach_athlete_relationships` row inserted; invitation marked accepted with `redeemed_by: athleteId`

Deep link registration: custom URL scheme `workload://` in Info.plist + `LSApplicationQueriesSchemes`.

### NFC flow (in-person)
The NFC flow relies on the physical presence of both parties as the consent mechanism — both users must actively participate (one initiates a write session, the other initiates a read session) before the coach's device creates the relationship. This is an accepted trust model for an in-person pairing scenario; no server-side token validation is required.

1. Athlete taps "Share via NFC" → `NFCSessionCoordinator.startWrite(athleteId:)` opens a CoreNFC NDEF write session, writes a text record containing the athlete's UUID
2. Coach taps "Scan NFC" → `NFCSessionCoordinator.startScan()` opens a CoreNFC NDEF read session
3. Devices tap → coach's app reads `athleteId` from the NDEF record, fetches the athlete's display name from Supabase, shows confirmation screen
4. Coach confirms → `coach_athlete_relationships` row inserted directly (no `invitations` row)

CoreNFC requires `NFCReaderUsageDescription` in Info.plist and the Near Field Communication Tag Reading capability in entitlements.

---

## iOS Architecture

### Model changes

**`Athlete`** (existing):
```swift
var isCoach: Bool = false  // new field, synced to athletes.is_coach
```

**`CoachAthleteRelationship`** (new SwiftData `@Model`):
```swift
@Model final class CoachAthleteRelationship {
    @Attribute(.unique) var id: UUID
    var coachId: UUID
    var athleteId: UUID
    var status: RelationshipStatus  // enum: String, Codable — 'pending' | 'accepted'
    var createdAt: Date
    var updatedAt: Date
}
```

### `AppMode` enum (new)
```swift
enum AppMode: String {
    case athlete
    case coach
}
```

### `AppContainer` changes
- `var currentMode: AppMode` — loaded from `UserDefaults` on init, default `.athlete`
- `func setMode(_ mode: AppMode)` — updates in-memory + UserDefaults
- No stored `InviteService` instance — `InviteService` is a namespace of static methods, used directly at call sites

### `InviteService` (new, `@MainActor` enum used as namespace)

Static methods only — no instance state. NFC sessions are managed by `NFCSessionCoordinator`.

```swift
enum InviteService {
    static func generateInviteCode(for athleteId: UUID, client: SupabaseClient) async throws -> String
    /// Resolves a code to the invitation's other-party athlete — shown on the confirmation screen.
    /// Does NOT insert the relationship. Call confirmRelationship after user confirms.
    static func resolveCode(_ code: String, client: SupabaseClient) async throws -> Athlete
    /// Inserts the coach_athlete_relationships row after user confirmation.
    static func confirmRelationship(coachId: UUID, athleteId: UUID, invitationCode: String?, client: SupabaseClient) async throws -> CoachAthleteRelationship
    static func sendEmailInvite(to email: String, from coachId: UUID, client: SupabaseClient) async throws
    static func handleDeepLink(_ url: URL) -> String?  // extracts code from workload://invite?code=XXXXXX
}
```

### `NFCSessionCoordinator` (new class)

CoreNFC requires a class-based delegate. `NFCSessionCoordinator` is a `final class` that wraps CoreNFC sessions and bridges callbacks to `async/await` continuations. It is instantiated on-demand in the view that triggers the NFC flow and released when the session completes.

CoreNFC delegate callbacks (`readerSession(_:didDetectNDEFs:)`, `readerSession(_:didInvalidateWithError:)`) are delivered on a background thread. The class must **not** be marked `@MainActor`. Instead, delegate methods are `nonisolated` and hand off results to the main actor via `async/await` continuations.

```swift
final class NFCSessionCoordinator: NSObject, NFCNDEFReaderSessionDelegate {
    // Public API — called from @MainActor views
    @MainActor func startWrite(athleteId: UUID) async throws
    @MainActor func startScan() async throws -> UUID  // returns athleteId from NDEF record

    // Delegate methods — nonisolated, called by CoreNFC on background thread
    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage])
    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error)
}
```

### `NFCSessionCoordinator` + SwiftData thread safety

`startScan()` is `@MainActor` and uses a `CheckedContinuation` to await the background delegate callback. It returns only a plain `UUID` — no SwiftData access occurs inside the coordinator. All SwiftData writes (via `confirmRelationship`) happen after `startScan()` returns, on the main actor in the calling view. This guarantees `ModelContext` is never touched from a background thread.

### `SyncService` additions (3a)
- `pullLinkedAthletes(context:)` — fetches accepted relationships + linked athlete profiles
- `pullAthleteSnapshots(athleteId:, context:)` — fetches workload/recovery/wellness/PR data for one linked athlete
- `pushCoachWorkloadSnapshot(_ snapshot: WorkloadSnapshot, for athleteId: UUID, context:)`
- `pushCoachRecoverySnapshot(_ snapshot: RecoverySnapshot, for athleteId: UUID, context:)`
- `pushCoachPersonalRecord(_ pr: PersonalRecord, for athleteId: UUID, context:)`

### Coach sync trigger points

Coach data uses the same 15-minute `shouldForegroundSync` throttle as athlete data (shared `lastSyncedAt` in `UserDefaults`). Sync fires on the following events:

| Event | Action |
|---|---|
| App launch in coach mode | `pullLinkedAthletes` + `pullAthleteSnapshots` for each, if `shouldForegroundSync` |
| Scene becomes `.active` in coach mode | Same as launch |
| User switches to coach mode | `pullLinkedAthletes` + `pullAthleteSnapshots` for each, if `shouldForegroundSync` |
| `CoachRosterView` pull-to-refresh | Always triggers `pullLinkedAthletes` + `pullAthleteSnapshots` (bypasses throttle) |
| Coach logs a workout for an athlete | `pushCoachWorkloadSnapshot` fires immediately (same pattern as athlete's pipeline sync) |

The `MainTabView.onChange(scenePhase:)` already fires `pullAll` for athlete mode; a parallel branch is added for coach mode to call `pullLinkedAthletes` + `pullAthleteSnapshots`.

### `AppRouter` change (3a)
Add `.onOpenURL { url in }` handler: calls `InviteService.handleDeepLink(url)` to extract the code, then pushes a confirmation sheet with the resolved invitation details.

---

## Coach UI (3b)

### Context switcher
A `ContextSwitcher` view rendered above the tab bar in `MainTabView`. Only visible when `athlete.isCoach == true`. Uses two `Rectangle()`-based segments (0pt border radius, per design system) separated by a hairline divider. The active segment shows a text label in `ColorTokens.text1`; the inactive in `ColorTokens.text3`. No color fill used to indicate active state — relies on text weight (DM Sans Medium vs Regular) and a hairline bottom border on the active segment.

```
[ Athlete  |  Coach ]
```

Tapping a segment calls `AppContainer.setMode(_:)`. The tab bar re-renders based on mode.

**Athlete mode tabs:** Home, Log, Recovery, Load, Profile (existing)
**Coach mode tabs:** Roster, Profile

Default mode on launch is stored in `UserDefaults` and configurable in Profile → Settings.

### `CoachRosterView`
- Fetches all accepted `CoachAthleteRelationship` records from local SwiftData
- Flat list of client cards; each card shows:
  - Athlete display name + sport type
  - Recovery zone: text label using `RecoveryZone.displayName` ("Rest / Light Only" / "Cautious" / "Go") + optional colored left border (per design system — zone communicated via text + border, never color alone)
  - ACWR zone label ("Optimal" / "Caution" / "Danger" / "Undertrained")
- Pull-to-refresh triggers `SyncService.pullLinkedAthletes` + `pullAthleteSnapshots` for each athlete
- Tapping a card pushes to `ClientDetailView`
- "Add client" button in nav bar opens the invite flow sheet

### `ClientDetailView`
Full profile for one linked athlete:
- Hero card: today's recovery score + zone label
- ACWR trend chart (28-day, reuses existing chart component pattern)
- Recent workload snapshots list
- Personal records section
- "Log workout" button → opens a simplified `ActiveWorkoutSheet` pre-scoped to this athlete, writes via `pushCoachWorkloadSnapshot`

### `ProfileView` additions (both modes)
- "Become a coach" toggle (sets `isCoach = true`, syncs to Supabase) — athlete mode only
- "Invite my coach" button → code flow sheet (athlete mode)
- "Invite an athlete" button → email flow sheet (coach mode)
- "Link via NFC" button → NFC flow (available in both modes)
- "Linked coaches" list with remove option (athlete mode)
- "My athletes" list with remove option (coach mode)

Removing a relationship deletes the `coach_athlete_relationships` row from Supabase and the local SwiftData record.

---

## Coach Access Matrix

| Table | Coach Access |
|---|---|
| `athletes` (linked only) | Read |
| `workload_snapshots` (linked only) | Read + Write |
| `recovery_snapshots` (linked only) | Read + Write |
| `wellness_check_ins` (linked only) | Read |
| `personal_records` (linked only) | Read + Write |
| `coach_athlete_relationships` | Read (own) + Insert (as coach) + Update (as athlete) |
| `invitations` | Read (own + by code) + Insert (own) + Update (accept) |

---

## Current Status

- **Phase 3a (backend + invite flows): Not started**
- **Phase 3b (coach UI): Not started**
- **Depends on:** Phase 2 complete ✅
