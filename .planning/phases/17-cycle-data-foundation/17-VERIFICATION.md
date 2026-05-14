---
phase: 17-cycle-data-foundation
verified: 2026-05-14T13:00:00Z
status: gaps_found
score: 5/7
overrides_applied: 0
gaps:
  - truth: "CycleTrackingService reads all 6 menstrual HealthKit types (menstrualFlow, appleSleepingWristTemperature, contraceptive, pregnancy, lactation, irregularMenstrualCycles, ovulationTestResult)"
    status: failed
    reason: "HealthKitService.readTypes (lines 38-56) does not include any menstrual category types. The SUMMARY for Plan 02 claims 6 types were added, but the actual code was not changed. CycleTrackingService creates its own HKHealthStore and queries without authorization ever being requested. HealthKit silently returns empty results for unauthorized types."
    artifacts:
      - path: "WorkloadApp/Services/HealthKitService.swift"
        issue: "readTypes set (lines 38-56) contains only the original 8 types: heartRateVariabilitySDNN, restingHeartRate, heartRate, activeEnergyBurned, stepCount, vo2Max, bodyTemperature, sleepAnalysis. The 6 menstrual types from Plan 02 Task 1 are absent."
    missing:
      - "Add HKCategoryType(.menstrualFlow) to readTypes in HealthKitService.swift"
      - "Add HKCategoryType(.contraceptive) to readTypes"
      - "Add HKCategoryType(.pregnancy) to readTypes"
      - "Add HKCategoryType(.lactation) to readTypes"
      - "Add HKCategoryType(.irregularMenstrualCycles) to readTypes"
      - "Add HKCategoryType(.ovulationTestResult) to readTypes"
  - truth: "Users who already track cycles in Apple Health see their data automatically — zero manual re-entry"
    status: failed
    reason: "Blocked by the HealthKit authorization gap above. Without menstrualFlow in readTypes, the requestAuthorization() sheet never asks for menstrual data permission, so CycleTrackingService.fetchMenstrualFlowHistory will always return an empty array. No cycle data flows to the UI regardless of what the user has tracked in other apps."
    artifacts:
      - path: "WorkloadApp/Services/CycleTrackingService.swift"
        issue: "Service creates its own HKHealthStore (line 19) and queries without authorization having been granted. Line 45 guard !flowHistory.isEmpty returns .none for all users due to missing auth."
    missing:
      - "Fix HealthKitService.readTypes to include menstrualFlow (resolves this gap transitively)"
human_verification:
  - test: "Visual verification of Cycle & Hormones section and soft prompt banner"
    expected: "ProfileView shows 3 toggles (Hormonal Contraceptive, Pregnant, Lactating) in correct position between Training Profile and Preferences sections. Toggles follow DESIGN.md: 0pt corners, no shadows, General Sans font, 8pt grid, 16pt vertical padding. DashboardView shows soft prompt banner with correct heading, body copy, dismiss X button, and Open Settings link. Tapping X permanently dismisses the banner. Navigating away and back confirms persistence."
    why_human: "Plan 03 Task 3 is a human checkpoint gate. Visual appearance, font rendering (General Sans vs system), spacing correctness, and toggle persistence require running the app in a simulator."
---

# Phase 17: Cycle Data Foundation — Verification Report

