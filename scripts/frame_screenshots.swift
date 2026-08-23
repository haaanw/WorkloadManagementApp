#!/usr/bin/env swift
//
// frame_screenshots.swift
// Marketing frame generator for App Store screenshots — DESIGN.md v6.2 "Field Notes".
//
// ── THE ONE COMMAND ────────────────────────────────────────────────────────────
//
//   swift scripts/frame_screenshots.swift --all
//
// Run from the repo root (required — the script reads design-system/tokens/colors.css,
// design-system/tokens/spacing.css and the screenshot harness at run time). It walks the
// job table in `frameJobs` below, frames every raw capture it finds, and REPLACES each
// framed set wholesale. Missing input dirs are skipped with a message, so it is safe to
// re-run at any time — which is the point: whenever a lane changes a captured surface,
// re-capture into the `raw/` dirs and re-run this one command.
//
// Ad-hoc / preview form (does not touch the canonical sets):
//
//   swift scripts/frame_screenshots.swift <input_dir> <output_dir> [en|zh-Hans]
//
// ── OUTPUT IS REPLACED, NEVER MERGED ───────────────────────────────────────────
//
// Round-2 review finding (BLOCKER): plates are named `NN_Screen_framed.png` where NN is
// the index within the CURRENT run, and nothing purged the output dir. Framing nine
// screens and then re-running with three left twelve files — `01_Dashboard_framed.png`
// beside a stale `03_Dashboard_framed.png`, a plate reading `/09` beside one reading
// `/03` — and still printed `0 error(s)` and exited 0. That fires the first time a lane
// changes how many surfaces are captured, which is the whole reason this pipeline exists.
//
// Every job renders into a sibling staging dir and publishes with a single filesystem
// `replaceItemAt`, so the swap is atomic:
//   * on a clean run the staged dir replaces the output dir wholesale, so the published set
//     is exactly this run's plates and nothing else (non-plate files are carried across);
//   * on ANY error nothing is published — the previous good set is left untouched and the
//     run exits non-zero. A half-written store set is not a reachable state.
//   * `--all` also exits non-zero when it publishes NOTHING, so a green exit code always
//     means store artwork was actually produced.
//
// ── WHAT IT REFUSES TO DO SILENTLY ─────────────────────────────────────────────
//
// Round-1 review finding: the old `detectScreenName` matched none of six of the twelve
// attachments the XCUITest harness saves, so half the harness output vanished with a
// one-line "not a recognized screen" and nobody noticed. Now:
//
//   * every capture is classified as FRAMED, EXCLUDED (with a stated reason), or
//     UNRECOGNIZED;
//   * each job prints an explicit `Summary [lang]:` line naming every excluded and
//     unrecognized file;
//   * ANY unrecognized capture, or a store screen missing copy, exits NON-ZERO;
//   * two captures resolving to the SAME screen is an error — it used to produce two
//     identical plates at exit 0;
//   * `verifyScreenSpecs()` proves store ranks are unique and every store screen has copy
//     in every job language;
//   * `verifyHarnessCoverage()` runs the drift guard in BOTH directions: every
//     `saveScreenshot("…")` in ScreenshotTests.swift must be classifiable here, AND every
//     `.store(rank:)` screen must be backed by a harness attachment. Screens that are
//     specced but have no capture yet are declared `.plannedNotCaptured` — they cannot
//     hide in the store set. A harness file this script cannot READ is a hard failure,
//     not a skipped check: the guard fails CLOSED.
//   * a missing bundled font, or a font whose PostScript name does not resolve, is a hard
//     failure at startup. Store artwork must never render in a fallback face.
//
// ── LAYOUT (Field Notes v6; reference canvas 440x956pt, captures are @3x) ──────
//
//   ┌───────────────────────────────────────────┐
//   │  ┌─────────────────────────────────────┐  │  annotation strip — a card plane
//   │  │ ● READINESS              TUWA·01/09 │  │  (surface-el + hairline + r12),
//   │  └─────────────────────────────────────┘  │  Fragment Mono 12pt uppercase,
//   │                                           │  metric hue on the left key
//   │  Know today's readiness                   │  Instrument Sans Medium 32pt, ink
//   │  Recovery and load in one daily read.     │  Instrument Sans Regular 17pt, text-2
//   │  INPUTS: HRV · RHR · SLEEP                │  Fragment Mono 12pt, text-2
//   │  ┌─────────────────────────────────────┐  │
//   │  │           device capture            │  │  hairline border, 12pt top corners,
//   │  │                                     │  │  1pt relief highlight, bleeds off
//
// The plate reads `TUWA · NN/TT` where **TT is the number of plates framed in this run**,
// not the size of the intended store set (see `PlateNumber`). A partial run therefore
// self-describes honestly: 3 captures produce 01/03 … 03/03.
//
// Law this file is written against (DESIGN.md v6.2):
//   - Two-Voice Type Law: Instrument Sans speaks (headline / subline); Fragment Mono
//     annotates only, ≤12pt, UPPERCASE + 0.05em tracking applied here (never at the
//     copy site) and suppressed for the zh-Hans JOB — gated on the job's language, the
//     way `Annotation` in CardStyle.swift gates on `\.locale`, NOT on whether a given
//     string happens to contain a CJK scalar (DESIGN.md:95).
//   - Metric hues (#2E7D4F / #1D7189 / #52589E / #A8442D / #8A6810) appear ONLY as the
//     metric-hue annotation key and its state dot. Never a plane fill, never decorative.
//     Sub-24pt hue text sits on a CARD plane (that is why the strip is a card).
//   - Travertine accent does NOT appear: it is live-state-marks-only, and a marketing
//     frame has no live state. (v5's decorative accent rule is deleted — it violated the
//     Reading Color Rule's "never decorative".)
//   - No shadows (relief only), corners 12/8/pill, 8pt grid, light-only, sentence case
//     in the working voice.
//   - CJK glyphs route to Noto Sans SC per-range, matching the app's cascade.
//

import AppKit
import CoreGraphics
import CoreText
import Foundation

// MARK: - Job table (the `--all` run)

struct FrameJob {
    let inputDir: String
    let outputDir: String
    let language: String
}

/// Canonical sets. Re-capture into the `raw/` dirs, then `--all` re-frames everything.
let frameJobs: [FrameJob] = [
    FrameJob(inputDir: "appstore screenshots/1.7-en/raw",
             outputDir: "appstore screenshots/1.7-en/framed",
             language: "en"),
    FrameJob(inputDir: "appstore screenshots/1.7-zh-Hans/raw",
             outputDir: "appstore screenshots/1.7-zh-Hans/framed",
             language: "zh-Hans")
]

/// App Store hard limit per device size. Exceeding it is a curation decision, not a bug,
/// so the run warns rather than fails.
let appStoreMaxScreenshots = 10

// MARK: - Repo-root paths read at run time (drift guards, not transcriptions)

let colorTokensPath = "design-system/tokens/colors.css"
let spacingTokensPath = "design-system/tokens/spacing.css"
let harnessPath = "workload management/ScreenshotTests/ScreenshotTests.swift"

/// The five bundled faces, and the PostScript name each must resolve to once registered.
/// A miss on either half is a hard failure at startup — see `registerBundledFonts()`.
let requiredFonts: [(path: String, postScriptName: String)] = [
    ("WorkloadApp/Resources/Fonts/InstrumentSans-Regular.ttf", "InstrumentSans-Regular"),
    ("WorkloadApp/Resources/Fonts/InstrumentSans-Medium.ttf",  "InstrumentSans-Medium"),
    ("WorkloadApp/Resources/Fonts/FragmentMono-Regular.ttf",   "FragmentMono-Regular"),
    ("WorkloadApp/Resources/Fonts/NotoSansSC-Regular.otf",     "NotoSansSC-Regular"),
    ("WorkloadApp/Resources/Fonts/NotoSansSC-Medium.otf",      "NotoSansSC-Medium")
]

