import SwiftUI

/// Fortschritt: Garten-Level, tägliche Aufträge, Sammelbuch und Vermitteln.
///
/// Der Kreislauf:
/// Pflegen → Erfahrung → Level → seltenere Gäste, neue Deko und Zuhause
/// → mehr Gemütlichkeit → noch seltenere Gäste → Sammelbuch füllen → Vermitteln schafft Platz.
/// Level steigen ohne Obergrenze; jedes Level braucht etwas mehr Erfahrung.
enum Progression {
    /// Erfahrung von Level n zu n + 1.
    static func xpNeeded(forLevel n: Int) -> Int { Int(60 * pow(Double(max(n, 1)), 1.4)) }

    /// Sterne als Belohnung beim Erreichen von Level n.
    static func levelReward(_ n: Int) -> Int { 15 + n * 5 }

    /// Seltenste Stufe, die auf diesem Level zu Besuch kommen kann.
    static func maxRarity(level: Int) -> Rarity {
        switch level {
        case ..<3: .selten
        case ..<6: .superSelten
        default: .legendaer
        }
    }

    /// Was auf einem Level neu dazukommt (für die Level-Meldung und die Übersicht).
    static func unlocks(at level: Int) -> [String] {
        var list: [String] = []
        if level == 3 { list.append("Super seltene Gäste") }
        if level == 6 { list.append("Legendäre Gäste") }
        for kind in DecorKind.allCases where kind.unlockLevel == level { list.append(kind.title) }
        for home in HomeStyle.allCases where home.unlockLevel == level && level > 1 { list.append(home.title) }
        return list
    }

    /// Nächstes Level mit einer Freischaltung (für „Als Nächstes“).
    static func nextUnlock(after level: Int) -> (level: Int, items: [String])? {
        for l in (level + 1)...(level + 20) {
            let items = unlocks(at: l)
            if !items.isEmpty { return (l, items) }
        }
        return nil
    }

    // MARK: Sammelbuch

    static func comboKey(_ look: RabbitLook) -> String { "\(look.fur.rawValue)-\(look.pattern.rawValue)-\(look.breed.rawValue)" }

    /// Meilensteine: Anzahl entdeckter Kombinationen → Belohnung.
    static let milestones = [3, 6, 10, 15, 20, 30, 40, 50, 65, 80, 100, 125, 150, 200, 250, 300, 400, 500]
    static func milestoneReward(_ m: Int) -> (stars: Int, xp: Int) { (20 + m * 2, 15 + m) }

    // MARK: Vermitteln

    /// Sterne fürs Vermitteln – seltene und gut befreundete Kaninchen bringen mehr.
    static func adoptionReward(_ r: GardenRabbit) -> Int {
        let base = [25, 60, 140, 350][r.rarity.rawValue]
        return base + Int(r.friendship / 2)
    }
}

extension DecorKind {
    var unlockLevel: Int {
        switch self {
        case .stein, .busch: 1
        case .pilz, .sonnenblumen, .heuraufe: 2
        case .blumenbeet, .gartenzwerg: 3
        case .baumstamm, .laterne: 4
        case .tunnel: 5
        case .teich: 7
        case .feenring: 10
        }
    }
}

extension HomeStyle {
    var unlockLevel: Int {
        switch self {
        case .holzstall: 1
        case .cottage: 3
        case .pilzhaus: 6
        case .schloss: 10
        }
    }
}

extension Rarity {
    /// Seltenheit nach Merkmalen (für das Sammelbuch).
    static func of(_ look: RabbitLook) -> Rarity {
        if GardenFur.legendary.contains(look.fur) { return .legendaer }
        if GardenFur.superRare.contains(look.fur) || [.russe, .japaner, .thueringer].contains(look.pattern)
            || [.hermelin, .angora, .riese].contains(look.breed) { return .superSelten }
        if GardenFur.uncommon.contains(look.fur) || [.hollaender, .schecke, .loh].contains(look.pattern)
            || [.loewenkopf, .rex].contains(look.breed) { return .selten }
        return .gewoehnlich
    }
}

