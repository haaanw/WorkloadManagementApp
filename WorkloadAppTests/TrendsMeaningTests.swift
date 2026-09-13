import XCTest
@testable import workload_management

/// v1.7.3 UAT round 2 · **U16 — "Trends is data, not meaning."**
///
/// The founder's verdict was that a fatigue index of 34 / LOW and an acute÷chronic of 1.01 /
/// LOAD STEADY are plain numbers: a non-expert cannot tell what either one means for them. The
/// meaning layer answers that in one plain-language reading under each hero, plus a collapsed
/// "how to read this" per section.
///
/// Three claims are pinned here.
///
/// 1. **Every state has a reading.** Four fatigue zones × three trajectories, and all five load
///    zones, compose a real sentence — not an empty string, and not a raw key that leaked
///    because the catalog lookup missed.
/// 2. **The claim rails hold.** Trends DESCRIBES; the day's proposal on Today DECIDES. So no
///    meaning string may name an injury, call anything a risk, forecast, predict, prescribe
///    ("should" / "must"), or call any part of a scale safe. This is enforced against the
///    catalog itself, so copy edited later by anyone is still fenced.
/// 3. **Both locales carry every key.** A reading that exists only in English is a blank card
///    for a zh-Hans reader.
final class TrendsMeaningTests: XCTestCase {

    // MARK: - Harness

    private let english = Locale(identifier: "en")

    private let zones: [FatigueIndexEngine.FatigueZone] = [.low, .elevated, .high, .saturation]
    private let trajectories: [FatigueHistoryEngine.Trajectory] = [.rising, .steady, .falling]
    private let loadZones: [ACWRZone] = [.undertrained, .optimal, .caution, .danger, .noData]

    /// The key prefix this lane owns. Both the rails fence and the locale sweep scope
    /// themselves to it, so neither one starts failing on copy another lane wrote.
    private let meaningPrefix = "trends.meaning."

    /// Substrings no meaning string may contain, lowercased. These are the claim rails in
    /// machine-enforced form: injury claims, hazard framing, anything forward-looking, anything
    /// prescriptive, and the particular phrase "safe range" that turns a description of the
    /// 0.8–1.3 band into a medical claim.
    private let bannedFragments = ["injur", "risk", "forecast", "predict", "should", "must", "safe"]

    /// A reading that is empty, or that is still the key it was looked up by, is a defect —
    /// `String(localized:)` hands the key back when the catalog has no entry, and that failure
    /// is invisible without this assertion.
    private func assertRealSentence(
        _ reading: String,
        _ context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertFalse(
            reading.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            "\(context): empty reading",
            file: file, line: line
        )
        XCTAssertFalse(
            reading.contains(meaningPrefix),
            "\(context): catalog lookup missed — raw key leaked into the reading (\(reading))",
            file: file, line: line
        )
    }

    private func point(index: Double) -> FatigueHistoryEngine.Point {
        let zone = FatigueIndexEngine.FatigueZone.classify(index: index)
        return FatigueHistoryEngine.Point(
            day: Calendar.current.startOfDay(for: .now),
            index: index,
            zone: zone,
            components: FatigueIndexEngine.FatigueResult(
                index: index,
                zone: zone,
                loadElevation: 0.5,
                sessionDensity: 0.5,
                recoveryTrend: 0.5,
                restDebt: 0.5,
                wellnessTrend: 0.5,
                softTissueRisk: 0.0
            )
        )
    }

    // MARK: - 1. Every state has a reading

    func test_everyZoneAndTrajectory_composesAReading() {
        for zone in zones {
            for trajectory in trajectories {
                let reading = TrendsFatigueSection.fatigueReading(
                    zone: zone,
                    trajectory: trajectory,
                    locale: english
                )
                assertRealSentence(reading, "fatigue \(zone) / \(trajectory)")

                // The reading is a COMPOSITION: the zone sentence carries what the number
                // means, the trajectory clause carries which way the window went. Both halves
                // have to actually be in there.
                XCTAssertTrue(
                    reading.contains(TrendsFatigueSection.zoneReading(zone, locale: english)),
                    "fatigue \(zone) / \(trajectory): zone sentence missing"
                )
                XCTAssertTrue(
                    reading.contains(TrendsFatigueSection.trajectoryClause(trajectory, locale: english)),
                    "fatigue \(zone) / \(trajectory): trajectory clause missing"
                )
            }
        }
    }