// MARK: - Metric identities (DESIGN.md v6 — each metric owns a hue)

enum Metric: String {
    case readiness
    case recovery
    case sleep
    case strain
    case load

    /// The annotation key, Latin and locale-independent — annotation is machine output.
    var key: String { rawValue }

    /// The `--metric-*` custom property this metric owns in design-system/tokens/colors.css.
    var tokenName: String { "metric-\(rawValue)" }
}

// MARK: - Copy

struct FrameCopy {
    /// Working voice — sentence case, Instrument Sans.
    let headline: String
    /// Working voice — sentence case, Instrument Sans.
    let subline: String
}

/// Whether a recognized screen belongs in the shipped store set, and if not, why not.
/// Every screen the harness can produce MUST appear in `screenSpecs` with one of these —
/// "unrecognized" is now an error, not a shrug.
enum Inclusion {
    /// In the store set. `rank` is the App Store upload order (also the plate order).
    /// Every `.store` screen MUST be backed by a harness attachment — `verifyHarnessCoverage()`
    /// checks that direction too, so a store screen cannot quietly be un-shootable.
    case store(rank: Int)
    /// Specced, with copy, but NO harness attachment produces it yet. It is not in the store
    /// set and never appears in a run; if a capture for it ever shows up, that is an error
    /// telling you to promote it to `.store(rank:)` — a one-word edit.
    case plannedNotCaptured(note: String)
    /// Deliberately not shipped. The reason is printed in every run summary and in
    /// `appstore screenshots/README.md`.
    case excluded(reason: String)

    var storeRank: Int? {
        if case .store(let rank) = self { return rank }
        return nil
    }

    var exclusionReason: String? {
        if case .excluded(let reason) = self { return reason }
        return nil
    }

    var plannedNote: String? {
        if case .plannedNotCaptured(let note) = self { return note }
        return nil
    }
}

/// The per-screen identity that does not change with locale: which metric owns the
/// screen, the machine-flavored annotation key that describes its mechanism, and whether
/// it ships. Annotation never asserts a reading the capture does not show — it names the
/// input. (`metric` / `machineKey` are unused for `.excluded` screens; they are kept so
/// promoting a screen into the store set is a one-word edit.)
struct ScreenSpec {
    let metric: Metric
    let machineKey: String
    let inclusion: Inclusion
}

let screenSpecs: [String: ScreenSpec] = [
    // ── Shipped store set ────────────────────────────────────────────────────────
    "VerdictMicrodose": ScreenSpec(metric: .readiness, machineKey: "match_proximity: aware",
                                   inclusion: .store(rank: 1)),
    "LogCapture":       ScreenSpec(metric: .strain,    machineKey: "input: voice · text · dictation",
                                   inclusion: .store(rank: 2)),
    "Dashboard":        ScreenSpec(metric: .readiness, machineKey: "inputs: hrv · rhr · sleep",
                                   inclusion: .store(rank: 3)),
    "Recovery":         ScreenSpec(metric: .recovery,  machineKey: "baseline: 28d rolling",
                                   inclusion: .store(rank: 4)),
    "SleepDetail":      ScreenSpec(metric: .sleep,     machineKey: "sleep_target: 7.5 h",
                                   inclusion: .store(rank: 5)),
    "Workload":         ScreenSpec(metric: .load,      machineKey: "acwr: acute 7d / chronic 28d",
                                   inclusion: .store(rank: 6)),
    "ActiveWorkout":    ScreenSpec(metric: .strain,    machineKey: "logged: sets · reps · load",
                                   inclusion: .store(rank: 7)),
    "TemplatePicker":   ScreenSpec(metric: .load,      machineKey: "templates: user-authored",
                                   inclusion: .store(rank: 8)),
    "MovementBank":     ScreenSpec(metric: .strain,    machineKey: "catalog: 1,324 movements",
                                   inclusion: .store(rank: 9)),

    // ── Dropped from the store set 2026-08-22 (ASO pass, Objective 3) ────────────
    //    Both were captures of the SAME surface as plate 1. `test07` used to save the verdict
    //    card twice in a row with no state change between the two saves, and `test03` shoots
    //    the identical scroll position of the Workout log — so three of nine plates were one
    //    screen wearing three captions. The strike-zone bar and the verdict live inside plate
    //    1; plate 1's caption is what names them. Their attachments are kept (they are useful
    //    navigation smoke) but they no longer occupy store slots.
    "StrikeZone":       ScreenSpec(metric: .load,      machineKey: "strike_zone: plan ± readiness",
                                   inclusion: .excluded(reason: "duplicate of VerdictMicrodose — the strike-zone bar is inside plate 1")),
    "WorkoutLog":       ScreenSpec(metric: .readiness, machineKey: "verdict: plan × readiness",
                                   inclusion: .excluded(reason: "duplicate of VerdictMicrodose — same surface, same scroll position")),

    // ── v2.1 beachhead screens: specced, NEVER YET CAPTURED. Round-2 review finding:
    //    these used to claim `.store(rank: 10…13)` while no harness attachment produces
    //    them — a store set that could never be shot. `.plannedNotCaptured` states that
    //    honestly and keeps them out of the reverse coverage check's store column.
    "NextMatch":        ScreenSpec(metric: .load,      machineKey: "schedule: match date set",
                                   inclusion: .plannedNotCaptured(note: "v2.1 beachhead — no harness attachment yet")),
    "MatchTier":        ScreenSpec(metric: .strain,    machineKey: "match_tier: pickup · scrimmage · match",
                                   inclusion: .plannedNotCaptured(note: "v2.1 beachhead — no harness attachment yet")),
    "ReadinessSignals": ScreenSpec(metric: .recovery,  machineKey: "signals: hrv · rhr · sleep",
                                   inclusion: .plannedNotCaptured(note: "v2.1 beachhead — no harness attachment yet")),
    "PlanInput":        ScreenSpec(metric: .readiness, machineKey: "plan: user-authored",
                                   inclusion: .plannedNotCaptured(note: "v2.1 beachhead — no harness attachment yet")),

    // ── Harness output that is deliberately NOT shipped ──────────────────────────
    "Profile":          ScreenSpec(metric: .readiness, machineKey: "account: settings",
                                   inclusion: .excluded(reason: "settings surface — no marketing value")),
    "SessionStart":     ScreenSpec(metric: .load,      machineKey: "session: start",
                                   inclusion: .excluded(reason: "same surface as TemplatePicker (test08 vs test12)")),
    "ExercisePicker":   ScreenSpec(metric: .strain,    machineKey: "search: movement bank",
                                   inclusion: .excluded(reason: "mid-flow search UI — unreadable at store thumbnail size")),

    // ── Retired surfaces still present in the historical 1.4 sets ────────────────
    "CoachRoster":      ScreenSpec(metric: .load,      machineKey: "coach: roster",
                                   inclusion: .excluded(reason: "retired — coach mode dropped in v1.6")),
    "PDFExport":        ScreenSpec(metric: .load,      machineKey: "export: pdf",
                                   inclusion: .excluded(reason: "retired — not produced by the v1.7 harness"))
]

