import Foundation

/// Ein Hinweis für "Heute": was gerade sinnvoll zu tun ist.
struct TodayHint: Identifiable, Hashable {
    enum Action: Hashable {
        case routine(CareRoutine.Kind, Pet.ID)
        case weigh(Pet.ID)
        case diary(Pet.ID?)
        case cabinet(CabinetItem.ID)
        case article(String)
    }

    let id: String
    let symbol: String
    let title: String
    let detail: String
    var urgent = false
    let action: Action
    var actionTitle: String
}

extension PetStore {
    /// Bis zu `limit` Hinweise, wichtigste zuerst. Ist nichts fällig, kommt ein Tipp des Tages.
    func todayHints(petID: Pet.ID?, limit: Int = 3) -> [TodayHint] {
        let chosen = petID.flatMap(pet).map { [$0] } ?? pets
        var hints: [TodayHint] = []

        for pet in chosen {
            // Fällige oder nie erledigte Pflege-Routinen
            for routine in pet.careRoutines {
                let days = pet.daysUntilDue(routine)
                // Nur wirklich Fälliges. Noch nie eingetragene Routinen stehen unter Tiere → Pflege
                // (Ausnahme: Wiegen, wenn es gar kein Gewicht gibt).
                let neverDone = pet.lastDone(routine) == nil
                if neverDone && routine.kind != .weigh { continue }
                guard neverDone || (days ?? 1) <= 0 else { continue }

                let detail: String
                if let last = pet.lastDone(routine) {
                    let ago = Calendar.current.dateComponents([.day], from: last, to: .now).day ?? 0
                    detail = "\(pet.name) · zuletzt vor \(ago) Tag\(ago == 1 ? "" : "en")"
                } else {
                    detail = "\(pet.name) · noch nie gewogen"
                }
                let isWeigh = routine.kind == .weigh
                hints.append(TodayHint(
                    id: "routine-\(pet.id)-\(routine.kind.rawValue)",
                    symbol: routine.kind.symbol,
                    title: routine.kind.title,
                    detail: detail,
                    urgent: (days ?? 0) < -routine.intervalDays,
                    action: isWeigh ? .weigh(pet.id) : .routine(routine.kind, pet.id),
                    actionTitle: isWeigh ? "Wiegen" : "Erledigt"))
            }

            // Impfung bald fällig oder überfällig
            for vaccination in pet.vaccinations {
                guard let due = vaccination.nextDueDate else { continue }
                let days = Calendar.current.dateComponents([.day], from: .now, to: due).day ?? 0
                guard days <= 21 else { continue }
                hints.append(TodayHint(
                    id: "vacc-\(vaccination.id)",
                    symbol: "syringe",
                    title: "Impfung \(vaccination.title)",
                    detail: days < 0 ? "\(pet.name) · überfällig" : "\(pet.name) · in \(days) Tagen fällig",
                    urgent: days < 0,
                    action: .diary(pet.id),
                    actionTitle: "Notieren"))
                break
            }
        }

        // Medikamentenschrank
        for item in cabinetAlerts.prefix(2) {
            hints.append(TodayHint(
                id: "cab-\(item.id)",
                symbol: "cross.case",
                title: item.name,
                detail: CabinetStatusText.short(status(of: item)),
                urgent: { if case .empty = status(of: item) { return true }; return false }(),
                action: .cabinet(item.id),
                actionTitle: "Ansehen"))
        }

        // Tagebuch schon länger nicht geschrieben
        let lastEntry = diary.filter { !$0.isAutomatic && (petID == nil || $0.petIDs.contains(petID!)) }
            .map(\.date).max()
        let daysSinceEntry = lastEntry.map { Calendar.current.dateComponents([.day], from: $0, to: .now).day ?? 0 }
        if daysSinceEntry == nil || daysSinceEntry! >= 3 {
            hints.append(TodayHint(
                id: "diary",
                symbol: "book.closed",
                title: "Was war heute los?",
                detail: daysSinceEntry.map { "Letzter Tagebucheintrag vor \($0) Tagen" } ?? "Noch kein Tagebucheintrag",
                action: .diary(petID),
                actionTitle: "Schreiben"))
        }

        hints.sort { $0.urgent && !$1.urgent }
        if hints.isEmpty, let tip = tipOfTheDay {
            hints.append(TodayHint(id: "tip-\(tip.id)", symbol: "lightbulb", title: tip.title,
                                   detail: tip.summary, action: .article(tip.id), actionTitle: "Lesen"))
        }
        return Array(hints.prefix(limit))
    }

    /// Jeden Tag ein anderer Lexikon-Artikel (ohne Notfall-Artikel).
    var tipOfTheDay: LexiconArticle? {
        let pool = Lexicon.articles.filter { $0.category != .emergency }
        guard !pool.isEmpty else { return nil }
        let dayIndex = Calendar.current.ordinality(of: .day, in: .era, for: .now) ?? 0
        return pool[dayIndex % pool.count]
    }
}
