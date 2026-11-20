import SwiftUI

/// Innendisplay (7,6", 4:3): zwei gleich breite Spalten, der Zwischenraum liegt auf dem Falz.
/// Links: Medikamenten-Checkliste + Stammdaten · Rechts: Gewicht, Impfungen, Abzeichen.
/// Beide Spalten scrollen unabhängig, damit Checkliste und Diagramm gleichzeitig sichtbar bleiben.
/// Navigation, Toolbar und Sheets liegen in `TodayView`, damit sie das Falten überstehen.
struct ExpandedDashboardView: View {
    @Environment(PetStore.self) private var store

    var body: some View {
        Group {
            if let pet = store.selectedPet {
                FoldColumns {
                    column {
                        ChecklistCard(pet: pet)
                        AsNeededSection(pet: pet)
                        DailyCheckCard()
                        PetProfileCard(pet: pet)
                    }
                } trailing: {
                    column {
                        StreakStrip()
                        CabinetAlertCard()
                        WeightChartView(pet: pet)
                        VaccinationCalendarView(pet: pet)
                        BadgeShelf()
                    }
                }
                .id(pet.id)
                .transition(.opacity)
            }
        }
        .animation(.smooth, value: store.selectedPetID)
    }

    private func column<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            VStack(spacing: 16, content: content)
                .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
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
