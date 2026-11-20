import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// Eigenes Dateiformat für Floof-Daten (JSON im Floof-Exportformat).
    /// Dadurch öffnet iOS empfangene Dateien – z. B. per AirDrop – direkt in Floof.
    static let floofExport = UTType(exportedAs: "app.floof.diary.export", conformingTo: .json)
}

/// Import/Export im Floof-Exportformat (Version 2 lesbar, Version 3 mit Tagebuch & Schrank).
extension PetStore {

    // MARK: Export

    /// - Parameter petIDs: nur diese Tiere (z. B. für Tiersitter), `nil` = alles.
    func makeExport(petIDs: Set<Pet.ID>? = nil) throws -> Data {
        let chosenPets = petIDs.map { ids in pets.filter { ids.contains($0.id) } } ?? pets
        let chosenIDs = Set(chosenPets.map(\.id))

        // Tagebuch: nur Einträge dieser Tiere, fremde Tier-IDs entfernen.
        let chosenDiary: [DiaryEntry] = diary.compactMap { entry in
            guard petIDs != nil else { return entry }
            var copy = entry
            copy.petIDs = entry.petIDs.filter(chosenIDs.contains)
            return copy.petIDs.isEmpty ? nil : copy
        }
        // Schrank: nur Artikel, die mit Medikamenten dieser Tiere verknüpft sind.
        let linkedItems = Set(chosenPets.flatMap(\.care).compactMap(\.cabinetItemID))
        let chosenCabinet = petIDs == nil ? cabinet : cabinet.filter { linkedItems.contains($0.id) }

        var photos: [String: String] = [:]
        for name in chosenPets.compactMap(\.photoFilename) + chosenDiary.compactMap(\.photoFilename) {
            if let jpeg = DiskStore.photoData(named: name) { photos[name] = jpeg.base64EncodedString() }
        }
        let export = FloofExport(
            data: ExportData(customBreeds: data.customBreeds, events: [], rabbits: chosenPets,
                             diary: chosenDiary, cabinet: chosenCabinet),
            photos: photos, version: 3)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(export)
    }

    // MARK: Import

    enum ImportMode: String, CaseIterable, Identifiable {
        case merge = "Zusammenführen"
        case replace = "Alles ersetzen"
        var id: Self { self }
    }

    /// Übernimmt einen Export. Zusammenführen: gleiche IDs werden aktualisiert,
    /// neue ergänzt, vorhandene Daten bleiben erhalten.
    func apply(_ export: FloofExport, mode: ImportMode) {
        for (name, base64) in export.photos {
            if let jpeg = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) {
                DiskStore.savePhoto(jpeg, named: name)
            }
        }
        update { data in
            switch mode {
            case .replace:
                data.pets = export.data.rabbits
                data.diary = export.data.diary ?? []
                data.cabinet = export.data.cabinet ?? []
                data.customBreeds = export.data.customBreeds
            case .merge:
                Self.merge(&data.pets, with: export.data.rabbits)
                Self.merge(&data.diary, with: export.data.diary ?? [])
                Self.merge(&data.cabinet, with: export.data.cabinet ?? [])
                data.customBreeds = Array(Set(data.customBreeds).union(export.data.customBreeds)).sorted()
            }
        }
        if selectedPetID == nil || pet(selectedPetID!) == nil { selectedPetID = pets.first?.id }
        refreshPhotos()
        let count = export.data.rabbits.count
        showToast(count == 1 ? "\(export.data.rabbits[0].name) übernommen" : "\(count) Tiere übernommen")
    }

    private static func merge<T: Identifiable>(_ existing: inout [T], with incoming: [T]) {
        for item in incoming {
            if let i = existing.firstIndex(where: { $0.id == item.id }) { existing[i] = item }
            else { existing.append(item) }
        }
    }
}

/// Eine empfangene oder ausgewählte Datei, die vor dem Übernehmen geprüft wird.
struct PendingImport: Identifiable {
    let id = UUID()
    let export: FloofExport

    init(url: URL) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        export = try JSONDecoder().decode(FloofExport.self, from: Data(contentsOf: url))
        // AirDrop legt eine Kopie in Documents/Inbox ab – nach dem Lesen aufräumen.
        if url.path.contains("/Documents/Inbox/") { try? FileManager.default.removeItem(at: url) }
    }
}

/// Teilbare Floof-Datei (AirDrop, Nachrichten, Dateien …).
/// Die Daten werden erst erzeugt, wenn wirklich geteilt wird.
struct FloofShareFile: Transferable {
    let filename: String
    let makeData: @MainActor @Sendable () throws -> Data

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .floofExport) { file in
            let data = try await MainActor.run { try file.makeData() }
            let url = URL.temporaryDirectory.appending(path: "\(file.filename).floof")
            try data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

extension PetStore {
    /// Alle Daten zum Teilen.
    var shareAll: FloofShareFile {
        FloofShareFile(filename: "Floof-\(DoseKey.day(.now))") { [unowned self] in try makeExport() }
    }

    /// Ein Tier (mit Tagebuch und verknüpftem Schrank) – z. B. für Tiersitter.
    func share(_ pet: Pet) -> FloofShareFile {
        FloofShareFile(filename: "Floof-\(pet.name)-\(DoseKey.day(.now))") { [unowned self] in
            try makeExport(petIDs: [pet.id])
        }
    }
}
