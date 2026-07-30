import SwiftUI
import SwiftData
import Charts

struct WorkloadView: View {
    @Query(sort: \WorkloadSnapshot.snapshotDate, order: .reverse)
    private var snapshots: [WorkloadSnapshot]
    @Query(sort: \PersonalRecord.achievedAt, order: .reverse)
    private var personalRecords: [PersonalRecord]
    @Query(sort: \WorkoutSession.sessionDate, order: .reverse)
    private var allSessions: [WorkoutSession]
    @Query private var athletes: [Athlete]
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showUpgrade = false
    @State private var showExportOptions = false
    @State private var showShareSheet = false
    @State private var showUpgradeForExport = false
    @State private var exportFileURL: URL?
    @State private var showPDFSheet = false
    @State private var viewModel = WorkloadViewModel()
    @State private var selectedTrendDate: Date?

    private var athlete: Athlete? { athletes.first }

    private var scopedSnapshots: [WorkloadSnapshot] {
        guard let athleteId = athlete?.id else { return [] }
        return snapshots.filter { $0.athlete?.id == athleteId }
    }

    private var scopedPersonalRecords: [PersonalRecord] {
        guard let athleteId = athlete?.id else { return [] }
        return personalRecords.filter { $0.athlete?.id == athleteId }
    }

    private var scopedSessions: [WorkoutSession] {
        guard let athleteId = athlete?.id else { return [] }
        return allSessions.filter { $0.athlete?.id == athleteId }
    }

    private var visibleSnapshots: [WorkloadSnapshot] {
        container.subscriptionService.isPro
            ? scopedSnapshots
            : SubscriptionService.filterSnapshotsForFree(scopedSnapshots)
    }

    private var lockedWeeks: Int {
        guard !container.subscriptionService.isPro else { return 0 }
        let visible = SubscriptionService.filterSnapshotsForFree(scopedSnapshots)
        return SubscriptionService.lockedWeeks(
            totalSessions: scopedSnapshots.count,
            visibleSessions: visible.count
        )
    }

    private var latestSnapshot: WorkloadSnapshot? { visibleSnapshots.first }

    private var visibleRecords: [PersonalRecord] {
        guard !container.subscriptionService.isPro else { return Array(scopedPersonalRecords.prefix(5)) }
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return scopedPersonalRecords.filter { $0.achievedAt >= cutoff }.prefix(5).map { $0 }
    }

