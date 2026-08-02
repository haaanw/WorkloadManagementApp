import XCTest
import SwiftData
@testable import workload_management

/// Sleep v2 Phase S3 — the shadow dual-run instrumentation.
///
/// Covers: (1) the `SleepShadowNight` §6 record round-trip; (2) the sync-omission grep fence;
/// (3) the H-39 morning/evening join windows (`RecoveryPipeline.runSleepShadowJoins`) and the
/// H-38 sleep-free proxy; (4) the H-33-closing pass-throughs (priorWakeZ / naps / prior-day
/// z's); (5) the §6 falsification criteria on synthetic datasets constructed to pass and to
/// fail. In-memory SwiftData; fetch patterns avoid optional-relationship `#Predicate`s (the
/// documented iOS 26.1 in-memory trap).
@MainActor
final class SleepShadowTests: XCTestCase {

    private typealias Builder = SleepStateBuilder
    private typealias Analysis = SleepShadowAnalysis

    // MARK: - Scaffolding

    /// Fixed UTC gregorian calendar (the SleepStateBuilderTests precedent).
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private var day0: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 1
        components.timeZone = TimeZone(identifier: "UTC")
        return calendar.date(from: components)!
    }

    private func day(_ index: Int) -> Date {
        calendar.date(byAdding: .day, value: index, to: day0)!
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Athlete.self, WorkoutSession.self, ExerciseEntry.self, SetRecord.self,
            WorkloadSnapshot.self, RecoverySnapshot.self, MenstrualCycleSnapshot.self,
            CyclePredictionLog.self, ShadowArmPrediction.self, SorenessLog.self,
            VerdictEvent.self, BaselineState.self, SleepShadowNight.self,
            WellnessCheckIn.self, PersonalRecord.self, CoachAthleteRelationship.self,
            WorkoutTemplate.self, ExerciseGroup.self, TemplateExercise.self, TemplateSet.self,
            PrescribedWorkout.self, CustomExercise.self, BehaviorTag.self, TrainingProfile.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func makeAthlete(_ context: ModelContext) -> Athlete {
        let athlete = Athlete(displayName: "S3 Tester")
        context.insert(athlete)
        return athlete
    }

    /// A minimal stored night for join tests: an 8-h session ending 07:00 on `wakeDay`.
    @discardableResult
    private func insertRow(
        _ context: ModelContext,
        athlete: Athlete,
        wakeDayIndex: Int
    ) -> SleepShadowNight {
        let wakeDay = day(wakeDayIndex)
        let end = wakeDay.addingTimeInterval(7 * 3600)
        let row = SleepShadowNight(
            wakeDate: wakeDay,
            sourceBundleID: "com.apple.health",
            tstMinutes: 450,
            sessionStart: end.addingTimeInterval(-8 * 3600),
            sessionEnd: end,
            tierRaw: "A",
            athlete: athlete
        )
        context.insert(row)
        return row
    }

    private func fetchRows(_ context: ModelContext) throws -> [SleepShadowNight] {
        try context.fetch(FetchDescriptor<SleepShadowNight>())
            .sorted { $0.wakeDate < $1.wakeDate }
    }

    // MARK: - 1. §6 record round-trip

    func test_record_roundTrip_fieldsLandWhereSection6NamesThem() throws {
        let context = try makeContext()
        let athlete = makeAthlete(context)
        let wakeDay = day(10)
        let start = wakeDay.addingTimeInterval(-3600)
        let end = wakeDay.addingTimeInterval(7 * 3600)

        let row = SleepShadowNight(
            wakeDate: wakeDay,
            sourceBundleID: "com.ouraring.oura",
            tstMinutes: 431,
            deepMinutes: 62,
            remMinutes: 88,
            coreMinutes: 281,
            wasoMinutes: 24,
            inBedMinutes: 470,
            sessionStart: start,
            sessionEnd: end,
            tierRaw: "A",
            componentDuration: 92,
            componentContinuity: 84,
            componentRegularity: 80,
            componentDeep: 81,
            componentRem: 79,
            pointsContinuity: 8,
            pointsRegularity: 5,
            pointsDeep: 3.5,
            pointsRem: 3.5,
            needBaseMinutes: 452,
            needTonightMinutes: 470,
            creditPressureMinutes: 12,
            creditStrainMinutes: 6,
            creditDebtMinutes: 9,
            creditNapDebitMinutes: 15,
            creditAppliedMinutes: 12,
            activeProfilesRaw: ["HIGH_PRESSURE", "DEBT_CARRY"],
            latchedProfilesRaw: ["DEBT_CARRY", "HIGH_PRESSURE"],
            v2Score: 78.4,
            confidence: 0.75,
            v1SleepMinutes: 445,
            v1SleepComponentScore: RecoveryScoreEngine.sleepDurationToScore(445),
            midpointSD14Minutes: 41,
            midpointDeviationMinutes: -13,
            priorWakeHours: 16.5,
            priorWakeZ: 1.1,
            priorDayLoadZ: 0.4,
            priorDayActiveEnergyZ: 1.3,
            napMinutes: 30,
            sleepDebt7Minutes: 95,
            deepQ: 1.05,
            remQ: 0.93,
            athlete: athlete
        )
        // Join fields are pipeline-written, not init parameters.
        row.nextMorningHRV = 61
        row.nextMorningRHR = 47
        row.nextMorningWellness = 85
        row.sleepFreeReadiness = 72.5
        row.morningJoinedAt = day(11)
        row.eveningSessionRPE = 8
        row.eveningFeltRightRaw = "right"
        row.eveningVerdictIssued = true
        row.eveningJoinedAt = day(12)
        context.insert(row)
        try context.save()

        let fetched = try XCTUnwrap(fetchRows(context).first)
        // §6: source bundle id, TST, stage minutes, WASO, inBed, start/end.
        XCTAssertEqual(fetched.wakeDate, wakeDay)
        XCTAssertEqual(fetched.sourceBundleID, "com.ouraring.oura")
        XCTAssertEqual(fetched.tstMinutes, 431)
        XCTAssertEqual(fetched.deepMinutes, 62)
        XCTAssertEqual(fetched.remMinutes, 88)
        XCTAssertEqual(fetched.coreMinutes, 281)
        XCTAssertEqual(fetched.wasoMinutes, 24)
        XCTAssertEqual(fetched.inBedMinutes, 470)
        XCTAssertEqual(fetched.sessionStart, start)
        XCTAssertEqual(fetched.sessionEnd, end)
        // §6: tier, each component score and weight (points), need_base/need_tonight with
        // their credits, v1 score, v2 score, confidence.
        XCTAssertEqual(fetched.tierRaw, "A")
        XCTAssertEqual(fetched.componentDuration, 92)
        XCTAssertEqual(fetched.componentContinuity, 84)
        XCTAssertEqual(fetched.componentRegularity, 80)
        XCTAssertEqual(fetched.componentDeep, 81)
        XCTAssertEqual(fetched.componentRem, 79)
        XCTAssertEqual(fetched.pointsContinuity, 8)
        XCTAssertEqual(fetched.pointsRegularity, 5)
        XCTAssertEqual(fetched.pointsDeep, 3.5)
        XCTAssertEqual(fetched.pointsRem, 3.5)
        XCTAssertEqual(fetched.needBaseMinutes, 452)
        XCTAssertEqual(fetched.needTonightMinutes, 470)
        XCTAssertEqual(fetched.creditPressureMinutes, 12)
        XCTAssertEqual(fetched.creditStrainMinutes, 6)
        XCTAssertEqual(fetched.creditDebtMinutes, 9)
        XCTAssertEqual(fetched.creditNapDebitMinutes, 15)
        XCTAssertEqual(fetched.creditAppliedMinutes, 12)
        XCTAssertEqual(fetched.activeProfilesRaw, ["HIGH_PRESSURE", "DEBT_CARRY"])
        XCTAssertEqual(fetched.latchedProfilesRaw, ["DEBT_CARRY", "HIGH_PRESSURE"])
        XCTAssertEqual(fetched.v2Score, 78.4)
        XCTAssertEqual(fetched.confidence, 0.75)
        XCTAssertEqual(fetched.v1SleepMinutes, 445)
        XCTAssertEqual(
            fetched.v1SleepComponentScore,
            RecoveryScoreEngine.sleepDurationToScore(445)
        )
        // State-vector audit + q's.
        XCTAssertEqual(fetched.midpointSD14Minutes, 41)
        XCTAssertEqual(fetched.midpointDeviationMinutes, -13)
        XCTAssertEqual(fetched.priorWakeHours, 16.5)
        XCTAssertEqual(fetched.priorWakeZ, 1.1)
        XCTAssertEqual(fetched.priorDayLoadZ, 0.4)
        XCTAssertEqual(fetched.priorDayActiveEnergyZ, 1.3)
        XCTAssertEqual(fetched.napMinutes, 30)
        XCTAssertEqual(fetched.sleepDebt7Minutes, 95)
        XCTAssertEqual(fetched.deepQ, 1.05)
        XCTAssertEqual(fetched.remQ, 0.93)
        // §6 joins: next morning + next evening.
        XCTAssertEqual(fetched.nextMorningHRV, 61)
        XCTAssertEqual(fetched.nextMorningRHR, 47)
        XCTAssertEqual(fetched.nextMorningWellness, 85)
        XCTAssertEqual(fetched.sleepFreeReadiness, 72.5)
        XCTAssertEqual(fetched.morningJoinedAt, day(11))
        XCTAssertEqual(fetched.eveningSessionRPE, 8)
        XCTAssertEqual(fetched.eveningFeltRightRaw, "right")
        XCTAssertEqual(fetched.eveningVerdictIssued, true)
        XCTAssertEqual(fetched.eveningJoinedAt, day(12))
        // H-33 boundary, persisted: rows record their pass-through wiring generation.
        XCTAssertEqual(fetched.schemaVersion, 2)
        XCTAssertEqual(fetched.athlete?.id, athlete.id)
    }

    // MARK: - 2. Local-only sync fence (privacy-by-omission)

    func test_syncFence_sleepShadowNightAbsentFromSyncService() throws {
        let thisFile = URL(fileURLWithPath: #filePath)
        let repoRoot = thisFile
            .deletingLastPathComponent()   // WorkloadAppTests
            .deletingLastPathComponent()   // repo root
        let syncURL = repoRoot
            .appendingPathComponent("WorkloadApp")
            .appendingPathComponent("Services")
            .appendingPathComponent("SyncService.swift")

        let contents = try String(contentsOf: syncURL, encoding: .utf8)
        XCTAssertFalse(
            contents.contains("SleepShadowNight"),
            "SleepShadowNight must NEVER appear in SyncService.swift (local-only by omission)."
        )
    }

    // MARK: - 3. Morning join (H-38 / H-39)

    func test_morningJoin_fillsYesterdayOnly_neverToday() throws {
        let context = try makeContext()
        let athlete = makeAthlete(context)
        let yesterday = 20
        let today = 21

        // Yesterday's persisted day: snapshot (morning) + wellness check-in (evening).
        let snapshot = RecoverySnapshot(
            date: day(yesterday).addingTimeInterval(8 * 3600),
            hrvSDNN: 60,
            restingHR: 50,
            sleepDurationMinutes: 430,
            recoveryScore: 71,
            hrvBaseline: 55,
            restingHRBaseline: 52
        )
        snapshot.athlete = athlete
        context.insert(snapshot)
        let checkIn = WellnessCheckIn(
            date: day(yesterday).addingTimeInterval(20 * 3600),
            sleepQuality: 4, soreness: 4, energy: 4, stress: 4  // wellnessScore 80
        )
        checkIn.athlete = athlete
        context.insert(checkIn)

        let yesterdayRow = insertRow(context, athlete: athlete, wakeDayIndex: yesterday)
        let todayRow = insertRow(context, athlete: athlete, wakeDayIndex: today)
        try context.save()

        RecoveryPipeline.runSleepShadowJoins(
            athlete: athlete,
            modelContext: context,
            now: day(today).addingTimeInterval(9 * 3600),
            calendar: calendar
        )

        // Yesterday's row: joined with YESTERDAY's persisted values.
        XCTAssertNotNil(yesterdayRow.morningJoinedAt)
        XCTAssertEqual(yesterdayRow.nextMorningHRV, 60)
        XCTAssertEqual(yesterdayRow.nextMorningRHR, 50)
        XCTAssertEqual(yesterdayRow.nextMorningWellness, 80)
        // H-38 (revised): sleep omitted, weights renormalized, trend zeroed, and the
        // wellness arm rebuilt WITHOUT sleepQuality — (soreness 4 + energy 4 + stress 4)
        // / 15 × 100 = 80 ⇒ exactly the engine's baseScore over the sleep-free input.
        let sleepFreeWellness = Double(4 + 4 + 4) / 15.0 * 100.0
        let expected = RecoveryScoreEngine.compute(
            input: RecoveryScoreEngine.RecoveryInput(
                hrvSDNN: 60,
                restingHR: 50,
                sleepDurationMinutes: nil,
                wellnessScore: sleepFreeWellness,
                hrvBaseline: 55,
                restingHRBaseline: 52,
                recentScores: []
            )
        ).baseScore
        XCTAssertEqual(try XCTUnwrap(yesterdayRow.sleepFreeReadiness), expected, accuracy: 1e-9)

        // Today's row: NEVER joined while its day is still in progress.
        XCTAssertNil(todayRow.morningJoinedAt)
        XCTAssertNil(todayRow.nextMorningHRV)
        XCTAssertNil(todayRow.nextMorningRHR)
        XCTAssertNil(todayRow.nextMorningWellness)
        XCTAssertNil(todayRow.sleepFreeReadiness)
    }

    func test_morningJoin_noData_stampsJoined_neverFabricatesNeutral50() throws {
        let context = try makeContext()
        let athlete = makeAthlete(context)
        let row = insertRow(context, athlete: athlete, wakeDayIndex: 20)
        try context.save()

        RecoveryPipeline.runSleepShadowJoins(
            athlete: athlete,
            modelContext: context,
            now: day(21).addingTimeInterval(9 * 3600),
            calendar: calendar
        )

        XCTAssertNotNil(row.morningJoinedAt, "A data-less day must still stamp (no re-scan forever)")
        XCTAssertNil(row.nextMorningHRV)
        XCTAssertNil(row.sleepFreeReadiness, "No component ⇒ nil, never the engine's neutral 50")
    }

    /// M1 / H-38 revision: the "sleep-free" proxy must contain NO sleepQuality. Two wake
    /// days identical in every respect except the check-in's sleepQuality (1 vs 5) must
    /// produce IDENTICAL proxy values — under the pre-fix composite leak the wellness-only
    /// proxy would differ by 20 points. The audit field keeps the composite (and differs).
    func test_morningJoin_proxyIdentical_whenOnlySleepQualityDiffers() throws {
        func proxyAndWellness(sleepQuality: Int) throws -> (proxy: Double, wellness: Double) {
            let context = try makeContext()
            let athlete = makeAthlete(context)
            let checkIn = WellnessCheckIn(
                date: day(20).addingTimeInterval(20 * 3600),
                sleepQuality: sleepQuality, soreness: 4, energy: 3, stress: 2
            )
            checkIn.athlete = athlete
            context.insert(checkIn)
            let row = insertRow(context, athlete: athlete, wakeDayIndex: 20)
            try context.save()
            RecoveryPipeline.runSleepShadowJoins(
                athlete: athlete,
                modelContext: context,
                now: day(21).addingTimeInterval(9 * 3600),
                calendar: calendar
            )
            return (
                proxy: try XCTUnwrap(row.sleepFreeReadiness),
                wellness: try XCTUnwrap(row.nextMorningWellness)
            )
        }

        let rated1 = try proxyAndWellness(sleepQuality: 1)
        let rated5 = try proxyAndWellness(sleepQuality: 5)
        XCTAssertEqual(
            rated1.proxy, rated5.proxy, accuracy: 1e-12,
            "sleepQuality must not move the sleep-free proxy"
        )
        // The proxy equals the sleep-free reconstruction (soreness+energy+stress → 0–100).
        XCTAssertEqual(rated1.proxy, Double(4 + 3 + 2) / 15.0 * 100.0, accuracy: 1e-9)
        // The AUDIT composite still reflects the rating difference (it is not the proxy).
        XCTAssertEqual(rated5.wellness - rated1.wellness, 20.0, accuracy: 1e-9)
    }

    // MARK: - 4. Evening join (H-39)

    func test_eveningJoin_waitsForFeltRightWindow_thenJoinsRPEFeltRightVerdict() throws {
        let context = try makeContext()
        let athlete = makeAthlete(context)
        let dayMinus2 = 20
        let dayMinus1 = 21
        let today = 22

        // Wake day D−2: two sessions (higher-TSS one carries the day's RPE) + a verdict
        // whose felt-right was reported the next day.
        let main = WorkoutSession(
            sessionDate: day(dayMinus2).addingTimeInterval(17 * 3600),
            sessionRPE: 8
        )
        main.trainingStress = 100
        main.athlete = athlete
        context.insert(main)
        let secondary = WorkoutSession(
            sessionDate: day(dayMinus2).addingTimeInterval(10 * 3600),
            sessionRPE: 6
        )
        secondary.trainingStress = 40
        secondary.athlete = athlete
        context.insert(secondary)
        let verdict = VerdictEvent(
            planDate: day(dayMinus2),
            verdictKindRaw: "modify",
            plannedTopSetKg: 100,
            actionRaw: "accepted",
            regionRaw: "legs",
            reasonLine: "test",
            feltRightRaw: "right",
            athlete: athlete
        )
        // VerdictEvent's init normalizes planDate with Calendar.current (the machine's
        // LOCAL timezone); pin it to the test's UTC wake day so the date-window join is
        // deterministic on any host timezone.
        verdict.planDate = day(dayMinus2)
        context.insert(verdict)

        let rowMinus3 = insertRow(context, athlete: athlete, wakeDayIndex: 19)  // no events
        let rowMinus2 = insertRow(context, athlete: athlete, wakeDayIndex: dayMinus2)
        let rowMinus1 = insertRow(context, athlete: athlete, wakeDayIndex: dayMinus1)
        try context.save()

        RecoveryPipeline.runSleepShadowJoins(
            athlete: athlete,
            modelContext: context,
            now: day(today).addingTimeInterval(9 * 3600),
            calendar: calendar
        )

        // D−2: the felt-right window (D−1) has closed ⇒ joined.
        XCTAssertNotNil(rowMinus2.eveningJoinedAt)
        XCTAssertEqual(rowMinus2.eveningSessionRPE, 8, "Highest-trainingStress session's RPE")
        XCTAssertEqual(rowMinus2.eveningFeltRightRaw, "right")
        XCTAssertEqual(rowMinus2.eveningVerdictIssued, true)

        // D−3 with no events: joined, explicit false / nils — absence is the record.
        XCTAssertNotNil(rowMinus3.eveningJoinedAt)
        XCTAssertNil(rowMinus3.eveningSessionRPE)
        XCTAssertNil(rowMinus3.eveningFeltRightRaw)
        XCTAssertEqual(rowMinus3.eveningVerdictIssued, false)

        // D−1: felt-right is write-once on D (today) — the window has NOT closed.
        XCTAssertNil(rowMinus1.eveningJoinedAt)
        XCTAssertNil(rowMinus1.eveningVerdictIssued)
        // Its MORNING join, though, is due (wake day elapsed).
        XCTAssertNotNil(rowMinus1.morningJoinedAt)
    }

    // MARK: - 5. Pass-throughs (closing H-33)

    func test_priorWakeZ_robustZ_gatesAndMath() {
        // (13 − median 10) / (1.4826 × MAD 1)
        let buffer = [8.0, 9.0, 10.0, 11.0, 12.0]
        let z = try! XCTUnwrap(Builder.robustZ(13, buffer: buffer))
        XCTAssertEqual(z, 3.0 / 1.4826, accuracy: 1e-9)

        // Below the H-34 night gate ⇒ nil.
        XCTAssertNil(Builder.robustZ(13, buffer: [8, 9, 10, 11]))
        // Zero dispersion ⇒ nil (never a fabricated z).
        XCTAssertNil(Builder.robustZ(13, buffer: [10, 10, 10, 10, 10]))
    }

    func test_makeInput_wiresPriorWakeZ_fromCarriedBuffer() {
        let sessionStart = day(30).addingTimeInterval(-3600)  // 23:00 the night before
        let state = Builder.State(
            lastSleepEndDate: sessionStart.addingTimeInterval(-17 * 3600),  // 17 h prior wake
            priorWakeBuffer: [14.0, 15.0, 16.0, 17.0, 18.0]  // median 16, MAD 1
        )
        let night = Builder.Night(
            bucketedDate: day(30),
            tstMinutes: 450,
            sessionStart: sessionStart,
            sessionEnd: day(30).addingTimeInterval(7 * 3600),
            sourceID: "com.apple.health"
        )
        let input = Builder.makeInput(state: state, night: night, calendar: calendar)
        XCTAssertEqual(try! XCTUnwrap(input.state.priorWakeHours), 17.0, accuracy: 1e-9)
        XCTAssertEqual(
            try! XCTUnwrap(input.state.priorWakeZ),
            (17.0 - 16.0) / 1.4826,
            accuracy: 1e-9
        )
    }

    func test_fold_pushesValidPriorWake_capped28() {
        let sessionStart = day(30).addingTimeInterval(-3600)
        let night = Builder.Night(
            bucketedDate: day(30),
            tstMinutes: 450,
            sessionStart: sessionStart,
            sessionEnd: day(30).addingTimeInterval(7 * 3600),
            sourceID: "com.apple.health"
        )

        // Valid 16-h span pushes; a full buffer stays capped at 28, oldest dropped.
        var state = Builder.State(
            lastSleepEndDate: sessionStart.addingTimeInterval(-16 * 3600),
            priorWakeBuffer: (0..<28).map { 10.0 + Double($0) * 0.1 }
        )
        var folded = Builder.fold(
            state: state, night: night, needTonightMinutes: 450,
            latchedProfiles: [], calendar: calendar
        )
        XCTAssertEqual(folded.priorWakeBuffer.count, 28)
        XCTAssertEqual(try! XCTUnwrap(folded.priorWakeBuffer.last), 16.0, accuracy: 1e-9)
        XCTAssertEqual(folded.priorWakeBuffer.first!, 10.1, accuracy: 1e-9, "Oldest dropped")

        // No previous sleep end ⇒ no span ⇒ no push (H-22: gap, not vigil).
        state = Builder.State(lastSleepEndDate: nil)
        folded = Builder.fold(
            state: state, night: night, needTonightMinutes: 450,
            latchedProfiles: [], calendar: calendar
        )
        XCTAssertTrue(folded.priorWakeBuffer.isEmpty)
    }

    func test_napMinutes_selection() {
        let lastSleepEnd = day(29).addingTimeInterval(7 * 3600)     // yesterday 07:00
        let mainStart = day(29).addingTimeInterval(23 * 3600)       // tonight 23:00

        func candidate(_ startHour: Double, minutes: Double) -> Builder.NapCandidate {
            let start = day(29).addingTimeInterval(startHour * 3600)
            return Builder.NapCandidate(
                start: start,
                end: start.addingTimeInterval(minutes * 60),
                asleepMinutes: minutes
            )
        }

        let counted = candidate(14, minutes: 30)       // daytime nap ≥ 20 min → counts
        let tooShort = candidate(16, minutes: 15)      // below the 20-min trigger
        let beforeMain = candidate(5, minutes: 45)     // ends before lastSleepEnd → previous night

        let total = Builder.napMinutes(
            candidates: [beforeMain, counted, tooShort],
            mainSessionStart: mainStart,
            lastSleepEnd: lastSleepEnd
        )
        XCTAssertEqual(total, 30, accuracy: 1e-9)

        // Unknown previous sleep end ⇒ candidates indistinguishable from an unfolded
        // previous night ⇒ 0 (absent — never fires NAP_DAY).
        XCTAssertEqual(
            Builder.napMinutes(
                candidates: [counted],
                mainSessionStart: mainStart,
                lastSleepEnd: nil
            ),
            0
        )
    }

    /// M5 / H-41 kill test — the missed-fold-day walk: Mon folds (lastSleepEnd = Mon
    /// 07:00), Tue the app never opens (Mon night stays unfolded), Wed folds Tue night.
    /// The unfolded Mon night sits in the widened gap and passes every pre-fix nap
    /// filter (~400 asleep min between Mon 07:00 and Tue 23:00) — the staleness gate
    /// must read napMinutes 0 (unknown). And the ~39.5 h Mon-07:00 → Tue-23:00 span
    /// (inside H-22's 48 h) must NOT enter the H-34 prior-wake buffer.
    func test_missedFoldDay_staleLastSleepEnd_noFalseNap_noPriorWakeBufferPush() {
        let monWakeEnd = day(0).addingTimeInterval(7 * 3600)        // Mon 07:00
        let tueNightStart = day(1).addingTimeInterval(22.5 * 3600)  // Tue 22:30 (~39.5 h later)
        let wedWakeEnd = day(2).addingTimeInterval(7 * 3600)        // Wed 07:00

        // The unfolded Mon night (Mon 23:00 → Tue 06:40, ~400 asleep min) appears as a
        // truncated non-main cluster in Wed's fetch window.
        let unfoldedMonNight = Builder.NapCandidate(
            start: day(0).addingTimeInterval(23 * 3600),
            end: day(1).addingTimeInterval((6.0 + 40.0 / 60.0) * 3600),
            asleepMinutes: 400
        )
        XCTAssertEqual(
            Builder.napMinutes(
                candidates: [unfoldedMonNight],
                mainSessionStart: tueNightStart,
                lastSleepEnd: monWakeEnd
            ),
            0,
            "A stale lastSleepEnd (> 24 h before the main session) must zero the nap sum"
        )

        // Wed's fold of Tue night: the 39.5 h fold-gap artifact must not push.
        let state = Builder.State(
            lastSleepEndDate: monWakeEnd,
            lastFoldedDate: day(1),  // Mon's fold stamped Mon night's wake day
            priorWakeBuffer: [15.0, 16.0, 17.0, 16.5, 15.5]
        )
        let tueNight = Builder.Night(
            bucketedDate: day(2),
            tstMinutes: 450,
            sessionStart: tueNightStart,
            sessionEnd: wedWakeEnd,
            sourceID: "com.apple.health"
        )
        let folded = Builder.fold(
            state: state, night: tueNight, needTonightMinutes: 450,
            latchedProfiles: [], calendar: calendar
        )
        XCTAssertEqual(
            folded.priorWakeBuffer, [15.0, 16.0, 17.0, 16.5, 15.5],
            "The ~39.5 h fold-gap artifact must never enter the H-34 buffer"
        )
        // The fold itself still happened (Tue night is a real night).
        XCTAssertEqual(folded.lastSleepEndDate, wedWakeEnd)
        XCTAssertEqual(folded.nightsOfHistory, state.nightsOfHistory + 1)

        // Control: a fresh (≤ 24 h) span still pushes.
        let freshState = Builder.State(
            lastSleepEndDate: tueNightStart.addingTimeInterval(-16 * 3600),
            priorWakeBuffer: []
        )
        let freshFolded = Builder.fold(
            state: freshState, night: tueNight, needTonightMinutes: 450,
            latchedProfiles: [], calendar: calendar
        )
        XCTAssertEqual(freshFolded.priorWakeBuffer.count, 1)
        XCTAssertEqual(try! XCTUnwrap(freshFolded.priorWakeBuffer.first), 16.0, accuracy: 1e-9)
    }

    func test_priorDayLoadZ_coverageAndMath() {
        let wakeDay = day(60)
        // Window = days 31…58 (28 days before the prior day, day 59).
        var dailyTSS: [Date: Double] = [:]
        var window: [Double] = []
        for index in 31...58 {
            let value: Double = index % 2 == 0 ? 100 : 0
            dailyTSS[day(index)] = value
            window.append(value)
        }
        dailyTSS[day(59)] = 150

        let mean = window.reduce(0, +) / Double(window.count)
        let sd = (window.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
            / Double(window.count - 1)).squareRoot()
        let expected = (150 - mean) / sd

        let z = Builder.priorDayLoadZ(
            dailyTSS: dailyTSS,
            wakeDay: wakeDay,
            earliestSessionDay: day(31),
            calendar: calendar
        )
        XCTAssertEqual(try! XCTUnwrap(z), expected, accuracy: 1e-9)

        // H-36 coverage: history younger than the window start ⇒ nil (no fabricated zeros).
        XCTAssertNil(
            Builder.priorDayLoadZ(
                dailyTSS: dailyTSS,
                wakeDay: wakeDay,
                earliestSessionDay: day(32),
                calendar: calendar
            )
        )
        // No history at all ⇒ nil.
        XCTAssertNil(
            Builder.priorDayLoadZ(
                dailyTSS: [:], wakeDay: wakeDay, earliestSessionDay: nil, calendar: calendar
            )
        )
    }

    func test_priorDayEnergyZ_presentDaysGate() {
        let wakeDay = day(60)
        func energyMap(presentDays: Int) -> [Date: Double] {
            var map: [Date: Double] = [day(59): 900]
            for offset in 0..<presentDays {
                map[day(58 - offset)] = 500 + Double(offset % 5) * 40
            }
            return map
        }

        // 21 present days (H-37 gate) ⇒ a z.
        XCTAssertNotNil(
            Builder.priorDayEnergyZ(
                dailyEnergy: energyMap(presentDays: 21), wakeDay: wakeDay, calendar: calendar
            )
        )
        // 20 present days ⇒ nil.
        XCTAssertNil(
            Builder.priorDayEnergyZ(
                dailyEnergy: energyMap(presentDays: 20), wakeDay: wakeDay, calendar: calendar
            )
        )
        // Prior day itself missing (watch off) ⇒ nil, never zero-read.
        var noPriorDay = energyMap(presentDays: 21)
        noPriorDay[day(59)] = nil
        XCTAssertNil(
            Builder.priorDayEnergyZ(
                dailyEnergy: noPriorDay, wakeDay: wakeDay, calendar: calendar
            )
        )
    }

    // MARK: - 6. §6 falsification criteria on synthetic datasets

    /// n Tier-A nights with fully controllable series.
    private func syntheticNights(
        count: Int,
        tier: String = "A",
        source: String? = "com.apple.health",
        v2: (Int) -> Double? = { Double($0) },
        v1: (Int) -> Double? = { Double($0) },
        proxy: (Int) -> Double? = { Double($0) },
        midpointSD14: (Int) -> Double? = { _ in nil },
        deepQ: (Int) -> Double? = { _ in nil },
        remQ: (Int) -> Double? = { _ in nil },
        needBase: (Int) -> Double? = { _ in nil },
        tst: (Int) -> Double = { _ in 450 }
    ) -> [Analysis.NightRecord] {
        (0..<count).map { index in
            Analysis.NightRecord(
                wakeDate: day(index),
                tierRaw: tier,
                sourceBundleID: source,
                v2Score: v2(index),
                v1Score: v1(index),
                sleepFreeReadiness: proxy(index),
                midpointSD14Minutes: midpointSD14(index),
                deepQ: deepQ(index),
                remQ: remQ(index),
                needBaseMinutes: needBase(index),
                tstMinutes: tst(index)
            )
        }
    }

    func test_criterion1_constructedPass_passes_constructedFail_fails() {
        // PASS construction: v2 tracks the outcome perfectly, v1 is anti-correlated —
        // Δρ = 2 in every resample, so the CI lower bound sits far above zero.
        let passNights = syntheticNights(
            count: 80,
            v2: { Double($0) * 2 + 5 },
            v1: { 100 - Double($0) },
            proxy: { Double($0) }
        )
        let passReport = Analysis.analyze(nights: passNights)
        XCTAssertEqual(passReport.wholeV2.verdict, .pass)
        XCTAssertEqual(passReport.wholeV2.n, 80)
        XCTAssertEqual(try! XCTUnwrap(passReport.wholeV2.rhoV2), 1.0, accuracy: 1e-9)
        XCTAssertEqual(try! XCTUnwrap(passReport.wholeV2.rhoV1), -1.0, accuracy: 1e-9)
        XCTAssertGreaterThan(try! XCTUnwrap(passReport.wholeV2.ciLower), 0)

        // FAIL construction: v1 tracks the outcome perfectly, v2 is scrambled — Δρ < 0,
        // the margin cannot exclude zero from above.
        let failNights = syntheticNights(
            count: 80,
            v2: { Double(($0 * 37) % 61) },
            v1: { Double($0) },
            proxy: { Double($0) }
        )
        let failReport = Analysis.analyze(nights: failNights)
        XCTAssertEqual(failReport.wholeV2.verdict, .fail)
        XCTAssertLessThan(try! XCTUnwrap(failReport.wholeV2.deltaRhoPoint), 0)
    }

    func test_criterion1_insufficientBelowSixtyNights_andTierDExcluded() {
        let thin = Analysis.analyze(nights: syntheticNights(count: 59))
        XCTAssertEqual(thin.wholeV2.verdict, .insufficientData)

        // 80 Tier-D nights: v1-identical by contract, so none are eligible.
        let tierD = Analysis.analyze(nights: syntheticNights(count: 80, tier: "D"))
        XCTAssertEqual(tierD.wholeV2.verdict, .insufficientData)
        XCTAssertEqual(tierD.wholeV2.n, 0)
    }

    func test_criterion2_stageNoise_flagsNoise_passesCalm() {
        // Noise: deep q alternates 0.2 / 2.0 — first-difference residual SD ≈ 1.27 >
        // 0.90. A single measured-noisy stage fails outright, REM unmeasured or not.
        let noisy = Analysis.analyze(
            nights: syntheticNights(count: 64, deepQ: { $0 % 2 == 0 ? 0.2 : 2.0 })
        )
        XCTAssertEqual(noisy.stageNoise.verdict, .fail)
        XCTAssertGreaterThan(
            try! XCTUnwrap(noisy.stageNoise.deepResidualSD),
            noisy.stageNoise.curveQRange
        )

        // Calm on BOTH stages (M3: `.pass` needs both measured): q wobbles ±0.05 around
        // baseline — residual SD ≈ 0.07, well inside the curve.
        let calm = Analysis.analyze(
            nights: syntheticNights(
                count: 64,
                deepQ: { $0 % 2 == 0 ? 0.95 : 1.05 },
                remQ: { $0 % 2 == 0 ? 1.02 : 0.98 }
            )
        )
        XCTAssertEqual(calm.stageNoise.verdict, .pass)

        // Below the pair gate on both stages ⇒ insufficient, never a verdict from 5 nights.
        let thin = Analysis.analyze(
            nights: syntheticNights(count: 5, deepQ: { _ in 1.0 }, remQ: { _ in 1.0 })
        )
        XCTAssertEqual(thin.stageNoise.verdict, .insufficientData)
    }

    /// M3 — the review's mixed scenario: deep measured calm (many pairs), REM unmeasured
    /// (pairs below `minStagePairs`). One measured stage must NOT buy a `.pass`; the
    /// per-stage numbers report which arm is missing.
    func test_criterion2_oneStageMeasured_oneUnmeasured_isPartial_neverPass() {
        let mixed = Analysis.analyze(
            nights: syntheticNights(
                count: 64,
                deepQ: { $0 % 2 == 0 ? 0.95 : 1.05 },       // 63 pairs, calm
                remQ: { $0 < 10 ? 1.0 : nil }               // 9 pairs < 30 — unmeasured
            )
        )
        XCTAssertEqual(mixed.stageNoise.verdict, .partial)
        XCTAssertNotNil(mixed.stageNoise.deepResidualSD)
        XCTAssertNil(mixed.stageNoise.remResidualSD)
        XCTAssertEqual(mixed.stageNoise.deepPairCount, 63)
        XCTAssertEqual(mixed.stageNoise.remPairCount, 9)
    }

    /// Minor — pairing runs WITHIN each source's own subsequence: strict two-source
    /// alternation (which yields ZERO physically-adjacent same-source pairs) still
    /// produces each source's night-to-night pairs.
    func test_criterion2_pairsWithinEachSourceSubsequence_underAlternation() {
        let nights = (0..<64).map { index in
            Analysis.NightRecord(
                wakeDate: day(index),
                tierRaw: "A",
                sourceBundleID: index % 2 == 0 ? "com.apple.health" : "com.ouraring.oura",
                deepQ: index % 4 < 2 ? 0.95 : 1.05,
                remQ: index % 4 < 2 ? 1.02 : 0.98,
                tstMinutes: 450
            )
        }
        let report = Analysis.analyze(nights: nights)
        // 32 nights per source ⇒ 31 pairs each ⇒ 62 pooled pairs per stage.
        XCTAssertEqual(report.stageNoise.deepPairCount, 62)
        XCTAssertEqual(report.stageNoise.remPairCount, 62)
        XCTAssertEqual(report.stageNoise.verdict, .pass)
    }

    func test_criterion3_regularityAssociation_presentPasses_absentIsStatisticalNull() {
        // M2: criterion 3's bootstrap block must cover its predictor's dependence length
        // (midpointSD14 is a 14-night rolling SD) — pinned so a retune cannot silently
        // shrink it below 14. Criterion 1 keeps its own 7-night block.
        XCTAssertGreaterThanOrEqual(Analysis.regularityBootstrapBlockLength, 14)

        // Association present: higher midpoint SD tracks lower readiness monotonically.
        let associated = Analysis.analyze(
            nights: syntheticNights(
                count: 80,
                proxy: { Double($0) },
                midpointSD14: { 100 - Double($0) }
            )
        )
        XCTAssertEqual(associated.regularity.verdict, .pass)
        XCTAssertEqual(try! XCTUnwrap(associated.regularity.rho), -1.0, accuracy: 1e-9)

        // No association: SD scrambled against the outcome — the CI straddles zero. The
        // null outcome is `.statisticalNull`, NOT `.fail`: §6's cut is a conjunction
        // (absent association AND HAN's not-actionable report), and the second condition
        // is human — code alone can never issue `.fail` for criterion 3.
        let scrambled = Analysis.analyze(
            nights: syntheticNights(
                count: 80,
                proxy: { Double(($0 * 29) % 83) },
                midpointSD14: { Double(($0 * 53) % 79) }
            )
        )
        XCTAssertEqual(scrambled.regularity.verdict, .statisticalNull)
    }

    func test_criterion4_splitHalfDisagreement_detected_agreementPasses() {
        // Alternating weeks: even weeks 400-min nights, odd weeks 480 — the two p75s
        // disagree by 80 min > 30 ⇒ the need estimator fails its split-half check.
        let disagreeing = Analysis.analyze(
            nights: syntheticNights(count: 42, tst: { ($0 / 7) % 2 == 0 ? 400 : 480 })
        )
        XCTAssertEqual(disagreeing.need.verdict, .fail)
        XCTAssertEqual(
            try! XCTUnwrap(disagreeing.need.splitHalfDeltaMinutes), 80, accuracy: 1e-9
        )
        XCTAssertFalse(disagreeing.need.estimatorBEvaluated)

        // Uniform sleeper with an interior learned need ⇒ BOTH guards ran clean ⇒ pass
        // (M4: without a learned need the bound guard never runs and pass is barred).
        let agreeing = Analysis.analyze(
            nights: syntheticNights(count: 42, needBase: { _ in 480 }, tst: { _ in 440 })
        )
        XCTAssertEqual(agreeing.need.verdict, .pass)
        XCTAssertEqual(try! XCTUnwrap(agreeing.need.splitHalfDeltaMinutes), 0, accuracy: 1e-9)
    }

    /// M4 — the review's counterexample: 21 nights → even weeks 14 nights, odd week 7.
    /// The odd half sits below `minHalfNights`, so the split-half guard NEVER ran; a
    /// clean bound guard alone must not buy a `.pass`.
    func test_criterion4_splitHalfNeverRan_isPartial_neverPass() {
        let report = Analysis.analyze(
            nights: syntheticNights(count: 21, needBase: { _ in 480 }, tst: { _ in 440 })
        )
        XCTAssertEqual(report.need.evenHalfCount, 14)
        XCTAssertEqual(report.need.oddHalfCount, 7)
        XCTAssertNil(report.need.splitHalfDeltaMinutes, "Below-gate halves must not compare")
        XCTAssertNil(report.need.boundHitDate, "The bound guard ran and found no hit")
        XCTAssertEqual(report.need.verdict, .partial)
    }

    /// Minor — the LOWER bound registers too: a stored need sitting on the 390-min §4
    /// clamp inside the first 90 days is a bound hit.
    func test_criterion4_lowerBoundHit_registers() {
        let report = Analysis.analyze(
            nights: syntheticNights(
                count: 42,
                needBase: { $0 == 3 ? SleepStateBuilder.needLowerBoundMinutes : 480 },
                tst: { _ in 440 }
            )
        )
        XCTAssertEqual(report.need.verdict, .fail)
        XCTAssertEqual(report.need.boundHitDate, day(3))
    }

    func test_criterion4_boundHit_withinFirst90Days_detected() {
        // The stored need sits on the 570-min upper bound on night 5 — inside the 90-day
        // window from the first learned need ⇒ fail, and the hit night is reported.
        let boundHit = Analysis.analyze(
            nights: syntheticNights(
                count: 42,
                needBase: { $0 == 5 ? SleepStateBuilder.needUpperBoundMinutes : 480 },
                tst: { _ in 440 }
            )
        )
        XCTAssertEqual(boundHit.need.verdict, .fail)
        XCTAssertEqual(boundHit.need.boundHitDate, day(5))

        // Interior need the whole way ⇒ no hit.
        let interior = Analysis.analyze(
            nights: syntheticNights(count: 42, needBase: { _ in 480 }, tst: { _ in 440 })
        )
        XCTAssertEqual(interior.need.verdict, .pass)
        XCTAssertNil(interior.need.boundHitDate)
    }

    func test_criterion5_tierCounts_andStagelessSourceRead() {
        // 10 staged Apple nights + 10 stage-less Whoop nights: the per-tier counts are the
        // coverage read, and the Whoop source is flagged as delivering no stages.
        let apple = syntheticNights(count: 10, tier: "A", source: "com.apple.health")
        let whoop = (0..<10).map { index in
            Analysis.NightRecord(
                wakeDate: day(20 + index),
                tierRaw: "C",
                sourceBundleID: "com.whoop.iphone",
                tstMinutes: 430
            )
        }
        let report = Analysis.analyze(nights: apple + whoop)
        XCTAssertEqual(report.tierCoverage.countsByTier["A"], 10)
        XCTAssertEqual(report.tierCoverage.countsByTier["C"], 10)
        XCTAssertEqual(report.tierCoverage.countsBySource["com.whoop.iphone"]?["C"], 10)
        XCTAssertEqual(report.tierCoverage.stagelessSources, ["com.whoop.iphone"])
        XCTAssertEqual(report.tierCoverage.verdict, .fail)
        XCTAssertEqual(report.tierCoverage.modalTierRaw, "A")

        // All-staged coverage ⇒ pass.
        let stagedOnly = Analysis.analyze(nights: apple)
        XCTAssertEqual(stagedOnly.tierCoverage.verdict, .pass)
    }

    /// Minor — determinism under seed: the bootstrap is `SplitMix64`-driven, so the same
    /// seed must reproduce the CI bounds bit-for-bit and a different seed must (on this
    /// resample-varying construction) move them.
    func test_analyze_deterministicUnderSeed_differentSeedMovesCI() {
        // Noisy construction: Δρ varies across resamples, so the CI actually depends on
        // the resample draw (a constant statistic would make every seed identical).
        let nights = syntheticNights(
            count: 80,
            v2: { Double(($0 * 37) % 61) },
            v1: { Double(($0 * 13) % 47) },
            proxy: { Double($0) },
            midpointSD14: { Double(($0 * 53) % 79) }
        )

        let runA = Analysis.analyze(nights: nights, seed: 0x5EED)
        let runB = Analysis.analyze(nights: nights, seed: 0x5EED)
        XCTAssertEqual(runA.wholeV2.ciLower, runB.wholeV2.ciLower)
        XCTAssertEqual(runA.wholeV2.ciUpper, runB.wholeV2.ciUpper)
        XCTAssertEqual(runA.regularity.ciLower, runB.regularity.ciLower)
        XCTAssertEqual(runA.regularity.ciUpper, runB.regularity.ciUpper)

        let runC = Analysis.analyze(nights: nights, seed: 0xD1CE)
        XCTAssertNotEqual(
            runA.wholeV2.ciLower, runC.wholeV2.ciLower,
            "A different seed draws different blocks — bounds move on this construction"
        )
    }
}
