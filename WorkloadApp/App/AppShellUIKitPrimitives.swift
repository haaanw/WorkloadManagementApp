import SwiftUI
import UIKit
import CoreText

protocol AppTabRootResetting: AnyObject {
    func resetToRoot(animated: Bool)
}

extension UIViewController {
    func applyTuwaLightInterfaceStyle() {
        overrideUserInterfaceStyle = .light
        view.window?.overrideUserInterfaceStyle = .light
    }
}

enum UIKitStrings {
    static func localized(_ key: String.LocalizationValue, locale: Locale) -> String {
        var resource = LocalizedStringResource(key)
        resource.locale = locale
        return String(localized: resource)
    }

    static func localized(
        _ key: StaticString,
        defaultValue: String.LocalizationValue,
        locale: Locale
    ) -> String {
        String(localized: key, defaultValue: defaultValue, locale: locale)
    }
}

enum UIKitDesign {
    static let hairline = 1 / UIScreen.main.scale

    static var background: UIColor { UIColor(ColorTokens.background) }
    static var surface: UIColor { UIColor(ColorTokens.surface) }
    static var plate: UIColor { UIColor(ColorTokens.plate) }
    static var raised: UIColor { UIColor(ColorTokens.raised) }
    static var active: UIColor { UIColor(ColorTokens.active) }
    static var hairlineColor: UIColor { UIColor(ColorTokens.hairline) }
    static var hairlineStrong: UIColor { UIColor(ColorTokens.hairlineStrong) }
    static var accent: UIColor { UIColor(ColorTokens.accent) }
    static var accentSubtle: UIColor { UIColor(ColorTokens.accent).withAlphaComponent(0.16) }
    static var textPrimary: UIColor { UIColor(ColorTokens.textPrimary) }
    static var textSecondary: UIColor { UIColor(ColorTokens.textSecondary) }
    static var textTertiary: UIColor { UIColor(ColorTokens.textTertiary) }

    static func regular(_ size: CGFloat) -> UIFont {
        UIFont(name: "GeneralSans-Regular", size: size)
            ?? UIFont(name: "NotoSansSC-Regular", size: size)
            ?? UIFont(descriptor: UIFontDescriptor(name: "GeneralSans-Regular", size: size), size: size)
    }

    static func medium(_ size: CGFloat) -> UIFont {
        UIFont(name: "GeneralSans-Medium", size: size)
            ?? UIFont(name: "NotoSansSC-Medium", size: size)
            ?? UIFont(descriptor: UIFontDescriptor(name: "GeneralSans-Medium", size: size), size: size)
    }

    static func tabular(_ font: UIFont) -> UIFont {
        let settings: [[UIFontDescriptor.FeatureKey: Int]] = [
            [
                .type: kNumberSpacingType,
                .selector: kMonospacedNumbersSelector
            ]
        ]
        let descriptor = font.fontDescriptor.addingAttributes([.featureSettings: settings])
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }

