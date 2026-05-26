import SwiftUI
import SwiftData

struct WorkoutLogView: View {
    @Query(sort: \WorkoutSession.sessionDate, order: .reverse)
    private var sessions: [WorkoutSession]
    @Query private var athletes: [Athlete]
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @State private var showActiveWorkout = false
    @State private var showUpgrade = false
    @State private var selectedSessionType: SessionType? = nil
    @State private var activePrescription: PrescribedWorkout?
    @State private var importSuggestions: [WorkoutImportSuggestion] = []
    @State private var importRPESheet: WorkoutImportSuggestion?
    @State private var showMyPrograms = false
    @State private var showTextImport = false
    @State private var selectedTemplateForPreview: WorkoutTemplate?
    @State private var selectedTemplateForShare: WorkoutTemplate?
    @State private var showTemplateEditor = false
    @State private var editingTemplate: WorkoutTemplate?
    @State private var showTemplatePicker = false
    @State private var selectedTemplateForSession: WorkoutTemplate?
    @State private var showShareImport = false
    @State private var shareImportResult: SharedTemplateResponse?
    @State private var showLLMImport = false

    private var visibleSessions: [WorkoutSession] {
        let base = container.subscriptionService.isPro
            ? sessions
            : SubscriptionService.filterSessionsForFree(sessions)
        guard let type = selectedSessionType else { return base }
        return base.filter { $0.sessionType == type }
    }

    private var upcomingPrescriptions: [PrescribedWorkout] {
        guard let athleteId = athletes.first?.id else { return [] }
        let assigned = PrescriptionStatus.assigned.rawValue
        guard let results = try? modelContext.fetch(
            FetchDescriptor<PrescribedWorkout>(
                predicate: #Predicate { $0.athleteId == athleteId && $0.statusRawValue == assigned },
                sortBy: [SortDescriptor(\.scheduledDate)]
            )
        ) else { return [] }
        return results
    }