let copyByLanguage: [String: [String: FrameCopy]] = [
    "en": [
        "VerdictMicrodose": FrameCopy(
            headline: "Microdose before match day",
            subline: "Cap the top set. Skip back-offs."
        ),
        "StrikeZone": FrameCopy(
            headline: "Stay in your strike zone",
            subline: "Today's number lands inside the band."
        ),
        "LogCapture": FrameCopy(
            headline: "Say the session. Keep the sets.",
            subline: "Speak it or type it — Tuwa writes the log."
        ),
        // "a 7.5-hour line", not "your own target": the shipping engine scores sleep against a
        // FIXED target. The adaptive one is designed and unbuilt (§10 claim rails). The window
        // is the screen's own default — 28 nights — so the subline says four weeks, not twelve.
        "SleepDetail": FrameCopy(
            headline: "Every night, against the target",
            subline: "Four weeks of nights on a 7.5-hour line."
        ),
        "NextMatch": FrameCopy(
            headline: "Match timing matters",
            subline: "Set the date. Tuwa tightens nearby lifts."
        ),
        "MatchTier": FrameCopy(
            headline: "Games hit legs",
            subline: "Log pickup, scrimmage, or match context."
        ),
        "ReadinessSignals": FrameCopy(
            headline: "Readiness from real signals",
            subline: "HRV, RHR, and sleep shape today."
        ),
        "PlanInput": FrameCopy(
            headline: "Your plan stays yours",
            subline: "Accept the trim, or keep the plan."
        ),
        "Dashboard": FrameCopy(
            headline: "Know today's readiness",
            subline: "Recovery and load in one daily read."
        ),
        "Recovery": FrameCopy(
            headline: "Recovery, decoded",
            subline: "See the signals behind today's state."
        ),
        "Workload": FrameCopy(
            headline: "Track training load",
            subline: "Watch acute and chronic load move."
        ),
        "WorkoutLog": FrameCopy(
            headline: "Today's call, then the log",
            subline: "The verdict first, your history under it."
        ),
        "ActiveWorkout": FrameCopy(
            headline: "Log every rep",
            subline: "Capture strength work without friction."
        ),
        "TemplatePicker": FrameCopy(
            headline: "Start from your own template",
            subline: "Your plan, ready to log."
        ),
        "MovementBank": FrameCopy(
            headline: "Search the movement bank",
            subline: "Find the lift, or add your own."
        )
    ],
    "zh-Hans": [
        "VerdictMicrodose": FrameCopy(
            headline: "比赛前，先做微量训练来找到状态",
            subline: "封顶最重组，跳过减重组。"
        ),
        "StrikeZone": FrameCopy(
            headline: "留在今日区间",
            subline: "今天的数字落在合适范围内。"
        ),
        "LogCapture": FrameCopy(
            headline: "说一句，训练就记好了",
            subline: "开口说或直接打字，Tuwa 帮你填好每一组。"
        ),
        "SleepDetail": FrameCopy(
            headline: "每一晚，都对照目标",
            subline: "四周的每一晚，画在 7.5 小时这条线上。"
        ),
        "NextMatch": FrameCopy(
            headline: "比赛时间很重要",
            subline: "设好日期，临近自动收紧训练。"
        ),
        "MatchTier": FrameCopy(
            headline: "比赛会打到腿",
            subline: "记录野球、对抗或正式比赛。"
        ),
        "ReadinessSignals": FrameCopy(
            headline: "真实信号，读出准备度",
            subline: "HRV、静息心率与睡眠决定今天。"
        ),
        "PlanInput": FrameCopy(
            headline: "计划仍然属于你",
            subline: "接受微调，或坚持原计划。"
        ),
        "Dashboard": FrameCopy(
            headline: "了解今天的准备度",
            subline: "恢复与负荷，一眼读懂。"
        ),
        "Recovery": FrameCopy(
            headline: "恢复，看得懂",
            subline: "看清今天状态背后的信号。"
        ),
        "Workload": FrameCopy(
            headline: "追踪训练负荷",
            subline: "急性与慢性负荷尽在掌握。"
        ),
        "WorkoutLog": FrameCopy(
            headline: "先给结论，再看记录",
            subline: "今日建议在上，历史训练在下。"
        ),
        "ActiveWorkout": FrameCopy(
            headline: "每一组都记下",
            subline: "顺手记录力量训练。"
        ),
        "TemplatePicker": FrameCopy(
            headline: "用你自己的模板开始",
            subline: "你的计划，随时开练。"
        ),
        "MovementBank": FrameCopy(
            headline: "搜索动作库",
            subline: "找到动作，或自己添加。"
        )
    ]
]

// MARK: - Design tokens — PARSED from design-system/tokens/colors.css

// Round-1 review finding: these eleven values used to be hand-transcribed here, and the
// design-fence test only scans `WorkloadApp/`, so a token edit in the design system would
// have drifted silently. They are now read out of the canonical CSS at run time; a missing
// file or a missing custom property is a hard failure.

func hex(_ value: UInt32) -> NSColor {
    NSColor(
        red: CGFloat((value >> 16) & 0xFF) / 255.0,
        green: CGFloat((value >> 8) & 0xFF) / 255.0,
        blue: CGFloat(value & 0xFF) / 255.0,
        alpha: 1.0
    )
}

func loadColorTokens(path: String) -> [String: NSColor] {
    guard let source = try? String(contentsOfFile: path, encoding: .utf8) else {
        FileHandle.standardError.write(Data("""
        Error: cannot read '\(path)'.
        frame_screenshots.swift reads the canonical design tokens at run time and must be
        run from the repo root:  swift scripts/frame_screenshots.swift --all

        """.utf8))
        exit(1)
    }
    // `--name:#RRGGBB;` — the only form colors.css uses for literal colors.
    let pattern = "--([a-z0-9-]+)\\s*:\\s*#([0-9A-Fa-f]{6})\\s*;"
    guard let regex = try? NSRegularExpression(pattern: pattern) else { exit(1) }
    var tokens: [String: NSColor] = [:]
    let full = NSRange(source.startIndex..., in: source)
    for match in regex.matches(in: source, range: full) {
        guard let nameRange = Range(match.range(at: 1), in: source),
              let hexRange = Range(match.range(at: 2), in: source),
              let value = UInt32(source[hexRange], radix: 16) else { continue }
        tokens[String(source[nameRange])] = hex(value)
    }
    return tokens
}

let colorTokens = loadColorTokens(path: colorTokensPath)

/// Every color in this file comes through here. An unknown token is a hard failure —
/// a renamed design token must break the pipeline, not silently change the frames.
func token(_ name: String) -> NSColor {
    guard let color = colorTokens[name] else {
        FileHandle.standardError.write(Data(
            "Error: color token '--\(name)' not found in \(colorTokensPath).\n".utf8))
        exit(1)
    }
    return color
}

// MARK: - Spacing & radii — PARSED from design-system/tokens/spacing.css

// Round-2 review finding: Round-1's token-drift fix was colour-only. Spacing, corner radii
// and the hairline width are canonicalised in `spacing.css` too and were still hand-typed
// here, so an 8pt-grid or Corner-Law edit in the design system would drift silently in
// exactly the way the colours no longer can.

func loadNumericTokens(path: String) -> [String: CGFloat] {
    guard let source = try? String(contentsOfFile: path, encoding: .utf8) else {
        FileHandle.standardError.write(Data("""
        Error: cannot read '\(path)'.
        frame_screenshots.swift reads the canonical design tokens at run time and must be
        run from the repo root:  swift scripts/frame_screenshots.swift --all

        """.utf8))
        exit(1)
    }
    // `--name:12px;` — the form spacing.css uses for every length.
    let pattern = "--([a-z0-9-]+)\\s*:\\s*([0-9]*\\.?[0-9]+)px\\s*;"
    guard let regex = try? NSRegularExpression(pattern: pattern) else { exit(1) }
    var tokens: [String: CGFloat] = [:]
    let full = NSRange(source.startIndex..., in: source)
    for match in regex.matches(in: source, range: full) {
        guard let nameRange = Range(match.range(at: 1), in: source),
              let valueRange = Range(match.range(at: 2), in: source),
              let value = Double(source[valueRange]) else { continue }
        tokens[String(source[nameRange])] = CGFloat(value)
    }
    return tokens
}

let spacingTokens = loadNumericTokens(path: spacingTokensPath)

/// Every point value in the layout comes through here. A renamed token must break the
/// pipeline, not silently resize the frames.
func metric(_ name: String) -> CGFloat {
    guard let value = spacingTokens[name] else {
        FileHandle.standardError.write(Data(
            "Error: token '--\(name)' not found in \(spacingTokensPath).\n".utf8))
        exit(1)
    }
    return value
}

