import SwiftUI
import SwiftData

/// The ONE fetch path into the zoomed trend screens (v1.7.3 reorientation slice 3,
/// APP-REORIENTATION R7 / appendix §6).
///
/// Before the Trends merge, Home and the Recovery tab each ran their OWN 90-day HRV +
/// snapshot fetches (`DashboardViewModel.hrv90Days` / `RecoveryViewModel.hrvHistoryExtended`)
/// whose only consumers were these pushes — two query paths for one screen. Every
/// `TrendDestination` now lands here, and the screens own their data; the pure rendering
/// views (`HRVDetailView` / `SleepDetailView`) keep their data-in initializers untouched.
struct HRVDetailScreen: View {
    @Environment(AppContainer.self) private var container
    @Query private var athletes: [Athlete]
    @Query(sort: \RecoverySnapshot.date, order: .reverse)
    private var recoverySnapshots: [RecoverySnapshot]

    /// 90 days of DAILY morning-window values (`HRVDailyStats`), matching the pinch
    /// window's maximum — the same series both retired paths built.
    @State private var data: [(date: Date, value: Double)] = []
    @State private var rawSampleCount = 0

    var body: some View {
        HRVDetailView(data: data, rawSampleCount: rawSampleCount)
            .task { await load() }
    }

    private func load() async {
        // Day-bucket to the morning window BEFORE anything reads it: a Watch writes
        // several SDNN samples a day, so raw-sample statistics called ~1–2 days of
        // data "7-day" (v1.7.1). See `HRVDailyStats` for the reduction and its limits.
        let rawSamples = (try? await container.healthKitService.fetchHRVHistory(days: 90)) ?? []
        rawSampleCount = rawSamples.count
        data = HRVDailyStats
            .dailyValues(samples: rawSamples, days: 90)
            .map { (date: $0.date, value: $0.value) }
        #if DEBUG
        // SCREENSHOT_MODE: HealthKit unauthorized — derive the series from seeded
        // snapshots, which are already one value per day (no bucketing needed).
        if data.isEmpty,
           ProcessInfo.processInfo.arguments.contains("SCREENSHOT_MODE") {
            let athleteId = athletes.first?.id
            data = recoverySnapshots
                .filter { $0.athlete?.id == athleteId }
                .compactMap { snap in snap.hrvSDNN.map { (date: snap.date, value: $0) } }
                .sorted { $0.date < $1.date }
            rawSampleCount = data.count
        }
        #endif
    }
}

/// The resting-heart-rate screen's fetch (v1.7.3 · UAT round 1 · U9). It is the HRV screen's
/// twin with one reduction swapped: `RHRDailyStats` buckets ALL DAY, because Apple derives RHR
/// as a daily aggregate and an hour filter would admit or drop a day at random.
struct RHRDetailScreen: View {
    @Environment(AppContainer.self) private var container
    @Query private var athletes: [Athlete]
    @Query(sort: \RecoverySnapshot.date, order: .reverse)
    private var recoverySnapshots: [RecoverySnapshot]

    /// 90 days of DAILY values, matching the pinch window's maximum.
    @State private var data: [(date: Date, value: Double)] = []

    var body: some View {
        RHRDetailView(data: data)
            .task { await load() }
    }

    private func load() async {
        let rawSamples = (try? await container.healthKitService.fetchRestingHRHistory(days: 90)) ?? []
        data = RHRDailyStats
            .dailyValues(samples: rawSamples, days: 90)
            .map { (date: $0.date, value: $0.value) }
        #if DEBUG
        // SCREENSHOT_MODE: HealthKit unauthorized — derive the series from seeded snapshots,
        // which are already one value per day (no bucketing needed). The HRV screen's idiom.
        if data.isEmpty,
           ProcessInfo.processInfo.arguments.contains("SCREENSHOT_MODE") {
            let athleteId = athletes.first?.id
            data = recoverySnapshots
                .filter { $0.athlete?.id == athleteId }
                .compactMap { snap in snap.restingHR.map { (date: snap.date, value: $0) } }
                .sorted { $0.date < $1.date }
        }
        #endif
    }
}

/// `SleepDetailView` fetches its own HealthKit nights already; what callers were
/// duplicating was the 90-day snapshot FALLBACK window (pre-fix persisted values, used
/// only when HealthKit has no nights). That window is now built here, once, reactively.
struct SleepDetailScreen: View {
    @Query private var athletes: [Athlete]
    @Query(sort: \RecoverySnapshot.date, order: .reverse)
    private var recoverySnapshots: [RecoverySnapshot]

