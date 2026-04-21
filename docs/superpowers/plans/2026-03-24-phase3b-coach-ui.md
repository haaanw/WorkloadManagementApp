# Phase 3b: Coach UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the coach-facing UI — context switcher, client roster, client detail view, and ProfileView coach management — on top of Phase 3a's backend and invite flows.

**Architecture:** `MainTabView` gains a `ContextSwitcher` band (via `.safeAreaInset(edge: .bottom)`) and a mode-aware tab set. `CoachRosterViewModel` (@Observable) reads linked athletes + their latest snapshots from SwiftData. `CoachRosterView` is a flat list of client cards with pull-to-refresh. `ClientDetailView` shows a single client's recovery score, ACWR trend, snapshots, and PRs, with a "Log Workout" action that opens `CoachWorkoutEntrySheet`. `ProfileView` gains coach management sections: become-a-coach toggle, invite buttons, and linked-party lists with remove.

**Tech Stack:** SwiftUI, SwiftData, Charts, XCTest

**Prerequisite:** Phase 3a must be complete before starting. The following Phase 3a constructs must exist:
- `AppMode` enum (`.athlete` / `.coach`) in `Enums.swift`
- `RelationshipStatus` enum (`.pending` / `.accepted`) in `Enums.swift`
- `CoachAthleteRelationship` SwiftData `@Model` with `coachId: UUID`, `athleteId: UUID`, `status: RelationshipStatus`
- `Athlete.isCoach: Bool` property on the `Athlete` model
- `AppContainer.currentMode: AppMode` and `AppContainer.setMode(_:)`
- `AppContainer.syncService` — instance of `SyncService`, accessible as `container.syncService`
- `SyncService.pullLinkedAthletes(context:)` instance method
- `SyncService.pullAthleteSnapshots(athleteId:context:)` instance method
- `SyncService.pushCoachWorkloadSnapshot(_:for:context:)` instance method
- `InviteService` static methods (`generateInviteCode`, `resolveCode`, `confirmRelationship`, `sendEmailInvite`, `handleDeepLink`)
- `NFCSessionCoordinator` class (`startWrite(athleteId:)`, `startScan()`)
- `AppRouter` `.onOpenURL` deep link handler and `InviteConfirmationSheet`

---

## File Map

| File | Change |
|---|---|
| `WorkloadApp/Utilities/FontTokens.swift` | Add `bodyMedium` token (15pt DMSans-Medium) |
| `WorkloadApp/Views/Coach/ContextSwitcher.swift` | **Create** — mode toggle band above tab bar |
| `WorkloadApp/ViewModels/CoachRosterViewModel.swift` | **Create** — @Observable, loads linked athletes + latest snapshots |
| `WorkloadApp/Views/Coach/CoachRosterView.swift` | **Create** — flat client roster list |
| `WorkloadApp/Views/Coach/ClientDetailView.swift` | **Create** — single client full profile |
| `WorkloadApp/Views/Coach/CoachWorkoutEntrySheet.swift` | **Create** — simplified workout log (date, duration, sRPE) |
| `WorkloadApp/Services/SyncService.swift` | Add `removeRelationship(id:context:)` instance method |
| `WorkloadApp/App/AppRouter.swift` | `MainTabView` — ContextSwitcher, mode-aware tabs, coach sync triggers |
| `WorkloadApp/Views/Profile/ProfileView.swift` | Add coach sections (toggle, invite buttons, linked lists) |
| `WorkloadAppTests/CoachRosterViewModelTests.swift` | **Create** — unit tests for roster loading logic |

---

## Prerequisite Verification

Before writing any code, confirm the Phase 3a additions are in place.

- [ ] **Step 1: Verify `Athlete.isCoach`**

Open `WorkloadApp/Models/Athlete.swift`. Confirm `var isCoach: Bool = false` is present.

- [ ] **Step 2: Verify `AppMode` and `RelationshipStatus` enums**

Open `WorkloadApp/Models/Enums.swift`. Confirm both enums exist.

- [ ] **Step 3: Verify `CoachAthleteRelationship` model and snapshot computed properties**

Open `WorkloadApp/Models/CoachAthleteRelationship.swift`. Confirm the model is present.

Also confirm:
- `WorkloadApp/Models/WorkloadSnapshot.swift` has `var zone: ACWRZone` (computed property) — used in `ClientCard` and `ClientDetailView`
- `WorkloadApp/Models/RecoverySnapshot.swift` has `var zone: RecoveryZone` (computed property) — used in `ClientCard` and `ClientDetailView`
- `WorkloadApp/Models/PersonalRecord.swift` has `var recordType: PRType` (not `prType`) — used in `ClientDetailView.prSection`

- [ ] **Step 4: Verify `AppContainer.currentMode` and `syncService`**

Open `WorkloadApp/App/AppContainer.swift`. Confirm:
- `var currentMode: AppMode` is present
- `func setMode(_ mode: AppMode)` is present
- `var syncService: SyncService` (or equivalent) is present as an instance property

---

## Task 1: `bodyMedium` Font Token + `ContextSwitcher`

**Files:**
- Modify: `WorkloadApp/Utilities/FontTokens.swift`
- Create: `WorkloadApp/Views/Coach/ContextSwitcher.swift`

The ContextSwitcher is a 44pt-tall horizontal band with two tappable segments ("Athlete" / "Coach"). Active segment: DM Sans Medium, `text1`, 1pt bottom border. Inactive: DM Sans Regular, `text3`. 0pt border radius throughout (Rectangle only). Hairline top border separates it from the content above. Only shown when `athlete.isCoach == true`. Positioning: `.safeAreaInset(edge: .bottom)` on `TabView` inserts the band above the system tab bar.

