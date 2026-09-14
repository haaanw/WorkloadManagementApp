import XCTest
@testable import workload_management

/// v1.7.3 UAT round 3 (U25 / U26) — unit tests for the pure `SessionCapEngine`.
///
/// The engine gives a planned day with NO weighted top set — a run, a court session, a
/// conditioning block — the same suggest-and-confirm shape the lift day already has, in the units
/// that day actually has: a maximum RPE and a duration cap.
///
/// Four claims are pinned here.
///
/// 1. **The rule table is what ships.** Each row of the record's table produces its stated
///    duration percentage and its stated RPE ceiling.
/// 2. **A cap can only shorten or lower.** No input combination can return a duration longer than
///    the plan or an RPE above what the plan asked for. This is the invariant the whole surface
///    rests on: the app modulates the athlete's session, it never writes one.
/// 3. **Nothing is invented.** A plan with no duration gets no duration cap; the max RPE is
///    always the recommendation's own `intensityCap`, never a new number.
/// 4. **The budget arithmetic is minutes × RPE** (Foster 1998), and nil whenever either factor is.
///
/// Foundation-only value tests, mirroring `TodayVerdictEngineTests` — no ModelContainer needed.
final class SessionCapEngineTests: XCTestCase {

    // MARK: - Fixtures

    private func recommendation(
        cap: Double,
        vol: Double = 1.0,
        type: AutoregulationEngine.TrainingRecommendation.RecommendedSessionType = .strength
    ) -> AutoregulationEngine.TrainingRecommendation {
        AutoregulationEngine.TrainingRecommendation(
            intensityCap: cap,
            volumeModifier: vol,
            sessionType: type,
            warnings: [],
            headline: "H",
            detail: "D"
        )
    }

    /// A 90-minute run — the record's own worked example.
    private let plannedNinetyMinutes = 90 * 60

    private func evaluate(
        cap: Double,
        recType: AutoregulationEngine.TrainingRecommendation.RecommendedSessionType = .strength,
        fatigue: FatigueIndexEngine.FatigueZone? = .low,
        strain: StrainRiskZone? = .low,
        matchDaysAway: Int? = nil,
        plannedDurationSeconds: Int? = nil,
        plannedRPE: Double? = nil,
        sessionType: SessionType = .cardio
    ) -> SessionCapEngine.SessionCap {
        SessionCapEngine.evaluate(
            recommendation: recommendation(cap: cap, type: recType),
            fatigueZone: fatigue,
            strainRiskZone: strain,
            matchDaysAway: matchDaysAway,
            plannedDurationSeconds: plannedDurationSeconds,
            plannedRPE: plannedRPE,
            sessionType: sessionType
        )
    }

    private func minutes(_ cap: SessionCapEngine.SessionCap) -> Int? { cap.maxDurationMinutes }

    // MARK: - 1. The rule table, row by row

    func test_highReadinessLowFatigue_isAsPlanned() {
        let cap = evaluate(
            cap: 10, recType: .power,
            fatigue: .low, strain: .low,
            plannedDurationSeconds: plannedNinetyMinutes
        )
        XCTAssertEqual(cap.shape, .asPlanned)
        XCTAssertEqual(minutes(cap), 90, "as planned means the whole planned session")
        XCTAssertEqual(cap.maxRPE, 10)
    }

    func test_highReadinessStrainElevated_caps85PercentAtRPE8() {
        let cap = evaluate(
            cap: 8, recType: .strength,
            fatigue: .low, strain: .elevated,
            plannedDurationSeconds: plannedNinetyMinutes
        )
        XCTAssertEqual(cap.shape, .capped)
        XCTAssertEqual(minutes(cap), 76, "90 × 0.85 = 76.5 → floored to a whole minute")
        XCTAssertEqual(cap.maxRPE, 8)
    }

