import Foundation

/// Ein Artikel im Medikamentenschrank (eine Flasche, eine Packung …).
struct CabinetItem: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var name: String
    var form: Form = .liquid
    /// Aktueller Bestand in `form.unit`.
    var stock: Double
    /// Inhalt einer vollen Packung – für "Nachfüllen" und die Füllstandsanzeige.
    var packageSize: Double
    /// Warnen, wenn der Vorrat nur noch so viele Tage reicht.
    var warnBelowDays = 7
    var expiryDate: Date?
    var openedDate: Date?
    /// Haltbarkeit nach Anbruch (z. B. Säfte: 28 Tage).
    var usableAfterOpeningDays: Int?
    var notes = ""
    var history: [StockEvent] = []

    enum Form: String, Codable, CaseIterable, Identifiable {
        case liquid, tablet, drops, powder, other
        var id: Self { self }

        var label: String {
            switch self {
            case .liquid: "Flüssigkeit"
            case .tablet: "Tabletten"
            case .drops: "Tropfen"
            case .powder: "Pulver"
            case .other: "Sonstiges"
            }
        }
        var unit: String {
            switch self {
            case .liquid: "ml"
            case .tablet: "Stk."
            case .drops: "Tr."
            case .powder: "g"
            case .other: "Einh."
            }
        }
        var symbol: String {
            switch self {
            case .liquid: "drop.fill"
            case .tablet: "pills.fill"
            case .drops: "eyedropper.halffull"
            case .powder: "takeoutbag.and.cup.and.straw.fill"
            case .other: "shippingbox.fill"
            }
        }
        /// Schrittweite für Korrekturen.
        var step: Double { self == .liquid || self == .powder ? 0.5 : 1 }
    }

    var fillLevel: Double {
        guard packageSize > 0 else { return 0 }
        return min(max(stock / packageSize, 0), 1)
    }

    /// Frühestes Datum aus Ablaufdatum und "nach Anbruch verwenden bis".
    var effectiveExpiry: Date? {
        let afterOpening = openedDate.flatMap { opened in
            usableAfterOpeningDays.flatMap { Calendar.current.date(byAdding: .day, value: $0, to: opened) }
        }
        return [expiryDate, afterOpening].compactMap { $0 }.min()
    }

    func formatted(_ amount: Double) -> String {
        "\(amount.formatted(.number.precision(.fractionLength(0...2)))) \(form.unit)"
    }
}

struct StockEvent: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var date = Date.now
    var delta: Double
    var kind: Kind
    var note: String?
    /// Verknüpfte Dosis – damit "Rückgängig" den Bestand exakt zurückbucht.
    var doseID: String?

    enum Kind: String, Codable {
        case dose, asNeeded, refill, correction

        var label: String {
            switch self {
            case .dose: "Gabe"
            case .asNeeded: "Bei Bedarf"
            case .refill: "Nachgefüllt"
            case .correction: "Korrektur"
            }
        }
    }
}

/// Ampel für einen Schrank-Artikel.
enum CabinetStatus: Comparable {
    case empty, expired, low(daysLeft: Int), expiringSoon(days: Int), ok

    var needsAttention: Bool {
        if case .ok = self { return false }
        return true
    }
}
