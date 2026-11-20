import SwiftUI

/// Übersicht aller Tiere.
/// Zugeklappt: Liste → Detail (Navigation). Aufgeklappt: Liste | Detail in zwei gleich
/// breiten Spalten, der Zwischenraum liegt auf dem Falz.
///
/// Beim Auf-/Zuklappen bleibt das gerade angesehene Tier erhalten: Der Navigationspfad
/// wird in die Auswahl übernommen und umgekehrt. Sheets hängen am gemeinsamen Stack
/// und bleiben dadurch offen.
struct PetsView: View {
    @Environment(PetStore.self) private var store
    @Environment(\.devicePosture) private var posture
    @State private var path: [Pet.ID] = []
    @State private var selection: Pet.ID?
    @State private var showsNewPet = false
    @State private var showsSettings = false
    @State private var sheets = PetSheets()

    var body: some View {
        @Bindable var sheets = sheets
        NavigationStack(path: $path) {
            Group {
                if posture == .unfolded {
                    FoldColumns {
                        list
                    } trailing: {
                        if let id = selection ?? store.pets.first?.id {
                            PetDetailView(petID: id, embedded: true)
                                .id(id)
                        } else {
                            ContentUnavailableView("Noch keine Tiere", systemImage: "pawprint")
                        }
                    }
                } else {
                    list
                        .padding(.horizontal, 16)
                        .foldedReadableWidth()
                }
            }
            .background(Theme.paper.ignoresSafeArea())
            .navigationDestination(for: Pet.ID.self) { PetDetailView(petID: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Einstellungen", systemImage: "gearshape") { showsSettings = true }
                }
            }
            .sheet(isPresented: $showsNewPet) { PetEditor(pet: .new()) }
            .sheet(isPresented: $showsSettings) { SettingsView() }
            .sheet(item: $sheets.editPet) { PetEditor(pet: $0) }
            .sheet(item: $sheets.weigh) { WeightSheet(pet: $0) }
            .sheet(item: $sheets.care) { CareEntryEditor(entry: $0.entry, petID: $0.petID) }
        }
        .environment(self.sheets)
        .onChange(of: posture) { _, new in
            switch new {
            case .unfolded:
                // Geöffnetes Detail wird zur Auswahl in der rechten Spalte.
                if let last = path.last { selection = last }
                path = []
            case .folded:
                // Ausgewähltes Tier bleibt sichtbar: als geöffnetes Detail.
                if let selection { path = [selection] }
            }
        }
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HandTitle(text: "Deine Tiere", size: 32).padding(.top, 4).padding(.bottom, 6)
                ForEach(store.pets) { pet in
                    if posture == .unfolded {
                        Button { withAnimation(.snappy) { selection = pet.id } } label: {
                            PetRow(pet: pet, isSelected: (selection ?? store.pets.first?.id) == pet.id)
                        }
                        .buttonStyle(.plain)
                    } else {
                        NavigationLink(value: pet.id) { PetRow(pet: pet, isSelected: false) }
                            .buttonStyle(.plain)
                    }
                }
                Button("Tier hinzufügen", systemImage: "plus") { showsNewPet = true }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .padding(.top, 4)
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }
}

private struct PetRow: View {
    @Environment(PetStore.self) private var store
    let pet: Pet
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            PetAvatar(pet: pet, size: 58)
            VStack(alignment: .leading, spacing: 3) {
                Text(pet.name).font(Theme.title(20))
                Text("\(pet.breed.isEmpty ? pet.animalType : pet.breed) · \(pet.ageDescription)")
                    .font(.subheadline).foregroundStyle(Theme.inkSoft)
                HStack(spacing: 10) {
                    if let w = pet.latestWeight {
                        Label("\(w.grams) g", systemImage: "scalemass").font(.caption)
                    }
                    let meds = pet.medications.count
                    if meds > 0 {
                        Label("\(meds) Medikament\(meds == 1 ? "" : "e")", systemImage: "pills").font(.caption)
                    }
                }
                .foregroundStyle(Theme.inkSoft)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(Theme.inkSoft)
        }
        .card()
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(isSelected ? pet.tint : .clear, lineWidth: 2))
    }
}
