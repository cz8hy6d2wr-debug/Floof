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

/// Indirekt beleuchteter Hintergrund – wie eine Schrank- oder Taschenlampe von oben:
/// ein warmer Lichtkegel fällt von oben mittig nach unten, die Ränder liegen im Halbschatten.
struct AmbientBackground: View {
    @Environment(\.colorScheme) private var scheme

    private var dark: Bool { scheme == .dark }
    /// Grundton: im Hellen etwas tiefer, damit das Licht darauf wirken kann.
    private var base: Color { dark ? .black : Color(red: 0.91, green: 0.88, blue: 0.83) }
    /// Lichtfarbe: warmes Glühbirnenlicht (dunkel) bzw. warmes Weiß (hell).
    private var light: Color { dark ? Color(red: 1.0, green: 0.70, blue: 0.42) : Color(red: 1.0, green: 0.97, blue: 0.91) }

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            ZStack {
                base

                // Licht wird EINMAL gezeichnet (drawingGroup) und beim Neigen nur verschoben.
                // Die Lichtfläche ist deutlich breiter als der Bildschirm, damit beim
                // Verschieben nie ihr Rand sichtbar wird.
                MovingLight(width: w, height: h) {
                    let lw = w * 1.8   // Breite der Lichtfläche
                    ZStack {
                        // Lichtkegel: oben schmal, nach unten breiter und schwächer.
                        Path { path in
                            path.move(to: CGPoint(x: lw / 2 - w * 0.14, y: -h * 0.05))
                            path.addLine(to: CGPoint(x: lw / 2 + w * 0.14, y: -h * 0.05))
                            path.addLine(to: CGPoint(x: lw / 2 + w * 0.65, y: h * 0.85))
                            path.addLine(to: CGPoint(x: lw / 2 - w * 0.65, y: h * 0.85))
                            path.closeSubpath()
                        }
                        .fill(LinearGradient(colors: [light.opacity(dark ? 0.30 : 0.95), light.opacity(0)],
                                             startPoint: .top, endPoint: .bottom))
                        .blur(radius: 50)

                        // Die "Lampe": heller Punkt oben mittig mit weichem Hof.
                        RadialGradient(colors: [light.opacity(dark ? 0.55 : 1.0), light.opacity(0)],
                                       center: UnitPoint(x: 0.5, y: -0.03),
                                       startRadius: 0, endRadius: min(w, h) * 0.75)

                        // Wärme im Licht (auch im Hellen ein Hauch Bernstein).
                        RadialGradient(colors: [Theme.glow.opacity(dark ? 0.22 : 0.16), .clear],
                                       center: UnitPoint(x: 0.5, y: 0.0),
                                       startRadius: 0, endRadius: min(w, h) * 0.9)
                    }
                    .frame(width: lw, height: h)
                    .drawingGroup()
                }

                // Halbschatten an Rändern und unten – statisch.
                RadialGradient(colors: [.clear, .black.opacity(dark ? 0.55 : 0.10)],
                               center: UnitPoint(x: 0.5, y: 0.25),
                               startRadius: min(w, h) * 0.45, endRadius: max(w, h) * 0.95)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Verschiebt das fertig gezeichnete Licht passend zur Neigung des iPhones.
/// Nur diese kleine Ansicht hängt am Bewegungssensor – nicht der ganze Bildschirm.
private struct MovingLight<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let width: CGFloat
    let height: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        let tilt = reduceMotion ? .zero : LightSource.shared.offset
        content
            .position(x: width / 2 + tilt.x * width * 0.16, y: height / 2 + tilt.y * height * 0.03)
            .frame(width: width, height: height)
            .clipped()
    }
}

extension View {
    /// Indirekt beleuchteter Hintergrund hinter dem Inhalt.
    func ambientBackground() -> some View {
        background { AmbientBackground() }
    }

    /// Gläserne Fläche (Liquid Glass), von oben beleuchtet:
    /// feine Lichtkante oben, weicher Schatten nach unten.
    func glassPanel(cornerRadius: CGFloat = 24) -> some View {
        modifier(LitGlass(cornerRadius: cornerRadius))
    }
}

private struct LitGlass: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .glassEffect(.regular, in: shape)
            .overlay {
                // Feste Lichtkante oben – hängt bewusst nicht am Bewegungssensor (flüssiger).
                shape.strokeBorder(
                    LinearGradient(colors: [.white.opacity(scheme == .dark ? 0.28 : 0.85), .white.opacity(0)],
                                   startPoint: .top, endPoint: .center),
                    lineWidth: 1)
                .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(scheme == .dark ? 0.45 : 0.08), radius: 12, x: 0, y: 8)
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
