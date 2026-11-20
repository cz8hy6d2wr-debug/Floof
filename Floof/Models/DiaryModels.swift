import Foundation

/// Ein Tagebucheintrag – kann für ein oder mehrere Tiere gelten
/// (z. B. "Beide haben heute zum ersten Mal Löwenzahn bekommen").
struct DiaryEntry: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var date = Date.now
    var petIDs: [String]
    var mood: Mood = .good
    var title = ""
    var text = ""
    var tags: [DiaryTag] = []
    var photoFilename: String?
    /// Automatisch angelegt (z. B. Bedarfsmedikament gegeben).
    var isAutomatic = false

    enum Mood: String, Codable, CaseIterable, Identifiable {
        case great, good, okay, low, sick
        var id: Self { self }

        var label: String {
            switch self {
            case .great: "Super drauf"
            case .good: "Gut"
            case .okay: "Geht so"
            case .low: "Schlapp"
            case .sick: "Krank"
            }
        }
        var symbol: String {
            switch self {
            case .great: "sun.max.fill"
            case .good: "cloud.sun.fill"
            case .okay: "cloud.fill"
            case .low: "cloud.drizzle.fill"
            case .sick: "cloud.bolt.rain.fill"
            }
        }
        /// 0 (krank) … 4 (super) – für den Stimmungskalender.
        var score: Int { Self.allCases.count - 1 - (Self.allCases.firstIndex(of: self) ?? 0) }
    }
}

enum DiaryTag: String, Codable, CaseIterable, Identifiable {
    case food = "Futter"
    case behavior = "Verhalten"
    case health = "Gesundheit"
    case vet = "Tierarzt"
    case grooming = "Pflege"
    case play = "Spiel"
    case milestone = "Meilenstein"

    var id: Self { self }
    var symbol: String {
        switch self {
        case .food: "leaf"
        case .behavior: "eye"
        case .health: "heart.text.square"
        case .vet: "stethoscope"
        case .grooming: "scissors"
        case .play: "figure.run"
        case .milestone: "star"
        }
    }
}

/// Alles, was in der Tagebuch-Zeitleiste auftaucht: eigene Einträge
/// plus automatisch erfasste Ereignisse (Wiegen, Tierarzt, Impfung).
enum TimelineItem: Identifiable, Hashable {
    case entry(DiaryEntry)
    case weight(Pet, WeightEntry)
    case care(Pet, CareEntry)

    var id: String {
        switch self {
        case .entry(let e): "d-\(e.id)"
        case .weight(_, let w): "w-\(w.id)"
        case .care(_, let c): "c-\(c.id)"
        }
    }

    var date: Date {
        switch self {
        case .entry(let e): e.date
        case .weight(_, let w): w.date
        case .care(_, let c): c.date
        }
    }
}