let spaceXS      = metric("space-xs")       // 8
let spaceSM      = metric("space-sm")       // 16
let spaceMD      = metric("space-md")       // 24
let spaceLG      = metric("space-lg")       // 32
let space2XL     = metric("space-2xl")      // 64
let radiusCard   = metric("radius-card")    // 12 — CornerTokens.card
let hairlineUnit = metric("hairline")       // 0.5

let bgColor            = token("bg")              // stone base plane
let surfaceElColor     = token("surface-el")      // card plane
let surfaceEl2Color    = token("surface-el-2")    // raised top
let dividerColor       = token("divider")
let dividerStrongColor = token("divider-strong")
let textColor          = token("text-1")
let text2Color         = token("text-2")

/// Metric hues — the ONLY colors v6 adds. Annotation keys + state dots only here.
/// Total over `Metric`, so there is no fallback branch to go stale (a missing token
/// fails inside `token(_:)` instead).
func metricColor(_ metric: Metric) -> NSColor {
    token(metric.tokenName)
}

// MARK: - Fonts

/// Round-2 review finding (MAJOR): a missing bundled font used to `print("Warning: …")`
/// and return, and `loadFont` then fell through a named fallback to `NSFont.systemFont` /
/// `NSFont.monospacedSystemFont` — routes DESIGN.md:302 bans outright. A complete App Store
/// plate rendered in HelveticaNeue + Menlo, reported `0 error(s)`, exit 0. Store artwork
/// must never render in a fallback face, so both halves are hard failures now, and both
/// are checked BEFORE any job runs so nothing is half-written when it fires.
func registerBundledFonts() {
    var problems: [String] = []
    for entry in requiredFonts {
        let url = URL(fileURLWithPath: entry.path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            problems.append("missing file: \(entry.path)")
            continue
        }
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
            let detail = error?.takeRetainedValue().localizedDescription ?? "unknown CoreText error"
            problems.append("could not register \(entry.path) — \(detail)")
            continue
        }
        if NSFont(name: entry.postScriptName, size: 12) == nil {
            problems.append("registered \(entry.path) but PostScript name '\(entry.postScriptName)' does not resolve")
        }
    }
    guard problems.isEmpty else {
        FileHandle.standardError.write(Data("""
        Error: the bundled marketing faces did not load. Nothing was framed.
          \(problems.joined(separator: "\n  "))
        DESIGN.md's Two-Voice Type Law admits no fallback face in shipped artwork —
        this is a hard failure, not a warning. Run from the repo root and check
        WorkloadApp/Resources/Fonts/.

        """.utf8))
        exit(1)
    }
}

/// The only route to a face. `registerBundledFonts()` has already proved every required
/// PostScript name resolves, so this cannot legitimately miss — if it does, fail rather
/// than substitute a system face.
func loadFont(_ postScriptName: String, size: CGFloat) -> NSFont {
    guard let font = NSFont(name: postScriptName, size: size) else {
        FileHandle.standardError.write(Data(
            "Error: font '\(postScriptName)' did not resolve at size \(size).\n".utf8))
        exit(1)
    }
    return font
}

/// True for glyphs the Latin face lacks — CJK ideographs, kana, fullwidth forms and
/// CJK punctuation. Mirrors the app's Instrument Sans → Noto Sans SC cascade.
func isCJK(_ scalar: Unicode.Scalar) -> Bool {
    switch scalar.value {
    case 0x2E80...0x303F,   // CJK radicals, punctuation
         0x3040...0x30FF,   // kana
         0x3400...0x4DBF,   // CJK ext A
         0x4E00...0x9FFF,   // CJK unified
         0xF900...0xFAFF,   // compatibility ideographs
         0xFE30...0xFE4F,   // vertical forms
         0xFF00...0xFFEF:   // fullwidth forms
        return true
    default:
        return false
    }
}

func containsCJK(_ text: String) -> Bool {
    text.unicodeScalars.contains(where: isCJK)
}

/// Whether a font actually carries a glyph for a scalar. Fragment Mono covers
/// `● ○ · ▲ ▼` but NOT the box-drawing / block set (`├ └ ─ ░ ▒ ▁ █`) — without this
/// check those would silently fall back to a system face and break the voice.
func hasGlyph(_ font: NSFont, _ scalar: Unicode.Scalar) -> Bool {
    let ctFont = font as CTFont
    var utf16 = Array(String(scalar).utf16)
    var glyphs = [CGGlyph](repeating: 0, count: utf16.count)
    let ok = CTFontGetGlyphsForCharacters(ctFont, &utf16, &glyphs, utf16.count)
    return ok && !glyphs.contains(0)
}

/// Glyphs Fragment Mono could not render during the plate currently being framed.
/// Round-2 review finding: this used to fall back to `NSFont.monospacedSystemFont` and
/// print a warning, i.e. ship a plate in a banned face at exit 0. It is now collected and
/// turned into a per-plate framing ERROR by `frameScreenshot`, so the run fails and the
/// published set is left at its last good state.
var annotationGlyphMisses: [String] = []

// MARK: - Working voice (Instrument Sans, sentence case)

/// Attributed string with per-range fonts: Latin stays on Instrument Sans, CJK runs on
/// Noto Sans SC — the marketing frames speak with the app's exact voices.
func workingVoice(
    _ text: String,
    latinFont: NSFont,
    cjkFont: NSFont,
    color: NSColor,
    lineHeightMultiple: CGFloat
) -> NSAttributedString {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .left
    paragraph.lineHeightMultiple = lineHeightMultiple
    paragraph.lineBreakMode = .byWordWrapping

    let result = NSMutableAttributedString(
        string: text,
        attributes: [.font: latinFont, .foregroundColor: color, .paragraphStyle: paragraph]
    )
    var utf16Index = 0
    for scalar in text.unicodeScalars {
        let length = UTF16.width(scalar)
        if isCJK(scalar) {
            result.addAttribute(.font, value: cjkFont, range: NSRange(location: utf16Index, length: length))
        }
        utf16Index += length
    }
    return result
}

// MARK: - Annotation voice (Fragment Mono, ≤12pt, uppercase + tracking APPLIED HERE)

/// True when a job's language takes the annotation case transform and tracking.
///
/// Round-2 review finding (MAJOR): this used to be decided from the STRING's content
/// (`containsCJK(text)`), so on a zh-Hans plate the Latin annotation — `● READINESS`,
/// `TUWA · 04/04`, `VERDICT: PLAN × READINESS` — still came out uppercase and tracked.
/// DESIGN.md:95 and :308 say **zh-Hans** gets no case transform and no added tracking, and
/// the app decides it on LOCALE: `CardStyle.swift` `isLatin = locale.language.languageCode
/// != "zh"`, applied at `.tracking(...)` / `.textCase(...)`. The frames now gate the same
/// way — on the job's language, not on what a given string happens to contain.
func isLatinAnnotation(language: String) -> Bool {
    !language.lowercased().hasPrefix("zh")
}

