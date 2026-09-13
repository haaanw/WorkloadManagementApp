import XCTest
import SwiftData
@testable import workload_management

/// v1.7.3 UAT round 2 · U12 — the weekly-review notification.
///
/// The defect HAN saw on the live 1.7.2 build was a FORMAT defect, not a copy one:
/// `NSString.localizedUserNotificationString(forKey:arguments:)` archives its arguments as
/// objects and substitutes `%@` only, so a catalog value written with `%1$lld` had its
/// positional prefix consumed and shipped the residual `$lld` verbatim. These tests pin the
/// catalog value, the rendering, the schema bump that purges the pending legacy requests,
/// and the freshness of the numbers those requests carry.
@MainActor
final class WeeklyNotificationTests: XCTestCase {

    // A TRANSIENT @MainActor object deallocating inside a synchronous test aborts the host in
    // `swift_task_deinitOnExecutorMainActorBackDeploy` (the documented trap, C-wdg-002 /
    // C-onb-005). Each of these is held for the life of the process and used by exactly one
    // test, so nothing here is ever deinitialised on a sync path.
    private static let migrationService = NotificationService()
    private static let routeDelegateAttached = NotificationRouteDelegate()
    private static let routeDelegateBuffered = NotificationRouteDelegate()
    private static let routeDelegateUnknown = NotificationRouteDelegate()
    private static let routerAttached = TabRouter()
    private static let routerBuffered = TabRouter()
    private static let routerUnknown = TabRouter()

    // MARK: - Catalog + rendering

    private func templateValue(locale: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // WorkloadAppTests
            .deletingLastPathComponent()   // repo root
        let url = root
            .appendingPathComponent("WorkloadApp/Resources/Localizable.xcstrings")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        let strings = (json as? [String: Any])?["strings"] as? [String: Any]
        let entry = strings?["notif.weekly.body.template"] as? [String: Any]
        let localizations = entry?["localizations"] as? [String: Any]
        let unit = (localizations?[locale] as? [String: Any])?["stringUnit"] as? [String: Any]
        return try XCTUnwrap(unit?["value"] as? String, "no \(locale) value for the weekly body")
    }

    func test_template_usesObjectSpecifiers_inBothLocales() throws {
        for locale in ["en", "zh-Hans"] {
            let value = try templateValue(locale: locale)
            XCTAssertFalse(
                value.contains("lld"),
                "\(locale): an integer specifier here ships raw '$lld' to the lock screen"
            )
            for index in 1...4 {
                XCTAssertTrue(
                    value.contains("%\(index)$@"),
                    "\(locale): positional argument \(index) must be an object specifier"
                )
            }
            XCTAssertTrue(value.contains("%%"), "\(locale): the literal percent sign survives")
        }
    }

    func test_renderedBody_carriesTheNumbersAndNoResidualSpecifier() throws {
        for locale in ["en", "zh-Hans"] {
            let template = try templateValue(locale: locale)
            // Exactly what NotificationService now hands the notification centre.
            let body = String(format: template, "4", "3", "2", "11")
            XCTAssertFalse(body.contains("$lld"), "\(locale): rendered body still shows a specifier")
            XCTAssertFalse(body.contains("$@"), "\(locale): rendered body still shows a specifier")
            XCTAssertEqual(
                body.filter { $0 == "%" }.count, 1,
                "\(locale): '%%' renders as exactly one percent sign in \(body)"
            )
            for number in ["4", "3", "2", "11"] {
                XCTAssertTrue(body.contains(number), "\(locale): '\(number)' is missing from \(body)")
            }
        }
    }

    func test_integerArguments_wouldHaveShippedTheDefect() throws {
        // The regression this class exists for, reproduced against the OLD value so the fix
        // is pinned by a demonstrated failure mode rather than by assertion alone.
        let legacy = "%1$lld sessions logged — %2$lld week streak."
        let rendered = NSString.localizedUserNotificationString(forKey: legacy, arguments: [4, 3])
        XCTAssertTrue(
            rendered.contains("$lld"),
            "if this ever stops holding, iOS changed the archiving rule — re-read U12"
        )
    }

    // MARK: - Schema version

    func test_schemaVersion_isBumpedPastTheBrokenFormat() {
        XCTAssertGreaterThanOrEqual(
            NotificationService.currentSchemaVersion, 3,
            "the pending requests scheduled by 1.7.2 must be cancelled and reissued"
        )
    }

