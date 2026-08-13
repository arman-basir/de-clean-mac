import SwiftUI

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

enum Theme {
    static let bg = Color(hex: "12161A")
    static let panel = Color(hex: "191F24")
    static let panel2 = Color(hex: "1E252B")
    static let line = Color(hex: "262E35")
    static let mint = Color(hex: "49D6C4")
    static let violet = Color(hex: "8B83F0")
    static let amber = Color(hex: "F0B84F")
    static let danger = Color(hex: "FF6B6B")
    static let text = Color(hex: "EAEEF1")
    static let muted = Color(hex: "8B96A1")
    static let mutedDim = Color(hex: "5D6770")
}