/// The single route to Fragment Mono. It applies the case transform and the 0.05em
/// tracking itself — call sites pass natural-case copy and never decide either, exactly
/// as `Annotation` behaves in the app. `points` is the DESIGN.md ramp size (≤12); `scale`
/// converts it to device pixels. The per-scalar CJK → Noto Sans SC mapping below stays
/// content-driven: that is the font CASCADE, not the case/tracking law.
///
/// v6.2 ruling: ≤12pt is a SPECIFICATION cap (the size declared at the default content
/// size). Marketing frames have no Dynamic Type, so here it is also the rendered size.
func annotation(
    _ text: String,
    points: CGFloat,
    scale: CGFloat,
    color: NSColor,
    isLatin: Bool,
    alignment: NSTextAlignment = .left
) -> NSAttributedString {
    precondition(points <= 12.0, "Annotation voice is capped at 12pt (DESIGN.md v6 Two-Voice Type Law)")
    let size = points * scale

    // HAN's marketing-plate ruling (2026-07-31), narrowing the round-2 language gate: on a
    // zh-Hans plate, a PURE-LATIN annotation (machine keys, `● readiness`, `tuwa · 04/09`)
    // takes the uppercase transform and tracking after all — lowercase English beside
    // polished Chinese store copy reads as a typo, not as typography. Strings containing
    // any CJK still take no transform and no tracking (that law protects Chinese glyphs
    // and is unchanged — in the frames AND in the app, which keeps its locale gate).
    let takesTransform = isLatin || !containsCJK(text)
    let body = takesTransform ? text.uppercased() : text

    let mono = loadFont("FragmentMono-Regular", size: size)
    let cjkFont = loadFont("NotoSansSC-Regular", size: size)

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineBreakMode = .byClipping

    var attributes: [NSAttributedString.Key: Any] = [
        .font: mono,
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
    if takesTransform {
        attributes[.kern] = size * 0.05   // +0.05em tracking, the annotation law
    }

    let result = NSMutableAttributedString(string: body, attributes: attributes)

    // Per-scalar coverage: CJK → Noto (the app's cascade). Anything Fragment Mono lacks is
    // recorded as a framing error — never substituted with a system face.
    var utf16Index = 0
    for scalar in body.unicodeScalars {
        let length = UTF16.width(scalar)
        if isCJK(scalar) {
            result.addAttribute(.font, value: cjkFont, range: NSRange(location: utf16Index, length: length))
        } else if !hasGlyph(mono, scalar) {
            let note = "Fragment Mono has no glyph for U+\(String(scalar.value, radix: 16, uppercase: true)) '\(scalar)' in \"\(text)\""
            if !annotationGlyphMisses.contains(note) { annotationGlyphMisses.append(note) }
        }
        utf16Index += length
    }
    return result
}

// MARK: - Screen name detection

/// Filename-substring → screen token. Ordered: the first match wins, so more specific
/// patterns come first (`activeworkout` before `workout`). Every token here must exist in
/// `screenSpecs`; `verifyHarnessCoverage()` proves every name the XCUITest harness saves
/// hits one of these patterns.
let screenPatterns: [(patterns: [String], token: String)] = [
    (["verdictmicrodose", "v21_01"],                 "VerdictMicrodose"),
    (["logcapture", "log_capture", "voicelog"],      "LogCapture"),
    (["sleepdetail", "sleep_detail"],                "SleepDetail"),
    (["strikezone", "strike_zone", "v21_02"],        "StrikeZone"),
    (["nextmatch", "next_match", "v21_03"],          "NextMatch"),
    (["matchtier", "match_tier", "v21_04"],          "MatchTier"),
    (["readinesssignals", "readiness_signals", "v21_05"], "ReadinessSignals"),
    (["planinput", "plan_input", "v21_06"],          "PlanInput"),
    (["activeworkout", "active_workout"],            "ActiveWorkout"),
    (["workoutlog", "workout_log"],                  "WorkoutLog"),
    (["templatepicker", "template_picker"],          "TemplatePicker"),
    (["sessionstart", "session_start"],              "SessionStart"),
    (["exercisepicker", "exercise_picker"],          "ExercisePicker"),
    (["movementbank", "movement_bank"],              "MovementBank"),
    (["coachroster", "coach_roster"],                "CoachRoster"),
    (["pdfexport", "pdf_export"],                    "PDFExport"),
    (["dashboard", "home"],                          "Dashboard"),
    (["recovery"],                                   "Recovery"),
    (["workload", "acwr"],                           "Workload"),
    (["profile"],                                    "Profile")
]

func detectScreenName(from filename: String) -> String? {
    let lower = filename.lowercased()
    for entry in screenPatterns where entry.patterns.contains(where: { lower.contains($0) }) {
        return entry.token
    }
    return nil
}

// MARK: - Harness coverage guard

/// Table-level invariants, checked before anything is read from disk.
///
/// Round-2 review finding: nothing enforced `rank` uniqueness, so two screens could claim
/// the same App Store slot and the sort would silently break the tie on filename.
/// Returns false on any violation.
@discardableResult
func verifyScreenSpecs() -> Bool {
    var problems: [String] = []

    var ranks: [Int: [String]] = [:]
    for (screen, spec) in screenSpecs {
        guard let rank = spec.inclusion.storeRank else { continue }
        ranks[rank, default: []].append(screen)
    }
    for (rank, screens) in ranks.sorted(by: { $0.key < $1.key }) where screens.count > 1 {
        problems.append("store rank \(rank) is claimed by \(screens.sorted().joined(separator: ", "))")
    }

    // A store screen with no copy fails per-file today; proving it up front fails CLOSED
    // before a single plate is written.
    for language in frameJobs.map(\.language) {
        guard let copySet = copyByLanguage[language] else {
            problems.append("job language '\(language)' has no `copyByLanguage` entry")
            continue
        }
        for (screen, spec) in screenSpecs where spec.inclusion.storeRank != nil {
            if copySet[screen] == nil {
                problems.append("\(screen) is in the store set but has no '\(language)' FrameCopy")
            }
        }
    }

    guard problems.isEmpty else {
        FileHandle.standardError.write(Data("""
        Error: `screenSpecs` is internally inconsistent:
          \(problems.sorted().joined(separator: "\n  "))

        """.utf8))
        return false
    }
    return true
}

/// The drift guard, run in BOTH directions.
///
/// harness → script: parses `saveScreenshot("NAME")` out of the XCUITest harness and proves
/// this script can classify every one. This is the Round-1 guard: the harness saved twelve
/// attachments and the script matched six, silently.
///
/// script → harness (Round-2 review finding): every `.store(rank:)` screen must be backed by
/// a harness attachment. Four screens used to claim ranks 10–13 with no attachment behind
/// them — a declared store set that could never actually be shot. Screens with no capture
/// yet now say so via `.plannedNotCaptured` and are reported, not counted.
///
/// The guard also fails CLOSED (Round-2 review finding): an unreadable harness file used to
/// return `true` and skip the whole check. A drift guard that cannot read its input has not
/// passed — it has failed.
@discardableResult
func verifyHarnessCoverage() -> Bool {
    guard let source = try? String(contentsOfFile: harnessPath, encoding: .utf8) else {
        FileHandle.standardError.write(Data("""
        Error: cannot read the screenshot harness at '\(harnessPath)'.
        The capture-coverage guard cannot be skipped — run from the repo root:
          swift scripts/frame_screenshots.swift --all

        """.utf8))
        return false
    }
    let pattern = "saveScreenshot\\(\"([^\"]+)\"\\)"
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        FileHandle.standardError.write(Data(
            "Error: the harness-coverage regex failed to compile.\n".utf8))
        return false
    }
    let full = NSRange(source.startIndex..., in: source)
    var names: [String] = []
    for match in regex.matches(in: source, range: full) {
        if let range = Range(match.range(at: 1), in: source) {
            let name = String(source[range])
            if !names.contains(name) { names.append(name) }
        }
    }

    var unmapped: [String] = []
    var shipped: [String] = []
    var dropped: [String] = []
    var backedScreens = Set<String>()
    for name in names {
        guard let screen = detectScreenName(from: name), let spec = screenSpecs[screen] else {
            unmapped.append(name)
            continue
        }
        backedScreens.insert(screen)
        if let reason = spec.inclusion.exclusionReason {
            dropped.append("\(name) → \(screen) (excluded: \(reason))")
        } else if let note = spec.inclusion.plannedNote {
            // A capture appeared for a screen declared un-capturable: promote it.
            dropped.append("\(name) → \(screen) (planned: \(note))")
        } else {
            shipped.append("\(name) → \(screen)")
        }
    }

    // script → harness
    var unbackedStoreScreens: [String] = []
    var planned: [String] = []
    for (screen, spec) in screenSpecs {
        if spec.inclusion.storeRank != nil, !backedScreens.contains(screen) {
            unbackedStoreScreens.append(screen)
        }
        if let note = spec.inclusion.plannedNote, !backedScreens.contains(screen) {
            planned.append("\(screen) — \(note)")
        }
    }

    print("Harness coverage: \(names.count) attachment(s) in \(harnessPath) — \(shipped.count) in the store set, \(dropped.count) excluded, \(unmapped.count) unmapped.")
    for line in dropped { print("  excluded: \(line)") }
    if !planned.isEmpty {
        print("  planned, not captured (\(planned.count)) — specced with copy, no harness attachment yet:")
        for line in planned.sorted() { print("    \(line)") }
    }

    var ok = true
    if !unmapped.isEmpty {
        FileHandle.standardError.write(Data("""
        Error: the screenshot harness saves attachment(s) this script cannot classify:
          \(unmapped.joined(separator: "\n  "))
        Add a pattern to `screenPatterns` and a `ScreenSpec` (store, planned, or
        excluded-with-reason).

        """.utf8))
        ok = false
    }
    if !unbackedStoreScreens.isEmpty {
        FileHandle.standardError.write(Data("""
        Error: screen(s) declared `.store(rank:)` that NO harness attachment produces:
          \(unbackedStoreScreens.sorted().joined(separator: "\n  "))
        A store screen that cannot be captured is not a store screen. Either add the
        attachment to \(harnessPath), or declare it `.plannedNotCaptured(note:)`.

        """.utf8))
        ok = false
    }
    // A capture exists for a screen still declared `.plannedNotCaptured` — the promotion
    // forcing function. Reported as an error so the store set cannot silently lag reality.
    let capturedButPlanned = backedScreens.filter { screenSpecs[$0]?.inclusion.plannedNote != nil }
    if !capturedButPlanned.isEmpty {
        FileHandle.standardError.write(Data("""
        Error: the harness now produces screen(s) still declared `.plannedNotCaptured`:
          \(capturedButPlanned.sorted().joined(separator: "\n  "))
        Promote each to `.store(rank:)` (or `.excluded(reason:)`) — a one-word edit.

        """.utf8))
        ok = false
    }
    return ok
}

