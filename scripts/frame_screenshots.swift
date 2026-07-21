#!/usr/bin/env swift
//
// frame_screenshots.swift
// Marketing frame generator for App Store screenshots — DESIGN.md v5 "Pavilion".
//
// Usage:
//   swift scripts/frame_screenshots.swift <input_dir> <output_dir> [en|zh-Hans]
//
// Layout (editorial, left-aligned, 8pt grid; reference canvas 440x956pt @3x):
//   - Warm stone canvas (#F0EFEC)
//   - Short travertine accent rule above the headline (the one accent mark)
//   - Headline: Instrument Sans Medium, ink, wraps up to 2 lines
//   - Subline: Instrument Sans Regular, secondary ink
//   - Device: hairline-bordered, 16pt soft top corners, bleeds off the bottom edge
//   - CJK glyphs route to Noto Sans SC (per-range), matching the app's cascade
//
// No shadows. All spacing multiples of 8pt (4pt sanctioned micro-gap).

import AppKit
import CoreGraphics
import CoreText
import Foundation

// MARK: - Copy

struct FrameCopy {
    let headline: String
    let subline: String
}

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
        "ActiveWorkout": FrameCopy(
            headline: "Log every rep",
            subline: "Capture strength work without friction."
        )
    ],
    "zh-Hans": [
        "VerdictMicrodose": FrameCopy(
            headline: "比赛前，先 microdose",
            subline: "封顶 top set，跳过 back-off。"
        ),
        "StrikeZone": FrameCopy(
            headline: "留在今日区间",
            subline: "今天的数字落在合适范围内。"
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
        "ActiveWorkout": FrameCopy(
            headline: "每一组都记下",
            subline: "顺手记录力量训练。"
        )
    ]
]

// MARK: - Design tokens (DESIGN.md v5 "Pavilion", light-only)

let bgColor      = NSColor(red: 0xF0/255.0, green: 0xEF/255.0, blue: 0xEC/255.0, alpha: 1.0) // --bg
let textColor    = NSColor(red: 0x1B/255.0, green: 0x1A/255.0, blue: 0x17/255.0, alpha: 1.0) // --text-1
let text2Color   = NSColor(red: 0x57/255.0, green: 0x54/255.0, blue: 0x4E/255.0, alpha: 1.0) // --text-2
let dividerColor = NSColor(red: 0xCC/255.0, green: 0xC9/255.0, blue: 0xC2/255.0, alpha: 1.0) // --divider-strong
let accentColor  = NSColor(red: 0x6F/255.0, green: 0x67/255.0, blue: 0x59/255.0, alpha: 1.0) // --accent (travertine)

// MARK: - Fonts

func registerFont(at path: String) {
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: url.path) else { return }
    var error: Unmanaged<CFError>?
    CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
}

func loadFont(_ postScriptName: String, fallback: String, size: CGFloat) -> NSFont {
    if let f = NSFont(name: postScriptName, size: size) { return f }
    print("Warning: \(postScriptName) not found, using \(fallback)")
    return NSFont(name: fallback, size: size) ?? NSFont.systemFont(ofSize: size)
}

