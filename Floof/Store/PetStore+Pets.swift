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

    func setDailyCheck(_ need: DailyCheck.Need, for petID: Pet.ID) {
        let today = DoseKey.day(.now)
        update { data in
            guard let p = data.pets.firstIndex(where: { $0.id == petID }) else { return }
            data.pets[p].dailyChecks.removeAll { $0.id == today }
            data.pets[p].dailyChecks.append(DailyCheck(id: today, need: need))
        }
    }
}
