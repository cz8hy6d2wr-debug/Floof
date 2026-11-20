import Foundation
import Observation
import UIKit

/// Zentrale Datenquelle der App. Alle Änderungen laufen über `update`,
/// das danach speichert und die Erinnerungen aktualisiert.
@MainActor
@Observable
final class PetStore {
    private(set) var data: AppData
    var selectedPetID: Pet.ID?
    /// Wird gesetzt, wenn etwas gefeiert werden soll (Tag geschafft, neues Abzeichen).
    var celebration: Celebration?
    /// Kurze Bestätigung unten ("Vitamin B eingetragen").
    var toast: String?
    /// Gerade abgehakte Dosis – nur für die kurze "+10"-Animation, wird nicht gespeichert.
    var recentlyAwardedDoseID: String?
    /// Per AirDrop o. Ä. empfangene Datei, die auf Bestätigung wartet.
    var pendingImport: PendingImport?

    @ObservationIgnored private var photoCache: [String: UIImage] = [:]
    /// Wird erhöht, wenn sich Fotos ändern – Views beobachten das statt des Caches.
    private(set) var photoVersion = 0
    @ObservationIgnored private let persists: Bool
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    init(data: AppData, persists: Bool = true) {
        self.data = data
        self.persists = persists
        self.selectedPetID = data.pets.first?.id
    }

    /// Lädt gespeicherte Daten; beim allerersten Start leer.
    static func load() -> PetStore {
        PetStore(data: DiskStore.load() ?? AppData())
    }

    // MARK: Lesezugriff

    var pets: [Pet] { data.pets }
    var game: GameState { data.game }
    var cabinet: [CabinetItem] { data.cabinet }
    var diary: [DiaryEntry] { data.diary }

    var selectedPet: Pet? {
        pets.first { $0.id == selectedPetID } ?? pets.first
    }

    func pet(_ id: Pet.ID) -> Pet? { pets.first { $0.id == id } }

    // MARK: Schreiben

    /// Einzige Stelle, an der `data` verändert wird.
    func update(_ change: (inout AppData) -> Void) {
        change(&data)
        scheduleSave()
    }

    private func scheduleSave() {
        guard persists else { return }
        saveTask?.cancel()
        let snapshot = data
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await Task.detached(priority: .utility) { DiskStore.write(snapshot) }.value
            await ReminderScheduler.reschedule(for: snapshot)
        }
    }

    // MARK: Fotos

    func photo(named name: String?) -> UIImage? {
        _ = photoVersion   // Abhängigkeit für Observation
        guard let name else { return nil }
        if let cached = photoCache[name] { return cached }
        guard let image = DiskStore.photoData(named: name).flatMap(UIImage.init(data:)) else { return nil }
        photoCache[name] = image
        return image
    }

    /// Verkleinert, speichert und liefert den Dateinamen.
    func storePhoto(_ image: UIImage) -> String {
        let name = "\(UUID().uuidString).jpg"
        let scale = min(1, 1600 / max(image.size.width, image.size.height))
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let scaled = image.preparingThumbnail(of: target) ?? image
        if let jpeg = scaled.jpegData(compressionQuality: 0.82) {
            if persists { DiskStore.savePhoto(jpeg, named: name) }
            photoCache[name] = scaled
        }
        photoVersion += 1
        return name
    }

    /// Leert den Foto-Cache (z. B. nach einem Import mit neuen Dateien).
    func refreshPhotos() {
        photoCache.removeAll()
        photoVersion += 1
    }

    func showToast(_ text: String) {
        toast = text
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            if toast == text { toast = nil }
        }
    }
}

struct Celebration: Identifiable, Equatable {
    enum Reason: Equatable {
        case perfectDay(streak: Int)
        case badge(Badge)
    }
    let id = UUID()
    let reason: Reason
}
