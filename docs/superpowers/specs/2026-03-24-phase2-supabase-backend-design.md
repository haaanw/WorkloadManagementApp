# Phase 2: Supabase Backend Design

**Date:** 2026-03-24
**Project:** WorkloadApp (iOS, SwiftUI + SwiftData)
**Scope:** Auth, cloud sync, PostgreSQL schema

---

## Overview

Phase 2 adds real user accounts (email/password via Supabase Auth) and cloud sync for computed scores. The local SwiftData layer remains the UI source of truth; Supabase is the sync/backup layer underneath it.

**In scope:**
- Supabase project setup (new project, credentials, schema)
- Email/password authentication (sign up, sign in, sign out)
- Cloud sync for: `Athlete`, `WorkloadSnapshot`, `RecoverySnapshot`, `WellnessCheckIn`, `PersonalRecord`
- Row-level security on all tables
- Removal of `isSynced` flag from all models (replaced by full-upsert strategy)

**Out of scope (deferred):**
- Google Sign-In (Phase 2b)
- Sync for `WorkoutSession`, `ExerciseEntry`, `SetRecord` (Phase 3)
- Delete sync / tombstones (Phase 3, when delete UI ships)

---

## Architecture

Four areas of change:

1. **Supabase SDK** — add `supabase-swift` via Xcode SPM integration (File → Add Package Dependencies); shared `SupabaseClient` instance in `AppContainer`
2. **Auth** — `AuthService` gets real implementation; `AppRouter` gates on `isAuthenticated`; reactive session via `onAuthStateChange` stream
3. **Schema** — 5 Supabase tables with row-level security; no Postgres trigger (client creates athlete row explicitly after signup)
4. **Sync** — `SyncService` full-upsert strategy with last-write-wins, throttled foreground sync, pipeline triggers

---

## Database Schema

All tables use UUID primary keys matching local SwiftData `id` fields, enabling idempotent upserts. Column names use snake_case mapping to Swift camelCase properties.

```sql
-- User profile
athletes (
  id                     uuid PRIMARY KEY,
  user_id                uuid REFERENCES auth.users NOT NULL,
  display_name           text,
  sport_type             text,
  weight_unit            text,
  acwr_method            text,
  load_metric_preference text,
  max_heart_rate         int,
  date_of_birth          date,
  created_at             timestamptz,
  updated_at             timestamptz
)

-- Computed workload metrics (ATL, CTL, ACWR, TSB)
workload_snapshots (
  id            uuid PRIMARY KEY,
  athlete_id    uuid REFERENCES athletes NOT NULL,
  snapshot_date date NOT NULL,
  acute_load    double precision,
  chronic_load  double precision,
  acwr          double precision,
  tsb           double precision,
  weekly_volume double precision,
  load_source   text,
  updated_at    timestamptz
)

-- Computed recovery scores
recovery_snapshots (
  id                     uuid PRIMARY KEY,
  athlete_id             uuid REFERENCES athletes NOT NULL,
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
  updated_at             timestamptz
)

-- Daily wellness check-ins
wellness_check_ins (
  id            uuid PRIMARY KEY,
  athlete_id    uuid REFERENCES athletes NOT NULL,
  date          date NOT NULL,
  sleep_quality int,
  soreness      int,
  energy        int,
  stress        int,
  notes         text,
  updated_at    timestamptz
)

-- Personal records
personal_records (
  id             uuid PRIMARY KEY,
  athlete_id     uuid REFERENCES athletes NOT NULL,
  exercise_name  text,
  record_type    text,
  value          double precision,
  previous_value double precision,
  session_id     uuid,
  achieved_at    timestamptz,
  updated_at     timestamptz
)
```

### Row-Level Security

All tables have both `USING` (read) and `WITH CHECK` (write) clauses to prevent cross-user data insertion.

```sql
-- athletes: owner only
ALTER TABLE athletes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "athletes_owner" ON athletes
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- workload_snapshots
ALTER TABLE workload_snapshots ENABLE ROW LEVEL SECURITY;
CREATE POLICY "workload_snapshots_owner" ON workload_snapshots
  USING (athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid()))
  WITH CHECK (athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid()));

-- recovery_snapshots (same pattern)
ALTER TABLE recovery_snapshots ENABLE ROW LEVEL SECURITY;
CREATE POLICY "recovery_snapshots_owner" ON recovery_snapshots
  USING (athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid()))
  WITH CHECK (athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid()));

-- wellness_check_ins (same pattern)
ALTER TABLE wellness_check_ins ENABLE ROW LEVEL SECURITY;
CREATE POLICY "wellness_check_ins_owner" ON wellness_check_ins
  USING (athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid()))
  WITH CHECK (athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid()));

-- personal_records (same pattern)
ALTER TABLE personal_records ENABLE ROW LEVEL SECURITY;
CREATE POLICY "personal_records_owner" ON personal_records
  USING (athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid()))
  WITH CHECK (athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid()));
```