// MARK: - Frame rendering

struct PlateNumber {
    let index: Int
    /// Number of plates framed in THIS run — deliberately not the size of the intended
    /// store set, so a partial run reads honestly (3 captures → 01/03 … 03/03).
    let total: Int
    var text: String {
        String(format: "tuwa · %02d/%02d", index, total)
    }
}

/// A plate either renders or states why it did not. Round-2 review finding: the strip
/// overflow guard was a `precondition`, so a too-long metric key aborted the process with
/// SIGTRAP (exit 133) — killing the remaining `--all` jobs mid-run and contradicting this
/// script's own exit-code contract. Framing failures are data now, not traps.
enum FrameOutcome {
    case rendered(NSImage)
    case failed(String)
}

func frameScreenshot(
    image: NSImage,
    copy: FrameCopy,
    spec: ScreenSpec,
    plate: PlateNumber,
    outputSize: CGSize,
    language: String
) -> FrameOutcome {
    let width = outputSize.width
    let height = outputSize.height
    // Reference canvas: iPhone 17 Pro Max, 440x956pt.
    let scale = width / 440.0

    // 8pt-grid spacing, in device pixels. Every value is composed from the canonical
    // `design-system/tokens/spacing.css` tokens — none is hand-typed here.
    let margin        = spaceLG * scale                 // canvas → content (lg 32)
    let topPadding    = space2XL * scale                // canvas top → annotation strip (2xl 64)
    let stripHeight   = (spaceLG + spaceXS) * scale     // annotation card (lg + xs = 40, on-grid)
    let stripPadding  = spaceSM * scale                 // strip interior (sm 16)
    let stripGutter   = spaceSM * scale                 // minimum gap between the two strip columns
    let stripGap      = spaceMD * scale                 // strip → headline (md 24)
    let sublineGap    = spaceXS * scale                 // headline → subline (xs 8)
    let machineGap    = spaceSM * scale                 // subline → machine key (sm 16)
    let deviceGap     = (spaceLG + spaceXS) * scale     // machine key → device (40)
    let deviceMargin  = (spaceLG + spaceXS) * scale     // device side margins (40)
    let cardRadius    = radiusCard * scale              // CornerTokens.card (12)
    let hairline      = hairlineUnit * scale            // --hairline (0.5)
    // NOT a spacing token: DESIGN.md's Relief Law specifies the raised top highlight and the
    // plate border as a 1px line. `spacing.css` canonicalises the 0.5px hairline only.
    let borderWidth   = 1.0 * scale

    let isLatin = isLatinAnnotation(language: language)
    annotationGlyphMisses.removeAll()

    let contentWidth = width - 2 * margin

    // Working voice — Instrument Sans with per-range Noto Sans SC (the app's cascade)
    let headlineSize = 32.0 * scale    // display value / marketing headline step
    let sublineSize  = 17.0 * scale    // body
    let annoPoints   = 12.0            // `anno` — the ≤12pt cap, enforced in annotation()

    let headline = workingVoice(
        copy.headline,
        latinFont: loadFont("InstrumentSans-Medium", size: headlineSize),
        cjkFont: loadFont("NotoSansSC-Medium", size: headlineSize),
        color: textColor,
        lineHeightMultiple: 1.1
    )
    let subline = workingVoice(
        copy.subline,
        latinFont: loadFont("InstrumentSans-Regular", size: sublineSize),
        cjkFont: loadFont("NotoSansSC-Regular", size: sublineSize),
        color: text2Color,
        lineHeightMultiple: 1.2
    )

    let hueColor = metricColor(spec.metric)
    // Metric-hue annotation key + its state dot — sanctioned use #3 of a metric hue.
    // It sits on the card plane below: on `--surface-el` the five hues run 4.71:1
    // (readiness) … 6.03:1 (sleep), all clear of the 4.5:1 floor; on `--bg` readiness
    // would be 4.39:1. That is what makes the strip a CARD and not loose text.
    let metricKey = annotation("● \(spec.metric.key)", points: annoPoints, scale: scale,
                               color: hueColor, isLatin: isLatin)
    // Plate number uses text-2 (7.04:1 on the card plane), not the in-app annotation
    // default text-3 (3.34:1 there): App Store thumbnails are viewed at ~1/6 size.
    let plateKey = annotation(plate.text, points: annoPoints, scale: scale,
                              color: text2Color, isLatin: isLatin, alignment: .right)
    // Machine key sits on the BASE plane, where text-2 is 6.56:1 and text-3 only 3.11:1.
    let machineKey = annotation(spec.machineKey, points: annoPoints, scale: scale,
                                color: text2Color, isLatin: isLatin)

    guard annotationGlyphMisses.isEmpty else {
        return .failed("annotation voice incomplete — \(annotationGlyphMisses.joined(separator: "; ")). "
                       + "Store artwork may not fall back to a system face (DESIGN.md Two-Voice Type Law).")
    }

    let measureBox = CGSize(width: contentWidth, height: .greatestFiniteMagnitude)
    let headlineHeight = ceil(headline.boundingRect(with: measureBox, options: [.usesLineFragmentOrigin]).height)
    let sublineHeight = ceil(subline.boundingRect(with: measureBox, options: [.usesLineFragmentOrigin]).height)
    let machineHeight = ceil(machineKey.boundingRect(with: measureBox, options: [.usesLineFragmentOrigin]).height)
    let annoLineHeight = ceil(metricKey.boundingRect(with: measureBox, options: [.usesLineFragmentOrigin]).height)

    // Bitmap context
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: Int(width),
        height: Int(height),
        bitsPerComponent: 8,
        bytesPerRow: Int(width) * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return .failed("could not create a \(Int(width))x\(Int(height)) CGContext")
    }

    // Canvas — stone base plane
    context.setFillColor(bgColor.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    // Annotation strip — a card plane (surface-el + hairline + 12pt corners). CG is bottom-up.
    let stripRect = CGRect(
        x: margin,
        y: height - topPadding - stripHeight,
        width: contentWidth,
        height: stripHeight
    )
    let stripPath = CGPath(roundedRect: stripRect, cornerWidth: cardRadius, cornerHeight: cardRadius, transform: nil)
    context.saveGState()
    context.addPath(stripPath)
    context.setFillColor(surfaceElColor.cgColor)
    context.fillPath()
    context.addPath(stripPath)
    context.setStrokeColor(dividerColor.cgColor)
    context.setLineWidth(hairline)
    context.strokePath()
    context.restoreGState()

    // Text — AppKit string drawing (exact multi-line metrics + wrapping)
    let previous = NSGraphicsContext.current
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

    // The two strip annotations get RESERVED COLUMNS. They used to be drawn into the same
    // rect with `.byClipping`, so a long metric key silently overprinted the plate number.
    let stripTextWidth = stripRect.width - 2 * stripPadding
    let stripTextY = stripRect.midY - annoLineHeight / 2
    let unbounded = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    let plateWidth = ceil(plateKey.boundingRect(with: unbounded, options: [.usesLineFragmentOrigin]).width)
    let metricWidth = ceil(metricKey.boundingRect(with: unbounded, options: [.usesLineFragmentOrigin]).width)
    guard metricWidth + stripGutter + plateWidth <= stripTextWidth else {
        NSGraphicsContext.current = previous
        return .failed("""
        annotation strip overflow: metric key (\(Int(metricWidth))px) + gutter + plate \
        (\(Int(plateWidth))px) exceeds the strip's \(Int(stripTextWidth))px. Shorten the \
        metric key or widen the strip — do not let the two columns overlap.
        """)
    }
    metricKey.draw(
        with: CGRect(x: stripRect.minX + stripPadding,
                     y: stripTextY,
                     width: stripTextWidth - plateWidth - stripGutter,
                     height: annoLineHeight),
        options: [.usesLineFragmentOrigin]
    )
    plateKey.draw(
        with: CGRect(x: stripRect.maxX - stripPadding - plateWidth,
                     y: stripTextY,
                     width: plateWidth,
                     height: annoLineHeight),
        options: [.usesLineFragmentOrigin]
    )

    let headlineTop = stripRect.minY - stripGap
    headline.draw(
        with: CGRect(x: margin, y: headlineTop - headlineHeight, width: contentWidth, height: headlineHeight),
        options: [.usesLineFragmentOrigin]
    )
    let sublineTop = headlineTop - headlineHeight - sublineGap
    subline.draw(
        with: CGRect(x: margin, y: sublineTop - sublineHeight, width: contentWidth, height: sublineHeight),
        options: [.usesLineFragmentOrigin]
    )
    let machineTop = sublineTop - sublineHeight - machineGap
    machineKey.draw(
        with: CGRect(x: margin, y: machineTop - machineHeight, width: contentWidth, height: machineHeight),
        options: [.usesLineFragmentOrigin]
    )

    NSGraphicsContext.current = previous

    // Device — bleeds off the bottom edge; 12pt top corners; hairline border + 1px inner
    // top highlight (relief; still no shadows)
    let deviceWidth = width - 2 * deviceMargin
    let deviceHeight = deviceWidth * (image.size.height / image.size.width)
    let deviceTop = machineTop - machineHeight - deviceGap
    let deviceRect = CGRect(
        x: deviceMargin,
        y: deviceTop - deviceHeight,   // extends below 0 = bleeds off the bottom
        width: deviceWidth,
        height: deviceHeight
    )
    let devicePath = CGPath(
        roundedRect: deviceRect,
        cornerWidth: cardRadius,
        cornerHeight: cardRadius,
        transform: nil
    )
    if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
        context.saveGState()
        context.addPath(devicePath)
        context.clip()
        context.draw(cgImage, in: deviceRect)
        // Relief: 1px raised top highlight
        context.setFillColor(surfaceEl2Color.cgColor)
        context.fill(CGRect(
            x: deviceRect.minX,
            y: deviceRect.maxY - borderWidth,
            width: deviceRect.width,
            height: borderWidth
        ))
        context.restoreGState()
    }
    context.saveGState()
    context.addPath(devicePath)
    context.setStrokeColor(dividerStrongColor.cgColor)
    context.setLineWidth(borderWidth)
    context.strokePath()
    context.restoreGState()

    guard let outputCGImage = context.makeImage() else {
        return .failed("could not create the output image from the render context")
    }
    return .rendered(NSImage(cgImage: outputCGImage, size: NSSize(width: width, height: height)))
}

