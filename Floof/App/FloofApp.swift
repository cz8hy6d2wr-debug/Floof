import SwiftUI

@main
struct FloofApp: App {
    @State private var store: PetStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let store = DemoMode.isActive ? PetStore.preview : PetStore.load()
        _store = State(initialValue: store)
        if !DemoMode.isActive { SyncManager.shared.attach(store) }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(store)
                .tint(Theme.carrot)
                .task {
                    guard !DemoMode.isActive else { return }
                    await ReminderScheduler.requestAuthorization()
                }
        }
        // Lampe (Bewegungssensor) nur im Vordergrund – spart Akku.
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                LightSource.shared.start()
                SyncManager.shared.startForeground()
                // Erinnerungen der nächsten 7 Tage auffrischen (konkrete Termine, nicht wiederholend).
                if !DemoMode.isActive {
                    let snapshot = store.data
                    Task { await ReminderScheduler.reschedule(for: snapshot) }
                }
            } else {
                LightSource.shared.stop()
                SyncManager.shared.stopForeground()
            }
        }
        // Gemeinsame Datei gelegentlich auch im Hintergrund prüfen (iOS entscheidet, wann).
        .backgroundTask(.appRefresh(SyncManager.backgroundTaskID)) {
            await SyncManager.shared.syncNow()
            await SyncManager.shared.scheduleBackgroundRefresh()
        }
    }
}

/// Demo-Modus für automatische Screenshots (Startparameter `-FloofDemo YES`,
/// optional `-FloofTab history|pets|more`). Lädt Beispieldaten,
/// speichert nichts und fragt nicht nach Mitteilungen.
enum DemoMode {
    static var isActive: Bool { UserDefaults.standard.bool(forKey: "FloofDemo") }

    static var startTab: AppTab? {
        guard isActive else { return nil }
        return UserDefaults.standard.string(forKey: "FloofTab").flatMap(AppTab.init(rawValue:))
    }
}
