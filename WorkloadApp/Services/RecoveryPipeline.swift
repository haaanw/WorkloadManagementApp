import Foundation
import SwiftData

/// Orchestrates recovery data flow: HealthKit fetch → baseline computation → score → snapshot upsert.
@MainActor
struct RecoveryPipeline {

    struct RecoveryResult {
        let score: Double
        let zone: RecoveryZone
        let snapshot: RecoveryScoreEngine.RecoveryResult
        let staleness: HealthKitStaleness
    }

    /// Run on app launch and after wellness check-in.
    /// v1.5 self-coached path: HRV / RHR / sleep / wellness + ordinary 7-day baselines only.
    /// Trailing days of history fetched for the HRV/RHR daily reductions. Wider than the
    /// 7-day baseline it feeds so a run after a gap still finds seven observed days.
    static let baselineWindowDays: Int = 30

    static func run(
        athlete: Athlete,
        healthKitService: HealthKitService,
        modelContext: ModelContext,
        syncService: SyncService? = nil
    ) async throws -> RecoveryResult {
        let recoveryRepo = RecoveryRepository(modelContext: modelContext)
        let calendar = Calendar.current
        let now = Date.now

        // 1. Fetch HealthKit data (staleness-aware)
        var hrv: Double?
        var rhr: Double?
        var sleep: Double?
        var bodyTemp: Double?
        var vo2Max: Double?
        var hrvDate: Date?
        var rhrDate: Date?
        var sleepDate: Date?
        var sleepDetail: HealthKitService.LastNightSleepDetail?
        var hrvReduced: ReadinessInputReducer.Reduced?
        var rhrReduced: ReadinessInputReducer.Reduced?

        // Attempt reads whenever HealthKit is available AND the user has requested access.
        // Absence of data is treated as "no recent data" downstream, never as "unauthorized".
        if healthKitService.isAvailable && healthKitService.hasRequestedAccess {
            // HRV and RHR now arrive as DAILY values rather than as "whichever sample
            // HealthKit wrote last" (v1.7.1 algorithm update). The two signals reduce
            // differently on purpose — HRV by morning window because time of day changes
            // what a momentary SDNN reading means, RHR by calendar day because Apple already
            // computes it as a daily aggregate. `ReadinessInputReducer` owns that split and
            // the rule that today never enters its own baseline.
            let hrvSamples = (try? await healthKitService.fetchHRVHistory(days: baselineWindowDays)) ?? []
            hrvReduced = ReadinessInputReducer.hrv(
                samples: hrvSamples,
                windowDays: baselineWindowDays,
                now: now,
                calendar: calendar
            )
            hrv = hrvReduced?.today
            hrvDate = hrvReduced?.today != nil ? now : nil

            let rhrSamples = (try? await healthKitService.fetchRestingHRHistory(days: baselineWindowDays)) ?? []
            rhrReduced = ReadinessInputReducer.rhr(
                samples: rhrSamples,
                windowDays: baselineWindowDays,
                now: now,
                calendar: calendar
            )
            rhr = rhrReduced?.today
            rhrDate = rhrReduced?.today != nil ? now : nil

            sleepDetail = try? await healthKitService.fetchLastNightSleepDetail()
            sleepDate = sleepDetail?.sessionEnd

            // Sleep belongs to the day the athlete WOKE, not the day the pipeline happens
            // to run (v1.7.1; the sleep-v2 shadow has always keyed this way). Opening the
            // app at 00:30 used to write the PREVIOUS morning's night onto the new day's
            // row and present it as "last night" — 17 h stale, and below the 24 h
            // staleness threshold so nothing flagged it.
            if let sleepDetail,
               calendar.isDateInToday(sleepDetail.sessionEnd) {
                sleep = sleepDetail.tstMinutes
            } else {
                sleep = nil
            }

            bodyTemp = try? await healthKitService.fetchLatestBodyTemp()
            vo2Max = try? await healthKitService.fetchLatestVO2Max()

            // Reflect the LATEST full read cycle: data present → .connected; nothing returned →
            // .requestedNoData (e.g. access revoked in Settings, or no recent samples). This is an
            // authoritative cycle (all reads attempted), so it may downgrade a stale .connected.
            // hasRequestedAccess stays sticky, so the connect CTA never reappears.
            healthKitService.updateObservedData(hrv != nil || rhr != nil || sleep != nil)
        }

        let staleness = HealthKitStaleness(lastHRVDate: hrvDate, lastSleepDate: sleepDate, lastRHRDate: rhrDate)

        // 2. Baselines from PRIOR days only.
        //
        // Both the values and the window changed (v1.7.1). The values are the daily
        // reductions above rather than a `compactMap` over stored snapshot fields, so the
        // baseline is built from the same series the score is measured against. And today is
        // excluded: the old 7-day history fetch included today's own row once the day's first
        // run had written it, so any later run — a wellness check-in, a dashboard reload —
        // folded today's reading into the mean it was about to be compared with. The
        // deviation shrank and the score drifted with no new physiology.
        let recoveryHistory = try recoveryRepo.fetchRecoveryHistory(days: 7, athlete: athlete)
        let hrvBaseline = RecoveryScoreEngine.computeBaseline(values: hrvReduced?.priorDays ?? [])
        let rhrBaseline = RecoveryScoreEngine.computeBaseline(values: rhrReduced?.priorDays ?? [])

        // 3. Fetch today's wellness check-in
        let todayCheckIn = try recoveryRepo.fetchTodayWellnessCheckIn(athlete: athlete)
        let wellnessScore = todayCheckIn?.wellnessScore

        // 4. Compute recovery score. The trend series also drops today: the modifier is an
        // autoregression on the engine's own past output, so letting it read the score it is
        // about to replace made a same-day re-run move the number on its own.
        let recentScores = ReadinessInputReducer.priorDayScores(
            recoveryHistory.map { (date: $0.date, score: $0.recoveryScore) },
            now: now,
            calendar: calendar
        )
        let input = RecoveryScoreEngine.RecoveryInput(
            hrvSDNN: hrv,
            restingHR: rhr,
            sleepDurationMinutes: sleep,
            wellnessScore: wellnessScore,
            hrvBaseline: hrvBaseline,
            restingHRBaseline: rhrBaseline,
            recentScores: recentScores
        )
        let result = RecoveryScoreEngine.compute(input: input)

        // 5. Upsert recovery snapshot (including baselines for ReasoningEngine)
        try recoveryRepo.upsertRecoverySnapshot(
            hrvSDNN: hrv,
            restingHR: rhr,
            sleepDurationMinutes: sleep,
            bodyTemp: bodyTemp,
            vo2Max: vo2Max,
            recoveryScore: result.score,
            hrvBaseline: hrvBaseline,
            restingHRBaseline: rhrBaseline,
            athlete: athlete,
            // The pipeline did the daily reduction itself, so a nil HRV here means "today has
            // no morning reading", not "the read failed". Writing it through clears any
            // earlier midday value that a pre-v1.7.1 run left on the row — otherwise the row
            // would display a number the score deliberately did not use.
            authoritativeHRV: healthKitService.isAvailable && healthKitService.hasRequestedAccess
        )

        // 5b. Orphan guard: a night whose wake day is NOT today did not reach the row
        // above. File it on the day the athlete woke, if that row exists and has no sleep
        // yet — otherwise a first open after midnight loses the night entirely, which is
        // worse than the wrong-day attribution the gate above removed. Never overwrites a
        // measured value and never fabricates a row (see `backfillSleep`).
        if let sleepDetail, !calendar.isDateInToday(sleepDetail.sessionEnd) {
            try? recoveryRepo.backfillSleep(
                minutes: sleepDetail.tstMinutes,
                wakeDay: sleepDetail.sessionEnd,
                athlete: athlete
            )
        }

        // 5c. Recovery estimator v2 — SHADOW dual-run. Runs AFTER the live score is final and
        // persisted, writes only to its own local-only model, and can never throw out of the
        // pipeline. Nothing reads it back into a decision (the sleep-v2 run-dark precedent).
        let respiratoryRate = (healthKitService.isAvailable && healthKitService.hasRequestedAccess)
            ? try? await healthKitService.fetchOvernightRespiratoryRate()
            : nil
        runRecoveryShadow(
            athlete: athlete,
            hrvReduced: hrvReduced,
            rhrReduced: rhrReduced,
            sleepMinutes: sleep,
            wellnessScore: wellnessScore,
            liveResult: result,
            hrvBaseline: hrvBaseline,
            rhrBaseline: rhrBaseline,
            wristTempC: bodyTemp,
            respiratoryRate: respiratoryRate,
            now: now,
            calendar: calendar,
            modelContext: modelContext
        )

        // 6. Sleep score v2 — SHADOW fold (Phase S2) + the §6 per-night record and its
        // deferred joins (Phase S3). Computed and recorded, NEVER driving: the live
        // recovery score above is already final, and nothing below can throw out of the
        // pipeline (CrossModalShadowGate is the run-dark precedent).
        await runSleepV2Shadow(
            athlete: athlete,
            healthKitService: healthKitService,
            modelContext: modelContext,
            detail: sleepDetail,
            v1SleepMinutes: sleep
        )
        runSleepShadowJoins(athlete: athlete, modelContext: modelContext)

        if let syncService {
            let athleteId = athlete.id
            Task {
                await syncService.pushRecoveryAndWellness(context: modelContext, athleteId: athleteId)
            }
        }

        return RecoveryResult(
            score: result.score,
            zone: result.zone,
            snapshot: result,
            staleness: staleness
        )
    }

