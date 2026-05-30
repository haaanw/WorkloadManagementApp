import XCTest
@testable import workload_management

/// **Tier-fence guard (Phase 26, HIGH-risk invariant T-26-06).**
///
/// These are SOURCE-LEVEL grep-gate tests. They read the actual `.swift` source files off disk
/// and assert, in machine-enforced form (not prose), that:
///
///  1. `RecoveryScoreEngine.computeBaseline` still exists with its trailing 7-day-mean body
///     (`.suffix(7)`) — the flat 7-day mean remains the LIVE recovery baseline source.
///  2. The live recovery path (`RecoveryPipeline`) references NONE of the new substrate types
///     (`BaselineEngine` / `DayBucketer` / `BaselineState`) — the substrate is parallel/gated OFF
///     this phase (D-01, substrate-only).
///  3. `BaselineEngine` references neither `RecoveryScoreEngine` nor `RecoveryPipeline` as a
///     real code symbol — the engine is standalone (re-asserts Plan-02's fence consumer-side).
///
/// This test must genuinely FAIL if someone later wires the substrate into the live output path.
///
/// ### Comment-stripping
/// The substrate type names legitimately appear inside DOC COMMENTS in `BaselineEngine.swift`
/// (and may appear in comments elsewhere) precisely to describe this fence. A naive
/// `contains(...)` over raw source would therefore false-fail on prose. So the "must NOT
/// contain" assertions run against a **comment-stripped** copy of the source — they fire only on
/// real code references, which is exactly the regression we want to catch.
final class BaselineTierFenceTests: XCTestCase {

    // MARK: - Source-path resolution

    /// Repo root, resolved at runtime by walking up from this test file's `#filePath`
    /// (`<repo>/WorkloadAppTests/BaselineTierFenceTests.swift` → two parents up).
    private func repoRoot(file: StaticString = #filePath) -> URL {
        URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent()   // WorkloadAppTests/
            .deletingLastPathComponent()   // <repo root>
    }

    /// Read a source file relative to the repo root, failing loudly (never silently passing)
    /// if the path cannot be resolved.
    private func readSource(_ relativePath: String) -> String {
        let url = repoRoot().appendingPathComponent(relativePath)
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("TIER-FENCE could not resolve source at \(url.path) — fence cannot be verified")
            return ""
        }
        return contents
    }

    /// Strip `//` line comments and `/* ... */` block comments so "must NOT contain" assertions
    /// fire only on real code, not documentation prose that names the fenced types deliberately.
    private func strippingComments(_ source: String) -> String {
        var result = ""
        result.reserveCapacity(source.count)
        var inLineComment = false
        var inBlockComment = false
        let chars = Array(source)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            let next: Character? = (i + 1 < chars.count) ? chars[i + 1] : nil
            if inLineComment {
                if c == "\n" { inLineComment = false; result.append(c) }
            } else if inBlockComment {
                if c == "*" && next == "/" { inBlockComment = false; i += 1 }
            } else if c == "/" && next == "/" {
                inLineComment = true; i += 1
            } else if c == "/" && next == "*" {
                inBlockComment = true; i += 1
            } else {
                result.append(c)
            }
            i += 1
        }
        return result
    }

    // MARK: - 1. Live 7-day-mean baseline is unchanged

    func testLiveBaselineStillExists() {
        let src = readSource("WorkloadApp/Services/RecoveryScoreEngine.swift")
        XCTAssertFalse(src.isEmpty, "RecoveryScoreEngine.swift must be readable for the fence to hold")
        XCTAssertTrue(
            src.contains("static func computeBaseline(values: [Double]) -> Double?"),
            "Live baseline signature must remain — RecoveryScoreEngine.computeBaseline(values:) is the LIVE source"
        )
        XCTAssertTrue(
            src.contains(".suffix(7)"),
            "computeBaseline must still compute the trailing 7-day-mean (.suffix(7)) — live baseline unchanged"
        )
    }

    // MARK: - 2. Substrate is NOT wired into the live recovery path

    func testSubstrateNotWiredLive() {
        let code = strippingComments(readSource("WorkloadApp/Services/RecoveryPipeline.swift"))
        XCTAssertFalse(code.isEmpty, "RecoveryPipeline.swift must be readable for the fence to hold")
        for substrate in ["BaselineEngine", "DayBucketer", "BaselineState"] {
            XCTAssertFalse(
                code.contains(substrate),
                "TIER-FENCE BREACH: RecoveryPipeline (live recovery path) now references \(substrate) — the substrate must stay gated OFF this phase"
            )
        }
    }

    // MARK: - 3. Engine is standalone (no live-path symbol references)

    func testEngineDoesNotImportLivePath() {
        let code = strippingComments(readSource("WorkloadApp/Services/BaselineEngine.swift"))
        XCTAssertFalse(code.isEmpty, "BaselineEngine.swift must be readable for the fence to hold")
        for livePath in ["RecoveryScoreEngine", "RecoveryPipeline"] {
            XCTAssertFalse(
                code.contains(livePath),
                "TIER-FENCE BREACH: BaselineEngine now references \(livePath) as code — the engine must stay standalone/parallel"
            )
        }
    }
}
