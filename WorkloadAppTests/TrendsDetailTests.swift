import XCTest
import SwiftUI
@testable import workload_management

/// v1.7.3 UAT round 3 · **U20 — "How to read this" belongs on a per-index page.**
///
/// The round-2 meaning layer put eleven collapsed explanation rows under the fatigue card, five
/// under the load card and two under the activity card. HAN's verdict on device: the reading
/// sentence stays, the disclosure lists cost the page more height than the heroes they explain.
/// Tapping the fatigue card should open a breakdown — what the score means and how to read the
/// current value — and the same for load.
///
/// Four claims are pinned here.
///
/// 1. **The doors exist.** `TrendDestination` carries a case per hero, each holding the window
///    the card was showing, and both tabs that switch on the enum route them to the new screens.
/// 2. **The lists actually MOVED.** Source-level, both directions: no `DetailDisclosureList` is
///    left in the Trends components, and the detail screens own one each. A list that was copied
///    rather than moved would leave the page exactly as tall as HAN rejected it.
/// 3. **Nothing is said twice.** The six fatigue components and the three loads are printed
///    expanded under their tree rows, so they are NOT also in the collapsed lists.
/// 4. **Both locales, and the claim rails hold.** A title that exists only in English is a blank
///    navigation bar for a zh-Hans reader; and a breakdown still describes rather than decides.
final class TrendsDetailTests: XCTestCase {

    private let english = Locale(identifier: "en")

    /// The key prefix this lane added. Scoped so neither fence starts failing on copy another
    /// lane wrote.
    private let detailPrefix = "trends.detail."

    /// The claim rails, in machine-enforced form — the same list the round-2 meaning fence uses.
    private let bannedFragments = ["injur", "risk", "forecast", "predict", "should", "must", "safe"]

    // MARK: - 1. The doors

    func test_destinationEnum_carriesBothTrendsHeroes() {
        // A case per hero, and the window rides along: a breakdown of a fortnight that silently
        // re-read a month would not be the number the athlete tapped.
        XCTAssertEqual(TrendDestination.fatigue(range: .twoWeeks), .fatigue(range: .twoWeeks))
        XCTAssertEqual(TrendDestination.load(range: .oneMonth), .load(range: .oneMonth))
        XCTAssertNotEqual(TrendDestination.fatigue(range: .twoWeeks), .fatigue(range: .oneMonth))
        XCTAssertNotEqual(TrendDestination.fatigue(range: .oneWeek), .load(range: .oneWeek))

        // Hashable is what `NavigationLink(value:)` requires of it.
        let path: Set<TrendDestination> = [
            .hrv, .rhr, .sleep,
            .fatigue(range: .oneWeek), .fatigue(range: .twoWeeks),
            .load(range: .oneWeek)
        ]
        XCTAssertEqual(path.count, 6)
    }

    /// Both tabs switch on the same enum, so both must land the new cases — a case handled in
    /// one place and defaulted in the other is a door that opens from Trends and nowhere else.
    func test_fence_bothTabsRouteTheNewDestinations() {
        for path in [
            "WorkloadApp/Views/Dashboard/DashboardView.swift",
            "WorkloadApp/Views/Trends/TrendsView.swift"
        ] {
            let source = readSource(path)
            XCTAssertTrue(source.contains("FatigueDetailScreen(range:"),
                          "\(path): TrendDestination.fatigue must land on FatigueDetailScreen")
            XCTAssertTrue(source.contains("LoadDetailScreen(range:"),
                          "\(path): TrendDestination.load must land on LoadDetailScreen")
        }
    }

    /// The cards are the doors. Both carry the caret, because a surface that navigates with no
    /// mark reads as a readout — U9's finding, applied to the two heroes U20 opened.
    func test_fence_theTrendsHeroesAreDoors() {
        let source = readSource("WorkloadApp/Views/Trends/TrendsComponents.swift")
        XCTAssertTrue(source.contains("NavigationLink(value: destination)"),
                      "the fatigue and load heroes must push their detail")
        XCTAssertEqual(
            source.components(separatedBy: "CardDoorCaret()").count - 1, 3,
            "each door carries the caret: fatigue's reading, fatigue's empty state, load's reading"
        )

        let view = readSource("WorkloadApp/Views/Trends/TrendsView.swift")
        XCTAssertTrue(view.contains("destination: .fatigue(range: viewModel.selectedRange)"),
                      "the fatigue card must hand its OWN window to the breakdown")
        XCTAssertTrue(view.contains("destination: .load(range: viewModel.selectedRange)"),
                      "the load card must hand its OWN window to the breakdown")
    }