    // MARK: - Sleep v2 shadow (Phase S2 fold + Phase S3 per-night record, never driving)

    /// Run the sleep-v2 shadow computation for last night: fetch stage detail, assemble the
    /// engine input from the carried `BaselineState` sleep-v2 sub-state (prequential —
    /// through t−1), score, fold the night back into the carrier, and PERSIST the §6
    /// per-night record.
    ///
    /// - The live recovery score is untouched — this is a shadow, per PLAN Phase S2 and the
    ///   `CrossModalShadowGate` run-dark precedent.
    /// - Storage (Phase S3): one local-only `SleepShadowNight` row per fold — the §6 log
    ///   record `SleepShadowAnalysis` computes the falsification criteria from. This
    ///   replaces the S2 print-only logging. The §6 morning/evening joins are deferred to
    ///   `runSleepShadowJoins` (H-39).
    /// - Pass-throughs (Phase S3, closing H-33): `napMinutes` from the fetch's own non-main
    ///   sessions (H-35), `priorDayLoadZ` from logged sessions (H-36),
    ///   `priorDayActiveEnergyZ` from HealthKit daily sums (H-37), `priorWakeZ` from the
    ///   carried 28-night buffer (H-34, computed inside `makeInput`).
    /// - All errors degrade silently to the existing behaviour: the method never throws and
    ///   catches everything internally (sleep v2 must never break the pipeline).
    /// - Once per wake day: the `sleepV2LastFoldedDate` monotonic cutoff (the W-1
    ///   idempotency contract) makes re-runs on the same day no-ops — the cutoff is
    ///   checked before any shadow work (F4). Since v1.7.1 the sleep detail is fetched
    ///   once in pipeline step 1 (the live score consumes it too) and passed in, so the
    ///   shadow itself issues no sleep query; the F4 pre-check now guards the fold and
    ///   the H-37 energy query.
    /// - The fold key is the SESSION's wake day — `startOfDay(sessionEnd)` — never the run
    ///   date (F3a): a pipeline run after midnight must not re-bucket last night onto the
    ///   run day. Two further guards live in `SleepStateBuilder.shouldFold` (F3b/F3c):
    ///   session identity (`sessionEnd` must advance past the stored end) and the H-26
    ///   completeness hold (a session that ended < 120 min ago may still be ongoing), so a
    ///   truncated 02:00 fetch never folds and the full night still folds later that day.
    private static func runSleepV2Shadow(
        athlete: Athlete,
        healthKitService: HealthKitService,
        modelContext: ModelContext,
        detail: HealthKitService.LastNightSleepDetail?,
        v1SleepMinutes: Double?
    ) async {
        do {
            guard healthKitService.isAvailable && healthKitService.hasRequestedAccess else {
                return
            }

            let calendar = Calendar.current
            let now = Date.now
            let today = calendar.startOfDay(for: now)

            // Fetch the athlete's BaselineState row if one exists. Fetch-all + filter in
            // Swift, dodging the optional to-one relationship #Predicate trap (the
            // BaselineStateModelTests pattern). Creation waits until a night actually
            // needs folding — no empty rows on early-exit paths.
            let allStates = try modelContext.fetch(FetchDescriptor<BaselineState>())
            let athleteId = athlete.id
            let existing = allStates.first(where: { $0.athlete?.id == athleteId })

            // F4 pre-check, BEFORE the HealthKit query: already folded today → done.
            if let last = existing?.sleepV2LastFoldedDate,
               today <= calendar.startOfDay(for: last) {
                return
            }

            guard let detail else {
                // No asleep samples in the window — Tier E, no night to fold. (The fetch
                // now happens once in step 1; live score and shadow share the detail.)
                return
            }

            let row: BaselineState
            if let existing {
                row = existing
            } else {
                let fresh = BaselineState(athlete: athlete)
                modelContext.insert(fresh)
                row = fresh
            }

            let state = sleepV2Mirror(of: row)
            // F3a: the fold key derives from the SESSION — the wake day is the day the
            // session ended, not the day the pipeline happens to run.
            let wakeDay = calendar.startOfDay(for: detail.sessionEnd)
            let night = SleepStateBuilder.Night(
                bucketedDate: wakeDay,
                tstMinutes: detail.tstMinutes,
                deepMinutes: detail.deepMinutes,
                remMinutes: detail.remMinutes,
                awakeMinutes: detail.awakeMinutes,
                inBedMinutes: detail.inBedMinutes,
                sessionStart: detail.sessionStart,
                sessionEnd: detail.sessionEnd,
                sourceID: detail.dominantSourceID
            )

            // F3b (session identity) + F3c (H-26 completeness hold): never re-fold the
            // same physical night, and never fold a possibly-ongoing one.
            guard SleepStateBuilder.shouldFold(night: night, state: state, now: now) else {
                return
            }

            // Pass-through inputs (Phase S3 — closing H-33). Each degrades to absent
            // (nil / 0), and a nil z never fires a trigger (the engine's own rule).
            let napMinutes = SleepStateBuilder.napMinutes(
                candidates: detail.napCandidates,
                mainSessionStart: detail.sessionStart,
                lastSleepEnd: state.lastSleepEndDate
            )

            // H-36 load z. The 40-day fetch bounds the query while covering the 29-day
            // window with margin; the coverage check (earliest observed session ≤ window
            // start) then decides honestly. An athlete whose most recent session is
            // younger than the window start — e.g. a ≥5-week layoff — fails coverage and
            // reads nil rather than being z-scored against fabricated zeros.
            let workoutRepo = WorkoutRepository(modelContext: modelContext)
            let sessions = (try? workoutRepo.fetchSessions(last: 40, athlete: athlete)) ?? []
            var dailyTSS: [Date: Double] = [:]
            for session in sessions {
                dailyTSS[calendar.startOfDay(for: session.sessionDate), default: 0]
                    += session.trainingStress
            }
            let priorDayLoadZ = SleepStateBuilder.priorDayLoadZ(
                dailyTSS: dailyTSS,
                wakeDay: wakeDay,
                earliestSessionDay: dailyTSS.keys.min(),
                calendar: calendar
            )

            // H-37 energy z (30 days covers the 29-day window). Runs only on a folding
            // night, so this is at most one extra HealthKit statistics query per day.
            let energyByDay =
                (try? await healthKitService.fetchDailyActiveEnergyByDay(days: 30)) ?? [:]
            let priorDayEnergyZ = SleepStateBuilder.priorDayEnergyZ(
                dailyEnergy: energyByDay,
                wakeDay: wakeDay,
                calendar: calendar
            )

            // Prequential: score against the state through t−1, then fold tonight in.
            let input = SleepStateBuilder.makeInput(
                state: state,
                night: night,
                priorDayLoadZ: priorDayLoadZ,
                priorDayActiveEnergyZ: priorDayEnergyZ,
                napMinutes: napMinutes,
                calendar: calendar
            )
            let result = SleepScoreEngine.compute(input: input)
            let folded = SleepStateBuilder.fold(
                state: state,
                night: night,
                needTonightMinutes: result.needTonightMinutes,
                latchedProfiles: result.latchedProfiles,
                calendar: calendar
            )
            applySleepV2(folded, to: row)
            row.updatedAt = .now

            // The §6 per-night record (Phase S3 — replaces the S2 print-only log). One
            // save covers the carrier fold and the record atomically.
            upsertShadowNight(
                athlete: athlete,
                wakeDay: wakeDay,
                detail: detail,
                input: input,
                result: result,
                napMinutes: napMinutes,
                v1SleepMinutes: v1SleepMinutes,
                modelContext: modelContext
            )
            try modelContext.save()
        } catch {
            print("Sleep v2 shadow error: \(error)")
        }
    }

