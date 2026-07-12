import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

/// Import sheet for LLM-powered workout parsing (D-01, D-02).
/// Supports text paste, PDF file selection, and photo/camera input.
/// Extracted text is sent to the parse-workout edge function, then
/// the result is presented in TemplateEditorSheet for user review.
struct WorkoutImportSheet: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var athletes: [Athlete]

    var onImported: ((WorkoutTemplate) -> Void)? = nil

    @State private var selectedTab: ImportTab = .text
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showEditor = false
    @State private var parsedName = ""
    @State private var parsedSportType: SportType = .lifting
    @State private var parsedSessionType: SessionType = .strength
    @State private var parsedGroups: [GroupDraft] = []
    @State private var showDocumentPicker = false
    @State private var showCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var lastPhotoImage: UIImage?
    @State private var templateIDsBeforeEditor: Set<UUID> = []

    private var athlete: Athlete? { athletes.first }

    // MARK: - Import Tab

    enum ImportTab: String, CaseIterable, Identifiable {
        case text
        case pdf
        case photo

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .text: return String(localized: "import.tab.text", defaultValue: "Text")
            case .pdf: return String(localized: "import.tab.pdf", defaultValue: "PDF")
            case .photo: return String(localized: "import.tab.photo", defaultValue: "Photo")
            }
        }

        var systemImage: String {
            switch self {
            case .text: return "doc.plaintext"
            case .pdf: return "doc.richtext"
            case .photo: return "camera"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // Segmented picker
                    tabPicker
                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                    // Tab content
                    ScrollView {
                        VStack(spacing: 16) {
                            switch selectedTab {
                            case .text:
                                textTabContent
                            case .pdf:
                                pdfTabContent
                            case .photo:
                                photoTabContent
                            }

                            // Error banner (D-08)
                            if let errorMessage {
                                errorBanner(
                                    message: errorMessage,
                                    canRetry: selectedTab != .photo || lastPhotoImage != nil
                                )
                            }
                        }
                        .padding(16)
                    }
                }
                .background(ColorTokens.background)

                // Loading overlay (D-09)
                if isLoading {
                    loadingOverlay
                }
            }
            .navigationTitle("nav.importWorkout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
            }
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
                CameraPickerView { image in
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
            .sheet(isPresented: $showEditor, onDismiss: handleEditorDismiss) {
                if let athleteId = athlete?.id {
                    TemplateEditorSheet(
                        coachId: athleteId,
                        prefillName: parsedName,
                        prefillSportType: parsedSportType,
                        prefillSessionType: parsedSessionType,
                        prefillGroups: parsedGroups
                    )
                    .environment(container)
                } else {
                    Text("error.loadingAthleteData")
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text2)
                }
            }
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(ImportTab.allCases) { tab in
                Button {
                    Haptics.select()
                    errorMessage = nil
                    selectedTab = tab
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: tab.systemImage)
                            .font(.Tokens.label)
                        Text(tab.displayName)
                            .font(.Tokens.label)
                    }
                    // Active segment carries the accent (live / you-are-here); idle stays neutral.
                    .foregroundStyle(selectedTab == tab ? ColorTokens.accent : ColorTokens.text2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(selectedTab == tab ? ColorTokens.accentSubtle : ColorTokens.background)
                    .overlay(
                        Rectangle()
                            .stroke(selectedTab == tab ? ColorTokens.accent : ColorTokens.divider, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Text Tab (D-02)

    private var textTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("import.label.workoutInstruction")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)

            TextEditor(text: $inputText)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 200)
                .padding(8)
                .background(ColorTokens.surface)
                .overlay(
                    Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5)
                )

            Button {
                Haptics.tap()
                handleTextParse()
            } label: {
                // Primary CTA → accent outline (live / actionable), not a filled accent button.
                Text("action.parseWorkout")
                    .font(.Tokens.body)
                    .foregroundStyle(
                        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? ColorTokens.text3 : ColorTokens.text1
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .overlay(
                        Rectangle().stroke(ColorTokens.accent, lineWidth: 0.5)
                    )
            }
            .buttonStyle(.pressable)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
    }

    // MARK: - PDF Tab (D-02)

    private var pdfTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("import.pdf.instruction")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)

            Button {
                Haptics.tap()
                showDocumentPicker = true
            } label: {
                // Primary CTA → accent outline (live / actionable), not a filled accent button.
                HStack(spacing: 8) {
                    Image(systemName: "doc.richtext")
                        .font(.Tokens.body)
                    Text("import.pdf.choose")
                        .font(.Tokens.body)
                }
                .foregroundStyle(ColorTokens.text1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .overlay(
                    Rectangle().stroke(ColorTokens.accent, lineWidth: 0.5)
                )
            }
            .buttonStyle(.pressable)
            .disabled(isLoading)
        }
    }

    // MARK: - Photo Tab (D-02)

    private var photoTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("import.photo.instruction")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)

            HStack(spacing: 16) {
                Button {
                    Haptics.tap()
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        showCamera = true
                    } else {
                        errorMessage = String(
                            localized: "error.import.cameraUnavailable",
                            defaultValue: "Camera is unavailable on this device. Choose a photo instead."
                        )
                        Haptics.warning()
                    }
                } label: {
                    // Primary CTA → accent outline (live / actionable), not a filled accent button.
                    HStack(spacing: 8) {
                        Image(systemName: "camera")
                            .font(.Tokens.body)
                        Text("import.photo.camera")
                            .font(.Tokens.body)
                    }
                    .foregroundStyle(ColorTokens.text1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .overlay(
                        Rectangle().stroke(ColorTokens.accent, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.pressable)
                .disabled(isLoading)

                PhotosPicker(
                    selection: $selectedPhotoItem,
                    matching: .images
                ) {
                    // Primary CTA → accent outline (live / actionable), not a filled accent button.
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.Tokens.body)
                        Text("import.photo.library")
                            .font(.Tokens.body)
                    }
                    .foregroundStyle(ColorTokens.text1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .overlay(
                        Rectangle().stroke(ColorTokens.accent, lineWidth: 0.5)
                    )
                }
                .disabled(isLoading)
            }
        }
    }

    // MARK: - Loading Overlay (D-09)

    private var loadingOverlay: some View {
        ZStack {
            ColorTokens.background.opacity(0.9)
            VStack(spacing: 16) {
                ProgressView()
                    .tint(ColorTokens.text2)
                Text("import.analyzing")
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text2)
            }
        }
    }

    // MARK: - Error Banner (D-08)

    private func errorBanner(message: String, canRetry: Bool) -> some View {
        VStack(spacing: 8) {
            Text(message)
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.zoneDanger)
                .multilineTextAlignment(.center)

            Button {
                Haptics.tap()
                errorMessage = nil
                if canRetry {
                    retryLastAction()
                }
            } label: {
                Text(
                    canRetry
                        ? String(localized: "action.retry", defaultValue: "Retry")
                        : String(localized: "action.close", defaultValue: "Close")
                )
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .overlay(
                        Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5)
                    )
            }
            .buttonStyle(.pressable)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        // Banner = surfaceEl plane + thin zone-colored border + text label (never a flooded fill).
        .background(ColorTokens.surfaceEl)
        .overlay(Rectangle().stroke(ColorTokens.zoneDanger, lineWidth: 0.5))
    }

    // MARK: - Handlers

    private func handleTextParse() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let response = try await WorkoutLLMImportService.parseWorkoutText(
                    inputText, client: container.supabase
                )
                mapAndPresent(response)
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
                Haptics.warning()
            }
        }
    }

    private func handlePDFImport(url: URL) {
        isLoading = true
        errorMessage = nil
        Task {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                let text = try await WorkoutLLMImportService.extractTextFromPDF(url: url)
                let response = try await WorkoutLLMImportService.parseWorkoutText(
                    text, client: container.supabase
                )
                mapAndPresent(response)
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
                Haptics.warning()
            }
        }
    }

    private func handlePhotoImport(image: UIImage) {
        lastPhotoImage = image
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let text = try await WorkoutLLMImportService.extractTextFromImage(image)
                let response = try await WorkoutLLMImportService.parseWorkoutText(
                    text, client: container.supabase
                )
                mapAndPresent(response)
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
                Haptics.warning()
            }
        }
    }

    private func mapAndPresent(_ response: WorkoutLLMImportService.ParsedWorkoutResponse) {
        let mapped = WorkoutLLMImportService.mapToGroupDrafts(response)
        guard mapped.groups.contains(where: { !$0.exercises.isEmpty }) else {
            errorMessage = String(
                localized: "error.import.noExercises",
                defaultValue: "No exercises were found. Add more plan detail and try again."
            )
            isLoading = false
            Haptics.warning()
            return
        }
        guard athlete != nil else {
            errorMessage = String(
                localized: "error.loadingAthleteData",
                defaultValue: "Unable to load athlete data."
            )
            isLoading = false
            Haptics.warning()
            return
        }
        parsedName = mapped.name
        parsedSportType = mapped.sportType
        parsedSessionType = mapped.sessionType
        parsedGroups = mapped.groups
        templateIDsBeforeEditor = currentTemplateIDs()
        isLoading = false
        Haptics.success()
        showEditor = true
    }

    private func retryLastAction() {
        switch selectedTab {
        case .text:
            if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                handleTextParse()
            }
        case .pdf:
            showDocumentPicker = true
        case .photo:
            if let lastPhotoImage {
                handlePhotoImport(image: lastPhotoImage)
            }
        }
    }

    private func currentTemplateIDs() -> Set<UUID> {
        let templates = (try? modelContext.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
        return Set(templates.map(\.id))
    }

    private func handleEditorDismiss() {
        let templates = (try? modelContext.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
        guard let importedTemplate = templates
            .filter({ !templateIDsBeforeEditor.contains($0.id) })
            .max(by: { $0.createdAt < $1.createdAt }) else {
            return
        }

        onImported?(importedTemplate)
        dismiss()
    }
}

// MARK: - Camera Picker (UIViewControllerRepresentable)

private struct CameraPickerView: UIViewControllerRepresentable {
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