    /// The pointer at Today's proposal is what keeps the reading descriptive: anything above
    /// Low names the surface that decides rather than deciding here. Low needs no pointer —
    /// there is nothing for the proposal to account for.
    func test_pointerAppearsAboveLowOnly() {
        let pointer = LocalePinnedStrings.localized("trends.meaning.fatigue.pointer", locale: english)

        for trajectory in trajectories {
            let low = TrendsFatigueSection.fatigueReading(zone: .low, trajectory: trajectory, locale: english)
            XCTAssertFalse(low.contains(pointer), "low / \(trajectory): pointer must not appear")

            for zone in [FatigueIndexEngine.FatigueZone.elevated, .high, .saturation] {
                let reading = TrendsFatigueSection.fatigueReading(
                    zone: zone,
                    trajectory: trajectory,
                    locale: english
                )
                XCTAssertTrue(reading.contains(pointer), "\(zone) / \(trajectory): pointer missing")
            }
        }
    }

    func test_everyLoadZone_composesAReading() {
        var readings: Set<String> = []
        for zone in loadZones {
            let reading = TrendsLoadSection.loadReading(zone, locale: english)
            assertRealSentence(reading, "load \(zone)")
            readings.insert(reading)
        }
        // Five zones, five distinct sentences — a shared sentence would mean two different
        // states read identically to the athlete.
        XCTAssertEqual(readings.count, loadZones.count, "load zones do not all read differently")
    }

    func test_activityReading_isASentence() {
        assertRealSentence(TrendsWhatYouDidSection.activityReading(locale: english), "activity")
    }

    // MARK: - The trajectory the reading uses

    /// The engine's slope classification wins when it has one: it fits every point in the
    /// window rather than the two ends.
    func test_readingTrajectory_prefersTheEnginesClassification() {
        let series = [point(index: 10), point(index: 90)]
        XCTAssertEqual(
            TrendsFatigueSection.readingTrajectory(points: series, trajectory: .falling),
            .falling
        )
    }

    /// Below the two points a slope needs, first-versus-last stands in — with a dead band, so a
    /// one-point wobble is reported as level rather than as a direction.
    func test_readingTrajectory_fallsBackToFirstVersusLastWithADeadBand() {
        let band = TrendsFatigueSection.readingDeadBand

        XCTAssertEqual(
            TrendsFatigueSection.readingTrajectory(
                points: [point(index: 40), point(index: 40 + band + 1)],
                trajectory: nil
            ),
            .rising
        )
        XCTAssertEqual(
            TrendsFatigueSection.readingTrajectory(
                points: [point(index: 40), point(index: 40 - band - 1)],
                trajectory: nil
            ),
            .falling
        )
        XCTAssertEqual(
            TrendsFatigueSection.readingTrajectory(
                points: [point(index: 40), point(index: 40 + band - 0.5)],
                trajectory: nil
            ),
            .steady,
            "movement inside the dead band is jitter, not a direction"
        )
        XCTAssertEqual(
            TrendsFatigueSection.readingTrajectory(points: [], trajectory: nil),
            .steady,
            "an empty series still needs a clause"
        )
    }

    // MARK: - 2. The claim rails

    func test_noMeaningStringMakesAForbiddenClaim() throws {
        let catalog = try meaningStrings()
        XCTAssertFalse(catalog.isEmpty, "no trends.meaning.* keys found — the fence cannot be verified")

        for (key, value) in catalog {
            let lowered = value.lowercased()
            for fragment in bannedFragments {
                XCTAssertFalse(
                    lowered.contains(fragment),
                    "CLAIM RAILS: \(key) contains \"\(fragment)\" — \(value)"
                )
            }
        }
    }