// MARK: - Run one job

struct JobResult {
    var framed = 0
    /// file → stated reason. Printed in the summary; never silent.
    var excluded: [(file: String, reason: String)] = []
    /// Files no pattern matched, duplicate screens, store screens with no copy, framing or
    /// publish failures. Any entry fails the run AND suppresses publication.
    var errors: [String] = []
    /// True when this run's plates replaced the output dir's contents.
    var published = false
}

/// Publishes a staged set over `outputDir`. Called only on a zero-error run.
///
/// The swap is two directory renames with an explicit restore, so the output dir is never
/// observed half-written: a reader sees either the previous set or this run's set, and a
/// throw leaves the previous set in place.
///
/// Two earlier versions were wrong, both proven by test rather than by reading:
///   * delete-then-move destroyed part of the live set before the staged replacement landed;
///   * `replaceItemAt` performed the swap and THEN threw while discarding its own backup, so
///     the dir held the new set while the caller reported "left unchanged" — a report that
///     contradicted the filesystem, which is worse than the failure it described.
/// Renaming the live dir aside first means the only failure that can happen before the new
/// set is in place is a failure that has changed nothing.
///
/// Because a directory rename swaps the whole directory rather than just the plates, anything
/// in the output dir that is not a generated plate is carried into staging first, so
/// publication cannot silently drop it.
func publish(stagingDir: String, outputDir: String) throws {
    let fm = FileManager.default

    guard fm.fileExists(atPath: outputDir) else {
        try fm.createDirectory(atPath: (outputDir as NSString).deletingLastPathComponent,
                               withIntermediateDirectories: true)
        try fm.moveItem(atPath: stagingDir, toPath: outputDir)
        return
    }

    for existing in try fm.contentsOfDirectory(atPath: outputDir)
        where !existing.lowercased().hasSuffix("_framed.png") {
        let destination = "\(stagingDir)/\(existing)"
        if !fm.fileExists(atPath: destination) {
            try fm.copyItem(atPath: "\(outputDir)/\(existing)", toPath: destination)
        }
    }

    let parked = "\(outputDir).previous-\(ProcessInfo.processInfo.processIdentifier)"
    try? fm.removeItem(atPath: parked)

    // Nothing has changed yet if this throws.
    try fm.moveItem(atPath: outputDir, toPath: parked)

    do {
        try fm.moveItem(atPath: stagingDir, toPath: outputDir)
    } catch {
        try? fm.moveItem(atPath: parked, toPath: outputDir)
        throw error
    }

    // The new set is live. Discarding the old one is housekeeping: if it fails (an immutable
    // plate, say) the publish still succeeded, so report the litter rather than claim failure.
    do {
        try fm.removeItem(atPath: parked)
    } catch {
        print("  note: published, but the previous set could not be removed — \(parked)")
    }
}

