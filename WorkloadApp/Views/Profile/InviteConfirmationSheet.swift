import SwiftUI
import SwiftData

enum InviteConfirmationMode {
    case athleteAccepting   // athlete tapped a deep link from coach email
    case coachConfirming    // coach entered a code
}

struct InviteConfirmationSheet: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var athletes: [Athlete]

    let code: String
    let mode: InviteConfirmationMode

    @State private var resolved: ResolvedInvitation?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isConfirming = false

    private var currentAthlete: Athlete? { athletes.first }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView(String(localized: "profile.invite.lookingUp", defaultValue: "Looking up invite..."))
                        .padding(.top, 64)
                        .transition(.opacity)
                } else if let error = errorMessage {
                    Text(error)
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.zoneDanger)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.top, 64)
                        .transition(.opacity)
                } else if let resolved {
                    VStack(alignment: .leading, spacing: 0) {
                        Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(mode == .athleteAccepting ? "COACH REQUEST" : "LINK ATHLETE")
                                .font(.Tokens.micro)
                                .tracking(1.2)
                                .foregroundStyle(ColorTokens.text3)
                            Text(resolved.otherPartyName)
                                .font(.Tokens.pageTitle)
                                .foregroundStyle(ColorTokens.text1)
                            Text(resolved.otherPartySport.displayName)
                                .font(.Tokens.smallLabel)
                                .foregroundStyle(ColorTokens.text2)
                        }
                        .padding(Spacing.sm)

                        Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                        Button {
                            Haptics.tap()
                            Task { await confirm(resolved: resolved) }
                        } label: {
                            Group {
                                if isConfirming {
                                    ProgressView()
                                } else {
                                    Text("profile.invite.confirmLink")
                                        .font(.Tokens.label)
                                        .foregroundStyle(ColorTokens.text1)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm)
                        }
                        .buttonStyle(.pressable(scale: 1, opacity: 0.6))
                        .disabled(isConfirming)

                        Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                        Button {
                            Haptics.tap()
                            dismiss()
                        } label: {
                            Text("action.cancel")
                                .font(.Tokens.smallLabel)
                                .foregroundStyle(ColorTokens.text2)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.sm)
                        }
                        .buttonStyle(.pressable(scale: 1, opacity: 0.6))

                        Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                    }
                    .transition(.opacity)
                }
                Spacer()
            }
            .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: isLoading)
            .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: errorMessage != nil)
            .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: resolved != nil)
            .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: isConfirming)
            .background(ColorTokens.background)
            .navigationBarHidden(true)
        }
        .task {
            await resolve()
        }
    }

    private func resolve() async {
        do {
            resolved = try await InviteService.resolveCode(code, client: container.supabase)
        } catch {
            errorMessage = String(localized: "invite.error.invalid", defaultValue: "Invalid or expired invite code.")
        }
        isLoading = false
    }

    private func confirm(resolved: ResolvedInvitation) async {
        guard let athlete = currentAthlete else { return }
        isConfirming = true
        do {
            let coachId = mode == .athleteAccepting ? resolved.otherPartyId : athlete.id
            let athleteId = mode == .athleteAccepting ? athlete.id : resolved.otherPartyId
            let rel = try await InviteService.confirmRelationship(
                coachId: coachId,
                athleteId: athleteId,
                invitationId: resolved.invitationId,
                redeemerAthleteId: athlete.id,
                client: container.supabase
            )
            modelContext.insert(rel)
            try? modelContext.save()
            Haptics.success()
            dismiss()
        } catch {
            Haptics.warning()
            errorMessage = error.localizedDescription
        }
        isConfirming = false
    }
}
