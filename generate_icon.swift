#!/usr/bin/swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let cs = CGColorSpaceCreateDeviceRGB()
let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

func makeContext() -> CGContext {
    let ctx = CGContext(data: nil, width: size, height: size,
                        bitsPerComponent: 8, bytesPerRow: size * 4,
                        space: cs, bitmapInfo: bitmapInfo)!
    // Flip to screen coordinates: origin top-left, y increases downward
    ctx.translateBy(x: 0, y: CGFloat(size))
    ctx.scaleBy(x: 1, y: -1)
    return ctx
}

func savePNG(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    print("Saved: \(path)")
}

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: a)
}

// Draws the pin shape centred horizontally, with the head near the top
func drawPin(ctx: CGContext, pinFill: CGColor, innerFill: CGColor) {
    let w = CGFloat(size)

    // Pin head — a circle near the top third
    let headR: CGFloat = 210
    let headCX = w / 2
    let headCY: CGFloat = 390          // top of pin head region
    let tipY:   CGFloat = 755          // sharp tip at the bottom

    // 1 — Draw head circle
    ctx.setFillColor(pinFill)
    ctx.fillEllipse(in: CGRect(x: headCX - headR, y: headCY - headR,
                               width: headR * 2, height: headR * 2))

    // 2 — Draw tail as a smooth teardrop path
    let tailHW: CGFloat = headR * 0.65          // half-width at the shoulder
    let shoulderY = headCY + headR * 0.74       // where the tail starts on the circle

    let path = CGMutablePath()
    path.move(to: CGPoint(x: headCX, y: tipY))
    // left curve: tip → left shoulder
    path.addCurve(to: CGPoint(x: headCX - tailHW, y: shoulderY),
                  control1: CGPoint(x: headCX - tailHW * 0.42, y: tipY - (tipY - shoulderY) * 0.22),
                  control2: CGPoint(x: headCX - tailHW, y: tipY - (tipY - shoulderY) * 0.72))
    // across the shoulder
    path.addLine(to: CGPoint(x: headCX + tailHW, y: shoulderY))
    // right curve: right shoulder → tip
    path.addCurve(to: CGPoint(x: headCX, y: tipY),
                  control1: CGPoint(x: headCX + tailHW, y: tipY - (tipY - shoulderY) * 0.72),
                  control2: CGPoint(x: headCX + tailHW * 0.42, y: tipY - (tipY - shoulderY) * 0.22))
    path.closeSubpath()

    ctx.addPath(path)
    ctx.setFillColor(pinFill)
    ctx.fillPath()

    // 3 — Inner dot (creates the "eye" of the pin)
    let innerR: CGFloat = 86
    ctx.setFillColor(innerFill)
    ctx.fillEllipse(in: CGRect(x: headCX - innerR, y: headCY - innerR,
                               width: innerR * 2, height: innerR * 2))
}

// ── Light icon ────────────────────────────────────────────────────────────────
func makeLight() -> CGImage {
    let ctx = makeContext()
    let w = CGFloat(size)

    let grad = CGGradient(
        colorsSpace: cs,
        colors: [rgb(0.267, 0.188, 0.780),   // #4430C7 deep indigo
                 rgb(0.388, 0.631, 0.957)] as CFArray, // #6392F4 cornflower
        locations: [0, 1])!
    // top-left → bottom-right in screen coords
    ctx.drawLinearGradient(grad,
                           start: CGPoint(x: 0, y: 0),
                           end:   CGPoint(x: w, y: w),
                           options: [])

    drawPin(ctx: ctx,
            pinFill:  rgb(1, 1, 1, 0.97),
            innerFill: rgb(0.267, 0.188, 0.780))
    return ctx.makeImage()!
}

// ── Dark icon ─────────────────────────────────────────────────────────────────
func makeDark() -> CGImage {
    let ctx = makeContext()
    let w = CGFloat(size)

    let grad = CGGradient(
        colorsSpace: cs,
        colors: [rgb(0.067, 0.055, 0.157),   // #110E28 near-black navy
                 rgb(0.133, 0.106, 0.286)] as CFArray, // #221B49 dark violet
        locations: [0, 1])!
    ctx.drawLinearGradient(grad,
                           start: CGPoint(x: 0, y: 0),
                           end:   CGPoint(x: w, y: w),
                           options: [])

    drawPin(ctx: ctx,
            pinFill:  rgb(0.671, 0.561, 1.0),   // #AB8FFF soft lavender
            innerFill: rgb(0.067, 0.055, 0.157))
    return ctx.makeImage()!
}

// ── Tinted icon (grayscale — system applies brand tint) ───────────────────────
func makeTinted() -> CGImage {
    let ctx = makeContext()
    let w = CGFloat(size)

    // Light neutral background so the system can colour it
    ctx.setFillColor(rgb(0.95, 0.95, 0.96))
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: w))

    drawPin(ctx: ctx,
            pinFill:  rgb(0.18, 0.18, 0.20),
            innerFill: rgb(0.95, 0.95, 0.96))
    return ctx.makeImage()!
}

// ── Generate & save ───────────────────────────────────────────────────────────
let base = "/Users/aditya/Desktop/InstaMapPin/InstaMapPin/Assets.xcassets/AppIcon.appiconset/"

savePNG(makeLight(),   to: base + "AppIcon-Light.png")
savePNG(makeDark(),    to: base + "AppIcon-Dark.png")
savePNG(makeTinted(),  to: base + "AppIcon-Tinted.png")
print("All icons generated.")
