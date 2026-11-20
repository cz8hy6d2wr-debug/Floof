import Foundation
import Observation
import UIKit

@Observable
final class PetStore {
    var pets: [Pet]
    var photos: [String: UIImage] = [:]
    var selectedPetID: Pet.ID?
    /// Abgehakte Dosen, Schlüssel = `ScheduledDose.id` (enthält das Datum).
    private(set) var takenDoses: Set<String>

    private static let takenKey = "floof.takenDoses"

    init(pets: [Pet] = [], photos: [String: UIImage] = [:]) {
        self.pets = pets
        self.photos = photos
        self.selectedPetID = pets.first?.id
        let stored = UserDefaults.standard.stringArray(forKey: Self.takenKey) ?? []
        self.takenDoses = Set(stored)
    }

    var selectedPet: Pet? {
        pets.first { $0.id == selectedPetID } ?? pets.first
    }

    // MARK: Medikamente heute

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

    func isTaken(_ dose: ScheduledDose) -> Bool { takenDoses.contains(dose.id) }

    func toggle(_ dose: ScheduledDose) {
        if takenDoses.contains(dose.id) { takenDoses.remove(dose.id) } else { takenDoses.insert(dose.id) }
        UserDefaults.standard.set(Array(takenDoses), forKey: Self.takenKey)
    }

    func progress(_ doses: [ScheduledDose]) -> Double {
        guard !doses.isEmpty else { return 1 }
        return Double(doses.filter(isTaken).count) / Double(doses.count)
    }

    // MARK: Import

    func importExport(from url: URL) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let export = try JSONDecoder().decode(FloofExport.self, from: Data(contentsOf: url))
        pets = export.data.rabbits
        photos = export.photos.compactMapValues { base64 in
            Data(base64Encoded: base64, options: .ignoreUnknownCharacters).flatMap(UIImage.init(data:))
        }
        selectedPetID = pets.first?.id
    }
}

// MARK: - Vorschaudaten (aus dem Floof-Export, ohne Fotos)

extension PetStore {
    static var preview: PetStore {
        let ref = Date(timeIntervalSinceReferenceDate: 0)
        func d(_ s: TimeInterval) -> Date { ref.addingTimeInterval(s) }
        let everyDay = Array(1...7)

        let cinnamon = Pet(
            id: "8C34D6C8-71EB-4CB4-8C4B-8E879C7A429C", name: "Cinnamon", animalType: "Kaninchen",
            breed: "Löwenköpfchen", birthday: d(649_272_000), petGroup: "smallAnimal", color: 3,
            photoFilename: nil, care: [],
            weights: [WeightEntry(id: "w1", date: d(814_296_960), grams: 1820, note: "")],
            dailyChecks: [DailyCheck(id: "2026-10-23", need: .green)], checkIns: [],
            extraInfo: [
                "smallAnimal.teeth": "13.10.2026 Allgemeinuntersuchung; kleine Treppe aber unbedenklich",
                "smallAnimal.claws": "11.10.2026 geschnitten",
                "smallAnimal.feeding": "Frische Kräuter, Strukturfutter, Heu",
                "smallAnimal.companions": "Brownie",
            ],
            hour: 10, weekday: 1, weighReminder: true)

        let brownie = Pet(
            id: "01D42681-3D56-4613-8232-1223FEFCD7FA", name: "Brownie", animalType: "Kaninchen",
            breed: "Zwergkaninchen", birthday: d(661_717_620), petGroup: "smallAnimal", color: 10,
            photoFilename: nil,
            care: [
                CareEntry(id: "ec", date: d(814_383_746), title: "EC", details: "Encephalitozoon cuniculi", kind: "Krankheit"),
                CareEntry(id: "panacur", date: d(814_383_788), title: "Panacur",
                          details: "0,35ml im Alltag\n0,80ml nach Bedarf", kind: "Medikation",
                          reminder: CareReminder(hour: 15, minute: 0, times: [.init(hour: 15, minute: 0)], weekdays: everyDay)),
                CareEntry(id: "vitb", date: d(814_383_854), title: "Vitamin B", details: "bei Bedarf", kind: "Medikation"),
                CareEntry(id: "gaba", date: d(814_383_894), title: "Gabapentin", details: "0,15ml", kind: "Medikation",
                          reminder: CareReminder(hour: 7, minute: 0,
                                                 times: [.init(hour: 7, minute: 0), .init(hour: 15, minute: 0)],
                                                 weekdays: everyDay)),
                CareEntry(id: "epi", date: d(814_383_931), title: "Epilepsie / Krämpfe", details: "", kind: "Krankheit"),
            ],
            weights: [WeightEntry(id: "w2", date: d(814_296_960), grams: 1690, note: "")],
            dailyChecks: [DailyCheck(id: "2026-10-23", need: .yellow)], checkIns: [],
            extraInfo: [
                "smallAnimal.teeth": "13.10.2026, alles in Ordnung",
                "smallAnimal.claws": "11.10.2026 geschnitten",
                "smallAnimal.feeding": "Frische Kräuter, Strukturfutter, Heu",
                "smallAnimal.companions": "Cinnamon",
            ],
            hour: 10, weekday: 1, weighReminder: true)

        return PetStore(pets: [cinnamon, brownie])
    }
}