    // MARK: - 2. The lists moved

    func test_fence_trendsComponentsCarryNoDisclosureList() {
        let source = readSource("WorkloadApp/Views/Trends/TrendsComponents.swift")
        XCTAssertFalse(
            source.contains("DetailDisclosureList("),
            "U20: no collapsed explanation list may render on the Trends page itself"
        )
    }

    func test_fence_theDetailScreensOwnTheLists() {
        let source = readSource("WorkloadApp/Views/Trends/TrendDetailScreens.swift")
        for screen in ["struct FatigueDetailScreen", "struct LoadDetailScreen"] {
            XCTAssertTrue(source.contains(screen), "\(screen) must exist")
        }
        // Three lists: fatigue's own, load's own, and the activity pair that rode across.
        XCTAssertEqual(
            source.components(separatedBy: "DetailDisclosureList(").count - 1, 3,
            "the explanations must land here — moved, not deleted"
        )
        XCTAssertTrue(source.contains("items: TrendsWhatYouDidSection.aboutItems"),
                      "the activity card's two items ride the load breakdown")
    }

    // MARK: - 3. Nothing is said twice

    /// The six component explanations print expanded under their tree rows, so they must not
    /// ALSO sit collapsed in the same page's list.
    func test_componentExplanationsAreNotAlsoCollapsed() {
        let collapsed = Set(TrendsFatigueSection.aboutItems.map { String(describing: $0.bodyKey) })
        for item in TrendsFatigueSection.componentAboutItems {
            XCTAssertFalse(
                collapsed.contains(String(describing: item.bodyKey)),
                "fatigue component gloss is both expanded and collapsed on one page"
            )
        }

        let loadCollapsed = Set(TrendsLoadSection.aboutItems.map { String(describing: $0.bodyKey) })
        for item in TrendsLoadSection.componentAboutItems {
            XCTAssertFalse(
                loadCollapsed.contains(String(describing: item.bodyKey)),
                "load gloss is both expanded and collapsed on one page"
            )
        }
    }

    /// One tree row per gloss, in the same order — the two arrays are zipped on screen, so a
    /// mismatch would silently pair a component with somebody else's explanation.
    func test_fatigueTreeRows_pairOneToOneWithTheirGlosses() {
        let rows = TrendsFatigueSection.componentRows(
            components: result(index: 48),
            names: TrendsFatigueSection.componentWeightedNames(locale: english)
        )
        XCTAssertEqual(rows.count, TrendsFatigueSection.componentAboutItems.count)
        XCTAssertEqual(rows.count, 6)

        for (offset, row) in rows.enumerated() {
            let isLast = offset == rows.count - 1
            XCTAssertTrue(row.hasPrefix(isLast ? "\u{2514}\u{2500}" : "\u{251C}\u{2500}"),
                          "row \(offset) carries the wrong stem: \(row)")
        }
        // The weighted names come from the About titles, so the weight is authored once.
        XCTAssertTrue(rows[0].contains("20%"), "the detail tree states the engine's own weight: \(rows[0])")
        // 0.62 → 62, above the neutral middle → ▲.
        XCTAssertTrue(rows[0].hasSuffix("\u{25B2} 62"), "the row must end in its glyph and value: \(rows[0])")
    }

    func test_loadTreeRows_printTheThreeLoadsWithTheirKeys() {
        let rows = TrendsLoadSection.loadRows(acute: 412, chronic: 408, tsb: -4, locale: english)
        XCTAssertEqual(rows.count, TrendsLoadSection.componentAboutItems.count)
        XCTAssertEqual(rows.count, 3)

        XCTAssertTrue(rows[0].contains("ATL 412"), rows[0])
        XCTAssertTrue(rows[1].contains("CTL 408"), rows[1])
        XCTAssertTrue(rows[2].contains("TSB -4"), rows[2])
        XCTAssertTrue(rows[2].hasPrefix("\u{2514}\u{2500}"), "the last row closes the stem: \(rows[2])")
    }

