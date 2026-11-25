import SwiftUI
import UIKit

/// Auffangstation: Level, Aufgaben, Sammelbuch, Fotos, Hoppelgram und Vermittlung.
extension GardenGame {

    // MARK: - Level & Erfahrung

    var level: Int { save.level ?? 1 }
    var xp: Int { save.xp ?? 0 }
    var xpForNext: Int { Progression.xpNeeded(forLevel: level) }
    var followers: Int { save.followers ?? 0 }
    var posts: [SocialPost] { save.posts ?? [] }
    var adopters: [Adopter] { (save.adopters ?? []).filter { $0.expires > .now } }
    var adoptions: [AdoptionRecord] { save.adoptions ?? [] }
    var quests: [GardenQuest] { save.quests ?? [] }
    var combosFound: Int { save.combos?.count ?? 0 }
    var claimableQuests: Int { quests.filter { $0.done && !$0.claimed }.count }

    // MARK: - Eigene Kaninchen

    /// Schützlinge in der Station (ohne die eigenen Kaninchen).
    var stationResidents: [GardenRabbit] { residents.filter { !$0.isKept } }
    var keptRabbits: [GardenRabbit] { residents.filter(\.isKept) }
    /// Plätze im eigenen Gehege: 2, alle 4 Level einer mehr.
    var keepCapacity: Int { 2 + level / 4 }

    /// Für immer behalten – oder wieder zur Vermittlung freigeben.
    func setKept(_ id: UUID, _ keep: Bool) {
        guard let i = index(of: id), !save.rabbits[i].isVisitor else { return }
        // Partner bleiben zusammen – behalten oder freigeben nur gemeinsam.
        let partnerIndex = save.rabbits[i].partner.flatMap { index(of: $0) }
        if keep {
            let needed = partnerIndex != nil && save.rabbits[partnerIndex!].isKept == false ? 2 : 1
            guard keptRabbits.count + needed <= keepCapacity else {
                showBanner("Dein Gehege ist voll (\(keepCapacity) Plätze) – mehr gibt es mit höherem Level", symbol: "house.fill", duration: 4)
                return
            }
            save.rabbits[i].kept = true
            save.rabbits[i].mood = min(100, save.rabbits[i].mood + 20)
            if let pi = partnerIndex { save.rabbits[pi].kept = true; save.rabbits[pi].mood = min(100, save.rabbits[pi].mood + 20) }
            let p = screen(save.rabbits[i].x, save.rabbits[i].y)
            burst(.heart, at: CGPoint(x: p.x, y: p.y - 40), count: 10, color: .pink)
            notify.notificationOccurred(.success)
            showBanner("\(save.rabbits[i].name) bleibt für immer bei dir 💛 – und hilft Neuankömmlingen, Vertrauen zu fassen",
                       symbol: "heart.circle.fill", duration: 5)
            gainXP(10)
        } else {
            save.rabbits[i].kept = nil
            if let pi = partnerIndex { save.rabbits[pi].kept = nil }
            showBanner("\(save.rabbits[i].name) wird wieder vermittelt", symbol: "house.and.flag.fill", duration: 3)
        }
        hudTick &+= 1
        persist()
    }

    func gainXP(_ amount: Int) {
        guard amount > 0, !isDemo else { return }
        var total = xp + amount
        var lvl = level
        var reached: [Int] = []
        while total >= Progression.xpNeeded(forLevel: lvl) {
            total -= Progression.xpNeeded(forLevel: lvl)
            lvl += 1
            reached.append(lvl)
        }
        save.xp = total
        save.level = lvl
        for l in reached {
            let reward = Progression.levelReward(l)
            inventory.sterne += reward
            let news = Progression.unlocks(at: l)
            showBanner("Level \(l)! +\(reward) ★" + (news.isEmpty ? "" : " · Neu: " + news.joined(separator: ", ")),
                       symbol: "rosette", duration: 6)
            notify.notificationOccurred(.success)
            burst(.confetti, at: CGPoint(x: size.width / 2, y: size.height * 0.3), count: 50, color: .white)
        }
        hudTick &+= 1
    }

    // MARK: - Aufgaben

