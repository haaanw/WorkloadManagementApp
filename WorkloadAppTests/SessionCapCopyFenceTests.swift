import XCTest
@testable import workload_management

/// v1.7.3 UAT round 3 (U25 / U26) — the **copy fence** over the "Start today" lane's strings.
///
/// Two laws are pinned against the catalog itself, so copy edited later by anyone is still fenced.
///
/// 1. **Every recommendation names THEIR plan and the modulation.** The cap sentences are the
///    load-bearing case: "your 90-minute run, capped at 60 today · RPE 7" is a modulation of the
///    session the athlete wrote; "run 60 minutes at RPE 7" would be a prescription from nothing,
///    which is the one thing the product never does. Each cap sentence therefore has to open by
///    naming the athlete's own session.
/// 2. **The claim rails hold.** No string in this lane may name an injury, call anything a risk,
///    look ahead (forecast / predict), prescribe ("should" / "must"), or call anything safe.
///
/// And the practical one: **both locales carry every key.** A line that exists only in English is
/// a blank row for a zh-Hans reader.
///
/// Mirrors `TrendsMeaningTests`' catalog-level fence, scoped to this lane's own prefixes so it
/// never starts failing on copy another lane wrote.
final class SessionCapCopyFenceTests: XCTestCase {

    private let english = Locale(identifier: "en")

    /// The key prefixes this lane owns.
    private let prefixes = ["brief.", "verdictCard.cap.", "guided.cap."]

    /// The claim rails in machine-enforced form.
    private let bannedFragments = ["injur", "risk", "forecast", "predict", "should", "must", "safe"]

    /// The cap sentences — the ones that must name the athlete's own session first.
    private let capSentenceKeys = [
        "brief.cap.asPlanned",
        "brief.cap.rpeOnly",
        "brief.cap.minutesAsPlanned",
        "brief.cap.minutesRPE",
        "brief.cap.capped",
        "brief.cap.cappedRPE"
    ]

    // MARK: - 1. Every recommendation names their plan

    func test_everyCapSentence_opensByNamingTheAthletesOwnSession() throws {
        let catalog = try laneStrings()
        for key in capSentenceKeys {
            let value = try XCTUnwrap(catalog[key], "\(key) missing from the catalog")
            XCTAssertTrue(
                value.lowercased().hasPrefix("your "),
                "\(key) must open on the athlete's own session — \(value)"
            )
            XCTAssertTrue(
                value.contains("%"),
                "\(key) must interpolate the session it is talking about — \(value)"
            )
        }
    }

    /// The two sentences that actually shorten the day must SAY what it becomes, and say it
    /// relative to the plan. A cap that states only the new number reads as a prescription.
    func test_theCappedSentences_stateBothTheirNumberAndTodays() throws {
        let catalog = try laneStrings()
        for key in ["brief.cap.capped", "brief.cap.cappedRPE"] {
            let value = try XCTUnwrap(catalog[key])
            XCTAssertTrue(
                value.lowercased().contains("capped at"),
                "\(key) must name the modulation, not just the new number — \(value)"
            )
            XCTAssertGreaterThanOrEqual(
                value.components(separatedBy: "%").count - 1, 3,
                "\(key) must carry the planned duration, the session and today's cap — \(value)"
            )
        }
    }

    // MARK: - 2. The claim rails