    func test_migration_isIdempotentAndStampsTheStoredVersion() {
        let key = "notificationSchemaVersion"
        let previous = UserDefaults.standard.object(forKey: key)
        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        UserDefaults.standard.set(2, forKey: key)
        let service = Self.migrationService
        service.migrateWeeklySummaryIfNeeded()
        XCTAssertEqual(
            UserDefaults.standard.integer(forKey: key),
            NotificationService.currentSchemaVersion
        )
        // Second call reads version == current and no-ops.
        service.migrateWeeklySummaryIfNeeded()
        XCTAssertEqual(
            UserDefaults.standard.integer(forKey: key),
            NotificationService.currentSchemaVersion
        )
    }

    // MARK: - Tap route

    func test_weeklyRoute_isRecordedOnTheRouterAndSelectsToday() {
        let router = Self.routerAttached
        router.selection = .profile
        let delegate = Self.routeDelegateAttached
        delegate.attach(router: router)

        delegate.apply(NotificationService.weeklySummaryRoute)

        XCTAssertEqual(router.selection, .home)
        XCTAssertEqual(router.pendingAnchor, NotificationService.weeklySummaryRoute)
    }

    func test_routeArrivingBeforeTheShell_isBufferedNotDropped() {
        // A cold-launch tap is delivered before any scene builds the tab shell.
        let delegate = Self.routeDelegateBuffered
        delegate.apply(NotificationService.weeklySummaryRoute)

        let router = Self.routerBuffered
        XCTAssertNil(router.pendingAnchor)
        delegate.attach(router: router)

        XCTAssertEqual(router.pendingAnchor, NotificationService.weeklySummaryRoute)
    }

    func test_unknownRoute_changesNothing() {
        let router = Self.routerUnknown
        router.selection = .trends
        let delegate = Self.routeDelegateUnknown
        delegate.attach(router: router)

        delegate.apply("someFutureRoute")

        XCTAssertEqual(router.selection, .trends)
        XCTAssertNil(router.pendingAnchor)
    }

    // MARK: - Freshness (the repeating trigger carries these forever)

    func test_weeklyNumbers_readTheAthletesRealWeek() throws {
        let schema = Schema([
            Athlete.self, WorkoutSession.self, ExerciseEntry.self, SetRecord.self,
            PersonalRecord.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let athlete = Athlete(displayName: "A", sportType: .lifting)
        context.insert(athlete)

        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let calendar = Calendar.current

        func session(daysAgo: Int, volume: Double) {
            let session = WorkoutSession(
                sessionDate: calendar.date(byAdding: .day, value: -daysAgo, to: now)!,
                sportType: .lifting
            )
            session.totalVolume = volume
            session.athlete = athlete
            context.insert(session)
        }

        session(daysAgo: 1, volume: 1000)
        session(daysAgo: 3, volume: 1000)
        session(daysAgo: 9, volume: 1000)   // previous week

        let record = PersonalRecord(
            exerciseName: "Back Squat", recordType: .maxWeight, value: 140,
            achievedAt: calendar.date(byAdding: .day, value: -2, to: now)!
        )
        context.insert(record)
        try context.save()

        let numbers = WeeklyNotificationNumbers.compute(
            modelContext: context, athleteId: athlete.id, now: now, calendar: calendar
        )

        XCTAssertEqual(numbers.sessionCount, 2, "this week's sessions, not zero")
        XCTAssertEqual(numbers.prCount, 1)
        XCTAssertGreaterThan(numbers.streak, 0)
        XCTAssertEqual(numbers.volumeDelta, 100, accuracy: 0.001, "2000 vs 1000 is +100%")
    }

    func test_weeklyNumbers_areZeroWithoutAnAthlete() {
        let numbers = WeeklyNotificationNumbers.compute(
            modelContext: ModelContext(try! ModelContainer(
                for: Schema([Athlete.self]),
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )),
            athleteId: nil
        )
        XCTAssertEqual(numbers.sessionCount, 0)
        XCTAssertEqual(numbers.streak, 0)
        XCTAssertEqual(numbers.prCount, 0)
        XCTAssertEqual(numbers.volumeDelta, 0)
    }

    func test_volumeDelta_isZeroWhenThereIsNoPreviousWeek() {
        XCTAssertEqual(WeeklyNotificationNumbers.volumeDelta(current: 5000, previous: 0), 0)
        XCTAssertEqual(WeeklyNotificationNumbers.volumeDelta(current: 0, previous: 1000), -100)
    }
}
