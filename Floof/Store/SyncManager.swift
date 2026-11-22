import Foundation
import Observation
import UserNotifications
import BackgroundTasks

/// Gemeinsame Nutzung über eine Datei in einem (geteilten) iCloud-Drive-Ordner.
///
/// Ohne bezahlten Developer-Account gibt es kein CloudKit – aber jede App darf eine
/// Datei lesen und schreiben, die der Nutzer selbst ausgewählt hat. Liegt sie in einem
/// geteilten iCloud-Drive-Ordner, sehen beide iPhones dieselbe Datei.
///
/// Ablauf je Durchgang: Datei lesen → mit lokalem Stand zusammenführen → zurückschreiben,
/// Fotos abgleichen. Läuft beim Öffnen, kurz nach Änderungen, alle 45 s im Vordergrund
/// und gelegentlich im Hintergrund (iOS entscheidet, wann).
@MainActor
@Observable
final class SyncManager {
    static let shared = SyncManager()
    static let backgroundTaskID = "app.floof.diary.sync"

    private(set) var folderName: String?
    private(set) var lastSync: Date?
    private(set) var isSyncing = false
    private(set) var lastError: String?

    var isConnected: Bool { folderName != nil }

    @ObservationIgnored private weak var store: PetStore?
    @ObservationIgnored private var timer: Task<Void, Never>?
    @ObservationIgnored private var pending: Task<Void, Never>?

    private let bookmarkKey = "floof.sync.folderBookmark"
    private let fileName = "Floof-Gemeinsam.floof"
    private let photoFolder = "Floof-Fotos"

    private init() {
        folderName = (try? resolveFolder())?.lastPathComponent
        lastSync = UserDefaults.standard.object(forKey: "floof.sync.last") as? Date
    }

    // MARK: Lebenszyklus

    func attach(_ store: PetStore) { self.store = store }

    /// App ist im Vordergrund: sofort abgleichen und dann regelmäßig.
    func startForeground() {
        guard isConnected else { return }
        timer?.cancel()
        timer = Task { [weak self] in
            while !Task.isCancelled {
                await self?.syncNow()
                try? await Task.sleep(for: .seconds(45))
            }
        }
    }

    func stopForeground() {
        timer?.cancel()
        timer = nil
        scheduleBackgroundRefresh()
    }

