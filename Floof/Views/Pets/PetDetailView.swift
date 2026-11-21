import SwiftUI

/// Sheets der Tier-Ansichten. Liegen am NavigationStack von `PetsView`,
/// damit ein offener Editor das Auf-/Zuklappen übersteht.
@MainActor
@Observable
final class PetSheets {
    var editPet: Pet?
    var weigh: Pet?
    var care: CareSheet?
    var article: ArticleSheet?

    struct ArticleSheet: Identifiable {
        let id: String
    }

    struct CareSheet: Identifiable {
        let entry: CareEntry
        let petID: Pet.ID
        var id: String { entry.id }
    }
}

struct PetDetailView: View {
    @Environment(PetStore.self) private var store
    @Environment(PetSheets.self) private var sheets
    let petID: Pet.ID
    /// Aufgeklappt als rechte Spalte eingebettet (kein eigener Titel).
    var embedded = false

    var body: some View {
        if let pet = store.pet(petID) {
            content(pet)
        } else {
            ContentUnavailableView("Nicht gefunden", systemImage: "pawprint")
        }
    }

    private func content(_ pet: Pet) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(pet)
                PetProfileCard(pet: pet)

                WeightChartView(pet: pet)
                    .overlay(alignment: .bottomTrailing) {
                        Button("Wiegen", systemImage: "plus") { sheets.weigh = pet }
                            .buttonStyle(.glass)
                            .controlSize(.small)
                            .padding(12)
                    }

                careSection(pet, kind: .medication, title: "Medikamente")
                careSection(pet, kind: .condition, title: "Erkrankungen")
                careSection(pet, kind: .vaccination, title: "Impfungen")
                careSection(pet, kind: .other, title: "Sonstiges")
                PetHealthHistory(pet: pet)
                PetRoutinesCard(pet: pet)
                readingSection(pet)
            }
            .padding(embedded ? .vertical : .all, embedded ? 12 : 16)
        }
        .scrollIndicators(embedded ? .hidden : .automatic)
        .ambientBackground()
        .navigationTitle(embedded ? "" : pet.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                // Ein Tier per AirDrop teilen – z. B. an Tiersitter.
                ShareLink(item: store.share(pet),
                          preview: SharePreview("Floof: \(pet.name)", image: Image("FloofLogo"))) {
                    Label("\(pet.name) teilen", systemImage: "square.and.arrow.up")
                }
                Button("Bearbeiten") { sheets.editPet = pet }
            }
        }
    }

    private func header(_ pet: Pet) -> some View {
        HStack(spacing: 16) {
            PetAvatar(pet: pet, size: 96)
                .rotationEffect(.degrees(-2))
            VStack(alignment: .leading, spacing: 6) {
                HandTitle(text: pet.name, size: 30)
                Text(pet.animalType).font(.subheadline).foregroundStyle(Theme.inkSoft).padding(.top, 6)
            }
        }
        .padding(.vertical, 6)
    }

    private func careSection(_ pet: Pet, kind: CareKind, title: String) -> some View {
        let entries = pet.care.filter { $0.careKind == kind }.sorted { $0.date > $1.date }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(Theme.title(20))
                Spacer()
                Button("Hinzufügen", systemImage: "plus") {
                    let entry = CareEntry(id: UUID().uuidString, date: .now, title: "", details: "", kind: kind.rawValue)
                    sheets.care = .init(entry: entry, petID: pet.id)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
            }
            if entries.isEmpty {
                Text(emptyText(kind)).font(.subheadline).foregroundStyle(Theme.inkSoft)
            }
            ForEach(entries) { entry in
                Button { sheets.care = .init(entry: entry, petID: pet.id) } label: { CareRow(entry: entry) }
                    .buttonStyle(.plain)
                if entry.id != entries.last?.id { Divider() }
            }
        }
        .card()
    }

    /// Lexikon-Artikel, die zu Medikamenten, Erkrankungen und Notizen dieses Tieres passen.
    @ViewBuilder
    private func readingSection(_ pet: Pet) -> some View {
        let articles = Lexicon.relevant(for: [pet]).map(\.article)
        if !articles.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Zum Nachlesen", systemImage: "books.vertical").font(Theme.title(20))
                ForEach(articles) { article in
                    Button { sheets.article = .init(id: article.id) } label: {
                        HStack(alignment: .top, spacing: 12) {
                            ArticleIcon(category: article.category)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(article.title).font(.subheadline.weight(.semibold))
                                Text(article.summary).font(.caption).foregroundStyle(Theme.inkSoft).lineLimit(2)
                            }
                            Spacer()
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .card()
        }
    }

    private func emptyText(_ kind: CareKind) -> String {
        switch kind {
        case .medication: "Keine Medikamente – schön!"
        case .condition: "Keine bekannten Erkrankungen."
        case .vaccination: "Noch keine Impfung eingetragen."
        case .other: "Zahnkontrolle, Krallen schneiden, Wurmkur …"
        }
    }
}

