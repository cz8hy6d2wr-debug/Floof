import Foundation

/// Reine Logik der Synchronisation: Änderungen stempeln und zwei Stände zusammenführen.
/// Kein Datei- oder UI-Code hier – dadurch leicht nachvollziehbar.
enum SyncEngine {

    // MARK: Stempeln

    /// Vergleicht den Stand vor und nach einer lokalen Änderung und vermerkt,
    /// welche Datensätze sich wann geändert haben.
    static func stamp(before: AppData, after: inout AppData, now: Date = .now) {
        diff("pet", before.pets, after.pets, &after.sync, now)
        diff("diary", before.diary, after.diary, &after.sync, now)
        diff("cab", before.cabinet, after.cabinet, &after.sync, now)
        for key in before.takenDoses.symmetricDifference(after.takenDoses) {
            after.sync.doseTimes[key] = now
        }
    }

    private static func diff<T: Identifiable & Hashable>(_ prefix: String, _ old: [T], _ new: [T],
                                                        _ meta: inout SyncMeta, _ now: Date) where T.ID == String {
        let oldMap = Dictionary(old.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let newMap = Dictionary(new.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for (id, value) in newMap where oldMap[id] != value {
            meta.recordTimes["\(prefix):\(id)"] = now
            meta.deleted.removeValue(forKey: "\(prefix):\(id)")
        }
        for id in oldMap.keys where newMap[id] == nil {
            meta.deleted["\(prefix):\(id)"] = now
        }
    }

    // MARK: Zusammenführen

    /// Führt den Stand aus der gemeinsamen Datei mit dem lokalen zusammen.
    static func merge(local: AppData, remote: SyncSnapshot) -> AppData {
        var result = local
        let lm = local.sync, rm = remote.meta

        result.pets = mergeRecords("pet", local.pets, remote.pets, lm, rm, combine: combinePets)
        result.diary = mergeRecords("diary", local.diary, remote.diary, lm, rm, combine: { newer, _ in newer })
        result.cabinet = mergeRecords("cab", local.cabinet, remote.cabinet, lm, rm, combine: combineCabinet)
        result.customBreeds = Array(Set(local.customBreeds).union(remote.customBreeds)).sorted()
        result.activity = mergeActivity(local.activity, remote.activity ?? [])

        // Gaben: je Schlüssel gewinnt die neuere Aktion (abgehakt oder zurückgenommen).
        var taken = local.takenDoses
        for key in Set(lm.doseTimes.keys).union(rm.doseTimes.keys).union(remote.takenDoses) {
            let lt = lm.doseTimes[key] ?? .distantPast
            let rt = rm.doseTimes[key] ?? .distantPast
            if rt > lt {
                if remote.takenDoses.contains(key) { taken.insert(key) } else { taken.remove(key) }
            } else if lt == .distantPast && rt == .distantPast && remote.takenDoses.contains(key) {
                taken.insert(key)   // ältere Daten ohne Zeitstempel: im Zweifel als gegeben werten
            }
        }
        result.takenDoses = taken

        // Zeitstempel: jeweils der neueste.
        result.sync.recordTimes = lm.recordTimes.merging(rm.recordTimes, uniquingKeysWith: max)
        result.sync.deleted = lm.deleted.merging(rm.deleted, uniquingKeysWith: max)
        result.sync.doseTimes = lm.doseTimes.merging(rm.doseTimes, uniquingKeysWith: max)
        return result
    }

    /// Datensätze je ID zusammenführen: neuere Änderung gewinnt, Löschungen werden respektiert.
    private static func mergeRecords<T: Identifiable & Hashable>(
        _ prefix: String, _ local: [T], _ remote: [T], _ lm: SyncMeta, _ rm: SyncMeta,
        combine: (_ newer: T, _ older: T) -> T
    ) -> [T] where T.ID == String {
        let localMap = Dictionary(local.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let remoteMap = Dictionary(remote.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var order = local.map(\.id)
        for r in remote where localMap[r.id] == nil { order.append(r.id) }

        var result: [T] = []
        for id in order {
            let key = "\(prefix):\(id)"
            let changed = max(lm.recordTimes[key] ?? .distantPast, rm.recordTimes[key] ?? .distantPast)
            let deleted = max(lm.deleted[key] ?? .distantPast, rm.deleted[key] ?? .distantPast)
            if deleted > changed { continue }   // gelöscht, und danach nicht mehr geändert

            switch (localMap[id], remoteMap[id]) {
            case let (l?, r?):
                if l == r { result.append(l); break }
                let lt = lm.recordTimes[key] ?? .distantPast
                let rt = rm.recordTimes[key] ?? .distantPast
                result.append(rt > lt ? combine(r, l) : combine(l, r))
            case let (l?, nil):
                result.append(l)
            case let (nil, r?):
                result.append(r)
            case (nil, nil):
                break
            }
        }
        return result
    }

    /// Tiere: neuere Version als Basis, aber Gewichte, Checks und Pflege-/Medikamenten-
    /// einträge beider Seiten behalten – so geht parallel Eingetragenes nicht verloren.
    private static func combinePets(newer: Pet, older: Pet) -> Pet {
        var pet = newer
        pet.weights = union(newer.weights, older.weights)
        pet.dailyChecks = union(newer.dailyChecks, older.dailyChecks)
        pet.care = union(newer.care, older.care)
        return pet
    }

    /// Schrank: neuere Version als Basis; Buchungen der anderen Seite nachtragen
    /// (inkl. Bestand). Dieselbe Gabe wird nicht doppelt abgebucht.
    private static func combineCabinet(newer: CabinetItem, older: CabinetItem) -> CabinetItem {
        var item = newer
        let knownIDs = Set(newer.history.map(\.id))
        let knownDoses = Set(newer.history.compactMap(\.doseID))
        for event in older.history where !knownIDs.contains(event.id) {
            if let dose = event.doseID, knownDoses.contains(dose) { continue }
            item.stock = max(0, item.stock + event.delta)
            item.history.append(event)
        }
        item.history.sort { $0.date > $1.date }
        return item
    }

    /// Protokoll: beide Seiten vereinen; bei gleicher ID gewinnt der neuere Eintrag.
    static func mergeActivity(_ a: [ActivityEntry], _ b: [ActivityEntry]) -> [ActivityEntry] {
        var byID: [String: ActivityEntry] = [:]
        for entry in a + b {
            if let existing = byID[entry.id], existing.date >= entry.date { continue }
            byID[entry.id] = entry
        }
        return Array(byID.values.sorted { $0.date > $1.date }.prefix(800))
    }

    private static func union<T: Identifiable>(_ preferred: [T], _ other: [T]) -> [T] where T.ID == String {
        let ids = Set(preferred.map(\.id))
        return preferred + other.filter { !ids.contains($0.id) }
    }
}
