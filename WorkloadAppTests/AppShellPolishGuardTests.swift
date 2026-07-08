import XCTest

final class AppShellPolishGuardTests: XCTestCase {

    private func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    func test_segmentedControlKeepsSeparatorsAsHairlines() throws {
        let source = try source("WorkloadApp/App/AppShellUIKitPrimitives.swift")
        let segmentedControl = try XCTUnwrap(source.range(of: "final class InstrumentSegmentedControlUIKit"))
        let bottomActionDock = try XCTUnwrap(source.range(of: "final class UIKitBottomActionDock"))
        let body = String(source[segmentedControl.lowerBound..<bottomActionDock.lowerBound])

        XCTAssertTrue(body.contains("stack.distribution = .fill"))
        XCTAssertFalse(body.contains("stack.distribution = .fillEqually"))
        XCTAssertTrue(body.contains("separator.setContentHuggingPriority(.required, for: .horizontal)"))
        XCTAssertTrue(body.contains("separator.setContentCompressionResistancePriority(.required, for: .horizontal)"))
    }

    func test_primaryCtasUseAccentOutline() throws {
        let source = try source("WorkloadApp/App/AppShellUIKitPrimitives.swift")

        XCTAssertTrue(source.contains("button.layer.borderColor = (isPrimary ? UIKitDesign.accent : UIKitDesign.hairlineColor).cgColor"))
        XCTAssertTrue(source.contains("button.layer.borderColor = UIKitDesign.accent.cgColor"))
    }

    func test_disclosureRowsUseRightAlignedTrailingColumn() throws {
        let source = try source("WorkloadApp/App/AppShellUIKitPrimitives.swift")
        let rowStart = try XCTUnwrap(source.range(of: "func disclosureRow"))
        let dividerStart = try XCTUnwrap(source.range(of: "func divider"))
        let body = String(source[rowStart.lowerBound..<dividerStart.lowerBound])

        XCTAssertTrue(body.contains("trailingLabel.textAlignment = .right"))
        XCTAssertTrue(body.contains("trailingLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 96).isActive = true"))
    }

    func test_idleAndReadyStatePlatesStayHiddenAtRest() throws {
        let source = try source("WorkloadApp/App/AppShell.swift")

        XCTAssertTrue(source.contains("private var shouldShowAuthStatePlate: Bool {\n        forcedStateText != nil || isLoading || validationMessages.isEmpty == false || errorMessage != nil\n    }"))
        XCTAssertTrue(source.contains("private var shouldShowPaywallStatePlate: Bool {\n        isLoadingOffering || isPurchasing || offeringUnavailable || errorMessage != nil\n    }"))
    }

    func test_activeWorkoutSetCountTextIsCompactAndUnspaced() throws {
        let source = try source("WorkloadApp/App/AppShell.swift")

        XCTAssertTrue(source.contains(".replacingOccurrences(of: \" / \", with: \"/\")"))
        XCTAssertTrue(source.contains(".replacingOccurrences(of: \" sets done\", with: \" sets\")"))
    }

    func test_sheetCancelButtonsHideIos26SharedBackground() throws {
        let source = try source("WorkloadApp/App/AppShell.swift")

        XCTAssertTrue(source.contains("private func instrumentPlainBarButtonItem("))
        XCTAssertTrue(source.contains("hidesSharedBackground = true"))
        XCTAssertTrue(source.contains("navigationItem.leftBarButtonItem = instrumentPlainBarButtonItem(\n            title: \"Cancel\""))
        XCTAssertTrue(source.contains("let cancelItem = instrumentPlainBarButtonItem("))
    }

    func test_loadInsightChineseStringsArePresent() throws {
        let source = try source("WorkloadApp/Resources/Localizable.xcstrings")

        XCTAssertTrue(source.contains("\"load.insights.heroKicker\""))
        XCTAssertTrue(source.contains("\"value\" : \"负荷\""))
        XCTAssertTrue(source.contains("\"value\" : \"负荷平衡\""))
        XCTAssertTrue(source.contains("\"value\" : \"训练量\""))
        XCTAssertTrue(source.contains("\"value\" : \"急性\""))
        XCTAssertTrue(source.contains("\"value\" : \"慢性\""))
        XCTAssertTrue(source.contains("\"value\" : \"平衡\""))
        XCTAssertTrue(source.contains("\"value\" : \"%1$@ · 更新于 %2$@\""))
    }

    func test_templateExerciseCountHasSingularAndPluralCopies() throws {
        let source = try source("WorkloadApp/Resources/Localizable.xcstrings")

        XCTAssertTrue(source.contains("\"template.exerciseCount\""))
        XCTAssertTrue(source.contains("\"value\" : \"%d exercises\""))
        XCTAssertTrue(source.contains("\"template.exerciseCount.one\""))
        XCTAssertTrue(source.contains("\"value\" : \"%d exercise\""))
    }
}
