import XCTest
@testable import workload_management

/// v1.7.2 codebase audit — the athlete/profile half of `SyncService`.
///
/// Three findings from `.planning/v171-hotfix/AUDIT-2026-08-05.md` are pinned here:
///
/// - **M1** — the athlete pull restored 4 of the 11 fields the push sends, so a new
///   device silently came up on default units, ACWR method, load metric, sport, max HR
///   and date of birth. `SyncService.apply(_:to:)` is now the single seam and it must
///   carry every pushed field.
/// - **H7** — `bootstrapAthlete` returned `Athlete?`, collapsing "this account owns no
///   profile" and "the request never reached the server" into one `nil`. Source fences
///   below hold the three-way outcome and its two dangerous call sites.
/// - **M6** — `DateOnly` cached a `DateFormatter` whose time zone was resolved once, at
///   first use, so a device that changed zone kept encoding the stale calendar day.
@MainActor
final class AthleteSyncFidelityTests: XCTestCase {

    // MARK: - M1: every pushed field comes back

    /// A fully-populated server row must restore every field `pushAthlete` sends.
    func testPullRestoresEveryPushedAthleteField() throws {
        let athlete = Athlete(displayName: "Local", sportType: .lifting)
        athlete.weightUnit = .kg
        athlete.acwrMethod = .rolling28day
        athlete.loadMetricPreference = .srpe
        athlete.maxHeartRate = nil
        athlete.dateOfBirth = nil

        let birthday = Calendar.current.date(from: DateComponents(year: 1994, month: 3, day: 7))!
        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        let row = AthleteRow(
            id: athlete.id,
            userId: UUID(),
            displayName: "Server Name",
            sportType: SportType.teamSport.rawValue,
            weightUnit: WeightUnit.lbs.rawValue,
            acwrMethod: ACWRMethod.ewma.rawValue,
            loadMetricPreference: LoadSource.trimp.rawValue,
            maxHeartRate: 192,
            dateOfBirth: DateOnly(birthday),
            isCoach: true,
            trainingFrequency: TrainingFrequency.fiveToSix.rawValue,
            experienceLevel: ExperienceLevel.advanced.rawValue,
            createdAt: stamp,
            updatedAt: stamp
        )

        SyncService.apply(row, to: athlete)

        XCTAssertEqual(athlete.displayName, "Server Name")
        XCTAssertEqual(athlete.sportType, .teamSport)
        XCTAssertEqual(athlete.weightUnit, .lbs, "weightUnit was write-only before audit M1")
        XCTAssertEqual(athlete.acwrMethod, .ewma, "acwrMethod was write-only before audit M1")
        XCTAssertEqual(athlete.loadMetricPreference, .trimp,
                       "loadMetricPreference was write-only before audit M1")
        XCTAssertEqual(athlete.maxHeartRate, 192, "maxHeartRate was write-only before audit M1")
        XCTAssertEqual(athlete.dateOfBirth, DateOnly(birthday).date,
                       "dateOfBirth was write-only before audit M1")
        XCTAssertTrue(athlete.isCoach)
        XCTAssertEqual(athlete.trainingFrequency, .fiveToSix)
        XCTAssertEqual(athlete.experienceLevel, .advanced)
        XCTAssertEqual(athlete.updatedAt, stamp)
    }

    /// A nil column means ABSENT — a server that has not grown the column yet must not
    /// wipe a value the athlete already chose on this device.
    func testNilServerFieldsDoNotClearLocalValues() {
        let athlete = Athlete(displayName: "Local", sportType: .teamSport)
        athlete.weightUnit = .lbs
        athlete.acwrMethod = .ewma
        athlete.loadMetricPreference = .trimp
        athlete.maxHeartRate = 188
        athlete.dateOfBirth = Date(timeIntervalSince1970: 0)
        athlete.trainingFrequency = .sevenPlus
        athlete.experienceLevel = .intermediate

        let row = AthleteRow(
            id: athlete.id,
            userId: UUID(),
            displayName: nil,
            sportType: nil,
            weightUnit: nil,
            acwrMethod: nil,
            loadMetricPreference: nil,
            maxHeartRate: nil,
            dateOfBirth: nil,
            isCoach: nil,
            trainingFrequency: nil,
            experienceLevel: nil,
            createdAt: .now,
            updatedAt: .now
        )

        SyncService.apply(row, to: athlete)

        XCTAssertEqual(athlete.displayName, "Local")
        XCTAssertEqual(athlete.sportType, .teamSport)
        XCTAssertEqual(athlete.weightUnit, .lbs)
        XCTAssertEqual(athlete.acwrMethod, .ewma)
        XCTAssertEqual(athlete.loadMetricPreference, .trimp)
        XCTAssertEqual(athlete.maxHeartRate, 188)
        XCTAssertEqual(athlete.dateOfBirth, Date(timeIntervalSince1970: 0))
        XCTAssertEqual(athlete.trainingFrequency, .sevenPlus)
        XCTAssertEqual(athlete.experienceLevel, .intermediate)
    }

