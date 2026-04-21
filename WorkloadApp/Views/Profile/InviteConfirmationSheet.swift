import SwiftUI
import SwiftData

enum InviteConfirmationMode {
    case athleteAccepting   // athlete tapped a deep link from coach email
    case coachConfirming    // coach entered a code or scanned NFC
}

struct InviteConfirmationSheet: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
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
                    ProgressView("Looking up invite...")
                        .padding(.top, 64)
                } else if let error = errorMessage {
                    Text(error)
                        .font(.custom("DMSans-Regular", size: 15))
                        .foregroundStyle(ColorTokens.zoneDanger)
                        .padding(.horizontal, 16)
                        .padding(.top, 64)
                } else if let resolved {
                    VStack(alignment: .leading, spacing: 0) {
                        Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(mode == .athleteAccepting ? "COACH REQUEST" : "LINK ATHLETE")
                                .font(.custom("DMSans-Medium", size: 11))
                                .tracking(1.2)
                                .foregroundStyle(ColorTokens.text3)
                            Text(resolved.otherPartyName)
                                .font(.custom("DMSans-Medium", size: 28))
                                .foregroundStyle(ColorTokens.text1)
                            Text(resolved.otherPartySport.displayName)
                                .font(.custom("DMSans-Regular", size: 13))
                                .foregroundStyle(ColorTokens.text2)
                        }
                        .padding(16)

                        Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                        Button {
                            Task { await confirm(resolved: resolved) }
                        } label: {
                            Group {
                                if isConfirming {
                                    ProgressView()
                                } else {
                                    Text("Confirm Link")
                                        .font(.custom("DMSans-Regular", size: 15))
                                        .foregroundStyle(ColorTokens.text1)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }
                        .disabled(isConfirming)

                        Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .font(.custom("DMSans-Regular", size: 13))
                                .foregroundStyle(ColorTokens.text2)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }

                        Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                    }
                }
                Spacer()
            }
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
            errorMessage = "Invalid or expired invite code."
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
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isConfirming = false
    }
}
