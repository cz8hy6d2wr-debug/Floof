import SwiftUI

/// Innendisplay (7,6", 4:3): zweispaltig.
/// Links: Medikamenten-Checkliste + Stammdaten · Rechts: Gewicht, Impfungen, Abzeichen.
/// Beide Spalten scrollen unabhängig, damit Checkliste und Diagramm gleichzeitig sichtbar bleiben.
struct ExpandedDashboardView: View {
    @Environment(PetStore.self) private var store
    @State private var showsNewEntry = false

    var body: some View {
        NavigationStack {
            Group {
                if let pet = store.selectedPet {
                    HStack(alignment: .top, spacing: 20) {
                        column {
                            ChecklistCard(pet: pet)
                            AsNeededSection(pet: pet)
                            DailyCheckCard()
                            PetProfileCard(pet: pet)
                        }
                        column {
                            StreakStrip()
                            CabinetAlertCard()
                            WeightChartView(pet: pet)
                            VaccinationCalendarView(pet: pet)
                            BadgeShelf()
                        }
                    }
                    .padding(.horizontal, 20)
                    .id(pet.id)
                    .transition(.opacity)
                }
            }
            .animation(.smooth, value: store.selectedPetID)
            .background(Theme.paper)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { PetPickerMenu() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Tagebuch-Eintrag", systemImage: "square.and.pencil") { showsNewEntry = true }
                }
            }
            .sheet(isPresented: $showsNewEntry) {
                DiaryEditor(entry: DiaryEntry(petIDs: [store.selectedPet?.id].compactMap { $0 }))
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
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 8) {
                    HandTitle(text: "Heute für \(pet.name)", size: 24)
                    Text(Greeting.status(open: doses.filter { !store.isTaken($0) }, pets: [pet]))
                        .font(.subheadline).foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                DoseProgressRing(progress: store.progress(doses), lineWidth: 5)
                    .frame(width: 44, height: 44)
            }
            .padding(.bottom, 4)

            if doses.isEmpty {
                Text("Heute stehen für \(pet.name) keine Medikamente an.")
                    .font(.subheadline).foregroundStyle(Theme.inkSoft)
                    .padding(.vertical, 8)
            } else {
                ForEach(doses) { dose in
                    MedicationCard(dose: dose, style: .row, showsPet: false)
                }
            }
        }
    }
}
