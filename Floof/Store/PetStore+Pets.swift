import Foundation

/// Tiere: Stammdaten, Gewicht, Pflege-/Medikamenteneinträge.
extension PetStore {
    func upsertPet(_ pet: Pet) {
        update { data in
            if let i = data.pets.firstIndex(where: { $0.id == pet.id }) { data.pets[i] = pet }
            else { data.pets.append(pet) }
        }
        if selectedPetID == nil { selectedPetID = pet.id }
    }

    func deletePet(_ pet: Pet) {
        update { data in
            data.pets.removeAll { $0.id == pet.id }
            for i in data.diary.indices { data.diary[i].petIDs.removeAll { $0 == pet.id } }
            data.diary.removeAll { $0.petIDs.isEmpty }
        }
        if selectedPetID == pet.id { selectedPetID = pets.first?.id }
    }

    func addWeight(_ grams: Int, on date: Date = .now, note: String = "", to petID: Pet.ID) {
        update { data in
            guard let i = data.pets.firstIndex(where: { $0.id == petID }) else { return }
            data.pets[i].weights.append(WeightEntry(id: UUID().uuidString, date: date, grams: grams, note: note))
        }
    }

    func deleteWeight(_ entry: WeightEntry, from petID: Pet.ID) {
        update { data in
            guard let i = data.pets.firstIndex(where: { $0.id == petID }) else { return }
            data.pets[i].weights.removeAll { $0.id == entry.id }
        }
    }

    func upsertCare(_ entry: CareEntry, for petID: Pet.ID) {
        update { data in
            guard let p = data.pets.firstIndex(where: { $0.id == petID }) else { return }
            if let c = data.pets[p].care.firstIndex(where: { $0.id == entry.id }) { data.pets[p].care[c] = entry }
            else { data.pets[p].care.append(entry) }
        }
    }

    func deleteCare(_ entry: CareEntry, from petID: Pet.ID) {
        update { data in
            guard let p = data.pets.firstIndex(where: { $0.id == petID }) else { return }
            data.pets[p].care.removeAll { $0.id == entry.id }
        }
    }

    // MARK: Kurz-Check

    /// Setzt eine Beobachtung (Fressen/Köttel/Verhalten) für einen Tag.
    func setCheck(_ aspect: DailyCheck.Aspect, _ level: DailyCheck.Level, for petID: Pet.ID, on day: Date = .now) {
        let key = DoseKey.day(day)
        update { data in
            guard let p = data.pets.firstIndex(where: { $0.id == petID }) else { return }
            var check = data.pets[p].dailyChecks.first { $0.id == key } ?? DailyCheck(id: key, need: .green)
            check.set(aspect, level)
            data.pets[p].dailyChecks.removeAll { $0.id == key }
            data.pets[p].dailyChecks.append(check)
        }
    }

    /// Alles normal – ein Tipp für alle drei Punkte.
    func setCheckAllNormal(for petID: Pet.ID, on day: Date = .now) {
        for aspect in DailyCheck.Aspect.allCases { setCheck(aspect, .normal, for: petID, on: day) }
    }

    func setCheckNote(_ note: String, for petID: Pet.ID, on day: Date = .now) {
        let key = DoseKey.day(day)
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        update { data in
            guard let p = data.pets.firstIndex(where: { $0.id == petID }),
                  let c = data.pets[p].dailyChecks.firstIndex(where: { $0.id == key }) else { return }
            data.pets[p].dailyChecks[c].note = trimmed.isEmpty ? nil : trimmed
        }
    }

    // MARK: Pflege-Routinen

    /// Routine erledigt: Datum merken und im Tagebuch festhalten.
    func markRoutineDone(_ kind: CareRoutine.Kind, for petID: Pet.ID, on date: Date = .now) {
        guard let pet = pet(petID) else { return }
        update { data in
            guard let p = data.pets.firstIndex(where: { $0.id == petID }) else { return }
            var routines = data.pets[p].careRoutines
            if let r = routines.firstIndex(where: { $0.kind == kind }) { routines[r].lastDone = date }
            data.pets[p].routines = routines
        }
        upsertDiary(DiaryEntry(date: date, petIDs: [petID], mood: .good, title: kind.doneTitle,
                               tags: [.grooming], isAutomatic: true))
        showToast("\(kind.doneTitle) – \(pet.name)")
    }

    func setRoutineInterval(_ kind: CareRoutine.Kind, days: Int, for petID: Pet.ID) {
        update { data in
            guard let p = data.pets.firstIndex(where: { $0.id == petID }) else { return }
            var routines = data.pets[p].careRoutines
            if let r = routines.firstIndex(where: { $0.kind == kind }) { routines[r].intervalDays = max(1, days) }
            data.pets[p].routines = routines
        }
    }
}

/// Lexikon: Merkliste.
extension PetStore {
    func isBookmarked(_ articleID: String) -> Bool { data.lexiconBookmarks.contains(articleID) }

    func toggleBookmark(_ articleID: String) {
        update { data in
            if data.lexiconBookmarks.contains(articleID) { data.lexiconBookmarks.remove(articleID) }
            else { data.lexiconBookmarks.insert(articleID) }
        }
    }
}
