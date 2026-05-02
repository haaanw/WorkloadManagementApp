# Phase 10: Cold-Start Questionnaire - Research

**Researched:** 2026-05-02
**Domain:** SwiftUI form UI, DashboardViewModel cold-start data path, WorkoutPipeline switchover logic
**Confidence:** HIGH

## Summary

Phase 10 builds the user-facing questionnaire UI and the dashboard integration layer that connects the Phase 9 foundation (TrainingProfile model, ColdStartEngine, BodyRegion/InjuryEntry enums) to the user experience. The scope is: (1) a single-sheet questionnaire form with 4 required + 4 optional fields, (2) a dashboard card to prompt completion, (3) a cold-start data path in DashboardViewModel that falls back to seeded ATL/CTL when no WorkloadSnapshot exists, (4) switchover logic in WorkoutPipeline that silently transitions to real data, (5) FatigueIndex suppression during the cold-start window, (6) silent bias capture at the 8-week mark, and (7) a ProfileView section for re-editing.

All foundation code exists from Phase 9: `TrainingProfile` model is registered in the SwiftData schema, `ColdStartEngine.computeSeed(input:)` is ready to call, `BodyRegion` and `InjuryEntry` are defined in Enums.swift, and `SyncService` already has push/pull methods for TrainingProfile. No new models or schema migrations are needed -- this phase is purely UI + ViewModel + pipeline integration.

**Primary recommendation:** Structure work around four integration surfaces: (A) questionnaire sheet + dashboard card, (B) DashboardViewModel cold-start data path + "EST" annotation on LoadStatCell, (C) WorkoutPipeline switchover check + bias capture, (D) ProfileView re-edit section + FatigueIndex suppression. These can be built sequentially since B depends on A's TrainingProfile creation, and C depends on B's data path.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- D-01: Post-onboarding dashboard card (like WelcomeActionCard) prompts "Set up your training profile". Non-blocking -- user can dismiss and fill later.
- D-02: Card reappears each app launch until questionnaire is completed. Dashboard shows workload 'no data' state meanwhile.
- D-03: Questionnaire also accessible from Profile screen at any time (for re-editing answers later).
- D-04: Single scrollable sheet with all 4 required questions at top + 4 optional questions below a divider. Not multi-step paged.
- D-05: Required: sessions/week (stepper/picker), avg duration minutes (stepper/picker), typical sRPE 1-10 (slider or picker), weeks at current level (stepper/picker).
- D-06: Optional: training age years, periodization preference (steady/periodized), movement types (multi-select), injury history (body region picker + notes).
- D-07: On submit: call ColdStartEngine.computeSeed(), save TrainingProfile, dismiss sheet. Dashboard immediately reflects estimated values.
- D-08: ATL/CTL/ACWR show in existing training load section with a small "Estimated" text label. Same layout, same position -- just annotated.
- D-09: Workload trend chart hidden during cold-start window. Only numeric values display. Chart appears when real data exists.
- D-10: ACWR bar and zone badge use estimated values but display normally (zone classification still meaningful with estimated data).
- D-11: Silent transition when threshold met (3 weeks + 8 sessions). "Estimated" label disappears, chart appears with real data. No toast, no modal, no celebration.
- D-12: No progress indicator toward switchover. User just trains and transition happens invisibly.
- D-13: coldStartCompletedAt set on TrainingProfile when switchover triggers. Dashboard reads this to decide display mode.
- D-14: Completely invisible to user. At 8-week mark, silently snapshot estimated vs actual ATL/CTL onto TrainingProfile bias fields. No UI, no notification.
- D-15: Bias ratio computed at read time (not stored). Used for internal analytics and future calibration research only.
- D-16: FatigueIndex section shows "Building baseline..." text with no score during cold-start window. Matches DESIGN.md text-label-for-states pattern.
- D-17: FatigueIndex begins computing normally after cold-start completes (sufficient HRV/recovery baselines by then).