    static func label(
        _ text: String,
        font: UIFont,
        color: UIColor,
        lines: Int = 1
    ) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        label.numberOfLines = lines
        label.adjustsFontForContentSizeCategory = true
        label.lineBreakMode = .byWordWrapping
        return label
    }

    static func microLabel(_ text: String) -> UILabel {
        let label = UILabel()
        let displayText = microText(text)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        label.attributedText = NSAttributedString(
            string: displayText,
            attributes: [
                .font: regular(12),
                .foregroundColor: textTertiary,
                .kern: containsCJK(displayText) ? 0 : 1.2,
                .paragraphStyle: paragraph
            ]
        )
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        return label
    }

    static func microText(_ text: String) -> String {
        containsCJK(text) ? text : text.uppercased()
    }

    private static func containsCJK(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3400...0x4DBF,
                 0x4E00...0x9FFF,
                 0xF900...0xFAFF,
                 0x20000...0x2A6DF,
                 0x2A700...0x2B73F,
                 0x2B740...0x2B81F,
                 0x2B820...0x2CEAF,
                 0x2CEB0...0x2EBEF,
                 0x30000...0x3134F:
                return true
            default:
                return false
            }
        }
    }

    static func verticalStack(spacing: CGFloat = Spacing.sm) -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = spacing
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    static func horizontalStack(spacing: CGFloat = Spacing.sm) -> UIStackView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = spacing
        stack.alignment = .fill
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    static func plateView(backgroundColor: UIColor = plate) -> UIView {
        let view = UIView()
        view.backgroundColor = backgroundColor
        view.layer.borderWidth = hairline
        view.layer.borderColor = hairlineColor.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    static func separator(axis: NSLayoutConstraint.Axis) -> UIView {
        let view = UIView()
        view.backgroundColor = hairlineColor
        view.translatesAutoresizingMaskIntoConstraints = false
        if axis == .horizontal {
            view.heightAnchor.constraint(equalToConstant: hairline).isActive = true
            view.setContentHuggingPriority(.required, for: .vertical)
            view.setContentCompressionResistancePriority(.required, for: .vertical)
        } else {
            view.widthAnchor.constraint(equalToConstant: hairline).isActive = true
            view.setContentHuggingPriority(.required, for: .horizontal)
            view.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
        return view
    }
}

enum UIKitMotion {
    static let stateDuration: TimeInterval = 0.30
    static let entranceDuration: TimeInterval = 0.42
    static let screenDuration: TimeInterval = 0.28
    static let exitDuration: TimeInterval = 0.20
    static let stateDamping: CGFloat = 0.86
    static let entranceDamping: CGFloat = 0.82

    static func animateContentChange(
        animated: Bool,
        animations: @escaping () -> Void
    ) {
        guard animated, !UIAccessibility.isReduceMotionEnabled else {
            animations()
            return
        }

        UIView.animate(
            withDuration: stateDuration,
            delay: 0,
            usingSpringWithDamping: stateDamping,
            initialSpringVelocity: 0,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: animations
        )
    }
}

final class SquareTabRailView: UIView {
    private let topRule = UIView()
    private let stack = UIStackView()
    private var itemSignature: String = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(items: [UITabBarItem], selectedIndex: Int, animated: Bool) {
        let signature = items.enumerated()
            .map { index, item in
                "\(index):\(item.title ?? ""):\(item.image?.description ?? ""):\(selectedIndex == index)"
            }
            .joined(separator: "|")
        guard signature != itemSignature || stack.arrangedSubviews.isEmpty else { return }
        itemSignature = signature

        let changes = { [self] in
            rebuild(items: items, selectedIndex: selectedIndex)
            layoutIfNeeded()
        }

        guard animated, !UIAccessibility.isReduceMotionEnabled else {
            changes()
            return
        }

        UIView.transition(
            with: stack,
            duration: UIKitMotion.screenDuration,
            options: [.transitionCrossDissolve, .allowUserInteraction, .beginFromCurrentState],
            animations: changes
        )
    }

    private func setup() {
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        backgroundColor = UIKitDesign.surface
        translatesAutoresizingMaskIntoConstraints = false

        topRule.backgroundColor = UIKitDesign.hairlineColor
        topRule.translatesAutoresizingMaskIntoConstraints = false
        addSubview(topRule)

        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fillEqually
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            topRule.leadingAnchor.constraint(equalTo: leadingAnchor),
            topRule.trailingAnchor.constraint(equalTo: trailingAnchor),
            topRule.topAnchor.constraint(equalTo: topAnchor),
            topRule.heightAnchor.constraint(equalToConstant: UIKitDesign.hairline),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topRule.bottomAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func rebuild(items: [UITabBarItem], selectedIndex: Int) {
        stack.arrangedSubviews.forEach { view in
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for (index, item) in items.enumerated() {
            stack.addArrangedSubview(cell(for: item, isSelected: index == selectedIndex))
        }
    }

    private func cell(for item: UITabBarItem, isSelected: Bool) -> UIView {
        let cell = UIView()
        cell.backgroundColor = isSelected ? UIKitDesign.accentSubtle : .clear

        let accentRule = UIView()
        accentRule.backgroundColor = isSelected ? UIKitDesign.accent : .clear
        accentRule.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(accentRule)

        let content = UIStackView()
        content.axis = .vertical
        content.alignment = .center
        content.spacing = Spacing.baselinePair
        content.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(content)

        let tint = isSelected ? UIKitDesign.accent : UIKitDesign.textTertiary
        let imageView = UIImageView(image: (isSelected ? item.selectedImage : item.image)?.withRenderingMode(.alwaysTemplate))
        imageView.tintColor = tint
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: 28).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 28).isActive = true

        let label = UIKitDesign.label(
            item.title ?? "",
            font: isSelected ? UIKitDesign.medium(12) : UIKitDesign.regular(12),
            color: tint
        )
        label.textAlignment = .center
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.75

        content.addArrangedSubview(imageView)
        content.addArrangedSubview(label)

        NSLayoutConstraint.activate([
            accentRule.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            accentRule.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
            accentRule.topAnchor.constraint(equalTo: cell.topAnchor),
            accentRule.heightAnchor.constraint(equalToConstant: 2),
            content.leadingAnchor.constraint(greaterThanOrEqualTo: cell.leadingAnchor, constant: Spacing.baselinePair),
            content.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -Spacing.baselinePair),
            content.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
            content.centerYAnchor.constraint(equalTo: cell.centerYAnchor, constant: -Spacing.baselinePair)
        ])

        return cell
    }
}

