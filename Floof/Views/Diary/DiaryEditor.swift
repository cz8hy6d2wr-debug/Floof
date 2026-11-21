import SwiftUI

struct DiaryEditor: View {
    @Environment(PetStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var entry: DiaryEntry
    @State private var weightText = ""
    @State private var confirmDelete = false
    @Namespace private var glass

    init(entry: DiaryEntry) {
        _entry = State(initialValue: entry)
    }

    private var exists: Bool { store.diary.contains { $0.id == entry.id } }

    var body: some View {
        editor.floofSheet()
    }

    private var editor: some View {
        NavigationStack {
            Form {
                Section {
                    petPicker
                    DatePicker("Wann", selection: $entry.date)
                }

                Section("Wie geht's?") {
                    moodPicker
                }

                Section {
                    TextField("Überschrift (optional)", text: $entry.title)
                        .font(Theme.title(18))
                    TextField("Was ist passiert?", text: $entry.text, axis: .vertical)
                        .lineLimit(4...12)
                }

                Section("Themen") {
                    tagPicker
                }

                Section {
                    PhotoField(filename: $entry.photoFilename)
                }

                if entry.petIDs.count == 1, !exists {
                    Section {
                        HStack {
                            TextField("Gewicht (optional)", text: $weightText)
                                .keyboardType(.numberPad)
                            Text("g").foregroundStyle(Theme.inkSoft)
                        }
                    } footer: {
                        Text("Wird zusätzlich in der Gewichtskurve eingetragen.")
                    }
                }

                if exists {
                    Section {
                        Button("Eintrag löschen", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .ambientBackground()
            .navigationTitle(exists ? "Eintrag" : "Neuer Eintrag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen", role: .cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", role: .confirm) { save() }
                        .disabled(entry.petIDs.isEmpty)
                }
            }
            .confirmationDialog("Eintrag löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    store.deleteDiary(entry)
                    dismiss()
                }
            }
        }
    }

    private var petPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(store.pets) { pet in
                    let selected = entry.petIDs.contains(pet.id)
                    Button {
                        withAnimation(.snappy) {
                            if selected { entry.petIDs.removeAll { $0 == pet.id } } else { entry.petIDs.append(pet.id) }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            PetAvatar(pet: pet, size: 26)
                            Text(pet.name).font(.subheadline.weight(.semibold))
                        }
                        .padding(.leading, 4).padding(.trailing, 12).padding(.vertical, 4)
                        .background(selected ? pet.tint.opacity(0.2) : Theme.sunken, in: Capsule())
                        .overlay(Capsule().strokeBorder(selected ? pet.tint : .clear, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var moodPicker: some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(DiaryEntry.Mood.allCases) { mood in
                    let selected = entry.mood == mood
                    Button {
                        withAnimation(.bouncy) { entry.mood = mood }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: mood.symbol)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(mood.tint)
                                .font(selected ? .title2 : .title3)
                            Text(mood.shortLabel).font(.caption2.weight(selected ? .bold : .regular))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 58)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(selected ? .regular.tint(Theme.carrot.opacity(0.22)).interactive() : .regular.interactive(),
                                 in: .rect(cornerRadius: 14))
                    .glassEffectID(mood.rawValue, in: glass)
                    .accessibilityLabel(mood.label)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }

    private var tagPicker: some View {
        let columns = [GridItem(.adaptive(minimum: 110), spacing: 8)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(DiaryTag.allCases) { tag in
                let selected = entry.tags.contains(tag)
                Button {
                    if selected { entry.tags.removeAll { $0 == tag } } else { entry.tags.append(tag) }
                } label: {
                    Label(tag.rawValue, systemImage: tag.symbol)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(selected ? Theme.carrot.opacity(0.16) : Theme.sunken,
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .foregroundStyle(selected ? Theme.carrot : Theme.ink)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func save() {
        entry.title = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.text = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
        store.upsertDiary(entry)
        if let grams = Int(weightText.filter(\.isNumber)), grams > 0, let petID = entry.petIDs.first {
            store.addWeight(grams, on: entry.date, to: petID)
        }
        dismiss()
    }
}