    func test_noLaneStringMakesAForbiddenClaim() throws {
        let catalog = try laneStrings()
        XCTAssertFalse(catalog.isEmpty, "no lane keys found — the fence cannot be verified")

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
    /// cap sentences are re-checked after interpolation, so a fenced phrase cannot be assembled
    /// from two clean halves.
    func test_composedCapSentencesMakeNoForbiddenClaim() throws {
        let catalog = try laneStrings()
        var composed: [String] = []
        composed.append(String(format: try XCTUnwrap(catalog["brief.cap.asPlanned"]), "morning run"))
        composed.append(String(format: try XCTUnwrap(catalog["brief.cap.rpeOnly"]), "morning run", 7))
        composed.append(String(format: try XCTUnwrap(catalog["brief.cap.minutesAsPlanned"]), 90, "run"))
        composed.append(String(format: try XCTUnwrap(catalog["brief.cap.minutesRPE"]), 90, "run", 7))
        composed.append(String(format: try XCTUnwrap(catalog["brief.cap.capped"]), 90, "run", 60))
        composed.append(String(format: try XCTUnwrap(catalog["brief.cap.cappedRPE"]), 90, "run", 60, 7))

        for sentence in composed {
            let lowered = sentence.lowercased()
            for fragment in bannedFragments {
                XCTAssertFalse(
                    lowered.contains(fragment),
                    "CLAIM RAILS: composed sentence contains \"\(fragment)\" — \(sentence)"
                )
            }
            XCTAssertFalse(
                sentence.contains("%"),
                "a placeholder survived interpolation — \(sentence)"
            )
        }
    }

    /// The worked example from HAN's own words, end to end.
    func test_theWorkedExampleReadsAsAModulation() throws {
        let catalog = try laneStrings()
        let sentence = String(format: try XCTUnwrap(catalog["brief.cap.cappedRPE"]), 90, "run", 60, 7)
        XCTAssertTrue(sentence.hasPrefix("Your 90-minute run"), sentence)
        XCTAssertTrue(sentence.contains("capped at 60"), sentence)
        XCTAssertTrue(sentence.contains("RPE 7"), sentence)
    }

    // MARK: - 3. Both locales

    func test_everyLaneKeyCarriesBothLocales() throws {
        let strings = try catalogStrings()
        let keys = strings.keys.filter { key in prefixes.contains { key.hasPrefix($0) } }.sorted()
        XCTAssertFalse(keys.isEmpty, "no lane keys in the catalog")

        for key in keys {
            let localizations = (strings[key] as? [String: Any])?["localizations"] as? [String: Any]
            for language in ["en", "zh-Hans"] {
                let unit = (localizations?[language] as? [String: Any])?["stringUnit"] as? [String: Any]
                let value = unit?["value"] as? String
                XCTAssertFalse(
                    (value ?? "").isEmpty,
                    "\(key) has no \(language) value — one locale would read a blank row"
                )
            }
        }
    }

    /// A format string whose placeholders differ between locales crashes at `String(format:)`.
    func test_bothLocalesCarryTheSamePlaceholderCount() throws {
        let strings = try catalogStrings()
        for (key, entry) in strings where prefixes.contains(where: { key.hasPrefix($0) }) {
            let localizations = (entry as? [String: Any])?["localizations"] as? [String: Any]
            let en = value(in: localizations, language: "en") ?? ""
            let zh = value(in: localizations, language: "zh-Hans") ?? ""
            XCTAssertEqual(
                en.components(separatedBy: "%").count,
                zh.components(separatedBy: "%").count,
                "\(key): placeholder counts differ between locales (en: \(en) / zh: \(zh))"
            )
        }
    }

    // MARK: - 4. Every key the surfaces ask for exists

    func test_everyKeyTheSurfacesUseIsInTheCatalog() throws {
        let strings = try catalogStrings()
        let referenced = [
            "todayProposal.startToday",
            "brief.nav.title", "brief.section.today", "brief.section.soToday", "brief.section.numbers",
            "brief.reading.readiness", "brief.reading.fatigue", "brief.reading.hrv",
            "brief.reading.rhr", "brief.reading.sleep", "brief.reading.match",
            "brief.value.learning", "brief.note.outOf100", "brief.note.vsBaseline",
            "brief.note.sleepMean",
            "brief.note.fatigue.low", "brief.note.fatigue.elevated",
            "brief.note.fatigue.high", "brief.note.fatigue.saturation",
            "brief.fatigue.low", "brief.fatigue.elevated", "brief.fatigue.high",
            "brief.fatigue.saturation",
            "brief.unit.ms", "brief.unit.msBare", "brief.unit.bpm", "brief.unit.bpmBare",
            "brief.unit.hoursMinutes",
            "brief.match.today", "brief.match.tomorrow", "brief.match.inDays",
            "brief.verdict.none", "brief.verdict.adjusted", "brief.verdict.asPlanned",
            "brief.verdict.deferred",
            "brief.action.accept", "brief.action.start",
            "brief.numbers.none", "brief.numbers.sets", "brief.numbers.rpe", "brief.numbers.planned",
            "brief.cap.anchor",
            "verdictCard.cap.minutes", "verdictCard.cap.rpeValue", "verdictCard.cap.asPlannedValue",
            "verdictCard.cap.fromPlanned", "verdictCard.cap.ceiling", "verdictCard.cap.noCeiling",
            "verdictCard.cap.asWritten", "verdictCard.cap.cell.take", "verdictCard.cap.cell.taper",
            "verdictCard.cap.cell.hold", "verdictCard.cap.state.capped",
            "verdictCard.cap.state.taper", "verdictCard.cap.state.hold", "verdictCard.cap.action",
            "guided.cap.planned", "guided.cap.today", "guided.cap.minutes",
            "guided.cap.elapsedOf", "guided.cap.ceiling", "guided.cap.logSession"
        ] + capSentenceKeys

        for key in referenced {
            XCTAssertNotNil(strings[key], "referenced key not in the catalog: \(key)")
        }
    }

    // MARK: - Catalog access

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

    private func value(in localizations: [String: Any]?, language: String) -> String? {
        let unit = (localizations?[language] as? [String: Any])?["stringUnit"] as? [String: Any]
        return unit?["value"] as? String
    }

    /// Every ENGLISH value this lane owns, keyed by its catalog key.
    private func laneStrings() throws -> [String: String] {
        let strings = try catalogStrings()
        var result: [String: String] = [:]
        for (key, entry) in strings where prefixes.contains(where: { key.hasPrefix($0) }) {
            let localizations = (entry as? [String: Any])?["localizations"] as? [String: Any]
            if let value = value(in: localizations, language: "en") {
                result[key] = value
            }
        }
        return result
    }
}
