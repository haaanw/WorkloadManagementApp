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
    @Environment(\.dismiss) private var dismiss
    @Query private var athletes: [Athlete]

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

    private var athlete: Athlete? { athletes.first }

    // MARK: - Import Tab

    enum ImportTab: String, CaseIterable, Identifiable {
        case text
        case pdf
        case photo

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .text: return "Text"
            case .pdf: return "PDF"
            case .photo: return "Photo"
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
                                errorBanner(message: errorMessage)
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
            .navigationTitle("Import Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
                    if let image {
                        handlePhotoImport(image: image)
                    }
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        handlePhotoImport(image: image)
                    }
                }
                selectedPhotoItem = nil
            }
            .sheet(isPresented: $showEditor, onDismiss: { dismiss() }) {
                if let athleteId = athlete?.id {
                    TemplateEditorSheet(
                        coachId: athleteId,
                        prefillName: parsedName,
                        prefillSportType: parsedSportType,
                        prefillSessionType: parsedSessionType,
                        prefillGroups: parsedGroups
                    )
                    .environment(container)
                }
            }
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(ImportTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: tab.systemImage)
                            .font(.Tokens.label)
                        Text(tab.displayName)
                            .font(.Tokens.label)
                    }
                    .foregroundStyle(selectedTab == tab ? ColorTokens.text1 : ColorTokens.text2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(selectedTab == tab ? ColorTokens.surface : ColorTokens.background)
                    .overlay(
                        Rectangle()
                            .stroke(ColorTokens.divider, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Text Tab (D-02)

    private var textTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Paste any workout text below")
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
                handleTextParse()
            } label: {
                Text("Parse Workout")
                    .font(.Tokens.body)
                    .foregroundStyle(
                        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? ColorTokens.text3 : ColorTokens.text1
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .overlay(
                        Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5)
                    )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
    }

    // MARK: - PDF Tab (D-02)

    private var pdfTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select a PDF file containing your workout")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)

            Button {
                showDocumentPicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.richtext")
                        .font(.Tokens.body)
                    Text("Choose PDF")
                        .font(.Tokens.body)
                }
                .foregroundStyle(ColorTokens.text1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .overlay(
                    Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5)
                )
            }
            .disabled(isLoading)
        }
    }

    // MARK: - Photo Tab (D-02)

    private var photoTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Take a photo of a workout or choose from your library")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)

            HStack(spacing: 16) {
                Button {
                    showCamera = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "camera")
                            .font(.Tokens.body)
                        Text("Camera")
                            .font(.Tokens.body)
                    }
                    .foregroundStyle(ColorTokens.text1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .overlay(
                        Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5)
                    )
                }
                .disabled(isLoading)

                PhotosPicker(
                    selection: $selectedPhotoItem,
                    matching: .images
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.Tokens.body)
                        Text("Library")
                            .font(.Tokens.body)
                    }
                    .foregroundStyle(ColorTokens.text1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .overlay(
                        Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5)
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
                Text("Analyzing workout...")
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text2)
            }
        }
    }

    // MARK: - Error Banner (D-08)

    private func errorBanner(message: String) -> some View {
        VStack(spacing: 8) {
            Text(message)
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.zoneDanger)
                .multilineTextAlignment(.center)

            Button {
                errorMessage = nil
                retryLastAction()
            } label: {
                Text("Retry")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .overlay(
                        Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5)
                    )
            }
        }
        .padding(16)
    }

    // MARK: - Handlers

    private func handleTextParse() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let response = try await WorkoutLLMImportService.parseWorkoutText(
                    inputText, client: container.supabaseClient
                )
                mapAndPresent(response)
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func handlePDFImport(url: URL) {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let text = try await WorkoutLLMImportService.extractTextFromPDF(url: url)
                let response = try await WorkoutLLMImportService.parseWorkoutText(
                    text, client: container.supabaseClient
                )
                mapAndPresent(response)
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func handlePhotoImport(image: UIImage) {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let text = try await WorkoutLLMImportService.extractTextFromImage(image)
                let response = try await WorkoutLLMImportService.parseWorkoutText(
                    text, client: container.supabaseClient
                )
                mapAndPresent(response)
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func mapAndPresent(_ response: WorkoutLLMImportService.ParsedWorkoutResponse) {
        let mapped = WorkoutLLMImportService.mapToGroupDrafts(response)
        parsedName = mapped.name
        parsedSportType = mapped.sportType
        parsedSessionType = mapped.sessionType
        parsedGroups = mapped.groups
        isLoading = false
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
            break
        }
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
