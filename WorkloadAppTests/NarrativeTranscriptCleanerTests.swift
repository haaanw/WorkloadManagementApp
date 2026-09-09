import XCTest
@testable import workload_management

/// R1 (dogfood 2026-09-01): the narrative transcript cleanup pass, plus the B1 program-text
/// preprocessing. Both are pure functions; conservatism is the property under test — a wrongly
/// removed word corrupts a workout record, so every "keeps" test is as load-bearing as every
/// "drops" test.
final class NarrativeTranscriptCleanerTests: XCTestCase {

    // MARK: - Filler removal

    func test_dropsStandaloneFillerTokens() {
        XCTAssertEqual(
            NarrativeTranscriptCleaner.clean("uh bench press um three sets of eight er at eighty kilos"),
            "bench press three sets of eight at eighty kilos"
        )
    }

    func test_dropsChineseFillerTokens() {
        XCTAssertEqual(
            NarrativeTranscriptCleaner.clean("呃 卧推 三组 嗯 每组八次"),
            "卧推 三组 每组八次"
        )
    }

    func test_keepsLike_becauseItCarriesContent() {
        XCTAssertEqual(
            NarrativeTranscriptCleaner.clean("felt like ninety percent effort"),
            "felt like ninety percent effort"
        )
    }

    func test_fillerInsideWordIsKept() {
        // "erg" contains "er"; "summer" contains "um" — token match only, never substring.
        XCTAssertEqual(
            NarrativeTranscriptCleaner.clean("erg rowing all summer"),
            "erg rowing all summer"
        )
    }

    // MARK: - Stutter collapse

    func test_collapsesExactAdjacentDuplicateWords() {
        XCTAssertEqual(
            NarrativeTranscriptCleaner.clean("bench bench press three sets"),
            "bench press three sets"
        )
    }

    func test_duplicateWithDifferentCaseCollapses() {
        XCTAssertEqual(
            NarrativeTranscriptCleaner.clean("Bench bench press"),
            "bench press"
        )
    }

    func test_neverCollapsesNumericTokens() {
        XCTAssertEqual(
            NarrativeTranscriptCleaner.clean("did 8 8 reps"),
            "did 8 8 reps"
        )
    }

    func test_neverCollapsesNumberWords() {
        XCTAssertEqual(
            NarrativeTranscriptCleaner.clean("eight eight reps at eighty eighty"),
            "eight eight reps at eighty eighty"
        )
    }

    func test_nonAdjacentRepeatsAreKept() {
        XCTAssertEqual(
            NarrativeTranscriptCleaner.clean("squats then bench then squats again"),
            "squats then bench then squats again"
        )
    }

    func test_stutterKeepsTrailingPunctuationOfLaterToken() {
        XCTAssertEqual(
            NarrativeTranscriptCleaner.clean("squats squats. then bench"),
            "squats. then bench"
        )
    }

    // MARK: - Structure

    func test_collapsesBlankLineRuns() {
        XCTAssertEqual(
            NarrativeTranscriptCleaner.clean("bench press\n\n\n\nsquats"),
            "bench press\n\nsquats"
        )
    }

    func test_emptyAndFillerOnlyInputYieldsEmpty() {
        XCTAssertEqual(NarrativeTranscriptCleaner.clean(""), "")
        XCTAssertEqual(NarrativeTranscriptCleaner.clean("uh um er"), "")
    }

    func test_decimalsAndHyphensSurvive() {
        XCTAssertEqual(
            NarrativeTranscriptCleaner.clean("chin-ups at 82.5 kilos"),
            "chin-ups at 82.5 kilos"
        )
    }
}

/// B1: PDF page-furniture stripping. The parser's plan-mode cap was raised server-side; this
/// pass keeps real extractions under it without ever touching content lines.
final class ProgramTextPreprocessingTests: XCTestCase {

    func test_keepsBareNumberLines_tableCellsAreContent() {
        // PDF table extraction emits real cells ("140") as their own lines — never strip.
        let input = "Back squat\n5\n5\n140\nRDL"
        XCTAssertEqual(
            WorkoutLLMImportService.preprocessProgramText(input),
            input
        )
    }

    func test_dropsPageXOfYLines() {
        let input = "Week 1\nPage 3 of 6\np. 4\n- 5 -\n第 3 页，共 6 页\nBack squat 5x5"
        XCTAssertEqual(
            WorkoutLLMImportService.preprocessProgramText(input),
            "Week 1\nBack squat 5x5"
        )
    }