**Note:** The Supabase anon key is included in the app binary by design. Supabase anon keys are intended to be public — RLS is the security boundary, not key secrecy.

---

## Auth Flow

### Email Confirmation

Email confirmation is **disabled** in Supabase project settings for Phase 2 (Auth → Providers → Email → "Confirm email" toggle off). This simplifies the sign-up flow: the user gets a session immediately after signing up. Email confirmation can be re-enabled in Phase 5 (App Store readiness).

### Session Management

`AppContainer` subscribes to `supabase.auth.authStateChanges` for **session loss only** (expiry, remote revocation, sign-out). It does NOT use `authStateChanges` to trigger the transition to `MainTabView` — that would race against `pullAll()`.

Active sign-in and sign-up set `isAuthenticated` manually after all steps (auth + sync) complete. This eliminates the race condition where `MainTabView` renders against an empty SwiftData store.

```swift
// In AppContainer — only handles session loss
Task {
    for await (event, _) in supabase.auth.authStateChanges {
        switch event {
        case .signedOut, .passwordRecovery:
            isAuthenticated = false
        default:
            break  // sign-in transitions are handled explicitly in LoginView/SignUpView
        }
    }
}
```

### `ModelContext` at Auth Call Sites

`LoginView` and `SignUpView` obtain `ModelContext` via `@Environment(\.modelContext)` (standard SwiftUI pattern). They pass it directly to `SyncService.pullAll(context:)` after auth completes. `AppContainer` does not hold a `ModelContext`.

### AppRouter Logic

`AppRouter` drops the `@Query athletes` check entirely. Routing is driven by `container.isAuthenticated` only.

```
App launch
  └─ Check supabase.auth.session (one-time, synchronous Keychain read)
       ├─ No session → LoginView
       │     ├─ Sign up (in SignUpView, has @Environment(\.modelContext)):
       │     │   1. supabase.auth.signUp(email, password)  → userId: UUID
       │     │   2. Insert athletes row into Supabase (athlete.id = new UUID(), user_id = userId)
       │     │   3. Create local Athlete in SwiftData with same UUID
       │     │   4. container.isAuthenticated = true → MainTabView
       │     │
       │     └─ Sign in (in LoginView, has @Environment(\.modelContext)):
       │         1. supabase.auth.signIn(email, password)
       │         2. SyncService.pullAll(context: modelContext)  ← populates local store
       │         3. container.isAuthenticated = true → MainTabView
       │
       └─ Session exists (Keychain) → perform pullAll if > 15 min stale, then MainTabView
```

**Sign-up resilience:** If step 2 (athlete row insert) fails due to network error, on next launch the app detects a missing Supabase athlete row and retries the insert before setting `isAuthenticated = true`. This prevents zombie auth accounts.

### Sign-Out Sequence

```
Sign out
  └─ supabase.auth.signOut()
  └─ Delete ALL local SwiftData (Athlete + all related records via cascade delete)
  └─ isAuthenticated = false → LoginView
```

Local data is fully cleared on sign-out via a single cascade delete:

```swift
// In AppContainer.signOut(), called from ProfileView
// modelContext passed in from the view layer
if let athlete = try? modelContext.fetch(FetchDescriptor<Athlete>()).first {
    modelContext.delete(athlete)  // cascade: deletes all related snapshots, check-ins, PRs
    try? modelContext.save()
}
```

This relies on the existing `deleteRule: .cascade` relationships on `Athlete`. No need to enumerate and delete each table individually. Safe because Supabase is the source of truth after Phase 2.

### OnboardingView

`OnboardingView` is **retired** in Phase 2. Its two responsibilities move to:
- Name + sport type → already in `SignUpView`
- HealthKit permissions → remains as the `EmptyStateCard` prompt on the dashboard (already implemented)

---

## Model Changes

### Remove `isSynced` from all synced models

The full-upsert sync strategy makes `isSynced` redundant. Remove it from:
- `WorkloadSnapshot`
- `RecoverySnapshot`
- `WellnessCheckIn`
- `PersonalRecord`

SwiftData handles field removal with lightweight migration automatically (deleted properties are ignored).

### Add `updatedAt` to models that lack it

- `WellnessCheckIn` — add `var updatedAt: Date`
- `PersonalRecord` — add `var updatedAt: Date`