func registerBundledFonts() {
    registerFont(at: "WorkloadApp/Resources/Fonts/InstrumentSans-Regular.ttf")
    registerFont(at: "WorkloadApp/Resources/Fonts/InstrumentSans-Medium.ttf")
    registerFont(at: "WorkloadApp/Resources/Fonts/NotoSansSC-Regular.otf")
    registerFont(at: "WorkloadApp/Resources/Fonts/NotoSansSC-Medium.otf")
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

/// Attributed string with per-range fonts: Latin stays on Instrument Sans, CJK runs on
/// Noto Sans SC — the marketing frames speak with the app's exact voices.
func styledString(
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
    let scalars = Array(text.unicodeScalars)
    var utf16Index = 0
    for scalar in scalars {
        let length = UTF16.width(scalar)
        if isCJK(scalar) {
            result.addAttribute(.font, value: cjkFont, range: NSRange(location: utf16Index, length: length))
        }
        utf16Index += length
    }
    return result
}

// MARK: - Screen name detection

func detectScreenName(from filename: String) -> String? {
    let lower = filename.lowercased()
    if lower.contains("verdictmicrodose") || lower.contains("v21_01") { return "VerdictMicrodose" }
    if lower.contains("strikezone") || lower.contains("v21_02") { return "StrikeZone" }
    if lower.contains("nextmatch") || lower.contains("v21_03") { return "NextMatch" }
    if lower.contains("matchtier") || lower.contains("v21_04") { return "MatchTier" }
    if lower.contains("readinesssignals") || lower.contains("v21_05") { return "ReadinessSignals" }
    if lower.contains("planinput") || lower.contains("v21_06") { return "PlanInput" }
    if lower.contains("dashboard") { return "Dashboard" }
    if lower.contains("recovery") { return "Recovery" }
    if lower.contains("workload") || lower.contains("acwr") { return "Workload" }
    if lower.contains("activeworkout") || lower.contains("active_workout") { return "ActiveWorkout" }
    return nil
}

// MARK: - Frame rendering

func frameScreenshot(image: NSImage, copy: FrameCopy, outputSize: CGSize) -> NSImage? {
    let width = outputSize.width
    let height = outputSize.height
    // Reference canvas: iPhone 17 Pro Max, 440x956pt.
    let scale = width / 440.0

    // 8pt-grid spacing (in device pixels)
    let margin        = 32.0 * scale   // text block left/right margin
    let topPadding    = 64.0 * scale   // canvas top → accent rule
    let ruleWidth     = 32.0 * scale   // travertine rule
    let ruleHeight    = 2.0 * scale
    let ruleGap       = 16.0 * scale   // rule → headline
    let sublineGap    = 12.0 * scale   // headline → subline
    let deviceGap     = 48.0 * scale   // subline → device
    let deviceMargin  = 40.0 * scale   // device side margins
    let cornerRadius  = 16.0 * scale   // device top corners
    let borderWidth   = 1.0 * scale

    let contentWidth = width - 2 * margin

    // Type — Instrument Sans with per-range Noto Sans SC (matches the app's cascade)
    let headlineSize = 30.0 * scale
    let sublineSize  = 16.0 * scale
    let headline = styledString(
        copy.headline,
        latinFont: loadFont("InstrumentSans-Medium", fallback: "HelveticaNeue-Medium", size: headlineSize),
        cjkFont: loadFont("NotoSansSC-Medium", fallback: "PingFangSC-Medium", size: headlineSize),
        color: textColor,
        lineHeightMultiple: 1.1
    )
    let subline = styledString(
        copy.subline,
        latinFont: loadFont("InstrumentSans-Regular", fallback: "HelveticaNeue", size: sublineSize),
        cjkFont: loadFont("NotoSansSC-Regular", fallback: "PingFangSC-Regular", size: sublineSize),
        color: text2Color,
        lineHeightMultiple: 1.2
    )

    let measureBox = CGSize(width: contentWidth, height: .greatestFiniteMagnitude)
    let headlineHeight = ceil(headline.boundingRect(with: measureBox, options: [.usesLineFragmentOrigin]).height)
    let sublineHeight = ceil(subline.boundingRect(with: measureBox, options: [.usesLineFragmentOrigin]).height)

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
        print("Error: could not create CGContext")
        return nil
    }

    // Canvas
    context.setFillColor(bgColor.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    // Travertine accent rule (top-left) — CG coords are bottom-up
    let ruleY = height - topPadding - ruleHeight
    context.setFillColor(accentColor.cgColor)
    context.fill(CGRect(x: margin, y: ruleY, width: ruleWidth, height: ruleHeight))

    // Text block via AppKit string drawing (handles wrapping + exact multi-line metrics)
    let previous = NSGraphicsContext.current
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    let headlineTop = ruleY - ruleGap
    headline.draw(
        with: CGRect(x: margin, y: headlineTop - headlineHeight, width: contentWidth, height: headlineHeight),
        options: [.usesLineFragmentOrigin]
    )
    let sublineTop = headlineTop - headlineHeight - sublineGap
    subline.draw(
        with: CGRect(x: margin, y: sublineTop - sublineHeight, width: contentWidth, height: sublineHeight),
        options: [.usesLineFragmentOrigin]
    )
    NSGraphicsContext.current = previous

    // Device — bleeds off the bottom edge; soft top corners; hairline border + 1px inner
    // top highlight (the machined nod; still no shadows)
    let deviceWidth = width - 2 * deviceMargin
    let deviceHeight = deviceWidth * (image.size.height / image.size.width)
    let deviceTop = sublineTop - sublineHeight - deviceGap
    let deviceRect = CGRect(
        x: deviceMargin,
        y: deviceTop - deviceHeight,   // extends below 0 = bleeds off the bottom
        width: deviceWidth,
        height: deviceHeight
    )
    let devicePath = CGPath(
        roundedRect: deviceRect,
        cornerWidth: cornerRadius,
        cornerHeight: cornerRadius,
        transform: nil
    )
    if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
        context.saveGState()
        context.addPath(devicePath)
        context.clip()
        context.draw(cgImage, in: deviceRect)
        // Inner top highlight
        context.setFillColor(NSColor.white.withAlphaComponent(0.55).cgColor)
        context.fill(CGRect(
            x: deviceRect.minX,
            y: deviceRect.maxY - 1.0 * scale,
            width: deviceRect.width,
            height: 1.0 * scale
        ))
        context.restoreGState()
    }
    context.saveGState()
    context.addPath(devicePath)
    context.setStrokeColor(dividerColor.cgColor)
    context.setLineWidth(borderWidth)
    context.strokePath()
    context.restoreGState()

    guard let outputCGImage = context.makeImage() else {
        print("Error: could not create output image")
        return nil
    }
    return NSImage(cgImage: outputCGImage, size: NSSize(width: width, height: height))
}

