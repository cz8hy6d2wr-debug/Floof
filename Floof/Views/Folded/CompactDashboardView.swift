import SwiftUI
import UniformTypeIdentifiers

/// Außendisplay (5,4"): Einhand-Dashboard mit Fokus auf die heutigen Medikamente.
/// - Große Karten, ganze Fläche tippbar
/// - Wichtigste Aktion ("Nächste Dosis") unten im Daumenbereich
struct CompactDashboardView: View {
    @Environment(PetStore.self) private var store

    var body: some View {
        let doses = store.todaysDoses()
        let open = doses.filter { !store.isTaken($0) }

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    summary(doses: doses, open: open.count)

                    if doses.isEmpty {
                        ContentUnavailableView("Heute keine Medikamente", systemImage: "checkmark.seal",
                                               description: Text("Für heute ist nichts geplant."))
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
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Heute")
            .toolbar { ImportToolbarItem() }
            // Daumenzone: nächste offene Dosis mit einem Tipp erledigen.
            .safeAreaInset(edge: .bottom) {
                if let next = open.first {
                    NextDoseBar(dose: next)
                }
            }
        }
    }

    private func summary(doses: [ScheduledDose], open: Int) -> some View {
        HStack(spacing: 16) {
            DoseProgressRing(progress: store.progress(doses))
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.subheadline).foregroundStyle(.secondary)
                Text(open == 0 ? "Alles erledigt 🎉" : "\(open) Gabe\(open == 1 ? "" : "n") offen")
                    .font(.title3.bold())
            }
            Spacer()
            HStack(spacing: -10) {
                ForEach(store.pets) { PetAvatar(pet: $0, size: 36) }
            }
        }
        .card()
    }
}

private struct NextDoseBar: View {
    @Environment(PetStore.self) private var store
    let dose: ScheduledDose

    var body: some View {
        Button {
            store.toggle(dose)
        } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill").font(.title2)
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(dose.medication.title) · \(dose.pet.name)").font(.headline)
                    Text("\(dose.time.label) Uhr").font(.caption).opacity(0.85)
                }
                Spacer()
                Text("Gegeben").font(.headline)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 60)
            .foregroundStyle(.white)
            .background(dose.pet.tint.gradient, in: Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .background(.bar)
        .accessibilityLabel("Nächste Dosis: \(dose.medication.title) für \(dose.pet.name) als gegeben markieren")
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
                Text("Bei Bedarf").font(.headline)
                ForEach(items, id: \.1.id) { item in
                    HStack {
                        Image(systemName: "pills").foregroundStyle(item.0.tint)
                        VStack(alignment: .leading) {
                            Text(item.1.title).font(.subheadline.weight(.semibold))
                            Text(pet == nil ? "\(item.0.name) · \(item.1.details)" : item.1.details)
                                .font(.caption).foregroundStyle(.secondary)
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
                .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
                    do { try store.importExport(from: result.get()) }
                    catch { importError = error.localizedDescription }
                }
                .alert("Import fehlgeschlagen", isPresented: .constant(importError != nil)) {
                    Button("OK") { importError = nil }
                } message: { Text(importError ?? "") }
        }
    }
}