    /// Trend snapshots filtered by selected time range
    private var trendData: [WorkloadSnapshot] {
        Array(visibleSnapshots.prefix(viewModel.selectedRange.days).reversed())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Editorial screen header (Stage 4a) — in-content title; the export
                    // action moves out of the hidden nav bar onto the header's baseline.
                    ScreenHeader(title: "workload.nav.title") {
                        Button {
                            Haptics.tap()
                            if container.subscriptionService.isPro {
                                showExportOptions = true
                            } else {
                                showUpgradeForExport = true
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.Tokens.body)
                                .foregroundStyle(ColorTokens.text1)
                        }
                        .accessibilityLabel("a11y.exportWorkoutData")
                        .accessibilityIdentifier("export.workoutData")
                        .buttonStyle(.pressable)
                    }

                    ACWRGaugeCard(snapshot: latestSnapshot)
                        .padding(.horizontal, Spacing.sm)
                        .entranceReveal()
                        .accessibilityIdentifier("workload.acwr")

                    // ATL / CTL / TSB — metric grid: three individually-planed metric
                    // cells with their descriptor on the delta line, scannable in one fixation.
                    HStack(alignment: .top, spacing: Spacing.xs) {
                        MetricCell(
                            label: "ATL",
                            value: String(format: "%.0f", latestSnapshot?.acuteLoad ?? 0),
                            delta: "Acute \u{00B7} 7-day"
                        )
                        MetricCell(
                            label: "CTL",
                            value: String(format: "%.0f", latestSnapshot?.chronicLoad ?? 0),
                            delta: "Chronic \u{00B7} 28-day"
                        )
                        MetricCell(
                            label: "TSB",
                            value: String(format: "%+.0f", latestSnapshot?.tsb ?? 0),
                            delta: latestSnapshot.map { $0.tsb >= 0 ? "Fresh" : "Fatigued" } ?? "\u{2014}"
                        )
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.top, Spacing.xs)
                    .entranceReveal(index: 1)

                    SectionContainer {
                        RuledSectionHeader(title: "workload.section.loadTrend")
                            .padding(.horizontal, Spacing.sm)
                        Spacer().frame(height: Spacing.sm)
                        VStack(spacing: 0) {
                            if container.subscriptionService.isPro {
                                TimeRangeSegmentedControl(selected: $viewModel.selectedRange)
                                    .padding(.bottom, Spacing.sm)
                            }

                            if trendData.count > 1 {
                                LoadTrendChartView(
                                    snapshots: trendData,
                                    selectedDate: $selectedTrendDate
                                )
                                .cardStyle()
                            }
                        }
                        .padding(.horizontal, Spacing.sm)
                    }
                    .entranceReveal(index: 2)

                    if lockedWeeks > 0 {
                        SectionContainer {
                            HistoryTeaserBanner(lockedWeeks: lockedWeeks) {
                                showUpgrade = true
                            }
                            .padding(.horizontal, Spacing.sm)
                        }
                        .transition(.opacity)
                        .entranceReveal(index: 3)
                    }

                    if container.subscriptionService.isPro {
                        SectionContainer {
                            RuledSectionHeader(title: "workload.section.recoveryVsLoad")
                                .padding(.horizontal, Spacing.sm)
                            Spacer().frame(height: Spacing.sm)
                            RecoveryLoadChart(
                                loadSnapshots: viewModel.correlationLoadSnapshots,
                                recoverySnapshots: viewModel.correlationRecoverySnapshots
                            )
                            .cardStyle()
                            .padding(.horizontal, Spacing.sm)
                        }
                        .transition(.opacity)
                        .entranceReveal(index: 4)
                    }

                    if !visibleRecords.isEmpty {
                        SectionContainer {
                            RuledSectionHeader(title: "workload.section.recentPRs")
                                .padding(.horizontal, Spacing.sm)
                            Spacer().frame(height: Spacing.sm)
                            PRHistorySection(records: visibleRecords)
                                .padding(.horizontal, Spacing.sm)
                        }
                        .transition(.opacity)
                        .entranceReveal(index: 5)
                    }

                    Spacer().frame(height: Spacing.lg)
                }
                .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: viewModel.isLoading)
                .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: lockedWeeks)
                .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: visibleRecords.count)
            }
            .contentMargins(.top, Spacing.md, for: .scrollContent)
            .contentMargins(.bottom, Spacing.lg, for: .scrollContent)
            .background(ColorTokens.background)
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog("workload.export.title", isPresented: $showExportOptions, titleVisibility: .visible) {
                Button("workload.export.sessionSummary") {
                    exportCSV(format: .sessionSummary)
                }
                Button("workload.export.detailedSets") {
                    exportCSV(format: .detailedSets)
                }
                Button("workload.export.pdfReport") {
                    showPDFSheet = true
                }
                .accessibilityIdentifier("export.pdfReport")
                Button("action.cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportFileURL {
                    ShareSheet(items: [url])
                }
            }
            .sheet(isPresented: $showPDFSheet) {
                PDFGenerationSheet()
            }
            .sheet(isPresented: $showUpgradeForExport) {
                UpgradeSheet(trigger: .export)
            }
            .sheet(isPresented: $showUpgrade) {
                UpgradeSheet(trigger: .history(lockedWeeks: lockedWeeks))
            }
            .onAppear {
                if let athlete {
                    viewModel.loadTrendData(modelContext: modelContext, athlete: athlete)
                }
            }
            .onChange(of: viewModel.selectedRange) { _, _ in
                Haptics.select()
                withAnimation(Motion.resolved(Motion.screen, reduceMotion: reduceMotion)) {
                    if let athlete {
                        viewModel.loadTrendData(modelContext: modelContext, athlete: athlete)
                    }
                }
            }
        }
    }

    // MARK: - Export

    private enum ExportFormat {
        case sessionSummary
        case detailedSets
    }

    private func exportCSV(format: ExportFormat) {
        let csvString: String
        let filename: String
        let dateString = Date.now.formatted(.dateTime.year().month().day())

        switch format {
        case .sessionSummary:
            csvString = CSVExportEngine.sessionSummaryCSV(sessions: scopedSessions)
            filename = "tuwa_sessions_\(dateString).csv"
        case .detailedSets:
            csvString = CSVExportEngine.detailedSetsCSV(sessions: scopedSessions)
            filename = "tuwa_sets_\(dateString).csv"
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            exportFileURL = tempURL
            showShareSheet = true
        } catch {
            print("CSV export error: \(error)")
        }
    }
}

// MARK: - ACWR Display

