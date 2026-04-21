# Codebase Concerns

**Analysis Date:** 2026-04-20

## Tech Debt

**Silent error suppression in SyncService:**
- Issue: Extensive use of `try?` with underscore (`_ = try?`) and `try?` in async operations silently swallows network/data errors
- Files: `WorkloadApp/Services/SyncService.swift` (lines 20, 34, 48, 50, 71, 88, 108, etc.)
- Impact: Sync failures go unlogged and untracked. Users may believe data was uploaded when it failed silently. No visibility into sync health. Difficult to debug user-reported inconsistencies.
- Fix approach: Log all sync failures to console/analytics. Maintain sync state indicators (success/fail/pending). Surface critical failures to user via status badge on app. Consider implementing retry mechanism for failed pushes.

**Weak error handling in critical data pipelines:**
- Issue: `RecoveryPipeline.run()` and `WorkoutPipeline.processSession()` use `try?` when fetching HealthKit data, swallowing authorization errors
- Files: `WorkloadApp/Services/RecoveryPipeline.swift` (lines 31-35), `WorkloadApp/Services/WorkoutPipeline.swift`
- Impact: If HealthKit authorization is revoked, the app computes recovery scores with null values instead of alerting user. User sees stale baselines as current data.
- Fix approach: Distinguish between "no data available" (expected) and "authorization denied" (needs action). Raise alerts for permission loss. Cache last-known baselines separately from computed values.

**Model context save failures ignored:**
- Issue: `try? context.save()` appears 20+ times throughout `SyncService.swift`, `RecoveryPipeline.swift`, and views. Failed saves are never logged or retried.
- Files: `WorkloadApp/Services/SyncService.swift` (lines 88, 125, 215, 243, 277, 312, 347), `WorkloadApp/Services/RecoveryPipeline.swift` (line 78), `WorkloadApp/Views/Profile/ProfileView.swift` (line 97)
- Impact: Profile edits, recovery snapshots, and coach relationships may not persist locally. Users see stale data or lose entered information. Cascading failures when sync depends on locally-saved state.
- Fix approach: Implement debug logging for all saves. Log to file in DEBUG builds. Surface persisted state before user dismisses sheets. Add recovery path if save fails (e.g., retry on next app activation).

## Known Bugs

**Deep link handling race condition:**
- Symptoms: User taps invite email deep link, gets routed to invite screen, but if app relaunches before confirmation, the link code is lost
- Files: `WorkloadApp/App/AppRouter.swift` (lines 86-89 handle deep links after initialization), `WorkloadApp/Views/Profile/ProfileView.swift` (enter-code flow)
- Trigger: Tap deep link while app is backgrounded; iOS launches app fresh; user navigates away before tapping confirm
- Workaround: User can copy-paste code manually via "Enter Code" flow in ProfileView
- Fix approach: Persist pending deep-link code to UserDefaults before routing. Check for pending code on each AppRouter load.

**SCREENSHOT_MODE launch argument bypasses auth but not subscription gating:**
- Symptoms: In DEBUG builds with SCREENSHOT_MODE=1, auth is bypassed but premium features may still appear locked
- Files: `WorkloadApp/App/AppRouter.swift` (lines 36-45), `WorkloadApp/Utilities/MockDataSeeder.swift`
- Trigger: Running screenshots with SCREENSHOT_MODE without manually upgrading subscription in RevenueCat sandbox
- Workaround: Manually test purchase flow in sandbox before capturing screenshots
- Fix approach: Extend SCREENSHOT_MODE to also set mock subscription entitlements (isPro=true, isCoach=true). Or document mandatory RevenueCat sandbox setup step.

**Sync race condition if user toggles coach mode during sync:**
- Symptoms: Coach relationships may not sync if user switches "Enable Coach Mode" while `pullLinkedAthletes` is running
- Files: `WorkloadApp/Services/SyncService.swift` (lines 283-318), `WorkloadApp/Views/Profile/ProfileView.swift` (lines 92-100)
- Trigger: User taps coach mode toggle, immediately navigates away before sync completes
- Workaround: Wait for sync to complete (UI disables toggle during sync), or force refresh via tab switch
- Fix approach: Add loading state during coach mode toggle. Queue sync operations instead of allowing overlapping calls. Use Sendable/isolated to enforce thread-safety.