private struct CareRow: View {
    @Environment(PetStore.self) private var store
    let entry: CareEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.careKind.symbol)
                .foregroundStyle(Theme.carrot)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title).font(.body.weight(.semibold))
                if !entry.details.isEmpty {
                    Text(entry.details).font(.caption).foregroundStyle(Theme.inkSoft).lineLimit(2)
                }
                if let reminder = entry.reminder {
                    Label(reminder.allTimes.map(\.label).joined(separator: " · ")
                          + (reminder.weekdays.count == 7 ? " täglich" : ""),
                          systemImage: "bell")
                        .font(.caption).foregroundStyle(Theme.inkSoft)
                }
                if let item = store.cabinetItem(entry.cabinetItemID) {
                    Label("\(item.name): \(item.formatted(item.stock)) übrig", systemImage: "cross.case")
                        .font(.caption)
                        .foregroundStyle(CabinetStatusText.color(store.status(of: item)))
                }
            }
            Spacer()
            Text(entry.date, format: .dateTime.day().month().year())
                .font(.caption).foregroundStyle(Theme.inkSoft)
        }
        .contentShape(.rect)
    }
}

// MARK: - Gewicht

struct WeightSheet: View {
    @Environment(PetStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let pet: Pet
    @State private var grams: Int?
    @State private var date = Date.now
    @State private var note = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .firstTextBaseline) {
                        TextField(pet.latestWeight.map { "\($0.grams)" } ?? "Gramm", value: $grams, format: .number)
                            .keyboardType(.numberPad)
                            .font(Theme.number(.largeTitle))
                            .focused($focused)
                        Text("g").font(.title2).foregroundStyle(Theme.inkSoft)
                    }
                    if let grams, let last = pet.latestWeight {
                        let delta = grams - last.grams
                        Text(delta == 0 ? "Genau wie beim letzten Mal."
                                        : "\(delta > 0 ? "+" : "")\(delta) g seit \(last.date.formatted(.dateTime.day().month()))")
                            .font(.subheadline)
                            .foregroundStyle(abs(delta) > 50 ? Theme.berry : Theme.inkSoft)
                    }
                }
                Section {
                    DatePicker("Datum", selection: $date)
                    TextField("Notiz", text: $note)
                }
                if !pet.weights.isEmpty {
                    Section("Bisherige Messungen") {
                        ForEach(pet.weights.sorted { $0.date > $1.date }) { w in
                            LabeledContent(w.date.formatted(date: .abbreviated, time: .omitted), value: "\(w.grams) g")
                        }
                        .onDelete { offsets in
                            let sorted = pet.weights.sorted { $0.date > $1.date }
                            offsets.map { sorted[$0] }.forEach { store.deleteWeight($0, from: pet.id) }
                        }
                    }
                }
            }
            .navigationTitle("\(pet.name) wiegen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen", role: .cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", role: .confirm) {
                        if let grams { store.addWeight(grams, on: date, note: note, to: pet.id) }
                        dismiss()
                    }
                    .disabled((grams ?? 0) <= 0)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
    }
}
