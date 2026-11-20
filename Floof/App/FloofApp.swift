import SwiftUI

@main
struct FloofApp: App {
    @State private var store = PetStore.preview   // bis zum ersten Import

    var body: some Scene {
        WindowGroup {
            AdaptiveRootView()
                .environment(store)
                // Persistente Systemleisten nicht ausblenden: die (im Querformat
                // seitliche) Statusleiste bleibt sichtbar, Inhalte respektieren ihre Safe Area.
                .persistentSystemOverlays(.automatic)
        }
    }
}
