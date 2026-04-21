# Phase 3a: Backend + Invite Flows Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire coach-athlete role system, invite flows (code, email, NFC), RLS policies, and SyncService coach additions — no UI yet.

**Architecture:** Two new Supabase tables (`coach_athlete_relationships`, `invitations`) + `is_coach` column on `athletes`. iOS gets a new `CoachAthleteRelationship` SwiftData model, `InviteService` (static methods), `NFCSessionCoordinator` (class), and `SyncService` additions for pulling/pushing linked athlete data. Deep link handling added to `AppRouter`.

**Tech Stack:** SwiftUI, SwiftData, Supabase Swift SDK, CoreNFC, XCTest

---

## File Map

| File | Change |
|---|---|
| `WorkloadApp/Models/Athlete.swift` | Add `isCoach: Bool` |
| `WorkloadApp/Models/CoachAthleteRelationship.swift` | **Create** — new SwiftData `@Model` |
| `WorkloadApp/Models/Enums.swift` | Add `RelationshipStatus`, `AppMode` enums |
| `WorkloadApp/App/WorkloadApp.swift` | Add `CoachAthleteRelationship.self` to schema |
| `WorkloadApp/App/AppContainer.swift` | Add `currentMode: AppMode`, `setMode(_:)` |
| `WorkloadApp/Services/InviteService.swift` | **Create** — static invite methods |
| `WorkloadApp/Services/NFCSessionCoordinator.swift` | **Create** — CoreNFC wrapper |
| `WorkloadApp/Services/SyncService.swift` | Add coach pull/push methods |
| `WorkloadApp/App/AppRouter.swift` | Add `.onOpenURL` deep link handler |
| `WorkloadAppTests/InviteServiceTests.swift` | **Create** — unit tests |
| `WorkloadAppTests/CoachRelationshipModelTests.swift` | **Create** — model tests |

---

## Task 1: Supabase Schema (Manual)

This task is performed in the Supabase dashboard SQL editor. No code changes.

**Files:** None (Supabase SQL editor only)

- [ ] **Step 1: Add `is_coach` column to `athletes`**

In Supabase dashboard → SQL Editor, run:
```sql
ALTER TABLE athletes ADD COLUMN IF NOT EXISTS is_coach boolean DEFAULT false;
```

- [ ] **Step 2: Create `coach_athlete_relationships` table**

```sql
CREATE TABLE IF NOT EXISTS coach_athlete_relationships (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id    uuid REFERENCES athletes(id) ON DELETE CASCADE NOT NULL,
  athlete_id  uuid REFERENCES athletes(id) ON DELETE CASCADE NOT NULL,
  status      text NOT NULL DEFAULT 'pending',
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now(),
  UNIQUE(coach_id, athlete_id)
);
```

- [ ] **Step 3: Create `invitations` table**

```sql
CREATE TABLE IF NOT EXISTS invitations (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inviter_id   uuid REFERENCES athletes(id) ON DELETE CASCADE NOT NULL,
  inviter_role text NOT NULL,
  code         text UNIQUE,
  email        text,
  status       text NOT NULL DEFAULT 'pending',
  redeemed_by  uuid REFERENCES athletes(id),
  expires_at   timestamptz NOT NULL,
  created_at   timestamptz DEFAULT now()
);
```

- [ ] **Step 4: Create `is_coach_for` helper function**

```sql
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

- [ ] **Step 5: Enable RLS on new tables**

```sql
ALTER TABLE coach_athlete_relationships ENABLE ROW LEVEL SECURITY;
ALTER TABLE invitations ENABLE ROW LEVEL SECURITY;
```

- [ ] **Step 6: Add coach read policy on `athletes`**

```sql
CREATE POLICY "coach_read_athletes"
ON athletes FOR SELECT
USING (is_coach_for(id));
```

- [ ] **Step 7: Add coach policies on `workload_snapshots`**

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

- [ ] **Step 8: Add coach policies on `recovery_snapshots`**

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

- [ ] **Step 9: Add coach read policy on `wellness_check_ins`**

```sql
CREATE POLICY "coach_read_wellness_check_ins"
ON wellness_check_ins FOR SELECT
USING (is_coach_for(athlete_id));
```

- [ ] **Step 10: Add coach policies on `personal_records`**

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

- [ ] **Step 11: Add policies on `coach_athlete_relationships`**

```sql
CREATE POLICY "read_own_relationships"
ON coach_athlete_relationships FOR SELECT
USING (
  coach_id IN (SELECT id FROM athletes WHERE user_id = auth.uid()) OR
  athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid())
);

CREATE POLICY "coach_insert_relationship"
ON coach_athlete_relationships FOR INSERT
WITH CHECK (
  coach_id IN (SELECT id FROM athletes WHERE user_id = auth.uid())
);

CREATE POLICY "athlete_update_relationship"
ON coach_athlete_relationships FOR UPDATE
USING (
  athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid())
)
WITH CHECK (
  athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid())
);
```

- [ ] **Step 12: Add policies on `invitations`**

```sql
CREATE POLICY "inviter_read_invitations"
ON invitations FOR SELECT
USING (inviter_id IN (SELECT id FROM athletes WHERE user_id = auth.uid()));

CREATE POLICY "redeem_invitation_by_code"
ON invitations FOR SELECT
USING (status = 'pending' AND expires_at > now());

CREATE POLICY "insert_own_invitations"
ON invitations FOR INSERT
WITH CHECK (inviter_id IN (SELECT id FROM athletes WHERE user_id = auth.uid()));

