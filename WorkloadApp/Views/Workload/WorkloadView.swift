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

                    // ATL / CTL / TSB — flat inline strip lifted onto the page.
                    HStack(spacing: 0) {
                        MetricTile(
                            title: "ATL",
                            value: String(format: "%.0f", latestSnapshot?.acuteLoad ?? 0),
                            subtitle: "Acute \u{00B7} 7-day",
                            color: ColorTokens.chartATL
                        )
                        MetricTile(
                            title: "CTL",
                            value: String(format: "%.0f", latestSnapshot?.chronicLoad ?? 0),
                            subtitle: "Chronic \u{00B7} 28-day",
                            color: ColorTokens.chartCTL
                        )
                        MetricTile(
                            title: "TSB",
                            value: String(format: "%+.0f", latestSnapshot?.tsb ?? 0),
                            subtitle: latestSnapshot.map { $0.tsb >= 0 ? "Fresh" : "Fatigued" } ?? "\u{2014}",
                            color: ColorTokens.chartTSB
                        )
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.top, Spacing.xs)
                    .entranceReveal(index: 1)

                    SectionContainer(header: "workload.section.loadTrend") {
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
                        SectionContainer(header: "workload.section.recoveryVsLoad") {
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
                        SectionContainer(header: "workload.section.recentPRs") {
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

/// Stage 4a — the Load screen's one peak: ACWR moves onto the emphasis plane
/// (`emphasisCardStyle`, accent top rule per Accent Rule v3 item 4) with display-scale
/// INSTRUMENT numerals (`Font.Tokens.displayMetric` — the Two-Voice law names exactly two
/// serif roles; ACWR is not one of them). The number is ink (`text1`), never accent; zone
/// state stays text-label-led via the ZoneBadge (color supplementary, never color alone).
struct ACWRGaugeCard: View {
    let snapshot: WorkloadSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("workload.section.acwr")
                    .font(.Tokens.micro)
                    .tracking(1.2)
                    .foregroundStyle(ColorTokens.text3)
                Spacer()
                if let snapshot {
                    ZoneBadge(
                        label: snapshot.zone.displayName,
                        color: ColorTokens.acwrZoneColor(snapshot.zone)
                    )
                }
            }

            if let snapshot {
                HStack(alignment: .lastTextBaseline, spacing: Spacing.xs) {
                    Text(String(format: "%.2f", snapshot.acwr))
                        .font(.Tokens.displayMetric)
                        .monospacedDigit()
                        .foregroundStyle(ColorTokens.text1)
                    Text("workload.label.ratio")
                        .font(.Tokens.micro)
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(ColorTokens.text3)
                }
            } else {
                Text("workload.empty.body")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
            }
        }
        .emphasisCardStyle()
    }
}

// MARK: - Load Trend Chart

struct LoadTrendChartView: View {
    @Environment(\.locale) private var locale
    let snapshots: [WorkloadSnapshot]
    @Binding var selectedDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Chart {
                ForEach(snapshots, id: \.id) { snapshot in
                    LineMark(
                        x: .value("Date", snapshot.snapshotDate),
                        y: .value("ATL", snapshot.acuteLoad)
                    )
                    .foregroundStyle(ColorTokens.chartATL)

                    LineMark(
                        x: .value("Date", snapshot.snapshotDate),
                        y: .value("CTL", snapshot.chronicLoad)
                    )
                    .foregroundStyle(ColorTokens.chartCTL)

                    AreaMark(
                        x: .value("Date", snapshot.snapshotDate),
                        y: .value("TSB", snapshot.tsb)
                    )
                    .foregroundStyle(ColorTokens.chartTSB.opacity(0.2))
                }
            }
            .frame(height: 160)
            .chartLegend(position: .bottom)
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
        }
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
                            Text(String(format: "+%.1f", improvement))
                                .font(.Tokens.label)
                                .monospacedDigit()
                                .foregroundStyle(ColorTokens.zoneOptimal)
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