final class InstrumentSegmentedControlUIKit: UIView {
    private let stack = UIStackView()
    private let buttons: [UIButton]
    var onSelectionChanged: ((Int) -> Void)?
    var selectedAccessibilityValue = "Selected" {
        didSet { applyState() }
    }
    var selectedIndex: Int = 0 {
        didSet { applyState() }
    }

    init(titles: [String]) {
        self.buttons = titles.enumerated().map { index, title in
            let button = UIButton(type: .custom)
            button.tag = index
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = UIKitDesign.regular(15)
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.accessibilityLabel = title
            button.translatesAutoresizingMaskIntoConstraints = false
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            return button
        }
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func setup() {
        backgroundColor = UIKitDesign.surface
        layer.borderWidth = UIKitDesign.hairline
        layer.borderColor = UIKitDesign.hairlineColor.cgColor
        translatesAutoresizingMaskIntoConstraints = false

        stack.axis = .horizontal
        stack.spacing = 0
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        var previousButton: UIButton?
        for (index, button) in buttons.enumerated() {
            button.addTarget(self, action: #selector(selectButton(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
            button.setContentHuggingPriority(.defaultLow, for: .horizontal)
            button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            if let previousButton {
                button.widthAnchor.constraint(equalTo: previousButton.widthAnchor).isActive = true
            } else {
                previousButton = button
            }
            if index < buttons.count - 1 {
                let separator = UIKitDesign.separator(axis: .vertical)
                separator.setContentHuggingPriority(.required, for: .horizontal)
                separator.setContentCompressionResistancePriority(.required, for: .horizontal)
                stack.addArrangedSubview(separator)
            }
        }
        applyState()
    }

    @objc private func selectButton(_ sender: UIButton) {
        selectedIndex = sender.tag
        Haptics.select()
        onSelectionChanged?(sender.tag)
    }

    private func applyState() {
        for button in buttons {
            let selected = button.tag == selectedIndex
            button.backgroundColor = selected ? UIKitDesign.active : .clear
            button.setTitleColor(selected ? UIKitDesign.textPrimary : UIKitDesign.textSecondary, for: .normal)
            button.titleLabel?.font = selected ? UIKitDesign.medium(15) : UIKitDesign.regular(15)
            button.layer.borderWidth = selected ? UIKitDesign.hairline : 0
            button.layer.borderColor = selected ? UIKitDesign.hairlineStrong.cgColor : UIColor.clear.cgColor
            button.accessibilityTraits = selected ? [.button, .selected] : .button
            button.accessibilityValue = selected ? selectedAccessibilityValue : nil
        }
    }
}

final class UIKitBottomActionDock: UIView {
    let primaryButton = UIButton(type: .custom)
    let secondaryButton = UIButton(type: .custom)
    private let stack = UIStackView()

    init(primaryTitle: String, secondaryTitle: String? = nil) {
        super.init(frame: .zero)
        setup(primaryTitle: primaryTitle, secondaryTitle: secondaryTitle)
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func setup(primaryTitle: String, secondaryTitle: String?) {
        backgroundColor = UIKitDesign.background
        translatesAutoresizingMaskIntoConstraints = false

        let topRule = UIKitDesign.separator(axis: .horizontal)
        addSubview(topRule)

        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = secondaryTitle == nil ? .fill : .fillEqually
        stack.spacing = Spacing.xs
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        configureButton(secondaryButton, title: secondaryTitle ?? "", isPrimary: false)
        configureButton(primaryButton, title: primaryTitle, isPrimary: true)

        if secondaryTitle != nil {
            stack.addArrangedSubview(secondaryButton)
        }
        stack.addArrangedSubview(primaryButton)

        NSLayoutConstraint.activate([
            topRule.leadingAnchor.constraint(equalTo: leadingAnchor),
            topRule.trailingAnchor.constraint(equalTo: trailingAnchor),
            topRule.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Spacing.sm),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Spacing.sm),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: Spacing.sm),
            stack.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -Spacing.sm)
        ])
    }

    private func configureButton(_ button: UIButton, title: String, isPrimary: Bool) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(UIKitDesign.textPrimary, for: .normal)
        button.setTitleColor(UIKitDesign.textTertiary, for: .disabled)
        button.titleLabel?.font = UIKitDesign.medium(17)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.numberOfLines = 1
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.82
        button.backgroundColor = isPrimary ? .clear : UIKitDesign.surface
        button.layer.borderWidth = UIKitDesign.hairline
        button.layer.borderColor = (isPrimary ? UIKitDesign.accent : UIKitDesign.hairlineColor).cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
    }

    func updatePrimary(
        title: String,
        isEnabled: Bool = true,
        accessibilityIdentifier: String? = nil,
        accessibilityValue: String? = nil
    ) {
        primaryButton.setTitle(title, for: .normal)
        primaryButton.isEnabled = isEnabled
        primaryButton.alpha = isEnabled ? 1 : 0.45
        primaryButton.accessibilityIdentifier = accessibilityIdentifier
        primaryButton.accessibilityValue = accessibilityValue
    }

    func updateSecondary(
        title: String,
        isVisible: Bool = true,
        isEnabled: Bool = true,
        accessibilityIdentifier: String? = nil,
        accessibilityValue: String? = nil
    ) {
        secondaryButton.setTitle(title, for: .normal)
        secondaryButton.isHidden = !isVisible
        secondaryButton.isEnabled = isEnabled
        secondaryButton.alpha = isVisible && isEnabled ? 1 : 0.45
        secondaryButton.accessibilityIdentifier = accessibilityIdentifier
        secondaryButton.accessibilityValue = accessibilityValue
    }
}

