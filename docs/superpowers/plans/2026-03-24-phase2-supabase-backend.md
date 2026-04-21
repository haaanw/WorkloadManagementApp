# Phase 2: Supabase Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add real email/password auth and cloud sync for computed scores (Athlete, WorkloadSnapshot, RecoverySnapshot, WellnessCheckIn, PersonalRecord) via Supabase.

**Architecture:** Local SwiftData stays as the UI source of truth. Supabase is the sync/backup layer. Auth gates the entire app — no local-only mode. Full-upsert sync strategy (no dirty flags) with last-write-wins conflict resolution on `updatedAt`.

**Tech Stack:** Supabase Swift SDK (`supabase-swift`), SwiftData, SwiftUI, `@MainActor`

**Spec:** `docs/superpowers/specs/2026-03-24-phase2-supabase-backend-design.md`

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `workload management/Config/SupabaseConfig.swift` | Create (gitignored) | Real URL + anon key |
| `workload management/Config/SupabaseConfig.example.swift` | Create | Placeholder template for other devs |
| `WorkloadApp/App/AppContainer.swift` | Modify | Add SupabaseClient, SyncService, session-loss listener |
| `WorkloadApp/App/AppRouter.swift` | Modify | Gate on `isAuthenticated`, drop `@Query athletes` |
| `WorkloadApp/Services/AuthService.swift` | Rewrite | Real Supabase auth implementation |
| `WorkloadApp/Services/SyncService.swift` | Rewrite | `@MainActor struct`, pushAll/pullAll, Codable row types |
| `WorkloadApp/Services/WorkoutPipeline.swift` | Modify | Push WorkloadSnapshot + PersonalRecord after processSession |
| `WorkloadApp/Services/RecoveryPipeline.swift` | Modify | Push RecoverySnapshot + WellnessCheckIn after run |
| `WorkloadApp/Models/WorkloadSnapshot.swift` | Modify | Remove `isSynced`, add `updatedAt` |
| `WorkloadApp/Models/RecoverySnapshot.swift` | Modify | Remove `isSynced`, add `updatedAt` |
| `WorkloadApp/Models/WellnessCheckIn.swift` | Modify | Remove `isSynced`, add `updatedAt` |
| `WorkloadApp/Models/PersonalRecord.swift` | Modify | Remove `isSynced`, add `updatedAt` |
| `WorkloadApp/Models/Athlete.swift` | Modify | `supabaseUserId: String?` → `UUID?` |
| `WorkloadApp/Views/Auth/LoginView.swift` | Modify | Real sign-in: auth → pullAll → isAuthenticated = true |
| `WorkloadApp/Views/Auth/SignUpView.swift` | Modify | Real sign-up: auth → insert Supabase athlete → local athlete |
| `WorkloadApp/Views/Profile/ProfileView.swift` | Modify | Pass modelContext to signOut |
| `WorkloadApp/Views/Onboarding/OnboardingView.swift` | Delete | Replaced by SignUpView |

---

## Task 1: Supabase Project Setup (manual — do this first)

**Files:** None (Supabase dashboard only)

- [ ] **Step 1: Create Supabase project**

  Go to https://supabase.com → New Project. Choose a region close to your users. Save the **Project URL** and **anon public key** from Settings → API.

- [ ] **Step 2: Disable email confirmation**

  Supabase dashboard → Authentication → Providers → Email → turn off "Confirm email". This lets users get a session immediately on sign-up.

- [ ] **Step 3: Run schema SQL**

  Go to Supabase dashboard → SQL Editor → New query. Paste and run:

  ```sql
  -- Athletes
  CREATE TABLE public.athletes (
    id                     uuid PRIMARY KEY,
    user_id                uuid REFERENCES auth.users NOT NULL,
    display_name           text,
    sport_type             text,
    weight_unit            text,
    acwr_method            text,
    load_metric_preference text,
    max_heart_rate         int,
    date_of_birth          date,
    created_at             timestamptz DEFAULT now(),
    updated_at             timestamptz DEFAULT now()
  );

  -- Workload snapshots
  CREATE TABLE public.workload_snapshots (
    id            uuid PRIMARY KEY,
    athlete_id    uuid REFERENCES public.athletes NOT NULL,
    snapshot_date date NOT NULL,
    acute_load    double precision,
    chronic_load  double precision,
    acwr          double precision,
    tsb           double precision,
    weekly_volume double precision,
    load_source   text,
    updated_at    timestamptz DEFAULT now()
  );

  -- Recovery snapshots
  CREATE TABLE public.recovery_snapshots (
    id                     uuid PRIMARY KEY,
    athlete_id             uuid REFERENCES public.athletes NOT NULL,
    date                   date NOT NULL,
    recovery_score         double precision,
    hrv_sdnn               double precision,
    resting_hr             double precision,
    sleep_duration_minutes double precision,
    sleep_score            double precision,
    body_temp              double precision,
    vo2_max                double precision,
    hrv_baseline           double precision,
    resting_hr_baseline    double precision,
    data_source            text,
    updated_at             timestamptz DEFAULT now()
  );

  -- Wellness check-ins
  CREATE TABLE public.wellness_check_ins (
    id            uuid PRIMARY KEY,
    athlete_id    uuid REFERENCES public.athletes NOT NULL,
    date          date NOT NULL,
    sleep_quality int,
    soreness      int,
    energy        int,
    stress        int,
    notes         text,
    updated_at    timestamptz DEFAULT now()
  );

  -- Personal records
  CREATE TABLE public.personal_records (
    id             uuid PRIMARY KEY,
    athlete_id     uuid REFERENCES public.athletes NOT NULL,
    exercise_name  text,
    record_type    text,
    value          double precision,
    previous_value double precision,
    session_id     uuid,
    achieved_at    timestamptz,
    updated_at     timestamptz DEFAULT now()
  );
  ```