// MARK: - Aufträge

/// Was im Spiel passiert – Aufträge zählen mit.
enum QuestEvent {
    case futtern(GardenFoodKind)
    case streicheln
    case maehen
    case giessen
    case ernten
    case pfluecken
    case zaehmen(Rarity)
    case wunsch
    case deko
    case vermitteln
    case foto(Int)
    case posten
    case buersten
}

enum QuestGoal: Codable, Hashable {
    case futtern(GardenFoodKind?)
    case streicheln
    case maehen
    case giessen
    case ernten
    case pfluecken
    case zaehmen(Rarity)
    case wunsch
    case deko
    case vermitteln
    /// Foto mit mindestens so vielen Sternen
    case foto(Int)
    case posten
    case buersten

    func matches(_ e: QuestEvent) -> Bool {
        switch (self, e) {
        case (.futtern(let want), .futtern(let got)): return want == nil || want == got
        case (.streicheln, .streicheln), (.maehen, .maehen), (.giessen, .giessen), (.ernten, .ernten),
             (.pfluecken, .pfluecken), (.wunsch, .wunsch), (.deko, .deko), (.vermitteln, .vermitteln): return true
        case (.zaehmen(let min), .zaehmen(let got)): return got >= min
        case (.foto(let min), .foto(let got)): return got >= min
        case (.posten, .posten), (.buersten, .buersten): return true
        default: return false
        }
    }

    func text(_ n: Int) -> String {
        switch self {
        case .futtern(nil): "Lege \(n)× Futter aus"
        case .futtern(.some(let k)): "Füttere \(n)× \(k.title)"
        case .streicheln: "Verteile \(n) Streichel-Herzen"
        case .maehen: "Mähe \(n) Rasenfelder"
        case .giessen: "Gieße \(n) Rasenfelder"
        case .ernten: "Ernte \(n) Möhren"
        case .pfluecken: "Pflücke \(n) Blumen"
        case .zaehmen(let r): r == .gewoehnlich ? (n == 1 ? "Gewinne das Vertrauen eines Fundtiers" : "Gewinne das Vertrauen von \(n) Fundtieren")
            : "Gewinne das Vertrauen eines \(r.title.lowercased())en Fundtiers"
        case .wunsch: n == 1 ? "Erfülle einem Fundtier seinen Wunsch" : "Erfülle \(n) Wünsche"
        case .deko: "Stelle \(n) Deko auf"
        case .vermitteln: "Vermittle ein Kaninchen"
        case .foto(let stars): n == 1 ? "Mache ein Foto mit \(stars) Sternen oder mehr" : "Mache \(n) Fotos mit \(stars)+ Sternen"
        case .posten: n == 1 ? "Poste ein Foto auf Hoppelgram" : "Poste \(n) Fotos auf Hoppelgram"
        case .buersten: "Bürste \(n)× ein Kaninchen"
        }
    }

    var symbol: String {
        switch self {
        case .futtern(let k): k?.symbol ?? "fork.knife"
        case .streicheln: "hand.raised.fill"
        case .maehen: "scissors"
        case .giessen: "drop.fill"
        case .ernten: "carrot.fill"
        case .pfluecken: "camera.macro"
        case .zaehmen(let r): r.symbol
        case .wunsch: "gift.fill"
        case .deko: "paintbrush.fill"
        case .vermitteln: "house.and.flag.fill"
        case .foto: "camera.fill"
        case .posten: "photo.on.rectangle.angled"
        case .buersten: "comb.fill"
        }
    }
}

struct GardenQuest: Codable, Identifiable, Hashable {
    var id = UUID()
    var goal: QuestGoal
    var target: Int
    var progress = 0
    var stars: Int
    var xp: Int
    var bonusFood: GardenFoodKind?
    var bonusAmount = 0
    var claimed = false

    var done: Bool { progress >= target }
    var text: String { goal.text(target) }

