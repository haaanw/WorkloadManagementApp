import SwiftUI
import SwiftData
import UIKit
import RevenueCat
import AuthenticationServices
import Supabase

struct AppShell: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @Query private var athletes: [Athlete]
    @State private var navigationState = NavigationState()

    private var athlete: Athlete? { athletes.first }

    private var resolvedContext: AppContext {
        if athlete?.isCoachOnly == true { return .coach }
        guard container.currentMode == .coach else { return .athlete }
        return athlete?.isCoach == true ? .coach : .athlete
    }

    var body: some View {
        UIKitShellController(
            appContext: resolvedContext,
            navigationState: navigationState,
            container: container,
            modelContext: modelContext,
            locale: locale
        )
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await container.subscriptionService.refreshEntitlementAsync()
                guard container.syncService.shouldForegroundSync else { return }
                await container.syncService.pushAll(context: modelContext)
                await container.syncService.pullAll(context: modelContext)
            }
        }
    }
}

private final class AppTabBarController: UITabBarController {
    private let tabRail = SquareTabRailView()
    private var cachedViewControllersByContext: [AppContext: [UIViewController]] = [:]
    private var cachedLocaleIdentifier: String?
    var appContext: AppContext?
    var localeIdentifier: String?
    var activeLocale: Locale = .current

    override func viewDidLoad() {
        super.viewDidLoad()
        applyTuwaLightInterfaceStyle()
        tabBar.addSubview(tabRail)
        NSLayoutConstraint.activate([
            tabRail.leadingAnchor.constraint(equalTo: tabBar.leadingAnchor),
            tabRail.trailingAnchor.constraint(equalTo: tabBar.trailingAnchor),
            tabRail.topAnchor.constraint(equalTo: tabBar.topAnchor),
            tabRail.bottomAnchor.constraint(equalTo: tabBar.bottomAnchor)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyTuwaLightInterfaceStyle()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tabBar.bringSubviewToFront(tabRail)
        updateTabRail(animated: false)
    }

    func updateTabRail(animated: Bool) {
        guard let items = tabBar.items, !items.isEmpty else {
            tabRail.isHidden = true
            return
        }
        tabRail.isHidden = false
        tabRail.update(items: items, selectedIndex: selectedIndex, animated: animated)
    }

    func viewControllers(
        for context: AppContext,
        localeIdentifier nextLocaleIdentifier: String,
        build: () -> [UIViewController]
    ) -> [UIViewController] {
        if cachedLocaleIdentifier != nextLocaleIdentifier {
            cachedViewControllersByContext = [:]
            cachedLocaleIdentifier = nextLocaleIdentifier
        }

        if let appContext, let viewControllers {
            cachedViewControllersByContext[appContext] = viewControllers
        }

        if let cached = cachedViewControllersByContext[context] {
            return cached
        }

        let built = build()
        cachedViewControllersByContext[context] = built
        return built
    }
}

private final class InstrumentNavigationController: UINavigationController {
    override func viewDidLoad() {
        super.viewDidLoad()
        applyTuwaLightInterfaceStyle()
        modalPresentationStyle = .pageSheet
        view.backgroundColor = UIKitDesign.background

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIKitDesign.surface
        appearance.shadowColor = UIKitDesign.hairlineColor
        appearance.titleTextAttributes = [
            .foregroundColor: UIKitDesign.textPrimary,
            .font: UIKitDesign.medium(17)
        ]

        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.tintColor = UIKitDesign.textPrimary
    }
}

private final class InstrumentTabNavigationController: UINavigationController, UINavigationControllerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        applyTuwaLightInterfaceStyle()
        delegate = self
        view.backgroundColor = UIKitDesign.background

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIKitDesign.surface
        appearance.shadowColor = UIKitDesign.hairlineColor
        appearance.titleTextAttributes = [
            .foregroundColor: UIKitDesign.textPrimary,
            .font: UIKitDesign.medium(17)
        ]

        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.tintColor = UIKitDesign.textPrimary
        setNavigationBarHidden(true, animated: false)
    }

    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        let isRoot = viewControllers.first === viewController
        setNavigationBarHidden(isRoot, animated: animated)
    }
}

private extension UIViewController {
    func showInstrumentDetail(_ controller: UIViewController, animated: Bool = true) {
        if let navigationController {
            navigationController.pushViewController(controller, animated: animated)
        } else {
            controller.navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: "Close",
                style: .plain,
                target: controller,
                action: #selector(dismissInstrumentDetail)
            )
            present(InstrumentNavigationController(rootViewController: controller), animated: animated)
        }
    }

    @objc func dismissInstrumentDetail() {
        dismiss(animated: true)
    }
}

private struct InstrumentChoiceOption {
    let title: String
    var subtitle: String?
    var isSelected: Bool
    var accessibilityIdentifier: String?
    let action: () -> Void

    init(
        title: String,
        subtitle: String? = nil,
        isSelected: Bool = false,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }
}

private final class InstrumentChoiceListViewController: InstrumentScrollViewController {
    private let choiceTitle: String
    private let kicker: String
    private let stateTextProvider: () -> String
    private let optionsProvider: () -> [InstrumentChoiceOption]
    private let dismissesOnSelection: Bool
    private let doneTitle: String

    init(
        title: String,
        kicker: String = "Choose",
        stateText: @escaping () -> String,
        options: @escaping () -> [InstrumentChoiceOption],
        dismissesOnSelection: Bool = true,
        doneTitle: String = "Cancel"
    ) {
        self.choiceTitle = title
        self.kicker = kicker
        self.stateTextProvider = stateText
        self.optionsProvider = options
        self.dismissesOnSelection = dismissesOnSelection
        self.doneTitle = doneTitle
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = choiceTitle
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: doneTitle,
            style: .plain,
            target: self,
            action: #selector(closeChoice)
        )
        navigationItem.leftBarButtonItem?.accessibilityIdentifier = "choice.cancel"
    }

    override func rebuild() {
        clearContent()
        let options = optionsProvider()
        addHorizontalInsets(hero(
            kicker: kicker,
            title: choiceTitle,
            body: stateTextProvider()
        ), top: Spacing.sm)
        addHorizontalInsets(statePlate(), top: Spacing.sm)
        addSection(content: dataPlate(optionRows(options), spacing: Spacing.sm))
    }

    private func statePlate() -> UIView {
        let label = UIKitDesign.label(stateTextProvider(), font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
        label.accessibilityIdentifier = "choice.state"
        return dataPlate([label], spacing: Spacing.sm)
    }

    private func optionRows(_ options: [InstrumentChoiceOption]) -> [UIView] {
        options.enumerated().flatMap { index, option -> [UIView] in
            var rows = [optionButton(option)]
            if index < options.count - 1 {
                rows.append(divider())
            }
            return rows
        }
    }

    private func optionButton(_ option: InstrumentChoiceOption) -> UIView {
        let button = UIButton(type: .custom)
        button.accessibilityIdentifier = option.accessibilityIdentifier
        button.accessibilityLabel = [
            option.title,
            option.subtitle,
            option.isSelected ? "Selected" : nil
        ]
            .compactMap { $0 }
            .joined(separator: ", ")
        button.accessibilityTraits = option.isSelected ? [.button, .selected] : .button
        button.backgroundColor = option.isSelected ? UIKitDesign.active : UIKitDesign.surface
        button.layer.borderWidth = UIKitDesign.hairline
        button.layer.borderColor = option.isSelected ? UIKitDesign.hairlineStrong.cgColor : UIKitDesign.hairlineColor.cgColor
        button.addAction(UIAction { [weak self] _ in
            option.action()
            Haptics.select()
            if self?.dismissesOnSelection == true {
                self?.closeChoice()
            } else {
                self?.rebuild()
            }
        }, for: .touchUpInside)

        let row = disclosureRow(
            title: option.title,
            subtitle: option.subtitle,
            trailing: option.isSelected ? "Selected" : nil
        )
        row.isUserInteractionEnabled = false
        button.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            row.topAnchor.constraint(equalTo: button.topAnchor),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return button
    }

    @objc private func closeChoice() {
        if let navigationController, navigationController.viewControllers.first !== self {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}

private struct UIKitShellController: UIViewControllerRepresentable {
    let appContext: AppContext
    let navigationState: NavigationState
    let container: AppContainer
    let modelContext: ModelContext
    let locale: Locale

    func makeCoordinator() -> Coordinator {
        Coordinator(
            navigationState: navigationState,
            analyticsService: container.uxAnalyticsService
        )
    }

    func makeUIViewController(context: Context) -> AppTabBarController {
        let controller = AppTabBarController()
        controller.applyTuwaLightInterfaceStyle()
        controller.delegate = context.coordinator
        configure(controller, coordinator: context.coordinator)
        return controller
    }

    func updateUIViewController(_ controller: AppTabBarController, context: Context) {
        controller.applyTuwaLightInterfaceStyle()
        context.coordinator.navigationState = navigationState
        if controller.appContext != appContext || controller.localeIdentifier != locale.identifier {
            configure(controller, coordinator: context.coordinator)
        } else {
            applyAppearance(to: controller)
            syncSelection(on: controller)
        }
    }

    private func configure(_ controller: AppTabBarController, coordinator: Coordinator) {
        let viewControllers = controller.viewControllers(
            for: appContext,
            localeIdentifier: locale.identifier
        ) {
            makeViewControllers()
        }
        controller.appContext = appContext
        controller.localeIdentifier = locale.identifier
        controller.activeLocale = locale
        controller.delegate = coordinator
        controller.applyTuwaLightInterfaceStyle()
        controller.view.backgroundColor = UIColor(ColorTokens.background)
        controller.viewControllers = viewControllers
        applyAppearance(to: controller)
        syncSelection(on: controller)
    }

    private func makeViewControllers() -> [UIViewController] {
        switch appContext {
        case .athlete:
            return AthleteTab.allCases.map(athleteController(for:))
        case .coach:
            return CoachTab.allCases.map(coachController(for:))
        }
    }

    private func athleteController(for tab: AthleteTab) -> UIViewController {
        switch tab {
        case .today:
            return controller(
                TodayViewController(
                    container: container,
                    modelContext: modelContext,
                    locale: locale
                ),
                tab: tab
            )
        case .train:
            return controller(
                TrainHomeViewController(
                    container: container,
                    modelContext: modelContext,
                    locale: locale
                ),
                tab: tab
            )
        case .insights:
            return controller(
                InsightsViewController(
                    container: container,
                    modelContext: modelContext,
                    locale: locale
                ),
                tab: tab
            )
        case .profile:
            return controller(
                AthleteProfileHubViewController(
                    container: container,
                    modelContext: modelContext,
                    locale: locale,
                    onOpenCoachMode: { controller in
                        switchContext(.coach, from: controller)
                    }
                ),
                tab: tab
            )
        }
    }

    private func coachController(for tab: CoachTab) -> UIViewController {
        switch tab {
        case .roster:
            return controller(
                CoachRosterViewController(
                    container: container,
                    modelContext: modelContext,
                    locale: locale
                ),
                tab: tab
            )
        case .plans:
            return controller(
                CoachPlansViewController(
                    container: container,
                    modelContext: modelContext,
                    locale: locale
                ),
                tab: tab
            )
        case .reports:
            return controller(
                CoachReportsViewController(
                    container: container,
                    modelContext: modelContext
                ),
                tab: tab
            )
        case .profile:
            return controller(
                CoachProfileViewController(
                    container: container,
                    modelContext: modelContext,
                    onReturnToAthlete: { controller in
                        navigationState.athleteTab = .profile
                        switchContext(.athlete, from: controller)
                        container.setMode(.athlete)
                    }
                ),
                tab: tab
            )
        }
    }

    private func controller(_ viewController: UIViewController, tab: AthleteTab) -> UIViewController {
        configuredController(
            viewController,
            title: tab.titleText(locale: locale),
            systemImage: tab.systemImage,
            accessibilityIdentifier: tab.accessibilityIdentifier,
            isSelected: navigationState.athleteTab == tab
        )
    }

    private func controller(_ viewController: UIViewController, tab: CoachTab) -> UIViewController {
        configuredController(
            viewController,
            title: tab.titleText(locale: locale),
            systemImage: tab.systemImage,
            accessibilityIdentifier: tab.accessibilityIdentifier,
            isSelected: navigationState.coachTab == tab
        )
    }

    private func configuredController(
        _ viewController: UIViewController,
        title: String,
        systemImage: String,
        accessibilityIdentifier: String,
        isSelected: Bool
    ) -> UIViewController {
        viewController.tabBarItem = UITabBarItem(
            title: title,
            image: UIImage(systemName: systemImage),
            selectedImage: UIImage(systemName: systemImage)
        )
        viewController.tabBarItem.accessibilityIdentifier = accessibilityIdentifier
        viewController.tabBarItem.accessibilityValue = isSelected ? selectedAccessibilityText(locale: locale) : nil
        let navigationController = InstrumentTabNavigationController(rootViewController: viewController)
        navigationController.tabBarItem = viewController.tabBarItem
        return navigationController
    }

    private func switchContext(_ context: AppContext, from source: UIViewController) {
        guard let controller = source.tabBarController as? AppTabBarController else { return }
        let viewControllers = controller.viewControllers(
            for: context,
            localeIdentifier: locale.identifier
        ) {
            switch context {
            case .athlete:
                AthleteTab.allCases.map(athleteController(for:))
            case .coach:
                CoachTab.allCases.map(coachController(for:))
            }
        }
        controller.appContext = context
        controller.localeIdentifier = locale.identifier
        controller.activeLocale = locale
        controller.viewControllers = viewControllers
        applyAppearance(to: controller)
        syncSelection(on: controller, context: context)
    }

    private func syncSelection(on controller: AppTabBarController, context overrideContext: AppContext? = nil) {
        let context = overrideContext ?? appContext
        let selectedIndex: Int
        switch context {
        case .athlete:
            selectedIndex = AthleteTab.allCases.firstIndex(of: navigationState.athleteTab) ?? 0
        case .coach:
            selectedIndex = CoachTab.allCases.firstIndex(of: navigationState.coachTab) ?? 0
        }
        guard let viewControllers = controller.viewControllers,
              viewControllers.indices.contains(selectedIndex) else { return }
        let selectedViewController = viewControllers[selectedIndex]
        if controller.selectedIndex != selectedIndex || controller.selectedViewController !== selectedViewController {
            controller.selectedIndex = selectedIndex
        }
        refreshAccessibilityValues(on: controller)
        controller.updateTabRail(animated: false)
    }

    private func applyAppearance(to controller: AppTabBarController) {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .clear
        appearance.backgroundEffect = nil
        appearance.shadowColor = .clear

        applyItemAppearance(to: appearance.stackedLayoutAppearance)
        applyItemAppearance(to: appearance.inlineLayoutAppearance)
        applyItemAppearance(to: appearance.compactInlineLayoutAppearance)

        controller.tabBar.standardAppearance = appearance
        controller.tabBar.scrollEdgeAppearance = appearance
        controller.tabBar.backgroundColor = .clear
        controller.tabBar.tintColor = .clear
        controller.tabBar.unselectedItemTintColor = .clear
        controller.tabBar.isTranslucent = false
        controller.updateTabRail(animated: false)
    }

    private func applyItemAppearance(to appearance: UITabBarItemAppearance) {
        appearance.selected.iconColor = .clear
        appearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.clear,
            .font: tabFont(name: "GeneralSans-Medium", fallbackName: "NotoSansSC-Medium")
        ]

        appearance.normal.iconColor = .clear
        appearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.clear,
            .font: tabFont(name: "GeneralSans-Regular", fallbackName: "NotoSansSC-Regular")
        ]
    }

    private func tabFont(name: String, fallbackName: String) -> UIFont {
        UIFont(name: name, size: 12)
            ?? UIFont(name: fallbackName, size: 12)
            ?? UIFont(descriptor: UIFontDescriptor(name: name, size: 12), size: 12)
    }

    private func refreshAccessibilityValues(on controller: AppTabBarController) {
        guard let viewControllers = controller.viewControllers else { return }
        for (index, viewController) in viewControllers.enumerated() {
            viewController.tabBarItem.accessibilityValue = index == controller.selectedIndex
                ? selectedAccessibilityText(locale: controller.activeLocale)
                : nil
        }
    }

    private func selectedAccessibilityText(locale: Locale) -> String {
        UIKitStrings.localized("accessibility.selected", defaultValue: "Selected", locale: locale)
    }

    final class Coordinator: NSObject, UITabBarControllerDelegate {
        var navigationState: NavigationState
        private let analyticsService: UXAnalyticsService

        init(navigationState: NavigationState, analyticsService: UXAnalyticsService) {
            self.navigationState = navigationState
            self.analyticsService = analyticsService
        }

        func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
            guard tabBarController.selectedViewController === viewController else { return true }
            resetSelectedRoot(viewController, animated: true)
            return true
        }

        func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
            guard let controller = tabBarController as? AppTabBarController,
                  let viewControllers = controller.viewControllers,
                  let selectedIndex = viewControllers.firstIndex(of: viewController),
                  let appContext = controller.appContext else { return }

            switch appContext {
            case .athlete:
                guard AthleteTab.allCases.indices.contains(selectedIndex) else { return }
                let tab = AthleteTab.allCases[selectedIndex]
                navigationState.athleteTab = tab
                analyticsService.track(.athleteTabViewed, properties: [
                    "context": appContext.rawValue,
                    "tab": tab.rawValue
                ])
            case .coach:
                guard CoachTab.allCases.indices.contains(selectedIndex) else { return }
                let tab = CoachTab.allCases[selectedIndex]
                navigationState.coachTab = tab
                analyticsService.track(.athleteTabViewed, properties: [
                    "context": appContext.rawValue,
                    "tab": tab.rawValue
                ])
            }
            controller.viewControllers?.enumerated().forEach { index, child in
                child.tabBarItem.accessibilityValue = index == selectedIndex
                    ? UIKitStrings.localized("accessibility.selected", defaultValue: "Selected", locale: controller.activeLocale)
                    : nil
            }
            controller.updateTabRail(animated: true)
        }

        private func resetSelectedRoot(_ viewController: UIViewController, animated: Bool) {
            if let navigationController = viewController as? UINavigationController {
                navigationController.popToRootViewController(animated: animated)
                (navigationController.viewControllers.first as? AppTabRootResetting)?.resetToRoot(animated: animated)
                return
            }
            (viewController as? AppTabRootResetting)?.resetToRoot(animated: animated)
        }
    }
}

private enum InsightsSection: Int, CaseIterable, Hashable {
    case overview
    case recovery
    case load

    var trackingValue: String {
        switch self {
        case .overview: "overview"
        case .recovery: "recovery"
        case .load: "load"
        }
    }

    var localizationKey: String.LocalizationValue {
        switch self {
        case .overview: "insights.section.overview"
        case .recovery: "insights.section.recovery"
        case .load: "insights.section.load"
        }
    }

    func title(locale: Locale) -> String {
        UIKitStrings.localized(localizationKey, locale: locale)
    }
}

struct UIKitAuthFlowController: UIViewControllerRepresentable {
    let container: AppContainer
    let modelContext: ModelContext
    let locale: Locale

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = AuthFlowViewController(
            container: container,
            modelContext: modelContext,
            locale: locale
        )
        controller.applyTuwaLightInterfaceStyle()
        return controller
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        controller.applyTuwaLightInterfaceStyle()
        (controller as? AuthFlowViewController)?.update(locale: locale)
    }
}

struct UIKitOnboardingFlowController: UIViewControllerRepresentable {
    let container: AppContainer
    let modelContext: ModelContext
    let locale: Locale
    let onComplete: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = OnboardingFlowViewController(
            container: container,
            modelContext: modelContext,
            locale: locale,
            onComplete: onComplete
        )
        controller.applyTuwaLightInterfaceStyle()
        return controller
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        controller.applyTuwaLightInterfaceStyle()
        (controller as? OnboardingFlowViewController)?.update(locale: locale)
    }
}

private enum AuthFlowMode {
    case signIn
    case signUp
}

private enum AuthFieldKind: String, CaseIterable {
    case name
    case email
    case password

    var accessibilityIdentifier: String {
        "auth.\(rawValue)"
    }

    var errorIdentifier: String {
        "auth.\(rawValue).error"
    }
}

private enum AuthLoadingKind {
    case credentials
    case google
    case apple
}

private enum UIKitAuthFlowError: LocalizedError {
    case noUserId
    case athleteNotFound

    var localizationKey: String.LocalizationValue {
        switch self {
        case .noUserId:
            return "auth.error.noUserId"
        case .athleteNotFound:
            return "auth.error.athleteNotFound"
        }
    }

    var errorDescription: String? {
        switch self {
        case .noUserId:
            return "Could not retrieve your account. Please try again."
        case .athleteNotFound:
            return "Account profile not found. Please contact support."
        }
    }
}

private final class AuthFlowViewController: InstrumentScrollViewController, UITextFieldDelegate, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let container: AppContainer
    private let modelContext: ModelContext
    private var locale: Locale
    private var mode: AuthFlowMode = .signIn

    private var displayName = ""
    private var email = ""
    private var password = ""
    private var selectedSport: SportType = .lifting
    private var isLoading = false
    private var loadingKind: AuthLoadingKind?
    private var focusedField: AuthFieldKind?
    private var hasAttemptedSubmit = false
    private var forcedStateText: String?
    private var errorMessage: String?
    private var lastAuthError: (any Error)?

    init(container: AppContainer, modelContext: ModelContext, locale: Locale) {
        self.container = container
        self.modelContext = modelContext
        self.locale = locale
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.accessibilityIdentifier = "auth.flow"
        applyScreenshotAuthStateIfNeeded()
    }

    func update(locale: Locale) {
        self.locale = locale
        if let lastAuthError, errorMessage != nil {
            errorMessage = resolveErrorMessage(lastAuthError)
        }
        rebuild()
    }

    override func rebuild() {
        clearContent()
        addHorizontalInsets(hero(
            kicker: localized("auth.brand.wordmark"),
            title: mode == .signIn ? localized("auth.brand.wordmark") : localized("auth.signup.heading"),
            body: mode == .signIn
                ? localized("auth.brand.tagline")
                : localized("auth.signup.subhead")
        ), top: Spacing.lg)
        addHorizontalInsets(authStatePlate(), top: Spacing.sm)

        addSection(
            title: mode == .signIn
                ? localized("auth.action.signIn")
                : localized("auth.signup.heading"),
            content: dataPlate(formRows(), spacing: Spacing.sm)
        )

        if mode == .signUp {
            addSection(title: localized("auth.signup.primarySport"), content: dataPlate([
                choiceRow(title: localized("auth.signup.primarySport"), value: sportDisplayName(selectedSport), action: #selector(chooseSport))
            ], spacing: Spacing.sm))
        }

        addSection(content: dataPlate(actionRows(), spacing: Spacing.sm))
    }

    private var canSubmit: Bool {
        !isLoading
    }

    private func formRows() -> [UIView] {
        var rows: [UIView] = []
        if mode == .signUp {
            rows.append(textInputRow(
                title: localized("auth.field.name"),
                placeholder: localized("auth.field.namePlaceholder"),
                value: displayName,
                contentType: .name,
                keyboardType: .default,
                isSecure: false,
                kind: .name
            ) { [weak self] value in
                self?.displayName = value
            })
            rows.append(divider())
        }

        rows.append(textInputRow(
            title: localized("auth.field.email"),
            placeholder: "you@example.com",
            value: email,
            contentType: .emailAddress,
            keyboardType: .emailAddress,
            isSecure: false,
            kind: .email
        ) { [weak self] value in
            self?.email = value
        })
        rows.append(divider())
        rows.append(textInputRow(
            title: localized("auth.field.password"),
            placeholder: localized("auth.field.passwordPlaceholder"),
            value: password,
            contentType: mode == .signUp ? .newPassword : .password,
            keyboardType: .default,
            isSecure: true,
            kind: .password
        ) { [weak self] value in
            self?.password = value
        })
        return rows
    }

    private func actionRows() -> [UIView] {
        let submit = actionButton(
            title: isLoading
                ? localized("auth.action.working", defaultValue: "Working...")
                : (mode == .signIn ? localized("auth.action.signIn") : localized("auth.signup.heading")),
            action: #selector(submit)
        )
        submit.isEnabled = canSubmit && !isLoading
        submit.alpha = submit.isEnabled ? 1 : 0.45
        submit.accessibilityIdentifier = mode == .signIn ? "auth.signIn" : "auth.signUp"
        submit.accessibilityValue = authStateText

        return [
            submit,
            divider(),
            switchModeButton(),
            divider(),
            googleButton(),
            divider(),
            appleButton()
        ]
    }

    private func textInputRow(
        title: String,
        placeholder: String,
        value: String,
        contentType: UITextContentType,
        keyboardType: UIKeyboardType,
        isSecure: Bool,
        kind: AuthFieldKind,
        onChange: @escaping (String) -> Void
    ) -> UIView {
        let stack = UIKitDesign.verticalStack(spacing: Spacing.xs)
        stack.addArrangedSubview(UIKitDesign.label(title, font: UIKitDesign.regular(13), color: UIKitDesign.textSecondary))

        let field = UITextField()
        field.text = value
        field.placeholder = placeholder
        field.textContentType = contentType
        field.accessibilityIdentifier = kind.accessibilityIdentifier
        field.accessibilityValue = fieldStateText(for: kind)
        field.keyboardType = keyboardType
        field.autocapitalizationType = contentType == .emailAddress ? .none : .words
        field.autocorrectionType = contentType == .emailAddress ? .no : .default
        field.isSecureTextEntry = isSecure
        field.delegate = self
        field.font = UIKitDesign.regular(17)
        field.textColor = UIKitDesign.textPrimary
        field.tintColor = UIKitDesign.textPrimary
        field.backgroundColor = UIKitDesign.surface
        field.layer.borderWidth = UIKitDesign.hairline
        field.layer.borderColor = fieldBorderColor(for: kind).cgColor
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: Spacing.xs, height: 1))
        field.leftViewMode = .always
        field.translatesAutoresizingMaskIntoConstraints = false
        field.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        field.addAction(UIAction { [weak field] _ in
            onChange(field?.text ?? "")
        }, for: .editingChanged)
        stack.addArrangedSubview(field)
        if let validationMessage = validationMessages[kind] {
            let error = UIKitDesign.label(validationMessage, font: UIKitDesign.regular(13), color: UIColor(ColorTokens.zoneDanger), lines: 0)
            error.accessibilityIdentifier = kind.errorIdentifier
            stack.addArrangedSubview(error)
        }
        return stack
    }

    private var validationMessages: [AuthFieldKind: String] {
        guard hasAttemptedSubmit else { return [:] }
        var messages: [AuthFieldKind: String] = [:]

        if mode == .signUp && displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages[.name] = localized("auth.error.nameRequired", defaultValue: "Enter your name.")
        }

        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isValidEmail(email) == false {
            messages[.email] = localized("auth.error.emailInvalid", defaultValue: "Enter a valid email address.")
        }

        if mode == .signIn {
            if password.isEmpty {
                messages[.password] = localized("auth.error.passwordRequired", defaultValue: "Enter your password.")
            }
        } else if password.count < 8 {
            messages[.password] = localized("auth.error.passwordLength", defaultValue: "Use at least 8 characters.")
        }

        return messages
    }

    private func isValidEmail(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let atIndex = trimmed.firstIndex(of: "@"),
              atIndex != trimmed.startIndex,
              trimmed.distance(from: atIndex, to: trimmed.endIndex) > 3 else { return false }
        let domain = trimmed[trimmed.index(after: atIndex)...]
        return domain.contains(".") && domain.last != "."
    }

    private func fieldStateText(for kind: AuthFieldKind) -> String {
        if validationMessages[kind] != nil {
            return localized("auth.state.invalid", defaultValue: "Invalid")
        }
        if focusedField == kind {
            return localized("auth.state.focused", defaultValue: "Focused")
        }
        return localized("auth.state.idle", defaultValue: "Idle")
    }

    private func fieldBorderColor(for kind: AuthFieldKind) -> UIColor {
        if validationMessages[kind] != nil {
            return UIColor(ColorTokens.zoneDanger)
        }
        if focusedField == kind {
            return UIKitDesign.hairlineStrong
        }
        return UIKitDesign.hairlineColor
    }

    private var authStateText: String {
        if let forcedStateText {
            return forcedStateText
        }
        if isLoading {
            switch loadingKind {
            case .credentials:
                return localized("auth.state.loading.credentials", defaultValue: "Signing in")
            case .google:
                return localized("auth.state.loading.google", defaultValue: "Google sign-in loading")
            case .apple:
                return localized("auth.state.loading.apple", defaultValue: "Apple sign-in loading")
            case nil:
                return localized("auth.state.loading", defaultValue: "Loading")
            }
        }
        if validationMessages.isEmpty == false {
            return localized("auth.state.invalid", defaultValue: "Invalid")
        }
        if errorMessage != nil {
            return localized("auth.state.serverError", defaultValue: "Server error")
        }
        return localized("auth.state.idle", defaultValue: "Idle")
    }

    private func authStatePlate() -> UIView {
        var rows: [UIView] = []
        let state = UIKitDesign.label(authStateText, font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
        state.accessibilityIdentifier = "auth.state"
        rows.append(state)

        if let errorMessage {
            rows.append(divider())
            let error = UIKitDesign.label(errorMessage, font: UIKitDesign.regular(15), color: UIColor(ColorTokens.zoneDanger), lines: 0)
            error.accessibilityIdentifier = "auth.error"
            rows.append(error)
        }

        return dataPlate(rows, spacing: Spacing.sm)
    }

    private func choiceRow(title: String, value: String, action: Selector) -> UIView {
        let button = UIButton(type: .custom)
        button.accessibilityIdentifier = "auth.primarySport"
        button.accessibilityLabel = "\(title), \(value)"
        button.addTarget(self, action: action, for: .touchUpInside)
        let row = disclosureRow(title: title, subtitle: nil, trailing: value)
        row.isUserInteractionEnabled = false
        button.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            row.topAnchor.constraint(equalTo: button.topAnchor),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return button
    }

    private func googleButton() -> UIButton {
        let button = secondaryButton(title: mode == .signIn ? localized("auth.google.signIn") : localized("auth.google.signUp"))
        button.addTarget(self, action: #selector(handleGoogle), for: .touchUpInside)
        button.accessibilityIdentifier = "auth.google"
        button.accessibilityValue = isLoading && loadingKind == .google ? authStateText : nil
        button.isEnabled = !isLoading
        button.alpha = button.isEnabled ? 1 : 0.45
        return button
    }

    private func appleButton() -> UIView {
        let button = ASAuthorizationAppleIDButton(
            authorizationButtonType: mode == .signIn ? .signIn : .signUp,
            authorizationButtonStyle: .black
        )
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityIdentifier = "auth.apple"
        button.accessibilityValue = isLoading && loadingKind == .apple ? authStateText : nil
        button.isEnabled = !isLoading
        button.alpha = button.isEnabled ? 1 : 0.45
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        button.addTarget(self, action: #selector(handleApple), for: .touchUpInside)
        return button
    }

    private func secondaryButton(title: String) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.setTitleColor(UIKitDesign.textPrimary, for: .normal)
        button.titleLabel?.font = UIKitDesign.medium(17)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.backgroundColor = UIKitDesign.surface
        button.layer.borderWidth = UIKitDesign.hairline
        button.layer.borderColor = UIKitDesign.hairlineColor.cgColor
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        return button
    }

    private func switchModeButton() -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(
            mode == .signIn
                ? localized("auth.action.createAccountLink")
                : localized("auth.action.alreadyHaveAccount", defaultValue: "Already have an account? Sign In"),
            for: .normal
        )
        button.setTitleColor(UIKitDesign.textSecondary, for: .normal)
        button.titleLabel?.font = UIKitDesign.regular(15)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.layer.borderWidth = UIKitDesign.hairline
        button.layer.borderColor = UIKitDesign.hairlineColor.cgColor
        button.backgroundColor = UIKitDesign.surface
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        button.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.mode = self.mode == .signIn ? .signUp : .signIn
            self.errorMessage = nil
            self.forcedStateText = nil
            self.hasAttemptedSubmit = false
            Haptics.tap()
            self.rebuild()
        }, for: .touchUpInside)
        button.accessibilityIdentifier = "auth.switchMode"
        return button
    }

    private func resolveErrorMessage(_ error: any Error) -> String {
        if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
            forcedStateText = localized("auth.state.offline", defaultValue: "Offline")
            return localized("auth.error.offline", defaultValue: "No internet connection. Check your connection and try again.")
        }
        if let authError = error as? AuthService.AuthError {
            if let serverMessage = authError.serverMessage {
                return serverMessage
            }
            return localized(authError.localizationKey)
        } else if let bootstrapError = error as? UIKitAuthFlowError {
            return localized(bootstrapError.localizationKey)
        }
        return error.localizedDescription
    }

    private func sportDisplayName(_ sport: SportType) -> String {
        switch sport {
        case .lifting:
            return localized("sport.lifting", defaultValue: "Lifting")
        case .running:
            return localized("sport.running", defaultValue: "Running")
        case .cycling:
            return localized("sport.cycling", defaultValue: "Cycling")
        case .teamSport:
            return localized("sport.teamSport", defaultValue: "Team Sport")
        case .crossfit:
            return localized("sport.crossfit", defaultValue: "CrossFit")
        case .swimming:
            return localized("sport.swimming", defaultValue: "Swimming")
        case .custom:
            return localized("sport.custom", defaultValue: "Custom")
        }
    }

    private func localized(_ key: String.LocalizationValue) -> String {
        var resource = LocalizedStringResource(key)
        resource.locale = locale
        return String(localized: resource)
    }

    private func localized(_ key: StaticString, defaultValue: String.LocalizationValue) -> String {
        String(localized: key, defaultValue: defaultValue, locale: locale)
    }

    private func finishAuthenticated() {
        Haptics.success()
        container.setAuthenticated(true)
    }

    @objc private func chooseSport() {
        let controller = InstrumentChoiceListViewController(
            title: localized("auth.signup.primarySport"),
            stateText: { [weak self] in
                guard let self else { return "" }
                return "\(self.localized("onboarding.selected", defaultValue: "Selected")): \(self.sportDisplayName(self.selectedSport))"
            },
            options: { [weak self] in
                guard let self else { return [] }
                return SportType.allCases.map { sport in
                    InstrumentChoiceOption(
                        title: self.sportDisplayName(sport),
                        isSelected: self.selectedSport == sport
                    ) { [weak self] in
                        self?.selectedSport = sport
                        self?.rebuild()
                    }
                }
            }
        )
        showInstrumentDetail(controller)
    }

    @objc private func submit() {
        guard canSubmit, !isLoading else { return }
        hasAttemptedSubmit = true
        forcedStateText = nil
        let messages = validationMessages
        guard messages.isEmpty else {
            errorMessage = localized("auth.error.invalidFields", defaultValue: "Fix the highlighted fields and try again.")
            Haptics.warning()
            rebuild()
            return
        }
        setLoading(.credentials)
        errorMessage = nil
        rebuild()
        Task {
            switch mode {
            case .signIn:
                await signIn()
            case .signUp:
                await signUp()
            }
        }
    }

    private func signIn() async {
        do {
            try await container.authService.signIn(email: email, password: password)
            let localAthletes = try? modelContext.fetch(FetchDescriptor<Athlete>())
            if localAthletes?.isEmpty != false {
                guard let userId = await container.authService.currentUserId() else {
                    throw UIKitAuthFlowError.noUserId
                }
                let athlete = await container.syncService.bootstrapAthlete(
                    context: modelContext,
                    userId: userId
                )
                if athlete == nil {
                    throw UIKitAuthFlowError.athleteNotFound
                }
            }
            await container.syncService.pullAll(context: modelContext)
            setLoading(nil)
            finishAuthenticated()
        } catch {
            lastAuthError = error
            errorMessage = resolveErrorMessage(error)
            setLoading(nil)
            rebuild()
        }
    }

    private func signUp() async {
        do {
            let userId = try await container.authService.signUp(
                email: email,
                password: password,
                displayName: displayName,
                sportType: selectedSport.rawValue
            )
            let athlete = Athlete(
                id: userId,
                displayName: displayName,
                sportType: selectedSport,
                supabaseUserId: userId
            )
            modelContext.insert(athlete)
            try modelContext.save()
            await container.syncService.pushAthlete(athlete)
            setLoading(nil)
            finishAuthenticated()
        } catch {
            lastAuthError = error
            errorMessage = resolveErrorMessage(error)
            setLoading(nil)
            rebuild()
        }
    }

    @objc private func handleGoogle() {
        guard !isLoading else { return }
        setLoading(.google)
        forcedStateText = nil
        errorMessage = nil
        rebuild()
        Task { await socialSignIn(credential: nil) }
    }

    @objc private func handleApple() {
        guard !isLoading else { return }
        setLoading(.apple)
        forcedStateText = nil
        errorMessage = nil
        rebuild()
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    private func socialSignIn(credential: ASAuthorizationAppleIDCredential?) async {
        do {
            if let credential {
                try await container.authService.signInWithApple(credential: credential)
            } else {
                try await container.authService.signInWithGoogle()
            }
            let localAthletes = try? modelContext.fetch(FetchDescriptor<Athlete>())
            if localAthletes?.isEmpty != false {
                guard let userId = await container.authService.currentUserId() else {
                    throw UIKitAuthFlowError.noUserId
                }
                let existingAthlete = await container.syncService.bootstrapAthlete(
                    context: modelContext,
                    userId: userId
                )
                if existingAthlete == nil {
                    let name = credential.map { credential in
                        [credential.fullName?.givenName, credential.fullName?.familyName]
                            .compactMap { $0 }
                            .joined(separator: " ")
                    } ?? ""
                    let athlete = Athlete(
                        id: userId,
                        displayName: name.isEmpty ? localized("auth.field.namePlaceholder") : name,
                        sportType: .custom,
                        supabaseUserId: userId
                    )
                    modelContext.insert(athlete)
                    try modelContext.save()
                    await container.syncService.pushAthlete(athlete)
                }
            }
            await container.syncService.pullAll(context: modelContext)
            setLoading(nil)
            finishAuthenticated()
        } catch {
            lastAuthError = error
            errorMessage = resolveErrorMessage(error)
            setLoading(nil)
            rebuild()
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            lastAuthError = AuthService.AuthError.noIdentityToken
            errorMessage = resolveErrorMessage(AuthService.AuthError.noIdentityToken)
            setLoading(nil)
            rebuild()
            return
        }
        Task { await socialSignIn(credential: credential) }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        lastAuthError = error
        errorMessage = resolveErrorMessage(error)
        setLoading(nil)
        rebuild()
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        view.window ?? ASPresentationAnchor()
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        focusedField = authFieldKind(for: textField)
        textField.layer.borderColor = UIKitDesign.hairlineStrong.cgColor
        textField.accessibilityValue = localized("auth.state.focused", defaultValue: "Focused")
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        focusedField = nil
        if let kind = authFieldKind(for: textField) {
            textField.layer.borderColor = fieldBorderColor(for: kind).cgColor
            textField.accessibilityValue = fieldStateText(for: kind)
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    private func authFieldKind(for textField: UITextField) -> AuthFieldKind? {
        AuthFieldKind.allCases.first { $0.accessibilityIdentifier == textField.accessibilityIdentifier }
    }

    private func setLoading(_ kind: AuthLoadingKind?) {
        loadingKind = kind
        isLoading = kind != nil
    }

    private func applyScreenshotAuthStateIfNeeded() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("SCREENSHOT_AUTH_INVALID_MODE") {
            email = "alex"
            password = ""
            hasAttemptedSubmit = true
            errorMessage = localized("auth.error.invalidFields", defaultValue: "Fix the highlighted fields and try again.")
        } else if args.contains("SCREENSHOT_AUTH_LOADING_MODE") {
            email = "alex@example.com"
            password = "password123"
            setLoading(.credentials)
        } else if args.contains("SCREENSHOT_AUTH_SOCIAL_LOADING_MODE") {
            setLoading(.google)
        } else if args.contains("SCREENSHOT_AUTH_OFFLINE_MODE") {
            forcedStateText = localized("auth.state.offline", defaultValue: "Offline")
            errorMessage = localized("auth.error.offline", defaultValue: "No internet connection. Check your connection and try again.")
        }
        #endif
    }
}

private final class OnboardingFlowViewController: InstrumentScrollViewController {
    private let finalStep = 4
    private let container: AppContainer
    private let modelContext: ModelContext
    private var locale: Locale
    private let onComplete: () -> Void

    private var currentStep = 0
    private var selectedFrequency: TrainingFrequency?
    private var selectedLevel: ExperienceLevel?

    init(
        container: AppContainer,
        modelContext: ModelContext,
        locale: Locale,
        onComplete: @escaping () -> Void
    ) {
        self.container = container
        self.modelContext = modelContext
        self.locale = locale
        self.onComplete = onComplete
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.accessibilityIdentifier = "onboarding.flow"
    }

    func update(locale: Locale) {
        self.locale = locale
        rebuild()
    }

    override func rebuild() {
        clearContent()
        addHorizontalInsets(hero(
            kicker: String(format: localized("onboarding.stepProgress", defaultValue: "Setup %d / 5"), currentStep + 1),
            title: stepTitle,
            body: stepBody
        ), top: Spacing.lg)
        addHorizontalInsets(progressStrip(), top: Spacing.sm)

        switch currentStep {
        case 0:
            addSection(title: localized("onboarding.section.language", defaultValue: "Language"), content: dataPlate(languageRows(), spacing: Spacing.sm))
        case 1:
            addSection(title: localized("onboarding.section.frequency", defaultValue: "Training frequency"), content: dataPlate(frequencyRows(), spacing: Spacing.sm))
        case 2:
            addSection(title: localized("onboarding.section.experience", defaultValue: "Experience"), content: dataPlate(experienceRows(), spacing: Spacing.sm))
        case 3:
            addSection(title: localized("onboarding.section.health", defaultValue: "Apple Health"), content: dataPlate(healthRows(), spacing: Spacing.sm))
        default:
            addSection(title: localized("onboarding.section.summary", defaultValue: "Ready"), content: dataPlate(summaryRows(), spacing: Spacing.sm))
        }

        addSection(content: dataPlate(navigationRows(), spacing: Spacing.sm))
    }

    private var stepTitle: String {
        switch currentStep {
        case 0: localized("onboarding.language.title")
        case 1: localized("onboarding.frequency.title")
        case 2: localized("onboarding.experience.title")
        case 3: localized("onboarding.healthkit.title")
        default: localized("onboarding.ready.title", defaultValue: "You're ready")
        }
    }

    private var stepBody: String {
        switch currentStep {
        case 0: localized("onboarding.language.subtitle")
        case 1: localized("onboarding.frequency.subtitle")
        case 2: localized("onboarding.experience.subtitle")
        case 3: localized("onboarding.healthkit.subtitle")
        default: localized("onboarding.ready.subtitle", defaultValue: "Your profile is configured. Tuwa will tune recommendations as you train.")
        }
    }

    private var canContinue: Bool {
        switch currentStep {
        case 0: true
        case 1: selectedFrequency != nil
        case 2: selectedLevel != nil
        default: true
        }
    }

    private func summaryRows() -> [UIView] {
        let selectedFrequencyText = selectedFrequency.map(frequencyDisplayName) ?? localized("onboarding.summary.notSet", defaultValue: "Not set")
        let selectedLevelText = selectedLevel.map(experienceDisplayName) ?? localized("onboarding.summary.notSet", defaultValue: "Not set")
        let healthText: String
        switch container.healthKitService.connectionState {
        case .notRequested:
            healthText = localized("onboarding.summary.healthNotConnected", defaultValue: "Skipped for now")
        case .requestedNoData, .connected:
            healthText = localized("onboarding.healthkit.connected")
        }

        return [
            summaryConfirmation(),
            divider(),
            summaryRow(
                title: localized("onboarding.section.language", defaultValue: "Language"),
                trailing: languageAutonym(for: container.localeManager.activeLocale),
                accessibilityIdentifier: "onboarding.summary.language"
            ),
            divider(),
            summaryRow(
                title: localized("onboarding.section.frequency", defaultValue: "Training frequency"),
                trailing: selectedFrequencyText,
                accessibilityIdentifier: "onboarding.summary.frequency"
            ),
            divider(),
            summaryRow(
                title: localized("onboarding.section.experience", defaultValue: "Experience"),
                trailing: selectedLevelText,
                accessibilityIdentifier: "onboarding.summary.experience"
            ),
            divider(),
            summaryRow(
                title: localized("onboarding.section.health", defaultValue: "Apple Health"),
                trailing: healthText,
                accessibilityIdentifier: "onboarding.summary.health"
            )
        ]
    }

    private func languageRows() -> [UIView] {
        container.localeManager.supportedLocales.enumerated().flatMap { index, locale in
            var rows = [selectionButton(
                title: languageAutonym(for: locale),
                subtitle: locale.identifier,
                selected: container.localeManager.activeLocale.identifier == locale.identifier,
                accessibilityIdentifier: "onboarding.option.language.\(locale.identifier)"
            ) { [weak self] in
                self?.container.localeManager.setLocale(locale)
                Haptics.select()
                self?.rebuild()
            }]
            if index < container.localeManager.supportedLocales.count - 1 {
                rows.append(divider())
            }
            return rows
        }
    }

    private func frequencyRows() -> [UIView] {
        TrainingFrequency.allCases.enumerated().flatMap { index, frequency in
            var rows = [selectionButton(
                title: frequencyDisplayName(frequency),
                subtitle: nil,
                selected: selectedFrequency == frequency,
                accessibilityIdentifier: "onboarding.option.frequency.\(frequency.rawValue)"
            ) { [weak self] in
                self?.selectedFrequency = frequency
                Haptics.select()
                self?.rebuild()
            }]
            if index < TrainingFrequency.allCases.count - 1 {
                rows.append(divider())
            }
            return rows
        }
    }

    private func experienceRows() -> [UIView] {
        ExperienceLevel.allCases.enumerated().flatMap { index, level in
            var rows = [selectionButton(
                title: experienceDisplayName(level),
                subtitle: experienceSubtitle(level),
                selected: selectedLevel == level,
                accessibilityIdentifier: "onboarding.option.experience.\(level.rawValue)"
            ) { [weak self] in
                self?.selectedLevel = level
                Haptics.select()
                self?.rebuild()
            }]
            if index < ExperienceLevel.allCases.count - 1 {
                rows.append(divider())
            }
            return rows
        }
    }

    private func healthRows() -> [UIView] {
        let privacy = UIKitDesign.label(
            localized("onboarding.healthkit.privacy", defaultValue: "Raw Health data stays on device. Tuwa uses recovery summaries to tune recommendations."),
            font: UIKitDesign.regular(15),
            color: UIKitDesign.textSecondary,
            lines: 0
        )
        privacy.accessibilityIdentifier = "onboarding.health.privacy"
        var rows: [UIView] = [
            privacy,
            divider(),
            UIKitDesign.label(localized("onboarding.healthkit.item.hrv"), font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0),
            divider(),
            UIKitDesign.label(localized("onboarding.healthkit.item.rhr"), font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0),
            divider(),
            UIKitDesign.label(localized("onboarding.healthkit.item.sleep"), font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0),
            divider()
        ]

        switch container.healthKitService.connectionState {
        case .notRequested:
            let connect = actionButton(title: localized("onboarding.healthkit.connect"), action: #selector(connectHealth))
            connect.accessibilityIdentifier = "onboarding.health.connect"
            rows.append(connect)
            rows.append(divider())
            rows.append(quietButton(
                title: localized("onboarding.skipForNow"),
                action: #selector(showSummary),
                accessibilityIdentifier: "onboarding.health.skip"
            ))
        case .requestedNoData, .connected:
            let connected = UIKitDesign.label(localized("onboarding.healthkit.connected"), font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
            connected.accessibilityIdentifier = "onboarding.health.connected"
            rows.append(connected)
            rows.append(divider())
            let continueButton = actionButton(title: localized("action.continue"), action: #selector(showSummary))
            continueButton.accessibilityIdentifier = "onboarding.health.continue"
            rows.append(continueButton)
        }
        return rows
    }

    private func navigationRows() -> [UIView] {
        var rows: [UIView] = []
        if currentStep > 0 {
            rows.append(quietButton(
                title: localized("action.back", defaultValue: "Back"),
                action: #selector(backStep),
                accessibilityIdentifier: "onboarding.back"
            ))
            rows.append(divider())
        }
        if currentStep < 3 {
            let button = actionButton(
                title: currentStep == 0
                    ? localized("onboarding.continue.toSetup")
                    : localized("action.continue"),
                action: #selector(nextStep)
            )
            button.isEnabled = canContinue
            button.alpha = canContinue ? 1 : 0.45
            button.accessibilityIdentifier = "onboarding.continue"
            rows.append(button)
        } else if currentStep == 3 {
            let note = UIKitDesign.label(localized("onboarding.healthkit.permissionsNote", defaultValue: "You can change Health permissions later in Profile."), font: UIKitDesign.regular(13), color: UIKitDesign.textTertiary, lines: 0)
            note.accessibilityIdentifier = "onboarding.health.permissionNote"
            rows.append(note)
        } else {
            let complete = actionButton(title: localized("onboarding.ready.action", defaultValue: "Start using Tuwa"), action: #selector(completeOnboarding))
            complete.accessibilityIdentifier = "onboarding.ready.complete"
            rows.append(complete)
        }
        return rows
    }

    private func selectionButton(
        title: String,
        subtitle: String?,
        selected: Bool,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> UIView {
        let button = UIButton(type: .custom)
        button.accessibilityIdentifier = accessibilityIdentifier
        button.accessibilityLabel = [title, subtitle, selected ? localized("onboarding.selected", defaultValue: "Selected") : nil]
            .compactMap { $0 }
            .joined(separator: ", ")
        button.backgroundColor = selected ? UIKitDesign.active : UIKitDesign.surface
        button.layer.borderWidth = UIKitDesign.hairline
        button.layer.borderColor = selected ? UIKitDesign.hairlineStrong.cgColor : UIKitDesign.hairlineColor.cgColor
        button.accessibilityTraits = selected ? [.button, .selected] : .button
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)

        let selectedText = selected ? "✓ \(localized("onboarding.selected", defaultValue: "Selected"))" : nil
        let row = disclosureRow(title: title, subtitle: subtitle, trailing: selectedText)
        row.isUserInteractionEnabled = false
        button.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            row.topAnchor.constraint(equalTo: button.topAnchor),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return button
    }

    private func progressStrip() -> UIView {
        let label = UIKitDesign.label(
            "Step \(currentStep + 1) of 5 · \(stepTitle)",
            font: UIKitDesign.regular(15),
            color: UIKitDesign.textSecondary,
            lines: 0
        )
        label.accessibilityIdentifier = "onboarding.progress"
        return dataPlate([label], spacing: Spacing.sm)
    }

    private func summaryConfirmation() -> UIView {
        let frequency = selectedFrequency.map(frequencyDisplayName) ?? localized("onboarding.summary.notSet", defaultValue: "Not set")
        let experience = selectedLevel.map(experienceDisplayName) ?? localized("onboarding.summary.notSet", defaultValue: "Not set")
        let label = UIKitDesign.label(
            String(format: localized("onboarding.summary.confirmation", defaultValue: "Configured for %@ at %@ experience."), frequency, experience),
            font: UIKitDesign.medium(19),
            color: UIKitDesign.textPrimary,
            lines: 0
        )
        label.accessibilityIdentifier = "onboarding.summary.confirmation"
        return label
    }

    private func summaryRow(title: String, trailing: String, accessibilityIdentifier: String) -> UIView {
        let row = disclosureRow(title: title, subtitle: nil, trailing: trailing)
        row.isAccessibilityElement = true
        row.accessibilityIdentifier = accessibilityIdentifier
        row.accessibilityLabel = "\(title), \(trailing)"
        return row
    }

    private func quietButton(title: String, action: Selector, accessibilityIdentifier: String? = nil) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.accessibilityIdentifier = accessibilityIdentifier
        button.setTitleColor(UIKitDesign.textSecondary, for: .normal)
        button.titleLabel?.font = UIKitDesign.regular(15)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.backgroundColor = UIKitDesign.surface
        button.layer.borderWidth = UIKitDesign.hairline
        button.layer.borderColor = UIKitDesign.hairlineColor.cgColor
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func languageAutonym(for locale: Locale) -> String {
        switch locale.identifier {
        case "zh-Hans": "中文(简体)"
        default: "English"
        }
    }

    private func frequencyDisplayName(_ frequency: TrainingFrequency) -> String {
        switch frequency {
        case .oneToTwo:
            return localized("frequency.oneToTwo", defaultValue: "1-2 days/week")
        case .threeToFour:
            return localized("frequency.threeToFour", defaultValue: "3-4 days/week")
        case .fiveToSix:
            return localized("frequency.fiveToSix", defaultValue: "5-6 days/week")
        case .sevenPlus:
            return localized("frequency.sevenPlus", defaultValue: "7+ days/week")
        }
    }

    private func experienceDisplayName(_ level: ExperienceLevel) -> String {
        switch level {
        case .beginner:
            return localized("experience.beginner", defaultValue: "Beginner")
        case .intermediate:
            return localized("experience.intermediate", defaultValue: "Intermediate")
        case .advanced:
            return localized("experience.advanced", defaultValue: "Advanced")
        }
    }

    private func experienceSubtitle(_ level: ExperienceLevel) -> String {
        switch level {
        case .beginner:
            return localized("experience.beginner.subtitle", defaultValue: "New to structured training")
        case .intermediate:
            return localized("experience.intermediate.subtitle", defaultValue: "1-3 years consistent training")
        case .advanced:
            return localized("experience.advanced.subtitle", defaultValue: "3+ years, understands periodization")
        }
    }

    private func localized(_ key: String.LocalizationValue) -> String {
        var resource = LocalizedStringResource(key)
        resource.locale = locale
        return String(localized: resource)
    }

    private func localized(_ key: StaticString, defaultValue: String.LocalizationValue) -> String {
        String(localized: key, defaultValue: defaultValue, locale: locale)
    }

    @objc private func nextStep() {
        guard canContinue else { return }
        currentStep = min(finalStep, currentStep + 1)
        Haptics.tap()
        rebuild()
    }

    @objc private func backStep() {
        currentStep = max(0, currentStep - 1)
        Haptics.tap()
        rebuild()
    }

    @objc private func connectHealth() {
        Task {
            try? await container.healthKitService.requestAuthorization()
            showSummary()
        }
    }

    @objc private func showSummary() {
        currentStep = finalStep
        Haptics.tap()
        rebuild()
    }

    @objc private func completeOnboarding() {
        guard let athlete = ((try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []).first,
              let selectedFrequency,
              let selectedLevel else {
            assertionFailure("completeOnboarding called without required selections")
            return
        }
        athlete.trainingFrequency = selectedFrequency
        athlete.experienceLevel = selectedLevel
        athlete.updatedAt = .now
        try? modelContext.save()
        Task { await container.syncService.pushAthlete(athlete) }
        Haptics.success()
        onComplete()
    }
}

private final class TodayViewController: InstrumentScrollViewController {
    private let container: AppContainer
    private let modelContext: ModelContext
    private let locale: Locale
    private var viewModel = DashboardViewModel()
    private var didRequestLoad = false
    private var didTrackRecommendationOpened = false

    init(container: AppContainer, modelContext: ModelContext, locale: Locale) {
        self.container = container
        self.modelContext = modelContext
        self.locale = locale
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadDashboardData()
    }

    override func rebuild() {
        clearContent()
        let state = makeViewState()
        addHorizontalInsets(todayHero(state: state), top: Spacing.sm)
        let primaryAction = actionButton(title: state.primaryActionTitle, action: #selector(performPrimaryAction))
        primaryAction.accessibilityIdentifier = "today.primaryAction"
        addHorizontalInsets(primaryAction, top: Spacing.lg)

        addSection(
            title: "Signals",
            content: metricRail(state.signalMetrics.map { ($0.label, $0.value, $0.detail) })
        )

        addSection(title: "Training load", content: dataPlate(metricRows(state.loadMetrics), spacing: Spacing.sm))

        if !state.recentSessions.isEmpty {
            var rows: [UIView] = []
            for (index, session) in state.recentSessions.enumerated() {
                rows.append(sessionRow(session))
                if index < state.recentSessions.count - 1 {
                    rows.append(divider())
                }
            }
            addSection(title: "Recent sessions", content: dataPlate(rows, spacing: Spacing.sm))
        }

        if let statusTitle = state.statusTitle,
           let statusBody = state.statusBody {
            addSection(content: dataPlate([
                UIKitDesign.label(statusTitle, font: UIKitDesign.medium(19), color: UIKitDesign.textPrimary),
                UIKitDesign.label(statusBody, font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
            ], spacing: Spacing.xs))
        }
    }

    private func makeViewState() -> TodayViewState {
        TodayViewState.make(
            recoveryScore: viewModel.recoveryScore,
            hasRealData: viewModel.hasRealData,
            recommendation: viewModel.recommendation,
            isLoading: viewModel.isLoading,
            healthConnectionState: container.healthKitService.connectionState,
            latestHRV: viewModel.latestHRV,
            latestSleepMinutes: viewModel.latestSleepMinutes,
            acwr: viewModel.acwr,
            acwrZone: viewModel.acwrZone,
            atl: viewModel.atl,
            ctl: viewModel.ctl,
            tsb: viewModel.tsb,
            recentSessions: recentSessions(),
            locale: locale
        )
    }

    private func todayHero(state: TodayViewState) -> UIView {
        hero(kicker: state.heroKicker, title: state.heroTitle, body: state.heroBody)
    }

    private func metricRows(_ metrics: [TodayViewState.Metric]) -> [UIView] {
        metrics.enumerated().flatMap { index, metric -> [UIView] in
            var rows = [metricCell(label: metric.label, value: metric.value, detail: metric.detail)]
            if index < metrics.count - 1 {
                rows.append(divider())
            }
            return rows
        }
    }

    private func loadDashboardData() {
        guard !didRequestLoad else { return }
        didRequestLoad = true
        Task { [weak self] in
            guard let self else { return }
            let athletes = (try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []
            guard let athlete = athletes.first else {
                viewModel.isLoading = false
                rebuild()
                return
            }
            await viewModel.load(
                athlete: athlete,
                healthKitService: container.healthKitService,
                modelContext: modelContext,
                syncService: container.syncService
            )
            viewModel.activateVerdictSurface()
            viewModel.refreshNotificationContent(
                notificationService: container.notificationService,
                modelContext: modelContext
            )
            trackRecommendationOpenedIfNeeded()
            rebuild()
        }
    }

    private func trackRecommendationOpenedIfNeeded() {
        guard !didTrackRecommendationOpened,
              let recommendation = viewModel.recommendation else { return }
        didTrackRecommendationOpened = true
        container.uxAnalyticsService.track(.todayRecommendationOpened, properties: [
            "surface": "today",
            "session_type": recommendation.sessionType.rawValue
        ])
    }

    private func recentSessions() -> [WorkoutSession] {
        let descriptor = FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.sessionDate, order: .reverse)])
        let athletes = (try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []
        guard let athleteId = athletes.first?.id else { return [] }
        return ((try? modelContext.fetch(descriptor)) ?? [])
            .filter { $0.athlete?.id == athleteId }
            .prefix(5)
            .map { $0 }
    }

    private func sessionRow(_ session: TodayViewState.SessionRow) -> UIView {
        let stack = UIKitDesign.verticalStack(spacing: Spacing.baselinePair)
        stack.addArrangedSubview(UIKitDesign.label(session.title, font: UIKitDesign.medium(17), color: UIKitDesign.textPrimary))
        stack.addArrangedSubview(UIKitDesign.label(session.subtitle, font: UIKitDesign.regular(13), color: UIKitDesign.textSecondary, lines: 0))
        stack.isAccessibilityElement = true
        stack.accessibilityLabel = "\(session.title), \(session.subtitle)"
        return stack
    }

    @objc private func performPrimaryAction() {
        switch makeViewState().primaryAction {
        case .workout:
            openWorkout()
        case .connectHealth:
            connectHealth()
        }
    }

    @objc private func openWorkout() {
        Haptics.tap()
        container.uxAnalyticsService.track(.primaryActionTapped, properties: [
            "surface": "today",
            "action": "start_workout"
        ])
        container.uxAnalyticsService.track(.workoutStarted, properties: [
            "source": "today"
        ])
        let controller = ActiveWorkoutViewController(
            container: container,
            modelContext: modelContext,
            locale: locale
        )
        present(InstrumentNavigationController(rootViewController: controller), animated: true)
    }

    @objc private func connectHealth() {
        Haptics.tap()
        container.uxAnalyticsService.track(.permissionCTATapped, properties: [
            "permission": "apple_health",
            "surface": "today"
        ])
        Task {
            try? await container.healthKitService.requestAuthorization()
            didRequestLoad = false
            loadDashboardData()
        }
    }
}

private final class AthleteProfileHubViewController: InstrumentScrollViewController {
    private let container: AppContainer
    private let modelContext: ModelContext
    private let locale: Locale
    private let onOpenCoachMode: (UIViewController) -> Void

    init(
        container: AppContainer,
        modelContext: ModelContext,
        locale: Locale,
        onOpenCoachMode: @escaping (UIViewController) -> Void
    ) {
        self.container = container
        self.modelContext = modelContext
        self.locale = locale
        self.onOpenCoachMode = onOpenCoachMode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func rebuild() {
        clearContent()
        let athlete = ((try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []).first
        let state = ProfileOverviewViewState.make(
            athlete: athlete,
            isCoachEntitled: container.subscriptionService.isCoach,
            isProEntitled: container.subscriptionService.isPro,
            hasSyncFailure: SyncTimestampStore.shared.hasAnyFailure,
            locale: locale
        )
        addHorizontalInsets(hero(
            kicker: state.heroKicker,
            title: state.athleteName,
            body: state.contextText
        ), top: Spacing.sm)

        if state.showsCoachContext {
            addSection(title: localized("profile.section.context"), content: actionPlate(
                title: localized("profile.context.coachMode.title"),
                subtitle: localized("profile.context.coachMode.subtitle"),
                trailing: state.coachModeTrailing,
                action: #selector(openCoachMode),
                accessibilityIdentifier: "profile.coachMode"
            ))
        }

        addSection(title: localized("profile.section.training"), content: dataPlate([
            actionRow(
                title: localized("profile.destination.trainingProfile.title"),
                subtitle: localized("profile.destination.trainingProfile.subtitle"),
                action: #selector(openTrainingProfile),
                accessibilityIdentifier: "profile.trainingProfile"
            ),
            divider(),
            actionRow(
                title: localized("profile.destination.fullSettings.title"),
                subtitle: localized("profile.destination.fullSettings.subtitle"),
                action: #selector(openLegacyProfile),
                accessibilityIdentifier: "profile.fullSettings"
            )
        ], spacing: Spacing.sm))

        addSection(title: localized("profile.section.connections"), content: dataPlate([
            actionRow(
                title: localized("profile.invite.coach.title", defaultValue: "Invite coach"),
                subtitle: localized("profile.invite.coach.subtitle", defaultValue: "Generate a code a coach can use to link with you"),
                action: #selector(openInviteCoach),
                accessibilityIdentifier: "profile.inviteCoach"
            ),
            divider(),
            actionRow(
                title: localized("profile.connection.health.title"),
                subtitle: localized("profile.connection.health.subtitle"),
                action: #selector(openHealthPermissions),
                accessibilityIdentifier: "profile.healthPermissions"
            ),
            divider(),
            actionRow(
                title: localized("sync.status.title", defaultValue: "Sync status"),
                subtitle: state.syncStatusText,
                action: #selector(openSyncStatus),
                accessibilityIdentifier: "profile.syncStatus"
            )
        ], spacing: Spacing.sm))

        addSection(title: localized("profile.section.product"), content: dataPlate([
            actionRow(
                title: localized("profile.destination.language"),
                subtitle: state.languageText,
                action: #selector(openLanguage),
                accessibilityIdentifier: "profile.language"
            ),
            divider(),
            actionRow(
                title: localized("profile.destination.subscription"),
                subtitle: state.subscriptionText,
                action: #selector(openSubscription),
                accessibilityIdentifier: "profile.subscription"
            )
        ], spacing: Spacing.sm))

        addSection(title: localized("profile.section.account"), content: dataPlate([
            actionRow(
                title: localized("profile.account.title", defaultValue: "Account and security"),
                subtitle: localized("profile.account.subtitle", defaultValue: "Sign out or permanently delete account"),
                action: #selector(openAccount),
                accessibilityIdentifier: "profile.account"
            )
        ]))
    }

    private func actionPlate(
        title: String,
        subtitle: String?,
        trailing: String? = nil,
        action: Selector,
        accessibilityIdentifier: String? = nil
    ) -> UIView {
        dataPlate([actionRow(
            title: title,
            subtitle: subtitle,
            trailing: trailing,
            action: action,
            accessibilityIdentifier: accessibilityIdentifier
        )])
    }

    private func actionRow(
        title: String,
        subtitle: String?,
        trailing: String? = nil,
        action: Selector,
        accessibilityIdentifier: String? = nil
    ) -> UIView {
        let button = UIButton(type: .custom)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.accessibilityLabel = title
        button.accessibilityIdentifier = accessibilityIdentifier
        let row = disclosureRow(title: title, subtitle: subtitle, trailing: trailing)
        row.isUserInteractionEnabled = false
        button.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            row.topAnchor.constraint(equalTo: button.topAnchor),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return button
    }

    private func localized(_ key: String.LocalizationValue) -> String {
        UIKitStrings.localized(key, locale: locale)
    }

    private func localized(_ key: StaticString, defaultValue: String.LocalizationValue) -> String {
        UIKitStrings.localized(key, defaultValue: defaultValue, locale: locale)
    }

    @objc private func openCoachMode() {
        Haptics.tap()
        container.uxAnalyticsService.track(.profileDestinationOpened, properties: [
            "destination": "coach_mode"
        ])
        if container.subscriptionService.isCoach {
            onOpenCoachMode(self)
            container.setMode(.coach)
        } else {
            present(InstrumentNavigationController(rootViewController: UpgradeViewController(container: container, trigger: .coach)), animated: true)
        }
    }

    @objc private func openTrainingProfile() {
        Haptics.tap()
        container.uxAnalyticsService.track(.profileDestinationOpened, properties: [
            "destination": "training_profile"
        ])
        let controller = TrainingProfileEditorViewController(
            container: container,
            modelContext: modelContext
        )
        present(InstrumentNavigationController(rootViewController: controller), animated: true)
    }

    @objc private func openLegacyProfile() {
        Haptics.tap()
        container.uxAnalyticsService.track(.profileDestinationOpened, properties: [
            "destination": "full_settings"
        ])
        let controller = ProfileSettingsViewController(
            container: container,
            modelContext: modelContext,
            locale: locale
        )
        present(InstrumentNavigationController(rootViewController: controller), animated: true)
    }

    @objc private func openHealthPermissions() {
        Haptics.tap()
        container.uxAnalyticsService.track(.profileDestinationOpened, properties: [
            "destination": "health_permissions"
        ])
        let controller = HealthPermissionsViewController(container: container)
        present(InstrumentNavigationController(rootViewController: controller), animated: true)
    }

    @objc private func openInviteCoach() {
        Haptics.tap()
        container.uxAnalyticsService.track(.profileDestinationOpened, properties: [
            "destination": "invite_coach"
        ])
        let controller = InviteFlowViewController(
            container: container,
            modelContext: modelContext,
            mode: .athleteCode
        )
        present(InstrumentNavigationController(rootViewController: controller), animated: true)
    }

    @objc private func openSyncStatus() {
        Haptics.tap()
        container.uxAnalyticsService.track(.profileDestinationOpened, properties: [
            "destination": "sync_status"
        ])
        let controller = SyncStatusViewController(
            container: container,
            modelContext: modelContext
        )
        present(InstrumentNavigationController(rootViewController: controller), animated: true)
    }

    @objc private func openLanguage() {
        Haptics.tap()
        container.uxAnalyticsService.track(.profileDestinationOpened, properties: [
            "destination": "language"
        ])
        let controller = LanguagePickerViewController(container: container)
        present(InstrumentNavigationController(rootViewController: controller), animated: true)
    }

    @objc private func openSubscription() {
        Haptics.tap()
        container.uxAnalyticsService.track(.profileDestinationOpened, properties: [
            "destination": "subscription"
        ])
        present(InstrumentNavigationController(rootViewController: UpgradeViewController(container: container, trigger: .athletePro)), animated: true)
    }

    @objc private func openAccount() {
        Haptics.tap()
        container.uxAnalyticsService.track(.profileDestinationOpened, properties: [
            "destination": "account"
        ])
        let controller = AccountSecurityViewController(
            container: container,
            modelContext: modelContext,
            locale: locale
        )
        present(InstrumentNavigationController(rootViewController: controller), animated: true)
    }
}

private final class AccountSecurityViewController: InstrumentScrollViewController {
    private let container: AppContainer
    private let modelContext: ModelContext
    private let locale: Locale
    private var isDeleting = false

    init(container: AppContainer, modelContext: ModelContext, locale: Locale) {
        self.container = container
        self.modelContext = modelContext
        self.locale = locale
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = localized("profile.section.account")
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: localized("action.done"),
            style: .done,
            target: self,
            action: #selector(close)
        )
    }

    override func rebuild() {
        clearContent()
        addHorizontalInsets(hero(
            kicker: localized("profile.section.account"),
            title: localized("profile.account.title", defaultValue: "Account and security"),
            body: localized("profile.account.body", defaultValue: "Security and destructive account actions live here, away from day-to-day preferences.")
        ), top: Spacing.sm)

        addSection(title: localized("profile.account.security", defaultValue: "Security"), content: dataPlate([
            disclosureRow(
                title: localized("profile.account.session", defaultValue: "Session"),
                subtitle: localized("profile.account.sessionDetail", defaultValue: "Managed by Supabase Auth and stored securely on this device"),
                trailing: localized("profile.account.signedIn", defaultValue: "Signed in")
            )
        ], spacing: Spacing.sm))

        addSection(title: localized("profile.section.account"), content: dataPlate([
            actionRow(
                title: localized("profile.signOut"),
                subtitle: localized("profile.account.signOutDetail", defaultValue: "Leave this device without deleting data"),
                action: #selector(signOut),
                accessibilityIdentifier: "profile.account.signOut"
            )
        ], spacing: Spacing.sm))

        addSection(title: localized("profile.account.dangerZone", defaultValue: "Delete account"), content: dataPlate([
            UIKitDesign.label(
                localized("profile.delete.confirmBody"),
                font: UIKitDesign.regular(15),
                color: UIKitDesign.textSecondary,
                lines: 0
            ),
            divider(),
            destructiveRow(
                title: isDeleting
                    ? localized("profile.action.deleting")
                    : localized("profile.action.deleteAccount"),
                subtitle: localized("profile.account.deleteDetail", defaultValue: "Permanent action. This cannot be undone."),
                action: #selector(confirmDeleteAccount),
                accessibilityIdentifier: "profile.account.delete"
            )
        ], spacing: Spacing.sm))
    }

    private func actionRow(
        title: String,
        subtitle: String?,
        action: Selector,
        accessibilityIdentifier: String? = nil
    ) -> UIView {
        let button = UIButton(type: .custom)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.accessibilityIdentifier = accessibilityIdentifier
        button.accessibilityLabel = [title, subtitle].compactMap { $0 }.joined(separator: ", ")
        let row = disclosureRow(title: title, subtitle: subtitle)
        row.isUserInteractionEnabled = false
        button.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            row.topAnchor.constraint(equalTo: button.topAnchor),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return button
    }

    private func destructiveRow(
        title: String,
        subtitle: String?,
        action: Selector,
        accessibilityIdentifier: String
    ) -> UIView {
        let button = actionRow(
            title: title,
            subtitle: subtitle,
            action: action,
            accessibilityIdentifier: accessibilityIdentifier
        )
        button.isUserInteractionEnabled = !isDeleting
        button.alpha = isDeleting ? 0.64 : 1
        return button
    }

    private func localized(_ key: String.LocalizationValue) -> String {
        UIKitStrings.localized(key, locale: locale)
    }

    private func localized(_ key: StaticString, defaultValue: String.LocalizationValue) -> String {
        UIKitStrings.localized(key, defaultValue: defaultValue, locale: locale)
    }

    @objc private func signOut() {
        Haptics.tap()
        Task {
            try? await container.signOut(modelContext: modelContext)
        }
    }

    @objc private func confirmDeleteAccount() {
        guard !isDeleting else { return }
        Haptics.warning()
        let alert = UIAlertController(
            title: localized("profile.action.deleteAccount"),
            message: localized("profile.delete.confirmBody"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: localized("action.cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: localized("action.delete"), style: .destructive) { [weak self] _ in
            self?.deleteAccount()
        })
        present(alert, animated: true)
    }

    private func deleteAccount() {
        guard !isDeleting else { return }
        isDeleting = true
        rebuild()
        Task { [weak self] in
            guard let self else { return }
            do {
                try await container.deleteAccount(modelContext: modelContext)
            } catch {
                isDeleting = false
                rebuild()
                showError(String(format: localized("profile.deleteAccount.error"), error.localizedDescription))
            }
        }
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: localized("error.generic", defaultValue: "Error"), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func close() {
        dismiss(animated: true)
    }
}

private enum InviteFlowMode: Equatable {
    case athleteCode
    case coachEmail

    var title: String {
        switch self {
        case .athleteCode: "Invite Coach"
        case .coachEmail: "Invite Athlete"
        }
    }

    var kicker: String {
        switch self {
        case .athleteCode: "Coach Link"
        case .coachEmail: "Roster Invite"
        }
    }

    var primaryTitle: String {
        switch self {
        case .athleteCode: "Generate Code"
        case .coachEmail: "Send Invite"
        }
    }
}

private enum UIKitInviteService {
    static func makeLocalCode() -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).compactMap { _ in chars.randomElement() })
    }

    @MainActor
    static func generateInviteCode(for athleteId: UUID, container: AppContainer) async throws -> String {
        let code = makeLocalCode()
        let expires = Date.now.addingTimeInterval(48 * 60 * 60)

        struct InvitationInsert: Encodable {
            let inviter_id: UUID
            let inviter_role: String
            let code: String
            let expires_at: Date
        }

        try await container.supabase
            .from("invitations")
            .insert(InvitationInsert(
                inviter_id: athleteId,
                inviter_role: "athlete",
                code: code,
                expires_at: expires
            ))
            .execute()

        return code
    }

    @MainActor
    static func sendEmailInvite(to email: String, from coachId: UUID, container: AppContainer) async throws {
        let code = makeLocalCode()
        let expires = Date.now.addingTimeInterval(48 * 60 * 60)

        struct InvitationInsert: Encodable {
            let inviter_id: UUID
            let inviter_role: String
            let code: String
            let email: String
            let expires_at: Date
        }

        try await container.supabase
            .from("invitations")
            .insert(InvitationInsert(
                inviter_id: coachId,
                inviter_role: "coach",
                code: code,
                email: email,
                expires_at: expires
            ))
            .execute()

        struct EdgePayload: Encodable {
            let email: String
            let code: String
        }

        try await container.supabase.functions.invoke(
            "send-invite-email",
            options: .init(body: EdgePayload(email: email, code: code))
        )
    }
}

private final class InviteFlowViewController: InstrumentScrollViewController, UITextFieldDelegate {
    private let container: AppContainer
    private let modelContext: ModelContext
    private let mode: InviteFlowMode
    private var inviteCode: String?
    private var email = ""
    private var isWorking = false
    private var didSend = false
    private var errorMessage: String?
    private let actionDock: UIKitBottomActionDock

    init(container: AppContainer, modelContext: ModelContext, mode: InviteFlowMode) {
        self.container = container
        self.modelContext = modelContext
        self.mode = mode
        self.actionDock = UIKitBottomActionDock(primaryTitle: mode.primaryTitle)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = mode.title
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(cancelInvite)
        )
        navigationItem.leftBarButtonItem?.accessibilityIdentifier = "invite.cancel"
        actionDock.primaryButton.addTarget(self, action: #selector(performPrimaryAction), for: .touchUpInside)
        installBottomActionDock(actionDock)
    }

    override func rebuild() {
        clearContent()
        actionDock.updatePrimary(
            title: primaryTitle,
            isEnabled: canSubmit,
            accessibilityIdentifier: primaryIdentifier,
            accessibilityValue: inviteStateText
        )

        addHorizontalInsets(hero(
            kicker: mode.kicker,
            title: heroTitle,
            body: heroBody
        ), top: Spacing.sm)
        addHorizontalInsets(inviteStatePlate(), top: Spacing.sm)

        switch mode {
        case .athleteCode:
            addAthleteCodeContent()
        case .coachEmail:
            addCoachEmailContent()
        }

        if let errorMessage {
            addSection(content: dataPlate([
                UIKitDesign.label(errorMessage, font: UIKitDesign.regular(15), color: UIColor(ColorTokens.zoneDanger), lines: 0)
            ], spacing: Spacing.sm))
        }
    }

    private var isScreenshotMode: Bool {
        ProcessInfo.processInfo.arguments.contains("SCREENSHOT_MODE")
    }

    private var primaryTitle: String {
        if isWorking {
            return mode == .athleteCode ? "Generating..." : "Sending..."
        }
        if didSend {
            return "Sent"
        }
        return mode.primaryTitle
    }

    private var primaryIdentifier: String {
        switch mode {
        case .athleteCode: "invite.generate"
        case .coachEmail: "invite.send"
        }
    }

    private var canSubmit: Bool {
        guard !isWorking, !didSend else { return false }
        switch mode {
        case .athleteCode:
            return currentAthlete() != nil
        case .coachEmail:
            return currentAthlete() != nil && isValidEmail(email)
        }
    }

    private var heroTitle: String {
        switch mode {
        case .athleteCode:
            return inviteCode == nil ? "Share a code" : inviteCode ?? "Invite code"
        case .coachEmail:
            return didSend ? "Invite sent" : "Add an athlete"
        }
    }

    private var heroBody: String {
        switch mode {
        case .athleteCode:
            return "A coach can enter this code to request a link with your athlete profile."
        case .coachEmail:
            return "Send a secure invite so an athlete can connect their training and recovery data."
        }
    }

    private var inviteStateText: String {
        if isWorking {
            return mode == .athleteCode ? "Generating invite code" : "Sending invite"
        }
        if didSend {
            return "Invite sent"
        }
        if errorMessage != nil {
            return "Invite needs attention"
        }
        switch mode {
        case .athleteCode:
            return inviteCode == nil ? "Ready to generate" : "Code ready"
        case .coachEmail:
            return isValidEmail(email) ? "Ready to send" : "Valid email required"
        }
    }

    private func inviteStatePlate() -> UIView {
        let label = UIKitDesign.label(inviteStateText, font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
        label.accessibilityIdentifier = "invite.state"
        return dataPlate([label], spacing: Spacing.sm)
    }

    private func addAthleteCodeContent() {
        var rows: [UIView] = []
        if let inviteCode {
            rows.append(codeRow(inviteCode))
            rows.append(divider())
            let copy = actionButton(title: "Copy Code", action: #selector(copyInviteCode))
            copy.accessibilityIdentifier = "invite.copyCode"
            rows.append(copy)
        } else {
            rows.append(UIKitDesign.label("Generate a short-lived code when your coach is ready to connect.", font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0))
        }
        addSection(title: "Code", content: dataPlate(rows, spacing: Spacing.sm))
    }

    private func codeRow(_ code: String) -> UIView {
        let stack = UIKitDesign.verticalStack(spacing: Spacing.xs)
        stack.isAccessibilityElement = true
        stack.accessibilityIdentifier = "invite.code"
        stack.accessibilityLabel = "Invite code \(code)"
        stack.addArrangedSubview(UIKitDesign.label("Invite code", font: UIKitDesign.regular(13), color: UIKitDesign.textSecondary))
        stack.addArrangedSubview(UIKitDesign.label(code, font: UIKitDesign.tabular(UIKitDesign.medium(32)), color: UIKitDesign.textPrimary))
        stack.addArrangedSubview(UIKitDesign.label("Expires in 48 hours.", font: UIKitDesign.regular(13), color: UIKitDesign.textSecondary))
        return stack
    }

    private func addCoachEmailContent() {
        addSection(title: "Athlete Email", content: dataPlate([
            emailField()
        ], spacing: Spacing.sm))

        let copy = didSend
            ? "The invite has been sent. The athlete can accept it from their email."
            : "Use the email tied to the athlete's Tuwa account when possible."
        addSection(content: dataPlate([
            UIKitDesign.label(copy, font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
        ], spacing: Spacing.sm))
    }

    private func emailField() -> UIView {
        let field = UITextField()
        field.text = email
        field.placeholder = "athlete@example.com"
        field.delegate = self
        field.keyboardType = .emailAddress
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.accessibilityIdentifier = "invite.email"
        field.font = UIKitDesign.regular(17)
        field.textColor = UIKitDesign.textPrimary
        field.tintColor = UIKitDesign.textPrimary
        field.backgroundColor = UIKitDesign.surface
        field.layer.borderWidth = UIKitDesign.hairline
        field.layer.borderColor = UIKitDesign.hairlineColor.cgColor
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: Spacing.xs, height: 1))
        field.leftViewMode = .always
        field.translatesAutoresizingMaskIntoConstraints = false
        field.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        field.addAction(UIAction { [weak self, weak field] _ in
            self?.email = field?.text ?? ""
            self?.errorMessage = nil
            self?.actionDock.updatePrimary(
                title: self?.primaryTitle ?? "Send Invite",
                isEnabled: self?.canSubmit == true,
                accessibilityIdentifier: self?.primaryIdentifier,
                accessibilityValue: self?.inviteStateText
            )
        }, for: .editingChanged)
        return field
    }

    private func currentAthlete() -> Athlete? {
        ((try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []).first
    }

    private func isValidEmail(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("@") && trimmed.contains(".")
    }

    @objc private func performPrimaryAction() {
        switch mode {
        case .athleteCode:
            generateCode()
        case .coachEmail:
            sendEmailInvite()
        }
    }

    private func generateCode() {
        guard !isWorking, let athlete = currentAthlete() else { return }
        isWorking = true
        errorMessage = nil
        rebuild()

        if isScreenshotMode {
            inviteCode = UIKitInviteService.makeLocalCode()
            isWorking = false
            Haptics.success()
            rebuild()
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                inviteCode = try await UIKitInviteService.generateInviteCode(for: athlete.id, container: container)
                Haptics.success()
            } catch {
                errorMessage = "Could not generate invite code. Check your connection and try again."
            }
            isWorking = false
            rebuild()
        }
    }

    private func sendEmailInvite() {
        guard !isWorking,
              let coach = currentAthlete(),
              isValidEmail(email) else { return }
        isWorking = true
        errorMessage = nil
        rebuild()

        if isScreenshotMode {
            didSend = true
            isWorking = false
            Haptics.success()
            rebuild()
            return
        }

        let targetEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        Task { [weak self] in
            guard let self else { return }
            do {
                try await UIKitInviteService.sendEmailInvite(to: targetEmail, from: coach.id, container: container)
                didSend = true
                Haptics.success()
            } catch {
                errorMessage = "Could not send invite. Check the email and try again."
            }
            isWorking = false
            rebuild()
        }
    }

    @objc private func copyInviteCode() {
        UIPasteboard.general.string = inviteCode
        Haptics.tap()
    }

    @objc private func cancelInvite() {
        Haptics.tap()
        dismiss(animated: true)
    }
}

private final class ProfileSettingsViewController: InstrumentScrollViewController, UITextFieldDelegate {
    private let container: AppContainer
    private let modelContext: ModelContext
    private let locale: Locale
    private var notificationsDenied = false

    private let notificationsEnabledKey = "notificationsEnabled"
    private let notificationDayKey = "notificationDay"
    private let notificationTimeKey = "notificationTime"

    init(container: AppContainer, modelContext: ModelContext, locale: Locale) {
        self.container = container
        self.modelContext = modelContext
        self.locale = locale
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Profile Settings"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Done",
            style: .done,
            target: self,
            action: #selector(close)
        )
        Task { [weak self] in
            guard let self else { return }
            let status = await container.notificationService.authorizationStatus()
            notificationsDenied = status == .denied
            if notificationsDenied && notificationsEnabled {
                notificationsEnabled = false
                container.notificationService.cancelWeeklySummary()
            }
            rebuild()
        }
    }

    override func rebuild() {
        clearContent()
        guard let athlete else {
            addHorizontalInsets(hero(kicker: "Profile", title: "No athlete", body: "Create or sync an athlete profile to edit settings."), top: Spacing.sm)
            return
        }

        addHorizontalInsets(hero(
            kicker: "Settings",
            title: athlete.displayName,
            body: "\(athlete.sportType.displayName) · \(athlete.weightUnit.displayName)"
        ), top: Spacing.sm)

        addSection(title: "Athlete", content: dataPlate([
            nameField(athlete),
            divider(),
            actionRow(title: "Sport", subtitle: athlete.sportType.displayName, action: #selector(chooseSport)),
            divider(),
            actionRow(title: "Training Frequency", subtitle: (athlete.trainingFrequency ?? .threeToFour).displayName, action: #selector(chooseFrequency)),
            divider(),
            actionRow(title: "Experience", subtitle: (athlete.experienceLevel ?? .intermediate).displayName, action: #selector(chooseExperience)),
            divider(),
            actionRow(title: "Weight Unit", subtitle: athlete.weightUnit.displayName, action: #selector(chooseWeightUnit))
        ], spacing: Spacing.sm))

        var notificationRows: [UIView] = [
            switchRow(title: "Weekly Summary", subtitle: notificationsDenied ? "Notifications are blocked in system settings" : nil),
            divider(),
            actionRow(title: "Day", subtitle: weekdayName(notificationDay), action: #selector(chooseNotificationDay)),
            divider(),
            actionRow(title: "Time", subtitle: formattedTime(notificationTime), action: #selector(chooseNotificationTime))
        ]
        if notificationsDenied {
            notificationRows.append(divider())
            notificationRows.append(UIKitDesign.label("Open iOS Settings to allow notifications before enabling the weekly summary.", font: UIKitDesign.regular(13), color: UIKitDesign.textSecondary, lines: 0))
        }
        addSection(title: "Notifications", content: dataPlate(notificationRows, spacing: Spacing.sm))

#if DEBUG
        addSection(title: "Measurement", content: dataPlate([
            actionRow(title: "Verdict Measurement", subtitle: "Review internal recommendation signals", action: #selector(openMeasurement))
        ], spacing: Spacing.sm))
#endif
    }

    private var athlete: Athlete? {
        ((try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []).first
    }

    private var notificationsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: notificationsEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: notificationsEnabledKey) }
    }

    private var notificationDay: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: notificationDayKey)
            return value == 0 ? 1 : value
        }
        set { UserDefaults.standard.set(newValue, forKey: notificationDayKey) }
    }

    private var notificationTime: String {
        get { UserDefaults.standard.string(forKey: notificationTimeKey) ?? "19:00" }
        set { UserDefaults.standard.set(newValue, forKey: notificationTimeKey) }
    }

    private func nameField(_ athlete: Athlete) -> UIView {
        let stack = UIKitDesign.verticalStack(spacing: Spacing.xs)
        stack.addArrangedSubview(UIKitDesign.label("Display Name", font: UIKitDesign.regular(13), color: UIKitDesign.textSecondary))
        let field = UITextField()
        field.text = athlete.displayName
        field.placeholder = "Name"
        field.delegate = self
        field.font = UIKitDesign.regular(17)
        field.textColor = UIKitDesign.textPrimary
        field.tintColor = UIKitDesign.textPrimary
        field.backgroundColor = UIKitDesign.surface
        field.layer.borderWidth = UIKitDesign.hairline
        field.layer.borderColor = UIKitDesign.hairlineColor.cgColor
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: Spacing.xs, height: 1))
        field.leftViewMode = .always
        field.translatesAutoresizingMaskIntoConstraints = false
        field.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        field.addAction(UIAction { [weak self, weak field, weak athlete] _ in
            guard let self, let athlete else { return }
            athlete.displayName = field?.text ?? ""
            self.saveAthlete(athlete)
        }, for: .editingChanged)
        stack.addArrangedSubview(field)
        return stack
    }

    private func switchRow(title: String, subtitle: String?) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = Spacing.sm
        row.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIKitDesign.verticalStack(spacing: Spacing.baselinePair)
        textStack.addArrangedSubview(UIKitDesign.label(title, font: UIKitDesign.regular(17), color: UIKitDesign.textPrimary))
        if let subtitle {
            textStack.addArrangedSubview(UIKitDesign.label(subtitle, font: UIKitDesign.regular(13), color: UIKitDesign.textSecondary, lines: 0))
        }

        let toggle = UISwitch()
        toggle.isOn = notificationsEnabled
        toggle.onTintColor = UIKitDesign.textSecondary
        toggle.addAction(UIAction { [weak self, weak toggle] _ in
            guard let self, let toggle else { return }
            self.setNotificationsEnabled(toggle.isOn)
        }, for: .valueChanged)

        row.addArrangedSubview(textStack)
        row.addArrangedSubview(toggle)
        return row
    }

    private func actionRow(title: String, subtitle: String?, action: Selector) -> UIView {
        let button = UIButton(type: .custom)
        button.addTarget(self, action: action, for: .touchUpInside)
        let row = disclosureRow(title: title, subtitle: subtitle)
        row.isUserInteractionEnabled = false
        button.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            row.topAnchor.constraint(equalTo: button.topAnchor),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return button
    }

    private func presentChoice<T>(
        title: String,
        options: [T],
        display: @escaping (T) -> String,
        isSelected: @escaping (T) -> Bool = { _ in false },
        onSelect: @escaping (T) -> Void
    ) {
        let controller = InstrumentChoiceListViewController(
            title: title,
            stateText: { "Select \(title.lowercased())." },
            options: { [weak self] in
                options.map { option in
                    InstrumentChoiceOption(
                        title: display(option),
                        isSelected: isSelected(option)
                    ) {
                        guard let self else { return }
                        onSelect(option)
                        self.rebuild()
                    }
                }
            }
        )
        showInstrumentDetail(controller)
    }

    @objc private func chooseSport() {
        guard let athlete else { return }
        presentChoice(title: "Sport", options: SportType.allCases, display: \.displayName) { [weak self, weak athlete] sport in
            guard let self, let athlete else { return }
            athlete.sportType = sport
            self.saveAthlete(athlete)
        }
    }

    @objc private func chooseFrequency() {
        guard let athlete else { return }
        presentChoice(title: "Training Frequency", options: TrainingFrequency.allCases, display: \.displayName) { [weak self, weak athlete] frequency in
            guard let self, let athlete else { return }
            athlete.trainingFrequency = frequency
            self.saveAthlete(athlete)
        }
    }

    @objc private func chooseExperience() {
        guard let athlete else { return }
        presentChoice(title: "Experience", options: ExperienceLevel.allCases, display: \.displayName) { [weak self, weak athlete] level in
            guard let self, let athlete else { return }
            athlete.experienceLevel = level
            self.saveAthlete(athlete)
        }
    }

    @objc private func chooseWeightUnit() {
        guard let athlete else { return }
        presentChoice(title: "Weight Unit", options: WeightUnit.allCases, display: \.displayName) { [weak self, weak athlete] unit in
            guard let self, let athlete else { return }
            athlete.weightUnit = unit
            self.saveAthlete(athlete)
        }
    }

    @objc private func chooseNotificationDay() {
        presentChoice(title: "Summary Day", options: Array(1...7), display: weekdayName) { [weak self] day in
            guard let self else { return }
            self.notificationDay = day
            if self.notificationsEnabled { self.scheduleNotification() }
        }
    }

    @objc private func chooseNotificationTime() {
        let options = stride(from: 6, through: 22, by: 1).map { String(format: "%02d:00", $0) }
        presentChoice(title: "Summary Time", options: options, display: formattedTime) { [weak self] time in
            guard let self else { return }
            self.notificationTime = time
            if self.notificationsEnabled { self.scheduleNotification() }
        }
    }

    @objc private func openMeasurement() {
        Haptics.tap()
        let controller = MeasurementViewController(
            modelContext: modelContext,
            locale: locale
        )
        present(InstrumentNavigationController(rootViewController: controller), animated: true)
    }

    @objc private func close() {
        dismiss(animated: true)
    }

    private func setNotificationsEnabled(_ enabled: Bool) {
        Haptics.tap()
        if enabled {
            Task { [weak self] in
                guard let self else { return }
                let status = await container.notificationService.authorizationStatus()
                if status == .denied {
                    notificationsDenied = true
                    notificationsEnabled = false
                    rebuild()
                    return
                }
                if status == .notDetermined {
                    let granted = await container.notificationService.requestAuthorization()
                    guard granted else {
                        notificationsEnabled = false
                        rebuild()
                        return
                    }
                }
                notificationsEnabled = true
                notificationsDenied = false
                scheduleNotification()
                rebuild()
            }
        } else {
            notificationsEnabled = false
            container.notificationService.cancelWeeklySummary()
            rebuild()
        }
    }

    private func weekdayName(_ weekday: Int) -> String {
        var calendar = Calendar.current
        calendar.locale = locale
        return calendar.weekdaySymbols[max(0, min(6, weekday - 1))]
    }

    private func formattedTime(_ time: String) -> String {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        let hour = parts.first ?? 19
        let minute = parts.count > 1 ? parts[1] : 0
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        var calendar = Calendar.current
        calendar.locale = locale
        let date = calendar.date(from: components) ?? .now
        return date.formatted(.dateTime.hour().minute().locale(locale))
    }

    private func scheduleNotification() {
        let parts = notificationTime.split(separator: ":").compactMap { Int($0) }
        container.notificationService.scheduleWeeklySummary(
            weekday: notificationDay,
            hour: parts.first ?? 19,
            minute: parts.count > 1 ? parts[1] : 0,
            sessionCount: 0,
            streak: 0,
            prCount: 0,
            volumeDelta: 0
        )
    }

    private func saveAthlete(_ athlete: Athlete) {
        athlete.updatedAt = .now
        try? modelContext.save()
        Task { await container.syncService.pushAthlete(athlete) }
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

private final class MeasurementViewController: InstrumentScrollViewController {
    private let modelContext: ModelContext
    private let locale: Locale

    init(modelContext: ModelContext, locale: Locale) {
        self.modelContext = modelContext
        self.locale = locale
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = localized("measurement.navTitle")
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(close))
    }

    override func rebuild() {
        clearContent()
        let metrics = loadMetrics()
        let dogfood = loadDogfoodSummary()
        addSection(title: localized("measurement.title"), content: dataPlate([
            metricRow(
                title: localized("measurement.greenLight.label"),
                value: percentText(metrics.greenLightRate),
                detail: metrics.greenLightRate == nil
                    ? nil
                    : String(format: localized("measurement.greenLight.context"), metrics.differingDays)
            ),
            divider(),
            metricRow(
                title: localized("measurement.activation.label"),
                value: percentText(metrics.activationRate),
                detail: metrics.activationRate == nil
                    ? nil
                    : String(format: localized("measurement.activation.context"), metrics.totalEvents)
            ),
            divider(),
            metricRow(title: localized("measurement.retention.day7"), value: retentionText(metrics.day7Retention), detail: nil),
            divider(),
            metricRow(title: localized("measurement.retention.day30"), value: retentionText(metrics.day30Retention), detail: nil)
        ], spacing: Spacing.sm))

        addSection(content: dataPlate([
            UIKitDesign.label(localized("measurement.caption"), font: UIKitDesign.regular(13), color: UIKitDesign.textSecondary, lines: 0)
        ]))

        addSection(title: localized("measurement.dogfood.title"), content: dataPlate([
            metricRow(
                title: localized("measurement.dogfood.differingDays"),
                value: "\(dogfood.differingDays)",
                detail: nil
            ),
            divider(),
            metricRow(
                title: localized("measurement.dogfood.followed.label"),
                value: percentText(dogfood.followedRate),
                detail: dogfood.followedRate == nil
                    ? nil
                    : String(
                        format: localized("measurement.dogfood.followed.context"),
                        dogfood.followedDays,
                        dogfood.differingDays
                    )
            ),
            divider(),
            metricRow(
                title: localized("measurement.dogfood.feltRight.label"),
                value: percentText(dogfood.feltRightRate),
                detail: (dogfood.ratedDays + dogfood.missedDays) == 0
                    ? nil
                    : String(
                        format: localized("measurement.dogfood.feltRight.context"),
                        dogfood.ratedDays,
                        dogfood.missedDays
                    )
            ),
            divider(),
            metricRow(
                title: localized("measurement.dogfood.proximity.label"),
                value: "\(dogfood.proximityMicrodoseDays)",
                detail: dogfood.proximityMicrodoseDays == 0
                    ? nil
                    : String(
                        format: localized("measurement.dogfood.proximity.context"),
                        dogfood.proximityMicrodoseFollowedDays
                    )
            )
        ], spacing: Spacing.sm))
    }

    private func loadMetrics() -> GreenLightEngine.GreenLightMetrics {
        let athletes = (try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []
        let repository = VerdictEventRepository(modelContext: modelContext)
        let events = repository.fetchAll(athlete: athletes.first)
        return GreenLightEngine.compute(events: events, asOf: .now, calendar: .current)
    }

    private func loadDogfoodSummary() -> FeltRightPromptEngine.DogfoodSummary {
        let athletes = (try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []
        let repository = VerdictEventRepository(modelContext: modelContext)
        let events = repository.fetchAll(athlete: athletes.first)
        return FeltRightPromptEngine.summary(events: events, asOf: .now, calendar: .current)
    }

    private func metricRow(title: String, value: String, detail: String?) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .firstBaseline
        row.spacing = Spacing.sm
        row.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIKitDesign.verticalStack(spacing: Spacing.baselinePair)
        textStack.addArrangedSubview(UIKitDesign.label(title, font: UIKitDesign.regular(17), color: UIKitDesign.textPrimary))
        if let detail {
            textStack.addArrangedSubview(UIKitDesign.label(detail, font: UIKitDesign.regular(13), color: UIKitDesign.textSecondary, lines: 0))
        }
        row.addArrangedSubview(textStack)

        let valueLabel = UIKitDesign.label(value, font: UIKitDesign.tabular(UIKitDesign.regular(17)), color: UIKitDesign.textPrimary)
        valueLabel.textAlignment = .right
        row.addArrangedSubview(valueLabel)
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        return row
    }

    private func percentText(_ rate: Double?) -> String {
        guard let rate else { return localized("measurement.learning") }
        return "\(Int((rate * 100).rounded()))%"
    }

    private func retentionText(_ retained: Bool?) -> String {
        switch retained {
        case .some(true): localized("measurement.retained")
        case .some(false): localized("measurement.lapsed")
        case .none: localized("measurement.tooEarly")
        }
    }

    private func localized(_ key: String.LocalizationValue) -> String {
        UIKitStrings.localized(key, locale: locale)
    }

    @objc private func close() {
        dismiss(animated: true)
    }
}

private final class TrainingProfileEditorViewController: InstrumentScrollViewController, UITextFieldDelegate {
    private let container: AppContainer
    private let modelContext: ModelContext
    private var existingProfile: TrainingProfile?
    private let actionDock = UIKitBottomActionDock(primaryTitle: "Save Profile")

    private var sessionsPerWeek: Int?
    private var avgDurationMinutes: Int?
    private var typicalSRPE: Int?
    private var weeksAtLevel: Int?
    private var trainingAgeYears: Int?
    private var scheduleType: String?
    private var selectedMovementTypes: Set<SportType> = []
    private var selectedBodyRegions: Set<BodyRegion> = []
    private var injuryNotes = ""

    init(container: AppContainer, modelContext: ModelContext) {
        self.container = container
        self.modelContext = modelContext
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Training Profile"
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(close))
        navigationItem.leftBarButtonItem?.accessibilityIdentifier = "trainingProfile.cancel"
        actionDock.primaryButton.addTarget(self, action: #selector(save), for: .touchUpInside)
        installBottomActionDock(actionDock)
        loadExistingProfile()
    }

    override func rebuild() {
        clearContent()
        actionDock.updatePrimary(
            title: "Save Profile",
            isEnabled: isValid,
            accessibilityIdentifier: "trainingProfile.save",
            accessibilityValue: trainingProfileStateText
        )
        addHorizontalInsets(hero(
            kicker: "Training Profile",
            title: isValid ? "Ready to save" : "Baseline inputs",
            body: "These answers seed workload estimates until enough sessions are logged."
        ), top: Spacing.sm)
        addHorizontalInsets(trainingProfileStatePlate(), top: Spacing.sm)

        addSection(title: "Required", content: dataPlate([
            choiceRow(
                title: "Sessions per week",
                value: sessionsPerWeek.map(String.init) ?? "Select",
                action: #selector(chooseSessionsPerWeek),
                accessibilityIdentifier: "trainingProfile.sessionsPerWeek"
            ),
            divider(),
            choiceRow(
                title: "Average duration",
                value: avgDurationMinutes.map { "\($0) min" } ?? "Select",
                action: #selector(chooseAverageDuration),
                accessibilityIdentifier: "trainingProfile.averageDuration"
            ),
            divider(),
            choiceRow(
                title: "Typical effort",
                value: typicalSRPE.map(srpeLabel) ?? "Select",
                action: #selector(chooseTypicalEffort),
                accessibilityIdentifier: "trainingProfile.typicalEffort"
            ),
            divider(),
            choiceRow(
                title: "Weeks at current level",
                value: weeksAtLevel.map { $0 == 1 ? "1 week" : "\($0) weeks" } ?? "Select",
                action: #selector(chooseWeeksAtLevel),
                accessibilityIdentifier: "trainingProfile.weeksAtLevel"
            )
        ], spacing: Spacing.sm))

        addSection(title: "Optional", content: dataPlate([
            choiceRow(
                title: "Training age",
                value: trainingAgeYears.map { $0 == 1 ? "1 year" : "\($0) years" } ?? "--",
                action: #selector(chooseTrainingAge),
                accessibilityIdentifier: "trainingProfile.trainingAge"
            ),
            divider(),
            choiceRow(
                title: "Schedule type",
                value: scheduleType ?? "--",
                action: #selector(chooseScheduleType),
                accessibilityIdentifier: "trainingProfile.scheduleType"
            ),
            divider(),
            choiceRow(
                title: "Movement types",
                value: selectedMovementTypes.isEmpty ? "--" : "\(selectedMovementTypes.count) selected",
                action: #selector(chooseMovementTypes),
                accessibilityIdentifier: "trainingProfile.movementTypes"
            ),
            divider(),
            choiceRow(
                title: "Injury history",
                value: selectedBodyRegions.isEmpty ? "--" : "\(selectedBodyRegions.count) areas",
                action: #selector(chooseBodyRegions),
                accessibilityIdentifier: "trainingProfile.injuryHistory"
            ),
            divider(),
            notesField()
        ], spacing: Spacing.sm))
    }

    private var athlete: Athlete? {
        ((try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []).first
    }

    private var isValid: Bool {
        sessionsPerWeek != nil && avgDurationMinutes != nil && typicalSRPE != nil && weeksAtLevel != nil
    }

    private var trainingProfileStateText: String {
        if isValid {
            return existingProfile == nil ? "Ready to save new profile" : "Ready to update profile"
        }
        let missing = [
            sessionsPerWeek == nil ? "sessions per week" : nil,
            avgDurationMinutes == nil ? "average duration" : nil,
            typicalSRPE == nil ? "typical effort" : nil,
            weeksAtLevel == nil ? "weeks at current level" : nil
        ].compactMap { $0 }
        return "Required: \(missing.joined(separator: ", "))"
    }

    private func trainingProfileStatePlate() -> UIView {
        let label = UIKitDesign.label(trainingProfileStateText, font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
        label.accessibilityIdentifier = "trainingProfile.state"
        return dataPlate([label], spacing: Spacing.sm)
    }

    private func loadExistingProfile() {
        guard let athlete else { return }
        existingProfile = try? TrainingProfileRepository(modelContext: modelContext).fetchProfile(athleteId: athlete.id)
        guard let profile = existingProfile else { return }
        sessionsPerWeek = profile.sessionsPerWeek
        avgDurationMinutes = profile.avgDurationMinutes
        typicalSRPE = Int(profile.typicalSRPE)
        weeksAtLevel = profile.weeksAtLevel
        trainingAgeYears = profile.trainingAgeYears
        scheduleType = profile.periodizationPreference
        if let types = profile.movementTypes {
            selectedMovementTypes = Set(types.compactMap { SportType(rawValue: $0) })
        }
        if let data = profile.injuryHistory,
           let injuries = try? JSONDecoder().decode([InjuryEntry].self, from: data) {
            selectedBodyRegions = Set(injuries.map(\.bodyRegion))
            injuryNotes = injuries.first?.notes ?? ""
        }
    }

    private func choiceRow(
        title: String,
        value: String,
        action: Selector,
        accessibilityIdentifier: String
    ) -> UIView {
        let button = UIButton(type: .custom)
        button.accessibilityIdentifier = accessibilityIdentifier
        button.accessibilityLabel = "\(title), \(value)"
        button.addTarget(self, action: action, for: .touchUpInside)
        let row = disclosureRow(title: title, subtitle: nil, trailing: value)
        row.isUserInteractionEnabled = false
        button.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            row.topAnchor.constraint(equalTo: button.topAnchor),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return button
    }

    private func notesField() -> UIView {
        let stack = UIKitDesign.verticalStack(spacing: Spacing.xs)
        stack.addArrangedSubview(UIKitDesign.label("Injury notes", font: UIKitDesign.regular(13), color: UIKitDesign.textSecondary))
        let field = UITextField()
        field.text = injuryNotes
        field.placeholder = "Optional"
        field.delegate = self
        field.accessibilityIdentifier = "trainingProfile.injuryNotes"
        field.font = UIKitDesign.regular(17)
        field.textColor = UIKitDesign.textPrimary
        field.tintColor = UIKitDesign.textPrimary
        field.backgroundColor = UIKitDesign.surface
        field.layer.borderWidth = UIKitDesign.hairline
        field.layer.borderColor = UIKitDesign.hairlineColor.cgColor
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: Spacing.xs, height: 1))
        field.leftViewMode = .always
        field.translatesAutoresizingMaskIntoConstraints = false
        field.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        field.addAction(UIAction { [weak self, weak field] _ in
            self?.injuryNotes = field?.text ?? ""
        }, for: .editingChanged)
        stack.addArrangedSubview(field)
        return stack
    }

    private func presentChoice<T>(
        title: String,
        options: [T],
        display: @escaping (T) -> String,
        isSelected: @escaping (T) -> Bool = { _ in false },
        onSelect: @escaping (T) -> Void
    ) {
        let controller = InstrumentChoiceListViewController(
            title: title,
            stateText: { "Select \(title.lowercased())." },
            options: { [weak self] in
                options.map { option in
                    InstrumentChoiceOption(
                        title: display(option),
                        isSelected: isSelected(option)
                    ) {
                        guard let self else { return }
                        onSelect(option)
                        self.rebuild()
                    }
                }
            }
        )
        showInstrumentDetail(controller)
    }

    private func presentToggleChoice<T: Hashable>(
        title: String,
        options: [T],
        selected: @escaping () -> Set<T>,
        display: @escaping (T) -> String,
        toggle: @escaping (T) -> Void
    ) {
        let controller = InstrumentChoiceListViewController(
            title: title,
            stateText: { "Tap rows to toggle selection." },
            options: { [weak self] in
                options.map { option in
                    InstrumentChoiceOption(
                        title: display(option),
                        isSelected: selected().contains(option)
                    ) {
                        guard let self else { return }
                        toggle(option)
                        self.rebuild()
                    }
                }
            },
            dismissesOnSelection: false,
            doneTitle: "Done"
        )
        showInstrumentDetail(controller)
    }

    @objc private func chooseSessionsPerWeek() {
        presentChoice(
            title: "Sessions per week",
            options: Array(1...14),
            display: String.init,
            isSelected: { [weak self] in self?.sessionsPerWeek == $0 }
        ) { [weak self] in self?.sessionsPerWeek = $0 }
    }

    @objc private func chooseAverageDuration() {
        presentChoice(
            title: "Average duration",
            options: [15, 30, 45, 60, 75, 90, 120, 150, 180],
            display: { (value: Int) in "\(value) min" },
            isSelected: { [weak self] in self?.avgDurationMinutes == $0 }
        ) { [weak self] in self?.avgDurationMinutes = $0 }
    }

    @objc private func chooseTypicalEffort() {
        presentChoice(
            title: "Typical effort",
            options: Array(1...10),
            display: srpeLabel,
            isSelected: { [weak self] in self?.typicalSRPE == $0 }
        ) { [weak self] in self?.typicalSRPE = $0 }
    }

    @objc private func chooseWeeksAtLevel() {
        presentChoice(
            title: "Weeks at current level",
            options: [1, 2, 3, 4, 6, 8, 12, 16, 24, 52],
            display: { (value: Int) in value == 1 ? "1 week" : "\(value) weeks" },
            isSelected: { [weak self] in self?.weeksAtLevel == $0 }
        ) { [weak self] in self?.weeksAtLevel = $0 }
    }

    @objc private func chooseTrainingAge() {
        presentChoice(
            title: "Training age",
            options: Array(0...30),
            display: { (value: Int) in value == 1 ? "1 year" : "\(value) years" },
            isSelected: { [weak self] in self?.trainingAgeYears == $0 }
        ) { [weak self] in self?.trainingAgeYears = $0 }
    }

    @objc private func chooseScheduleType() {
        presentChoice(
            title: "Schedule type",
            options: ["Steady", "Periodized"],
            display: { $0 },
            isSelected: { [weak self] in self?.scheduleType == $0 }
        ) { [weak self] in self?.scheduleType = $0 }
    }

    @objc private func chooseMovementTypes() {
        presentToggleChoice(title: "Movement types", options: SportType.allCases, selected: { [weak self] in self?.selectedMovementTypes ?? [] }, display: \.displayName) { [weak self] sport in
            guard let self else { return }
            if selectedMovementTypes.contains(sport) {
                selectedMovementTypes.remove(sport)
            } else {
                selectedMovementTypes.insert(sport)
            }
        }
    }

    @objc private func chooseBodyRegions() {
        presentToggleChoice(title: "Injury history", options: BodyRegion.allCases, selected: { [weak self] in self?.selectedBodyRegions ?? [] }, display: \.displayName) { [weak self] region in
            guard let self else { return }
            if selectedBodyRegions.contains(region) {
                selectedBodyRegions.remove(region)
            } else {
                selectedBodyRegions.insert(region)
            }
        }
    }

    @objc private func save() {
        guard let athlete,
              let sessions = sessionsPerWeek,
              let duration = avgDurationMinutes,
              let srpe = typicalSRPE,
              let weeks = weeksAtLevel else { return }

        let result = ColdStartEngine.computeSeed(input: .init(
            sessionsPerWeek: sessions,
            avgDurationMinutes: duration,
            typicalSRPE: Double(srpe),
            weeksAtLevel: weeks
        ))
        let injuryData: Data? = {
            guard !selectedBodyRegions.isEmpty else { return nil }
            return try? JSONEncoder().encode(selectedBodyRegions.map {
                InjuryEntry(bodyRegion: $0, notes: injuryNotes.isEmpty ? nil : injuryNotes, isActive: true)
            })
        }()
        let movementTypes = selectedMovementTypes.isEmpty ? nil : selectedMovementTypes.map(\.rawValue)
        let repo = TrainingProfileRepository(modelContext: modelContext)

        do {
            if let profile = existingProfile {
                profile.sessionsPerWeek = sessions
                profile.avgDurationMinutes = duration
                profile.typicalSRPE = Double(srpe)
                profile.weeksAtLevel = weeks
                profile.trainingAgeYears = trainingAgeYears
                profile.periodizationPreference = scheduleType
                profile.movementTypes = movementTypes
                profile.injuryHistory = injuryData
                profile.seededATL = result.seededATL
                profile.seededCTL = result.seededCTL
                try repo.updateProfile(profile)
            } else {
                let profile = TrainingProfile(
                    athleteId: athlete.id,
                    sessionsPerWeek: sessions,
                    avgDurationMinutes: duration,
                    typicalSRPE: Double(srpe),
                    weeksAtLevel: weeks,
                    trainingAgeYears: trainingAgeYears,
                    periodizationPreference: scheduleType,
                    movementTypes: movementTypes,
                    injuryHistory: injuryData,
                    seededATL: result.seededATL,
                    seededCTL: result.seededCTL
                )
                try repo.saveProfile(profile)
            }
            Task { await container.syncService.pushTrainingProfile(context: modelContext, athleteId: athlete.id) }
            Haptics.success()
            dismiss(animated: true)
        } catch {
            showError("Could not save your training profile. Please try again.")
        }
    }

    @objc private func close() {
        dismiss(animated: true)
    }

    private func srpeLabel(_ value: Int) -> String {
        switch value {
        case 1: "1 -- Rest"
        case 2: "2 -- Very Light"
        case 3: "3 -- Light"
        case 4: "4 -- Moderate-"
        case 5: "5 -- Moderate"
        case 6: "6 -- Moderate+"
        case 7: "7 -- Hard"
        case 8: "8 -- Very Hard"
        case 9: "9 -- Near Max"
        case 10: "10 -- Maximal"
        default: "\(value)"
        }
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

private final class HealthPermissionsViewController: InstrumentScrollViewController {
    private let container: AppContainer
    private var isAuthorizing = false
    private var authError: String?
    private let actionDock = UIKitBottomActionDock(primaryTitle: "Connect Apple Health")

    private let dataTypes: [(id: String, title: String)] = [
        ("hrv", "Heart Rate Variability"),
        ("rhr", "Resting Heart Rate"),
        ("sleep", "Sleep Analysis"),
        ("workoutHeartRate", "Workout Heart Rate"),
        ("activeEnergy", "Active Energy"),
        ("bodyTemperature", "Body Temperature"),
        ("vo2Max", "VO2 Max"),
        ("workouts", "Workouts")
    ]

    init(container: AppContainer) {
        self.container = container
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Apple Health"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(close)
        )
        navigationItem.leftBarButtonItem?.accessibilityIdentifier = "healthPermissions.cancel"
        actionDock.primaryButton.addTarget(self, action: #selector(performPrimaryAction), for: .touchUpInside)
        installBottomActionDock(actionDock)
    }

    override func rebuild() {
        clearContent()
        let state = container.healthKitService.connectionState
        actionDock.updatePrimary(
            title: healthActionTitle(state),
            isEnabled: !isAuthorizing,
            accessibilityIdentifier: healthActionIdentifier(state),
            accessibilityValue: healthStateText(state)
        )
        addHorizontalInsets(hero(
            kicker: "Connections",
            title: healthStateTitle(state),
            body: "Tuwa reads recovery and training signals. Raw HealthKit samples stay on device."
        ), top: Spacing.sm)
        addHorizontalInsets(healthStatePlate(state), top: Spacing.sm)

        var rows: [UIView] = []
        for (index, item) in dataTypes.enumerated() {
            rows.append(dataTypeRow(item))
            if index < dataTypes.count - 1 { rows.append(divider()) }
        }
        addSection(title: "Data We Read", content: dataPlate(rows, spacing: Spacing.sm))

        if let authError {
            addSection(content: dataPlate([
                UIKitDesign.label(authError, font: UIKitDesign.regular(15), color: UIColor(ColorTokens.zoneDanger), lines: 0)
            ]))
        }
    }

    private func healthStateTitle(_ state: HealthKitConnectionState) -> String {
        switch state {
        case .notRequested: "Not connected"
        case .requestedNoData: "Connected, no recent data"
        case .connected: "Connected"
        }
    }

    private func healthStateText(_ state: HealthKitConnectionState) -> String {
        if isAuthorizing {
            return "Connecting Apple Health"
        }
        if authError != nil {
            return "Permission needs attention"
        }
        return switch state {
        case .notRequested: "Not connected"
        case .requestedNoData: "Connected, waiting for recent data"
        case .connected: "Connected"
        }
    }

    private func healthStatePlate(_ state: HealthKitConnectionState) -> UIView {
        let label = UIKitDesign.label(
            healthStateText(state),
            font: UIKitDesign.regular(15),
            color: UIKitDesign.textSecondary,
            lines: 0
        )
        label.accessibilityIdentifier = "healthPermissions.state"
        return dataPlate([label], spacing: Spacing.sm)
    }

    private func healthActionTitle(_ state: HealthKitConnectionState) -> String {
        if isAuthorizing {
            return "Connecting..."
        }
        return switch state {
        case .notRequested:
            "Connect Apple Health"
        case .requestedNoData, .connected:
            "Manage in Health"
        }
    }

    private func healthActionIdentifier(_ state: HealthKitConnectionState) -> String {
        switch state {
        case .notRequested:
            return "healthPermissions.connect"
        case .requestedNoData, .connected:
            return "healthPermissions.openSettings"
        }
    }

    private func dataTypeRow(_ item: (id: String, title: String)) -> UIView {
        let row = disclosureRow(title: item.title, subtitle: nil, trailing: "Read only")
        row.isAccessibilityElement = true
        row.accessibilityIdentifier = "healthPermissions.data.\(item.id)"
        row.accessibilityLabel = "\(item.title), read only"
        return row
    }

    @objc private func performPrimaryAction() {
        switch container.healthKitService.connectionState {
        case .notRequested:
            requestAuthorization()
        case .requestedNoData, .connected:
            openHealthSettings()
        }
    }

    @objc private func requestAuthorization() {
        guard !isAuthorizing else { return }
        isAuthorizing = true
        rebuild()
        Task { [weak self] in
            guard let self else { return }
            do {
                try await container.healthKitService.requestAuthorization()
                await container.healthKitService.runMigrationProbe()
                authError = nil
            } catch {
                authError = error.localizedDescription
            }
            isAuthorizing = false
            rebuild()
        }
    }

    @objc private func openHealthSettings() {
        if let url = URL(string: "x-apple-health://"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let settings = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settings)
        }
    }

    @objc private func close() {
        dismiss(animated: true)
    }
}

private final class SyncStatusViewController: InstrumentScrollViewController {
    private let container: AppContainer
    private let modelContext: ModelContext
    private let store = SyncTimestampStore.shared
    private var isManualSyncing = false
    private let actionDock = UIKitBottomActionDock(primaryTitle: "Sync Now")
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    init(container: AppContainer, modelContext: ModelContext) {
        self.container = container
        self.modelContext = modelContext
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Sync Status"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(close)
        )
        navigationItem.leftBarButtonItem?.accessibilityIdentifier = "syncStatus.cancel"
        actionDock.primaryButton.addTarget(self, action: #selector(syncNow), for: .touchUpInside)
        installBottomActionDock(actionDock)
    }

    override func rebuild() {
        clearContent()
        actionDock.updatePrimary(
            title: isSyncing ? "Syncing..." : "Sync Now",
            isEnabled: !isSyncing,
            accessibilityIdentifier: "syncStatus.syncNow",
            accessibilityValue: syncStateText
        )
        addHorizontalInsets(hero(
            kicker: "Data Sync",
            title: store.hasAnyFailure ? "Needs attention" : "All synced",
            body: isSyncing ? "Sync in progress." : "Review the last successful sync for each data type."
        ), top: Spacing.sm)
        addHorizontalInsets(syncStatePlate(), top: Spacing.sm)

        var rows: [UIView] = []
        for (index, entity) in SyncEntity.allCases.enumerated() {
            rows.append(entityRow(entity))
            if index < SyncEntity.allCases.count - 1 { rows.append(divider()) }
        }
        addSection(title: "Entities", content: dataPlate(rows, spacing: Spacing.sm))
    }

    private var isSyncing: Bool {
        store.isSyncing || isManualSyncing
    }

    private var syncStateText: String {
        if isSyncing {
            return "Sync in progress"
        }
        if store.hasAnyFailure {
            return "Needs attention"
        }
        if store.shouldSync {
            return "Ready to sync"
        }
        return "All synced"
    }

    private func syncStatePlate() -> UIView {
        let label = UIKitDesign.label(syncStateText, font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
        label.accessibilityIdentifier = "syncStatus.state"
        return dataPlate([label], spacing: Spacing.sm)
    }

    private func entityRow(_ entity: SyncEntity) -> UIView {
        let failed = store.lastErrors[entity]
        let lastSync = store.lastSuccess(for: entity)
        let detail: String
        if let failed {
            detail = "Failed \(Self.relativeFormatter.localizedString(for: failed.timestamp, relativeTo: .now)): \(failed.message)"
        } else if let lastSync {
            detail = Self.relativeFormatter.localizedString(for: lastSync, relativeTo: .now)
        } else {
            detail = "Never synced"
        }
        let row = disclosureRow(title: entity.displayName, subtitle: detail, trailing: failed == nil ? "OK" : "Issue")
        row.isAccessibilityElement = true
        row.accessibilityIdentifier = "syncStatus.entity.\(entity.rawValue)"
        row.accessibilityLabel = "\(entity.displayName), \(detail), \(failed == nil ? "OK" : "Issue")"
        return row
    }

    @objc private func syncNow() {
        guard !isSyncing else { return }
        isManualSyncing = true
        rebuild()
        Task { [weak self] in
            guard let self else { return }
            await container.syncService.pushAll(context: modelContext)
            await container.syncService.pullAll(context: modelContext)
            isManualSyncing = false
            rebuild()
        }
    }

    @objc private func close() {
        dismiss(animated: true)
    }
}

private final class LanguagePickerViewController: InstrumentScrollViewController {
    private let container: AppContainer
    private let actionDock = UIKitBottomActionDock(primaryTitle: "Done")

    init(container: AppContainer) {
        self.container = container
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Language"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(close)
        )
        navigationItem.leftBarButtonItem?.accessibilityIdentifier = "language.cancel"
        actionDock.primaryButton.addTarget(self, action: #selector(close), for: .touchUpInside)
        installBottomActionDock(actionDock)
    }

    override func rebuild() {
        clearContent()
        actionDock.updatePrimary(
            title: "Done",
            accessibilityIdentifier: "language.done",
            accessibilityValue: languageStateText
        )
        addHorizontalInsets(hero(
            kicker: "Product",
            title: "Language",
            body: "Choose the app language. The interface updates immediately."
        ), top: Spacing.sm)
        addHorizontalInsets(languageStatePlate(), top: Spacing.sm)

        var rows: [UIView] = []
        let locales = container.localeManager.supportedLocales
        for (index, locale) in locales.enumerated() {
            rows.append(localeRow(locale))
            if index < locales.count - 1 { rows.append(divider()) }
        }
        addSection(content: dataPlate(rows, spacing: Spacing.sm))
        addSection(content: dataPlate([
            UIKitDesign.label("Language changes render immediately.", font: UIKitDesign.regular(13), color: UIKitDesign.textSecondary, lines: 0)
        ]))
    }

    private var languageStateText: String {
        "Current language: \(autonym(for: container.localeManager.activeLocale))"
    }

    private func languageStatePlate() -> UIView {
        let label = UIKitDesign.label(languageStateText, font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
        label.accessibilityIdentifier = "language.state"
        return dataPlate([label], spacing: Spacing.sm)
    }

    private func localeRow(_ locale: Locale) -> UIView {
        let active = container.localeManager.activeLocale.identifier == locale.identifier
        let button = UIButton(type: .custom)
        button.accessibilityIdentifier = "language.option.\(locale.identifier)"
        button.accessibilityLabel = [autonym(for: locale), locale.identifier, active ? "Selected" : nil]
            .compactMap { $0 }
            .joined(separator: ", ")
        button.accessibilityTraits = active ? [.button, .selected] : .button
        button.accessibilityValue = active ? "Selected" : nil
        button.backgroundColor = active ? UIKitDesign.active : UIKitDesign.surface
        button.layer.borderWidth = UIKitDesign.hairline
        button.layer.borderColor = active ? UIKitDesign.hairlineStrong.cgColor : UIKitDesign.hairlineColor.cgColor
        button.addAction(UIAction { [weak self] _ in
            guard let self, !active else { return }
            Haptics.select()
            container.localeManager.setLocale(locale)
            rebuild()
        }, for: .touchUpInside)
        let row = disclosureRow(title: autonym(for: locale), subtitle: nil, trailing: active ? "Selected" : nil)
        row.isUserInteractionEnabled = false
        button.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            row.topAnchor.constraint(equalTo: button.topAnchor),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return button
    }

    private func autonym(for locale: Locale) -> String {
        switch locale.identifier {
        case "zh-Hans": "中文(简体)"
        default: "English"
        }
    }

    @objc private func close() {
        dismiss(animated: true)
    }
}

private final class TrainHomeViewController: InstrumentScrollViewController {
    private let container: AppContainer
    private let modelContext: ModelContext
    private let locale: Locale
    private var verdictVM: TodayVerdictViewModel?
    private var verdictRepository: VerdictEventRepository?

    init(container: AppContainer, modelContext: ModelContext, locale: Locale) {
        self.container = container
        self.modelContext = modelContext
        self.locale = locale
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(dayScopedStateChanged),
            name: .NSCalendarDayChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(dayScopedStateChanged),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    override func rebuild() {
        clearContent()
        let summary = loadSummary()
        expirePastMatchDate(for: summary.athlete)
        refreshVerdictIfNeeded(athlete: summary.athlete)
        let state = TrainHomeViewState.make(summary: summary, locale: locale)
        addHorizontalInsets(hero(
            kicker: "Train",
            title: state.heroTitle,
            body: state.heroBody
        ), top: Spacing.sm)

        let startButton = actionButton(title: state.primaryActionTitle, action: #selector(openTemplatePicker))
        startButton.accessibilityIdentifier = "workoutLog.startWorkout"
        addHorizontalInsets(startButton, top: Spacing.lg)

        if let display = verdictVM?.display {
            addSection(content: dataPlate([verdictCard(display: display, weightUnit: summary.athlete?.weightUnit ?? .kg)], spacing: Spacing.sm))
        }

        addSection(
            title: localized("nextMatch.section.header"),
            content: dataPlate([nextMatchRow(athlete: summary.athlete)], spacing: Spacing.sm)
        )

        if let event = feltRightEvent(athlete: summary.athlete) {
            addSection(content: dataPlate([feltRightPromptRow(event: event, weightUnit: summary.athlete?.weightUnit ?? .kg)], spacing: Spacing.sm))
        }

        addSection(title: "Today", content: dataPlate(todayRows(state: state), spacing: Spacing.sm))

        if state.programRows.isEmpty {
            addSection(content: dataPlate([
                UIKitDesign.label(state.emptyProgramsTitle, font: UIKitDesign.medium(19), color: UIKitDesign.textPrimary),
                UIKitDesign.label(state.emptyProgramsBody, font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
            ], spacing: Spacing.xs))
        } else {
            var templateRows: [UIView] = []
            let visibleTemplates = Array(summary.templates.prefix(state.programRows.count))
            for (index, pair) in zip(visibleTemplates, state.programRows).enumerated() {
                templateRows.append(templateRow(pair.1, template: pair.0))
                if index < state.programRows.count - 1 {
                    templateRows.append(divider())
                }
            }
            addSection(title: "Programs", content: dataPlate(templateRows, spacing: Spacing.sm))
        }

        if !state.sessionRows.isEmpty {
            var sessionRows: [UIView] = []
            for (index, row) in state.sessionRows.enumerated() {
                sessionRows.append(sessionRow(row))
                if index < state.sessionRows.count - 1 {
                    sessionRows.append(divider())
                }
            }
            addSection(title: "History", content: dataPlate(sessionRows, spacing: Spacing.sm))
        }

        addSection(title: "More", content: dataPlate([
            actionRow(
                title: "Workout history",
                subtitle: "Filter sessions and inspect completed work",
                action: #selector(openWorkoutHistory),
                accessibilityIdentifier: "workoutLog.history"
            ),
            divider(),
            actionRow(
                title: "Plan today",
                subtitle: "Assign a session for today",
                action: #selector(openPlanToday),
                accessibilityIdentifier: "workoutLog.planToday"
            ),
            divider(),
            actionRow(
                title: "Manage templates",
                subtitle: "Edit saved programs and weekly schedule",
                action: #selector(openTemplateManager),
                accessibilityIdentifier: "workoutLog.templateManager"
            )
        ], spacing: Spacing.sm))
    }

    private func loadSummary() -> (
        athlete: Athlete?,
        sessions: [WorkoutSession],
        templates: [WorkoutTemplate],
        prescriptions: [PrescribedWorkout]
    ) {
        let athletes = (try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []
        let athlete = athletes.first
        let sessions = (try? modelContext.fetch(FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.sessionDate, order: .reverse)]))) ?? []
        let templates = (try? modelContext.fetch(FetchDescriptor<WorkoutTemplate>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))) ?? []
        let prescriptions = (try? modelContext.fetch(FetchDescriptor<PrescribedWorkout>(sortBy: [SortDescriptor(\.scheduledDate, order: .reverse)]))) ?? []

        guard let athleteId = athlete?.id else {
            return (nil, [], [], [])
        }
        return (
            athlete,
            sessions.filter { $0.athlete?.id == athleteId },
            templates.filter {
                !$0.isArchived && ($0.athleteId == athleteId || $0.coachId == athleteId)
            },
            prescriptions.filter { $0.athleteId == athleteId || $0.coachId == athleteId }
        )
    }

    private func refreshVerdictIfNeeded(athlete: Athlete?) {
        guard let athlete else { return }
        if verdictVM == nil {
            let vm = TodayVerdictViewModel(modelContext: modelContext)
            let repository = VerdictEventRepository(modelContext: modelContext)
            verdictRepository = repository
            vm.onDecisionRecorded = { [weak self, weak vm] decision in
                guard let self, let vm else { return }
                let delta = (decision.adjustedTopSetKg ?? decision.plannedTopSetKg) - decision.plannedTopSetKg
                repository.log(
                    decidedAt: decision.decidedAt,
                    planDate: .now,
                    verdictKindRaw: vm.lastHeadlineVerdictRaw ?? "go",
                    plannedTopSetKg: decision.plannedTopSetKg,
                    adjustedTopSetKg: decision.adjustedTopSetKg,
                    deltaKg: delta,
                    differed: decision.hadAdjustment,
                    actionRaw: self.verdictActionRaw(decision.action),
                    regionRaw: vm.lastHeadlineRegionRaw ?? MuscleRegion.fullBody.rawValue,
                    reasonLine: decision.reasonLine,
                    confidenceNote: vm.display?.confidenceNote,
                    prescriptionId: vm.currentPrescriptionId,
                    suggestedBackoffSetCut: decision.suggestedBackoffSetCut,
                    suggestedRPECap: decision.suggestedRPECap,
                    matchProximity: vm.lastHeadlineMatchProximity,
                    athlete: self.currentAthlete()
                )
            }
            verdictVM = vm
        }
        verdictVM?.refresh(athlete: athlete)
    }

    private func verdictCard(display: TodayVerdictDisplay, weightUnit: WeightUnit) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.accessibilityIdentifier = "workoutLog.verdictCard"

        if let stripColor = verdictStripColor(display.kind) {
            let strip = UIView()
            strip.backgroundColor = stripColor
            strip.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(strip)
            NSLayoutConstraint.activate([
                strip.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                strip.topAnchor.constraint(equalTo: container.topAnchor),
                strip.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                strip.widthAnchor.constraint(equalToConstant: 2)
            ])
        }

        let stack = UIKitDesign.verticalStack(spacing: Spacing.sm)
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        stack.addArrangedSubview(UIKitDesign.microLabel(localized("verdictCard.title")))

        let header = UIStackView()
        header.axis = .horizontal
        header.alignment = .firstBaseline
        header.spacing = Spacing.sm
        header.translatesAutoresizingMaskIntoConstraints = false
        let exercise = UIKitDesign.label(display.headlineExerciseName, font: UIKitDesign.medium(17), color: UIKitDesign.textPrimary, lines: 0)
        exercise.accessibilityIdentifier = "workoutLog.verdict.exercise"
        header.addArrangedSubview(exercise)
        let state = UIKitDesign.microLabel(verdictStateLabel(display))
        state.accessibilityIdentifier = "workoutLog.verdict.state"
        state.textAlignment = .right
        state.setContentHuggingPriority(.required, for: .horizontal)
        header.addArrangedSubview(state)
        stack.addArrangedSubview(header)

        let numberRow = UIStackView()
        numberRow.axis = .horizontal
        numberRow.alignment = .firstBaseline
        numberRow.spacing = Spacing.xs
        numberRow.translatesAutoresizingMaskIntoConstraints = false
        let number = UIKitDesign.label(
            WeightFormatter.display(display.adjustedTopSetKg, unit: weightUnit, locale: locale),
            font: UIKitDesign.tabular(UIKitDesign.regular(32)),
            color: UIKitDesign.textPrimary
        )
        number.accessibilityIdentifier = "workoutLog.verdict.adjustedTopSet"
        numberRow.addArrangedSubview(number)
        if display.hasAdjustment {
            let planned = WeightFormatter.display(display.plannedTopSetKg, unit: weightUnit, locale: locale)
            let format = localized("verdictCard.fromPlanned")
            let plannedLabel = UIKitDesign.label(
                String(format: format, planned),
                font: UIKitDesign.tabular(UIKitDesign.regular(13)),
                color: UIKitDesign.textTertiary
            )
            plannedLabel.accessibilityIdentifier = "workoutLog.verdict.fromPlanned"
            numberRow.addArrangedSubview(plannedLabel)
        }
        stack.addArrangedSubview(numberRow)

        if display.kind == .deferred {
            let caption = UIKitDesign.label(verdictActionCaption(display.kind), font: UIKitDesign.regular(13), color: UIKitDesign.textSecondary, lines: 0)
            caption.accessibilityIdentifier = "workoutLog.verdict.actionCaption"
            stack.addArrangedSubview(caption)
        } else {
            let bar = UIKitStrikeZoneBarView(
                planned: display.plannedTopSetKg,
                adjusted: display.adjustedTopSetKg,
                hasAdjustment: display.hasAdjustment,
                accessibilityLabel: localized("verdictCard.zone.a11y")
            )
            bar.accessibilityIdentifier = "workoutLog.verdict.strikeZone"
            stack.addArrangedSubview(bar)
            bar.heightAnchor.constraint(equalToConstant: 28).isActive = true
            let zone = UIKitDesign.microLabel(verdictZoneCaption(display.kind))
            zone.accessibilityIdentifier = "workoutLog.verdict.zone"
            stack.addArrangedSubview(zone)
        }

        let reason = UIKitDesign.label(display.reasonLine, font: UIKitDesign.regular(15), color: UIKitDesign.textPrimary, lines: 0)
        reason.accessibilityIdentifier = "workoutLog.verdict.reason"
        stack.addArrangedSubview(reason)

        if let note = display.confidenceNote {
            let confidence = UIKitDesign.label(note, font: UIKitDesign.regular(13), color: UIKitDesign.textTertiary, lines: 0)
            confidence.accessibilityIdentifier = "workoutLog.verdict.confidence"
            stack.addArrangedSubview(confidence)
        }

        stack.addArrangedSubview(verdictDecisionArea(display: display))
        stack.addArrangedSubview(verdictFeelRow())

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    private func verdictDecisionArea(display: TodayVerdictDisplay) -> UIView {
        switch display.appliedState {
        case .accepted, .keptPlan:
            let stack = UIKitDesign.verticalStack(spacing: Spacing.sm)
            let confirmed = UIKitDesign.label(verdictConfirmedLine(display.appliedState), font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
            confirmed.accessibilityIdentifier = "workoutLog.verdict.confirmed"
            stack.addArrangedSubview(confirmed)
            if verdictVM?.canStartResolvedWorkout == true {
                stack.addArrangedSubview(verdictButton(
                    title: verdictStartLabel(display),
                    accessibilityIdentifier: "workoutLog.verdict.start"
                ) { [weak self] in
                    self?.startResolvedVerdictWorkout()
                })
            }
            return stack
        case .pending:
            if display.kind == .asPlanned {
                return verdictButton(
                    title: localized("verdictCard.action.gotIt"),
                    accessibilityIdentifier: "workoutLog.verdict.gotIt"
                ) { [weak self] in
                    self?.verdictVM?.keepPlan()
                    self?.rebuild()
                }
            }
            let stack = UIStackView()
            stack.axis = .horizontal
            stack.spacing = Spacing.xs
            stack.distribution = .fillEqually
            stack.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(verdictButton(
                title: localized("verdictCard.action.accept"),
                accessibilityIdentifier: "workoutLog.verdict.accept"
            ) { [weak self] in
                self?.verdictVM?.accept()
                self?.rebuild()
            })
            stack.addArrangedSubview(verdictButton(
                title: localized("verdictCard.action.keep"),
                accessibilityIdentifier: "workoutLog.verdict.keepPlan"
            ) { [weak self] in
                self?.verdictVM?.keepPlan()
                self?.rebuild()
            })
            return stack
        }
    }

    private func verdictFeelRow() -> UIView {
        let stack = UIKitDesign.verticalStack(spacing: Spacing.xs)
        let prompt = UIKitDesign.label(localized("verdictCard.feel.prompt"), font: UIKitDesign.regular(13), color: UIKitDesign.textSecondary, lines: 0)
        prompt.accessibilityIdentifier = "workoutLog.verdict.feel.prompt"
        stack.addArrangedSubview(prompt)
        let buttons = UIStackView()
        buttons.axis = .horizontal
        buttons.spacing = Spacing.xs
        buttons.distribution = .fillEqually
        buttons.translatesAutoresizingMaskIntoConstraints = false
        buttons.addArrangedSubview(verdictButton(
            title: localized("verdictCard.feel.strong"),
            accessibilityIdentifier: "workoutLog.verdict.feel.strong",
            font: UIKitDesign.regular(13)
        ) { [weak self] in
            self?.verdictVM?.feelOverride(.feelingStrong)
            self?.rebuild()
        })
        buttons.addArrangedSubview(verdictButton(
            title: localized("verdictCard.feel.rough"),
            accessibilityIdentifier: "workoutLog.verdict.feel.rough",
            font: UIKitDesign.regular(13)
        ) { [weak self] in
            self?.verdictVM?.feelOverride(.feelingRough)
            self?.rebuild()
        })
        stack.addArrangedSubview(buttons)
        return stack
    }

    private func verdictButton(
        title: String,
        accessibilityIdentifier: String,
        font: UIFont = UIKitDesign.medium(17),
        action: @escaping () -> Void
    ) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.setTitleColor(UIKitDesign.textPrimary, for: .normal)
        button.titleLabel?.font = font
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.backgroundColor = UIKitDesign.surface
        button.layer.borderWidth = UIKitDesign.hairline
        button.layer.borderColor = UIKitDesign.hairlineColor.cgColor
        button.accessibilityIdentifier = accessibilityIdentifier
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        button.addAction(UIAction { _ in
            Haptics.tap()
            action()
        }, for: .touchUpInside)
        return button
    }

    private func nextMatchRow(athlete: Athlete?) -> UIView {
        if let date = athlete?.nextMatchDate,
           let days = Self.displayDaysOut(nextMatchDate: date, asOf: .now, calendar: .current) {
            let row = UIStackView()
            row.axis = .horizontal
            row.alignment = .center
            row.spacing = Spacing.sm
            row.translatesAutoresizingMaskIntoConstraints = false
            row.accessibilityIdentifier = "workoutLog.nextMatch"

            let textStack = UIKitDesign.verticalStack(spacing: Spacing.baselinePair)
            textStack.addArrangedSubview(UIKitDesign.label(daysOutText(days), font: UIKitDesign.medium(17), color: UIKitDesign.textPrimary, lines: 0))
            textStack.addArrangedSubview(UIKitDesign.label(shortDateText(date), font: UIKitDesign.regular(13), color: UIKitDesign.textSecondary))
            row.addArrangedSubview(textStack)

            let change = quietInlineButton(title: localized("nextMatch.action.change"), accessibilityIdentifier: "workoutLog.nextMatch.change") { [weak self] in
                self?.presentNextMatchPicker()
            }
            let clear = quietInlineButton(title: localized("nextMatch.action.clear"), color: UIKitDesign.textSecondary, accessibilityIdentifier: "workoutLog.nextMatch.clear") { [weak self] in
                self?.clearMatchDate()
            }
            row.addArrangedSubview(change)
            row.addArrangedSubview(clear)
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
            return row
        }

        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = Spacing.sm
        row.translatesAutoresizingMaskIntoConstraints = false
        row.accessibilityIdentifier = "workoutLog.nextMatch.empty"
        row.addArrangedSubview(UIKitDesign.label(localized("nextMatch.empty.label"), font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0))
        let button = quietInlineButton(title: localized("nextMatch.empty.set"), accessibilityIdentifier: "workoutLog.nextMatch.set") { [weak self] in
            self?.presentNextMatchPicker()
        }
        row.addArrangedSubview(button)
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        return row
    }

    private func feltRightPromptRow(event: VerdictEvent, weightUnit: WeightUnit) -> UIView {
        let stack = UIKitDesign.verticalStack(spacing: Spacing.xs)
        stack.accessibilityIdentifier = "workoutLog.feltRight"
        stack.addArrangedSubview(UIKitDesign.microLabel(localized("feltRight.header")))

        let number = UIKitDesign.label(feltRightNumberLine(event, weightUnit: weightUnit), font: UIKitDesign.tabular(UIKitDesign.regular(17)), color: UIKitDesign.textPrimary, lines: 0)
        number.accessibilityIdentifier = "workoutLog.feltRight.number"
        stack.addArrangedSubview(number)

        if !event.reasonLine.isEmpty {
            let reason = UIKitDesign.label(event.reasonLine, font: UIKitDesign.regular(13), color: UIKitDesign.textSecondary, lines: 0)
            reason.accessibilityIdentifier = "workoutLog.feltRight.reason"
            stack.addArrangedSubview(reason)
        }

        let question = UIKitDesign.label(localized("feltRight.question"), font: UIKitDesign.regular(17), color: UIKitDesign.textPrimary, lines: 0)
        question.accessibilityIdentifier = "workoutLog.feltRight.question"
        stack.addArrangedSubview(question)

        let buttons = UIStackView()
        buttons.axis = .horizontal
        buttons.spacing = Spacing.xs
        buttons.distribution = .fillEqually
        buttons.translatesAutoresizingMaskIntoConstraints = false
        buttons.addArrangedSubview(feltRightButton(title: localized("feltRight.right"), answer: "right", event: event))
        buttons.addArrangedSubview(feltRightButton(title: localized("feltRight.wrong"), answer: "wrong", event: event))
        buttons.addArrangedSubview(feltRightButton(title: localized("feltRight.unsure"), answer: "unsure", event: event))
        stack.addArrangedSubview(buttons)
        return stack
    }

    private func feltRightButton(title: String, answer: String, event: VerdictEvent) -> UIButton {
        let button = verdictButton(
            title: title,
            accessibilityIdentifier: "workoutLog.feltRight.\(answer)",
            font: UIKitDesign.regular(13)
        ) { [weak self, weak event] in
            guard let self, let event else { return }
            let recorded = self.verdictRepository?.recordFeltRight(answer, for: event, at: .now, calendar: .current) ?? false
            if !recorded {
                self.rebuild()
                return
            }
            self.rebuild()
        }
        return button
    }

    private func quietInlineButton(
        title: String,
        color: UIColor = UIKitDesign.textPrimary,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.setTitleColor(color, for: .normal)
        button.titleLabel?.font = UIKitDesign.regular(15)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.accessibilityIdentifier = accessibilityIdentifier
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.addAction(UIAction { _ in
            Haptics.tap()
            action()
        }, for: .touchUpInside)
        return button
    }

    private func feltRightEvent(athlete: Athlete?) -> VerdictEvent? {
        let repository = verdictRepository ?? VerdictEventRepository(modelContext: modelContext)
        verdictRepository = repository
        return FeltRightPromptEngine.eligibleEvent(
            events: repository.fetchRecent(days: 3, athlete: athlete),
            asOf: .now,
            calendar: .current
        )
    }

    private func feltRightNumberLine(_ event: VerdictEvent, weightUnit: WeightUnit) -> String {
        let planned = WeightFormatter.display(event.plannedTopSetKg, unit: weightUnit, locale: locale)
        guard let adjusted = event.adjustedTopSetKg else { return planned }
        let adjustedText = WeightFormatter.display(adjusted, unit: weightUnit, locale: locale)
        return "\(planned) -> \(adjustedText)"
    }

    private func startResolvedVerdictWorkout() {
        guard let plan = verdictVM?.resolvedPlanForWorkout else { return }
        presentResolvedWorkout(plan: plan)
    }

    private func currentAthlete() -> Athlete? {
        ((try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []).first
    }

    private func presentNextMatchPicker() {
        guard let athlete = currentAthlete() else { return }
        let controller = NextMatchPickerViewController(
            locale: locale,
            initialDate: athlete.nextMatchDate
        ) { [weak self, weak athlete] date in
            guard let self, let athlete else { return }
            athlete.nextMatchDate = Calendar.current.startOfDay(for: date)
            try? self.modelContext.save()
            self.rebuild()
        }
        present(InstrumentNavigationController(rootViewController: controller), animated: true)
    }

    private func clearMatchDate() {
        guard let athlete = currentAthlete() else { return }
        athlete.nextMatchDate = nil
        try? modelContext.save()
        rebuild()
    }

    private func expirePastMatchDate(for athlete: Athlete?) {
        guard let athlete, let date = athlete.nextMatchDate else { return }
        if Self.displayDaysOut(nextMatchDate: date, asOf: .now, calendar: .current) == nil {
            athlete.nextMatchDate = nil
            try? modelContext.save()
        }
    }

    static func displayDaysOut(nextMatchDate: Date?, asOf: Date, calendar: Calendar) -> Int? {
        guard let nextMatchDate else { return nil }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: asOf),
            to: calendar.startOfDay(for: nextMatchDate)
        ).day ?? 0
        return days < 0 ? nil : days
    }

    private func daysOutText(_ days: Int) -> String {
        switch days {
        case 0: return localized("nextMatch.daysOut.today")
        case 1: return localized("nextMatch.daysOut.tomorrow")
        default:
            return String(format: localized("nextMatch.daysOut.inDays"), Int64(days))
        }
    }

    private func shortDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func verdictStateLabel(_ display: TodayVerdictDisplay) -> String {
        switch display.kind {
        case .adjusted:
            return display.isMicrodose ? localized("verdictCard.state.microdose") : localized("verdictCard.state.adjust")
        case .asPlanned:
            return localized("verdictCard.state.steady")
        case .deferred:
            return localized("verdictCard.state.learning")
        }
    }

    private func verdictActionCaption(_ kind: TodayVerdictDisplay.Kind) -> String {
        switch kind {
        case .adjusted: localized("verdictCard.action.adjusted")
        case .asPlanned: localized("verdictCard.action.asPlanned")
        case .deferred: localized("verdictCard.action.deferred")
        }
    }

    private func verdictZoneCaption(_ kind: TodayVerdictDisplay.Kind) -> String {
        switch kind {
        case .adjusted: localized("verdictCard.zone.in")
        case .asPlanned: localized("verdictCard.zone.right")
        case .deferred: ""
        }
    }

    private func verdictConfirmedLine(_ state: TodayVerdictDisplay.AppliedState) -> String {
        switch state {
        case .accepted: localized("verdictCard.state.accepted")
        case .keptPlan: localized("verdictCard.state.kept")
        case .pending: ""
        }
    }

    private func verdictStartLabel(_ display: TodayVerdictDisplay) -> String {
        switch display.appliedState {
        case .accepted:
            return localized("verdictCard.start.adjusted")
        case .keptPlan:
            return display.kind == .adjusted ? localized("verdictCard.start.plan") : localized("verdictCard.start.workout")
        case .pending:
            return ""
        }
    }

    private func verdictStripColor(_ kind: TodayVerdictDisplay.Kind) -> UIColor? {
        switch kind {
        case .adjusted: return UIColor(ColorTokens.zoneCaution)
        case .deferred: return UIColor(ColorTokens.zoneLow)
        case .asPlanned: return nil
        }
    }

    private func verdictActionRaw(_ action: VerdictAction) -> String {
        switch action {
        case .accepted: return "accepted"
        case .keptPlan: return "keptPlan"
        case .feel(.feelingStrong): return "feelStrong"
        case .feel(.feelingRough): return "feelRough"
        }
    }

    @objc private func dayScopedStateChanged() {
        rebuild()
    }

    private func localized(_ key: String.LocalizationValue) -> String {
        UIKitStrings.localized(key, locale: locale)
    }

    private func todayRows(state: TrainHomeViewState) -> [UIView] {
        if let todayPlan = state.todayPlan {
            return [
                actionRow(
                    title: todayPlan.title,
                    subtitle: todayPlan.subtitle,
                    trailing: todayPlan.actionTitle,
                    action: #selector(startTodayPlan),
                    accessibilityIdentifier: "workoutLog.todayPlan"
                )
            ]
        }
        return [
            UIKitDesign.label(state.emptyTodayTitle, font: UIKitDesign.medium(19), color: UIKitDesign.textPrimary),
            UIKitDesign.label(state.emptyTodayBody, font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
        ]
    }

    private func todayPrescription(from prescriptions: [PrescribedWorkout]) -> PrescribedWorkout? {
        let calendar = Calendar.current
        return prescriptions.first {
            calendar.isDateInToday($0.scheduledDate) && $0.status == .assigned
        }
    }

    private func templateRow(_ rowState: TrainHomeViewState.ProgramRow, template: WorkoutTemplate) -> UIView {
        let button = UIButton(type: .custom)
        button.accessibilityIdentifier = "workoutLog.programStart"
        button.accessibilityLabel = [rowState.title, rowState.subtitle, rowState.trailing].joined(separator: ", ")
        button.addAction(UIAction { [weak self] _ in
            Haptics.select()
            self?.presentActiveWorkout(template: template)
        }, for: .touchUpInside)
        let row = disclosureRow(title: rowState.title, subtitle: rowState.subtitle, trailing: rowState.trailing)
        row.isUserInteractionEnabled = false
        button.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            row.topAnchor.constraint(equalTo: button.topAnchor),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return button
    }

    private func sessionRow(_ rowState: TrainHomeViewState.SessionRow) -> UIView {
        disclosureRow(title: rowState.title, subtitle: rowState.subtitle)
    }

    private func actionRow(
        title: String,
        subtitle: String?,
        trailing: String? = nil,
        action: Selector,
        accessibilityIdentifier: String? = nil
    ) -> UIView {
        let button = UIButton(type: .custom)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.accessibilityIdentifier = accessibilityIdentifier
        button.accessibilityLabel = [title, subtitle, trailing].compactMap { $0 }.joined(separator: ", ")
        let row = disclosureRow(title: title, subtitle: subtitle, trailing: trailing)
        row.isUserInteractionEnabled = false
        button.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            row.topAnchor.constraint(equalTo: button.topAnchor),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return button
    }

    @objc private func startTodayPlan() {
        Haptics.tap()
        container.uxAnalyticsService.track(.primaryActionTapped, properties: [
            "surface": "train",
            "action": "start_today_plan"
        ])
        let summary = loadSummary()
        guard let todayPlan = todayPrescription(from: summary.prescriptions) else {
            openTemplatePicker()
            return
        }
        container.uxAnalyticsService.track(.todayPlanDecisionMade, properties: [
            "surface": "train",
            "decision": "start_assigned_plan"
        ])
        presentResolvedWorkout(plan: ResolvedSessionPlan.resolve(from: todayPlan))
    }

    private func presentResolvedWorkout(plan: ResolvedSessionPlan) {
        container.uxAnalyticsService.track(.workoutStarted, properties: [
            "source": "planned_session"
        ])
        let controller = ActiveWorkoutViewController(
            container: container,
            modelContext: modelContext,
            locale: locale,
            resolvedPlan: plan
        )
        present(InstrumentNavigationController(rootViewController: controller), animated: true)
    }

    @objc private func openTemplatePicker() {
        Haptics.tap()
        container.uxAnalyticsService.track(.primaryActionTapped, properties: [
            "surface": "train",
            "action": "start_workout"
        ])
        let picker = TemplatePickerViewController(
            container: container,
            modelContext: modelContext,
            locale: locale,
            showUnifiedRoutes: true,
            onSelectTemplate: { [weak self] template in
                self?.presentActiveWorkout(template: template)
            },
            onStartBlank: { [weak self] in
                self?.presentActiveWorkout(template: nil)
            },
            onCreateTemplate: { [weak self] in
                self?.presentTemplateEditor(existingTemplate: nil)
            },
            onPlanToday: { [weak self] in
                self?.openPlanToday()
            }
        )
        present(InstrumentNavigationController(rootViewController: picker), animated: true)
    }

    private func presentActiveWorkout(template: WorkoutTemplate?) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            self.container.uxAnalyticsService.track(.workoutStarted, properties: [
                "source": template == nil ? "blank" : "template"
            ])
            if template != nil {
                self.container.uxAnalyticsService.track(.programStarted, properties: [
                    "surface": "train"
                ])
            }
            let controller = ActiveWorkoutViewController(
                container: self.container,
                modelContext: self.modelContext,
                locale: self.locale,
                template: template
            )
            self.present(InstrumentNavigationController(rootViewController: controller), animated: true)
        }
    }

    private func presentTemplateEditor(existingTemplate: WorkoutTemplate?) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self,
                  let athleteId = ((try? self.modelContext.fetch(FetchDescriptor<Athlete>())) ?? []).first?.id else { return }
            let controller = TemplateEditorViewController(
                container: self.container,
                modelContext: self.modelContext,
                locale: self.locale,
                ownerId: athleteId,
                existingTemplate: existingTemplate,
                newTemplatesAreAthleteOwned: true
            )
            self.present(InstrumentNavigationController(rootViewController: controller), animated: true)
        }
    }

    @objc private func openWorkoutHistory() {
        Haptics.tap()
        let controller = WorkoutHistoryViewController(
            container: container,
            modelContext: modelContext,
            locale: locale
        )
        present(InstrumentNavigationController(rootViewController: controller), animated: true)
    }

    @objc private func openPlanToday() {
        Haptics.tap()
        let controller = PlanTodayViewController(
            container: container,
            modelContext: modelContext,
            locale: locale,
            onPlanned: { [weak self] in
                self?.rebuild()
            }
        )
        present(InstrumentNavigationController(rootViewController: controller), animated: true)
    }

    @objc private func openTemplateManager() {
        Haptics.tap()
        let controller = TemplateManagerViewController(
            container: container,
            modelContext: modelContext,
            locale: locale,
            newTemplatesAreAthleteOwned: true
        )
        present(InstrumentNavigationController(rootViewController: controller), animated: true)
    }
}

private final class UIKitStrikeZoneBarView: UIView {
    private let planned: Double
    private let adjusted: Double
    private let hasAdjustment: Bool

    init(planned: Double, adjusted: Double, hasAdjustment: Bool, accessibilityLabel: String) {
        self.planned = planned
        self.adjusted = adjusted
        self.hasAdjustment = hasAdjustment
        super.init(frame: .zero)
        backgroundColor = .clear
        isAccessibilityElement = true
        self.accessibilityLabel = accessibilityLabel
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let width = rect.width
        let midY = rect.midY

        let lo = min(planned, adjusted)
        let hi = max(planned, adjusted)
        let span = max(hi - lo, max(lo, 1) * 0.08)
        let scaleMin = lo - span * 0.7
        let scaleRange = max((hi + span * 0.7) - scaleMin, 0.0001)
        let x: (Double) -> CGFloat = { value in
            CGFloat((value - scaleMin) / scaleRange) * width
        }

        let zoneLo = adjusted - span * 0.45
        let zoneHi = adjusted + span * 0.45
        let zoneLeft = x(zoneLo)
        let zoneRight = x(zoneHi)

        context.setFillColor(UIKitDesign.hairlineColor.cgColor)
        context.fill(CGRect(x: 0, y: midY - 0.5, width: width, height: 1))

        context.setFillColor(UIKitDesign.hairlineStrong.cgColor)
        context.fill(CGRect(x: zoneLeft, y: midY - 1.5, width: max(zoneRight - zoneLeft, 1), height: 3))
        context.fill(CGRect(x: zoneLeft - 0.75, y: midY - 7, width: 1.5, height: 14))
        context.fill(CGRect(x: zoneRight - 0.75, y: midY - 7, width: 1.5, height: 14))

        if hasAdjustment {
            context.setFillColor(UIKitDesign.textTertiary.cgColor)
            context.fill(CGRect(x: x(planned) - 0.75, y: midY - 8, width: 1.5, height: 16))
        }

        context.setFillColor(UIKitDesign.textPrimary.cgColor)
        context.fillEllipse(in: CGRect(x: x(adjusted) - 4, y: midY - 4, width: 8, height: 8))
    }
}

private final class NextMatchPickerViewController: InstrumentScrollViewController {
    private let locale: Locale
    private let onSet: (Date) -> Void
    private let datePicker = UIDatePicker()
    private let actionDock = UIKitBottomActionDock(primaryTitle: "Set")

    init(locale: Locale, initialDate: Date?, onSet: @escaping (Date) -> Void) {
        self.locale = locale
        self.onSet = onSet
        super.init(nibName: nil, bundle: nil)
        let today = Calendar.current.startOfDay(for: .now)
        datePicker.date = max(initialDate.map { Calendar.current.startOfDay(for: $0) } ?? today, today)
        datePicker.minimumDate = today
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = localized("nextMatch.picker.navTitle")
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: localized("action.cancel", defaultValue: "Cancel"),
            style: .plain,
            target: self,
            action: #selector(cancel)
        )
        navigationItem.leftBarButtonItem?.accessibilityIdentifier = "nextMatch.picker.cancel"
        actionDock.primaryButton.addTarget(self, action: #selector(confirm), for: .touchUpInside)
        installBottomActionDock(actionDock)
    }

    override func rebuild() {
        clearContent()
        actionDock.updatePrimary(
            title: localized("nextMatch.picker.confirm"),
            accessibilityIdentifier: "nextMatch.picker.confirm",
            accessibilityValue: nil
        )

        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .inline
        datePicker.locale = locale
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        datePicker.accessibilityIdentifier = "nextMatch.picker.date"
        addSection(content: dataPlate([datePicker], spacing: Spacing.sm))
    }

    @objc private func confirm() {
        Haptics.tap()
        onSet(datePicker.date)
        dismiss(animated: true)
    }

    @objc private func cancel() {
        Haptics.tap()
        dismiss(animated: true)
    }

    private func localized(_ key: String.LocalizationValue) -> String {
        UIKitStrings.localized(key, locale: locale)
    }

    private func localized(_ key: StaticString, defaultValue: String.LocalizationValue) -> String {
        UIKitStrings.localized(key, defaultValue: defaultValue, locale: locale)
    }
}

private final class WorkoutHistoryViewController: InstrumentScrollViewController {
    private let container: AppContainer
    private let modelContext: ModelContext
    private let locale: Locale
    private var selectedSessionType: SessionType?
    private var latestLockedWeeks = 0

    init(container: AppContainer, modelContext: ModelContext, locale: Locale) {
        self.container = container
        self.modelContext = modelContext
        self.locale = locale
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Workout Log"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Done",
            style: .plain,
            target: self,
            action: #selector(closeHistory)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Start",
            style: .done,
            target: self,
            action: #selector(openTemplatePicker)
        )
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "workoutLog.startWorkout"
    }

    override func rebuild() {
        clearContent()
        let sessions = scopedSessions()
        let freeVisible = container.subscriptionService.isPro ? sessions : SubscriptionService.filterSessionsForFree(sessions)
        let visible = selectedSessionType.map { type in
            freeVisible.filter { $0.sessionType == type }
        } ?? freeVisible
        let lockedWeeks = container.subscriptionService.isPro
            ? 0
            : SubscriptionService.lockedWeeks(totalSessions: sessions.count, visibleSessions: freeVisible.count)
        latestLockedWeeks = lockedWeeks

        addHorizontalInsets(hero(
            kicker: "History",
            title: selectedSessionType?.displayName ?? "All sessions",
            body: "\(visible.count) visible sessions · \(sessions.count) total"
        ), top: Spacing.sm)

        addSection(title: "Filter", content: dataPlate([
            actionRow(title: "Session type", subtitle: nil, trailing: selectedSessionType?.displayName ?? "All", action: #selector(chooseSessionType))
        ]))

        if visible.isEmpty {
            addSection(content: dataPlate([
                UIKitDesign.label("No sessions", font: UIKitDesign.medium(19), color: UIKitDesign.textPrimary),
                UIKitDesign.label("Completed workouts appear here after they are saved.", font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
            ], spacing: Spacing.xs))
        } else {
            var rows: [UIView] = []
            for (index, session) in visible.enumerated() {
                rows.append(sessionButton(session))
                if index < visible.count - 1 {
                    rows.append(divider())
                }
            }
            addSection(title: "Sessions", content: dataPlate(rows, spacing: Spacing.sm))
        }

        if lockedWeeks > 0 {
            addSection(title: "History", content: dataPlate([
                UIKitDesign.label("\(lockedWeeks) week\(lockedWeeks == 1 ? "" : "s") locked", font: UIKitDesign.medium(19), color: UIKitDesign.textPrimary),
                UIKitDesign.label("Athlete Pro unlocks the full training history.", font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0),
                actionButton(title: "Upgrade", action: #selector(openUpgrade))
            ], spacing: Spacing.sm))
        }
    }

    private func scopedSessions() -> [WorkoutSession] {
        let athletes = (try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []
        let athleteId = athletes.first?.id
        let sessions = (try? modelContext.fetch(FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.sessionDate, order: .reverse)]))) ?? []
        guard let athleteId else { return sessions }
        return sessions.filter { $0.athlete?.id == athleteId }
    }

    private func sessionButton(_ session: WorkoutSession) -> UIView {
        let button = UIButton(type: .custom)
        button.accessibilityIdentifier = "workoutHistory.session"
        button.accessibilityLabel = session.sessionName ?? session.sportType.displayName
        button.addAction(UIAction { [weak self] _ in
            self?.openSession(session)
        }, for: .touchUpInside)
        let detail = [
            session.sessionDate.relativeString(locale: locale),
            Date.durationString(seconds: session.durationSeconds, locale: locale),
            session.sessionRPE.map { String(format: "RPE %.0f", $0) },
            session.trainingStress > 0 ? String(format: "%.1f load", session.trainingStress) : nil
        ]
            .compactMap { $0 }
            .joined(separator: " · ")
        let row = disclosureRow(title: session.sessionName ?? session.sportType.displayName, subtitle: detail, trailing: session.sessionType.displayName)
        row.isUserInteractionEnabled = false
        button.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            row.topAnchor.constraint(equalTo: button.topAnchor),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return button
    }

    private func actionRow(title: String, subtitle: String?, trailing: String? = nil, action: Selector) -> UIView {
        let button = UIButton(type: .custom)
        button.addTarget(self, action: action, for: .touchUpInside)
        let row = disclosureRow(title: title, subtitle: subtitle, trailing: trailing)
        row.isUserInteractionEnabled = false
        button.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            row.topAnchor.constraint(equalTo: button.topAnchor),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return button
    }

    private func openSession(_ session: WorkoutSession) {
        Haptics.tap()
        showInstrumentDetail(WorkoutSessionDetailViewController(session: session, locale: locale))
    }

    @objc private func chooseSessionType() {
        let controller = InstrumentChoiceListViewController(
            title: "Session Type",
            stateText: { [weak self] in "Current filter: \(self?.selectedSessionType?.displayName ?? "All")" },
            options: { [weak self] in
                [
                    InstrumentChoiceOption(
                        title: "All",
                        isSelected: self?.selectedSessionType == nil
                    ) { [weak self] in
                        self?.selectedSessionType = nil
                        self?.rebuild()
                    }
                ] + SessionType.allCases.map { type in
                    InstrumentChoiceOption(
                        title: type.displayName,
                        isSelected: self?.selectedSessionType == type
                    ) { [weak self] in
                        self?.selectedSessionType = type
                        self?.rebuild()
                    }
                }
            }
        )
        showInstrumentDetail(controller)
    }

    @objc private func openTemplatePicker() {
        Haptics.tap()
        let picker = TemplatePickerViewController(
            container: container,
            modelContext: modelContext,
            locale: locale,
            showUnifiedRoutes: true,
            onSelectTemplate: { [weak self] template in
                self?.presentActiveWorkout(template: template)
            },
            onStartBlank: { [weak self] in
                self?.presentActiveWorkout(template: nil)
            },
            onCreateTemplate: { [weak self] in
                self?.presentTemplateEditor()
            }
        )
        present(InstrumentNavigationController(rootViewController: picker), animated: true)
    }

    private func presentActiveWorkout(template: WorkoutTemplate?) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            self.container.uxAnalyticsService.track(.workoutStarted, properties: [
                "source": template == nil ? "blank" : "template"
            ])
            if template != nil {
                self.container.uxAnalyticsService.track(.programStarted, properties: [
                    "surface": "workout_history"
                ])
            }
            let controller = ActiveWorkoutViewController(
                container: self.container,
                modelContext: self.modelContext,
                locale: self.locale,
                template: template
            )
            self.present(InstrumentNavigationController(rootViewController: controller), animated: true)
        }
    }

    private func presentTemplateEditor() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self,
                  let athleteId = ((try? self.modelContext.fetch(FetchDescriptor<Athlete>())) ?? []).first?.id else { return }
            let controller = TemplateEditorViewController(
                container: self.container,
                modelContext: self.modelContext,
                locale: self.locale,
                ownerId: athleteId,
                existingTemplate: nil,
                newTemplatesAreAthleteOwned: true
            )
            self.present(InstrumentNavigationController(rootViewController: controller), animated: true)
        }
    }

    @objc private func openUpgrade() {
        let controller = UpgradeViewController(container: container, trigger: .history(lockedWeeks: latestLockedWeeks))
        present(InstrumentNavigationController(rootViewController: controller), animated: true)
    }

    @objc private func closeHistory() {
        Haptics.tap()
        dismiss(animated: true)
    }
}

private final class WorkoutSessionDetailViewController: InstrumentScrollViewController {
    private let session: WorkoutSession
    private let locale: Locale

    init(session: WorkoutSession, locale: Locale) {
        self.session = session
        self.locale = locale
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = session.sessionName ?? session.sportType.displayName
    }

    override func rebuild() {
        clearContent()
        addHorizontalInsets(hero(
            kicker: session.sportType.displayName,
            title: session.sessionName ?? session.sportType.displayName,
            body: session.sessionDate.formatted(date: .abbreviated, time: .shortened)
        ), top: Spacing.sm)

        addSection(title: "Summary", content: metricRail([
            ("Duration", Date.durationString(seconds: session.durationSeconds, locale: locale), "Elapsed"),
            ("RPE", session.sessionRPE.map { String(format: "%.0f", $0) } ?? "--", "Session"),
            ("Load", session.trainingStress > 0 ? String(format: "%.1f", session.trainingStress) : "--", "TSS")
        ]))

        if session.totalVolume > 0 || session.acuteLoad > 0 {
            addSection(title: "Load", content: metricRail([
                ("Volume", session.totalVolume > 0 ? String(format: "%.0f", session.totalVolume) : "--", session.totalVolume > 0 ? "kg / m" : "No data"),
                ("ATL", session.acuteLoad > 0 ? String(format: "%.0f", session.acuteLoad) : "--", "Acute"),
                ("CTL", session.chronicLoad > 0 ? String(format: "%.0f", session.chronicLoad) : "--", "Chronic")
            ]))
        }

        if session.sortedEntries.isEmpty {
            addSection(content: dataPlate([
                UIKitDesign.label("No exercise rows", font: UIKitDesign.medium(19), color: UIKitDesign.textPrimary),
                UIKitDesign.label("This session was saved without detailed sets.", font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
            ], spacing: Spacing.xs))
            return
        }

        for (entryIndex, entry) in session.sortedEntries.enumerated() {
            addSection(title: entry.exerciseName, content: exercisePlate(entry, entryIndex: entryIndex))
        }
    }

    private func exercisePlate(_ entry: ExerciseEntry, entryIndex: Int) -> UIView {
        var rows: [UIView] = []
        let subtitle = [
            entry.exerciseCategory.displayName,
            entry.muscleGroup?.displayName
        ]
            .compactMap { $0 }
            .joined(separator: " · ")
        if !subtitle.isEmpty {
            let label = UIKitDesign.label(subtitle, font: UIKitDesign.regular(13), color: UIKitDesign.textSecondary, lines: 0)
            label.accessibilityIdentifier = "sessionDetail.exercise.\(entryIndex).subtitle"
            rows.append(label)
            rows.append(divider())
        }
        for (index, set) in entry.sortedSets.enumerated() {
            rows.append(setRow(set, entryIndex: entryIndex, setIndex: index))
            if index < entry.sortedSets.count - 1 {
                rows.append(divider())
            }
        }
        if entry.totalVolume > 0 {
            rows.append(divider())
            rows.append(UIKitDesign.label(String(format: "Total %.0f kg", entry.totalVolume), font: UIKitDesign.medium(15), color: UIKitDesign.textPrimary))
        }
        return dataPlate(rows, spacing: Spacing.sm)
    }

    private func setRow(_ set: SetRecord, entryIndex: Int, setIndex: Int) -> UIView {
        let stack = UIKitDesign.verticalStack(spacing: Spacing.xs)
        let title = set.isWarmup ? "Set \(set.setIndex + 1) · Warm-up" : "Set \(set.setIndex + 1)"
        let titleLabel = UIKitDesign.label(title, font: UIKitDesign.medium(15), color: UIKitDesign.textPrimary)
        titleLabel.accessibilityIdentifier = "sessionDetail.set.\(entryIndex).\(setIndex).title"
        stack.addArrangedSubview(titleLabel)
        let detail = [
            set.weightKg.map { String(format: "%.1f kg", $0) },
            set.reps.map { "\($0) reps" },
            set.distanceMeters.map { String(format: "%.0f m", $0) },
            set.durationSeconds.map { Date.durationString(seconds: $0, locale: locale) },
            set.rpe.map { String(format: "RPE %.0f", $0) },
            set.volume > 0 ? String(format: "%.0f volume", set.volume) : nil
        ]
            .compactMap { $0 }
            .joined(separator: " · ")
        let detailLabel = UIKitDesign.label(
            detail.isEmpty ? "No recorded targets" : detail,
            font: UIKitDesign.regular(15),
            color: UIKitDesign.textSecondary,
            lines: 0
        )
        detailLabel.accessibilityIdentifier = "sessionDetail.set.\(entryIndex).\(setIndex).detail"
        stack.addArrangedSubview(detailLabel)
        return stack
    }
}

private final class PlanTodayViewController: InstrumentScrollViewController {
    private let container: AppContainer
    private let modelContext: ModelContext
    private let locale: Locale
    private let onPlanned: () -> Void

    init(
        container: AppContainer,
        modelContext: ModelContext,
        locale: Locale,
        onPlanned: @escaping () -> Void
    ) {
        self.container = container
        self.modelContext = modelContext
        self.locale = locale
        self.onPlanned = onPlanned
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Plan Today"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(cancelPlan)
        )
        navigationItem.leftBarButtonItem?.accessibilityIdentifier = "planToday.cancel"
    }

    override func rebuild() {
        clearContent()
        addHorizontalInsets(hero(
            kicker: "Today",
            title: "Plan session",
            body: "Choose a saved template or enter one lift."
        ), top: Spacing.sm)
        addSection(content: dataPlate([
            actionRow(
                title: "Load Template",
                subtitle: "Freeze a saved program as today's plan",
                action: #selector(openTemplatePicker),
                accessibilityIdentifier: "planToday.loadTemplate"
            ),
            divider(),
            actionRow(
                title: "Enter Lift",
                subtitle: "Create a one-off target for today",
                action: #selector(openManualLift),
                accessibilityIdentifier: "planToday.enterLift"
            )
        ], spacing: Spacing.sm))
    }

    private func actionRow(title: String, subtitle: String?, action: Selector, accessibilityIdentifier: String? = nil) -> UIView {
        let button = UIButton(type: .custom)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.accessibilityIdentifier = accessibilityIdentifier
        button.accessibilityLabel = [title, subtitle].compactMap { $0 }.joined(separator: ", ")
        let row = disclosureRow(title: title, subtitle: subtitle)
        row.isUserInteractionEnabled = false
        button.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            row.topAnchor.constraint(equalTo: button.topAnchor),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return button
    }

    @objc private func openTemplatePicker() {
        Haptics.tap()
        let picker = TemplatePickerViewController(
            container: container,
            modelContext: modelContext,
            locale: locale,
            onSelectTemplate: { [weak self] template in
                self?.planFromTemplate(template)
            },
            onStartBlank: { [weak self] in
                self?.openManualLift()
            },
            onCreateTemplate: { [weak self] in
                self?.openTemplateEditor()
            }
        )
        present(InstrumentNavigationController(rootViewController: picker), animated: true)
    }

    @objc private func openManualLift() {
        Haptics.tap()
        let controller = ManualLiftPlanViewController(modelContext: modelContext) { [weak self] in
            guard let self else { return }
            self.onPlanned()
            self.dismiss(animated: true)
        }
        present(InstrumentNavigationController(rootViewController: controller), animated: true)
    }

    private func openTemplateEditor() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self,
                  let athleteId = ((try? self.modelContext.fetch(FetchDescriptor<Athlete>())) ?? []).first?.id else { return }
            let controller = TemplateEditorViewController(
                container: self.container,
                modelContext: self.modelContext,
                locale: self.locale,
                ownerId: athleteId,
                existingTemplate: nil,
                newTemplatesAreAthleteOwned: true
            )
            self.present(InstrumentNavigationController(rootViewController: controller), animated: true)
        }
    }

    private func planFromTemplate(_ template: WorkoutTemplate) {
        guard let athleteId = ((try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []).first?.id else { return }
        let repo = PlannedSessionRepository(modelContext: modelContext)
        repo.planFromTemplate(template, athleteId: athleteId)
        Haptics.success()
        onPlanned()
        dismiss(animated: true)
    }

    @objc private func cancelPlan() {
        Haptics.tap()
        dismiss(animated: true)
    }
}

private final class ManualLiftPlanViewController: InstrumentScrollViewController, UITextFieldDelegate {
    private let modelContext: ModelContext
    private let onPlanned: () -> Void
    private var liftName = ""
    private var weightText = ""
    private var repsText = ""
    private var rpeEnabled = false
    private var rpe: Double = 8
    private let actionDock = UIKitBottomActionDock(primaryTitle: "Plan Lift")

    init(modelContext: ModelContext, onPlanned: @escaping () -> Void) {
        self.modelContext = modelContext
        self.onPlanned = onPlanned
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Manual Lift"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(cancelManual)
        )
        navigationItem.leftBarButtonItem?.accessibilityIdentifier = "manualLift.cancel"
        actionDock.primaryButton.addTarget(self, action: #selector(planLift), for: .touchUpInside)
        installBottomActionDock(actionDock)
    }

    override func rebuild() {
        clearContent()
        actionDock.updatePrimary(
            title: "Plan Lift",
            isEnabled: canPlan,
            accessibilityIdentifier: "manualLift.plan",
            accessibilityValue: manualLiftStateText
        )
        addHorizontalInsets(hero(
            kicker: "One-off",
            title: liftName.isEmpty ? "Manual lift" : liftName,
            body: rpeEnabled ? String(format: "RPE %.0f target", rpe) : "Weight, reps, and optional RPE"
        ), top: Spacing.sm)
        addHorizontalInsets(manualLiftStatePlate(), top: Spacing.sm)

        addSection(title: "Target", content: dataPlate([
            textInputRow(
                title: "Lift Name",
                placeholder: "Back Squat",
                value: liftName,
                keyboardType: .default,
                accessibilityIdentifier: "manualLift.name"
            ) { [weak self] value in
                self?.liftName = value
                self?.actionDock.updatePrimary(
                    title: "Plan Lift",
                    isEnabled: self?.canPlan == true,
                    accessibilityIdentifier: "manualLift.plan",
                    accessibilityValue: self?.manualLiftStateText
                )
            },
            divider(),
            fieldPairRow(),
            divider(),
            rpeRow()
        ], spacing: Spacing.sm))
    }

    private var canPlan: Bool {
        !liftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && ((try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []).first != nil
    }

    private var manualLiftStateText: String {
        if ((try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []).first == nil {
            return "No athlete profile"
        }
        if liftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Lift name required"
        }
        return "Ready to plan"
    }

    private func manualLiftStatePlate() -> UIView {
        let label = UIKitDesign.label(manualLiftStateText, font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
        label.accessibilityIdentifier = "manualLift.state"
        return dataPlate([label], spacing: Spacing.sm)
    }

    private func fieldPairRow() -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Spacing.xs
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(textInputRow(title: "Weight", placeholder: "kg", value: weightText, keyboardType: .decimalPad, accessibilityIdentifier: "manualLift.weight") { [weak self] value in
            self?.weightText = value
        })
        stack.addArrangedSubview(textInputRow(title: "Reps", placeholder: "reps", value: repsText, keyboardType: .numberPad, accessibilityIdentifier: "manualLift.reps") { [weak self] value in
            self?.repsText = value
        })
        return stack
    }

    private func rpeRow() -> UIView {
        let stack = UIKitDesign.verticalStack(spacing: Spacing.sm)
        let header = UIStackView()
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = Spacing.sm
        header.translatesAutoresizingMaskIntoConstraints = false
        header.addArrangedSubview(UIKitDesign.label("RPE Target", font: UIKitDesign.regular(17), color: UIKitDesign.textPrimary))
        header.addArrangedSubview(UIView())
        let toggle = UISwitch()
        toggle.accessibilityIdentifier = "manualLift.rpeToggle"
        toggle.isOn = rpeEnabled
        toggle.onTintColor = UIKitDesign.textPrimary
        toggle.thumbTintColor = UIKitDesign.background
        toggle.addAction(UIAction { [weak self] _ in
            self?.rpeEnabled.toggle()
            Haptics.select()
            self?.rebuild()
        }, for: .valueChanged)
        header.addArrangedSubview(toggle)
        stack.addArrangedSubview(header)

        if rpeEnabled {
            stack.addArrangedSubview(UIKitDesign.label(String(format: "RPE %.0f", rpe), font: UIKitDesign.medium(17), color: UIKitDesign.textPrimary))
            let slider = UISlider()
            slider.minimumValue = 1
            slider.maximumValue = 10
            slider.value = Float(rpe)
            slider.minimumTrackTintColor = UIKitDesign.textSecondary
            slider.maximumTrackTintColor = UIKitDesign.hairlineColor
            slider.thumbTintColor = UIKitDesign.textPrimary
            slider.addAction(UIAction { [weak self, weak slider] _ in
                self?.rpe = Double(slider?.value.rounded() ?? 8)
                Haptics.select()
            }, for: .valueChanged)
            stack.addArrangedSubview(slider)
        }
        return stack
    }

    private func textInputRow(
        title: String,
        placeholder: String,
        value: String,
        keyboardType: UIKeyboardType,
        accessibilityIdentifier: String? = nil,
        onChange: @escaping (String) -> Void
    ) -> UIView {
        let stack = UIKitDesign.verticalStack(spacing: Spacing.xs)
        stack.addArrangedSubview(UIKitDesign.label(title, font: UIKitDesign.regular(13), color: UIKitDesign.textSecondary))
        let field = UITextField()
        field.text = value
        field.placeholder = placeholder
        field.keyboardType = keyboardType
        field.delegate = self
        field.accessibilityIdentifier = accessibilityIdentifier
        field.font = UIKitDesign.regular(17)
        field.textColor = UIKitDesign.textPrimary
        field.tintColor = UIKitDesign.textPrimary
        field.backgroundColor = UIKitDesign.surface
        field.layer.borderWidth = UIKitDesign.hairline
        field.layer.borderColor = UIKitDesign.hairlineColor.cgColor
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: Spacing.xs, height: 1))
        field.leftViewMode = .always
        field.translatesAutoresizingMaskIntoConstraints = false
        field.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        field.addAction(UIAction { [weak field] _ in
            onChange(field?.text ?? "")
        }, for: .editingChanged)
        stack.addArrangedSubview(field)
        return stack
    }

    @objc private func planLift() {
        guard let athleteId = ((try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []).first?.id else { return }
        let name = liftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let repo = PlannedSessionRepository(modelContext: modelContext)
        repo.planManualLift(
            athleteId: athleteId,
            liftName: name,
            targetWeightKg: Double(weightText.replacingOccurrences(of: ",", with: ".")),
            targetReps: Int(repsText),
            targetRPE: rpeEnabled ? rpe : nil
        )
        Haptics.success()
        dismiss(animated: true) { [onPlanned] in
            onPlanned()
        }
    }

    @objc private func cancelManual() {
        Haptics.tap()
        dismiss(animated: true)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

private enum WorkoutImportEntryMode {
    case text
    case ai
    case health

    var title: String {
        switch self {
        case .text: "Import Text"
        case .ai: "Import With AI"
        case .health: "Apple Health Import"
        }
    }

    var kicker: String {
        switch self {
        case .text: "Text Import"
        case .ai: "AI Import"
        case .health: "Health Import"
        }
    }

    var body: String {
        switch self {
        case .text:
            "Paste a written program and save parsed strength templates."
        case .ai:
            "Paste messy workout notes for AI-assisted parsing and review."
        case .health:
            "Review recent Health workouts that can be converted into Tuwa sessions."
        }
    }

    var primaryTitle: String {
        switch self {
        case .text: "Import Program"
        case .ai: "Parse With AI"
        case .health: "Scan Health"
        }
    }

    var primaryIdentifier: String {
        switch self {
        case .text: "workoutImport.importText"
        case .ai: "workoutImport.parseAI"
        case .health: "workoutImport.scanHealth"
        }
    }

    var trackingValue: String {
        switch self {
        case .text: "text"
        case .ai: "ai"
        case .health: "health"
        }
    }
}

private struct ParsedUIKitTemplate {
    var name: String
    var exercises: [ParsedUIKitExercise]
}

private struct ParsedUIKitExercise {
    var name: String
    var sets: Int
    var reps: Int
    var weight: Double?
    var rpe: Double?

    var summary: String {
        [
            "\(sets)x\(reps)",
            weight.map { "\(formatNumber($0)) kg" },
            rpe.map { "RPE \(formatNumber($0))" }
        ]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private func formatNumber(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }
}

private final class WorkoutImportEntryViewController: InstrumentScrollViewController, UITextViewDelegate {
    private let container: AppContainer?
    private let modelContext: ModelContext
    private let mode: WorkoutImportEntryMode
    private var inputText = ""
    private var parsedTemplates: [ParsedUIKitTemplate] = []
    private var healthSuggestions: [WorkoutImportSuggestion] = []
    private var message: String?
    private var isWorking = false
    private let actionDock: UIKitBottomActionDock

    init(container: AppContainer?, modelContext: ModelContext, mode: WorkoutImportEntryMode) {
        self.container = container
        self.modelContext = modelContext
        self.mode = mode
        self.actionDock = UIKitBottomActionDock(primaryTitle: mode.primaryTitle)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = mode.title
        let cancel = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(closeImport)
        )
        cancel.accessibilityIdentifier = "workoutImport.cancel"
        navigationItem.leftBarButtonItem = cancel
        actionDock.primaryButton.addTarget(self, action: #selector(commitImport), for: .touchUpInside)
        installBottomActionDock(actionDock)
    }

    override func rebuild() {
        clearContent()
        actionDock.updatePrimary(
            title: isWorking ? "Working..." : mode.primaryTitle,
            isEnabled: canCommit,
            accessibilityIdentifier: mode.primaryIdentifier,
            accessibilityValue: importStateText
        )

        addHorizontalInsets(hero(
            kicker: mode.kicker,
            title: mode.title,
            body: mode.body
        ), top: Spacing.sm)
        addHorizontalInsets(importStatePlate(), top: Spacing.sm)

        switch mode {
        case .text:
            addSection(title: "Program Text", content: dataPlate([
                textEditor(
                    placeholder: "Day 1: Upper Body\nBench Press 4x8 @RPE 7\nBarbell Row 4x8",
                    accessibilityIdentifier: "workoutImport.text"
                )
            ], spacing: Spacing.sm))
            if !parsedTemplates.isEmpty {
                addSection(title: "Preview", content: dataPlate(parsedRows(), spacing: Spacing.sm))
            }
        case .ai:
            addSection(title: "Source", content: dataPlate([
                textEditor(
                    placeholder: "Paste workout notes, screenshots transcribed text, or coach instructions.",
                    accessibilityIdentifier: "workoutImport.aiText"
                )
            ], spacing: Spacing.sm))
            addSection(content: dataPlate([
                UIKitDesign.label("AI-assisted local parsing converts messy notes into templates. Review the preview after import.", font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
            ], spacing: Spacing.sm))
            if !parsedTemplates.isEmpty {
                addSection(title: "Preview", content: dataPlate(parsedRows(), spacing: Spacing.sm))
            }
        case .health:
            addHealthImportSections()
        }

        if let message {
            addSection(content: dataPlate([
                UIKitDesign.label(message, font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
            ], spacing: Spacing.sm))
        }
    }

    private var canCommit: Bool {
        guard !isWorking else { return false }
        switch mode {
        case .text, .ai:
            return !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .health:
            return container != nil
        }
    }

    private var importStateText: String {
        if isWorking {
            return "Working"
        }
        if let message {
            return message
        }
        switch mode {
        case .text:
            return inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Paste a program to enable import"
                : "Ready to parse text"
        case .ai:
            return inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Paste notes to enable AI parsing"
                : "Ready to parse notes"
        case .health:
            if container == nil {
                return "Health import unavailable here"
            }
            if !healthSuggestions.isEmpty {
                return "\(healthSuggestions.count) Health workout\(healthSuggestions.count == 1 ? "" : "s") ready to import"
            }
            return "Ready to scan Health workouts"
        }
    }

    private func importStatePlate() -> UIView {
        let label = UIKitDesign.label(importStateText, font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
        label.accessibilityIdentifier = "workoutImport.state"
        return dataPlate([label], spacing: Spacing.sm)
    }

    private func textEditor(placeholder: String, accessibilityIdentifier: String) -> UIView {
        let textView = UITextView()
        textView.text = inputText.isEmpty ? placeholder : inputText
        textView.textColor = inputText.isEmpty ? UIKitDesign.textTertiary : UIKitDesign.textPrimary
        textView.font = UIKitDesign.regular(17)
        textView.backgroundColor = UIKitDesign.surface
        textView.tintColor = UIKitDesign.textPrimary
        textView.delegate = self
        textView.accessibilityIdentifier = accessibilityIdentifier
        textView.layer.borderWidth = UIKitDesign.hairline
        textView.layer.borderColor = UIKitDesign.hairlineColor.cgColor
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 160).isActive = true
        return textView
    }

    private func parsedRows() -> [UIView] {
        parsedTemplates.enumerated().flatMap { templateIndex, template -> [UIView] in
            var rows: [UIView] = [
                UIKitDesign.label(template.name, font: UIKitDesign.medium(17), color: UIKitDesign.textPrimary, lines: 0)
            ]
            for exercise in template.exercises {
                rows.append(UIKitDesign.label("\(exercise.name) · \(exercise.summary)", font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0))
            }
            if templateIndex < parsedTemplates.count - 1 {
                rows.append(divider())
            }
            return rows
        }
    }

    private func stateRow(title: String, detail: String) -> UIView {
        let stack = UIKitDesign.verticalStack(spacing: Spacing.baselinePair)
        stack.addArrangedSubview(UIKitDesign.label(title, font: UIKitDesign.medium(15), color: UIKitDesign.textPrimary))
        stack.addArrangedSubview(UIKitDesign.label(detail, font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0))
        return stack
    }

    private func addHealthImportSections() {
        addSection(title: "Health Scope", content: dataPlate([
            stateRow(title: "Recent workouts", detail: "Runs, rides, swims, and strength workouts from Apple Health"),
            divider(),
            stateRow(title: "Privacy", detail: "Raw samples stay on device. Tuwa imports only workout summaries."),
            divider(),
            stateRow(title: "Default effort", detail: "Imported summaries use RPE 6 so workload can be computed immediately.")
        ], spacing: Spacing.sm))

        if healthSuggestions.isEmpty {
            addSection(title: "Results", content: dataPlate([
                UIKitDesign.label("No scanned workouts yet", font: UIKitDesign.medium(17), color: UIKitDesign.textPrimary, lines: 0),
                UIKitDesign.label("Use Scan Health to find recent workouts that are not already in Tuwa.", font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
            ], spacing: Spacing.sm))
        } else {
            addSection(title: "Results", content: dataPlate(healthRows(), spacing: Spacing.sm))
        }
    }

    private func healthRows() -> [UIView] {
        healthSuggestions.enumerated().flatMap { index, suggestion -> [UIView] in
            var rows: [UIView] = [healthButton(suggestion)]
            if index < healthSuggestions.count - 1 {
                rows.append(divider())
            }
            return rows
        }
    }

    private func healthButton(_ suggestion: WorkoutImportSuggestion) -> UIView {
        let button = UIButton(type: .custom)
        button.accessibilityIdentifier = "workoutImport.healthSuggestion"
        button.accessibilityLabel = "\(suggestion.name), \(Date.durationString(seconds: suggestion.durationSeconds, locale: .current)), import workout"
        button.addAction(UIAction { [weak self] _ in
            self?.importHealthSuggestion(suggestion)
        }, for: .touchUpInside)

        let subtitle = [
            suggestion.date.relativeString(locale: .current),
            Date.durationString(seconds: suggestion.durationSeconds, locale: .current),
            suggestion.activeCalories.map { "\(Int($0)) kcal" },
            suggestion.distanceMeters.map { String(format: "%.1f km", $0 / 1000) }
        ]
            .compactMap { $0 }
            .joined(separator: " · ")
        let row = disclosureRow(
            title: suggestion.name,
            subtitle: "\(suggestion.sportType.displayName) · \(subtitle)",
            trailing: "Import"
        )
        row.isUserInteractionEnabled = false
        button.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            row.topAnchor.constraint(equalTo: button.topAnchor),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return button
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == UIKitDesign.textTertiary {
            textView.text = ""
            textView.textColor = UIKitDesign.textPrimary
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        inputText = textView.text ?? ""
        message = nil
        parsedTemplates = []
        actionDock.updatePrimary(
            title: mode.primaryTitle,
            isEnabled: canCommit,
            accessibilityIdentifier: mode.primaryIdentifier,
            accessibilityValue: importStateText
        )
    }

    @objc private func commitImport() {
        guard canCommit else { return }
        Haptics.tap()
        container?.uxAnalyticsService.track(.primaryActionTapped, properties: [
            "surface": "workout_import",
            "action": mode.primaryIdentifier,
            "mode": mode.trackingValue
        ])
        switch mode {
        case .text:
            importTextProgram()
        case .ai:
            importAIProgram()
        case .health:
            scanHealthWorkouts()
        }
    }

    private func importAIProgram() {
        importParsedProgram(
            successPrefix: "Parsed and imported",
            failureMessage: "Could not parse notes. Try: Bench Press 4x8 @RPE 7"
        )
    }

    private func importTextProgram() {
        importParsedProgram(
            successPrefix: "Imported",
            failureMessage: "Could not parse exercises. Try: Bench Press 4x8 @RPE 7"
        )
    }

    private func importParsedProgram(successPrefix: String, failureMessage: String) {
        let parsed = parseProgram(inputText)
        guard !parsed.isEmpty else {
            message = failureMessage
            rebuild()
            return
        }
        parsedTemplates = parsed
        guard let ownerId = ((try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []).first?.id else {
            message = "No athlete profile available."
            rebuild()
            return
        }

        for parsedTemplate in parsed {
            let template = WorkoutTemplate(
                coachId: ownerId,
                templateName: parsedTemplate.name,
                sportType: .lifting,
                sessionType: .strength
            )
            template.athleteId = ownerId
            template.isAthleteOwned = true
            let group = ExerciseGroup(groupName: "Main", orderIndex: 0)
            group.template = template
            for (exerciseIndex, parsedExercise) in parsedTemplate.exercises.enumerated() {
                let exercise = TemplateExercise(
                    exerciseName: parsedExercise.name,
                    exerciseCategory: .compound,
                    orderIndex: exerciseIndex
                )
                exercise.group = group
                for setIndex in 0..<parsedExercise.sets {
                    let set = TemplateSet(
                        setIndex: setIndex,
                        targetReps: parsedExercise.reps,
                        targetWeightKg: parsedExercise.weight,
                        targetRPE: parsedExercise.rpe
                    )
                    set.exercise = exercise
                    exercise.sets.append(set)
                }
                group.exercises.append(exercise)
            }
            template.groups.append(group)
            modelContext.insert(template)
        }

        do {
            try modelContext.save()
            Haptics.success()
            message = "\(successPrefix) \(parsed.count) template\(parsed.count == 1 ? "" : "s")."
        } catch {
            message = "Could not save imported templates."
        }
        rebuild()
    }

    private func scanHealthWorkouts() {
        guard let healthKit = container?.healthKitService else {
            message = "Health import unavailable here."
            rebuild()
            return
        }
        isWorking = true
        message = "Scanning Health workouts"
        rebuild()

        Task { [weak self] in
            guard let self else { return }
            let suggestions = await WorkoutImportService.findUnmatchedWorkouts(
                healthKit: healthKit,
                modelContext: modelContext
            )
            healthSuggestions = suggestions
            isWorking = false
            message = suggestions.isEmpty
                ? "No unmatched Health workouts found."
                : "Found \(suggestions.count) Health workout\(suggestions.count == 1 ? "" : "s"). Choose one to import."
            Haptics.select()
            rebuild()
        }
    }

    private func importHealthSuggestion(_ suggestion: WorkoutImportSuggestion) {
        guard let container,
              let athlete = currentAthlete(in: modelContext) else {
            message = "No athlete profile available."
            rebuild()
            return
        }
        Haptics.tap()
        let session = WorkoutImportService.createSession(
            from: suggestion,
            sessionRPE: 6,
            athlete: athlete,
            modelContext: modelContext
        )
        modelContext.insert(session)

        do {
            try modelContext.save()
            _ = try WorkoutPipeline.processSession(
                session,
                athlete: athlete,
                modelContext: modelContext,
                syncService: container.syncService
            )
            WorkoutImportService.dismissSuggestion(suggestion)
            healthSuggestions.removeAll { $0.id == suggestion.id }
            message = "Imported \(suggestion.name)."
            Haptics.success()
        } catch {
            message = "Could not import Health workout."
        }
        rebuild()
    }

    private func parseProgram(_ source: String) -> [ParsedUIKitTemplate] {
        var templates: [ParsedUIKitTemplate] = []
        var current = ParsedUIKitTemplate(name: "Imported Workout", exercises: [])

        for rawLine in source.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            if isHeader(line) {
                if !current.exercises.isEmpty {
                    templates.append(current)
                }
                current = ParsedUIKitTemplate(name: cleanHeader(line), exercises: [])
            } else if let exercise = parseExercise(line) {
                current.exercises.append(exercise)
            }
        }

        if !current.exercises.isEmpty {
            templates.append(current)
        }
        return templates
    }

    private func isHeader(_ line: String) -> Bool {
        let lower = line.lowercased()
        return lower.hasPrefix("day ")
            || lower.hasPrefix("session ")
            || lower.hasPrefix("workout ")
            || (lower.contains(":") && !lower.contains("x"))
    }

    private func cleanHeader(_ line: String) -> String {
        guard let colonIndex = line.firstIndex(of: ":") else {
            return line
        }
        let name = line[line.index(after: colonIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? line : name
    }

    private func parseExercise(_ line: String) -> ParsedUIKitExercise? {
        let pattern = #"(.+?)\s+(\d+)\s*[xX]\s*(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let nameRange = Range(match.range(at: 1), in: line),
              let setsRange = Range(match.range(at: 2), in: line),
              let repsRange = Range(match.range(at: 3), in: line) else {
            let name = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.count > 2 ? ParsedUIKitExercise(name: name, sets: 3, reps: 10, weight: nil, rpe: nil) : nil
        }

        let name = String(line[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        let sets = Int(line[setsRange]) ?? 3
        let reps = Int(line[repsRange]) ?? 10
        let remainder = String(line[repsRange.upperBound...]).lowercased()
        let rpe = firstNumber(in: remainder, matching: #"@?\s*rpe\s*(\d+\.?\d*)"#)
        let weight = firstNumber(in: remainder, matching: #"@?\s*(\d+\.?\d*)\s*kg"#)
        return ParsedUIKitExercise(name: name, sets: sets, reps: reps, weight: weight, rpe: rpe)
    }

    private func firstNumber(in text: String, matching pattern: String) -> Double? {
        guard let range = text.range(of: pattern, options: .regularExpression) else { return nil }
        let token = text[range]
            .components(separatedBy: CharacterSet.decimalDigits.union(CharacterSet(charactersIn: ".")).inverted)
            .joined()
        return Double(token)
    }

    @objc private func closeImport() {
        Haptics.tap()
        if let navigationController, navigationController.viewControllers.first !== self {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}

private final class TemplatePickerViewController: InstrumentScrollViewController {
    private let container: AppContainer?
    private let modelContext: ModelContext
    private let locale: Locale
    private let showUnifiedRoutes: Bool
    private let onSelectTemplate: (WorkoutTemplate) -> Void
    private let onStartBlank: () -> Void
    private let onCreateTemplate: () -> Void
    private let onPlanToday: (() -> Void)?
    private let actionDock = UIKitBottomActionDock(primaryTitle: "Start Blank Workout", secondaryTitle: "Create Template")

    init(
        container: AppContainer? = nil,
        modelContext: ModelContext,
        locale: Locale,
        showUnifiedRoutes: Bool = false,
        onSelectTemplate: @escaping (WorkoutTemplate) -> Void,
        onStartBlank: @escaping () -> Void,
        onCreateTemplate: @escaping () -> Void,
        onPlanToday: (() -> Void)? = nil
    ) {
        self.container = container
        self.modelContext = modelContext
        self.locale = locale
        self.showUnifiedRoutes = showUnifiedRoutes
        self.onSelectTemplate = onSelectTemplate
        self.onStartBlank = onStartBlank
        self.onCreateTemplate = onCreateTemplate
        self.onPlanToday = onPlanToday
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = showUnifiedRoutes ? "Start Workout" : "Choose Template"
        let cancelItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(cancelPicker)
        )
        cancelItem.accessibilityIdentifier = "templatePicker.cancel"
        navigationItem.leftBarButtonItem = cancelItem
        actionDock.primaryButton.addTarget(self, action: #selector(startBlank), for: .touchUpInside)
        actionDock.secondaryButton.addTarget(self, action: #selector(createTemplate), for: .touchUpInside)
        installBottomActionDock(actionDock)
    }

    override func rebuild() {
        clearContent()
        let templates = loadTemplates()
        actionDock.updatePrimary(
            title: "Start Blank Workout",
            accessibilityIdentifier: "templatePicker.startBlank",
            accessibilityValue: "Primary action"
        )
        actionDock.updateSecondary(
            title: "Create Template",
            accessibilityIdentifier: "templatePicker.createTemplate",
            accessibilityValue: "Secondary action"
        )
        addHorizontalInsets(hero(
            kicker: showUnifiedRoutes ? "Train" : "Templates",
            title: templates.isEmpty ? "Start blank" : "Choose a session",
            body: templates.isEmpty
                ? "No saved templates yet. Start blank, import, or create a reusable plan."
                : "Start blank, pick a program, plan today, or import a workout."
        ), top: Spacing.sm)
        if showUnifiedRoutes {
            addHorizontalInsets(startStatePlate(), top: Spacing.sm)
        }

        if templates.isEmpty {
            addSection(content: dataPlate([
                UIKitDesign.label("No templates", font: UIKitDesign.medium(19), color: UIKitDesign.textPrimary),
                UIKitDesign.label("Create a template for repeated sessions, or begin with a blank workout now.", font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
            ], spacing: Spacing.sm))
        } else {
            var rows: [UIView] = []
            for (index, template) in templates.enumerated() {
                rows.append(templateButton(template))
                if index < templates.count - 1 {
                    rows.append(divider())
                }
            }
            addSection(title: "Saved templates", content: dataPlate(rows, spacing: Spacing.sm))
        }

        if showUnifiedRoutes {
            addSection(title: "Add Workout", content: dataPlate(unifiedRows(), spacing: Spacing.sm))
        }

        let actionHint = UIKitDesign.label(
            showUnifiedRoutes
                ? "All start, planning, and import paths live here so training starts from one place."
                : "Use the bottom actions to start blank or create a new reusable template.",
            font: UIKitDesign.regular(13),
            color: UIKitDesign.textTertiary,
            lines: 0
        )
        actionHint.translatesAutoresizingMaskIntoConstraints = false
        actionHint.accessibilityIdentifier = "templatePicker.actionHint"
        addHorizontalInsets(actionHint, top: Spacing.lg, bottom: Spacing.xl)
    }

    private func loadTemplates() -> [WorkoutTemplate] {
        let athletes = (try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []
        guard let athleteId = athletes.first?.id else { return [] }
        return ((try? modelContext.fetch(FetchDescriptor<WorkoutTemplate>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))) ?? [])
            .filter {
                !$0.isArchived && ($0.athleteId == athleteId || $0.coachId == athleteId)
            }
    }

    private func startStatePlate() -> UIView {
        let label = UIKitDesign.label(
            "Choose one route. Blank and program starts remain available without hidden gestures.",
            font: UIKitDesign.regular(15),
            color: UIKitDesign.textSecondary,
            lines: 0
        )
        label.accessibilityIdentifier = "workoutStart.state"
        return dataPlate([label], spacing: Spacing.sm)
    }

    private func unifiedRows() -> [UIView] {
        [
            actionRow(
                title: "Plan today",
                subtitle: "Prepare a session before starting",
                accessibilityIdentifier: "workoutStart.planToday",
                action: #selector(planToday)
            ),
            divider(),
            actionRow(
                title: "Import text",
                subtitle: "Paste a written program into Tuwa templates",
                accessibilityIdentifier: "workoutStart.importText",
                action: #selector(importText)
            ),
            divider(),
            actionRow(
                title: "Import with AI",
                subtitle: "Parse messy notes before reviewing the result",
                accessibilityIdentifier: "workoutStart.importAI",
                action: #selector(importAI)
            ),
            divider(),
            actionRow(
                title: "Import Apple Health workout",
                subtitle: "Match recent Health workouts to Tuwa sessions",
                accessibilityIdentifier: "workoutStart.importHealth",
                action: #selector(importHealth)
            )
        ]
    }

    private func templateButton(_ template: WorkoutTemplate) -> UIView {
        let button = UIButton(type: .custom)
        button.accessibilityIdentifier = "templatePicker.template"
        button.accessibilityLabel = "\(template.templateName), \(template.sortedGroups.flatMap(\.sortedExercises).count) exercises"
        button.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            Haptics.select()
            self.dismiss(animated: true) {
                self.onSelectTemplate(template)
            }
        }, for: .touchUpInside)

        let row = disclosureRow(
            title: template.templateName,
            subtitle: "\(template.sessionType.displayName) · \(template.sortedGroups.flatMap(\.sortedExercises).count) exercises",
            trailing: template.lastUsedAt?.relativeString(locale: locale)
        )
        row.isUserInteractionEnabled = false
        button.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            row.topAnchor.constraint(equalTo: button.topAnchor),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return button
    }

    private func actionRow(
        title: String,
        subtitle: String,
        accessibilityIdentifier: String,
        action: Selector
    ) -> UIView {
        let button = UIButton(type: .custom)
        button.accessibilityIdentifier = accessibilityIdentifier
        button.accessibilityLabel = "\(title), \(subtitle)"
        button.addTarget(self, action: action, for: .touchUpInside)
        let row = disclosureRow(title: title, subtitle: subtitle)
        row.isUserInteractionEnabled = false
        button.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            row.topAnchor.constraint(equalTo: button.topAnchor),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return button
    }

    @objc private func startBlank() {
        Haptics.tap()
        dismiss(animated: true) { [onStartBlank] in
            onStartBlank()
        }
    }

    @objc private func createTemplate() {
        Haptics.tap()
        dismiss(animated: true) { [onCreateTemplate] in
            onCreateTemplate()
        }
    }

    @objc private func planToday() {
        Haptics.tap()
        container?.uxAnalyticsService.track(.todayPlanDecisionMade, properties: [
            "surface": "workout_start",
            "decision": "open_plan_today"
        ])
        dismiss(animated: true) { [onPlanToday] in
            onPlanToday?()
        }
    }

    @objc private func importText() {
        openImport(mode: .text)
    }

    @objc private func importAI() {
        openImport(mode: .ai)
    }

    @objc private func importHealth() {
        openImport(mode: .health)
    }

    private func openImport(mode: WorkoutImportEntryMode) {
        Haptics.tap()
        container?.uxAnalyticsService.track(.workoutImportStarted, properties: [
            "mode": mode.trackingValue,
            "stage": "opened"
        ])
        let controller = WorkoutImportEntryViewController(
            container: container,
            modelContext: modelContext,
            mode: mode
        )
        showInstrumentDetail(controller)
    }

    @objc private func cancelPicker() {
        Haptics.tap()
        dismiss(animated: true)
    }
}

private struct TemplateGroupDraft {
    let id = UUID()
    var groupName: String
    var exercises: [TemplateExerciseDraft] = []
}

private struct TemplateExerciseDraft {
    let id = UUID()
    var exerciseName: String
    var exerciseCategory: ExerciseCategory
    var muscleGroup: MuscleGroup?
    var sets: [TemplateTargetSetDraft] = [TemplateTargetSetDraft()]
}

private struct TemplateTargetSetDraft {
    let id = UUID()
    var targetReps: Int?
    var targetWeightKg: Double?
    var targetDurationSeconds: Int?
    var targetDistanceMeters: Double?
    var targetRPE: Double?
    var targetRIR: Int?
    var isWarmup = false

    var targetDurationMinutes: Double? {
        get { targetDurationSeconds.map { Double($0) / 60.0 } }
        set { targetDurationSeconds = newValue.map { Int($0 * 60.0) } }
    }
}

private final class TemplateManagerViewController: InstrumentScrollViewController {
    private let container: AppContainer
    private let modelContext: ModelContext
    private let locale: Locale
    private let newTemplatesAreAthleteOwned: Bool

    init(
        container: AppContainer,
        modelContext: ModelContext,
        locale: Locale,
        newTemplatesAreAthleteOwned: Bool
    ) {
        self.container = container
        self.modelContext = modelContext
        self.locale = locale
        self.newTemplatesAreAthleteOwned = newTemplatesAreAthleteOwned
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Templates"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Done",
            style: .plain,
            target: self,
            action: #selector(closeManager)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "New",
            style: .done,
            target: self,
            action: #selector(newTemplate)
        )
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "templateManager.new"
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        rebuild()
    }

    override func rebuild() {
        clearContent()
        let templates = loadTemplates()
        let exerciseCount = templates.reduce(0) { $0 + $1.sortedGroups.flatMap(\.sortedExercises).count }
        addHorizontalInsets(hero(
            kicker: "Plans",
            title: "Template manager",
            body: "\(templates.count) active templates · \(exerciseCount) exercises"
        ), top: Spacing.sm)

        addSection(
            title: "Scope",
            content: metricRail([
                ("Templates", "\(templates.count)", "Active"),
                ("Favorites", "\(templates.filter(\.isFavorite).count)", "Pinned"),
                ("Scheduled", "\(templates.filter { !$0.scheduledDays.isEmpty }.count)", "Weekly")
            ])
        )

        if templates.isEmpty {
            addSection(content: dataPlate([
                UIKitDesign.label("No templates", font: UIKitDesign.medium(19), color: UIKitDesign.textPrimary),
                UIKitDesign.label("Create the first reusable session plan for this account.", font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0),
                actionButton(title: "New Template", action: #selector(newTemplate))
            ], spacing: Spacing.sm))
            return
        }

        var rows: [UIView] = []
        for (index, template) in templates.enumerated() {
            rows.append(templateButton(template))
            if index < templates.count - 1 {
                rows.append(divider())
            }
        }
        addSection(title: "Templates", content: dataPlate(rows, spacing: Spacing.sm))
    }

    private func currentOwnerId() -> UUID? {
        ((try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []).first?.id
    }

    private func loadTemplates() -> [WorkoutTemplate] {
        guard let ownerId = currentOwnerId() else { return [] }
        return ((try? modelContext.fetch(FetchDescriptor<WorkoutTemplate>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))) ?? [])
            .filter { $0.coachId == ownerId && !$0.isArchived }
    }

    private func templateButton(_ template: WorkoutTemplate) -> UIView {
        let button = UIButton(type: .custom)
        button.accessibilityIdentifier = "templateManager.template"
        button.accessibilityLabel = template.templateName
        button.addAction(UIAction { [weak self] _ in
            self?.openPreview(template)
        }, for: .touchUpInside)

        let groupCount = template.sortedGroups.count
        let exerciseCount = template.sortedGroups.flatMap(\.sortedExercises).count
        let schedule = weekdayInitials(for: template.scheduledDays)
        let detail = [
            "\(groupCount) group\(groupCount == 1 ? "" : "s")",
            "\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")",
            schedule.isEmpty ? nil : schedule
        ]
            .compactMap { $0 }
            .joined(separator: " · ")
        let row = disclosureRow(
            title: template.templateName,
            subtitle: detail,
            trailing: template.isFavorite ? "Favorite" : template.sessionType.displayName
        )
        row.isUserInteractionEnabled = false
        button.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            row.topAnchor.constraint(equalTo: button.topAnchor),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return button
    }

    private func weekdayInitials(for days: [Int]) -> String {
        guard !days.isEmpty else { return "" }
        let labels = [1: "M", 2: "T", 3: "W", 4: "T", 5: "F", 6: "S", 7: "S"]
        return days.sorted().compactMap { labels[$0] }.joined()
    }

    private func openPreview(_ template: WorkoutTemplate) {
        guard let ownerId = currentOwnerId() else { return }
        Haptics.tap()
        let controller = TemplatePreviewViewController(
            container: container,
            modelContext: modelContext,
            locale: locale,
            ownerId: ownerId,
            template: template,
            newTemplatesAreAthleteOwned: newTemplatesAreAthleteOwned,
            onSave: { [weak self] in
                self?.rebuild()
            }
        )
        showInstrumentDetail(controller)
    }

    private func openEditor(existingTemplate: WorkoutTemplate?) {
        guard let ownerId = currentOwnerId() else { return }
        Haptics.tap()
        let controller = TemplateEditorViewController(
            container: container,
            modelContext: modelContext,
            locale: locale,
            ownerId: ownerId,
            existingTemplate: existingTemplate,
            newTemplatesAreAthleteOwned: newTemplatesAreAthleteOwned,
            onSave: { [weak self] in
                self?.rebuild()
            }
        )
        present(InstrumentNavigationController(rootViewController: controller), animated: true)
    }

    @objc private func newTemplate() {
        openEditor(existingTemplate: nil)
    }

    @objc private func closeManager() {
        Haptics.tap()
        dismiss(animated: true)
    }
}

private final class TemplatePreviewViewController: InstrumentScrollViewController {
    private let container: AppContainer
    private let modelContext: ModelContext
    private let locale: Locale
    private let ownerId: UUID
    private let template: WorkoutTemplate
    private let newTemplatesAreAthleteOwned: Bool
    private let onSave: () -> Void
    private let actionDock = UIKitBottomActionDock(primaryTitle: "Edit Template")

    init(
        container: AppContainer,
        modelContext: ModelContext,
        locale: Locale,
        ownerId: UUID,
        template: WorkoutTemplate,
        newTemplatesAreAthleteOwned: Bool,
        onSave: @escaping () -> Void
    ) {
        self.container = container
        self.modelContext = modelContext
        self.locale = locale
        self.ownerId = ownerId
        self.template = template
        self.newTemplatesAreAthleteOwned = newTemplatesAreAthleteOwned
        self.onSave = onSave
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Template Preview"
        actionDock.primaryButton.addTarget(self, action: #selector(openEditor), for: .touchUpInside)
        installBottomActionDock(actionDock)
    }

    override func rebuild() {
        clearContent()
        actionDock.updatePrimary(
            title: "Edit Template",
            accessibilityIdentifier: "templatePreview.edit",
            accessibilityValue: templatePreviewStateText
        )
        addHorizontalInsets(hero(
            kicker: template.sportType.displayName,
            title: template.templateName,
            body: template.notes?.isEmpty == false ? template.notes ?? "" : templatePreviewStateText
        ), top: Spacing.sm)
        addHorizontalInsets(templatePreviewStatePlate(), top: Spacing.sm)
        addSection(
            title: "Summary",
            content: metricRail([
                ("Groups", "\(template.sortedGroups.count)", "Blocks"),
                ("Exercises", "\(exerciseCount)", "Movements"),
                ("Sets", "\(setCount)", "Targets")
            ])
        )

        if template.sortedGroups.isEmpty {
            addSection(content: dataPlate([
                UIKitDesign.label("No exercise groups", font: UIKitDesign.medium(19), color: UIKitDesign.textPrimary),
                UIKitDesign.label("Edit the template to add exercises and target sets.", font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
            ], spacing: Spacing.sm))
            return
        }

        for group in template.sortedGroups {
            addSection(title: group.groupName, content: groupPlate(group))
        }
    }

    private var exerciseCount: Int {
        template.sortedGroups.flatMap(\.sortedExercises).count
    }

    private var setCount: Int {
        template.sortedGroups.flatMap(\.sortedExercises).flatMap(\.sortedSets).count
    }

    private var templatePreviewStateText: String {
        let schedule = weekdayNames(for: template.scheduledDays)
        let usage = template.usageCount == 0
            ? "Not started yet"
            : "\(template.usageCount) start\(template.usageCount == 1 ? "" : "s")"
        return [
            "\(template.sessionType.displayName) · \(exerciseCount) exercises · \(setCount) sets",
            schedule.isEmpty ? nil : schedule,
            usage
        ]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private func templatePreviewStatePlate() -> UIView {
        let label = UIKitDesign.label(
            templatePreviewStateText,
            font: UIKitDesign.regular(15),
            color: UIKitDesign.textSecondary,
            lines: 0
        )
        label.accessibilityIdentifier = "templatePreview.state"
        return dataPlate([label], spacing: Spacing.sm)
    }

    private func groupPlate(_ group: ExerciseGroup) -> UIView {
        if group.sortedExercises.isEmpty {
            return dataPlate([
                UIKitDesign.label("No exercises in this group", font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
            ], spacing: Spacing.sm)
        }

        var rows: [UIView] = []
        for (index, exercise) in group.sortedExercises.enumerated() {
            rows.append(exerciseRow(exercise))
            if index < group.sortedExercises.count - 1 {
                rows.append(divider())
            }
        }
        return dataPlate(rows, spacing: Spacing.sm)
    }

    private func exerciseRow(_ exercise: TemplateExercise) -> UIView {
        let row = disclosureRow(
            title: exercise.exerciseName,
            subtitle: exerciseSummary(exercise),
            trailing: "\(exercise.sortedSets.count) set\(exercise.sortedSets.count == 1 ? "" : "s")"
        )
        row.isAccessibilityElement = true
        row.accessibilityIdentifier = "templatePreview.exercise"
        row.accessibilityLabel = "\(exercise.exerciseName), \(exerciseSummary(exercise))"
        return row
    }

    private func exerciseSummary(_ exercise: TemplateExercise) -> String {
        let target = exercise.sortedSets.first.map(setSummary) ?? "No target sets"
        return [
            exercise.exerciseCategory.displayName,
            exercise.muscleGroup?.displayName,
            target
        ]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private func setSummary(_ set: TemplateSet) -> String {
        let parts = [
            set.targetWeightKg.map { "\(formatNumber($0)) kg" },
            set.targetReps.map { "\($0) reps" },
            set.targetDistanceMeters.map { "\(formatNumber($0)) m" },
            set.targetDurationSeconds.map { Date.durationString(seconds: $0, locale: locale) },
            set.targetRPE.map { "RPE \(formatNumber($0))" },
            set.targetRIR.map { "RIR \($0)" },
            set.isWarmup ? "Warm-up" : nil
        ]
            .compactMap { $0 }
        return parts.isEmpty ? "Open target" : parts.joined(separator: " · ")
    }

    private func weekdayNames(for days: [Int]) -> String {
        guard !days.isEmpty else { return "" }
        let formatter = DateFormatter()
        formatter.locale = locale
        let symbols = formatter.shortWeekdaySymbols ?? []
        let calendarIndexByISO = [1: 1, 2: 2, 3: 3, 4: 4, 5: 5, 6: 6, 7: 0]
        return days.sorted().compactMap { day in
            guard let index = calendarIndexByISO[day], symbols.indices.contains(index) else { return nil }
            return symbols[index]
        }.joined(separator: ", ")
    }

    private func formatNumber(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    @objc private func openEditor() {
        Haptics.tap()
        let controller = TemplateEditorViewController(
            container: container,
            modelContext: modelContext,
            locale: locale,
            ownerId: ownerId,
            existingTemplate: template,
            newTemplatesAreAthleteOwned: newTemplatesAreAthleteOwned,
            onSave: { [weak self] in
                self?.onSave()
                self?.rebuild()
            }
        )
        present(InstrumentNavigationController(rootViewController: controller), animated: true)
    }
}

private final class TemplateEditorViewController: InstrumentScrollViewController, UITextFieldDelegate {
    private let container: AppContainer
    private let modelContext: ModelContext
    private let locale: Locale
    private let ownerId: UUID
    private let existingTemplate: WorkoutTemplate?
    private let newTemplatesAreAthleteOwned: Bool
    private let onSave: (() -> Void)?

    private var templateName = ""
    private var sportType: SportType = .lifting
    private var sessionType: SessionType = .strength
    private var notes = ""
    private var scheduledDays: [Int] = []
    private var isFavorite = false
    private var groups: [TemplateGroupDraft] = [TemplateGroupDraft(groupName: "Main")]
    private var activeGroupIndex = 0
    private var didLoadExisting = false
    private let actionDock = UIKitBottomActionDock(primaryTitle: "Save Template")

    init(
        container: AppContainer,
        modelContext: ModelContext,
        locale: Locale,
        ownerId: UUID,
        existingTemplate: WorkoutTemplate?,
        newTemplatesAreAthleteOwned: Bool,
        onSave: (() -> Void)? = nil
    ) {
        self.container = container
        self.modelContext = modelContext
        self.locale = locale
        self.ownerId = ownerId
        self.existingTemplate = existingTemplate
        self.newTemplatesAreAthleteOwned = newTemplatesAreAthleteOwned
        self.onSave = onSave
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = existingTemplate == nil ? "New Template" : "Edit Template"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(cancelEditor)
        )
        navigationItem.leftBarButtonItem?.accessibilityIdentifier = "templateEditor.cancel"
        actionDock.primaryButton.addTarget(self, action: #selector(saveTemplate), for: .touchUpInside)
        installBottomActionDock(actionDock)
        loadExistingIfNeeded()
    }

    override func rebuild() {
        loadExistingIfNeeded()
        clearContent()
        actionDock.updatePrimary(
            title: "Save Template",
            isEnabled: canSave,
            accessibilityIdentifier: "templateEditor.save",
            accessibilityValue: templateEditorStateText
        )

        addHorizontalInsets(hero(
            kicker: existingTemplate == nil ? "Template" : "Editing",
            title: templateName.isEmpty ? "Untitled session" : templateName,
            body: "\(sportType.displayName) · \(sessionType.displayName) · \(totalSetCount) target sets"
        ), top: Spacing.sm)
        addHorizontalInsets(templateEditorStatePlate(), top: Spacing.sm)

        addSection(title: "Details", content: dataPlate(detailRows(), spacing: Spacing.sm))
        addSection(title: "Schedule", content: dataPlate([
            weekdayRow(),
            divider(),
            compactButtonRow([
                (isFavorite ? "Favorite" : "Mark Favorite", { [weak self] in
                    guard let self else { return }
                    self.isFavorite.toggle()
                    Haptics.select()
                    self.rebuild()
                })
            ])
        ], spacing: Spacing.sm))

        for (index, group) in groups.enumerated() {
            addSection(title: group.groupName.isEmpty ? "Group \(index + 1)" : group.groupName, content: groupPlate(groupIndex: index, group: group))
        }

        let addGroupButton = actionButton(title: "Add Group", action: #selector(addGroup))
        addGroupButton.accessibilityIdentifier = "templateEditor.addGroup"
        addHorizontalInsets(addGroupButton, top: Spacing.lg, bottom: Spacing.xl)
    }

    private var canSave: Bool {
        !templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var templateEditorStateText: String {
        if canSave {
            return totalSetCount == 0 ? "Ready to save without target sets" : "Ready to save"
        }
        return "Template name required"
    }

    private func templateEditorStatePlate() -> UIView {
        let label = UIKitDesign.label(templateEditorStateText, font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
        label.accessibilityIdentifier = "templateEditor.state"
        return dataPlate([label], spacing: Spacing.sm)
    }

    private var totalSetCount: Int {
        groups.reduce(0) { groupCount, group in
            groupCount + group.exercises.reduce(0) { $0 + $1.sets.count }
        }
    }

    private func loadExistingIfNeeded() {
        guard !didLoadExisting else { return }
        didLoadExisting = true
        guard let template = existingTemplate else { return }
        templateName = template.templateName
        sportType = template.sportType
        sessionType = template.sessionType
        notes = template.notes ?? ""
        scheduledDays = template.scheduledDays
        isFavorite = template.isFavorite
        groups = template.sortedGroups.map { group in
            var groupDraft = TemplateGroupDraft(groupName: group.groupName)
            groupDraft.exercises = group.sortedExercises.map { exercise in
                var exerciseDraft = TemplateExerciseDraft(
                    exerciseName: exercise.exerciseName,
                    exerciseCategory: exercise.exerciseCategory,
                    muscleGroup: exercise.muscleGroup
                )
                exerciseDraft.sets = exercise.sortedSets.map { set in
                    TemplateTargetSetDraft(
                        targetReps: set.targetReps,
                        targetWeightKg: set.targetWeightKg,
                        targetDurationSeconds: set.targetDurationSeconds,
                        targetDistanceMeters: set.targetDistanceMeters,
                        targetRPE: set.targetRPE,
                        targetRIR: set.targetRIR,
                        isWarmup: set.isWarmup
                    )
                }
                if exerciseDraft.sets.isEmpty {
                    exerciseDraft.sets = [TemplateTargetSetDraft()]
                }
                return exerciseDraft
            }
            return groupDraft
        }
        if groups.isEmpty {
            groups = [TemplateGroupDraft(groupName: "Main")]
        }
    }

    private func detailRows() -> [UIView] {
        [
            textInputRow(
                title: "Template Name",
                placeholder: "Required",
                value: templateName,
                keyboardType: .default,
            accessibilityIdentifier: "templateEditor.name"
        ) { [weak self] value in
            self?.templateName = value
            self?.actionDock.updatePrimary(
                title: "Save Template",
                isEnabled: self?.canSave == true,
                accessibilityIdentifier: "templateEditor.save",
                accessibilityValue: self?.templateEditorStateText
            )
        },
            divider(),
            choiceRow(title: "Sport", value: sportType.displayName, action: #selector(chooseSportType)),
            divider(),
            choiceRow(title: "Type", value: sessionType.displayName, action: #selector(chooseSessionType)),
            divider(),
            textInputRow(
                title: "Notes",
                placeholder: "Optional",
                value: notes,
                keyboardType: .default
            ) { [weak self] value in
                self?.notes = value
            }
        ]
    }

    private func weekdayRow() -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Spacing.xs
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false

        let days = [(1, "M"), (2, "T"), (3, "W"), (4, "T"), (5, "F"), (6, "S"), (7, "S")]
        for day in days {
            let selected = scheduledDays.contains(day.0)
            let button = UIButton(type: .custom)
            button.setTitle(day.1, for: .normal)
            button.setTitleColor(selected ? UIKitDesign.background : UIKitDesign.textSecondary, for: .normal)
            button.titleLabel?.font = UIKitDesign.medium(15)
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.backgroundColor = selected ? UIKitDesign.textPrimary : UIKitDesign.surface
            button.layer.borderWidth = UIKitDesign.hairline
            button.layer.borderColor = UIKitDesign.hairlineColor.cgColor
            button.heightAnchor.constraint(equalToConstant: 40).isActive = true
            button.accessibilityLabel = "Schedule \(day.1)"
            button.accessibilityTraits = selected ? [.button, .selected] : .button
            button.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                if self.scheduledDays.contains(day.0) {
                    self.scheduledDays.removeAll { $0 == day.0 }
                } else {
                    self.scheduledDays.append(day.0)
                    self.scheduledDays.sort()
                }
                Haptics.select()
                self.rebuild()
            }, for: .touchUpInside)
            stack.addArrangedSubview(button)
        }
        return stack
    }

    private func groupPlate(groupIndex: Int, group: TemplateGroupDraft) -> UIView {
        var rows: [UIView] = [
            textInputRow(
                title: "Group Name",
                placeholder: "Main",
                value: group.groupName,
                keyboardType: .default
            ) { [weak self] value in
                guard let self, self.groups.indices.contains(groupIndex) else { return }
                self.groups[groupIndex].groupName = value
            }
        ]

        if group.exercises.isEmpty {
            rows.append(divider())
            rows.append(UIKitDesign.label("No exercises in this group", font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary))
        } else {
            for (exerciseIndex, exercise) in group.exercises.enumerated() {
                rows.append(divider())
                rows.append(exercisePlate(groupIndex: groupIndex, exerciseIndex: exerciseIndex, exercise: exercise))
            }
        }

        rows.append(divider())
        rows.append(compactButtonRow(groupActions(groupIndex: groupIndex)))
        return dataPlate(rows, spacing: Spacing.sm)
    }

    private func groupActions(groupIndex: Int) -> [(String, () -> Void)] {
        var actions: [(String, () -> Void)] = [
            ("Add Exercise", { [weak self] in
                self?.openExercisePicker(groupIndex: groupIndex)
            })
        ]
        if groups.count > 1 {
            actions.append(("Remove Group", { [weak self] in
                guard let self, self.groups.indices.contains(groupIndex) else { return }
                self.groups.remove(at: groupIndex)
                Haptics.tap()
                self.rebuild()
            }))
        }
        return actions
    }

    private func exercisePlate(groupIndex: Int, exerciseIndex: Int, exercise: TemplateExerciseDraft) -> UIView {
        let stack = UIKitDesign.verticalStack(spacing: Spacing.sm)
        let subtitle = [
            exercise.exerciseCategory.displayName,
            exercise.muscleGroup?.displayName
        ]
            .compactMap { $0 }
            .joined(separator: " · ")

        stack.addArrangedSubview(UIKitDesign.label(exercise.exerciseName, font: UIKitDesign.medium(17), color: UIKitDesign.textPrimary, lines: 0))
        if !subtitle.isEmpty {
            stack.addArrangedSubview(UIKitDesign.label(subtitle, font: UIKitDesign.regular(13), color: UIKitDesign.textSecondary, lines: 0))
        }
        stack.addArrangedSubview(setHeaderRow(for: exercise.exerciseCategory.inputMode))

        for (setIndex, set) in exercise.sets.enumerated() {
            stack.addArrangedSubview(setRow(
                groupIndex: groupIndex,
                exerciseIndex: exerciseIndex,
                setIndex: setIndex,
                set: set,
                inputMode: exercise.exerciseCategory.inputMode
            ))
        }
        stack.addArrangedSubview(compactButtonRow([
            ("Add Set", { [weak self] in
                guard let self,
                      self.groups.indices.contains(groupIndex),
                      self.groups[groupIndex].exercises.indices.contains(exerciseIndex) else { return }
                self.groups[groupIndex].exercises[exerciseIndex].sets.append(TemplateTargetSetDraft())
                Haptics.tap()
                self.rebuild()
            }),
            ("Remove", { [weak self] in
                guard let self,
                      self.groups.indices.contains(groupIndex),
                      self.groups[groupIndex].exercises.indices.contains(exerciseIndex) else { return }
                self.groups[groupIndex].exercises.remove(at: exerciseIndex)
                Haptics.tap()
                self.rebuild()
            })
        ]))
        return stack
    }

    private func setHeaderRow(for inputMode: ExerciseInputMode) -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Spacing.xs
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false

        let labels: [String]
        switch inputMode {
        case .weightReps:
            labels = ["Set", "Kg", "Reps", "RPE"]
        case .repsOnly:
            labels = ["Set", "Reps", "RPE"]
        case .distanceDuration:
            labels = ["Set", "Meters", "Min", "RPE"]
        case .durationOnly:
            labels = ["Set", "Min", "RPE"]
        }

        for label in labels {
            let view = UIKitDesign.label(UIKitDesign.microText(label), font: UIKitDesign.regular(12), color: UIKitDesign.textTertiary)
            stack.addArrangedSubview(view)
        }
        return stack
    }

    private func setRow(
        groupIndex: Int,
        exerciseIndex: Int,
        setIndex: Int,
        set: TemplateTargetSetDraft,
        inputMode: ExerciseInputMode
    ) -> UIView {
        let stack = UIKitDesign.verticalStack(spacing: Spacing.xs)
        let header = UIStackView()
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = Spacing.xs
        header.translatesAutoresizingMaskIntoConstraints = false
        header.addArrangedSubview(UIKitDesign.label("Set \(setIndex + 1)", font: UIKitDesign.medium(15), color: UIKitDesign.textPrimary))
        header.addArrangedSubview(UIView())
        header.addArrangedSubview(chipButton(title: "Warm-up", isSelected: set.isWarmup) { [weak self] in
            self?.updateSet(groupIndex: groupIndex, exerciseIndex: exerciseIndex, setIndex: setIndex) { draft in
                draft.isWarmup.toggle()
            }
            Haptics.select()
            self?.rebuild()
        })
        stack.addArrangedSubview(header)

        let fields = UIStackView()
        fields.axis = .horizontal
        fields.spacing = Spacing.xs
        fields.distribution = .fillEqually
        fields.translatesAutoresizingMaskIntoConstraints = false

        switch inputMode {
        case .weightReps:
            fields.addArrangedSubview(numberField(title: "Kg", value: set.targetWeightKg, placeholder: nil, keyboardType: .decimalPad) { [weak self] value in
                self?.updateSet(groupIndex: groupIndex, exerciseIndex: exerciseIndex, setIndex: setIndex) { $0.targetWeightKg = value }
            })
            fields.addArrangedSubview(integerField(title: "Reps", value: set.targetReps, placeholder: nil) { [weak self] value in
                self?.updateSet(groupIndex: groupIndex, exerciseIndex: exerciseIndex, setIndex: setIndex) { $0.targetReps = value }
            })
        case .repsOnly:
            fields.addArrangedSubview(integerField(title: "Reps", value: set.targetReps, placeholder: nil) { [weak self] value in
                self?.updateSet(groupIndex: groupIndex, exerciseIndex: exerciseIndex, setIndex: setIndex) { $0.targetReps = value }
            })
        case .distanceDuration:
            fields.addArrangedSubview(numberField(title: "Meters", value: set.targetDistanceMeters, placeholder: nil, keyboardType: .decimalPad) { [weak self] value in
                self?.updateSet(groupIndex: groupIndex, exerciseIndex: exerciseIndex, setIndex: setIndex) { $0.targetDistanceMeters = value }
            })
            fields.addArrangedSubview(numberField(title: "Min", value: set.targetDurationMinutes, placeholder: nil, keyboardType: .decimalPad) { [weak self] value in
                self?.updateSet(groupIndex: groupIndex, exerciseIndex: exerciseIndex, setIndex: setIndex) { $0.targetDurationMinutes = value }
            })
        case .durationOnly:
            fields.addArrangedSubview(numberField(title: "Min", value: set.targetDurationMinutes, placeholder: nil, keyboardType: .decimalPad) { [weak self] value in
                self?.updateSet(groupIndex: groupIndex, exerciseIndex: exerciseIndex, setIndex: setIndex) { $0.targetDurationMinutes = value }
            })
        }
        fields.addArrangedSubview(numberField(title: "RPE", value: set.targetRPE, placeholder: nil, keyboardType: .decimalPad) { [weak self] value in
            self?.updateSet(groupIndex: groupIndex, exerciseIndex: exerciseIndex, setIndex: setIndex) { $0.targetRPE = value }
        })
        stack.addArrangedSubview(fields)
        return stack
    }

    private func textInputRow(
        title: String,
        placeholder: String,
        value: String,
        keyboardType: UIKeyboardType,
        accessibilityIdentifier: String? = nil,
        onStep: ((_ direction: Int, _ currentText: String) -> String?)? = nil,
        onChange: @escaping (String) -> Void
    ) -> UIView {
        let stack = UIKitDesign.verticalStack(spacing: Spacing.xs)
        stack.addArrangedSubview(UIKitDesign.label(title, font: UIKitDesign.regular(13), color: UIKitDesign.textSecondary))
        let field = UITextField()
        field.text = value
        field.placeholder = placeholder
        field.keyboardType = keyboardType
        field.delegate = self
        field.font = UIKitDesign.regular(17)
        field.textColor = UIKitDesign.textPrimary
        field.tintColor = UIKitDesign.textPrimary
        field.backgroundColor = UIKitDesign.surface
        field.layer.borderWidth = UIKitDesign.hairline
        field.layer.borderColor = UIKitDesign.hairlineColor.cgColor
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: Spacing.xs, height: 1))
        field.leftViewMode = .always
        field.accessibilityIdentifier = accessibilityIdentifier
        field.translatesAutoresizingMaskIntoConstraints = false
        field.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        field.addAction(UIAction { [weak field] _ in
            onChange(field?.text ?? "")
        }, for: .editingChanged)
        stack.addArrangedSubview(field)
        return stack
    }

    private func numberField(
        title: String,
        value: Double?,
        placeholder: Double?,
        keyboardType: UIKeyboardType,
        onChange: @escaping (Double?) -> Void
    ) -> UIView {
        textInputRow(
            title: title,
            placeholder: placeholder.map { formatNumber($0) } ?? "--",
            value: value.map { formatNumber($0) } ?? "",
            keyboardType: keyboardType
        ) { text in
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            onChange(trimmed.isEmpty ? nil : Double(trimmed))
        }
    }

    private func integerField(
        title: String,
        value: Int?,
        placeholder: Int?,
        onChange: @escaping (Int?) -> Void
    ) -> UIView {
        textInputRow(
            title: title,
            placeholder: placeholder.map(String.init) ?? "--",
            value: value.map(String.init) ?? "",
            keyboardType: .numberPad
        ) { text in
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            onChange(trimmed.isEmpty ? nil : Int(trimmed))
        }
    }

    private func choiceRow(title: String, value: String, action: Selector) -> UIView {
        let button = UIButton(type: .custom)
        button.addTarget(self, action: action, for: .touchUpInside)
        let row = disclosureRow(title: title, subtitle: nil, trailing: value)
        row.isUserInteractionEnabled = false
        button.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            row.topAnchor.constraint(equalTo: button.topAnchor),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return button
    }

    private func compactButtonRow(_ actions: [(String, () -> Void)]) -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Spacing.xs
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        for action in actions {
            let button = UIButton(type: .custom)
            button.setTitle(action.0, for: .normal)
            button.setTitleColor(UIKitDesign.textPrimary, for: .normal)
            button.titleLabel?.font = UIKitDesign.regular(15)
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.backgroundColor = UIKitDesign.surface
            button.layer.borderWidth = UIKitDesign.hairline
            button.layer.borderColor = UIKitDesign.hairlineColor.cgColor
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            button.addAction(UIAction { _ in action.1() }, for: .touchUpInside)
            stack.addArrangedSubview(button)
        }
        return stack
    }

    private func chipButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.setTitleColor(isSelected ? UIKitDesign.background : UIKitDesign.textSecondary, for: .normal)
        button.titleLabel?.font = UIKitDesign.regular(13)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.backgroundColor = isSelected ? UIKitDesign.textPrimary : UIKitDesign.surface
        button.layer.borderWidth = UIKitDesign.hairline
        button.layer.borderColor = UIKitDesign.hairlineColor.cgColor
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        button.accessibilityTraits = isSelected ? [.button, .selected] : .button
        return button
    }

    private func updateSet(
        groupIndex: Int,
        exerciseIndex: Int,
        setIndex: Int,
        mutate: (inout TemplateTargetSetDraft) -> Void
    ) {
        guard groups.indices.contains(groupIndex),
              groups[groupIndex].exercises.indices.contains(exerciseIndex),
              groups[groupIndex].exercises[exerciseIndex].sets.indices.contains(setIndex) else { return }
        mutate(&groups[groupIndex].exercises[exerciseIndex].sets[setIndex])
    }

    private func formatNumber(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    private func defaultSessionType(for sport: SportType) -> SessionType {
        switch sport {
        case .lifting, .crossfit: .strength
        case .running, .cycling, .swimming: .cardio
        case .teamSport: .skill
        case .custom: sessionType
        }
    }

    @objc private func chooseSportType() {
        let controller = InstrumentChoiceListViewController(
            title: "Sport",
            stateText: { [weak self] in self.map { "\($0.sportType.displayName) - \($0.sessionType.displayName)" } ?? "Choose sport." },
            options: { [weak self] in
                SportType.allCases.map { sport in
                    InstrumentChoiceOption(
                        title: sport.displayName,
                        isSelected: self?.sportType == sport
                    ) { [weak self] in
                        guard let self else { return }
                        self.sportType = sport
                        self.sessionType = self.defaultSessionType(for: sport)
                        self.rebuild()
                    }
                }
            }
        )
        showInstrumentDetail(controller)
    }

    @objc private func chooseSessionType() {
        let controller = InstrumentChoiceListViewController(
            title: "Session Type",
            stateText: { [weak self] in self.map { "\($0.sportType.displayName) - \($0.sessionType.displayName)" } ?? "Choose session type." },
            options: { [weak self] in
                SessionType.allCases.map { type in
                    InstrumentChoiceOption(
                        title: type.displayName,
                        isSelected: self?.sessionType == type
                    ) { [weak self] in
                        self?.sessionType = type
                        self?.rebuild()
                    }
                }
            }
        )
        showInstrumentDetail(controller)
    }

    private func openExercisePicker(groupIndex: Int) {
        guard groups.indices.contains(groupIndex) else { return }
        activeGroupIndex = groupIndex
        Haptics.tap()
        let picker = ExercisePickerViewController(sportType: sportType, modelContext: modelContext) { [weak self] exercise in
            guard let self, self.groups.indices.contains(self.activeGroupIndex) else { return }
            self.groups[self.activeGroupIndex].exercises.append(TemplateExerciseDraft(
                exerciseName: exercise.name,
                exerciseCategory: exercise.category,
                muscleGroup: exercise.muscleGroup
            ))
            self.rebuild()
        }
        present(InstrumentNavigationController(rootViewController: picker), animated: true)
    }

    @objc private func addGroup() {
        let nextName: String
        if groups.count < 26,
           let scalar = UnicodeScalar(65 + groups.count) {
            nextName = "Group \(Character(scalar))"
        } else {
            nextName = "Group \(groups.count + 1)"
        }
        groups.append(TemplateGroupDraft(groupName: nextName))
        Haptics.tap()
        rebuild()
    }

    @objc private func saveTemplate() {
        let trimmedName = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            showSaveError(message: "Template name is required.")
            return
        }

        let template: WorkoutTemplate
        if let existingTemplate {
            template = existingTemplate
            template.templateName = trimmedName
            template.sportType = sportType
            template.sessionType = sessionType
            template.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
            template.updatedAt = .now
            let oldGroups = Array(template.groups)
            template.groups = []
            for group in oldGroups {
                modelContext.delete(group)
            }
        } else {
            template = WorkoutTemplate(
                coachId: ownerId,
                templateName: trimmedName,
                sportType: sportType,
                sessionType: sessionType,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
            )
            template.isAthleteOwned = newTemplatesAreAthleteOwned
            template.athleteId = newTemplatesAreAthleteOwned ? ownerId : nil
            modelContext.insert(template)
        }

        template.scheduledDays = scheduledDays
        template.isFavorite = isFavorite
        if template.isAthleteOwned {
            template.athleteId = template.athleteId ?? ownerId
        }

        for (groupIndex, groupDraft) in groups.enumerated() {
            let group = ExerciseGroup(
                groupName: groupDraft.groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Group \(groupIndex + 1)" : groupDraft.groupName,
                orderIndex: groupIndex
            )
            for (exerciseIndex, exerciseDraft) in groupDraft.exercises.enumerated() {
                let exercise = TemplateExercise(
                    exerciseName: exerciseDraft.exerciseName,
                    exerciseCategory: exerciseDraft.exerciseCategory,
                    muscleGroup: exerciseDraft.muscleGroup,
                    orderIndex: exerciseIndex
                )
                for (setIndex, setDraft) in exerciseDraft.sets.enumerated() {
                    exercise.sets.append(TemplateSet(
                        setIndex: setIndex,
                        targetReps: setDraft.targetReps,
                        targetWeightKg: setDraft.targetWeightKg,
                        targetDurationSeconds: setDraft.targetDurationSeconds,
                        targetDistanceMeters: setDraft.targetDistanceMeters,
                        targetRPE: setDraft.targetRPE,
                        targetRIR: setDraft.targetRIR,
                        isWarmup: setDraft.isWarmup
                    ))
                }
                group.exercises.append(exercise)
            }
            template.groups.append(group)
        }

        do {
            try modelContext.save()
        } catch {
            showSaveError(message: error.localizedDescription)
            return
        }

        Task {
            await container.syncService.pushWorkoutTemplates(context: modelContext, coachId: ownerId)
        }

        Haptics.success()
        dismiss(animated: true) { [onSave] in
            onSave?()
        }
    }

    private func showSaveError(message: String) {
        let alert = UIAlertController(title: "Could not save template", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func cancelEditor() {
        Haptics.tap()
        dismiss(animated: true)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

private struct WorkoutDraftSnapshot: Equatable {
    var sessionName: String
    var sportType: SportType
    var sessionType: SessionType
    var matchTier: MatchTier?
    var sessionRPE: Double
    var saveAsTemplate: Bool
    var templateName: String
    var entries: [ExerciseEntryDraftSnapshot]
}

private struct ExerciseEntryDraftSnapshot: Equatable {
    var exerciseName: String
    var exerciseCategory: ExerciseCategory
    var muscleGroup: MuscleGroup?
    var groupName: String?
    var sets: [SetDraftSnapshot]
}

private struct SetDraftSnapshot: Equatable {
    var reps: Int?
    var weightKg: Double?
    var durationSeconds: Int?
    var distanceMeters: Double?
    var rpe: Double?
    var rir: Int?
    var isWarmup: Bool
    var targetReps: Int?
    var targetWeightKg: Double?
    var targetRPE: Double?
    var targetRIR: Int?
    var targetDistanceMeters: Double?
    var targetDurationSeconds: Int?
    var isDone: Bool
    var isSkipped: Bool
}

private enum ActiveWorkoutSaveError: LocalizedError {
    case simulatedFailure

    var errorDescription: String? {
        switch self {
        case .simulatedFailure:
            "Simulated workout save failure."
        }
    }
}

private final class ActiveWorkoutViewController: InstrumentScrollViewController, UITextFieldDelegate, UIAdaptivePresentationControllerDelegate {
    private let container: AppContainer
    private let modelContext: ModelContext
    private let locale: Locale
    private let template: WorkoutTemplate?
    private let resolvedPlan: ResolvedSessionPlan?

    private var sessionName = ""
    private var sportType: SportType = .lifting
    private var sessionType: SessionType = .strength
    private var matchTier: MatchTier?
    private var entries: [ExerciseEntryDraft] = []
    private var sessionRPE: Double = 5
    private var startTime = Date.now
    private var saveAsTemplate = false
    private var templateName = ""
    private var sourceTemplate: WorkoutTemplate?
    private var resolvedPrescriptionID: UUID?
    private var plannedSessionRepository: PlannedSessionRepository?
    private var didLoadInitialSession = false
    private var initialDraftSnapshot: WorkoutDraftSnapshot?
    private var expandedCompletedSetIDs: Set<UUID> = []
    private var isSaving = false
    private var activeSetFields: [String: UITextField] = [:]
    private var activeSetFieldOrder: [String] = []
    private let actionDock = UIKitBottomActionDock(primaryTitle: "Finish · 0/0 sets", secondaryTitle: "Add Exercise")

    init(
        container: AppContainer,
        modelContext: ModelContext,
        locale: Locale,
        template: WorkoutTemplate? = nil,
        resolvedPlan: ResolvedSessionPlan? = nil
    ) {
        self.container = container
        self.modelContext = modelContext
        self.locale = locale
        self.template = template
        self.resolvedPlan = resolvedPlan
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Workout"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(cancelWorkout)
        )
        configureActionDock()
        loadInitialSessionIfNeeded()
        initialDraftSnapshot = currentDraftSnapshot()
        updateActionDock()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.presentationController?.delegate = self
        updateDismissProtection()
    }

    override func rebuild() {
        activeSetFields = [:]
        activeSetFieldOrder = []
        clearContent()
        let state = makeViewState()
        addHorizontalInsets(hero(
            kicker: state.heroKicker,
            title: state.sessionTitle,
            body: state.heroBody
        ), top: Spacing.sm)

        let sessionState = makeSessionState()
        addSection(title: sessionState.sectionTitle, content: dataPlate(sessionRows(sessionState), spacing: Spacing.sm))

        if !state.hasExercises {
            addSection(content: dataPlate([
                UIKitDesign.label(state.emptyTitle, font: UIKitDesign.medium(19), color: UIKitDesign.textPrimary),
                UIKitDesign.label(state.emptyBody, font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
            ], spacing: Spacing.xs))
        } else {
            for (index, entry) in entries.enumerated() {
                let blockState = ActiveWorkoutExerciseBlockState.make(entry: entry, entryIndex: index)
                addSection(
                    title: blockState.title,
                    content: exercisePlate(entryIndex: index, entry: entry, blockState: blockState)
                )
            }
        }

        updateActionDock()
        updateDismissProtection()
    }

    private func configureActionDock() {
        actionDock.primaryButton.addTarget(self, action: #selector(openFinish), for: .touchUpInside)
        actionDock.secondaryButton.addTarget(self, action: #selector(openExercisePicker), for: .touchUpInside)
        installBottomActionDock(actionDock)
    }

    private func updateActionDock() {
        let state = makeViewState()
        actionDock.updatePrimary(
            title: state.finishActionTitle,
            isEnabled: !state.isSaving,
            accessibilityIdentifier: "activeWorkout.finish",
            accessibilityValue: state.finishAccessibilityValue
        )
        actionDock.updateSecondary(
            title: state.addExerciseActionTitle,
            isEnabled: !state.isSaving,
            accessibilityIdentifier: state.addExerciseAccessibilityIdentifier
        )
    }

    private func makeViewState() -> ActiveWorkoutViewState {
        ActiveWorkoutViewState.make(
            sessionTitle: sessionTitle,
            sessionRPE: sessionRPE,
            entries: entries,
            hasUnsavedChanges: hasUnsavedChanges,
            isSaving: isSaving
        )
    }

    private func makeSessionState() -> ActiveWorkoutSessionState {
        var state = ActiveWorkoutSessionState.make(
            sessionName: sessionName,
            sportType: sportType,
            sessionType: sessionType,
            elapsedSeconds: Int(Date.now.timeIntervalSince(startTime)),
            locale: locale
        )
        if sessionType == .match {
            state.settingsValue = "\(state.settingsValue) · \((matchTier ?? .pickup).displayName)"
        }
        return state
    }

    private var athlete: Athlete? {
        ((try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []).first
    }

    private var sessionTitle: String {
        if !sessionName.isEmpty { return sessionName }
        if let sourceTemplate { return sourceTemplate.templateName }
        return sportType.displayName
    }

    private var totalSetCount: Int {
        entries.reduce(0) { $0 + $1.sets.count }
    }

    private var doneSetCount: Int {
        entries.reduce(0) { $0 + $1.sets.filter(\.isDone).count }
    }

    private var weightUnit: WeightUnit {
        athlete?.weightUnit ?? .kg
    }

    private var hasUnsavedChanges: Bool {
        guard let initialDraftSnapshot else { return false }
        return currentDraftSnapshot() != initialDraftSnapshot
    }

    private func currentDraftSnapshot() -> WorkoutDraftSnapshot {
        WorkoutDraftSnapshot(
            sessionName: sessionName,
            sportType: sportType,
            sessionType: sessionType,
            matchTier: matchTier,
            sessionRPE: sessionRPE,
            saveAsTemplate: saveAsTemplate,
            templateName: templateName,
            entries: entries.map { entry in
                ExerciseEntryDraftSnapshot(
                    exerciseName: entry.exerciseName,
                    exerciseCategory: entry.exerciseCategory,
                    muscleGroup: entry.muscleGroup,
                    groupName: entry.groupName,
                    sets: entry.sets.map { set in
                        SetDraftSnapshot(
                            reps: set.reps,
                            weightKg: set.weightKg,
                            durationSeconds: set.durationSeconds,
                            distanceMeters: set.distanceMeters,
                            rpe: set.rpe,
                            rir: set.rir,
                            isWarmup: set.isWarmup,
                            targetReps: set.targetReps,
                            targetWeightKg: set.targetWeightKg,
                            targetRPE: set.targetRPE,
                            targetRIR: set.targetRIR,
                            targetDistanceMeters: set.targetDistanceMeters,
                            targetDurationSeconds: set.targetDurationSeconds,
                            isDone: set.isDone,
                            isSkipped: set.isSkipped
                        )
                    }
                )
            }
        )
    }

    private func updateDismissProtection() {
        navigationController?.isModalInPresentation = hasUnsavedChanges
    }

    private func loadInitialSessionIfNeeded() {
        guard !didLoadInitialSession else { return }
        didLoadInitialSession = true
        if let template {
            loadFromTemplate(template)
        } else if let resolvedPlan {
            loadFromResolvedPlan(resolvedPlan)
        }
    }

    private func sessionRows(_ state: ActiveWorkoutSessionState) -> [UIView] {
        [
            textInputRow(
                title: state.sessionNameTitle,
                placeholder: state.sessionNamePlaceholder,
                value: state.sessionNameValue,
                keyboardType: .default
            ) { [weak self] value in
                self?.sessionName = value
            },
            divider(),
            metricCell(label: state.elapsedLabel, value: state.elapsedValue, detail: state.elapsedDetail),
            divider(),
            choiceRow(
                title: state.settingsTitle,
                value: state.settingsValue,
                action: #selector(openSessionSettings),
                accessibilityIdentifier: state.settingsAccessibilityIdentifier
            )
        ]
    }

    private func exercisePlate(entryIndex: Int, entry: ExerciseEntryDraft, blockState: ActiveWorkoutExerciseBlockState) -> UIView {
        var rows: [UIView] = []

        rows.append(exerciseProgressRow(blockState))
        rows.append(divider())
        for (setIndex, set) in entry.sets.enumerated() {
            rows.append(setRow(entryIndex: entryIndex, setIndex: setIndex, set: set, category: entry.exerciseCategory))
            rows.append(divider())
        }
        let actionHandlers: [() -> Void] = [
            { [weak self] in self?.addCarriedSet(entryIndex: entryIndex) },
            { [weak self] in self?.repeatLastSet(entryIndex: entryIndex) },
            { [weak self] in self?.removeExercise(entryIndex: entryIndex) }
        ]
        let actionRows: [(String, String?, () -> Void)] = zip(blockState.actions, actionHandlers).map { pair in
            let action = pair.0
            let handler = pair.1
            return (action.title, action.accessibilityIdentifier, handler)
        }
        rows.append(compactButtonRow(actionRows))
        return dataPlate(rows, spacing: Spacing.sm)
    }

    private func exerciseProgressRow(_ blockState: ActiveWorkoutExerciseBlockState) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = Spacing.sm
        row.translatesAutoresizingMaskIntoConstraints = false

        let detailLabel = UIKitDesign.label(blockState.detail, font: UIKitDesign.regular(13), color: UIKitDesign.textSecondary, lines: 0)
        row.addArrangedSubview(detailLabel)

        let progressLabel = UIKitDesign.label(
            blockState.progressText,
            font: UIKitDesign.tabular(UIKitDesign.medium(15)),
            color: UIKitDesign.textPrimary
        )
        progressLabel.textAlignment = .right
        progressLabel.accessibilityIdentifier = blockState.progressAccessibilityIdentifier
        progressLabel.setContentHuggingPriority(.required, for: .horizontal)
        row.addArrangedSubview(progressLabel)
        return row
    }

    private func setRow(entryIndex: Int, setIndex: Int, set: SetDraft, category: ExerciseCategory) -> UIView {
        let rowState = ActiveWorkoutSetRowState.make(
            set: set,
            setIndex: setIndex,
            category: category,
            weightUnit: weightUnit,
            isCompletedExpanded: expandedCompletedSetIDs.contains(set.id)
        )
        let stack = UIKitDesign.verticalStack(spacing: Spacing.xs)
        let header = UIStackView()
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = Spacing.xs
        header.translatesAutoresizingMaskIntoConstraints = false
        header.addArrangedSubview(UIKitDesign.label(rowState.setLabel, font: UIKitDesign.medium(15), color: UIKitDesign.textPrimary))
        header.addArrangedSubview(UIView())
        let warmupButton = chipButton(title: "Warm-up", isSelected: set.isWarmup) { [weak self] in
            guard let self, self.entries.indices.contains(entryIndex), self.entries[entryIndex].sets.indices.contains(setIndex) else { return }
            self.entries[entryIndex].sets[setIndex].isWarmup.toggle()
            Haptics.select()
            self.rebuild()
        }
        warmupButton.accessibilityIdentifier = "activeWorkout.warmup.\(entryIndex).\(setIndex)"
        header.addArrangedSubview(warmupButton)

        let skipButton = chipButton(title: "Skip", isSelected: set.isSkipped) { [weak self] in
            guard let self, self.entries.indices.contains(entryIndex), self.entries[entryIndex].sets.indices.contains(setIndex) else { return }
            let setID = self.entries[entryIndex].sets[setIndex].id
            self.entries[entryIndex].sets[setIndex].isSkipped.toggle()
            if self.entries[entryIndex].sets[setIndex].isSkipped {
                self.entries[entryIndex].sets[setIndex].isDone = false
                self.expandedCompletedSetIDs.remove(setID)
            }
            Haptics.select()
            self.rebuild()
        }
        skipButton.accessibilityIdentifier = "activeWorkout.skip.\(entryIndex).\(setIndex)"
        header.addArrangedSubview(skipButton)

        let doneButton = chipButton(title: rowState.doneActionTitle, isSelected: set.isDone) { [weak self] in
            guard let self, self.entries.indices.contains(entryIndex), self.entries[entryIndex].sets.indices.contains(setIndex) else { return }
            let setID = self.entries[entryIndex].sets[setIndex].id
            self.entries[entryIndex].sets[setIndex].isDone.toggle()
            if self.entries[entryIndex].sets[setIndex].isDone {
                self.entries[entryIndex].sets[setIndex].isSkipped = false
            }
            self.expandedCompletedSetIDs.remove(setID)
            Haptics.select()
            self.rebuild()
        }
        doneButton.accessibilityIdentifier = "activeWorkout.markDone.\(entryIndex).\(setIndex)"
        header.addArrangedSubview(doneButton)
        stack.addArrangedSubview(header)

        let stateLabel = UIKitDesign.label(
            rowState.stateText,
            font: UIKitDesign.regular(13),
            color: UIKitDesign.textSecondary,
            lines: 0
        )
        stateLabel.accessibilityIdentifier = "activeWorkout.setState.\(entryIndex).\(setIndex)"
        stack.addArrangedSubview(stateLabel)

        if rowState.showsCollapsedCompletedSummary {
            stack.addArrangedSubview(completedSetSummary(entryIndex: entryIndex, setIndex: setIndex, rowState: rowState))
        } else if rowState.showsSkippedSummary {
            stack.addArrangedSubview(skippedSetSummary(entryIndex: entryIndex, setIndex: setIndex, rowState: rowState))
        } else if rowState.showsInputFields {
            stack.addArrangedSubview(setInputFields(entryIndex: entryIndex, setIndex: setIndex, set: set, category: category))
        }
        return stack
    }

    private func setInputFields(entryIndex: Int, setIndex: Int, set: SetDraft, category: ExerciseCategory) -> UIView {
        let state = ActiveWorkoutSetInputFieldsState.make(
            set: set,
            category: category,
            weightUnit: weightUnit,
            entryIndex: entryIndex,
            setIndex: setIndex
        )
        let fields = UIStackView()
        fields.axis = .horizontal
        fields.alignment = .fill
        fields.spacing = Spacing.xs
        fields.distribution = .fillEqually
        fields.translatesAutoresizingMaskIntoConstraints = false

        for field in state.fields {
            fields.addArrangedSubview(setInputField(field, entryIndex: entryIndex, setIndex: setIndex))
        }
        return fields
    }

    private func setInputField(
        _ field: ActiveWorkoutSetInputFieldsState.Field,
        entryIndex: Int,
        setIndex: Int
    ) -> UIView {
        switch field.value {
        case let .decimal(value, placeholder, step, closedRange):
            return numberField(
                title: field.title,
                value: value,
                placeholder: placeholder,
                keyboardType: .decimalPad,
                accessibilityIdentifier: field.accessibilityIdentifier,
                step: step,
                closedRange: closedRange
            ) { [weak self] value in
                guard let self else { return }
                self.updateSet(entryIndex: entryIndex, setIndex: setIndex) { draft in
                    self.applyDecimalInput(field.kind, value: value, to: &draft)
                }
            }
        case let .integer(value, placeholder, step, closedRange):
            return integerField(
                title: field.title,
                value: value,
                placeholder: placeholder,
                accessibilityIdentifier: field.accessibilityIdentifier,
                step: step,
                closedRange: closedRange
            ) { [weak self] value in
                guard let self else { return }
                self.updateSet(entryIndex: entryIndex, setIndex: setIndex) { draft in
                    self.applyIntegerInput(field.kind, value: value, to: &draft)
                }
            }
        }
    }

    private func applyDecimalInput(
        _ kind: ActiveWorkoutSetInputFieldsState.Field.Kind,
        value: Double?,
        to draft: inout SetDraft
    ) {
        switch kind {
        case .weight:
            draft.weightKg = value.map { $0 * weightUnit.conversionToKg }
        case .distance:
            draft.distanceMeters = value.map { $0 * 1000 }
        case .rpe:
            draft.rpe = value
            draft.rir = nil
        case .reps, .duration, .rir:
            return
        }
        draft.isDone = true
    }

    private func applyIntegerInput(
        _ kind: ActiveWorkoutSetInputFieldsState.Field.Kind,
        value: Int?,
        to draft: inout SetDraft
    ) {
        switch kind {
        case .reps:
            draft.reps = value
        case .duration:
            draft.durationSeconds = value.map { $0 * 60 }
        case .rir:
            draft.rir = value
            draft.rpe = nil
        case .weight, .distance, .rpe:
            return
        }
        draft.isDone = true
    }

    private func completedSetSummary(entryIndex: Int, setIndex: Int, rowState: ActiveWorkoutSetRowState) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = Spacing.sm
        row.translatesAutoresizingMaskIntoConstraints = false

        let label = UIKitDesign.label(
            rowState.completedSummaryText,
            font: UIKitDesign.regular(15),
            color: UIKitDesign.textPrimary,
            lines: 0
        )
        label.accessibilityIdentifier = "activeWorkout.completedSummary.\(entryIndex).\(setIndex)"
        row.addArrangedSubview(label)

        let editButton = chipButton(title: "Edit", isSelected: false) { [weak self] in
            guard let self, self.entries.indices.contains(entryIndex), self.entries[entryIndex].sets.indices.contains(setIndex) else { return }
            self.expandedCompletedSetIDs.insert(self.entries[entryIndex].sets[setIndex].id)
            Haptics.tap()
            self.rebuild()
        }
        editButton.accessibilityIdentifier = "activeWorkout.editSet.\(entryIndex).\(setIndex)"
        editButton.setContentHuggingPriority(.required, for: .horizontal)
        row.addArrangedSubview(editButton)
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        return row
    }

    private func skippedSetSummary(entryIndex: Int, setIndex: Int, rowState: ActiveWorkoutSetRowState) -> UIView {
        let label = UIKitDesign.label(
            rowState.skippedSummaryText,
            font: UIKitDesign.regular(15),
            color: UIKitDesign.textSecondary,
            lines: 0
        )
        label.accessibilityIdentifier = "activeWorkout.skippedSummary.\(entryIndex).\(setIndex)"
        label.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        return label
    }

    private func textInputRow(
        title: String,
        placeholder: String,
        value: String,
        keyboardType: UIKeyboardType,
        accessibilityIdentifier: String? = nil,
        onStep: ((_ direction: Int, _ currentText: String) -> String?)? = nil,
        onChange: @escaping (String) -> Void
    ) -> UIView {
        let stack = UIKitDesign.verticalStack(spacing: Spacing.xs)
        stack.addArrangedSubview(UIKitDesign.label(title, font: UIKitDesign.regular(13), color: UIKitDesign.textSecondary))
        let field = UITextField()
        field.text = value
        field.placeholder = placeholder
        field.keyboardType = keyboardType
        field.delegate = self
        if let accessibilityIdentifier {
            field.accessibilityIdentifier = accessibilityIdentifier
        } else if title == "Session Name" {
            field.accessibilityIdentifier = "activeWorkout.sessionName"
        }
        field.font = UIKitDesign.regular(17)
        field.textColor = UIKitDesign.textPrimary
        field.tintColor = UIKitDesign.textPrimary
        field.backgroundColor = UIKitDesign.surface
        field.layer.borderWidth = UIKitDesign.hairline
        field.layer.borderColor = UIKitDesign.hairlineColor.cgColor
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: Spacing.xs, height: 1))
        field.leftViewMode = .always
        field.translatesAutoresizingMaskIntoConstraints = false
        field.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        if let accessibilityIdentifier, accessibilityIdentifier.hasPrefix("activeWorkout.field.") {
            registerSetField(field, identifier: accessibilityIdentifier)
        }
        field.addAction(UIAction { [weak self, weak field] _ in
            onChange(field?.text ?? "")
            self?.updateDismissProtection()
        }, for: .editingChanged)
        stack.addArrangedSubview(field)
        if let onStep, let accessibilityIdentifier {
            stack.addArrangedSubview(stepperRow(
                baseIdentifier: accessibilityIdentifier,
                title: title,
                field: field,
                onStep: onStep,
                onChange: onChange
            ))
        }
        return stack
    }

    private func stepperRow(
        baseIdentifier: String,
        title: String,
        field: UITextField,
        onStep: @escaping (_ direction: Int, _ currentText: String) -> String?,
        onChange: @escaping (String) -> Void
    ) -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Spacing.xs
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(stepperButton(
            title: "-",
            accessibilityIdentifier: "\(baseIdentifier).decrement",
            accessibilityLabel: "Decrease \(title)"
        ) { [weak self, weak field] in
            guard let self, let field else { return }
            guard let text = onStep(-1, field.text ?? "") else { return }
            field.text = text
            onChange(text)
            self.updateDismissProtection()
            Haptics.select()
        })

        stack.addArrangedSubview(stepperButton(
            title: "+",
            accessibilityIdentifier: "\(baseIdentifier).increment",
            accessibilityLabel: "Increase \(title)"
        ) { [weak self, weak field] in
            guard let self, let field else { return }
            guard let text = onStep(1, field.text ?? "") else { return }
            field.text = text
            onChange(text)
            self.updateDismissProtection()
            Haptics.select()
        })

        return stack
    }

    private func stepperButton(
        title: String,
        accessibilityIdentifier: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.accessibilityIdentifier = accessibilityIdentifier
        button.accessibilityLabel = accessibilityLabel
        button.setTitleColor(UIKitDesign.textPrimary, for: .normal)
        button.titleLabel?.font = UIKitDesign.medium(17)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.backgroundColor = UIKitDesign.surface
        button.layer.borderWidth = UIKitDesign.hairline
        button.layer.borderColor = UIKitDesign.hairlineColor.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    private func numberField(
        title: String,
        value: Double?,
        placeholder: Double?,
        keyboardType: UIKeyboardType,
        accessibilityIdentifier: String? = nil,
        step: Double? = nil,
        closedRange: ClosedRange<Double>? = nil,
        onChange: @escaping (Double?) -> Void
    ) -> UIView {
        let stepper = numericStepper(
            value: value,
            placeholder: placeholder,
            step: step,
            closedRange: closedRange
        )
        return textInputRow(
            title: title,
            placeholder: placeholder.map { formatNumber($0) } ?? "--",
            value: value.map { formatNumber($0) } ?? "",
            keyboardType: keyboardType,
            accessibilityIdentifier: accessibilityIdentifier,
            onStep: stepper
        ) { text in
            onChange(Double(text))
        }
    }

    private func integerField(
        title: String,
        value: Int?,
        placeholder: Int?,
        accessibilityIdentifier: String? = nil,
        step: Int? = nil,
        closedRange: ClosedRange<Int>? = nil,
        onChange: @escaping (Int?) -> Void
    ) -> UIView {
        let stepper = integerStepper(
            value: value,
            placeholder: placeholder,
            step: step,
            closedRange: closedRange
        )
        return textInputRow(
            title: title,
            placeholder: placeholder.map(String.init) ?? "--",
            value: value.map(String.init) ?? "",
            keyboardType: .decimalPad,
            accessibilityIdentifier: accessibilityIdentifier,
            onStep: stepper
        ) { text in
            onChange(Int(text))
        }
    }

    private func numericStepper(
        value: Double?,
        placeholder: Double?,
        step: Double?,
        closedRange: ClosedRange<Double>?
    ) -> ((_ direction: Int, _ currentText: String) -> String?)? {
        guard let step else { return nil }
        return { [weak self] direction, currentText in
            guard let self else { return nil }
            let currentValue = Double(currentText) ?? value ?? placeholder ?? 0
            var nextValue = currentValue + (Double(direction) * step)
            if let closedRange {
                nextValue = min(max(nextValue, closedRange.lowerBound), closedRange.upperBound)
            } else {
                nextValue = max(0, nextValue)
            }
            return self.formatNumber(nextValue)
        }
    }

    private func integerStepper(
        value: Int?,
        placeholder: Int?,
        step: Int?,
        closedRange: ClosedRange<Int>?
    ) -> ((_ direction: Int, _ currentText: String) -> String?)? {
        guard let step else { return nil }
        return { direction, currentText in
            let currentValue = Int(currentText) ?? value ?? placeholder ?? 0
            var nextValue = currentValue + (direction * step)
            if let closedRange {
                nextValue = min(max(nextValue, closedRange.lowerBound), closedRange.upperBound)
            } else {
                nextValue = max(0, nextValue)
            }
            return String(nextValue)
        }
    }

    private func registerSetField(_ field: UITextField, identifier: String) {
        activeSetFields[identifier] = field
        activeSetFieldOrder.append(identifier)
        field.inputAccessoryView = setKeyboardAccessory(for: identifier)
    }

    private func setKeyboardAccessory(for identifier: String) -> UIView {
        let wrapper = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 56))
        wrapper.backgroundColor = UIKitDesign.background

        let topRule = UIKitDesign.separator(axis: .horizontal)
        wrapper.addSubview(topRule)

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fillEqually
        stack.spacing = Spacing.xs
        stack.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(stack)

        let nextButton = keyboardAccessoryButton(title: "Next")
        nextButton.accessibilityIdentifier = "activeWorkout.keyboard.next"
        nextButton.addAction(UIAction { [weak self] _ in
            self?.focusNextSetField(after: identifier)
        }, for: .touchUpInside)

        let doneButton = keyboardAccessoryButton(title: "Done")
        doneButton.accessibilityIdentifier = "activeWorkout.keyboard.done"
        doneButton.addAction(UIAction { [weak self] _ in
            self?.view.endEditing(true)
        }, for: .touchUpInside)

        stack.addArrangedSubview(nextButton)
        stack.addArrangedSubview(doneButton)

        NSLayoutConstraint.activate([
            topRule.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            topRule.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            topRule.topAnchor.constraint(equalTo: wrapper.topAnchor),
            stack.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: Spacing.sm),
            stack.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -Spacing.sm),
            stack.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: Spacing.xs),
            stack.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -Spacing.xs)
        ])

        return wrapper
    }

    private func keyboardAccessoryButton(title: String) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.setTitleColor(UIKitDesign.textPrimary, for: .normal)
        button.titleLabel?.font = UIKitDesign.medium(15)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.backgroundColor = UIKitDesign.surface
        button.layer.borderWidth = UIKitDesign.hairline
        button.layer.borderColor = UIKitDesign.hairlineColor.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }

    private func focusNextSetField(after identifier: String) {
        guard let index = activeSetFieldOrder.firstIndex(of: identifier) else {
            view.endEditing(true)
            return
        }

        let nextIndex = activeSetFieldOrder.index(after: index)
        guard activeSetFieldOrder.indices.contains(nextIndex) else {
            view.endEditing(true)
            return
        }

        Haptics.select()
        activeSetFields[activeSetFieldOrder[nextIndex]]?.becomeFirstResponder()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let identifier = textField.accessibilityIdentifier,
           identifier.hasPrefix("activeWorkout.field.") {
            focusNextSetField(after: identifier)
            return false
        }

        textField.resignFirstResponder()
        return true
    }

    private func choiceRow(
        title: String,
        value: String,
        action: Selector,
        accessibilityIdentifier: String? = nil
    ) -> UIView {
        let button = UIButton(type: .custom)
        button.accessibilityIdentifier = accessibilityIdentifier
        button.accessibilityLabel = "\(title), \(value)"
        button.addTarget(self, action: action, for: .touchUpInside)
        let row = disclosureRow(title: title, subtitle: nil, trailing: value)
        row.isUserInteractionEnabled = false
        button.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            row.topAnchor.constraint(equalTo: button.topAnchor),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return button
    }

    private func compactButtonRow(_ actions: [(String, String?, () -> Void)]) -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Spacing.xs
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        for action in actions {
            let button = UIButton(type: .custom)
            button.setTitle(action.0, for: .normal)
            button.accessibilityIdentifier = action.1
            button.setTitleColor(UIKitDesign.textPrimary, for: .normal)
            button.titleLabel?.font = UIKitDesign.regular(15)
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.backgroundColor = UIKitDesign.surface
            button.layer.borderWidth = UIKitDesign.hairline
            button.layer.borderColor = UIKitDesign.hairlineColor.cgColor
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            button.addAction(UIAction { _ in action.2() }, for: .touchUpInside)
            stack.addArrangedSubview(button)
        }
        return stack
    }

    private func chipButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.setTitleColor(isSelected ? UIKitDesign.background : UIKitDesign.textSecondary, for: .normal)
        button.titleLabel?.font = UIKitDesign.regular(13)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.backgroundColor = isSelected ? UIKitDesign.textPrimary : UIKitDesign.surface
        button.layer.borderWidth = UIKitDesign.hairline
        button.layer.borderColor = UIKitDesign.hairlineColor.cgColor
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        button.accessibilityTraits = isSelected ? [.button, .selected] : .button
        return button
    }

    private func formatNumber(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    private func updateSet(entryIndex: Int, setIndex: Int, mutate: (inout SetDraft) -> Void) {
        guard entries.indices.contains(entryIndex), entries[entryIndex].sets.indices.contains(setIndex) else { return }
        mutate(&entries[entryIndex].sets[setIndex])
        updateActionDock()
    }

    private func addCarriedSet(entryIndex: Int) {
        guard entries.indices.contains(entryIndex) else { return }
        var draft = SetDraft()
        if let last = entries[entryIndex].sets.last {
            draft.targetWeightKg = last.weightKg ?? last.targetWeightKg
            draft.targetReps = last.reps ?? last.targetReps
            draft.targetRPE = last.rpe ?? last.targetRPE
            draft.targetRIR = last.rir ?? last.targetRIR
            draft.targetDistanceMeters = last.distanceMeters ?? last.targetDistanceMeters
            draft.targetDurationSeconds = last.durationSeconds ?? last.targetDurationSeconds
        }
        entries[entryIndex].sets.append(draft)
        Haptics.tap()
        rebuild()
    }

    private func repeatLastSet(entryIndex: Int) {
        guard entries.indices.contains(entryIndex), let last = entries[entryIndex].sets.last else { return }
        var draft = SetDraft()
        draft.weightKg = last.weightKg ?? last.targetWeightKg
        draft.reps = last.reps ?? last.targetReps
        draft.durationSeconds = last.durationSeconds ?? last.targetDurationSeconds
        draft.distanceMeters = last.distanceMeters ?? last.targetDistanceMeters
        draft.rpe = last.rpe ?? last.targetRPE
        draft.rir = last.rir ?? last.targetRIR
        draft.isWarmup = last.isWarmup
        draft.isDone = true
        entries[entryIndex].sets.append(draft)
        Haptics.tap()
        rebuild()
    }

    private func removeExercise(entryIndex: Int) {
        guard entries.indices.contains(entryIndex) else { return }
        entries.remove(at: entryIndex)
        Haptics.tap()
        rebuild()
    }

    private func loadFromTemplate(_ template: WorkoutTemplate) {
        sessionName = template.templateName
        sportType = template.sportType
        sessionType = template.sessionType
        if sessionType != .match {
            matchTier = nil
        }
        sourceTemplate = template
        entries = template.sortedGroups.flatMap { group in
            group.sortedExercises.map { exercise in
                var draft = ExerciseEntryDraft(
                    exerciseName: exercise.exerciseName,
                    exerciseCategory: exercise.exerciseCategory,
                    muscleGroup: exercise.muscleGroup
                )
                draft.groupName = group.groupName
                draft.sets = exercise.sortedSets.map { templateSet in
                    var set = SetDraft(
                        targetReps: templateSet.targetReps,
                        targetWeightKg: templateSet.targetWeightKg,
                        targetRPE: templateSet.targetRPE,
                        targetRIR: templateSet.targetRIR,
                        isFromHistory: false
                    )
                    set.isWarmup = templateSet.isWarmup
                    set.targetDistanceMeters = templateSet.targetDistanceMeters
                    set.targetDurationSeconds = templateSet.targetDurationSeconds
                    return set
                }
                if draft.sets.isEmpty { draft.sets = [SetDraft()] }
                return draft
            }
        }
    }

    private func loadFromResolvedPlan(_ plan: ResolvedSessionPlan) {
        sessionName = plan.sessionName
        sportType = plan.sportType
        sessionType = plan.sessionType
        if sessionType != .match {
            matchTier = nil
        }
        resolvedPrescriptionID = plan.prescriptionID
        if plannedSessionRepository == nil {
            plannedSessionRepository = PlannedSessionRepository(modelContext: modelContext)
        }
        entries = plan.exercises.map { exercise in
            var draft = ExerciseEntryDraft(
                exerciseName: exercise.exerciseName,
                exerciseCategory: exercise.exerciseCategory,
                muscleGroup: exercise.muscleGroup
            )
            draft.groupName = exercise.groupName
            draft.sets = exercise.sets.map { set in
                var setDraft = SetDraft(
                    targetReps: set.reps,
                    targetWeightKg: set.weightKg,
                    targetRPE: set.rpe,
                    targetDistanceMeters: set.distanceMeters,
                    targetDurationSeconds: set.durationSeconds,
                    isFromHistory: false
                )
                setDraft.targetRIR = set.rir
                setDraft.isWarmup = set.isWarmup
                setDraft.plannedWeightKg = set.plannedWeightKg
                setDraft.plannedRPE = set.plannedRPE
                setDraft.isSuggestedAdjustment = set.isSuggestedAdjustment
                setDraft.verdictReason = set.verdictReason
                return setDraft
            }
            if draft.sets.isEmpty { draft.sets = [SetDraft()] }
            return draft
        }
    }

    @objc private func openSessionSettings() {
        Haptics.tap()
        let controller = ActiveWorkoutSessionSettingsViewController(
            sportType: sportType,
            sessionType: sessionType,
            matchTier: matchTier,
            locale: locale
        ) { [weak self] sport, type, tier in
            guard let self else { return }
            self.sportType = sport
            self.sessionType = type
            self.matchTier = type == .match ? tier : nil
            self.rebuild()
        }
        present(InstrumentNavigationController(rootViewController: controller), animated: true)
    }

    @objc private func openExercisePicker() {
        Haptics.tap()
        let picker = ExercisePickerViewController(sportType: sportType, modelContext: modelContext) { [weak self] exercise in
            guard let self else { return }
            var draft = ExerciseEntryDraft(
                exerciseName: exercise.name,
                exerciseCategory: exercise.category,
                muscleGroup: exercise.muscleGroup
            )
            draft.sets = [SetDraft()]
            self.entries.append(draft)
            self.rebuild()
            DispatchQueue.main.async { [weak self] in
                self?.scrollToWorkoutContentBottom()
            }
        }
        present(InstrumentNavigationController(rootViewController: picker), animated: true)
    }

    private func scrollToWorkoutContentBottom() {
        view.layoutIfNeeded()
        scrollView.layoutIfNeeded()
        let topOffset = -scrollView.adjustedContentInset.top
        let bottomOffset = scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom
        scrollView.setContentOffset(
            CGPoint(x: 0, y: max(topOffset, bottomOffset)),
            animated: false
        )
    }

    @objc private func openFinish() {
        Haptics.tap()
        let controller = FinishWorkoutViewController(
            sessionName: sessionTitle,
            sportType: sportType,
            initialRPE: sessionRPE,
            initialSaveAsTemplate: saveAsTemplate,
            initialTemplateName: templateName
        ) { [weak self] rpe, shouldSaveTemplate, name in
            guard let self else { return }
            self.sessionRPE = rpe
            self.saveAsTemplate = shouldSaveTemplate
            self.templateName = name
            self.saveSession()
        }
        present(InstrumentNavigationController(rootViewController: controller), animated: true)
    }

    @objc private func cancelWorkout() {
        Haptics.tap()
        guard hasUnsavedChanges else {
            dismiss(animated: true)
            return
        }
        presentDiscardChangesPrompt()
    }

    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        !hasUnsavedChanges
    }

    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        presentDiscardChangesPrompt()
    }

    private func presentDiscardChangesPrompt() {
        Haptics.warning()
        let state = ActiveWorkoutAlertState.unsavedChanges(locale: locale)
        presentAlert(state) { [weak self] action in
            if action.role == .destructive {
                self?.dismiss(animated: true)
            }
        }
    }

    private func presentAlert(
        _ state: ActiveWorkoutAlertState,
        onAction: ((ActiveWorkoutAlertState.Action) -> Void)? = nil
    ) {
        let alert = UIAlertController(
            title: state.title,
            message: state.message,
            preferredStyle: .alert
        )
        for action in state.actions {
            alert.addAction(UIAlertAction(title: action.title, style: alertActionStyle(for: action.role)) { _ in
                onAction?(action)
            })
        }
        present(alert, animated: true)
    }

    private func alertActionStyle(for role: ActiveWorkoutAlertState.ActionRole) -> UIAlertAction.Style {
        switch role {
        case .normal: .default
        case .cancel: .cancel
        case .destructive: .destructive
        }
    }

    private func presentNoCompletedSetsGuard() {
        let state = ActiveWorkoutAlertState.noCompletedSets(locale: locale)
        presentAlert(state) { [weak self] action in
            if action.role == .destructive {
                self?.dismiss(animated: true)
            }
        }
    }

    private func saveSession() {
        guard !isSaving else { return }
        Haptics.prepare()
        if doneSetCount == 0 {
            presentNoCompletedSetsGuard()
            return
        }
        isSaving = true
        updateActionDock()
        DispatchQueue.main.async { [weak self] in
            self?.persistSession()
        }
    }

    private func persistSession() {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("SCREENSHOT_SAVE_FAILURE_MODE") {
            showSaveError(ActiveWorkoutSaveError.simulatedFailure)
            return
        }
#endif

        let session = WorkoutSession(
            sessionDate: startTime,
            sessionName: sessionName.isEmpty ? nil : sessionName,
            sportType: sportType,
            durationSeconds: Int(Date.now.timeIntervalSince(startTime)),
            sessionRPE: sessionRPE,
            sessionType: sessionType
        )

        var entryOrder = 0
        for draft in entries {
            let doneSets = draft.sets.filter { $0.isDone }
            guard !doneSets.isEmpty else { continue }
            let entry = ExerciseEntry(
                exerciseName: draft.exerciseName,
                exerciseCategory: draft.exerciseCategory,
                muscleGroup: draft.muscleGroup,
                orderIndex: entryOrder
            )
            entryOrder += 1
            for (setIndex, setDraft) in doneSets.enumerated() {
                entry.sets.append(SetRecord(
                    setIndex: setIndex,
                    reps: setDraft.reps,
                    weightKg: setDraft.weightKg,
                    durationSeconds: setDraft.durationSeconds,
                    distanceMeters: setDraft.distanceMeters,
                    rpe: setDraft.rpe,
                    rir: setDraft.rir,
                    isWarmup: setDraft.isWarmup
                ))
            }
            session.exerciseEntries.append(entry)
        }

        session.recalculateDerivedFields()
        session.matchTier = MatchTier.persistedTier(sessionType: sessionType, selected: matchTier)
        session.sourceTemplateId = sourceTemplate?.id
        session.athlete = athlete
        modelContext.insert(session)

        do {
            try modelContext.save()
        } catch {
            showSaveError(error)
            return
        }

        if let prescriptionID = resolvedPrescriptionID {
            let repo = plannedSessionRepository ?? PlannedSessionRepository(modelContext: modelContext)
            let linked = repo.markCompleted(prescriptionId: prescriptionID, completedSessionId: session.id)
            if !linked {
                print("Verdict linkage failed: session \(session.id) saved but prescription \(prescriptionID) not marked completed.")
            }
        }

        if let source = sourceTemplate {
            source.lastUsedAt = .now
            source.usageCount += 1
            source.updatedAt = .now
            try? modelContext.save()
        }

        let didSaveTemplate = saveAsTemplate ? saveTemplateFromSession() : false
        initialDraftSnapshot = currentDraftSnapshot()
        updateDismissProtection()

        if let athlete {
            do {
                let result = try WorkoutPipeline.processSession(
                    session,
                    athlete: athlete,
                    modelContext: modelContext,
                    syncService: container.syncService
                )
                finishAfterPipelineResult(result, didSaveTemplate: didSaveTemplate)
                return
            } catch {
                print("Workout pipeline error: \(error)")
            }
        }

        showPostSaveFeedback(.make(templateSaved: didSaveTemplate), didSaveTemplate: didSaveTemplate)
    }

    private func finishAfterPipelineResult(_ result: WorkoutPipeline.PipelineResult, didSaveTemplate: Bool) {
        showPostSaveFeedback(.make(result: result, templateSaved: didSaveTemplate), didSaveTemplate: didSaveTemplate)
    }

    private func showPostSaveFeedback(_ feedback: WorkoutPostSaveFeedback, didSaveTemplate: Bool) {
        isSaving = false
        updateActionDock()
        container.uxAnalyticsService.track(.workoutFinished, properties: [
            "source": workoutStartSource,
            "template_saved": didSaveTemplate ? "true" : "false",
            "warning": feedback.hasWarning ? "true" : "false"
        ])

        if feedback.hasWarning {
            Haptics.warning()
        } else {
            Haptics.success()
        }

        let controller = WorkoutPostSaveFeedbackViewController(feedback: feedback) { [weak self] in
            self?.dismissActiveWorkoutFlow()
        }
        present(InstrumentNavigationController(rootViewController: controller), animated: true)
    }

    private var workoutStartSource: String {
        if resolvedPlan != nil || resolvedPrescriptionID != nil {
            return "planned_session"
        }
        if template != nil || sourceTemplate != nil {
            return "template"
        }
        return "blank"
    }

    private func dismissActiveWorkoutFlow() {
        let presentingController = navigationController?.presentingViewController ?? presentingViewController
        if let presentingController {
            presentingController.dismiss(animated: true)
        } else if let navigationController {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    private func saveTemplateFromSession() -> Bool {
        guard let athleteId = athlete?.id else { return false }
        let name = templateName.isEmpty ? sessionTitle : templateName
        let template = WorkoutTemplate(
            coachId: athleteId,
            templateName: name,
            sportType: sportType,
            sessionType: sessionType
        )
        template.isAthleteOwned = true
        template.athleteId = athleteId

        let group = ExerciseGroup(groupName: "Main", orderIndex: 0)
        for (entryIndex, entryDraft) in entries.enumerated() {
            let validSets = entryDraft.sets.filter { set in
                set.reps != nil || set.weightKg != nil || set.durationSeconds != nil || set.distanceMeters != nil
            }
            guard !validSets.isEmpty else { continue }
            let exercise = TemplateExercise(
                exerciseName: entryDraft.exerciseName,
                exerciseCategory: entryDraft.exerciseCategory,
                muscleGroup: entryDraft.muscleGroup,
                orderIndex: entryIndex
            )
            for (setIndex, setDraft) in validSets.enumerated() {
                exercise.sets.append(TemplateSet(
                    setIndex: setIndex,
                    targetReps: setDraft.reps,
                    targetWeightKg: setDraft.weightKg,
                    targetRPE: setDraft.rpe,
                    targetRIR: setDraft.rir,
                    isWarmup: setDraft.isWarmup
                ))
            }
            group.exercises.append(exercise)
        }
        template.groups.append(group)
        modelContext.insert(template)
        do {
            try modelContext.save()
            Task {
                await container.syncService.pushWorkoutTemplates(context: modelContext, coachId: athleteId)
            }
            return true
        } catch {
            print("Failed to save template: \(error)")
            return false
        }
    }

    private func showSaveError(_ error: Error) {
        isSaving = false
        updateActionDock()
        container.uxAnalyticsService.track(.uiErrorPresented, properties: [
            "surface": "active_workout",
            "error": "save_failed"
        ])
        presentAlert(ActiveWorkoutAlertState.saveFailure(errorDescription: error.localizedDescription, locale: locale))
    }

    private func defaultSessionType(for sport: SportType) -> SessionType {
        switch sport {
        case .lifting, .crossfit: .strength
        case .running, .cycling, .swimming: .cardio
        case .teamSport: .skill
        case .custom: sessionType
        }
    }

    private func localized(_ key: String.LocalizationValue) -> String {
        UIKitStrings.localized(key, locale: locale)
    }

    private func localized(_ key: StaticString, defaultValue: String.LocalizationValue) -> String {
        UIKitStrings.localized(key, defaultValue: defaultValue, locale: locale)
    }
}

private final class WorkoutPostSaveFeedbackViewController: InstrumentScrollViewController {
    private let feedback: WorkoutPostSaveFeedback
    private let onDone: () -> Void
    private let actionDock = UIKitBottomActionDock(primaryTitle: "Done")

    init(feedback: WorkoutPostSaveFeedback, onDone: @escaping () -> Void) {
        self.feedback = feedback
        self.onDone = onDone
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = feedback.navigationTitle
        actionDock.primaryButton.addTarget(self, action: #selector(done), for: .touchUpInside)
        installBottomActionDock(actionDock)
    }

    override func rebuild() {
        clearContent()
        actionDock.updatePrimary(
            title: feedback.doneActionTitle,
            accessibilityIdentifier: feedback.doneAccessibilityIdentifier,
            accessibilityValue: feedback.doneAccessibilityValue
        )
        addHorizontalInsets(hero(
            kicker: feedback.heroKicker,
            title: feedback.title,
            body: feedback.summary
        ), top: Spacing.sm)

        var rows: [UIView] = []
        for (index, item) in feedback.items.enumerated() {
            rows.append(feedbackRow(item))
            if index < feedback.items.count - 1 {
                rows.append(divider())
            }
        }
        addSection(content: dataPlate(rows, spacing: Spacing.sm))
    }

    private func feedbackRow(_ item: WorkoutPostSaveFeedback.Item) -> UIView {
        let stack = UIKitDesign.verticalStack(spacing: Spacing.xs)
        stack.accessibilityIdentifier = item.identifier
        let title = UIKitDesign.label(item.title, font: UIKitDesign.medium(17), color: UIKitDesign.textPrimary, lines: 0)
        title.accessibilityIdentifier = "\(item.identifier).title"
        stack.addArrangedSubview(title)

        let detail = UIKitDesign.label(item.detail, font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
        detail.accessibilityIdentifier = "\(item.identifier).detail"
        stack.addArrangedSubview(detail)

        if item.isWarning {
            let label = UIKitDesign.label(feedback.warningLabel, font: UIKitDesign.regular(13), color: UIKitDesign.textSecondary)
            label.accessibilityIdentifier = "\(item.identifier).state"
            stack.addArrangedSubview(label)
        }

        return stack
    }

    @objc private func done() {
        Haptics.tap()
        onDone()
    }
}

private final class ActiveWorkoutSessionSettingsViewController: InstrumentScrollViewController {
    private var sportType: SportType
    private var sessionType: SessionType
    private var matchTier: MatchTier?
    private let locale: Locale
    private let onChange: (SportType, SessionType, MatchTier?) -> Void
    private let actionDock = UIKitBottomActionDock(primaryTitle: "Done")

    init(
        sportType: SportType,
        sessionType: SessionType,
        matchTier: MatchTier?,
        locale: Locale,
        onChange: @escaping (SportType, SessionType, MatchTier?) -> Void
    ) {
        self.sportType = sportType
        self.sessionType = sessionType
        self.matchTier = sessionType == .match ? matchTier : nil
        self.locale = locale
        self.onChange = onChange
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let state = makeViewState()
        title = state.navigationTitle
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: state.cancelTitle,
            style: .plain,
            target: self,
            action: #selector(done)
        )
        navigationItem.leftBarButtonItem?.accessibilityIdentifier = state.cancelAccessibilityIdentifier
        actionDock.primaryButton.addTarget(self, action: #selector(done), for: .touchUpInside)
        installBottomActionDock(actionDock)
    }

    override func rebuild() {
        clearContent()
        let state = makeViewState()
        actionDock.updatePrimary(
            title: state.doneActionTitle,
            accessibilityIdentifier: state.doneAccessibilityIdentifier,
            accessibilityValue: state.stateText
        )
        addHorizontalInsets(hero(
            kicker: state.heroKicker,
            title: state.heroTitle,
            body: state.heroBody
        ), top: Spacing.sm)
        addHorizontalInsets(settingsStatePlate(state), top: Spacing.sm)

        var rows: [UIView] = [
            settingsRow(
                state.sportRow,
                action: #selector(chooseSportType)
            ),
            divider(),
            settingsRow(
                state.sessionTypeRow,
                action: #selector(chooseSessionType)
            )
        ]
        if sessionType == .match {
            rows.append(divider())
            rows.append(matchTierPickerRow())
        }
        addSection(content: dataPlate(rows, spacing: Spacing.sm))
    }

    private func makeViewState() -> ActiveWorkoutSessionSettingsViewState {
        ActiveWorkoutSessionSettingsViewState.make(
            sportType: sportType,
            sessionType: sessionType
        )
    }

    private var settingsStateText: String {
        let state = makeViewState().stateText
        guard sessionType == .match else { return state }
        return "\(state) - \((matchTier ?? .pickup).displayName)"
    }

    private func settingsStatePlate(_ state: ActiveWorkoutSessionSettingsViewState) -> UIView {
        let label = UIKitDesign.label(settingsStateText, font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
        label.accessibilityIdentifier = state.stateAccessibilityIdentifier
        return dataPlate([label], spacing: Spacing.sm)
    }

    private func settingsRow(
        _ rowState: ActiveWorkoutSessionSettingsViewState.Row,
        action: Selector
    ) -> UIView {
        let button = UIButton(type: .custom)
        button.accessibilityIdentifier = rowState.accessibilityIdentifier
        button.accessibilityLabel = rowState.accessibilityLabel
        button.addTarget(self, action: action, for: .touchUpInside)
        let row = disclosureRow(title: rowState.title, subtitle: nil, trailing: rowState.value)
        row.isUserInteractionEnabled = false
        button.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            row.topAnchor.constraint(equalTo: button.topAnchor),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return button
    }

    private func matchTierPickerRow() -> UIView {
        let stack = UIKitDesign.verticalStack(spacing: Spacing.xs)
        stack.accessibilityIdentifier = "activeWorkout.settings.matchTier"
        stack.addArrangedSubview(UIKitDesign.microLabel(UIKitStrings.localized("matchTier.picker.title", locale: locale)))

        let buttons = UIStackView()
        buttons.axis = .horizontal
        buttons.spacing = Spacing.xs
        buttons.distribution = .fillEqually
        buttons.translatesAutoresizingMaskIntoConstraints = false
        for tier in MatchTier.allCases {
            buttons.addArrangedSubview(matchTierButton(tier))
        }
        stack.addArrangedSubview(buttons)
        return stack
    }

    private func matchTierButton(_ tier: MatchTier) -> UIButton {
        let isSelected = (matchTier ?? .pickup) == tier
        let button = UIButton(type: .custom)
        button.setTitle(matchTierTitle(tier), for: .normal)
        button.setTitleColor(isSelected ? UIKitDesign.background : UIKitDesign.textSecondary, for: .normal)
        button.titleLabel?.font = UIKitDesign.regular(15)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.backgroundColor = isSelected ? UIKitDesign.textPrimary : UIKitDesign.surface
        button.layer.borderWidth = UIKitDesign.hairline
        button.layer.borderColor = UIKitDesign.hairlineColor.cgColor
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        button.accessibilityIdentifier = "activeWorkout.settings.matchTier.\(tier.rawValue)"
        button.accessibilityTraits = isSelected ? [.button, .selected] : .button
        button.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.matchTier = tier
            self.onChange(self.sportType, self.sessionType, self.matchTier)
            Haptics.select()
            self.rebuild()
        }, for: .touchUpInside)
        return button
    }

    @objc private func chooseSportType() {
        let state = makeViewState()
        let fallbackStateText = state.stateText
        let controller = InstrumentChoiceListViewController(
            title: state.sportChoiceTitle,
            stateText: { [weak self] in self?.settingsStateText ?? fallbackStateText },
            options: { [weak self] in
                SportType.allCases.map { sport in
                    InstrumentChoiceOption(
                        title: sport.displayName,
                        isSelected: self?.sportType == sport
                    ) { [weak self] in
                        guard let self else { return }
                        self.sportType = sport
                        self.sessionType = self.defaultSessionType(for: sport)
                        if self.sessionType != .match {
                            self.matchTier = nil
                        }
                        self.onChange(self.sportType, self.sessionType, self.matchTier)
                        self.rebuild()
                    }
                }
            }
        )
        showInstrumentDetail(controller)
    }

    @objc private func chooseSessionType() {
        let state = makeViewState()
        let fallbackStateText = state.stateText
        let controller = InstrumentChoiceListViewController(
            title: state.sessionTypeChoiceTitle,
            stateText: { [weak self] in self?.settingsStateText ?? fallbackStateText },
            options: { [weak self] in
                SessionType.allCases.map { type in
                    InstrumentChoiceOption(
                        title: type.displayName,
                        isSelected: self?.sessionType == type
                    ) { [weak self] in
                        guard let self else { return }
                        self.sessionType = type
                        if type != .match {
                            self.matchTier = nil
                        }
                        self.onChange(self.sportType, self.sessionType, self.matchTier)
                        self.rebuild()
                    }
                }
            }
        )
        showInstrumentDetail(controller)
    }

    @objc private func done() {
        Haptics.tap()
        dismiss(animated: true)
    }

    private func defaultSessionType(for sport: SportType) -> SessionType {
        switch sport {
        case .lifting, .crossfit: .strength
        case .running, .cycling, .swimming: .cardio
        case .teamSport: .skill
        case .custom: sessionType
        }
    }

    private func matchTierTitle(_ tier: MatchTier) -> String {
        switch tier {
        case .pickup: UIKitStrings.localized("matchTier.pickup", locale: locale)
        case .scrimmage: UIKitStrings.localized("matchTier.scrimmage", locale: locale)
        case .match: UIKitStrings.localized("matchTier.match", locale: locale)
        }
    }
}

private final class ExercisePickerViewController: InstrumentScrollViewController {
    private let sportType: SportType
    private let modelContext: ModelContext
    private let onSelect: (ExerciseDefinition) -> Void

    init(
        sportType: SportType,
        modelContext: ModelContext,
        onSelect: @escaping (ExerciseDefinition) -> Void
    ) {
        self.sportType = sportType
        self.modelContext = modelContext
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let state = ExercisePickerViewState.make(sportType: sportType, exercises: [])
        title = state.navigationTitle
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: state.cancelTitle,
            style: .plain,
            target: self,
            action: #selector(cancelPicker)
        )
        navigationItem.leftBarButtonItem?.accessibilityIdentifier = state.cancelAccessibilityIdentifier
    }

    override func rebuild() {
        clearContent()
        let exercises = allExercises()
        let state = ExercisePickerViewState.make(sportType: sportType, exercises: exercises)
        addHorizontalInsets(hero(
            kicker: state.heroKicker,
            title: state.heroTitle,
            body: state.heroBody
        ), top: Spacing.sm)
        addHorizontalInsets(exercisePickerStatePlate(state), top: Spacing.sm)

        var rows: [UIView] = []
        for (index, pair) in zip(state.rows, exercises).enumerated() {
            rows.append(exerciseButton(pair.0, exercise: pair.1))
            if index < exercises.count - 1 {
                rows.append(divider())
            }
        }
        addSection(content: dataPlate(rows, spacing: Spacing.sm))
    }

    private func allExercises() -> [ExerciseDefinition] {
        var exercises = ExerciseDatabase.exercises(for: sportType)
        let customExercises = (try? modelContext.fetch(FetchDescriptor<CustomExercise>())) ?? []
        exercises.append(contentsOf: customExercises
            .filter { $0.sportType == nil || $0.sportType == sportType }
            .map {
                ExerciseDefinition(
                    name: $0.name,
                    category: $0.exerciseCategory,
                    muscleGroup: $0.muscleGroup,
                    isCustom: true
                )
            })
        return exercises
    }

    private func exercisePickerStatePlate(_ state: ExercisePickerViewState) -> UIView {
        let label = UIKitDesign.label(state.stateText, font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
        label.accessibilityIdentifier = state.stateAccessibilityIdentifier
        return dataPlate([label], spacing: Spacing.sm)
    }

    private func exerciseButton(_ rowState: ExercisePickerViewState.Row, exercise: ExerciseDefinition) -> UIView {
        let button = UIButton(type: .custom)
        button.accessibilityLabel = rowState.accessibilityLabel
        button.accessibilityIdentifier = rowState.accessibilityIdentifier
        let row = disclosureRow(title: rowState.title, subtitle: rowState.detail)
        row.isUserInteractionEnabled = false
        button.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            row.topAnchor.constraint(equalTo: button.topAnchor),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        button.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            Haptics.select()
            self.dismiss(animated: true) {
                self.onSelect(exercise)
            }
        }, for: .touchUpInside)
        return button
    }

    @objc private func cancelPicker() {
        Haptics.tap()
        dismiss(animated: true)
    }
}

private final class FinishWorkoutViewController: InstrumentScrollViewController, UITextFieldDelegate {
    private let sessionName: String
    private let sportType: SportType
    private let onFinish: (Double, Bool, String) -> Void
    private var rpe: Double
    private var saveAsTemplate: Bool
    private var templateName: String
    private let actionDock = UIKitBottomActionDock(primaryTitle: "Finish Workout")

    init(
        sessionName: String,
        sportType: SportType,
        initialRPE: Double,
        initialSaveAsTemplate: Bool,
        initialTemplateName: String,
        onFinish: @escaping (Double, Bool, String) -> Void
    ) {
        self.sessionName = sessionName
        self.sportType = sportType
        self.rpe = initialRPE
        self.saveAsTemplate = initialSaveAsTemplate
        self.templateName = initialTemplateName.isEmpty ? sessionName : initialTemplateName
        self.onFinish = onFinish
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let state = makeViewState()
        title = state.navigationTitle
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: state.keepEditingTitle,
            style: .plain,
            target: self,
            action: #selector(keepEditing)
        )
        navigationItem.leftBarButtonItem?.accessibilityIdentifier = state.keepEditingAccessibilityIdentifier
        actionDock.primaryButton.addTarget(self, action: #selector(finishWorkout), for: .touchUpInside)
        installBottomActionDock(actionDock)
    }

    override func rebuild() {
        clearContent()
        let state = makeViewState()
        actionDock.updatePrimary(
            title: state.commitActionTitle,
            accessibilityIdentifier: state.commitAccessibilityIdentifier,
            accessibilityValue: state.commitAccessibilityValue
        )
        addHorizontalInsets(hero(
            kicker: state.heroKicker,
            title: state.heroTitle,
            body: state.heroBody
        ), top: Spacing.sm)
        addHorizontalInsets(finishStatePlate(state), top: Spacing.sm)

        let slider = UISlider()
        slider.minimumValue = 1
        slider.maximumValue = 10
        slider.value = Float(rpe)
        slider.minimumTrackTintColor = UIKitDesign.textPrimary
        slider.maximumTrackTintColor = UIKitDesign.hairlineColor
        slider.thumbTintColor = UIKitDesign.textPrimary
        slider.accessibilityIdentifier = state.rpeAccessibilityIdentifier
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        slider.addAction(UIAction { [weak self, weak slider] _ in
            guard let self, let slider else { return }
            self.rpe = Double(slider.value.rounded())
            self.rebuild()
        }, for: .valueChanged)

        let saveSwitch = UISwitch()
        saveSwitch.isOn = saveAsTemplate
        saveSwitch.onTintColor = UIKitDesign.textSecondary
        saveSwitch.accessibilityIdentifier = state.saveAsTemplateAccessibilityIdentifier
        saveSwitch.addAction(UIAction { [weak self, weak saveSwitch] _ in
            guard let self, let saveSwitch else { return }
            self.saveAsTemplate = saveSwitch.isOn
            self.rebuild()
        }, for: .valueChanged)

        let switchRow = UIStackView()
        switchRow.axis = .horizontal
        switchRow.alignment = .center
        switchRow.spacing = Spacing.sm
        switchRow.translatesAutoresizingMaskIntoConstraints = false
        switchRow.addArrangedSubview(UIKitDesign.label(state.saveAsTemplateTitle, font: UIKitDesign.regular(17), color: UIKitDesign.textPrimary))
        switchRow.addArrangedSubview(UIView())
        switchRow.addArrangedSubview(saveSwitch)

        var rows: [UIView] = [
            UIKitDesign.label(state.rpeLabel, font: UIKitDesign.medium(19), color: UIKitDesign.textPrimary),
            slider,
            divider(),
            switchRow
        ]

        if state.showsTemplateName {
            rows.append(divider())
            rows.append(templateNameField(state))
        }

        addSection(content: dataPlate(rows, spacing: Spacing.sm))
    }

    private func makeViewState() -> FinishWorkoutViewState {
        FinishWorkoutViewState.make(
            sessionName: sessionName,
            sportType: sportType,
            rpe: rpe,
            saveAsTemplate: saveAsTemplate,
            templateName: templateName
        )
    }

    private func finishStatePlate(_ state: FinishWorkoutViewState) -> UIView {
        let label = UIKitDesign.label(state.stateText, font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
        label.accessibilityIdentifier = state.stateAccessibilityIdentifier
        return dataPlate([label], spacing: Spacing.sm)
    }

    private func templateNameField(_ state: FinishWorkoutViewState) -> UIView {
        let stack = UIKitDesign.verticalStack(spacing: Spacing.xs)
        stack.addArrangedSubview(UIKitDesign.label(state.templateNameTitle, font: UIKitDesign.regular(13), color: UIKitDesign.textSecondary))
        let field = UITextField()
        field.text = state.templateNameValue
        field.placeholder = state.templateNamePlaceholder
        field.delegate = self
        field.accessibilityIdentifier = state.templateNameAccessibilityIdentifier
        field.font = UIKitDesign.regular(17)
        field.textColor = UIKitDesign.textPrimary
        field.tintColor = UIKitDesign.textPrimary
        field.backgroundColor = UIKitDesign.surface
        field.layer.borderWidth = UIKitDesign.hairline
        field.layer.borderColor = UIKitDesign.hairlineColor.cgColor
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: Spacing.xs, height: 1))
        field.leftViewMode = .always
        field.translatesAutoresizingMaskIntoConstraints = false
        field.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        field.addAction(UIAction { [weak self, weak field] _ in
            self?.templateName = field?.text ?? ""
        }, for: .editingChanged)
        stack.addArrangedSubview(field)
        return stack
    }

    @objc private func keepEditing() {
        Haptics.tap()
        dismiss(animated: true)
    }

    @objc private func finishWorkout() {
        Haptics.tap()
        dismiss(animated: true) { [rpe, saveAsTemplate, templateName, onFinish] in
            onFinish(rpe, saveAsTemplate, templateName)
        }
    }
}

private final class InsightsViewController: UIViewController, AppTabRootResetting {
    private let container: AppContainer
    private let modelContext: ModelContext
    private let locale: Locale
    private let segmentedControl: InstrumentSegmentedControlUIKit
    private let childContainer = UIView()
    private var selectedSection: InsightsSection = .overview
    private var activeChild: UIViewController?
    private var sectionControllers: [InsightsSection: UIViewController] = [:]

    init(container: AppContainer, modelContext: ModelContext, locale: Locale) {
        self.container = container
        self.modelContext = modelContext
        self.locale = locale
        self.segmentedControl = InstrumentSegmentedControlUIKit(titles: InsightsSection.allCases.map { $0.title(locale: locale) })
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIKitDesign.background
        segmentedControl.selectedAccessibilityValue = UIKitStrings.localized(
            "accessibility.selected",
            defaultValue: "Selected",
            locale: locale
        )
        segmentedControl.selectedIndex = selectedSection.rawValue
        segmentedControl.onSelectionChanged = { [weak self] index in
            guard let section = InsightsSection(rawValue: index) else { return }
            self?.selectSection(section)
        }

        let separator = UIKitDesign.separator(axis: .horizontal)
        childContainer.translatesAutoresizingMaskIntoConstraints = false
        childContainer.backgroundColor = UIKitDesign.background

        view.addSubview(segmentedControl)
        view.addSubview(separator)
        view.addSubview(childContainer)
        NSLayoutConstraint.activate([
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Spacing.sm),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Spacing.sm),
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Spacing.sm),
            separator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            separator.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: Spacing.xs),
            childContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            childContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            childContainer.topAnchor.constraint(equalTo: separator.bottomAnchor),
            childContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        showSelectedSection()
    }

    private func showSelectedSection() {
        if let cachedChild = sectionControllers[selectedSection], activeChild === cachedChild { return }
        activeChild?.willMove(toParent: nil)
        activeChild?.view.removeFromSuperview()
        activeChild?.removeFromParent()

        let child = controller(for: selectedSection)

        addChild(child)
        child.view.translatesAutoresizingMaskIntoConstraints = false
        childContainer.addSubview(child.view)
        NSLayoutConstraint.activate([
            child.view.leadingAnchor.constraint(equalTo: childContainer.leadingAnchor),
            child.view.trailingAnchor.constraint(equalTo: childContainer.trailingAnchor),
            child.view.topAnchor.constraint(equalTo: childContainer.topAnchor),
            child.view.bottomAnchor.constraint(equalTo: childContainer.bottomAnchor)
        ])
        child.didMove(toParent: self)
        activeChild = child
    }

    private func selectSection(_ section: InsightsSection) {
        selectedSection = section
        segmentedControl.selectedIndex = section.rawValue
        container.uxAnalyticsService.track(.insightsSectionViewed, properties: [
            "section": section.trackingValue
        ])
        showSelectedSection()
    }

    private func controller(for section: InsightsSection) -> UIViewController {
        if let controller = sectionControllers[section] {
            return controller
        }

        let controller: UIViewController
        switch section {
        case .overview:
            controller = InsightsOverviewViewController(modelContext: modelContext, locale: locale) { [weak self] section in
                self?.container.uxAnalyticsService.track(.insightDetailOpened, properties: [
                    "section": section.trackingValue
                ])
                self?.selectSection(section)
            }
        case .recovery:
            controller = RecoveryInsightsSummaryViewController(
                container: container,
                modelContext: modelContext,
                locale: locale
            )
        case .load:
            controller = LoadInsightsSummaryViewController(
                container: container,
                modelContext: modelContext,
                locale: locale
            )
        }
        sectionControllers[section] = controller
        return controller
    }

    func resetToRoot(animated: Bool) {
        if selectedSection != .overview {
            selectSection(.overview)
        }
        (activeChild as? AppTabRootResetting)?.resetToRoot(animated: animated)
    }

}

private final class InsightsOverviewViewController: InstrumentScrollViewController {
    private let modelContext: ModelContext
    private let locale: Locale
    private let onSelectSection: (InsightsSection) -> Void

    init(modelContext: ModelContext, locale: Locale, onSelectSection: @escaping (InsightsSection) -> Void) {
        self.modelContext = modelContext
        self.locale = locale
        self.onSelectSection = onSelectSection
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func rebuild() {
        clearContent()
        let data = loadData()
        let state = InsightsOverviewViewState.make(
            recoverySnapshots: data.recoverySnapshots,
            workloadSnapshots: data.workloadSnapshots,
            sessions: data.sessions,
            locale: locale
        )

        addHorizontalInsets(hero(
            kicker: state.heroKicker,
            title: state.headline,
            body: state.body
        ), top: Spacing.sm)

        addSection(
            title: "Signals",
            content: metricRail(state.signalMetrics.map { ($0.label, $0.value, $0.detail) })
        )

        addSection(
            title: "Current trajectory",
            content: dataPlate(insightRows(state.insights), spacing: Spacing.sm)
        )

        addSection(
            title: "What to watch",
            content: dataPlate([
                detailActionRow(
                    title: "Recovery detail",
                    subtitle: "HRV, resting heart rate, sleep, wellness, and behavior links",
                    section: .recovery,
                    accessibilityIdentifier: "insights.overview.recoveryDetail"
                ),
                divider(),
                detailActionRow(
                    title: "Load detail",
                    subtitle: "ACWR, ATL, CTL, distribution, spikes, and personal records",
                    section: .load,
                    accessibilityIdentifier: "insights.overview.loadDetail"
                )
            ], spacing: Spacing.sm)
        )
    }

    private func detailActionRow(
        title: String,
        subtitle: String,
        section: InsightsSection,
        accessibilityIdentifier: String
    ) -> UIView {
        let button = UIButton(type: .custom)
        button.accessibilityIdentifier = accessibilityIdentifier
        button.accessibilityLabel = "\(title), \(subtitle)"
        button.addAction(UIAction { [weak self] _ in
            Haptics.tap()
            self?.onSelectSection(section)
        }, for: .touchUpInside)
        let row = disclosureRow(title: title, subtitle: subtitle)
        row.isUserInteractionEnabled = false
        button.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            row.topAnchor.constraint(equalTo: button.topAnchor),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return button
    }

    private func loadData() -> (
        recoverySnapshots: [RecoverySnapshot],
        workloadSnapshots: [WorkloadSnapshot],
        sessions: [WorkoutSession]
    ) {
        let athletes = (try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []
        guard let athleteId = athletes.first?.id else { return ([], [], []) }

        var recoveryDescriptor = FetchDescriptor<RecoverySnapshot>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        recoveryDescriptor.fetchLimit = 40
        let recoverySnapshots = ((try? modelContext.fetch(recoveryDescriptor)) ?? [])
            .filter { $0.athlete?.id == athleteId }

        var workloadDescriptor = FetchDescriptor<WorkloadSnapshot>(sortBy: [SortDescriptor(\.snapshotDate, order: .reverse)])
        workloadDescriptor.fetchLimit = 40
        let workloadSnapshots = ((try? modelContext.fetch(workloadDescriptor)) ?? [])
            .filter { $0.athlete?.id == athleteId }

        var sessionDescriptor = FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.sessionDate, order: .reverse)])
        sessionDescriptor.fetchLimit = 40
        let sessions = ((try? modelContext.fetch(sessionDescriptor)) ?? [])
            .filter { $0.athlete?.id == athleteId }
        return (recoverySnapshots, workloadSnapshots, sessions)
    }

    private func insightRows(_ insights: [InsightsOverviewViewState.Insight]) -> [UIView] {
        insights.enumerated().flatMap { index, insight -> [UIView] in
            var rows = [insightRow(insight)]
            if index < insights.count - 1 {
                rows.append(divider())
            }
            return rows
        }
    }

    private func insightRow(_ insight: InsightsOverviewViewState.Insight) -> UIView {
        let stack = UIKitDesign.verticalStack(spacing: Spacing.xs)
        let title = UIKitDesign.label(insight.title, font: UIKitDesign.medium(19), color: UIKitDesign.textPrimary, lines: 0)
        title.accessibilityIdentifier = "insights.overview.insight.\(insight.identifier).title"
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(insightAnswer(
            label: "What changed",
            body: insight.whatChanged,
            identifier: "insights.overview.insight.\(insight.identifier).changed"
        ))
        stack.addArrangedSubview(insightAnswer(
            label: "Why it matters",
            body: insight.whyItMatters,
            identifier: "insights.overview.insight.\(insight.identifier).why"
        ))
        stack.addArrangedSubview(insightAnswer(
            label: "Watch next",
            body: insight.watchNext,
            identifier: "insights.overview.insight.\(insight.identifier).next"
        ))
        return stack
    }

    private func insightAnswer(label: String, body: String, identifier: String) -> UIView {
        let stack = UIKitDesign.verticalStack(spacing: Spacing.baselinePair)
        stack.addArrangedSubview(UIKitDesign.label(UIKitDesign.microText(label), font: UIKitDesign.regular(12), color: UIKitDesign.textTertiary))
        let bodyLabel = UIKitDesign.label(body, font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
        bodyLabel.accessibilityIdentifier = identifier
        stack.addArrangedSubview(bodyLabel)
        return stack
    }

}

private final class RecoveryInsightsSummaryViewController: InstrumentScrollViewController {
    private let container: AppContainer
    private let modelContext: ModelContext
    private let locale: Locale

    init(container: AppContainer, modelContext: ModelContext, locale: Locale) {
        self.container = container
        self.modelContext = modelContext
        self.locale = locale
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func rebuild() {
        clearContent()
        let snapshots = loadSnapshots()
        let state = RecoveryInsightsViewState.make(snapshots: snapshots, locale: locale)
        addHorizontalInsets(hero(
            kicker: state.heroKicker,
            title: state.scoreText,
            body: state.body
        ), top: Spacing.sm)

        addSection(
            title: "Signals",
            content: metricRail(state.signalMetrics.map { ($0.label, $0.value, $0.detail) })
        )

        addSection(title: "Trend", content: dataPlate(trendRows(state: state), spacing: Spacing.sm))
        addSection(title: "More", content: dataPlate([
            actionRow(
                title: "Morning check-in",
                subtitle: "Sleep, soreness, energy, stress, and notes",
                action: #selector(openMorningCheckIn),
                accessibilityIdentifier: "recovery.morningCheckIn"
            ),
            divider(),
            actionRow(
                title: "Open recovery detail",
                subtitle: "HRV, resting heart rate, sleep, wellness, and check-in history",
                action: #selector(openFullRecovery),
                accessibilityIdentifier: "recovery.openDetail"
            )
        ], spacing: Spacing.sm))
    }

    private func loadSnapshots() -> [RecoverySnapshot] {
        let athletes = (try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []
        guard let athleteId = athletes.first?.id else { return [] }
        let descriptor = FetchDescriptor<RecoverySnapshot>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return ((try? modelContext.fetch(descriptor)) ?? [])
            .filter { $0.athlete?.id == athleteId }
            .prefix(14)
            .map { $0 }
    }

    private func trendRows(state: RecoveryInsightsViewState) -> [UIView] {
        guard !state.trendRows.isEmpty else {
            return [
                UIKitDesign.label(state.emptyTrendTitle, font: UIKitDesign.medium(19), color: UIKitDesign.textPrimary),
                UIKitDesign.label(state.emptyTrendBody, font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
            ]
        }
        return state.trendRows.enumerated().flatMap { index, row -> [UIView] in
            var rows = [
                disclosureRow(
                    title: row.title,
                    subtitle: row.subtitle,
                    trailing: row.trailing
                )
            ]
            if index < state.trendRows.count - 1 {
                rows.append(divider())
            }
            return rows
        }
    }

    private func actionRow(
        title: String,
        subtitle: String?,
        action: Selector,
        accessibilityIdentifier: String
    ) -> UIView {
        let button = UIButton(type: .custom)
        button.accessibilityIdentifier = accessibilityIdentifier
        button.accessibilityLabel = "\(title), \(subtitle ?? "")"
        button.addTarget(self, action: action, for: .touchUpInside)
        let row = disclosureRow(title: title, subtitle: subtitle)
        row.isUserInteractionEnabled = false
        button.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            row.topAnchor.constraint(equalTo: button.topAnchor),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return button
    }

    @objc private func openMorningCheckIn() {
        Haptics.tap()
        let controller = MorningCheckInViewController(
            container: container,
            modelContext: modelContext
        ) { [weak self] in
            self?.rebuild()
        }
        present(InstrumentNavigationController(rootViewController: controller), animated: true)
    }

    @objc private func openFullRecovery() {
        Haptics.tap()
        let controller = RecoveryInsightsDetailViewController(
            container: container,
            modelContext: modelContext,
            locale: locale
        )
        present(InstrumentNavigationController(rootViewController: controller), animated: true)
    }
}

private final class MorningCheckInViewController: InstrumentScrollViewController, UITextFieldDelegate {
    private let container: AppContainer
    private let modelContext: ModelContext
    private let onSaved: () -> Void
    private var sleepQuality = 3
    private var soreness = 3
    private var energy = 3
    private var stress = 3
    private var notes = ""
    private var errorMessage: String?
    private let actionDock = UIKitBottomActionDock(primaryTitle: "Save Check-in")

    init(container: AppContainer, modelContext: ModelContext, onSaved: @escaping () -> Void) {
        self.container = container
        self.modelContext = modelContext
        self.onSaved = onSaved
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Morning Check-in"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(cancelCheckIn)
        )
        navigationItem.leftBarButtonItem?.accessibilityIdentifier = "morningCheckIn.cancel"
        actionDock.primaryButton.addTarget(self, action: #selector(saveCheckIn), for: .touchUpInside)
        installBottomActionDock(actionDock)
        seedFromExistingCheckIn()
    }

    override func rebuild() {
        clearContent()
        actionDock.updatePrimary(
            title: "Save Check-in",
            isEnabled: currentAthlete() != nil,
            accessibilityIdentifier: "morningCheckIn.save",
            accessibilityValue: checkInStateText
        )
        addHorizontalInsets(hero(
            kicker: "Recovery",
            title: "\(Int(wellnessScore))",
            body: "Capture subjective context before training decisions harden."
        ), top: Spacing.sm)
        addHorizontalInsets(checkInStatePlate(), top: Spacing.sm)

        addSection(title: "Signals", content: dataPlate([
            valueSelector(
                identifier: "sleep",
                title: "Sleep Quality",
                subtitle: "How well did you sleep?",
                lowLabel: "Terrible",
                highLabel: "Great",
                value: sleepQuality
            ) { [weak self] value in self?.sleepQuality = value },
            divider(),
            valueSelector(
                identifier: "soreness",
                title: "Muscle Soreness",
                subtitle: "Higher means fresher.",
                lowLabel: "Very sore",
                highLabel: "Fresh",
                value: soreness
            ) { [weak self] value in self?.soreness = value },
            divider(),
            valueSelector(
                identifier: "energy",
                title: "Energy",
                subtitle: "How much drive do you have?",
                lowLabel: "Exhausted",
                highLabel: "Energized",
                value: energy
            ) { [weak self] value in self?.energy = value },
            divider(),
            valueSelector(
                identifier: "stress",
                title: "Stress",
                subtitle: "Higher means more relaxed.",
                lowLabel: "Very stressed",
                highLabel: "Relaxed",
                value: stress
            ) { [weak self] value in self?.stress = value }
        ], spacing: Spacing.sm))

        addSection(title: "Notes", content: dataPlate([notesField()], spacing: Spacing.sm))

        if let errorMessage {
            addSection(content: dataPlate([
                UIKitDesign.label(errorMessage, font: UIKitDesign.regular(15), color: UIColor(ColorTokens.zoneDanger), lines: 0)
            ], spacing: Spacing.sm))
        }
    }

    private var wellnessScore: Double {
        (Double(sleepQuality + soreness + energy + stress) / 20.0) * 100.0
    }

    private var checkInStateText: String {
        if errorMessage != nil {
            return "Save needs attention"
        }
        return "Wellness score \(Int(wellnessScore))/100"
    }

    private func checkInStatePlate() -> UIView {
        let label = UIKitDesign.label(checkInStateText, font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
        label.accessibilityIdentifier = "morningCheckIn.state"
        return dataPlate([label], spacing: Spacing.sm)
    }

    private func valueSelector(
        identifier: String,
        title: String,
        subtitle: String,
        lowLabel: String,
        highLabel: String,
        value: Int,
        onSelect: @escaping (Int) -> Void
    ) -> UIView {
        let stack = UIKitDesign.verticalStack(spacing: Spacing.xs)
        let titleRow = UIStackView()
        titleRow.axis = .horizontal
        titleRow.alignment = .firstBaseline
        titleRow.spacing = Spacing.sm
        titleRow.translatesAutoresizingMaskIntoConstraints = false
        titleRow.addArrangedSubview(UIKitDesign.label(title, font: UIKitDesign.medium(17), color: UIKitDesign.textPrimary))
        titleRow.addArrangedSubview(UIView())
        let state = UIKitDesign.label("\(value)/5", font: UIKitDesign.tabular(UIKitDesign.medium(17)), color: UIKitDesign.textSecondary)
        state.accessibilityIdentifier = "morningCheckIn.\(identifier).state"
        titleRow.addArrangedSubview(state)
        stack.addArrangedSubview(titleRow)
        stack.addArrangedSubview(UIKitDesign.label(subtitle, font: UIKitDesign.regular(13), color: UIKitDesign.textSecondary, lines: 0))

        let buttons = UIStackView()
        buttons.axis = .horizontal
        buttons.spacing = Spacing.xs
        buttons.distribution = .fillEqually
        buttons.translatesAutoresizingMaskIntoConstraints = false
        for score in 1...5 {
            buttons.addArrangedSubview(scoreButton(
                score: score,
                selected: score == value,
                accessibilityIdentifier: "morningCheckIn.\(identifier).\(score)"
            ) { [weak self] in
                onSelect(score)
                self?.errorMessage = nil
                Haptics.select()
                self?.rebuild()
            })
        }
        stack.addArrangedSubview(buttons)

        let labels = UIStackView()
        labels.axis = .horizontal
        labels.spacing = Spacing.sm
        labels.translatesAutoresizingMaskIntoConstraints = false
        labels.addArrangedSubview(UIKitDesign.label(lowLabel, font: UIKitDesign.regular(12), color: UIKitDesign.textTertiary))
        labels.addArrangedSubview(UIView())
        labels.addArrangedSubview(UIKitDesign.label(highLabel, font: UIKitDesign.regular(12), color: UIKitDesign.textTertiary))
        stack.addArrangedSubview(labels)
        return stack
    }

    private func scoreButton(
        score: Int,
        selected: Bool,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle("\(score)", for: .normal)
        button.setTitleColor(selected ? UIKitDesign.background : UIKitDesign.textSecondary, for: .normal)
        button.titleLabel?.font = UIKitDesign.medium(15)
        button.backgroundColor = selected ? UIKitDesign.textPrimary : UIKitDesign.surface
        button.layer.borderWidth = UIKitDesign.hairline
        button.layer.borderColor = selected ? UIKitDesign.hairlineStrong.cgColor : UIKitDesign.hairlineColor.cgColor
        button.accessibilityIdentifier = accessibilityIdentifier
        button.accessibilityTraits = selected ? [.button, .selected] : .button
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    private func notesField() -> UIView {
        let field = UITextField()
        field.text = notes
        field.placeholder = "Optional note"
        field.delegate = self
        field.accessibilityIdentifier = "morningCheckIn.notes"
        field.font = UIKitDesign.regular(17)
        field.textColor = UIKitDesign.textPrimary
        field.tintColor = UIKitDesign.textPrimary
        field.backgroundColor = UIKitDesign.surface
        field.layer.borderWidth = UIKitDesign.hairline
        field.layer.borderColor = UIKitDesign.hairlineColor.cgColor
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: Spacing.xs, height: 1))
        field.leftViewMode = .always
        field.translatesAutoresizingMaskIntoConstraints = false
        field.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        field.addAction(UIAction { [weak self, weak field] _ in
            self?.notes = field?.text ?? ""
        }, for: .editingChanged)
        return field
    }

    private func seedFromExistingCheckIn() {
        guard let athlete = currentAthlete() else { return }
        let repo = RecoveryRepository(modelContext: modelContext)
        let source = (try? repo.fetchTodayWellnessCheckIn(athlete: athlete))
            ?? (try? repo.fetchLatestWellnessCheckIn(athlete: athlete))
        guard let source else { return }
        sleepQuality = source.sleepQuality
        soreness = source.soreness
        energy = source.energy
        stress = source.stress
    }

    private func currentAthlete() -> Athlete? {
        ((try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []).first
    }

    @objc private func saveCheckIn() {
        guard let athlete = currentAthlete() else { return }
        let repo = RecoveryRepository(modelContext: modelContext)
        let checkIn: WellnessCheckIn
        if let existing = try? repo.fetchTodayWellnessCheckIn(athlete: athlete) {
            checkIn = existing
        } else {
            checkIn = WellnessCheckIn(date: .now)
            checkIn.athlete = athlete
            modelContext.insert(checkIn)
        }
        checkIn.sleepQuality = sleepQuality
        checkIn.soreness = soreness
        checkIn.energy = energy
        checkIn.stress = stress
        checkIn.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
        checkIn.updatedAt = .now

        do {
            try modelContext.save()
            Task { await container.syncService.pushRecoveryAndWellness(context: modelContext, athleteId: athlete.id) }
            Haptics.success()
            dismiss(animated: true) { [onSaved] in
                onSaved()
            }
        } catch {
            errorMessage = "Could not save check-in. Please try again."
            rebuild()
        }
    }

    @objc private func cancelCheckIn() {
        Haptics.tap()
        dismiss(animated: true)
    }
}

private final class LoadInsightsSummaryViewController: InstrumentScrollViewController {
    private let container: AppContainer
    private let modelContext: ModelContext
    private let locale: Locale

    init(container: AppContainer, modelContext: ModelContext, locale: Locale) {
        self.container = container
        self.modelContext = modelContext
        self.locale = locale
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func rebuild() {
        clearContent()
        let snapshots = loadSnapshots()
        let state = LoadInsightsViewState.make(snapshots: snapshots, locale: locale)
        addHorizontalInsets(hero(
            kicker: state.heroKicker,
            title: state.acwrText,
            body: state.body
        ), top: Spacing.sm)

        addSection(
            title: "Load balance",
            content: metricRail(state.balanceMetrics.map { ($0.label, $0.value, $0.detail) })
        )

        addSection(title: "Volume", content: dataPlate(volumeRows(state: state), spacing: Spacing.sm))
        let export = actionRow(title: "Export workout data", subtitle: "CSV summary, detailed sets, or PDF report", action: #selector(openExportOptions))
        export.accessibilityIdentifier = "export.workoutData"
        addSection(title: "More", content: dataPlate([
            export,
            divider(),
            actionRow(title: "Open load detail", subtitle: "Load history, recent sessions, PRs, and export", action: #selector(openFullLoad))
        ], spacing: Spacing.sm))
    }

    private func loadSnapshots() -> [WorkloadSnapshot] {
        let athletes = (try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []
        guard let athleteId = athletes.first?.id else { return [] }
        let descriptor = FetchDescriptor<WorkloadSnapshot>(sortBy: [SortDescriptor(\.snapshotDate, order: .reverse)])
        return ((try? modelContext.fetch(descriptor)) ?? [])
            .filter { $0.athlete?.id == athleteId }
            .prefix(14)
            .map { $0 }
    }

    private func volumeRows(state: LoadInsightsViewState) -> [UIView] {
        guard !state.volumeRows.isEmpty else {
            return [
                UIKitDesign.label(state.emptyVolumeTitle, font: UIKitDesign.medium(19), color: UIKitDesign.textPrimary),
                UIKitDesign.label(state.emptyVolumeBody, font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
            ]
        }
        return state.volumeRows.enumerated().flatMap { index, row -> [UIView] in
            var rows = [
                disclosureRow(
                    title: row.title,
                    subtitle: row.subtitle,
                    trailing: row.trailing
                )
            ]
            if index < state.volumeRows.count - 1 {
                rows.append(divider())
            }
            return rows
        }
    }

    private func actionRow(title: String, subtitle: String?, action: Selector) -> UIView {
        let button = UIButton(type: .custom)
        button.addTarget(self, action: action, for: .touchUpInside)
        let row = disclosureRow(title: title, subtitle: subtitle)
        row.isUserInteractionEnabled = false
        button.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            row.topAnchor.constraint(equalTo: button.topAnchor),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return button
    }

    @objc private func openFullLoad() {
        Haptics.tap()
        let controller = LoadInsightsDetailViewController(
            container: container,
            modelContext: modelContext,
            locale: locale
        )
        present(InstrumentNavigationController(rootViewController: controller), animated: true)
    }

    @objc private func openExportOptions() {
        presentExportOptions(from: self, container: container, modelContext: modelContext)
    }
}

private enum UIKitPlanOption {
    case annual
    case monthly
}

private enum UIKitSubscriptionAction {
    case purchase
    case restore
}

private final class UpgradeViewController: InstrumentScrollViewController {
    private let container: AppContainer
    private let trigger: UpgradeTrigger
    private let selectedTier: SubscriptionTier
    private var locale: Locale { container.localeManager.activeLocale }

    private var offering: Offering?
    private var selectedPlan: UIKitPlanOption = .annual
    private var isPurchasing = false
    private var subscriptionAction: UIKitSubscriptionAction?
    private var isLoadingOffering = false
    private var offeringUnavailable = false
    private var errorMessage: String?

    init(container: AppContainer, trigger: UpgradeTrigger) {
        self.container = container
        self.trigger = trigger
        self.selectedTier = trigger.defaultTier
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = localized("upgrade.nav.title")
        let cancelItem = UIBarButtonItem(
            title: localized("action.cancel"),
            style: .plain,
            target: self,
            action: #selector(closeUpgrade)
        )
        cancelItem.accessibilityIdentifier = "upgrade.cancel"
        navigationItem.leftBarButtonItem = cancelItem
        Task { await loadOffering() }
    }

    override func rebuild() {
        clearContent()
        addHorizontalInsets(hero(
            kicker: triggerLabel,
            title: selectedTier.headline(locale: locale),
            body: selectedTier.subtitle(locale: locale)
        ), top: Spacing.sm)
        addHorizontalInsets(paywallStatePlate(), top: Spacing.sm)

        addSection(title: localized("upgrade.section.tier", defaultValue: "Tier"), content: dataPlate(tierRows(), spacing: Spacing.sm))
        addSection(title: localized("upgrade.section.includes"), content: dataPlate(featureRows(), spacing: Spacing.sm))
        addSection(title: localized("upgrade.section.choosePlan"), content: dataPlate([
            planSelector(),
            divider(),
            UIKitDesign.label(planExplanation, font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
        ], spacing: Spacing.sm))

        var actionRows: [UIView] = []
        if let errorMessage {
            let error = UIKitDesign.label(errorMessage, font: UIKitDesign.regular(15), color: UIColor(ColorTokens.zoneDanger), lines: 0)
            error.accessibilityIdentifier = "upgrade.error"
            actionRows.append(error)
            actionRows.append(divider())
        }

        if isLoadingOffering {
            let indicator = UIActivityIndicatorView(style: .medium)
            indicator.color = UIKitDesign.textSecondary
            indicator.startAnimating()
            actionRows.append(indicator)
        } else if offeringUnavailable {
            let unavailable = UIKitDesign.label(localized("upgrade.error.unavailable"), font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
            unavailable.accessibilityIdentifier = "upgrade.offeringUnavailable"
            actionRows.append(unavailable)
            let retry = actionButton(title: localized("action.retry"), action: #selector(retryOffering))
            retry.accessibilityIdentifier = "upgrade.retry"
            actionRows.append(retry)
        } else {
            let subscribe = actionButton(
                title: trialAvailable ? localized("upgrade.cta.trial") : localized("upgrade.cta.subscribe"),
                action: #selector(subscribe)
            )
            subscribe.isEnabled = !isPurchasing && activePackage != nil
            subscribe.alpha = subscribe.isEnabled ? 1 : 0.45
            subscribe.accessibilityIdentifier = "upgrade.subscribe"
            subscribe.accessibilityValue = paywallStateText
            actionRows.append(subscribe)
        }

        actionRows.append(divider())
        actionRows.append(contentsOf: subscriptionDisclosureRows())
        actionRows.append(divider())
        actionRows.append(footerActions())
        addSection(title: localized("upgrade.section.subscription"), content: dataPlate(actionRows, spacing: Spacing.sm))
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

    private var triggerLabel: String {
        switch trigger {
        case .history(let lockedWeeks):
            return lockedWeeks > 0
                ? String(format: localized("upgrade.trigger.historyWeeks"), lockedWeeks)
                : localized("upgrade.trigger.history")
        case .coach:
            return localized("upgrade.trigger.coach")
        case .athletePro:
            return localized("upgrade.trigger.athletePro")
        case .export:
            return localized("upgrade.trigger.export")
        }
    }

    private var planExplanation: String {
        selectedPlan == .annual
            ? String(format: localized("upgrade.label.annualBenefit"), selectedTier.monthlyEquivalent)
            : localized("upgrade.label.monthlyBenefit")
    }

    private var activePriceText: String {
        activePackage?.localizedPriceString ?? (selectedPlan == .annual ? selectedTier.fallbackAnnualPrice : selectedTier.fallbackMonthlyPrice)
    }

    private var selectedTierName: String {
        switch selectedTier {
        case .athletePro:
            return localized("upgrade.tier.athletePro.name", defaultValue: "Athlete Pro")
        case .coach:
            return localized("upgrade.tier.coach.name", defaultValue: "Coach")
        }
    }

    private var paywallStateText: String {
        if isLoadingOffering {
            return localized("upgrade.state.loadingOffering", defaultValue: "Loading subscription options")
        }
        if isPurchasing {
            switch subscriptionAction {
            case .restore:
                return localized("upgrade.state.restoring", defaultValue: "Restoring purchases")
            case .purchase:
                return localized("upgrade.state.purchasing", defaultValue: "Purchase loading")
            case nil:
                return localized("upgrade.state.working", defaultValue: "Working")
            }
        }
        if offeringUnavailable {
            return localized("upgrade.state.unavailable", defaultValue: "Subscription options unavailable")
        }
        if errorMessage != nil {
            return localized("upgrade.state.failure", defaultValue: "Recoverable failure")
        }
        return localized("upgrade.state.ready", defaultValue: "Ready")
    }

    private func paywallStatePlate() -> UIView {
        let label = UIKitDesign.label(paywallStateText, font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
        label.accessibilityIdentifier = "upgrade.state"
        return dataPlate([label], spacing: Spacing.sm)
    }

    private func tierRows() -> [UIView] {
        [
            summaryRow(
                title: localized("upgrade.tier.selected", defaultValue: "Selected tier"),
                trailing: selectedTierName,
                accessibilityIdentifier: "upgrade.tier.selected"
            ),
            divider(),
            summaryRow(
                title: localized("upgrade.tier.athletePro.name", defaultValue: "Athlete Pro"),
                trailing: localized("upgrade.tier.athletePro.summary", defaultValue: "Unlocks athlete history, training decisions, exports, and PRs."),
                accessibilityIdentifier: "upgrade.tier.athletePro"
            ),
            divider(),
            summaryRow(
                title: localized("upgrade.tier.coach.name", defaultValue: "Coach"),
                trailing: localized("upgrade.tier.coach.summary", defaultValue: "Includes Athlete Pro plus roster, planning, and reports."),
                accessibilityIdentifier: "upgrade.tier.coach"
            )
        ]
    }

    private func featureRows() -> [UIView] {
        let features = selectedTier.features(locale: locale)
        return features.enumerated().flatMap { index, feature in
            var rows: [UIView] = [featureRow(feature)]
            if index < features.count - 1 {
                rows.append(divider())
            }
            return rows
        }
    }

    private func featureRow(_ text: String) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .top
        row.spacing = Spacing.xs
        row.translatesAutoresizingMaskIntoConstraints = false

        let check = UIImageView(image: UIImage(systemName: "checkmark"))
        check.tintColor = UIKitDesign.textSecondary
        check.translatesAutoresizingMaskIntoConstraints = false
        check.widthAnchor.constraint(equalToConstant: 16).isActive = true
        row.addArrangedSubview(check)
        row.addArrangedSubview(UIKitDesign.label(text, font: UIKitDesign.regular(17), color: UIKitDesign.textPrimary, lines: 0))
        return row
    }

    private func planSelector() -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Spacing.xs
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(planButton(
            plan: .annual,
            title: localized("upgrade.plan.annual"),
            price: annualPackage?.localizedPriceString ?? selectedTier.fallbackAnnualPrice,
            detail: selectedTier.annualSavingsBadge(locale: locale)
        ))
        stack.addArrangedSubview(planButton(
            plan: .monthly,
            title: localized("upgrade.plan.monthly"),
            price: monthlyPackage?.localizedPriceString ?? selectedTier.fallbackMonthlyPrice,
            detail: nil
        ))
        return stack
    }

    private func planButton(plan: UIKitPlanOption, title: String, price: String, detail: String?) -> UIButton {
        let selected = selectedPlan == plan
        let button = UIButton(type: .custom)
        button.accessibilityIdentifier = plan == .annual ? "upgrade.plan.annual" : "upgrade.plan.monthly"
        button.accessibilityLabel = [title, price, detail, selected ? localized("accessibility.selected", defaultValue: "Selected") : nil]
            .compactMap { $0 }
            .joined(separator: ", ")
        button.backgroundColor = selected ? UIKitDesign.active : UIKitDesign.surface
        button.layer.borderWidth = UIKitDesign.hairline
        button.layer.borderColor = selected ? UIKitDesign.hairlineStrong.cgColor : UIKitDesign.hairlineColor.cgColor
        button.accessibilityTraits = selected ? [.button, .selected] : .button

        let stack = UIKitDesign.verticalStack(spacing: Spacing.baselinePair)
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(stack)
        stack.addArrangedSubview(UIKitDesign.label(UIKitDesign.microText(title), font: UIKitDesign.regular(12), color: UIKitDesign.textTertiary))
        stack.addArrangedSubview(UIKitDesign.label(price, font: UIKitDesign.medium(19), color: UIKitDesign.textPrimary))
        if let detail {
            stack.addArrangedSubview(UIKitDesign.label(detail, font: UIKitDesign.regular(12), color: UIKitDesign.textSecondary))
        }
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: Spacing.sm),
            stack.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -Spacing.sm),
            stack.topAnchor.constraint(equalTo: button.topAnchor, constant: Spacing.sm),
            stack.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -Spacing.sm),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 88)
        ])
        button.addAction(UIAction { [weak self] _ in
            self?.selectedPlan = plan
            Haptics.select()
            self?.rebuild()
        }, for: .touchUpInside)
        return button
    }

    private func subscriptionDisclosureRows() -> [UIView] {
        [
            summaryRow(
                title: localized("upgrade.disclosure.price", defaultValue: "Price"),
                trailing: activePriceText,
                accessibilityIdentifier: "upgrade.disclosure.price"
            ),
            divider(),
            summaryRow(
                title: localized("upgrade.disclosure.trial", defaultValue: "Trial"),
                trailing: trialAvailable
                    ? localized("upgrade.disclosure.trial.available", defaultValue: "Shown before billing.")
                    : localized("upgrade.disclosure.trial.none", defaultValue: "No trial is assumed until the App Store confirms it."),
                accessibilityIdentifier: "upgrade.disclosure.trial"
            ),
            divider(),
            summaryRow(
                title: localized("upgrade.disclosure.renewal", defaultValue: "Renewal"),
                trailing: localized("upgrade.disclosure.renewal.copy", defaultValue: "Renews automatically. Cancel anytime in App Store subscriptions."),
                accessibilityIdentifier: "upgrade.disclosure.renewal"
            ),
            divider(),
            summaryRow(
                title: localized("upgrade.disclosure.restore", defaultValue: "Restore"),
                trailing: localized("upgrade.disclosure.restore.copy", defaultValue: "Existing subscribers can restore purchases here."),
                accessibilityIdentifier: "upgrade.disclosure.restore"
            )
        ]
    }

    private func summaryRow(title: String, trailing: String, accessibilityIdentifier: String) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .top
        row.spacing = Spacing.sm
        row.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UIKitDesign.label(title, font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
        let trailingLabel = UIKitDesign.label(trailing, font: UIKitDesign.regular(15), color: UIKitDesign.textPrimary, lines: 0)
        trailingLabel.textAlignment = .right
        trailingLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(trailingLabel)
        titleLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 96).isActive = true
        row.isAccessibilityElement = true
        row.accessibilityIdentifier = accessibilityIdentifier
        row.accessibilityLabel = "\(title), \(trailing)"
        return row
    }

    private func footerActions() -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Spacing.xs
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(quietButton(title: localized("upgrade.button.restorePurchases"), action: #selector(restore), accessibilityIdentifier: "upgrade.restore"))
        stack.addArrangedSubview(quietButton(title: localized("link.terms"), action: #selector(openTerms), accessibilityIdentifier: "upgrade.terms"))
        stack.addArrangedSubview(quietButton(title: localized("link.privacy"), action: #selector(openPrivacy), accessibilityIdentifier: "upgrade.privacy"))
        return stack
    }

    private func quietButton(title: String, action: Selector, accessibilityIdentifier: String? = nil) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.accessibilityIdentifier = accessibilityIdentifier
        button.setTitleColor(UIKitDesign.textSecondary, for: .normal)
        button.titleLabel?.font = UIKitDesign.regular(13)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.layer.borderWidth = UIKitDesign.hairline
        button.layer.borderColor = UIKitDesign.hairlineColor.cgColor
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func setLoading(_ loading: Bool) {
        isLoadingOffering = loading
        rebuild()
    }

    private func setPurchasing(_ purchasing: Bool) {
        isPurchasing = purchasing
        if purchasing == false {
            subscriptionAction = nil
        }
        rebuild()
    }

    private func loadOffering() async {
        setLoading(true)
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
        setLoading(false)
    }

    private func localized(_ key: String.LocalizationValue) -> String {
        UIKitStrings.localized(key, locale: locale)
    }

    private func localized(_ key: StaticString, defaultValue: String.LocalizationValue) -> String {
        UIKitStrings.localized(key, defaultValue: defaultValue, locale: locale)
    }

    @objc private func retryOffering() {
        Task { await loadOffering() }
    }

    @objc private func subscribe() {
        guard let package = activePackage else { return }
        subscriptionAction = .purchase
        setPurchasing(true)
        errorMessage = nil
        Task {
            do {
                try await container.subscriptionService.purchase(package: package)
                Haptics.success()
                dismiss(animated: true)
            } catch {
                errorMessage = error.localizedDescription
                setPurchasing(false)
            }
        }
    }

    @objc private func restore() {
        subscriptionAction = .restore
        setPurchasing(true)
        errorMessage = nil
        Task {
            do {
                try await container.subscriptionService.restorePurchases()
                Haptics.success()
                dismiss(animated: true)
            } catch {
                errorMessage = error.localizedDescription
                setPurchasing(false)
            }
        }
    }

    @objc private func openTerms() {
        guard let url = URL(string: "https://haaanw.github.io/WorkloadManagementApp/terms.html") else { return }
        UIApplication.shared.open(url)
    }

    @objc private func openPrivacy() {
        guard let url = URL(string: "https://haaanw.github.io/WorkloadManagementApp/privacy.html") else { return }
        UIApplication.shared.open(url)
    }

    @objc private func closeUpgrade() {
        Haptics.tap()
        dismiss(animated: true)
    }
}

private final class PDFReportViewController: InstrumentScrollViewController {
    private let container: AppContainer
    private let modelContext: ModelContext
    private var selectedRange: PDFReportEngine.ReportDateRange = .fourWeeks
    private var isGenerating = false
    private var errorMessage: String?
    private let actionDock = UIKitBottomActionDock(primaryTitle: "Generate PDF")

    init(container: AppContainer, modelContext: ModelContext) {
        self.container = container
        self.modelContext = modelContext
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "PDF Report"
        let cancelItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(closeReport)
        )
        cancelItem.accessibilityIdentifier = "export.pdf.cancel"
        navigationItem.leftBarButtonItem = cancelItem
        actionDock.primaryButton.addTarget(self, action: #selector(generateReport), for: .touchUpInside)
        installBottomActionDock(actionDock)
        applyScreenshotReportStateIfNeeded()
    }

    override func rebuild() {
        clearContent()
        let athlete = currentAthlete(in: modelContext)
        actionDock.updatePrimary(
            title: isGenerating ? "Generating..." : "Generate PDF",
            isEnabled: !isGenerating && athlete != nil,
            accessibilityIdentifier: "export.pdf.generate",
            accessibilityValue: reportStateText
        )
        addHorizontalInsets(hero(
            kicker: "Export",
            title: "Training report",
            body: athlete.map { "\($0.displayName) · \($0.sportType.displayName)" } ?? "Choose a date range and generate a PDF."
        ), top: Spacing.sm)
        addHorizontalInsets(reportStatePlate(), top: Spacing.sm)

        addSection(title: "Range", content: dataPlate([rangeSelector()], spacing: Spacing.sm))

        var rows: [UIView] = []
        if let errorMessage {
            let error = UIKitDesign.label(errorMessage, font: UIKitDesign.regular(15), color: UIColor(ColorTokens.zoneDanger), lines: 0)
            error.accessibilityIdentifier = "export.pdf.error"
            rows.append(error)
            rows.append(divider())
        }
        if !rows.isEmpty {
            addSection(title: "Report", content: dataPlate(rows, spacing: Spacing.sm))
        }
    }

    private var reportStateText: String {
        if isGenerating {
            return "Generating report"
        }
        if errorMessage != nil {
            return "Recoverable failure"
        }
        if currentAthlete(in: modelContext) == nil {
            return "No athlete profile"
        }
        return "Ready"
    }

    private func reportStatePlate() -> UIView {
        let label = UIKitDesign.label(reportStateText, font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
        label.accessibilityIdentifier = "export.pdf.state"
        return dataPlate([label], spacing: Spacing.sm)
    }

    private func rangeSelector() -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Spacing.xs
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        for range in PDFReportEngine.ReportDateRange.allCases {
            stack.addArrangedSubview(rangeButton(range))
        }
        return stack
    }

    private func rangeButton(_ range: PDFReportEngine.ReportDateRange) -> UIButton {
        let selected = selectedRange == range
        let button = UIButton(type: .custom)
        button.accessibilityIdentifier = "export.pdf.range.\(range.days)"
        button.accessibilityLabel = range.displayName
        button.setTitle(range.displayName, for: .normal)
        button.setTitleColor(selected ? UIKitDesign.background : UIKitDesign.textSecondary, for: .normal)
        button.titleLabel?.font = selected ? UIKitDesign.medium(15) : UIKitDesign.regular(15)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.numberOfLines = 2
        button.backgroundColor = selected ? UIKitDesign.textPrimary : UIKitDesign.surface
        button.layer.borderWidth = UIKitDesign.hairline
        button.layer.borderColor = UIKitDesign.hairlineColor.cgColor
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true
        button.accessibilityTraits = selected ? [.button, .selected] : .button
        button.accessibilityValue = selected ? "Selected" : nil
        button.addAction(UIAction { [weak self] _ in
            self?.selectedRange = range
            Haptics.select()
            self?.rebuild()
        }, for: .touchUpInside)
        return button
    }

    @objc private func generateReport() {
        guard let athlete = currentAthlete(in: modelContext), !isGenerating else { return }
        isGenerating = true
        errorMessage = nil
        rebuild()

        Task {
            do {
                let workoutRepo = WorkoutRepository(modelContext: modelContext)
                let sessions = try workoutRepo.fetchSessions(last: selectedRange.days, athlete: athlete)

                let workloadRepo = WorkloadRepository(modelContext: modelContext)
                let workloadSnapshots = try workloadRepo.fetchSnapshots(last: selectedRange.days, athlete: athlete)

                let recoveryRepo = RecoveryRepository(modelContext: modelContext)
                let recoverySnapshots = try recoveryRepo.fetchRecoveryHistory(days: selectedRange.days, athlete: athlete)

                let cutoff = Calendar.current.date(
                    byAdding: .day,
                    value: -selectedRange.days,
                    to: .now
                ) ?? .now
                let athleteId = athlete.id
                var prDescriptor = FetchDescriptor<PersonalRecord>(
                    predicate: #Predicate<PersonalRecord> {
                        $0.achievedAt >= cutoff && $0.athlete?.id == athleteId
                    }
                )
                prDescriptor.sortBy = [SortDescriptor(\.achievedAt, order: .reverse)]
                let personalRecords = (try? modelContext.fetch(prDescriptor)) ?? []
                let streakCount = StreakEngine.computeStreak(sessions: sessions)

                let pdfData = PDFReportEngine.generateAthleteReport(
                    athlete: athlete,
                    sessions: sessions,
                    workloadSnapshots: workloadSnapshots,
                    recoverySnapshots: recoverySnapshots,
                    personalRecords: personalRecords,
                    streakCount: streakCount,
                    dateRange: selectedRange
                )

                let dateString = Date.now.formatted(.dateTime.year().month().day())
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("tuwa_report_\(dateString).pdf")
                try pdfData.write(to: tempURL)
                isGenerating = false
                rebuild()
                let share = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
                present(share, animated: true)
            } catch {
                print("PDF generation error: \(error)")
                errorMessage = "Report generation failed. Please try again."
                isGenerating = false
                rebuild()
            }
        }
    }

    @objc private func closeReport() {
        Haptics.tap()
        dismiss(animated: true)
    }

    private func applyScreenshotReportStateIfNeeded() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("SCREENSHOT_PDF_GENERATING_MODE") {
            isGenerating = true
        } else if args.contains("SCREENSHOT_PDF_ERROR_MODE") {
            errorMessage = "Report generation failed. Please try again."
        }
        #endif
    }
}

private enum UIKitExportFormat {
    case sessionSummary
    case detailedSets
}

private final class ExportOptionsViewController: InstrumentScrollViewController {
    private let container: AppContainer
    private let modelContext: ModelContext
    private let actionDock = UIKitBottomActionDock(primaryTitle: "PDF Report")

    init(container: AppContainer, modelContext: ModelContext) {
        self.container = container
        self.modelContext = modelContext
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Export"
        let cancelItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(closeExport)
        )
        cancelItem.accessibilityIdentifier = "export.cancel"
        navigationItem.leftBarButtonItem = cancelItem
        actionDock.primaryButton.addTarget(self, action: #selector(openPDFReport), for: .touchUpInside)
        installBottomActionDock(actionDock)
    }

    override func rebuild() {
        clearContent()
        actionDock.updatePrimary(
            title: "PDF Report",
            accessibilityIdentifier: "export.pdfReport",
            accessibilityValue: "Generate a date-ranged PDF training report"
        )
        addHorizontalInsets(hero(
            kicker: "Export",
            title: "Workout data",
            body: "Choose a CSV file for analysis, or generate a date-ranged training report."
        ), top: Spacing.sm)
        addHorizontalInsets(exportStatePlate(), top: Spacing.sm)

        let rows: [UIView] = [
            exportRow(
                title: "Session summary CSV",
                subtitle: "One row per workout with load, duration, and session context.",
                accessibilityIdentifier: "export.csvSummary",
                action: #selector(exportSessionSummary)
            ),
            divider(),
            exportRow(
                title: "Detailed sets CSV",
                subtitle: "Exercise and set-level rows for deeper training review.",
                accessibilityIdentifier: "export.csvDetailed",
                action: #selector(exportDetailedSets)
            )
        ]
        addSection(title: "CSV", content: dataPlate(rows, spacing: Spacing.sm))
    }

    private func exportStatePlate() -> UIView {
        let label = UIKitDesign.label(
            "Ready",
            font: UIKitDesign.regular(15),
            color: UIKitDesign.textSecondary,
            lines: 0
        )
        label.accessibilityIdentifier = "export.options.state"
        return dataPlate([label], spacing: Spacing.sm)
    }

    private func exportRow(
        title: String,
        subtitle: String,
        accessibilityIdentifier: String,
        action: Selector
    ) -> UIButton {
        let button = UIButton(type: .custom)
        button.accessibilityIdentifier = accessibilityIdentifier
        button.accessibilityLabel = title
        button.accessibilityValue = subtitle
        button.addTarget(self, action: action, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true

        let row = disclosureRow(title: title, subtitle: subtitle)
        row.isUserInteractionEnabled = false
        button.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            row.topAnchor.constraint(equalTo: button.topAnchor),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return button
    }

    @objc private func exportSessionSummary() {
        Haptics.tap()
        exportCSV(format: .sessionSummary, from: self, modelContext: modelContext)
    }

    @objc private func exportDetailedSets() {
        Haptics.tap()
        exportCSV(format: .detailedSets, from: self, modelContext: modelContext)
    }

    @objc private func openPDFReport() {
        Haptics.tap()
        let controller = PDFReportViewController(
            container: container,
            modelContext: modelContext
        )
        showInstrumentDetail(controller)
    }

    @objc private func closeExport() {
        Haptics.tap()
        dismiss(animated: true)
    }
}

private func presentExportOptions(
    from presenter: UIViewController,
    container: AppContainer,
    modelContext: ModelContext
) {
    guard container.subscriptionService.isPro else {
        let controller = UpgradeViewController(container: container, trigger: .export)
        presenter.present(InstrumentNavigationController(rootViewController: controller), animated: true)
        return
    }

    let controller = ExportOptionsViewController(
        container: container,
        modelContext: modelContext
    )
    presenter.present(InstrumentNavigationController(rootViewController: controller), animated: true)
}

private func exportCSV(
    format: UIKitExportFormat,
    from presenter: UIViewController,
    modelContext: ModelContext
) {
    let sessions = scopedWorkoutSessions(modelContext: modelContext)
    let csvString: String
    let filename: String
    let dateString = Date.now.formatted(.dateTime.year().month().day())

    switch format {
    case .sessionSummary:
        csvString = CSVExportEngine.sessionSummaryCSV(sessions: sessions)
        filename = "tuwa_sessions_\(dateString).csv"
    case .detailedSets:
        csvString = CSVExportEngine.detailedSetsCSV(sessions: sessions)
        filename = "tuwa_sets_\(dateString).csv"
    }

    let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    do {
        try csvString.write(to: url, atomically: true, encoding: .utf8)
        let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        presenter.present(share, animated: true)
    } catch {
        let alert = UIAlertController(title: "Export failed", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        presenter.present(alert, animated: true)
    }
}

private func currentAthlete(in modelContext: ModelContext) -> Athlete? {
    ((try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []).first
}

private func scopedWorkoutSessions(modelContext: ModelContext) -> [WorkoutSession] {
    guard let athleteId = currentAthlete(in: modelContext)?.id else { return [] }
    let descriptor = FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.sessionDate, order: .reverse)])
    return ((try? modelContext.fetch(descriptor)) ?? [])
        .filter { $0.athlete?.id == athleteId }
}

private final class RecoveryInsightsDetailViewController: InstrumentScrollViewController {
    private let container: AppContainer
    private let modelContext: ModelContext
    private let locale: Locale

    init(container: AppContainer, modelContext: ModelContext, locale: Locale) {
        self.container = container
        self.modelContext = modelContext
        self.locale = locale
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Recovery Detail"
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(close))
    }

    override func rebuild() {
        clearContent()
        let snapshots = loadRecoverySnapshots(limit: 28)
        let checkIns = loadCheckIns(limit: 14)
        let latest = snapshots.first

        addHorizontalInsets(hero(
            kicker: "Recovery Detail",
            title: latest.map { "\(Int($0.recoveryScore))" } ?? "No data",
            body: detailBody(latest: latest)
        ), top: Spacing.sm)

        addSection(title: "Current Signals", content: metricRail([
            ("HRV", latest?.hrvSDNN.map { "\(Int($0))" } ?? "--", latest?.hrvBaseline.map { "Baseline \(Int($0))" } ?? "No baseline"),
            ("RHR", latest?.restingHR.map { "\(Int($0))" } ?? "--", latest?.restingHRBaseline.map { "Baseline \(Int($0))" } ?? "No baseline"),
            ("Sleep", latest?.sleepDurationMinutes.map { String(format: "%.1f", $0 / 60) } ?? "--", "hours")
        ]))

        addSection(title: "HealthKit", content: dataPlate([
            disclosureRow(title: "Connection", subtitle: healthStateTitle(container.healthKitService.connectionState), trailing: nil),
            divider(),
            disclosureRow(title: "Source", subtitle: latest?.dataSource.rawValue ?? "No source", trailing: nil)
        ], spacing: Spacing.sm))

        addSection(title: "28-day Recovery", content: dataPlate(recoveryRows(snapshots), spacing: Spacing.sm))
        addSection(title: "Wellness Check-ins", content: dataPlate(checkInRows(checkIns), spacing: Spacing.sm))
    }

    private func loadRecoverySnapshots(limit: Int) -> [RecoverySnapshot] {
        guard let athleteId = currentAthlete(in: modelContext)?.id else { return [] }
        var descriptor = FetchDescriptor<RecoverySnapshot>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = limit
        return ((try? modelContext.fetch(descriptor)) ?? []).filter { $0.athlete?.id == athleteId }
    }

    private func loadCheckIns(limit: Int) -> [WellnessCheckIn] {
        guard let athleteId = currentAthlete(in: modelContext)?.id else { return [] }
        var descriptor = FetchDescriptor<WellnessCheckIn>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = limit
        return ((try? modelContext.fetch(descriptor)) ?? []).filter { $0.athlete?.id == athleteId }
    }

    private func detailBody(latest: RecoverySnapshot?) -> String {
        guard let latest else {
            return "Connect Apple Health and complete check-ins to build a recovery record."
        }
        return "\(latest.zone.displayName) · Updated \(latest.date.relativeString(locale: locale))"
    }

    private func healthStateTitle(_ state: HealthKitConnectionState) -> String {
        switch state {
        case .notRequested: "Not connected"
        case .requestedNoData: "Connected, no recent data"
        case .connected: "Connected"
        }
    }

    private func recoveryRows(_ snapshots: [RecoverySnapshot]) -> [UIView] {
        guard !snapshots.isEmpty else {
            return [
                UIKitDesign.label("No recovery history yet", font: UIKitDesign.medium(19), color: UIKitDesign.textPrimary),
                UIKitDesign.label("Recent HRV, RHR, sleep, and composite score will appear here.", font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
            ]
        }
        return snapshots.prefix(10).enumerated().flatMap { index, snapshot -> [UIView] in
            var rows: [UIView] = [
                disclosureRow(
                    title: snapshot.date.relativeString(locale: locale),
                    subtitle: [
                        snapshot.zone.displayName,
                        snapshot.hrvSDNN.map { "HRV \(Int($0))" },
                        snapshot.restingHR.map { "RHR \(Int($0))" }
                    ].compactMap { $0 }.joined(separator: " · "),
                    trailing: "\(Int(snapshot.recoveryScore))"
                )
            ]
            if index < min(snapshots.count, 10) - 1 { rows.append(divider()) }
            return rows
        }
    }

    private func checkInRows(_ checkIns: [WellnessCheckIn]) -> [UIView] {
        guard !checkIns.isEmpty else {
            return [
                UIKitDesign.label("No check-ins yet", font: UIKitDesign.medium(19), color: UIKitDesign.textPrimary),
                UIKitDesign.label("Morning check-ins will add subjective context to recovery.", font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
            ]
        }
        return checkIns.prefix(7).enumerated().flatMap { index, checkIn -> [UIView] in
            let row = disclosureRow(
                title: checkIn.date.relativeString(locale: locale),
                subtitle: "Sleep \(checkIn.sleepQuality) · Energy \(checkIn.energy) · Soreness \(checkIn.soreness) · Stress \(checkIn.stress)",
                trailing: "\(Int(checkIn.wellnessScore))"
            )
            row.isAccessibilityElement = true
            row.accessibilityIdentifier = "recoveryDetail.checkIn"
            row.accessibilityLabel = "Check-in, wellness score \(Int(checkIn.wellnessScore))"
            var rows: [UIView] = [
                row
            ]
            if index < min(checkIns.count, 7) - 1 { rows.append(divider()) }
            return rows
        }
    }

    @objc private func close() {
        dismiss(animated: true)
    }
}

private final class LoadInsightsDetailViewController: InstrumentScrollViewController {
    private let container: AppContainer
    private let modelContext: ModelContext
    private let locale: Locale

    init(container: AppContainer, modelContext: ModelContext, locale: Locale) {
        self.container = container
        self.modelContext = modelContext
        self.locale = locale
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Load Detail"
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(close))
        let export = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(openExport))
        export.accessibilityIdentifier = "export.workoutData"
        navigationItem.rightBarButtonItem = export
    }

    override func rebuild() {
        clearContent()
        let snapshots = loadSnapshots(limit: 84)
        let sessions = scopedWorkoutSessions(modelContext: modelContext)
        let records = loadPersonalRecords(limit: 8)
        let latest = snapshots.first

        addHorizontalInsets(hero(
            kicker: "Load Detail",
            title: latest.map { String(format: "%.2f", $0.acwr) } ?? "No data",
            body: detailBody(latest: latest)
        ), top: Spacing.sm)

        addSection(title: "Load Balance", content: metricRail([
            ("ATL", latest.map { String(format: "%.0f", $0.acuteLoad) } ?? "--", "Acute"),
            ("CTL", latest.map { String(format: "%.0f", $0.chronicLoad) } ?? "--", "Chronic"),
            ("TSB", latest.map { String(format: "%+.0f", $0.tsb) } ?? "--", latest.map { $0.tsb >= 0 ? "Fresh" : "Fatigued" } ?? "Balance")
        ]))

        addSection(title: "Workload History", content: dataPlate(loadRows(snapshots), spacing: Spacing.sm))
        addSection(title: "Recent Sessions", content: dataPlate(sessionRows(sessions), spacing: Spacing.sm))
        addSection(title: "Personal Records", content: dataPlate(recordRows(records), spacing: Spacing.sm))
    }

    private func loadSnapshots(limit: Int) -> [WorkloadSnapshot] {
        guard let athleteId = currentAthlete(in: modelContext)?.id else { return [] }
        var descriptor = FetchDescriptor<WorkloadSnapshot>(sortBy: [SortDescriptor(\.snapshotDate, order: .reverse)])
        descriptor.fetchLimit = limit
        return ((try? modelContext.fetch(descriptor)) ?? []).filter { $0.athlete?.id == athleteId }
    }

    private func loadPersonalRecords(limit: Int) -> [PersonalRecord] {
        guard let athleteId = currentAthlete(in: modelContext)?.id else { return [] }
        var descriptor = FetchDescriptor<PersonalRecord>(sortBy: [SortDescriptor(\.achievedAt, order: .reverse)])
        descriptor.fetchLimit = limit
        return ((try? modelContext.fetch(descriptor)) ?? []).filter { $0.athlete?.id == athleteId }
    }

    private func detailBody(latest: WorkloadSnapshot?) -> String {
        guard let latest else {
            return "Log sessions to build acute, chronic, and balance history."
        }
        return "\(latest.zone.displayName) · Updated \(latest.snapshotDate.relativeString(locale: locale))"
    }

    private func loadRows(_ snapshots: [WorkloadSnapshot]) -> [UIView] {
        guard !snapshots.isEmpty else {
            return [
                UIKitDesign.label("No workload history yet", font: UIKitDesign.medium(19), color: UIKitDesign.textPrimary),
                UIKitDesign.label("ACWR, ATL, CTL, TSB, and volume will appear after workout saves.", font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
            ]
        }
        return snapshots.prefix(12).enumerated().flatMap { index, snapshot -> [UIView] in
            var rows: [UIView] = [
                disclosureRow(
                    title: snapshot.snapshotDate.relativeString(locale: locale),
                    subtitle: "ATL \(Int(snapshot.acuteLoad)) · CTL \(Int(snapshot.chronicLoad)) · TSB \(Int(snapshot.tsb))",
                    trailing: String(format: "%.2f", snapshot.acwr)
                )
            ]
            if index < min(snapshots.count, 12) - 1 { rows.append(divider()) }
            return rows
        }
    }

    private func sessionRows(_ sessions: [WorkoutSession]) -> [UIView] {
        guard !sessions.isEmpty else {
            return [
                UIKitDesign.label("No sessions yet", font: UIKitDesign.medium(19), color: UIKitDesign.textPrimary),
                UIKitDesign.label("Training load starts with logged workouts.", font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
            ]
        }
        return sessions.prefix(8).enumerated().flatMap { index, session -> [UIView] in
            var rows: [UIView] = [
                disclosureRow(
                    title: session.sessionName ?? session.sportType.displayName,
                    subtitle: "\(session.sessionDate.relativeString(locale: locale)) · \(Int(session.durationMinutes)) min · \(Int(session.totalVolume)) volume",
                    trailing: "\(Int(session.trainingStress))"
                )
            ]
            if index < min(sessions.count, 8) - 1 { rows.append(divider()) }
            return rows
        }
    }

    private func recordRows(_ records: [PersonalRecord]) -> [UIView] {
        guard !records.isEmpty else {
            return [
                UIKitDesign.label("No PRs yet", font: UIKitDesign.medium(19), color: UIKitDesign.textPrimary),
                UIKitDesign.label("Personal records appear after enough performed sets are saved.", font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
            ]
        }
        return records.prefix(8).enumerated().flatMap { index, record -> [UIView] in
            let improvement = record.improvement.map { String(format: " · +%.1f", $0) } ?? ""
            var rows: [UIView] = [
                disclosureRow(
                    title: record.exerciseName,
                    subtitle: "\(record.recordType.displayName)\(improvement)",
                    trailing: String(format: "%.1f", record.value)
                )
            ]
            if index < min(records.count, 8) - 1 { rows.append(divider()) }
            return rows
        }
    }

    @objc private func openExport() {
        presentExportOptions(from: self, container: container, modelContext: modelContext)
    }

    @objc private func close() {
        dismiss(animated: true)
    }
}

private final class CoachRosterViewController: InstrumentScrollViewController {
    private let container: AppContainer
    private let modelContext: ModelContext
    private let locale: Locale

    init(container: AppContainer, modelContext: ModelContext, locale: Locale) {
        self.container = container
        self.modelContext = modelContext
        self.locale = locale
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func rebuild() {
        clearContent()
        let data = loadRosterData()
        let state = CoachRosterViewState.make(
            linkedAthletes: data.linkedAthletes,
            recovery: data.recovery,
            workload: data.workload,
            sessions: data.sessions,
            prescriptions: data.prescriptions,
            locale: locale
        )
        addHorizontalInsets(hero(kicker: state.heroKicker, title: state.countText, body: state.statusText), top: Spacing.sm)

        if state.rows.isEmpty {
            addSection(content: dataPlate([
                UIKitDesign.label(state.emptyTitle, font: UIKitDesign.medium(19), color: UIKitDesign.textPrimary),
                UIKitDesign.label(state.emptyBody, font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
            ], spacing: Spacing.xs))
        } else {
            var rows: [UIView] = []
            for (index, rowState) in state.rows.enumerated() {
                guard let athlete = data.linkedAthletes.first(where: { $0.id == rowState.athleteID }) else { continue }
                rows.append(rosterRow(rowState, athlete: athlete))
                if index < state.rows.count - 1 {
                    rows.append(divider())
                }
            }
            addSection(title: "Athletes", content: dataPlate(rows, spacing: Spacing.sm))
        }
    }

    private func loadRosterData() -> (
        linkedAthletes: [Athlete],
        recovery: [RecoverySnapshot],
        workload: [WorkloadSnapshot],
        sessions: [WorkoutSession],
        prescriptions: [PrescribedWorkout]
    ) {
        let athletes = (try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []
        let relationships = (try? modelContext.fetch(FetchDescriptor<CoachAthleteRelationship>())) ?? []
        let recovery = (try? modelContext.fetch(FetchDescriptor<RecoverySnapshot>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        let workload = (try? modelContext.fetch(FetchDescriptor<WorkloadSnapshot>(sortBy: [SortDescriptor(\.snapshotDate, order: .reverse)]))) ?? []
        let sessions = (try? modelContext.fetch(FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.sessionDate, order: .reverse)]))) ?? []
        let prescriptions = (try? modelContext.fetch(FetchDescriptor<PrescribedWorkout>())) ?? []

        guard let coachId = athletes.first?.id else {
            return ([], recovery, workload, sessions, prescriptions)
        }
        let linkedIds = Set(
            relationships
                .filter { $0.coachId == coachId && $0.status == .accepted }
                .map(\.athleteId)
        )
        let linkedAthletes = athletes
            .filter { linkedIds.contains($0.id) }
            .sorted { $0.displayName < $1.displayName }
        return (linkedAthletes, recovery, workload, sessions, prescriptions)
    }

    private func rosterRow(
        _ rowState: CoachRosterViewState.AthleteRow,
        athlete: Athlete
    ) -> UIView {
        let stack = UIKitDesign.verticalStack(spacing: Spacing.xs)
        let top = UIStackView()
        top.axis = .horizontal
        top.alignment = .firstBaseline
        top.spacing = Spacing.sm
        top.translatesAutoresizingMaskIntoConstraints = false
        let name = UIKitDesign.label(rowState.name, font: UIKitDesign.medium(17), color: UIKitDesign.textPrimary)
        let sport = UIKitDesign.label(rowState.sportText, font: UIKitDesign.regular(15), color: UIKitDesign.textTertiary)
        top.addArrangedSubview(name)
        top.addArrangedSubview(UIView())
        top.addArrangedSubview(sport)

        stack.addArrangedSubview(top)
        stack.addArrangedSubview(UIKitDesign.label(rowState.rosterText, font: UIKitDesign.regular(13), color: UIKitDesign.textSecondary, lines: 0))

        let button = UIButton(type: .custom)
        button.accessibilityIdentifier = "coachRoster.athlete"
        button.accessibilityLabel = "\(rowState.name), \(rowState.accessibilityText)"
        button.addAction(UIAction { [weak self] _ in
            self?.openAthleteDetail(athlete)
        }, for: .touchUpInside)
        stack.isUserInteractionEnabled = false
        button.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            stack.topAnchor.constraint(equalTo: button.topAnchor),
            stack.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return button
    }

    private func openAthleteDetail(_ athlete: Athlete) {
        Haptics.tap()
        let controller = CoachAthleteDetailViewController(
            athlete: athlete,
            container: container,
            modelContext: modelContext
        )
        showInstrumentDetail(controller)
    }
}

private enum CoachAthleteDetailSection: Int, CaseIterable {
    case overview
    case plan
    case history

    var title: String {
        switch self {
        case .overview: "Overview"
        case .plan: "Plan"
        case .history: "History"
        }
    }
}

private final class CoachAthleteDetailViewController: InstrumentScrollViewController {
    private let athlete: Athlete
    private let container: AppContainer
    private let modelContext: ModelContext
    private var selectedSection: CoachAthleteDetailSection = .overview

    init(athlete: Athlete, container: AppContainer, modelContext: ModelContext) {
        self.athlete = athlete
        self.container = container
        self.modelContext = modelContext
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = athlete.displayName
    }

    override func rebuild() {
        clearContent()
        let data = loadDetailData()
        addHorizontalInsets(hero(
            kicker: "Coach athlete",
            title: athlete.displayName,
            body: "\(athlete.sportType.displayName) · \(scopeSummary(data: data))"
        ), top: Spacing.sm)
        addHorizontalInsets(sectionSelector(), top: Spacing.md)

        switch selectedSection {
        case .overview:
            addOverview(data: data)
        case .plan:
            addPlan(data: data)
        case .history:
            addHistory(data: data)
        }
    }

    private func sectionSelector() -> UIView {
        let control = InstrumentSegmentedControlUIKit(titles: CoachAthleteDetailSection.allCases.map(\.title))
        control.selectedIndex = selectedSection.rawValue
        control.onSelectionChanged = { [weak self] index in
            guard let self, let section = CoachAthleteDetailSection(rawValue: index) else { return }
            selectedSection = section
            rebuild()
        }
        return control
    }

    private func loadDetailData() -> (
        recovery: [RecoverySnapshot],
        workload: [WorkloadSnapshot],
        sessions: [WorkoutSession],
        prescriptions: [PrescribedWorkout]
    ) {
        let athleteId = athlete.id
        let recovery = ((try? modelContext.fetch(FetchDescriptor<RecoverySnapshot>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? [])
            .filter { $0.athlete?.id == athleteId }
        let workload = ((try? modelContext.fetch(FetchDescriptor<WorkloadSnapshot>(sortBy: [SortDescriptor(\.snapshotDate, order: .reverse)]))) ?? [])
            .filter { $0.athlete?.id == athleteId }
        let sessions = ((try? modelContext.fetch(FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.sessionDate, order: .reverse)]))) ?? [])
            .filter { $0.athlete?.id == athleteId }
        let prescriptions = ((try? modelContext.fetch(FetchDescriptor<PrescribedWorkout>(sortBy: [SortDescriptor(\.scheduledDate, order: .reverse)]))) ?? [])
            .filter { $0.athleteId == athleteId }
        return (recovery, workload, sessions, prescriptions)
    }

    private func addOverview(data: (
        recovery: [RecoverySnapshot],
        workload: [WorkloadSnapshot],
        sessions: [WorkoutSession],
        prescriptions: [PrescribedWorkout]
    )) {
        let marker = UIKitDesign.label("OVERVIEW", font: UIKitDesign.regular(12), color: UIKitDesign.textTertiary)
        marker.accessibilityIdentifier = "coachAthleteDetail.overview"
        addSection(content: dataPlate([marker], spacing: Spacing.sm))

        let latestRecovery = data.recovery.first
        let latestWorkload = data.workload.first
        let latestSession = data.sessions.first
        addSection(title: "Readiness", content: metricRail([
            ("Recovery", latestRecovery.map { "\(Int($0.recoveryScore))" } ?? "--", latestRecovery?.zone.displayName ?? "No recovery"),
            ("Load", latestWorkload.map { String(format: "%.2f", $0.acwr) } ?? "--", latestWorkload?.zone.displayName ?? "No load"),
            ("Last", latestSession.map { "\(Int($0.trainingStress))" } ?? "--", latestSession?.sessionDate.relativeString(locale: .current) ?? "No sessions")
        ]))

        addSection(title: "Attention", content: dataPlate([
            disclosureRow(
                title: "Today",
                subtitle: todayStatus(from: data.prescriptions),
                trailing: nil
            ),
            divider(),
            disclosureRow(
                title: "Coach read",
                subtitle: attentionText(recovery: latestRecovery, workload: latestWorkload),
                trailing: nil
            )
        ], spacing: Spacing.sm))
    }

    private func addPlan(data: (
        recovery: [RecoverySnapshot],
        workload: [WorkloadSnapshot],
        sessions: [WorkoutSession],
        prescriptions: [PrescribedWorkout]
    )) {
        let marker = UIKitDesign.label("PLAN", font: UIKitDesign.regular(12), color: UIKitDesign.textTertiary)
        marker.accessibilityIdentifier = "coachAthleteDetail.plan"

        addSection(title: "Prescription", content: dataPlate([
            prescribeButton()
        ], spacing: Spacing.sm))

        let lifecycle = UIKitDesign.label(
            "Authored plan -> Coach sent -> Athlete may autoregulate on start -> Completed session links back here.",
            font: UIKitDesign.regular(15),
            color: UIKitDesign.textSecondary,
            lines: 0
        )
        lifecycle.accessibilityIdentifier = "coachAthleteDetail.plan.lifecycle"
        addSection(content: dataPlate([marker, divider(), lifecycle], spacing: Spacing.sm))

        if data.prescriptions.isEmpty {
            addSection(title: "Assigned plans", content: dataPlate([
                UIKitDesign.label("No assigned plans", font: UIKitDesign.medium(19), color: UIKitDesign.textPrimary),
                UIKitDesign.label("Use Plans to prescribe a program, then return here to track sent and completed states.", font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
            ], spacing: Spacing.xs))
        } else {
            addSection(title: "Assigned plans", content: dataPlate(planRows(data.prescriptions), spacing: Spacing.sm))
        }
    }

    private func addHistory(data: (
        recovery: [RecoverySnapshot],
        workload: [WorkloadSnapshot],
        sessions: [WorkoutSession],
        prescriptions: [PrescribedWorkout]
    )) {
        let marker = UIKitDesign.label("HISTORY", font: UIKitDesign.regular(12), color: UIKitDesign.textTertiary)
        marker.accessibilityIdentifier = "coachAthleteDetail.history"
        addSection(content: dataPlate([marker], spacing: Spacing.sm))

        if data.sessions.isEmpty {
            addSection(title: "Recent sessions", content: dataPlate([
                UIKitDesign.label("No sessions yet", font: UIKitDesign.medium(19), color: UIKitDesign.textPrimary),
                UIKitDesign.label("Completed athlete sessions appear here with load and duration.", font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
            ], spacing: Spacing.xs))
        } else {
            addSection(title: "Recent sessions", content: dataPlate(sessionRows(data.sessions), spacing: Spacing.sm))
        }
    }

    private func planRows(_ prescriptions: [PrescribedWorkout]) -> [UIView] {
        prescriptions.prefix(8).enumerated().flatMap { index, prescription -> [UIView] in
            let lifecycle = prescription.status == .assigned
                ? "Authored plan · Sent · Athlete autoregulation possible"
                : "Authored plan · \(prescription.status.displayName)"
            let row = disclosureRow(
                title: prescription.templateName,
                subtitle: "\(prescription.scheduledDate.relativeString(locale: .current)) · \(lifecycle)",
                trailing: prescription.status.displayName
            )
            row.isAccessibilityElement = true
            row.accessibilityIdentifier = "coachAthleteDetail.plan.prescription"
            row.accessibilityLabel = "\(prescription.templateName), \(prescription.status.displayName), \(lifecycle)"
            var rows = [row]
            if index < min(prescriptions.count, 8) - 1 {
                rows.append(divider())
            }
            return rows
        }
    }

    private func sessionRows(_ sessions: [WorkoutSession]) -> [UIView] {
        sessions.prefix(8).enumerated().flatMap { index, session -> [UIView] in
            var rows = [
                disclosureRow(
                    title: session.sessionName ?? session.sportType.displayName,
                    subtitle: "\(session.sessionDate.relativeString(locale: .current)) · \(Int(session.durationMinutes)) min",
                    trailing: "\(Int(session.trainingStress)) load"
                )
            ]
            if index < min(sessions.count, 8) - 1 {
                rows.append(divider())
            }
            return rows
        }
    }

    private func prescribeButton() -> UIView {
        let button = UIButton(type: .custom)
        button.accessibilityIdentifier = "coachAthleteDetail.prescribe"
        button.accessibilityLabel = "Assign plan to \(athlete.displayName)"
        button.addTarget(self, action: #selector(openPrescription), for: .touchUpInside)
        let row = disclosureRow(
            title: "Assign plan",
            subtitle: "Pick a template, schedule it, and send it to this athlete.",
            trailing: "New"
        )
        row.isUserInteractionEnabled = false
        button.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            row.topAnchor.constraint(equalTo: button.topAnchor),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return button
    }

    @objc private func openPrescription() {
        Haptics.tap()
        let controller = CoachPrescriptionViewController(
            container: container,
            modelContext: modelContext,
            athlete: athlete
        ) { [weak self] in
            self?.selectedSection = .plan
            self?.rebuild()
        }
        present(InstrumentNavigationController(rootViewController: controller), animated: true)
    }

    private func scopeSummary(data: (
        recovery: [RecoverySnapshot],
        workload: [WorkloadSnapshot],
        sessions: [WorkoutSession],
        prescriptions: [PrescribedWorkout]
    )) -> String {
        let pending = data.prescriptions.filter { $0.status == .assigned }.count
        return "\(pending) pending plan\(pending == 1 ? "" : "s") · \(data.sessions.count) sessions"
    }

    private func todayStatus(from prescriptions: [PrescribedWorkout]) -> String {
        guard let plan = prescriptions.first(where: { Calendar.current.isDateInToday($0.scheduledDate) && $0.status == .assigned }) else {
            return "No assigned plan today."
        }
        return "\(plan.templateName) is assigned for today."
    }

    private func attentionText(recovery: RecoverySnapshot?, workload: WorkloadSnapshot?) -> String {
        let recoveryText = recovery?.zone.displayName ?? "No recovery"
        let loadText = workload?.zone.displayName ?? "No load"
        return "\(recoveryText) · \(loadText)"
    }
}

private enum CoachPrescriptionScheduleOption: String, CaseIterable {
    case today
    case tomorrow
    case nextWeek

    var title: String {
        switch self {
        case .today: "Today"
        case .tomorrow: "Tomorrow"
        case .nextWeek: "Next week"
        }
    }

    var detail: String {
        scheduledDate.formatted(.dateTime.weekday(.wide).month().day())
    }

    var scheduledDate: Date {
        let calendar = Calendar.current
        switch self {
        case .today:
            return calendar.startOfDay(for: .now)
        case .tomorrow:
            let date = calendar.date(byAdding: .day, value: 1, to: .now) ?? .now
            return calendar.startOfDay(for: date)
        case .nextWeek:
            let date = calendar.date(byAdding: .day, value: 7, to: .now) ?? .now
            return calendar.startOfDay(for: date)
        }
    }
}

private final class CoachPrescriptionViewController: InstrumentScrollViewController, UITextFieldDelegate {
    private let container: AppContainer
    private let modelContext: ModelContext
    private let athlete: Athlete
    private let onAssigned: () -> Void
    private var selectedTemplate: WorkoutTemplate?
    private var selectedSchedule: CoachPrescriptionScheduleOption = .today
    private var notes = ""
    private var errorMessage: String?
    private let actionDock = UIKitBottomActionDock(primaryTitle: "Assign Plan")

    init(
        container: AppContainer,
        modelContext: ModelContext,
        athlete: Athlete,
        onAssigned: @escaping () -> Void
    ) {
        self.container = container
        self.modelContext = modelContext
        self.athlete = athlete
        self.onAssigned = onAssigned
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Assign Plan"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(cancelPrescription)
        )
        navigationItem.leftBarButtonItem?.accessibilityIdentifier = "coachPrescription.cancel"
        actionDock.primaryButton.addTarget(self, action: #selector(assignPlan), for: .touchUpInside)
        installBottomActionDock(actionDock)
    }

    override func rebuild() {
        clearContent()
        let templates = loadTemplates()
        reconcileSelection(with: templates)
        actionDock.updatePrimary(
            title: "Assign Plan",
            isEnabled: canAssign,
            accessibilityIdentifier: "coachPrescription.assign",
            accessibilityValue: prescriptionStateText(templates: templates)
        )

        addHorizontalInsets(hero(
            kicker: "Prescription",
            title: athlete.displayName,
            body: selectedTemplate.map { "\($0.templateName) · \(selectedSchedule.title)" } ?? "Choose a template to assign."
        ), top: Spacing.sm)
        addHorizontalInsets(prescriptionStatePlate(templates: templates), top: Spacing.sm)

        if templates.isEmpty {
            addSection(content: dataPlate([
                UIKitDesign.label("No templates available", font: UIKitDesign.medium(19), color: UIKitDesign.textPrimary),
                UIKitDesign.label("Create a coach template first, then return here to assign it.", font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
            ], spacing: Spacing.sm))
        } else {
            addSection(title: "Template", content: dataPlate(templateRows(templates), spacing: Spacing.sm))
        }

        addSection(title: "Schedule", content: dataPlate(scheduleRows(), spacing: Spacing.sm))
        addSection(title: "Notes", content: dataPlate([notesField()], spacing: Spacing.sm))

        if let errorMessage {
            addSection(content: dataPlate([
                UIKitDesign.label(errorMessage, font: UIKitDesign.regular(15), color: UIColor(ColorTokens.zoneDanger), lines: 0)
            ], spacing: Spacing.sm))
        }
    }

    private var canAssign: Bool {
        selectedTemplate != nil && currentCoach() != nil
    }

    private func prescriptionStateText(templates: [WorkoutTemplate]) -> String {
        if errorMessage != nil {
            return "Assignment needs attention"
        }
        guard currentCoach() != nil else {
            return "Coach profile unavailable"
        }
        guard let selectedTemplate else {
            return templates.isEmpty ? "No templates available" : "Template required"
        }
        return "Ready to assign \(selectedTemplate.templateName) for \(selectedSchedule.title)"
    }

    private func prescriptionStatePlate(templates: [WorkoutTemplate]) -> UIView {
        let label = UIKitDesign.label(
            prescriptionStateText(templates: templates),
            font: UIKitDesign.regular(15),
            color: UIKitDesign.textSecondary,
            lines: 0
        )
        label.accessibilityIdentifier = "coachPrescription.state"
        return dataPlate([label], spacing: Spacing.sm)
    }

    private func reconcileSelection(with templates: [WorkoutTemplate]) {
        if let selectedTemplate,
           templates.contains(where: { $0.id == selectedTemplate.id }) {
            return
        }
        selectedTemplate = templates.first
    }

    private func loadTemplates() -> [WorkoutTemplate] {
        guard let coach = currentCoach() else { return [] }
        return ((try? modelContext.fetch(FetchDescriptor<WorkoutTemplate>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        ))) ?? [])
        .filter { !$0.isArchived && ($0.coachId == coach.id || $0.athleteId == coach.id) }
    }

    private func currentCoach() -> Athlete? {
        let athletes = (try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []
        return athletes.first { $0.isCoach } ?? athletes.first { $0.id != athlete.id }
    }

    private func templateRows(_ templates: [WorkoutTemplate]) -> [UIView] {
        templates.enumerated().flatMap { index, template -> [UIView] in
            var rows = [templateButton(template)]
            if index < templates.count - 1 {
                rows.append(divider())
            }
            return rows
        }
    }

    private func templateButton(_ template: WorkoutTemplate) -> UIView {
        let selected = selectedTemplate?.id == template.id
        let button = UIButton(type: .custom)
        button.accessibilityIdentifier = "coachPrescription.template"
        button.accessibilityLabel = [
            template.templateName,
            template.sessionType.displayName,
            selected ? "Selected" : nil
        ].compactMap { $0 }.joined(separator: ", ")
        button.accessibilityTraits = selected ? [.button, .selected] : .button
        button.backgroundColor = selected ? UIKitDesign.active : UIKitDesign.surface
        button.layer.borderWidth = UIKitDesign.hairline
        button.layer.borderColor = selected ? UIKitDesign.hairlineStrong.cgColor : UIKitDesign.hairlineColor.cgColor
        button.addAction(UIAction { [weak self] _ in
            self?.selectedTemplate = template
            self?.errorMessage = nil
            Haptics.select()
            self?.rebuild()
        }, for: .touchUpInside)

        let exerciseCount = template.sortedGroups.flatMap(\.sortedExercises).count
        let row = disclosureRow(
            title: template.templateName,
            subtitle: "\(template.sportType.displayName) · \(template.sessionType.displayName) · \(exerciseCount) exercises",
            trailing: selected ? "Selected" : nil
        )
        row.isUserInteractionEnabled = false
        button.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            row.topAnchor.constraint(equalTo: button.topAnchor),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return button
    }

    private func scheduleRows() -> [UIView] {
        CoachPrescriptionScheduleOption.allCases.enumerated().flatMap { index, option -> [UIView] in
            var rows = [scheduleButton(option)]
            if index < CoachPrescriptionScheduleOption.allCases.count - 1 {
                rows.append(divider())
            }
            return rows
        }
    }

    private func scheduleButton(_ option: CoachPrescriptionScheduleOption) -> UIView {
        let selected = selectedSchedule == option
        let button = UIButton(type: .custom)
        button.accessibilityIdentifier = "coachPrescription.schedule.\(option.rawValue)"
        button.accessibilityLabel = [option.title, option.detail, selected ? "Selected" : nil]
            .compactMap { $0 }
            .joined(separator: ", ")
        button.accessibilityTraits = selected ? [.button, .selected] : .button
        button.backgroundColor = selected ? UIKitDesign.active : UIKitDesign.surface
        button.layer.borderWidth = UIKitDesign.hairline
        button.layer.borderColor = selected ? UIKitDesign.hairlineStrong.cgColor : UIKitDesign.hairlineColor.cgColor
        button.addAction(UIAction { [weak self] _ in
            self?.selectedSchedule = option
            self?.errorMessage = nil
            Haptics.select()
            self?.rebuild()
        }, for: .touchUpInside)

        let row = disclosureRow(title: option.title, subtitle: option.detail, trailing: selected ? "Selected" : nil)
        row.isUserInteractionEnabled = false
        button.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            row.topAnchor.constraint(equalTo: button.topAnchor),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return button
    }

    private func notesField() -> UIView {
        let field = UITextField()
        field.text = notes
        field.placeholder = "Optional note"
        field.delegate = self
        field.accessibilityIdentifier = "coachPrescription.notes"
        field.font = UIKitDesign.regular(17)
        field.textColor = UIKitDesign.textPrimary
        field.tintColor = UIKitDesign.textPrimary
        field.backgroundColor = UIKitDesign.surface
        field.layer.borderWidth = UIKitDesign.hairline
        field.layer.borderColor = UIKitDesign.hairlineColor.cgColor
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: Spacing.xs, height: 1))
        field.leftViewMode = .always
        field.translatesAutoresizingMaskIntoConstraints = false
        field.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        field.addAction(UIAction { [weak self, weak field] _ in
            self?.notes = field?.text ?? ""
        }, for: .editingChanged)
        return field
    }

    @objc private func assignPlan() {
        guard let coach = currentCoach(), let template = selectedTemplate else { return }
        let prescription = PrescribedWorkout(
            coachId: coach.id,
            athleteId: athlete.id,
            templateId: template.id,
            scheduledDate: selectedSchedule.scheduledDate,
            templateName: template.templateName,
            sportType: template.sportType,
            sessionType: template.sessionType,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
        )
        prescription.groups = template.deepCopyGroups()
        modelContext.insert(prescription)

        do {
            try modelContext.save()
            Haptics.success()
            dismiss(animated: true) { [onAssigned] in
                onAssigned()
            }
        } catch {
            modelContext.delete(prescription)
            errorMessage = "Could not assign plan. Please try again."
            rebuild()
        }
    }

    @objc private func cancelPrescription() {
        Haptics.tap()
        dismiss(animated: true)
    }
}

private final class CoachPlansViewController: InstrumentScrollViewController {
    private let container: AppContainer
    private let modelContext: ModelContext
    private let locale: Locale
    private let actionDock = UIKitBottomActionDock(primaryTitle: "New Template", secondaryTitle: "Assign Plan")

    init(container: AppContainer, modelContext: ModelContext, locale: Locale) {
        self.container = container
        self.modelContext = modelContext
        self.locale = locale
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        actionDock.primaryButton.addTarget(self, action: #selector(newTemplate), for: .touchUpInside)
        actionDock.secondaryButton.addTarget(self, action: #selector(openAssignPlan), for: .touchUpInside)
        installBottomActionDock(actionDock)
    }

    override func rebuild() {
        clearContent()
        let data = loadPlanData()
        actionDock.updatePrimary(
            title: "New Template",
            accessibilityIdentifier: "coachPlans.newTemplate",
            accessibilityValue: "Create a reusable coach plan"
        )
        actionDock.updateSecondary(
            title: "Assign Plan",
            isVisible: true,
            accessibilityIdentifier: "coachPlans.assignPlan",
            accessibilityValue: coachPlansStateText(data: data)
        )
        addHorizontalInsets(hero(
            kicker: "Plans",
            title: "\(data.templates.count)",
            body: "Create, preview, and assign coach-owned templates from one place."
        ), top: Spacing.sm)
        addHorizontalInsets(coachPlansStatePlate(data: data), top: Spacing.sm)

        addSection(
            title: "Scope",
            content: metricRail([
                ("Templates", "\(data.templates.count)", "Active"),
                ("Assigned", "\(data.assignedCount)", "Pending"),
                ("Completed", "\(data.completedCount)", "Done")
            ])
        )

        if data.templates.isEmpty {
            addSection(content: dataPlate([
                UIKitDesign.label("No plans yet", font: UIKitDesign.medium(19), color: UIKitDesign.textPrimary),
                UIKitDesign.label("Create the first coach-owned template, then assign it to an athlete.", font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
            ], spacing: Spacing.xs))
        } else {
            var rows: [UIView] = []
            for (index, template) in data.templates.prefix(6).enumerated() {
                rows.append(templateRow(template))
                if index < min(data.templates.count, 6) - 1 {
                    rows.append(divider())
                }
            }
            addSection(title: "Templates", content: dataPlate(rows, spacing: Spacing.sm))
        }

        addSection(title: "More", content: dataPlate([
            actionRow(
                title: "Open full plan manager",
                subtitle: "Template list, editing, preview, and detailed targets",
                accessibilityIdentifier: "coachPlans.manager",
                action: #selector(openPlanManager)
            )
        ]))
    }

    private func loadPlanData() -> (templates: [WorkoutTemplate], assignedCount: Int, completedCount: Int) {
        let athletes = (try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []
        guard let coachId = currentCoachId(athletes: athletes) else { return ([], 0, 0) }
        let templates = ((try? modelContext.fetch(FetchDescriptor<WorkoutTemplate>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))) ?? [])
            .filter { $0.coachId == coachId && !$0.isArchived }
        let prescriptions = ((try? modelContext.fetch(FetchDescriptor<PrescribedWorkout>())) ?? [])
            .filter { $0.coachId == coachId }
        return (
            templates,
            prescriptions.filter { $0.status == .assigned }.count,
            prescriptions.filter { $0.status == .completed }.count
        )
    }

    private func currentCoachId(athletes: [Athlete]? = nil) -> UUID? {
        let allAthletes = athletes ?? ((try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? [])
        return allAthletes.first { $0.isCoach }?.id ?? allAthletes.first?.id
    }

    private func coachPlansStateText(data: (templates: [WorkoutTemplate], assignedCount: Int, completedCount: Int)) -> String {
        if data.templates.isEmpty {
            return "Template required before assignment"
        }
        return "\(data.templates.count) active templates · \(data.assignedCount) pending assignments"
    }

    private func coachPlansStatePlate(data: (templates: [WorkoutTemplate], assignedCount: Int, completedCount: Int)) -> UIView {
        let label = UIKitDesign.label(
            coachPlansStateText(data: data),
            font: UIKitDesign.regular(15),
            color: UIKitDesign.textSecondary,
            lines: 0
        )
        label.accessibilityIdentifier = "coachPlans.state"
        return dataPlate([label], spacing: Spacing.sm)
    }

    private func templateRow(_ template: WorkoutTemplate) -> UIView {
        let button = UIButton(type: .custom)
        button.accessibilityIdentifier = "coachPlans.template"
        button.accessibilityLabel = "\(template.templateName), \(template.sessionType.displayName)"
        button.addAction(UIAction { [weak self] _ in
            self?.openPreview(template)
        }, for: .touchUpInside)
        let row = disclosureRow(
            title: template.templateName,
            subtitle: "\(template.sessionType.displayName) · \(template.sortedGroups.flatMap(\.sortedExercises).count) exercises",
            trailing: template.lastUsedAt?.relativeString(locale: locale)
        )
        row.isUserInteractionEnabled = false
        button.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            row.topAnchor.constraint(equalTo: button.topAnchor),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return button
    }

    private func actionRow(
        title: String,
        subtitle: String?,
        trailing: String? = nil,
        accessibilityIdentifier: String? = nil,
        action: Selector
    ) -> UIView {
        let button = UIButton(type: .custom)
        button.accessibilityIdentifier = accessibilityIdentifier
        button.accessibilityLabel = [title, subtitle, trailing].compactMap { $0 }.joined(separator: ", ")
        button.addTarget(self, action: action, for: .touchUpInside)
        let row = disclosureRow(title: title, subtitle: subtitle, trailing: trailing)
        row.isUserInteractionEnabled = false
        button.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            row.topAnchor.constraint(equalTo: button.topAnchor),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return button
    }

    @objc private func newTemplate() {
        guard let ownerId = currentCoachId() else { return }
        Haptics.tap()
        let controller = TemplateEditorViewController(
            container: container,
            modelContext: modelContext,
            locale: locale,
            ownerId: ownerId,
            existingTemplate: nil,
            newTemplatesAreAthleteOwned: false,
            onSave: { [weak self] in
                self?.rebuild()
            }
        )
        present(InstrumentNavigationController(rootViewController: controller), animated: true)
    }

    @objc private func openAssignPlan() {
        Haptics.tap()
        let controller = CoachPlanAssignmentViewController(
            container: container,
            modelContext: modelContext,
            onAssigned: { [weak self] in
                self?.rebuild()
            }
        )
        present(InstrumentNavigationController(rootViewController: controller), animated: true)
    }

    private func openPreview(_ template: WorkoutTemplate) {
        guard let ownerId = currentCoachId() else { return }
        Haptics.tap()
        let controller = TemplatePreviewViewController(
            container: container,
            modelContext: modelContext,
            locale: locale,
            ownerId: ownerId,
            template: template,
            newTemplatesAreAthleteOwned: false,
            onSave: { [weak self] in
                self?.rebuild()
            }
        )
        showInstrumentDetail(controller)
    }

    @objc private func openPlanManager() {
        Haptics.tap()
        let controller = TemplateManagerViewController(
            container: container,
            modelContext: modelContext,
            locale: locale,
            newTemplatesAreAthleteOwned: false
        )
        present(InstrumentNavigationController(rootViewController: controller), animated: true)
    }
}

private final class CoachPlanAssignmentViewController: InstrumentScrollViewController {
    private let container: AppContainer
    private let modelContext: ModelContext
    private let onAssigned: () -> Void

    init(container: AppContainer, modelContext: ModelContext, onAssigned: @escaping () -> Void) {
        self.container = container
        self.modelContext = modelContext
        self.onAssigned = onAssigned
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Assign Plan"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(closeAssignment)
        )
        navigationItem.leftBarButtonItem?.accessibilityIdentifier = "coachPlanAssignment.cancel"
    }

    override func rebuild() {
        clearContent()
        let scope = loadScope()
        addHorizontalInsets(hero(
            kicker: "Assign",
            title: "Choose athlete",
            body: "Select the athlete first, then choose template, schedule, and notes."
        ), top: Spacing.sm)
        addHorizontalInsets(assignmentStatePlate(scope: scope), top: Spacing.sm)

        if scope.templates.isEmpty {
            addSection(content: dataPlate([
                UIKitDesign.label("No templates available", font: UIKitDesign.medium(19), color: UIKitDesign.textPrimary, lines: 0),
                UIKitDesign.label("Create a coach template before assigning plans.", font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
            ], spacing: Spacing.sm))
            return
        }

        if scope.athletes.isEmpty {
            addSection(content: dataPlate([
                UIKitDesign.label("No linked athletes", font: UIKitDesign.medium(19), color: UIKitDesign.textPrimary, lines: 0),
                UIKitDesign.label("Invite athletes from Coach Profile, then assign plans here.", font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
            ], spacing: Spacing.sm))
            return
        }

        var rows: [UIView] = []
        for (index, athlete) in scope.athletes.enumerated() {
            rows.append(athleteButton(athlete))
            if index < scope.athletes.count - 1 {
                rows.append(divider())
            }
        }
        addSection(title: "Athletes", content: dataPlate(rows, spacing: Spacing.sm))
    }

    private func loadScope() -> (coach: Athlete?, athletes: [Athlete], templates: [WorkoutTemplate]) {
        let athletes = (try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []
        guard let coach = athletes.first(where: { $0.isCoach }) ?? athletes.first else {
            return (nil, [], [])
        }
        let relationships = (try? modelContext.fetch(FetchDescriptor<CoachAthleteRelationship>())) ?? []
        let linkedIds = Set(
            relationships
                .filter { $0.coachId == coach.id && $0.status == .accepted }
                .map(\.athleteId)
        )
        let linkedAthletes = athletes
            .filter { linkedIds.contains($0.id) }
            .sorted { $0.displayName < $1.displayName }
        let templates = ((try? modelContext.fetch(FetchDescriptor<WorkoutTemplate>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))) ?? [])
            .filter { $0.coachId == coach.id && !$0.isArchived }
        return (coach, linkedAthletes, templates)
    }

    private func assignmentStatePlate(scope: (coach: Athlete?, athletes: [Athlete], templates: [WorkoutTemplate])) -> UIView {
        let state: String
        if scope.coach == nil {
            state = "Coach profile unavailable"
        } else if scope.templates.isEmpty {
            state = "Template required"
        } else if scope.athletes.isEmpty {
            state = "Linked athlete required"
        } else {
            state = "\(scope.athletes.count) linked athlete\(scope.athletes.count == 1 ? "" : "s") · \(scope.templates.count) templates"
        }
        let label = UIKitDesign.label(state, font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
        label.accessibilityIdentifier = "coachPlanAssignment.state"
        return dataPlate([label], spacing: Spacing.sm)
    }

    private func athleteButton(_ athlete: Athlete) -> UIView {
        let button = UIButton(type: .custom)
        button.accessibilityIdentifier = "coachPlanAssignment.athlete"
        button.accessibilityLabel = "\(athlete.displayName), \(athlete.sportType.displayName)"
        button.addAction(UIAction { [weak self] _ in
            self?.openPrescription(for: athlete)
        }, for: .touchUpInside)
        let row = disclosureRow(
            title: athlete.displayName,
            subtitle: athlete.sportType.displayName,
            trailing: "Assign"
        )
        row.isUserInteractionEnabled = false
        button.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            row.topAnchor.constraint(equalTo: button.topAnchor),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return button
    }

    private func openPrescription(for athlete: Athlete) {
        Haptics.select()
        let controller = CoachPrescriptionViewController(
            container: container,
            modelContext: modelContext,
            athlete: athlete,
            onAssigned: onAssigned
        )
        showInstrumentDetail(controller)
    }

    @objc private func closeAssignment() {
        Haptics.tap()
        dismiss(animated: true)
    }
}

private final class CoachReportsViewController: InstrumentScrollViewController {
    private let container: AppContainer
    private let modelContext: ModelContext

    init(container: AppContainer, modelContext: ModelContext) {
        self.container = container
        self.modelContext = modelContext
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func rebuild() {
        clearContent()
        let scope = loadScope()
        addHorizontalInsets(hero(kicker: "Reports", title: "Roster-level readouts", body: "Review coach-scoped roster health, plan status, and recent training context."), top: Spacing.sm)
        addHorizontalInsets(reportsStatePlate(scope: scope), top: Spacing.sm)

        let reportButton = UIButton(type: .custom)
        reportButton.accessibilityIdentifier = "coachReports.rosterReport"
        reportButton.accessibilityLabel = "Roster report"
        reportButton.contentHorizontalAlignment = .fill
        reportButton.addTarget(self, action: #selector(openRosterReport), for: .touchUpInside)
        let reportRow = disclosureRow(
            title: "Roster report",
            subtitle: "Coach-scoped athlete status, attention, plans, and recent sessions.",
            trailing: container.subscriptionService.isCoach ? "Ready" : "Coach"
        )
        reportRow.isUserInteractionEnabled = false
        reportButton.addSubview(reportRow)
        reportRow.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            reportRow.leadingAnchor.constraint(equalTo: reportButton.leadingAnchor),
            reportRow.trailingAnchor.constraint(equalTo: reportButton.trailingAnchor),
            reportRow.topAnchor.constraint(equalTo: reportButton.topAnchor),
            reportRow.bottomAnchor.constraint(equalTo: reportButton.bottomAnchor)
        ])
        addSection(title: "Available reports", content: dataPlate([reportButton]))
        addSection(
            title: "Current scope",
            content: metricRail([
                ("Clients", "\(scope.acceptedRelationshipCount)", "Accepted"),
                ("Plans", "\(scope.templateCount)", "Active"),
                ("Assigned", "\(scope.pendingPrescriptionCount)", "Pending")
            ])
        )
    }

    private func reportsStatePlate(scope: (acceptedRelationshipCount: Int, pendingPrescriptionCount: Int, templateCount: Int)) -> UIView {
        let state = "\(scope.acceptedRelationshipCount) accepted athletes · \(scope.pendingPrescriptionCount) pending assignments · \(scope.templateCount) active plans"
        let label = UIKitDesign.label(state, font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
        label.accessibilityIdentifier = "coachReports.state"
        return dataPlate([label], spacing: Spacing.sm)
    }

    @objc private func openRosterReport() {
        if container.subscriptionService.isCoach {
            Haptics.tap()
            let controller = CoachRosterReportViewController(modelContext: modelContext)
            showInstrumentDetail(controller)
        } else {
            let controller = UpgradeViewController(container: container, trigger: .coach)
            present(InstrumentNavigationController(rootViewController: controller), animated: true)
        }
    }

    private func loadScope() -> (acceptedRelationshipCount: Int, pendingPrescriptionCount: Int, templateCount: Int) {
        let athletes = (try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []
        guard let coachId = athletes.first?.id else { return (0, 0, 0) }
        let relationships = (try? modelContext.fetch(FetchDescriptor<CoachAthleteRelationship>())) ?? []
        let prescriptions = (try? modelContext.fetch(FetchDescriptor<PrescribedWorkout>())) ?? []
        let templates = (try? modelContext.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
        return (
            relationships.filter { $0.coachId == coachId && $0.status == .accepted }.count,
            prescriptions.filter { $0.coachId == coachId && $0.status == .assigned }.count,
            templates.filter { $0.coachId == coachId && !$0.isArchived }.count
        )
    }
}

private final class CoachRosterReportViewController: InstrumentScrollViewController {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Roster Report"
    }

    override func rebuild() {
        clearContent()
        let data = loadReportData()
        let attentionCount = data.linkedAthletes.filter { reportNeedsAttention(athlete: $0, data: data) }.count
        let pendingCount = data.prescriptions.filter { $0.status == .assigned }.count
        let completedCount = data.prescriptions.filter { $0.status == .completed }.count
        addHorizontalInsets(hero(
            kicker: "Roster Report",
            title: "\(data.linkedAthletes.count)",
            body: "Generated \(Date.now.formatted(.dateTime.month().day().hour().minute())) from coach-scoped Tuwa data."
        ), top: Spacing.sm)
        addHorizontalInsets(reportStatePlate(data: data, attentionCount: attentionCount), top: Spacing.sm)

        addSection(title: "Summary", content: metricRail([
            ("Athletes", "\(data.linkedAthletes.count)", "Accepted"),
            ("Attention", "\(attentionCount)", "Needs review"),
            ("Pending", "\(pendingCount)", "Plans")
        ]))

        addSection(title: "Plan Lifecycle", content: metricRail([
            ("Assigned", "\(pendingCount)", "Sent"),
            ("Completed", "\(completedCount)", "Done"),
            ("Templates", "\(data.templates.count)", "Active")
        ]))

        if data.linkedAthletes.isEmpty {
            addSection(content: dataPlate([
                UIKitDesign.label("No athletes in report", font: UIKitDesign.medium(19), color: UIKitDesign.textPrimary),
                UIKitDesign.label("Accepted coach-athlete relationships appear here.", font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
            ], spacing: Spacing.sm))
            return
        }

        addSection(title: "Athlete Readouts", content: dataPlate(reportRows(data: data), spacing: Spacing.sm))
    }

    private func loadReportData() -> (
        linkedAthletes: [Athlete],
        recovery: [RecoverySnapshot],
        workload: [WorkloadSnapshot],
        sessions: [WorkoutSession],
        prescriptions: [PrescribedWorkout],
        templates: [WorkoutTemplate]
    ) {
        let athletes = (try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []
        let relationships = (try? modelContext.fetch(FetchDescriptor<CoachAthleteRelationship>())) ?? []
        let recovery = (try? modelContext.fetch(FetchDescriptor<RecoverySnapshot>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        let workload = (try? modelContext.fetch(FetchDescriptor<WorkloadSnapshot>(sortBy: [SortDescriptor(\.snapshotDate, order: .reverse)]))) ?? []
        let sessions = (try? modelContext.fetch(FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.sessionDate, order: .reverse)]))) ?? []
        let prescriptions = (try? modelContext.fetch(FetchDescriptor<PrescribedWorkout>(sortBy: [SortDescriptor(\.scheduledDate, order: .reverse)]))) ?? []
        let templates = (try? modelContext.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []

        guard let coachId = athletes.first(where: { $0.isCoach })?.id ?? athletes.first?.id else {
            return ([], recovery, workload, sessions, prescriptions, templates)
        }
        let linkedIds = Set(
            relationships
                .filter { $0.coachId == coachId && $0.status == .accepted }
                .map(\.athleteId)
        )
        let linkedAthletes = athletes
            .filter { linkedIds.contains($0.id) }
            .sorted { $0.displayName < $1.displayName }
        return (
            linkedAthletes,
            recovery,
            workload,
            sessions,
            prescriptions.filter { $0.coachId == coachId },
            templates.filter { $0.coachId == coachId && !$0.isArchived }
        )
    }

    private func reportStatePlate(
        data: (
            linkedAthletes: [Athlete],
            recovery: [RecoverySnapshot],
            workload: [WorkloadSnapshot],
            sessions: [WorkoutSession],
            prescriptions: [PrescribedWorkout],
            templates: [WorkoutTemplate]
        ),
        attentionCount: Int
    ) -> UIView {
        let state = "\(attentionCount) attention flags · \(data.prescriptions.filter { $0.status == .assigned }.count) pending assignments"
        let label = UIKitDesign.label(state, font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
        label.accessibilityIdentifier = "coachRosterReport.state"
        return dataPlate([label], spacing: Spacing.sm)
    }

    private func reportRows(data: (
        linkedAthletes: [Athlete],
        recovery: [RecoverySnapshot],
        workload: [WorkloadSnapshot],
        sessions: [WorkoutSession],
        prescriptions: [PrescribedWorkout],
        templates: [WorkoutTemplate]
    )) -> [UIView] {
        data.linkedAthletes.enumerated().flatMap { index, athlete -> [UIView] in
            var rows = [reportRow(athlete: athlete, data: data)]
            if index < data.linkedAthletes.count - 1 {
                rows.append(divider())
            }
            return rows
        }
    }

    private func reportRow(
        athlete: Athlete,
        data: (
            linkedAthletes: [Athlete],
            recovery: [RecoverySnapshot],
            workload: [WorkloadSnapshot],
            sessions: [WorkoutSession],
            prescriptions: [PrescribedWorkout],
            templates: [WorkoutTemplate]
        )
    ) -> UIView {
        let athleteId = athlete.id
        let latestRecovery = data.recovery.first { $0.athlete?.id == athleteId }
        let latestWorkload = data.workload.first { $0.athlete?.id == athleteId }
        let latestSession = data.sessions.first { $0.athlete?.id == athleteId }
        let pending = data.prescriptions.filter { $0.athleteId == athleteId && $0.status == .assigned }.count
        let attention = reportAttentionText(recovery: latestRecovery, workload: latestWorkload, pending: pending)
        let subtitle = [
            "Recovery \(latestRecovery?.zone.displayName ?? "No recovery")",
            "Load \(latestWorkload?.zone.displayName ?? "No load")",
            latestSession.map { "Last \($0.sessionDate.relativeString(locale: .current))" },
            pending > 0 ? "\(pending) pending plan\(pending == 1 ? "" : "s")" : "No pending plans"
        ]
            .compactMap { $0 }
            .joined(separator: " · ")
        let row = disclosureRow(title: athlete.displayName, subtitle: subtitle, trailing: attention)
        row.isAccessibilityElement = true
        row.accessibilityIdentifier = "coachRosterReport.athlete"
        row.accessibilityLabel = "\(athlete.displayName), \(subtitle), \(attention)"
        return row
    }

    private func reportNeedsAttention(
        athlete: Athlete,
        data: (
            linkedAthletes: [Athlete],
            recovery: [RecoverySnapshot],
            workload: [WorkloadSnapshot],
            sessions: [WorkoutSession],
            prescriptions: [PrescribedWorkout],
            templates: [WorkoutTemplate]
        )
    ) -> Bool {
        let athleteId = athlete.id
        let latestRecovery = data.recovery.first { $0.athlete?.id == athleteId }
        let latestWorkload = data.workload.first { $0.athlete?.id == athleteId }
        let pending = data.prescriptions.contains { $0.athleteId == athleteId && $0.status == .assigned }
        return latestRecovery?.zone != .green || latestWorkload?.zone == .danger || pending
    }

    private func reportAttentionText(recovery: RecoverySnapshot?, workload: WorkloadSnapshot?, pending: Int) -> String {
        if pending > 0 {
            return "Plan"
        }
        if recovery?.zone != .green {
            return "Recovery"
        }
        if workload?.zone == .danger {
            return "Load"
        }
        return "Stable"
    }
}

private final class CoachProfileViewController: InstrumentScrollViewController {
    private let container: AppContainer
    private let modelContext: ModelContext
    private let onReturnToAthlete: (UIViewController) -> Void

    init(
        container: AppContainer,
        modelContext: ModelContext,
        onReturnToAthlete: @escaping (UIViewController) -> Void
    ) {
        self.container = container
        self.modelContext = modelContext
        self.onReturnToAthlete = onReturnToAthlete
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func rebuild() {
        clearContent()
        let athlete = ((try? modelContext.fetch(FetchDescriptor<Athlete>())) ?? []).first
        addHorizontalInsets(hero(kicker: "Coach context", title: athlete?.displayName ?? "Coach", body: "Coach tools are separated from the athlete shell to keep planning, reports, and roster data scoped clearly."), top: Spacing.sm)

        addSection(title: "Team", content: actionPlate(
            title: "Invite athlete",
            subtitle: "Send an email invite or test the invite path in screenshot mode",
            action: #selector(openInviteAthlete),
            accessibilityIdentifier: "coachProfile.inviteAthlete"
        ))

        addSection(title: "Context", content: actionPlate(
            title: "Return to athlete mode",
            subtitle: "Today, Train, Insights, and Profile",
            action: #selector(returnToAthleteMode),
            accessibilityIdentifier: "coachProfile.returnToAthlete"
        ))
        addSection(title: "Account", content: actionPlate(
            title: "Sign out",
            subtitle: nil,
            action: #selector(signOut),
            accessibilityIdentifier: "coachProfile.signOut"
        ))
    }

    private func actionPlate(
        title: String,
        subtitle: String?,
        action: Selector,
        accessibilityIdentifier: String
    ) -> UIView {
        let button = UIButton(type: .custom)
        button.accessibilityIdentifier = accessibilityIdentifier
        button.accessibilityLabel = [title, subtitle].compactMap { $0 }.joined(separator: ", ")
        button.addTarget(self, action: action, for: .touchUpInside)
        let row = disclosureRow(title: title, subtitle: subtitle)
        row.isUserInteractionEnabled = false
        button.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            row.topAnchor.constraint(equalTo: button.topAnchor),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return dataPlate([button])
    }

    @objc private func openInviteAthlete() {
        Haptics.tap()
        let controller = InviteFlowViewController(
            container: container,
            modelContext: modelContext,
            mode: .coachEmail
        )
        present(InstrumentNavigationController(rootViewController: controller), animated: true)
    }

    @objc private func returnToAthleteMode() {
        Haptics.tap()
        onReturnToAthlete(self)
    }

    @objc private func signOut() {
        Haptics.tap()
        Task {
            try? await container.signOut(modelContext: modelContext)
        }
    }
}
