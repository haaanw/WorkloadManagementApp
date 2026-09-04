import Foundation
import PostHog

/// PostHog as an `AnalyticsSink` behind `UXAnalyticsService` (GROWTH-STACK §1.1). Views
/// never import PostHog — this file and the AppContainer registration are the only two
/// places the SDK's name may appear, and a fence test pins that. Events arrive here
/// already sanitized (the service's chokepoint); property discipline upstream is
/// buckets-only, never a health value.
///
/// Configuration: the ingest key is a PUBLIC client-side key (phc_…), committed empty
/// until HAN approves the vendor and creates the project (GROWTH-STACK §6.4). With an
/// empty key the sink is never constructed, so nothing initializes and nothing egresses.
enum PostHogSettings {
    /// HAN fills this after vendor approval. Public ingest key — not a secret, but its
    /// presence is the switch that makes the SDK live.
    static let apiKey = ""
    /// EU cloud by decision (GROWTH-STACK §1: the privacy escape hatch).
    static let host = "https://eu.i.posthog.com"
}

final class PostHogAnalyticsSink: AnalyticsSink {

    /// Fails (nil) on an empty key: no SDK setup, no network, no vendor contact.
    init?(apiKey: String = PostHogSettings.apiKey, host: String = PostHogSettings.host) {
        guard !apiKey.isEmpty else { return nil }
        let config = PostHogConfig(apiKey: apiKey, host: host)
        // Autocapture surfaces UI internals we did not sanitize — the §1.2 event spec
        // is the whole contract, so everything automatic stays off.
        config.captureApplicationLifecycleEvents = false
        config.captureScreenViews = false
        PostHogSDK.shared.setup(config)
    }

    func send(_ event: UXAnalyticsEvent, properties: [String: String]) {
        PostHogSDK.shared.capture(event.rawValue, properties: properties)
    }
}
