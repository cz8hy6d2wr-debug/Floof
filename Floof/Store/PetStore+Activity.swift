import Foundation

/// Protokoll: jede Aktion mit Name und Uhrzeit festhalten.
extension PetStore {
    /// Mein Name für das Protokoll (leer = ohne Namen).
    var myName: String { data.userName.trimmingCharacters(in: .whitespaces) }

    /// Eintrag hinzufügen. Mit gleicher `id` wird ein bestehender Eintrag ersetzt
    /// (z. B. Kurz-Check eines Tages, der nachträglich geändert wird).
    func log(_ kind: ActivityEntry.Kind, _ text: String, petID: Pet.ID? = nil, id: String? = nil, date: Date = .now) {
        let entry = ActivityEntry(id: id ?? UUID().uuidString, date: date, author: myName,
                                  petID: petID, kind: kind, text: text)
        update { data in
            data.activity.removeAll { $0.id == entry.id }
            data.activity.insert(entry, at: 0)
            if data.activity.count > 800 { data.activity.removeLast(data.activity.count - 800) }
        }
    }

    /// "Du" für eigene Einträge, sonst der Name (oder "Jemand").
    func displayAuthor(_ entry: ActivityEntry) -> String {
        if entry.author.isEmpty { return myName.isEmpty ? "Du" : "Jemand" }
        return entry.author == myName ? "Du" : entry.author
    }

    // MARK: Neu seit dem letzten Blick in den Verlauf

    private static let seenKey = "floof.activity.seen"

    var activitySeen: Date {
        UserDefaults.standard.object(forKey: Self.seenKey) as? Date ?? .distantPast
    }

    /// Einträge vom anderen iPhone, die ich noch nicht gesehen habe.
    var newActivityCount: Int {
        _ = activityRevision   // neu berechnen, wenn der Verlauf gelesen wurde
        let seen = activitySeen
        return data.activity.filter { $0.date > seen && !$0.author.isEmpty && $0.author != myName }.count
    }

    func markActivitySeen() {
        UserDefaults.standard.set(Date.now, forKey: Self.seenKey)
        activityRevision += 1
    }
}
