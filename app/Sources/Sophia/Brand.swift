import SwiftUI
import AppKit

/// The working identity. Reading and interface typography remain native.
enum Brand {
    static let plum = adaptive(light: 0x6E2F55, dark: 0xE3A9C8)
    static let onPlum = adaptive(light: 0xFFFFFF, dark: 0x16171A)
    static let selectionFill = plum.opacity(0.18)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: Double((value >> 16) & 255) / 255,
                           green: Double((value >> 8) & 255) / 255,
                           blue: Double(value & 255) / 255, alpha: 1)
        })
    }
}

struct BrandLockup: View {
    var body: some View {
        HStack(alignment: .center, spacing: 4.4) {
            BrandMark().fill(Brand.plum).frame(width: 20, height: 20)
            Text("Sophia")
                .font(NSFont(name: "Palatino-Roman", size: 13.3) != nil
                      ? .custom("Palatino-Roman", fixedSize: 13.3)
                      : .system(size: 13.3, design: .serif))
                .tracking(0.133).baselineOffset(-0.93)
                .foregroundStyle(.primary)
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sophia")
    }
}
