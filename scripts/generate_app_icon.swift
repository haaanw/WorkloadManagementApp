#!/usr/bin/env swift
//
// generate_app_icon.swift
// App icon generator — DESIGN.md v5 "Pavilion" (warm stone, travertine accent).
//
// Usage:
//   swift scripts/generate_app_icon.swift <output_dir> [variant]
//
// Variants:
//   scale  — horizontal tick scale with travertine needle (the TickScale signature)
//   gauge  — debossed circular well with travertine needle
//   slab   — the one precious material: raised travertine slab on stone
//   mark   — Instrument Sans "T" in ink with travertine needle accent
//
// Rules: opaque, no alpha, no shadows; relief via gradients + highlights only;
// exactly one travertine element per icon.

import AppKit
import CoreGraphics
import CoreText
import Foundation

let S: CGFloat = 1024

// v5 tokens
let stoneTop    = NSColor(red: 0xF6/255, green: 0xF5/255, blue: 0xF2/255, alpha: 1)
let stoneBottom = NSColor(red: 0xEC/255, green: 0xEB/255, blue: 0xE7/255, alpha: 1)
let ink         = NSColor(red: 0x1B/255, green: 0x1A/255, blue: 0x17/255, alpha: 1)
let tickMinor   = NSColor(red: 0x8B/255, green: 0x87/255, blue: 0x7F/255, alpha: 1)
let tickMajor   = NSColor(red: 0x63/255, green: 0x60/255, blue: 0x5A/255, alpha: 1)
let accent      = NSColor(red: 0x6F/255, green: 0x67/255, blue: 0x59/255, alpha: 1)
let accentDeep  = NSColor(red: 0x5F/255, green: 0x58/255, blue: 0x4C/255, alpha: 1)
let wellTop     = NSColor(red: 0xE5/255, green: 0xE3/255, blue: 0xDE/255, alpha: 1)
let wellBottom  = NSColor(red: 0xEE/255, green: 0xEC/255, blue: 0xE7/255, alpha: 1)
let hairline    = NSColor(red: 0xCC/255, green: 0xC9/255, blue: 0xC2/255, alpha: 1)

func makeContext() -> CGContext? {
    CGContext(
        data: nil, width: Int(S), height: Int(S),
        bitsPerComponent: 8, bytesPerRow: Int(S) * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )
}

func fillStone(_ ctx: CGContext) {
    let colors = [stoneTop.cgColor, stoneBottom.cgColor] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: S), end: CGPoint(x: 0, y: 0), options: [])
}

func fillVertical(_ ctx: CGContext, rect: CGRect, top: NSColor, bottom: NSColor, radius: CGFloat) {
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    let colors = [top.cgColor, bottom.cgColor] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: rect.maxY), end: CGPoint(x: 0, y: rect.minY), options: [])
    ctx.restoreGState()
}

func save(_ ctx: CGContext, to path: String) {
    guard let cg = ctx.makeImage() else { fatalError("makeImage failed") }
    let rep = NSBitmapImageRep(cgImage: cg)
    guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("png failed") }
    try? png.write(to: URL(fileURLWithPath: path))
    print("Saved: \(path)")
}

// MARK: scale — the TickScale signature

func drawScale(_ ctx: CGContext) {
    fillStone(ctx)
    let centerY = S / 2
    let tickCount = 17
    let spacing: CGFloat = 52
    let totalWidth = spacing * CGFloat(tickCount - 1)
    let startX = (S - totalWidth) / 2
    let needleIndex = 11   // ~71% of the scale — the readiness nod

    for i in 0..<tickCount {
        let x = startX + CGFloat(i) * spacing
        let isMajor = i % 4 == 0
        if i == needleIndex {
            // travertine needle — taller, heavier, with a soft top cap
            let w: CGFloat = 16
            let h: CGFloat = 340
            let rect = CGRect(x: x - w/2, y: centerY - h/2, width: w, height: h)
            fillVertical(ctx, rect: rect, top: accent, bottom: accentDeep, radius: w/2)
        } else {
            let w: CGFloat = isMajor ? 10 : 6
            let h: CGFloat = isMajor ? 200 : 120
            ctx.setFillColor((isMajor ? tickMajor : tickMinor).cgColor)
            let rect = CGRect(x: x - w/2, y: centerY - h/2, width: w, height: h)
            ctx.addPath(CGPath(roundedRect: rect, cornerWidth: w/2, cornerHeight: w/2, transform: nil))
            ctx.fillPath()
        }
    }
}

// MARK: gauge — debossed circular well + needle

