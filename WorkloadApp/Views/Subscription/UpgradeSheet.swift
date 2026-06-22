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
        // v1.5 is single-tier: always the self-coached Tuwa Pro offer, even when opened
        // from a legacy coach trigger.
        _selectedTier = State(initialValue: .athletePro)
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

                            Button {
                                Task { await loadOffering() }
                            } label: {
                                Text("action.retry")
                                    .font(.Tokens.bodyMedium)
                                    .foregroundStyle(ColorTokens.background)
                                    .frame(maxWidth: .infinity, minHeight: 48)
                                    .background(ColorTokens.text1)
                            }
                            .buttonStyle(.pressable)
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
                                    Text(trialAvailable ? String(localized: "upgrade.cta.trial", defaultValue: "Start 7-Day Free Trial") : String(localized: "upgrade.cta.subscribe", defaultValue: "Subscribe"))
                                        .font(.Tokens.bodyMedium)
                                        .foregroundStyle(ColorTokens.background)
                                        .frame(maxWidth: .infinity, minHeight: 48)
                                        .background(ColorTokens.text1)
                                        .overlay(Rectangle().stroke(ColorTokens.accent, lineWidth: 1))
                                }
                            }
                            .disabled(isPurchasing || activePackage == nil)
                            .buttonStyle(.pressable)
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
            VStack(spacing: 2) {
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
                            .overlay { Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5) }
                    }
                }
                Text(price)
                    .font(.Tokens.sectionHead)
                    .foregroundStyle(isSelected ? ColorTokens.accent : ColorTokens.text2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isSelected ? ColorTokens.accentSubtle : Color.clear)
            .overlay(alignment: .bottom) {
                if isSelected {
                    Rectangle().fill(ColorTokens.accent).frame(height: 2)
                }
            }
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

    var headline: String {
        String(localized: "upgrade.tier.athletePro.headline", defaultValue: "Coach yourself with confidence")
    }

    var subtitle: String {
        String(localized: "upgrade.tier.athletePro.subtitle", defaultValue: "Unlock the full power of Tuwa to adapt your strength training to how your body is recovering.")
    }

    var features: [String] {
        [
            String(localized: "upgrade.feat.pro.history", defaultValue: "Full training history (free tier: 7 days only)"),
            String(localized: "upgrade.feat.pro.overload", defaultValue: "Smart progressive overload suggestions"),
            String(localized: "upgrade.feat.pro.targets", defaultValue: "Recovery-aware volume and intensity targets"),
            String(localized: "upgrade.feat.pro.detraining", defaultValue: "Detraining detection after breaks"),
            String(localized: "upgrade.feat.pro.acwr", defaultValue: "Advanced training-load and workload charts"),
            String(localized: "upgrade.feat.pro.customExercises", defaultValue: "Unlimited custom exercises"),
            String(localized: "upgrade.feat.pro.import", defaultValue: "Workout program import"),
            String(localized: "upgrade.feat.pro.pr", defaultValue: "Personal record tracking across all time"),
        ]
    }

    var fallbackAnnualPrice: String { "$59.99/yr" }

    var fallbackMonthlyPrice: String { "$6.99/mo" }

    var monthlyEquivalent: String { "$5.00" }

    var annualSavingsBadge: String {
        String(localized: "upgrade.savings.pro", defaultValue: "SAVE 29%")
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