    // MARK: - 4. Both locales, and the rails

    func test_everyDetailKeyCarriesBothLocales() throws {
        let strings = try catalogStrings()
        let keys = strings.keys.filter { $0.hasPrefix(detailPrefix) }.sorted()
        XCTAssertFalse(keys.isEmpty, "no trends.detail.* keys in the catalog")

        for key in keys {
            let localizations = (strings[key] as? [String: Any])?["localizations"] as? [String: Any]
            for language in ["en", "zh-Hans"] {
                let unit = (localizations?[language] as? [String: Any])?["stringUnit"] as? [String: Any]
                let value = unit?["value"] as? String
                XCTAssertFalse(
                    (value ?? "").isEmpty,
                    "\(key) has no \(language) value — one locale would read a blank breakdown"
                )
            }
        }
    }

    /// Every key the two screens ask for, present in the catalog. A key referenced in code but
    /// absent renders as the raw key string on screen, which no catalog-only test would catch.
    func test_everyKeyTheDetailScreensUseIsInTheCatalog() throws {
        let strings = try catalogStrings()
        var referenced = [
            "trends.detail.fatigue.title",
            "trends.detail.fatigue.subtitleFormat",
            "trends.detail.fatigue.components.eyebrow",
            "trends.detail.load.title",
            "trends.detail.load.subtitleFormat",
            "trends.detail.load.components.eyebrow",
            "trends.detail.load.tsb.title",
            // Carried over from the cards — the breakdowns restate the same heroes.
            "trends.fatigue.unit",
            "trends.fatigue.empty",
            "trends.load.unit",
            "trends.load.sentence",
            "trends.load.sentence.heldRange",
            "trends.meaning.about.eyebrow",
            "trends.section.activity"
        ]
        referenced += TrendsFatigueSection.componentAboutItems.map { String(describing: $0.titleKey) }
        referenced += TrendsLoadSection.componentAboutItems.map { String(describing: $0.titleKey) }

        for key in referenced {
            let resolved = strings.keys.first { key == $0 || key.contains($0) }
            XCTAssertNotNil(resolved, "referenced key not in the catalog: \(key)")
        }
    }

    /// A breakdown still DESCRIBES. The rails that fence the card's reading fence its detail
    /// page too, or the copy simply moved one tap away from the rule.
    func test_noDetailStringMakesAForbiddenClaim() throws {
        let strings = try catalogStrings()
        var checked = 0
        for (key, entry) in strings where key.hasPrefix(detailPrefix) {
            let localizations = (entry as? [String: Any])?["localizations"] as? [String: Any]
            let unit = (localizations?["en"] as? [String: Any])?["stringUnit"] as? [String: Any]
            guard let value = unit?["value"] as? String else { continue }
            checked += 1
            let lowered = value.lowercased()
            for fragment in bannedFragments {
                XCTAssertFalse(
                    lowered.contains(fragment),
                    "CLAIM RAILS: \(key) contains \"\(fragment)\" — \(value)"
                )
            }
        }
        XCTAssertGreaterThan(checked, 0, "no trends.detail.* English values found — the fence cannot be verified")
    }

    // MARK: - Harness

    private func result(index: Double) -> FatigueIndexEngine.FatigueResult {
        FatigueIndexEngine.FatigueResult(
            index: index,
            zone: FatigueIndexEngine.FatigueZone.classify(index: index),
            loadElevation: 0.62,
            sessionDensity: 0.5,
            recoveryTrend: 0.5,
            restDebt: 0.5,
            wellnessTrend: 0.5,
            softTissueRisk: 0.0
        )
    }

    /// Repo root, from this test file's own path — the resolution every source-level fence uses.
    private func repoRoot(file: StaticString = #filePath) -> URL {
        URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func readSource(_ path: String, file: StaticString = #filePath, line: UInt = #line) -> String {
        let url = repoRoot().appendingPathComponent(path)
        guard let source = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("could not read \(path)", file: file, line: line)
            return ""
        }
        return source
    }

    private func catalogStrings() throws -> [String: Any] {
        let url = repoRoot()
            .appendingPathComponent("WorkloadApp/Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return (json?["strings"] as? [String: Any]) ?? [:]
    }
}