    func track(_ event: QuestEvent, _ amount: Int = 1) {
        guard var list = save.quests, !isDemo else { return }
        var changed = false
        for i in list.indices where !list[i].claimed && !list[i].done && list[i].goal.matches(event) {
            list[i].progress = min(list[i].target, list[i].progress + amount)
            changed = true
            if list[i].done {
                showBanner("Aufgabe geschafft: \(list[i].text) – Belohnung abholen!", symbol: "checkmark.seal.fill", duration: 4)
                notify.notificationOccurred(.success)
            }
        }
        if changed { save.quests = list; hudTick &+= 1 }
    }

    static func dayKey(_ date: Date = .now) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// Neuer Tag → neue Aufgaben.
    func refreshQuestsIfNeeded() {
        guard !isDemo else { return }
        let today = Self.dayKey()
        guard save.questDay != today else { return }
        save.questDay = today
        save.quests = GardenQuest.daily(level: level, season: season, residents: residents.count,
                                        decorOwned: DecorKind.allCases.contains { save.stock($0) > 0 })
        hudTick &+= 1
    }

    var canReroll: Bool { save.rerollDay != Self.dayKey() }

    func rerollQuest(_ id: UUID) {
        guard canReroll, var list = save.quests, let i = list.firstIndex(where: { $0.id == id }) else { return }
        let fresh = GardenQuest.daily(level: level, season: season, residents: residents.count, decorOwned: true)
        let existing = Set(list.map { "\($0.goal)".components(separatedBy: "(").first ?? "" })
        guard let replacement = fresh.first(where: { !existing.contains("\($0.goal)".components(separatedBy: "(").first ?? "") })
                ?? fresh.first else { return }
        list[i] = replacement
        save.quests = list
        save.rerollDay = Self.dayKey()
        hudTick &+= 1
    }

    func claimQuest(_ id: UUID) {
        guard var list = save.quests, let i = list.firstIndex(where: { $0.id == id }), list[i].done, !list[i].claimed else { return }
        list[i].claimed = true
        save.quests = list
        inventory.sterne += list[i].stars
        if let food = list[i].bonusFood { inventory[food] += list[i].bonusAmount }
        notify.notificationOccurred(.success)
        gainXP(list[i].xp)
        hudTick &+= 1
        persist()
    }

    // MARK: - Sammelbuch

    /// Neue Kombination aus Fell, Zeichnung und Rasse ins Sammelbuch.
    func register(_ look: RabbitLook) {
        var combos = save.combos ?? []
        let key = Progression.comboKey(look)
        guard !combos.contains(key) else { return }
        combos.insert(key)
        save.combos = combos
        var claimed = save.claimedMilestones ?? []
        for m in Progression.milestones where combos.count >= m && !claimed.contains(m) {
            claimed.insert(m)
            let r = Progression.milestoneReward(m)
            inventory.sterne += r.stars
            showBanner("Sammelbuch: \(m) Kombinationen entdeckt! +\(r.stars) ★", symbol: "books.vertical.fill", duration: 5)
            gainXP(r.xp)
        }
        save.claimedMilestones = claimed
    }

    // MARK: - Fotos