CREATE POLICY "accept_invitation"
ON invitations FOR UPDATE
USING (status = 'pending' AND expires_at > now())
WITH CHECK (
  status = 'accepted'
  AND redeemed_by IN (SELECT id FROM athletes WHERE user_id = auth.uid())
);
```

- [ ] **Step 13: Add pg_cron job for invitation cleanup**

First enable pg_cron in Supabase dashboard → Database → Extensions → enable `pg_cron`.
Then run:
```sql
SELECT cron.schedule(
  'expire-invitations',
  '0 3 * * *',
  $$UPDATE invitations SET status = 'expired' WHERE status = 'pending' AND expires_at < now()$$
);
```

- [ ] **Step 14: Verify in Supabase Table Editor**

Confirm both tables appear in Table Editor with the correct columns. Check that RLS is enabled (shield icon) on all tables.

---

## Task 2: SwiftData Models

**Files:**
- Modify: `WorkloadApp/Models/Athlete.swift`
- Modify: `WorkloadApp/Models/Enums.swift`
- Create: `WorkloadApp/Models/CoachAthleteRelationship.swift`
- Modify: `WorkloadApp/App/WorkloadApp.swift`
- Create: `WorkloadAppTests/CoachRelationshipModelTests.swift`

- [ ] **Step 1: Add `RelationshipStatus` and `AppMode` to `Enums.swift`**

Open `WorkloadApp/Models/Enums.swift` and add at the bottom:

```swift
// MARK: - Coach / Role Enums

enum RelationshipStatus: String, Codable {
    case pending
    case accepted
}

enum AppMode: String {
    case athlete
    case coach
}
```

- [ ] **Step 2: Add `isCoach` to `Athlete.swift`**

In `WorkloadApp/Models/Athlete.swift`, add after `var supabaseUserId: UUID?`:
```swift
var isCoach: Bool = false
```

In the `init(...)` parameter list add `isCoach: Bool = false` and in the body add `self.isCoach = isCoach`.

- [ ] **Step 3: Create `CoachAthleteRelationship.swift`**

Create `WorkloadApp/Models/CoachAthleteRelationship.swift`:

```swift
import Foundation
import SwiftData

@Model
final class CoachAthleteRelationship {
    @Attribute(.unique) var id: UUID
    var coachId: UUID
    var athleteId: UUID
    var status: RelationshipStatus
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        coachId: UUID,
        athleteId: UUID,
        status: RelationshipStatus = .pending
    ) {
        self.id = id
        self.coachId = coachId
        self.athleteId = athleteId
        self.status = status
        self.createdAt = .now
        self.updatedAt = .now
    }
}
```

- [ ] **Step 4: Add `CoachAthleteRelationship` to the schema in `WorkloadApp.swift`**

In `WorkloadApp/App/WorkloadApp.swift`, add `CoachAthleteRelationship.self` to the `Schema([...])` array:

```swift
let schema = Schema([
    Athlete.self,
    WorkoutSession.self,
    ExerciseEntry.self,
    SetRecord.self,
    WorkloadSnapshot.self,
    RecoverySnapshot.self,
    WellnessCheckIn.self,
    PersonalRecord.self,
    CoachAthleteRelationship.self,  // add this
])
```

- [ ] **Step 5: Write model tests**

Create `WorkloadAppTests/CoachRelationshipModelTests.swift`:

```swift
import XCTest
import SwiftData
@testable import WorkloadApp  // adjust to your module name if different

final class CoachRelationshipModelTests: XCTestCase {

    func test_relationship_defaultStatus_isPending() {
        let rel = CoachAthleteRelationship(coachId: UUID(), athleteId: UUID())
        XCTAssertEqual(rel.status, .pending)
    }

    func test_relationship_accept_changesStatus() {
        let rel = CoachAthleteRelationship(coachId: UUID(), athleteId: UUID())
        rel.status = .accepted
        XCTAssertEqual(rel.status, .accepted)
    }

    func test_relationshipStatus_rawValues() {
        XCTAssertEqual(RelationshipStatus.pending.rawValue, "pending")
        XCTAssertEqual(RelationshipStatus.accepted.rawValue, "accepted")
    }

    func test_appMode_rawValues() {
        XCTAssertEqual(AppMode.athlete.rawValue, "athlete")
        XCTAssertEqual(AppMode.coach.rawValue, "coach")
    }
}
```

- [ ] **Step 6: Run tests (⌘U in Xcode)**

Expected: All `CoachRelationshipModelTests` pass.

- [ ] **Step 7: Delete app from simulator, relaunch to confirm schema migrates cleanly**

Since the SwiftData schema changed (new model + new field), delete the app from the simulator before running. In simulator: long-press app → Remove App. Then ⌘R.

- [ ] **Step 8: Commit**

```bash
git add WorkloadApp/Models/Athlete.swift \
        WorkloadApp/Models/Enums.swift \
        WorkloadApp/Models/CoachAthleteRelationship.swift \
        WorkloadApp/App/WorkloadApp.swift \
        WorkloadAppTests/CoachRelationshipModelTests.swift
git commit -m "feat: add CoachAthleteRelationship model and AppMode/RelationshipStatus enums"
```

---

## Task 3: AppContainer — AppMode

**Files:**
- Modify: `WorkloadApp/App/AppContainer.swift`

- [ ] **Step 1: Add `currentMode` and `setMode` to `AppContainer`**

In `WorkloadApp/App/AppContainer.swift`, inside the `AppContainer` class after `private(set) var isAuthenticated = false`, add:

```swift
var currentMode: AppMode = {
    let stored = UserDefaults.standard.string(forKey: "appMode") ?? AppMode.athlete.rawValue
    return AppMode(rawValue: stored) ?? .athlete
}()

func setMode(_ mode: AppMode) {
    currentMode = mode
    UserDefaults.standard.set(mode.rawValue, forKey: "appMode")
}
```

- [ ] **Step 2: Build (⌘B)**

Expected: Clean build. No new errors.

- [ ] **Step 3: Commit**

```bash
git add WorkloadApp/App/AppContainer.swift
git commit -m "feat: add AppMode context switching to AppContainer"
```

---

## Task 4: InviteService — Code + Email Flows

**Files:**
- Create: `WorkloadApp/Services/InviteService.swift`
- Create: `WorkloadAppTests/InviteServiceTests.swift`

- [ ] **Step 1: Write failing tests first**

Create `WorkloadAppTests/InviteServiceTests.swift`:

```swift
import XCTest
@testable import WorkloadApp  // adjust module name if needed