    /// The rails apply to what is on screen, not only to what is in the catalog: the composed
    /// readings are re-checked after composition, so a fenced phrase cannot be assembled from
    /// two clean halves.
    func test_composedReadingsMakeNoForbiddenClaim() {
        var composed: [String] = [TrendsWhatYouDidSection.activityReading(locale: english)]
        for zone in zones {
            for trajectory in trajectories {
                composed.append(TrendsFatigueSection.fatigueReading(
                    zone: zone,
                    trajectory: trajectory,
                    locale: english
                ))
            }
        }
        composed.append(contentsOf: loadZones.map { TrendsLoadSection.loadReading($0, locale: english) })

        for reading in composed {
            let lowered = reading.lowercased()
            for fragment in bannedFragments {
                XCTAssertFalse(
                    lowered.contains(fragment),
                    "CLAIM RAILS: composed reading contains \"\(fragment)\" — \(reading)"
                )
            }
        }
    }

    // MARK: - 3. Both locales

    func test_everyMeaningKeyCarriesBothLocales() throws {
        let strings = try catalogStrings()
        let keys = strings.keys.filter { $0.hasPrefix(meaningPrefix) }.sorted()
        XCTAssertFalse(keys.isEmpty, "no trends.meaning.* keys in the catalog")

        for key in keys {
            let localizations = (strings[key] as? [String: Any])?["localizations"] as? [String: Any]
            for language in ["en", "zh-Hans"] {
                let unit = (localizations?[language] as? [String: Any])?["stringUnit"] as? [String: Any]
                let value = unit?["value"] as? String
                XCTAssertFalse(
                    (value ?? "").isEmpty,
                    "\(key) has no \(language) value — one locale would read a blank card"
                )
            }
        }
    }

    /// Every key the sections ask for has to exist. A key referenced in code but absent from
    /// the catalog renders as the raw key string on screen, which no test of the catalog alone
    /// would catch.
    func test_everyKeyTheSectionsUseIsInTheCatalog() throws {
        let strings = try catalogStrings()
        var referenced: [String] = [
            "trends.meaning.about.eyebrow",
            "trends.meaning.activity",
            "trends.meaning.fatigue.pointer"
        ]
        referenced += ["low", "elevated", "high", "veryHigh"].map { "trends.meaning.fatigue.zone.\($0)" }
        referenced += ["rising", "steady", "falling"].map { "trends.meaning.fatigue.trajectory.\($0)" }
        referenced += ["light", "steady", "building", "high", "noData"].map { "trends.meaning.load.\($0)" }

        for item in TrendsFatigueSection.aboutItems
            + TrendsLoadSection.aboutItems
            + TrendsWhatYouDidSection.aboutItems {
            referenced.append(String(describing: item.titleKey))
            referenced.append(String(describing: item.bodyKey))
        }

        for key in referenced {
            // `LocalizedStringKey`'s description wraps the key; match on containment so this
            // survives whatever wrapper the standard library prints.
            let resolved = strings.keys.first { key == $0 || key.contains($0) }
            XCTAssertNotNil(resolved, "referenced key not in the catalog: \(key)")
        }
    }

    // MARK: - Catalog access

    /// Repo root, from this test file's own path (`<repo>/WorkloadAppTests/…` → two up) —
    /// the same resolution the other source-level fence tests use.
    private func repoRoot(file: StaticString = #filePath) -> URL {
        URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func catalogStrings() throws -> [String: Any] {
        let url = repoRoot()
            .appendingPathComponent("WorkloadApp/Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return (json?["strings"] as? [String: Any]) ?? [:]
    }

    /// Every `trends.meaning.*` ENGLISH value in the catalog, keyed by its catalog key.
    private func meaningStrings() throws -> [String: String] {
        let strings = try catalogStrings()
        var result: [String: String] = [:]
        for (key, entry) in strings where key.hasPrefix(meaningPrefix) {
            let localizations = (entry as? [String: Any])?["localizations"] as? [String: Any]
            let unit = (localizations?["en"] as? [String: Any])?["stringUnit"] as? [String: Any]
            if let value = unit?["value"] as? String {
                result[key] = value
            }
        }
        return result
    }
}