    func test_moderateReadinessFatigueElevated_caps80PercentAtRPE7() {
        let cap = evaluate(
            cap: 7, recType: .conditioning,
            fatigue: .elevated, strain: .elevated,
            plannedDurationSeconds: plannedNinetyMinutes
        )
        XCTAssertEqual(cap.shape, .capped)
        XCTAssertEqual(minutes(cap), 72, "the STRONGER row wins: 80% beats 85%")
        XCTAssertEqual(cap.maxRPE, 7)
    }

    func test_moderateReadinessStrainHigh_caps70PercentAtRPE6() {
        let cap = evaluate(
            cap: 6, recType: .activeRecovery,
            fatigue: .low, strain: .high,
            plannedDurationSeconds: plannedNinetyMinutes
        )
        XCTAssertEqual(cap.shape, .capped)
        // `.activeRecovery` is the low-readiness row, which is stronger than strain-high.
        XCTAssertEqual(minutes(cap), 54)
        XCTAssertEqual(cap.maxRPE, 6)
    }

    func test_strainHighAlone_caps70Percent() {
        let cap = evaluate(
            cap: 6, recType: .conditioning,
            fatigue: .low, strain: .high,
            plannedDurationSeconds: plannedNinetyMinutes
        )
        XCTAssertEqual(minutes(cap), 63, "90 × 0.70")
        XCTAssertEqual(cap.maxRPE, 6)
    }

    func test_fatigueHigh_caps60PercentTechnical() {
        let cap = evaluate(
            cap: 6, recType: .conditioning,
            fatigue: .high, strain: .moderate,
            plannedDurationSeconds: plannedNinetyMinutes
        )
        XCTAssertEqual(cap.shape, .capped)
        XCTAssertEqual(minutes(cap), 54, "90 × 0.60")
        XCTAssertEqual(cap.maxRPE, 6)
    }

    func test_fatigueSaturation_holdsAtThirtyMinutesAndRPE5() {
        let cap = evaluate(
            cap: 6, recType: .activeRecovery,
            fatigue: .saturation, strain: .high,
            plannedDurationSeconds: plannedNinetyMinutes
        )
        XCTAssertEqual(cap.shape, .hold)
        XCTAssertEqual(minutes(cap), 30, "a hold is bounded at the 30-minute ceiling")
        XCTAssertEqual(cap.maxRPE, 5)
    }

    func test_restRecommendation_alsoHolds_andStillCarriesANumber() {
        let cap = evaluate(
            cap: 5, recType: .rest,
            fatigue: .high, strain: .high,
            plannedDurationSeconds: plannedNinetyMinutes
        )
        XCTAssertEqual(cap.shape, .hold)
        // The nocebo guard: a hold is a SHORT DOSE with a number, never a nil "do not train".
        XCTAssertNotNil(cap.maxDurationSeconds)
        XCTAssertNotNil(cap.maxRPE)
        XCTAssertGreaterThan(cap.maxDurationSeconds ?? 0, 0)
    }

    func test_matchWithinTwoDays_tapersToHalf_keepingIntensity() {
        let cap = evaluate(
            cap: 9, recType: .strength,
            fatigue: .low, strain: .low,
            matchDaysAway: 2,
            plannedDurationSeconds: plannedNinetyMinutes,
            plannedRPE: 9
        )
        XCTAssertEqual(cap.shape, .taper)
        XCTAssertEqual(minutes(cap), 45, "half the planned session")
        XCTAssertEqual(cap.maxRPE, 9, "a taper keeps the intensity — it cuts duration only")
    }

    func test_matchThreeDaysOut_doesNotTaper() {
        let cap = evaluate(
            cap: 9, fatigue: .low, strain: .low,
            matchDaysAway: 3,
            plannedDurationSeconds: plannedNinetyMinutes
        )
        XCTAssertEqual(cap.shape, .asPlanned)
        XCTAssertEqual(minutes(cap), 90)
    }

    func test_matchToday_tapers() {
        let cap = evaluate(
            cap: 9, matchDaysAway: 0,
            plannedDurationSeconds: plannedNinetyMinutes
        )
        XCTAssertEqual(cap.shape, .taper)
        XCTAssertEqual(minutes(cap), 45)
    }

