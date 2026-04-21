# Domain Pitfalls

**Domain:** Training analytics, periodization detection, fatigue patterns, and data export for athlete workload management iOS app
**Researched:** 2026-04-20

## Critical Pitfalls

Mistakes that cause rewrites, incorrect athlete guidance, or data integrity failures.

### Pitfall 1: ACWR Over-Reliance Creates False Confidence in Injury Prediction

**What goes wrong:** The app presents ACWR zones as authoritative injury risk indicators. Athletes and coaches make training decisions based on ACWR thresholds (e.g., "sweet spot" 0.8-1.3) that have weak predictive validity. A 2021 cluster RCT of 482 elite youth footballers found zero difference in injury rates between ACWR-guided and control groups after a full season.

**Why it happens:** ACWR is intuitive and widely marketed by wearable companies. The ratio suffers from mathematical coupling (acute load appears in both numerator and denominator of the uncoupled version), arbitrary 7/28-day windows, and susceptibility to noise. Tonus already uses EWMA which is better than rolling averages, but the fundamental limitation remains.

**Consequences:** Athletes ignore real fatigue signals because the app says they're in the "sweet spot." Or they skip training unnecessarily because of a high ACWR that reflects normal periodized loading. Liability risk if injury occurs while the app showed "green."

**Prevention:**
- Frame ACWR as a trend indicator, never as injury prediction. Use language like "training load trend" not "injury risk."
- Always pair ACWR with recovery score data. A high ACWR with good recovery is different from high ACWR with poor recovery.
- Add disclaimer text in analytics views: "Training load trends are informational, not medical advice."
- Do not add color-coded "danger zones" to weekly summaries without recovery context.

**Detection:** Review any analytics UI copy that implies causation ("you're at risk of injury"). Check that ACWR is never presented standalone without recovery data.

**Phase relevance:** Weekly training summary, fatigue pattern analysis.

---

### Pitfall 2: Periodization Detection Without Sufficient Training History

**What goes wrong:** The app attempts to detect mesocycles (accumulation, intensification, realization/deload) from too little data. With fewer than 8-12 weeks of consistent training data, periodization detection produces noisy, meaningless results. Users see "detected patterns" that are actually random variation.

**Why it happens:** Developers want the feature to work immediately. But periodization is inherently a multi-week pattern. A mesocycle is typically 3-6 weeks, meaning you need at least 2 complete cycles (6-12 weeks minimum) to detect any pattern.

**Consequences:** New users see garbage pattern labels. Power users lose trust in the analytics. Coaches sharing athlete reports see inconsistent cycle labels that change week to week.

**Prevention:**
- Require minimum 8 weeks of data with at least 3 workouts/week before enabling periodization detection.
- Show "Collecting data..." placeholder with a progress indicator (e.g., "6 of 8 weeks recorded") instead of attempting early detection.
- Use a rolling window of at least 12 weeks for pattern matching.
- Never auto-label a phase unless confidence exceeds a defined threshold (e.g., volume variance between candidate phases > 20%).

**Detection:** Test periodization feature with 2-week, 4-week, and 8-week synthetic data. If it produces labels for the 2-week case, the threshold is too low.

**Phase relevance:** Training cycle detection phase. Gate behind data sufficiency check from day one.

---

### Pitfall 3: Fatigue Pattern Correlation Presented as Causation

**What goes wrong:** The app detects that recovery dips follow training spikes (which is obvious by definition -- that is what fatigue IS) and presents this as an insight. Or worse, it finds spurious correlations (e.g., "your recovery drops on Tuesdays") driven by confounders like Monday being a heavy training day for most athletes.

**Why it happens:** Correlation between load and recovery is built into the EWMA model itself -- ATL rising while CTL lags IS the mathematical definition of the load-recovery relationship. Finding it is circular, not insightful. Additionally, HRV has high day-to-day variability (CV of 15-30%) unrelated to training, and confounders like alcohol, stress, illness, and travel are invisible to the app.

**Consequences:** Athletes optimize for meaningless patterns. "I always feel bad after Thursday sessions" might actually be because they drink on Wednesdays. False insights erode trust in the analytics suite.

**Prevention:**
- Focus fatigue analysis on multi-week trends, not day-to-day correlations.
- Use at least 7-day rolling averages for recovery trends before correlating with load.
- Frame insights as observations, not explanations: "Recovery trended down during weeks with 20%+ load increases" not "High training load caused poor recovery."
- Consider adding confounders to wellness check-ins (travel, illness, alcohol) so correlations can be filtered. But do NOT block the feature on this -- just be honest about limitations.

