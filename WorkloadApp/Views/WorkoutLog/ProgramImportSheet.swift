import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

/// The one program door (v1.7.3 feature 6, U1 + epic 5): "Bring your program" —
/// paste / PDF / photo / say it, one sheet, one parser (program mode, week/day-preserving).
///
/// Flow (gated demo §3): doors → parse → the duration ladder (a file that states its
/// duration or has multi-week structure is READ and skips the ask; a silent file gets ONE
/// tap to answer) → activate. Activation archives any current block with history intact
/// and materializes the schedule from W1D1.
struct ProgramImportSheet: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var athletes: [Athlete]
    @Query private var recentSessions: [WorkoutSession]

    /// Called after successful activation, with the now-active program.
    var onActivated: ((TrainingProgram) -> Void)? = nil

    private enum Step {
        case doors
        case textEntry(voice: Bool)
        case durationAsk
        case transition
        case done
    }

    @State private var step: Step = .doors
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showDocumentPicker = false
    @State private var showCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var parsedResponse: WorkoutLLMImportService.ParsedProgramResponse?
    @State private var parsedSource: ProgramSource = .text
    @State private var activatedProgram: TrainingProgram?
    @State private var archivedPredecessorName: String?
    @State private var showDurationSuggestion = false
    // Built-but-not-inserted graph, held across the transition-compare step.
    @State private var builtProgram: TrainingProgram?
    @State private var builtTemplates: [WorkoutTemplate] = []
    @State private var comparison: ProgramInsightEngine.TransitionComparison?

    // Held as @State, never method locals (iOS 26.1 @MainActor deinit trap).
    @State private var programRepo: ProgramRepository?
    @State private var scheduleRepo: ScheduleRepository?

    private var athlete: Athlete? { athletes.first }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                InstrumentSheetHeader(title: "programImport.nav.title") {
                    SheetHeaderButton(title: "action.cancel") { dismiss() }
                }

                ZStack {
                    ScrollView {
                        VStack(spacing: Spacing.sm) {
                            switch step {
                            case .doors:
                                doorsContent
                            case .textEntry(let voice):
                                textEntryContent(voice: voice)
                            case .durationAsk:
                                durationAskContent
                            case .transition:
                                transitionContent
                            case .done:
                                doneContent
                            }

                            if let errorMessage {
                                errorBanner(message: errorMessage)
                            }
                        }
                        .padding(Spacing.sm)
                    }
                    .background(ColorTokens.background)

                    if isLoading {
                        loadingOverlay
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .fileImporter(
                isPresented: $showDocumentPicker,
                allowedContentTypes: [.pdf]
            ) { result in
                switch result {
                case .success(let url):
                    handlePDFImport(url: url)
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                ProgramCameraPickerView { image in
                    showCamera = false
                    if let image {
                        handlePhotoImport(image: image)
                    }
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    do {
                        guard let data = try await newItem.loadTransferable(type: Data.self),
                              let image = UIImage(data: data) else {
                            throw WorkoutLLMImportService.ImportError.invalidImage
                        }
                        handlePhotoImport(image: image)
                    } catch {
                        errorMessage = String(
                            localized: "error.import.photoLoadFailed",
                            defaultValue: "Could not load that photo. Try a different image."
                        )
                        Haptics.warning()
                    }
                }
                selectedPhotoItem = nil
            }
            .onAppear {
                if programRepo == nil {
                    programRepo = ProgramRepository(modelContext: modelContext)
                    scheduleRepo = ScheduleRepository(modelContext: modelContext)
                }
            }
        }
    }

    // MARK: - Step 0 · Doors

    private var doorsContent: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                AnnotationLabel(key: "programImport.doors.stamp")
                Text("programImport.doors.body")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
            }

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    doorCell(
                        title: "programImport.door.paste",
                        sub: "programImport.door.paste.sub",
                        systemImage: "text.alignleft"
                    ) {
                        parsedSource = .text
                        step = .textEntry(voice: false)
                    }
                    Rectangle().fill(ColorTokens.dividerStrong).frame(width: 0.5)
                    doorCell(
                        title: "programImport.door.pdf",
                        sub: "programImport.door.pdf.sub",
                        systemImage: "doc.richtext"
                    ) {
                        parsedSource = .pdf
                        showDocumentPicker = true
                    }
                }
                Rectangle().fill(ColorTokens.dividerStrong).frame(height: 0.5)
                HStack(spacing: 0) {
                    photoDoorCell
                    Rectangle().fill(ColorTokens.dividerStrong).frame(width: 0.5)
                    doorCell(
                        title: "programImport.door.say",
                        sub: "programImport.door.say.sub",
                        systemImage: "mic"
                    ) {
                        parsedSource = .voice
                        step = .textEntry(voice: true)
                    }
                }
            }
            .background(ColorTokens.surfaceEl)
            .clipShape(RoundedRectangle(cornerRadius: CornerTokens.card))
            .overlay(
                RoundedRectangle(cornerRadius: CornerTokens.card)
                    .stroke(ColorTokens.dividerStrong, lineWidth: 0.5)
            )
        }
    }

    private func doorCell(
        title: LocalizedStringKey,
        sub: LocalizedStringKey,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.tap()
            errorMessage = nil
            action()
        } label: {
            doorCellLabel(title: title, sub: sub, systemImage: systemImage)
        }
        .buttonStyle(.pressable)
    }

    private var photoDoorCell: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            doorCellLabel(
                title: "programImport.door.photo",
                sub: "programImport.door.photo.sub",
                systemImage: "camera"
            )
        }
        .simultaneousGesture(TapGesture().onEnded {
            parsedSource = .photo
            errorMessage = nil
        })
    }

    private func doorCellLabel(
        title: LocalizedStringKey,
        sub: LocalizedStringKey,
        systemImage: String
    ) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text2)
            Text(title)
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text1)
            AnnotationLabel(key: sub, size: .small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
    }

    // MARK: - Step · Paste / Say it

    private func textEntryContent(voice: Bool) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(voice ? "programImport.say.instruction" : "programImport.paste.instruction")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)

            TextEditor(text: $inputText)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 220)
                .padding(Spacing.xs)
                .background(ColorTokens.surface, in: RoundedRectangle(cornerRadius: CornerTokens.control))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerTokens.control)
                        .stroke(ColorTokens.divider, lineWidth: 0.5)
                )

            Button {
                Haptics.tap()
                handleTextParse()
            } label: {
                Text("programImport.action.read")
                    .font(.Tokens.body)
                    .foregroundStyle(
                        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? ColorTokens.text3 : ColorTokens.text1
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerTokens.control)
                            .stroke(ColorTokens.dividerStrong, lineWidth: 0.5)
                    )
            }
            .buttonStyle(.pressable)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)

            Button {
                Haptics.select()
                step = .doors
            } label: {
                Text("programImport.action.back")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
            }
            .buttonStyle(.pressable)
        }
    }

    // MARK: - Step · Duration ask (the ladder's second rung)

    private var durationAskContent: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                AnnotationLabel(key: "programImport.duration.stamp")
                if let response = parsedResponse {
                    Text(verbatim: response.program_name)
                        .font(.Tokens.sectionTitle)
                        .foregroundStyle(ColorTokens.text1)
                }
                Text("programImport.duration.question")
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.sm)
            .emphasisCardStyle()

            HStack(spacing: 4) {
                ForEach([4, 6, 8, 12], id: \.self) { weeks in
                    Button {
                        Haptics.select()
                        activateParsed(durationWeeks: weeks, durationSource: .asked)
                    } label: {
                        Text(verbatim: "\(weeks)")
                            .font(.Tokens.body)
                            .monospacedDigit()
                            .foregroundStyle(ColorTokens.text1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm)
                            .background(ColorTokens.surface, in: RoundedRectangle(cornerRadius: CornerTokens.control))
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerTokens.control)
                                    .stroke(ColorTokens.divider, lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.pressable)
                }
            }
            AnnotationLabel(key: "programImport.duration.unit", size: .small)

            // The ladder's third rung — a suggestion only on request; it names its inputs
            // and hands the decision back. The plan's content is never edited.
            Button {
                Haptics.select()
                withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
                    showDurationSuggestion = true
                }
            } label: {
                Text("programImport.duration.suggest")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xs)
            }
            .buttonStyle(.pressable)

            if showDurationSuggestion {
                durationSuggestionCard
            }
        }
    }

    @ViewBuilder
    private var durationSuggestionCard: some View {
        if let response = parsedResponse, let athleteId = athlete?.id {
            // A probe build at 8 weeks gives the engine the plan's own volume structure.
            let probe = WorkoutLLMImportService.buildProgram(
                from: response, durationWeeks: max(response.weeks.count, 8),
                durationSource: .suggested, athleteId: athleteId, source: parsedSource
            )
            let probeTemplates = Dictionary(uniqueKeysWithValues: probe.dayTemplates.map { ($0.id, $0) })
            let historyWeeks = historyDepthWeeks()
            let suggestion = ProgramInsightEngine.suggestDuration(
                program: probe.program, templates: probeTemplates, historyWeeks: historyWeeks
            )
            VStack(alignment: .leading, spacing: Spacing.xs) {
                AnnotationLabel(key: "programImport.suggest.stamp", size: .small)
                Text(verbatim: suggestionLine(suggestion))
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
                KeyRow([
                    KeyRow.Key(
                        title: LocalizedStringKey(String(
                            format: String(localized: "programImport.suggest.use", defaultValue: "Use %lld weeks"),
                            suggestion.weeks
                        ))
                    ) {
                        activateParsed(durationWeeks: suggestion.weeks, durationSource: .suggested)
                    },
                    KeyRow.Key(title: "programImport.suggest.own") {
                        withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
                            showDurationSuggestion = false
                        }
                    }
                ])
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.sm)
            .cardStyle(horizontalPadding: 0, verticalPadding: 0)
        }
    }

    private func historyDepthWeeks() -> Int {
        guard let earliest = recentSessions.map(\.sessionDate).min() else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: earliest, to: .now).day ?? 0
        return max(0, days / 7)
    }

    private func suggestionLine(_ suggestion: ProgramInsightEngine.DurationSuggestion) -> String {
        let step = suggestion.weeklyVolumeStepFraction
            .map { String(format: "%+.0f%%", $0 * 100) }
        if suggestion.includesLighterWeek {
            return String(
                format: String(
                    localized: "programImport.suggest.lineLighter",
                    defaultValue: "Against your %lld weeks of logged training and this plan's volume step%@, %lld weeks with a lighter middle week keeps the climb steady. Your call — the plan stays as written."
                ),
                suggestion.historyWeeks,
                step.map { " (\($0)/wk)" } ?? "",
                suggestion.weeks
            )
        }
        return String(
            format: String(
                localized: "programImport.suggest.line",
                defaultValue: "Against your %lld weeks of logged training and this plan's structure, %lld weeks keeps the climb steady. Your call — the plan stays as written."
            ),
            suggestion.historyWeeks,
            suggestion.weeks
        )
    }

    // MARK: - Step · Transition compare (epic 8)

    @ViewBuilder
    private var transitionContent: some View {
        if let comparison, let program = builtProgram {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    AnnotationLabel(verbatimProgramStamp(program))
                    HStack(spacing: Spacing.xs) {
                        compareSide(
                            value: volumeShort(comparison.chronicWeeklyVolume),
                            key: "programImport.compare.chronic"
                        )
                        AnnotationLabel("→", color: ColorTokens.text3)
                        compareSide(
                            value: volumeShort(comparison.openingWeekVolume),
                            key: "programImport.compare.opening"
                        )
                    }
                    if let step = comparison.openingStepFraction {
                        AnnotationLabel(String(
                            format: String(localized: "programImport.compare.step", defaultValue: "OPENING STEP · %+.0f%% · STRENGTH VOLUME"),
                            step * 100
                        ), size: .small)
                    }
                    Text(easeBody(comparison))
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.sm)
                .emphasisCardStyle()

                KeyRow([
                    KeyRow.Key(title: "programImport.compare.ease") {
                        finishActivation(entryMode: .eased)
                    },
                    KeyRow.Key(title: "programImport.compare.asWritten") {
                        finishActivation(entryMode: .asWritten)
                    }
                ])
            }
        }
    }

    private func verbatimProgramStamp(_ program: TrainingProgram) -> String {
        "\(program.name.uppercased()) · " + String(
            format: String(localized: "programImport.compare.weeks", defaultValue: "%lld WEEKS"),
            program.durationWeeks
        )
    }

    private func compareSide(value: String, key: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: value)
                .font(.Tokens.sectionTitle)
                .monospacedDigit()
                .foregroundStyle(ColorTokens.text1)
            AnnotationLabel(key: key, size: .small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.xs)
        .background(ColorTokens.surface, in: RoundedRectangle(cornerRadius: CornerTokens.control))
        .overlay(
            RoundedRectangle(cornerRadius: CornerTokens.control)
                .stroke(ColorTokens.divider, lineWidth: 0.5)
        )
    }

    private func volumeShort(_ volume: Double) -> String {
        volume >= 1000 ? String(format: "%.1fK", volume / 1000) : String(format: "%.0f", volume)
    }

    private func easeBody(_ comparison: ProgramInsightEngine.TransitionComparison) -> String {
        String(
            format: String(
                localized: "programImport.compare.body",
                defaultValue: "The new block opens above the load you have been carrying. Suggestion: train week 1 with the top sets as written and one back-off set trimmed per lift — about %@ — then as written from week 2."
            ),
            volumeShort(comparison.easedWeekVolume)
        )
    }

    // MARK: - Step · Done

    private var doneContent: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                AnnotationLabel(key: "programImport.done.stamp")
                if let program = activatedProgram {
                    Text(verbatim: program.name)
                        .font(.Tokens.sectionTitle)
                        .foregroundStyle(ColorTokens.text1)
                    AnnotationLabel(String(
                        format: String(
                            localized: "programImport.done.position",
                            defaultValue: "W1 · D1 · %lld WEEKS"
                        ),
                        program.durationWeeks
                    ))
                }
                Text("programImport.done.body")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                if archivedPredecessorName != nil {
                    Text("programImport.done.archived")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.sm)
            .emphasisCardStyle()

            PrimaryActionButton(title: "action.done") {
                dismiss()
            }
        }
    }

    // MARK: - Chrome

    private var loadingOverlay: some View {
        ZStack {
            ColorTokens.background.opacity(0.9)
            VStack(spacing: Spacing.sm) {
                ProgressView()
                    .tint(ColorTokens.text2)
                Text("programImport.reading")
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text2)
            }
        }
    }

    private func errorBanner(message: String) -> some View {
        VStack(spacing: Spacing.xs) {
            Text(verbatim: message)
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.zoneDanger)
                .multilineTextAlignment(.center)
            Button {
                Haptics.tap()
                errorMessage = nil
            } label: {
                Text("action.close")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .overlay(Capsule().stroke(ColorTokens.divider, lineWidth: 0.5))
            }
            .buttonStyle(.pressable)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.sm)
        .background(ColorTokens.surfaceEl, in: RoundedRectangle(cornerRadius: CornerTokens.card))
        .overlay(
            RoundedRectangle(cornerRadius: CornerTokens.card)
                .stroke(ColorTokens.zoneDanger, lineWidth: 0.5)
        )
    }

    // MARK: - Handlers

    private func handleTextParse() {
        parseProgram {
            WorkoutLLMImportService.preprocessProgramText(inputText)
        }
    }

    private func handlePDFImport(url: URL) {
        parsedSource = .pdf
        parseProgram {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            return try await WorkoutLLMImportService.extractTextFromPDF(url: url)
        }
    }

    private func handlePhotoImport(image: UIImage) {
        parsedSource = .photo
        parseProgram {
            try await WorkoutLLMImportService.extractTextFromImage(image)
        }
    }

    private func parseProgram(_ extract: @escaping () async throws -> String) {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let text = try await extract()
                let response = try await WorkoutLLMImportService.parseProgramText(
                    text, client: container.supabase
                )
                parsedResponse = response
                isLoading = false
                Haptics.success()
                if let stated = WorkoutLLMImportService.statedDurationWeeks(of: response) {
                    activateParsed(durationWeeks: stated, durationSource: .readFromFile)
                } else {
                    step = .durationAsk
                }
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
                Haptics.warning()
            }
        }
    }

    /// Build the model graph, then branch: when the opening week asks a real step above
    /// the athlete's chronic strength volume, the transition compare offers a controlled
    /// entry (equal-weight; "as written" is never nagged). Otherwise activate directly.
    private func activateParsed(durationWeeks: Int, durationSource: ProgramDurationSource) {
        guard let response = parsedResponse,
              let athleteId = athlete?.id else { return }
        let built = WorkoutLLMImportService.buildProgram(
            from: response,
            durationWeeks: durationWeeks,
            durationSource: durationSource,
            athleteId: athleteId,
            source: parsedSource
        )
        builtProgram = built.program
        builtTemplates = built.dayTemplates

        let templatesById = Dictionary(uniqueKeysWithValues: built.dayTemplates.map { ($0.id, $0) })
        let history = recentSessions
            .filter { $0.athlete?.id == athleteId }
            .map { (date: $0.sessionDate, volume: $0.totalVolume) }
        let result = ProgramInsightEngine.transitionComparison(
            program: built.program, templates: templatesById, sessions: history
        )
        if result.suggestsEasedEntry {
            comparison = result
            step = .transition
        } else {
            finishActivation(entryMode: nil)
        }
    }

    private func finishActivation(entryMode: ProgramEntryMode?) {
        guard let program = builtProgram,
              let athleteId = athlete?.id,
              let programRepo, let scheduleRepo else { return }
        do {
            program.entryMode = entryMode
            archivedPredecessorName = programRepo.fetchActiveProgram(athleteId: athleteId)?.name
            for template in builtTemplates {
                modelContext.insert(template)
            }
            try programRepo.save(program)
            try ProgramScheduleService.activate(
                program,
                programRepo: programRepo,
                scheduleRepo: scheduleRepo
            )
            activatedProgram = program
            step = .done
            Haptics.success()
            onActivated?(program)
        } catch {
            errorMessage = error.localizedDescription
            Haptics.warning()
        }
    }
}

// MARK: - Camera Picker (UIViewControllerRepresentable)

private struct ProgramCameraPickerView: UIViewControllerRepresentable {
    let onImagePicked: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (UIImage?) -> Void

        init(onImagePicked: @escaping (UIImage?) -> Void) {
            self.onImagePicked = onImagePicked
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = info[.originalImage] as? UIImage
            onImagePicked(image)
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImagePicked(nil)
            picker.dismiss(animated: true)
        }
    }
}
