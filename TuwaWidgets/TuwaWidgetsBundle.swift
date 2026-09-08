import SwiftUI
import WidgetKit

/// The Tuwa widget extension — two widgets, small + medium families each.
///
/// **Membership: widget extension target only.** Shared files this target also needs
/// (see the Xcode checklist): `WidgetSnapshot.swift`, `WidgetSnapshotStore.swift`,
/// `ColorTokens.swift`, `FontTokens.swift`, plus the five font files.
///
/// The extension reads ONLY the App Group snapshot — no SwiftData, no HealthKit,
/// no network. The app writes; the widget renders.
@main
struct TuwaWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ReadinessWidget()
        TrainingLoadWidget()
        // The guided session's lock-screen Live Activity (v1.7.3 feature 9 batch 2). Not a
        // home-screen widget: it renders only while a guided session is running.
        GuidedSessionLiveActivity()
    }
}