class InstrumentScrollViewController: UIViewController, AppTabRootResetting {
    let scrollView = UIScrollView()
    let contentStack = UIKitDesign.verticalStack(spacing: 0)

    override func viewDidLoad() {
        super.viewDidLoad()
        applyTuwaLightInterfaceStyle()
        view.backgroundColor = UIKitDesign.background
        scrollView.backgroundColor = UIKitDesign.background
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyTuwaLightInterfaceStyle()
        rebuild()
    }

    func rebuild() {}

    func resetToRoot(animated: Bool) {
        let topOffset = CGPoint(x: 0, y: -scrollView.adjustedContentInset.top)
        scrollView.setContentOffset(topOffset, animated: animated)
    }

    func clearContent() {
        contentStack.arrangedSubviews.forEach { view in
            contentStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }

    func installBottomActionDock(_ dock: UIKitBottomActionDock) {
        view.addSubview(dock)
        NSLayoutConstraint.activate([
            dock.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dock.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dock.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
        ])
        let dockClearance = Spacing.xl + Spacing.xl
        scrollView.contentInset.bottom = dockClearance
        scrollView.verticalScrollIndicatorInsets.bottom = dockClearance
    }

    func addHorizontalInsets(_ view: UIView, top: CGFloat = 0, bottom: CGFloat = 0) {
        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: Spacing.sm),
            view.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -Spacing.sm),
            view.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: top),
            view.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -bottom)
        ])
        contentStack.addArrangedSubview(wrapper)
    }

    func addSection(title: String? = nil, content: UIView) {
        let section = UIKitDesign.verticalStack(spacing: Spacing.sm)
        section.layoutMargins = UIEdgeInsets(
            top: title == nil ? Spacing.md : Spacing.lg,
            left: Spacing.sm,
            bottom: 0,
            right: Spacing.sm
        )
        section.isLayoutMarginsRelativeArrangement = true

        if let title {
            section.addArrangedSubview(sectionHeader(title))
        }
        section.addArrangedSubview(content)
        contentStack.addArrangedSubview(section)
    }

    private func sectionHeader(_ title: String) -> UIView {
        let stack = UIKitDesign.verticalStack(spacing: Spacing.xs)
        let rule = UIKitDesign.separator(axis: .horizontal)
        let label = UIKitDesign.label(
            title,
            font: UIKitDesign.medium(19),
            color: UIKitDesign.textPrimary
        )
        stack.addArrangedSubview(rule)
        stack.addArrangedSubview(label)
        return stack
    }

    func hero(kicker: String, title: String, body: String) -> UIView {
        let container = UIKitDesign.plateView(backgroundColor: UIKitDesign.raised)
        container.layer.borderColor = UIKitDesign.hairlineStrong.cgColor

        let topRule = UIView()
        topRule.backgroundColor = UIKitDesign.accent
        topRule.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(topRule)

        let stack = UIKitDesign.verticalStack(spacing: Spacing.sm)
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        let isScore = shouldUseHeroAccent(kicker: kicker, title: title)
        stack.addArrangedSubview(UIKitDesign.microLabel(kicker))
        stack.addArrangedSubview(UIKitDesign.label(
            title,
            font: isScore ? UIKitDesign.tabular(UIKitDesign.regular(64)) : UIKitDesign.regular(32),
            color: isScore ? UIKitDesign.accent : UIKitDesign.textPrimary,
            lines: 0
        ))
        stack.addArrangedSubview(UIKitDesign.separator(axis: .horizontal))
        stack.addArrangedSubview(UIKitDesign.label(body, font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0))

        NSLayoutConstraint.activate([
            topRule.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            topRule.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            topRule.topAnchor.constraint(equalTo: container.topAnchor),
            topRule.heightAnchor.constraint(equalToConstant: 2),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Spacing.sm),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -Spacing.sm),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: Spacing.md),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -Spacing.md)
        ])
        return container
    }

    private func shouldUseHeroAccent(kicker: String, title: String) -> Bool {
        guard Int(title) != nil else { return false }
        let lowercasedKicker = kicker.lowercased()
        if lowercasedKicker.contains("recovery") || lowercasedKicker.contains("readiness") {
            return true
        }
        if lowercasedKicker.contains("roster") || lowercasedKicker.contains("plans") {
            return false
        }
        return lowercasedKicker.contains(",")
    }

    func dataPlate(_ arrangedSubviews: [UIView], spacing: CGFloat = 0) -> UIView {
        let container = UIKitDesign.plateView()
        let stack = UIKitDesign.verticalStack(spacing: spacing)
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        arrangedSubviews.forEach(stack.addArrangedSubview)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Spacing.sm),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -Spacing.sm),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: Spacing.md),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -Spacing.md)
        ])
        return container
    }

    func metricRail(_ metrics: [(String, String, String)]) -> UIView {
        let container = UIKitDesign.plateView(backgroundColor: UIKitDesign.surface)
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fill
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        var metricCells: [UIView] = []
        for (index, metric) in metrics.enumerated() {
            let cell = metricCell(label: metric.0, value: metric.1, detail: metric.2)
            metricCells.append(cell)
            stack.addArrangedSubview(cell)
            if index < metrics.count - 1 {
                stack.addArrangedSubview(UIKitDesign.separator(axis: .vertical))
            }
        }
        for cell in metricCells.dropFirst() {
            cell.widthAnchor.constraint(equalTo: metricCells[0].widthAnchor).isActive = true
        }
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Spacing.sm),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -Spacing.sm),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: Spacing.sm),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -Spacing.sm)
        ])
        return container
    }

    func metricCell(label: String, value: String, detail: String) -> UIView {
        let stack = UIKitDesign.verticalStack(spacing: Spacing.baselinePair)
        stack.layoutMargins = UIEdgeInsets(top: 0, left: Spacing.xs, bottom: 0, right: Spacing.xs)
        stack.isLayoutMarginsRelativeArrangement = true
        stack.addArrangedSubview(UIKitDesign.microLabel(label))
        stack.addArrangedSubview(UIKitDesign.label(value, font: UIKitDesign.tabular(UIKitDesign.medium(19)), color: UIKitDesign.textPrimary))
        stack.addArrangedSubview(UIKitDesign.label(detail, font: UIKitDesign.regular(13), color: UIKitDesign.textSecondary))
        return stack
    }

    func disclosureRow(title: String, subtitle: String? = nil, trailing: String? = nil) -> UIView {
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
        textStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        row.addArrangedSubview(textStack)
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)
        if let trailing {
            let trailingLabel = UIKitDesign.label(trailing, font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary)
            trailingLabel.textAlignment = .right
            trailingLabel.adjustsFontSizeToFitWidth = true
            trailingLabel.minimumScaleFactor = 0.82
            trailingLabel.setContentHuggingPriority(.required, for: .horizontal)
            trailingLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
            trailingLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 96).isActive = true
            row.addArrangedSubview(trailingLabel)
        }
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = UIKitDesign.textTertiary
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.widthAnchor.constraint(equalToConstant: 16).isActive = true
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        chevron.setContentCompressionResistancePriority(.required, for: .horizontal)
        row.addArrangedSubview(chevron)
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        return row
    }

    func divider() -> UIView {
        UIKitDesign.separator(axis: .horizontal)
    }

    func actionButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.setTitleColor(UIKitDesign.textPrimary, for: .normal)
        button.setTitleColor(UIKitDesign.textTertiary, for: .disabled)
        button.titleLabel?.font = UIKitDesign.medium(17)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.backgroundColor = .clear
        button.layer.borderWidth = UIKitDesign.hairline
        button.layer.borderColor = UIKitDesign.accent.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
}

