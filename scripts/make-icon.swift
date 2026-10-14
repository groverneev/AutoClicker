// Renders the app icon into an asset catalog.
// Usage: swift scripts/make-icon.swift AutoClicker/Assets.xcassets/AppIcon.appiconset
import AppKit

let outputDir = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

func renderIcon(pixels: Int) -> Data {
    let size = CGFloat(pixels)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // macOS icon grid: 824/1024 body with ~22% corner radius.
    let inset = size * 100 / 1024
    let body = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let radius = body.width * 0.225
    let path = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)

    let shadow = NSShadow()
    shadow.shadowColor = .black.withAlphaComponent(0.3)
    shadow.shadowBlurRadius = size * 0.02
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.01)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    NSColor.black.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(starting: NSColor(srgbRed: 0.33, green: 0.62, blue: 1.0, alpha: 1),
               ending: NSColor(srgbRed: 0.12, green: 0.30, blue: 0.85, alpha: 1))!
        .draw(in: path, angle: -90)

    let config = NSImage.SymbolConfiguration(pointSize: size * 0.42, weight: .semibold)
        .applying(.init(paletteColors: [.white]))
    if let symbol = NSImage(systemSymbolName: "cursorarrow.click.2", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let s = symbol.size
        symbol.draw(in: NSRect(x: (size - s.width) / 2 + size * 0.02, y: (size - s.height) / 2,
                               width: s.width, height: s.height))
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try renderIcon(pixels: points * scale).write(to: outputDir.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
    }
}

let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: outputDir.appendingPathComponent("Contents.json"))

let catalogContents = outputDir.deletingLastPathComponent().appendingPathComponent("Contents.json")
try #"{ "info" : { "author" : "xcode", "version" : 1 } }"#.write(to: catalogContents, atomically: true, encoding: .utf8)
print("Wrote \(images.count) icon images to \(outputDir.path)")
