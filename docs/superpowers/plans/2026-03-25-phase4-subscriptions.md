# Phase 4 — Subscriptions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add RevenueCat-powered Free/Pro subscriptions — 7-day history gate, coach-mode gate, hybrid teaser paywall with context-aware UpgradeSheet.

**Architecture:** `SubscriptionService` wraps RevenueCat and lives in `AppContainer` (same pattern as `AuthService`). Gating is done by post-filtering `@Query` results in views (since `@Query` predicates are compile-time only). `UpgradeSheet` is a single sheet parametrised by trigger type; `HistoryTeaserBanner` is a reusable component placed at the bottom of truncated lists.

**Tech Stack:** RevenueCat iOS SDK v5 (SPM), SwiftUI, SwiftData, XCTest

---

## File Map

| Action | Path | Purpose |
|--------|------|---------|
| Create | `WorkloadApp/RevenueCatConfig.swift` | API key constant (mirrors `SupabaseConfig.swift`) |
| Create | `WorkloadApp/Services/SubscriptionService.swift` | RevenueCat wrapper — `isPro`, purchase, restore |
| Create | `WorkloadApp/Views/Subscription/UpgradeSheet.swift` | Paywall sheet + `HistoryTeaserBanner` |
| Modify | `WorkloadApp/App/AppContainer.swift` | Add `subscriptionService` property, init first |
| Modify | `WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift` | Post-filter sessions to 7 days, append teaser |
| Modify | `WorkloadApp/Views/Workload/WorkloadView.swift` | Post-filter snapshots to 7 days, append teaser |
| Modify | `WorkloadApp/Views/Coach/ContextSwitcher.swift` | Gate coach mode with Pro check |
| Create | `WorkloadAppTests/SubscriptionGatingTests.swift` | Tests for date-filter + locked-weeks logic |

---

## Task 1: Add RevenueCat via SPM and create RevenueCatConfig

**Files:**
- Create: `WorkloadApp/RevenueCatConfig.swift`

> RevenueCat is added as a Swift Package. It cannot be added from code — this is a one-time Xcode step.

- [ ] **Step 1: Add RevenueCat package in Xcode**

  In Xcode: File → Add Package Dependencies…
  URL: `https://github.com/RevenueCat/purchases-ios.git`
  Version rule: Up to Next Major from `5.0.0`
  Product to add to target: `RevenueCat`

  Expected: `RevenueCat` appears under Package Dependencies in the project navigator.

- [ ] **Step 2: Create RevenueCatConfig.swift**

```swift
// WorkloadApp/RevenueCatConfig.swift
import Foundation

enum RevenueCatConfig {
    /// Replace with your real RevenueCat iOS public API key from app.revenuecat.com.
    static let apiKey = "appl_REPLACE_WITH_YOUR_KEY"
}
```

- [ ] **Step 3: Commit**

```bash
git add WorkloadApp/RevenueCatConfig.swift
git commit -m "feat(subscriptions): add RevenueCat SPM dependency and config stub"
```

---

## Task 2: SubscriptionService

**Files:**
- Create: `WorkloadApp/Services/SubscriptionService.swift`
- Create: `WorkloadAppTests/SubscriptionGatingTests.swift`

> `SubscriptionService` wraps RevenueCat. Because `Purchases.shared` is a real SDK singleton (StoreKit-backed), unit tests cover only the pure helper functions. End-to-end purchase flow is tested manually in the Xcode sandbox.

- [ ] **Step 1: Write failing tests for pure gating helpers**