- [ ] **Step 1: Add `bodyMedium` to FontTokens**

In `WorkloadApp/Utilities/FontTokens.swift`, after the `body` token, insert:

```swift
/// 15pt Medium — active state labels (context switcher, selected states)
static let bodyMedium  = Font.custom("DMSans-Medium",  size: 15)
```

- [ ] **Step 2: Create `ContextSwitcher.swift`**

Create `WorkloadApp/Views/Coach/ContextSwitcher.swift`:

```swift
import SwiftUI
import SwiftData

/// Horizontal mode toggle rendered above the system tab bar.
/// Only visible when the local athlete has isCoach = true.
/// Calls AppContainer.setMode(_:) on tap; mode persists via UserDefaults.
struct ContextSwitcher: View {
    @Environment(AppContainer.self) private var container
    @Query private var athletes: [Athlete]

    private var athlete: Athlete? { athletes.first }

    var body: some View {
        if athlete?.isCoach == true {
            HStack(spacing: 0) {
                modeButton(.athlete, label: "Athlete")
                Rectangle()
                    .fill(ColorTokens.divider)
                    .frame(width: 0.5)
                modeButton(.coach, label: "Coach")
            }
            .frame(height: 44)
            .background(ColorTokens.surface)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(ColorTokens.divider)
                    .frame(height: 0.5)
            }
        }
    }

    @ViewBuilder
    private func modeButton(_ mode: AppMode, label: String) -> some View {
        let isActive = container.currentMode == mode
        Button {
            container.setMode(mode)
        } label: {
            Text(label)
                .font(isActive ? .Tokens.bodyMedium : .Tokens.body)
                .foregroundStyle(isActive ? ColorTokens.text1 : ColorTokens.text3)
                .frame(maxWidth: .infinity, minHeight: 44)
                .overlay(alignment: .bottom) {
                    if isActive {
                        Rectangle()
                            .fill(ColorTokens.text1)
                            .frame(height: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 3: Add files to the Xcode project**

In Xcode: right-click the `Views/` group → "Add Files to 'workload management'" → navigate to `Views/Coach/` → select `ContextSwitcher.swift`. Confirm it is added to the `workload management` target. Also add `FontTokens.swift` if it's not already tracked (it should be).

- [ ] **Step 4: Build to verify no errors**

Press ⌘B. Expected: Build succeeds.

- [ ] **Step 5: Commit**

```bash
cd "/Users/hanwen/Desktop/workload app"
git add WorkloadApp/Utilities/FontTokens.swift WorkloadApp/Views/Coach/ContextSwitcher.swift
git commit -m "feat(3b): add bodyMedium font token and ContextSwitcher"
```

---

## Task 2: `CoachRosterViewModel`

**Files:**
- Create: `WorkloadApp/ViewModels/CoachRosterViewModel.swift`
- Create: `WorkloadAppTests/CoachRosterViewModelTests.swift`

Reads `CoachAthleteRelationship` and `Athlete` records from local SwiftData. No Supabase calls — sync is triggered by the caller (view) before `load()`. Exposes `linkedAthletes`, `latestWorkloadSnapshot[athleteId]`, and `latestRecoverySnapshot[athleteId]`.

- [ ] **Step 1: Write the failing test**

Create `WorkloadAppTests/CoachRosterViewModelTests.swift`:

```swift
import Testing
import SwiftData
@testable import WorkloadApp

@MainActor
struct CoachRosterViewModelTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Athlete.self, CoachAthleteRelationship.self,
            WorkloadSnapshot.self, RecoverySnapshot.self,
            WorkoutSession.self, WellnessCheckIn.self, PersonalRecord.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test func load_returnsAcceptedLinkedAthletes() async throws {
        let context = try makeContext()
        let coachId = UUID()
        let athleteId = UUID()
        context.insert(Athlete(id: coachId, displayName: "Coach"))
        let client = Athlete(id: athleteId, displayName: "Athlete A", sportType: .running)
        context.insert(client)
        context.insert(CoachAthleteRelationship(
            coachId: coachId, athleteId: athleteId, status: .accepted
        ))
        try context.save()

        let vm = CoachRosterViewModel()
        await vm.load(context: context, coachAthleteId: coachId)

        #expect(vm.linkedAthletes.count == 1)
        #expect(vm.linkedAthletes.first?.id == athleteId)
    }

    @Test func load_excludesPendingRelationships() async throws {
        let context = try makeContext()
        let coachId = UUID()
        let athleteId = UUID()
        context.insert(Athlete(id: coachId, displayName: "Coach"))
        context.insert(Athlete(id: athleteId, displayName: "Pending A"))
        context.insert(CoachAthleteRelationship(
            coachId: coachId, athleteId: athleteId, status: .pending
        ))
        try context.save()

        let vm = CoachRosterViewModel()
        await vm.load(context: context, coachAthleteId: coachId)

        #expect(vm.linkedAthletes.isEmpty)
    }

    @Test func load_populatesLatestWorkloadSnapshot() async throws {
        let context = try makeContext()
        let coachId = UUID()
        let athleteId = UUID()
        context.insert(Athlete(id: coachId, displayName: "Coach"))
        let client = Athlete(id: athleteId, displayName: "Client")
        context.insert(client)
        context.insert(CoachAthleteRelationship(
            coachId: coachId, athleteId: athleteId, status: .accepted
        ))
        let older = WorkloadSnapshot(snapshotDate: .now.addingTimeInterval(-86400), acuteLoad: 50)
        older.athlete = client
        let newer = WorkloadSnapshot(snapshotDate: .now, acuteLoad: 100)
        newer.athlete = client
        context.insert(older)
        context.insert(newer)
        try context.save()

        let vm = CoachRosterViewModel()
        await vm.load(context: context, coachAthleteId: coachId)

        #expect(vm.latestWorkloadSnapshot[athleteId]?.acuteLoad == 100)
    }
}
```

- [ ] **Step 2: Add test file to Xcode project**

In Xcode: right-click `WorkloadAppTests/` group → "Add Files to 'workload management'" → select `CoachRosterViewModelTests.swift`. Confirm it is added to the `WorkloadAppTests` target (not the main app target).

- [ ] **Step 3: Run tests to verify they fail**

```bash
xcodebuild test \
  -scheme "workload management" \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  -only-testing WorkloadAppTests/CoachRosterViewModelTests \
  2>&1 | tail -20
