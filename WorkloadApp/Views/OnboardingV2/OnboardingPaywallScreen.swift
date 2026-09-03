import SwiftUI
import RevenueCat

/// OnboardingV2 screen 11 — the paywall, hard or soft per the §4 branch. Plans are
/// CLICKABLE and comparable, with a tap-through free-vs-pro comparison sourced from the
/// real entitlement gates (amendment 2). The trial CTA is the one ink pill. The hard
/// variant offers no dismiss — a dismiss INTENT routes to the exit offer once per
/// install when HAN's `onboarding_exit` offering exists (C6 graceful absence); the soft
/// variant's "Not now" lands the athlete in the free tier and starts the day-7 clock.
///
/// Degradation law: if NO offering resolves at all (RevenueCat unconfigured, or HAN's
/// dashboard work not landed), the wall must not brick the flow — the screen shows the
/// soft affordance regardless of branch. Restore is always present (App Review 3.1.1).
struct OnboardingPaywallScreen: View {
    enum Variant {
        case hard, soft
    }

    let variant: Variant
    /// Purchase or restore resolved an entitlement — the flow moves on.
    let onPurchased: () -> Void
    /// Soft only: "not now" → free tier; the caller stamps `softPaywallShownAt`.
    let onSoftDeclined: () -> Void

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var offering: Offering?
    @State private var exitOffering: Offering?
    @State private var selectedPlan: PlanOption = .annual
    @State private var isPurchasing = false
    @State private var isLoadingOffering = true
    @State private var errorMessage: String?
    @State private var showComparison = false
    @State private var showExitOffer = false

    enum PlanOption {
        case annual, monthly
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

    /// The hard wall can only hold when there is something to buy.
    private var effectiveVariant: Variant {
        offering == nil && !isLoadingOffering ? .soft : variant
    }

    var body: some View {
        VStack(spacing: 0) {
            // Hard variant: no dismiss affordance; the top-right mark is the dismiss
            // INTENT — it routes to the exit offer, never out of the flow.
            HStack {
                Spacer()
                if effectiveVariant == .hard {
                    Button {
                        handleDismissIntent()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text3)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(Text("onboardingV2.paywall.dismissIntent"))
                    .accessibilityIdentifier("onboardingV2.paywall.dismiss")
                }
            }
            .frame(height: 44)
            .padding(.horizontal, Spacing.xs)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("onboardingV2.paywall.title")
                        .font(.Tokens.pageTitle)
                        .foregroundStyle(ColorTokens.text1)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("onboardingV2.paywall.subtitle")
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Spacing.xs)

                    // Clickable plan cells (amendment 2) — equal-weight butted cells.
                    HStack(spacing: 0) {
                        planCell(
                            .annual,
                            titleKey: "onboardingV2.paywall.plan.annual",
                            price: annualPackage?.localizedPriceString
                                ?? SubscriptionTier.athletePro.fallbackAnnualPrice
                        )
                        Rectangle().fill(ColorTokens.divider).frame(width: 0.5)
                        planCell(
                            .monthly,
                            titleKey: "onboardingV2.paywall.plan.monthly",
                            price: monthlyPackage?.localizedPriceString
                                ?? SubscriptionTier.athletePro.fallbackMonthlyPrice
                        )
                    }
                    .frame(height: 88)
                    .background(ColorTokens.surfaceEl, in: RoundedRectangle(cornerRadius: CornerTokens.card))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerTokens.card)
                            .stroke(ColorTokens.divider, lineWidth: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: CornerTokens.card))
                    .padding(.top, Spacing.lg)

                    if trialAvailable {
                        AnnotationLabel(key: "onboardingV2.paywall.trialNote", size: .small, color: ColorTokens.text2)
                            .padding(.top, Spacing.xs)
                    }