**Detection:** If the fatigue analysis ever outputs an insight that is definitionally true from the EWMA model, it is circular and should be removed.

**Phase relevance:** Fatigue pattern analysis. Design insights carefully during implementation.

---

### Pitfall 4: PDF/CSV Export Crashes on Real-World Data Volumes

**What goes wrong:** Export works in development with 2 weeks of data but crashes or hangs on a real athlete's phone with 6+ months of daily snapshots, hundreds of workout sessions, and thousands of set records. PDF generation with SwiftUI Charts is particularly memory-intensive.

**Why it happens:** SwiftUI Charts performance degrades sharply above ~10,000 data points. PDF rendering via `UIGraphicsPDFRenderer` or `ImageRenderer` loads the entire view hierarchy into memory. CSV string concatenation for large datasets creates excessive allocations. All of this runs on `@MainActor` because of SwiftData context isolation.

**Consequences:** App crashes during export -- the worst possible UX for a "pro" feature users are paying for. Users lose trust. App Store reviews tank.

**Prevention:**
- Set hard limits on export date ranges (max 12 weeks per PDF, unlimited for CSV but paginated).
- For PDF: render charts as pre-aggregated data (weekly averages, not daily points). Use `UIGraphicsPDFRenderer` with page breaks, not a single massive view.
- For CSV: stream to file using `OutputStream` instead of building a giant String in memory. Write in chunks of 100 rows.
- Profile export on-device with 6 months of synthetic data (180 recovery snapshots, 150 workload snapshots, 500 workout sessions, 2000 set records) before shipping.
- Show progress indicator during export. Run export work off the main actor where possible (prepare data on main actor, render PDF on background thread).

**Detection:** If export takes >3 seconds with 3 months of data during development, it will crash with 12 months on a real device.

**Phase relevance:** Data export phase. Build with streaming/pagination from the start -- do not retrofit.

---

### Pitfall 5: Weekly Summary Aggregation Ignores Rest Days and Creates Misleading Averages

**What goes wrong:** Weekly training summary divides total load by 7 days, making a 4-day-per-week athlete look like they train at moderate intensity daily. Or it reports "average session load" that conflates strength and cardio sessions with wildly different TSS scales.

**Why it happens:** Tonus currently computes daily TSS and EWMA but has no concept of "training days vs rest days" or session type categorization for aggregation purposes. The `WorkloadSnapshot` stores a single `loadSource` (sRPE or TRIMP) but weekly summaries need to handle mixed sources.

**Consequences:** Athletes misinterpret weekly summaries. A coach comparing two athletes sees misleading averages. Weekly volume comparisons across different training modalities are meaningless.

**Prevention:**
- Report training days separately from rest days in weekly summaries: "4 training days, 3 rest days."
- Show total weekly load AND per-session average (total / training days, not total / 7).
- If mixing sRPE and TRIMP sessions, normalize before aggregating or report them separately.
- Include session count and training frequency as first-class metrics in the weekly summary, not just load totals.

**Detection:** Generate a weekly summary for an athlete who trains 3x/week. If the "daily average" looks like light training, the denominator is wrong.

**Phase relevance:** Weekly training summary. Design the aggregation model before building the UI.

---

### Pitfall 6: HealthKit Authorization Revocation Silently Corrupts Analytics

**What goes wrong:** User grants HealthKit access, builds 8 weeks of recovery baselines, then revokes access (or gets a new phone and forgets to re-authorize). The app continues computing recovery scores using stale baselines that drift further from reality. Weekly summaries and fatigue analysis use outdated biometric data without any indication.

**Why it happens:** This is already flagged in CONCERNS.md as existing tech debt: `RecoveryPipeline.run()` uses `try?` and swallows HealthKit authorization errors. The analytics layer would inherit this silent failure.

**Consequences:** Recovery scores become fictional. Fatigue pattern analysis correlates training load with stale recovery data, producing completely wrong insights. Athlete makes training decisions based on phantom recovery status.

**Prevention:**
- Before building any analytics features, fix the existing HealthKit error handling in RecoveryPipeline (distinguish "no data" from "no permission").
- Add a `lastHealthKitSync` timestamp to the Athlete model. If >48 hours stale, show a prominent warning on any analytics view.
- In weekly summaries, include a "data quality" indicator: "Recovery data: Complete" vs "Recovery data: Partial (HealthKit disconnected since [date])."
- Never include stale recovery data (>7 days old) in fatigue pattern correlations.

**Detection:** Revoke HealthKit access in Settings during testing. If analytics views show no warning, this pitfall is active.

