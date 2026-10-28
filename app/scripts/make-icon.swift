import AppKit
import SwiftUI

/// Compile with BrandMarkPath.swift; generate iconset files in an owned scratch directory.
/// The checked-in .icns is a replaceable implementation treatment, not another user lock.
@main
struct MakeIcon {
    static func main() throws {
        guard CommandLine.arguments.count == 3 else {
            fatalError("Usage: make-icon <owned .iconset directory> <output .icns>")
        }
        let iconset = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let output = URL(fileURLWithPath: CommandLine.arguments[2])
        try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        for size in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let pixels = size * scale
                guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
                      let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else { fatalError("Bitmap unavailable") }
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = graphics
                let context = graphics.cgContext
                context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
                context.setFillColor(NSColor.white.cgColor)
                context.addPath(CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824),
                                       cornerWidth: 185, cornerHeight: 185, transform: nil))
                context.fillPath()
                let markScale: CGFloat = 3.6
                context.translateBy(x: 512 - 100 * markScale, y: 512 + 100 * markScale)
                context.scaleBy(x: markScale, y: -markScale)
                context.setFillColor(NSColor(srgbRed: 110.0/255, green: 47.0/255, blue: 85.0/255, alpha: 1).cgColor)
                context.addPath(BrandMark.unitPath.cgPath)
                context.fillPath()
                context.flush()
                NSGraphicsContext.restoreGraphicsState()
                let suffix = scale == 2 ? "@2x" : ""
                guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("PNG unavailable") }
                try png.write(to: iconset.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
            }
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        process.arguments = ["-c", "icns", iconset.path, "-o", output.path]
        try process.run(); process.waitUntilExit()
        guard process.terminationStatus == 0 else { fatalError("iconutil failed") }
    }
}