**Phase Goal:** Zero-friction cycle data integration — read existing HealthKit menstrual data from apps users already use (Clue, Flo, Apple Cycle Tracking), compute cycle day/phase with confidence scoring, and handle all edge cases (irregular, anovulatory, contraceptive, perimenopause, pregnancy, lactation)
**Verified:** 2026-05-14T13:00:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | CycleTrackingService reads all 6 menstrual HealthKit types | FAILED | HealthKitService.readTypes (lines 38-56) contains 0 menstrual types. SUMMARY-02 claims they were added but the code does not reflect it. |
| 2 | MenstrualCycleSnapshot model stores daily cycle state | VERIFIED | MenstrualCycleSnapshot.swift: @Model with @Attribute(.unique) id, date, cycleDay, estimatedPhase, confidence, cycleLength, wristTempDeviation, flowIntensity, exclusion flags, updatedAt, athlete relationship. Follows RecoverySnapshot pattern exactly. |
| 3 | CycleContext struct provides confidence-scored phase estimation with exclusion flags | VERIFIED | CycleContext struct in MenstrualCycleSnapshot.swift: hasExclusion computed property, static .none sentinel, phase/confidence/cycleDay/cycleLength fields. CycleTrackingService.computeConfidence is a static pure function with CV-based regularity scoring and wrist temp boost. |
| 4 | Users who already track cycles in Apple Health see data automatically | FAILED | Blocked by SC-01. Authorization never requested for menstrualFlow, so HealthKit returns empty array to fetchMenstrualFlowHistory, and .none is returned from run(). |
| 5 | Users who don't track cycles experience zero change | VERIFIED | showCyclePrompt gates the dashboard banner (only shows when cycleSnapshots.isEmpty). showCycleSection gates profile section (only shows when snapshots exist or flags set). Non-cycle users are unaffected. |
| 6 | Raw menstrual data never syncs to Supabase | VERIFIED | grep for MenstrualCycleSnapshot in SyncService.swift returns 0 matches. D-12 privacy constraint enforced. Only Athlete.isOnHormonalContraceptive / isPregnant / isLactating sync via existing AthleteRow, which is by design. |
| 7 | Contraceptive status settable in ProfileView; OC users skip phase-based adjustments | VERIFIED | ProfileView has CYCLE & HORMONES section with Hormonal Contraceptive toggle wired to athlete.isOnHormonalContraceptive, saving via saveAthlete() which calls pushAthlete(). CycleTrackingService line 62: if athlete.isOnHormonalContraceptive == true returns .unknown phase. |