    private var lockedWeeks: Int {
        guard !container.subscriptionService.isPro else { return 0 }
        let visible = SubscriptionService.filterSessionsForFree(sessions)
        return SubscriptionService.lockedWeeks(
            totalSessions: sessions.count,
            visibleSessions: visible.count
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                SessionTypeFilterBar(selectedType: $selectedSessionType)
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                ScrollView {
                    VStack(spacing: 0) {
                        // Template carousel
                        TemplateCarouselSection(
                            onEditTemplate: { template in
                                editingTemplate = template
                                showTemplateEditor = true
                            },
                            onStartFromTemplate: { template in
                                selectedTemplateForSession = template
                                showActiveWorkout = true
                            },
                            onCreateTemplate: {
                                editingTemplate = nil
                                showTemplateEditor = true
                            },
                            onPreviewTemplate: { template in
                                selectedTemplateForPreview = template
                            },
                            onShareTemplate: { template in
                                selectedTemplateForShare = template
                            }
                        )
                        Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                        // HealthKit import suggestions
                        if !importSuggestions.isEmpty {
                            WorkoutImportBanner(
                                imports: importSuggestions,
                                onAccept: { suggestion in
                                    importRPESheet = suggestion
                                },
                                onDismiss: { suggestion in
                                    WorkoutImportService.dismissSuggestion(suggestion)
                                    withAnimation {
                                        importSuggestions.removeAll { $0.id == suggestion.id }
                                    }
                                }
                            )
                            Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                        }

                        // Prescribed workouts
                        if !upcomingPrescriptions.isEmpty {
                            Text("PRESCRIBED")
                                .font(.Tokens.micro)
                                .tracking(1.2)
                                .foregroundStyle(ColorTokens.text3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                                .padding(.bottom, 8)

                            ForEach(upcomingPrescriptions, id: \.id) { rx in
                                PrescribedWorkoutCard(
                                    prescription: rx,
                                    onStart: {
                                        activePrescription = rx
                                        showActiveWorkout = true
                                    },
                                    onSkip: {
                                        rx.markSkipped()
                                        try? modelContext.save()
                                        Task {
                                            await container.syncService.pushPrescribedWorkout(rx)
                                        }
                                    }
                                )
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                            }

                            Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                        }

                        // Session history
                        if visibleSessions.isEmpty && importSuggestions.isEmpty {
                            VStack(spacing: 16) {
                                Text("No Workouts Yet")
                                    .font(.Tokens.sectionHead)
                                    .foregroundStyle(ColorTokens.text1)
                                Text("Tap + to log your first workout session.")
                                    .font(.Tokens.label)
                                    .foregroundStyle(ColorTokens.text2)
                            }
                            .padding(.vertical, 48)
                            .frame(maxWidth: .infinity)
                        } else {
                            ForEach(visibleSessions, id: \.id) { session in
                                NavigationLink(value: session.id) {
                                    SessionRow(session: session)
                                }
                                .buttonStyle(.plain)

                                Rectangle()
                                    .fill(ColorTokens.divider)
                                    .frame(height: 0.5)
                            }

                            if lockedWeeks > 0 {
                                HistoryTeaserBanner(lockedWeeks: lockedWeeks) {
                                    showUpgrade = true
                                }
                            }
                        }
                    }
                }
                .background(ColorTokens.background)
            }
            .navigationTitle("Workout Log")
            .toolbarBackground(ColorTokens.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .withContextSwitcher()
            .navigationDestination(for: UUID.self) { sessionId in
                if let session = sessions.first(where: { $0.id == sessionId }) {
                    SessionDetailView(session: session)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 16) {
                        Menu {
                            Button {
                                showLLMImport = true
                            } label: {
                                Label("Import Workout (AI)", systemImage: "sparkles")
                            }
                            Button {
                                showMyPrograms = true
                            } label: {
                                Label("My Programs", systemImage: "doc.text.fill")
                            }
                            Button {
                                if container.subscriptionService.isPro {
                                    showTextImport = true
                                } else {
                                    showUpgrade = true
                                }
                            } label: {
                                Label("Import Program (Text)", systemImage: "doc.plaintext")
                            }
                            Button {
                                showShareImport = true
                            } label: {
                                Label("Import Shared Template", systemImage: "square.and.arrow.down")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(ColorTokens.text2)
                        }
                        Button {
                            showTemplatePicker = true
                        } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(ColorTokens.text1)
                        }
                    }
                }
            }
            .sheet(isPresented: $showActiveWorkout) {
                ActiveWorkoutSheet(
                    prescription: activePrescription,
                    template: selectedTemplateForSession
                )
            }
            .onChange(of: showActiveWorkout) { _, isPresented in
                if !isPresented {
                    activePrescription = nil
                    selectedTemplateForSession = nil
                }
            }
            .sheet(isPresented: $showTemplatePicker) {
                TemplatePickerSheet(
                    onSelectTemplate: { template in
                        selectedTemplateForSession = template
                        showActiveWorkout = true
                    },
                    onStartBlank: {
                        activePrescription = nil
                        selectedTemplateForSession = nil
                        showActiveWorkout = true
                    },
                    onCreateTemplate: {
                        editingTemplate = nil
                        showTemplateEditor = true
                    }
                )
                .environment(container)
            }
            .sheet(isPresented: $showUpgrade) {
                UpgradeSheet(trigger: .history(lockedWeeks: lockedWeeks))
            }
            .sheet(item: $importRPESheet) { suggestion in
                ImportRPESheet(suggestion: suggestion) { rpe in
                    acceptImport(suggestion, rpe: rpe)
                }
            }
            .sheet(isPresented: $showMyPrograms) {
                NavigationStack {
                    TemplateListView()
                        .environment(container)
                }
            }
            .sheet(isPresented: $showTextImport) {
                TextTemplateImportSheet()
                    .environment(container)
            }
            .sheet(item: $selectedTemplateForPreview) { template in
                TemplatePreviewSheet(
                    template: template,
                    onEdit: {
                        selectedTemplateForPreview = nil
                        editingTemplate = template
                        showTemplateEditor = true
                    }
                )
                .environment(container)
            }
            .sheet(item: $selectedTemplateForShare) { template in
                ShareCodeSheet(template: template)
                    .environment(container)
            }
            .sheet(isPresented: $showLLMImport) {
                WorkoutImportSheet()
                    .environment(container)
            }
            .sheet(isPresented: $showShareImport) {
                ShareImportSheet(onLookupSuccess: { result in
                    shareImportResult = result
                })
                .environment(container)
            }
            .sheet(item: $shareImportResult) { result in
                ShareImportPreviewSheet(response: result)
                    .environment(container)
            }
            .sheet(isPresented: $showTemplateEditor) {
                if let athleteId = athletes.first?.id {
                    TemplateEditorSheet(
                        coachId: athleteId,
                        existingTemplate: editingTemplate
                    )
                    .environment(container)
                }
            }
            .task {
                await loadImportSuggestions()
            }
        }
    }

