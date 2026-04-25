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
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @State private var showUpgrade = false
    @State private var showExportOptions = false
    @State private var showShareSheet = false
    @State private var showUpgradeForExport = false
    @State private var exportFileURL: URL?
    @State private var showPDFSheet = false
    @State private var viewModel = WorkloadViewModel()
    @State private var selectedTrendDate: Date?

    private var visibleSnapshots: [WorkloadSnapshot] {
        container.subscriptionService.isPro
            ? snapshots
            : SubscriptionService.filterSnapshotsForFree(snapshots)
    }

    private var lockedWeeks: Int {
        guard !container.subscriptionService.isPro else { return 0 }
        let visible = SubscriptionService.filterSnapshotsForFree(snapshots)
        return SubscriptionService.lockedWeeks(
            totalSessions: snapshots.count,
            visibleSessions: visible.count
        )
    }

    private var latestSnapshot: WorkloadSnapshot? { visibleSnapshots.first }

    private var visibleRecords: [PersonalRecord] {
        guard !container.subscriptionService.isPro else { return Array(personalRecords.prefix(5)) }
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        return personalRecords.filter { $0.achievedAt >= cutoff }.prefix(5).map { $0 }
    }

    /// Trend snapshots filtered by selected time range
    private var trendData: [WorkloadSnapshot] {
        Array(visibleSnapshots.prefix(viewModel.selectedRange.days).reversed())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ACWRGaugeCard(snapshot: latestSnapshot)

                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)

                    HStack(spacing: 0) {
                        MetricTile(
                            title: "ATL",
                            value: String(format: "%.0f", latestSnapshot?.acuteLoad ?? 0),
                            subtitle: "Acute \u{00B7} 7-day",
                            color: ColorTokens.chartATL
                        )
                        Rectangle().fill(ColorTokens.divider).frame(width: 0.5)
                        MetricTile(
                            title: "CTL",
                            value: String(format: "%.0f", latestSnapshot?.chronicLoad ?? 0),
                            subtitle: "Chronic \u{00B7} 28-day",
                            color: ColorTokens.chartCTL
                        )
                        Rectangle().fill(ColorTokens.divider).frame(width: 0.5)
                        MetricTile(
                            title: "TSB",
                            value: String(format: "%+.0f", latestSnapshot?.tsb ?? 0),
                            subtitle: latestSnapshot.map { $0.tsb >= 0 ? "Fresh" : "Fatigued" } ?? "\u{2014}",
                            color: ColorTokens.chartTSB
                        )
                    }

                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)

                    if container.subscriptionService.isPro {
                        TimeRangeSegmentedControl(selected: $viewModel.selectedRange)
                            .padding(.vertical, 16)

                        Rectangle()
                            .fill(ColorTokens.divider)
                            .frame(height: 0.5)
                    }

                    if trendData.count > 1 {
                        LoadTrendChartView(
                            snapshots: trendData,
                            selectedDate: $selectedTrendDate
                        )

                        Rectangle()
                            .fill(ColorTokens.divider)
                            .frame(height: 0.5)
                    }

                    if lockedWeeks > 0 {
                        HistoryTeaserBanner(lockedWeeks: lockedWeeks) {
                            showUpgrade = true
                        }
                        Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                    }

                    if container.subscriptionService.isPro {
                        RecoveryLoadChart(
                            loadSnapshots: viewModel.correlationLoadSnapshots,
                            recoverySnapshots: viewModel.correlationRecoverySnapshots
                        )

                        Rectangle()
                            .fill(ColorTokens.divider)
                            .frame(height: 0.5)
                    }

                    if !visibleRecords.isEmpty {
                        PRHistorySection(records: visibleRecords)
                    }
                }
            }
            .background(ColorTokens.background)
            .navigationTitle("Load & Progress")
            .toolbarBackground(ColorTokens.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .withContextSwitcher()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if container.subscriptionService.isPro {
                            showExportOptions = true
                        } else {
                            showUpgradeForExport = true
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(ColorTokens.text1)
                    }
                    .accessibilityLabel("Export workout data")
                }
            }
            .confirmationDialog("Export Workout Data", isPresented: $showExportOptions, titleVisibility: .visible) {
                Button("Session Summary") {
                    exportCSV(format: .sessionSummary)
                }
                Button("Detailed Sets") {
                    exportCSV(format: .detailedSets)
                }
                Button("PDF Report (Pro)") {
                    showPDFSheet = true
                }
                Button("Cancel", role: .cancel) {}
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
                viewModel.loadTrendData(modelContext: modelContext)
            }
            .onChange(of: viewModel.selectedRange) { _, _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    viewModel.loadTrendData(modelContext: modelContext)
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
            csvString = CSVExportEngine.sessionSummaryCSV(sessions: allSessions)
            filename = "tonus_sessions_\(dateString).csv"
        case .detailedSets:
            csvString = CSVExportEngine.detailedSetsCSV(sessions: allSessions)
            filename = "tonus_sets_\(dateString).csv"
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

struct ACWRGaugeCard: View {
    let snapshot: WorkloadSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("ACWR")
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
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(String(format: "%.2f", snapshot.acwr))
                        .font(.Tokens.pageTitle)
                        .monospacedDigit()
                        .foregroundStyle(ColorTokens.acwrZoneColor(snapshot.zone))
                    Text("ratio")
                        .font(.Tokens.micro)
                        .foregroundStyle(ColorTokens.text3)
                }
            } else {
                Text("No workload data yet. Log a workout to see your training load.")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(ColorTokens.surface)
    }
}

// MARK: - Load Trend Chart

struct LoadTrendChartView: View {
    let snapshots: [WorkloadSnapshot]
    @Binding var selectedDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("LOAD TREND")
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)

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
                        dateLabel: snapshot.snapshotDate.formatted(.dateTime.month(.abbreviated).day())
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(ColorTokens.background)
    }
}

// MARK: - PR History

struct PRHistorySection: View {
    let records: [PersonalRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("RECENT PRS")
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)

            Rectangle()
                .fill(ColorTokens.divider)
                .frame(height: 0.5)

            ForEach(records, id: \.id) { pr in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pr.exerciseName)
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                        Text(pr.recordType.displayName)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
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
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Rectangle()
                    .fill(ColorTokens.divider)
                    .frame(height: 0.5)
            }
        }
        .background(ColorTokens.background)
    }
}