@discardableResult
func runJob(inputDir: String, outputDir: String, language: String) -> JobResult {
    var result = JobResult()
    guard let copySet = copyByLanguage[language] else {
        result.errors.append("unknown language '\(language)' (expected en or zh-Hans)")
        return result
    }
    let fm = FileManager.default
    var isDir: ObjCBool = false
    guard fm.fileExists(atPath: inputDir, isDirectory: &isDir), isDir.boolValue else {
        print("Skipping job: no input dir at '\(inputDir)'")
        return result
    }

    let files = (try? fm.contentsOfDirectory(atPath: inputDir))?.sorted() ?? []
    let pngs = files.filter { $0.lowercased().hasSuffix(".png") }

    // Two passes: the plate number needs the eligible total up front, and the store order
    // is the declared `rank`, NOT filename order (filename order put the two hero verdict
    // shots last, because ASCII digits sort before letters).
    var eligible: [(file: String, screen: String, rank: Int)] = []
    var seenScreens: [String: String] = [:]   // screen → the file that claimed it
    for file in pngs {
        guard let screen = detectScreenName(from: file), let spec = screenSpecs[screen] else {
            result.errors.append("\(file): no `screenPatterns` entry matches this filename")
            continue
        }
        if let reason = spec.inclusion.exclusionReason {
            result.excluded.append((file, "\(screen) — \(reason)"))
            continue
        }
        if let note = spec.inclusion.plannedNote {
            result.errors.append("\(file): resolves to \(screen), which is declared `.plannedNotCaptured` (\(note)). A capture exists now — promote it to `.store(rank:)`.")
            continue
        }
        // Round-2 review finding: two captures resolving to the same screen used to frame
        // BOTH, shipping a duplicated plate at exit 0.
        if let firstFile = seenScreens[screen] {
            result.errors.append("\(file): resolves to \(screen), already claimed by \(firstFile) — two captures of one screen would ship as duplicate plates. Remove one, or give it its own `screenPatterns` entry.")
            continue
        }
        seenScreens[screen] = file
        guard copySet[screen] != nil else {
            result.errors.append("\(file): \(screen) is in the store set but has no '\(language)' FrameCopy")
            continue
        }
        eligible.append((file, screen, spec.inclusion.storeRank ?? Int.max))
    }
    eligible.sort { ($0.rank, $0.file) < ($1.rank, $1.file) }

    print("\n[\(language)] \(inputDir) → \(outputDir)  (\(eligible.count) screens)")
    if eligible.count > appStoreMaxScreenshots {
        print("  Warning: \(eligible.count) store screens > App Store's \(appStoreMaxScreenshots) per device size — curate before upload.")
    }

    // Sweep litter from earlier runs first: a publish whose housekeeping failed leaves a
    // `.previous-<pid>` behind by design, and a killed run can strand a `.staging-<pid>`.
    // Without this they accumulate silently next to the store set.
    let outputParent = (outputDir as NSString).deletingLastPathComponent
    let outputLeaf = (outputDir as NSString).lastPathComponent
    for sibling in (try? fm.contentsOfDirectory(atPath: outputParent)) ?? []
        where sibling.hasPrefix("\(outputLeaf).staging-") || sibling.hasPrefix("\(outputLeaf).previous-") {
        try? fm.removeItem(atPath: "\(outputParent)/\(sibling)")
    }

    // Staging dir: a sibling of `outputDir`, so the publish move never crosses a volume.
    let stagingDir = "\(outputDir).staging-\(ProcessInfo.processInfo.processIdentifier)"
    try? fm.removeItem(atPath: stagingDir)
    do {
        try fm.createDirectory(atPath: stagingDir, withIntermediateDirectories: true)
    } catch {
        result.errors.append("could not create staging dir '\(stagingDir)' — \(error)")
        return result
    }
    defer { try? fm.removeItem(atPath: stagingDir) }

    for (offset, entry) in eligible.enumerated() {
        let index = offset + 1
        guard let image = NSImage(contentsOfFile: "\(inputDir)/\(entry.file)"),
              let rep = image.representations.first else {
            result.errors.append("\(entry.file): could not be loaded as an image")
            continue
        }
        let pixelSize = CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        image.size = pixelSize   // work in pixels throughout

        let copy = copySet[entry.screen]!
        let spec = screenSpecs[entry.screen]!
        print("  \(String(format: "%02d", index)) \(entry.screen) (\(Int(pixelSize.width))x\(Int(pixelSize.height))) · \(spec.metric.rawValue) — \"\(copy.headline)\"")

        let outcome = frameScreenshot(
            image: image,
            copy: copy,
            spec: spec,
            plate: PlateNumber(index: index, total: eligible.count),
            outputSize: pixelSize,
            language: language
        )
        guard case .rendered(let framed) = outcome else {
            if case .failed(let reason) = outcome {
                result.errors.append("\(entry.file): \(reason)")
            }
            continue
        }
        guard let tiff = framed.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            result.errors.append("\(entry.file): could not be encoded as PNG")
            continue
        }
        let name = "\(String(format: "%02d", index))_\(entry.screen)_framed.png"
        do {
            try png.write(to: URL(fileURLWithPath: "\(stagingDir)/\(name)"))
            print("     → \(outputDir)/\(name)")
            result.framed += 1
        } catch {
            result.errors.append("\(name): write failed — \(error)")
        }
    }

    // Publish or don't — never half. A store set is replaced wholesale or left alone.
    // A run that framed nothing does NOT publish: an accidentally-empty raw dir must not
    // be able to delete a good framed set.
    if result.errors.isEmpty && result.framed > 0 {
        do {
            try publish(stagingDir: stagingDir, outputDir: outputDir)
            result.published = true
        } catch {
            result.errors.append("publish to '\(outputDir)' failed — \(error). The previous set is unchanged.")
        }
    }

    // The explicit summary line. Nothing this pipeline drops is allowed to be invisible.
    let excludedNote = result.excluded.isEmpty
        ? "0 excluded"
        : "\(result.excluded.count) excluded"
    var publishNote = "PUBLISHED (output dir replaced)"
    if !result.published {
        let why = result.errors.isEmpty ? "nothing framed" : "\(result.errors.count) error(s)"
        publishNote = "NOT PUBLISHED (\(why)) — '\(outputDir)' left unchanged"
    }
    print("  Summary [\(language)]: \(pngs.count) capture(s) in · \(result.framed) framed · \(excludedNote) · \(result.errors.count) error(s) · \(publishNote)")
    for item in result.excluded {
        print("    excluded: \(item.file) — \(item.reason)")
    }
    for error in result.errors {
        print("    ERROR: \(error)")
    }
    return result
}

// MARK: - Main

func main() {
    // Hard-fails before a single plate is rendered: bundled faces must load, the spec table
    // must be self-consistent, and the harness drift guard must actually run.
    registerBundledFonts()

    // Fail CLOSED: a startup guard that did not pass aborts the run before a single set is
    // published. Exiting non-zero *after* replacing the store artwork is not a guard.
    var startupOK = verifyScreenSpecs()
    if !verifyHarnessCoverage() { startupOK = false }
    guard startupOK else {
        FileHandle.standardError.write(Data(
            "Aborted before framing: a startup guard failed. Nothing was written.\n".utf8))
        exit(1)
    }

    let args = CommandLine.arguments
    var total = 0
    var errorCount = 0
    var publishedJobs = 0

    func absorb(_ result: JobResult) {
        total += result.framed
        errorCount += result.errors.count
        if result.published { publishedJobs += 1 }
    }

    if args.count >= 2 && args[1] == "--all" {
        for job in frameJobs {
            absorb(runJob(inputDir: job.inputDir, outputDir: job.outputDir, language: job.language))
        }
        print("\nFramed \(total) screenshots across \(frameJobs.count) job(s); \(publishedJobs) set(s) published; \(errorCount) error(s).")
        if total == 0 && errorCount == 0 {
            print("Nothing framed — capture raw screenshots into the job input dirs first.")
        }
        if errorCount > 0 { exit(1) }
        // Publishing nothing is a failure, not a quiet success: an orchestrator gating the
        // wave on this exit code must not read "0 sets published" as green.
        if publishedJobs == 0 { exit(1) }
        return
    }

    guard args.count >= 3 else {
        print("""
        Usage:
          swift scripts/frame_screenshots.swift --all
          swift scripts/frame_screenshots.swift <input_dir> <output_dir> [en|zh-Hans]
        """)
        exit(1)
    }
    let language = args.count >= 4 ? args[3] : "en"
    absorb(runJob(inputDir: args[1], outputDir: args[2], language: language))
    print("\nFramed \(total) screenshots to \(args[2]); \(publishedJobs) set(s) published; \(errorCount) error(s).")
    if errorCount > 0 { exit(1) }
}

main()
