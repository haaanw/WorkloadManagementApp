#!/usr/bin/env swift
//
// frame_screenshots.swift
// Marketing frame generator for App Store screenshots.
//
// Usage:
//   swift scripts/frame_screenshots.swift <input_dir> <output_dir>
//
// Takes raw simulator screenshots and composites them with:
// - Headline text overlay (DM Sans Medium)
// - Flat rectangular device frame (no rounded corners, no shadows)
// - Background matching the app's light mode aesthetic
//
// Per DESIGN.md: 0pt border radius, no shadows, DM Sans Medium,
// International Style Minimalism.

import AppKit
import CoreGraphics
import CoreText
import Foundation

// MARK: - Configuration

/// Headlines for the 4 required screens (per D-07).
let headlines: [String: String] = [
    "Dashboard": "Know Your Readiness",
    "Recovery": "Recovery, Decoded",
    "Workload": "Track Training Load",
    "ActiveWorkout": "Log Every Rep"
]

/// Design tokens from DESIGN.md (light mode).
let bgColor = NSColor(red: 0xF4/255.0, green: 0xF1/255.0, blue: 0xED/255.0, alpha: 1.0) // --bg light
let textColor = NSColor(red: 0x1C/255.0, green: 0x19/255.0, blue: 0x15/255.0, alpha: 1.0) // --text-1 light
let dividerColor = NSColor(red: 0xCF/255.0, green: 0xCB/255.0, blue: 0xC5/255.0, alpha: 1.0) // --divider light

// MARK: - Font Loading

/// Load DM Sans Medium from the project's font bundle.
func loadDMSansMedium() -> CTFont? {
    let fontPaths = [
        "WorkloadApp/Resources/DMSans-Medium.ttf",
        "WorkloadApp/Resources/DMSans-Medium.otf"
    ]

    for path in fontPaths {
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: url.path) {
            var error: Unmanaged<CFError>?
            if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                if let font = CTFontCreateWithName("DMSans-Medium" as CFString, 48, nil) as CTFont? {
                    return font
                }
            }
        }
    }

    // Fallback: try system font registration
    let font = CTFontCreateWithName("DMSans-Medium" as CFString, 48, nil)
    let fontName = CTFontCopyPostScriptName(font) as String
    if fontName.contains("DMSans") {
        return font
    }

    // Final fallback: use Helvetica Neue Medium (similar geometric sans)
    print("Warning: DM Sans Medium not found, using Helvetica Neue Medium as fallback")
    return CTFontCreateWithName("HelveticaNeue-Medium" as CFString, 48, nil)
}

// MARK: - Screen Name Detection

/// Match a filename to one of the 4 required screens.
func detectScreenName(from filename: String) -> String? {
    let lower = filename.lowercased()
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
    headline: String,
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
    let headlineGap = 48.0 * scale       // xl
    let sidePadding = 32.0 * scale       // lg
    let bottomPadding = 32.0 * scale     // lg
    let frameBorderWidth = 1.0 * scale   // hairline

    // Font size scaled
    let fontSize = 28.0 * scale  // page title size from DESIGN.md
    let scaledFont = CTFontCreateCopyWithAttributes(baseFont, fontSize, nil, nil)

    // Measure headline text
    let attrString = NSAttributedString(
        string: headline,
        attributes: [
            .font: scaledFont,
            .foregroundColor: textColor
        ]
    )
    let textLine = CTLineCreateWithAttributedString(attrString)
    let textBounds = CTLineGetBoundsWithOptions(textLine, .useOpticalBounds)

    // Calculate screenshot area
    let screenshotX = sidePadding + frameBorderWidth
    let screenshotY = bottomPadding + frameBorderWidth
    let screenshotWidth = width - 2 * sidePadding - 2 * frameBorderWidth
    let headlineY = height - topPadding - textBounds.height
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

    // Draw device frame border (rectangle, no rounded corners per DESIGN.md)
    let frameRect = CGRect(
        x: sidePadding,
        y: bottomPadding,
        width: width - 2 * sidePadding,
        height: screenshotHeight + 2 * frameBorderWidth
    )
    context.setStrokeColor(dividerColor.cgColor)
    context.setLineWidth(frameBorderWidth)
    context.stroke(frameRect)

    // Draw screenshot inside frame
    if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
        let drawRect = CGRect(
            x: screenshotX,
            y: screenshotY,
            width: screenshotWidth,
            height: screenshotHeight
        )
        context.draw(cgImage, in: drawRect)
    }

    // Draw headline text (centered)
    let textX = (width - textBounds.width) / 2.0
    context.saveGState()
    context.textPosition = CGPoint(x: textX, y: headlineY - textBounds.height + CTFontGetDescent(scaledFont))
    CTLineDraw(textLine, context)
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

    // Create output directory
    try? FileManager.default.createDirectory(
        atPath: outputDir,
        withIntermediateDirectories: true
    )

    // Load font
    guard let baseFont = loadDMSansMedium() else {
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

        guard let headline = headlines[screenName] else {
            print("Skipping \(filename) (no headline for \(screenName))")
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

        print("Framing \(screenName) (\(Int(pixelWidth))x\(Int(pixelHeight))): \"\(headline)\"")

        guard let framedImage = frameScreenshot(
            image: image,
            headline: headline,
            baseFont: baseFont,
            outputSize: outputSize
        ) else {
            print("Error: framing failed for \(filename)")
            continue
        }

        // Save as PNG
        let outputFilename = "\(screenName)_framed.png"
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