final class InviteServiceTests: XCTestCase {

    // MARK: - Code generation

    func test_generateCode_returns6CharAlphanumeric() {
        let code = InviteService.makeLocalCode()
        XCTAssertEqual(code.count, 6)
        XCTAssertTrue(code.allSatisfy { $0.isLetter || $0.isNumber })
        XCTAssertTrue(code.allSatisfy { $0.isUppercase || $0.isNumber })
    }

    func test_generateCode_isRandom() {
        let codes = Set((0..<20).map { _ in InviteService.makeLocalCode() })
        XCTAssertGreaterThan(codes.count, 1)
    }

    // MARK: - Deep link parsing

    func test_handleDeepLink_validURL_returnsCode() {
        let url = URL(string: "workload://invite?code=ABC123")!
        let code = InviteService.handleDeepLink(url)
        XCTAssertEqual(code, "ABC123")
    }

    func test_handleDeepLink_missingCode_returnsNil() {
        let url = URL(string: "workload://invite")!
        let code = InviteService.handleDeepLink(url)
        XCTAssertNil(code)
    }

    func test_handleDeepLink_wrongScheme_returnsNil() {
        let url = URL(string: "https://example.com/invite?code=ABC123")!
        let code = InviteService.handleDeepLink(url)
        XCTAssertNil(code)
    }

    func test_handleDeepLink_wrongHost_returnsNil() {
        let url = URL(string: "workload://other?code=ABC123")!
        let code = InviteService.handleDeepLink(url)
        XCTAssertNil(code)
    }
}
```

- [ ] **Step 2: Run tests — verify they FAIL**

Run ⌘U. Expected: Compile error — `InviteService` does not exist yet.

- [ ] **Step 3: Create `InviteService.swift`**

Create `WorkloadApp/Services/InviteService.swift`:

```swift
import Foundation
import Supabase

/// Namespace for invite flow operations: code generation, email invite, deep link parsing, relationship confirmation.
/// All Supabase calls happen on the @MainActor; no instance state.
enum InviteService {

    // MARK: - Code generation (local, no network)

    /// Generates a cryptographically random 6-character uppercase alphanumeric code.
    static func makeLocalCode() -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }

    // MARK: - Deep link parsing (local, no network)

    /// Extracts the invite code from a deep link URL.
    /// Expected format: workload://invite?code=XXXXXX
    /// Returns nil if the URL is not a valid invite link.
    static func handleDeepLink(_ url: URL) -> String? {
        guard url.scheme == "workload",
              url.host == "invite" else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "code" })?
            .value
    }

    // MARK: - Code flow: athlete generates invite code

    /// Creates an invitation row in Supabase and returns the 6-char code.
    /// The athlete is the inviter. Expires in 48 hours.
    @MainActor
    static func generateInviteCode(
        for athleteId: UUID,
        client: SupabaseClient
    ) async throws -> String {
        let code = makeLocalCode()
        let expires = Date.now.addingTimeInterval(48 * 60 * 60)

        struct InvitationInsert: Encodable {
            let inviterId: UUID
            let inviterRole: String
            let code: String
            let expiresAt: Date
        }

        try await client
            .from("invitations")
            .insert(InvitationInsert(
                inviterId: athleteId,
                inviterRole: "athlete",
                code: code,
                expiresAt: expires
            ))
            .execute()

        return code
    }

    // MARK: - Code flow: coach resolves code (before confirmation)

    /// Looks up an invitation by code and returns the athlete who created it.
    /// Shown on the confirmation screen — does NOT insert the relationship.
    @MainActor
    static func resolveCode(
        _ code: String,
        client: SupabaseClient
    ) async throws -> ResolvedInvitation {
        struct InvitationRow: Decodable {
            let id: UUID
            let inviterId: UUID
            let inviterRole: String
        }

        let row: InvitationRow = try await client
            .from("invitations")
            .select("id, inviter_id, inviter_role")
            .eq("code", value: code)
            .single()
            .execute()
            .value

        struct AthleteRow: Decodable {
            let id: UUID
            let displayName: String?
            let sportType: String?
        }

        let athlete: AthleteRow = try await client
            .from("athletes")
            .select("id, display_name, sport_type")
            .eq("id", value: row.inviterId)
            .single()
            .execute()
            .value

        return ResolvedInvitation(
            invitationId: row.id,
            code: code,
            otherPartyId: athlete.id,
            otherPartyName: athlete.displayName ?? "Unknown",
            otherPartySport: SportType(rawValue: athlete.sportType ?? "") ?? .custom
        )
    }

    // MARK: - Confirm relationship (after user taps "Confirm")

    /// Inserts the coach_athlete_relationships row.
    /// Also marks the invitation as accepted (if invitationCode is provided).
    @MainActor
    static func confirmRelationship(
        coachId: UUID,
        athleteId: UUID,
        invitationId: UUID?,
        redeemerAthleteId: UUID?,
        client: SupabaseClient
    ) async throws -> CoachAthleteRelationship {
        struct RelationshipInsert: Encodable {
            let coachId: UUID
            let athleteId: UUID
            let status: String
        }

        struct RelationshipRow: Decodable {
            let id: UUID
            let coachId: UUID
            let athleteId: UUID
            let status: String
            let createdAt: Date
            let updatedAt: Date
        }

        let row: RelationshipRow = try await client
            .from("coach_athlete_relationships")
            .insert(RelationshipInsert(coachId: coachId, athleteId: athleteId, status: "accepted"))
            .select()
            .single()
            .execute()
            .value

        // Mark invitation accepted (code and email flows)
        if let invitationId, let redeemerAthleteId {
            struct InvitationUpdate: Encodable {
                let status: String
                let redeemedBy: UUID
            }
            try? await client
                .from("invitations")
                .update(InvitationUpdate(status: "accepted", redeemedBy: redeemerAthleteId))
                .eq("id", value: invitationId)
                .execute()
        }

        let rel = CoachAthleteRelationship(
            id: row.id,
            coachId: row.coachId,
            athleteId: row.athleteId,
            status: RelationshipStatus(rawValue: row.status) ?? .accepted
        )
        rel.createdAt = row.createdAt
        rel.updatedAt = row.updatedAt
        return rel
    }

    // MARK: - Email flow: coach sends invite to athlete

    /// Creates an invitation row for email-based invite.
    /// Supabase email (configured in dashboard) sends the deep link.
    @MainActor
    static func sendEmailInvite(
        to email: String,
        from coachId: UUID,
        client: SupabaseClient
    ) async throws {
        let code = makeLocalCode()
        let expires = Date.now.addingTimeInterval(48 * 60 * 60)

        struct InvitationInsert: Encodable {
            let inviterId: UUID
            let inviterRole: String
            let code: String
            let email: String
            let expiresAt: Date
        }

        try await client
            .from("invitations")
            .insert(InvitationInsert(
                inviterId: coachId,
                inviterRole: "coach",
                code: code,
                email: email,
                expiresAt: expires
            ))
            .execute()

        // Trigger email via Supabase Edge Function (configured separately in dashboard)
        // Edge Function name: "send-invite-email"
        // It reads the invitation row and sends the deep link workload://invite?code=XXXXXX
        struct EdgePayload: Encodable {
            let email: String
            let code: String
        }
        try await client.functions.invoke(
            "send-invite-email",
            options: .init(body: EdgePayload(email: email, code: code))
        )
    }
}