## Security Considerations

**Invite codes are not rate-limited:**
- Risk: Attacker can brute-force 6-character alphanumeric codes (36^6 ≈ 2.2B combinations, but codes expire in 48h) to guess valid invites and gain access to athlete data
- Files: `WorkloadApp/Services/InviteService.swift` (lines 11-14, 38-39)
- Current mitigation: 48-hour expiration, Supabase RLS requires athlete to view own data
- Recommendations: Add server-side rate limiting on `invitations.code` lookups (e.g., max 5 invalid attempts per IP per 1 hour). Increase code entropy if possible (8 chars or add symbols). Log suspicious patterns.

**Email invites reveal athlete existence:**
- Risk: Sending invite email to arbitrary address reveals whether that email is associated with an athlete account (attacker can enumerate valid emails)
- Files: `WorkloadApp/Services/InviteService.swift` (lines 172-207)
- Current mitigation: Supabase Edge Function handles email sending server-side
- Recommendations: Return same success response regardless of whether email exists (privacy-preserving). Send non-delivery notifications only to authenticated users.

**HealthKit data caching may include sensitive metrics:**
- Risk: HRV, RHR, sleep duration cached locally in SwiftData could leak if device is physically compromised
- Files: `WorkloadApp/Models/` (RecoverySnapshot, WorkloadSnapshot models), `WorkloadApp/Services/HealthKitService.swift`
- Current mitigation: Data encrypted by SwiftData on-device; HealthKit API requires app permission
- Recommendations: Consider encrypting at-rest fields using Keychain for most sensitive metrics (HRV). Implement app-level data expiration policy (e.g., purge data >6 months old).

**RevenueCat configuration not in version control:**
- Risk: `RevenueCatConfig.swift` with API key is gitignored, but if accidentally committed, API key leaks
- Files: `RevenueCatConfig.swift` (gitignored, but risk during merges)
- Current mitigation: .gitignore prevents accidental commits
- Recommendations: Use environment-based config injection (Bundle.main.infoDictionary or Xcode Build Settings). Document setup step clearly.

## Performance Bottlenecks

**Large SyncService upsert operations:**
- Problem: `pushAll()` and `pullAll()` fetch entire entity collections at once, then map/upsert all rows in single batch
- Files: `WorkloadApp/Services/SyncService.swift` (lines 19-44, 47-57)
- Cause: No pagination or incremental sync; full refetch on every cycle. `WorkloadSnapshot` and `RecoverySnapshot` can grow to hundreds of rows per athlete over time.
- Improvement path: Implement delta sync using `updatedAt` timestamps (push only modified records since last sync). Paginate pulls in batches of 50-100. Profile on real devices with 1+ year of data.

**RecoveryPipeline always fetches 7-day history for baselines:**
- Problem: Runs on app launch and after wellness check-in; fetches 7 days of recovery snapshots every time, even if baselines haven't changed
- Files: `WorkloadApp/Services/RecoveryPipeline.swift` (lines 39-43)
- Cause: No baseline cache; compute from raw HealthKit fetches on every run
- Improvement path: Cache computed baselines in Athlete model or UserDefaults with expiry (e.g., 24h). Recompute only if new data available.

**SyncService MainActor contention on foreground sync:**
- Problem: All sync operations are `@MainActor`, running on main thread during sync blocks UI
- Files: `WorkloadApp/Services/SyncService.swift` (line 7), `WorkloadApp/App/AppRouter.swift` (lines 159-160)
- Cause: SwiftData's ModelContext is MainActor-isolated in iOS 17+; can't offload to background
- Improvement path: Profile with Instruments to measure sync duration. If >100ms, consider breaking sync into smaller chunks (push athlete, then snapshots, with pauses). Show indeterminate progress indicator during sync.

