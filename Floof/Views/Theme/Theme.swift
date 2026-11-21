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

    // Schrift: modern und klar (SF Pro), Zahlen gerundet.
    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .bold) }
    static func number(_ style: Font.TextStyle) -> Font { .system(style, design: .rounded).weight(.bold).monospacedDigit() }

    /// Warmer Schimmer hinter dem Glas – eine einzige Farbe, nicht bunt.
    static let glow = Color(light: 0xEE8C50, dark: 0xF08A4B)
}

// MARK: - Hintergrund

/// Leuchtender Hintergrund im Stil von Lumy, aber zurückhaltend:
/// ein warmer Schimmer von oben, ein leiser Nachhall unten rechts.
struct AmbientBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Theme.paper
            RadialGradient(colors: [Theme.glow.opacity(scheme == .dark ? 0.40 : 0.42), .clear],
                           center: UnitPoint(x: 0.5, y: -0.12), startRadius: 0, endRadius: 520)
            RadialGradient(colors: [Theme.glow.opacity(scheme == .dark ? 0.12 : 0.14), .clear],
                           center: UnitPoint(x: 1.05, y: 1.05), startRadius: 0, endRadius: 420)
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Leuchtender Hintergrund hinter dem Inhalt.
    func ambientBackground() -> some View {
        background { AmbientBackground() }
    }

    /// Gläserne Fläche (Liquid Glass) für Inhaltsgruppen.
    func glassPanel(cornerRadius: CGFloat = 24) -> some View {
        glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
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

// MARK: - Seitentitel

/// Großer, klarer Seitentitel.
struct HandTitle: View {
    let text: String
    var size: CGFloat = 34

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .bold))
            .tracking(-0.4)
            .foregroundStyle(Theme.ink)
            .accessibilityAddTraits(.isHeader)
    }
}
