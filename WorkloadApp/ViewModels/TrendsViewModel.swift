import Foundation
import SwiftData
import SwiftUI

/// The Trends range rail (v1.7.3 · UAT round 1 · U9).
///
/// The windows changed with the page's question. The retired Load tab asked "how has my load
/// moved" and offered 4W / 12W / 6M; the re-scoped page asks "what have the last weeks added up
/// to in my fatigue budget", and that question is answered over a fortnight, not a half-year —
/// the fatigue model's own windows are 14 days (session density, wellness trend) and 7 days
/// (recovery trend), so a six-month rail was plotting a number whose inputs never reached back
/// that far.
enum TimeRange: String, CaseIterable, Identifiable {
    case oneWeek = "1W"
    case twoWeeks = "2W"
    case oneMonth = "1M"

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .oneWeek: return 7
        case .twoWeeks: return 14
        case .oneMonth: return 30
        }
    }

    /// The rail's label — the working voice spells the window out ("2 weeks"), because the rail
    /// is something the app says, not marginalia. `rawValue` stays the stable identity.
    var label: LocalizedStringKey {
        switch self {
        case .oneWeek: return "trends.range.oneWeek"
        case .twoWeeks: return "trends.range.twoWeeks"
        case .oneMonth: return "trends.range.oneMonth"
        }
    }
}

/// ViewModel for the Trends tab, re-scoped in v1.7.3 (UAT round 1 · U9) around the fatigue
/// narrative.
///
/// **What it stopped owning.** The HRV and sleep glance series are gone. Today prints both
/// readings and every one of its three metric cells now pushes a detail screen, so re-plotting
/// the same two lines one tab away was the page spending its whole first screen on data the
/// athlete had already seen — and saying nothing about what any of it added up to.
///
/// **What it owns instead.** The fatigue accumulation series (`FatigueHistoryEngine`, run over
/// history the app already persists), its trajectory, and the session-density read behind
/// "what you did". The load trend, the Pro recovery-vs-load window, the insight engines and the
/// PR/check-in histories are carried over unchanged.
///
/// The zoomed detail screens are NOT fed from here — `HRVDetailScreen` / `RHRDetailScreen` /
/// `SleepDetailScreen` own their fetches (one fetch path for one screen).
@MainActor
@Observable
final class TrendsViewModel {

    // MARK: Fatigue narrative (U9 — the page's spine)

    /// The accumulation series across `selectedRange`, oldest first. Empty when there is not
    /// enough history to draw one; the view says so rather than plotting a warm-up.
    var fatiguePoints: [FatigueHistoryEngine.Point] = []
    /// Whole calendar days of session history the athlete actually has — the numerator of the
    /// "not enough history yet" state.
    var observedHistoryDays: Int = 0
    /// Sessions inside the selected window.
    var sessionsInRange: Int = 0
    /// The athlete's OWN average number of sessions for a window this long, from up to 90 days
    /// of history. Nil until there is any history to average.
    var baselineSessionsInRange: Double?
    /// One bar per day of the window: that day's summed training stress, oldest first. Days
    /// with no session are present with zero, so the rhythm of rest days is visible.
    var dailyLoadBars: [(date: Date, load: Double)] = []
    /// Session counts by type inside the window, most frequent first — the "strength 5 · skill
    /// 3" line. Counts of stored sessions, nothing derived.
    var sessionTypeCounts: [(type: SessionType, count: Int)] = []
    /// The window's ACWR span, for the held-range sentence. Nil when the window has no
    /// workload snapshots.
    var acwrRange: (low: Double, high: Double)?
    /// The most recent workload snapshot inside the window — the load section's reading.
    var latestLoadSnapshot: WorkloadSnapshot?

    /// 28-day recovery history — the insights-encouragement guard reads its count.
    var recoveryHistory: [RecoverySnapshot] = []

    // Fatigue insights (INTEL-04, INTEL-05)
    var fatigueInsights: [FatiguePatternEngine.Insight] = []

    // Behavior correlations (INTEL-07)
    var behaviorCorrelations: [BehaviorCorrelationEngine.TagCorrelation] = []
    var behaviorSufficiency: [BehaviorCorrelationEngine.SufficiencyInfo] = []

    // MARK: Load-side trend state (from WorkloadViewModel)