- [ ] **Step 4: Run RLS policy SQL**

  In SQL Editor → New query:

  ```sql
  -- Enable RLS
  ALTER TABLE public.athletes ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.workload_snapshots ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.recovery_snapshots ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.wellness_check_ins ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.personal_records ENABLE ROW LEVEL SECURITY;

  -- athletes: owner only
  CREATE POLICY "athletes_owner" ON public.athletes
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

  -- workload_snapshots
  CREATE POLICY "workload_snapshots_owner" ON public.workload_snapshots
    USING (athlete_id IN (SELECT id FROM public.athletes WHERE user_id = auth.uid()))
    WITH CHECK (athlete_id IN (SELECT id FROM public.athletes WHERE user_id = auth.uid()));

  -- recovery_snapshots
  CREATE POLICY "recovery_snapshots_owner" ON public.recovery_snapshots
    USING (athlete_id IN (SELECT id FROM public.athletes WHERE user_id = auth.uid()))
    WITH CHECK (athlete_id IN (SELECT id FROM public.athletes WHERE user_id = auth.uid()));

  -- wellness_check_ins
  CREATE POLICY "wellness_check_ins_owner" ON public.wellness_check_ins
    USING (athlete_id IN (SELECT id FROM public.athletes WHERE user_id = auth.uid()))
    WITH CHECK (athlete_id IN (SELECT id FROM public.athletes WHERE user_id = auth.uid()));

  -- personal_records
  CREATE POLICY "personal_records_owner" ON public.personal_records
    USING (athlete_id IN (SELECT id FROM public.athletes WHERE user_id = auth.uid()))
    WITH CHECK (athlete_id IN (SELECT id FROM public.athletes WHERE user_id = auth.uid()));
  ```

- [ ] **Step 5: Verify tables exist**

  In Supabase dashboard → Table Editor — confirm all 5 tables appear with the correct columns.

---

## Task 2: Add Supabase Swift SDK + Config Files

**Files:**
- Create: `workload management/Config/SupabaseConfig.swift`
- Create: `workload management/Config/SupabaseConfig.example.swift`

- [ ] **Step 1: Add supabase-swift via Xcode SPM**

  In Xcode: File → Add Package Dependencies → search for:
  ```
  https://github.com/supabase/supabase-swift
  ```
  Select the `Supabase` product. Add to the `workload management` target.

- [ ] **Step 2: Create the example config file**

  Create `workload management/Config/SupabaseConfig.example.swift` (add to Xcode target):

  ```swift
  // Copy this file to SupabaseConfig.swift and fill in your values.
  // SupabaseConfig.swift is gitignored — never commit real credentials.
  import Foundation

  enum SupabaseConfig {
      static let url = URL(string: "https://YOUR_PROJECT_ID.supabase.co")!
      static let anonKey = "YOUR_ANON_KEY"
  }
  ```

- [ ] **Step 3: Create the real config file**

  Create `workload management/Config/SupabaseConfig.swift` (add to Xcode target, **do NOT add to git**):

  ```swift
  import Foundation

  enum SupabaseConfig {
      static let url = URL(string: "https://YOUR_ACTUAL_PROJECT_ID.supabase.co")!
      static let anonKey = "YOUR_ACTUAL_ANON_KEY"
  }
  ```

  Fill in the real values from the Supabase dashboard (Settings → API).

- [ ] **Step 4: Gitignore SupabaseConfig.swift**

  If the project has a `.gitignore`, add:
  ```
  SupabaseConfig.swift
  ```

- [ ] **Step 5: Build to verify SDK compiles**

  Press ⌘B in Xcode.
  Expected: build succeeds with Supabase framework linked.

---

## Task 3: Model Changes — Remove `isSynced`, Add `updatedAt`

**Files:**
- Modify: `WorkloadApp/Models/WorkloadSnapshot.swift`
- Modify: `WorkloadApp/Models/RecoverySnapshot.swift`
- Modify: `WorkloadApp/Models/WellnessCheckIn.swift`
- Modify: `WorkloadApp/Models/PersonalRecord.swift`
- Modify: `WorkloadApp/Models/Athlete.swift`

- [ ] **Step 1: Update WorkloadSnapshot**

  Replace the full file content:

  ```swift
  import Foundation
  import SwiftData

  @Model
  final class WorkloadSnapshot {
      @Attribute(.unique) var id: UUID
      var snapshotDate: Date
      var acuteLoad: Double
      var chronicLoad: Double
      var acwr: Double
      var tsb: Double
      var weeklyVolume: Double
      var loadSource: LoadSource
      var updatedAt: Date

      var athlete: Athlete?

      var zone: ACWRZone {
          ACWRZone.classify(acwr: acwr, ctl: chronicLoad)
      }

      init(
          id: UUID = UUID(),
          snapshotDate: Date = .now,
          acuteLoad: Double = 0,
          chronicLoad: Double = 0,
          acwr: Double = 0,
          tsb: Double = 0,
          weeklyVolume: Double = 0,
          loadSource: LoadSource = .srpe
      ) {
          self.id = id
          self.snapshotDate = snapshotDate
          self.acuteLoad = acuteLoad
          self.chronicLoad = chronicLoad
          self.acwr = acwr
          self.tsb = tsb
          self.weeklyVolume = weeklyVolume
          self.loadSource = loadSource
          self.updatedAt = .now
      }
  }
  ```

- [ ] **Step 2: Update RecoverySnapshot**

  Replace the full file content:

  ```swift
  import Foundation
  import SwiftData

  @Model
  final class RecoverySnapshot {
      @Attribute(.unique) var id: UUID
      var date: Date
      var hrvSDNN: Double?
      var restingHR: Double?
      var sleepDurationMinutes: Double?
      var sleepScore: Double?
      var bodyTemp: Double?
      var vo2Max: Double?
      var recoveryScore: Double
      var hrvBaseline: Double?
      var restingHRBaseline: Double?
      var dataSource: RecoveryDataSource
      var updatedAt: Date

      var athlete: Athlete?

      var zone: RecoveryZone {
          RecoveryZone.classify(score: recoveryScore)
      }

      init(
          id: UUID = UUID(),
          date: Date = .now,
          hrvSDNN: Double? = nil,
          restingHR: Double? = nil,
          sleepDurationMinutes: Double? = nil,
          sleepScore: Double? = nil,
          bodyTemp: Double? = nil,
          vo2Max: Double? = nil,
          recoveryScore: Double = 50,
          hrvBaseline: Double? = nil,
          restingHRBaseline: Double? = nil,
          dataSource: RecoveryDataSource = .healthKit
      ) {
          self.id = id
          self.date = date
          self.hrvSDNN = hrvSDNN
          self.restingHR = restingHR
          self.sleepDurationMinutes = sleepDurationMinutes
          self.sleepScore = sleepScore
          self.bodyTemp = bodyTemp
          self.vo2Max = vo2Max
          self.recoveryScore = recoveryScore
          self.hrvBaseline = hrvBaseline
          self.restingHRBaseline = restingHRBaseline
          self.dataSource = dataSource
          self.updatedAt = .now
      }
  }
  ```

