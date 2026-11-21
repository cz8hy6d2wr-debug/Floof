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
    /// Pflege-Routinen; `nil` bei älteren Daten → Standard-Routinen.
    var routines: [CareRoutine]?

    var careRoutines: [CareRoutine] { routines ?? CareRoutine.defaults }

    /// Wann eine Routine zuletzt erledigt wurde – Wiegen ergibt sich aus den Gewichten.
    func lastDone(_ routine: CareRoutine) -> Date? {
        if routine.kind == .weigh {
            return [routine.lastDone, latestWeight?.date].compactMap { $0 }.max()
        }
        return routine.lastDone
    }

    /// Tage bis zur nächsten Fälligkeit (negativ = überfällig, nil = noch nie erledigt).
    func daysUntilDue(_ routine: CareRoutine) -> Int? {
        guard let due = routine.nextDue(lastDone: lastDone(routine)) else { return nil }
        return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now),
                                               to: Calendar.current.startOfDay(for: due)).day
    }

    func check(on day: Date) -> DailyCheck? {
        dailyChecks.first { $0.id == DoseKey.day(day) }
    }

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

/// Tages-Check eines Tieres: drei konkrete Beobachtungen statt einer vagen Ampel.
/// Der Gesamtstatus (`need`) wird daraus abgeleitet. Ältere Daten mit nur `need` bleiben lesbar.
struct DailyCheck: Codable, Hashable, Identifiable {
    var id: String      // "yyyy-MM-dd"
    var need: Need
    var appetite: Level?
    var droppings: Level?
    var behavior: Level?
    var note: String?

    enum Need: String, Codable { case green, yellow, red }

    /// 0 = normal, 1 = auffällig, 2 = Alarm.
    enum Level: Int, Codable, CaseIterable, Identifiable {
        case normal = 0, reduced = 1, alarming = 2
        var id: Self { self }
    }

    enum Aspect: String, CaseIterable, Identifiable {
        case appetite, droppings, behavior
        var id: Self { self }

        var title: String {
            switch self {
            case .appetite: "Fressen"
            case .droppings: "Köttel"
            case .behavior: "Verhalten"
            }
        }
        var symbol: String {
            switch self {
            case .appetite: "fork.knife"
            case .droppings: "circle.grid.2x2.fill"
            case .behavior: "hare.fill"
            }
        }
        func label(_ level: Level) -> String {
            switch (self, level) {
            case (.appetite, .normal): "normal"
            case (.appetite, .reduced): "weniger"
            case (.appetite, .alarming): "gar nicht"
            case (.droppings, .normal): "normal"
            case (.droppings, .reduced): "kleiner"
            case (.droppings, .alarming): "keine"
            case (.behavior, .normal): "munter"
            case (.behavior, .reduced): "ruhiger"
            case (.behavior, .alarming): "apathisch"
            }
        }
    }

    func level(_ aspect: Aspect) -> Level? {
        switch aspect {
        case .appetite: appetite
        case .droppings: droppings
        case .behavior: behavior
        }
    }

    mutating func set(_ aspect: Aspect, _ level: Level) {
        switch aspect {
        case .appetite: appetite = level
        case .droppings: droppings = level
        case .behavior: behavior = level
        }
        let worst = Aspect.allCases.compactMap { self.level($0)?.rawValue }.max() ?? 0
        need = worst == 2 ? .red : (worst == 1 ? .yellow : .green)
    }

    var isComplete: Bool { Aspect.allCases.allSatisfy { level($0) != nil } }

    /// Kurzfassung der Auffälligkeiten, z. B. "frisst weniger, Köttel kleiner".
    var findings: String? {
        let items = Aspect.allCases.compactMap { aspect -> String? in
            guard let l = level(aspect), l != .normal else { return nil }
            switch aspect {
            case .appetite: return l == .alarming ? "frisst nicht" : "frisst weniger"
            case .droppings: return l == .alarming ? "keine Köttel" : "Köttel kleiner"
            case .behavior: return l == .alarming ? "apathisch" : "ruhiger als sonst"
            }
        }
        return items.isEmpty ? nil : items.joined(separator: ", ")
    }
}

// MARK: - Pflege-Routinen

/// Wiederkehrende Pflege mit Intervall (Wiegen, Krallen, Zähne …).
struct CareRoutine: Codable, Hashable, Identifiable {
    var id: String
    var kind: Kind
    var intervalDays: Int
    var lastDone: Date?

    enum Kind: String, Codable, CaseIterable {
        case weigh, claws, teeth, fur

        var title: String {
            switch self {
            case .weigh: "Wiegen"
            case .claws: "Krallen kontrollieren"
            case .teeth: "Zähne kontrollieren"
            case .fur: "Fell & Po kontrollieren"
            }
        }
        var doneTitle: String {
            switch self {
            case .weigh: "Gewogen"
            case .claws: "Krallen kontrolliert"
            case .teeth: "Zähne kontrolliert"
            case .fur: "Fell & Po kontrolliert"
            }
        }
        var symbol: String {
            switch self {
            case .weigh: "scalemass"
            case .claws: "scissors"
            case .teeth: "mouth"
            case .fur: "sparkles"
            }
        }
        var defaultInterval: Int {
            switch self {
            case .weigh: 7
            case .claws: 42
            case .teeth: 90
            case .fur: 7
            }
        }
    }

    static var defaults: [CareRoutine] {
        Kind.allCases.map { CareRoutine(id: $0.rawValue, kind: $0, intervalDays: $0.defaultInterval, lastDone: nil) }
    }

    func nextDue(lastDone: Date?) -> Date? {
        lastDone.flatMap { Calendar.current.date(byAdding: .day, value: intervalDays, to: $0) }
    }
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
    /// "yyyy-MM-dd" → Mittag dieses Tages (für Zeitleisten).
    static func date(_ key: String) -> Date? {
        formatter.date(from: key).flatMap { Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: $0) }
    }
}
