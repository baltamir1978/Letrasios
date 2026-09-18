import SwiftUI

/// Central color tokens, taken from the app icon's emerald gradient. Every token resolves to a
/// light and a dark value, so `.primary`/`.secondary` text stays legible in both appearances.
///
/// Contrast, measured against WCAG 2.1 (recompute before changing any value):
/// - `brand` on `appBackground`: 5.7:1 light, 10.4:1 dark.
/// - `brand` on `surface`: 5.2:1 light, 8.8:1 dark.
/// - Glyphs sitting on `brand` use `appBackground`, which inverts with it (5.7:1 / 10.4:1).
///   Never white: on the dark variant (a light mint) white drops below 2:1.
extension Color {
    static let brand = Color(light: "#0B6F53", dark: "#4FD8A6")
    static let appBackground = Color(light: "#F2F8F5", dark: "#0A1411")
    static let surface = Color(light: "#E1F0EA", dark: "#14261F")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// A color that resolves to a different value in light vs. dark mode.
    init(light: String, dark: String) {
        self.init(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
    }
}
