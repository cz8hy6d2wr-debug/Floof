import Foundation

/// Medikamentengaben: Tagesplan, Abhaken, Möhren & Serie, Lagerabbuchung.
extension PetStore {
    func doses(for pet: Pet, on day: Date = .now) -> [ScheduledDose] {
        let weekday = Calendar.current.component(.weekday, from: day)
        return pet.medications
            .compactMap { med -> [ScheduledDose]? in
                guard let reminder = med.reminder, reminder.weekdays.contains(weekday) else { return nil }
                return reminder.allTimes.map { ScheduledDose(pet: pet, medication: med, time: $0, day: day) }
            }
            .flatMap { $0 }
            .sorted { $0.time < $1.time }
    }

    func todaysDoses(on day: Date = .now) -> [ScheduledDose] {
        pets.flatMap { doses(for: $0, on: day) }
            .sorted { ($0.time, $0.pet.name) < ($1.time, $1.pet.name) }
    }

    var nextOpenDose: ScheduledDose? { todaysDoses().first { !isTaken($0) } }

    func isTaken(_ dose: ScheduledDose) -> Bool { data.takenDoses.contains(dose.id) }

    func progress(_ doses: [ScheduledDose]) -> Double {
        guard !doses.isEmpty else { return 1 }
        return Double(doses.filter(isTaken).count) / Double(doses.count)
    }

    func toggle(_ dose: ScheduledDose) {
        if isTaken(dose) {
            update { data in
                data.takenDoses.remove(dose.id)
                let points = data.game.awarded.removeValue(forKey: dose.id) ?? 0
                data.game.carrots -= points
                if points == 10 { data.game.onTimeCount -= 1 }
                if data.game.perfectDays.remove(DoseKey.day(dose.day)) != nil { data.game.carrots -= 20 }
            }
            restock(forDose: dose.id)
        } else {
            update { $0.takenDoses.insert(dose.id) }
            award(dose)
            if let itemID = dose.medication.cabinetItemID, let amount = dose.medication.effectiveDoseAmount {
                consume(itemID: itemID, amount: amount, kind: .dose, note: "\(dose.medication.title) · \(dose.pet.name)", doseID: dose.id)
            }
        }
    }

    /// Bedarfsmedikament gegeben: Lager abbuchen + automatischer Tagebucheintrag.
    func logAsNeeded(_ med: CareEntry, for pet: Pet) {
        if let itemID = med.cabinetItemID, let amount = med.effectiveDoseAmount {
            consume(itemID: itemID, amount: amount, kind: .asNeeded, note: "\(med.title) · \(pet.name)", doseID: nil)
        }
        upsertDiary(DiaryEntry(petIDs: [pet.id], mood: .okay, title: "\(med.title) gegeben",
                               text: med.details, tags: [.health], isAutomatic: true))
        showToast("\(med.title) für \(pet.name) eingetragen")
    }

    /// Pünktlich (±1 h) = 10 Möhren, später = 5. Kein Abzug fürs Vergessen.
    private func award(_ dose: ScheduledDose) {
        let cal = Calendar.current
        let due = cal.date(bySettingHour: dose.time.hour, minute: dose.time.minute, second: 0, of: dose.day) ?? dose.day
        let onTime = abs(Date.now.timeIntervalSince(due)) <= GameState.onTimeWindow
        let points = onTime ? 10 : 5
        let dayDoses = todaysDoses(on: dose.day)
        let perfect = !dayDoses.isEmpty && dayDoses.allSatisfy(isTaken)

        var reason: Celebration.Reason?
        update { data in
            data.game.carrots += points
            data.game.awarded[dose.id] = points
            if onTime { data.game.onTimeCount += 1 }
            if perfect {
                data.game.perfectDays.insert(DoseKey.day(dose.day))
                data.game.carrots += 20
                reason = .perfectDay(streak: data.game.streak(today: dose.day))
            }
            let fresh = Badge.all.filter { !data.game.unlocked.contains($0.id) && $0.isEarned(by: data.game) }
            data.game.unlocked.formUnion(fresh.map(\.id))
            if let badge = fresh.last { reason = .badge(badge) }   // Abzeichen schlägt Tagesfeier
        }
        if let reason { celebration = Celebration(reason: reason) }
    }

    var streak: Int { game.streak() }
    var unlockedBadges: Set<Badge.ID> { game.unlocked }
}