**Score: 5/7 truths verified**

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `WorkloadApp/Models/Enums.swift` | CyclePhase enum | VERIFIED | Lines 380-400: 6-case enum (earlyFollicular, lateFollicular, ovulatory, earlyLuteal, lateLuteal, unknown) with displayName. Conforms to String, Codable, CaseIterable, Identifiable. |
| `WorkloadApp/Models/MenstrualCycleSnapshot.swift` | Daily cycle state model | VERIFIED | @Model final class with all required fields. CycleContext struct with hasExclusion and static .none. |
| `WorkloadApp/Models/Athlete.swift` | Cycle exclusion fields | VERIFIED | Lines 21-23: isOnHormonalContraceptive, isPregnant, isLactating as optional Bool. Line 46-47: cascade relationship to menstrualCycleSnapshots. init() signature not modified. |
| `WorkloadApp/Services/SyncService.swift` | AthleteRow sync for new fields | VERIFIED | AthleteRow struct has 3 Bool? fields (lines 827-829). pushAthlete maps them (lines 232-234). pullAthlete merges with nil-coalescing (lines 269-271). |
| `WorkloadApp/App/WorkloadApp.swift` | Schema registration | VERIFIED | Line 25: MenstrualCycleSnapshot.self in schema array, positioned after RecoverySnapshot.self. |
| `migrations/add_cycle_fields_to_athletes.sql` | Supabase migration | VERIFIED | 3 ALTER TABLE statements adding nullable BOOLEAN columns with no defaults. |
| `WorkloadApp/Services/HealthKitService.swift` | Extended readTypes with menstrual types | FAILED | readTypes contains only original 8 types. No menstrual HKCategoryType entries present. |
| `WorkloadApp/Services/CycleTrackingService.swift` | HealthKit menstrual reader + phase estimator | VERIFIED (partial) | File exists with full implementation: run(), fetchMenstrualFlowHistory(), detectCycleStarts() with metadata+gap fallback, estimatePhase(), computeConfidence(), checkBiphasicShift(), upsertSnapshot(). Logic is correct but silently fails due to missing auth. |
| `WorkloadApp/Views/Profile/ProfileView.swift` | Cycle & Hormones section with 3 toggles | VERIFIED | sectionHeader("CYCLE & HORMONES"), 3 Toggle rows for Hormonal Contraceptive/Pregnant/Lactating, showCycleSection guard, @Query cycleSnapshots, saveAthlete() in each setter. |
| `WorkloadApp/Views/Dashboard/DashboardView.swift` | One-time soft prompt banner | VERIFIED | @AppStorage("cyclePromptDismissed"), @Query cycleSnapshots, showCyclePrompt computed property, "Cycle-Aware Recovery" heading, body copy, xmark dismiss with accessibilityLabel, Open Settings link, Rectangle border (no rounded corners), ColorTokens throughout. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| MenstrualCycleSnapshot.swift | Athlete.swift | var athlete: Athlete? relationship | WIRED | MenstrualCycleSnapshot line 22: `var athlete: Athlete?` |
| Athlete.swift | MenstrualCycleSnapshot.swift | @Relationship cascade inverse | WIRED | Athlete.swift lines 46-47: `@Relationship(deleteRule: .cascade, inverse: \MenstrualCycleSnapshot.athlete) var menstrualCycleSnapshots` |
| SyncService.swift | Athlete.swift | AthleteRow maps new fields | WIRED | AthleteRow has 3 Bool? fields; pushAthlete and pullAthlete both handle them |
| CycleTrackingService.swift | HealthKit Store | HKSampleQueryDescriptor for menstrualFlow | PARTIAL | Query code is correct but authorization is never granted — calls will return empty silently |
| CycleTrackingService.swift | MenstrualCycleSnapshot.swift | Creates and upserts daily snapshot | WIRED | upsertSnapshot() method creates/updates MenstrualCycleSnapshot per athlete per day |
| ProfileView.swift | Athlete.swift | Toggle bindings to exclusion fields | WIRED | Three Toggle bindings directly write to athlete.isOnHormonalContraceptive, isPregnant, isLactating |
| ProfileView.swift | SyncService.swift | saveAthlete() triggers pushAthlete | WIRED | saveAthlete() at line 673 calls `container.syncService.pushAthlete(athlete)` |
| MenstrualCycleSnapshot.swift | SyncService.swift | Must NOT be linked (D-12) | VERIFIED ABSENT | 0 matches for MenstrualCycleSnapshot in SyncService.swift |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| CycleTrackingService | flowHistory | HealthKit HKSampleQueryDescriptor for menstrualFlow | No — HK auth never granted for this type | HOLLOW — query code correct but authorization missing means empty results always returned |
| ProfileView toggles | athlete.isOnHormonalContraceptive | Athlete SwiftData model via @Query | Yes — reads from local SwiftData store | FLOWING |
| DashboardView banner | cycleSnapshots | @Query [MenstrualCycleSnapshot] | Yes — reads from SwiftData | FLOWING (banner shows correctly because no snapshots exist) |

### Behavioral Spot-Checks

