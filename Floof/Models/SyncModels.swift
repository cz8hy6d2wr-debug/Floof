import Foundation

/// Zeitstempel für die Synchronisation: wann welcher Datensatz zuletzt geändert,
/// gelöscht oder welche Gabe zuletzt abgehakt/zurückgenommen wurde.
struct SyncMeta: Codable, Hashable {
    /// "pet:<id>", "diary:<id>", "cab:<id>" → letzte Änderung
    var recordTimes: [String: Date] = [:]
    /// gleiche Schlüssel → Zeitpunkt der Löschung
    var deleted: [String: Date] = [:]
    /// Dosis-Schlüssel → letzte Änderung (abgehakt oder zurückgenommen)
    var doseTimes: [String: Date] = [:]
}

/// Inhalt der gemeinsamen Datei in iCloud Drive.
struct SyncSnapshot: Codable {
    var format = 1
    var savedAt = Date.now
    var savedBy: String
    var pets: [Pet]
    var diary: [DiaryEntry]
    var cabinet: [CabinetItem]
    var customBreeds: [String]
    var takenDoses: Set<String>
    var meta: SyncMeta
}