final class InstrumentLoadingViewController: UIViewController {
    private let titleLabel = UIKitDesign.label("", font: UIKitDesign.regular(32), color: UIKitDesign.textPrimary, lines: 0)
    private let messageLabel = UIKitDesign.label("", font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
    private let stateLabel = UIKitDesign.label("", font: UIKitDesign.regular(15), color: UIKitDesign.textSecondary, lines: 0)
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var loadingTitle: String
    private var loadingMessage: String

    init(title: String, message: String) {
        self.loadingTitle = title
        self.loadingMessage = message
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        applyTuwaLightInterfaceStyle()
        view.backgroundColor = UIKitDesign.background
        setupLayout()
        applyText()
        spinner.startAnimating()
    }

    func update(title: String, message: String) {
        loadingTitle = title
        loadingMessage = message
        applyText()
    }

    private func setupLayout() {
        let plate = UIKitDesign.plateView(backgroundColor: UIKitDesign.raised)
        plate.layer.borderColor = UIKitDesign.hairlineStrong.cgColor
        view.addSubview(plate)

        let topRule = UIView()
        topRule.backgroundColor = UIKitDesign.accent
        topRule.translatesAutoresizingMaskIntoConstraints = false
        plate.addSubview(topRule)

        spinner.color = UIKitDesign.textSecondary
        spinner.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIKitDesign.verticalStack(spacing: Spacing.sm)
        stack.addArrangedSubview(UIKitDesign.label(UIKitDesign.microText("Tuwa"), font: UIKitDesign.regular(12), color: UIKitDesign.textTertiary))
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(messageLabel)

        let stateRow = UIStackView()
        stateRow.axis = .horizontal
        stateRow.spacing = Spacing.xs
        stateRow.alignment = .center
        stateRow.translatesAutoresizingMaskIntoConstraints = false
        stateRow.addArrangedSubview(spinner)
        stateRow.addArrangedSubview(stateLabel)
        stack.addArrangedSubview(stateRow)

        plate.addSubview(stack)
        NSLayoutConstraint.activate([
            plate.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: Spacing.sm),
            plate.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -Spacing.sm),
            plate.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            topRule.leadingAnchor.constraint(equalTo: plate.leadingAnchor),
            topRule.trailingAnchor.constraint(equalTo: plate.trailingAnchor),
            topRule.topAnchor.constraint(equalTo: plate.topAnchor),
            topRule.heightAnchor.constraint(equalToConstant: 2),
            stack.leadingAnchor.constraint(equalTo: plate.leadingAnchor, constant: Spacing.sm),
            stack.trailingAnchor.constraint(equalTo: plate.trailingAnchor, constant: -Spacing.sm),
            stack.topAnchor.constraint(equalTo: plate.topAnchor, constant: Spacing.md),
            stack.bottomAnchor.constraint(equalTo: plate.bottomAnchor, constant: -Spacing.md),
            spinner.widthAnchor.constraint(equalToConstant: 24),
            spinner.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    private func applyText() {
        guard isViewLoaded else { return }
        titleLabel.text = loadingTitle
        messageLabel.text = loadingMessage
        stateLabel.text = "Checking session"
        stateLabel.accessibilityIdentifier = "app.loading"
        stateLabel.accessibilityLabel = "Checking session"
        view.accessibilityIdentifier = "app.loading.view"
    }
}

struct UIKitLoadingController: UIViewControllerRepresentable {
    let title: String
    let message: String

    func makeUIViewController(context: Context) -> InstrumentLoadingViewController {
        let controller = InstrumentLoadingViewController(title: title, message: message)
        controller.applyTuwaLightInterfaceStyle()
        return controller
    }

    func updateUIViewController(_ controller: InstrumentLoadingViewController, context: Context) {
        controller.applyTuwaLightInterfaceStyle()
        controller.update(title: title, message: message)
    }
}
