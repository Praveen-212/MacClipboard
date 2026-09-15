import AppKit
import CoreGraphics

func createIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let scale = size / 1024.0

    // Background Canvas
    ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))

    // macOS Standard Squircle Path (Base 1024: inset 80, size 864, corner 192)
    let squircleRect = CGRect(x: 80 * scale, y: 80 * scale, width: 864 * scale, height: 864 * scale)
    let squircleCorner = 192 * scale
    let squirclePath = CGPath(roundedRect: squircleRect, cornerWidth: squircleCorner, cornerHeight: squircleCorner, transform: nil)

    // Outer Drop Shadow for App Tile
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12 * scale), blur: 24 * scale, color: CGColor(gray: 0.0, alpha: 0.35))
    ctx.setFillColor(CGColor(red: 0.08, green: 0.12, blue: 0.22, alpha: 1.0))
    ctx.addPath(squirclePath)
    ctx.fillPath()
    ctx.restoreGState()

    // Squircle Clip & Gradient Background
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        CGColor(red: 0.16, green: 0.38, blue: 0.95, alpha: 1.0), // Royal Blue
        CGColor(red: 0.09, green: 0.18, blue: 0.55, alpha: 1.0), // Deep Navy
        CGColor(red: 0.06, green: 0.10, blue: 0.28, alpha: 1.0)  // Midnight Blue
    ] as CFArray
    let bgLocations: [CGFloat] = [0.0, 0.65, 1.0]
    if let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: bgLocations) {
        ctx.drawLinearGradient(bgGradient,
                               start: CGPoint(x: squircleRect.midX, y: squircleRect.maxY),
                               end: CGPoint(x: squircleRect.midX, y: squircleRect.minY),
                               options: [])
    }

    // Inner Specular Border Highlight
    ctx.setLineWidth(3.0 * scale)
    ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.25))
    ctx.addPath(squirclePath)
    ctx.strokePath()

    // Subtle Radial Glow behind clipboard
    if let glowGradient = CGGradient(colorsSpace: colorSpace, colors: [
        CGColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.35),
        CGColor(red: 0.1, green: 0.2, blue: 0.6, alpha: 0.0)
    ] as CFArray, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(glowGradient,
                               startCenter: CGPoint(x: 512 * scale, y: 550 * scale), startRadius: 0,
                               endCenter: CGPoint(x: 512 * scale, y: 550 * scale), endRadius: 360 * scale,
                               options: [])
    }

    // Clipboard Wooden/Graphite Board
    let boardRect = CGRect(x: 232 * scale, y: 170 * scale, width: 560 * scale, height: 680 * scale)
    let boardPath = CGPath(roundedRect: boardRect, cornerWidth: 36 * scale, cornerHeight: 36 * scale, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10 * scale), blur: 18 * scale, color: CGColor(gray: 0, alpha: 0.4))
    let boardColors = [
        CGColor(red: 0.22, green: 0.25, blue: 0.32, alpha: 1.0),
        CGColor(red: 0.14, green: 0.16, blue: 0.22, alpha: 1.0)
    ] as CFArray
    if let boardGradient = CGGradient(colorsSpace: colorSpace, colors: boardColors, locations: [0.0, 1.0]) {
        ctx.addPath(boardPath)
        ctx.clip()
        ctx.drawLinearGradient(boardGradient,
                               start: CGPoint(x: boardRect.midX, y: boardRect.maxY),
                               end: CGPoint(x: boardRect.midX, y: boardRect.minY),
                               options: [])
    }
    ctx.restoreGState()

    // Board Border Stroke
    ctx.saveGState()
    ctx.setLineWidth(2 * scale)
    ctx.setStrokeColor(CGColor(red: 0.4, green: 0.45, blue: 0.55, alpha: 0.6))
    ctx.addPath(boardPath)
    ctx.strokePath()
    ctx.restoreGState()

    // Clean Paper Sheet
    let paperRect = CGRect(x: 272 * scale, y: 200 * scale, width: 480 * scale, height: 600 * scale)
    let paperPath = CGPath(roundedRect: paperRect, cornerWidth: 16 * scale, cornerHeight: 16 * scale, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -4 * scale), blur: 10 * scale, color: CGColor(gray: 0, alpha: 0.25))
    let paperColors = [
        CGColor(red: 0.99, green: 0.99, blue: 1.0, alpha: 1.0),
        CGColor(red: 0.92, green: 0.94, blue: 0.97, alpha: 1.0)
    ] as CFArray
    if let paperGradient = CGGradient(colorsSpace: colorSpace, colors: paperColors, locations: [0.0, 1.0]) {
        ctx.addPath(paperPath)
        ctx.clip()
        ctx.drawLinearGradient(paperGradient,
                               start: CGPoint(x: paperRect.midX, y: paperRect.maxY),
                               end: CGPoint(x: paperRect.midX, y: paperRect.minY),
                               options: [])
    }
    ctx.restoreGState()

    // Paper Content Lines (representing text clippings)
    ctx.saveGState()
    let lineColors: [CGColor] = [
        CGColor(red: 0.25, green: 0.45, blue: 0.85, alpha: 0.8), // Accent line (title)
        CGColor(red: 0.65, green: 0.70, blue: 0.78, alpha: 0.7),
        CGColor(red: 0.65, green: 0.70, blue: 0.78, alpha: 0.7),
        CGColor(red: 0.65, green: 0.70, blue: 0.78, alpha: 0.5),
        CGColor(red: 0.65, green: 0.70, blue: 0.78, alpha: 0.7),
        CGColor(red: 0.65, green: 0.70, blue: 0.78, alpha: 0.4)
    ]
    let lineYs: [CGFloat] = [660, 590, 530, 470, 410, 350]
    let lineWidths: [CGFloat] = [280, 400, 360, 260, 390, 200]

    for (i, yBase) in lineYs.enumerated() {
        let y = yBase * scale
        let w = lineWidths[i] * scale
        let h = (i == 0 ? 14 : 10) * scale
        let lineRect = CGRect(x: 312 * scale, y: y, width: w, height: h)
        let linePath = CGPath(roundedRect: lineRect, cornerWidth: h / 2, cornerHeight: h / 2, transform: nil)
        ctx.setFillColor(lineColors[i])
        ctx.addPath(linePath)
        ctx.fillPath()
    }
    ctx.restoreGState()

    // Metallic Clip Base on top of paper
    let clipBaseRect = CGRect(x: 392 * scale, y: 760 * scale, width: 240 * scale, height: 100 * scale)
    let clipBasePath = CGPath(roundedRect: clipBaseRect, cornerWidth: 16 * scale, cornerHeight: 16 * scale, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6 * scale), blur: 12 * scale, color: CGColor(gray: 0, alpha: 0.35))
    let metalColors = [
        CGColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1.0),
        CGColor(red: 0.70, green: 0.74, blue: 0.80, alpha: 1.0),
        CGColor(red: 0.55, green: 0.58, blue: 0.65, alpha: 1.0)
    ] as CFArray
    if let metalGradient = CGGradient(colorsSpace: colorSpace, colors: metalColors, locations: [0.0, 0.5, 1.0]) {
        ctx.addPath(clipBasePath)
        ctx.clip()
        ctx.drawLinearGradient(metalGradient,
                               start: CGPoint(x: clipBaseRect.midX, y: clipBaseRect.maxY),
                               end: CGPoint(x: clipBaseRect.midX, y: clipBaseRect.minY),
                               options: [])
    }
    ctx.restoreGState()

    // Metallic Clip Ring / Fastener
    let clipRingRect = CGRect(x: 462 * scale, y: 830 * scale, width: 100 * scale, height: 60 * scale)
    let clipRingPath = CGPath(roundedRect: clipRingRect, cornerWidth: 20 * scale, cornerHeight: 20 * scale, transform: nil)
    ctx.saveGState()
    ctx.setLineWidth(14 * scale)
    ctx.setStrokeColor(CGColor(red: 0.85, green: 0.88, blue: 0.92, alpha: 1.0))
    ctx.addPath(clipRingPath)
    ctx.strokePath()
    ctx.restoreGState()

    // Favorite Star Accent in lower right
    let starCenter = CGPoint(x: 680 * scale, y: 260 * scale)
    let starRadius = 42 * scale
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -2 * scale), blur: 6 * scale, color: CGColor(red: 0.9, green: 0.6, blue: 0.1, alpha: 0.5))
    ctx.setFillColor(CGColor(red: 0.98, green: 0.75, blue: 0.18, alpha: 1.0)) // Golden Yellow
    let starPath = CGMutablePath()
    let points = 5
    for i in 0..<(points * 2) {
        let r = i % 2 == 0 ? starRadius : starRadius * 0.45
        let angle = CGFloat(i) * CGFloat.pi / CGFloat(points) - CGFloat.pi / 2
        let pt = CGPoint(x: starCenter.x + r * cos(angle), y: starCenter.y + r * sin(angle))
        if i == 0 {
            starPath.move(to: pt)
        } else {
            starPath.addLine(to: pt)
        }
    }
    starPath.closeSubpath()
    ctx.addPath(starPath)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.restoreGState() // Pop Squircle Clip

    image.unlockFocus()
    return image
}

func savePNG(image: NSImage, path: String) {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        print("❌ Failed to create PNG for \(path)")
        return
    }
    try? png.write(to: URL(fileURLWithPath: path))
    print("✅ Generated: \(path)")
}

let iconSetPath = "ClipboardLibrary/Assets.xcassets/AppIcon.appiconset"

let iconSizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (fileName, size) in iconSizes {
    let img = createIcon(size: size)
    let fullPath = "\(iconSetPath)/\(fileName)"
    savePNG(image: img, path: fullPath)
}
print("🎉 All icons created successfully.")
