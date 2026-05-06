import SwiftUI
import RevenueCat

// MARK: - Trigger

enum UpgradeTrigger {
    case history(lockedWeeks: Int)
    case coach
    case athletePro
    case export
}

// MARK: - UpgradeSheet

struct UpgradeSheet: View {
    let trigger: UpgradeTrigger
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var offering: Offering?
    @State private var selectedTier: SubscriptionTier
    @State private var selectedPlan: PlanOption = .annual
    @State private var isPurchasing = false
    @State private var isLoadingOffering = false
    @State private var offeringUnavailable = false
    @State private var errorMessage: String?

    enum PlanOption { case annual, monthly }

    init(trigger: UpgradeTrigger) {
        self.trigger = trigger
        switch trigger {
        case .coach: _selectedTier = State(initialValue: .coach)
        default: _selectedTier = State(initialValue: .athletePro)
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

                    // MARK: Tier selector
                    HStack(spacing: 0) {
                        tierTab(.athletePro, label: "ATHLETE PRO")
                        Rectangle().fill(ColorTokens.divider).frame(width: 0.5)
                        tierTab(.coach, label: "COACH")
                    }
                    .frame(height: 48)

                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                    // MARK: Tier description
                    VStack(alignment: .leading, spacing: 16) {
                        Text(selectedTier.headline)
                            .font(.Tokens.pageTitle)
                            .foregroundStyle(ColorTokens.text1)

                        Text(selectedTier.subtitle)
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text2)

                        // Feature list
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(selectedTier.features, id: \.self) { feature in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(ColorTokens.text2)
                                        .frame(width: 16)
                                        .padding(.top, 2)
                                    Text(feature)
                                        .font(.Tokens.body)
                                        .foregroundStyle(ColorTokens.text1)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)

                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                    // MARK: Plan toggle
                    HStack(spacing: 0) {
                        planButton(.annual,
                                   title: "ANNUAL",
                                   price: annualPackage?.localizedPriceString ?? selectedTier.fallbackAnnualPrice,
                                   badge: selectedTier.annualSavingsBadge)
                        Rectangle().fill(ColorTokens.divider).frame(width: 0.5)
                        planButton(.monthly,
                                   title: "MONTHLY",
                                   price: monthlyPackage?.localizedPriceString ?? selectedTier.fallbackMonthlyPrice,
                                   badge: nil)
                    }
                    .frame(height: 72)

                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                    // MARK: Monthly/Annual explanation
                    VStack(alignment: .leading, spacing: 8) {
                        if selectedPlan == .annual {
                            Text("Best value — billed once per year. Comes out to \(selectedTier.monthlyEquivalent) per month. Cancel anytime.")
                                .font(.Tokens.label)
                                .foregroundStyle(ColorTokens.text2)
                        } else {
                            Text("Flexible month-to-month. No commitment — cancel anytime from Settings on your device.")
                                .font(.Tokens.label)
                                .foregroundStyle(ColorTokens.text2)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)

                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                    // MARK: CTA
                    VStack(spacing: 16) {
                        if let errorMessage {
                            Text(errorMessage)
                                .font(.Tokens.label)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }

                        if isLoadingOffering {
                            ProgressView()
                                .tint(ColorTokens.text2)
                                .frame(maxWidth: .infinity, minHeight: 48)
                        } else if offeringUnavailable {
                            Text("Subscriptions unavailable — check your connection and try again")
                                .font(.Tokens.label)
                                .foregroundStyle(ColorTokens.text2)
                                .multilineTextAlignment(.center)

                            Button {
                                Task { await loadOffering() }
                            } label: {
                                Text("Retry")
                                    .font(.Tokens.bodyMedium)
                                    .foregroundStyle(ColorTokens.background)
                                    .frame(maxWidth: .infinity, minHeight: 48)
                                    .background(ColorTokens.text1)
                            }
                            .buttonStyle(.plain)
                        } else {
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
                        }
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
                            openURL(URL(string: "https://haaanw.github.io/WorkloadManagementApp/terms.html")!)
                        }
                        Button("Privacy") {
                            openURL(URL(string: "https://haaanw.github.io/WorkloadManagementApp/privacy.html")!)
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
        .onChange(of: selectedTier) { _, _ in
            Task { await loadOffering() }
        }
    }

    // MARK: - Tier Tab

    @ViewBuilder
    private func tierTab(_ tier: SubscriptionTier, label: String) -> some View {
        let isSelected = selectedTier == tier
        Button { selectedTier = tier } label: {
            Text(label)
                .font(.Tokens.micro)
                .tracking(1.0)
                .foregroundStyle(isSelected ? ColorTokens.text1 : ColorTokens.text3)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottom) {
                    if isSelected {
                        Rectangle().fill(ColorTokens.text1).frame(height: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Plan Button

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

    // MARK: - Actions

    private func loadOffering() async {
        isLoadingOffering = true
        offeringUnavailable = false
        errorMessage = nil
        do {
            offering = try await container.subscriptionService.fetchOffering(for: selectedTier)
            offeringUnavailable = offering == nil
        } catch {
            offering = nil
            offeringUnavailable = true
            errorMessage = error.localizedDescription
        }
        isLoadingOffering = false
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

// MARK: - Subscription Tiers

enum SubscriptionTier: String, CaseIterable {
    case athletePro
    case coach

    var headline: String {
        switch self {
        case .athletePro: return "Train smarter, not harder"
        case .coach: return "Your athletes, one dashboard"
        }
    }

    var subtitle: String {
        switch self {
        case .athletePro:
            return "Unlock the full power of Tonus to push your training forward with data-driven precision."
        case .coach:
            return "Manage your roster, prescribe workouts, and monitor every athlete's load and recovery in real time."
        }
    }

    var features: [String] {
        switch self {
        case .athletePro:
            return [
                "Full training history (free tier: 7 days only)",
                "Smart progressive overload suggestions",
                "Recovery-aware volume and intensity targets",
                "Detraining detection after breaks",
                "Advanced ACWR and workload charts",
                "Unlimited custom exercises",
                "Workout program import",
                "Personal record tracking across all time",
            ]
        case .coach:
            return [
                "Everything in Athlete Pro",
                "Coach dashboard with full athlete roster",
                "Real-time recovery scores and ACWR for each athlete",
                "Prescribe workouts with target weight, reps, and RPE",
                "Workout template builder with exercise groups",
                "Log workouts on behalf of any athlete",
                "Coach-only mode (hide athlete tabs entirely)",
                "Link athletes via invite code or email",
            ]
        }
    }

    var fallbackAnnualPrice: String {
        switch self {
        case .athletePro: return "$59.99/yr"
        case .coach: return "$89.99/yr"
        }
    }

    var fallbackMonthlyPrice: String {
        switch self {
        case .athletePro: return "$6.99/mo"
        case .coach: return "$9.99/mo"
        }
    }

    var monthlyEquivalent: String {
        switch self {
        case .athletePro: return "$5.00"
        case .coach: return "$7.42"
        }
    }

    var annualSavingsBadge: String {
        switch self {
        case .athletePro: return "SAVE 29%"
        case .coach: return "SAVE 25%"
        }
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
