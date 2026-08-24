import AppKit

guard CommandLine.arguments.count == 2 else {
    fputs("usage: swift make_icon.swift OUTPUT.png\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let pixelSize = 1024
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixelSize,
    pixelsHigh: pixelSize,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fputs("failed to create bitmap context\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
defer { NSGraphicsContext.restoreGraphicsState() }

NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize).fill()

let tileRect = NSRect(x: 64, y: 64, width: 896, height: 896)
let tile = NSBezierPath(roundedRect: tileRect, xRadius: 210, yRadius: 210)
NSColor(calibratedRed: 0.075, green: 0.086, blue: 0.105, alpha: 1).setFill()
tile.fill()

let glow = NSBezierPath(ovalIn: NSRect(x: 650, y: 650, width: 210, height: 210))
NSColor(calibratedRed: 0.98, green: 0.62, blue: 0.08, alpha: 0.18).setFill()
glow.fill()

let barColors = [
    NSColor(calibratedRed: 0.04, green: 0.73, blue: 0.66, alpha: 1),
    NSColor(calibratedRed: 0.10, green: 0.52, blue: 0.96, alpha: 1),
    NSColor(calibratedRed: 0.98, green: 0.55, blue: 0.18, alpha: 1)
]
let heights: [CGFloat] = [250, 390, 560]

for index in 0..<3 {
    let rect = NSRect(x: 245 + CGFloat(index) * 175, y: 220, width: 115, height: heights[index])
    let bar = NSBezierPath(roundedRect: rect, xRadius: 52, yRadius: 52)
    barColors[index].setFill()
    bar.fill()
}

let baseline = NSBezierPath(roundedRect: NSRect(x: 190, y: 190, width: 645, height: 26), xRadius: 13, yRadius: 13)
NSColor.white.withAlphaComponent(0.82).setFill()
baseline.fill()

let ring = NSBezierPath(ovalIn: NSRect(x: 675, y: 675, width: 150, height: 150))
ring.lineWidth = 24
NSColor.white.withAlphaComponent(0.92).setStroke()
ring.stroke()

let dot = NSBezierPath(ovalIn: NSRect(x: 728, y: 728, width: 44, height: 44))
NSColor(calibratedRed: 0.98, green: 0.62, blue: 0.08, alpha: 1).setFill()
dot.fill()

context.flushGraphics()
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("failed to render icon\n", stderr)
    exit(1)
}

try png.write(to: outputURL)