    /// Oldest-first 90-day window — the same shape `RecoveryView.sleepWindowExtended`
    /// and `DashboardViewModel.recentSnapshots90` used to build in parallel.
    private var snapshots90: [RecoverySnapshot] {
        guard let athleteId = athletes.first?.id else { return [] }
        return Array(
            recoverySnapshots
                .filter { $0.athlete?.id == athleteId }
                .prefix(90)
                .reversed()
        )
    }

    var body: some View {
        SleepDetailView(snapshots: snapshots90)
    }
}

// MARK: - Fatigue (v1.7.3 · UAT round 3 · U20)

/// The fatigue breakdown, reached by tapping the Trends fatigue card.
///
/// ## Why it exists
///
/// The meaning layer shipped in round 2 as a reading under the hero plus eleven collapsed
/// "how to read this" rows ON the Trends page. HAN's round-3 verdict: the reading stays, the
/// eleven rows cost the page more height than the hero they explain. So the explanations moved
/// behind the number they explain, and the card became a door.
///
/// ## Claim rails
///
/// Unchanged from the card. Everything here DESCRIBES values the app already holds — the index,
/// its six component scores, where the window started and ended. It names no injury, forecasts
/// nothing, prescribes nothing. Trends describes; Today decides.
struct FatigueDetailScreen: View {
    /// The window the card was showing when it was tapped.
    let range: TimeRange

    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Query private var athletes: [Athlete]

    /// The page's own ViewModel instance, run at the pushed range. The narrative build is
    /// ~80 lines of repository fetches and engine calls; a second copy of it here would be a
    /// second answer to "what is my fatigue", which is the defect the one-fetch-path rule at the
    /// top of this file exists to prevent.
    @State private var viewModel = TrendsViewModel()

    var body: some View {
        FatigueDetailView(
            points: viewModel.fatiguePoints,
            trajectory: viewModel.trajectory,
            daysWithoutRelief: viewModel.daysWithoutRelief,
            observedHistoryDays: viewModel.observedHistoryDays,
            hasEnoughHistory: viewModel.hasEnoughHistory,
            rangeDays: range.days
        )
        .task { await load() }
    }

    private func load() async {
        guard let athlete = athletes.first else { return }
        viewModel.selectedRange = range
        await viewModel.load(
            athlete: athlete,
            healthKitService: container.healthKitService,
            modelContext: modelContext
        )
    }
}

/// The rendering half — data in, no fetching. Same chrome as `HRVDetailView`: context stamp →
/// title → hero band → plot → reason tree → expandable explanations.
struct FatigueDetailView: View {
    let points: [FatigueHistoryEngine.Point]
    let trajectory: FatigueHistoryEngine.Trajectory?
    let daysWithoutRelief: Int
    let observedHistoryDays: Int
    let hasEnoughHistory: Bool
    let rangeDays: Int

    @Environment(\.locale) private var locale

    private var latest: FatigueHistoryEngine.Point? { points.last }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                DetailScreenHeader(
                    stamp: TrendWindowStamp.stamp(days: points.map(\.day), locale: locale),
                    titleKey: "trends.detail.fatigue.title",
                    subtitle: String(
                        format: LocalePinnedStrings.localized("trends.detail.fatigue.subtitleFormat", locale: locale),
                        rangeDays
                    )
                )

                AreaRule()

                if hasEnoughHistory, let latest {
                    hero(latest)
                    AreaRule()
                    plot
                    AreaRule()
                    componentTree(latest)
                    AreaRule()
                } else {
                    empty
                    AreaRule()
                }