// MARK: - Value types

struct ResolvedInvitation {
    let invitationId: UUID
    let code: String
    let otherPartyId: UUID
    let otherPartyName: String
    let otherPartySport: SportType
}
```

- [ ] **Step 4: Run tests (⌘U)**

Expected: All `InviteServiceTests` pass.

- [ ] **Step 5: Build full project (⌘B)**

Expected: Clean build.

- [ ] **Step 6: Commit**

```bash
git add WorkloadApp/Services/InviteService.swift \
        WorkloadAppTests/InviteServiceTests.swift
git commit -m "feat: add InviteService with code generation, deep link parsing, email and code invite flows"
```

---

## Task 5: NFCSessionCoordinator

**Files:**
- Create: `WorkloadApp/Services/NFCSessionCoordinator.swift`

Note: CoreNFC cannot be unit tested (requires physical hardware). Manual testing on a real device is required. The `NFCReaderUsageDescription` key must be added to Info.plist and the Near Field Communication Tag Reading capability must be enabled in Xcode entitlements.

- [ ] **Step 1: Add NFC capability in Xcode**

In Xcode: Select the target → Signing & Capabilities → + Capability → Near Field Communication Tag Reading. This adds the entitlement automatically.

- [ ] **Step 2: Add `NFCReaderUsageDescription` to Info.plist**

In `workload management/workload management/workload-management-Info.plist`, add:
```xml
<key>NFCReaderUsageDescription</key>
<string>WorkloadApp uses NFC to link athletes and coaches in person.</string>
```

- [ ] **Step 3: Create `NFCSessionCoordinator.swift`**

Create `WorkloadApp/Services/NFCSessionCoordinator.swift`:

```swift
import Foundation
import CoreNFC

/// Wraps CoreNFC write and scan sessions with async/await.
/// Must be a class (not struct) to conform to NFCNDEFReaderSessionDelegate.
/// @MainActor is on individual public methods only — delegate callbacks are nonisolated.
final class NFCSessionCoordinator: NSObject {

    private var readerSession: NFCNDEFReaderSession?
    private var writerSession: NFCNDEFReaderSession?
    private var scanContinuation: CheckedContinuation<UUID, Error>?
    private var writeContinuation: CheckedContinuation<Void, Error>?
    private var athleteIdToWrite: UUID?

    // MARK: - Public API (called from @MainActor views)

    /// Writes the athlete's UUID to an NFC tag.
    /// Call from a view button action — presents the system NFC UI.
    @MainActor
    func startWrite(athleteId: UUID) async throws {
        guard NFCNDEFReaderSession.readingAvailable else {
            throw NFCError.notAvailable
        }
        athleteIdToWrite = athleteId
        return try await withCheckedThrowingContinuation { continuation in
            self.writeContinuation = continuation
            let session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
            session.alertMessage = "Hold your iPhone near the coach's device."
            self.writerSession = session
            session.begin()
        }
    }

    /// Scans an NFC tag and returns the athleteId written by the athlete's device.
    /// Call from a view button action — presents the system NFC UI.
    @MainActor
    func startScan() async throws -> UUID {
        guard NFCNDEFReaderSession.readingAvailable else {
            throw NFCError.notAvailable
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.scanContinuation = continuation
            let session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
            session.alertMessage = "Hold your iPhone near the athlete's device."
            self.readerSession = session
            session.begin()
        }
    }

    // MARK: - Errors

    enum NFCError: LocalizedError {
        case notAvailable
        case invalidPayload
        case invalidUUID

        var errorDescription: String? {
            switch self {
            case .notAvailable: return "NFC is not available on this device."
            case .invalidPayload: return "Could not read NFC data. Try again."
            case .invalidUUID: return "NFC data was not a valid athlete ID."
            }
        }
    }
}

// MARK: - NFCNDEFReaderSessionDelegate (nonisolated — called on CoreNFC background thread)

extension NFCSessionCoordinator: NFCNDEFReaderSessionDelegate {

    nonisolated func readerSession(
        _ session: NFCNDEFReaderSession,
        didDetectNDEFs messages: [NFCNDEFMessage]
    ) {
        // Scan path: extract UUID from first text record
        guard let record = messages.first?.records.first,
              record.typeNameFormat == .nfcWellKnown,
              let payloadString = String(data: record.payload.advanced(by: 3), encoding: .utf8),
              let uuid = UUID(uuidString: payloadString) else {
            scanContinuation?.resume(throwing: NFCError.invalidPayload)
            scanContinuation = nil
            return
        }
        session.invalidate()
        scanContinuation?.resume(returning: uuid)
        scanContinuation = nil
    }