```

Expected: FAIL — `CoachRosterViewModel` does not exist yet.

- [ ] **Step 4: Create `CoachRosterViewModel.swift`**

Create `WorkloadApp/ViewModels/CoachRosterViewModel.swift`:

```swift
import Foundation
import SwiftData

@MainActor
@Observable
final class CoachRosterViewModel {
    var linkedAthletes: [Athlete] = []
    var latestWorkloadSnapshot: [UUID: WorkloadSnapshot] = [:]
    var latestRecoverySnapshot: [UUID: RecoverySnapshot] = [:]
    var isLoading = false
    var errorMessage: String?

    func load(context: ModelContext, coachAthleteId: UUID) async {
        isLoading = true
        errorMessage = nil
        do {
            // 1. Find accepted relationships where this user is the coach
            let allRels = try context.fetch(FetchDescriptor<CoachAthleteRelationship>())
            let acceptedAthleteIds = Set(
                allRels
                    .filter { $0.coachId == coachAthleteId && $0.status == .accepted }
                    .map { $0.athleteId }
            )

            // 2. Fetch those athlete profiles
            let allAthletes = try context.fetch(FetchDescriptor<Athlete>())
            linkedAthletes = allAthletes.filter { acceptedAthleteIds.contains($0.id) }

            // 3. Latest workload snapshot per linked athlete
            let allWorkload = try context.fetch(
                FetchDescriptor<WorkloadSnapshot>(
                    sortBy: [SortDescriptor(\.snapshotDate, order: .reverse)]
                )
            )
            for athlete in linkedAthletes {
                latestWorkloadSnapshot[athlete.id] = allWorkload.first { $0.athlete?.id == athlete.id }
            }

            // 4. Latest recovery snapshot per linked athlete
            let allRecovery = try context.fetch(
                FetchDescriptor<RecoverySnapshot>(
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            )
            for athlete in linkedAthletes {
                latestRecoverySnapshot[athlete.id] = allRecovery.first { $0.athlete?.id == athlete.id }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
```

- [ ] **Step 5: Add `CoachRosterViewModel.swift` to Xcode project**

In Xcode: right-click the `ViewModels/` group → "Add Files to 'workload management'" → select `CoachRosterViewModel.swift`. Confirm added to the main app target.

- [ ] **Step 6: Run tests to verify they pass**

```bash
xcodebuild test \
  -scheme "workload management" \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  -only-testing WorkloadAppTests/CoachRosterViewModelTests \
  2>&1 | tail -20
```

Expected: PASS — 3 tests pass.

- [ ] **Step 7: Commit**

```bash
git add WorkloadApp/ViewModels/CoachRosterViewModel.swift \
        WorkloadAppTests/CoachRosterViewModelTests.swift
git commit -m "feat(3b): add CoachRosterViewModel with linked athlete loading"
```

---

## Task 3: `CoachRosterView`

**Files:**
- Create: `WorkloadApp/Views/Coach/CoachRosterView.swift`

Flat `List` of `ClientCard` rows. Each card: athlete name + sport label (top row); recovery zone text label (`RecoveryZone.displayName`) + 3pt left colored border + ACWR zone label (bottom row). Zone is communicated via text — the colored border is supplementary only (per design system). Pull-to-refresh forces sync + VM reload. Tapping a row navigates to `ClientDetailView`. "Add Client" opens a sheet (placeholder for Phase 3a invite flow) rather than pushing ProfileView.

- [ ] **Step 1: Create `CoachRosterView.swift`**

```swift
import SwiftUI
import SwiftData

struct CoachRosterView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Query private var athletes: [Athlete]

    @State private var viewModel = CoachRosterViewModel()
    @State private var showAddClient = false

    private var athlete: Athlete? { athletes.first }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.linkedAthletes.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(ColorTokens.background)
                } else if viewModel.linkedAthletes.isEmpty {
                    emptyState
                } else {
                    clientList
                }
            }
            .background(ColorTokens.background)
            .navigationTitle("Roster")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Client") { showAddClient = true }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text1)
                }
            }
            // Placeholder — replace with Phase 3a EmailInviteSheet(coachId:) when available
            .sheet(isPresented: $showAddClient) {
                Text("Invite an athlete — see Profile for invite options")
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text2)
                    .padding(24)
            }
        }
        .task {
            guard let id = athlete?.id else { return }
            await viewModel.load(context: modelContext, coachAthleteId: id)
        }
    }

    private var clientList: some View {
        List {
            ForEach(viewModel.linkedAthletes, id: \.id) { client in
                NavigationLink {
                    ClientDetailView(athlete: client)
                } label: {
                    ClientCard(
                        athlete: client,
                        workload: viewModel.latestWorkloadSnapshot[client.id],
                        recovery: viewModel.latestRecoverySnapshot[client.id]
                    )
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(ColorTokens.surface)
                .listRowSeparatorTint(ColorTokens.divider)
            }
        }
        .listStyle(.plain)
        .refreshable {
            guard let id = athlete?.id else { return }
            await container.syncService.pullLinkedAthletes(context: modelContext)
            for client in viewModel.linkedAthletes {
                await container.syncService.pullAthleteSnapshots(
                    athleteId: client.id, context: modelContext
                )
            }
            await viewModel.load(context: modelContext, coachAthleteId: id)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No clients yet")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
            Text("Invite an athlete from your Profile to see their workload here.")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
        .background(ColorTokens.background)
    }
}

// MARK: - Client Card

private struct ClientCard: View {
    let athlete: Athlete
    let workload: WorkloadSnapshot?
    let recovery: RecoverySnapshot?

    var body: some View {
        HStack(spacing: 0) {
            // 3pt colored left border — supplementary zone indicator.
            // Zone identity is always communicated in text (recovery.zone.displayName) below.
            Rectangle()
                .fill(recovery.map { ColorTokens.recoveryZoneColor($0.zone) } ?? ColorTokens.divider)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(athlete.displayName)
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text1)
                    Spacer()
                    Text(athlete.sportType.displayName)
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text3)
                }

                HStack {
                    Text(recovery?.zone.displayName ?? "No recovery data")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                    Spacer()
                    Text(workload?.zone.displayName ?? "No load data")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
    }
}
```

- [ ] **Step 2: Add `CoachRosterView.swift` to Xcode project**

In Xcode: right-click `Views/Coach/` group → "Add Files to 'workload management'" → select `CoachRosterView.swift`. Confirm added to the main app target.

- [ ] **Step 3: Build to verify no compile errors**

Press ⌘B. Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add WorkloadApp/Views/Coach/CoachRosterView.swift
git commit -m "feat(3b): add CoachRosterView with client cards and pull-to-refresh"
```