    /// Write the §6 per-night record for one fold. Upsert on (athlete, wake day): the fold
    /// guards make a same-day second fold unreachable, so a pre-existing row is a defensive
    /// rarity — it is replaced wholesale (its joins re-run via `runSleepShadowJoins`).
    private static func upsertShadowNight(
        athlete: Athlete,
        wakeDay: Date,
        detail: HealthKitService.LastNightSleepDetail,
        input: SleepScoreEngine.SleepInput,
        result: SleepScoreEngine.SleepResult,
        napMinutes: Double,
        v1SleepMinutes: Double?,
        modelContext: ModelContext
    ) {
        // Date-equality #Predicate (predicate-safe); athlete filtered in Swift (the
        // optional to-one relationship #Predicate trap).
        let athleteId = athlete.id
        let sameDayDescriptor = FetchDescriptor<SleepShadowNight>(
            predicate: #Predicate { $0.wakeDate == wakeDay }
        )
        let existing = ((try? modelContext.fetch(sameDayDescriptor)) ?? [])
            .filter { $0.athlete?.id == athleteId }
        for stale in existing {
            modelContext.delete(stale)
        }

        // q per stage (H-11 kill-test read): tonight ÷ the same-source EWMA the engine
        // actually scored against; nil whenever the engine's stage input was nil.
        func stageQ(_ minutes: Double?, _ baseline: Double?) -> Double? {
            guard let minutes, let baseline, baseline > 0 else { return nil }
            return minutes / baseline
        }

        let record = SleepShadowNight(
            wakeDate: wakeDay,
            sourceBundleID: detail.dominantSourceID,
            tstMinutes: detail.tstMinutes,
            deepMinutes: detail.deepMinutes,
            remMinutes: detail.remMinutes,
            coreMinutes: detail.coreMinutes,
            wasoMinutes: detail.awakeMinutes,
            inBedMinutes: detail.inBedMinutes,
            sessionStart: detail.sessionStart,
            sessionEnd: detail.sessionEnd,
            tierRaw: result.tier.rawValue,
            componentDuration: result.componentScores[.duration],
            componentContinuity: result.componentScores[.continuity],
            componentRegularity: result.componentScores[.regularity],
            componentDeep: result.componentScores[.deep],
            componentRem: result.componentScores[.rem],
            pointsContinuity: result.points.continuity,
            pointsRegularity: result.points.regularity,
            pointsDeep: result.points.deep,
            pointsRem: result.points.rem,
            needBaseMinutes: input.needBaseMinutes,
            needTonightMinutes: result.needTonightMinutes,
            creditPressureMinutes: result.needCredits.pressureMinutes,
            creditStrainMinutes: result.needCredits.strainMinutes,
            creditDebtMinutes: result.needCredits.debtMinutes,
            creditNapDebitMinutes: result.needCredits.napDebitMinutes,
            creditAppliedMinutes: result.needCredits.appliedMinutes,
            activeProfilesRaw: result.activeProfiles.map(\.rawValue),
            latchedProfilesRaw: result.latchedProfiles.map(\.rawValue).sorted(),
            v2Score: result.score,
            confidence: result.confidence,
            v1SleepMinutes: v1SleepMinutes,
            v1SleepComponentScore: v1SleepMinutes.map(
                RecoveryScoreEngine.sleepDurationToScore
            ),
            midpointSD14Minutes: input.state.midpointSD14Minutes,
            midpointDeviationMinutes: input.state.midpointDeviationMinutes,
            priorWakeHours: input.state.priorWakeHours,
            priorWakeZ: input.state.priorWakeZ,
            priorDayLoadZ: input.state.priorDayLoadZ,
            priorDayActiveEnergyZ: input.state.priorDayActiveEnergyZ,
            napMinutes: napMinutes,
            sleepDebt7Minutes: input.state.sleepDebt7Minutes,
            deepQ: stageQ(input.deepMinutes, input.deepBaselineMinutes),
            remQ: stageQ(input.remMinutes, input.remBaselineMinutes),
            athlete: athlete
        )
        modelContext.insert(record)
    }