func drawGauge(_ ctx: CGContext) {
    fillStone(ctx)
    let center = CGPoint(x: S/2, y: S/2)
    let radius: CGFloat = 330

    // debossed well: darker gradient pocket + inner top shade + bottom highlight
    let wellRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius*2, height: radius*2)
    ctx.saveGState()
    ctx.addEllipse(in: wellRect)
    ctx.clip()
    let colors = [wellTop.cgColor, wellBottom.cgColor] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: wellRect.maxY), end: CGPoint(x: 0, y: wellRect.minY), options: [])
    // inner top shade (the cut edge)
    ctx.setFillColor(ink.withAlphaComponent(0.07).cgColor)
    ctx.fill(CGRect(x: wellRect.minX, y: wellRect.maxY - 14, width: wellRect.width, height: 14))
    // bottom closing highlight
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.6).cgColor)
    ctx.fill(CGRect(x: wellRect.minX, y: wellRect.minY, width: wellRect.width, height: 8))
    ctx.restoreGState()
    // hairline rim
    ctx.setStrokeColor(hairline.cgColor)
    ctx.setLineWidth(3)
    ctx.strokeEllipse(in: wellRect)

    // ticks inside the well rim (12 o'clock to needle sweep suggestion — full ring, quiet)
    for i in 0..<48 {
        let angle = CGFloat(i) / 48 * 2 * .pi
        let isMajor = i % 4 == 0
        let outer = radius - 36
        let len: CGFloat = isMajor ? 56 : 32
        let inner = outer - len
        let p1 = CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer)
        let p2 = CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner)
        ctx.setStrokeColor((isMajor ? tickMajor : tickMinor).withAlphaComponent(isMajor ? 0.9 : 0.6).cgColor)
        ctx.setLineWidth(isMajor ? 8 : 5)
        ctx.setLineCap(.round)
        ctx.move(to: p1)
        ctx.addLine(to: p2)
        ctx.strokePath()
    }

    // travertine needle at "71" (about 1 o'clock, pointing up-right)
    let needleAngle: CGFloat = .pi * 0.32
    let needleLen = radius - 80
    let tip = CGPoint(x: center.x + cos(needleAngle) * needleLen, y: center.y + sin(needleAngle) * needleLen)
    let tail = CGPoint(x: center.x - cos(needleAngle) * 70, y: center.y - sin(needleAngle) * 70)
    ctx.setStrokeColor(accent.cgColor)
    ctx.setLineWidth(18)
    ctx.setLineCap(.round)
    ctx.move(to: tail)
    ctx.addLine(to: tip)
    ctx.strokePath()
    // center pivot
    ctx.setFillColor(accentDeep.cgColor)
    ctx.fillEllipse(in: CGRect(x: center.x - 26, y: center.y - 26, width: 52, height: 52))
}

// MARK: slab — the one precious material

func drawSlab(_ ctx: CGContext) {
    fillStone(ctx)
    let side: CGFloat = 400
    let rect = CGRect(x: (S - side)/2, y: (S - side)/2, width: side, height: side)
    let radius: CGFloat = 56   // 12pt corner law at icon scale
    // raised travertine slab: gradient + 2px top highlight, no shadow
    fillVertical(ctx, rect: rect, top: accent, bottom: accentDeep, radius: radius)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.clip()
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.35).cgColor)
    ctx.fill(CGRect(x: rect.minX, y: rect.maxY - 5, width: rect.width, height: 5))
    ctx.restoreGState()
    ctx.setStrokeColor(accentDeep.cgColor)
    ctx.setLineWidth(2)
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.strokePath()
}

// MARK: mark — Instrument Sans "T" + needle accent

func registerFont(at path: String) {
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: url.path) else { return }
    var error: Unmanaged<CFError>?
    CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
}

func drawMark(_ ctx: CGContext) {
    fillStone(ctx)
    registerFont(at: "WorkloadApp/Resources/Fonts/InstrumentSans-Medium.ttf")
    let font = NSFont(name: "InstrumentSans-Medium", size: 660) ?? NSFont.systemFont(ofSize: 660, weight: .medium)
    let str = NSAttributedString(string: "T", attributes: [.font: font, .foregroundColor: ink])
    let line = CTLineCreateWithAttributedString(str)
    let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
    ctx.saveGState()
    ctx.textPosition = CGPoint(x: (S - bounds.width)/2 - bounds.minX, y: (S - bounds.height)/2 - bounds.minY + 20)
    CTLineDraw(line, ctx)
    ctx.restoreGState()
    // travertine needle: a short vertical accent under the T's right arm — quiet, off-center
    let w: CGFloat = 16
    let h: CGFloat = 150
    let rect = CGRect(x: S/2 + 190 - w/2, y: (S - bounds.height)/2 - 40, width: w, height: h)
    fillVertical(ctx, rect: rect, top: accent, bottom: accentDeep, radius: w/2)
}

// MARK: - Main

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("Usage: swift scripts/generate_app_icon.swift <output_dir> [scale|gauge|slab|mark|all]")
    exit(1)
}
let outDir = args[1]
let which = args.count >= 3 ? args[2] : "all"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let variants: [(String, (CGContext) -> Void)] = [
    ("scale", drawScale), ("gauge", drawGauge), ("slab", drawSlab), ("mark", drawMark)
]
for (name, draw) in variants where which == "all" || which == name {
    guard let ctx = makeContext() else { fatalError("context failed") }
    draw(ctx)
    save(ctx, to: "\(outDir)/AppIcon-v5-\(name).png")
}
