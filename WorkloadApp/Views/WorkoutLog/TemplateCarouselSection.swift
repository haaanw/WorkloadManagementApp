import SwiftUI
import SwiftData

struct TemplateCarouselSection: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Query private var athletes: [Athlete]

    // Callbacks for parent coordination
    var onEditTemplate: (WorkoutTemplate) -> Void
    var onStartFromTemplate: (WorkoutTemplate) -> Void
    var onCreateTemplate: () -> Void
    var onPreviewTemplate: ((WorkoutTemplate) -> Void)? = nil
    var onShareTemplate: ((WorkoutTemplate) -> Void)? = nil

    @State private var centeredId: UUID?
    @State private var showDeleteConfirmation = false
    @State private var templateToDelete: WorkoutTemplate?
    @State private var swipeOffset: CGFloat = 0
    @State private var swipedTemplateId: UUID?
    @State private var suggestionResult: TemplateSuggestionEngine.SuggestionResult?

    // MARK: - Template Fetching

    private var templates: [WorkoutTemplate] {
        guard let athleteId = athletes.first?.id else { return [] }
        return (try? TemplateRepository(modelContext: modelContext)
            .fetchAthleteTemplates(athleteId: athleteId)) ?? []
    }

    // MARK: - ISO Weekday

    private var todayISOWeekday: Int {
        let apple = Calendar.current.component(.weekday, from: .now)
        return apple == 1 ? 7 : apple - 1  // Apple 1=Sun -> ISO 7=Sun
    }

    // MARK: - Centering Logic

    private func initialCenteredId() -> UUID? {
        let today = todayISOWeekday
        let todayTemplates = templates.filter { $0.scheduledDays.contains(today) }
        if !todayTemplates.isEmpty {
            return todayTemplates
                .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
                .first?.id
        }
        let byLastUsed = templates.sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
        if let mostRecent = byLastUsed.first, mostRecent.lastUsedAt != nil {
            return mostRecent.id
        }
        return templates.first?.id
    }

    // MARK: - Body

    var body: some View {
        if templates.isEmpty {
            emptyState
        } else {
            carouselContent
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("empty.noTemplates.title")
                .font(.Tokens.sectionHead)
                .foregroundStyle(ColorTokens.text1)

            Text("empty.noTemplates.description")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text2)
                .multilineTextAlignment(.center)

            Button {
                onCreateTemplate()
            } label: {
                Text("action.createTemplate")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(ColorTokens.background)
    }

    // MARK: - Carousel

    private var carouselContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("section.myTemplates")
                .font(.Tokens.micro)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(ColorTokens.text3)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(templates, id: \.id) { template in
                        templateCard(template)
                            .containerRelativeFrame(.horizontal) { size, _ in size - 80 }
                            .scrollTransition { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1.0 : 0.85)
                                    .opacity(phase.isIdentity ? 1.0 : 0.6)
                            }
                    }

                    // New Template card
                    newTemplateCard
                        .containerRelativeFrame(.horizontal) { size, _ in size - 80 }
                        .scrollTransition { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1.0 : 0.85)
                                .opacity(phase.isIdentity ? 1.0 : 0.6)
                        }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $centeredId)
            .onAppear {
                if centeredId == nil {
                    centeredId = initialCenteredId()
                }
                computeSuggestion()
            }
        }
        .confirmationDialog("confirm.deleteTemplate", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("action.delete", role: .destructive) {
                if let t = templateToDelete { deleteTemplate(t) }
            }
            Button("action.cancel", role: .cancel) {}
        } message: {
            Text(String(format: String(localized: "confirm.deleteTemplate.message", defaultValue: "This will permanently remove '%@'. This cannot be undone."), templateToDelete?.templateName ?? ""))
        }
    }

    // MARK: - Template Card

    private func templateCard(_ template: WorkoutTemplate) -> some View {
        let isCentered = template.id == centeredId
        let exercises = template.sortedGroups.flatMap { $0.sortedExercises }
        let totalSets = exercises.flatMap { $0.sortedSets }.count

        return ZStack(alignment: .leading) {
            // Swipe action background
            if isCentered {
                HStack(spacing: 0) {
                    Spacer()
                    Button {
                        archiveTemplate(template)
                        withAnimation(.easeOut(duration: 0.25)) {
                            swipeOffset = 0
                            swipedTemplateId = nil
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "archivebox")
                                .font(.system(size: 17))
                            Text("action.archive")
                                .font(.Tokens.micro)
                        }
                        .foregroundStyle(ColorTokens.text1)
                        .frame(width: 72, height: 160)
                        .background(ColorTokens.surface)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("a11y.archiveTemplate")

                    Button {
                        templateToDelete = template
                        showDeleteConfirmation = true
                        withAnimation(.easeOut(duration: 0.25)) {
                            swipeOffset = 0
                            swipedTemplateId = nil
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 17))
                            Text("action.delete")
                                .font(.Tokens.micro)
                        }
                        .foregroundStyle(ColorTokens.zoneDanger)
                        .frame(width: 72, height: 160)
                        .background(ColorTokens.surface)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("a11y.deleteTemplate")
                }
            }

            // Card content
            VStack(alignment: .leading, spacing: 0) {
                // Top row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(template.templateName)
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                            .lineLimit(2)

                        Text(String(format: String(localized: "template.typeDisplay", defaultValue: "%@ - %@"), template.sportType.displayName, template.sessionType.displayName))
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)

                        Text(String(format: String(localized: "template.exerciseSetCount", defaultValue: "%d exercises, %d sets"), exercises.count, totalSets))
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                    }
                    Spacer()
                    Image(systemName: template.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 15))
                        .foregroundStyle(template.isFavorite ? ColorTokens.zoneCaution : ColorTokens.text3)
                }

                Spacer()

                // Bottom row
                HStack(alignment: .bottom) {
                    weekdayInitials(scheduledDays: template.scheduledDays)

                    Spacer()

                    if let lastUsed = template.lastUsedAt {
                        Text(String(format: String(localized: "template.lastUsed", defaultValue: "Last used %@"), lastUsed.formatted(.relative(presentation: .named))))
                            .font(.Tokens.micro)
                            .foregroundStyle(ColorTokens.text3)
                    }
                }
            }
            .padding(16)
            .frame(height: 160)
            .background(ColorTokens.surface)
            .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))
            .overlay(alignment: .topTrailing) {
                if container.subscriptionService.isPro,
                   let suggestion = suggestionResult,
                   suggestion.template.id == template.id {
                    Text(suggestion.isRecoveryAdjusted ? "template.label.recoveryAdjusted" : "template.label.suggested")
                        .font(.Tokens.micro)
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(ColorTokens.text2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .overlay(
                            Rectangle().stroke(
                                suggestion.isRecoveryAdjusted ? ColorTokens.zoneCaution : ColorTokens.zoneOptimal,
                                lineWidth: 0.5
                            )
                        )
                        .padding(8)
                }
            }
            .offset(x: isCentered && swipedTemplateId == template.id ? swipeOffset : 0)
            .gesture(
                isCentered
                    ? DragGesture()
                        .onChanged { value in
                            let translation = min(0, value.translation.width)
                            swipeOffset = max(-144, translation)
                            swipedTemplateId = template.id
                        }
                        .onEnded { value in
                            withAnimation(.easeOut(duration: 0.25)) {
                                if swipeOffset < -72 {
                                    swipeOffset = -144
                                } else {
                                    swipeOffset = 0
                                    swipedTemplateId = nil
                                }
                            }
                        }
                    : nil
            )
            .onTapGesture {
                if swipedTemplateId == template.id && swipeOffset < 0 {
                    withAnimation(.easeOut(duration: 0.25)) {
                        swipeOffset = 0
                        swipedTemplateId = nil
                    }
                    return
                }
                if isCentered {
                    onStartFromTemplate(template)
                } else {
                    withAnimation(.easeOut(duration: 0.25)) {
                        centeredId = template.id
                    }
                }
            }
            .contextMenu {
                if let onPreviewTemplate {
                    Button { onPreviewTemplate(template) } label: {
                        Label("action.preview", systemImage: "eye")
                    }
                }
                Button { onEditTemplate(template) } label: {
                    Label("action.editTemplate", systemImage: "pencil")
                }
                Button { duplicateTemplate(template) } label: {
                    Label("action.duplicateTemplate", systemImage: "doc.on.doc")
                }
                if let onShareTemplate {
                    Button { onShareTemplate(template) } label: {
                        Label("action.shareTemplate", systemImage: "square.and.arrow.up")
                    }
                }
                Button { toggleFavorite(template) } label: {
                    Label(template.isFavorite ? "action.unfavorite" : "action.favorite",
                          systemImage: template.isFavorite ? "star.fill" : "star")
                }
                Button { archiveTemplate(template) } label: {
                    Label("action.archiveTemplate", systemImage: "archivebox")
                }
                Divider()
                Button(role: .destructive) {
                    templateToDelete = template
                    showDeleteConfirmation = true
                } label: {
                    Label("action.deleteTemplate", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - New Template Card

    private var newTemplateCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 24))
                .foregroundStyle(ColorTokens.text2)
            Text("action.createTemplate")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .background(ColorTokens.background)
        .overlay(
            Rectangle()
                .stroke(style: StrokeStyle(lineWidth: 0.5, dash: [6, 4]))
                .foregroundStyle(ColorTokens.divider)
        )
        .onTapGesture {
            onCreateTemplate()
        }
    }

    // MARK: - Weekday Initials

    private func weekdayInitials(scheduledDays: [Int]) -> some View {
        let days = ["M", "T", "W", "T", "F", "S", "S"]
        return HStack(spacing: 4) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, initial in
                let isoDay = index + 1  // 1=Mon...7=Sun
                Text(initial)
                    .font(.Tokens.micro)
                    .foregroundStyle(scheduledDays.contains(isoDay)
                        ? ColorTokens.text1
                        : ColorTokens.text3)
            }
        }
    }

    // MARK: - Suggestion

    private func computeSuggestion() {
        guard container.subscriptionService.isPro else { return }
        guard let athleteId = athletes.first?.id else { return }
        let allTemplates = (try? TemplateRepository(modelContext: modelContext)
            .fetchAthleteTemplates(athleteId: athleteId)) ?? []
        guard !allTemplates.isEmpty else { return }

        let fourWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -4, to: .now)!
        let sessionDescriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.sessionDate >= fourWeeksAgo },
            sortBy: [SortDescriptor(\.sessionDate, order: .reverse)]
        )
        let sessions = (try? modelContext.fetch(sessionDescriptor)) ?? []

        var recoveryDescriptor = FetchDescriptor<RecoverySnapshot>(
            sortBy: [SortDescriptor<RecoverySnapshot>(\.date, order: .reverse)]
        )
        recoveryDescriptor.fetchLimit = 1
        let latestRecovery = (try? modelContext.fetch(recoveryDescriptor))?.first
        let recoveryZone = latestRecovery.map { RecoveryZone.classify(score: $0.recoveryScore) } ?? .green

        suggestionResult = TemplateSuggestionEngine.suggest(
            templates: allTemplates,
            recentSessions: sessions,
            currentRecoveryZone: recoveryZone
        )

        // Auto-center on suggested template
        if let suggestion = suggestionResult {
            centeredId = suggestion.template.id
        }
    }

    // MARK: - CRUD Helpers

    private func duplicateTemplate(_ template: WorkoutTemplate) {
        guard let athleteId = athletes.first?.id else { return }
        do {
            _ = try TemplateRepository(modelContext: modelContext).duplicate(template, athleteId: athleteId)
            Task { await container.syncService.pushWorkoutTemplates(context: modelContext, coachId: athleteId) }
        } catch {
            print("Duplicate template error: \(error)")
        }
    }

    private func toggleFavorite(_ template: WorkoutTemplate) {
        template.isFavorite.toggle()
        template.updatedAt = .now
        do {
            try modelContext.save()
            guard let athleteId = athletes.first?.id else { return }
            Task { await container.syncService.pushWorkoutTemplates(context: modelContext, coachId: athleteId) }
        } catch {
            print("Toggle favorite error: \(error)")
        }
    }

    private func archiveTemplate(_ template: WorkoutTemplate) {
        do {
            try TemplateRepository(modelContext: modelContext).archive(template)
            guard let athleteId = athletes.first?.id else { return }
            Task { await container.syncService.pushWorkoutTemplates(context: modelContext, coachId: athleteId) }
        } catch {
            print("Archive template error: \(error)")
        }
    }

    private func deleteTemplate(_ template: WorkoutTemplate) {
        do {
            try TemplateRepository(modelContext: modelContext).delete(template)
            guard let athleteId = athletes.first?.id else { return }
            Task { await container.syncService.pushWorkoutTemplates(context: modelContext, coachId: athleteId) }
        } catch {
            print("Delete template error: \(error)")
        }
    }
}
