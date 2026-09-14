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
    // Presented via .sheet(item:) — the boolean-plus-optional pair raced under load and
    // presented an EMPTY sheet (caught by the store-plate harness, 2026-09-09).
    @State private var resolvedPlanForSession: ResolvedSessionPlan?
    @State private var showUnplannedWorkout = false
    @State private var showProgramImport = false
    /// UAT round 3 · U25: the day's ONE action. The verdict card stays on Today as a preview of
    /// what the app sees; the decision, the readings behind it and the numbers all live one tap
    /// away in the brief, which is also the only door to the session from here.
    @State private var showPreSessionBrief = false
    // Program designation repos (feature 6 wire) — held as @State (deinit trap).
    @State private var designationPlannedRepo: PlannedSessionRepository?
    @State private var designationScheduleRepo: ScheduleRepository?
    @State private var designationProgramRepo: ProgramRepository?
    /// UAT round 2 · U14: the bring-card used to stand in for "nothing designated today",
    /// so it sat under the readiness score on every rest day of an ACTIVE program. These two
    /// separate "no plan at all" from "no session today", read once per refresh.
    @State private var hasActiveProgram = false
    @State private var todayHasProgramSession = false
    @State private var nextPlannedSessionDate: Date?

    private var athlete: Athlete? { athletes.first }

    var body: some View {
        Group {
            if let vm = verdictVM, let display = vm.display, let athlete {
                SectionContainer {
                    VStack(spacing: Spacing.sm) {
                        // The card is a PREVIEW of the day: it still carries the state, the
                        // number and the reason, and its inline cells still decide. What it no
                        // longer carries is the start door — `onStartWorkout` is nil here, so
                        // the section has exactly ONE ink pill (U25 / the CTA Law).
                        TodayVerdictCard(
                            display: display,
                            weightUnit: athlete.weightUnit,
                            canStartWorkout: false,
                            onAccept: { vm.accept(); onProposalChanged() },
                            onKeepPlan: { vm.keepPlan(); onProposalChanged() },
                            onFeel: { vm.feelOverride($0); onProposalChanged() },
                            onStartWorkout: nil
                        )

                        // U25: "Start today" — the day's one action. It opens the brief, which
                        // states what the app sees, what it therefore suggests, and the numbers
                        // the session will start with.
                        PrimaryActionButton(title: "todayProposal.startToday") {
                            showPreSessionBrief = true
                        }
                        .accessibilityIdentifier("dashboard.proposal.startToday")
                    }
                    .padding(.horizontal, Spacing.sm)
                }
            } else if athlete != nil, showsNoPlanFallback {
                // Three states, not two (U14): a block is running and today is simply not a
                // training day → say so; no block at all → offer the door.
                if hasActiveProgram {
                    // Today DOES carry a program session but the card could not be built
                    // (a missing template, a verdict the engine cannot yet form). Saying
                    // "rest day" there would be a lie, so this states nothing instead —
                    // the Log tab's day cell still starts the session.
                    if !todayHasProgramSession {
                        restDayCard
                    }
                } else {
                    noPlanCard
                }
            }
        }
        .task(id: athletes.first?.id) {
            wireIfNeeded()
            refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            refresh()
        }
        .sheet(isPresented: $showPreSessionBrief, onDismiss: {
            refresh()
            onProposalChanged()
        }) {
            if let vm = verdictVM, let athlete {
                PreSessionBriefView(
                    viewModel: vm,
                    weightUnit: athlete.weightUnit,
                    onProposalChanged: onProposalChanged
                )
                .environment(container)
            }
        }
        .sheet(item: $resolvedPlanForSession, onDismiss: {
            refresh()
            onProposalChanged()
        }) { plan in
            ActiveWorkoutSheet(resolvedPlan: plan)
                .environment(container)
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

    // MARK: - Rest day (U14: a running block, nothing scheduled today)

    /// One quiet line and one quiet way out. No ink pill — a rest day is not a call to
    /// action, and the day's one pill belongs to the surface below when there is a session
    /// to start. "Start unplanned" stays reachable because an unscheduled session is still
    /// an athlete's own business.
    private var restDayCard: some View {
        SectionContainer {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                AnnotationLabel(key: "todayProposal.restDay.stamp")
                Text(verbatim: restDayLine)
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text1)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    Haptics.tap()
                    showUnplannedWorkout = true
                } label: {
                    Text("todayProposal.startUnplanned")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                        .frame(minHeight: 32, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("dashboard.proposal.startUnplanned")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.sm)
            .cardStyle(horizontalPadding: 0, verticalPadding: 0)
            .padding(.horizontal, Spacing.sm)
        }
    }

    private var restDayLine: String {
        guard let next = nextPlannedSessionDate else {
            return String(
                localized: "todayProposal.restDay.noneThisWeek",
                defaultValue: "Rest day — no session scheduled this week."
            )
        }
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("EEEdMMM")
        return String(
            format: String(
                localized: "todayProposal.restDay.next",
                defaultValue: "Rest day — next session %@."
            ),
            formatter.string(from: next)
        )
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
        refreshProgramState(athleteId: athlete.id)
        verdictVM?.refresh(athlete: athlete)
    }

    /// Reads the two facts the three-way branch needs (U14). `fetchActiveProgram` is the
    /// ONLY thing that answers "does this athlete have a plan" — `vm.display == nil` only
    /// ever meant "nothing designated today", which is true on every rest day.
    private func refreshProgramState(athleteId: UUID) {
        guard let programRepo = designationProgramRepo,
              let scheduleRepo = designationScheduleRepo else { return }
        hasActiveProgram = programRepo.fetchActiveProgram(athleteId: athleteId) != nil
        guard hasActiveProgram else {
            todayHasProgramSession = false
            nextPlannedSessionDate = nil
            return
        }
        todayHasProgramSession = scheduleRepo
            .entries(on: .now, athleteId: athleteId)
            .contains { $0.kind == .programSession && ($0.status == .planned || $0.status == .completed) }
        let calendar = Calendar.current
        let tomorrow = calendar.date(
            byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)
        ) ?? .now
        let horizon = calendar.date(byAdding: .day, value: 14, to: tomorrow) ?? tomorrow
        nextPlannedSessionDate = scheduleRepo
            .entries(from: tomorrow, to: horizon, athleteId: athleteId)
            .first { $0.kind == .programSession && $0.status == .planned }?
            .date
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
