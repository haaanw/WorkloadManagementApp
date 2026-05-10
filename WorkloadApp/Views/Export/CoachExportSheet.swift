import SwiftUI
import SwiftData

/// Sheet for coaches to select athletes and generate a roster summary PDF report.
/// Receives the CoachRosterViewModel to reuse linked athletes and snapshot data.
struct CoachExportSheet: View {
    let viewModel: CoachRosterViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppContainer.self) private var container
    @Query private var athletes: [Athlete]

    @State private var selectedAthleteIds: Set<UUID> = []
    @State private var selectedRange: PDFReportEngine.ReportDateRange = .fourWeeks
    @State private var isGenerating = false
    @State private var showShareSheet = false
    @State private var exportFileURL: URL?
    @State private var errorMessage: String?
    @State private var didInitialize = false

    // MARK: - Computed

    private var allSelected: Bool {
        selectedAthleteIds.count == viewModel.linkedAthletes.count
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Title section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select Athletes")
                        .font(.Tokens.sectionHead)
                        .foregroundStyle(ColorTokens.text1)
                    Text("Choose athletes to include in the roster report")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                // Athlete list with checkmarks
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(viewModel.linkedAthletes, id: \.id) { athlete in
                            athleteRow(athlete)
                            Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                        }
                    }
                }

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                // Date range chips
                dateRangeChips
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)

                // CTA button
                generateButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
            .background(ColorTokens.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text1)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(allSelected ? "Deselect All" : "Select All") {
                        toggleSelectAll()
                    }
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
                }
            }
        }
        .onAppear {
            if !didInitialize {
                selectedAthleteIds = Set(viewModel.linkedAthletes.map(\.id))
                didInitialize = true
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportFileURL {
                ShareSheet(items: [url])
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Athlete Row

    private func athleteRow(_ athlete: Athlete) -> some View {
        Button {
            if selectedAthleteIds.contains(athlete.id) {
                selectedAthleteIds.remove(athlete.id)
            } else {
                selectedAthleteIds.insert(athlete.id)
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: selectedAthleteIds.contains(athlete.id) ? "checkmark.circle.fill" : "circle")
                    .font(.Tokens.body)
                    .foregroundStyle(
                        selectedAthleteIds.contains(athlete.id) ? ColorTokens.text1 : ColorTokens.text2
                    )

                Text(athlete.displayName)
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)

                Spacer()

                let zoneName = viewModel.latestWorkloadSnapshot[athlete.id]?.zone.displayName ?? "No data"
                let zoneColor = zoneColorFor(athlete)
                Text(zoneName)
                    .font(.Tokens.micro)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(ColorTokens.text2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(
                        Rectangle()
                            .stroke(zoneColor, lineWidth: 0.5)
                    )
            }
            .padding(.horizontal, 24)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(selectedAthleteIds.contains(athlete.id) ? "selected" : "not selected")
    }

    // MARK: - Date Range Chips

    private var dateRangeChips: some View {
        HStack(spacing: 8) {
            ForEach(PDFReportEngine.ReportDateRange.allCases, id: \.self) { range in
                Button {
                    selectedRange = range
                } label: {
                    Text(range.displayName)
                        .font(.Tokens.micro)
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(
                            selectedRange == range ? ColorTokens.text1 : ColorTokens.text2
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            selectedRange == range ? ColorTokens.surface : Color.clear
                        )
                        .overlay(
                            Rectangle()
                                .stroke(
                                    selectedRange == range ? ColorTokens.text1 : ColorTokens.divider,
                                    lineWidth: 0.5
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        Button {
            generateReport()
        } label: {
            Text(isGenerating ? "Generating..." : "Generate Roster Report")
                .font(.Tokens.bodyMedium)
                .foregroundStyle(ColorTokens.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    selectedAthleteIds.isEmpty || isGenerating
                        ? ColorTokens.text3
                        : ColorTokens.text1
                )
        }
        .buttonStyle(.plain)
        .disabled(isGenerating || selectedAthleteIds.isEmpty)
    }

    // MARK: - Actions

    private func toggleSelectAll() {
        if allSelected {
            selectedAthleteIds.removeAll()
        } else {
            selectedAthleteIds = Set(viewModel.linkedAthletes.map(\.id))
        }
    }

    private func generateReport() {
        isGenerating = true

        Task {
            let selectedAthletes = viewModel.linkedAthletes.filter {
                selectedAthleteIds.contains($0.id)
            }

            let rosterData: [PDFReportEngine.RosterAthleteData] = selectedAthletes.map { athlete in
                let workload = viewModel.latestWorkloadSnapshot[athlete.id]
                let recovery = viewModel.latestRecoverySnapshot[athlete.id]

                let cutoffDate = Calendar.current.date(
                    byAdding: .day, value: -selectedRange.days, to: .now
                ) ?? .now
                let recentSessions = athlete.sessions.filter {
                    $0.sessionDate >= cutoffDate
                }

                let streak = StreakEngine.computeStreak(sessions: Array(athlete.sessions))

                return PDFReportEngine.RosterAthleteData(
                    name: athlete.displayName,
                    recoveryScore: recovery?.recoveryScore,
                    acwrZone: workload?.zone ?? .noData,
                    sessionsCount: recentSessions.count,
                    streakCount: streak,
                    isOverreaching: workload?.zone == .danger
                )
            }

            let coachName = athletes.first?.displayName ?? "Coach"
            let dateString = Date.now.formatted(.dateTime.year().month().day())

            do {
                let pdfData = PDFReportEngine.generateCoachRosterReport(
                    coachName: coachName,
                    athletes: rosterData,
                    dateRange: selectedRange
                )

                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("Tutrice_Roster_\(dateString).pdf")
                try pdfData.write(to: tempURL)
                exportFileURL = tempURL
                showShareSheet = true
            } catch {
                print("Coach export error: \(error)")
                errorMessage = "Report generation failed. Please try again."
            }

            isGenerating = false
        }
    }

    // MARK: - Helpers

    private func zoneColorFor(_ athlete: Athlete) -> Color {
        guard let zone = viewModel.latestWorkloadSnapshot[athlete.id]?.zone else {
            return ColorTokens.divider
        }
        switch zone {
        case .optimal:
            return ColorTokens.zoneOptimal
        case .caution:
            return ColorTokens.zoneCaution
        case .danger:
            return ColorTokens.zoneDanger
        case .undertrained, .noData:
            return ColorTokens.divider
        }
    }
}
