import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(PetStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var isImporting = false
    @State private var exportDocument: FloofExportDocument?
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Erinnerungen für Medikamente", isOn: Binding(
                        get: { store.data.notificationsEnabled },
                        set: { value in store.update { $0.notificationsEnabled = value } }))
                } footer: {
                    Text("Mitteilungen zu den Uhrzeiten aus dem Medikamentenplan und wenn im Schrank etwas knapp wird.")
                }

                Section("Daten") {
                    Button("Floof-Export laden", systemImage: "square.and.arrow.down") { isImporting = true }
                    Button("Alles exportieren", systemImage: "square.and.arrow.up") {
                        do { exportDocument = FloofExportDocument(data: try store.makeExport()) }
                        catch { message = error.localizedDescription }
                    }
                }

                Section("Dein Fortschritt") {
                    LabeledContent("Möhren", value: "\(store.game.carrots)")
                    LabeledContent("Längste Serie gerade", value: "\(store.streak) Tage")
                    LabeledContent("Abzeichen", value: "\(store.unlockedBadges.count) von \(Badge.all.count)")
                }

                Section {
                    Text("Floof speichert alles nur auf diesem Gerät. Für ein Backup: „Alles exportieren“.")
                        .font(.footnote).foregroundStyle(Theme.inkSoft)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig", role: .close) { dismiss() } }
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
                do {
                    try store.importExport(from: result.get())
                    message = "Import erfolgreich: \(store.pets.count) Tier\(store.pets.count == 1 ? "" : "e")."
                } catch {
                    message = "Das hat nicht geklappt: \(error.localizedDescription)"
                }
            }
            .fileExporter(isPresented: Binding(get: { exportDocument != nil }, set: { if !$0 { exportDocument = nil } }),
                          document: exportDocument, contentType: .json,
                          defaultFilename: "Floof-Export-\(DoseKey.day(.now))") { _ in }
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil }
            }
        }
    }
}
