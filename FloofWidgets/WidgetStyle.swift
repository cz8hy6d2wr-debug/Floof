import SwiftUI
import WidgetKit

/// Farben und Bausteine der Widgets – dieselbe Palette wie die App.
enum WStyle {
    static let ink = Color(light: 0x2A1D15, dark: 0xF3E9DC)
    static let soft = Color(light: 0x7D6B5B, dark: 0xA89886)
    static let carrot = Color(light: 0xC9642A, dark: 0xE0864A)
    static let leaf = Color(light: 0x5E7F48, dark: 0x9DB58A)
    static let berry = Color(light: 0xB0434B, dark: 0xE27C82)
    static let hair = Color(light: 0x2A1D15, dark: 0xF3E9DC).opacity(0.09)

    static func serif(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .serif)
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

/// Warmer Hintergrund mit Licht von oben – wie im App-Icon.
struct WidgetBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            LinearGradient(colors: scheme == .dark ? [Color(red: 0.11, green: 0.09, blue: 0.075), .black]
                                                   : [Color(red: 1, green: 0.985, blue: 0.96), Color(red: 0.95, green: 0.92, blue: 0.87)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color(red: 0.93, green: 0.55, blue: 0.31).opacity(scheme == .dark ? 0.30 : 0.16), .clear],
                           center: UnitPoint(x: 0.5, y: -0.15), startRadius: 0, endRadius: 220)
        }
    }
}

/// Kleiner Abschnitts-Titel in Versalien mit Symbol.
struct WCaption: View {
    let text: String
    var symbol: String?
    var color: Color = WStyle.soft

    var body: some View {
        HStack(spacing: 5) {
            if let symbol { WIcon(symbol: symbol, size: 13) }
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(color)
                .lineLimit(1)
        }
    }
}

/// Floof-Symbol aus dem Asset-Katalog (Rückfall: SF Symbol).
struct WIcon: View {
    let symbol: String
    var size: CGFloat = 18
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        if let asset = FloofIconSet.asset(for: symbol) {
            Image(asset)
                .resizable()
                .widgetAccentedRenderingMode(.fullColor)
                .scaledToFit()
                .frame(width: size, height: size)
                .opacity(renderingMode == .fullColor ? 1 : 0.9)
        } else {
            Image(systemName: symbol)
                .font(.system(size: size * 0.7, weight: .semibold))
                .foregroundStyle(WStyle.carrot)
                .frame(width: size, height: size)
        }
    }
}

/// Symbol auf kleiner dunkler Kachel.
struct WIconTile: View {
    let symbol: String
    var size: CGFloat = 18

    var body: some View {
        WIcon(symbol: symbol, size: size)
            .padding(size * 0.26)
            .background(
                RoundedRectangle(cornerRadius: size * 0.45, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.18, green: 0.15, blue: 0.13), Color(red: 0.10, green: 0.08, blue: 0.07)],
                                         startPoint: .top, endPoint: .bottom))
            )
    }
}

/// Fortschrittsring.
struct WRing: View {
    let progress: Double
    var lineWidth: CGFloat = 5

    var body: some View {
        ZStack {
            Circle().stroke(WStyle.ink.opacity(0.12), lineWidth: lineWidth)
            Circle().trim(from: 0, to: max(0.02, min(progress, 1)))
                .stroke(progress >= 1 ? WStyle.leaf : WStyle.carrot,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

/// Kreis zum Abhaken.
struct WCheck: View {
    let done: Bool
    var size: CGFloat = 22

    var body: some View {
        ZStack {
            Circle().strokeBorder(done ? WStyle.leaf : WStyle.ink.opacity(0.3), lineWidth: 1.5)
            if done {
                Circle().fill(WStyle.leaf)
                Image(systemName: "checkmark").font(.system(size: size * 0.5, weight: .heavy)).foregroundStyle(.black.opacity(0.75))
            }
        }
        .frame(width: size, height: size)
    }
}

/// Hinweis, wenn noch keine Daten da sind (App noch nicht geöffnet, keine App-Gruppe).
struct WOpenApp: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image("FloofMark").resizable().scaledToFit().frame(width: 30, height: 30).foregroundStyle(WStyle.ink)
            Spacer(minLength: 0)
            Text("Floof öffnen").font(WStyle.serif(17, .semibold)).foregroundStyle(WStyle.ink)
            Text("Dann erscheint hier dein Tag.").font(.caption).foregroundStyle(WStyle.soft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