- [ ] **Step 3: Update WellnessCheckIn**

  Replace the full file content:

  ```swift
  import Foundation
  import SwiftData

  @Model
  final class WellnessCheckIn {
      @Attribute(.unique) var id: UUID
      var date: Date
      var sleepQuality: Int
      var soreness: Int
      var energy: Int
      var stress: Int
      var notes: String?
      var updatedAt: Date

      var athlete: Athlete?

      var wellnessScore: Double {
          let sum = Double(sleepQuality + soreness + energy + stress)
          return (sum / 20.0) * 100.0
      }

      init(
          id: UUID = UUID(),
          date: Date = .now,
          sleepQuality: Int = 3,
          soreness: Int = 3,
          energy: Int = 3,
          stress: Int = 3,
          notes: String? = nil
      ) {
          self.id = id
          self.date = date
          self.sleepQuality = sleepQuality
          self.soreness = soreness
          self.energy = energy
          self.stress = stress
          self.notes = notes
          self.updatedAt = .now
      }
  }
  ```

- [ ] **Step 4: Update PersonalRecord**

  Replace the full file content:

  ```swift
  import Foundation
  import SwiftData

  @Model
  final class PersonalRecord {
      @Attribute(.unique) var id: UUID
      var exerciseName: String
      var recordType: PRType
      var value: Double
      var achievedAt: Date
      var sessionId: UUID?
      var previousValue: Double?
      var updatedAt: Date

      var athlete: Athlete?

      var improvement: Double? {
          guard let prev = previousValue, prev > 0 else { return nil }
          return value - prev
      }

      var improvementPercent: Double? {
          guard let prev = previousValue, prev > 0 else { return nil }
          return ((value - prev) / prev) * 100.0
      }

      init(
          id: UUID = UUID(),
          exerciseName: String,
          recordType: PRType = .maxWeight,
          value: Double,
          achievedAt: Date = .now,
          sessionId: UUID? = nil,
          previousValue: Double? = nil
      ) {
          self.id = id
          self.exerciseName = exerciseName
          self.recordType = recordType
          self.value = value
          self.achievedAt = achievedAt
          self.sessionId = sessionId
          self.previousValue = previousValue
          self.updatedAt = .now
      }
  }
  ```

- [ ] **Step 5: Update Athlete.supabaseUserId type**

  `Athlete` already has `createdAt: Date` and `updatedAt: Date` — no changes needed there.

  In `WorkloadApp/Models/Athlete.swift`, change:
  ```swift
  // Before
  var supabaseUserId: String?
  ```
  to:
  ```swift
  // After
  var supabaseUserId: UUID?
  ```

  Also update the init parameter:
  ```swift
  // Before
  supabaseUserId: String? = nil
  // After
  supabaseUserId: UUID? = nil
  ```

- [ ] **Step 6: Build to verify no compile errors**

  Press ⌘B. SwiftData handles the model changes via lightweight migration — no migration file needed.
  Expected: build succeeds.

---

## Task 4: AuthService — Real Supabase Implementation

**Files:**
- Modify: `WorkloadApp/Services/AuthService.swift`

- [ ] **Step 1: Rewrite AuthService**

  Replace the full file content:

  ```swift
  import Foundation
  import Supabase

  /// Wraps Supabase authentication.
  @MainActor
  @Observable
  final class AuthService {

      private let client: SupabaseClient

      init(client: SupabaseClient) {
          self.client = client
      }

      /// Returns the current authenticated user's UUID, or nil if not signed in.
      func currentUserId() async -> UUID? {
          try? await client.auth.session.user.id
      }

      func signUp(email: String, password: String, displayName: String, sportType: String) async throws -> UUID {
          let response = try await client.auth.signUp(
              email: email,
              password: password,
              data: [
                  "display_name": .string(displayName),
                  "sport_type": .string(sportType)
              ]
          )
          guard let userId = response.user?.id else {
              throw AuthError.noUserReturned
          }
          return userId
      }

      func signIn(email: String, password: String) async throws {
          try await client.auth.signIn(email: email, password: password)
      }

      func signOut() async throws {
          try await client.auth.signOut()
      }

      /// Returns true if a valid session exists (checks Keychain — does not make a network request).
      func hasSession() async -> Bool {
          (try? await client.auth.session) != nil
      }

      enum AuthError: LocalizedError {
          case noUserReturned
          var errorDescription: String? {
              switch self {
              case .noUserReturned: return "Sign up succeeded but no user was returned. Please try again."
              }
          }
      }
  }
  ```

- [ ] **Step 2: Skip build — compile errors expected until Task 8**

  Task 4 changes `AuthService.signUp` to require `displayName` and `sportType` params. The existing `SignUpView` calls the old signature and will fail to compile. Task 8 fixes `SignUpView`. Do not build until Task 8 is complete.

---

## Task 5: AppContainer — Supabase Client + Session-Loss Listener

**Files:**
- Modify: `WorkloadApp/App/AppContainer.swift`

