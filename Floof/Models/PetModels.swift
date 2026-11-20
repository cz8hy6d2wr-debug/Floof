import Foundation

// MARK: - Export-Format (Floof-Export, version 2)
//
// Datumswerte im Export sind Sekunden seit 01.01.2001 (Apple-Referenzdatum).
// Das entspricht der Standard-Strategie `.deferredToDate` von JSONDecoder,
// daher sind keine eigenen Date-Decoder nötig.

struct FloofExport: Codable {
    var data: ExportData
    var photos: [String: String]   // Dateiname -> Base64-JPEG
    var version: Int
}

struct ExportData: Codable {
    var customBreeds: [String]
    var events: [PetEvent]
    var rabbits: [Pet]             // Feldname historisch, enthält alle Tiere
    // Ab Version 3 – ältere Exporte haben diese Felder nicht.
    var diary: [DiaryEntry]?
    var cabinet: [CabinetItem]?
}

/// Struktur der Events ist im aktuellen Export leer – alle Felder optional,
/// damit ältere/neuere Exporte nicht am Decoding scheitern.
struct PetEvent: Codable, Hashable, Identifiable {
    var id: String
    var title: String?
    var date: Date?
    var kind: String?
    var petID: String?
}

// MARK: - Tier

struct Pet: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var animalType: String
    var breed: String
    var birthday: Date
    var petGroup: String
    var color: Int
    var photoFilename: String?
    var care: [CareEntry]
    var weights: [WeightEntry]
    var dailyChecks: [DailyCheck]
    var checkIns: [Date]
    var extraInfo: [String: String]
    var hour: Int?
    var weekday: Int?
    var weighReminder: Bool?

    var medications: [CareEntry] { care.filter { $0.careKind == .medication } }
    var conditions: [CareEntry] { care.filter { $0.careKind == .condition } }
    var vaccinations: [CareEntry] {
        care.filter { $0.careKind == .vaccination }.sorted { $0.date > $1.date }
    }
    var sortedWeights: [WeightEntry] { weights.sorted { $0.date < $1.date } }

    static func new(name: String = "", animalType: String = "Kaninchen") -> Pet {
        Pet(id: UUID().uuidString, name: name, animalType: animalType, breed: "",
            birthday: Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .now,
            petGroup: PetGroup.for(animalType).rawValue, color: Int.random(in: 0..<12),
            photoFilename: nil, care: [], weights: [], dailyChecks: [], checkIns: [],
            extraInfo: [:], hour: 10, weekday: 1, weighReminder: true)
    }
    var latestWeight: WeightEntry? { sortedWeights.last }

    /// `extraInfo` ohne Gruppen-Präfix ("smallAnimal.teeth" -> "teeth").
    func info(_ key: String) -> String? {
        let value = extraInfo["\(petGroup).\(key)"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty ?? true) ? nil : value
    }

    var ageDescription: String {
        let parts = Calendar.current.dateComponents([.year, .month], from: birthday, to: .now)
        let years = parts.year ?? 0, months = parts.month ?? 0
        if years == 0 { return "\(months) Mon." }
        return months == 0 ? "\(years) J." : "\(years) J. \(months) Mon."
    }
}

// MARK: - Pflege / Medikation

enum CareKind: String, CaseIterable, Identifiable {
    case medication = "Medikation"
    case condition = "Krankheit"
    case vaccination = "Impfung"
    case other = "Sonstiges"

    var id: Self { self }
    var symbol: String {
        switch self {
        case .medication: "pills"
        case .condition: "stethoscope"
        case .vaccination: "syringe"
        case .other: "note.text"
        }
    }
}

struct CareEntry: Codable, Identifiable, Hashable {
    var id: String
    var date: Date
    var title: String
    var details: String
    var kind: String
    var reminder: CareReminder?
    /// Menge je Gabe in der Einheit des verknüpften Schrank-Artikels.
    var doseAmount: Double?
    /// Verknüpfter Artikel im Medikamentenschrank.
    var cabinetItemID: String?

    var careKind: CareKind { CareKind(rawValue: kind) ?? .other }
    var isAsNeeded: Bool { reminder == nil }