---

## Task 4: `CoachWorkoutEntrySheet` + `ClientDetailView`

**Files:**
- Create: `WorkloadApp/Views/Coach/CoachWorkoutEntrySheet.swift`
- Create: `WorkloadApp/Views/Coach/ClientDetailView.swift`

These are view-only tasks. The only logic is in `logWorkout()`: it computes `load = durationMinutes × srpe`, constructs a `WorkloadSnapshot`, and calls `container.syncService.pushCoachWorkloadSnapshot`. This arithmetic is trivial and the external dependency (`pushCoachWorkloadSnapshot`) is covered by Phase 3a tests. UI-driven test coverage is provided by Task 8 (E2E).

`ClientDetailView` reads data from the athlete's `@Relationship` properties (`workloadSnapshots`, `recoverySnapshots`, `personalRecords`) — no additional fetch is needed.

- [ ] **Step 1: Create `CoachWorkoutEntrySheet.swift`**

```swift
import SwiftUI

struct CoachWorkoutEntrySheet: View {
    let athlete: Athlete
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var sessionDate = Date()
    @State private var durationMinutes: Double = 60
    @State private var srpe: Double = 6
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                    // Date
                    HStack {
                        Text("DATE")
                            .font(.Tokens.micro)
                            .tracking(1.2)
                            .foregroundStyle(ColorTokens.text3)
                        Spacer()
                        DatePicker("", selection: $sessionDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(ColorTokens.surface)

                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                    // Duration
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("DURATION")
                                .font(.Tokens.micro)
                                .tracking(1.2)
                                .foregroundStyle(ColorTokens.text3)
                            Spacer()
                            Text("\(Int(durationMinutes)) min")
                                .font(.Tokens.body)
                                .foregroundStyle(ColorTokens.text1)
                        }
                        Slider(value: $durationMinutes, in: 15...180, step: 5)
                            .tint(ColorTokens.text2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(ColorTokens.surface)

                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                    // sRPE
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("SRPE")
                                .font(.Tokens.micro)
                                .tracking(1.2)
                                .foregroundStyle(ColorTokens.text3)
                            Spacer()
                            Text(String(format: "%.1f / 10", srpe))
                                .font(.Tokens.body)
                                .foregroundStyle(ColorTokens.text1)
                        }
                        Slider(value: $srpe, in: 1...10, step: 0.5)
                            .tint(ColorTokens.text2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(ColorTokens.surface)

                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                    if let error = errorMessage {
                        Text(error)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.zoneDanger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                    }

                    Button {
                        Task { await logWorkout() }
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView()
                            } else {
                                Text("Log Workout for \(athlete.displayName)")
                                    .font(.Tokens.body)
                                    .foregroundStyle(ColorTokens.text1)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(ColorTokens.surface)
                    }
                    .disabled(isLoading)

                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                }
            }
            .background(ColorTokens.background)
            .navigationTitle("Log Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
            }
        }
    }

    private func logWorkout() async {
        isLoading = true
        errorMessage = nil
        do {
            let load = durationMinutes * srpe  // sRPE load = duration × perceived exertion
            let snapshot = WorkloadSnapshot(
                snapshotDate: sessionDate,
                acuteLoad: load,
                chronicLoad: load,  // rough seed; recalculated on next full sync
                acwr: 1.0,
                tsb: 0,
                weeklyVolume: load,
                loadSource: .srpe
            )
            try await container.syncService.pushCoachWorkloadSnapshot(
                snapshot, for: athlete.id, context: modelContext
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
```

