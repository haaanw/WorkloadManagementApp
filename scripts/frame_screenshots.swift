#!/usr/bin/env swift
//
// frame_screenshots.swift
// Marketing frame generator for App Store screenshots.
//
// Usage:
//   swift scripts/frame_screenshots.swift <input_dir> <output_dir>
//
// Takes raw simulator screenshots and composites them with:
// - Headline text overlay (Instrument Sans Medium)
// - Hairline device frame with 12pt-equivalent soft corners, no shadows
// - Background matching the app's v5 "Pavilion" warm stone palette
//
// Per DESIGN.md v5: CornerTokens card 12pt, no shadows, Instrument Sans one voice,
// International Style Minimalism in warm stone.

import AppKit
import CoreGraphics
import CoreText
import Foundation

// MARK: - Configuration

struct FrameCopy {
    let headline: String
    let subline: String
}

/// Headlines/subline copy for v2.1 App Store frames.
let englishCopy: [String: FrameCopy] = [
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
    "Dashboard": FrameCopy(headline: "Know Today's Readiness", subline: "Recovery and load in one daily read."),
    "Recovery": FrameCopy(headline: "Recovery, Decoded", subline: "See the signals behind today's state."),
    "Workload": FrameCopy(headline: "Track Training Load", subline: "Watch acute and chronic load move."),
    "ActiveWorkout": FrameCopy(headline: "Log Every Rep", subline: "Capture strength work without friction.")
]

let zhHansCopy: [String: FrameCopy] = [
    "VerdictMicrodose": FrameCopy(
        headline: "比赛前 microdose",
        subline: "封顶 top set，跳过 back-off。"
    ),
    "StrikeZone": FrameCopy(
        headline: "留在今日区间",
        subline: "今天的数字落在合适范围内。"
    ),
    "NextMatch": FrameCopy(
        headline: "比赛时间很重要",
        subline: "设置日期，临近时自动收紧训练。"
    ),
    "MatchTier": FrameCopy(
        headline: "比赛会打到腿",
        subline: "记录野球、对抗赛或正式比赛。"
    ),
    "ReadinessSignals": FrameCopy(
        headline: "真实信号看准备度",
        subline: "HRV、静息心率和睡眠影响今天。"
    ),
    "PlanInput": FrameCopy(
        headline: "计划仍然属于你",
        subline: "接受微调，或坚持原计划。"
    )
]

/// Design tokens from DESIGN.md v5 "Pavilion" (warm stone, light-only).
let bgColor = NSColor(red: 0xF0/255.0, green: 0xEF/255.0, blue: 0xEC/255.0, alpha: 1.0) // --bg
let textColor = NSColor(red: 0x1B/255.0, green: 0x1A/255.0, blue: 0x17/255.0, alpha: 1.0) // --text-1
let dividerColor = NSColor(red: 0xD6/255.0, green: 0xD3/255.0, blue: 0xCD/255.0, alpha: 1.0) // --divider

// MARK: - Font Loading

/// Load Instrument Sans Medium from the project's font bundle (static face; PS name
/// resolves directly — verified 2026-07-21).
func loadInstrumentSansMedium() -> CTFont? {
    let fontPaths = [
        "WorkloadApp/Resources/Fonts/InstrumentSans-Medium.ttf"
    ]

    for path in fontPaths {
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: url.path) {
            var error: Unmanaged<CFError>?
            if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                if let font = CTFontCreateWithName("InstrumentSans-Medium" as CFString, 48, nil) as CTFont? {
                    return font
                }
            }
        }
    }

    // Fallback: try system font registration
    let font = CTFontCreateWithName("InstrumentSans-Medium" as CFString, 48, nil)
    let fontName = CTFontCopyPostScriptName(font) as String
    if fontName.contains("InstrumentSans") {
        return font
    }

    // Final fallback: use Helvetica Neue Medium (similar geometric sans)
    print("Warning: Instrument Sans Medium not found, using Helvetica Neue Medium as fallback")
    return CTFontCreateWithName("HelveticaNeue-Medium" as CFString, 48, nil)
}

// MARK: - Screen Name Detection

