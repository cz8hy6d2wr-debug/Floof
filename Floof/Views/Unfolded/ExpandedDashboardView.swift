import SwiftUI

/// Innendisplay (7,6", 4:3): zweispaltig.
/// Links: Medikamenten-Checkliste + Stammdaten · Rechts: Gewichtsverlauf + Impfkalender.
/// Beide Spalten scrollen unabhängig, damit Checkliste und Diagramm gleichzeitig sichtbar bleiben.
struct ExpandedDashboardView: View {
    @Environment(PetStore.self) private var store

    var body: some View {
        NavigationStack {
            Group {
                if let pet = store.selectedPet {
                    HStack(alignment: .top, spacing: 20) {
                        column {
                            ChecklistCard(pet: pet)
                            AsNeededSection(pet: pet)
                            PetProfileCard(pet: pet)
                        }
                        column {
                            WeightChartView(pet: pet)
                            VaccinationCalendarView(pet: pet)
                        }
                    }
                    .padding(.horizontal, 20)
                    .id(pet.id)
                    .transition(.opacity)
                } else {
                    ContentUnavailableView("Keine Tiere", systemImage: "pawprint",
                                           description: Text("Importiere einen Floof-Export."))
                }
            }
            .animation(.smooth, value: store.selectedPetID)
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { PetPickerMenu() }
                ImportToolbarItem()
            }
        }
    }

    private func column<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            VStack(spacing: 16, content: content)
                .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity)
    }
}

private struct ChecklistCard: View {
    @Environment(PetStore.self) private var store
    let pet: Pet

    var body: some View {
        let doses = store.doses(for: pet)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Medikamente heute", systemImage: "pills.fill").font(.headline)
                Spacer()
                DoseProgressRing(progress: store.progress(doses), lineWidth: 5)
                    .frame(width: 40, height: 40)
            }
            if doses.isEmpty {
                Text("Heute keine geplanten Gaben für \(pet.name).")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(doses) { dose in
                    MedicationCard(dose: dose, style: .row, showsPet: false)
                }
            }
        }
    }
}