    /// Menge je Gabe – wenn nicht gepflegt, aus dem Freitext gelesen ("0,15ml" → 0.15).
    var effectiveDoseAmount: Double? {
        if let doseAmount { return doseAmount }
        guard let match = details.firstMatch(of: /(\d+(?:[.,]\d+)?)/) else { return nil }
        return Double(match.1.replacingOccurrences(of: ",", with: "."))
    }

    /// Erwarteter Verbrauch pro Tag (Gaben × Menge, über die Woche gemittelt).
    var dailyConsumption: Double {
        guard let reminder, let amount = effectiveDoseAmount else { return 0 }
        return amount * Double(reminder.allTimes.count) * Double(reminder.weekdays.count) / 7
    }

    /// Annahme: Impfungen (RHD/Myxomatose) jährlich auffrischen.
    var nextDueDate: Date? {
        guard careKind == .vaccination else { return nil }
        return Calendar.current.date(byAdding: .year, value: 1, to: date)
    }
}

struct CareReminder: Codable, Hashable {
    var hour: Int
    var minute: Int
    var times: [ReminderTime]?
    /// Calendar-Konvention: 1 = Sonntag … 7 = Samstag
    var weekdays: [Int]

    var allTimes: [ReminderTime] {
        let list = times ?? []
        return list.isEmpty ? [ReminderTime(hour: hour, minute: minute)] : list
    }
}

struct ReminderTime: Codable, Hashable, Comparable {
    var hour: Int
    var minute: Int

    var label: String { String(format: "%02d:%02d", hour, minute) }
    static func < (l: Self, r: Self) -> Bool { (l.hour, l.minute) < (r.hour, r.minute) }
}

// MARK: - Gewicht & Checks

/// Tierart-Gruppe – bestimmt, welche Zusatzfelder (`extraInfo`) angeboten werden.
enum PetGroup: String {
    case smallAnimal, dog, cat, bird, other

    /// Vorerst nur Kaninchen. Weitere Tierarten (Meerschweinchen, Hund, Katze …)
    /// lassen sich hier wieder ergänzen – Datenmodell und Notizfelder unterstützen sie bereits.
    static let animalTypes = ["Kaninchen"]

    static func `for`(_ animalType: String) -> PetGroup {
        switch animalType {
        case "Kaninchen", "Meerschweinchen", "Hamster", "Ratte", "Chinchilla", "Degu": .smallAnimal
        case "Hund": .dog
        case "Katze": .cat
        case "Vogel": .bird
        default: .other
        }
    }

    /// (Schlüssel, Bezeichnung) der Notizfelder je Gruppe.
    var infoFields: [(key: String, label: String)] {
        let base: [(key: String, label: String)] = [("feeding", "Fütterung"), ("companions", "Partner"), ("claws", "Krallen")]
        switch self {
        case .smallAnimal:
            return [("teeth", "Zähne")] + base + [("enclosure", "Gehege"), ("droppings", "Köttel"), ("introductions", "Vergesellschaftung")]
        case .dog, .cat:
            return [("teeth", "Zähne")] + base + [("parasites", "Parasitenschutz"), ("insurance", "Versicherung")]
        case .bird, .other:
            return base + [("enclosure", "Unterbringung")]
        }
    }
}

struct WeightEntry: Codable, Identifiable, Hashable {
    var id: String
    var date: Date
    var grams: Int
    var note: String
}

struct DailyCheck: Codable, Hashable, Identifiable {
    var id: String      // "yyyy-MM-dd"
    var need: Need

    enum Need: String, Codable { case green, yellow, red }
}

// MARK: - Tagesdosis (abgeleitet)

struct ScheduledDose: Identifiable, Hashable {
    let pet: Pet
    let medication: CareEntry
    let time: ReminderTime
    let day: Date

    var id: String { "\(DoseKey.day(day))|\(medication.id)|\(time.label)" }

    var isOverdue: Bool {
        let cal = Calendar.current
        guard let due = cal.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: day) else { return false }
        return due < .now
    }
}

enum DoseKey {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    static func day(_ date: Date) -> String { formatter.string(from: date) }
}