    /// Lokale Änderung: kurz warten (mehrere Taps bündeln), dann abgleichen.
    func localDidChange() {
        guard isConnected else { return }
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await self?.syncNow()
        }
    }

    // MARK: Ordner wählen / trennen

    func connect(folder url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
            folderName = url.lastPathComponent
            lastError = nil
            startForeground()
        } catch {
            lastError = "Ordner konnte nicht gemerkt werden: \(error.localizedDescription)"
        }
    }

    func disconnect() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        folderName = nil
        lastError = nil
        timer?.cancel()
    }

    // MARK: Abgleich

    @discardableResult
    func syncNow() async -> Bool {
        guard let store, !isSyncing else { return false }
        guard let folder = try? resolveFolder() else {
            if isConnected { lastError = "Zugriff auf den Ordner verloren – bitte neu auswählen." }
            return false
        }
        isSyncing = true
        defer { isSyncing = false }

        let local = store.data
        let me = local.userName.isEmpty ? "Jemand" : local.userName
        let fileURL = folder.appending(path: fileName)
        let photosURL = folder.appending(path: photoFolder, directoryHint: .isDirectory)
        let photoNames = Set(local.pets.compactMap(\.photoFilename) + local.diary.compactMap(\.photoFilename))

        // Datei- und Foto-Arbeit abseits des Hauptthreads (iCloud kann erst laden müssen).
        let outcome: (remote: SyncSnapshot?, error: String?) = await Task.detached(priority: .utility) {
            let accessing = folder.startAccessingSecurityScopedResource()
            defer { if accessing { folder.stopAccessingSecurityScopedResource() } }
            do {
                let remote = try Self.readSnapshot(at: fileURL)
                Self.syncPhotos(names: photoNames, folder: photosURL)
                return (remote, nil)
            } catch {
                return (nil, error.localizedDescription)
            }
        }.value

        if let error = outcome.error {
            lastError = "Lesen fehlgeschlagen: \(error)"
            return false
        }

        // Zusammenführen und übernehmen
        var merged = local
        if let remote = outcome.remote {
            merged = SyncEngine.merge(local: local, remote: remote)
            notifyAboutPartnerDoses(before: local, after: merged, by: remote.savedBy)
            store.applySynced(merged)
        }

        // Zurückschreiben
        let snapshot = SyncSnapshot(savedBy: me, pets: merged.pets, diary: merged.diary, cabinet: merged.cabinet,
                                    customBreeds: merged.customBreeds, takenDoses: merged.takenDoses, meta: merged.sync)
        let allPhotos = Set(merged.pets.compactMap(\.photoFilename) + merged.diary.compactMap(\.photoFilename))
        let writeError: String? = await Task.detached(priority: .utility) {
            let accessing = folder.startAccessingSecurityScopedResource()
            defer { if accessing { folder.stopAccessingSecurityScopedResource() } }
            do {
                try Self.writeSnapshot(snapshot, to: fileURL)
                Self.syncPhotos(names: allPhotos, folder: photosURL)
                return nil
            } catch {
                return error.localizedDescription
            }
        }.value

        if let writeError {
            lastError = "Speichern fehlgeschlagen: \(writeError)"
            return false
        }
        lastError = nil
        lastSync = .now
        UserDefaults.standard.set(lastSync, forKey: "floof.sync.last")
        return true
    }

    // MARK: Mitteilung, wenn der/die andere eine Gabe abgehakt hat

    private func notifyAboutPartnerDoses(before: AppData, after: AppData, by name: String) {
        let newlyTaken = after.takenDoses.subtracting(before.takenDoses)
        guard !newlyTaken.isEmpty, before.notificationsEnabled else { return }
        // Dosis-Schlüssel: "yyyy-MM-dd|<medID>|HH:mm" – nur heutige melden.
        let today = DoseKey.day(.now)
        var lines: [String] = []
        for key in newlyTaken {
            let parts = key.split(separator: "|").map(String.init)
            guard parts.count == 3, parts[0] == today else { continue }
            for pet in after.pets {
                if let med = pet.care.first(where: { $0.id == parts[1] }) {
                    lines.append("\(med.title) für \(pet.name) (\(parts[2]))")
                }
            }
        }
        guard !lines.isEmpty else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(name) hat Medikamente gegeben"
        content.body = lines.sorted().joined(separator: ", ")
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "floof.partner.\(UUID().uuidString)", content: content, trigger: nil))
    }

    // MARK: Hintergrund

    func scheduleBackgroundRefresh() {
        guard isConnected else { return }
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskID)
        request.earliestBeginDate = .now.addingTimeInterval(15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: Dateien (ohne Hauptthread)

    private func resolveFolder() throws -> URL {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { throw CocoaError(.fileNoSuchFile) }
        var stale = false
        let url = try URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
        if stale, let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(fresh, forKey: bookmarkKey)
        }
        return url
    }

    nonisolated private static func readSnapshot(at url: URL) throws -> SyncSnapshot? {
        var coordError: NSError?
        var result: Result<SyncSnapshot?, Error> = .success(nil)
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordError) { readURL in
            guard FileManager.default.fileExists(atPath: readURL.path) else { return }
            result = Result { try JSONDecoder().decode(SyncSnapshot.self, from: Data(contentsOf: readURL)) }
        }
        if let coordError { throw coordError }
        return try result.get()
    }

    nonisolated private static func writeSnapshot(_ snapshot: SyncSnapshot, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(snapshot)
        var coordError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordError) { writeURL in
            do { try data.write(to: writeURL, options: .atomic) } catch { writeError = error }
        }
        if let coordError { throw coordError }
        if let writeError { throw writeError }
    }

    /// Fotos in beide Richtungen kopieren, die auf einer Seite fehlen.
    nonisolated private static func syncPhotos(names: Set<String>, folder: URL) {
        let fm = FileManager.default
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        try? fm.createDirectory(at: DiskStore.photosDirectory, withIntermediateDirectories: true)
        let coordinator = NSFileCoordinator()
        for name in names {
            let local = DiskStore.photosDirectory.appending(path: name)
            let remote = folder.appending(path: name)
            let hasLocal = fm.fileExists(atPath: local.path)
            if hasLocal && !fm.fileExists(atPath: remote.path) {
                coordinator.coordinate(writingItemAt: remote, options: .forReplacing, error: nil) { url in
                    try? fm.copyItem(at: local, to: url)
                }
            } else if !hasLocal {
                coordinator.coordinate(readingItemAt: remote, options: [], error: nil) { url in
                    if fm.fileExists(atPath: url.path) { try? fm.copyItem(at: url, to: local) }
                }
            }
        }
    }
}
