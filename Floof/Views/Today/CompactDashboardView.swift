import SwiftUI

/// Außendisplay (5,4"): Einhand-Layout.
/// Oben Tag und Fortschritt, darunter der Wochenkalender, die Gaben als Glas-Liste
/// und ein paar ruhige Kacheln. "Gegeben" für die nächste Gabe liegt in der
/// gläsernen Leiste über den Tabs – im Daumenbereich.
struct CompactDashboardView: View {
    @Environment(PetStore.self) private var store
    @Binding var selection: TodaySelection

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TodayHeader(selection: selection)
                    .padding(.horizontal, 4)
                    .padding(.top, 8)
                    .padding(.bottom, 6)

                WeekStrip(selection: $selection)
                DoseList(selection: selection)

                ForEach(checkPets) { pet in
                    HealthCheckCard(pet: pet, day: selection.day)
                        .id("\(pet.id)-\(DoseKey.day(selection.day))")
                }
                if selection.isToday {
                    TodayHintsCard(petID: selection.petID, limit: 2)
                    AsNeededSection(pet: selection.petID.flatMap(store.pet))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .foldedReadableWidth()
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    /// Kurz-Check für vergangene Tage und heute, nicht für die Zukunft.
    private var checkPets: [Pet] {
        guard !selection.isFuture else { return [] }
        return selection.petID.flatMap(store.pet).map { [$0] } ?? store.pets
    }
}

/// Texte, die nach Mensch klingen statt nach System.
enum Greeting {
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

/// Medikamente ohne festen Zeitplan ("bei Bedarf") – mit Gegeben-Knopf, der Lager & Tagebuch pflegt.
struct AsNeededSection: View {
    @Environment(PetStore.self) private var store
    var pet: Pet? = nil   // nil = alle Tiere

    var body: some View {
        let items = (pet.map { [$0] } ?? store.pets)
            .flatMap { p in p.medications.filter(\.isAsNeeded).map { (p, $0) } }

        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Wenn nötig").sectionLabel()
                ForEach(items, id: \.1.id) { item in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.1.title).font(.subheadline.weight(.semibold))
                            Text(pet == nil && store.pets.count > 1 ? "\(item.0.name) · \(item.1.details)" : item.1.details)
                                .font(.caption).foregroundStyle(Theme.inkSoft)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button("Eintragen") { store.logAsNeeded(item.1, for: item.0) }
                            .buttonStyle(.glass)
                            .controlSize(.small)
                    }
                }
            }
            .card()
        }
    }
}

/// Hinweis, wenn im Schrank etwas knapp wird oder abläuft.
struct CabinetAlertCard: View {
    @Environment(PetStore.self) private var store

    var body: some View {
        let alerts = store.cabinetAlerts
        if !alerts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label("Im Schrank wird's knapp", systemImage: "cross.case.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.berry)
                ForEach(alerts) { item in
                    HStack {
                        Text(item.name).font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(CabinetStatusText.short(store.status(of: item)))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
            }
            .card()
        }
    }
}