### Claude's Discretion
- Input control types for questionnaire fields (steppers, sliders, pickers -- whatever fits DESIGN.md best)
- Exact "Estimated" label styling and placement within the metrics section
- "Building baseline..." text styling for FatigueIndex
- DashboardViewModel integration approach for cold-start data path
- Whether to create a dedicated ColdStartService pipeline or integrate into existing RecoveryPipeline/WorkoutPipeline

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| COLD-01 | User can complete 4 required questions (sessions/week, avg duration, typical sRPE 1-10, weeks at current level) via training profile card post-onboarding | TrainingProfileSheet form with Menu pickers matching ProfileView pattern. TrainingProfileCard on dashboard triggers sheet. All field types map to existing TrainingProfile model fields. |
| COLD-02 | User can optionally answer 4 additional questions (training age, periodized vs steady, movement types, injury history) | Optional section below divider in same sheet. SportType.allCases for movement types multi-select. BodyRegion enum + InjuryEntry struct for injury history. All model fields exist. |
| COLD-04 | Estimated ATL/CTL stored on TrainingProfile only (never on WorkloadSnapshot), displayed on dashboard during cold-start window | DashboardViewModel.load() gains cold-start fallback path: query TrainingProfile, use seeded ATL/CTL when no WorkloadSnapshot exists. LoadStatCell gains "EST" annotation. |
| COLD-05 | Dashboard switches from estimated to real ATL/CTL after 3+ weeks elapsed AND 8+ sessions logged | WorkoutPipeline.processSession() checks threshold after each save. Sets coldStartCompletedAt on TrainingProfile. Next DashboardViewModel.load() uses real WorkloadSnapshot. |
| COLD-06 | App stores perceptual bias metric (estimated vs actual load) silently at 8-week mark on TrainingProfile | Bias capture runs in WorkoutPipeline after session save: if 8+ weeks since seededAt AND biasCapturedAt is nil, snapshot estimated vs actual ATL/CTL onto bias fields. |
| COLD-07 | FatigueIndex displays "insufficient data" state during cold-start window instead of computing from incomplete baselines | Dashboard conditionally shows "Building baseline..." card instead of FatigueAttentionBanner when cold-start is active. |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Questionnaire form UI | Browser / Client (SwiftUI View) | -- | Pure UI: picker controls, form layout, sheet presentation |
| Questionnaire data persistence | Database / Storage (SwiftData) | API / Backend (Supabase sync) | TrainingProfile saved locally via modelContext, synced via SyncService |
| Cold-start seed computation | API / Backend (Engine) | -- | ColdStartEngine.computeSeed() is pure computation, already exists |
| Dashboard cold-start data path | Frontend Server (ViewModel) | -- | DashboardViewModel orchestrates fallback from WorkloadSnapshot to TrainingProfile |
| "EST" annotation rendering | Browser / Client (SwiftUI View) | -- | LoadStatCell modification, conditional UI based on ViewModel state |
| Switchover threshold check | API / Backend (Pipeline) | Database / Storage | WorkoutPipeline checks session count + time elapsed, updates TrainingProfile |
| Bias capture | API / Backend (Pipeline) | Database / Storage | Silent snapshot in WorkoutPipeline at 8-week mark |
| FatigueIndex suppression | Browser / Client (SwiftUI View) | Frontend Server (ViewModel) | Dashboard view conditionally renders "Building baseline..." instead of banner |
| Profile re-edit | Browser / Client (SwiftUI View) | -- | ProfileView section links to same TrainingProfileSheet |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ | Form UI, sheet presentation, Menu pickers | Native framework, already used throughout app [VERIFIED: codebase] |
| SwiftData | iOS 17+ | TrainingProfile persistence and @Query reads | Native ORM, already used for all models [VERIFIED: codebase] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Foundation | iOS 17+ | Date arithmetic for switchover/bias thresholds | Calendar.current for week/session counting [VERIFIED: codebase] |
| Charts | iOS 17+ | Workload trend chart (conditionally shown post-switchover) | Already used in WorkloadView; gated during cold-start [VERIFIED: codebase] |

No new dependencies required. All work uses existing Apple frameworks and project patterns.

## Architecture Patterns

### System Architecture Diagram

```
[User taps "Complete Profile"]
         |
         v
[TrainingProfileSheet] --- fills 4 required + 4 optional fields
         |
         v (on Save)
[ColdStartEngine.computeSeed(input:)] --- pure math, returns SeedResult
         |
         v
[TrainingProfile saved to SwiftData] --- seededATL, seededCTL, seededAt set
         |
         v
[SyncService.pushTrainingProfile()] --- async push to Supabase
         |
         v
[DashboardViewModel.load()] --- detects TrainingProfile with seededAt, no WorkloadSnapshot
         |
         v
[Dashboard renders estimated ATL/CTL with "EST" label]
         |
         v (after each workout save)
[WorkoutPipeline.processSession()] --- checks switchover threshold
         |
    [3wk + 8 sessions?] --- NO: continue showing estimated
         |              --- YES: set coldStartCompletedAt, check 8wk bias
         v
[Dashboard switches to real WorkloadSnapshot data, "EST" labels disappear]
```

