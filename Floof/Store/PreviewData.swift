import Foundation

/// Vorschaudaten (angelehnt an den Floof-Export, ohne Fotos) – nur für Xcode-Previews.
extension PetStore {
    static var preview: PetStore {
        let ref = Date(timeIntervalSinceReferenceDate: 0)
        func d(_ s: TimeInterval) -> Date { ref.addingTimeInterval(s) }
        func daysAgo(_ n: Int) -> Date { Calendar.current.date(byAdding: .day, value: -n, to: .now) ?? .now }
        let everyDay = Array(1...7)

        let panacurBottle = CabinetItem(id: "cab-panacur", name: "Panacur Suspension", form: .liquid,
                                        stock: 6.4, packageSize: 10, warnBelowDays: 10,
                                        expiryDate: Calendar.current.date(byAdding: .month, value: 8, to: .now),
                                        openedDate: daysAgo(12), usableAfterOpeningDays: 90)
        let gabaBottle = CabinetItem(id: "cab-gaba", name: "Gabapentin Saft", form: .liquid,
                                     stock: 2.1, packageSize: 15, warnBelowDays: 7,
                                     expiryDate: Calendar.current.date(byAdding: .month, value: 4, to: .now),
                                     openedDate: daysAgo(40), usableAfterOpeningDays: 56)
        let vitB = CabinetItem(id: "cab-vitb", name: "Vitamin B Komplex", form: .drops,
                               stock: 48, packageSize: 60, warnBelowDays: 7)

        let cinnamon = Pet(
            id: "8C34D6C8-71EB-4CB4-8C4B-8E879C7A429C", name: "Cinnamon", animalType: "Kaninchen",
            breed: "Löwenköpfchen", birthday: d(649_272_000), petGroup: "smallAnimal", color: 3,
            photoFilename: nil, care: [],
            weights: [
                WeightEntry(id: "c1", date: daysAgo(21), grams: 1790, note: ""),
                WeightEntry(id: "c2", date: daysAgo(14), grams: 1805, note: ""),
                WeightEntry(id: "c3", date: daysAgo(7), grams: 1820, note: ""),
            ],
            dailyChecks: [DailyCheck(id: DoseKey.day(.now), need: .green)], checkIns: [],
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
                          reminder: CareReminder(hour: 15, minute: 0, times: [.init(hour: 15, minute: 0)], weekdays: everyDay),
                          doseAmount: 0.35, cabinetItemID: panacurBottle.id),
                CareEntry(id: "vitb", date: d(814_383_854), title: "Vitamin B", details: "bei Bedarf, 5 Tropfen", kind: "Medikation",
                          doseAmount: 5, cabinetItemID: vitB.id),
                CareEntry(id: "gaba", date: d(814_383_894), title: "Gabapentin", details: "0,15ml", kind: "Medikation",
                          reminder: CareReminder(hour: 7, minute: 0,
                                                 times: [.init(hour: 7, minute: 0), .init(hour: 15, minute: 0)],
                                                 weekdays: everyDay),
                          doseAmount: 0.15, cabinetItemID: gabaBottle.id),
                CareEntry(id: "epi", date: d(814_383_931), title: "Epilepsie / Krämpfe", details: "", kind: "Krankheit"),
                CareEntry(id: "rhd", date: daysAgo(200), title: "RHD-1/RHD-2", details: "Filavac", kind: "Impfung"),
            ],
            weights: [
                WeightEntry(id: "b1", date: daysAgo(21), grams: 1710, note: ""),
                WeightEntry(id: "b2", date: daysAgo(14), grams: 1695, note: ""),
                WeightEntry(id: "b3", date: daysAgo(7), grams: 1690, note: ""),
            ],
            dailyChecks: [DailyCheck(id: DoseKey.day(.now), need: .yellow)], checkIns: [],
            extraInfo: [
                "smallAnimal.teeth": "13.10.2026, alles in Ordnung",
                "smallAnimal.claws": "11.10.2026 geschnitten",
                "smallAnimal.feeding": "Frische Kräuter, Strukturfutter, Heu",
                "smallAnimal.companions": "Cinnamon",
            ],
            hour: 10, weekday: 1, weighReminder: true)

        let diary = [
            DiaryEntry(date: daysAgo(0), petIDs: [brownie.id], mood: .okay, title: "Etwas wackelig heute",
                       text: "Morgens kurz schief gesessen, nach dem Gabapentin wieder ruhig. Hat gut gefressen.",
                       tags: [.health, .behavior]),
            DiaryEntry(date: daysAgo(1), petIDs: [cinnamon.id, brownie.id], mood: .great, title: "Erster Löwenzahn der Saison",
                       text: "Beide völlig verrückt danach. Cinnamon hat Brownie sogar ein Blatt überlassen!",
                       tags: [.food, .milestone]),
            DiaryEntry(date: daysAgo(3), petIDs: [cinnamon.id], mood: .good, title: "Revier verteidigt",
                       text: "Hat Brownie zweimal vom Heuhaufen gescheucht. Danach aber zusammen gekuschelt.",
                       tags: [.behavior]),
        ]

        var data = AppData()
        data.pets = [cinnamon, brownie]
        data.cabinet = [panacurBottle, gabaBottle, vitB]
        data.diary = diary
        data.game.carrots = 340
        data.game.perfectDays = Set((1...5).map { DoseKey.day(daysAgo($0)) })
        data.game.unlocked = ["first", "perfect"]
        return PetStore(data: data, persists: false)
    }
}
