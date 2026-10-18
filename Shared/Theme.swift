import SwiftUI

#if os(iOS)
import UIKit
#else
import AppKit
#endif

// MARK: - Palette

/// Flat, paper and ink. Every surface is one solid colour; no gradients anywhere.
enum Theme {
    static var canvas: Color { .dynamic(light: 0xF5F0E6, dark: 0x14120F) }
    static var surface: Color { .dynamic(light: 0xFBF7EE, dark: 0x1E1B17) }
    static var surfaceSunken: Color { .dynamic(light: 0xEDE6D7, dark: 0x100E0C) }
    static var ink: Color { .dynamic(light: 0x16201B, dark: 0xF3EEE4) }
    static var inkSoft: Color { .dynamic(light: 0x6B6858, dark: 0xA39D90) }
    static var line: Color { .dynamic(light: 0xE0D8C6, dark: 0x2C2822) }
    static var moss: Color { .dynamic(light: 0x1F3D33, dark: 0x35705E) }
    static var tomato: Color { .dynamic(light: 0xBB4128, dark: 0xE27052) }
    static var butter: Color { .dynamic(light: 0xC9992A, dark: 0xE4BE5A) }

    // MARK: Type

    /// Large serif display. New York on both platforms, so the voice is the same.
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }

    static func title(_ size: CGFloat = 20) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }

    static func body(_ size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    /// Numbers line up because they are monospaced everywhere they are counted.
    static func number(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    // MARK: Metrics

    static let radius: CGFloat = 18
    static let gap: CGFloat = 14
    static let page: CGFloat = 20
}

// MARK: - Colour plumbing

extension Color {
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        #if os(iOS)
        return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
        })
        #else
        return Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(rgb: dark)
                : NSColor(rgb: light)
        })
        #endif
    }
}

#if os(iOS)
extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
#else
extension NSColor {
    convenience init(rgb: UInt32) {
        self.init(
            srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
#endif