### Recommended Project Structure

No new directories needed. New files integrate into existing structure:

```
WorkloadApp/
├── Views/
│   ├── Dashboard/
│   │   ├── TrainingProfileCard.swift      # NEW: dashboard CTA card
│   │   └── DashboardView.swift            # MODIFY: add card + EST annotations
│   └── Profile/
│       ├── TrainingProfileSheet.swift     # NEW: questionnaire form sheet
│       └── ProfileView.swift              # MODIFY: add Training Profile section
├── ViewModels/
│   └── DashboardViewModel.swift           # MODIFY: cold-start data path
├── Repositories/
│   └── TrainingProfileRepository.swift    # NEW: fetch/save TrainingProfile
├── Services/
│   └── WorkoutPipeline.swift              # MODIFY: switchover + bias capture
└── Components/
    └── (no new components needed)
```

### Pattern 1: Cold-Start Data Path in DashboardViewModel

**What:** When DashboardViewModel.load() finds no WorkloadSnapshot but TrainingProfile exists with seeded values and coldStartCompletedAt == nil, populate ATL/CTL/ACWR/TSB from seeded values instead.

**When to use:** Every dashboard load -- this is the primary conditional branch.

**Example:**
```swift
// Source: [VERIFIED: codebase analysis of DashboardViewModel.swift lines 139-149]
// After existing WorkloadSnapshot fetch (line 142), add cold-start fallback:

// Fetch latest workload snapshot
let workloadRepo = WorkloadRepository(modelContext: modelContext)
if let snapshot = try? workloadRepo.fetchLatestSnapshot() {
    acwr = snapshot.acwr
    acwrZone = snapshot.zone
    tsb = snapshot.tsb
    atl = snapshot.acuteLoad
    ctl = snapshot.chronicLoad
} else {
    // Cold-start fallback: use seeded values from TrainingProfile
    let profileRepo = TrainingProfileRepository(modelContext: modelContext)
    if let profile = try? profileRepo.fetchProfile(athleteId: athlete.id),
       profile.coldStartCompletedAt == nil {
        atl = profile.seededATL
        ctl = profile.seededCTL
        acwr = profile.seededCTL > 0 ? profile.seededATL / profile.seededCTL : 0
        tsb = profile.seededCTL - profile.seededATL
        acwrZone = ACWRZone.classify(acwr: acwr, ctl: ctl)
        isColdStartActive = true  // new property for EST label
    }
}
```

### Pattern 2: Switchover Check in WorkoutPipeline

**What:** After every session save, check if the cold-start threshold (3 weeks + 8 sessions) has been met. If so, set `coldStartCompletedAt` on the TrainingProfile.

**When to use:** End of `WorkoutPipeline.processSession()`, after snapshot upsert.

**Example:**
```swift
// Source: [VERIFIED: codebase analysis of WorkoutPipeline.swift]
// Add after line 80 (modelContext.save()):

// Cold-start switchover check
let profilePredicate = #Predicate<TrainingProfile> { $0.athleteId == athlete.id }
if let profile = try? modelContext.fetch(FetchDescriptor(predicate: profilePredicate)).first,
   profile.coldStartCompletedAt == nil {
    let weeksSinceSeeded = Calendar.current.dateComponents(
        [.weekOfYear], from: profile.seededAt, to: .now
    ).weekOfYear ?? 0
    let sessionCount = try? workoutRepo.fetchSessions(last: 365).count

    if weeksSinceSeeded >= 3 && (sessionCount ?? 0) >= 8 {
        profile.coldStartCompletedAt = .now
        profile.updatedAt = .now
        try? modelContext.save()
    }

    // Bias capture at 8-week mark (D-14)
    if profile.biasCapturedAt == nil {
        let weeksSinceSeeded8 = Calendar.current.dateComponents(
            [.weekOfYear], from: profile.seededAt, to: .now
        ).weekOfYear ?? 0
        if weeksSinceSeeded8 >= 8, let snapshot = try? workloadRepo.fetchLatestSnapshot() {
            profile.biasEstimatedATL = profile.seededATL
            profile.biasEstimatedCTL = profile.seededCTL
            profile.biasActualATL = snapshot.acuteLoad
            profile.biasActualCTL = snapshot.chronicLoad
            profile.biasCapturedAt = .now
            profile.updatedAt = .now
            try? modelContext.save()
        }
    }
}
```