- [ ] **Step 1: Rewrite AppContainer**

  Replace the full file content:

  ```swift
  import Foundation
  import SwiftData
  import Supabase

  /// Central dependency container.
  /// Owns the SupabaseClient, AuthService, SyncService, and HealthKitService.
  @MainActor
  @Observable
  final class AppContainer {
      let supabase: SupabaseClient
      let authService: AuthService
      let healthKitService: HealthKitService
      let syncService: SyncService

      private(set) var isAuthenticated = false

      init() {
          let encoder = JSONEncoder()
          encoder.keyEncodingStrategy = .convertToSnakeCase
          encoder.dateEncodingStrategy = .iso8601

          let decoder = JSONDecoder()
          decoder.keyDecodingStrategy = .convertFromSnakeCase
          decoder.dateDecodingStrategy = .iso8601

          // Note: `PostgrestClientOptions` is the correct type in supabase-swift ≥ 2.x.
          // If it doesn't compile, check the SDK version — older releases use `SupabaseClientOptions.DatabaseOptions`.
          let client = SupabaseClient(
              supabaseURL: SupabaseConfig.url,
              supabaseKey: SupabaseConfig.anonKey,
              options: SupabaseClientOptions(
                  db: PostgrestClientOptions(
                      encoder: encoder,
                      decoder: decoder
                  )
              )
          )
          self.supabase = client
          self.authService = AuthService(client: client)
          self.healthKitService = HealthKitService()
          self.syncService = SyncService(client: client)

          // Subscribe to session-loss events only.
          // Sign-in/sign-up transitions set isAuthenticated manually (after sync completes).
          Task {
              for await (event, _) in client.auth.authStateChanges {
                  switch event {
                  case .signedOut, .passwordRecovery:
                      self.isAuthenticated = false
                  default:
                      break
                  }
              }
          }
      }

      /// Called by LoginView and SignUpView after auth + sync complete.
      func setAuthenticated(_ value: Bool) {
          isAuthenticated = value
      }

      /// Sign out: clear Supabase session + wipe local SwiftData via cascade delete.
      /// modelContext is passed from the calling view.
      func signOut(modelContext: ModelContext) async throws {
          try await authService.signOut()
          // Cascade delete: Athlete has deleteRule: .cascade on all relationships
          let athletes = try modelContext.fetch(FetchDescriptor<Athlete>())
          for athlete in athletes {
              modelContext.delete(athlete)
          }
          try modelContext.save()
          // isAuthenticated = false is set by authStateChanges listener above
      }
  }
  ```

- [ ] **Step 2: Skip build — compile errors expected until Task 10**

  Task 5 changes `AppContainer.signOut` to `signOut(modelContext:)` and removes `checkAuthState()`. The existing `ProfileView` calls `container.signOut()` with no arguments and will fail to compile. Task 10 fixes `ProfileView`. Do not build until Task 10 is complete.

---

## Task 6: SyncService — pushAll / pullAll

**Files:**
- Modify: `WorkloadApp/Services/SyncService.swift`

