import SwiftUI

/// "Heute"-Tab: wechselt je nach Faltzustand zwischen Einhand- und Zweispalten-Layout.
struct TodayView: View {
    @Environment(\.devicePosture) private var posture
    @Environment(PetStore.self) private var store

    var body: some View {
        Group {
            if store.pets.isEmpty {
                NavigationStack { WelcomeView() }
            } else {
                switch posture {
                case .folded:
                    CompactDashboardView()
                        .transition(.asymmetric(insertion: .opacity.combined(with: .scale(0.96)), removal: .opacity))
                case .unfolded:
                    ExpandedDashboardView()
                        .transition(.asymmetric(insertion: .opacity.combined(with: .scale(1.03)), removal: .opacity))
                }
            }
        }
        .background(Theme.paper.ignoresSafeArea())
    }
}

/// Erster Start: ein Tier anlegen oder einen Export laden.
private struct WelcomeView: View {
    @State private var showsEditor = false
    @State private var showsSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Image(systemName: "pawprint.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.carrot)
                .rotationEffect(.degrees(-12))
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
        .background(Theme.paper)
        .sheet(isPresented: $showsEditor) { PetEditor(pet: .new()) }
        .sheet(isPresented: $showsSettings) { SettingsView() }
    }
}