    // MARK: - Sleep v2 shadow joins (Phase S3 — the §6 deferred outcome joins, H-39)

    /// Fill the §6 morning and evening join fields on stored `SleepShadowNight` rows from
    /// PERSISTED day-keyed records — the `ShadowAnalyticsService.resolveOutcomes` target-day
    /// discipline (D-03), never a live fetch:
    ///
    /// - **Morning join** (once the row's wake day has elapsed): the wake day's
    ///   `RecoverySnapshot` (HRV / RHR / baselines) + `WellnessCheckIn`, plus the H-38
    ///   sleep-free readiness proxy — `RecoveryScoreEngine.compute` with the sleep component
    ///   omitted (its documented missing-data path renormalizes the remaining weights) and
    ///   `recentScores: []` so the trend modifier (whose history contains sleep) is zero;
    ///   `baseScore` is stored. The proxy's wellness arm is REBUILT from the check-in's
    ///   sleep-free sub-ratings (soreness + energy + stress rescaled to 0–100) — the
    ///   composite `wellnessScore` contains `sleepQuality`, a subjective rating of the
    ///   tested night, which would leak the tested signal into the "sleep-free" outcome
    ///   (H-38 revision). Were only a composite available, wellness would be EXCLUDED
    ///   from the proxy (HRV + RHR only); this join always has the row, so the
    ///   reconstruction is always possible. With no scorable component the proxy stays
    ///   nil — the engine's neutral 50 would fabricate an outcome.
    /// - **Evening join** (once wake day + 1 has ALSO elapsed, because the felt-right
    ///   self-report is write-once on the next calendar day): the wake day's
    ///   highest-`trainingStress` session's RPE, the wake day's `VerdictEvent` existence,
    ///   and its `feltRightRaw`. A missed report stays nil — absence is the record.
    ///
    /// Joins are stamped (`morningJoinedAt` / `eveningJoinedAt`) even when the joined
    /// values are nil, so a data-less day is not re-scanned forever. Non-throwing; every
    /// error degrades silently (shadow rule). Internal, with `now` injected, so the join
    /// windows are testable.
    static func runSleepShadowJoins(
        athlete: Athlete,
        modelContext: ModelContext,
        now: Date = .now,
        calendar: Calendar = Calendar.current
    ) {
        do {
            let today = calendar.startOfDay(for: now)
            let athleteId = athlete.id

            // Predicate on the PENDING set (nil-stamp checks are predicate-safe), so a
            // long-run store never re-fetches every joined row; the athlete filter stays
            // Swift-side (the optional-relationship #Predicate trap).
            let pendingDescriptor = FetchDescriptor<SleepShadowNight>(
                predicate: #Predicate {
                    $0.morningJoinedAt == nil || $0.eveningJoinedAt == nil
                }
            )
            let pending = try modelContext.fetch(pendingDescriptor)
                .filter { $0.athlete?.id == athleteId }
            guard !pending.isEmpty else { return }

            var changed = false
            for row in pending {
                let wakeDay = calendar.startOfDay(for: row.wakeDate)
                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: wakeDay),
                      let eveningCutoff = calendar.date(byAdding: .day, value: 2, to: wakeDay)
                else { continue }

                if row.morningJoinedAt == nil, wakeDay < today {
                    joinMorning(
                        row: row, wakeDay: wakeDay, nextDay: nextDay,
                        athleteId: athleteId, modelContext: modelContext, now: now
                    )
                    changed = true
                }
                if row.eveningJoinedAt == nil, eveningCutoff <= today {
                    joinEvening(
                        row: row, wakeDay: wakeDay, nextDay: nextDay,
                        athleteId: athleteId, modelContext: modelContext, now: now
                    )
                    changed = true
                }
            }
            if changed {
                try modelContext.save()
            }
        } catch {
            print("Sleep shadow join error: \(error)")
        }
    }

    /// The §6 morning join for one row (see `runSleepShadowJoins`). Date-only predicates;
    /// athlete filtered in Swift.
    private static func joinMorning(
        row: SleepShadowNight,
        wakeDay: Date,
        nextDay: Date,
        athleteId: UUID,
        modelContext: ModelContext,
        now: Date
    ) {
        let snapDescriptor = FetchDescriptor<RecoverySnapshot>(
            predicate: #Predicate { $0.date >= wakeDay && $0.date < nextDay }
        )
        let snapshot = ((try? modelContext.fetch(snapDescriptor)) ?? [])
            .filter { $0.athlete?.id == athleteId }
            .max { $0.updatedAt < $1.updatedAt }

        let checkInDescriptor = FetchDescriptor<WellnessCheckIn>(
            predicate: #Predicate { $0.date >= wakeDay && $0.date < nextDay }
        )
        let checkIn = ((try? modelContext.fetch(checkInDescriptor)) ?? [])
            .filter { $0.athlete?.id == athleteId }
            .max { $0.date < $1.date }

        row.nextMorningHRV = snapshot?.hrvSDNN
        row.nextMorningRHR = snapshot?.restingHR
        // The audit field keeps the full composite; ONLY the proxy strips sleepQuality.
        row.nextMorningWellness = checkIn?.wellnessScore

        // H-38 (revised): the proxy's wellness arm must contain NO sleepQuality — the
        // composite `wellnessScore` is 25% a subjective rating of the tested night, and
        // feeding it in would bias criterion 1 anti-conservatively. Reconstruct a
        // sleep-free wellness from the raw sub-ratings (soreness + energy + stress,
        // rescaled to 0–100, each rated 1–5).
        let sleepFreeWellness = checkIn.map {
            Double($0.soreness + $0.energy + $0.stress) / 15.0 * 100.0
        }

        // H-38: the sleep-free readiness proxy — never a fabricated neutral 50.
        if snapshot != nil || sleepFreeWellness != nil {
            let proxy = RecoveryScoreEngine.compute(
                input: RecoveryScoreEngine.RecoveryInput(
                    hrvSDNN: snapshot?.hrvSDNN,
                    restingHR: snapshot?.restingHR,
                    sleepDurationMinutes: nil,
                    wellnessScore: sleepFreeWellness,
                    hrvBaseline: snapshot?.hrvBaseline,
                    restingHRBaseline: snapshot?.restingHRBaseline,
                    recentScores: []
                )
            )
            let hasComponent = proxy.hrvContribution != nil
                || proxy.rhrContribution != nil
                || proxy.wellnessContribution != nil
            row.sleepFreeReadiness = hasComponent ? proxy.baseScore : nil
        }

        row.morningJoinedAt = now
        row.updatedAt = now
    }

    /// The §6 evening join for one row (see `runSleepShadowJoins`). Date-only predicates;
    /// athlete filtered in Swift.
    private static func joinEvening(
        row: SleepShadowNight,
        wakeDay: Date,
        nextDay: Date,
        athleteId: UUID,
        modelContext: ModelContext,
        now: Date
    ) {
        let sessionDescriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.sessionDate >= wakeDay && $0.sessionDate < nextDay }
        )
        let mainSession = ((try? modelContext.fetch(sessionDescriptor)) ?? [])
            .filter { $0.athlete?.id == athleteId }
            .max { $0.trainingStress < $1.trainingStress }
        row.eveningSessionRPE = mainSession?.sessionRPE

        let verdictDescriptor = FetchDescriptor<VerdictEvent>(
            predicate: #Predicate { $0.planDate >= wakeDay && $0.planDate < nextDay }
        )
        let verdict = ((try? modelContext.fetch(verdictDescriptor)) ?? [])
            .filter { $0.athlete?.id == athleteId }
            .max { $0.decidedAt < $1.decidedAt }
        row.eveningVerdictIssued = verdict != nil
        row.eveningFeltRightRaw = verdict?.feltRightRaw

        row.eveningJoinedAt = now
        row.updatedAt = now
    }

    /// Read the `sleepV2*` fields of the @Model into the builder's value mirror.
    /// Dumb mapping only — every rule lives in `SleepStateBuilder` (§6.3 carrier contract).
    private static func sleepV2Mirror(of row: BaselineState) -> SleepStateBuilder.State {
        SleepStateBuilder.State(
            deepMu: row.sleepV2DeepMu,
            deepCount: row.sleepV2DeepCount,
            remMu: row.sleepV2RemMu,
            remCount: row.sleepV2RemCount,
            dominantSourceID: row.sleepV2DominantSourceID,
            nightsSinceSourceChange: row.sleepV2NightsSinceSourceChange,
            midpointBuffer: row.sleepV2MidpointBuffer,
            irregularFlags14: row.sleepV2IrregularFlags14,
            nightsSinceRhythmBreak: row.sleepV2NightsSinceRhythmBreak,
            nightsBelowChronicExitSD: row.sleepV2NightsBelowChronicExitSD,
            deficitBuffer7: row.sleepV2DeficitBuffer7,
            tstBuffer: row.sleepV2TSTBuffer,
            needBaseMinutes: row.sleepV2NeedBaseMinutes,
            needUpdatedAt: row.sleepV2NeedUpdatedAt,
            needFrozen: row.sleepV2NeedFrozen,
            nightsOfHistory: row.sleepV2NightsOfHistory,
            previousProfilesRaw: row.sleepV2PreviousProfilesRaw,
            lastSleepEndDate: row.sleepV2LastSleepEndDate,
            lastFoldedDate: row.sleepV2LastFoldedDate,
            priorWakeBuffer: row.sleepV2PriorWakeBuffer
        )
    }

    /// Write a folded mirror back onto the @Model. Dumb mapping only.
    private static func applySleepV2(_ state: SleepStateBuilder.State, to row: BaselineState) {
        row.sleepV2DeepMu = state.deepMu
        row.sleepV2DeepCount = state.deepCount
        row.sleepV2RemMu = state.remMu
        row.sleepV2RemCount = state.remCount
        row.sleepV2DominantSourceID = state.dominantSourceID
        row.sleepV2NightsSinceSourceChange = state.nightsSinceSourceChange
        row.sleepV2MidpointBuffer = state.midpointBuffer
        row.sleepV2IrregularFlags14 = state.irregularFlags14
        row.sleepV2NightsSinceRhythmBreak = state.nightsSinceRhythmBreak
        row.sleepV2NightsBelowChronicExitSD = state.nightsBelowChronicExitSD
        row.sleepV2DeficitBuffer7 = state.deficitBuffer7
        row.sleepV2TSTBuffer = state.tstBuffer
        row.sleepV2NeedBaseMinutes = state.needBaseMinutes
        row.sleepV2NeedUpdatedAt = state.needUpdatedAt
        row.sleepV2NeedFrozen = state.needFrozen
        row.sleepV2NightsOfHistory = state.nightsOfHistory
        row.sleepV2PreviousProfilesRaw = state.previousProfilesRaw
        row.sleepV2LastSleepEndDate = state.lastSleepEndDate
        row.sleepV2LastFoldedDate = state.lastFoldedDate
        row.sleepV2PriorWakeBuffer = state.priorWakeBuffer
    }
    // MARK: - Recovery estimator v2 shadow — checkpoint mirrors + the dual-run fold
    //
    // Placed AFTER `runSleepV2Shadow` deliberately: `BaselineTierFenceTests` defines the
    // sanctioned shadow region as everything from that declaration onward, and greps the
    // slice before it for substrate symbols. This code is genuinely shadow-only, so it
    // belongs inside that region — the fence caught it sitting above the line and the
    // answer was to move the code, never to widen the fence.

    // MARK: - Baseline checkpoint mirrors (HRV / RHR generic sub-state)

    /// Read one signal's persisted checkpoint out of the `@Model` row into plain values.
    ///
    /// `sealedThroughDay` and `sealedDayCount` are NOT stored separately — the signal state
    /// already carries them exactly (`lastBucketedDate` and `count`), and a second copy could
    /// disagree with the first.
    private static func checkpointMirror(
        of row: BaselineState,
        signal: CheckpointSignal
    ) -> BaselineCheckpoint.Stored {
        var state = BaselineEngine.SignalState()
        switch signal {
        case .hrv:
            state.mu = row.hrvMu
            state.welfordMean = row.hrvWelfordMean
            state.m2 = row.hrvM2
            state.count = row.hrvCount
            state.madBuffer = row.hrvMadBuffer
            state.lastBucketedDate = row.hrvLastBucketedDate
            state.cvRatio = row.hrvCvRatio
            state.cvLevel = BaselineEngine.CVWarning(rawValue: row.hrvCvLevelRaw) ?? .normal
            state.confidence = row.hrvConfidence
        case .rhr:
            state.mu = row.rhrMu
            state.welfordMean = row.rhrWelfordMean
            state.m2 = row.rhrM2
            state.count = row.rhrCount
            state.madBuffer = row.rhrMadBuffer
            state.lastBucketedDate = row.rhrLastBucketedDate
            state.cvRatio = row.rhrCvRatio
            state.cvLevel = BaselineEngine.CVWarning(rawValue: row.rhrCvLevelRaw) ?? .normal
            state.confidence = row.rhrConfidence
        }
        return BaselineCheckpoint.Stored(
            state: state,
            sealedThroughDay: state.lastBucketedDate,
            sealedDayCount: state.count,
            schemaVersion: row.baselineCheckpointVersion
        )
    }

    /// Write one signal's advanced checkpoint back to the `@Model` row.
    private static func applyCheckpoint(
        _ stored: BaselineCheckpoint.Stored,
        to row: BaselineState,
        signal: CheckpointSignal
    ) {
        let state = stored.state
        switch signal {
        case .hrv:
            row.hrvMu = state.mu
            row.hrvWelfordMean = state.welfordMean
            row.hrvM2 = state.m2
            row.hrvCount = state.count
            row.hrvMadBuffer = state.madBuffer
            row.hrvLastBucketedDate = state.lastBucketedDate
            row.hrvCvRatio = state.cvRatio
            row.hrvCvLevelRaw = state.cvLevel.rawValue
            row.hrvConfidence = state.confidence
        case .rhr:
            row.rhrMu = state.mu
            row.rhrWelfordMean = state.welfordMean
            row.rhrM2 = state.m2
            row.rhrCount = state.count
            row.rhrMadBuffer = state.madBuffer
            row.rhrLastBucketedDate = state.lastBucketedDate
            row.rhrCvRatio = state.cvRatio
            row.rhrCvLevelRaw = state.cvLevel.rawValue
            row.rhrConfidence = state.confidence
        }
        row.baselineCheckpointVersion = stored.schemaVersion
    }

    private enum CheckpointSignal { case hrv, rhr }

    /// The athlete's `BaselineState` row, created on first use.
    ///
    /// Fetch-all + filter in Swift: traversing the optional to-one `athlete` relationship
    /// inside a `#Predicate` crashes SwiftData rather than throwing (the trap this file's
    /// sleep-v2 fold already documents, and which bit `RecoveryRepository` for real).
    private static func baselineStateRow(
        for athlete: Athlete,
        modelContext: ModelContext
    ) throws -> BaselineState {
        let athleteId = athlete.id
        let all = try modelContext.fetch(FetchDescriptor<BaselineState>())
        if let existing = all.first(where: { $0.athlete?.id == athleteId }) {
            return existing
        }
        let fresh = BaselineState(athlete: athlete)
        modelContext.insert(fresh)
        return fresh
    }

    // MARK: - Recovery estimator v2 shadow (never driving)

    /// Record today's v1-vs-v2 recovery comparison.
    ///
    /// The v2 arm rescoring HRV and RHR from a robust personal z would move every number the
    /// athlete has seen, so per the 2026-05-30 approved scope it runs dark until parity is
    /// reviewed by a human. This is the evidence for that review.
    ///
    /// Discipline, all deliberate:
    /// - Called after the live score is computed AND persisted, so it cannot influence it.
    /// - **Both stored scores are pre-trend** (`baseScore`). v1's trend modifier is an
    ///   autoregression on its own past output; including it would confound an estimator
    ///   change with accumulated inertia.
    /// - Every failure is swallowed — a shadow must never break the pipeline.
    /// - Upserts on (athlete, day), so repeated runs in a day refine one row rather than
    ///   accumulating duplicates.
    private static func runRecoveryShadow(
        athlete: Athlete,
        hrvReduced: ReadinessInputReducer.Reduced?,
        rhrReduced: ReadinessInputReducer.Reduced?,
        sleepMinutes: Double?,
        wellnessScore: Double?,
        liveResult: RecoveryScoreEngine.RecoveryResult,
        hrvBaseline: Double?,
        rhrBaseline: Double?,
        wristTempC: Double?,
        respiratoryRate: Double?,
        now: Date,
        calendar: Calendar,
        modelContext: ModelContext
    ) {
        do {
            guard let hrvReduced, let rhrReduced else { return }
            let day = calendar.startOfDay(for: now)

            // Baselines resume from a saved checkpoint plus a replayed tail rather than being
            // re-walked from the fetch window. Two things this buys, both real: days beyond
            // the fetch window keep counting (`BaselineEngine.confidence` ramps toward 60
            // days, so a window-bounded fold could never express a settled baseline), and a
            // gap in app usage is a non-event because the unfolded days are simply still in
            // the tail. `BaselineCheckpoint` documents why the tail is replayed rather than
            // trusted.
            let stateRow = try baselineStateRow(for: athlete, modelContext: modelContext)
            let hrvCheckpoint = BaselineCheckpoint.advance(
                stored: checkpointMirror(of: stateRow, signal: .hrv),
                days: hrvReduced.priorDatedDays.map {
                    BaselineCheckpoint.DayValue(day: $0.day, value: $0.value)
                },
                config: .hrv,
                now: now,
                calendar: calendar
            )
            let rhrCheckpoint = BaselineCheckpoint.advance(
                stored: checkpointMirror(of: stateRow, signal: .rhr),
                days: rhrReduced.priorDatedDays.map {
                    BaselineCheckpoint.DayValue(day: $0.day, value: $0.value)
                },
                config: .rhr,
                now: now,
                calendar: calendar
            )
            applyCheckpoint(hrvCheckpoint.checkpoint, to: stateRow, signal: .hrv)
            applyCheckpoint(rhrCheckpoint.checkpoint, to: stateRow, signal: .rhr)
            stateRow.updatedAt = .now

            let hrvOutcome = RecoveryShadowEngine.evaluate(
                today: hrvReduced.today,
                state: hrvCheckpoint.workingState,
                config: .hrv
            )
            let rhrOutcome = RecoveryShadowEngine.evaluate(
                today: rhrReduced.today,
                state: rhrCheckpoint.workingState,
                config: .rhr
            )
            let v2Score = RecoveryShadowEngine.compositeScore(
                hrvComponent: hrvOutcome.component,
                rhrComponent: rhrOutcome.component,
                // Sleep and wellness are carried over from the live arm untouched, so the only
                // difference under test is the HRV/RHR estimator.
                sleepComponent: liveResult.sleepContribution,
                wellnessComponent: liveResult.wellnessContribution
            )

            // Today's blinded probe, if the athlete answered one before any score rendered.
            // Date-only predicate + Swift-side athlete filter (the optional-relationship trap).
            let probe = (try? modelContext.fetch(
                FetchDescriptor<MorningReadinessProbe>(predicate: #Predicate { $0.date == day })
            ))?.first(where: { $0.athlete?.id == athlete.id })

            let athleteId = athlete.id
            let descriptor = FetchDescriptor<RecoveryShadowDay>(
                predicate: #Predicate { $0.date == day }
            )
            let existing = ((try? modelContext.fetch(descriptor)) ?? [])
                .filter { $0.athlete?.id == athleteId }
            for stale in existing {
                modelContext.delete(stale)
            }

            let record = RecoveryShadowDay(
                date: day,
                hrvToday: hrvReduced.today,
                rhrToday: rhrReduced.today,
                sleepMinutes: sleepMinutes,
                wellnessScore: wellnessScore,
                hrvPriorDayCount: hrvReduced.priorDays.count,
                rhrPriorDayCount: rhrReduced.priorDays.count,
                v1BaseScore: liveResult.baseScore,
                v1HrvComponent: liveResult.hrvContribution,
                v1RhrComponent: liveResult.rhrContribution,
                v1SleepComponent: liveResult.sleepContribution,
                v1WellnessComponent: liveResult.wellnessContribution,
                v1HrvBaseline: hrvBaseline,
                v1RhrBaseline: rhrBaseline,
                v2BaseScore: v2Score,
                v2HrvComponent: hrvOutcome.component,
                v2RhrComponent: rhrOutcome.component,
                hrvZ: hrvOutcome.z,
                rhrZ: rhrOutcome.z,
                hrvMu: hrvOutcome.mu,
                rhrMu: rhrOutcome.mu,
                hrvConfidence: hrvOutcome.confidence,
                // Held-out evidence, recorded beside the two arms and fed to neither.
                outcomeWristTempC: wristTempC,
                outcomeRespiratoryRate: respiratoryRate,
                outcomePerceivedReadiness: probe?.perceivedReadiness,
                outcomeGripStrengthKg: probe?.gripStrengthKg,
                outcomeGripHandRaw: probe?.gripHandRaw,
                // Defaults to false: absent a probe there is nothing blinded to claim.
                outcomeWasBlinded: probe?.wasBlinded ?? false
            )
            record.athlete = athlete
            modelContext.insert(record)
            try modelContext.save()
        } catch {
            print("Recovery shadow error: \(error)")
        }
    }

}