### Pattern 3: TrainingProfileCard (Dashboard Entry Point)

**What:** A card following WelcomeActionCard's exact visual pattern, prompting users to fill their training profile.

**When to use:** Shown on dashboard when TrainingProfile does not exist for current athlete. Hidden once profile is created.

**Example:**
```swift
// Source: [VERIFIED: WelcomeActionCard.swift codebase pattern]
struct TrainingProfileCard: View {
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TRAINING PROFILE")
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Text("Set up your training profile")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
                .padding(.horizontal, 16)

            Text("Answer a few questions about your training to get estimated workload data right away.")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 16)

            Button(action: onComplete) {
                Text("Complete Profile")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(ColorTokens.surface)
        .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))
    }
}
```

### Pattern 4: Menu Picker for Form Fields

**What:** Reuse ProfileView's `editablePicker` pattern for questionnaire form rows. Each row has a label on the left, Menu picker on the right.

**When to use:** All 8 questionnaire fields use this pattern (with variations for multi-select and injury sub-form).

**Example:**
```swift
// Source: [VERIFIED: ProfileView.swift lines 464-494]
// The existing editablePicker pattern in ProfileView:
HStack {
    Text("Sessions per week")
        .font(.Tokens.body)
        .foregroundStyle(ColorTokens.text2)
    Spacer()
    Menu {
        ForEach(1...14, id: \.self) { count in
            Button("\(count)") { sessionsPerWeek = count }
        }
    } label: {
        HStack(spacing: 4) {
            Text("\(sessionsPerWeek)")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 10))
                .foregroundStyle(ColorTokens.text3)
        }
    }
}
.padding(.horizontal, 16)
.padding(.vertical, 16)
```

### Anti-Patterns to Avoid
- **Writing estimated values to WorkloadSnapshot:** This is the critical contamination boundary. Seeded ATL/CTL MUST only live on TrainingProfile. DashboardViewModel reads from TrainingProfile during cold-start, WorkloadSnapshot during normal operation. Never mix. [VERIFIED: CONTEXT.md D-08, D-04, STATE.md decision]
- **Blocking onboarding on questionnaire:** The card is non-blocking (D-01). User can dismiss and train without filling it. Dashboard shows "--" values when neither WorkloadSnapshot nor TrainingProfile exists.
- **Showing FatigueIndex during cold-start:** FatigueIndexEngine needs baseline session TSS data which won't be meaningful during cold-start. Show "Building baseline..." instead (D-16).
- **Using `.sheet(item:)` with TrainingProfile directly:** TrainingProfile is a @Model class -- pass it as a binding or use a boolean sheet trigger, not as an identifiable item to `.sheet(item:)`. SwiftData models in sheet presentation can cause reference issues.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| ACWR zone classification from estimated values | Custom zone logic for cold-start | `ACWRZone.classify(acwr:ctl:)` | Same enum already handles zone classification; seeded ACWR is just a ratio [VERIFIED: WorkloadSnapshot.swift line 18-20] |
| TSS computation from questionnaire inputs | New TSS formula | `ColdStartEngine.computeSeed(input:)` | Already built in Phase 9, delegates to WorkloadCalculator.sessionTSS [VERIFIED: ColdStartEngine.swift] |
| Form picker UI controls | Custom stepper/slider components | SwiftUI `Menu` + `ForEach` | Matches existing ProfileView editablePicker pattern exactly [VERIFIED: ProfileView.swift] |
| TrainingProfile sync | Manual JSON encoding | `SyncService.pushTrainingProfile()` | Already implemented with TrainingProfileRow Codable struct [VERIFIED: SyncService.swift] |
| Injury history encoding | Custom serialization | `JSONEncoder().encode([InjuryEntry])` → `Data` | TrainingProfile.injuryHistory is `Data?`, InjuryEntry is already `Codable` [VERIFIED: Enums.swift, TrainingProfile.swift] |

**Key insight:** Phase 9 built all the foundation -- models, engine, enums, sync. This phase is pure integration: wiring existing foundation to UI + ViewModel + pipeline hooks.

## Common Pitfalls

