import SwiftUI

/// Eigene, gezeichnete Floof-Symbole (Assets "fi.*") statt Standard-SF-Symbols.
/// Die Modelle liefern weiterhin SF-Symbol-Namen; hier wird übersetzt.
/// Für Namen ohne eigenes Motiv fällt die Ansicht auf das SF-Symbol zurück.
enum FloofIconSet {
    static func asset(for symbol: String) -> String? {
        switch symbol {
        case "pills", "pills.fill", "takeoutbag.and.cup.and.straw.fill": "fi.tablette"
        case "drop.fill", "eyedropper.halffull", "cross.vial", "cross.vial.fill", "checkmark.circle.fill": "fi.pipette"
        case "syringe", "syringe.fill": "fi.spritze"
        case "cross.case", "cross.case.fill", "shippingbox.fill": "fi.schrank"
        case "scalemass", "scalemass.fill": "fi.wiegen"
        case "scissors": "fi.krallen"
        case "mouth", "mouth.fill": "fi.zaehne"
        case "sparkles": "fi.fell"
        case "fork.knife", "leaf", "leaf.fill": "fi.heu"
        case "circle.grid.2x2.fill": "fi.koettel"
        case "hare.fill", "eye", "figure.run": "fi.verhalten"
        case "book.closed", "book.closed.fill", "note.text", "square.and.pencil": "fi.tagebuch"
        case "books.vertical", "books.vertical.fill": "fi.lexikon"
        case "carrot.fill", "carrot": "fi.moehre"
        case "stethoscope", "heart.text.square", "heart.fill": "fi.gesundheit"
        case "pawprint", "pawprint.fill", "hare": "fi.tiere"
        case "calendar", "sun.horizon": "fi.heute"
        case "clock", "clock.fill": "fi.verlauf"
        case "lightbulb", "lightbulb.fill": "fi.tipp"
        case "person.2.fill", "arrow.triangle.2.circlepath": "fi.wolke"
        case "gearshape.fill", "gearshape": "fi.zahnrad"
        case "crown.fill", "checkmark.seal.fill", "star", "star.fill", "trophy.fill": "fi.pokal"
        default: nil
        }
    }
}

/// Ein Floof-Symbol in fester Größe. `tile` legt es auf eine kleine dunkle Kachel
/// (in Hell und Dunkel gleich – wie das App-Icon), damit die cremefarbenen Motive immer tragen.
struct FloofIcon: View {
    let symbol: String
    var size: CGFloat = 24
    var tile = true
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
        .padding(tile ? size * 0.24 : 0)
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