- [ ] **Step 1: Rewrite SyncService**

  Replace the full file content:

  ```swift
  import Foundation
  import SwiftData
  import Supabase

  /// Bidirectional sync between SwiftData (local) and Supabase (cloud).
  /// Strategy: full upsert — no dirty flags. Last-write-wins on updatedAt.
  @MainActor
  struct SyncService {

      private let client: SupabaseClient

      init(client: SupabaseClient) {
          self.client = client
      }

      // MARK: - Public API

      /// Push all local records to Supabase (idempotent upsert by id).
      func pushAll(context: ModelContext) async {
          guard let athlete = try? context.fetch(FetchDescriptor<Athlete>()).first else { return }
          await pushAthlete(athlete)
          await pushWorkloadSnapshots(context: context, athleteId: athlete.id)
          await pushRecoverySnapshots(context: context, athleteId: athlete.id)
          await pushWellnessCheckIns(context: context, athleteId: athlete.id)
          await pushPersonalRecords(context: context, athleteId: athlete.id)
          UserDefaults.standard.set(Date(), forKey: "lastSyncedAt")
      }

      /// Pull all Supabase records for current user and upsert into local SwiftData (last-write-wins).
      func pullAll(context: ModelContext) async {
          guard let athlete = try? context.fetch(FetchDescriptor<Athlete>()).first else { return }
          await pullAthlete(context: context, existingAthlete: athlete)
          await pullWorkloadSnapshots(context: context, athlete: athlete)
          await pullRecoverySnapshots(context: context, athlete: athlete)
          await pullWellnessCheckIns(context: context, athlete: athlete)
          await pullPersonalRecords(context: context, athlete: athlete)
          UserDefaults.standard.set(Date(), forKey: "lastSyncedAt")
      }

      /// Push only WorkloadSnapshot records (called after WorkoutPipeline).
      func pushWorkloadSnapshots(context: ModelContext, athleteId: UUID) async {
          guard let snapshots = try? context.fetch(FetchDescriptor<WorkloadSnapshot>()) else { return }
          let rows = snapshots.map { WorkloadSnapshotRow(from: $0, athleteId: athleteId) }
          _ = try? await client.from("workload_snapshots").upsert(rows).execute()
      }

      /// Push only RecoverySnapshot + WellnessCheckIn (called after RecoveryPipeline).
      func pushRecoveryAndWellness(context: ModelContext, athleteId: UUID) async {
          await pushRecoverySnapshots(context: context, athleteId: athleteId)
          await pushWellnessCheckIns(context: context, athleteId: athleteId)
      }

      /// True if foreground sync should run (>15 min since last sync).
      var shouldForegroundSync: Bool {
          guard let last = UserDefaults.standard.object(forKey: "lastSyncedAt") as? Date else { return true }
          return Date().timeIntervalSince(last) > 15 * 60
      }

      // MARK: - Athlete push/pull

      /// Fetches the athlete profile from Supabase and creates it locally.
      /// Called on first sign-in to a fresh device (no local Athlete exists yet).
      /// Returns the newly-created local Athlete, or nil if not found.
      func bootstrapAthlete(context: ModelContext, userId: UUID) async -> Athlete? {
          guard let row: AthleteRow = try? await client
              .from("athletes")
              .select()
              .eq("user_id", value: userId)
              .single()
              .execute()
              .value
          else { return nil }
          let athlete = Athlete(
              id: row.id,
              displayName: row.displayName ?? "",
              sportType: SportType(rawValue: row.sportType ?? "") ?? .other
          )
          athlete.supabaseUserId = row.userId
          athlete.updatedAt = row.updatedAt
          context.insert(athlete)
          try? context.save()
          return athlete
      }

      func pushAthlete(_ athlete: Athlete) async {
          guard let userId = athlete.supabaseUserId else { return }
          let row = AthleteRow(
              id: athlete.id,
              userId: userId,
              displayName: athlete.displayName,
              sportType: athlete.sportType.rawValue,
              weightUnit: athlete.weightUnit.rawValue,
              acwrMethod: athlete.acwrMethod.rawValue,
              loadMetricPreference: athlete.loadMetricPreference.rawValue,
              maxHeartRate: athlete.maxHeartRate,
              dateOfBirth: athlete.dateOfBirth,
              createdAt: athlete.createdAt,
              updatedAt: athlete.updatedAt
          )
          _ = try? await client.from("athletes").upsert(row).execute()
      }

      private func pullAthlete(context: ModelContext, existingAthlete: Athlete) async {
          guard let userId = existingAthlete.supabaseUserId else { return }
          guard let row: AthleteRow = try? await client
              .from("athletes")
              .select()
              .eq("user_id", value: userId)
              .single()
              .execute()
              .value
          else { return }
          // last-write-wins
          if existingAthlete.updatedAt > row.updatedAt { return }
          existingAthlete.displayName = row.displayName ?? existingAthlete.displayName
          existingAthlete.updatedAt = row.updatedAt
          try? context.save()
      }

      // MARK: - Push helpers

      private func pushRecoverySnapshots(context: ModelContext, athleteId: UUID) async {
          guard let snapshots = try? context.fetch(FetchDescriptor<RecoverySnapshot>()) else { return }
          let rows = snapshots.map { RecoverySnapshotRow(from: $0, athleteId: athleteId) }
          _ = try? await client.from("recovery_snapshots").upsert(rows).execute()
      }

      private func pushWellnessCheckIns(context: ModelContext, athleteId: UUID) async {
          guard let checkIns = try? context.fetch(FetchDescriptor<WellnessCheckIn>()) else { return }
          let rows = checkIns.map { WellnessCheckInRow(from: $0, athleteId: athleteId) }
          _ = try? await client.from("wellness_check_ins").upsert(rows).execute()
      }

      private func pushPersonalRecords(context: ModelContext, athleteId: UUID) async {
          guard let prs = try? context.fetch(FetchDescriptor<PersonalRecord>()) else { return }
          let rows = prs.map { PersonalRecordRow(from: $0, athleteId: athleteId) }
          _ = try? await client.from("personal_records").upsert(rows).execute()
      }

      // MARK: - Pull helpers

      private func pullWorkloadSnapshots(context: ModelContext, athlete: Athlete) async {
          guard let rows: [WorkloadSnapshotRow] = try? await client
              .from("workload_snapshots")
              .select()
              .eq("athlete_id", value: athlete.id)
              .execute()
              .value
          else { return }

          for row in rows {
              let pred = #Predicate<WorkloadSnapshot> { $0.id == row.id }
              let existing = try? context.fetch(FetchDescriptor(predicate: pred)).first
              if let existing, existing.updatedAt > row.updatedAt { continue }
              let snap = existing ?? WorkloadSnapshot()
              snap.id = row.id
              snap.snapshotDate = row.snapshotDate
              snap.acuteLoad = row.acuteLoad ?? 0
              snap.chronicLoad = row.chronicLoad ?? 0
              snap.acwr = row.acwr ?? 0
              snap.tsb = row.tsb ?? 0
              snap.weeklyVolume = row.weeklyVolume ?? 0
              snap.loadSource = LoadSource(rawValue: row.loadSource ?? "") ?? .srpe
              snap.updatedAt = row.updatedAt
              snap.athlete = athlete
              if existing == nil { context.insert(snap) }
          }
          try? context.save()
      }

      private func pullRecoverySnapshots(context: ModelContext, athlete: Athlete) async {
          guard let rows: [RecoverySnapshotRow] = try? await client
              .from("recovery_snapshots")
              .select()
              .eq("athlete_id", value: athlete.id)
              .execute()
              .value
          else { return }

          for row in rows {
              let pred = #Predicate<RecoverySnapshot> { $0.id == row.id }
              let existing = try? context.fetch(FetchDescriptor(predicate: pred)).first
              if let existing, existing.updatedAt > row.updatedAt { continue }
              let snap = existing ?? RecoverySnapshot()
              snap.id = row.id
              snap.date = row.date
              snap.hrvSDNN = row.hrvSdnn
              snap.restingHR = row.restingHr
              snap.sleepDurationMinutes = row.sleepDurationMinutes
              snap.sleepScore = row.sleepScore
              snap.bodyTemp = row.bodyTemp
              snap.vo2Max = row.vo2Max
              snap.recoveryScore = row.recoveryScore ?? 50
              snap.hrvBaseline = row.hrvBaseline
              snap.restingHRBaseline = row.restingHrBaseline
              snap.dataSource = RecoveryDataSource(rawValue: row.dataSource ?? "") ?? .healthKit
              snap.updatedAt = row.updatedAt
              snap.athlete = athlete
              if existing == nil { context.insert(snap) }
          }
          try? context.save()
      }

      private func pullWellnessCheckIns(context: ModelContext, athlete: Athlete) async {
          guard let rows: [WellnessCheckInRow] = try? await client
              .from("wellness_check_ins")
              .select()
              .eq("athlete_id", value: athlete.id)
              .execute()
              .value
          else { return }

          for row in rows {
              let pred = #Predicate<WellnessCheckIn> { $0.id == row.id }
              let existing = try? context.fetch(FetchDescriptor(predicate: pred)).first
              if let existing, existing.updatedAt > row.updatedAt { continue }
              let checkIn = existing ?? WellnessCheckIn()
              checkIn.id = row.id
              checkIn.date = row.date
              checkIn.sleepQuality = row.sleepQuality ?? 3
              checkIn.soreness = row.soreness ?? 3
              checkIn.energy = row.energy ?? 3
              checkIn.stress = row.stress ?? 3
              checkIn.notes = row.notes
              checkIn.updatedAt = row.updatedAt
              checkIn.athlete = athlete
              if existing == nil { context.insert(checkIn) }
          }
          try? context.save()
      }

      private func pullPersonalRecords(context: ModelContext, athlete: Athlete) async {
          guard let rows: [PersonalRecordRow] = try? await client
              .from("personal_records")
              .select()
              .eq("athlete_id", value: athlete.id)
              .execute()
              .value
          else { return }

          for row in rows {
              let pred = #Predicate<PersonalRecord> { $0.id == row.id }
              let existing = try? context.fetch(FetchDescriptor(predicate: pred)).first
              if let existing, existing.updatedAt > row.updatedAt { continue }
              let pr = existing ?? PersonalRecord(exerciseName: row.exerciseName ?? "", value: row.value ?? 0)
              pr.id = row.id
              pr.exerciseName = row.exerciseName ?? ""
              pr.recordType = PRType(rawValue: row.recordType ?? "") ?? .maxWeight
              pr.value = row.value ?? 0
              pr.previousValue = row.previousValue
              pr.sessionId = row.sessionId
              pr.achievedAt = row.achievedAt ?? .now
              pr.updatedAt = row.updatedAt
              pr.athlete = athlete
              if existing == nil { context.insert(pr) }
          }
          try? context.save()
      }
  }

  // MARK: - Codable Row Types (snake_case ↔ camelCase)

  struct AthleteRow: Codable {
      let id: UUID
      let userId: UUID
      let displayName: String?
      let sportType: String?
      let weightUnit: String?
      let acwrMethod: String?
      let loadMetricPreference: String?
      let maxHeartRate: Int?
      let dateOfBirth: Date?
      let createdAt: Date
      let updatedAt: Date
  }

  struct WorkloadSnapshotRow: Codable {
      let id: UUID
      let athleteId: UUID
      let snapshotDate: Date
      let acuteLoad: Double?
      let chronicLoad: Double?
      let acwr: Double?
      let tsb: Double?
      let weeklyVolume: Double?
      let loadSource: String?
      let updatedAt: Date

      init(from model: WorkloadSnapshot, athleteId: UUID) {
          self.id = model.id
          self.athleteId = athleteId
          self.snapshotDate = model.snapshotDate
          self.acuteLoad = model.acuteLoad
          self.chronicLoad = model.chronicLoad
          self.acwr = model.acwr
          self.tsb = model.tsb
          self.weeklyVolume = model.weeklyVolume
          self.loadSource = model.loadSource.rawValue
          self.updatedAt = model.updatedAt
      }
  }

  struct RecoverySnapshotRow: Codable {
      let id: UUID
      let athleteId: UUID
      let date: Date
      let recoveryScore: Double?
      let hrvSdnn: Double?
      let restingHr: Double?
      let sleepDurationMinutes: Double?
      let sleepScore: Double?
      let bodyTemp: Double?
      let vo2Max: Double?
      let hrvBaseline: Double?
      let restingHrBaseline: Double?
      let dataSource: String?
      let updatedAt: Date

      init(from model: RecoverySnapshot, athleteId: UUID) {
          self.id = model.id
          self.athleteId = athleteId
          self.date = model.date
          self.recoveryScore = model.recoveryScore
          self.hrvSdnn = model.hrvSDNN
          self.restingHr = model.restingHR
          self.sleepDurationMinutes = model.sleepDurationMinutes
          self.sleepScore = model.sleepScore
          self.bodyTemp = model.bodyTemp
          self.vo2Max = model.vo2Max
          self.hrvBaseline = model.hrvBaseline
          self.restingHrBaseline = model.restingHRBaseline
          self.dataSource = model.dataSource.rawValue
          self.updatedAt = model.updatedAt
      }
  }

  struct WellnessCheckInRow: Codable {
      let id: UUID
      let athleteId: UUID
      let date: Date
      let sleepQuality: Int?
      let soreness: Int?
      let energy: Int?
      let stress: Int?
      let notes: String?
      let updatedAt: Date

      init(from model: WellnessCheckIn, athleteId: UUID) {
          self.id = model.id
          self.athleteId = athleteId
          self.date = model.date
          self.sleepQuality = model.sleepQuality
          self.soreness = model.soreness
          self.energy = model.energy
          self.stress = model.stress
          self.notes = model.notes
          self.updatedAt = model.updatedAt
      }
  }

  struct PersonalRecordRow: Codable {
      let id: UUID
      let athleteId: UUID
      let exerciseName: String?
      let recordType: String?
      let value: Double?
      let previousValue: Double?
      let sessionId: UUID?
      let achievedAt: Date?
      let updatedAt: Date

      init(from model: PersonalRecord, athleteId: UUID) {
          self.id = model.id
          self.athleteId = athleteId
          self.exerciseName = model.exerciseName
          self.recordType = model.recordType.rawValue
          self.value = model.value
          self.previousValue = model.previousValue
          self.sessionId = model.sessionId
          self.achievedAt = model.achievedAt
          self.updatedAt = model.updatedAt
      }
  }
  ```