### Pitfall 1: EWMA Contamination
**What goes wrong:** Estimated ATL/CTL values accidentally get written to WorkloadSnapshot, contaminating the EWMA time series. Once contaminated, all future real workload calculations are skewed.
**Why it happens:** DashboardViewModel populates `atl` and `ctl` properties from either WorkloadSnapshot or TrainingProfile. If a code path downstream reads these ViewModel properties and writes them back to WorkloadSnapshot, contamination occurs.
**How to avoid:** The `isColdStartActive` boolean on DashboardViewModel must be checked anywhere that reads ViewModel ATL/CTL for persistence. WorkoutPipeline.processSession() computes its own ATL/CTL from real sessions -- it never reads DashboardViewModel. The danger is if future code adds a "refresh snapshot from ViewModel" path.
**Warning signs:** WorkloadSnapshot records with seeded-looking ATL/CTL values before the user has logged enough sessions.

### Pitfall 2: Switchover Race Condition
**What goes wrong:** User logs session 8 in week 2. Threshold for sessions met (8+) but not for time (3 weeks). Next week, time threshold met but session count check runs against a different session set. Or: two sessions saved rapidly, both trigger switchover check simultaneously.
**Why it happens:** WorkoutPipeline.processSession() runs after each save. If the check uses `fetchSessions(last: N)` the result depends on timing.
**How to avoid:** Count ALL sessions (not just recent), and use `Calendar.current.dateComponents([.weekOfYear])` for the time check. The check is idempotent (setting coldStartCompletedAt when already set is harmless, but guard against it with the nil check).
**Warning signs:** `coldStartCompletedAt` being set before week 3.

