import SwiftUI

/// Vorschau einer empfangenen Floof-Datei (AirDrop, Dateien …) vor dem Übernehmen.
struct ImportReviewSheet: View {
    @Environment(PetStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let pending: PendingImport
    @State private var mode: PetStore.ImportMode = .merge

    private var export: FloofExport { pending.export }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        Image("FloofLogo")
                            .resizable().scaledToFit()
                            .frame(width: 64, height: 64)
                            .rotationEffect(.degrees(-6))
                        VStack(alignment: .leading, spacing: 4) {
                            HandTitle(text: "Floof-Daten empfangen", size: 24)
                            Text("Schau kurz drüber, bevor du sie übernimmst.")
                                .font(.subheadline).foregroundStyle(Theme.inkSoft)
                                .padding(.top, 6)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Enthalten").font(Theme.title(18))
                        ForEach(export.data.rabbits) { pet in
                            HStack(spacing: 12) {
                                PetAvatar(pet: pet, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pet.name).font(.body.weight(.semibold))
                                    Text("\(pet.breed.isEmpty ? pet.animalType : pet.breed) · \(pet.medications.count) Medikament\(pet.medications.count == 1 ? "" : "e")")
                                        .font(.caption).foregroundStyle(Theme.inkSoft)
                                }
                                Spacer()
                                Text(store.pet(pet.id) == nil ? "Neu" : "Aktualisieren")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(store.pet(pet.id) == nil ? Theme.leaf : Theme.honey)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background((store.pet(pet.id) == nil ? Theme.leaf : Theme.honey).opacity(0.14), in: Capsule())
                            }
                        }
                        Divider()
                        HStack(spacing: 18) {
                            count(export.data.diary?.count ?? 0, "Tagebuch", "book.closed")
                            count(export.data.cabinet?.count ?? 0, "Schrank", "cross.case")
                            count(export.photos.count, "Fotos", "photo")
                        }
                    }
                    .card()

                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Übernehmen", selection: $mode) {
                            ForEach(PetStore.ImportMode.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        Text(mode == .merge
                             ? "Deine vorhandenen Daten bleiben. Gleiche Tiere, Einträge und Schrank-Artikel werden aktualisiert, neue kommen dazu."
                             : "Achtung: Alle Tiere, Tagebucheinträge und Schrank-Artikel auf diesem iPhone werden durch die empfangenen ersetzt.")
                            .font(.footnote)
                            .foregroundStyle(mode == .merge ? Theme.inkSoft : Theme.berry)
                    }
                    .card()
                }
                .padding(16)
            }
            .background(Theme.paper)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen", role: .cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernehmen", role: .confirm) {
                        store.apply(export, mode: mode)
                        dismiss()
                    }
                }
            }
        }
        .floofSheet()
    }

    private func count(_ value: Int, _ label: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("\(value)", systemImage: symbol).font(Theme.number(.headline))
            Text(label).font(.caption).foregroundStyle(Theme.inkSoft)
        }
    }
}