    nonisolated func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        // Write path: write NDEF record when session activates
        guard session === writerSession,
              let athleteId = athleteIdToWrite else { return }

        let uuidString = athleteId.uuidString
        let payload = NFCNDEFPayload(
            format: .nfcWellKnown,
            type: "T".data(using: .utf8)!,
            identifier: Data(),
            payload: Data([0x02, 0x65, 0x6E]) + uuidString.data(using: .utf8)!  // lang prefix: en
        )
        let message = NFCNDEFMessage(records: [payload])

        session.connect(to: session.connectedTag ?? {
            // Tag connection handled in didDetectTags
            return NFCNDEFTag()  // placeholder — actual write happens in didDetectTags
        }()) { _ in }
    }

    nonisolated func readerSession(
        _ session: NFCNDEFReaderSession,
        didDetectTags tags: [NFCNDEFTag]
    ) {
        guard let tag = tags.first else { return }
        session.connect(to: tag) { [weak self] error in
            if let error {
                session.invalidate(errorMessage: error.localizedDescription)
                self?.writeContinuation?.resume(throwing: error)
                self?.writeContinuation = nil
                return
            }
            guard let athleteId = self?.athleteIdToWrite else { return }
            let uuidString = athleteId.uuidString
            let langData = Data([0x02, 0x65, 0x6E])  // length(2) + "en"
            let textData = uuidString.data(using: .utf8)!
            let payload = NFCNDEFPayload(
                format: .nfcWellKnown,
                type: "T".data(using: .utf8)!,
                identifier: Data(),
                payload: langData + textData
            )
            let message = NFCNDEFMessage(records: [payload])
            tag.writeNDEF(message) { error in
                if let error {
                    session.invalidate(errorMessage: "Write failed: \(error.localizedDescription)")
                    self?.writeContinuation?.resume(throwing: error)
                } else {
                    session.alertMessage = "Linked! ✓"
                    session.invalidate()
                    self?.writeContinuation?.resume()
                }
                self?.writeContinuation = nil
            }
        }
    }

    nonisolated func readerSession(
        _ session: NFCNDEFReaderSession,
        didInvalidateWithError error: Error
    ) {
        let nsError = error as NSError
        // Code 200 = user cancelled — not an error
        guard nsError.code != 200 else {
            scanContinuation?.resume(throwing: CancellationError())
            writeContinuation?.resume(throwing: CancellationError())
            scanContinuation = nil
            writeContinuation = nil
            return
        }
        scanContinuation?.resume(throwing: error)
        writeContinuation?.resume(throwing: error)
        scanContinuation = nil
        writeContinuation = nil
    }
}
```

- [ ] **Step 4: Build (⌘B)**

Expected: Clean build. CoreNFC will emit no warnings if the entitlement is properly added.

- [ ] **Step 5: Commit**

```bash
git add WorkloadApp/Services/NFCSessionCoordinator.swift \
        "workload management/workload management/workload-management-Info.plist"
git commit -m "feat: add NFCSessionCoordinator for in-person athlete-coach pairing"
```

---

## Task 6: SyncService — Coach Pull/Push Methods

**Files:**
- Modify: `WorkloadApp/Services/SyncService.swift`

`SyncService` is currently 382 lines. Add coach methods at the bottom of the file.

- [ ] **Step 1: Add Codable row types for CoachAthleteRelationship**

At the bottom of `SyncService.swift`, before the final closing brace, add:

```swift
// MARK: - Coach Rows

private struct CoachAthleteRelationshipRow: Codable {
    let id: UUID
    let coachId: UUID
    let athleteId: UUID
    let status: String
    let createdAt: Date
    let updatedAt: Date
}
```

- [ ] **Step 2: Add `pullLinkedAthletes`**

```swift
/// Fetches accepted coach_athlete_relationships and linked athlete profiles for the current coach.
func pullLinkedAthletes(context: ModelContext) async {
    guard let currentAthlete = try? context.fetch(FetchDescriptor<Athlete>()).first else { return }

    // Fetch accepted relationships where current user is coach
    guard let rows: [CoachAthleteRelationshipRow] = try? await client
        .from("coach_athlete_relationships")
        .select()
        .eq("coach_id", value: currentAthlete.id)
        .eq("status", value: "accepted")
        .execute()
        .value
    else { return }

    // Upsert each relationship into local SwiftData
    for row in rows {
        let predicate = #Predicate<CoachAthleteRelationship> { $0.id == row.id }
        if let existing = try? context.fetch(FetchDescriptor(predicate: predicate)).first {
            existing.status = RelationshipStatus(rawValue: row.status) ?? .accepted
            existing.updatedAt = row.updatedAt
        } else {
            let rel = CoachAthleteRelationship(
                id: row.id,
                coachId: row.coachId,
                athleteId: row.athleteId,
                status: RelationshipStatus(rawValue: row.status) ?? .accepted
            )
            rel.createdAt = row.createdAt
            rel.updatedAt = row.updatedAt
            context.insert(rel)
        }
    }
    try? context.save()

    // Fetch athlete profiles for each linked athlete
    let linkedAthleteIds = rows.map { $0.athleteId }
    for athleteId in linkedAthleteIds {
        await pullLinkedAthleteProfile(athleteId: athleteId, context: context)
    }
}

