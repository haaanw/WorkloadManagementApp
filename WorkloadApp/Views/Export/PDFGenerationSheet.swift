import SwiftUI
import SwiftData

/// Date range selection sheet for generating athlete PDF training reports.
/// Presents preset date range chips and a generate CTA that calls PDFReportEngine,
/// then presents the system ShareSheet with the resulting PDF file.
struct PDFGenerationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppContainer.self) private var container
    @Query private var athletes: [Athlete]

    @State private var selectedRange: PDFReportEngine.ReportDateRange = .fourWeeks
    @State private var isGenerating = false
    @State private var showShareSheet = false
    @State private var exportFileURL: URL?
    @State private var errorMessage: String?

    private var athlete: Athlete? { athletes.first }

    private var subtitleText: String {
        guard let athlete = athlete else { return "" }
        return "\(athlete.displayName) - \(athlete.sportType.displayName)"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Title section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Export PDF Report")
                        .font(.Tokens.sectionHead)
                        .foregroundStyle(ColorTokens.text1)
                    Text(subtitleText)
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                // Date range chips
                dateRangeChips
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)

                Spacer()

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

    // MARK: - Date Range Chips

    private var dateRangeChips: some View {
        HStack(spacing: 8) {
            ForEach(PDFReportEngine.ReportDateRange.allCases, id: \.self) { range in
                Button {
                    selectedRange = range
                } label: {
                    Text(range.displayName)
                        .font(.Tokens.label)
                        .foregroundStyle(
                            selectedRange == range
                                ? ColorTokens.text1
                                : ColorTokens.text2
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(minHeight: 44)
                        .background(ColorTokens.surface)
                        .overlay(
                            Rectangle()
                                .stroke(
                                    selectedRange == range
                                        ? ColorTokens.text1
                                        : ColorTokens.divider,
                                    lineWidth: selectedRange == range ? 1 : 0.5
                                )
                        )
                }
            }
        }
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        Button {
            generateReport()
        } label: {
            HStack(spacing: 8) {
                if isGenerating {
                    ProgressView()
                        .tint(ColorTokens.background)
                    Text("Generating...")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.background)
                } else {
                    Text("Generate Report")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.background)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(ColorTokens.text1)
        }
        .disabled(isGenerating)
    }

    // MARK: - Report Generation

    private func generateReport() {
        guard let athlete = athlete else { return }
        isGenerating = true

        Task {
            do {
                let workoutRepo = WorkoutRepository(modelContext: modelContext)
                let sessions = try workoutRepo.fetchSessions(last: selectedRange.days, athlete: athlete)

                let workloadRepo = WorkloadRepository(modelContext: modelContext)
                let workloadSnapshots = try workloadRepo.fetchSnapshots(last: selectedRange.days, athlete: athlete)

                let recoveryRepo = RecoveryRepository(modelContext: modelContext)
                let recoverySnapshots = try recoveryRepo.fetchRecoveryHistory(days: selectedRange.days, athlete: athlete)

                let cutoff = Calendar.current.date(
                    byAdding: .day,
                    value: -selectedRange.days,
                    to: .now
                ) ?? .now
                let athleteId = athlete.id
                var prDescriptor = FetchDescriptor<PersonalRecord>(
                    predicate: #Predicate<PersonalRecord> {
                        $0.achievedAt >= cutoff && $0.athlete?.id == athleteId
                    }
                )
                prDescriptor.sortBy = [SortDescriptor(\.achievedAt, order: .reverse)]
                let personalRecords = (try? modelContext.fetch(prDescriptor)) ?? []

                let streakCount = StreakEngine.computeStreak(sessions: sessions)

                let pdfData = PDFReportEngine.generateAthleteReport(
                    athlete: athlete,
                    sessions: sessions,
                    workloadSnapshots: workloadSnapshots,
                    recoverySnapshots: recoverySnapshots,
                    personalRecords: personalRecords,
                    streakCount: streakCount,
                    dateRange: selectedRange
                )

                let dateString = Date.now.formatted(.dateTime.year().month().day())
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("tonus_report_\(dateString).pdf")
                try pdfData.write(to: tempURL)

                exportFileURL = tempURL
                showShareSheet = true
            } catch {
                print("PDF generation error: \(error)")
                errorMessage = "Report generation failed. Please try again."
            }

            isGenerating = false
        }
    }
}
