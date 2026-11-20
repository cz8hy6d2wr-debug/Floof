import SwiftUI
import UIKit

/// Eigenes, warmes Farbsystem statt System-Grau.
/// Jede Farbe hat eine bewusst gewählte Hell- und Dunkelvariante –
/// Dunkel ist kein invertiertes Hell: OLED-Schwarz als Grund, warme Akzente darauf.
enum Theme {
    // Flächen – Dunkel = echtes OLED-Schwarz (Pixel aus, spart Akku),
    // Karten heben sich nur minimal und warm davon ab.
    static let paper   = Color(light: 0xF6F1E8, dark: 0x000000)   // Hintergrund
    static let card    = Color(light: 0xFFFCF6, dark: 0x141210)   // Karten
    static let sunken  = Color(light: 0xEDE5D8, dark: 0x221F1C)   // Badges, Ringspur
    static let hairline = Color(light: 0xE4DACB, dark: 0x2B2723)

    // Text
    static let ink     = Color(light: 0x2B2622, dark: 0xF1EADF)
    static let inkSoft = Color(light: 0x7A6F64, dark: 0xA89D90)

    // Akzente
    static let carrot  = Color(light: 0xD9682B, dark: 0xF08A4B)   // Hauptakzent, Möhren-Punkte
    static let leaf    = Color(light: 0x4F7D3A, dark: 0x8BBF6E)   // erledigt
    static let leafWash = Color(light: 0xE6EEDB, dark: 0x16200F)
    static let berry   = Color(light: 0xB8434E, dark: 0xE77C86)   // Erkrankungen, überfällig
    static let honey   = Color(light: 0xC99A2E, dark: 0xE8C064)   // beobachten, Serie

    // Schrift: Überschriften in New York (Serif), Zahlen gerundet.
    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .serif) }
    static func number(_ style: Font.TextStyle) -> Font { .system(style, design: .rounded).weight(.bold).monospacedDigit() }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }
}

// MARK: - Handgemachte Details

/// Leicht unregelmäßige Wellenlinie – wie mit dem Stift unterstrichen.
struct Scribble: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let y = rect.midY
        p.move(to: CGPoint(x: rect.minX, y: y + 1))
        p.addCurve(to: CGPoint(x: rect.width * 0.45, y: y - 1.5),
                   control1: CGPoint(x: rect.width * 0.15, y: y - 3),
                   control2: CGPoint(x: rect.width * 0.3, y: y + 2.5))
        p.addCurve(to: CGPoint(x: rect.maxX, y: y - 2),
                   control1: CGPoint(x: rect.width * 0.65, y: y - 4),
                   control2: CGPoint(x: rect.width * 0.85, y: y + 2))
        return p
    }
}

/// Seitentitel in Serif mit handgezogener Unterstreichung.
struct HandTitle: View {
    let text: String
    var size: CGFloat = 34

    var body: some View {
        Text(text)
            .font(Theme.title(size))
            .foregroundStyle(Theme.ink)
            .background(alignment: .bottomLeading) {
                Scribble()
                    .stroke(Theme.carrot, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(height: 8)
                    .offset(y: 6)
                    .padding(.trailing, -6)
            }
            .accessibilityAddTraits(.isHeader)
    }
}