    /// The load chart's data itself derives in the VIEW from its reactive `@Query` + the
    /// free-tier filter (`visibleSnapshots`), exactly as the retired Load tab built it — a
    /// range change re-slices without a fetch.
    ///
    /// Defaults to a fortnight: it is the fatigue model's own window, and it is what a free
    /// athlete sees, since the rail itself stays Pro (gating carried over verbatim).
    var selectedRange: TimeRange = .twoWeeks
    var correlationLoadSnapshots: [WorkloadSnapshot] = []
    var correlationRecoverySnapshots: [RecoverySnapshot] = []

    var isLoading = false

    /// The trajectory of the drawn series, or nil when there is no series.
    var trajectory: FatigueHistoryEngine.Trajectory? {
        FatigueHistoryEngine.trajectory(fatiguePoints)
    }

    /// Consecutive days at the end of the window on which fatigue did not come down.
    var daysWithoutRelief: Int {
        FatigueHistoryEngine.daysWithoutRelief(fatiguePoints)
    }

    /// True once the athlete has enough history for the accumulation chart to mean anything.
    var hasEnoughHistory: Bool {
        observedHistoryDays >= FatigueHistoryEngine.minimumHistoryDays && !fatiguePoints.isEmpty
    }

    /// Full load: the fatigue series, the density read, the load windows, the insight engines.
    /// Idempotent — the view calls it on task, on scene activation, on day change and on a
    /// range change (`.task` runs once per appearance, so an overnight background otherwise
    /// leaves yesterday rendered as today).
    func load(
        athlete: Athlete,
        healthKitService: any HealthDataProviding,
        modelContext: ModelContext
    ) async {
        isLoading = true

        let calendar = Calendar.current
        let recoveryRepo = RecoveryRepository(modelContext: modelContext)
        let workloadRepo = WorkloadRepository(modelContext: modelContext)
        let workoutRepo = WorkoutRepository(modelContext: modelContext)

        recoveryHistory = (try? recoveryRepo.fetchRecoveryHistory(days: 28, athlete: athlete)) ?? []

        // 90 days is the fatigue engine's own baseline reach (`baselineSessionsPer14Days`
        // caps there), so it is the widest history any point in the series can consult —
        // fetching more would change nothing.
        let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: .now)!
        let sessions = (try? workoutRepo.fetchSessions(from: ninetyDaysAgo, to: .now, athlete: athlete)) ?? []
        let workloadSnapshots = (try? workloadRepo.fetchSnapshots(from: ninetyDaysAgo, to: .now, athlete: athlete)) ?? []
        let recoverySnaps = (try? recoveryRepo.fetchSnapshots(from: ninetyDaysAgo, to: .now, athlete: athlete)) ?? []

        buildFatigueNarrative(
            athlete: athlete,
            sessions: sessions,
            recoverySnapshots: recoverySnaps,
            workloadSnapshots: workloadSnapshots,
            modelContext: modelContext,
            calendar: calendar
        )

        // Correlation windows — always 28 days (the Recovery-vs-Load chart's contract).
        correlationLoadSnapshots = (try? workloadRepo.fetchSnapshots(last: 28, athlete: athlete)) ?? []
        correlationRecoverySnapshots = recoveryHistory

        // Fatigue pattern detection (INTEL-04, INTEL-05)
        fatigueInsights = FatiguePatternEngine.detectPatterns(
            workloadSnapshots: workloadSnapshots,
            recoverySnapshots: recoverySnaps,
            sessions: sessions
        )

        // Behavior correlation (INTEL-07)
        let behaviorTagRepo = BehaviorTagRepository(modelContext: modelContext)
        let allTags = (try? behaviorTagRepo.fetchAllTags(days: 90, athlete: athlete)) ?? []
        if !allTags.isEmpty {
            behaviorCorrelations = BehaviorCorrelationEngine.computeCorrelations(
                tags: allTags,
                recoverySnapshots: recoverySnaps
            )
            behaviorSufficiency = BehaviorCorrelationEngine.checkSufficiency(tags: allTags, recoverySnapshots: recoverySnaps)
        }

