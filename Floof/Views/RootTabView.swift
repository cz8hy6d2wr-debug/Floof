import SwiftUI

enum AppTab: String, Hashable {
    case today, history, pets, more
}

/// Hauptnavigation.
///
/// Liquid Glass: Die Tab-Leiste ist systemseitig aus Glas und schrumpft beim Scrollen
/// (`tabBarMinimizeBehavior`). Abgehakt wird direkt in der Liste auf "Heute",
/// in den Widgets oder in der Live-Aktivität – eine Extra-Leiste braucht es nicht.
///
/// Faltzustand: Die Größe wird hier einmal gemessen und als `devicePosture` an alle
/// Tabs weitergegeben. Jeder Tab hat genau einen NavigationStack, dessen Inhalt beim
/// Falten wechselt – Auswahl, geöffnete Details und offene Editoren bleiben erhalten.
struct RootTabView: View {
    @Environment(PetStore.self) private var store
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: AppTab = DemoMode.startTab ?? .today
    @State private var size: CGSize = .zero
    @State private var showsGarden = DemoMode.opensGarden

    var body: some View {
        let posture = DevicePosture.resolve(size: size, horizontalSizeClass: horizontalSizeClass)

        TabView(selection: $tab) {
            Tab("Heute", image: "tab.heute", value: AppTab.today) {
                TodayView()
            }
            Tab("Verlauf", image: "tab.verlauf", value: AppTab.history) {
                HistoryView()
            }
            .badge(store.newActivityCount)
            Tab("Tiere", image: "tab.tiere", value: AppTab.pets) {
                PetsView()
            }
            Tab("Mehr", image: "tab.mehr", value: AppTab.more) {
                MoreView()
            }
            .badge(store.cabinetAlerts.count)
        }
        // Neuer Tag → alles, was vom heutigen Datum abhängt, neu aufbauen
        // (Tagesplan, Datum, Wochenpunkte, Serie, Reichweiten im Schrank).
        .id(store.currentDay)
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .environment(\.devicePosture, posture)
        .animation(.smooth(duration: 0.35), value: posture)
        .onChange(of: posture) { old, new in
            if old == .folded, new == .unfolded { EasterEggs.shared.didUnfold() }
        }
        .celebrations(store)
        .overlay { EasterEggOverlay(posture: posture) }
        .overlay(alignment: .top) { ToastView() }
        // Tageswechsel erkennen: um Mitternacht (App offen) und beim Zurückkehren in die App.
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            store.refreshDay()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.refreshDay() }
        }
        // Empfangene .floof-Dateien (AirDrop, Dateien-App, Nachrichten) öffnen hier.
        .onOpenURL { url in
            guard url.isFileURL else { return }
            do { store.pendingImport = try PendingImport(url: url) }
            catch { store.showToast("Datei konnte nicht gelesen werden") }
        }
        .fullScreenCover(isPresented: $showsGarden) { GardenView() }
        .sheet(item: Binding(get: { store.pendingImport }, set: { store.pendingImport = $0 })) {
            ImportReviewSheet(pending: $0)
        }
        .animation(.spring(duration: 0.35), value: store.toast)
    }
}

/// Kurze gläserne Bestätigung am oberen Rand.
private struct ToastView: View {
    @Environment(PetStore.self) private var store

    var body: some View {
        if let text = store.toast {
            Label(text, systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16).padding(.vertical, 10)
                .glassEffect(.regular.tint(Theme.leaf.opacity(0.25)), in: .capsule)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .id(text)
        }
    }
}

#Preview("Zugeklappt") {
    RootTabView().environment(PetStore.preview)
}

#Preview("Aufgeklappt (4:3)", traits: .fixedLayout(width: 744, height: 992)) {
    RootTabView().environment(PetStore.preview)
}

#Preview("OLED-Dunkel") {
    RootTabView().environment(PetStore.preview).preferredColorScheme(.dark)
}
