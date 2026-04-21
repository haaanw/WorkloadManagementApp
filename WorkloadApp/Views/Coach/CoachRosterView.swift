import SwiftUI
import SwiftData

struct CoachRosterView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Query private var athletes: [Athlete]

    @State private var viewModel = CoachRosterViewModel()
    @State private var showAddClient = false

    private var athlete: Athlete? { athletes.first }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.linkedAthletes.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(ColorTokens.background)
                } else if viewModel.linkedAthletes.isEmpty {
                    emptyState
                } else {
                    clientList
                }
            }
            .background(ColorTokens.background)
            .navigationTitle("Roster")
            .withContextSwitcher()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Client") { showAddClient = true }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text1)
                }
            }
            .sheet(isPresented: $showAddClient) {
                Text("Invite an athlete — see Profile for invite options")
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text2)
                    .padding(24)
            }
        }
        .task {
            guard let id = athlete?.id else { return }
            await viewModel.load(context: modelContext, coachAthleteId: id)
        }
        .onChange(of: container.currentMode) { _, newMode in
            guard newMode == .coach, let id = athlete?.id else { return }
            Task {
                // Give sync a moment to write to SwiftData before reloading
                try? await Task.sleep(for: .milliseconds(500))
                await viewModel.load(context: modelContext, coachAthleteId: id)
            }
        }
    }

    private var clientList: some View {
        List {
            ForEach(viewModel.linkedAthletes, id: \.id) { client in
                NavigationLink {
                    ClientDetailView(athlete: client)
                } label: {
                    ClientCard(
                        athlete: client,
                        workload: viewModel.latestWorkloadSnapshot[client.id],
                        recovery: viewModel.latestRecoverySnapshot[client.id]
                    )
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(ColorTokens.surface)
                .listRowSeparatorTint(ColorTokens.divider)
            }
        }
        .listStyle(.plain)
        .refreshable {
            guard let id = athlete?.id else { return }
            await container.syncService.pullLinkedAthletes(context: modelContext)
            for client in viewModel.linkedAthletes {
                await container.syncService.pullAthleteSnapshots(
                    athleteId: client.id, context: modelContext
                )
            }
            await viewModel.load(context: modelContext, coachAthleteId: id)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No clients yet")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
            Text("Invite an athlete from your Profile to see their workload here.")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
        .background(ColorTokens.background)
    }
}

// MARK: - Client Card

private struct ClientCard: View {
    let athlete: Athlete
    let workload: WorkloadSnapshot?
    let recovery: RecoverySnapshot?

    var body: some View {
        HStack(spacing: 0) {
            // 3pt colored left border — supplementary zone indicator.
            // Zone identity is always communicated via text labels below.
            Rectangle()
                .fill(recoveryBorderColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(athlete.displayName)
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text1)
                    Spacer()
                    Text(athlete.sportType.displayName)
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text3)
                }

                HStack {
                    Text(recovery?.zone.displayName ?? "No recovery data")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                    Spacer()
                    Text(workload?.zone.displayName ?? "No load data")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
    }

    private var recoveryBorderColor: Color {
        guard let recovery else { return ColorTokens.divider }
        return ColorTokens.recoveryZoneColor(recovery.zone)
    }
}
