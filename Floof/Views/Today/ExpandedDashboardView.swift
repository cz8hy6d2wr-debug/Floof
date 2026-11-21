import SwiftUI

/// Innendisplay (7,6", 4:3): zwei gleich breite Spalten, der Zwischenraum liegt auf dem Falz.
/// Links: Tag, Wochenkalender, Gaben, Wenn nötig, Tages-Check.
/// Rechts: Kacheln, Hinweise, Gewicht, Impfungen, Abzeichen.
/// Navigation, Toolbar und Sheets liegen in `TodayView`, damit sie das Falten überstehen.
struct ExpandedDashboardView: View {
    @Environment(PetStore.self) private var store
    @Binding var selection: TodaySelection

    var body: some View {
        let pet = selection.petID.flatMap(store.pet) ?? store.selectedPet

        FoldColumns {
            column {
                TodayHeader(selection: selection)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
                WeekStrip(selection: $selection)
                DoseList(selection: selection)
                if selection.isToday {
                    AsNeededSection(pet: selection.petID.flatMap(store.pet))
                    DailyCheckCard()
                }
            }
        } trailing: {
            column {
                StatTiles(petID: pet?.id)
                CabinetAlertCard()
                if let pet {
                    WeightChartView(pet: pet)
                    VaccinationCalendarView(pet: pet)
                    PetProfileCard(pet: pet)
                }
                BadgeShelf()
            }
        }
        .animation(.smooth, value: selection.petID)
    }

    private func column<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16, content: content)
                .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        // Glas-Schatten nicht an den Spaltenrändern abschneiden.
        .scrollClipDisabled()
    }
}