/// v5 "Pavilion" + v6 "Field Notes": the Load screen's hero reading — ACWR on the screen's one
/// raised light hero card (Hero Law): micro-caps label in `text3`, the ratio in `heroScore`
/// wearing **`metricLoad`** (v6 Reading Color Rule — the hero reading takes its own metric's hue;
/// ACWR is the training-load metric, so ochre. This supersedes v5's travertine hero: `accent` now
/// owns live-state marks exclusively, which is why the TickScale NEEDLE below stays accent).
/// It remains the single colored text element on this screen. Zone state is a caps TEXT label in
/// its zone color (never color alone), and a full-width `TickScale` 0–2.0 carries the 0.8–1.3
/// productive band (ACWRZone.classify) with the accent needle at today's ratio.
struct ACWRGaugeCard: View {
    let snapshot: WorkloadSnapshot?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The productive ACWR band (ACWRZone.classify: optimal = 0.8..<1.3) — the ink zone
    /// band rendered on the tick scale.
    private static let optimalBand: ClosedRange<Double> = 0.8...1.3

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // v6: the hero card's metric key is marginalia, not speech — the annotation voice.
            // `AnnotationLabel` owns the case transform, the +0.05em tracking and the CJK guard,
            // so the key resolves through `String(localized:)` (the primitive takes a String).
            //
            // The key wears `metricLoad` + a `●` state dot, matching this card's own specimen in
            // `design-system/ui_kits/ios-app/LoadScreen.jsx` (`ACWR ●` in `--metric-load`).
            // DESIGN.md's Reading Color Rule sanctions exactly this ("metric-hue annotation — a
            // `● READINESS` key"), and rule 7 is satisfied because the key sits on a RAISED CARD
            // plane (metricLoad = 4.82:1 there, vs 4.49:1 on the base plane).
            HStack(spacing: Spacing.baselinePair) {
                AnnotationLabel(
                    String(localized: "workload.section.acwr"),
                    color: ColorTokens.metricLoad
                )
                AnnotationLabel("\u{25CF}", color: ColorTokens.metricLoad)
                    .accessibilityHidden(true)
            }
            .annotationReveal()

            Spacer().frame(height: Spacing.sm)

            if let snapshot {
                // Baseline-aligned readout: the ratio dominates the left, the zone label
                // pinned to the trailing edge on its baseline — same grammar as Home.
                HStack(alignment: .lastTextBaseline, spacing: Spacing.sm) {
                    Text(String(format: "%.2f", snapshot.acwr))
                        .font(.Tokens.heroScore)
                        .monospacedDigit()
                        .foregroundStyle(ColorTokens.metricLoad)
                    Spacer(minLength: Spacing.sm)
                    // Zone state as a TEXT LABEL in its zone color (text first, color
                    // supplementary — never color alone, nocebo guard unchanged). v6 moves it to
                    // the annotation voice, matching the reference specimen's mono zone label
                    // beside the hero. Sits on a RAISED CARD plane, which is where rule 7
                    // requires sub-24pt zone-colored text to live.
                    AnnotationLabel(
                        snapshot.zone.displayName,
                        color: ColorTokens.acwrZoneColor(snapshot.zone)
                    )
                    .annotationReveal(index: 1)
                }

                Spacer().frame(height: Spacing.sm)

                TickScale(
                    range: 0...2,
                    value: snapshot.acwr,
                    zone: Self.optimalBand,
                    variant: .scale,
                    theme: .light,
                    numeralText: { String(format: "%.1f", $0) },
                    accessibilityLabel: Text(verbatim: "\(String(format: "%.2f", snapshot.acwr)) · \(snapshot.zone.displayName)")
                )
                // Needle position changes settle mechanically via `Motion.state` (TickScale
                // is Animatable on `value`); Reduce Motion resolves to an instant settle.
                .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: snapshot.acwr)
            } else {
                Text("workload.empty.body")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .raised(cornerRadius: CornerTokens.card)
    }
}

// MARK: - Load Trend Chart

