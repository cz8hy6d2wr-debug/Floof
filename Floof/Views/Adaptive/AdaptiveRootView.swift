import SwiftUI

/// Hauptansicht: wechselt automatisch zwischen Außen- und Innendisplay.
struct AdaptiveRootView: View {
    @Environment(PetStore.self) private var store
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        GeometryReader { proxy in
            // proxy.size ist die Fläche *innerhalb* der Safe Area – also schon
            // ohne Statusleiste (auch wenn sie im Querformat seitlich liegt).
            let posture = DevicePosture.resolve(size: proxy.size, horizontalSizeClass: horizontalSizeClass)

            ZStack {
                switch posture {
                case .folded:
                    CompactDashboardView()
                        .transition(.asymmetric(insertion: .opacity.combined(with: .scale(0.96)), removal: .opacity))
                case .unfolded:
                    ExpandedDashboardView()
                        .transition(.asymmetric(insertion: .opacity.combined(with: .scale(1.03)), removal: .opacity))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .environment(\.devicePosture, posture)
            .animation(.smooth(duration: 0.35), value: posture)
        }
        // Hintergrund randlos bis in alle Ecken – Inhalte bleiben in der Safe Area.
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

#Preview("Zugeklappt") {
    AdaptiveRootView()
        .environment(PetStore.preview)
}

#Preview("Aufgeklappt (4:3)", traits: .fixedLayout(width: 744, height: 992)) {
    AdaptiveRootView()
        .environment(PetStore.preview)
}
