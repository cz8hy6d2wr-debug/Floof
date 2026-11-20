import SwiftUI
import UniformTypeIdentifiers

/// Außendisplay (5,4"): Einhand-Dashboard mit Fokus auf die heutigen Medikamente.
/// - Große Karten, ganze Fläche tippbar
/// - Wichtigste Aktion ("Gegeben") unten im Daumenbereich
struct CompactDashboardView: View {
    @Environment(PetStore.self) private var store

    var body: some View {
        let doses = store.todaysDoses()
        let open = doses.filter { !store.isTaken($0) }

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header(open: open)
                        .padding(.top, 4)
                        .padding(.bottom, 6)

                    StreakStrip()

                    if doses.isEmpty {
                        ContentUnavailableView("Heute nichts zu geben", systemImage: "leaf",
                                               description: Text("Genieß den Tag mit den beiden."))
                    } else {
                        ForEach(doses) { dose in
                            MedicationCard(dose: dose, style: .large)
                        }
                    }

                    AsNeededSection()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Theme.paper)
            .toolbarBackground(Theme.paper, for: .navigationBar)
            .toolbar { ImportToolbarItem() }
            // Daumenzone: nächste offene Dosis mit einem Tipp erledigen.
            .safeAreaInset(edge: .bottom) {
                if let next = open.first {
                    NextDoseBar(dose: next)
                }
            }
        }
    }

    private func header(open: [ScheduledDose]) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.inkSoft)
                HandTitle(text: Greeting.now)
                Text(Greeting.status(open: open, pets: store.pets))
                    .font(.callout)
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
            DoseProgressRing(progress: store.progress(store.todaysDoses()), lineWidth: 6)
                .frame(width: 54, height: 54)
        }
    }
}

/// Texte, die nach Mensch klingen statt nach System.
enum Greeting {
    static var now: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<11: "Guten Morgen"
        case 11..<17: "Hallo am Mittag"
        case 17..<22: "Guten Abend"
        default: "Noch wach?"
        }
    }

    static func status(open: [ScheduledDose], pets: [Pet]) -> String {
        guard let next = open.first else {
            return pets.count == 1 ? "Alles gegeben. \(pets[0].name) ist versorgt."
                                   : "Alles gegeben. Feierabend für euch alle."
        }
        if next.isOverdue { return "\(next.pet.name) wartet noch auf \(next.medication.title)." }
        return open.count == 1 ? "Noch eine Gabe heute, um \(next.time.label)."
                               : "Noch \(open.count) Gaben, die nächste um \(next.time.label)."
    }
}

private struct NextDoseBar: View {
    @Environment(PetStore.self) private var store
    let dose: ScheduledDose

    var body: some View {
        Button {
            store.toggle(dose)
        } label: {
            HStack(spacing: 12) {
                PetAvatar(pet: dose.pet, size: 36)
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(dose.medication.title) für \(dose.pet.name)").font(.headline)
                    Text("\(dose.time.label) Uhr · +10 Möhren wenn pünktlich").font(.caption).opacity(0.85)
                }
                Spacer()
                Text("Gegeben").font(.headline)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.white.opacity(0.22), in: Capsule())
            }
            .padding(.leading, 10).padding(.trailing, 10)
            .frame(maxWidth: .infinity, minHeight: 62)
            .foregroundStyle(.white)
            .background(Theme.carrot, in: Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background(Theme.paper.opacity(0.96))
        .accessibilityLabel("\(dose.medication.title) für \(dose.pet.name) als gegeben markieren")
    }
}

/// Medikamente ohne festen Zeitplan ("bei Bedarf").
struct AsNeededSection: View {
    @Environment(PetStore.self) private var store
    var pet: Pet? = nil   // nil = alle Tiere

    var body: some View {
        let items = (pet.map { [$0] } ?? store.pets)
            .flatMap { p in p.medications.filter(\.isAsNeeded).map { (p, $0) } }

        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Wenn nötig").font(Theme.title(18))
                ForEach(items, id: \.1.id) { item in
                    HStack(spacing: 10) {
                        Image(systemName: "pills").foregroundStyle(item.0.tint)
                        VStack(alignment: .leading) {
                            Text(item.1.title).font(.subheadline.weight(.semibold))
                            Text(pet == nil ? "\(item.0.name) · \(item.1.details)" : item.1.details)
                                .font(.caption).foregroundStyle(Theme.inkSoft)
                        }
                    }
                }
            }
            .card()
        }
    }
}

struct ImportToolbarItem: ToolbarContent {
    @Environment(PetStore.self) private var store
    @State private var isImporting = false
    @State private var importError: String?

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Import", systemImage: "square.and.arrow.down") { isImporting = true }
                .tint(Theme.carrot)
                .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
                    do { try store.importExport(from: result.get()) }
                    catch { importError = error.localizedDescription }
                }
                .alert("Das hat nicht geklappt", isPresented: .constant(importError != nil)) {
                    Button("OK") { importError = nil }
                } message: { Text(importError ?? "") }
        }
    }
}
