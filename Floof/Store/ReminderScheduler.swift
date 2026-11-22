import Foundation
import UserNotifications

/// Lokale Mitteilungen für Medikamentengaben und knappen Vorrat.
enum ReminderScheduler {
    private static let dosePrefix = "floof.dose."

    static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Plant die Erinnerungen der nächsten 7 Tage – konkret je Tag und Uhrzeit, nicht wöchentlich
    /// wiederholend. So entfällt eine Erinnerung, wenn die Gabe schon gegeben wurde
    /// (auch vom anderen iPhone bei gemeinsamer Nutzung). iOS erlaubt max. 64 geplante Mitteilungen.
    static func reschedule(for data: AppData) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(dosePrefix) })
        guard data.notificationsEnabled else { return }

        let cal = Calendar.current
        var requests: [UNNotificationRequest] = []
        for offset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: .now)) else { continue }
            let weekday = cal.component(.weekday, from: day)

            // Offene Gaben dieses Tages nach Uhrzeit gruppieren
            var slots: [ReminderTime: [String]] = [:]
            for pet in data.pets {
                for med in pet.medications {
                    guard let reminder = med.reminder, reminder.weekdays.contains(weekday) else { continue }
                    for time in reminder.allTimes {
                        let key = "\(DoseKey.day(day))|\(med.id)|\(time.label)"
                        guard !data.takenDoses.contains(key) else { continue }   // schon gegeben
                        slots[time, default: []].append("\(med.title) für \(pet.name)")
                    }
                }
            }

            for (time, items) in slots {
                guard let fire = cal.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: day),
                      fire > .now else { continue }
                let content = UNMutableNotificationContent()
                content.title = "Zeit für die Medizin"
                content.body = items.sorted().joined(separator: ", ")
                content.sound = .default
                content.interruptionLevel = .timeSensitive
                let parts = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
                requests.append(UNNotificationRequest(identifier: "\(dosePrefix)\(DoseKey.day(day))-\(time.label)",
                                                      content: content, trigger: trigger))
            }
        }

        for request in requests.sorted(by: { $0.identifier < $1.identifier }).prefix(60) {
            try? await center.add(request)
        }
    }

    static func notifyLowStock(_ name: String, daysLeft: Int?) {
        let content = UNMutableNotificationContent()
        content.title = "\(name) wird knapp"
        content.body = daysLeft.map { "Reicht noch etwa \($0) Tag\($0 == 1 ? "" : "e"). Zeit nachzukaufen." }
            ?? "Bitte bald nachkaufen."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "floof.stock.\(name)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
