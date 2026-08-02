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
    static func run(
        athlete: Athlete,
        healthKitService: HealthKitService,
        modelContext: ModelContext,
        syncService: SyncService? = nil
    ) async throws -> RecoveryResult {
        let recoveryRepo = RecoveryRepository(modelContext: modelContext)

        // 1. Fetch HealthKit data (staleness-aware)
        var hrv: Double?
        var rhr: Double?
        var sleep: Double?
        var bodyTemp: Double?
        var vo2Max: Double?
        var hrvDate: Date?
        var rhrDate: Date?
        var sleepDate: Date?

        // Attempt reads whenever HealthKit is available AND the user has requested access.
        // Absence of data is treated as "no recent data" downstream, never as "unauthorized".
        if healthKitService.isAvailable && healthKitService.hasRequestedAccess {
            let hrvResult = try? await healthKitService.fetchLatestHRVWithDate()
            hrv = hrvResult?.value
            hrvDate = hrvResult?.date

            let rhrResult = try? await healthKitService.fetchLatestRestingHRWithDate()
            rhr = rhrResult?.value
            rhrDate = rhrResult?.date

            let sleepResult = try? await healthKitService.fetchLastNightSleepWithDate()
            sleep = sleepResult?.value
            sleepDate = sleepResult?.date

            bodyTemp = try? await healthKitService.fetchLatestBodyTemp()
            vo2Max = try? await healthKitService.fetchLatestVO2Max()

            // Reflect the LATEST full read cycle: data present → .connected; nothing returned →
            // .requestedNoData (e.g. access revoked in Settings, or no recent samples). This is an
            // authoritative cycle (all reads attempted), so it may downgrade a stale .connected.
            // hasRequestedAccess stays sticky, so the connect CTA never reappears.
            healthKitService.updateObservedData(hrv != nil || rhr != nil || sleep != nil)
        }

        let staleness = HealthKitStaleness(lastHRVDate: hrvDate, lastSleepDate: sleepDate, lastRHRDate: rhrDate)

        // 2. Fetch 7-day history for baselines
        let recoveryHistory = try recoveryRepo.fetchRecoveryHistory(days: 7, athlete: athlete)
        let hrvValues = recoveryHistory.compactMap(\.hrvSDNN)
        let rhrValues = recoveryHistory.compactMap(\.restingHR)
        let hrvBaseline = RecoveryScoreEngine.computeBaseline(values: hrvValues)
        let rhrBaseline = RecoveryScoreEngine.computeBaseline(values: rhrValues)

        // 3. Fetch today's wellness check-in
        let todayCheckIn = try recoveryRepo.fetchTodayWellnessCheckIn(athlete: athlete)
        let wellnessScore = todayCheckIn?.wellnessScore

        // 4. Compute recovery score (with trend from recent history)
        let recentScores = recoveryHistory
            .sorted { $0.date < $1.date }
            .map(\.recoveryScore)
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
            athlete: athlete
        )

        // 6. Sleep score v2 — SHADOW fold (Phase S2). Computed and recorded, NEVER driving:
        // the live recovery score above is already final, and nothing below can throw out
        // of the pipeline (CrossModalShadowGate is the run-dark precedent).
        await runSleepV2Shadow(
            athlete: athlete,
            healthKitService: healthKitService,
            modelContext: modelContext
        )

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

    // MARK: - Sleep v2 shadow (Phase S2 — computed + logged, never driving)

    /// Run the sleep-v2 shadow computation for last night: fetch stage detail, assemble the
    /// engine input from the carried `BaselineState` sleep-v2 sub-state (prequential —
    /// through t−1), score, fold the night back into the carrier, and LOG the result.
    ///
    /// - The live recovery score is untouched — this is a shadow, per PLAN Phase S2 and the
    ///   `CrossModalShadowGate` run-dark precedent.
    /// - Storage: `RecoverySnapshot` carries no shadow/diagnostic fields today, so the
    ///   per-night result is logged via the existing print pattern; snapshot-side
    ///   persistence is Phase S3 (`ShadowMetrics`-style instrumentation).
    /// - All errors degrade silently to the existing behaviour: the method never throws and
    ///   catches everything internally (sleep v2 must never break the pipeline).
    /// - Once per wake day: the `sleepV2LastFoldedDate` monotonic cutoff (the W-1
    ///   idempotency contract) makes re-runs on the same day no-ops — and that cutoff is
    ///   checked BEFORE any HealthKit work (F4): the SwiftData read is a cheap local fetch,
    ///   the HealthKit query is the expensive part, so on every run after the day's first
    ///   fold the shadow exits without touching HealthKit. The shadow stays inline
    ///   otherwise (accepted latency decision: one HealthKit query on the first run of the
    ///   day — with F3's session keying, a same-day second fold attempt exits at this
    ///   pre-check because the fold stamps the wake day).
    /// - The fold key is the SESSION's wake day — `startOfDay(sessionEnd)` — never the run
    ///   date (F3a): a pipeline run after midnight must not re-bucket last night onto the
    ///   run day. Two further guards live in `SleepStateBuilder.shouldFold` (F3b/F3c):
    ///   session identity (`sessionEnd` must advance past the stored end) and the H-26
    ///   completeness hold (a session that ended < 120 min ago may still be ongoing), so a
    ///   truncated 02:00 fetch never folds and the full night still folds later that day.
    private static func runSleepV2Shadow(
        athlete: Athlete,
        healthKitService: HealthKitService,
        modelContext: ModelContext
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

            guard let detail = try await healthKitService.fetchLastNightSleepDetail() else {
                // No asleep samples in the window — Tier E, no night to fold.
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

            // Prequential: score against the state through t−1, then fold tonight in.
            let input = SleepStateBuilder.makeInput(state: state, night: night, calendar: calendar)
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
            try modelContext.save()

            // The shadow record (S3 persists this; S2 logs it — see the doc comment).
            let scoreText = result.score.map { String(format: "%.1f", $0) } ?? "nil"
            let needText = result.needTonightMinutes.map { String(format: "%.0f", $0) } ?? "n/a"
            let profileText = result.activeProfiles.map(\.rawValue).joined(separator: "+")
            print(
                "Sleep v2 shadow: score=\(scoreText) tier=\(result.tier.rawValue) "
                + "profiles=\(profileText) need=\(needText)min "
                + String(format: "confidence=%.2f", result.confidence)
            )
        } catch {
            print("Sleep v2 shadow error: \(error)")
        }
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
            lastFoldedDate: row.sleepV2LastFoldedDate
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
    }
}
