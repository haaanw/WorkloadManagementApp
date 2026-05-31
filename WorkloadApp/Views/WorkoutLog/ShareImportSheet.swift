import SwiftUI
import SwiftData

/// Sheet for entering an 8-character share code to look up a shared template.
/// On successful lookup, calls `onLookupSuccess` with the response so the parent
/// can present ShareImportPreviewSheet (avoids sheet-in-sheet issues).
struct ShareImportSheet: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var codeInput = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    /// Optional pre-filled code from universal link
    var prefillCode: String?

    /// Callback when lookup succeeds -- parent presents preview sheet
    var onLookupSuccess: ((SharedTemplateResponse) -> Void)?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // Instruction text
                Text("import.instructionCode")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                    .padding(.horizontal, 16)
                    .padding(.top, 24)

                // Code entry text field
                TextField("ABCD1234", text: $codeInput)
                    .textFieldStyle(SharpTextFieldStyle())
                    .monospacedDigit()
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
                    .onChange(of: codeInput) { _, newValue in
                        let filtered = String(newValue.uppercased().prefix(8))
                        if filtered != newValue { codeInput = filtered }
                        errorMessage = nil
                    }
                    .disabled(isLoading)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                // Look Up button
                Button {
                    Task { await lookUpCode() }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("action.lookup")
                                .font(.Tokens.body)
                        }
                    }
                    .foregroundStyle(codeInput.count == 8 ? ColorTokens.text1 : ColorTokens.text3)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(ColorTokens.surface)
                    .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))
                }
                .disabled(codeInput.count < 8 || isLoading)
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // Error message
                if let errorMessage {
                    Text(errorMessage)
                        .font(.Tokens.smallLabel)
                        .foregroundStyle(ColorTokens.zoneDanger)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }

                Spacer()
            }
            .background(ColorTokens.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("nav.importTemplate")
                        .font(.Tokens.sectionHead)
                        .foregroundStyle(ColorTokens.text1)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.close") { dismiss() }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            if let prefillCode, !prefillCode.isEmpty {
                codeInput = prefillCode.uppercased()
                Task { await lookUpCode() }
            }
        }
    }

    // MARK: - Lookup

    private func lookUpCode() async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await TemplateSharingService.lookupShareCode(
                codeInput,
                client: container.supabase
            )
            onLookupSuccess?(result)
            dismiss()
        } catch {
            let errorStr = "\(error)"
            if errorStr.contains("expired") || errorStr.contains("406") || errorStr.contains("PGRST116") {
                errorMessage = String(localized: "error.shareExpired", defaultValue: "This share link has expired. Ask the sender for a new code.")
            } else {
                errorMessage = String(localized: "error.templateNotFound", defaultValue: "No template found for this code. Check the code and try again.")
            }
        }
        isLoading = false
    }
}