private func pullLinkedAthleteProfile(athleteId: UUID, context: ModelContext) async {
    guard let row: AthleteRow = try? await client
        .from("athletes")
        .select()
        .eq("id", value: athleteId)
        .single()
        .execute()
        .value
    else { return }

    let predicate = #Predicate<Athlete> { $0.id == athleteId }
    if let existing = try? context.fetch(FetchDescriptor(predicate: predicate)).first {
        existing.displayName = row.displayName ?? existing.displayName
        existing.sportType = SportType(rawValue: row.sportType ?? "") ?? existing.sportType
        existing.isCoach = row.isCoach ?? existing.isCoach
        existing.updatedAt = row.updatedAt
    } else {
        let athlete = Athlete(
            id: row.id,
            displayName: row.displayName ?? "",
            sportType: SportType(rawValue: row.sportType ?? "") ?? .custom
        )
        athlete.supabaseUserId = row.userId
        athlete.isCoach = row.isCoach ?? false
        athlete.updatedAt = row.updatedAt
        context.insert(athlete)
    }
    try? context.save()
}
```

Note: You need to add `isCoach` to the existing `AthleteRow` Codable struct in `SyncService.swift`. Find it (search for `struct AthleteRow`) and add `var isCoach: Bool?`.

- [ ] **Step 3: Add `pullAthleteSnapshots`**

```swift
/// Fetches all snapshot data for a single linked athlete.
func pullAthleteSnapshots(athleteId: UUID, context: ModelContext) async {
    guard let linkedAthlete = try?
        context.fetch(FetchDescriptor<Athlete>(predicate: #Predicate { $0.id == athleteId })).first
    else { return }

    await pullWorkloadSnapshots(context: context, athlete: linkedAthlete)
    await pullRecoverySnapshots(context: context, athlete: linkedAthlete)
    await pullWellnessCheckIns(context: context, athlete: linkedAthlete)
    await pullPersonalRecords(context: context, athlete: linkedAthlete)
}
```

- [ ] **Step 4: Add coach push methods**

```swift
/// Push a workload snapshot on behalf of a linked athlete (coach-initiated).
func pushCoachWorkloadSnapshot(_ snapshot: WorkloadSnapshot, for athleteId: UUID) async {
    let row = WorkloadSnapshotRow(from: snapshot, athleteId: athleteId)
    _ = try? await client.from("workload_snapshots").upsert(row).execute()
}

/// Push a recovery snapshot on behalf of a linked athlete (coach-initiated).
func pushCoachRecoverySnapshot(_ snapshot: RecoverySnapshot, for athleteId: UUID) async {
    let row = RecoverySnapshotRow(from: snapshot, athleteId: athleteId)
    _ = try? await client.from("recovery_snapshots").upsert(row).execute()
}

/// Push a personal record on behalf of a linked athlete (coach-initiated).
func pushCoachPersonalRecord(_ pr: PersonalRecord, for athleteId: UUID) async {
    let row = PersonalRecordRow(from: pr, athleteId: athleteId)
    _ = try? await client.from("personal_records").upsert(row).execute()
}
```

- [ ] **Step 5: Build (⌘B)**

Expected: Clean build. If `AthleteRow` doesn't have `isCoach`, you'll see a compile error — add `var isCoach: Bool?` to the struct.

- [ ] **Step 6: Commit**

```bash
git add WorkloadApp/Services/SyncService.swift
git commit -m "feat: add SyncService coach pull/push methods for linked athlete data"
```

---

## Task 7: AppRouter — Deep Link Handling

**Files:**
- Modify: `WorkloadApp/App/AppRouter.swift`

- [ ] **Step 1: Add `pendingInviteCode` state and `onOpenURL` handler**

In `WorkloadApp/App/AppRouter.swift`, add a `@State` variable and the deep link handler to the `AppRouter` body:

```swift
struct AppRouter: View {
    @State private var container = AppContainer()
    @State private var isCheckingSession = true
    @State private var pendingInviteCode: String? = nil  // add this
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            // ... existing code ...
        }
        .environment(container)
        .task { /* existing task */ }
        .onOpenURL { url in                                          // add this block
            if let code = InviteService.handleDeepLink(url) {
                pendingInviteCode = code
            }
        }
        .sheet(item: $pendingInviteCode) { code in                  // add this sheet
            InviteConfirmationSheet(code: code, mode: .athleteAccepting)
                .environment(container)
        }
    }
}
```

`String` doesn't conform to `Identifiable` by default — use a wrapper or make `pendingInviteCode` an `@State private var pendingInviteCode: PendingInvite?` where:

```swift
struct PendingInvite: Identifiable {
    let id = UUID()
    let code: String
}
```

Change the state to `@State private var pendingInviteCode: PendingInvite?` and update `pendingInviteCode = PendingInvite(code: code)`.

- [ ] **Step 2: Create `InviteConfirmationSheet.swift`**

Create `WorkloadApp/Views/Profile/InviteConfirmationSheet.swift`:

```swift
import SwiftUI
import SwiftData

enum InviteConfirmationMode {
    case athleteAccepting   // athlete tapped a deep link from coach email
    case coachConfirming    // coach entered a code or scanned NFC
}