    func test_holdOutranksTaper() {
        // A saturated body two days out from a match still holds — the shape names the body.
        let cap = evaluate(
            cap: 6, recType: .activeRecovery,
            fatigue: .saturation, strain: .high,
            matchDaysAway: 1,
            plannedDurationSeconds: plannedNinetyMinutes
        )
        XCTAssertEqual(cap.shape, .hold)
        XCTAssertEqual(cap.maxRPE, 5)
    }

    // MARK: - 2. A cap can only shorten or lower

    func test_neverExceedsThePlannedDuration_acrossEveryRow() {
        let planned = 40 * 60
        let fatigueZones: [FatigueIndexEngine.FatigueZone?] = [nil, .low, .elevated, .high, .saturation]
        let strainZones: [StrainRiskZone?] = [nil, .low, .moderate, .elevated, .high]
        let recTypes: [AutoregulationEngine.TrainingRecommendation.RecommendedSessionType] =
            [.power, .strength, .hypertrophy, .conditioning, .activeRecovery, .rest]
        let sessionTypes: [SessionType] = [.strength, .skill, .cardio, .match, .recovery]

        for fatigue in fatigueZones {
            for strain in strainZones {
                for recType in recTypes {
                    for sessionType in sessionTypes {
                        for days in [nil, 0, 1, 2, 3, 10] as [Int?] {
                            let cap = evaluate(
                                cap: 10, recType: recType,
                                fatigue: fatigue, strain: strain,
                                matchDaysAway: days,
                                plannedDurationSeconds: planned,
                                plannedRPE: 8,
                                sessionType: sessionType
                            )
                            XCTAssertLessThanOrEqual(
                                cap.maxDurationSeconds ?? 0, planned,
                                "a cap lengthened the session (\(String(describing: fatigue)) / \(String(describing: strain)) / \(recType) / \(sessionType) / \(String(describing: days)))"
                            )
                            XCTAssertLessThanOrEqual(
                                cap.maxRPE ?? 0, 8,
                                "a cap raised the intensity above the plan's own RPE"
                            )
                        }
                    }
                }
            }
        }
    }

    func test_plannedRPEBelowTheMatrixCeiling_wins() {
        let cap = evaluate(
            cap: 10, recType: .power,
            plannedDurationSeconds: plannedNinetyMinutes,
            plannedRPE: 6
        )
        XCTAssertEqual(cap.maxRPE, 6, "the plan's own RPE is the ceiling when it is the lower one")
    }

    func test_fractionalPlannedRPE_roundsDownNeverUp() {
        let cap = evaluate(
            cap: 10, plannedDurationSeconds: plannedNinetyMinutes, plannedRPE: 7.5
        )
        XCTAssertEqual(cap.maxRPE, 7, "7.5 must not be presented as the next rung up")
    }

    func test_rpeIsClampedToThePublishedScale() {
        let high = evaluate(cap: 99, plannedDurationSeconds: 600)
        XCTAssertEqual(high.maxRPE, 10)
        let low = evaluate(cap: -4, plannedDurationSeconds: 600)
        XCTAssertEqual(low.maxRPE, 1)
    }

    // MARK: - 3. Nothing is invented

    func test_noPlannedDuration_producesNoDurationCap() {
        let cap = evaluate(
            cap: 7, fatigue: .high, strain: .high,
            plannedDurationSeconds: nil
        )
        XCTAssertNil(cap.maxDurationSeconds, "a plan with no duration must not be given one")
        XCTAssertNil(cap.maxDurationMinutes)
        XCTAssertEqual(cap.maxRPE, 7, "the RPE ceiling still stands on its own")
    }

    func test_zeroPlannedDuration_isTreatedAsAbsent() {
        let cap = evaluate(cap: 7, fatigue: .high, plannedDurationSeconds: 0)
        XCTAssertNil(cap.maxDurationSeconds)
    }

