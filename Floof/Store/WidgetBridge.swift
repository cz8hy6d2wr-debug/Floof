import ActivityKit
import Foundation
import WidgetKit

/// Verbindet die App mit Widgets und Live-Aktivität:
/// schreibt den Widget-Stand, lädt die Widgets neu und pflegt die Live-Aktivität.
@MainActor
enum WidgetBridge {
    private static var lastSnapshot: WidgetSnapshot?

    /// Nach jeder Änderung aufrufen. Lädt Widgets nur neu, wenn sich wirklich etwas geändert hat.
    static func refresh(from store: PetStore) {
        guard !DemoMode.isActive else { return }
        let snapshot = makeSnapshot(store)
        guard snapshot != lastSnapshot else { return }
        lastSnapshot = snapshot
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
        updateLiveActivity(snapshot)
    }

    static func makeSnapshot(_ store: PetStore) -> WidgetSnapshot {
        let doses = store.todaysDoses().map { dose in
            let item = store.cabinetItem(dose.medication.cabinetItemID)
            let amount: String
            if let item, let value = dose.medication.effectiveDoseAmount {
                amount = item.formatted(value)
            } else {
                amount = dose.medication.details.split(separator: "\n").first.map(String.init) ?? ""
            }
            return WidgetSnapshot.Dose(id: dose.id, title: dose.medication.title, petName: dose.pet.name,
                                       amount: amount, time: dose.time.label, due: dose.dueDate,
                                       taken: store.isTaken(dose), symbol: item?.form.symbol ?? "drop.fill")
        }
        let checks = store.pets.map { pet in
            let check = pet.check(on: .now)
            return WidgetSnapshot.Check(id: pet.id, petName: pet.name,
                                        done: check?.isComplete == true,
                                        allNormal: check?.isComplete == true && check?.need == .green)
        }
        let weightPet = store.pets
            .compactMap { pet in pet.latestWeight.map { (pet, $0) } }
            .max { $0.1.date < $1.1.date }
        let alert = store.cabinetAlerts.first.map {
            WidgetSnapshot.CabinetAlert(name: $0.name, text: CabinetStatusText.short(store.status(of: $0)))
        }
        let last = store.data.activity.first.map { entry in
            let who = store.displayAuthor(entry)
            return "\(who) · \(entry.date.formatted(date: .omitted, time: .shortened)) · \(entry.text)"
        }
        return WidgetSnapshot(day: .now, doses: doses, checks: checks,
                              weight: weightPet.map { .init(petName: $0.0.name, grams: $0.1.grams, date: $0.1.date) },
                              cabinetAlert: alert, lastActivity: last, carrots: store.game.carrots,
                              weather: WeatherStore.shared.summary,
                              weatherSymbol: WeatherStore.shared.condition.map(WeatherStore.symbol))
    }

    // MARK: Live-Aktivität

    /// Zeigt die nächste Gabe auf dem Sperrbildschirm, sobald sie in den nächsten
    /// drei Stunden ansteht. Ist sie gegeben, verschwindet die Aktivität.
    static func updateLiveActivity(_ snapshot: WidgetSnapshot) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let group = snapshot.nextGroup()
        let current = Activity<DoseActivityAttributes>.activities

        guard let first = group.first, first.due.timeIntervalSinceNow < 3 * 3600 else {
            for activity in current { Task { await activity.end(nil, dismissalPolicy: .immediate) } }
            return
        }

        let pets = Array(Set(group.map(\.petName))).sorted().joined(separator: " & ")
        let state = DoseActivityAttributes.ContentState(
            title: group.map(\.title).joined(separator: " + "),
            detail: group.count == 1 ? "\(first.amount) · \(pets)" : pets,
            due: first.due,
            doseIDs: group.map(\.id),
            symbol: first.symbol)
        // Eine Stunde nach Fälligkeit gilt sie als veraltet.
        let content = ActivityContent(state: state, staleDate: first.due.addingTimeInterval(3600))

        if let activity = current.first {
            if activity.content.state != state { Task { await activity.update(content) } }
            for extra in current.dropFirst() { Task { await extra.end(nil, dismissalPolicy: .immediate) } }
        } else {
            _ = try? Activity.request(attributes: DoseActivityAttributes(), content: content)
        }
    }
}

/// Was die Knöpfe in Widgets und Live-Aktivität auslösen. Läuft im App-Prozess.
@MainActor
enum FloofActions {
    static func toggleDoses(_ ids: [String]) async {
        let store = PetStore.shared
        for dose in store.todaysDoses() where ids.contains(dose.id) { store.toggle(dose) }
        await finish(store)
    }

    /// Nur offene Gaben abhaken (nie versehentlich zurücknehmen).
    static func give(_ ids: [String]) async {
        let store = PetStore.shared
        for dose in store.todaysDoses() where ids.contains(dose.id) && !store.isTaken(dose) { store.toggle(dose) }
        await finish(store)
    }

    static func allNormal(petIDs: [String]?) async {
        let store = PetStore.shared
        for pet in store.pets where petIDs?.contains(pet.id) ?? true {
            if pet.check(on: .now)?.isComplete != true { store.setCheckAllNormal(for: pet.id) }
        }
        await finish(store)
    }

    /// Sofort speichern und abgleichen – die App läuft hier evtl. nur kurz im Hintergrund.
    private static func finish(_ store: PetStore) async {
        await store.saveNow()
        WidgetBridge.refresh(from: store)
        _ = await SyncManager.shared.syncNow()
    }
}
