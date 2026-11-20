import Foundation

/// Gesamter App-Zustand, wird als JSON in den Dokumenten gespeichert.
struct AppData: Codable {
    var version = 3
    var pets: [Pet] = []
    var diary: [DiaryEntry] = []
    var cabinet: [CabinetItem] = []
    var customBreeds: [String] = []
    /// Abgehakte Dosen, Schlüssel = `ScheduledDose.id` (enthält das Datum).
    var takenDoses: Set<String> = []
    var game = GameState()
    var notificationsEnabled = true
    /// Gemerkte Lexikon-Artikel.
    var lexiconBookmarks: Set<String> = []
}

extension AppData {
    /// Tolerantes Laden: Fehlende Felder (z. B. nach einem App-Update) bekommen
    /// ihren Standardwert, statt dass die ganze Datei nicht gelesen werden kann.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? version
        pets = try c.decodeIfPresent([Pet].self, forKey: .pets) ?? []
        diary = try c.decodeIfPresent([DiaryEntry].self, forKey: .diary) ?? []
        cabinet = try c.decodeIfPresent([CabinetItem].self, forKey: .cabinet) ?? []
        customBreeds = try c.decodeIfPresent([String].self, forKey: .customBreeds) ?? []
        takenDoses = try c.decodeIfPresent(Set<String>.self, forKey: .takenDoses) ?? []
        game = try c.decodeIfPresent(GameState.self, forKey: .game) ?? GameState()
        notificationsEnabled = try c.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
        lexiconBookmarks = try c.decodeIfPresent(Set<String>.self, forKey: .lexiconBookmarks) ?? []
    }
}

/// Datei-Ablage: `floof-data.json` + Fotos als JPEG im Ordner `Photos`.
enum DiskStore {
    static var dataURL: URL { URL.documentsDirectory.appending(path: "floof-data.json") }
    static var photosDirectory: URL { URL.documentsDirectory.appending(path: "Photos", directoryHint: .isDirectory) }

    static func load() -> AppData? {
        guard let data = try? Data(contentsOf: dataURL) else { return nil }
        return try? JSONDecoder().decode(AppData.self, from: data)
    }

    static func write(_ appData: AppData) {
        do {
            let data = try JSONEncoder().encode(appData)
            try data.write(to: dataURL, options: [.atomic, .completeFileProtection])
        } catch {
            print("Floof: Speichern fehlgeschlagen – \(error)")
        }
    }

    static func savePhoto(_ jpeg: Data, named name: String) {
        try? FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        try? jpeg.write(to: photosDirectory.appending(path: name), options: .atomic)
    }

    static func photoData(named name: String) -> Data? {
        try? Data(contentsOf: photosDirectory.appending(path: name))
    }

    static func deletePhoto(named name: String) {
        try? FileManager.default.removeItem(at: photosDirectory.appending(path: name))
    }
}