Step 7b: SKIPPED — iOS app with no runnable CLI entry points. All behaviors require simulator execution.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| CYCLE-01 | 17-02, 17-03 | HealthKit menstrual data reading | PARTIAL | CycleTrackingService exists with correct query logic but HK auth missing |
| CYCLE-02 | 17-01, 17-02 | MenstrualCycleSnapshot model and cycle tracking pipeline | VERIFIED | Model, enum, CycleContext, and service all implemented |
| CYCLE-03 | 17-01, 17-03 | Athlete exclusion fields, profile UI, sync | VERIFIED | Athlete fields, AthleteRow sync, ProfileView section, migration SQL |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| CycleTrackingService.swift | 291 | `context.fetch(FetchDescriptor<MenstrualCycleSnapshot>())` — fetches all snapshots without predicate, then filters in memory | Warning | Performance degrades at ~365+ records/year; potential duplicate insertion if fetch fails silently (per REVIEW.md WR-02) |
| CycleTrackingService.swift | 183-200 | `estimatePhase` has no guard for cycleDay > cycleLength + threshold, returning .lateLuteal for days 40+ on a 28-day cycle | Warning | Could produce misleading phase label late in an unexpectedly long cycle (per REVIEW.md WR-03) |
| DashboardView.swift | 86-88 | `UIApplication.openSettingsURLString` deep-links to app Settings page, not HealthKit permissions | Info | User must navigate manually to Settings > Privacy > Health > Faros (per REVIEW.md IN-01) |
| ProfileView.swift | ~215 | Notification denied text references "Tuwa" instead of "Faros" (app renamed) | Info | Wrong app name shown to user in an edge-case message (per REVIEW.md IN-02) |

Severity classification:
- Blocker anti-patterns: 0
- Warning anti-patterns: 2 (WR-02, WR-03)
- Info anti-patterns: 2 (IN-01, IN-02)

### Human Verification Required

#### 1. Visual verification of Cycle & Hormones section and soft prompt banner

**Test:** Build and run the app in Xcode simulator. Navigate to Profile tab. If Cycle & Hormones section is not visible (expected for a fresh install with no cycle data), set any of the 3 athlete flags to nil != nil to trigger visibility, or use Xcode's data editor to insert a MenstrualCycleSnapshot record. Then:
1. Verify 3 toggle rows appear (Hormonal Contraceptive, Pregnant, Lactating) with correct heading between Training Profile and Preferences
2. Verify fonts are General Sans (not system fonts), spacing is 16pt vertical per toggle row
3. Toggle each value and navigate away/back to confirm persistence
4. Navigate to Dashboard tab
5. Verify soft prompt banner appears with "Cycle-Aware Recovery" heading and body copy
6. Tap X dismiss button — verify banner disappears permanently (survives navigation and app restart)
7. Verify 0pt corners (no rounded rectangles), no shadows, correct divider border style

**Expected:** All elements match DESIGN.md: 0pt corners, General Sans font, ColorTokens, 8pt grid. Toggles persist. Banner dismissal is permanent.

**Why human:** Visual font rendering, layout spacing accuracy, and interaction persistence require running the compiled app. The plan's Task 3 is explicitly marked as `checkpoint:human-verify` with gate: blocking.

## Gaps Summary

Two gaps block the phase goal:

**Gap 1 (root cause): HealthKit authorization never requested for menstrual data.** `HealthKitService.readTypes` does not include any of the 6 menstrual HKCategoryType values. Plan 02 Task 1 was supposed to add them, the SUMMARY claims they were added, but the actual file was not modified. This is a clean miss — the code at lines 38-56 of HealthKitService.swift is identical to its pre-phase state.

**Gap 2 (downstream effect): Zero-friction data reading fails.** Since authorization is never requested, `CycleTrackingService.fetchMenstrualFlowHistory` will always receive an empty array from HealthKit, causing `run()` to return `CycleContext.none` for all users. The cycle data that users have accumulated in Clue, Flo, or Apple Cycle Tracking will never be read.

The fix for both gaps is the same: add the 6 `HKCategoryType` lines to `HealthKitService.readTypes`. This is a 6-line addition. Once authorization is requested and granted, the existing `CycleTrackingService` query logic (which is correct) will begin receiving data.

The two code-review warnings (WR-02 predicate-less fetch, WR-03 cycleDay overflow) are non-blocking for Phase 17's goal — they are quality issues to address in a follow-up but do not prevent cycle data from flowing.

The human verification checkpoint from Plan 03 Task 3 remains outstanding and must be completed before the phase is fully closed.

---

_Verified: 2026-05-14T13:00:00Z_
_Verifier: Claude (gsd-verifier)_
