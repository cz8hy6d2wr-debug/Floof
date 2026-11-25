import SwiftUI

@main
struct MuemmelwieseApp: App {
    var body: some Scene {
        WindowGroup {
            GardenView()
                .tint(MTheme.carrot)
        }
    }
}
