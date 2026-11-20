import SwiftUI

struct LexiconArticle: Identifiable, Hashable {
    let id: String
    let title: String
    let category: LexiconCategory
    let summary: String
    let sections: [LexiconSection]
    /// Begriffe, über die der Artikel gefunden und mit Tier-Akten verknüpft wird.
    var keywords: [String] = []
    var related: [String] = []

    /// Passt der Artikel zu einem Text aus der Akte (Medikament, Erkrankung …)?
    func matches(_ text: String) -> Bool {
        let haystack = text.lowercased()
        let words = Set(haystack.split { !$0.isLetter && !$0.isNumber }.map(String.init))
        return keywords.contains { keyword in
            let k = keyword.lowercased()
            // Kurze Begriffe (z. B. "EC") nur als ganzes Wort, sonst Teilstring.
            return k.count <= 3 ? words.contains(k) : haystack.contains(k)
        }
    }

    /// Volltextsuche über Titel, Zusammenfassung, Schlagworte und Inhalt.
    func matches(search: String) -> Bool {
        let q = search.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return true }
        return title.lowercased().contains(q)
            || summary.lowercased().contains(q)
            || keywords.contains { $0.lowercased().contains(q) }
            || sections.contains { $0.body.lowercased().contains(q) || ($0.heading?.lowercased().contains(q) ?? false) }
    }
}

struct LexiconSection: Hashable {
    var heading: String?
    var body: String
}

enum LexiconCategory: String, CaseIterable, Identifiable {
    case emergency = "Notfall"
    case health = "Krankheiten"
    case medicine = "Medikamente"
    case food = "Ernährung"
    case care = "Pflege"
    case behavior = "Verhalten"
    case housing = "Haltung"

    var id: Self { self }

    var symbol: String {
        switch self {
        case .emergency: "cross.case.fill"
        case .health: "stethoscope"
        case .medicine: "pills.fill"
        case .food: "carrot.fill"
        case .care: "scissors"
        case .behavior: "hare.fill"
        case .housing: "house.fill"
        }
    }

    var tint: Color {
        switch self {
        case .emergency: Theme.berry
        case .health: Color(light: 0x557A95, dark: 0x8FB3CE)
        case .medicine: Color(light: 0x7E5A86, dark: 0xBD9AC6)
        case .food: Theme.carrot
        case .care: Color(light: 0x6E8F7C, dark: 0xA3C4B0)
        case .behavior: Theme.honey
        case .housing: Theme.leaf
        }
    }
}

struct FoodItem: Identifiable, Hashable {
    let name: String
    let verdict: Verdict
    var note: String = ""
    var id: String { name }

    enum Verdict: String, CaseIterable, Identifiable {
        case ok = "Gut"
        case sometimes = "In Maßen"
        case toxic = "Giftig / ungeeignet"
        var id: Self { self }

        var symbol: String {
            switch self {
            case .ok: "checkmark.circle.fill"
            case .sometimes: "exclamationmark.circle.fill"
            case .toxic: "xmark.octagon.fill"
            }
        }
        var color: Color {
            switch self {
            case .ok: Theme.leaf
            case .sometimes: Theme.honey
            case .toxic: Theme.berry
            }
        }
    }
}

/// Normalwerte eines gesunden Kaninchens.
struct VitalSign: Identifiable {
    let label: String
    let value: String
    let symbol: String
    var id: String { label }
}

/// Navigationsziele im Lexikon (eigener Typ, damit es nicht mit Tier-IDs kollidiert).
enum LexiconRoute: Hashable {
    case article(String)
    case foodCheck
    case category(LexiconCategory)
    case supplements
    case supplement(String)
}