**Phase relevance:** Must be fixed BEFORE fatigue pattern analysis and weekly summaries. Prerequisite work.

## Moderate Pitfalls

### Pitfall 7: Sync Conflicts Corrupt Aggregated Analytics

**What goes wrong:** Coach edits a workout's RPE on their device while the athlete is viewing a weekly summary. Last-write-wins sync overwrites the RPE. The weekly summary now shows different numbers than what the athlete saw 5 minutes ago. With no conflict resolution (flagged in CONCERNS.md), aggregated analytics become unreliable.

**Prevention:**
- Make analytics computations idempotent: re-derive weekly summaries from source data, never cache aggregated values.
- Add `updatedAt` checks when displaying analytics. If underlying data changed since last computation, re-compute.
- For PDF exports, snapshot the data at export time (copy values, do not reference live objects). A PDF should represent a point-in-time view.

**Phase relevance:** All analytics phases. Use a compute-on-read pattern, not cached aggregations.

---

### Pitfall 8: Periodization Labels Confuse Non-Expert Users

**What goes wrong:** The app labels training phases as "Accumulation," "Intensification," or "Realization" -- terms that mean nothing to 80% of recreational athletes. Users see jargon they don't understand and ignore the feature entirely, or worse, misinterpret it.

**Prevention:**
- Use plain language: "Building" (accumulation), "Pushing" (intensification), "Tapering/Recovery" (realization/deload).
- Include a one-line explanation with each label: "Building: Higher volume, moderate intensity -- growing your base."
- Provide a "Learn More" sheet explaining the concept, not just the label.
- For coaches (who know the terminology), offer a "scientific labels" toggle in settings.

**Phase relevance:** Training cycle detection UI design.

---

### Pitfall 9: CSV Export Leaks Sensitive HealthKit Data

**What goes wrong:** The CSV export includes raw HRV, RHR, and sleep data. The user shares the CSV with their coach via email. This may violate Apple's HealthKit guidelines (raw HealthKit data must not leave the device) and creates privacy liability.

**Prevention:**
- Export only composite scores (recovery score, ACWR, TSB) and training metrics (session load, volume, RPE), never raw HealthKit values.
- If users request raw biometric data, direct them to Apple Health's native export.
- Add a clear disclaimer: "This export contains training metrics only. Raw health data stays on your device."
- Review Apple's HealthKit guidelines before implementing export: raw sample data cannot be shared with third parties or transmitted off-device.

**Detection:** Check every column in the CSV output against the HealthKit guidelines. If `hrvSDNN` or `restingHR` appears as a raw column, it violates the policy.

**Phase relevance:** Data export phase. Design the export schema before writing code.

---

### Pitfall 10: MainActor Bottleneck During Analytics Computation

**What goes wrong:** Computing 12 weeks of aggregated analytics (weekly summaries, periodization detection, fatigue correlations) requires reading hundreds of SwiftData objects. Since SwiftData ModelContext is MainActor-isolated in iOS 17, all this computation blocks the UI thread.

**Prevention:**
- Fetch data on MainActor, but immediately copy values into plain structs (not @Model objects).
- Perform all analytics computation (aggregation, pattern matching, correlation) on plain structs in a background Task.
- Use the existing pure-struct engine pattern (WorkloadCalculator, RecoveryScoreEngine) for all new analytics engines.
- Profile with Instruments: if analytics computation exceeds 100ms on MainActor, it needs to be moved.

**Detection:** Open the weekly summary view with 6 months of data. If there is any frame drop or delay, computation is blocking the main thread.

**Phase relevance:** All analytics phases. Establish the pattern in the first analytics feature (weekly summary).

---

### Pitfall 11: Export Feature Bypasses Subscription Gating

**What goes wrong:** Data export is a "Pro" feature but the implementation generates the file before checking the subscription. A determined user could intercept the file, or the export runs (consuming resources) before showing the paywall.

**Prevention:**
- Check `isPro` entitlement before beginning any export computation, not after.
- Follow the existing pattern: check subscription -> show UpgradeSheet if needed -> only then run export.
- For coach exports of athlete data, verify both `isCoach` entitlement and that the coach-athlete relationship is active.

**Phase relevance:** Data export phase.

## Minor Pitfalls

### Pitfall 12: Weekly Summary Timezone Handling

**What goes wrong:** "This week" means different things depending on the user's timezone and locale (week starts Monday in most of the world, Sunday in the US). Workout timestamps from HealthKit use UTC. If the app doesn't normalize to the user's local calendar, weekly boundaries split sessions incorrectly.