// MARK: - Main

func main() {
    let args = CommandLine.arguments
    guard args.count >= 3 else {
        print("Usage: swift frame_screenshots.swift <input_dir> <output_dir> [en|zh-Hans]")
        exit(1)
    }
    let inputDir = args[1]
    let outputDir = args[2]
    let language = args.count >= 4 ? args[3] : "en"
    guard let copySet = copyByLanguage[language] else {
        print("Error: unknown language '\(language)' (expected en or zh-Hans)")
        exit(1)
    }

    registerBundledFonts()
    try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

    let files = (try? FileManager.default.contentsOfDirectory(atPath: inputDir))?.sorted() ?? []
    var framedCount = 0
    for file in files where file.lowercased().hasSuffix(".png") {
        guard let screen = detectScreenName(from: file) else {
            print("Skipping \(file) (not a required screen)")
            continue
        }
        guard let copy = copySet[screen] else {
            print("Skipping \(file) (no \(language) copy for \(screen))")
            continue
        }
        guard let image = NSImage(contentsOfFile: "\(inputDir)/\(file)"),
              let rep = image.representations.first else {
            print("Error: could not load \(file)")
            continue
        }
        let pixelSize = CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        image.size = pixelSize   // work in pixels throughout
        print("Framing \(screen) (\(Int(pixelSize.width))x\(Int(pixelSize.height))): \"\(copy.headline)\"")
        guard let framed = frameScreenshot(image: image, copy: copy, outputSize: pixelSize),
              let tiff = framed.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            print("  Error: framing failed")
            continue
        }
        let outPath = "\(outputDir)/\(screen)_framed.png"
        try? png.write(to: URL(fileURLWithPath: outPath))
        print("  Saved: \(outPath)")
        framedCount += 1
    }
    print("\nFramed \(framedCount) screenshots to \(outputDir)")
}

main()