    /// Drei Aufträge für heute – passend zu Level, Jahreszeit und Wiese.
    static func daily(level: Int, season: Season, residents: Int, decorOwned: Bool) -> [GardenQuest] {
        let scale = 1 + Double(level) * 0.12
        func n(_ base: Double) -> Int { max(1, Int((base * scale).rounded())) }
        var pool: [(QuestGoal, Int, Int)] = [   // Ziel, Menge, Grund-Sterne
            (.futtern(nil), n(4), 12),
            (.streicheln, n(10), 12),
            (.buersten, n(8), 12),
            (.maehen, n(20), 10),
            (.giessen, n(15), 8),
            (.zaehmen(.gewoehnlich), 1, 25),
        ]
        if season != .winter {
            pool.append((.pfluecken, n(3), 10))
            pool.append((.futtern(.loewenzahn), n(2), 14))
            pool.append((.ernten, n(2), 14))
        } else {
            pool.append((.futtern(.zweige), n(2), 14))
            pool.append((.futtern(.heu), n(4), 12))
        }
        if residents > 0 { pool.append((.futtern(.moehre), n(1), 15)) }
        if level >= 3 { pool.append((.wunsch, 1, 30)) }
        if level >= 4 { pool.append((.zaehmen(.selten), 1, 45)) }
        if decorOwned { pool.append((.deko, 1, 10)) }
        if residents > 0 {
            pool.append((.foto(level >= 4 ? 4 : 3), 1, 15))
            pool.append((.posten, level >= 5 ? 2 : 1, 15))
        }
        if level >= 2, residents >= 2 { pool.append((.vermitteln, 1, 30)) }

        var picked: [GardenQuest] = []
        var used = Set<String>()
        for entry in pool.shuffled() where picked.count < 3 {
            let key = "\(entry.0)".components(separatedBy: "(").first ?? ""
            guard !used.contains(key) else { continue }
            used.insert(key)
            var q = GardenQuest(goal: entry.0, target: entry.1, stars: Int(Double(entry.2) * scale), xp: 20 + level * 4)
            if Double.random(in: 0...1) < 0.35 {
                q.bonusFood = season == .winter ? [.heu, .zweige].randomElement()! : [.moehre, .heu, .loewenzahn].randomElement()!
                q.bonusAmount = q.bonusFood == .heu ? 8 : 2
            }
            picked.append(q)
        }
        return picked
    }
}

// MARK: - Vermittlung an super Menschen

/// Was Interessenten sich wünschen.
enum AdopterWish: Codable, Hashable {
    case wesen(GardenPersonality)
    case rasse(GardenBreed)
    case fell(GardenFur)
    case zeichnung(GardenPattern)
    case klein
    case gross
    case schlappohren
    case sehrZutraulich

    var text: String {
        switch self {
        case .wesen(let p): p.title
        case .rasse(let b): b.title
        case .fell(let f): f.title
        case .zeichnung(let p): p.title
        case .klein: "klein"
        case .gross: "groß"
        case .schlappohren: "Schlappohren"
        case .sehrZutraulich: "sehr zutraulich"
        }
    }

    func fits(_ r: GardenRabbit) -> Bool {
        switch self {
        case .wesen(let p): r.personality == p
        case .rasse(let b): r.look.breed == b
        case .fell(let f): r.look.fur == f
        case .zeichnung(let p): r.look.pattern == p
        case .klein: r.look.breed.bodyScale < 0.95
        case .gross: r.look.breed.bodyScale > 1.04
        case .schlappohren: r.look.breed == .widder
        case .sehrZutraulich: r.friendship >= 80
        }
    }

    /// Ein Wunsch, den dieses Kaninchen erfüllt (damit Anfragen auch lösbar sind).
    static func matching(_ r: GardenRabbit) -> AdopterWish {
        var options: [AdopterWish] = [.wesen(r.personality), .rasse(r.look.breed), .fell(r.look.fur)]
        if r.look.pattern != .einfarbig { options.append(.zeichnung(r.look.pattern)) }
        if r.look.breed.bodyScale < 0.95 { options.append(.klein) }
        if r.look.breed.bodyScale > 1.04 { options.append(.gross) }
        if r.look.breed == .widder { options.append(.schlappohren) }
        return options.randomElement()!
    }

