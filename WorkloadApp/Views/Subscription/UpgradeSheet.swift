import SwiftUI
import RevenueCat

// MARK: - Trigger

enum UpgradeTrigger {
    case history(lockedWeeks: Int)
    case coach
    case athletePro
    case export

    var defaultTier: SubscriptionTier {
        switch self {
        case .coach:
            return .coach
        case .history, .athletePro, .export:
            return .athletePro
        }
    }
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
        _selectedTier = State(initialValue: trigger.defaultTier)
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
            // Drag handle — pill affordance (v3 Corner Law).
            Capsule()
                .fill(ColorTokens.text3.opacity(0.3))
                .frame(width: Spacing.lg, height: Spacing.baselinePair)
                .padding(.top, Spacing.xs)
                .padding(.bottom, Spacing.md)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // MARK: Tier description
                    VStack(alignment: .leading, spacing: 16) {
                        Text(selectedTier.headline)
                            .font(.Tokens.pageTitle)
                            .foregroundStyle(ColorTokens.text1)

                        Text(selectedTier.subtitle)
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text2)

                        // Feature list
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            ForEach(selectedTier.features, id: \.self) { feature in
                                HStack(alignment: .top, spacing: Spacing.xs) {
                                    Image(systemName: "checkmark")
                                        .font(.Tokens.micro)
                                        .foregroundStyle(ColorTokens.text2)
                                        .frame(width: 16)
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

                    // MARK: Plan section header
                    SectionHeader(title: "upgrade.section.choosePlan")
                        .padding(.top, Spacing.md)
                        .padding(.bottom, Spacing.sm)

                    // MARK: Plan toggle
                    HStack(spacing: 0) {
                        planButton(.annual,
                                   title: String(localized: "upgrade.plan.annual", defaultValue: "ANNUAL"),
                                   price: annualPackage?.localizedPriceString ?? selectedTier.fallbackAnnualPrice,
                                   badge: selectedTier.annualSavingsBadge)
                        Rectangle().fill(ColorTokens.divider).frame(width: 0.5)
                        planButton(.monthly,
                                   title: String(localized: "upgrade.plan.monthly", defaultValue: "MONTHLY"),
                                   price: monthlyPackage?.localizedPriceString ?? selectedTier.fallbackMonthlyPrice,
                                   badge: nil)
                    }
                    .frame(height: 72)

                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                    // MARK: Monthly/Annual explanation
                    VStack(alignment: .leading, spacing: 8) {
                        if selectedPlan == .annual {
                            Text(String(format: NSLocalizedString("upgrade.label.annualBenefit", comment: ""), selectedTier.monthlyEquivalent))
                                .font(.Tokens.label)
                                .foregroundStyle(ColorTokens.text2)
                        } else {
                            Text("upgrade.label.monthlyBenefit")
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
                                .foregroundStyle(ColorTokens.zoneDanger)
                                .multilineTextAlignment(.center)
                        }

                        if isLoadingOffering {
                            ProgressView()
                                .tint(ColorTokens.text2)
                                .frame(maxWidth: .infinity, minHeight: 48)
                        } else if offeringUnavailable {
                            Text("upgrade.error.unavailable")
                                .font(.Tokens.label)
                                .foregroundStyle(ColorTokens.text2)
                                .multilineTextAlignment(.center)

                            // Shared accent-pill primary CTA (Stage 4a — CTA grammar completion).
                            PrimaryActionButton(title: "action.retry") {
                                Task { await loadOffering() }
                            }
                        } else {
                            PrimaryActionButton(
                                title: trialAvailable ? "upgrade.cta.trial" : "upgrade.cta.subscribe",
                                isLoading: isPurchasing,
                                isDisabled: activePackage == nil
                            ) {
                                guard let pkg = activePackage else { return }
                                Task { await doPurchase(pkg) }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)

                    // MARK: Footer
                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                    HStack(spacing: 24) {
                        Button("upgrade.button.restorePurchases") {
                            Task { await doRestore() }
                        }
                        Button("link.terms") {
                            openURL(URL(string: "https://haaanw.github.io/WorkloadManagementApp/terms.html")!)
                        }
                        Button("link.privacy") {
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
    }

    // MARK: - Plan Button

    @ViewBuilder
    private func planButton(_ plan: PlanOption, title: String, price: String, badge: String?) -> some View {
        let isSelected = selectedPlan == plan
        Button {
            Haptics.select()
            selectedPlan = plan
        } label: {
            VStack(spacing: Spacing.baselinePair) {
                HStack(spacing: Spacing.xs) {
                    Text(title)
                        .font(.Tokens.micro)
                        .tracking(1)
                        .foregroundStyle(ColorTokens.text3)
                    if let badge {
                        Text(badge)
                            .font(.Tokens.micro)
                            .tracking(0.8)
                            .foregroundStyle(ColorTokens.text2)
                            .padding(.horizontal, Spacing.baselinePair)
                            .padding(.vertical, Spacing.baselinePair)
                            .overlay { Capsule().stroke(ColorTokens.divider, lineWidth: 0.5) }
                    }
                }
                Text(price)
                    .font(.Tokens.sectionHead)
                    .foregroundStyle(isSelected ? ColorTokens.text1 : ColorTokens.text2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isSelected ? ColorTokens.surfaceEl2 : Color.clear)
        }
        .buttonStyle(.pressable(scale: 1, opacity: 0.6))
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
            Haptics.success()
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
            Haptics.success()
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

    var offeringIdentifier: String {
        switch self {
        case .athletePro:
            return "athlete_pro"
        case .coach:
            return "coach"
        }
    }

    var headline: String {
        String(localized: headlineKey)
    }

    func headline(locale: Locale) -> String {
        UIKitStrings.localized(headlineKey, locale: locale)
    }

    private var headlineKey: String.LocalizationValue {
        switch self {
        case .athletePro:
            return "upgrade.tier.athletePro.headline"
        case .coach:
            return "upgrade.tier.coach.headline"
        }
    }

    var subtitle: String {
        String(localized: subtitleKey)
    }

    func subtitle(locale: Locale) -> String {
        UIKitStrings.localized(subtitleKey, locale: locale)
    }

    private var subtitleKey: String.LocalizationValue {
        switch self {
        case .athletePro:
            return "upgrade.tier.athletePro.subtitle"
        case .coach:
            return "upgrade.tier.coach.subtitle"
        }
    }

    var features: [String] {
        featureKeys.map { String(localized: $0) }
    }

    func features(locale: Locale) -> [String] {
        featureKeys.map { UIKitStrings.localized($0, locale: locale) }
    }

    private var featureKeys: [String.LocalizationValue] {
        switch self {
        case .athletePro:
            return [
                "upgrade.feat.pro.history",
                "upgrade.feat.pro.overload",
                "upgrade.feat.pro.targets",
                "upgrade.feat.pro.detraining",
                "upgrade.feat.pro.acwr",
                "upgrade.feat.pro.customExercises",
                "upgrade.feat.pro.import",
                "upgrade.feat.pro.pr"
            ]
        case .coach:
            return [
                "upgrade.feat.coach.roster",
                "upgrade.feat.coach.plans",
                "upgrade.feat.coach.reports",
                "upgrade.feat.coach.pro"
            ]
        }
    }

    var fallbackAnnualPrice: String {
        switch self {
        case .athletePro:
            return "$59.99/yr"
        case .coach:
            return "$149.99/yr"
        }
    }

    var fallbackMonthlyPrice: String {
        switch self {
        case .athletePro:
            return "$6.99/mo"
        case .coach:
            return "$14.99/mo"
        }
    }

    var monthlyEquivalent: String {
        switch self {
        case .athletePro:
            return "$5.00"
        case .coach:
            return "$12.50"
        }
    }

    var annualSavingsBadge: String {
        String(localized: annualSavingsBadgeKey)
    }

    func annualSavingsBadge(locale: Locale) -> String {
        UIKitStrings.localized(annualSavingsBadgeKey, locale: locale)
    }

    private var annualSavingsBadgeKey: String.LocalizationValue {
        switch self {
        case .athletePro:
            return "upgrade.savings.pro"
        case .coach:
            return "upgrade.savings.coach"
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
                VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                    Text(String(format: NSLocalizedString("upgrade.label.lockedWeeks", comment: ""), lockedWeeks))
                        .font(.Tokens.bodyMedium)
                        .foregroundStyle(ColorTokens.text1)
                    Text("upgrade.label.unlockHistory")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
                Spacer()
                Image(systemName: "lock.fill")
                    .foregroundStyle(ColorTokens.text3)
            }
            .cardStyle(verticalPadding: Spacing.sm)
        }
        .buttonStyle(.pressable(scale: 1, opacity: 0.6))
    }
}