**Prevention:**
- Use `Calendar.current` for all week boundary calculations.
- Store and compare dates using the user's local calendar, not UTC day boundaries.
- Test with timezones that straddle midnight (e.g., US Pacific where a late-night workout is the next UTC day).

**Phase relevance:** Weekly training summary.

---

### Pitfall 13: PDF Export Doesn't Match Screen Appearance

**What goes wrong:** Charts rendered in PDF look different from the in-app charts. SwiftUI Charts renders differently in `ImageRenderer` context vs live views. Colors may shift, dark mode charts rendered on white PDF background look wrong, and text sizing differs.

**Prevention:**
- Force light mode for PDF chart rendering regardless of system appearance.
- Use `ImageRenderer` with explicit size and scale factor, test on multiple device sizes.
- Provide a PDF preview screen before export so users can verify appearance.

**Phase relevance:** Data export phase.

---

### Pitfall 14: Fatigue Analysis Recommends Deload During Planned Peaking

**What goes wrong:** The fatigue pattern engine detects sustained high load and recommends recovery. But the athlete is intentionally peaking for a competition. The app's recommendation contradicts their (or their coach's) plan.

**Prevention:**
- Allow athletes/coaches to mark "competition prep" or "planned overreach" periods that suppress deload recommendations.
- Frame fatigue insights as observations, not directives: "Your load has been elevated for 3 weeks" not "You should take a recovery week."
- For coached athletes, never auto-generate recommendations -- let the coach interpret the data.

**Phase relevance:** Fatigue pattern analysis.

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Weekly training summary | Rest day averaging (Pitfall 5), timezone issues (Pitfall 12), MainActor blocking (Pitfall 10) | Design aggregation model first; use training-day denominators; normalize to local calendar |
| Periodization detection | Insufficient data threshold (Pitfall 2), jargon labels (Pitfall 8) | Require 8+ weeks minimum; use plain language with scientific toggle |
| Fatigue pattern analysis | Circular correlations (Pitfall 3), stale HealthKit data (Pitfall 6), competition conflicts (Pitfall 14) | Fix HealthKit error handling first; use multi-week trends only; frame as observations |
| Data export (PDF/CSV) | Memory crashes (Pitfall 4), HealthKit data leakage (Pitfall 9), appearance mismatch (Pitfall 13), subscription bypass (Pitfall 11) | Stream CSV; paginate PDF; export only composite scores; check entitlement first |
| All analytics | ACWR overstatement (Pitfall 1), sync conflicts (Pitfall 7) | Frame as trends not predictions; compute-on-read pattern |

## Prerequisite Work Before Analytics

The following existing tech debt (from CONCERNS.md) must be addressed before building analytics features, or the analytics will inherit and amplify these problems:

1. **HealthKit error handling** -- RecoveryPipeline's `try?` swallowing must be fixed. Analytics built on silently-stale data are worse than no analytics.
2. **SyncService error suppression** -- Silent sync failures mean coach and athlete see different data. Analytics computed from inconsistent local state produce different results per device.
3. **MainActor contention** -- Existing sync already has performance concerns. Adding analytics computation on top will make the UI thread situation worse.

## Sources

- [Science for Sport: ACWR Overview](https://www.scienceforsport.com/acutechronic-workload-ratio/) - ACWR methodology and limitations
- [PMC: ACWR Systematic Review and Meta-Analysis](https://pmc.ncbi.nlm.nih.gov/articles/PMC12487117/) - Evidence for ACWR predictive limitations
- [gpexe: ACWR Rolling Average vs EWMA](https://www.gpexe.com/acutechronic-workload-ratio-part-2/) - EWMA practical limitations in sport
- [Medium: Training Load & Strain Wearable Limitations](https://medium.com/@CuriousCatalyst/training-load-strain-understanding-your-wearables-injury-prevention-system-and-its-7c9aa456e53a) - Wearable load monitoring false confidence
- [arXiv: Fatigue Monitoring Using Wearables and AI](https://arxiv.org/html/2412.16847v1) - HRV false positives, confounders
- [Apple Developer Forums: Swift Charts Performance](https://developer.apple.com/forums/thread/740314) - Chart rendering limits at scale
- [Joyfill: PDF Limitations in Native Swift](https://joyfill.io/blog/overcoming-the-pdf-limitations-in-native-swift-mobile-apps) - iOS PDF generation constraints
- [Apple: Understanding SwiftUI Performance](https://developer.apple.com/documentation/Xcode/understanding-and-improving-swiftui-performance) - MainActor and rendering performance

---

*Pitfalls audit: 2026-04-20*
