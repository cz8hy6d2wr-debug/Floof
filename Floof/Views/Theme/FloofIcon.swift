import SwiftUI

/// Ein Floof-Symbol in fester Größe. `tile` legt es auf eine kleine dunkle Kachel
/// (in Hell und Dunkel gleich – wie das App-Icon), damit die cremefarbenen Motive immer tragen.
struct FloofIcon: View {
    let symbol: String
    var size: CGFloat = 24
    var tile = true
    /// Abstand des Symbols zum Kachelrand (Anteil der Symbolgröße).
    var inset: CGFloat = 0.24
    /// Farbe für den Rückfall auf ein SF-Symbol.
    var fallbackTint: Color = Theme.carrot

    var body: some View {
        Group {
            if let asset = FloofIconSet.asset(for: symbol) {
                Image(asset)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.62, weight: .semibold))
                    .foregroundStyle(fallbackTint)
                    .frame(width: size, height: size)
            }
        }
        .padding(tile ? size * inset : 0)
        .background {
            if tile { IconTileBackground(cornerRadius: size * 0.42) }
        }
        .accessibilityHidden(true)
    }
}

/// Dunkle, leicht von oben beleuchtete Kachel hinter einem Symbol.
struct IconTileBackground: View {
    var cornerRadius: CGFloat = 12

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(LinearGradient(colors: [Color(hex: 0x2E2621), Color(hex: 0x1A1512)],
                                 startPoint: .top, endPoint: .bottom))
            .overlay {
                shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.14), .white.opacity(0.03)],
                                                  startPoint: .top, endPoint: .bottom), lineWidth: 0.75)
            }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