                DetailDisclosureList(
                    eyebrowKey: "trends.meaning.about.eyebrow",
                    items: TrendsFatigueSection.aboutItems
                )
            }
        }
        .background(ColorTokens.background)
        // The fatigue index is an accumulation reading in the LOAD hue — the same area the
        // Trends page itself declares, so the door and the room behind it read alike.
        .metricArea(.load)
        .navigationTitle(Text("trends.detail.fatigue.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The index, its zone and the one plain-language reading — the card's hero, restated so the
    /// athlete who tapped a number lands on that same number.
    private func hero(_ latest: FatigueHistoryEngine.Point) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text("\(Int(latest.index.rounded()))")
                        .font(.Tokens.displayAction)
                        .monospacedDigit()
                        .foregroundStyle(ColorTokens.metricLoad)
                    AnnotationLabel(key: "trends.fatigue.unit", size: .small)
                        .annotationReveal()
                }
                Spacer()
                ZoneBadge(
                    label: TrendsFatigueSection.zoneLabel(latest.zone, locale: locale),
                    color: ColorTokens.fatigueZoneColor(latest.zone)
                )
            }

            Text(TrendsFatigueSection.fatigueReading(
                zone: latest.zone,
                trajectory: TrendsFatigueSection.readingTrajectory(points: points, trajectory: trajectory),
                locale: locale
            ))
            .font(.Tokens.body)
            .foregroundStyle(ColorTokens.text2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, Spacing.sm)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.md)
        .heroPlane()
    }

    private var plot: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            FatigueAccumulationChart(points: points)
            Text(TrendsFatigueSection.trajectorySentence(
                points: points,
                trajectory: trajectory,
                daysWithoutRelief: daysWithoutRelief,
                rangeDays: rangeDays,
                locale: locale
            ))
            .font(.Tokens.body)
            .foregroundStyle(ColorTokens.text1)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.md)
    }

    /// The reason tree, expanded: each component keeps the row the card prints and gains the
    /// sentence that used to hide behind a disclosure.
    private func componentTree(_ latest: FatigueHistoryEngine.Point) -> some View {
        GlossedTreeSection(
            headKey: "trends.detail.fatigue.components.eyebrow",
            rows: Array(zip(
                TrendsFatigueSection.componentRows(
                    components: latest.components,
                    names: TrendsFatigueSection.componentWeightedNames(locale: locale)
                ),
                TrendsFatigueSection.componentAboutItems.map(\.bodyKey)
            ))
        )
    }

    private var empty: some View {
        Text(String(
            format: LocalePinnedStrings.localized("trends.fatigue.empty", locale: locale),
            observedHistoryDays,
            FatigueHistoryEngine.minimumHistoryDays
        ))
        .font(.Tokens.body)
        .foregroundStyle(ColorTokens.text2)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.md)
    }
}

// MARK: - Load (v1.7.3 · UAT round 3 · U20)

/// The load breakdown, reached from the Trends load card's hero.
///
/// Free-tier gating carries over verbatim from the page that pushed it: the snapshots this
/// screen reads are the same `filterSnapshotsForFree` window the Trends load chart draws, so the
/// detail can never show a free athlete history the card withheld.
struct LoadDetailScreen: View {
    let range: TimeRange

    @Environment(AppContainer.self) private var container
    @Query private var athletes: [Athlete]
    @Query(sort: \WorkloadSnapshot.snapshotDate, order: .reverse)
    private var workloadSnapshots: [WorkloadSnapshot]

    /// Oldest-first window, athlete-scoped and free-tier filtered — `TrendsView.trendData`'s
    /// own derivation, which is reactive rather than fetched.
    private var window: [WorkloadSnapshot] {
        guard let athleteId = athletes.first?.id else { return [] }
        let scoped = workloadSnapshots.filter { $0.athlete?.id == athleteId }
        let visible = container.subscriptionService.isPro
            ? scoped
            : SubscriptionService.filterSnapshotsForFree(scoped)
        return Array(visible.prefix(range.days).reversed())
    }

    /// The window's ratio span, for the held-range statement.
    private var acwrRange: (low: Double, high: Double)? {
        let ratios = window.map(\.acwr).filter { $0 > 0 }
        guard let low = ratios.min(), let high = ratios.max() else { return nil }
        return (low: low, high: high)
    }

    var body: some View {
        LoadDetailView(
            snapshot: window.last,
            acwrRange: acwrRange,
            trendSnapshots: window,
            rangeDays: range.days
        )
    }
}

/// The rendering half — data in, no fetching.
struct LoadDetailView: View {
    let snapshot: WorkloadSnapshot?
    let acwrRange: (low: Double, high: Double)?
    let trendSnapshots: [WorkloadSnapshot]
    let rangeDays: Int

    @Environment(\.locale) private var locale
    @State private var selectedTrendDate: Date?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                DetailScreenHeader(
                    stamp: TrendWindowStamp.stamp(days: trendSnapshots.map(\.snapshotDate), locale: locale),
                    titleKey: "trends.detail.load.title",
                    subtitle: String(
                        format: LocalePinnedStrings.localized("trends.detail.load.subtitleFormat", locale: locale),
                        rangeDays
                    )
                )

                AreaRule()

                if let snapshot {
                    hero(snapshot)
                    AreaRule()
                }

                plot

                AreaRule()

                if let snapshot {
                    loadTree(snapshot)
                    AreaRule()
                }

                DetailDisclosureList(
                    eyebrowKey: "trends.meaning.about.eyebrow",
                    items: TrendsLoadSection.aboutItems
                )

                AreaRule()