```swift
// WorkloadAppTests/SubscriptionGatingTests.swift
import XCTest
@testable import WorkloadApp

final class SubscriptionGatingTests: XCTestCase {

    // MARK: - filterSessionsForFree

    func test_filterSessionsForFree_keepsSessionsWithin7Days() {
        let now = Date()
        let recent = makeSession(daysAgo: 3, from: now)
        let old = makeSession(daysAgo: 10, from: now)
        let result = SubscriptionService.filterSessionsForFree([recent, old], relativeTo: now)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, recent.id)
    }

    func test_filterSessionsForFree_includesSessionExactly7DaysAgo() {
        let now = Date()
        let boundary = makeSession(daysAgo: 7, from: now)
        let result = SubscriptionService.filterSessionsForFree([boundary], relativeTo: now)
        XCTAssertEqual(result.count, 1)
    }

    func test_filterSessionsForFree_excludesSessionOver7Days() {
        let now = Date()
        let old = makeSession(daysAgo: 8, from: now)
        let result = SubscriptionService.filterSessionsForFree([old], relativeTo: now)
        XCTAssertEqual(result.count, 0)
    }

    // MARK: - lockedWeeks

    func test_lockedWeeks_returnsCorrectCount() {
        XCTAssertEqual(SubscriptionService.lockedWeeks(totalSessions: 30, visibleSessions: 5), 3)
    }

    func test_lockedWeeks_returnsZeroWhenNothingLocked() {
        XCTAssertEqual(SubscriptionService.lockedWeeks(totalSessions: 5, visibleSessions: 5), 0)
    }

    func test_lockedWeeks_returnsZeroWhenVisibleExceedsTotal() {
        XCTAssertEqual(SubscriptionService.lockedWeeks(totalSessions: 3, visibleSessions: 10), 0)
    }

    // MARK: - filterSnapshotsForFree

    func test_filterSnapshotsForFree_keepsSnapshotsWithin7Days() {
        let now = Date()
        let recent = makeSnapshot(daysAgo: 2, from: now)
        let old = makeSnapshot(daysAgo: 14, from: now)
        let result = SubscriptionService.filterSnapshotsForFree([recent, old], relativeTo: now)
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - Helpers

    private func makeSession(daysAgo: Int, from date: Date) -> WorkoutSession {
        let s = WorkoutSession(
            sportType: .strength,
            sessionDate: Calendar.current.date(byAdding: .day, value: -daysAgo, to: date)!,
            durationSeconds: 3600
        )
        return s
    }

    private func makeSnapshot(daysAgo: Int, from date: Date) -> WorkloadSnapshot {
        WorkloadSnapshot(
            snapshotDate: Calendar.current.date(byAdding: .day, value: -daysAgo, to: date)!,
            acuteLoad: 50, chronicLoad: 45, acwr: 1.1,
            zone: .optimal, tsb: 5
        )
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

  Build target: `WorkloadAppTests`
  Expected: compile error — `SubscriptionService` does not exist yet.

- [ ] **Step 3: Implement SubscriptionService**

```swift
// WorkloadApp/Services/SubscriptionService.swift
import Foundation
import RevenueCat

@MainActor
@Observable
final class SubscriptionService {

    /// True when the current user holds an active "pro" entitlement.
    /// Stored var (not computed) so @Observable tracks mutations.
    private(set) var isPro: Bool = false

    /// True when the "pro" entitlement has never had a free trial on this Apple ID.
    /// Derived from the current offering's annual package introductory discount.
    private(set) var trialAvailable: Bool = true

    init() {
        Purchases.configure(withAPIKey: RevenueCatConfig.apiKey)
        Purchases.logLevel = .error
        refreshEntitlement()
    }

    // MARK: - Entitlement

    func refreshEntitlement() {
        Task {
            guard let info = try? await Purchases.shared.customerInfo() else { return }
            isPro = info.entitlements["pro"]?.isActive == true
        }
    }

    // MARK: - Offering

    func fetchOffering() async throws -> Offering? {
        let offerings = try await Purchases.shared.offerings()
        return offerings.current
    }

    // MARK: - Purchase

    func purchase(package: Package) async throws {
        let result = try await Purchases.shared.purchase(package: package)
        isPro = result.customerInfo.entitlements["pro"]?.isActive == true
    }

    // MARK: - Restore

    func restorePurchases() async throws {
        let info = try await Purchases.shared.restorePurchases()
        isPro = info.entitlements["pro"]?.isActive == true
    }

    // MARK: - Pure helpers (static — testable without SDK)

