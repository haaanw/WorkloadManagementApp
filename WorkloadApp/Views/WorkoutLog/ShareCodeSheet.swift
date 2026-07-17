import SwiftUI
import SwiftData

struct ShareCodeSheet: View {
    let template: WorkoutTemplate
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var athletes: [Athlete]

    @State private var shareCode: String?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCopied = false

    private var athlete: Athlete? { athletes.first }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(.Tokens.smallLabel)
                        .foregroundStyle(ColorTokens.text2)
                        .multilineTextAlignment(.center)
                        .padding(Spacing.sm)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let code = shareCode {
                    shareContent(code: code)
                }
            }
            .background(ColorTokens.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("nav.shareTemplate")
                        .font(.Tokens.sectionHead)
                        .foregroundStyle(ColorTokens.text1)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.done") { dismiss() }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
            }
        }
        .presentationDetents([.medium])
        .task {
            await generateCode()
        }
    }

    @ViewBuilder
    private func shareContent(code: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Template name
                Text(template.templateName)
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text1)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.top, Spacing.sm)

                // Sport + session type
                Text("\(template.sportType.displayName) - \(template.sessionType.displayName)")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.top, Spacing.xs)

                // Divider
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                    .padding(.top, Spacing.sm)

                // Share code card
                VStack(alignment: .leading, spacing: 0) {
                    Text("label.shareCode")
                        .font(.Tokens.smallLabel)
                        .tracking(1.2)
                        .foregroundStyle(ColorTokens.text3)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.top, Spacing.sm)

                    Text(code)
                        .font(.Tokens.body)
                        .monospacedDigit()
                        .tracking(2.0)
                        .foregroundStyle(ColorTokens.text1)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.top, Spacing.xs)
                        .accessibilityLabel("a11y.shareCode")
                        .accessibilityValue(code)

                    Text("shareCode.expiryText")
                        .font(.Tokens.smallLabel)
                        .foregroundStyle(ColorTokens.text3)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.top, Spacing.xs)
                        .padding(.bottom, Spacing.sm)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ColorTokens.surface, in: RoundedRectangle(cornerRadius: CornerTokens.card))
                .overlay(RoundedRectangle(cornerRadius: CornerTokens.card).stroke(ColorTokens.divider, lineWidth: 0.5))
                .padding(.horizontal, Spacing.sm)
                .padding(.top, Spacing.sm)

                // Buttons
                VStack(spacing: Spacing.xs) {
                    // Copy Code button
                    Button {
                        UIPasteboard.general.string = code
                        Haptics.success()
                        showCopied = true
                        Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            showCopied = false
                        }
                    } label: {
                        Text(showCopied ? "action.copied" : "action.copyCode")
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(ColorTokens.surface, in: Capsule())
                            .overlay(Capsule().stroke(ColorTokens.divider, lineWidth: 0.5))
                    }
                    .buttonStyle(.pressable)
                    .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: showCopied)

                    // Share Link button via ShareLink
                    let shareURL = URL(string: "https://tuwa.app/t/\(code)")!
                    ShareLink(item: shareURL) {
                        Text("action.shareLink")
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(ColorTokens.surface, in: Capsule())
                            .overlay(Capsule().stroke(ColorTokens.divider, lineWidth: 0.5))
                    }
                    .buttonStyle(.pressable)
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.top, Spacing.md)
            }
        }
    }

    private func generateCode() async {
        guard let athlete else {
            errorMessage = String(localized: "share.error.generate", defaultValue: "Could not generate share code. Check your connection and try again.")
            isLoading = false
            return
        }
        do {
            let code = try await TemplateSharingService.shareTemplate(
                template,
                ownerId: athlete.supabaseUserId ?? athlete.id,
                client: container.supabase
            )
            shareCode = code
        } catch {
            print("Share code generation error: \(error)")
            errorMessage = String(localized: "share.error.generate", defaultValue: "Could not generate share code. Check your connection and try again.")
        }
        isLoading = false
    }
}
