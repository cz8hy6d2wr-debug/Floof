import Foundation

/// Kleiner, fertig aufbereiteter Stand für Widgets und Live-Aktivität.
/// Die App schreibt ihn nach jeder Änderung in den gemeinsamen App-Group-Ordner,
/// die Widgets lesen nur – rechnen müssen sie nichts.
struct WidgetSnapshot: Codable, Equatable {
    struct Dose: Codable, Equatable, Identifiable {
        var id: String
        var title: String
        var petName: String
        var amount: String
        var time: String
        var due: Date
        var taken: Bool
        /// SF-Symbol-Name der Darreichungsform – wird auf ein Floof-Symbol abgebildet.
        var symbol: String
    }

    struct Check: Codable, Equatable, Identifiable {
        var id: String          // Tier-ID
        var petName: String
        var done: Bool
        var allNormal: Bool
    }

    struct Weight: Codable, Equatable {
        var petName: String
        var grams: Int
        var date: Date
    }

    struct CabinetAlert: Codable, Equatable {
        var name: String
        var text: String
    }

    var day: Date
    var doses: [Dose]
    var checks: [Check]
    var weight: Weight?
    var cabinetAlert: CabinetAlert?
    var lastActivity: String?
    var carrots: Int
    /// "24° · sonnig · bis 29°" (optional, ältere Stände haben es nicht).
    var weather: String?
    var weatherSymbol: String?

    static let empty = WidgetSnapshot(day: .now, doses: [], checks: [], weight: nil,
                                      cabinetAlert: nil, lastActivity: nil, carrots: 0, weather: nil, weatherSymbol: nil)

    // MARK: Ableitungen

    var open: [Dose] { doses.filter { !$0.taken } }
    var givenCount: Int { doses.filter(\.taken).count }
    var progress: Double { doses.isEmpty ? 1 : Double(givenCount) / Double(doses.count) }

    /// Nächste offene Gabe (überfällige zuerst).
    func nextOpen(after date: Date = .now) -> Dose? { open.sorted { $0.due < $1.due }.first }

    /// Alle offenen Gaben zur selben Uhrzeit wie die nächste ("Gabapentin + Panacur").
    func nextGroup(after date: Date = .now) -> [Dose] {
        guard let next = nextOpen(after: date) else { return [] }
        return open.filter { $0.due == next.due }
    }

    /// Ist der Stand von heute? Sonst zeigen Widgets "Floof öffnen".
    var isCurrent: Bool { Calendar.current.isDateInToday(day) }

    // MARK: Ablage

    /// Kennung der App-Gruppe, aus der Info.plist (folgt der Bundle-ID, siehe Build-Einstellungen).
    static var groupID: String? {
        (Bundle.main.object(forInfoDictionaryKey: "FloofAppGroup") as? String).flatMap { $0.isEmpty ? nil : $0 }
    }

    static var url: URL? {
        guard let id = groupID,
              let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) else { return nil }
        return dir.appending(path: "widget-snapshot.json")
    }

    /// `nil`, wenn es (noch) keinen gemeinsamen Ordner gibt.
    static func load() -> WidgetSnapshot? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    func save() {
        guard let url = Self.url else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(self) { try? data.write(to: url, options: .atomic) }
    }
}