`WorkloadSnapshot` and `RecoverySnapshot` do **not** currently have `updatedAt` — add it to both as well.

### `Athlete.supabaseUserId` type

Change `supabaseUserId: String?` → `supabaseUserId: UUID?` to match Supabase's `UUID` type. The Supabase Swift SDK returns `user.id` as a `UUID`.

---

## Sync

### Strategy: Full Upsert

Every sync pushes all local records for the current user to Supabase and pulls all Supabase records back. No `isSynced` dirty flag. Works because:
- Data volumes are tiny (worst case ~365 rows/year per table, ~5 tables = ~1825 rows total after a full year)
- All records have stable UUID `id` fields; upserts are idempotent
- `updatedAt` on every record handles last-write-wins

### `SyncService` Concurrency

`SyncService` is refactored from `actor` to `@MainActor struct` to match the CLAUDE.md pipeline convention. `ModelContext` is passed per-call (same pattern as `WorkoutPipeline` and `RecoveryPipeline`).

### Last-Write-Wins (pullAll)

Before overwriting a local record during pull, compare `updatedAt`:

```
for each remote record:
  fetch local record by id from SwiftData
  if local exists AND local.updatedAt > remote.updatedAt:
    skip (local is newer — offline edit wins)
  else:
    upsert remote into SwiftData
```

### Trigger Points

| Trigger | Operation |
|---------|-----------|
| Sign-in | `pullAll` — populate clean local store |
| App foreground (`scenePhase == .active`) | `pushAll` then `pullAll` — throttled to once per 15 minutes |
| After `WorkoutPipeline.processSession()` | `pushAll(WorkloadSnapshot)` |
| After `RecoveryPipeline.run()` | `pushAll(RecoverySnapshot, WellnessCheckIn)` |

### Throttle

`lastSyncedAt: Date?` stored in `UserDefaults`. Foreground sync skips if `now - lastSyncedAt < 15 minutes`. Post-pipeline pushes always fire regardless of throttle.

### Error Handling

- Sync failures are silent — local SwiftData always works offline
- Errors logged via `print` but not surfaced to the user
- No retry logic — next trigger point handles recovery naturally

### Known Limitation: No Delete Sync

Sync handles inserts and updates only. The app has no delete UI in Phase 2, so no local deletes occur in practice. Soft-delete tombstones (`deletedAt: Date?`) will be added in Phase 3 when delete UI ships.

---

## Credentials

Supabase URL and anon key stored in `Config/SupabaseConfig.swift`. This file is **gitignored**. A committed `Config/SupabaseConfig.example.swift` serves as a template with placeholder values.

**Build requirement:** Any developer (or CI environment) must copy the example file, rename it, and fill in real values before the project will compile. CI injects values via environment variables at build time.

---

## Files Changed

| File | Change |
|------|--------|
| Xcode SPM (project.pbxproj + Package.resolved) | Add `supabase-swift` via File → Add Package Dependencies |
| `Config/SupabaseConfig.swift` | New (gitignored) — Supabase URL + anon key |
| `Config/SupabaseConfig.example.swift` | New (committed) — placeholder template |
| `App/WorkloadApp.swift` | Minor: ensure ModelContainer setup is compatible with new auth flow |
| `App/AppContainer.swift` | Add `SupabaseClient`, `SyncService`; subscribe to `authStateChanges` |
| `App/AppRouter.swift` | Gate on `isAuthenticated`; remove `@Query athletes` |
| `Services/AuthService.swift` | Real Supabase implementation |
| `Services/SyncService.swift` | Refactor from `actor` to `@MainActor struct`; real pushAll / pullAll |
| `Services/WorkoutPipeline.swift` | Call `SyncService.pushAll(WorkloadSnapshot)` after processSession |
| `Services/RecoveryPipeline.swift` | Call `SyncService.pushAll(RecoverySnapshot, WellnessCheckIn)` after run |
| `Models/WorkloadSnapshot.swift` | Remove `isSynced`; add `updatedAt` |
| `Models/RecoverySnapshot.swift` | Remove `isSynced`; add `updatedAt` |
| `Models/WellnessCheckIn.swift` | Remove `isSynced`; add `updatedAt` |
| `Models/PersonalRecord.swift` | Remove `isSynced`; add `updatedAt` |
| `Models/Athlete.swift` | Change `supabaseUserId: String?` → `UUID?` |
| `Views/Auth/SignUpView.swift` | Pass display_name + sport_type in signup metadata; fetch athlete after signup |
| `Views/Onboarding/OnboardingView.swift` | **Removed** — replaced by SignUpView + dashboard HealthKit prompt |