**ExercisePickerView full-text search with no indexing:**
- Problem: Searches 500+ exercises by filtering entire array on each keystroke
- Files: `WorkloadApp/Views/WorkoutLog/ExercisePickerView.swift` (414 lines)
- Cause: Naive .filter() on large array without tokenization or prefix tree
- Improvement path: Implement prefix-based filtering. Cache search results. Consider moving to Combine debounce. Lazy-load exercise library if possible.

## Fragile Areas

**Coach-athlete relationship lifecycle not transactional:**
- Files: `WorkloadApp/Services/SyncService.swift` (lines 283-318), `WorkloadApp/Services/InviteService.swift` (lines 113-165)
- Why fragile: Multiple steps (confirm relationship, fetch linked athletes, fetch athlete profiles) are not atomic. If step N fails, relationship exists locally but athlete data doesn't sync.
- Safe modification: Wrap entire flow in transaction-like pattern (batch multiple sync operations, rollback local state on Supabase failure).
- Test coverage: InviteServiceTests exist but don't cover failure paths (network timeout during confirmRelationship, then pullLinkedAthletes fails).

**ProfileView edits don't validate before save:**
- Files: `WorkloadApp/Views/Profile/ProfileView.swift` (lines 92-100, 30-51)
- Why fragile: Toggle enable coach mode with no loading state; immediately saves to modelContext and pushes to Supabase. If push fails, local and cloud are inconsistent.
- Safe modification: Add loading state during toggle. Disable toggle UI until save completes. Show error toast if push fails, offer retry.
- Test coverage: No UI tests for ProfileView state transitions or error recovery.

**Workout import and multi-coach attribution assumes session integrity:**
- Files: `WorkloadApp/Views/WorkoutLog/WorkoutImportBanner.swift` (275 lines), `WorkloadApp/Services/WorkoutPipeline.swift`
- Why fragile: If coach logs workout with sessionType=strength but app crashes before WorkoutPipeline completes, session exists without computed load fields (trainingStress, acwrLoad).
- Safe modification: Defer UI success confirmation until WorkoutPipeline fully completes. Pre-compute load fields before session is visible.
- Test coverage: WorkloadCalculatorTests (46 tests) cover the math; no integration tests for pipeline completion under interruption.

## Scaling Limits

**HealthKit sample fetching for TRIMP calculation:**
- Current capacity: Assumes <1000 HR samples per workout (realistic for 2-hour max workouts at 8-10 Hz sample rate)
- Limit: Fetching 1 week of continuous HR data for baselines could be 600K+ samples if user wore watch 24/7
- Scaling path: Aggregate HealthKit samples into 5-minute buckets before processing. Use HealthKit's pre-computed statistics (e.g., average HR per interval) instead of raw samples.
- Files: `WorkloadApp/Services/HealthKitService.swift` (lines 113-149)

**Supabase RLS policies scale with O(N) checks per athlete:**
- Current capacity: Works for single coach with <50 athletes (typical coach); `is_coach_for()` RLS function called on every pull
- Limit: Scales poorly if coach has 500+ athletes — each query to athlete tables runs RLS check for each row
- Scaling path: Pre-compute coach-athlete access lists on backend (materialized view). Cache on client with version tags.
- Files: Supabase schema (backend) — not in codebase, but referenced by `SyncService.pullAthleteSnapshots()` (lines 354-378)

**SwiftData local storage for 3+ years of daily data:**
- Current capacity: 365 × 3 = 1095 recovery snapshots, ~365 workload snapshots, ~100 personal records — reasonable
- Limit: If scaling to 10 coaches × 50 athletes each with 1000 snapshots each = 500K rows, SwiftData query performance degrades
- Scaling path: Archive old data to cloud-only tier. Implement data retention policy (purge data >2 years old unless starred).

## Dependencies at Risk