- [ ] **Step 2: Create `ClientDetailView.swift`**

```swift
import SwiftUI
import SwiftData
import Charts

struct ClientDetailView: View {
    let athlete: Athlete
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @State private var showWorkoutEntry = false

    private var latestRecovery: RecoverySnapshot? {
        athlete.recoverySnapshots.max(by: { $0.date < $1.date })
    }

    // 28 most recent workload snapshots in chronological order (for chart)
    private var recentWorkload: [WorkloadSnapshot] {
        Array(
            athlete.workloadSnapshots
                .sorted(by: { $0.snapshotDate < $1.snapshotDate })
                .suffix(28)
        )
    }

    // Last 5 snapshots newest-first (for list)
    private var recentWorkloadList: [WorkloadSnapshot] {
        Array(recentWorkload.reversed().prefix(5))
    }

    private var recentPRs: [PersonalRecord] {
        Array(
            athlete.personalRecords
                .sorted(by: { $0.achievedAt > $1.achievedAt })
                .prefix(5)
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                recoveryHero
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                acwrTrend
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                workloadSection
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                prSection
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                Button { showWorkoutEntry = true } label: {
                    Text("Log Workout for \(athlete.displayName)")
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(ColorTokens.surface)
                }

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
            }
        }
        .background(ColorTokens.background)
        .navigationTitle(athlete.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showWorkoutEntry) {
            CoachWorkoutEntrySheet(athlete: athlete)
        }
        .task {
            await container.syncService.pullAthleteSnapshots(
                athleteId: athlete.id, context: modelContext
            )
        }
    }

    // MARK: - Sections

    private var recoveryHero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RECOVERY")
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)

            if let r = latestRecovery {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(String(format: "%.0f", r.recoveryScore))
                        .font(.Tokens.heroScore)
                        .monospacedDigit()
                        .foregroundStyle(ColorTokens.accent)
                    Text(r.zone.displayName)
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text2)
                }
            } else {
                Text("No recovery data")
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
        .background(ColorTokens.surface)
    }

    private var acwrTrend: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ACWR TREND (28 DAYS)")
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            if recentWorkload.isEmpty {
                Text("No workload data")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text3)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            } else {
                Chart(recentWorkload, id: \.id) { snapshot in
                    LineMark(
                        x: .value("Date", snapshot.snapshotDate, unit: .day),
                        y: .value("ACWR", snapshot.acwr)
                    )
                    .foregroundStyle(ColorTokens.chartATL)
                }
                .chartYScale(domain: 0...2)
                .frame(height: 120)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    private var workloadSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("RECENT LOAD")
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            if recentWorkloadList.isEmpty {
                Text("No workload data")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text3)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            } else {
                ForEach(recentWorkloadList, id: \.id) { snapshot in
                    HStack {
                        Text(snapshot.snapshotDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                        Spacer()
                        Text(snapshot.zone.displayName)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                        Text(String(format: "%.2f", snapshot.acwr))
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text3)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                }
            }
        }
    }

    private var prSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PERSONAL RECORDS")
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            if recentPRs.isEmpty {
                Text("No records yet")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text3)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            } else {
                ForEach(recentPRs, id: \.id) { pr in
                    HStack {
                        Text(pr.exerciseName)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text1)
                        Spacer()
                        Text(pr.recordType.displayName)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text3)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                }
            }
        }
    }
}
```

- [ ] **Step 3: Add both files to Xcode project**

In Xcode: right-click `Views/Coach/` group → "Add Files to 'workload management'" → select `CoachWorkoutEntrySheet.swift` and `ClientDetailView.swift`. Confirm added to the main app target.

- [ ] **Step 4: Build to verify no compile errors**

Press ⌘B. Expected: Build succeeds.

- [ ] **Step 5: Commit**

```bash
git add WorkloadApp/Views/Coach/CoachWorkoutEntrySheet.swift \
        WorkloadApp/Views/Coach/ClientDetailView.swift
git commit -m "feat(3b): add ClientDetailView and CoachWorkoutEntrySheet"
```

---

## Task 5: `SyncService.removeRelationship` + Supabase DELETE Policy

**Files:**
- Modify: `WorkloadApp/Services/SyncService.swift`

Adds the ability to remove a coach-athlete relationship from both Supabase and local SwiftData. Requires a new Supabase DELETE RLS policy (not included in Phase 3a) which must be added first. `removeRelationship` is an instance method to match all other `SyncService` methods.

- [ ] **Step 1: Add DELETE policy in Supabase**

In Supabase Dashboard → SQL Editor, run:

```sql
-- Both the coach and the athlete in a relationship can delete it
CREATE POLICY "delete_own_relationship"
ON coach_athlete_relationships FOR DELETE
USING (
  coach_id IN (SELECT id FROM athletes WHERE user_id = auth.uid()) OR
  athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid())
);
```

- [ ] **Step 2: Add `removeRelationship(id:context:)` to `SyncService.swift`**

In `WorkloadApp/Services/SyncService.swift`, add this instance method alongside the other coach methods (after `pushCoachPersonalRecord`):