    func test_keepsSlashNotationLines() {
        // "3 / 8" can be reps or RPE notation — never treated as a page marker.
        let input = "3 / 8\n8/10 RPE"
        XCTAssertEqual(
            WorkoutLLMImportService.preprocessProgramText(input),
            input
        )
    }

    func test_keepsRepeatedContentLines() {
        // Programs legitimately repeat lines — no dedupe may ever fire.
        let input = "Rest 2 min\n3x8 @ 100\nRest 2 min\n3x8 @ 100"
        XCTAssertEqual(
            WorkoutLLMImportService.preprocessProgramText(input),
            input
        )
    }

    func test_keepsNumbersInsideContentLines() {
        let input = "Back squat 5 x 5 @ 140\nWeek 3 Day 2"
        XCTAssertEqual(
            WorkoutLLMImportService.preprocessProgramText(input),
            input
        )
    }

    func test_collapsesWhitespaceAndBlankRuns() {
        let input = "Back   squat\t5x5\n\n\n\n\nRDL 3x8"
        XCTAssertEqual(
            WorkoutLLMImportService.preprocessProgramText(input),
            "Back squat 5x5\n\nRDL 3x8"
        )
    }

    func test_largeSetsAndRepsLinesSurvive() {
        // "5x5" style lines must never match the page-number patterns.
        let input = "5x5\n10 x 3\n21s"
        XCTAssertEqual(
            WorkoutLLMImportService.preprocessProgramText(input),
            input
        )
    }
}

/// U11: several photos or PDFs of ONE program reach the parser as one document.
final class ProgramFileCombinationTests: XCTestCase {

    func test_singleFile_carriesNoMarker() {
        XCTAssertEqual(
            WorkoutLLMImportService.combineProgramFiles(["Week 1\nBack squat 5x5"]),
            "Week 1\nBack squat 5x5"
        )
    }

    func test_noFiles_isEmpty() {
        XCTAssertEqual(WorkoutLLMImportService.combineProgramFiles([]), "")
    }

    func test_marksEachFileWithItsPositionAndTheTotal() {
        XCTAssertEqual(
            WorkoutLLMImportService.combineProgramFiles(["W1", "W2", "W3"]),
            "— file 1 of 3 —\nW1\n\n— file 2 of 3 —\nW2\n\n— file 3 of 3 —\nW3"
        )
    }

    func test_preservesTheAthletesPickOrder() {
        // The order the athlete chose IS the program's order — never sorted, never reversed.
        let combined = WorkoutLLMImportService.combineProgramFiles(["Deload week", "Week 1"])
        let deload = combined.range(of: "Deload week")
        let week1 = combined.range(of: "Week 1")
        XCTAssertNotNil(deload)
        XCTAssertNotNil(week1)
        XCTAssertTrue(deload!.lowerBound < week1!.lowerBound)
    }

    func test_blankExtractionsAreDroppedAndTheTotalFollows() {
        XCTAssertEqual(
            WorkoutLLMImportService.combineProgramFiles(["W1", "   \n\n", "W2"]),
            "— file 1 of 2 —\nW1\n\n— file 2 of 2 —\nW2"
        )
    }

    func test_markersSurvivePreprocessing() {
        // The page-furniture pass strips "- 3 -"; a file marker carries words, so it must
        // reach the parser intact — losing it would merge two files into one week sequence.
        let combined = WorkoutLLMImportService.combineProgramFiles(["Week 1\n- 3 -", "Week 2"])
        let processed = WorkoutLLMImportService.preprocessProgramText(combined)
        XCTAssertTrue(processed.contains("— file 1 of 2 —"))
        XCTAssertTrue(processed.contains("— file 2 of 2 —"))
        XCTAssertFalse(processed.contains("- 3 -"), "page furniture should still be stripped")
    }

    func test_combinationIsUnderTheParserCapForOrdinaryBatches() {
        // Three dense PDF extractions still fit the 60k budget; the cap only fires on a
        // genuinely oversized batch, where the "a few weeks at a time" prompt takes over.
        let page = String(repeating: "Back squat 5x5 @ 140\n", count: 500)
        let combined = WorkoutLLMImportService.combineProgramFiles([page, page, page])
        XCTAssertLessThanOrEqual(WorkoutLLMImportService.preprocessProgramText(combined).count, 60_000)
    }
}
