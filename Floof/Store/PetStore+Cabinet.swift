import Foundation

/// Medikamentenschrank: Bestand, Reichweite, Ablauf, Buchungen.
extension PetStore {
    func cabinetItem(_ id: CabinetItem.ID?) -> CabinetItem? {
        guard let id else { return nil }
        return cabinet.first { $0.id == id }
    }

    /// Alle Medikamente (mit Tier), die aus diesem Artikel versorgt werden.
    func linkedMedications(of item: CabinetItem) -> [(pet: Pet, med: CareEntry)] {
        pets.flatMap { pet in
            pet.medications.filter { $0.cabinetItemID == item.id }.map { (pet: pet, med: $0) }
        }
    }

    func dailyConsumption(of item: CabinetItem) -> Double {
        linkedMedications(of: item).reduce(0) { $0 + $1.med.dailyConsumption }
    }

    /// Wie viele Tage der Vorrat bei planmäßiger Gabe noch reicht (nil = kein Plan).
    func daysLeft(of item: CabinetItem) -> Int? {
        let perDay = dailyConsumption(of: item)
        guard perDay > 0 else { return nil }
        return Int((item.stock / perDay).rounded(.down))
    }

    func status(of item: CabinetItem) -> CabinetStatus {
        if item.stock <= 0.0001 { return .empty }
        if let expiry = item.effectiveExpiry {
            let days = Calendar.current.dateComponents([.day], from: .now, to: expiry).day ?? 0
            if days < 0 { return .expired }
            if let left = daysLeft(of: item), left <= item.warnBelowDays { return .low(daysLeft: left) }
            if days <= 14 { return .expiringSoon(days: days) }
        }
        if let left = daysLeft(of: item), left <= item.warnBelowDays { return .low(daysLeft: left) }
        return .ok
    }

    var cabinetAlerts: [CabinetItem] {
        cabinet.filter { status(of: $0).needsAttention }
    }

    // MARK: Buchungen

    func consume(itemID: CabinetItem.ID, amount: Double, kind: StockEvent.Kind, note: String?, doseID: String?) {
        guard let before = cabinetItem(itemID) else { return }
        let wasLow = status(of: before).needsAttention
        update { data in
            guard let i = data.cabinet.firstIndex(where: { $0.id == itemID }) else { return }
            data.cabinet[i].stock = max(0, data.cabinet[i].stock - amount)
            if data.cabinet[i].openedDate == nil { data.cabinet[i].openedDate = .now }
            data.cabinet[i].history.insert(StockEvent(delta: -amount, kind: kind, note: note, doseID: doseID), at: 0)
        }
        if let after = cabinetItem(itemID), !wasLow, status(of: after).needsAttention {
            ReminderScheduler.notifyLowStock(after.name, daysLeft: daysLeft(of: after))
        }
    }

    /// Bucht eine rückgängig gemachte Gabe zurück ins Lager.
    func restock(forDose doseID: String) {
        update { data in
            for i in data.cabinet.indices {
                if let e = data.cabinet[i].history.firstIndex(where: { $0.doseID == doseID }) {
                    data.cabinet[i].stock -= data.cabinet[i].history[e].delta
                    data.cabinet[i].history.remove(at: e)
                }
            }
        }
    }

    func refill(_ item: CabinetItem, amount: Double? = nil, newExpiry: Date? = nil) {
        let added = amount ?? item.packageSize
        update { data in
            guard let i = data.cabinet.firstIndex(where: { $0.id == item.id }) else { return }
            data.cabinet[i].stock += added
            data.cabinet[i].openedDate = nil
            if let newExpiry { data.cabinet[i].expiryDate = newExpiry }
            data.cabinet[i].history.insert(StockEvent(delta: added, kind: .refill), at: 0)
        }
        log(.cabinet, "\(item.name) nachgefüllt (+\(item.formatted(added)))")
        showToast("\(item.name): +\(item.formatted(added))")
    }

    func correctStock(_ item: CabinetItem, to newStock: Double) {
        let delta = newStock - item.stock
        guard abs(delta) > 0.0001 else { return }
        update { data in
            guard let i = data.cabinet.firstIndex(where: { $0.id == item.id }) else { return }
            data.cabinet[i].stock = max(0, newStock)
            data.cabinet[i].history.insert(StockEvent(delta: delta, kind: .correction), at: 0)
        }
    }

    func upsertCabinetItem(_ item: CabinetItem) {
        update { data in
            if let i = data.cabinet.firstIndex(where: { $0.id == item.id }) { data.cabinet[i] = item }
            else { data.cabinet.append(item) }
        }
    }

    func deleteCabinetItem(_ item: CabinetItem) {
        update { data in
            data.cabinet.removeAll { $0.id == item.id }
            for p in data.pets.indices {
                for c in data.pets[p].care.indices where data.pets[p].care[c].cabinetItemID == item.id {
                    data.pets[p].care[c].cabinetItemID = nil
                }
            }
        }
    }
}