### Pitfall 3: Sheet Dismissal Without Save Losing State
**What goes wrong:** User fills 3 of 4 required fields, accidentally swipes to dismiss the sheet, loses all input.
**Why it happens:** SwiftUI `.sheet` allows swipe-to-dismiss by default. If form state is local `@State`, it's lost on dismiss.
**How to avoid:** The sheet uses `@State` for form fields (correct -- they're temporary until save). The "Discard Changes" nav button is explicit. Consider using `.interactiveDismissDisabled(hasChanges)` to prevent accidental swipe dismissal when partial data entered.
**Warning signs:** User complaints about lost form data.

### Pitfall 4: TrainingProfile Query Returns Nil After Save
**What goes wrong:** Sheet saves TrainingProfile, dismisses, dashboard loads but `@Query` for TrainingProfile returns nil because SwiftData hasn't propagated the insert.
**Why it happens:** `@Query` is reactive but depends on the same ModelContext. If the sheet uses a different context or the save hasn't been observed, there's a timing gap.
**How to avoid:** Use the same `modelContext` from `@Environment(\.modelContext)` for both the sheet and the dashboard. After `modelContext.insert(profile)` + `modelContext.save()`, the `@Query` in DashboardView will reactively update. Alternatively, trigger an explicit `viewModel.load()` after sheet dismissal via `.onDismiss`.
**Warning signs:** Dashboard still showing TrainingProfileCard after user saved the questionnaire.

### Pitfall 5: Optional Fields With Default Values
**What goes wrong:** A picker for sessions/week defaults to 0 or 1. User taps "Save Profile" without actually choosing a value. The default is technically valid but doesn't represent the user's real training.
**Why it happens:** Picker fields need initial values to render, but those initial values might be incorrect defaults.
**How to avoid:** Use sentinel values (e.g., `sessionsPerWeek: Int? = nil` in form state) and only enable the "Save Profile" button when all 4 required fields have been explicitly set. Per the UI-SPEC: "all 4 required fields valid" check before enabling save.
**Warning signs:** TrainingProfile records with suspiciously uniform values (all 1s or minimum values).

## Code Examples

### Complete TrainingProfileRepository

```swift
// Source: [VERIFIED: matches AthleteRepository pattern from AthleteRepository.swift]
import Foundation
import SwiftData

@MainActor
final class TrainingProfileRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchProfile(athleteId: UUID) throws -> TrainingProfile? {
        let predicate = #Predicate<TrainingProfile> { $0.athleteId == athleteId }
        let descriptor = FetchDescriptor<TrainingProfile>(predicate: predicate)
        return try modelContext.fetch(descriptor).first
    }

    func saveProfile(_ profile: TrainingProfile) throws {
        modelContext.insert(profile)
        try modelContext.save()
    }

    func updateProfile(_ profile: TrainingProfile) throws {
        profile.updatedAt = .now
        try modelContext.save()
    }
}
```

### DashboardViewModel Cold-Start Properties

```swift
// Source: [VERIFIED: DashboardViewModel.swift existing property pattern]
// Add to DashboardViewModel alongside existing properties:

/// True when displaying seeded ATL/CTL from TrainingProfile (cold-start window active)
var isColdStartActive: Bool = false

/// True when TrainingProfile exists but cold-start has completed
var isColdStartCompleted: Bool = false
```

### LoadStatCell with "EST" Annotation

```swift
// Source: [VERIFIED: DashboardView.swift LoadStatCell lines 454-470, UI-SPEC component #4]
struct LoadStatCell: View {
    let label: String
    let value: String
    var isEstimated: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)
            Text(value)
                .font(.Tokens.label)
                .monospacedDigit()
                .foregroundStyle(ColorTokens.text1)
            if isEstimated {
                Text("EST")
                    .font(.Tokens.micro)
                    .tracking(0.88)
                    .foregroundStyle(ColorTokens.text3)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isEstimated ? "\(label) \(value), estimated" : "\(label) \(value)")
    }
}
```

### FatigueIndex Cold-Start Card

```swift
// Source: [VERIFIED: FatigueAttentionBanner.swift pattern, UI-SPEC component #6]
// Replaces FatigueAttentionBanner during cold-start window
struct FatigueBaselineCard: View {
    var body: some View {
        Text("Building baseline...")
            .font(.Tokens.label)
            .foregroundStyle(ColorTokens.text2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(ColorTokens.surface)
            .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))
    }
}
```

### Injury History Encoding/Decoding

```swift
// Source: [VERIFIED: InjuryEntry struct in Enums.swift, TrainingProfile.injuryHistory: Data?]
// Encode injuries for TrainingProfile.injuryHistory
let injuries: [InjuryEntry] = [
    InjuryEntry(bodyRegion: .knee, notes: "ACL recovery", isActive: true),
    InjuryEntry(bodyRegion: .shoulder, notes: nil, isActive: false)
]
let encoded = try? JSONEncoder().encode(injuries)  // -> Data? for TrainingProfile.injuryHistory

// Decode for display
if let data = profile.injuryHistory,
   let decoded = try? JSONDecoder().decode([InjuryEntry].self, from: data) {
    // Use decoded injuries for UI display
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| No cold-start handling -- new users see empty dashboard | Seeded ATL/CTL from questionnaire with "EST" annotation | Phase 10 (this phase) | New users get immediate value from day 1 |
| FatigueIndex computed on all sessions regardless of data quality | FatigueIndex suppressed during cold-start window | Phase 10 (this phase) | Prevents misleading fatigue scores from incomplete baselines |

**Deprecated/outdated:**
- None for this phase. All patterns are current.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `@Query` for TrainingProfile will reactively update after insert in same ModelContext | Pitfall 4 | Dashboard won't show estimated values after questionnaire save -- would need explicit reload trigger |
| A2 | `.interactiveDismissDisabled()` prevents swipe-to-dismiss on sheets (iOS 15+) | Pitfall 3 | Users could accidentally lose form data; fallback is to accept swipe-dismiss |
| A3 | `Calendar.current.dateComponents([.weekOfYear])` correctly computes weeks elapsed between two dates | Switchover Pattern | Could miscalculate switchover timing if calendar edge cases arise; verify with unit tests |

**Note:** A1 is very likely correct based on standard SwiftData behavior but should be verified during implementation. A2 is an iOS 15+ API that is definitely available on our iOS 17+ target. A3 needs verification -- `.weekOfYear` may have edge cases around year boundaries; `.day` / 7 may be more reliable.

## Open Questions (RESOLVED)

1. **Session count for switchover threshold: total lifetime or since seededAt?**
   - What we know: D-13 says "3 weeks + 8 sessions" but doesn't specify whether sessions count from seededAt or from all time
   - What's unclear: A user who had the app installed before Phase 10, then fills the questionnaire, might already have 8+ sessions
   - RESOLVED: Count ALL sessions (lifetime total). The purpose of the threshold is to ensure enough real data exists. If the user already has 8+ sessions and 3+ weeks of data, the switchover triggers immediately (correct -- they don't need estimated values). Plan 03 Task 1 implements this as total session count.

2. **What happens when user fills questionnaire but already has WorkloadSnapshot data?**
   - What we know: An existing user who upgrades to this version might already have real snapshots. The cold-start path only activates when NO WorkloadSnapshot exists.
   - What's unclear: Should we skip the cold-start window entirely for users with existing snapshots?
   - RESOLVED: Yes. If WorkloadSnapshot exists, use it regardless of TrainingProfile state. The cold-start data path is a fallback for the empty-snapshot case only. Plan 02 Task 1 implements this -- the `else` branch in DashboardViewModel.load() only executes when no WorkloadSnapshot is found.

3. **Re-edit behavior after switchover**
   - What we know: D-03 says questionnaire is accessible from Profile for re-editing. UI-SPEC says re-runs computeSeed() but dashboard continues using real data post-switchover.
   - What's unclear: Whether re-editing should update seeded values (which are no longer displayed) or just the raw questionnaire answers.
   - RESOLVED: Re-run computeSeed() and update seeded values for data completeness, but since coldStartCompletedAt is set, dashboard ignores them. Raw answers are always updated. Plan 01 Task 2 implements this in the save handler's `existingProfile` branch.

## Environment Availability

Step 2.6: SKIPPED (no external dependencies identified). This phase is purely SwiftUI/SwiftData code changes with no new tools, services, or CLIs needed. Xcode is the sole build tool, already available.

## Project Constraints (from CLAUDE.md)

- **0pt border radius everywhere** -- use `Rectangle()`, never `RoundedRectangle` [DESIGN.md]
- **No shadows** -- remove any `.shadow()` modifiers; use hairline borders instead [DESIGN.md]
- **Accent color only on hero readiness score number** -- NOT on questionnaire card, buttons, or EST labels [DESIGN.md]
- **DM Sans Regular + Medium only** -- use `Font.Tokens.*` extension, never `.system()` [DESIGN.md, FontTokens.swift]
- **All spacing multiples of 8pt** -- no magic numbers in layout [DESIGN.md]
- **Zone states via text labels + optional colored border** -- never color alone [DESIGN.md]
- **Both dark and light mode supported** via `ColorTokens` semantic tokens [DESIGN.md]
- **Incremental build verification** -- run build check after every 3-5 files [CLAUDE.md]
- **HealthKit raw data never uploaded to Supabase** -- only composite scores sync [CLAUDE.md]
- **Verify Xcode project includes all new source files** after generating Swift files [CLAUDE.md]

## Sources

### Primary (HIGH confidence)
- TrainingProfile.swift -- Model fields, init signature, all seeded/bias/coldStart fields verified
- ColdStartEngine.swift -- computeSeed(input:) API, SeedInput/SeedResult types, formula verified
- DashboardViewModel.swift -- load() method, all published properties, WorkloadSnapshot fetch path
- DashboardView.swift -- Full view hierarchy, WelcomeActionCard placement, LoadStatCell, FatigueAttentionBanner conditional, TrainingLoadSection
- WelcomeActionCard.swift -- Visual pattern for dashboard cards (spacing, fonts, border)
- WorkoutPipeline.swift -- processSession() flow, where to insert switchover check
- ProfileView.swift -- editablePicker pattern, sectionHeader pattern, divider pattern
- Enums.swift -- BodyRegion enum (8 cases), InjuryEntry struct, SportType.allCases
- SyncService.swift -- pushTrainingProfile/pullTrainingProfile already implemented
- WorkloadApp.swift -- TrainingProfile registered in schema
- FatigueAttentionBanner.swift -- Current rendering pattern, zone-based display
- FontTokens.swift -- All font token definitions
- 10-UI-SPEC.md -- Component inventory, copywriting, accessibility, state matrix
- 10-CONTEXT.md -- All 17 locked decisions, discretion areas, canonical references

### Secondary (MEDIUM confidence)
- 09-CONTEXT.md -- Phase 9 locked decisions on seeding math, field design, migration strategy
- DESIGN.md -- Design system constraints (0pt corners, no shadows, accent rule, 8pt grid)

### Tertiary (LOW confidence)
- None. All findings verified against codebase.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All Apple native frameworks already in use, no new dependencies
- Architecture: HIGH - All integration points verified by reading actual source files
- Pitfalls: HIGH - Based on direct codebase analysis of data flow paths
- UI patterns: HIGH - Every component pattern traced to existing code

**Research date:** 2026-05-02
**Valid until:** 2026-06-02 (stable -- no framework version concerns, pure integration work)
