import SwiftUI
import SwiftData
import Charts

struct ClientDetailView: View {
    let athlete: Athlete
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Query private var allAthletes: [Athlete]
    @State private var showWorkoutEntry = false
    @State private var showPrescribeSheet = false
    @State private var selectedSessionType: SessionType? = nil

    // The viewing coach's own Athlete record (device owner — always allAthletes.first)
    private var viewingCoach: Athlete? { allAthletes.first }

    private var latestRecovery: RecoverySnapshot? {
        athlete.recoverySnapshots.max(by: { $0.date < $1.date })
    }

    private var recentWorkload: [WorkloadSnapshot] {
        Array(
            athlete.workloadSnapshots
                .sorted(by: { $0.snapshotDate < $1.snapshotDate })
                .suffix(28)
        )
    }

    private var recentWorkloadList: [WorkloadSnapshot] {
        Array(recentWorkload.reversed().prefix(5))
    }

    private var upcomingPrescriptions: [PrescribedWorkout] {
        let athleteId = athlete.id
        let assigned = PrescriptionStatus.assigned.rawValue
        guard let results = try? modelContext.fetch(
            FetchDescriptor<PrescribedWorkout>(
                predicate: #Predicate { $0.athleteId == athleteId && $0.statusRawValue == assigned },
                sortBy: [SortDescriptor(\.scheduledDate)]
            )
        ) else { return [] }
        return Array(results.prefix(5))
    }

    private var recentPRs: [PersonalRecord] {
        Array(
            athlete.personalRecords
                .sorted(by: { $0.achievedAt > $1.achievedAt })
                .prefix(5)
        )
    }

    private var sessions: [WorkoutSession] {
        athlete.sessions
            .sorted(by: { $0.sessionDate > $1.sessionDate })
    }

    private var filteredSessions: [WorkoutSession] {
        guard let type = selectedSessionType else { return sessions }
        return sessions.filter { $0.sessionType == type }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                recoveryHero
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                acwrTrend
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                workloadSection
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                prSection
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                prescriptionsSection
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                sessionsSection
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                HStack(spacing: 0) {
                    Button { showWorkoutEntry = true } label: {
                        Text("coach.client.logWorkout")
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .background(ColorTokens.surface)

                    Rectangle().fill(ColorTokens.divider).frame(width: 0.5)

                    Button { showPrescribeSheet = true } label: {
                        Text("coach.client.prescribeWorkout")
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .background(ColorTokens.surface)
                }

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
            }
        }
        .background(ColorTokens.background)
        .navigationTitle(athlete.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showWorkoutEntry) {
            CoachWorkoutEntrySheet(athlete: athlete)
                .environment(container)
        }
        .sheet(isPresented: $showPrescribeSheet) {
            if let coachId = viewingCoach?.id {
                PrescribeWorkoutSheet(athlete: athlete, coachId: coachId)
                    .environment(container)
            }
        }
        .task {
            await container.syncService.pullAthleteSnapshots(
                athleteId: athlete.id, context: modelContext
            )
        }
    }

    // MARK: - Sections

    private var recoveryHero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("coach.client.sectionRecovery")
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)

            if let r = latestRecovery {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(String(format: "%.0f", r.recoveryScore))
                        .font(.Tokens.dialValue)
                        .monospacedDigit()
                        .foregroundStyle(ColorTokens.text1)
                    Text(r.zone.displayName)
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text2)
                }
            } else {
                Text("coach.client.recovery.empty")
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
        .background(ColorTokens.surface)
    }

    private var acwrTrend: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("coach.client.sectionACWRTrend")
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            if recentWorkload.isEmpty {
                Text("coach.client.workload.empty")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text3)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            } else {
                Chart(recentWorkload, id: \.id) { snapshot in
                    LineMark(
                        x: .value("Date", snapshot.snapshotDate, unit: .day),
                        y: .value("ACWR", snapshot.acwr)
                    )
                    .foregroundStyle(ColorTokens.chartATL)
                }
                .chartYScale(domain: 0...2)
                .frame(height: 120)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    private var workloadSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("coach.client.sectionRecentLoad")
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            if recentWorkloadList.isEmpty {
                Text("coach.client.workload.empty")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text3)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            } else {
                ForEach(recentWorkloadList, id: \.id) { snapshot in
                    HStack {
                        Text(snapshot.snapshotDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                        Spacer()
                        Text(snapshot.zone.displayName)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                        Text(String(format: "%.2f", snapshot.acwr))
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text3)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                }
            }
        }
    }

    private var prSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("coach.client.sectionPRs")
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            if recentPRs.isEmpty {
                Text("coach.client.prs.empty")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text3)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            } else {
                ForEach(recentPRs, id: \.id) { pr in
                    HStack {
                        Text(pr.exerciseName)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text1)
                        Spacer()
                        Text(pr.recordType.displayName)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text3)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                }
            }
        }
    }

    private var prescriptionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("coach.client.sectionPrescribed")
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            if upcomingPrescriptions.isEmpty {
                Text("coach.client.prescribed.empty")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text3)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            } else {
                ForEach(upcomingPrescriptions, id: \.id) { rx in
                    HStack {
                        VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                            Text(rx.templateName)
                                .font(.Tokens.label)
                                .foregroundStyle(ColorTokens.text1)
                            Text(rx.scheduledDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.Tokens.label)
                                .foregroundStyle(ColorTokens.text3)
                        }
                        Spacer()
                        Text(rx.status.displayName)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                }
            }
        }
    }

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("coach.client.sectionSessions")
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
            SessionTypeFilterBar(selectedType: $selectedSessionType)
            Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

            if sessions.isEmpty {
                Text("coach.client.sessions.empty")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text3)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            } else if filteredSessions.isEmpty {
                Text(String(localized: "coach.client.sessions.noMatch", defaultValue: "No \(selectedSessionType?.displayName ?? "matching") sessions found."))
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
            } else {
                ForEach(filteredSessions, id: \.id) { session in
                    VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                        HStack {
                            Text(session.sessionDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.Tokens.label)
                                .foregroundStyle(ColorTokens.text1)
                            Spacer()
                            Text(session.sessionType.displayName)
                                .font(.Tokens.label)
                                .foregroundStyle(ColorTokens.text2)
                        }
                        Text(attributionLabel(for: session))
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text3)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                }
            }
        }
    }

    private func attributionLabel(for session: WorkoutSession) -> String {
        guard let coachId = session.loggedByCoachId else { return "Self" }
        if let vc = viewingCoach, coachId == vc.id { return "You" }
        let name = allAthletes.first(where: { $0.id == coachId })?.displayName
        return name ?? "Unknown Coach"
    }
}
