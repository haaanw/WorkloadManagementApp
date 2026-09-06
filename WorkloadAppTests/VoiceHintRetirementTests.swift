import XCTest
@testable import workload_management

/// v1.7.3 feature 6, batch 6 — the first-run voice coaching line retires permanently
/// after ~two weeks and never before its first sighting.
final class VoiceHintRetirementTests: XCTestCase {

    func test_neverSeen_isNotRetired() {
        XCTAssertFalse(VoiceHintRetirement.isRetired(firstSeenAt: nil, now: .now))
    }

    func test_withinTwoWeeks_staysActive() {
        let firstSeen = Calendar.current.date(byAdding: .day, value: -13, to: .now)!
        XCTAssertFalse(VoiceHintRetirement.isRetired(firstSeenAt: firstSeen, now: .now))
    }

    func test_afterTwoWeeks_retiresPermanently() {
        let firstSeen = Calendar.current.date(byAdding: .day, value: -15, to: .now)!
        XCTAssertTrue(VoiceHintRetirement.isRetired(firstSeenAt: firstSeen, now: .now))
    }

    func test_defaultsPath_stampsFirstSightingThenRetires() {
        let suiteName = "VoiceHintRetirementTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertFalse(VoiceHintRetirement.isRetired(defaults: defaults),
                       "first call stamps the sighting and reports active")
        XCTAssertNotNil(defaults.object(forKey: VoiceHintRetirement.firstSeenKey))

        let later = Calendar.current.date(byAdding: .day, value: 15, to: .now)!
        XCTAssertTrue(VoiceHintRetirement.isRetired(defaults: defaults, now: later))
    }
}