    /// An unparseable enum raw value (an older client, a hand-edited row) is ignored
    /// rather than nilling the local setting.
    func testUnknownEnumRawValuesAreIgnored() {
        let athlete = Athlete(displayName: "Local", sportType: .teamSport)
        athlete.trainingFrequency = .sevenPlus

        let row = AthleteRow(
            id: athlete.id,
            userId: UUID(),
            displayName: "Local",
            sportType: "teleportation",
            weightUnit: "stones",
            acwrMethod: nil,
            loadMetricPreference: nil,
            maxHeartRate: nil,
            dateOfBirth: nil,
            isCoach: nil,
            trainingFrequency: "hourly",
            experienceLevel: nil,
            createdAt: .now,
            updatedAt: .now
        )

        SyncService.apply(row, to: athlete)

        XCTAssertEqual(athlete.sportType, .teamSport)
        XCTAssertEqual(athlete.weightUnit, .kg)
        XCTAssertEqual(athlete.trainingFrequency, .sevenPlus)
    }

    // MARK: - M6: the date codec follows the device's time zone

    /// The same instant is a different calendar day on either side of the date line. The
    /// cached-formatter defect produced the SAME string in both zones, so every snapshot
    /// written after a flight landed on the departure zone's day.
    func testCalendarDayFollowsTheZoneItIsGiven() {
        // 2026-08-21 22:00 UTC — already the 22nd in Tokyo, still the 21st in Los Angeles.
        let instant = Date(timeIntervalSince1970: 1_787_349_600)
        let tokyo = TimeZone(identifier: "Asia/Tokyo")!
        let losAngeles = TimeZone(identifier: "America/Los_Angeles")!

        XCTAssertEqual(CalendarDay.string(from: instant, in: tokyo), "2026-08-22")
        XCTAssertEqual(CalendarDay.string(from: instant, in: losAngeles), "2026-08-21")
        XCTAssertNotEqual(
            CalendarDay.startOfDay(for: instant, in: tokyo),
            CalendarDay.startOfDay(for: instant, in: losAngeles)
        )
    }

    /// A DST spring-forward day still starts at its own local midnight, and the string is
    /// still that day.
    func testCalendarDaySurvivesADSTTransition() {
        let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
        // 2026-03-08 is the US spring-forward day; 10:00 local is after the skipped hour.
        let duringDST = CalendarDay.date(from: "2026-03-08", in: losAngeles)
        XCTAssertNotNil(duringDST)
        XCTAssertEqual(CalendarDay.string(from: duringDST!, in: losAngeles), "2026-03-08")
    }

    /// A non-Gregorian locale calendar must not reach the wire format: `Calendar.current`
    /// under a Buddhist locale numbers 2026 as 2569.
    func testCalendarDayIsGregorianRegardlessOfLocale() {
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = TimeZone(identifier: "Asia/Bangkok")!
        let instant = Date(timeIntervalSince1970: 1_787_349_600)

        let buddhistYear = buddhist.dateComponents([.year], from: instant).year
        XCTAssertNotEqual(buddhistYear, 2026, "Precondition: the Buddhist calendar renumbers the year")
        XCTAssertTrue(
            CalendarDay.string(from: instant, in: TimeZone(identifier: "Asia/Bangkok")!)
                .hasPrefix("2026-")
        )
    }