    func test_maxRPEIsAlwaysTheRecommendationsIntensityCap() {
        for ceiling in [5.0, 6.0, 7.0, 8.0, 9.0, 10.0] {
            let cap = evaluate(cap: ceiling, plannedDurationSeconds: 3600)
            XCTAssertEqual(
                cap.maxRPE, Int(ceiling),
                "the engine invented an RPE instead of reusing the matrix's own cap"
            )
        }
    }

    func test_nilZones_engageNoRow() {
        let cap = evaluate(
            cap: 9, recType: .strength,
            fatigue: nil, strain: nil,
            plannedDurationSeconds: plannedNinetyMinutes
        )
        XCTAssertEqual(cap.shape, .asPlanned)
        XCTAssertEqual(minutes(cap), 90)
    }

    func test_matchSession_keepsItsPlannedDuration() {
        // You do not leave a game at 60%. Only the RPE ceiling applies.
        let cap = evaluate(
            cap: 7, fatigue: .high, strain: .high,
            plannedDurationSeconds: plannedNinetyMinutes,
            sessionType: .match
        )
        XCTAssertEqual(minutes(cap), 90)
        XCTAssertEqual(cap.maxRPE, 7)
    }

    func test_recoverySession_keepsItsPlannedDuration() {
        let cap = evaluate(
            cap: 6, fatigue: .high, strain: .high,
            plannedDurationSeconds: 30 * 60,
            sessionType: .recovery
        )
        XCTAssertEqual(minutes(cap), 30, "the recovery dose IS the short session")
    }

    func test_matchSessionOnMatchDay_isNotTapered() {
        let cap = evaluate(
            cap: 9, matchDaysAway: 0,
            plannedDurationSeconds: plannedNinetyMinutes,
            sessionType: .match
        )
        XCTAssertNotEqual(cap.shape, .taper)
        XCTAssertEqual(minutes(cap), 90)
    }

    func test_deterministic_sameInputSameOutput() {
        let first = evaluate(
            cap: 7, fatigue: .elevated, strain: .elevated,
            matchDaysAway: 5, plannedDurationSeconds: 4200, plannedRPE: 8
        )
        let second = evaluate(
            cap: 7, fatigue: .elevated, strain: .elevated,
            matchDaysAway: 5, plannedDurationSeconds: 4200, plannedRPE: 8
        )
        XCTAssertEqual(first, second)
    }

    // MARK: - 4. The load budget

    func test_loadBudget_isMinutesTimesRPE() {
        let cap = evaluate(
            cap: 7, fatigue: .elevated,
            plannedDurationSeconds: plannedNinetyMinutes
        )
        // 90 × 0.80 = 72 min, RPE 7 → 504 AU.
        XCTAssertEqual(cap.maxDurationMinutes, 72)
        XCTAssertEqual(cap.loadBudgetAU ?? 0, 72 * 7, accuracy: 1e-6)
    }

    func test_loadBudget_isNilWithoutADuration() {
        let cap = evaluate(cap: 7, plannedDurationSeconds: nil)
        XCTAssertNil(cap.loadBudgetAU)
    }

    // MARK: - 5. Shape honesty

    func test_aCapThatChangesNothing_readsAsPlanned() {
        // Strain elevated, but the plan is already shorter than 85% of nothing to cut: a plan
        // with no duration and an RPE at the ceiling has had nothing done to it.
        let cap = SessionCapEngine.evaluate(
            recommendation: recommendation(cap: 8, type: .strength),
            fatigueZone: .low,
            strainRiskZone: .elevated,
            matchDaysAway: nil,
            plannedDurationSeconds: nil,
            plannedRPE: 8,
            sessionType: .cardio
        )
        XCTAssertEqual(cap.shape, .asPlanned)
        XCTAssertFalse(cap.modulatesPlan)
    }