```swift
/// Deletes a coach-athlete relationship from Supabase and removes the local SwiftData record.
/// Callable by either party (coach or athlete) in the relationship.
func removeRelationship(id: UUID, context: ModelContext) async throws {
    // 1. Delete from Supabase
    try await supabaseClient
        .from("coach_athlete_relationships")
        .delete()
        .eq("id", value: id.uuidString)
        .execute()

    // 2. Remove local SwiftData record
    let descriptor = FetchDescriptor<CoachAthleteRelationship>(
        predicate: #Predicate { $0.id == id }
    )
    if let local = try context.fetch(descriptor).first {
        context.delete(local)
        try context.save()
    }
}
```

Note: use whatever name `SyncService` uses internally for the Supabase client (e.g., `supabaseClient`, `client`, or `container.supabaseClient`). Check the existing `SyncService.swift` for the correct property name before writing this method.

- [ ] **Step 3: Build to verify no compile errors**

Press ⌘B. Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add WorkloadApp/Services/SyncService.swift
git commit -m "feat(3b): add SyncService.removeRelationship + Supabase DELETE policy"
```

---

## Task 6: `MainTabView` — ContextSwitcher + Mode-Aware Tabs + Coach Sync

**Files:**
- Modify: `WorkloadApp/App/AppRouter.swift`

`MainTabView` gains three changes:
1. `@Query private var athletes` to read `athlete.isCoach`
2. Mode-aware `TabView` — athlete mode shows existing 5 tabs; coach mode shows Roster + Profile
3. `.safeAreaInset(edge: .bottom)` adds `ContextSwitcher` above the system tab bar (only renders when `isCoach == true`)
4. `onChange(of: scenePhase)` gains a coach-mode branch

**Note on launch sync:** `onChange(of: scenePhase)` fires when the scene transitions to `.active`, which includes cold launch (the scene moves from inactive to active on first open). There is no separate launch-only trigger needed — the `scenePhase == .active` branch covers both cold launch and foreground-from-background.

- [ ] **Step 1: Read `AppRouter.swift` in full before editing**

Open `WorkloadApp/App/AppRouter.swift`. Confirm the current `MainTabView` struct starts around line 58 and ends around line 85.

- [ ] **Step 2: Replace `MainTabView` struct**

Replace the entire `MainTabView` struct with:

```swift
struct MainTabView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var athletes: [Athlete]

    private var athlete: Athlete? { athletes.first }

    var body: some View {
        TabView {
            if container.currentMode == .coach {
                CoachRosterView()
                    .tabItem { Label("Roster", systemImage: "person.2.fill") }
                ProfileView()
                    .tabItem { Label("Profile", systemImage: "person.fill") }
            } else {
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
        }
        .safeAreaInset(edge: .bottom) {
            // ContextSwitcher renders itself only when athlete.isCoach == true
            ContextSwitcher()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, container.syncService.shouldForegroundSync else { return }
            Task {
                if container.currentMode == .coach, let id = athlete?.id {
                    // Coach mode: sync roster and all linked athlete data
                    await container.syncService.pullLinkedAthletes(context: modelContext)
                    let rels = (try? modelContext.fetch(FetchDescriptor<CoachAthleteRelationship>())) ?? []
                    for rel in rels where rel.coachId == id && rel.status == .accepted {
                        await container.syncService.pullAthleteSnapshots(
                            athleteId: rel.athleteId, context: modelContext
                        )
                    }
                } else {
                    // Athlete mode: existing sync
                    await container.syncService.pushAll(context: modelContext)
                    await container.syncService.pullAll(context: modelContext)
                }
            }
        }
        .onChange(of: container.currentMode) { _, newMode in
            // Fire sync immediately when the user switches to coach mode
            guard newMode == .coach, container.syncService.shouldForegroundSync,
                  let id = athlete?.id else { return }
            Task {
                await container.syncService.pullLinkedAthletes(context: modelContext)
                let rels = (try? modelContext.fetch(FetchDescriptor<CoachAthleteRelationship>())) ?? []
                for rel in rels where rel.coachId == id && rel.status == .accepted {
                    await container.syncService.pullAthleteSnapshots(
                        athleteId: rel.athleteId, context: modelContext
                    )
                }
            }
        }
    }
}
```

- [ ] **Step 3: Build to verify no compile errors**

Press ⌘B. Expected: Build succeeds.

- [ ] **Step 4: Smoke-test in Simulator**

Run (⌘R) on iPhone 16 Simulator. Log in. Verify:
- No ContextSwitcher appears (athlete.isCoach == false by default)
- All five athlete tabs are present and functional

- [ ] **Step 5: Commit**

```bash
git add WorkloadApp/App/AppRouter.swift
git commit -m "feat(3b): mode-aware MainTabView with ContextSwitcher and coach sync triggers"
```

---

## Task 7: `ProfileView` Coach Additions

**Files:**
- Modify: `WorkloadApp/Views/Profile/ProfileView.swift`

Adds three sections inside the existing `if let athlete` block:
1. **"Coaching" section** (athlete mode only, per spec): "Become a coach" toggle — sets `athlete.isCoach = true`, calls `pushAll` to sync
2. **"My Coach" section** (athlete mode only): "Invite my coach" button (code flow), "Link via NFC" button, linked coaches list with swipe-to-remove
3. **"My Athletes" section** (coach mode only, requires `isCoach == true`): "Invite an athlete" button (email flow), "Link via NFC" button (reads NFC tag → shows confirmation), linked athletes list with swipe-to-remove

NFC flows: After scanning, a confirmation sheet is shown before committing the relationship (spec requires an explicit confirmation screen). A `pendingNFCAthleteId` state variable holds the scanned UUID and triggers the sheet.

All remove actions call `container.syncService.removeRelationship(id:context:)`.

- [ ] **Step 1: Read `ProfileView.swift` in full before editing**

Open `WorkloadApp/Views/Profile/ProfileView.swift`. Understand the existing section structure before making changes.

- [ ] **Step 2: Add state variables**

Inside `ProfileView`, add:

```swift
@State private var showEnterCodeSheet = false
@State private var showEmailInviteSheet = false
@State private var pendingNFCAthleteId: UUID?  // set after NFC scan, triggers confirmation sheet
@Query private var allRelationships: [CoachAthleteRelationship]

