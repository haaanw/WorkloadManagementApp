import SwiftUI
import SwiftData

/// The day's proposal on the screen where the day starts (v1.7.3 feature 7, slice 2 — R1).
///
/// Self-contained: owns the verdict ViewModel, the decision→VerdictEvent logger seam, the
/// program designation wire, and its own start/import sheets — so Home mounts it in three
/// lines and the Log tab sheds the card without losing any machinery. The decision seam
/// stays single-surfaced: this is now the ONE place a verdict is accepted, kept, or felt.
///
/// With no plan for today, the surface still carries the loop (R5/R6): an equal-weight
/// choice between bringing your program and starting unplanned — the door exists on the
/// Today surface, and the blank path is a fallback, never the default.
struct TodayProposalSection: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Query private var athletes: [Athlete]

    /// Suppresses the no-plan fallback while the first-run welcome card owns the screen.
    var showsNoPlanFallback: Bool = true
    /// Fired after a decision or plan change so the host can refresh readings that cite it.
    var onProposalChanged: () -> Void = {}

    @State private var verdictVM: TodayVerdictViewModel?
    @State private var verdictRepository: VerdictEventRepository?
    @State private var resolvedPlanForSession: ResolvedSessionPlan?
    @State private var showResolvedWorkout = false
    @State private var showUnplannedWorkout = false
    @State private var showProgramImport = false
    // Program designation repos (feature 6 wire) — held as @State (deinit trap).
    @State private var designationPlannedRepo: PlannedSessionRepository?
    @State private var designationScheduleRepo: ScheduleRepository?
    @State private var designationProgramRepo: ProgramRepository?

    private var athlete: Athlete? { athletes.first }

    var body: some View {
        Group {
            if let vm = verdictVM, let display = vm.display, let athlete {
                SectionContainer {
                    TodayVerdictCard(
                        display: display,
                        weightUnit: athlete.weightUnit,
                        canStartWorkout: vm.canStartResolvedWorkout,
                        onAccept: { vm.accept(); onProposalChanged() },
                        onKeepPlan: { vm.keepPlan(); onProposalChanged() },
                        onFeel: { vm.feelOverride($0); onProposalChanged() },
                        onStartWorkout: {
                            guard let plan = vm.resolvedPlanForWorkout else {
                                assertionFailure("Start tapped without a resolvable plan — canStartWorkout/resolvedPlanForWorkout drifted")
                                return
                            }
                            resolvedPlanForSession = plan
                            showResolvedWorkout = true
                        }
                    )
                    .padding(.horizontal, Spacing.sm)
                }
            } else if athlete != nil, showsNoPlanFallback {
                noPlanCard
            }
        }
        .task(id: athletes.first?.id) {
            wireIfNeeded()
            refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            refresh()
        }
        .sheet(isPresented: $showResolvedWorkout, onDismiss: {
            refresh()
            onProposalChanged()
        }) {
            if let plan = resolvedPlanForSession {
                ActiveWorkoutSheet(resolvedPlan: plan)
                    .environment(container)
            }
        }
        .sheet(isPresented: $showUnplannedWorkout, onDismiss: {
            refresh()
            onProposalChanged()
        }) {
            ActiveWorkoutSheet()
                .environment(container)
        }
        .sheet(isPresented: $showProgramImport, onDismiss: {
            refresh()
            onProposalChanged()
        }) {
            ProgramImportSheet()
                .environment(container)
        }
    }

    // MARK: - No-plan proposal (R5/R6: the door lives on the Today surface)

    private var noPlanCard: some View {
        SectionContainer {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                AnnotationLabel(key: "todayProposal.noPlan.stamp")
                Text("todayProposal.noPlan.body")
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text1)
                    .fixedSize(horizontal: false, vertical: true)
                KeyRow([
                    KeyRow.Key(
                        title: "workoutLog.menu.bringProgram",
                        accessibilityID: "dashboard.proposal.bringProgram"
                    ) {
                        showProgramImport = true
                    },
                    KeyRow.Key(
                        title: "todayProposal.startUnplanned",
                        accessibilityID: "dashboard.proposal.startUnplanned"
                    ) {
                        showUnplannedWorkout = true
                    }
                ])
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.sm)
            .emphasisCardStyle()
            .padding(.horizontal, Spacing.sm)
        }
    }

    // MARK: - Wiring (moved verbatim from the Log tab's mount — slice 2)

    private func wireIfNeeded() {
        guard verdictVM == nil else { return }
        let vm = TodayVerdictViewModel(modelContext: modelContext)
        let repository = VerdictEventRepository(modelContext: modelContext)
        verdictRepository = repository
        let loggedAthlete = athletes.first
        // SC4 ordering guard: the logger seam is wired at construction, so this surface
        // can never record a decision without a VerdictEvent.
        vm.onDecisionRecorded = { [weak vm] decision in
            guard let vm else { return }
            let delta = (decision.adjustedTopSetKg ?? decision.plannedTopSetKg) - decision.plannedTopSetKg
            repository.log(
                decidedAt: decision.decidedAt,
                planDate: .now,
                verdictKindRaw: vm.lastHeadlineVerdictRaw ?? "go",
                plannedTopSetKg: decision.plannedTopSetKg,
                adjustedTopSetKg: decision.adjustedTopSetKg,
                deltaKg: delta,
                differed: decision.hadAdjustment,
                actionRaw: dashboardVerdictActionRaw(decision.action),
                regionRaw: vm.lastHeadlineRegionRaw ?? MuscleRegion.fullBody.rawValue,
                reasonLine: decision.reasonLine,
                confidenceNote: vm.display?.confidenceNote,
                prescriptionId: vm.currentPrescriptionId,
                suggestedBackoffSetCut: decision.suggestedBackoffSetCut,
                suggestedRPECap: decision.suggestedRPECap,
                matchProximity: vm.lastHeadlineMatchProximity,
                athlete: loggedAthlete
            )
        }
        verdictVM = vm
    }

    private func refresh() {
        guard let athlete else { return }
        ensureProgramDesignation(athleteId: athlete.id)
        verdictVM?.refresh(athlete: athlete)
    }

    /// The program→proposal wire (feature 6, epic 1): designate today's program day when
    /// nothing is designated yet, so the card proposes it without a manual Plan Today step.
    private func ensureProgramDesignation(athleteId: UUID) {
        if designationPlannedRepo == nil {
            designationPlannedRepo = PlannedSessionRepository(modelContext: modelContext)
            designationScheduleRepo = ScheduleRepository(modelContext: modelContext)
            designationProgramRepo = ProgramRepository(modelContext: modelContext)
        }
        guard let plannedRepo = designationPlannedRepo,
              let scheduleRepo = designationScheduleRepo,
              let programRepo = designationProgramRepo else { return }
        ProgramScheduleService.ensureTodayDesignation(
            athleteId: athleteId,
            plannedSessionRepo: plannedRepo,
            scheduleRepo: scheduleRepo,
            programRepo: programRepo
        )
    }
}

/// Map a `VerdictDecision.action` to the composite `VerdictEvent.actionRaw` token
/// (same mapping the Log tab used — the token vocabulary is a persistence contract).
private func dashboardVerdictActionRaw(_ action: VerdictAction) -> String {
    switch action {
    case .accepted: return "accepted"
    case .keptPlan: return "keptPlan"
    case .feel(.feelingStrong): return "feelStrong"
    case .feel(.feelingRough): return "feelRough"
    }
}