/// DESIGN.md v6 "Field Notes" — the load trend chart carries two series with a METRIC IDENTITY,
/// so each takes its hue: **ATL (acute load) → `metricStrain`** (rust) and
/// **CTL (chronic load) → `metricLoad`** (ochre). TSB is a derived balance with no metric identity
/// of its own, so its area keeps the identity-less warm-ink `chartTSB` token — which also keeps v6's
/// hard prohibition intact: a metric hue is never an area fill.
///
/// Grid hairlines are `chartGrid`; axis value labels render in the annotation voice (10pt Fragment
/// Mono via `AnnotationLabel`). The mono series key under the plot is the design system's own chart
/// grammar (`design-system/guidelines/charts.card.html` labels its series in mono): the DOT carries
/// the hue (a state dot — a sanctioned mark) while the key text stays `text3`, so the screen still
/// has exactly one colored text element (the ACWR hero).
struct LoadTrendChartView: View {
    @Environment(\.locale) private var locale
    let snapshots: [WorkloadSnapshot]
    @Binding var selectedDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Chart {
                ForEach(snapshots, id: \.id) { snapshot in
                    // `series:` is load-bearing, not decoration. Swift Charts groups marks into
                    // series, and two `LineMark`s sharing the same x-values with NO series
                    // discriminator collapse into ONE series — so Charts connected ATL→CTL→ATL→CTL
                    // and drew a single zigzag in whichever style won, with the CTL line rendering
                    // nowhere. That predates v6 (it shipped with the warm-ink `chartATL`/`chartCTL`
                    // pair, where two near-identical inks made the artifact easy to miss); v6's
                    // distinct rust/ochre hues plus the series key below made it visible. Naming
                    // the series is what makes the two-hue mapping actually true on screen.
                    LineMark(
                        x: .value("Date", snapshot.snapshotDate),
                        y: .value("ATL", snapshot.acuteLoad),
                        series: .value("Series", "ATL")
                    )
                    .foregroundStyle(ColorTokens.metricStrain)

                    LineMark(
                        x: .value("Date", snapshot.snapshotDate),
                        y: .value("CTL", snapshot.chronicLoad),
                        series: .value("Series", "CTL")
                    )
                    .foregroundStyle(ColorTokens.metricLoad)

                    AreaMark(
                        x: .value("Date", snapshot.snapshotDate),
                        y: .value("TSB", snapshot.tsb)
                    )
                    .foregroundStyle(ColorTokens.chartTSB.opacity(0.2))
                }
            }
            .frame(height: 160)
            .chartLegend(position: .bottom)
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine().foregroundStyle(ColorTokens.chartGrid)
                    AxisTick().foregroundStyle(ColorTokens.chartGrid)
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            AnnotationLabel(
                                date.formatted(.dateTime.month(.abbreviated).day().locale(locale)),
                                size: .small
                            )
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine().foregroundStyle(ColorTokens.chartGrid)
                    AxisValueLabel {
                        if let load = value.as(Double.self) {
                            AnnotationLabel(String(format: "%.0f", load), size: .small)
                        }
                    }
                }
            }
            .id(locale)
            .entranceReveal()
            .chartOverlay { proxy in
                ChartTooltipGesture(
                    proxy: proxy,
                    data: snapshots.map { (date: $0.snapshotDate, value: $0.acuteLoad) },
                    selectedDate: $selectedDate
                )
            }
            .overlay(alignment: .top) {
                if let selectedDate,
                   let snapshot = snapshots.first(where: { Calendar.current.isDate($0.snapshotDate, inSameDayAs: selectedDate) }) {
                    TooltipBubble(
                        value: "ATL: \(String(format: "%.0f", snapshot.acuteLoad)) | CTL: \(String(format: "%.0f", snapshot.chronicLoad))",
                        dateLabel: snapshot.snapshotDate.formatted(.dateTime.month(.abbreviated).day().locale(locale))
                    )
                }
            }

            // Mono series key. ATL/CTL/TSB are the same untranslated scientific abbreviations the
            // metric grid above already prints verbatim, so this adds no new localizable copy.
            HStack(spacing: Spacing.sm) {
                seriesKey(glyph: "\u{25CF}", color: ColorTokens.metricStrain, label: "ATL", index: 0)
                seriesKey(glyph: "\u{25CF}", color: ColorTokens.metricLoad, label: "CTL", index: 1)
                seriesKey(glyph: "\u{2592}", color: ColorTokens.chartTSB, label: "TSB", index: 2)
                Spacer(minLength: 0)
            }
        }
    }

    /// One series-key cell: a hue-bearing state dot (`●`) or fill glyph (`▒`) plus its `text3`
    /// abbreviation, both in the annotation voice, revealed on the v6 choreography.
    private func seriesKey(glyph: String, color: Color, label: String, index: Int) -> some View {
        HStack(spacing: Spacing.baselinePair) {
            AnnotationLabel(glyph, size: .small, color: color)
                .accessibilityHidden(true)
            AnnotationLabel(label, size: .small)
        }
        .annotationReveal(index: index)
    }
}

// MARK: - PR History

struct PRHistorySection: View {
    let records: [PersonalRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(records.enumerated()), id: \.element.id) { index, pr in
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                        Text(pr.exerciseName)
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                        Text(pr.recordType.displayName)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: Spacing.baselinePair) {
                        Text(String(format: "%.1f", pr.value))
                            .font(.Tokens.body)
                            .monospacedDigit()
                            .foregroundStyle(ColorTokens.text1)
                        if let improvement = pr.improvement {
                            // v6: a signed delta is marginalia — the annotation voice. It keeps
                            // its zone color and sits on a CARD plane, which is where rule 7
                            // requires sub-24pt zone-colored text to live.
                            AnnotationLabel(
                                String(format: "+%.1f", improvement),
                                color: ColorTokens.zoneOptimal
                            )
                        }
                    }
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.sm)

                if index < records.count - 1 {
                    RowSeparator()
                }
            }
        }
        .cardStyle(horizontalPadding: 0, verticalPadding: 0)
    }
}
