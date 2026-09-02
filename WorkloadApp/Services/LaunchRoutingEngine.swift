import Foundation

/// Decides the cold-launch route — and it is the ONLY place that decision lives.
///
/// Born from dogfood B3 (2026-09-01): the loading screen blocked first paint on a serial
/// network chain — session check with a possible token refresh, a full `pullAll` whenever
/// the sync clock said stale (true every morning), then a RevenueCat round-trip — which on
/// a mobile network was an observed ~10 s of "Preparing Tuwa" on every open.
///
/// The law this engine encodes: **blocking is legitimate only when the local store cannot
/// answer.** A returning user — a local Athlete exists AND a session sits in the Keychain —
/// routes to the app immediately; sync, identity linking, and any token refresh happen
/// behind first paint, with `@Query` surfaces updating as pulled data lands. A fresh
/// install with a valid session has no local Athlete to show, so the bootstrap (and its
/// zombie / unreachable-server outcomes, which encode the H7 incident) stays blocking.
///
/// Pure and static so the routing decision is testable without SwiftUI, SwiftData, or a
/// network in the room.
struct LaunchRoutingEngine {

    /// What the launch task does before letting the UI route.
    enum Decision: Equatable {
        /// No stored session → login screen. This consults LOCAL storage only: an
        /// expired-but-present session still routes to the app (the background sync
        /// refreshes it on demand), because "expired" every morning is exactly the
        /// state that made launch block on the network.
        case showLogin
        /// Session but no local Athlete (fresh install / reinstall): the blocking
        /// bootstrap chain runs — it is the only honest option, since there is no
        /// local data to paint.
        case blockingBootstrap
        /// Returning user: route to the app NOW; sync runs behind first paint.
        case routeImmediately
    }

    static func decide(hasLocalSession: Bool, hasLocalAthlete: Bool) -> Decision {
        guard hasLocalSession else { return .showLogin }
        return hasLocalAthlete ? .routeImmediately : .blockingBootstrap
    }

    /// What the deferred (post-paint) zombie check may do.
    enum DeferredZombieAction: Equatable {
        /// Local athlete still present after the pull — the normal case, nothing to do.
        case none
        /// The athlete store emptied under a signed-in session. The fault is SURFACED to
        /// the athlete; nothing is wiped and nobody is signed out. There is deliberately
        /// no `.signOut` case: the blocking launch may sign a zombie out because the user
        /// has seen nothing yet, but once they are inside the app a background task
        /// destroying their session (and, through the sign-out cascade, their local data)
        /// is never acceptable — sign-out stays behind the user-confirmed Profile path
        /// with its push-risk wipe guard.
        case surfaceFault
    }

    static func deferredZombieAction(athleteCountAfterPull: Int) -> DeferredZombieAction {
        athleteCountAfterPull == 0 ? .surfaceFault : .none
    }
}
