import Foundation
import UserNotifications

/// Lokale Mitteilungen für Medikamentengaben und knappen Vorrat.
enum ReminderScheduler {
    private static let dosePrefix = "floof.dose."

    static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Plant alle wöchentlich wiederkehrenden Gaben neu (max. 64 Mitteilungen erlaubt iOS).
    static func reschedule(for data: AppData) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(dosePrefix) })
        guard data.notificationsEnabled else { return }

        // Gaben zur selben Uhrzeit zusammenfassen: "15:00 – Panacur, Gabapentin für Brownie"
        struct Slot: Hashable { let weekday: Int; let time: ReminderTime }
        var slots: [Slot: [String]] = [:]
        for pet in data.pets {
            for med in pet.medications {
                guard let reminder = med.reminder else { continue }
                for weekday in reminder.weekdays {
                    for time in reminder.allTimes {
                        slots[Slot(weekday: weekday, time: time), default: []].append("\(med.title) für \(pet.name)")
                    }
                }
            }
        }

        for (slot, items) in slots.prefix(60) {
            let content = UNMutableNotificationContent()
            content.title = "Zeit für die Medizin"
            content.body = items.joined(separator: ", ")
            content.sound = .default
            content.interruptionLevel = .timeSensitive
            var components = DateComponents()
            components.weekday = slot.weekday
            components.hour = slot.time.hour
            components.minute = slot.time.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let id = "\(dosePrefix)\(slot.weekday)-\(slot.time.label)"
            try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
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