struct InviteConfirmationSheet: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var athletes: [Athlete]

    let code: String
    let mode: InviteConfirmationMode

    @State private var resolved: ResolvedInvitation?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isConfirming = false

    private var currentAthlete: Athlete? { athletes.first }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView("Looking up invite...")
                        .padding(.top, 64)
                } else if let error = errorMessage {
                    Text(error)
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.zoneDanger)
                        .padding(.horizontal, 16)
                        .padding(.top, 64)
                } else if let resolved {
                    VStack(alignment: .leading, spacing: 0) {
                        Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(mode == .athleteAccepting ? "COACH REQUEST" : "LINK ATHLETE")
                                .font(.Tokens.micro)
                                .tracking(1.2)
                                .foregroundStyle(ColorTokens.text3)
                            Text(resolved.otherPartyName)
                                .font(.Tokens.pageTitle)
                                .foregroundStyle(ColorTokens.text1)
                            Text(resolved.otherPartySport.displayName)
                                .font(.Tokens.label)
                                .foregroundStyle(ColorTokens.text2)
                        }
                        .padding(16)

                        Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                        Button {
                            Task { await confirm(resolved: resolved) }
                        } label: {
                            Group {
                                if isConfirming {
                                    ProgressView()
                                } else {
                                    Text("Confirm Link")
                                        .font(.Tokens.body)
                                        .foregroundStyle(ColorTokens.text1)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }
                        .disabled(isConfirming)

                        Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .font(.Tokens.label)
                                .foregroundStyle(ColorTokens.text2)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }

                        Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                    }
                }
                Spacer()
            }
            .background(ColorTokens.background)
            .navigationBarHidden(true)
        }
        .task {
            await resolve()
        }
    }

    private func resolve() async {
        do {
            resolved = try await InviteService.resolveCode(code, client: container.supabase)
        } catch {
            errorMessage = "Invalid or expired invite code."
        }
        isLoading = false
    }

    private func confirm(resolved: ResolvedInvitation) async {
        guard let athlete = currentAthlete else { return }
        isConfirming = true
        do {
            let coachId = mode == .athleteAccepting ? resolved.otherPartyId : athlete.id
            let athleteId = mode == .athleteAccepting ? athlete.id : resolved.otherPartyId
            let rel = try await InviteService.confirmRelationship(
                coachId: coachId,
                athleteId: athleteId,
                invitationId: resolved.invitationId,
                redeemerAthleteId: athlete.id,
                client: container.supabase
            )
            modelContext.insert(rel)
            try? modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isConfirming = false
    }
}
```

- [ ] **Step 3: Register the `workload://` URL scheme**

In Xcode: Select the target → Info tab → URL Types → + → set URL Schemes to `workload`, Role to `Viewer`.

- [ ] **Step 4: Build (⌘B)**

Expected: Clean build.

- [ ] **Step 5: Commit**

```bash
git add WorkloadApp/App/AppRouter.swift \
        WorkloadApp/Views/Profile/InviteConfirmationSheet.swift
git commit -m "feat: add deep link handler and InviteConfirmationSheet for email invite flow"
```

---

## Task 8: ProfileView — Invite UI

**Files:**
- Modify: `WorkloadApp/Views/Profile/ProfileView.swift`

- [ ] **Step 1: Add invite state and invite sheets to ProfileView**

Replace the contents of `WorkloadApp/Views/Profile/ProfileView.swift` with the updated version that adds coach-related sections. Add these state variables and sections to the existing `ProfileView`:

