import SwiftUI

@main
struct FloofApp: App {
    @State private var store: PetStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let store = PetStore.shared
        _store = State(initialValue: store)
        if !DemoMode.isActive { SyncManager.shared.attach(store) }
        Self.styleNavigationTitles()
    }

    /// Seitentitel in der Serifenschrift der App (New York) statt im System-Standard.
    private static func styleNavigationTitles() {
        func serif(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
            let base = UIFont.systemFont(ofSize: size, weight: weight)
            guard let descriptor = base.fontDescriptor.withDesign(.serif) else { return base }
            return UIFont(descriptor: descriptor, size: size)
        }
        let bar = UINavigationBar.appearance()
        bar.largeTitleTextAttributes = [.font: serif(34, .semibold)]
        bar.titleTextAttributes = [.font: serif(17, .semibold)]
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

    /// Gewählter Tag im Kalender für Screenshots (`-FloofDay 2` = übermorgen).
    static var selectedDay: Date {
        let today = Calendar.current.startOfDay(for: .now)
        guard isActive else { return today }
        let offset = UserDefaults.standard.integer(forKey: "FloofDay")
        return Calendar.current.date(byAdding: .day, value: offset, to: today) ?? today
    }

    /// `-FloofTab garden` öffnet den Floof-Garten (Kaninchen-Spiel).
    static var opensGarden: Bool {
        isActive && UserDefaults.standard.string(forKey: "FloofTab") == "garden"
    }

    static var startTab: AppTab? {
        guard isActive else { return nil }
        return UserDefaults.standard.string(forKey: "FloofTab").flatMap(AppTab.init(rawValue:))
    }
}
