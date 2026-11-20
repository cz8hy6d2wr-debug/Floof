import SwiftUI

/// Übersicht aller Tiere. Zugeklappt eine Liste, aufgeklappt Liste + Detail nebeneinander.
struct PetsView: View {
    @Environment(PetStore.self) private var store
    @Environment(\.devicePosture) private var posture
    @State private var selection: Pet.ID?
    @State private var showsNewPet = false
    @State private var showsSettings = false

    var body: some View {
        if posture == .unfolded {
            NavigationSplitView {
                list
                    .navigationSplitViewColumnWidth(min: 260, ideal: 300)
            } detail: {
                if let id = selection ?? store.pets.first?.id {
                    NavigationStack { PetDetailView(petID: id) }
                } else {
                    ContentUnavailableView("Kein Tier ausgewählt", systemImage: "pawprint")
                }
            }
        } else {
            NavigationStack {
                list
                    .navigationDestination(for: Pet.ID.self) { PetDetailView(petID: $0) }
            }
        }
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HandTitle(text: "Deine Tiere", size: 32).padding(.top, 4).padding(.bottom, 6)
                ForEach(store.pets) { pet in
                    if posture == .unfolded {
                        Button { selection = pet.id } label: { PetRow(pet: pet, isSelected: selection == pet.id) }
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
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.paper)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Einstellungen", systemImage: "gearshape") { showsSettings = true }
            }
        }
        .sheet(isPresented: $showsNewPet) { PetEditor(pet: .new()) }
        .sheet(isPresented: $showsSettings) { SettingsView() }
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
