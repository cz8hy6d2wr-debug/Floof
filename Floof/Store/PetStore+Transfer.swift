import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Import/Export im Floof-Exportformat (kompatibel zu Version 2, erweitert um Tagebuch & Schrank).
extension PetStore {
    func importExport(from url: URL) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let export = try JSONDecoder().decode(FloofExport.self, from: Data(contentsOf: url))

        // Fotos unter ihrem ursprünglichen Namen ablegen.
        for (name, base64) in export.photos {
            if let jpeg = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) {
                DiskStore.savePhoto(jpeg, named: name)
            }
        }
        update { data in
            data.pets = export.data.rabbits
            data.customBreeds = export.data.customBreeds
            if let diary = export.data.diary { data.diary = diary }
            if let cabinet = export.data.cabinet { data.cabinet = cabinet }
        }
        selectedPetID = pets.first?.id
        refreshPhotos()
    }

    func makeExport() throws -> Data {
        var photos: [String: String] = [:]
        let names = pets.compactMap(\.photoFilename) + diary.compactMap(\.photoFilename)
        for name in names {
            if let jpeg = DiskStore.photoData(named: name) { photos[name] = jpeg.base64EncodedString() }
        }
        let export = FloofExport(
            data: ExportData(customBreeds: data.customBreeds, events: [], rabbits: pets,
                             diary: diary, cabinet: cabinet),
            photos: photos, version: 3)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(export)
    }
}

/// Exportdatei für `.fileExporter`.
struct FloofExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
