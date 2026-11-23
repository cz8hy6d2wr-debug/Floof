import Foundation

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