private var linkedCoaches: [CoachAthleteRelationship] {
    guard let id = athlete?.id else { return [] }
    return allRelationships.filter { $0.athleteId == id && $0.status == .accepted }
}

private var linkedAthletes: [CoachAthleteRelationship] {
    guard let id = athlete?.id else { return [] }
    return allRelationships.filter { $0.coachId == id && $0.status == .accepted }
}
```

- [ ] **Step 3: Add the three new List sections**

Inside the `if let athlete` block, before the existing Sign Out section, add:

```swift
// "Become a coach" toggle — athlete mode only (spec: ProfileView additions, athlete mode)
if container.currentMode == .athlete {
    Section("Coaching") {
        Toggle(isOn: Binding(
            get: { athlete.isCoach },
            set: { newValue in
                athlete.isCoach = newValue
                athlete.updatedAt = .now
                Task { await container.syncService.pushAll(context: modelContext) }
            }
        )) {
            Text("I am a coach")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
        }
    }
}

// My Coach section — athlete mode only
if container.currentMode == .athlete {
    Section("My Coach") {
        Button("Invite my coach (share code)") {
            showEnterCodeSheet = true
        }
        .font(.Tokens.label)
        .foregroundStyle(ColorTokens.text2)

        Button("Link via NFC") {
            guard let id = athlete.id as UUID? else { return }
            Task {
                let nfc = NFCSessionCoordinator()
                try? await nfc.startWrite(athleteId: id)
            }
        }
        .font(.Tokens.label)
        .foregroundStyle(ColorTokens.text2)

        ForEach(linkedCoaches, id: \.id) { rel in
            LinkedPartyRow(displayId: rel.coachId, allAthletes: allAthletes)
        }
        .onDelete { indexSet in
            for i in indexSet {
                let rel = linkedCoaches[i]
                Task {
                    try? await container.syncService.removeRelationship(
                        id: rel.id, context: modelContext
                    )
                }
            }
        }
    }
}

// My Athletes section — coach mode only
if athlete.isCoach && container.currentMode == .coach {
    Section("My Athletes") {
        Button("Invite an athlete (send email)") {
            showEmailInviteSheet = true
        }
        .font(.Tokens.label)
        .foregroundStyle(ColorTokens.text2)

        // NFC scan — reads athleteId from athlete's NFC tag → shows confirmation sheet
        Button("Link via NFC") {
            guard let coachId = athlete.id as UUID? else { return }
            Task {
                let nfc = NFCSessionCoordinator()
                if let scannedAthleteId = try? await nfc.startScan() {
                    // Trigger confirmation sheet; relationship is only committed after user confirms
                    pendingNFCAthleteId = scannedAthleteId
                }
            }
        }
        .font(.Tokens.label)
        .foregroundStyle(ColorTokens.text2)

        ForEach(linkedAthletes, id: \.id) { rel in
            LinkedPartyRow(displayId: rel.athleteId, allAthletes: allAthletes)
        }
        .onDelete { indexSet in
            for i in indexSet {
                let rel = linkedAthletes[i]
                Task {
                    try? await container.syncService.removeRelationship(
                        id: rel.id, context: modelContext
                    )
                }
            }
        }
    }
}
```

Note: `allAthletes` in `LinkedPartyRow` refers to the `@Query private var athletes: [Athlete]` already on `ProfileView`. Pass it as a parameter so `LinkedPartyRow` doesn't need its own `@Query`.

- [ ] **Step 4: Add sheet modifiers and NFC confirmation**

After the existing `.navigationTitle("Profile")`, add:

```swift
// Code invite sheet (athlete inviting a coach)
.sheet(isPresented: $showEnterCodeSheet) {
    // Replace with Phase 3a's EnterInviteCodeSheet(athleteId: athlete!.id) when available
    Text("Enter invite code — Phase 3a sheet")
        .font(.Tokens.body).padding(24)
}
// Email invite sheet (coach inviting an athlete)
.sheet(isPresented: $showEmailInviteSheet) {
    // Replace with Phase 3a's EmailInviteSheet(coachId: athlete!.id) when available
    Text("Email invite — Phase 3a sheet")
        .font(.Tokens.body).padding(24)
}
// NFC confirmation — presented after coach scans an athlete's NFC tag
// Confirm before committing the relationship (spec requirement: explicit confirmation screen)
.sheet(item: $pendingNFCAthleteId) { scannedAthleteId in
    // Replace with Phase 3a's InviteConfirmationSheet(coachId:, athleteId:) when available
    // That sheet calls InviteService.confirmRelationship after the user taps Confirm.
    VStack(spacing: 16) {
        Text("Link this athlete?")
            .font(.Tokens.sectionHead)
            .foregroundStyle(ColorTokens.text1)
        Text("Athlete ID: \(scannedAthleteId.uuidString.prefix(8))...")
            .font(.Tokens.label)
            .foregroundStyle(ColorTokens.text3)
        Button("Confirm") {
            guard let coachId = athlete?.id else { return }
            Task {
                _ = try? await InviteService.confirmRelationship(
                    coachId: coachId,
                    athleteId: scannedAthleteId,
                    invitationCode: nil,
                    client: container.supabaseClient
                )
                pendingNFCAthleteId = nil
            }
        }
        .font(.Tokens.body)
        .foregroundStyle(ColorTokens.text1)
        Button("Cancel") { pendingNFCAthleteId = nil }
            .font(.Tokens.label)
            .foregroundStyle(ColorTokens.text3)
    }
    .padding(24)
}
```

Note: `UUID` does not conform to `Identifiable` by default for use with `sheet(item:)`. Wrap it: add `extension UUID: @retroactive Identifiable { public var id: UUID { self } }` in a new file `WorkloadApp/Utilities/UUIDIdentifiable.swift`, or use a simple wrapper struct.

Alternatively, use `@State private var showNFCConfirmation = false` + separate `@State private var pendingNFCAthleteId: UUID?` and trigger `.sheet(isPresented: $showNFCConfirmation)`.

- [ ] **Step 5: Add `LinkedPartyRow` as a private struct**

At the bottom of `ProfileView.swift`, add:

```swift
/// Displays a linked party's display name, resolved from a pre-fetched athlete array.
/// Falls back to a short UUID prefix if the athlete is not found locally.
private struct LinkedPartyRow: View {
    let displayId: UUID
    let allAthletes: [Athlete]

