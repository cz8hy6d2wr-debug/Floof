import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(PetStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var isImporting = false
    @State private var pending: PendingImport?
    @State private var message: String?

    var body: some View {
        editor.floofSheet()
    }

    private var editor: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Erinnerungen für Medikamente", isOn: Binding(
                        get: { store.data.notificationsEnabled },
                        set: { value in store.update { $0.notificationsEnabled = value } }))
                } footer: {
                    Text("Mitteilungen zu den Uhrzeiten aus dem Medikamentenplan und wenn im Schrank etwas knapp wird.")
                }

                Section {
                    ShareLink(item: store.shareAll,
                              preview: SharePreview("Alle Floof-Daten", image: Image("FloofLogo"))) {
                        Label("Alles teilen (AirDrop, Nachrichten …)", systemImage: "square.and.arrow.up")
                    }
                    ForEach(store.pets) { pet in
                        ShareLink(item: store.share(pet),
                                  preview: SharePreview("Floof: \(pet.name)", image: Image("FloofLogo"))) {
                            Label("Nur \(pet.name) teilen", systemImage: "pawprint")
                        }
                    }
                    Button("Datei öffnen", systemImage: "square.and.arrow.down") { isImporting = true }
                } header: {
                    Text("Teilen & Übernehmen")
                } footer: {
                    Text("Per AirDrop empfangene Floof-Dateien öffnen sich direkt in Floof – du siehst vorher, was übernommen wird. Ein einzelnes Tier enthält sein Tagebuch und die verknüpften Medikamente aus dem Schrank, ideal für Tiersitter.")
                }

                Section("Dein Fortschritt") {
                    LabeledContent("Möhren", value: "\(store.game.carrots)")
                    LabeledContent("Längste Serie gerade", value: "\(store.streak) Tage")
                    LabeledContent("Abzeichen", value: "\(store.unlockedBadges.count) von \(Badge.all.count)")
                }

                Section {
                    Text("Floof speichert alles nur auf diesem Gerät. Für ein Backup: „Alles teilen“ und in Dateien sichern.")
                        .font(.footnote).foregroundStyle(Theme.inkSoft)
                }
            }
            .scrollContentBackground(.hidden)
            .ambientBackground()
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig", role: .close) { dismiss() } }
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.floofExport, .json]) { result in
                do { pending = try PendingImport(url: result.get()) }
                catch { message = "Das hat nicht geklappt: \(error.localizedDescription)" }
            }
            .sheet(item: $pending) { ImportReviewSheet(pending: $0) }
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil }
            }
        }
    }
}
