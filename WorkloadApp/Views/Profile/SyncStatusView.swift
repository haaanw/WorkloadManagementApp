import SwiftUI

/// Displays per-entity sync status with success/failure indicators and relative timestamps.
/// Accessible from Profile > Sync Status navigation row.
struct SyncStatusView: View {
    private let store = SyncTimestampStore.shared
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    /// `AnnotationLabel` takes a `String`, so the sync stamps below resolve through
    /// `LocalePinnedStrings` — the app pins its language via `.environment(\.locale, …)`, which
    /// `String(localized:)` does not observe.
    @Environment(\.locale) private var locale

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Section header: 17pt Medium sectionHead per DESIGN.md separator grammar.
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

        HStack(spacing: Spacing.xs) {
            // Leading status indicator: 8pt circle
            Circle()
                .fill(hasFailed ? ColorTokens.zoneCaution : ColorTokens.zoneOptimal)
                .frame(width: 8, height: 8)

            // Center VStack: entity name + timestamp
            VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                Text(entity.displayName)
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)

                // v6 "Field Notes": a sync stamp is a timestamp — textbook marginalia, so it
                // takes the annotation voice. `text2` rather than the `text3` default because
                // this is information the athlete may need to act on. The entity name above
                // stays working voice, and the trailing server error stays working voice too:
                // it is prose, and the annotation voice never speaks sentences.
                if hasFailed, let error = store.lastErrors[entity] {
                    AnnotationLabel(
                        String(format: String(localized: "sync.status.failed", defaultValue: "Failed %@"), Self.relativeFormatter.localizedString(for: error.timestamp, relativeTo: Date())),
                        size: .small,
                        color: ColorTokens.text2
                    )
                    .annotationReveal()
                } else if let date = lastSync {
                    AnnotationLabel(
                        Self.relativeFormatter.localizedString(for: date, relativeTo: Date()),
                        size: .small,
                        color: ColorTokens.text2
                    )
                    .annotationReveal()
                } else {
                    AnnotationLabel(
                        LocalePinnedStrings.localized("profile.sync.neverSynced", locale: locale),
                        size: .small,
                        color: ColorTokens.text2
                    )
                    .annotationReveal()
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
        .padding(.horizontal, Spacing.sm)
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