    static func random() -> AdopterWish {
        switch Int.random(in: 0..<7) {
        case 0: .wesen(GardenPersonality.allCases.randomElement()!)
        case 1: .rasse([.stehohr, .widder, .zwerg, .loewenkopf, .rex].randomElement()!)
        case 2: .fell(GardenFur.common.randomElement()!)
        case 3: .klein
        case 4: .gross
        case 5: .schlappohren
        default: .sehrZutraulich
        }
    }
}

/// Eine Anfrage von Menschen, die Kaninchen ein gutes Zuhause geben wollen.
struct Adopter: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var symbol: String
    var story: String
    var wishes: [AdopterWish]
    /// Wie viele Kaninchen (Kaninchen sollen nicht allein leben – viele nehmen zwei).
    var count: Int
    var stars: Int
    var xp: Int
    var expires: Date
    /// Über welchen Post die Anfrage kam
    var viaPost: String?

    /// Passt dieses Kaninchen? Bei zwei Kaninchen muss jeder Wunsch von mindestens einem erfüllt werden.
    func fits(_ rabbits: [GardenRabbit]) -> Bool {
        guard rabbits.count == count else { return false }
        return wishes.allSatisfy { w in rabbits.contains { w.fits($0) } }
    }

    private static let people: [(String, String, String)] = [
        ("Familie Berger", "figure.2.and.child.holdinghands", "Großer Garten mit sicherem Freigehege – die Kinder freuen sich riesig."),
        ("Oma Gerda", "figure.seated.side", "Seit ihr Mümmel gestorben ist, fehlt ihr jemand zum Kuscheln."),
        ("Lena & Tom", "figure.2", "Frisch zusammengezogen, mit einem ganzen Zimmer nur für Kaninchen."),
        ("Herr Yilmaz", "figure.stand", "Hat einen Schrebergarten mit Stall und viel Zeit."),
        ("Familie Nguyen", "figure.2.and.child.holdinghands", "Hat schon ein Kaninchen, das dringend Gesellschaft braucht."),
        ("Frau Albers", "figure.walk", "Tierärztin im Ruhestand – kennt sich bestens aus."),
        ("WG Sonnenhof", "person.3.fill", "Fünf Leute, ein großer Innenhof und ganz viel Liebe."),
        ("Pia (12) & Papa", "figure.and.child.holdinghands", "Pia hat lange gespart und alles über Kaninchen gelesen."),
        ("Herr und Frau Kaya", "figure.2", "Haben ein Haus am Feldrand und einen begehbaren Stall gebaut."),
        ("Jonas", "figure.wave", "Arbeitet von zu Hause und baut gerade ein Gehege mit Tunneln."),
        ("Familie Schröder", "figure.2.and.child.holdinghands", "Haben ein altes Bauernhaus mit riesiger Wiese."),
        ("Ida & Mo", "figure.2", "Wollen ein ruhiges Pärchen für ihre Dachterrasse mit Rasen."),
        ("Kindergarten Pusteblume", "building.2.fill", "Sucht Kaninchen für den Garten – mit festen Pflegezeiten."),
        ("Frau Petrović", "figure.stand.dress", "Hatte früher selbst eine Auffangstation."),
    ]

    /// Neue Anfrage. Meist passt sie zu einem Schützling, der gerade da ist – so bleibt alles lösbar.
    static func random(level: Int, residents: [GardenRabbit], taken: Set<String>, via: GardenRabbit? = nil) -> Adopter {
        let person = people.filter { !taken.contains($0.0) }.randomElement() ?? people.randomElement()!
        // Partner gibt es nur zu zweit – sonst nehmen viele ohnehin zwei.
        let count = via?.partner != nil ? 2 : (Double.random(in: 0...1) < 0.45 && residents.count >= 2 ? 2 : 1)
        var wishes: [AdopterWish] = []
        if let base = via ?? residents.randomElement(), via != nil || Double.random(in: 0...1) < 0.7 {
            wishes.append(AdopterWish.matching(base))
            if level >= 4, Double.random(in: 0...1) < 0.4, let other = residents.randomElement() {
                let w = AdopterWish.matching(other)
                if !wishes.contains(w) { wishes.append(w) }
            }
        } else {
            wishes.append(AdopterWish.random())
        }
        if level >= 6, Double.random(in: 0...1) < 0.25 { wishes.append(.sehrZutraulich) }
        let stars = (30 + level * 6) * count + wishes.count * 10
        return Adopter(name: person.0, symbol: person.1, story: person.2, wishes: wishes, count: count,
                       stars: stars, xp: 40 + level * 8 + (count - 1) * 30,
                       expires: Date.now.addingTimeInterval(.random(in: 8 * 3600...30 * 3600)), viaPost: via?.name)
    }
}

