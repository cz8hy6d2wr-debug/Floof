import Foundation

/// Tagebuch: Einträge und Zeitleiste.
extension PetStore {
    func upsertDiary(_ entry: DiaryEntry) {
        let isNew = !diary.contains { $0.id == entry.id }
        defer {
            if isNew && !entry.isAutomatic {
                let title = entry.title.isEmpty ? String(entry.text.prefix(40)) : entry.title
                log(.diary, "Tagebuch: \(title.isEmpty ? entry.mood.label : title)", petID: entry.petIDs.first, date: entry.date)
            }
        }
        update { data in
            if let i = data.diary.firstIndex(where: { $0.id == entry.id }) { data.diary[i] = entry }
            else { data.diary.append(entry) }
        }
    }

    func deleteDiary(_ entry: DiaryEntry) {
        if let photo = entry.photoFilename { DiskStore.deletePhoto(named: photo) }
        update { $0.diary.removeAll { $0.id == entry.id } }
    }

    /// Zeitleiste, neueste zuerst. `petID == nil` = alle Tiere.
    func timeline(petID: Pet.ID? = nil, tag: DiaryTag? = nil) -> [TimelineItem] {
        var items: [TimelineItem] = diary
            .filter { petID == nil || $0.petIDs.contains(petID!) }
            .filter { tag == nil || $0.tags.contains(tag!) }
            .map { .entry($0) }

        // Automatische Ereignisse nur ohne Tag-Filter (bzw. passend zum Tag).
        for pet in pets where petID == nil || pet.id == petID {
            if tag == nil || tag == .health {
                items += pet.weights.map { .weight(pet, $0) }
            }
            if tag == nil || tag == .vet || tag == .health {
                items += pet.care.filter { $0.careKind != .medication }.map { .care(pet, $0) }
            }
            // Kurz-Checks mit Auffälligkeiten oder Notiz – so bleibt nachvollziehbar, seit wann etwas war.
            if tag == nil || tag == .health {
                items += pet.dailyChecks.filter { $0.findings != nil || $0.note != nil }.map { .check(pet, $0) }
            }
        }
        return items.sorted { $0.date > $1.date }
    }

    /// Durchschnittliche Stimmung je Tag eines Monats (0…4), für den Stimmungskalender.
    func moodByDay(in month: Date, petID: Pet.ID?) -> [Int: Double] {
        let cal = Calendar.current
        var buckets: [Int: [Int]] = [:]
        for entry in diary where !entry.isAutomatic && (petID == nil || entry.petIDs.contains(petID!)) {
            guard cal.isDate(entry.date, equalTo: month, toGranularity: .month) else { continue }
            buckets[cal.component(.day, from: entry.date), default: []].append(entry.mood.score)
        }
        return buckets.mapValues { Double($0.reduce(0, +)) / Double($0.count) }
    }
}
