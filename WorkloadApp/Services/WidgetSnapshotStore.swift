import Foundation

/// Reads and writes the `WidgetSnapshot` JSON in the App Group container.
///
/// **Membership:** compiles in BOTH the app target and the widget extension target.
/// The app writes through `merge`; the widget only ever calls `read`.
///
/// **Degrades to a no-op without the entitlement.** Until the App Group capability is
/// added to both targets (HAN's Xcode checklist), `containerURL(forSecurityApplication
/// GroupIdentifier:)` returns nil, `sharedDefaults()` returns nil, and every call here
/// silently does nothing — the app keeps working, the widget shows its empty state.
/// This is deliberate: the writer ships in the app target before the extension target
/// exists.
enum WidgetSnapshotStore {

    /// The App Group both targets join. The app's bundle ID is `com.tonus.app`
    /// (historical — the product is Tuwa), so the group follows it.
    static let appGroupID = "group.com.tonus.app"

    /// The single storage key. The suffix is a STORAGE-format version, distinct from
    /// `WidgetSnapshot.schemaVersion` (which versions field meaning): bump this only if
    /// the container format itself changes (e.g. JSON → file).
    static let snapshotKey = "widgetSnapshot.v1"

    /// True once the App Group entitlement is live on the running target.
    static var isAppGroupAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil
    }

    static func sharedDefaults() -> UserDefaults? {
        guard isAppGroupAvailable else { return nil }
        return UserDefaults(suiteName: appGroupID)
    }

    /// Decode the stored snapshot. Returns nil when nothing was ever written, when the
    /// data does not decode, or when the snapshot was written by a NEWER schema than
    /// this binary understands (an old widget must not misrender re-meant fields).
    static func read(from defaults: UserDefaults? = nil) -> WidgetSnapshot? {
        guard let defaults = defaults ?? sharedDefaults(),
              let data = defaults.data(forKey: snapshotKey),
              let snapshot = try? WidgetSnapshot.decoded(from: data),
              snapshot.schemaVersion <= WidgetSnapshot.currentSchemaVersion
        else { return nil }
        return snapshot
    }

    static func write(_ snapshot: WidgetSnapshot, to defaults: UserDefaults? = nil) {
        guard let defaults = defaults ?? sharedDefaults(),
              let data = try? snapshot.encoded()
        else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    /// Read-modify-write with merge semantics: the recovery pipeline updates the
    /// readiness half without clobbering the load half, and vice versa. Starts from an
    /// empty snapshot when none exists. Stamps `generatedAt` and the schema version on
    /// every write so a partially-populated snapshot is still honestly dated.
    static func merge(in defaults: UserDefaults? = nil, _ mutate: (inout WidgetSnapshot) -> Void) {
        guard let defaults = defaults ?? sharedDefaults() else { return }
        var snapshot = read(from: defaults) ?? WidgetSnapshot()
        mutate(&snapshot)
        snapshot.schemaVersion = WidgetSnapshot.currentSchemaVersion
        snapshot.generatedAt = .now
        write(snapshot, to: defaults)
    }
}