        isLoading = false
    }

    // MARK: - The fatigue narrative

    /// Reduce the fetched models to the engine's value types and run the series.
    ///
    /// The series reads the athlete's FULL history, not the free-tier-filtered arrays. Today's
    /// fatigue banner already does — so filtering here would make one tab contradict the other
    /// about the same number on the same day, which is a defect, not a paywall. The gates that
    /// exist stay exactly where they are: the load snapshots keep their free-tier filter and
    /// teaser, the range rail and the recovery-vs-load chart stay Pro.
    private func buildFatigueNarrative(
        athlete: Athlete,
        sessions: [WorkoutSession],
        recoverySnapshots: [RecoverySnapshot],
        workloadSnapshots: [WorkloadSnapshot],
        modelContext: ModelContext,
        calendar: Calendar
    ) {
        let now = Date.now
        let today = calendar.startOfDay(for: now)
        let windowDays = selectedRange.days

        let sessionPoints = sessions.map {
            FatigueHistoryEngine.SessionPoint(date: $0.sessionDate, trainingStress: $0.trainingStress)
        }

        observedHistoryDays = sessionPoints
            .map { calendar.startOfDay(for: $0.date) }
            .min()
            .map { (calendar.dateComponents([.day], from: $0, to: today).day ?? 0) + 1 }
            ?? 0

        // Wellness over the widest window any point in the series can read (the engine's
        // 14-day wellness window, measured from the OLDEST day drawn).
        let wellnessStart = calendar.date(byAdding: .day, value: -(windowDays + 14), to: today) ?? today
        let wellnessDescriptor = FetchDescriptor<WellnessCheckIn>(
            predicate: #Predicate<WellnessCheckIn> { $0.date >= wellnessStart },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        // Athlete filtered in Swift, not in the predicate — traversing the optional to-one
        // `athlete` relationship inside a `#Predicate` is the documented SIGABRT shape.
        let athleteId = athlete.id
        let wellnessScores = ((try? modelContext.fetch(wellnessDescriptor)) ?? [])
            .filter { $0.athlete?.id == athleteId }
            .map { FatigueHistoryEngine.DayScore(date: $0.date, value: $0.wellnessScore) }

        let recoveryScores = recoverySnapshots.map {
            FatigueHistoryEngine.DayScore(date: $0.date, value: $0.recoveryScore)
        }

        let niggleLogs = SorenessLogRepository(modelContext: modelContext)
            .fetchRecent(days: windowDays + NiggleInjuryDeriver.injuryWindowDays, athlete: athlete)

        fatiguePoints = FatigueHistoryEngine.series(
            sessions: sessionPoints,
            recoveryScores: recoveryScores,
            wellnessScores: wellnessScores,
            qualifyingInjuryDates: NiggleInjuryDeriver.qualifyingDates(logs: niggleLogs),
            days: windowDays,
            asOf: now,
            calendar: calendar
        )

        buildActivityRead(
            sessions: sessions,
            sessionPoints: sessionPoints,
            workloadSnapshots: workloadSnapshots,
            windowDays: windowDays,
            today: today,
            calendar: calendar
        )
    }

    /// The "what you did" read and the load section's numbers — counts and stored values only.
    private func buildActivityRead(
        sessions: [WorkoutSession],
        sessionPoints: [FatigueHistoryEngine.SessionPoint],
        workloadSnapshots: [WorkloadSnapshot],
        windowDays: Int,
        today: Date,
        calendar: Calendar
    ) {
        let windowStart = calendar.date(byAdding: .day, value: -(windowDays - 1), to: today) ?? today
        let inWindow = sessions.filter { calendar.startOfDay(for: $0.sessionDate) >= windowStart }

        sessionsInRange = inWindow.count

        // The athlete's own density, scaled from the engine's 14-day unit to this window —
        // one formula, not a second one, so the density the chart implies and the density the
        // fatigue model scores are the same statement.
        baselineSessionsInRange = FatigueIndexEngine
            .baselineSessionsPer14Days(sessionDates: sessionPoints.map(\.date), asOf: today, calendar: calendar)
            .map { $0 / 14.0 * Double(windowDays) }

        var loadByDay: [Date: Double] = [:]
        for session in inWindow {
            let day = calendar.startOfDay(for: session.sessionDate)
            loadByDay[day, default: 0] += session.trainingStress
        }
        dailyLoadBars = stride(from: 0, to: windowDays, by: 1).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: windowStart) else { return nil }
            return (date: day, load: loadByDay[day] ?? 0)
        }

        sessionTypeCounts = Dictionary(grouping: inWindow, by: \.sessionType)
            .map { (type: $0.key, count: $0.value.count) }
            .sorted { ($0.count, $0.type.rawValue) > ($1.count, $1.type.rawValue) }

        let snapshotsInWindow = workloadSnapshots
            .filter { calendar.startOfDay(for: $0.snapshotDate) >= windowStart }
        latestLoadSnapshot = snapshotsInWindow.max { $0.snapshotDate < $1.snapshotDate }
        let ratios = snapshotsInWindow.map(\.acwr).filter { $0 > 0 }
        if let low = ratios.min(), let high = ratios.max() {
            acwrRange = (low: low, high: high)
        } else {
            acwrRange = nil
        }
    }
}