**RevenueCat SDK version pinned at 5.66.0+:**
- Risk: `purchases-ios` (RevenueCat) is on fast release cycle; 5.66 → 5.70+ may have breaking changes
- Impact: Can't test new subscription features without major bump; support burden increases
- Migration plan: Quarterly dependency audit. Abstract RevenueCat behind `SubscriptionService` (already done) so swapping SDKs is easier. Add integration tests for purchase flow.
- Files: `Package.swift`, `WorkloadApp/Services/SubscriptionService.swift`

**Supabase Swift SDK client is new (< 1 year old):**
- Risk: API changes, missing features, undiscovered bugs. Official SDK stability not battle-tested
- Impact: Auth or sync failures in production hard to debug without strong vendor support
- Migration plan: Monitor Supabase GitHub releases. Have fallback REST API client ready if SDK breaks. Test auth/sync flows on every minor version bump.
- Files: `WorkloadApp/Services/SyncService.swift`, `WorkloadApp/Services/AuthService.swift`

## Missing Critical Features

**No offline-first data model:**
- Problem: Sync operations assume network connectivity. No queue for offline writes (e.g., user logs workout on plane, loses connectivity).
- Blocks: Reliable mobile-first experience; users can't train in remote locations
- Files: `WorkloadApp/Services/SyncService.swift` (all push/pull methods)
- Fix approach: Implement write-ahead log (WAL) pattern: save locally first (mark dirty), then sync when network available. Supabase Realtime can handle sync conflicts.

**No conflict resolution strategy for concurrent edits:**
- Problem: If user edits athlete name on phone while coach edits on iPad, last-write-wins on `updatedAt` may clobber changes
- Blocks: Multi-device coaching workflows
- Files: `WorkloadApp/Services/SyncService.swift` (lines 121-125 for athlete pull)
- Fix approach: Use deterministic CRDTs (last-write-wins is acceptable if timestamps are precise, but consider adding user ID to conflict resolution).

**No undo/redo for workouts or wellness check-ins:**
- Problem: Users can't recover accidentally-deleted sessions or check-ins
- Blocks: Premium feature (future): "Training journal" with edit history
- Impact: User frustration; support tickets for "I accidentally deleted my workout"

## Test Coverage Gaps

**SyncService error paths are untested:**
- What's not tested: Network failures during push/pull, Supabase timeouts, malformed responses
- Files: `WorkloadApp/Services/SyncService.swift` (892 lines, no error-path tests)
- Risk: Silent failures go undetected until production
- Priority: HIGH — sync is critical path
- Solution: Add mock SupabaseClient that throws errors. Test that failures are logged and don't crash app.

**RecoveryPipeline HealthKit permission revocation not tested:**
- What's not tested: If HealthKit auth is revoked mid-run, pipeline behavior
- Files: `WorkloadApp/Services/RecoveryPipeline.swift` (lines 30-36)
- Risk: Stale baselines used forever if user denies HealthKit
- Priority: MEDIUM
- Solution: Mock HealthKitService with `isAuthorized=false`. Verify pipeline handles nil values gracefully.

**ViewModels don't test UI state transitions under network failures:**
- What's not tested: Coach switches mode while sync is running; network timeout during profile save
- Files: `WorkloadApp/ViewModels/DashboardViewModel.swift`, `WorkloadApp/ViewModels/RecoveryViewModel.swift`, ProfileView
- Risk: UI frozen, loading indicators never dismissed
- Priority: MEDIUM
- Solution: Add async test harness for ViewModels. Mock SyncService to simulate delays and failures.

**Coach multi-session attribution end-to-end flow is untested:**
- What's not tested: Coach logs workout with sessionType, app crashes, workout recovered with correct type; multiple coaches logging same session
- Files: `WorkloadApp/Services/WorkoutPipeline.swift`, `WorkloadApp/Views/Coach/CoachWorkoutEntrySheet.swift`
- Risk: Session type lost on crash; attribution confusion if coaches edit same session
- Priority: MEDIUM
- Solution: Add integration tests for multi-coach workflows. Mock WorkoutPipeline interruption scenarios.

---

*Concerns audit: 2026-04-20*
