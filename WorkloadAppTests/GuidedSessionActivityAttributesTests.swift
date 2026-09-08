import XCTest
import ActivityKit
@testable import workload_management

/// The guided session Live Activity's contract (v1.7.3 feature 9 batch 2, tier 1).
///
/// Three of these are FENCES, not behavior checks:
/// - `test_compositeOnly_noRawSignalFieldNames` — the composite-only law, hardened. The App Group
///   container is private to the device; the LOCK SCREEN is public, so this state may not carry a
///   body number of ANY kind, composite ones included. Mirrors `WidgetSnapshotTests`' field-name
///   fence with a wider forbidden list.
/// - `test_appDeclaresLiveActivitySupport` — ActivityKit refuses to start without
///   `NSSupportsLiveActivities`, and it fails silently at runtime. Fail here instead.
/// - `test_widgetExtension_readsOnly` — the extension renders; it never reaches for a database, a
///   health store, or the snapshot WRITER.
final class GuidedSessionActivityAttributesTests: XCTestCase {

    // MARK: - Fixtures

    private func makeFullState() -> GuidedSessionActivityAttributes.ContentState {
        // Whole-second dates: the codec's date strategy must not be the reason a round-trip fails.
        GuidedSessionActivityAttributes.ContentState(
            moveName: "Back squat",
            moveTag: "3A",
            movePosition: "1/4",
            targetLine: "132.5 kg × 5",
            setStates: [.logged, .current, .planned, .skipped],
            nextKind: .then,
            nextMoveName: "Romanian deadlift",
            nextLine: "Set 2 · 30 kg × 10",
            sessionStates: [.logged, .logged, .current, .planned, .planned],
            startedAt: Date(timeIntervalSince1970: 1_756_500_000),
            lastLoggedAt: Date(timeIntervalSince1970: 1_756_500_600),
            loggedCount: 2,
            setsLeft: 3,
            isComplete: false
        )
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // WorkloadAppTests/
            .deletingLastPathComponent()   // repo root
    }

    // MARK: - Codec