                // The activity card's two explanations (UAT round 3 · U20). They belong to the
                // bars on Trends, and the bars are the sessions this ratio is built from — so a
                // reader standing on the ratio is exactly the reader who wants them.
                DetailDisclosureList(
                    eyebrowKey: "trends.section.activity",
                    items: TrendsWhatYouDidSection.aboutItems
                )
            }
        }
        .background(ColorTokens.background)
        .metricArea(.load)
        .navigationTitle(Text("trends.detail.load.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func hero(_ snapshot: WorkloadSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text(String(format: "%.2f", snapshot.acwr))
                        .font(.Tokens.displayAction)
                        .monospacedDigit()
                        .foregroundStyle(ColorTokens.text1)
                    AnnotationLabel(key: "trends.load.unit", size: .small)
                        .annotationReveal()
                }
                Spacer()
                ZoneBadge(
                    label: snapshot.zone.displayName,
                    color: ColorTokens.acwrZoneColor(snapshot.zone)
                )
            }

            Text(TrendsLoadSection.loadReading(snapshot.zone, locale: locale))
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.sm)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.md)
        .heroPlane()
    }

    @ViewBuilder
    private var plot: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if trendSnapshots.count > 1 {
                LoadTrendChartView(snapshots: trendSnapshots, selectedDate: $selectedTrendDate)
            } else {
                // Say WHY there is no chart — a young history, not a rendering failure.
                Text("workload.chart.insufficientData")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
            }

            if let sentence = heldRangeSentence {
                Text(sentence)
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.md)
    }

    private func loadTree(_ snapshot: WorkloadSnapshot) -> some View {
        GlossedTreeSection(
            headKey: "trends.detail.load.components.eyebrow",
            rows: Array(zip(
                TrendsLoadSection.loadRows(
                    acute: snapshot.acuteLoad,
                    chronic: snapshot.chronicLoad,
                    tsb: snapshot.tsb,
                    locale: locale
                ),
                TrendsLoadSection.componentAboutItems.map(\.bodyKey)
            ))
        )
    }

    /// The ratio and the span it has held — both readings of stored values, the card's own
    /// sentence pair.
    private var heldRangeSentence: String? {
        guard let snapshot else { return nil }
        var sentence = String(
            format: LocalePinnedStrings.localized("trends.load.sentence", locale: locale),
            String(format: "%.2f", snapshot.acwr)
        )
        if let acwrRange, acwrRange.high > acwrRange.low {
            sentence += " " + String(
                format: LocalePinnedStrings.localized("trends.load.sentence.heldRange", locale: locale),
                String(format: "%.2f", acwrRange.low),
                String(format: "%.2f", acwrRange.high)
            )
        }
        return sentence
    }
}

// MARK: - Shared furniture

/// The context stamp above the two breakdown screens' titles — `14D · Aug 31 – Sep 13`.
///
/// A day count and a span, in the annotation voice. `HRVDetailView` composes the same stamp for
/// its pinch window; this is the fixed-window twin, held here so the two Trends screens cannot
/// drift from each other.
enum TrendWindowStamp {
    static func stamp(days: [Date], locale: Locale) -> String? {
        guard let first = days.min(), let last = days.max() else { return nil }
        let format = Date.FormatStyle.dateTime.month(.abbreviated).day().locale(locale)
        return "\(days.count)D \u{00B7} \(first.formatted(format)) – \(last.formatted(format))"
    }
}

/// Context stamp → page title → subtitle. `HRVDetailView`'s header, shared by the two screens
/// this file added so a third one cannot invent a fourth spacing.
private struct DetailScreenHeader: View {
    let stamp: String?
    let titleKey: LocalizedStringKey
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let stamp {
                AnnotationLabel(stamp, size: .small)
                    .annotationReveal()
                    .padding(.bottom, Spacing.baselinePair)
            }
            Text(titleKey)
                .font(.Tokens.pageTitle)
                .foregroundStyle(ColorTokens.text1)
                .padding(.bottom, Spacing.xs)
            Text(subtitle)
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.sm)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.md)
    }
}

/// A reason tree whose every node carries its own gloss.
///
/// `ReasonTreeSection` prints the derivation and stops; on a breakdown screen the point IS the
/// explanation, so each stemmed annotation row is followed by the working-voice sentence that
/// defines it. The row stays marginalia (a machine key and a number) and the gloss stays a
/// sentence — the Two-Voice Law holds line by line, which is exactly why they are two lines.
private struct GlossedTreeSection: View {
    let headKey: LocalizedStringKey
    /// The stemmed row and the catalog key of its one-line gloss, in print order.
    let rows: [(String, LocalizedStringKey)]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionEyebrow(key: headKey)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                        AnnotationLabel(row.0, color: ColorTokens.text2)
                            .annotationReveal(index: index)
                        Text(row.1)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .background(ColorTokens.surfaceEl)
    }
}