    /// Returns sessions dated within 7 days of `date`, inclusive.
    static func filterSessionsForFree(
        _ sessions: [WorkoutSession],
        relativeTo date: Date = .now
    ) -> [WorkoutSession] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: date)!
        return sessions.filter { $0.sessionDate >= cutoff }
    }

    /// Returns snapshots dated within 7 days of `date`, inclusive.
    static func filterSnapshotsForFree(
        _ snapshots: [WorkloadSnapshot],
        relativeTo date: Date = .now
    ) -> [WorkloadSnapshot] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: date)!
        return snapshots.filter { $0.snapshotDate >= cutoff }
    }

    /// Converts a count of locked (out-of-window) sessions into approximate weeks.
    /// Returns 0 if nothing is locked.
    static func lockedWeeks(totalSessions: Int, visibleSessions: Int) -> Int {
        let locked = max(0, totalSessions - visibleSessions)
        guard locked > 0 else { return 0 }
        // Rough heuristic: assume ~3 sessions/week
        return max(1, locked / 3)
    }
}
```

- [ ] **Step 4: Run tests — expect all pass**

  Expected: 7 tests pass in `SubscriptionGatingTests`.

- [ ] **Step 5: Commit**

```bash
git add WorkloadApp/Services/SubscriptionService.swift WorkloadAppTests/SubscriptionGatingTests.swift
git commit -m "feat(subscriptions): add SubscriptionService with pure gating helpers + tests"
```

---

## Task 3: Wire SubscriptionService into AppContainer

**Files:**
- Modify: `WorkloadApp/App/AppContainer.swift`

- [ ] **Step 1: Add subscriptionService to AppContainer**

  Add a new stored property after the existing service declarations (no `import RevenueCat` needed — `AppContainer` only holds `SubscriptionService`, not any RevenueCat types directly):
  ```swift
  let subscriptionService: SubscriptionService
  ```

  In `init()`, initialise it **before** all other services (first line of `init`):
  ```swift
  self.subscriptionService = SubscriptionService()
  ```

  The full `init()` open should look like:
  ```swift
  init() {
      self.subscriptionService = SubscriptionService()

      let encoder = JSONEncoder()
      // ... rest of existing init unchanged
  ```

- [ ] **Step 2: Build — expect no errors**

- [ ] **Step 3: Commit**

```bash
git add WorkloadApp/App/AppContainer.swift
git commit -m "feat(subscriptions): wire SubscriptionService into AppContainer"
```

---

## Task 4: UpgradeSheet and HistoryTeaserBanner

**Files:**
- Create: `WorkloadApp/Views/Subscription/UpgradeSheet.swift`

> Both components live in the same file — `HistoryTeaserBanner` is small and only used as an entry point to `UpgradeSheet`. If it grows, split it out.

- [ ] **Step 1: Create the Subscription views directory and file**

```swift
// WorkloadApp/Views/Subscription/UpgradeSheet.swift
import SwiftUI
import RevenueCat

// MARK: - Trigger

enum UpgradeTrigger {
    case history(lockedWeeks: Int)
    case coach
}

// MARK: - UpgradeSheet

struct UpgradeSheet: View {
    let trigger: UpgradeTrigger
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var offering: Offering?
    @State private var selectedPlan: PlanOption = .annual
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    enum PlanOption { case annual, monthly }

    private var headline: String {
        switch trigger {
        case .history(let weeks):
            return weeks > 0
                ? "\(weeks) week\(weeks == 1 ? "" : "s") of training history waiting"
                : "Your full training history is waiting"
        case .coach:
            return "Coach your athletes from one place"
        }
    }

    private var subtitle: String {
        switch trigger {
        case .history: return "Unlock everything with Pro — no data is ever deleted."
        case .coach:   return "Manage your full roster and log workouts for any athlete."
        }
    }

    private var annualPackage: Package? {
        offering?.availablePackages.first { $0.packageType == .annual }
    }

    private var monthlyPackage: Package? {
        offering?.availablePackages.first { $0.packageType == .monthly }
    }

    private var activePackage: Package? {
        selectedPlan == .annual ? annualPackage : monthlyPackage
    }

    /// True only if the selected package still has an introductory offer (trial not yet used).
    private var trialAvailable: Bool {
        activePackage?.storeProduct.introductoryDiscount != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Rectangle()
                .fill(ColorTokens.text3.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 24)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // MARK: Headline
                    VStack(alignment: .leading, spacing: 8) {
                        Text("WORKLOAD PRO")
                            .font(.Tokens.micro)
                            .tracking(1.2)
                            .foregroundStyle(ColorTokens.text3)

                        Text(headline)
                            .font(.Tokens.pageTitle)
                            .foregroundStyle(ColorTokens.text1)

                        Text(subtitle)
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text2)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)

                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                    // MARK: Plan toggle
                    HStack(spacing: 0) {
                        planButton(.annual,
                                   title: "ANNUAL",
                                   price: annualPackage?.localizedPriceString ?? "$79.99/yr",
                                   badge: "BEST VALUE")
                        Rectangle().fill(ColorTokens.divider).frame(width: 0.5)
                        planButton(.monthly,
                                   title: "MONTHLY",
                                   price: monthlyPackage?.localizedPriceString ?? "$9.99/mo",
                                   badge: nil)
                    }
                    .frame(height: 72)

                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                    // MARK: CTA
                    VStack(spacing: 16) {
                        if let errorMessage {
                            Text(errorMessage)
                                .font(.Tokens.label)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }

                        Button {
                            guard let pkg = activePackage else { return }
                            Task { await doPurchase(pkg) }
                        } label: {
                            if isPurchasing {
                                ProgressView()
                                    .tint(ColorTokens.background)
                                    .frame(maxWidth: .infinity, minHeight: 48)
                            } else {
                                Text(trialAvailable ? "Start 7-Day Free Trial" : "Subscribe")
                                    .font(.Tokens.bodyMedium)
                                    .foregroundStyle(ColorTokens.background)
                                    .frame(maxWidth: .infinity, minHeight: 48)
                                    .background(ColorTokens.text1)
                            }
                        }
                        .disabled(isPurchasing || activePackage == nil)
                        .buttonStyle(.plain)

                        Text("Full history · Coach mode · Advanced charts")
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text3)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

                        Text("Team plans — coming soon")
                            .font(.Tokens.micro)
                            .foregroundStyle(ColorTokens.text3.opacity(0.6))
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)

                    // MARK: Footer
                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                    HStack(spacing: 24) {
                        Button("Restore purchases") {
                            Task { await doRestore() }
                        }
                        Button("Terms") {
                            openURL(URL(string: "https://example.com/terms")!)
                        }
                        Button("Privacy") {
                            openURL(URL(string: "https://example.com/privacy")!)
                        }
                    }
                    .font(.Tokens.micro)
                    .foregroundStyle(ColorTokens.text3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
            }
        }
        .background(ColorTokens.background)
        .task { await loadOffering() }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func planButton(_ plan: PlanOption, title: String, price: String, badge: String?) -> some View {
        let isSelected = selectedPlan == plan
        Button { selectedPlan = plan } label: {
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.Tokens.micro)
                        .tracking(1)
                        .foregroundStyle(ColorTokens.text3)
                    if let badge {
                        Text(badge)
                            .font(.custom("DMSans-Medium", size: 9))
                            .tracking(0.8)
                            .foregroundStyle(ColorTokens.text3)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .overlay { Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5) }
                    }
                }
                Text(price)
                    .font(isSelected ? .Tokens.bodyMedium : .Tokens.body)
                    .foregroundStyle(isSelected ? ColorTokens.text1 : ColorTokens.text2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                if isSelected {
                    Rectangle().fill(ColorTokens.text1).frame(height: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func loadOffering() async {
        offering = try? await container.subscriptionService.fetchOffering()
    }

    private func doPurchase(_ package: Package) async {
        isPurchasing = true
        errorMessage = nil
        do {
            try await container.subscriptionService.purchase(package: package)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isPurchasing = false
    }

    private func doRestore() async {
        isPurchasing = true
        errorMessage = nil
        do {
            try await container.subscriptionService.restorePurchases()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isPurchasing = false
    }
}

// MARK: - HistoryTeaserBanner

struct HistoryTeaserBanner: View {
    let lockedWeeks: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(lockedWeeks) week\(lockedWeeks == 1 ? "" : "s") of training data locked")
                        .font(.Tokens.bodyMedium)
                        .foregroundStyle(ColorTokens.text1)
                    Text("Unlock your full history with Pro")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
                Spacer()
                Image(systemName: "lock.fill")
                    .foregroundStyle(ColorTokens.text3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(ColorTokens.surface)
            .overlay(alignment: .top) {
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
            }
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Build — expect no errors**

- [ ] **Step 3: Commit**

```bash
git add WorkloadApp/Views/Subscription/UpgradeSheet.swift
git commit -m "feat(subscriptions): add UpgradeSheet and HistoryTeaserBanner"
```

---

## Task 5: Gate WorkoutLogView history

**Files:**
- Modify: `WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift`

> `@Query` returns all sessions. Post-filter to 7 days when not Pro. Count all sessions to compute locked weeks for the teaser banner.

- [ ] **Step 1: Add `isPro` and upgrade sheet state to WorkoutLogView**

  Add at the top of `WorkoutLogView`:
  ```swift
  @Environment(AppContainer.self) private var container
  @State private var showUpgrade = false
  ```

- [ ] **Step 2: Replace `filteredSessions` computed property**

  The existing `filteredSessions` filters by `SessionType`. Extend it to also apply the 7-day gate when not Pro.

  Replace the existing computed property:
  ```swift
  // Old:
  private var filteredSessions: [WorkoutSession] {
      guard let type = selectedSessionType else { return sessions }
      return sessions.filter { $0.sessionType == type }
  }
  ```

  With:
  ```swift
  // New:
  private var visibleSessions: [WorkoutSession] {
      let base = container.subscriptionService.isPro
          ? sessions
          : SubscriptionService.filterSessionsForFree(sessions)
      guard let type = selectedSessionType else { return base }
      return base.filter { $0.sessionType == type }
  }

  private var lockedWeeks: Int {
      guard !container.subscriptionService.isPro else { return 0 }
      let visible = SubscriptionService.filterSessionsForFree(sessions)
      return SubscriptionService.lockedWeeks(
          totalSessions: sessions.count,
          visibleSessions: visible.count
      )
  }
  ```

- [ ] **Step 3: Update body to use `visibleSessions` and append teaser**

  - Replace all references to `filteredSessions` in `body` with `visibleSessions`.
  - Inside the `ScrollView` `VStack`, after the `ForEach` loop, add:
  ```swift
  if lockedWeeks > 0 {
      HistoryTeaserBanner(lockedWeeks: lockedWeeks) {
          showUpgrade = true
      }
  }
  ```
  - Add `.sheet` modifier on the `NavigationStack`:
  ```swift
  .sheet(isPresented: $showUpgrade) {
      UpgradeSheet(trigger: .history(lockedWeeks: lockedWeeks))
  }
  ```

- [ ] **Step 4: Build — expect no errors**

- [ ] **Step 5: Commit**

```bash
git add WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift
git commit -m "feat(subscriptions): gate workout log history to 7 days for free tier"
```

---

## Task 6: Gate WorkloadView history

**Files:**
- Modify: `WorkloadApp/Views/Workload/WorkloadView.swift`

- [ ] **Step 1: Add environment and upgrade state**

  At top of `WorkloadView`:
  ```swift
  @Environment(AppContainer.self) private var container
  @State private var showUpgrade = false
  ```

- [ ] **Step 2: Add computed properties for gated snapshots and locked weeks**

  ```swift
  private var visibleSnapshots: [WorkloadSnapshot] {
      container.subscriptionService.isPro
          ? snapshots
          : SubscriptionService.filterSnapshotsForFree(snapshots)
  }

  private var lockedWeeks: Int {
      guard !container.subscriptionService.isPro else { return 0 }
      let visible = SubscriptionService.filterSnapshotsForFree(snapshots)
      return SubscriptionService.lockedWeeks(
          totalSessions: snapshots.count,
          visibleSessions: visible.count
      )
  }
  ```

- [ ] **Step 3: Update body to use `visibleSnapshots` and append teaser**

  - Replace `snapshots` with `visibleSnapshots` in:
    - `latestSnapshot` computed property (or inline): use `visibleSnapshots.first`
    - `snapshots.count > 1` check: use `visibleSnapshots.count > 1`
    - `snapshots.prefix(28)`: use `visibleSnapshots.prefix(28)`
  - After the `LoadTrendChartView` divider block, add:
  ```swift
  if lockedWeeks > 0 {
      HistoryTeaserBanner(lockedWeeks: lockedWeeks) {
          showUpgrade = true
      }
      Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
  }
  ```
  - Add `.sheet` on `NavigationStack`:
  ```swift
  .sheet(isPresented: $showUpgrade) {
      UpgradeSheet(trigger: .history(lockedWeeks: lockedWeeks))
  }
  ```

- [ ] **Step 4: Fix `latestSnapshot` property**

  `latestSnapshot` is currently `snapshots.first`. Update it to use `visibleSnapshots`:
  ```swift
  private var latestSnapshot: WorkloadSnapshot? { visibleSnapshots.first }
  ```

- [ ] **Step 5: Build — expect no errors**

- [ ] **Step 6: Commit**

```bash
git add WorkloadApp/Views/Workload/WorkloadView.swift
git commit -m "feat(subscriptions): gate workload/ACWR history to 7 days for free tier"
```

---

## Task 7: Gate ContextSwitcher coach mode

**Files:**
- Modify: `WorkloadApp/Views/Coach/ContextSwitcher.swift`

> Free users see both Athlete and Coach buttons. Tapping Coach while not Pro presents UpgradeSheet instead of switching mode.

- [ ] **Step 1: Add upgrade sheet state**

  Add to `ContextSwitcher`:
  ```swift
  @State private var showUpgrade = false
  ```

- [ ] **Step 2: Update modeButton to intercept coach tap when not Pro**

  Modify the `Button` action inside `modeButton(_:label:)`:
  ```swift
  Button {
      if mode == .coach && !container.subscriptionService.isPro {
          showUpgrade = true
      } else {
          container.setMode(mode)
      }
  } label: { ... }
  ```

- [ ] **Step 3: Add sheet to the outer HStack**

  After the closing brace of the `HStack`, add:
  ```swift
  .sheet(isPresented: $showUpgrade) {
      UpgradeSheet(trigger: .coach)
  }
  ```

  The full `body` structure becomes:
  ```swift
  var body: some View {
      if athlete?.isCoach == true {
          HStack(spacing: 0) {
              modeButton(.athlete, label: "Athlete")
              Rectangle()...
              modeButton(.coach, label: "Coach")
          }
          .frame(height: 44)
          ...
          .sheet(isPresented: $showUpgrade) {
              UpgradeSheet(trigger: .coach)
          }
      }
  }
  ```

- [ ] **Step 4: Build — expect no errors**

- [ ] **Step 5: Commit**

```bash
git add WorkloadApp/Views/Coach/ContextSwitcher.swift
git commit -m "feat(subscriptions): gate ContextSwitcher coach mode behind Pro"
```

---

## Task 8: Refresh entitlement on app foreground

**Files:**
- Modify: `WorkloadApp/App/AppRouter.swift`

> RevenueCat caches entitlement, but we should refresh when the app returns to foreground to pick up renewals and expirations without a full restart. `AppRouter.swift` is the right place — `container` is declared there (`@State private var container = AppContainer()`), so it's accessible without any environment lookup.

- [ ] **Step 1: Add scene phase observation in AppRouter**

  Add to `AppRouter`:
  ```swift
  @Environment(\.scenePhase) private var scenePhase
  ```

  In `body`, on the outermost `Group`, add:
  ```swift
  .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active {
          container.subscriptionService.refreshEntitlement()
      }
  }
  ```

- [ ] **Step 2: Build — expect no errors**

- [ ] **Step 3: Commit**

```bash
git add WorkloadApp/App/AppRouter.swift
git commit -m "feat(subscriptions): refresh RevenueCat entitlement on app foreground"
```

---

## Task 9: Manual sandbox verification

> No automated test covers the full purchase flow — this requires a Sandbox Apple ID in Xcode.

- [ ] **Step 1: Set up sandbox in App Store Connect**
  - Create a Sandbox Tester account in App Store Connect → Users & Access → Sandbox
  - Ensure `workload_pro_monthly` and `workload_pro_annual` products are configured in App Store Connect with 7-day introductory free trial

- [ ] **Step 2: Configure RevenueCat**
  - In app.revenuecat.com: create the `pro` entitlement, attach both products, configure the `default` offering with both packages (annual pre-selected)
  - Replace the placeholder in `RevenueCatConfig.swift` with your real iOS public API key

- [ ] **Step 3: Verify free tier gating**
  - Run on device/simulator signed in as a user with >7 days of workout history
  - Confirm `WorkoutLogView` shows only last 7 days + `HistoryTeaserBanner`
  - Confirm `WorkloadView` shows only last 7 days of snapshots + `HistoryTeaserBanner`
  - Confirm `ContextSwitcher` coach tap (for a `isCoach == true` athlete) shows `UpgradeSheet`

- [ ] **Step 4: Verify purchase flow**
  - Tap `HistoryTeaserBanner` → `UpgradeSheet` appears with context-aware headline
  - Annual plan is pre-selected; CTA shows "Start 7-Day Free Trial"
  - Complete sandbox purchase
  - Confirm `isPro` becomes true, history teaser disappears, full history visible
  - Confirm coach mode switches normally after purchase

- [ ] **Step 5: Verify restore**
  - Delete app, reinstall
  - Tap any gate → `UpgradeSheet` → "Restore purchases"
  - Confirm entitlement restores, UI unlocks

- [ ] **Step 6: Final commit**

```bash
git add WorkloadApp/RevenueCatConfig.swift
git commit -m "feat(subscriptions): update RevenueCat API key for production"
```