```swift
struct ProfileView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Query private var athletes: [Athlete]
    @Query private var relationships: [CoachAthleteRelationship]  // add

    private var athlete: Athlete? { athletes.first }

    // Invite flow state
    @State private var showInviteCodeSheet = false
    @State private var showEnterCodeSheet = false
    @State private var showEmailInviteSheet = false
    @State private var showNFCSheet = false
    @State private var generatedCode: String?
    @State private var enteredCode = ""
    @State private var inviteEmail = ""
    @State private var isGeneratingCode = false
    @State private var isSendingEmail = false
    @State private var pendingInviteFromProfile: PendingInvite?
    @State private var nfcCoordinator = NFCSessionCoordinator()
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if let athlete {
                    // ... existing sections (Athlete info, Preferences, HealthKit) ...

                    // COACH SECTION
                    Section("Coach") {
                        if !athlete.isCoach {
                            Toggle("Enable Coach Mode", isOn: Binding(
                                get: { athlete.isCoach },
                                set: { newValue in
                                    athlete.isCoach = newValue
                                    athlete.updatedAt = .now
                                    try? modelContext.save()
                                    Task { await container.syncService.pushAthlete(athlete) }
                                }
                            ))
                        }

                        Button("Invite My Coach") {
                            Task { await generateCode(for: athlete) }
                        }

                        if athlete.isCoach {
                            Button("Invite an Athlete (Email)") {
                                showEmailInviteSheet = true
                            }
                        }

                        Button("Link via NFC") {
                            Task { await startNFC(athlete: athlete) }
                        }
                    }

                    // LINKED COACHES
                    let myCoachRels = relationships.filter {
                        $0.athleteId == athlete.id && $0.status == .accepted
                    }
                    if !myCoachRels.isEmpty {
                        Section("My Coaches") {
                            ForEach(myCoachRels) { rel in
                                LinkedPartyRow(athleteId: rel.coachId)
                                    .swipeActions {
                                        Button("Remove", role: .destructive) {
                                            Task { await removeRelationship(rel) }
                                        }
                                    }
                            }
                        }
                    }

                    // MY ATHLETES (coach mode)
                    if athlete.isCoach {
                        let myAthleteRels = relationships.filter {
                            $0.coachId == athlete.id && $0.status == .accepted
                        }
                        if !myAthleteRels.isEmpty {
                            Section("My Athletes") {
                                ForEach(myAthleteRels) { rel in
                                    LinkedPartyRow(athleteId: rel.athleteId)
                                        .swipeActions {
                                            Button("Remove", role: .destructive) {
                                                Task { await removeRelationship(rel) }
                                            }
                                        }
                                }
                            }
                        }
                    }

                    // ... existing Account/Sign Out section ...
                }
            }
            .navigationTitle("Profile")
            // Generated code display
            .alert("Your Invite Code", isPresented: $showInviteCodeSheet, presenting: generatedCode) { code in
                Button("Done") { generatedCode = nil }
                Button("Copy") { UIPasteboard.general.string = code }
            } message: { code in
                Text("Share this code with your coach:\n\n\(code)\n\nExpires in 48 hours.")
            }
            // Enter code sheet (coach flow)
            .sheet(isPresented: $showEnterCodeSheet) {
                EnterInviteCodeSheet()
                    .environment(container)
            }
            // Email invite sheet
            .sheet(isPresented: $showEmailInviteSheet) {
                EmailInviteSheet()
                    .environment(container)
            }
            // Confirmation sheet (from NFC or enter-code flows)
            .sheet(item: $pendingInviteFromProfile) { pending in
                InviteConfirmationSheet(code: pending.code, mode: .coachConfirming)
                    .environment(container)
            }
            // Error
            .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func generateCode(for athlete: Athlete) async {
        isGeneratingCode = true
        do {
            generatedCode = try await InviteService.generateInviteCode(for: athlete.id, client: container.supabase)
            showInviteCodeSheet = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isGeneratingCode = false
    }

    private func startNFC(athlete: Athlete) async {
        do {
            if athlete.isCoach {
                // Coach scans athlete's tag
                let athleteId = try await nfcCoordinator.startScan()
                pendingInviteFromProfile = PendingInvite(code: athleteId.uuidString)
            } else {
                // Athlete writes their ID
                try await nfcCoordinator.startWrite(athleteId: athlete.id)
            }
        } catch is CancellationError {
            // User cancelled — no-op
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeRelationship(_ rel: CoachAthleteRelationship) async {
        do {
            try await container.supabase
                .from("coach_athlete_relationships")
                .delete()
                .eq("id", value: rel.id)
                .execute()
            modelContext.delete(rel)
            try? modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Supporting views

struct LinkedPartyRow: View {
    @Query private var athletes: [Athlete]
    let athleteId: UUID

    private var linkedAthlete: Athlete? {
        athletes.first(where: { $0.id == athleteId })
    }

    var body: some View {
        if let a = linkedAthlete {
            VStack(alignment: .leading, spacing: 2) {
                Text(a.displayName)
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text1)
                Text(a.sportType.displayName)
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text3)
            }
        } else {
            Text("Unknown")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text3)
        }
    }
}

struct EnterInviteCodeSheet: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var pending: PendingInvite?
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                VStack(alignment: .leading, spacing: 0) {
                    Text("INVITE CODE")
                        .font(.Tokens.micro).tracking(1.2)
                        .foregroundStyle(ColorTokens.text3)
                        .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 8)
                    TextField("Enter 6-character code", text: $code)
                        .font(.Tokens.body)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 16).padding(.bottom, 16)
                }
                .background(ColorTokens.surface)
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                if let error {
                    Text(error).font(.Tokens.label).foregroundStyle(ColorTokens.zoneDanger)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                }
                Button {
                    pending = PendingInvite(code: code.uppercased())
                } label: {
                    Text("Look Up Code").font(.Tokens.body)
                        .foregroundStyle(code.count == 6 ? ColorTokens.text1 : ColorTokens.text3)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                }
                .disabled(code.count != 6)
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                Spacer()
            }
            .background(ColorTokens.background)
            .navigationBarHidden(true)
            .sheet(item: $pending) { p in
                InviteConfirmationSheet(code: p.code, mode: .coachConfirming)
                    .environment(container)
                    .onDisappear { dismiss() }
            }
        }
    }
}

struct EmailInviteSheet: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @Query private var athletes: [Athlete]
    @State private var email = ""
    @State private var isSending = false
    @State private var sent = false
    @State private var error: String?

    private var athlete: Athlete? { athletes.first }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                VStack(alignment: .leading, spacing: 0) {
                    Text("ATHLETE EMAIL")
                        .font(.Tokens.micro).tracking(1.2)
                        .foregroundStyle(ColorTokens.text3)
                        .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 8)
                    TextField("athlete@example.com", text: $email)
                        .font(.Tokens.body)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 16).padding(.bottom, 16)
                }
                .background(ColorTokens.surface)
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                if let error {
                    Text(error).font(.Tokens.label).foregroundStyle(ColorTokens.zoneDanger)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                }
                if sent {
                    Text("Invite sent! They'll receive a link by email.")
                        .font(.Tokens.label).foregroundStyle(ColorTokens.text2)
                        .padding(16)
                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                    Button("Done") { dismiss() }
                        .font(.Tokens.body).foregroundStyle(ColorTokens.text1)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                } else {
                    Button {
                        Task { await sendInvite() }
                    } label: {
                        Group {
                            if isSending { ProgressView() }
                            else {
                                Text("Send Invite").font(.Tokens.body)
                                    .foregroundStyle(email.contains("@") ? ColorTokens.text1 : ColorTokens.text3)
                            }
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                    }
                    .disabled(!email.contains("@") || isSending)
                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                }
                Spacer()
            }
            .background(ColorTokens.background)
            .navigationBarHidden(true)
        }
    }

    private func sendInvite() async {
        guard let athlete else { return }
        isSending = true
        do {
            try await InviteService.sendEmailInvite(to: email, from: athlete.id, client: container.supabase)
            sent = true
        } catch {
            self.error = error.localizedDescription
        }
        isSending = false
    }
}
```

- [ ] **Step 2: Build (⌘B)**

Expected: Clean build.

- [ ] **Step 3: Commit**

```bash
git add WorkloadApp/Views/Profile/ProfileView.swift \
        WorkloadApp/Views/Profile/InviteConfirmationSheet.swift
git commit -m "feat: add invite UI to ProfileView (code, email, NFC flows)"
```

---

## Task 9: End-to-End Manual Test (3a)

No code changes. Test on a real device for NFC flows; simulator is sufficient for code + email flows.

**Test: Code flow**
- [ ] User A signs in as athlete → Profile → "Invite My Coach" → code shown
- [ ] User B signs in as coach on second device → Profile → enters code → confirmation screen → confirms → relationship appears in "My Athletes" / "My Coaches"

**Test: Email flow**
- [ ] User B (coach) → Profile → "Invite an Athlete (Email)" → enters User A's email → "Invite sent" confirmation
- [ ] User A receives email, taps deep link → app opens → confirmation screen → confirms → relationship established
- [ ] (Note: Supabase Edge Function `send-invite-email` must be deployed separately for email delivery)

**Test: Relationship removal**
- [ ] Swipe on a linked athlete/coach in ProfileView → "Remove" → relationship disappears from both devices on next sync

**Test: Coach toggle**
- [ ] Toggle "Enable Coach Mode" → `is_coach` updates in Supabase `athletes` table