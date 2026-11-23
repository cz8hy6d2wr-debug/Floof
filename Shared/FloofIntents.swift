import AppIntents
import Foundation

/// Knöpfe in Widgets und Live-Aktivität.
///
/// Sie sind `LiveActivityIntent`s: iOS führt sie im Prozess der **App** aus
/// (notfalls kurz im Hintergrund gestartet), nicht im Widget. So laufen sie über
/// dieselbe Logik wie in der App – Möhren, Schrank, Verlauf und die gemeinsame Datei.

struct ToggleDoseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Gabe abhaken"
    static let isDiscoverable = false

    @Parameter(title: "Gabe") var doseID: String

    init() {}
    init(doseID: String) { self.doseID = doseID }

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await FloofActions.toggleDoses([doseID])
        #endif
        return .result()
    }
}

/// Alle Gaben einer Uhrzeit auf einmal ("Gegeben" in der Live-Aktivität).
struct GiveDosesIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Gaben als gegeben markieren"
    static let isDiscoverable = false

    @Parameter(title: "Gaben") var doseIDs: [String]

    init() {}
    init(doseIDs: [String]) { self.doseIDs = doseIDs }

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await FloofActions.give(doseIDs)
        #endif
        return .result()
    }
}

struct AllNormalIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Kurz-Check: alles normal"
    static let isDiscoverable = false

    @Parameter(title: "Tier") var petID: String

    init() {}
    init(petID: String) { self.petID = petID }

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await FloofActions.allNormal(petIDs: petID.isEmpty ? nil : [petID])
        #endif
        return .result()
    }
}
