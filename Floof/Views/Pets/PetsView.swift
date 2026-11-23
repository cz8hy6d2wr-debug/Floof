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
    @State private var sheets = PetSheets()
    /// Aufgeklappt mit zwei oder mehr Tieren: nebeneinander vergleichen statt Liste | Detail.
    @AppStorage("floof.pets.duo") private var duo = true

    private var showsDuo: Bool { posture == .unfolded && duo && store.pets.count >= 2 }

    var body: some View {
        @Bindable var sheets = sheets
        NavigationStack(path: $path) {
            Group {
                if showsDuo {
                    DuoView()
                } else if posture == .unfolded {
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
            .ambientBackground()
            .navigationDestination(for: Pet.ID.self) { PetDetailView(petID: $0) }
            .toolbar {
                if posture == .unfolded && store.pets.count >= 2 {
                    ToolbarItem(placement: .topBarLeading) {
                        Picker("Ansicht", selection: $duo.animation(.smooth)) {
                            Text("Liste").tag(false)
                            Text("Duo").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Tier hinzufügen", systemImage: "plus") { showsNewPet = true }
                }
            }
            .sheet(isPresented: $showsNewPet) { PetEditor(pet: .new()) }
            .sheet(item: $sheets.editPet) { PetEditor(pet: $0) }
            .sheet(item: $sheets.weigh) { WeightSheet(pet: $0) }
            .sheet(item: $sheets.care) { CareEntryEditor(entry: $0.entry, petID: $0.petID) }
            .sheet(item: $sheets.article) { LexiconSheet(start: .article($0.id)) }
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
                        Label("\(w.grams.formatted()) g", systemImage: "scalemass").font(.caption)
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

// MARK: - Duo-Ansicht

/// Aufgeklappt: zwei Tiere nebeneinander, links und rechts vom Falz –
/// auf beiden Seiten dieselbe Reihenfolge, damit man direkt vergleichen kann.
private struct DuoView: View {
    @Environment(PetStore.self) private var store
    @AppStorage("floof.pets.duo.left") private var leftID = ""
    @AppStorage("floof.pets.duo.right") private var rightID = ""

    var body: some View {
        let (left, right) = pair
        FoldColumns {
            if let left { DuoColumn(pet: left, choose: { leftID = $0 }, excluded: right?.id) }
        } trailing: {
            if let right { DuoColumn(pet: right, choose: { rightID = $0 }, excluded: left?.id) }
        }
    }

    /// Gewählte Tiere – sonst die ersten beiden. Nie zweimal dasselbe.
    private var pair: (Pet?, Pet?) {
        let pets = store.pets
        let left = store.pet(leftID) ?? pets.first
        let right = store.pet(rightID).flatMap { $0.id == left?.id ? nil : $0 }
            ?? pets.first { $0.id != left?.id }
        return (left, right)
    }
}

private struct DuoColumn: View {
    @Environment(PetStore.self) private var store
    @Environment(PetSheets.self) private var sheets
    let pet: Pet
    let choose: (Pet.ID) -> Void
    let excluded: Pet.ID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                WeightChartView(pet: pet) { sheets.weigh = pet }
                PetHealthHistory(pet: pet, dayCount: 7)
                medications
                PetRoutinesCard(pet: pet)
            }
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .contentMargins(.bottom, 90, for: .scrollContent)
    }

    private var header: some View {
        HStack(spacing: 12) {
            NavigationLink(value: pet.id) {
                HStack(spacing: 12) {
                    PetAvatar(pet: pet, size: 50)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pet.name).font(Theme.title(24)).foregroundStyle(Theme.ink)
                        Text("\(pet.breed.isEmpty ? pet.animalType : pet.breed) · \(pet.ageDescription)")
                            .font(.caption).foregroundStyle(Theme.inkSoft).lineLimit(1)
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
            // Mehr als zwei Tiere: hier tauschen.
            if store.pets.count > 2 {
                Menu {
                    ForEach(store.pets.filter { $0.id != pet.id && $0.id != excluded }) { other in
                        Button(other.name) { withAnimation(.smooth) { choose(other.id) } }
                    }
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 34, height: 34)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .accessibilityLabel("Anderes Tier zeigen")
            }
        }
        .padding(.horizontal, 4)
    }

    private var medications: some View {
        let meds = pet.medications.sorted { !$0.isAsNeeded && $1.isAsNeeded }
        let today = store.doses(for: pet)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Medikamente").sectionLabel()
            if meds.isEmpty {
                Text("Keine Medikamente – gesund und munter.")
                    .font(.subheadline).foregroundStyle(Theme.inkSoft)
            } else {
                ForEach(meds) { med in
                    let doses = today.filter { $0.medication.id == med.id }
                    HStack(spacing: 12) {
                        FloofIcon(symbol: store.cabinetItem(med.cabinetItemID)?.form.symbol ?? "drop.fill", size: 22)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(med.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                            Text(detail(med, doses: doses)).font(.caption).foregroundStyle(Theme.inkSoft).lineLimit(1)
                        }
                        Spacer(minLength: 6)
                        if !doses.isEmpty {
                            let given = doses.filter(store.isTaken).count
                            Text("\(given)/\(doses.count)")
                                .font(.caption.weight(.semibold).monospacedDigit())
                                .foregroundStyle(given == doses.count ? Theme.leaf : Theme.inkSoft)
                        }
                    }
                }
            }
        }
        .card()
    }

    private func detail(_ med: CareEntry, doses: [ScheduledDose]) -> String {
        let amount: String
        if let item = store.cabinetItem(med.cabinetItemID), let value = med.effectiveDoseAmount {
            amount = item.formatted(value)
        } else {
            amount = med.details.split(separator: "\n").first.map(String.init) ?? ""
        }
        if med.isAsNeeded { return amount.isEmpty ? "bei Bedarf" : "\(amount) · bei Bedarf" }
        let times = doses.map(\.time.label).joined(separator: " & ")
        return [amount, times].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