- [ ] **Step 2: Build to verify**

  Press ⌘B. Expected: builds cleanly.

---

## Task 7: AppRouter — Auth-Gated Routing

**Files:**
- Modify: `WorkloadApp/App/AppRouter.swift`

- [ ] **Step 1: Rewrite AppRouter**

  Replace the full file content:

  ```swift
  import SwiftUI
  import SwiftData

  struct AppRouter: View {
      @State private var container = AppContainer()
      @State private var isCheckingSession = true
      @Environment(\.modelContext) private var modelContext

      var body: some View {
          Group {
              if isCheckingSession {
                  ProgressView("Loading...")
              } else if !container.isAuthenticated {
                  LoginView()
              } else {
                  MainTabView()
              }
          }
          .environment(container)
          .task {
              // Check Keychain for existing session
              let hasSession = await container.authService.hasSession()
              if hasSession {
                  // Session exists — sync if stale, then show app
                  if container.syncService.shouldForegroundSync {
                      await container.syncService.pullAll(context: modelContext)
                  }
                  container.setAuthenticated(true)
              }
              isCheckingSession = false
          }
          .onChange(of: container.isAuthenticated) { _, isAuth in
              // When session is lost (authStateChanges fires), isCheckingSession stays false
              // and the body re-evaluates to show LoginView
              _ = isAuth
          }
      }
  }

  struct MainTabView: View {
      @Environment(AppContainer.self) private var container
      @Environment(\.modelContext) private var modelContext
      @Environment(\.scenePhase) private var scenePhase

      var body: some View {
          TabView {
              DashboardView()
                  .tabItem { Label("Home", systemImage: "house.fill") }
              WorkoutLogView()
                  .tabItem { Label("Log", systemImage: "list.bullet.clipboard.fill") }
              RecoveryView()
                  .tabItem { Label("Recovery", systemImage: "heart.fill") }
              WorkloadView()
                  .tabItem { Label("Load", systemImage: "chart.line.uptrend.xyaxis") }
              ProfileView()
                  .tabItem { Label("Profile", systemImage: "person.fill") }
          }
          .onChange(of: scenePhase) { _, newPhase in
              if newPhase == .active && container.syncService.shouldForegroundSync {
                  Task {
                      await container.syncService.pushAll(context: modelContext)
                      await container.syncService.pullAll(context: modelContext)
                  }
              }
          }
      }
  }
  ```