    private var displayName: String {
        allAthletes.first(where: { $0.id == displayId })?.displayName
            ?? String(displayId.uuidString.prefix(8))
    }

    var body: some View {
        Text(displayName)
            .font(.Tokens.body)
            .foregroundStyle(ColorTokens.text1)
    }
}
```

- [ ] **Step 6: Resolve `UUID` conformance for `sheet(item:)` if needed**

`UUID` does not conform to `Identifiable` by default. If the compiler reports an error on `.sheet(item: $pendingNFCAthleteId)`, create `WorkloadApp/Utilities/UUIDIdentifiable.swift`:

```swift
extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}
```

Then add it to the Xcode project: right-click `Utilities/` group → "Add Files to 'workload management'" → select `UUIDIdentifiable.swift`, confirm main app target.

Alternatively, replace `pendingNFCAthleteId: UUID?` + `sheet(item:)` with `pendingNFCAthleteId: UUID?` + `showNFCConfirmation: Bool` + `sheet(isPresented: $showNFCConfirmation)`.

- [ ] **Step 7: Build to verify no compile errors**

Press ⌘B. Expected: Build succeeds.

- [ ] **Step 8: Commit**

```bash
# Stage ProfileView and UUIDIdentifiable.swift if it was created
git add WorkloadApp/Views/Profile/ProfileView.swift
git add WorkloadApp/Utilities/UUIDIdentifiable.swift 2>/dev/null || true
git commit -m "feat(3b): add coach sections to ProfileView"
```

---

## Task 8: End-to-End Manual Test

No code changes — manual verification checklist.

- [ ] **Step 1: Build and run on iPhone 16 Simulator**

Press ⌘R. Log in using the Phase 2 test account.

- [ ] **Step 2: ContextSwitcher hidden for non-coaches**

Confirm no ContextSwitcher band appears above the tab bar. All 5 athlete tabs are present.

- [ ] **Step 3: Enable coach mode**

Profile → Coaching → toggle "I am a coach" ON. Verify toggle state persists. After sync completes (or after re-launching), the ContextSwitcher should appear above the tab bar.

- [ ] **Step 4: Switch to coach mode**

Tap "Coach" in the ContextSwitcher. Verify:
- Tab bar shows Roster + Profile only
- CoachRosterView empty state: "No clients yet"
- No crash

- [ ] **Step 5: Switch back to athlete mode**

Tap "Athlete" in the ContextSwitcher. All 5 athlete tabs reappear.

- [ ] **Step 6: Manually seed a linked athlete in Supabase**

In Supabase Dashboard → SQL Editor, run (substitute real UUIDs):

```sql
-- Link a second test athlete to the coach
INSERT INTO coach_athlete_relationships (coach_id, athlete_id, status)
VALUES ('<coach-athlete-uuid>', '<second-athlete-uuid>', 'accepted');
```

Switch to coach mode and pull to refresh on Roster. Verify the client card appears with display name, sport type, recovery zone label, and ACWR zone label.

- [ ] **Step 7: Tap client card → ClientDetailView**

Verify:
- Hero recovery score shows (or "No recovery data" if empty)
- ACWR trend chart renders or shows empty state
- Recent load and PR sections render
- "Log Workout" button is present

- [ ] **Step 8: Log a workout for the client**

Tap "Log Workout." In `CoachWorkoutEntrySheet`: set duration to 60 min, sRPE to 7. Tap "Log Workout for [name]." Verify the sheet dismisses without error.

- [ ] **Step 9: Verify workload snapshot persisted**

Return to `ClientDetailView` and pull to refresh. The new snapshot should appear in the "Recent Load" list.

- [ ] **Step 10: Remove a linked athlete**

Profile (coach mode) → My Athletes → swipe left on the athlete row → Delete. Verify the row disappears. Return to Roster and pull to refresh — the client card should be gone.

- [ ] **Step 11: Final commit**

```bash
git add -A
git status  # verify only expected changes
git commit -m "feat(3b): complete Phase 3b coach UI"
```
