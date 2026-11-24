import SwiftUI

struct PetEditor: View {
    @Environment(PetStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var pet: Pet
    @State private var confirmDelete = false

    init(pet: Pet) {
        _pet = State(initialValue: pet)
    }

    private var exists: Bool { store.pet(pet.id) != nil }
    private var group: PetGroup { PetGroup.for(pet.animalType) }

    var body: some View {
        editor.floofSheet()
    }

    private var editor: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        PetAvatar(pet: pet, size: 110)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    PhotoField(filename: $pet.photoFilename, title: "Foto wählen")
                }

                Section {
                    TextField("Name", text: $pet.name)
                        .font(Theme.title(20))
                    // Auswahl nur, wenn es mehr als eine Tierart gibt (vorerst nur Kaninchen).
                    if PetGroup.animalTypes.count > 1 {
                        Picker("Tierart", selection: $pet.animalType) {
                            ForEach(PetGroup.animalTypes, id: \.self) { Text($0).tag($0) }
                        }
                    }
                    TextField("Rasse", text: $pet.breed)
                    DatePicker("Geburtstag", selection: $pet.birthday, in: ...Date.now, displayedComponents: .date)
                }

                Section {
                    Picker("Haltung", selection: Binding(get: { pet.housingOrDefault }, set: { pet.housing = $0 })) {
                        ForEach(Housing.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Haltung")
                } footer: {
                    Text("Gemischt heißt: drinnen mit Auslauf draußen, z. B. Balkon oder Garten. Danach richten sich die Wetter-Hinweise – drinnen nur Hitze, draußen auch Frost, Regen und Sturm.")
                }

                Section("Farbe") {
                    colorPicker
                }

                Section("Notizen") {
                    ForEach(group.infoFields, id: \.key) { field in
                        TextField(field.label, text: infoBinding(field.key), axis: .vertical)
                            .lineLimit(1...4)
                    }
                }

                Section {
                    Toggle("Wöchentlich ans Wiegen erinnern", isOn: Binding(
                        get: { pet.weighReminder ?? false }, set: { pet.weighReminder = $0 }))
                }

                if exists {
                    Section {
                        Button("\(pet.name) entfernen", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .ambientBackground()
            .navigationTitle(exists ? "Bearbeiten" : "Neues Tier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen", role: .cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", role: .confirm) { save() }
                        .disabled(pet.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("\(pet.name) wirklich entfernen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Entfernen", role: .destructive) {
                    store.deletePet(pet)
                    dismiss()
                }
            } message: {
                Text("Alle Medikamente, Gewichte und Tagebucheinträge nur dieses Tieres gehen verloren.")
            }
        }
    }

    private var colorPicker: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(0..<12, id: \.self) { index in
                Button {
                    withAnimation(.snappy) { pet.color = index }
                } label: {
                    Circle().fill(Pet.tint(forColor: index))
                        .frame(height: 34)
                        .overlay {
                            if pet.color == index {
                                Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func infoBinding(_ key: String) -> Binding<String> {
        let fullKey = "\(group.rawValue).\(key)"
        return Binding(get: { pet.extraInfo[fullKey] ?? "" },
                       set: { pet.extraInfo[fullKey] = $0.isEmpty ? nil : $0 })
    }

    private func save() {
        pet.name = pet.name.trimmingCharacters(in: .whitespaces)
        pet.petGroup = group.rawValue
        store.upsertPet(pet)
        dismiss()
    }
}
