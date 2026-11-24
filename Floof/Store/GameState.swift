import Foundation

/// Gamification: Möhren (Punkte), Tages-Serie und Abzeichen.
/// Bewusst sanft: keine Strafen, Rückgängig gibt Punkte zurück,
/// der Fokus bleibt auf dem Tier, nicht auf dem Highscore.
struct GameState: Codable {
    var carrots = 0
    /// Möhren je abgehakter Dosis – damit Rückgängig exakt abzieht.
    var awarded: [String: Int] = [:]
    /// Tage ("yyyy-MM-dd"), an denen alle geplanten Gaben erledigt waren.
    var perfectDays: Set<String> = []
    var onTimeCount = 0
    var unlocked: Set<Badge.ID> = []

    static let onTimeWindow: TimeInterval = 60 * 60   // ±1 h gilt als pünktlich

    /// Aufeinanderfolgende perfekte Tage bis heute (oder bis gestern, solange heute noch läuft).
    func streak(today: Date = .now) -> Int {
        let cal = Calendar.current
        var day = today
        if !perfectDays.contains(DoseKey.day(day)) {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while perfectDays.contains(DoseKey.day(day)) {
            count += 1
            guard let previous = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }
}

struct Badge: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let symbol: String

    static let all: [Badge] = [
        Badge(id: "first", title: "Erste Gabe", detail: "Die erste Dosis abgehakt", symbol: "drop.fill"),
        Badge(id: "perfect", title: "Rundum versorgt", detail: "Alle Gaben eines Tages erledigt", symbol: "checkmark.seal.fill"),
        Badge(id: "streak7", title: "Eine Woche lang", detail: "7 Tage am Stück alles gegeben", symbol: "calendar"),
        Badge(id: "punctual", title: "Pünktlich wie die Uhr", detail: "10 Gaben innerhalb einer Stunde", symbol: "clock.fill"),
        Badge(id: "streak30", title: "Monats-Held:in", detail: "30 Tage am Stück", symbol: "crown.fill"),
        Badge(id: "carrots500", title: "Möhrenvorrat", detail: "500 Möhren gesammelt", symbol: "carrot.fill"),
    ]

    func isEarned(by game: GameState) -> Bool {
        switch id {
        case "first": !game.awarded.isEmpty || game.carrots > 0
        case "perfect": !game.perfectDays.isEmpty
        case "streak7": game.streak() >= 7
        case "punctual": game.onTimeCount >= 10
        case "streak30": game.streak() >= 30
        case "carrots500": game.carrots >= 500
        default: false
        }
    }
}
