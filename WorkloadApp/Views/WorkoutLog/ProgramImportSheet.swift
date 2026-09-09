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
        /// The one narrative-capture surface behind BOTH the "Paste it" and "Say it" doors.
        /// `voice` adds the mic control and its recording stamp; the text and the parse path
        /// are identical either way — speaking a program is typing it by another route
        /// (UAT round 1, U2).
        case capture(voice: Bool)
        /// The picked photos / PDFs, in the athlete's own order, each removable before the
        /// one parse runs (UAT round 1, U11).
        case files
        case durationAsk
        case transition
        case done
    }

    /// One picked file, already extracted. Extraction happens at PICK time, not at parse
    /// time, so a page that yields no text names itself while the athlete can still act on
    /// it — and removing a wrong pick costs a tap, not a restart.
    private struct PickedFile: Identifiable {
        let id = UUID()
        let name: String
        let text: String
    }

    @State private var step: Step = .doors
    @State private var inputText = ""
    /// Per-sheet speech capture, torn down on disappear — never shared (see
    /// `SpeechCaptureService` ownership note).
    @State private var speech = SpeechCaptureService()
    /// What the athlete had already typed when recording started; the live transcript is
    /// appended after it, never in place of it.
    @State private var recordingPrefix = ""
    @FocusState private var isEditorFocused: Bool
    @State private var isLoading = false
    /// Position inside a multi-file extraction ("READING 2 OF 5"). OCR over five photos is
    /// slow enough that a bare spinner reads as a hang.
    @State private var loadingDetail: String?
    @State private var errorMessage: String?
    @State private var showDocumentPicker = false
    @State private var showCamera = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var pickedFiles: [PickedFile] = []
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
                            case .capture(let voice):
                                captureContent(voice: voice)
                            case .files:
                                filesContent
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
                    // U3: the keyboard leaves by a downward drag as well as by the editor's
                    // own toolbar Done — a half-screen editor must never trap it. No
                    // tap-to-dismiss here: the editor fills most of this surface, and a tap
                    // on it is a request to type, not to close the keyboard.
                    .scrollDismissesKeyboard(.interactively)
                    .background(ColorTokens.background)

                    if isLoading {
                        loadingOverlay
                    }
                }

                // U3: the CTA is PINNED under the editor, never scrolled to. It exists only
                // on the two steps that end in a parse, so the sheet still carries one ink
                // pill at a time.
                if showsParseFooter {
                    parseFooter
                        .padding(.horizontal, Spacing.sm)
                        .padding(.top, Spacing.sm)
                        .padding(.bottom, Spacing.sm)
                }
            }
            .background(ColorTokens.background)
            .toolbar(.hidden, for: .navigationBar)
            // U11: a coach's program routinely arrives as two or three PDFs.
            .fileImporter(
                isPresented: $showDocumentPicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    appendPDFs(urls)
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                ProgramCameraPickerView { image in
                    showCamera = false
                    if let image {
                        appendCameraPhoto(image)
                    }
                }
            }
            .onChange(of: selectedPhotoItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                appendPhotos(newItems)
                // Clearing the binding resets the picker, so "Add more photos" opens with
                // nothing preselected. The empty write re-enters here and is guarded above.
                selectedPhotoItems = []
            }
            .onAppear {
                if programRepo == nil {
                    programRepo = ProgramRepository(modelContext: modelContext)
                    scheduleRepo = ScheduleRepository(modelContext: modelContext)
                }
            }
            // The live transcript mirrors into the editor after whatever was already typed,
            // so voice and typing feed ONE text (the LogCaptureSheet recording model).
            .onChange(of: speech.transcript) { _, newValue in
                guard isRecording else { return }
                inputText = recordingPrefix.isEmpty ? newValue : recordingPrefix + newValue
            }
            .onDisappear {
                speech.cancel()
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
                        step = .capture(voice: false)
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
                        step = .capture(voice: true)
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
        // U11: a whiteboard or a printed block rarely fits in one frame.
        PhotosPicker(
            selection: $selectedPhotoItems,
            maxSelectionCount: Self.maxPhotoSelection,
            matching: .images
        ) {
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

    /// Per-pick ceiling only — "Add more photos" can go past it. The real budget is the
    /// parser's 60k character cap, enforced on the combined text.
    private static let maxPhotoSelection = 10

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

    // MARK: - Step · Paste / Say it (one capture surface, one parse path)

    private func captureContent(voice: Bool) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(voice ? "programImport.say.instruction" : "programImport.paste.instruction")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)

            editor

            // U2: the "Say it" door lands on a REAL capture surface. The mic is the door's
            // whole point, so it sits directly under the editor — but the editor is still
            // there, and typing alone remains a complete way through this step.
            if voice {
                micControl

                if case .failed(let error) = speech.state {
                    speechFailureNotice(for: error)
                }
            }
        }
    }

    private var editor: some View {
        TextEditor(text: $inputText)
            .font(.Tokens.body)
            .foregroundStyle(ColorTokens.text1)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 220)
            .focused($isEditorFocused)
            .padding(Spacing.xs)
            // Read-only while the mic owns the text and while the parser reads it — the
            // words stay visible in both states.
            .disabled(isRecording || isLoading)
            .background(ColorTokens.surface, in: RoundedRectangle(cornerRadius: CornerTokens.control))
            .overlay(
                RoundedRectangle(cornerRadius: CornerTokens.control)
                    .stroke(ColorTokens.divider, lineWidth: 0.5)
            )
            .accessibilityIdentifier("programImport.editor")
            .toolbar {
                // U3: the software keyboard covers half the sheet and a TextEditor has no
                // return key that dismisses it. Contributed only while THIS field owns
                // focus, so nothing else in the sheet stacks a duplicate Done.
                if isEditorFocused {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button(String(localized: "action.done", defaultValue: "Done")) {
                            isEditorFocused = false
                        }
                    }
                }
            }
    }

    // MARK: - The parse footer (capture + files)

    private var showsParseFooter: Bool {
        switch step {
        case .capture, .files: return true
        default: return false
        }
    }

    /// The one ink pill on the parse steps, pinned below the content so "Read my program"
    /// is reachable without scrolling past the text or the file list (U3).
    @ViewBuilder
    private var parseFooter: some View {
        switch step {
        case .capture:
            PrimaryActionButton(
                title: "programImport.action.read",
                isLoading: isLoading,
                isDisabled: inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading
            ) {
                submitCapture()
            }
            .accessibilityIdentifier("programImport.read")
        case .files:
            PrimaryActionButton(
                title: "programImport.action.read",
                isLoading: isLoading,
                isDisabled: pickedFiles.isEmpty || isLoading
            ) {
                submitFiles()
            }
            .accessibilityIdentifier("programImport.read")
        default:
            EmptyView()
        }
    }

    // MARK: - Step · Picked files (U11)

    private var filesContent: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                AnnotationLabel(key: "programImport.files.stamp")
                Text("programImport.files.body")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
            }

            VStack(spacing: 0) {
                ForEach(Array(pickedFiles.enumerated()), id: \.element.id) { index, file in
                    if index > 0 {
                        Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                    }
                    fileRow(index: index, file: file)
                }
            }
            .background(ColorTokens.surfaceEl)
            .clipShape(RoundedRectangle(cornerRadius: CornerTokens.card))
            .overlay(
                RoundedRectangle(cornerRadius: CornerTokens.card)
                    .stroke(ColorTokens.dividerStrong, lineWidth: 0.5)
            )

            addMoreControl
        }
    }

    private func fileRow(index: Int, file: PickedFile) -> some View {
        HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                AnnotationLabel(String(
                    format: String(localized: "programImport.files.index", defaultValue: "File %lld"),
                    index + 1
                ), size: .small)
                Text(verbatim: file.name)
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text1)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                Haptics.select()
                withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
                    pickedFiles.removeAll { $0.id == file.id }
                }
                if pickedFiles.isEmpty {
                    step = .doors
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.Tokens.micro)
                    .foregroundStyle(ColorTokens.text2)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(Text(String(
                format: String(localized: "programImport.files.remove", defaultValue: "Remove %@"),
                file.name
            )))
        }
        .padding(.leading, Spacing.sm)
        .padding(.trailing, Spacing.xs)
        .padding(.vertical, Spacing.xs)
    }

    /// Removal alone would still force a restart when the athlete picked too FEW pages, so
    /// the same door stays open. It reopens the picker this batch came from, which keeps
    /// the batch one kind of file and `parsedSource` honest.
    @ViewBuilder
    private var addMoreControl: some View {
        if parsedSource == .photo {
            PhotosPicker(
                selection: $selectedPhotoItems,
                maxSelectionCount: Self.maxPhotoSelection,
                matching: .images
            ) {
                addMoreLabel(title: "programImport.files.addPhotos")
            }
        } else {
            Button {
                Haptics.tap()
                errorMessage = nil
                showDocumentPicker = true
            } label: {
                addMoreLabel(title: "programImport.files.addFiles")
            }
            .buttonStyle(.pressable)
        }
    }

    private func addMoreLabel(title: LocalizedStringKey) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "plus")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
            Text(title)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .overlay(
            RoundedRectangle(cornerRadius: CornerTokens.control)
                .stroke(ColorTokens.dividerStrong, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
    }

    // MARK: - Voice capture

    private var isRecording: Bool { speech.state == .recording }

    /// Start/stop only — never a silence auto-stop (HAN's B2 ruling). Describing a whole
    /// training block has long pauses in it; the athlete says when they are done.
    private var micControl: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Button {
                Task { await toggleRecording() }
            } label: {
                HStack(spacing: Spacing.xs) {
                    micIcon
                    Text(isRecording ? "voice.capture.mic.stop" : "programImport.say.record")
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerTokens.control)
                        .stroke(ColorTokens.dividerStrong, lineWidth: 0.5)
                )
            }
            .buttonStyle(.pressable)
            .disabled(speech.state == .requestingPermission || isLoading)
            .accessibilityIdentifier("programImport.mic")
            .accessibilityLabel(
                isRecording
                    ? Text("voice.capture.mic.stop.a11y")
                    : Text("programImport.say.record.a11y")
            )

            if isRecording {
                AnnotationLabel(recordingStamp, color: ColorTokens.text2)
                    .accessibilityLabel(recordingStampAccessibilityLabel)
            }
        }
    }

    @ViewBuilder
    private var micIcon: some View {
        switch speech.state {
        case .requestingPermission:
            ProgressView()
                .tint(ColorTokens.text2)
        case .recording:
            // The live-recording dot — accent's sanctioned live-state territory (v6
            // Reading Color Rule). reduceMotion pins the scale flat.
            Circle()
                .fill(ColorTokens.accent)
                .frame(width: 10, height: 10)
                .scaleEffect(reduceMotion ? 1 : 1 + CGFloat(min(speech.audioLevel, 1)) * 0.6)
                .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: speech.audioLevel)
                .accessibilityHidden(true)
            Image(systemName: "stop.fill")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
        default:
            Image(systemName: "mic")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
        }
    }

    /// "REC MM:SS" — the annotation-voice recording clock, shared with `LogCaptureSheet`.
    private var recordingStamp: String {
        let totalSeconds = Int(speech.elapsed)
        let clock = String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
        return String(format: String(localized: "voice.capture.recording"), clock)
    }

    private var recordingStampAccessibilityLabel: Text {
        let totalSeconds = Int(speech.elapsed)
        let clock = String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
        return Text(String(format: String(localized: "voice.capture.recording.a11y"), clock))
    }

    /// Inline mic-failure notice. The message comes from `CaptureError.errorDescription`, so
    /// this view owns no duplicate error copy. Typing keeps working through every one of
    /// these — voice is one route into the same text, never a gate on importing.
    private func speechFailureNotice(for error: SpeechCaptureService.CaptureError) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let message = error.errorDescription {
                Text(message)
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
            }
            if error == .permissionDenied {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("action.openSettings")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text1)
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.surfaceEl, in: RoundedRectangle(cornerRadius: CornerTokens.card))
        .overlay(RoundedRectangle(cornerRadius: CornerTokens.card).stroke(ColorTokens.divider, lineWidth: 0.5))
    }

    private func toggleRecording() async {
        if isRecording {
            stopRecording()
            return
        }
        let granted = await speech.requestAuthorization()
        guard granted else { return }
        errorMessage = nil
        isEditorFocused = false
        recordingPrefix = inputText.isEmpty ? "" : inputText + " "
        speech.start(localeIdentifier: container.localeManager.activeLocale.identifier)
    }

    /// Stop the recognizer and fold its FINAL transcript in (never the last mirrored
    /// `onChange` value, which can lag the tail). Returns the resulting text so a caller
    /// that needs it in the same turn — `submitCapture()` — need not read `@State` back.
    @discardableResult
    private func stopRecording() -> String {
        let finalText = speech.stop()
        let combined = recordingPrefix.isEmpty ? finalText : recordingPrefix + finalText
        inputText = combined
        recordingPrefix = ""
        return combined
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
                if let loadingDetail {
                    AnnotationLabel(loadingDetail, color: ColorTokens.text3)
                }
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

    /// The single parse path behind both capture doors. A live recording is STOPPED (not
    /// cancelled) first, so submitting mid-sentence can never drop the tail of what the
    /// athlete just said — spoken words and typed words reach the parser identically.
    private func submitCapture() {
        isEditorFocused = false
        let captured = isRecording ? stopRecording() : inputText
        guard !captured.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        parseProgram {
            WorkoutLLMImportService.preprocessProgramText(captured)
        }
    }

    // MARK: - Handlers · picked files (U11)

    private func appendPDFs(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        parsedSource = .pdf
        isLoading = true
        errorMessage = nil
        Task {
            var unreadable: [String] = []
            for (offset, url) in urls.enumerated() {
                loadingDetail = readingStamp(offset + 1, of: urls.count)
                let name = url.deletingPathExtension().lastPathComponent
                do {
                    pickedFiles.append(
                        PickedFile(name: name, text: try await extractPDF(at: url))
                    )
                } catch {
                    unreadable.append(name)
                }
            }
            isLoading = false
            loadingDetail = nil
            finishPicking(unreadable: unreadable)
        }
    }

    private func extractPDF(at url: URL) async throws -> String {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        return try await WorkoutLLMImportService.extractTextFromPDF(url: url)
    }

    private func appendPhotos(_ items: [PhotosPickerItem]) {
        parsedSource = .photo
        isLoading = true
        errorMessage = nil
        let firstNumber = pickedFiles.count + 1
        Task {
            var unreadable: [String] = []
            for (offset, item) in items.enumerated() {
                let name = String(
                    format: String(localized: "programImport.files.photoName", defaultValue: "Photo %lld"),
                    firstNumber + offset
                )
                loadingDetail = readingStamp(offset + 1, of: items.count)
                do {
                    guard let data = try await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else {
                        throw WorkoutLLMImportService.ImportError.invalidImage
                    }
                    pickedFiles.append(
                        PickedFile(name: name, text: try await WorkoutLLMImportService.extractTextFromImage(image))
                    )
                } catch {
                    unreadable.append(name)
                }
            }
            isLoading = false
            loadingDetail = nil
            finishPicking(unreadable: unreadable)
        }
    }

    private func readingStamp(_ position: Int, of total: Int) -> String? {
        guard total > 1 else { return nil }
        return String(
            format: String(localized: "programImport.files.reading", defaultValue: "Reading %1$lld of %2$lld"),
            position,
            total
        )
    }

    /// The camera cover's single shot joins the same list as one more picked file, so a
    /// photographed page and a chosen page take the identical path from here on.
    private func appendCameraPhoto(_ image: UIImage) {
        parsedSource = .photo
        isLoading = true
        errorMessage = nil
        let name = String(
            format: String(localized: "programImport.files.photoName", defaultValue: "Photo %lld"),
            pickedFiles.count + 1
        )
        Task {
            var unreadable: [String] = []
            do {
                pickedFiles.append(
                    PickedFile(name: name, text: try await WorkoutLLMImportService.extractTextFromImage(image))
                )
            } catch {
                unreadable.append(name)
            }
            isLoading = false
            loadingDetail = nil
            finishPicking(unreadable: unreadable)
        }
    }

    /// A file that yields no readable text is NAMED and left out; the rest of the batch
    /// stands. Failing the whole pick on one blurred page would send the athlete back to
    /// the doors with nothing.
    private func finishPicking(unreadable: [String]) {
        if !unreadable.isEmpty {
            errorMessage = String(
                format: String(
                    localized: "error.import.filesUnreadable",
                    defaultValue: "No text found in %@. Everything else is still here."
                ),
                unreadable.joined(separator: ", ")
            )
            Haptics.warning()
        }
        if pickedFiles.isEmpty {
            step = .doors
        } else {
            step = .files
            if unreadable.isEmpty { Haptics.success() }
        }
    }

    /// One combined document, one parse (`combineProgramFiles` carries the why). The
    /// combination then takes the preprocessing pass as a WHOLE, so furniture that survived
    /// per-file extraction is stripped before the budget is measured. Still over budget
    /// after that, `parseProgramText`'s client-side cap raises the "a few weeks at a time"
    /// prompt instead of letting the server answer with a bare 400.
    private func submitFiles() {
        guard !pickedFiles.isEmpty else { return }
        let combined = WorkoutLLMImportService.combineProgramFiles(pickedFiles.map(\.text))
        parseProgram {
            WorkoutLLMImportService.preprocessProgramText(combined)
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