    func test_modulatesPlan_isTrueForEveryNonPlannedShape() {
        XCTAssertTrue(evaluate(cap: 8, strain: .elevated, plannedDurationSeconds: 3600).modulatesPlan)
        XCTAssertTrue(evaluate(cap: 9, matchDaysAway: 1, plannedDurationSeconds: 3600).modulatesPlan)
        XCTAssertTrue(evaluate(cap: 5, fatigue: .saturation, plannedDurationSeconds: 3600).modulatesPlan)
        XCTAssertFalse(evaluate(cap: 10, plannedDurationSeconds: 3600).modulatesPlan)
    }

    func test_durationIsAlwaysAWholeNumberOfMinutes() {
        for planned in [37 * 60 + 41, 53 * 60 + 7, 91 * 60 + 59] {
            let cap = evaluate(cap: 7, fatigue: .elevated, plannedDurationSeconds: planned)
            let seconds = cap.maxDurationSeconds ?? 0
            XCTAssertEqual(seconds % 60, 0, "a cap must land on a whole minute")
            XCTAssertLessThanOrEqual(seconds, planned)
        }
    }

    /// Regression: 5400 × 0.70 is 3779.999999999999 in `Double`, so a bare truncation to whole
    /// minutes handed back 62 where the rule says 63 — a minute silently taken off the athlete's
    /// session by a binary-representation artefact, not by a decision.
    func test_exactPercentages_landOnTheirWholeMinute_notOneBelow() {
        let cases: [(planned: Int, factor: Double, expected: Int)] = [
            (90 * 60, 0.70, 63),
            (90 * 60, 0.80, 72),
            (90 * 60, 0.60, 54),
            (90 * 60, 0.50, 45),
            (60 * 60, 0.70, 42),
            (50 * 60, 0.70, 35)
        ]
        for row in cases {
            let cap: SessionCapEngine.SessionCap
            switch row.factor {
            case 0.70: cap = evaluate(cap: 6, strain: .high, plannedDurationSeconds: row.planned)
            case 0.80: cap = evaluate(cap: 7, fatigue: .elevated, plannedDurationSeconds: row.planned)
            case 0.60: cap = evaluate(cap: 6, fatigue: .high, plannedDurationSeconds: row.planned)
            default:   cap = evaluate(cap: 9, matchDaysAway: 1, plannedDurationSeconds: row.planned)
            }
            XCTAssertEqual(
                minutes(cap), row.expected,
                "\(row.planned / 60) min × \(row.factor) must be \(row.expected) min"
            )
        }
    }

    func test_proximityPredicate_matchesTheVerdictEngines() {
        for days in 0...2 {
            XCTAssertTrue(SessionCapEngine.isMatchNear(daysAway: days))
            XCTAssertEqual(
                SessionCapEngine.isMatchNear(daysAway: days),
                TodayVerdictEngine.isMatchNear(daysAway: days),
                "two proximity rules would be two answers to one question"
            )
        }
        XCTAssertFalse(SessionCapEngine.isMatchNear(daysAway: 3))
        XCTAssertFalse(SessionCapEngine.isMatchNear(daysAway: nil))
        XCTAssertFalse(SessionCapEngine.isMatchNear(daysAway: -1))
    }

    // MARK: - 6. The engine speaks no copy

    /// The engine emits numbers; the surfaces say the sentence. A user-facing string here would
    /// mean two places author the same claim — the separation `TodayVerdictEngine` /
    /// `VerdictReasonBuilder` already keeps.
    func test_engineSourceContainsNoUserFacingCopy() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("WorkloadApp/Services/SessionCapEngine.swift"),
            encoding: .utf8
        )
        XCTAssertFalse(source.contains("String(localized:"))
        XCTAssertFalse(source.contains("LocalizedStringKey"))
        // The claim rails, at the source: the engine never frames a cap as a harm claim.
        for fragment in ["injur", "predict", "forecast"] {
            XCTAssertFalse(
                source.lowercased().contains(fragment),
                "SessionCapEngine.swift contains the forbidden claim fragment '\(fragment)'"
            )
        }
    }
}
