import SwiftUI

@main
struct FloofApp: App {
    @State private var store = DemoMode.isActive ? PetStore.preview : PetStore.load()
    @Environment(\.scenePhase) private var scenePhase

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
            if phase == .active { LightSource.shared.start() } else { LightSource.shared.stop() }
        }
    }
}

/// Demo-Modus für automatische Screenshots (Startparameter `-FloofDemo YES`,
/// optional `-FloofTab diary|cabinet|pets|lexicon`). Lädt Beispieldaten,
/// speichert nichts und fragt nicht nach Mitteilungen.
enum DemoMode {
    static var isActive: Bool { UserDefaults.standard.bool(forKey: "FloofDemo") }

    static var startTab: AppTab? {
        guard isActive else { return nil }
        return UserDefaults.standard.string(forKey: "FloofTab").flatMap(AppTab.init(rawValue:))
    }
}
