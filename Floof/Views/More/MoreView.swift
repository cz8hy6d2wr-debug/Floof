import SwiftUI

/// "Mehr": alles, was man nicht täglich braucht – an einem Ort.
struct MoreView: View {
    @Environment(PetStore.self) private var store
    @State private var showsLexicon = false
    @State private var showsSettings = false
    @State private var showsGarden = false

    private enum Route: Hashable { case cabinet, progress }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HandTitle(text: "Mehr", size: 32)
                        .padding(.top, 8)

                    Button { showsGarden = true } label: {
                        row("Mümmelwiese", symbol: "hare.fill",
                            detail: "Spiel: Kaninchen zu Besuch, Rasen, Möhrenbeet")
                    }
                    .buttonStyle(.plain)
                    .glassPanel()

                    VStack(spacing: 0) {
                        NavigationLink(value: Route.cabinet) {
                            row("Medikamentenschrank", symbol: "cross.case.fill",
                                detail: cabinetDetail, alert: !store.cabinetAlerts.isEmpty)
                        }
                        Divider().padding(.leading, 66)
                        Button { showsLexicon = true } label: {
                            row("Lexikon", symbol: "books.vertical.fill",
                                detail: "Notfall, Krankheiten, Futter-Check, RodiCare")
                        }
                    }
                    .buttonStyle(.plain)
                    .glassPanel()

                    VStack(spacing: 0) {
                        Button { showsSettings = true } label: {
                            row("Gemeinsam nutzen", symbol: "person.2.fill", detail: syncDetail)
                        }
                        Divider().padding(.leading, 66)
                        Button { showsSettings = true } label: {
                            row("Einstellungen & Teilen", symbol: "gearshape.fill",
                                detail: "Erinnerungen, AirDrop, Import & Export")
                        }
                        Divider().padding(.leading, 66)
                        NavigationLink(value: Route.progress) {
                            row("Möhren & Abzeichen", symbol: "carrot.fill",
                                detail: "\(store.game.carrots) Möhren · \(store.streak) Tage am Stück")
                        }
                    }
                    .buttonStyle(.plain)
                    .glassPanel()

                    signature
                        .padding(.top, 28)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .foldedReadableWidth()
            }
            .ambientBackground()
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .cabinet: CabinetView()
                case .progress: ProgressPage()
                }
            }
            .sheet(isPresented: $showsLexicon) { LexiconView() }
            .sheet(isPresented: $showsSettings) { SettingsView() }
            .fullScreenCover(isPresented: $showsGarden) { GardenView() }
        }
    }

    /// Unterschrift unten – das Zeichen verrät bei jedem Tipp einen Kaninchen-Fakt.
    private var signature: some View {
        VStack(spacing: 8) {
            Button { EasterEggs.shared.nextFact() } label: {
                Image("FloofMark")
                    .resizable().scaledToFit()
                    .frame(width: 34, height: 34)
                    .foregroundStyle(Theme.inkSoft.opacity(0.7))
                    .padding(6)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Kaninchen-Fakt")
            Text("floof").font(Theme.title(17)).foregroundStyle(Theme.inkSoft)
            if !store.pets.isEmpty {
                Text("Gemacht für \(store.pets.map(\.name).formatted(.list(type: .and)))")
                    .font(.caption).foregroundStyle(Theme.inkSoft.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var cabinetDetail: String {
        let alerts = store.cabinetAlerts.count
        if store.cabinet.isEmpty { return "Noch leer" }
        return alerts == 0 ? "\(store.cabinet.count) Artikel, alles da" : "\(alerts) wird knapp oder läuft ab"
    }

    private var syncDetail: String {
        let sync = SyncManager.shared
        guard let folder = sync.folderName else { return "Mit Partner:in teilen (iCloud Drive)" }
        if let last = sync.lastSync { return "\(folder) · abgeglichen \(last.formatted(.relative(presentation: .named)))" }
        return folder
    }

    private func row(_ title: String, symbol: String, detail: String, alert: Bool = false) -> some View {
        HStack(spacing: 14) {
            FloofIcon(symbol: symbol, size: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(detail).font(.caption).foregroundStyle(alert ? Theme.berry : Theme.inkSoft).lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(Theme.inkSoft)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .contentShape(.rect)
    }
}

/// Möhren, Serie und Abzeichen.
private struct ProgressPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                StatTiles()
                BadgeShelf()
            }
            .padding(16)
            .foldedReadableWidth()
        }
        .ambientBackground()
        .navigationTitle("Möhren & Abzeichen")
        .navigationBarTitleDisplayMode(.inline)
    }
}
