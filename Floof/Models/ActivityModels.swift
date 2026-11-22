import Foundation

/// Ein Eintrag im Protokoll: wer hat wann was gemacht.
/// Wird mit dem anderen iPhone abgeglichen – so sieht man "Anna · 15:02 · Gabapentin gegeben".
struct ActivityEntry: Codable, Identifiable, Hashable {
    var id: String
    var date: Date
    /// Name aus "Gemeinsam nutzen" (leer = ohne Namen eingetragen).
    var author: String
    var petID: String?
    var kind: Kind
    var text: String

    enum Kind: String, Codable {
        case dose, doseUndo, check, weight, diary, care, cabinet, pet

        var symbol: String {
            switch self {
            case .dose: "checkmark.circle.fill"
            case .doseUndo: "arrow.uturn.backward.circle"
            case .check: "stethoscope"
            case .weight: "scalemass"
            case .diary: "book.closed"
            case .care: "scissors"
            case .cabinet: "cross.case"
            case .pet: "pawprint"
            }
        }

        /// Für die Filter im Verlauf.
        var group: Group {
            switch self {
            case .dose, .doseUndo, .cabinet: .medicine
            case .check, .weight, .care, .pet: .health
            case .diary: .diary
            }
        }
    }

    enum Group { case medicine, health, diary }
}
