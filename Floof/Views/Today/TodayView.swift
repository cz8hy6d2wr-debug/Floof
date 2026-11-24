import SwiftUI

/// "Heute"-Tab: wechselt je nach Faltzustand zwischen Einhand- und Zweispalten-Layout.
///
/// Es gibt bewusst nur *einen* NavigationStack und die Sheets hängen hier oben:
/// Beim Auf- oder Zuklappen tauscht nur der Inhalt, ein offener Editor bleibt offen.
struct TodayView: View {
    @Environment(\.devicePosture) private var posture
    @Environment(PetStore.self) private var store
    @State private var newEntry: DiaryEntry?
    @State private var selection = TodaySelection()
    @State private var effectRun = 0
    private var weather: WeatherStore { WeatherStore.shared }

    var body: some View {
        NavigationStack {
            Group {
                if store.pets.isEmpty {
                    WelcomeView()
                } else {
                    switch posture {
                    case .folded:
                        CompactDashboardView(selection: $selection)
                            .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.96)), removal: .opacity))
                    case .unfolded:
                        ExpandedDashboardView(selection: $selection)
                            .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 1.03)), removal: .opacity))
                    }
                }
            }
            .ambientBackground()
            // Wetter rund um die Dynamic Island – 10 Sekunden beim Öffnen.
            .overlay(alignment: .top) {
                if !store.pets.isEmpty, let condition = weather.condition, let w = weather.current {
                    WeatherIslandEffect(condition: condition, temperature: Int(w.temperature.rounded()), posture: posture)
                        .id("\(condition.rawValue)-\(effectRun)-\(posture == .folded)")
                }
            }
            .onAppear { effectRun += 1 }
            .task { await weather.refreshIfNeeded() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !store.pets.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        TodayPetMenu(petID: $selection.petID)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Tagebuch-Eintrag", systemImage: "square.and.pencil") {
                            let pets = selection.petID.map { [$0] } ?? store.pets.map(\.id)
                            newEntry = DiaryEntry(date: entryDate, petIDs: pets)
                        }
                    }
                }
            }
            .sheet(item: $newEntry) { DiaryEditor(entry: $0) }
            .onAppear {
                // Ein Tier: direkt dieses zeigen, mehrere: alle.
                if selection.petID == nil, store.pets.count == 1 { selection.petID = store.pets.first?.id }
            }
        }
    }

    /// Eintrag für den gewählten Tag (heute: jetzt, sonst Mittag dieses Tages).
    private var entryDate: Date {
        selection.isToday ? .now
            : Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: selection.day) ?? selection.day
    }
}

/// Erster Start: ein Tier anlegen oder einen Export laden.
private struct WelcomeView: View {
    @State private var showsEditor = false
    @State private var showsSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Image("FloofLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
                .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
                .accessibilityHidden(true)
            HandTitle(text: "Willkommen bei Floof", size: 32)
            Text("Hier landet alles, was deine Tiere betrifft: Medikamente, Gewicht, Tierarzt – und die kleinen Momente dazwischen.")
                .foregroundStyle(Theme.inkSoft)
            GlassEffectContainer(spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    Button("Erstes Tier anlegen", systemImage: "plus") { showsEditor = true }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                    Button("Floof-Export laden", systemImage: "square.and.arrow.down") { showsSettings = true }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                }
            }
            .padding(.top, 8)
            Spacer()
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: 520, alignment: .leading)
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showsEditor) { PetEditor(pet: .new()) }
        .sheet(isPresented: $showsSettings) { SettingsView() }
    }
}
