import SwiftUI

/// Zustand des faltbaren Geräts, abgeleitet aus der *tatsächlich verfügbaren*
/// Fläche – nicht aus dem Gerätemodell.
///
/// Warum Geometrie statt Geräte-API?
/// - Außendisplay 5,4" ≈ 19,5:9  → Seitenverhältnis kurz/lang ≈ 0,46
/// - Innendisplay 7,6" = 4:3     → Seitenverhältnis kurz/lang = 0,75
/// - iPhones melden im Hochformat auch auf großen Displays oft
///   `horizontalSizeClass == .compact`; die Size Class allein reicht daher nicht.
/// - Funktioniert identisch in Stage Manager, Split View und im Simulator.
///
/// Falls das SDK eine dedizierte Faltzustand-API anbietet, wird sie nur in
/// `DevicePosture.resolve` eingehängt – keine View muss sich ändern.
enum DevicePosture: Equatable {
    case folded     // Außendisplay, Einhandbedienung
    case unfolded   // Innendisplay, zweispaltig

    static func resolve(size: CGSize, horizontalSizeClass: UserInterfaceSizeClass?) -> DevicePosture {
        guard size.width > 0, size.height > 0 else { return .folded }
        if horizontalSizeClass == .regular { return .unfolded }

        let short = min(size.width, size.height)
        let long = max(size.width, size.height)
        let ratio = short / long

        // Breiter als 4:3-Grenzbereich UND genug Platz für zwei Spalten.
        return (ratio >= 0.62 && short >= 500) ? .unfolded : .folded
    }
}

extension EnvironmentValues {
    @Entry var devicePosture: DevicePosture = .folded
}
