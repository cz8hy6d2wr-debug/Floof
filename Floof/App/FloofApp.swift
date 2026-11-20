import SwiftUI

@main
struct FloofApp: App {
    @State private var store = PetStore.load()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(store)
                .tint(Theme.carrot)
                .task { await ReminderScheduler.requestAuthorization() }
        }
    }
}