                    comparison
                        .padding(.top, Spacing.md)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.zoneDanger)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, Spacing.sm)
                    }
                }
                .padding(.horizontal, Spacing.sm)
            }

            // CTA block, pinned.
            VStack(spacing: Spacing.xs) {
                PrimaryActionButton(
                    title: trialAvailable ? "upgrade.cta.trial" : "upgrade.cta.subscribe",
                    isLoading: isPurchasing || isLoadingOffering,
                    isDisabled: activePackage == nil && !isLoadingOffering
                ) {
                    guard let package = activePackage else { return }
                    Task { await purchase(package) }
                }

                if effectiveVariant == .soft {
                    Button {
                        onSoftDeclined()
                    } label: {
                        Text("onboardingV2.paywall.notNow")
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.xs)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("onboardingV2.paywall.notNow")
                }

                Button {
                    Task { await restore() }
                } label: {
                    Text("upgrade.button.restorePurchases")
                        .font(.Tokens.micro)
                        .foregroundStyle(ColorTokens.text3)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.baselinePair)
                }
                .buttonStyle(.pressable)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.bottom, Spacing.md)
        }
        .fullScreenCover(isPresented: $showExitOffer) {
            ExitOfferScreen(
                offering: exitOffering,
                onAccepted: onPurchased,
                onDeclined: { showExitOffer = false }
            )
        }
        .task { await loadOfferings() }
    }

    // MARK: - Plan cell

    private func planCell(_ plan: PlanOption, titleKey: LocalizedStringKey, price: String) -> some View {
        let isSelected = selectedPlan == plan
        return Button {
            Haptics.select()
            selectedPlan = plan
        } label: {
            VStack(spacing: Spacing.baselinePair) {
                Text(titleKey)
                    .font(.Tokens.micro)
                    .tracking(0.9)
                    .foregroundStyle(ColorTokens.text3)
                Text(price)
                    .font(.Tokens.sectionHead)
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? ColorTokens.text1 : ColorTokens.text2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isSelected ? ColorTokens.surfaceEl2 : Color.clear)
            .overlay(alignment: .top) {
                if isSelected {
                    Rectangle().fill(ColorTokens.text1).frame(height: 1)
                }
            }
        }
        .buttonStyle(.pressable(scale: 1, opacity: 0.6))
    }

    // MARK: - Free vs Pro (amendment 2)

    /// Tap-through comparison sourced from the REAL gates: the free rows state what the
    /// free tier actually keeps (7-day history window, logging incl. voice, readiness),
    /// the Pro rows are `SubscriptionTier.athletePro`'s entitlement-gated feature list.
    private var comparison: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
                    showComparison.toggle()
                }
            } label: {
                HStack {
                    Text("onboardingV2.paywall.compare")
                        .font(.Tokens.bodyMedium)
                        .foregroundStyle(ColorTokens.text1)
                    Spacer()
                    Image(systemName: showComparison ? "chevron.up" : "chevron.down")
                        .font(.Tokens.smallLabel)
                        .foregroundStyle(ColorTokens.text3)
                }
                .padding(.vertical, Spacing.xs)
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("onboardingV2.paywall.compareToggle")

            if showComparison {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    AnnotationLabel(key: "onboardingV2.paywall.compare.freeHead", size: .small)
                    VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                        comparisonRow("onboardingV2.paywall.free.logging")
                        comparisonRow("onboardingV2.paywall.free.readiness")
                        comparisonRow("onboardingV2.paywall.free.history")
                    }

                    AnnotationLabel(key: "onboardingV2.paywall.compare.proHead", size: .small)
                        .padding(.top, Spacing.xs)
                    VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                        ForEach(SubscriptionTier.athletePro.features, id: \.self) { feature in
                            HStack(alignment: .top, spacing: Spacing.xs) {
                                Image(systemName: "checkmark")
                                    .font(.Tokens.micro)
                                    .foregroundStyle(ColorTokens.text2)
                                    .frame(width: 16)
                                Text(feature)
                                    .font(.Tokens.label)
                                    .foregroundStyle(ColorTokens.text1)
                            }
                        }
                    }
                }
                .padding(.top, Spacing.xs)
                .transition(.opacity)
            }
        }
    }

    private func comparisonRow(_ key: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "checkmark")
                .font(.Tokens.micro)
                .foregroundStyle(ColorTokens.text3)
                .frame(width: 16)
            Text(key)
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
        }
    }

    // MARK: - Actions

    /// The onboarding offering keeps the funnel separable; the tier offering is the
    /// fallback so the wall stays sellable before HAN's dashboard work lands. The exit
    /// offering is exact-match ONLY — a substitute exit discount would be a lie.
    private func loadOfferings() async {
        isLoadingOffering = true
        do {
            offering = try await container.subscriptionService.fetchOffering(identifier: "onboarding")
            if offering == nil {
                offering = try await container.subscriptionService.fetchOffering(for: .athletePro)
            }
            exitOffering = try? await container.subscriptionService.fetchOffering(identifier: "onboarding_exit")
        } catch {
            offering = nil
            errorMessage = error.localizedDescription
        }
        isLoadingOffering = false
    }

    private func handleDismissIntent() {
        let gate = OnboardingV2Gate()
        if !gate.exitOfferShown,
           exitOffering?.availablePackages.isEmpty == false {
            gate.exitOfferShown = true
            showExitOffer = true
        }
        // Otherwise: stay. The hard wall is the product boundary (BUILD-PLAN §3).
    }

    private func purchase(_ package: Package) async {
        isPurchasing = true
        errorMessage = nil
        do {
            try await container.subscriptionService.purchase(package: package)
            if container.subscriptionService.isPro {
                Haptics.success()
                onPurchased()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isPurchasing = false
    }

    private func restore() async {
        isPurchasing = true
        errorMessage = nil
        do {
            try await container.subscriptionService.restorePurchases()
            if container.subscriptionService.isPro {
                Haptics.success()
                onPurchased()
            } else {
                errorMessage = String(localized: "onboardingV2.paywall.restoreNothing", defaultValue: "No previous purchase found for this account.")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isPurchasing = false
    }
}