    private func loadImportSuggestions() async {
        guard container.healthKitService.isAuthorized else { return }
        importSuggestions = await WorkoutImportService.findUnmatchedWorkouts(
            healthKit: container.healthKitService,
            modelContext: modelContext
        )
    }

    private func acceptImport(_ suggestion: WorkoutImportSuggestion, rpe: Double) {
        guard let athlete = athletes.first else { return }
        let session = WorkoutImportService.createSession(
            from: suggestion,
            sessionRPE: rpe,
            athlete: athlete,
            modelContext: modelContext
        )
        modelContext.insert(session)
        try? modelContext.save()

        // Run pipeline
        do {
            _ = try WorkoutPipeline.processSession(
                session,
                athlete: athlete,
                modelContext: modelContext,
                syncService: container.syncService
            )
        } catch {
            print("Import pipeline error: \(error)")
        }

        withAnimation {
            importSuggestions.removeAll { $0.id == suggestion.id }
        }
    }
}

// MARK: - Import RPE Sheet

struct ImportRPESheet: View {
    let suggestion: WorkoutImportSuggestion
    let onConfirm: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var rpe: Double = 5

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text(suggestion.name)
                        .font(.Tokens.sectionHead)
                        .foregroundStyle(ColorTokens.text1)
                    HStack(spacing: 12) {
                        Text(suggestion.date.relativeString(locale: locale))
                        Text(Date.durationString(seconds: suggestion.durationSeconds, locale: locale))
                        if let dist = suggestion.distanceMeters {
                            Text(String(format: "%.1f km", dist / 1000))
                        }
                    }
                    .font(.Tokens.label)
                    .monospacedDigit()
                    .foregroundStyle(ColorTokens.text2)
                }

                VStack(spacing: 8) {
                    Text("How hard was this session?")
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text1)
                    Text("RPE: \(Int(rpe))")
                        .font(.Tokens.pageTitle)
                        .monospacedDigit()
                        .foregroundStyle(ColorTokens.text1)
                    Slider(value: $rpe, in: 1...10, step: 1)
                        .tint(ColorTokens.text2)
                    HStack {
                        Text("Easy").font(.Tokens.label).foregroundStyle(ColorTokens.text3)
                        Spacer()
                        Text("Maximal").font(.Tokens.label).foregroundStyle(ColorTokens.text3)
                    }
                }

                Spacer()
            }
            .padding(24)
            .background(ColorTokens.background)
            .navigationTitle("Import Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        onConfirm(rpe)
                        dismiss()
                    }
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
                }
            }
        }
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: WorkoutSession
    @Environment(\.locale) private var locale

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.sessionName ?? session.sportType.displayName)
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text1)
                HStack(spacing: 12) {
                    Text(Date.durationString(seconds: session.durationSeconds, locale: locale))
                    if session.totalVolume > 0 {
                        Text(String(format: "%.0f kg", session.totalVolume))
                    }
                    if let rpe = session.sessionRPE {
                        Text("RPE \(Int(rpe))")
                    }
                }
                .font(.Tokens.label)
                .monospacedDigit()
                .foregroundStyle(ColorTokens.text2)
            }
            Spacer()
            Text(session.sessionDate.relativeString(locale: locale))
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ColorTokens.background)
    }
}

// MARK: - Session Type Filter Bar

struct SessionTypeFilterBar: View {
    @Binding var selectedType: SessionType?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                SessionFilterChip(label: "All", isSelected: selectedType == nil) {
                    selectedType = nil
                }
                ForEach(SessionType.allCases) { type in
                    SessionFilterChip(label: type.displayName, isSelected: selectedType == type) {
                        selectedType = type
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 40)
        .background(ColorTokens.background)
    }
}

private struct SessionFilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(isSelected ? .Tokens.smallLabelMedium : .Tokens.smallLabel)
                .foregroundStyle(isSelected ? ColorTokens.text1 : ColorTokens.text2)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .overlay(alignment: .leading) {
                    if isSelected {
                        Rectangle()
                            .fill(ColorTokens.text1)
                            .frame(width: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}