    func testDateOnlyRoundTripsTheLocalCalendarDay() throws {
        let noon = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 21, hour: 12))!
        let encoded = try JSONEncoder().encode(DateOnly(noon))
        XCTAssertEqual(String(data: encoded, encoding: .utf8), "\"2026-08-21\"")

        let decoded = try JSONDecoder().decode(DateOnly.self, from: encoded)
        XCTAssertEqual(decoded.date, Calendar.current.startOfDay(for: noon))
    }

    /// M6 fence. The codec must resolve the zone at call time; a stored formatter or a
    /// stored calendar is what froze the offset in the first place.
    func testDateOnlyHoldsNoCachedFormatter() {
        let source = readSource("WorkloadApp/Services/SyncService.swift")
        XCTAssertFalse(source.isEmpty)
        XCTAssertFalse(
            source.contains("= DateFormatter()"),
            "SyncService builds a DateFormatter again — its time zone freezes at first use (audit M6)"
        )
        XCTAssertTrue(
            source.contains("CalendarDay.startOfDay(for: date, in: .current)"),
            "DateOnly no longer reads TimeZone.current per call (audit M6)"
        )
    }

    /// PostgREST may serve a timestamptz string if a column is ever migrated; the codec
    /// keeps tolerating the leading date part.
    func testDateOnlyTolerantOfATimestampString() throws {
        let decoded = try JSONDecoder().decode(
            DateOnly.self,
            from: Data("\"2026-08-21T13:45:00+00:00\"".utf8)
        )
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: decoded.date)
        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 8)
        XCTAssertEqual(parts.day, 21)
    }

    func testDateOnlyRejectsGarbage() {
        XCTAssertThrowsError(
            try JSONDecoder().decode(DateOnly.self, from: Data("\"not-a-date\"".utf8))
        )
    }

    // MARK: - Source fences

    private func readSource(_ relativePath: String, file: StaticString = #filePath) -> String {
        let root = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent()   // WorkloadAppTests/
            .deletingLastPathComponent()   // <repo root>
        let url = root.appendingPathComponent(relativePath)
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("Fence could not resolve source at \(url.path)")
            return ""
        }
        return contents
    }

    /// H7. `.single()` reports zero rows as the error PGRST116, which is exactly the
    /// ambiguity the bootstrap must not have. Every athlete/profile read decodes an array.
    func testNoSingleRowSelectsRemainInSyncService() {
        let code = strippingComments(readSource("WorkloadApp/Services/SyncService.swift"))
        XCTAssertFalse(code.isEmpty)
        XCTAssertFalse(
            code.contains(".single()"),
            "A `.single()` select is back in SyncService — zero rows would decode as a transport failure (audit H4/H7)"
        )
    }

    /// Line comments only — enough for these fences, and it keeps a comment that NAMES the
    /// banned call (they all do, deliberately) from tripping the fence that bans it.
    private func strippingComments(_ source: String) -> String {
        source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let slashes = line.range(of: "//") else { return line }
                return line[..<slashes.lowerBound]
            }
            .joined(separator: "\n")
    }

    /// H7. The router may sign out only on a genuine `notFound`. A failed request tells us
    /// nothing about whether the account owns a profile, and destroying the Keychain
    /// session over a dropped connection is the zombie sign-out.
    func testRouterSignsOutOnlyOnGenuineNotFound() {
        let source = readSource("WorkloadApp/App/AppRouter.swift")
        XCTAssertFalse(source.isEmpty)

        guard let bootstrapRange = source.range(of: "syncService.bootstrapAthlete") else {
            return XCTFail("AppRouter no longer bootstraps the athlete — re-point this fence")
        }
        let tail = source[bootstrapRange.upperBound...]
        guard let notFound = tail.range(of: "case .notFound:"),
              let failed = tail.range(of: "case .failed:") else {
            return XCTFail("AppRouter does not branch on the three bootstrap outcomes (audit H7)")
        }
        XCTAssertTrue(
            notFound.lowerBound < failed.lowerBound,
            "Expected .notFound to be handled before .failed"
        )
        let failureBranch = tail[failed.upperBound...]
        let branchEnd = failureBranch.range(of: "}")?.lowerBound ?? failureBranch.endIndex
        XCTAssertFalse(
            failureBranch[..<branchEnd].contains("signOut"),
            "A transport failure signs the athlete out — the zombie sign-out is back (audit H7)"
        )
    }

    /// H7. Neither social sign-in may fabricate a profile after a failed lookup: Apple
    /// supplies `fullName` only on the first authorization, so the fabricated athlete is
    /// named "Athlete" and the push writes it over the real server row.
    func testSocialSignInCreatesAProfileOnlyOnNotFound() {
        for path in ["WorkloadApp/Views/Auth/LoginView.swift",
                     "WorkloadApp/Views/Auth/SignUpView.swift"] {
            let source = readSource(path)
            XCTAssertFalse(source.isEmpty)
            XCTAssertFalse(
                source.contains("if existingAthlete == nil"),
                "\(path) still treats a nil bootstrap as 'new user' — a transport failure fabricates a profile (audit H7)"
            )
            XCTAssertTrue(
                source.contains("case .notFound:"),
                "\(path) does not branch on the bootstrap outcome (audit H7)"
            )
        }
    }

    /// M4. `training_profiles` is keyed UNIQUE(athlete_id) while every device mints its
    /// own primary key, so a default upsert from a second device is an INSERT that trips
    /// 23505 and paints the row permanently red.
    func testTrainingProfileUpsertConflictsOnAthleteId() {
        let source = readSource("WorkloadApp/Services/SyncService.swift")
        XCTAssertFalse(source.isEmpty)
        XCTAssertTrue(
            source.contains("""
            .upsert(row, onConflict: "athlete_id")
            """),
            "The training_profiles upsert lost its athlete_id conflict target (audit M4)"
        )
    }
}