- [ ] **Step 2: Build to verify**

  Press ⌘B. Expected: builds cleanly.

---

## Task 8: SignUpView — Real Sign-Up Flow

**Files:**
- Modify: `WorkloadApp/Views/Auth/SignUpView.swift`

- [ ] **Step 1: Update the signUp() method**

  Replace the `signUp()` function in `SignUpView.swift`:

  ```swift
  private func signUp() async {
      isLoading = true
      errorMessage = nil
      do {
          // 1. Create Supabase auth user
          let userId = try await container.authService.signUp(
              email: email,
              password: password,
              displayName: displayName,
              sportType: selectedSport.rawValue
          )

          // 2. Create Athlete locally
          let athleteId = UUID()
          let athlete = Athlete(
              id: athleteId,
              displayName: displayName,
              sportType: selectedSport,
              supabaseUserId: userId
          )
          modelContext.insert(athlete)
          try modelContext.save()

          // 3. Push athlete profile to Supabase
          // AthleteRow is defined in SyncService.swift — reuse it here
          await container.syncService.pushAthlete(athlete)

          // 4. Mark as authenticated
          container.setAuthenticated(true)
      } catch {
          errorMessage = error.localizedDescription
      }
      isLoading = false
  }
  ```

  Note: `AthleteRow` is defined in `SyncService.swift` and is internal to the module — no need to redeclare it here.

- [ ] **Step 2: Build to verify**

  Press ⌘B. Expected: builds cleanly.

---

## Task 9: LoginView — Real Sign-In Flow

**Files:**
- Modify: `WorkloadApp/Views/Auth/LoginView.swift`

- [ ] **Step 1: Add modelContext and update signIn()**

  In `LoginView`, add `@Environment(\.modelContext) private var modelContext` alongside the existing environment properties.

  Replace the `signIn()` function:

  ```swift
  private func signIn() async {
      isLoading = true
      errorMessage = nil
      do {
          // 1. Authenticate
          try await container.authService.signIn(email: email, password: password)

          // 2. Bootstrap local Athlete if not present (fresh install / new device)
          let localAthletes = try? modelContext.fetch(FetchDescriptor<Athlete>())
          if localAthletes?.isEmpty != false,
             let userId = await container.authService.currentUserId() {
              _ = await container.syncService.bootstrapAthlete(
                  context: modelContext,
                  userId: userId
              )
          }

          // 3. Populate local store from Supabase (requires local Athlete to be present)
          await container.syncService.pullAll(context: modelContext)

          // 4. Mark as authenticated (after sync — no race condition)
          container.setAuthenticated(true)
      } catch {
          errorMessage = error.localizedDescription
      }
      isLoading = false
  }
  ```

- [ ] **Step 2: Build to verify**

  Press ⌘B. Expected: builds cleanly.

---

## Task 10: ProfileView — Sign Out with Cascade Delete

**Files:**
- Modify: `WorkloadApp/Views/Profile/ProfileView.swift`

- [ ] **Step 1: Add modelContext and update sign-out button**

  Add `@Environment(\.modelContext) private var modelContext` to `ProfileView`.

  Replace the sign-out button action:

  ```swift
  Button("Sign Out", role: .destructive) {
      Task {
          try? await container.signOut(modelContext: modelContext)
      }
  }
  ```

- [ ] **Step 2: Build to verify**

  Press ⌘B. Expected: builds cleanly.

---

## Task 11: Pipeline Sync Triggers

**Files:**
- Modify: `WorkloadApp/Services/WorkoutPipeline.swift`
- Modify: `WorkloadApp/Services/RecoveryPipeline.swift`

The pipelines are called from view layer (`ActiveWorkoutSheet`, `DashboardViewModel`). They don't have access to `AppContainer` directly — pass `SyncService` in as a parameter.

- [ ] **Step 1: Update WorkoutPipeline.processSession signature**

  Add `syncService: SyncService?` as an optional parameter (optional so callers that don't need sync — like tests — don't need to provide it):

  ```swift
  static func processSession(
      _ session: WorkoutSession,
      athlete: Athlete,
      modelContext: ModelContext,
      syncService: SyncService? = nil
  ) throws -> PipelineResult {
      // ... existing implementation ...

      // At the very end, before return:
      if let syncService {
          let athleteId = athlete.id
          Task {
              await syncService.pushWorkloadSnapshots(context: modelContext, athleteId: athleteId)
          }
      }

      return PipelineResult(snapshot: latestResult, newPRs: newPRs, weeklyVolume: weeklyVol)
  }
  ```

