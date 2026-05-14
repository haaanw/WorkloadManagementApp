# Phase 17: Cycle Data Foundation - Context

**Gathered:** 2026-05-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Zero-friction cycle data integration — read existing HealthKit menstrual data from apps users already use (Clue, Flo, Apple Cycle Tracking), compute cycle day/phase with confidence scoring, and handle all edge cases (irregular, anovulatory, contraceptive, perimenopause, pregnancy, lactation). Users who don't track cycles experience zero change.

</domain>

<decisions>
## Implementation Decisions

### HealthKit Permission Flow
- **D-01:** Bundle menstrual data types (`.menstrualFlow`, `.contraceptive`, `.pregnancy`, `.lactation`, `.irregularMenstrualCycles`, `.ovulationTestResult`) into the existing `readTypes` set in `HealthKitService`. One permission sheet covers everything — no separate menstrual-specific auth flow.
- **D-02:** If user declines menstrual permissions (or HealthKit returns no menstrual data), show a one-time soft prompt on Dashboard explaining cycle-aware benefits with a link to Settings to re-enable. Then never ask again. All cycle features remain invisible otherwise.

### Contraceptive Status UX
- **D-03:** Add a "Cycle & Hormones" section in `ProfileView` below the existing Training Profile section. Contains contraceptive status picker and pregnancy/lactation toggles. Section visible only after HealthKit menstrual permissions are granted (or menstrual data exists).
- **D-04:** Simple binary contraceptive model: "Hormonal contraceptive: Yes/No". All hormonal methods (OC, patch, ring, hormonal IUD, implant) flatten the cycle similarly enough — no need for type-specific granularity. OC users skip all phase-based adjustments downstream.

### Cycle Phase Confidence
- **D-05:** Show phase info on Dashboard after 1 complete cycle (2 logged period starts in HealthKit). Low bar to deliver value quickly. Phase 18 (same-phase baselines) needs 3+ cycles anyway for meaningful comparison.
- **D-06:** Irregular cycles (>35 days or highly variable): Claude's Discretion — pick the approach that best serves Phase 18 downstream. Options considered: show cycle day only (skip phase), or show phase with low confidence flag. Either way, Phase 18 baselines fall back to 7-day rolling for irregular users.

### Data Model Shape
- **D-07:** Contraceptive status and exclusion flags (pregnancy, lactation) live on the `Athlete` model as optional fields: `isOnHormonalContraceptive: Bool`, `isPregnant: Bool`, `isLactating: Bool`. These are athlete-level states, not per-snapshot. Syncs to Supabase with existing Athlete sync.
- **D-08:** `MenstrualCycleSnapshot` is a new `@Model` with one row per day — matches the existing `RecoverySnapshot` pattern. Fields: date, cycleDay, estimatedPhase (CyclePhase enum), confidence, cycleLength, wristTempDeviation, flowIntensity, isCycleStart, exclusionFlags. Easy to query "what phase was I on date X?"
- **D-09:** `CycleContext` is a lightweight struct (not @Model) that `CycleTrackingService` produces and passes to downstream engines (RecoveryScoreEngine in Phase 18). Contains today's phase, confidence, exclusion flags, cycle day.
- **D-10:** `CyclePhase` enum: earlyFollicular, lateFollicular, ovulatory, earlyLuteal, lateLuteal, unknown. String-backed, Codable, CaseIterable.
- **D-11:** `CycleTrackingService` is a `@MainActor final class` (stateful — needs HealthKit store access). Reads `.menstrualFlow` with `HKMetadataKeyMenstrualCycleStart`, `.appleSleepingWristTemperature`, and cycle irregularity flags. Pure HealthKit reader — zero manual logging required.

### Privacy
- **D-12:** Raw menstrual data (flow dates, ovulation tests, cervical mucus) never syncs to Supabase. Only derivative values (cycle phase, cycle day) can influence algorithms. `MenstrualCycleSnapshot` is local-only — no Supabase table, no sync.

### Claude's Discretion
- Irregular cycle handling strategy (D-06) — Claude picks best approach for Phase 18 compatibility
- CyclePhase estimation algorithm details (day-count vs temperature-confirmed)
- Wrist temperature biphasic shift detection thresholds

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Research
- `.planning/research/female-athlete-optimization-research.md` — 696-line evidence base covering HealthKit API specifics (Section 5), competitor analysis, algorithm implications, and guiding principles (Section 9)

### Apple HealthKit APIs
- `HKCategoryTypeIdentifier.menstrualFlow` — primary cycle data source
- `HKMetadataKeyMenstrualCycleStart` — metadata flag distinguishing cycle start from mid-cycle flow
- `HKQuantityTypeIdentifier.appleSleepingWristTemperature` — biphasic shift for ovulation detection (already in readTypes)
- `HKCategoryTypeIdentifier.irregularMenstrualCycles` — Apple-detected irregularity flag
- `HKCategoryTypeIdentifier.ovulationTestResult` — user-logged ovulation test results

### Existing Code
- `WorkloadApp/Services/HealthKitService.swift` — existing HK service to extend with menstrual types
- `WorkloadApp/Models/Athlete.swift` — add contraceptive/pregnancy/lactation fields here
- `WorkloadApp/Models/TrainingProfile.swift` — Phase 9 model pattern (UUID FK to Athlete)
- `WorkloadApp/Views/Profile/ProfileView.swift` — add "Cycle & Hormones" section here
- `WorkloadApp/Services/RecoveryPipeline.swift` — will query CycleTrackingService in Phase 18

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `HealthKitService`: Already structured with `readTypes` set, `requestAuthorization()`, and typed fetch methods. New menstrual types slot directly into the same pattern.
- `RecoverySnapshot` pattern: One-row-per-day @Model with date-based queries — `MenstrualCycleSnapshot` follows this exact pattern.
- `ProfileView` section pattern: `sectionHeader()` + `editablePicker()` + `divider()` helpers for consistent profile UI.

### Established Patterns
- `@MainActor final class` for stateful services (HealthKitService, AuthService)
- `@Model` with `@Attribute(.unique) var id: UUID` for all persistent entities
- `@Relationship(deleteRule: .cascade)` for parent-child links on Athlete
- Enums conform to `String, Codable, CaseIterable, Identifiable` with `displayName` computed property

### Integration Points
- `HealthKitService.readTypes` — add menstrual category types here
- `Athlete` model — add optional Bool fields for contraceptive/pregnancy/lactation
- `ProfileView.body` — insert new section after Training Profile
- `RecoveryPipeline.run()` — will query CycleContext in Phase 18 (not this phase)
- `WorkloadApp.swift` schema — register `MenstrualCycleSnapshot` in ModelContainer

</code_context>

<specifics>
## Specific Ideas

- Research document (Section 9.1) provides a complete proposed model schema — use as reference but adapt to decisions above
- CycleTrackingService should be a pure HealthKit reader on first launch — zero friction (user feedback memory)
- Dr. Stacy Sims's position: "train by readiness, use cycle as context" — cycle phase is metadata, not override
- Marco Altini (HRV4Training): "Group-level changes don't always translate into useful individual-level information" — individual over population

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 17-cycle-data-foundation*
*Context gathered: 2026-05-14*