    static var photoFolder: URL {
        let url = URL.documentsDirectory.appending(path: "Fotos")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func photoImage(_ file: String) -> UIImage? {
        if let cached = photoCache[file] { return cached }
        let image = UIImage(contentsOfFile: Self.photoFolder.appending(path: file).path())
        if let image { photoCache[file] = image }
        return image
    }

    /// Foto eines Schützlings – die Note hängt davon ab, was er gerade tut, vom Licht und von der Umgebung.
    func takePhoto(of id: UUID) {
        guard let r = save.rabbits.first(where: { $0.id == id }) else { return }
        let a = actors[id] ?? RabbitActor()
        var score = 25.0
        var notes: [String] = []
        switch a.mode {
        case .binky: score += 40; notes.append("Luftsprung erwischt! 🤩")
        case .flop: score += 28; notes.append("Herrlich entspannt ausgestreckt")
        case .eat, .graze: score += 16; notes.append("Beim Mümmeln")
        case .groom: score += 12; notes.append("Beim Putzen")
        case .drink: score += 12; notes.append("Am Teich")
        case .sleep: score += 6; notes.append("Schläft – süß, aber etwas langweilig")
        case .startled: score -= 10; notes.append("Verwackelt – es hat sich erschreckt")
        case .hide: score -= 20; notes.append("Steckt im Tunnel …")
        default: score += a.isHopping ? 10 : 4
        }
        if a.pettedUntil > clock { score += 10; notes.append("Mit Streichelhand – herzig") }
        if isTwilight { score += 14; notes.append("Goldene Stunde ✨") }
        else if daylight > 0.8 { score += 8 }
        else { score -= 6; notes.append("Etwas dunkel") }
        if rainAmount > 0.5 { score -= 5 }
        if snowCover > 0.5 { score += 6; notes.append("Winterzauber ❄️") }
        if save.decor.contains(where: { hypot($0.x - r.x, $0.y - r.y) < 0.16 }) { score += 8; notes.append("Schöne Deko im Bild") }
        score += r.mood / 10
        score += Double(r.rarity.rawValue) * 3
        if r.isVisitor { score -= 15; notes.append("Noch scheu – erst Vertrauen gewinnen") }
        let finalScore = Int(min(100, max(5, score)))

        // Szene ohne Bedienelemente aufnehmen und um das Kaninchen zuschneiden.
        let sceneSize = size
        let time = Date.now.timeIntervalSinceReferenceDate
        let content = Canvas(opaque: true) { ctx, s in
            GardenRenderer.draw(self, in: &ctx, size: s, time: time)
        }
        .frame(width: sceneSize.width, height: sceneSize.height)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let full = renderer.cgImage else { return }
        let p = screen(r.x, r.y)
        let s = scale(atY: r.y) * r.look.breed.bodyScale
        let side = min(min(sceneSize.width, sceneSize.height), max(170, 150 * s))
        var crop = CGRect(x: p.x - side / 2, y: p.y - side * 0.62, width: side, height: side)
        crop.origin.x = min(max(0, crop.origin.x), sceneSize.width - side)
        crop.origin.y = min(max(0, crop.origin.y), sceneSize.height - side)
        let px = CGRect(x: crop.minX * 2, y: crop.minY * 2, width: crop.width * 2, height: crop.height * 2)
        guard let cut = full.cropping(to: px) else { return }

        burst(.sparkle, at: CGPoint(x: p.x, y: p.y - 30), count: 10, color: .white)
        light.impactOccurred()
        track(.foto(max(1, min(5, Int((Double(finalScore) / 20).rounded(.up))))))
        gainXP(2)
        photoResult = PhotoResult(rabbitID: id, name: r.isVisitor ? "Neuankömmling" : r.name,
                                  image: UIImage(cgImage: cut), score: finalScore, notes: notes)
    }

    /// Foto auf Hoppelgram posten.
    func post(_ photo: PhotoResult, caption: String) {
        let file = "\(UUID().uuidString).jpg"
        if let data = photo.image.jpegData(compressionQuality: 0.82) {
            try? data.write(to: Self.photoFolder.appending(path: file))
        }
        let rarity = save.rabbits.first { $0.id == photo.rabbitID }?.rarity ?? .gewoehnlich
        let target = Int(pow(Double(photo.score), 1.25) * (1 + Double(followers) / 250) * (1 + Double(rarity.rawValue) * 0.3)) + 3
        var list = save.posts ?? []
        // pro Kaninchen zählt nur der neueste Post für die Vermittlung
        list.insert(SocialPost(rabbitID: photo.rabbitID, rabbitName: photo.name, photo: file, score: photo.score,
                               caption: caption, targetLikes: target), at: 0)
        save.posts = Array(list.prefix(60))
        photoResult = nil
        track(.posten)
        gainXP(5)
        showBanner("Gepostet! Mal sehen, wer sich in \(photo.name) verliebt 💛", symbol: "photo.on.rectangle.angled", duration: 4)
        if (save.nextAdopterAt ?? .distantFuture) > Date.now.addingTimeInterval(adopterInterval()) {
            save.nextAdopterAt = Date.now.addingTimeInterval(adopterInterval())
        }
        hudTick &+= 1
        persist()
    }

    /// Likes, Kommentare und Follower wachsen mit der Zeit (auch während die App zu ist).
    func updateSocial(elapsed: Double) {
        guard var list = save.posts, !list.isEmpty else { return }
        var gained = 0
        for i in list.indices where list[i].likes < list[i].targetLikes {
            let age = Date.now.timeIntervalSince(list[i].created)
            let share = min(1, age / 7200)   // nach etwa zwei Stunden voll
            let goal = Int(Double(list[i].targetLikes) * (1 - pow(1 - share, 2)))
            if goal > list[i].likes {
                gained += goal - list[i].likes
                list[i].likes = goal
                let wanted = min(6, list[i].likes / 12)
                while list[i].comments.count < wanted {
                    let c = SocialPost.commentPool.randomElement()!.replacingOccurrences(of: "%@", with: list[i].rabbitName)
                    list[i].comments.append(c)
                }
            }
        }
        save.posts = list
        if gained > 0 {
            save.followers = followers + max(0, gained / 8)
            hudTick &+= 1
        }
    }

    // MARK: - Vermittlung

    /// Abstand zwischen neuen Anfragen: gute Fotos und viele Follower bringen schneller Interessenten.
    func adopterInterval() -> TimeInterval {
        let best = Double(posts.filter { !$0.adopted }.map(\.score).max() ?? 40)
        let base = 22.0 * 60 / (1 + Double(followers) / 300) / max(0.6, best / 60)
        return max(4 * 60, base)
    }

    /// Neue Anfragen nur für Schützlinge, die auf Hoppelgram gezeigt wurden.
    func updateAdopters() {
        guard !isDemo else { return }
        var list = (save.adopters ?? []).filter { $0.expires > .now }
        let postedIDs = Set(posts.filter { !$0.adopted }.map(\.rabbitID))
        let posted = stationResidents.filter { postedIDs.contains($0.id) }
        if list.count < 3, !posted.filter({ !$0.isKept }).isEmpty {
            let due = save.nextAdopterAt ?? Date.now.addingTimeInterval(adopterInterval())
            if save.nextAdopterAt == nil { save.nextAdopterAt = due }
            if Date.now >= due {
                // bevorzugt Kaninchen mit gutem Foto
                let weighted = posted.max { a, b in
                    let sa = posts.first { $0.rabbitID == a.id }?.score ?? 0
                    let sb = posts.first { $0.rabbitID == b.id }?.score ?? 0
                    return Double(sa) * Double.random(in: 0.6...1) < Double(sb) * Double.random(in: 0.6...1)
                }
                let adopter = Adopter.random(level: level, residents: stationResidents, taken: Set(list.map(\.name)), via: weighted)
                list.append(adopter)
                save.nextAdopterAt = Date.now.addingTimeInterval(adopterInterval())
                showBanner("\(adopter.name) interessiert sich\(adopter.viaPost.map { " für \($0)" } ?? "")! 💌",
                           symbol: "envelope.fill", duration: 5)
                notify.notificationOccurred(.success)
            }
        }
        save.adopters = list
        hudTick &+= 1
    }

    /// Schützlinge an ihre neuen Menschen übergeben.
    @discardableResult
    func adopt(_ adopterID: UUID, rabbits ids: [UUID]) -> Bool {
        guard var list = save.adopters, let ai = list.firstIndex(where: { $0.id == adopterID }) else { return false }
        let adopter = list[ai]
        let chosen = save.rabbits.filter { ids.contains($0.id) }
        // Partner werden nicht getrennt.
        let together = chosen.allSatisfy { r in r.partner.map { p in ids.contains(p) } ?? true }
        guard adopter.fits(chosen), chosen.allSatisfy(\.isReady), together else { return false }
        let bondedPair = chosen.count == 2 && chosen[0].partner == chosen[1].id
        list.remove(at: ai)
        save.adopters = list
        var records = save.adoptions ?? []
        var bonus = 0
        for r in chosen {
            bonus += Progression.adoptionReward(r) / 2
            records.insert(AdoptionRecord(name: r.name, look: r.look, rarity: r.rarity, family: adopter.name, date: .now,
                                          postcard: AdoptionRecord.postcard(name: r.name, family: adopter.name)), at: 0)
            let p = screen(r.x, r.y)
            burst(.heart, at: CGPoint(x: p.x, y: p.y - 30), count: 8, color: .pink)
            burst(.confetti, at: CGPoint(x: p.x, y: p.y - 30), count: 30, color: .white)
            if var posts = save.posts {
                for i in posts.indices where posts[i].rabbitID == r.id { posts[i].adopted = true }
                save.posts = posts
            }
            save.rabbits.removeAll { $0.id == r.id }
            actors[r.id] = nil
            if selectedID == r.id { selectedID = nil }
            track(.vermitteln)
        }
        save.adoptions = records
        if bondedPair { bonus += adopter.stars * 2 / 5 }
        inventory.sterne += adopter.stars + bonus
        notify.notificationOccurred(.success)
        let names = chosen.map(\.name).formatted(.list(type: .and))
        showBanner("\(names) \(chosen.count > 1 ? "ziehen" : "zieht") zu \(adopter.name) 💛 +\(adopter.stars + bonus) ★",
                   symbol: "house.and.flag.fill", duration: 6)
        gainXP(adopter.xp)
        hudTick &+= 1
        persist()
        return true
    }

    /// Was einem Schützling noch fehlt, bis er vermittelt werden kann.
    func readinessHint(_ r: GardenRabbit) -> String? {
        guard !r.isVisitor, !r.isReady, !r.isKept else { return nil }
        var missing: [String] = []
        if r.hunger < 55 { missing.append("Futter") }
        if r.mood < 60 { missing.append("gute Laune") }
        if r.friendship < 45 { missing.append("Zuneigung") }
        if Date.now.timeIntervalSince(r.joined) <= 8 * 60 { missing.append("Zeit zum Eingewöhnen") }
        return "Braucht noch: " + missing.joined(separator: ", ")
    }

    // MARK: - Takt (aus dem Spieltakt alle paar Sekunden)

    // MARK: - Partnerschaften

    static func bondKey(_ a: UUID, _ b: UUID) -> String {
        a.uuidString < b.uuidString ? "\(a.uuidString)|\(b.uuidString)" : "\(b.uuidString)|\(a.uuidString)"
    }

    func partnerName(of r: GardenRabbit) -> String? {
        r.partner.flatMap { id in save.rabbits.first { $0.id == id }?.name }
    }

    /// Wer viel Zeit nebeneinander verbringt, freundet sich an – bis die beiden unzertrennlich sind.
    func updateBonds(elapsed: Double) {
        let list = residents
        guard list.count >= 2 else { return }
        var bonds = save.bonds ?? [:]
        for a in 0..<list.count {
            for b in (a + 1)..<list.count {
                let r1 = list[a], r2 = list[b]
                let near = hypot(r1.x - r2.x, r1.y - r2.y) < 0.14
                if r1.partner == r2.id {
                    // Partner zeigen sich ab und zu ihre Zuneigung
                    if near, Double.random(in: 0...1) < 0.15 {
                        let p = screen((r1.x + r2.x) / 2, (r1.y + r2.y) / 2)
                        burst(.heart, at: CGPoint(x: p.x, y: p.y - 40), count: 1, color: .pink)
                    }
                    continue
                }
                guard r1.partner == nil, r2.partner == nil, near else { continue }
                let key = Self.bondKey(r1.id, r2.id)
                let value = (bonds[key] ?? 0) + elapsed * 0.08 * (r1.personality == .schuechtern || r2.personality == .schuechtern ? 0.7 : 1)
                bonds[key] = value
                if value >= 100, let i1 = index(of: r1.id), let i2 = index(of: r2.id) {
                    save.rabbits[i1].partner = r2.id
                    save.rabbits[i2].partner = r1.id
                    // Wer behalten wird, nimmt den Partner mit – oder beide gehen in die Vermittlung.
                    if r1.isKept != r2.isKept {
                        if keptRabbits.count < keepCapacity { save.rabbits[i1].kept = true; save.rabbits[i2].kept = true }
                        else { save.rabbits[i1].kept = nil; save.rabbits[i2].kept = nil }
                    }
                    bonds[key] = nil
                    let p = screen((r1.x + r2.x) / 2, (r1.y + r2.y) / 2)
                    burst(.heart, at: CGPoint(x: p.x, y: p.y - 40), count: 12, color: .pink)
                    showBanner("\(r1.name) und \(r2.name) sind jetzt unzertrennlich 💞 – sie werden nur zusammen vermittelt",
                               symbol: "heart.circle.fill", duration: 6)
                    notify.notificationOccurred(.success)
                    gainXP(15)
                }
            }
        }
        // verwaiste Einträge aufräumen
        let ids = Set(list.map(\.id.uuidString))
        save.bonds = bonds.filter { k, _ in k.split(separator: "|").allSatisfy { ids.contains(String($0)) } }
        // Partner, deren Gegenstück nicht mehr da ist, wieder lösen
        for i in save.rabbits.indices where save.rabbits[i].partner != nil {
            if !save.rabbits.contains(where: { $0.id == save.rabbits[i].partner }) { save.rabbits[i].partner = nil }
        }
    }

    func stationTick(elapsed: Double) {
        refreshQuestsIfNeeded()
        updateBonds(elapsed: elapsed)
        updateSocial(elapsed: elapsed)
        updateAdopters()
    }
}