/// Erinnerung an einen vermittelten Schützling (mit Postkarte).
struct AdoptionRecord: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var look: RabbitLook
    var rarity: Rarity
    var family: String
    var date: Date
    var postcard: String

    static func postcard(name: String, family: String) -> String {
        [
            "\(name) hat das ganze Wohnzimmer erobert und schläft am liebsten auf dem Sofa. Liebe Grüße, \(family)",
            "Jeden Morgen macht \(name) Luftsprünge, sobald wir das Gehege öffnen. Danke für alles! \(family)",
            "\(name) hat schon einen Lieblingsplatz unter dem Apfelbaum gefunden. \(family)",
            "Die Kinder lesen \(name) abends vor – \(name) schläft dabei immer ein. Herzlich, \(family)",
            "\(name) und unser anderes Kaninchen sind unzertrennlich geworden! \(family)",
            "\(name) frisst uns die Petersilie weg – und wir lieben es. \(family)",
            "Gestern hat \(name) zum ersten Mal auf dem Schoß geschlafen. 💛 \(family)",
        ].randomElement()!
    }
}

// MARK: - Hoppelgram

/// Ein Foto auf dem Profil der Station.
struct SocialPost: Codable, Identifiable, Hashable {
    var id = UUID()
    var rabbitID: UUID
    var rabbitName: String
    /// Dateiname im Ordner „Fotos“
    var photo: String
    /// 0…100
    var score: Int
    var caption: String
    var created: Date = .now
    var likes: Int = 0
    var targetLikes: Int
    var comments: [String] = []
    var adopted = false

    var stars: Int { max(1, min(5, Int((Double(score) / 20).rounded(.up)))) }

    static let captions = [
        "Darf ich vorstellen: %@! Sucht ein Zuhause für immer 💛",
        "%@ hat heute Luftsprünge geübt 🐇✨",
        "Wer verliebt sich in %@? Vermittlung über unsere Station.",
        "%@ ist aufgepäppelt und bereit für tolle Menschen!",
        "Sonntagsstimmung mit %@ 🌼",
    ]

    static let commentPool = [
        "So süß! 😍", "Ist %@ noch zu haben?", "Diese Ohren!! 🥺", "Teilen, damit %@ schnell ein Zuhause findet!",
        "Was für ein schönes Fell ✨", "Wir haben schon ein Kaninchen – passt %@ dazu?", "Ihr macht so tolle Arbeit 💛",
        "Ich schmelze dahin 🫠", "Hoffentlich findet %@ bald eine Familie!", "Das Foto ist der Hammer 📸",
    ]
}

/// Ergebnis eines Fotos (wird als Polaroid gezeigt).
struct PhotoResult: Identifiable {
    let id = UUID()
    let rabbitID: UUID
    let name: String
    let image: UIImage
    let score: Int
    let notes: [String]
    var stars: Int { max(1, min(5, Int((Double(score) / 20).rounded(.up)))) }
}
