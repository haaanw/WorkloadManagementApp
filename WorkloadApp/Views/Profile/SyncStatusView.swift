import SwiftUI

/// Displays per-entity sync status with success/failure indicators and relative timestamps.
/// Accessible from Profile > Sync Status navigation row.
struct SyncStatusView: View {
    private let store = SyncTimestampStore.shared
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Section header: 19pt Medium sectionHead per DESIGN.md separator grammar.
                SectionHeader(title: "profile.sync.statusTitle")
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.sm)

                // Card container: entity rows on the surfaceEl plane with row hairlines
                VStack(spacing: 0) {
                    ForEach(Array(SyncEntity.allCases.enumerated()), id: \.element.id) { index, entity in
                        entityRow(entity)
                        if index < SyncEntity.allCases.count - 1 {
                            Rectangle()
                                .fill(ColorTokens.divider)
                                .frame(height: 0.5)
                                .padding(.leading, 40)
                        }
                    }
                }
                .cardStyle(horizontalPadding: 0, verticalPadding: 0)
                .padding(.horizontal, Spacing.sm)
            }
        }
        .background(ColorTokens.background)
        .navigationTitle("profile.sync.navTitle")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            // Pull-to-refresh triggers immediate sync per UI-SPEC interaction contract
            guard !store.isSyncing else { return }
            await container.syncService.pushAll(context: modelContext)
            await container.syncService.pullAll(context: modelContext)
        }
    }

    @ViewBuilder
    private func entityRow(_ entity: SyncEntity) -> some View {
        let hasFailed = store.lastErrors[entity] != nil
        let lastSync = store.lastSuccess(for: entity)

        HStack(spacing: 8) {
            // Leading status indicator: 8pt circle
            Circle()
                .fill(hasFailed ? ColorTokens.zoneCaution : ColorTokens.zoneOptimal)
                .frame(width: 8, height: 8)

            // Center VStack: entity name + timestamp
            VStack(alignment: .leading, spacing: 2) {
                Text(entity.displayName)
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)

                if hasFailed, let error = store.lastErrors[entity] {
                    Text(String(format: String(localized: "sync.status.failed", defaultValue: "Failed %@"), Self.relativeFormatter.localizedString(for: error.timestamp, relativeTo: Date())))
                        .font(.Tokens.smallLabel)
                        .foregroundStyle(ColorTokens.text2)
                } else if let date = lastSync {
                    Text(Self.relativeFormatter.localizedString(for: date, relativeTo: Date()))
                        .font(.Tokens.smallLabel)
                        .foregroundStyle(ColorTokens.text2)
                } else {
                    Text("profile.sync.neverSynced")
                        .font(.Tokens.smallLabel)
                        .foregroundStyle(ColorTokens.text2)
                }
            }

            Spacer()

            // Trailing error text (only when failed)
            if let error = store.lastErrors[entity] {
                Text(error.message)
                    .font(.Tokens.smallLabel)
                    .foregroundStyle(ColorTokens.zoneCaution)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 48)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(hasFailed
            ? "\(entity.displayName), sync failed, \(store.lastErrors[entity]?.message ?? "")"
            : "\(entity.displayName), synced \(lastSync.map { Self.relativeFormatter.localizedString(for: $0, relativeTo: Date()) } ?? "never")")
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()
}
