import SwiftUI

/// Innendisplay (7,6", 4:3): zwei gleich breite Spalten, der Zwischenraum liegt auf dem Falz.
/// Links: Tag, Wochenkalender, Gaben, Wenn nötig, Tages-Check.
/// Rechts: Für heute, Gewicht und die letzten Einträge aus dem Verlauf.
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
                if !selection.isFuture {
                    ForEach(selection.petID.flatMap(store.pet).map { [$0] } ?? store.pets) { pet in
                        HealthCheckCard(pet: pet, day: selection.day)
                            .id("\(pet.id)-\(DoseKey.day(selection.day))")
                    }
                }
                if selection.isToday {
                    AsNeededSection(pet: selection.petID.flatMap(store.pet))
                }
            }
        } trailing: {
            column {
                if selection.isToday {
                    TodayHintsCard(petID: selection.petID)
                }
                if let pet {
                    WeightChartView(pet: pet)
                }
                RecentActivityCard(petID: selection.petID)
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
        // Unten genug Platz, damit nichts unter der Tab-Leiste und der Glas-Leiste verschwindet.
        .contentMargins(.bottom, 140, for: .scrollContent)
    }
}