    func test_roundTrip_preservesEveryField() throws {
        let original = makeFullState()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            GuidedSessionActivityAttributes.ContentState.self,
            from: data
        )
        XCTAssertEqual(decoded, original)
    }

    func test_attributes_roundTrip() throws {
        let original = GuidedSessionActivityAttributes(sessionName: "Heavy lower")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GuidedSessionActivityAttributes.self, from: data)
        XCTAssertEqual(decoded.sessionName, original.sessionName)
    }

    func test_optionalNextFields_surviveAsNil() throws {
        var state = makeFullState()
        state.nextKind = .finish
        state.nextMoveName = nil
        state.nextLine = nil
        state.lastLoggedAt = nil
        let decoded = try JSONDecoder().decode(
            GuidedSessionActivityAttributes.ContentState.self,
            from: try JSONEncoder().encode(state)
        )
        XCTAssertNil(decoded.nextMoveName)
        XCTAssertNil(decoded.nextLine)
        XCTAssertNil(decoded.lastLoggedAt)
        XCTAssertEqual(decoded.nextKind, .finish)
    }

    func test_setStateRawValues_areStable() {
        // The renderer switches on these; a rename must fail here, not silently repaint the bar.
        XCTAssertEqual(GuidedSessionActivityAttributes.SetState.logged.rawValue, "logged")
        XCTAssertEqual(GuidedSessionActivityAttributes.SetState.current.rawValue, "current")
        XCTAssertEqual(GuidedSessionActivityAttributes.SetState.planned.rawValue, "planned")
        XCTAssertEqual(GuidedSessionActivityAttributes.SetState.skipped.rawValue, "skipped")
        XCTAssertEqual(GuidedSessionActivityAttributes.NextKind.next.rawValue, "next")
        XCTAssertEqual(GuidedSessionActivityAttributes.NextKind.then.rawValue, "then")
        XCTAssertEqual(GuidedSessionActivityAttributes.NextKind.finish.rawValue, "finish")
    }

    // MARK: - The session bar cap

    func test_sessionBar_capsFromTheFront() {
        let cap = GuidedSessionActivityAttributes.ContentState.sessionBarCap
        // A long session: the first entries are logged history, the tail is what is still owed.
        let states: [GuidedSessionActivityAttributes.SetState] =
            Array(repeating: .logged, count: cap) + [.current, .planned, .planned]
        var state = makeFullState()
        state.sessionStates = states

        XCTAssertEqual(state.sessionStates.count, cap, "The bar is capped")
        XCTAssertEqual(
            state.sessionStates.suffix(3),
            [.current, .planned, .planned],
            "The TAIL survives — the cursor and the sets still owed are what the bar is for"
        )
    }

    func test_sessionBar_shortSessionIsUntouched() {
        let state = makeFullState()
        XCTAssertEqual(state.sessionStates.count, 5)
    }

    // MARK: - Fences

    func test_compositeOnly_noRawSignalFieldNames() throws {
        // The lock screen is a PUBLIC surface. Unlike the App Group snapshot — which may carry a
        // readiness score because only this device reads it — nothing physiological belongs here
        // at all, composite or raw. A field whose NAME matches a body signal is a law violation
        // regardless of intent.
        let forbiddenFragments = [
            "hrv", "sdnn", "heart", "rhr", "sleep", "temperature", "bodytemp",
            "vo2", "respirat", "readiness", "recovery", "score", "wellness"
        ]

        var names = Mirror(reflecting: makeFullState()).children.compactMap(\.label)
        names += Mirror(reflecting: GuidedSessionActivityAttributes(sessionName: "Heavy lower"))
            .children.compactMap(\.label)
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(makeFullState()))
        names += (try XCTUnwrap(encoded as? [String: Any])).keys.map { $0 }

        for name in names {
            let lowered = name.lowercased()
            for fragment in forbiddenFragments {
                XCTAssertFalse(
                    lowered.contains(fragment),
                    "GuidedSessionActivityAttributes field '\(name)' matches body-signal fragment '\(fragment)' — the lock screen is public; the activity carries the SESSION, never the athlete"
                )
            }
        }
    }

    func test_attributesFile_importsNothingAppSpecific() throws {
        // The file compiles in BOTH targets (app + widget extension), so it may import only
        // Foundation and ActivityKit — a SwiftUI or SwiftData import here would break the
        // extension build, and an app model type would break the contract.
        let source = try String(
            contentsOf: repoRoot()
                .appendingPathComponent("WorkloadApp/Services/GuidedSessionActivityAttributes.swift"),
            encoding: .utf8
        )
        let imports = source
            .components(separatedBy: .newlines)
            .filter { $0.hasPrefix("import ") }
            .map { $0.replacingOccurrences(of: "import ", with: "").trimmingCharacters(in: .whitespaces) }
        XCTAssertEqual(
            Set(imports), ["ActivityKit", "Foundation"],
            "The shared activity contract imports Foundation + ActivityKit only (it compiles in the widget extension too)"
        )
    }

    func test_appDeclaresLiveActivitySupport() throws {
        // ActivityKit reports `areActivitiesEnabled == false` forever without this key, with no
        // error anywhere — the mode would just never show a lock screen.
        let plist = try Data(
            contentsOf: repoRoot()
                .appendingPathComponent("workload management/workload-management-Info.plist")
        )
        let parsed = try PropertyListSerialization.propertyList(from: plist, format: nil)
        let dictionary = try XCTUnwrap(parsed as? [String: Any])
        XCTAssertEqual(
            dictionary["NSSupportsLiveActivities"] as? Bool, true,
            "The app's Info.plist must declare NSSupportsLiveActivities — without it ActivityKit silently refuses to start the guided session's activity"
        )
    }

    func test_widgetExtension_readsOnly() throws {
        // The app writes; the extension renders. A SwiftData or HealthKit import in the extension
        // means a second source of truth on the wrong side of the App Group boundary, and
        // `WidgetSnapshotWriter` in the extension means it started writing back.
        let root = repoRoot().appendingPathComponent("TuwaWidgets")
        let banned = ["import SwiftData", "import HealthKit", "WidgetSnapshotWriter"]
        var checked = 0
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            // Full-line comments are stripped, per `DesignSystemFenceTests` — a doc comment that
            // NAMES the writer (to say the app owns it) is documentation, not a dependency.
            let text = try String(contentsOf: url, encoding: .utf8)
                .components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            checked += 1
            for token in banned {
                XCTAssertFalse(
                    text.contains(token),
                    "\(url.lastPathComponent) references \(token) — the widget extension READS the App Group snapshot and renders activity state; it never writes and never touches a store"
                )
            }
        }
        XCTAssertGreaterThan(checked, 2, "Extension enumeration looks broken — TuwaWidgets/ should hold several Swift sources")
    }
}