/// Match a filename to one of the required screens.
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

// MARK: - Frame Rendering

/// Create a marketing-framed screenshot.
///
/// Layout (top to bottom):
/// - Top padding (64pt equivalent at screen scale)
/// - Headline text (DM Sans Medium, centered)
/// - Gap (48pt equivalent)
/// - Device frame (1pt border, screenshot inside)
/// - Bottom padding (64pt equivalent)
///
/// All spacing multiples of 8pt per DESIGN.md.
func frameScreenshot(
    image: NSImage,
    copy: FrameCopy,
    baseFont: CTFont,
    outputSize: CGSize
) -> NSImage? {
    let width = outputSize.width
    let height = outputSize.height

    // Scale factor: output pixels / reference points
    // Reference: iPhone 17 Pro Max is 1320x2868 at 3x = 440x956 points
    let scale = width / 440.0

    // Spacing (in pixels, derived from 8pt grid * scale)
    let topPadding = 64.0 * scale       // 2xl
    let subtitleGap = 8.0 * scale        // xs
    let headlineGap = 40.0 * scale       // xl minus subtitle line
    let sidePadding = 32.0 * scale       // lg
    let bottomPadding = 32.0 * scale     // lg
    let frameBorderWidth = 1.0 * scale   // hairline

    // Font size scaled
    let headlineFontSize = 28.0 * scale  // page title size from DESIGN.md
    let subtitleFontSize = 15.0 * scale  // label size from DESIGN.md
    let headlineFont = CTFontCreateCopyWithAttributes(baseFont, headlineFontSize, nil, nil)
    let subtitleFont = CTFontCreateCopyWithAttributes(baseFont, subtitleFontSize, nil, nil)

    // Measure headline text
    let headlineAttrString = NSAttributedString(
        string: copy.headline,
        attributes: [
            .font: headlineFont,
            .foregroundColor: textColor
        ]
    )
    let subtitleAttrString = NSAttributedString(
        string: copy.subline,
        attributes: [
            .font: subtitleFont,
            .foregroundColor: textColor
        ]
    )
    let headlineLine = CTLineCreateWithAttributedString(headlineAttrString)
    let subtitleLine = CTLineCreateWithAttributedString(subtitleAttrString)
    let headlineBounds = CTLineGetBoundsWithOptions(headlineLine, .useOpticalBounds)
    let subtitleBounds = CTLineGetBoundsWithOptions(subtitleLine, .useOpticalBounds)

    // Calculate screenshot area
    let screenshotX = sidePadding + frameBorderWidth
    let screenshotY = bottomPadding + frameBorderWidth
    let screenshotWidth = width - 2 * sidePadding - 2 * frameBorderWidth
    let headlineY = height - topPadding - headlineBounds.height
    let subtitleY = headlineY - subtitleGap - subtitleBounds.height
    let screenshotHeight = headlineY - headlineGap - screenshotY - frameBorderWidth

    guard screenshotWidth > 0, screenshotHeight > 0 else {
        print("Error: calculated screenshot area is too small")
        return nil
    }

    // Create bitmap context
    let bitsPerComponent = 8
    let bytesPerRow = Int(width) * 4
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: Int(width),
        height: Int(height),
        bitsPerComponent: bitsPerComponent,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        print("Error: could not create CGContext")
        return nil
    }

    // Fill background
    context.setFillColor(bgColor.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    // Draw device frame border (12pt-equivalent soft corners per DESIGN.md v5 Corner Law)
    let cornerRadius = 12.0 * scale
    let frameRect = CGRect(
        x: sidePadding,
        y: bottomPadding,
        width: width - 2 * sidePadding,
        height: screenshotHeight + 2 * frameBorderWidth
    )
    let framePath = CGPath(roundedRect: frameRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    context.setStrokeColor(dividerColor.cgColor)
    context.setLineWidth(frameBorderWidth)
    context.addPath(framePath)
    context.strokePath()

    // Draw screenshot inside frame, clipped to the soft corners
    if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
        let drawRect = CGRect(
            x: screenshotX,
            y: screenshotY,
            width: screenshotWidth,
            height: screenshotHeight
        )
        let clipRadius = max(cornerRadius - frameBorderWidth, 0)
        context.saveGState()
        context.addPath(CGPath(roundedRect: drawRect, cornerWidth: clipRadius, cornerHeight: clipRadius, transform: nil))
        context.clip()
        context.draw(cgImage, in: drawRect)
        context.restoreGState()
    }

    // Draw headline + subline text (centered)
    let headlineX = (width - headlineBounds.width) / 2.0
    let subtitleX = (width - subtitleBounds.width) / 2.0
    context.saveGState()
    context.textPosition = CGPoint(
        x: headlineX,
        y: headlineY - headlineBounds.height + CTFontGetDescent(headlineFont)
    )
    CTLineDraw(headlineLine, context)
    context.textPosition = CGPoint(
        x: subtitleX,
        y: subtitleY - subtitleBounds.height + CTFontGetDescent(subtitleFont)
    )
    CTLineDraw(subtitleLine, context)
    context.restoreGState()

    // Create output image
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
        print("Usage: swift frame_screenshots.swift <input_dir> <output_dir>")
        exit(1)
    }

    let inputDir = args[1]
    let outputDir = args[2]
    let isZhHans = inputDir.lowercased().contains("zh")
        || outputDir.lowercased().contains("zh")
        || args.contains("--zh-Hans")
    let copyByScreen = isZhHans ? zhHansCopy.merging(englishCopy) { zh, _ in zh } : englishCopy

    // Create output directory
    try? FileManager.default.createDirectory(
        atPath: outputDir,
        withIntermediateDirectories: true
    )

    // Load font
    guard let baseFont = loadInstrumentSansMedium() else {
        print("Error: could not load any suitable font")
        exit(1)
    }

    // Find PNG files
    guard let files = try? FileManager.default.contentsOfDirectory(atPath: inputDir) else {
        print("Error: could not read input directory: \(inputDir)")
        exit(1)
    }

    let pngFiles = files.filter { $0.hasSuffix(".png") }
    print("Found \(pngFiles.count) PNG files in \(inputDir)")

    var framed = 0

    for filename in pngFiles {
        guard let screenName = detectScreenName(from: filename) else {
            print("Skipping \(filename) (not a required screen)")
            continue
        }

        guard let copy = copyByScreen[screenName] else {
            print("Skipping \(filename) (no copy for \(screenName))")
            continue
        }

        let inputPath = (inputDir as NSString).appendingPathComponent(filename)
        guard let image = NSImage(contentsOfFile: inputPath) else {
            print("Error: could not load image: \(inputPath)")
            continue
        }

        // Get pixel dimensions from the image representation
        guard let rep = image.representations.first else {
            print("Error: no image representation for \(filename)")
            continue
        }

        let pixelWidth = CGFloat(rep.pixelsWide)
        let pixelHeight = CGFloat(rep.pixelsHigh)
        let outputSize = CGSize(width: pixelWidth, height: pixelHeight)

        print("Framing \(screenName) (\(Int(pixelWidth))x\(Int(pixelHeight))): \"\(copy.headline)\"")

        guard let framedImage = frameScreenshot(
            image: image,
            copy: copy,
            baseFont: baseFont,
            outputSize: outputSize
        ) else {
            print("Error: framing failed for \(filename)")
            continue
        }

        // Save as PNG
        let localeSuffix = isZhHans ? "_zh-Hans" : ""
        let outputFilename = "\(screenName)\(localeSuffix)_framed.png"
        let outputPath = (outputDir as NSString).appendingPathComponent(outputFilename)

        guard let tiffData = framedImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            print("Error: could not encode PNG for \(filename)")
            continue
        }

        do {
            try pngData.write(to: URL(fileURLWithPath: outputPath))
            print("  Saved: \(outputPath)")
            framed += 1
        } catch {
            print("Error writing \(outputPath): \(error)")
        }
    }

    print("\nFramed \(framed) screenshots to \(outputDir)")

    if framed == 0 {
        print("Warning: No screenshots were framed. Check that input files contain Dashboard, Recovery, Workload, or ActiveWorkout in their names.")
        exit(1)
    }
}

main()