- [ ] **Step 2: Update RecoveryPipeline.run signature**

  Add `syncService: SyncService?` as an optional parameter:

  ```swift
  static func run(
      athlete: Athlete,
      healthKitService: HealthKitService,
      modelContext: ModelContext,
      syncService: SyncService? = nil
  ) async throws -> RecoveryResult {
      // ... existing implementation ...

      // At the very end, before return:
      if let syncService {
          let athleteId = athlete.id
          Task {
              await syncService.pushRecoveryAndWellness(context: modelContext, athleteId: athleteId)
          }
      }

      return RecoveryResult(score: result.score, zone: result.zone, snapshot: result)
  }
  ```

- [ ] **Step 3: Pass syncService at all call sites**

  **`WorkoutLogViewModel.swift`** — add `syncService` parameter to `onSessionSaved`:

  ```swift
  func onSessionSaved(
      session: WorkoutSession,
      athlete: Athlete,
      modelContext: ModelContext,
      syncService: SyncService? = nil
  ) {
      do {
          let result = try WorkoutPipeline.processSession(
              session,
              athlete: athlete,
              modelContext: modelContext,
              syncService: syncService
          )
          if !result.newPRs.isEmpty {
              newPRs = result.newPRs
              showPRCelebration = true
          }
      } catch {
          print("Workout pipeline error: \(error)")
      }
  }
  ```

  **`ActiveWorkoutSheet.swift`** — find the call to `viewModel.onSessionSaved(...)` (or the direct `WorkoutPipeline.processSession(...)` call) and add `syncService: container.syncService`:

  ```swift
  viewModel.onSessionSaved(
      session: session,
      athlete: athlete,
      modelContext: modelContext,
      syncService: container.syncService
  )
  ```

  **`DashboardViewModel.swift`** — add `syncService` parameter to `load()`:

  ```swift
  func load(
      athlete: Athlete,
      healthKitService: HealthKitService,
      modelContext: ModelContext,
      syncService: SyncService? = nil
  ) async {
  ```

  Inside `load()`, update the `RecoveryPipeline.run(...)` call to pass `syncService`:

  ```swift
  let recoveryResult = try await RecoveryPipeline.run(
      athlete: athlete,
      healthKitService: healthKitService,
      modelContext: modelContext,
      syncService: syncService
  )
  ```

  **`DashboardView.swift`** — update `loadData()` to pass `container.syncService`:

  ```swift
  private func loadData() async {
      guard let athlete else { return }
      await viewModel.load(
          athlete: athlete,
          healthKitService: container.healthKitService,
          modelContext: modelContext,
          syncService: container.syncService
      )
  }
  ```

- [ ] **Step 4: Build to verify**

  Press ⌘B. Expected: builds cleanly.

---

## Task 12: Remove OnboardingView

**Files:**
- Delete: `WorkloadApp/Views/Onboarding/OnboardingView.swift`

- [ ] **Step 1: Remove from Xcode target**

  In Xcode Navigator, right-click `OnboardingView.swift` → Delete → Move to Trash.

- [ ] **Step 2: Build to verify no remaining references**

  Press ⌘B. If there are compile errors referencing `OnboardingView`, remove those references (the only caller was `AppRouter` which has been rewritten).
  Expected: builds cleanly.

---

## Task 13: End-to-End Manual Test

- [ ] **Step 1: Test sign-up**

  Run app on simulator. Tap "Create an account". Fill in name, email, password, sport. Tap "Create Account".
  Expected: app transitions to `MainTabView` (Dashboard).

- [ ] **Step 2: Verify athlete in Supabase**

  In Supabase dashboard → Table Editor → athletes.
  Expected: one row with correct display_name and sport_type.

- [ ] **Step 3: Test sign-out**

  In Profile tab, tap "Sign Out".
  Expected: app returns to `LoginView`.

- [ ] **Step 4: Test sign-in**

  Enter credentials from step 1. Tap "Sign In".
  Expected: app transitions to `MainTabView`.

- [ ] **Step 5: Test session persistence**

  Force-quit app and relaunch.
  Expected: app goes directly to `MainTabView` without showing `LoginView` (Keychain session restored).

- [ ] **Step 6: Verify sync round-trip**

  Log a workout (to generate a WorkloadSnapshot). Force-quit. Relaunch.
  In Supabase dashboard → workload_snapshots: verify the row exists.

---

## Task 14: Sign-Up Resilience — Missing Athlete Row Detection

**Files:**
- Modify: `WorkloadApp/App/AppRouter.swift`

If the athlete row insert in `SignUpView` fails silently (network error), the user has a valid session but no Supabase athlete profile. Add a check on session restore:

- [ ] **Step 1: Add athlete row check to AppRouter.task**

  In `AppRouter.task`, after `pullAll`, check if the local store has an athlete. If the session exists but no athlete was pulled, it means the row was never created — retry the insert:

  ```swift
  .task {
      let hasSession = await container.authService.hasSession()
      if hasSession {
          if container.syncService.shouldForegroundSync {
              await container.syncService.pullAll(context: modelContext)
          }
          // Check for missing athlete row (sign-up resilience)
          let athletes = try? modelContext.fetch(FetchDescriptor<Athlete>())
          if athletes?.isEmpty == true {
              // Session exists but no profile — sign out and show LoginView with a message
              try? await container.authService.signOut()
              isCheckingSession = false
              return
          }
          container.setAuthenticated(true)
      }
      isCheckingSession = false
  }
  ```

- [ ] **Step 2: Build and verify**

  Press ⌘B. Expected: builds cleanly.

---

## Done

At this point Phase 2 is complete:
- Users must sign in with email/password to use the app
- Sessions persist via Keychain across app restarts
- All computed scores sync to Supabase automatically
- Sign-out clears all local data, preventing cross-user bleed
- App works fully offline; Supabase sync is a silent background operation
