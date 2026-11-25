import SwiftUI

// MARK: - Seltenheit

enum Rarity: Int, Codable, CaseIterable, Comparable, Identifiable {
    case gewoehnlich, selten, superSelten, legendaer
    var id: Int { rawValue }

    static func < (a: Rarity, b: Rarity) -> Bool { a.rawValue < b.rawValue }

    var title: String {
        switch self {
        case .gewoehnlich: "Gewöhnlich"
        case .selten: "Selten"
        case .superSelten: "Super selten"
        case .legendaer: "Legendär"
        }
    }

    var color: Color {
        switch self {
        case .gewoehnlich: Color(hex: 0x7FA36E)
        case .selten: Color(hex: 0x3F8FE0)
        case .superSelten: Color(hex: 0xA05BE0)
        case .legendaer: Color(hex: 0xF0A92E)
        }
    }

    var symbol: String {
        switch self {
        case .gewoehnlich: "leaf.fill"
        case .selten: "diamond.fill"
        case .superSelten: "star.fill"
        case .legendaer: "crown.fill"
        }
    }

    /// Sterne, wenn ein Gast dieser Stufe einzieht.
    var reward: Int { [10, 25, 60, 150][rawValue] }
    /// Sterne, die ein glückliches Kaninchen dieser Stufe regelmäßig bringt.
    var income: Int { [1, 2, 3, 5][rawValue] }
    /// Wie leicht ein Gast Vertrauen fasst.
    var trustFactor: Double { [1, 0.8, 0.6, 0.42][rawValue] }
    /// So lange bleibt ein Gast (Sekunden) – Besuch ist selten, also bleibt er eine Weile.
    var stay: ClosedRange<Double> { [300...420, 280...400, 240...340, 210...300][rawValue] }
    /// Wie wahrscheinlich ein Gast dieser Stufe einen Wunsch hat.
    var wishChance: Double { [0.3, 0.75, 1, 1][rawValue] }

    /// Wahrscheinlichkeiten je Stufe – mehr Gemütlichkeit und Glücksklee helfen.
    static func odds(cozy: Int, lucky: Bool) -> [Double] {
        let c = Double(cozy)
        let legend = min(0.06, 0.012 + c * 0.0004) + (lucky ? 0.15 : 0)
        let superRare = min(0.16, 0.05 + c * 0.001) + (lucky ? 0.2 : 0)
        let rare = min(0.36, 0.2 + c * 0.0015)
        return [max(0, 1 - legend - superRare - rare), rare, superRare, legend]
    }

    static func roll(cozy: Int, lucky: Bool) -> Rarity {
        let o = odds(cozy: cozy, lucky: lucky)
        var x = Double.random(in: 0..<1)
        for (i, p) in o.enumerated().reversed() where i > 0 {
            if x < p { return Rarity(rawValue: i)! }
            x -= p
        }
        return .gewoehnlich
    }
}

// MARK: - Aussehen

/// Fellfarbe: Grundton, Schatten und Bauch.
enum GardenFur: String, Codable, CaseIterable {
    case weiss, creme, wildfarben, grau, schwarz, schoko, rot, sand
    case silber, lila
    case gold, mond, kirsch, nacht

    var title: String {
        switch self {
        case .weiss: "Weiß"
        case .creme: "Creme"
        case .wildfarben: "Wildfarben"
        case .grau: "Blaugrau"
        case .schwarz: "Schwarz"
        case .schoko: "Schoko"
        case .rot: "Rotbraun"
        case .sand: "Sandfarben"
        case .silber: "Silberfuchs"
        case .lila: "Flieder"
        case .gold: "Sternenstaub"
        case .mond: "Mondschein"
        case .kirsch: "Kirschblüte"
        case .nacht: "Nachthimmel"
        }
    }

    var main: Color {
        switch self {
        case .weiss: Color(hex: 0xF6F2EB)
        case .creme: Color(hex: 0xEFD9B6)
        case .wildfarben: Color(hex: 0x9C7653)
        case .grau: Color(hex: 0x98A0AA)
        case .schwarz: Color(hex: 0x3B3634)
        case .schoko: Color(hex: 0x6C4532)
        case .rot: Color(hex: 0xD3854A)
        case .sand: Color(hex: 0xCDA77D)
        case .silber: Color(hex: 0xC5CBD3)
        case .lila: Color(hex: 0xB8A3C6)
        case .gold: Color(hex: 0xF2C14E)
        case .mond: Color(hex: 0xDDE9F8)
        case .kirsch: Color(hex: 0xF7C3D4)
        case .nacht: Color(hex: 0x2E3A6E)
        }
    }

    var shade: Color {
        switch self {
        case .weiss: Color(hex: 0xD8CFC2)
        case .creme: Color(hex: 0xCFB38A)
        case .wildfarben: Color(hex: 0x6E5139)
        case .grau: Color(hex: 0x6E7680)
        case .schwarz: Color(hex: 0x1E1B1A)
        case .schoko: Color(hex: 0x4A2E21)
        case .rot: Color(hex: 0xA95F2E)
        case .sand: Color(hex: 0xA8845C)
        case .silber: Color(hex: 0x8F97A3)
        case .lila: Color(hex: 0x8A759B)
        case .gold: Color(hex: 0xD3962A)
        case .mond: Color(hex: 0xA6BEDF)
        case .kirsch: Color(hex: 0xD98EA9)
        case .nacht: Color(hex: 0x1A2149)
        }
    }

    var belly: Color {
        switch self {
        case .schwarz, .schoko: Color(hex: 0x5A4A42)
        case .gold: Color(hex: 0xFFF1C4)
        case .nacht: Color(hex: 0x4A5A9A)
        case .kirsch: Color(hex: 0xFFF0F4)
        default: Color(hex: 0xFBF5EA)
        }
    }

    static let common: [GardenFur] = [.weiss, .creme, .wildfarben, .grau, .schwarz]
    static let uncommon: [GardenFur] = [.schoko, .rot, .sand]
    static let superRare: [GardenFur] = [.silber, .lila]
    static let legendary: [GardenFur] = [.gold, .mond, .kirsch, .nacht]

    /// Leuchtende Fellfarben (legendär) mit eigenen Effekten.
    var isMagic: Bool { GardenFur.legendary.contains(self) }
}

enum GardenPattern: String, Codable, CaseIterable {
    case einfarbig, blesse, hollaender, schecke, loh, russe, japaner, thueringer

    var title: String {
        switch self {
        case .einfarbig: "Einfarbig"
        case .hollaender: "Holländer"
        case .schecke: "Schecke"
        case .blesse: "Blesse"
        case .loh: "Loh"
        case .russe: "Russe"
        case .japaner: "Japaner"
        case .thueringer: "Thüringer"
        }
    }
}

enum GardenBreed: String, Codable, CaseIterable {
    case stehohr, widder, zwerg, hermelin, rex, loewenkopf, angora, riese

    var title: String {
        switch self {
        case .stehohr: "Stehohr"
        case .widder: "Widder"
        case .loewenkopf: "Löwenkopf"
        case .zwerg: "Zwerg"
        case .hermelin: "Hermelin"
        case .rex: "Rex"
        case .angora: "Angora"
        case .riese: "Deutscher Riese"
        }
    }

    /// Gesamtgröße – Merkmale sollen auf den ersten Blick erkennbar sein.
    var bodyScale: CGFloat {
        switch self {
        case .hermelin: 0.62
        case .zwerg: 0.74
        case .loewenkopf: 0.9
        case .widder: 1.05
        case .angora: 1.08
        case .riese: 1.5
        default: 1
        }
    }

    /// Kopf im Verhältnis zum Körper (Zwerge haben runde, große Köpfe).
    var headScale: CGFloat {
        switch self {
        case .hermelin: 1.3
        case .zwerg: 1.22
        case .loewenkopf: 1.08
        case .riese: 0.94
        default: 1
        }
    }

    /// Körper gestaucht (rund) oder gestreckt (lang).
    var bodyLength: CGFloat {
        switch self {
        case .hermelin: 0.84
        case .zwerg: 0.88
        case .riese: 1.1
        case .rex: 1.03
        default: 1
        }
    }

    var earLength: CGFloat {
        switch self {
        case .hermelin: 13
        case .zwerg: 19
        case .loewenkopf: 22
        case .angora: 25
        case .widder: 30
        case .riese: 38
        default: 29
        }
    }

    var detail: String {
        switch self {
        case .stehohr: "Klassisches Kaninchen mit aufrechten Ohren."
        case .widder: "Lange Schlappohren, die seitlich hängen."
        case .zwerg: "Klein, rund, große Augen und kurze Ohren."
        case .hermelin: "Winzig, schneeweiß, ganz kurze Ohren."
        case .rex: "Samtig kurzes Fell, gewellte Schnurrhaare."
        case .loewenkopf: "Wilde Mähne rund um den Kopf."
        case .angora: "Lange, wolkige Wolle am ganzen Körper."
        case .riese: "Riesig, gemütlich und tiefenentspannt."
        }
    }
}

enum GardenPersonality: String, Codable, CaseIterable {
    case verfressen, verschmust, verspielt, schuechtern, verschlafen, neugierig

    var title: String {
        switch self {
        case .verfressen: "verfressen"
        case .verschmust: "verschmust"
        case .verspielt: "verspielt"
        case .schuechtern: "schüchtern"
        case .verschlafen: "verschlafen"
        case .neugierig: "neugierig"
        }
    }

    var hint: String {
        switch self {
        case .verfressen: "Denkt eigentlich nur an Futter."
        case .verschmust: "Liebt Streicheleinheiten über alles."
        case .verspielt: "Macht ständig Luftsprünge."
        case .schuechtern: "Braucht etwas Geduld."
        case .verschlafen: "Hält gern ein Nickerchen."
        case .neugierig: "Kommt nachsehen, wo du tippst."
        }
    }
}

/// Alles, was man an einem Kaninchen sieht.
struct RabbitLook: Codable, Hashable {
    var fur: GardenFur
    var pattern: GardenPattern
    var breed: GardenBreed
    /// Zweitfarbe für Schecken, Russen und Holländer.
    var accent: GardenFur

    static func random(_ rarity: Rarity) -> RabbitLook {
        let accent: GardenFur = [.schwarz, .schoko, .grau, .wildfarben, .rot].randomElement()!
        var fur: GardenFur
        var pattern: GardenPattern
        var breed: GardenBreed
        switch rarity {
        case .gewoehnlich:
            fur = GardenFur.common.randomElement()!
            pattern = [.einfarbig, .einfarbig, .blesse].randomElement()!
            breed = [.stehohr, .stehohr, .widder, .zwerg].randomElement()!
        case .selten:
            fur = (GardenFur.common + GardenFur.uncommon + GardenFur.uncommon).randomElement()!
            pattern = [.einfarbig, .blesse, .hollaender, .schecke, .loh].randomElement()!
            breed = [.stehohr, .widder, .zwerg, .loewenkopf, .rex].randomElement()!
            // mindestens ein besonderes Merkmal
            if !GardenFur.uncommon.contains(fur) && ![.hollaender, .schecke, .loh].contains(pattern)
                && ![.loewenkopf, .rex].contains(breed) {
                pattern = [.hollaender, .schecke, .loh].randomElement()!
            }
        case .superSelten:
            fur = (GardenFur.superRare + GardenFur.superRare + GardenFur.uncommon + GardenFur.common).randomElement()!
            pattern = [.einfarbig, .hollaender, .schecke, .russe, .japaner, .thueringer].randomElement()!
            breed = [.hermelin, .angora, .riese, .loewenkopf, .widder, .zwerg].randomElement()!
            if !GardenFur.superRare.contains(fur) && ![.russe, .japaner, .thueringer].contains(pattern)
                && ![.hermelin, .angora, .riese].contains(breed) {
                breed = [.hermelin, .angora, .riese].randomElement()!
            }
        case .legendaer:
            fur = GardenFur.legendary.randomElement()!
            pattern = [.einfarbig, .einfarbig, .blesse].randomElement()!
            breed = GardenBreed.allCases.randomElement()!
        }
        // Rassetypische Farben
        if rarity != .legendaer {
            switch pattern {
            case .russe: fur = .weiss
            case .thueringer: fur = .sand
            case .loh: fur = [.schwarz, .schoko, .grau, .lila].randomElement()!
            case .japaner: fur = [.schwarz, .schoko, .grau].randomElement()!
            default: break
            }
            if breed == .hermelin { fur = .weiss; pattern = .einfarbig }
        }
        return RabbitLook(fur: fur, pattern: pattern, breed: breed, accent: fur == accent ? .schwarz : accent)
    }

    var description: String {
        pattern == .einfarbig ? "\(breed.title) · \(fur.title)" : "\(breed.title) · \(pattern.title) · \(fur.title)"
    }
}

// MARK: - Jahreszeiten

enum Season: String, CaseIterable {
    case fruehling, sommer, herbst, winter

    static var current: Season {
        if GardenDemo.isActive, GardenDemo.screen == "winter" { return .winter }
        switch Calendar.current.component(.month, from: .now) {
        case 3...5: return .fruehling
        case 6...8: return .sommer
        case 9...11: return .herbst
        default: return .winter
        }
    }

    var title: String {
        switch self {
        case .fruehling: "Frühling"
        case .sommer: "Sommer"
        case .herbst: "Herbst"
        case .winter: "Winter"
        }
    }

    var symbol: String {
        switch self {
        case .fruehling: "camera.macro"
        case .sommer: "sun.max.fill"
        case .herbst: "leaf.fill"
        case .winter: "snowflake"
        }
    }

    private var index: Int { Season.allCases.firstIndex(of: self)! }
    /// Wie schnell das Gras wächst.
    var growth: Double { [1.3, 1, 0.65, 0.2][index] }
    /// Wie oft Blumen sprießen (0 = gar nicht).
    var flowers: Double { [1.5, 1, 0.5, 0][index] }
    /// Wie schnell Hunger wächst.
    var appetite: Double { [1, 1, 1.1, 1.35][index] }
}

// MARK: - Wünsche

/// Besondere Gäste wollen etwas, bevor sie einziehen.
enum VisitorWish: Codable, Hashable {
    case futter(GardenFoodKind)
    case deko(DecorKind)
    case streicheln
    case kurzerRasen

    var text: String {
        switch self {
        case .futter(.heu): "Möchte frisches Heu"
        case .futter(.loewenzahn): "Hätte gern Löwenzahn"
        case .futter(.moehre): "Wünscht sich eine Möhre"
        case .futter(.zweige): "Möchte an Apfelzweigen knabbern"
        case .deko(let kind): "Sucht auf der Wiese: \(kind.title)"
        case .streicheln: "Will ausgiebig gestreichelt werden"
        case .kurzerRasen: "Mag nur frisch gemähten Rasen"
        }
    }

    var hint: String {
        switch self {
        case .futter(.zweige): "Apfelzweige gibt es im Shop."
        case .futter(let kind): "Leg \(kind.title) in seine Nähe."
        case .deko(let kind): "Stell \(kind.title) auf (Shop → Gestalten)."
        case .streicheln: "Streichle es mit der Hand, bis die Herzen voll sind."
        case .kurzerRasen: "Mäh den Rasen rund um den Gast."
        }
    }

    var symbol: String {
        switch self {
        case .futter(let kind): kind.symbol
        case .deko(let kind): kind.symbol
        case .streicheln: "hand.raised.fill"
        case .kurzerRasen: "scissors"
        }
    }

    static func random(for rarity: Rarity, season: Season = .current) -> VisitorWish {
        // Im Winter gibt es kein frisches Grün – Gäste wünschen sich dann oft Zweige oder Heu.
        if season == .winter, Double.random(in: 0...1) < 0.5 {
            return [.futter(.zweige), .futter(.heu), .futter(.zweige)].randomElement()!
        }
        switch rarity {
        case .gewoehnlich:
            return [.futter(.loewenzahn), .futter(.heu), .streicheln, .kurzerRasen].randomElement()!
        case .selten:
            return [.futter(.loewenzahn), .futter(.moehre), .streicheln, .kurzerRasen,
                    .deko(.stein), .deko(.busch), .deko(.blumenbeet), .deko(.sonnenblumen), .deko(.pilz)].randomElement()!
        case .superSelten:
            return [.futter(.moehre), .streicheln, .deko(.tunnel), .deko(.laterne), .deko(.baumstamm),
                    .deko(.gartenzwerg), .deko(.heuraufe)].randomElement()!
        case .legendaer:
            return [.deko(.teich), .deko(.feenring), .deko(.tunnel), .futter(.moehre)].randomElement()!
        }
    }
}

// MARK: - Deko & Zuhause

enum DecorKind: String, Codable, CaseIterable, Identifiable {
    case stein, busch, pilz, sonnenblumen, blumenbeet, gartenzwerg, baumstamm, laterne, tunnel, heuraufe, teich, feenring
    var id: String { rawValue }

    var title: String {
        switch self {
        case .stein: "Findling"
        case .busch: "Busch"
        case .pilz: "Fliegenpilz"
        case .sonnenblumen: "Sonnenblumen"
        case .blumenbeet: "Blumenbeet"
        case .gartenzwerg: "Gartenzwerg"
        case .baumstamm: "Baumstamm"
        case .laterne: "Laterne"
        case .tunnel: "Weidentunnel"
        case .heuraufe: "Heuraufe"
        case .teich: "Teich"
        case .feenring: "Feenring"
        }
    }

    var detail: String {
        switch self {
        case .stein: "Warm in der Sonne – ein Lieblingsplatz."
        case .busch: "Versteck und Schattenspender."
        case .pilz: "Sieht giftig aus, ist aber nur Deko."
        case .sonnenblumen: "Bringt Sommer auf die Wiese."
        case .blumenbeet: "Bunt und duftend."
        case .gartenzwerg: "Bewacht die Möhren. Angeblich."
        case .baumstamm: "Zum Draufhüpfen und Ausruhen."
        case .laterne: "Leuchtet nachts warm."
        case .tunnel: "Kaninchen flitzen hinein und wieder heraus."
        case .heuraufe: "Füttert hungrige Kaninchen automatisch mit deinem Heu."
        case .teich: "Zum Trinken und Verweilen – sehr gemütlich."
        case .feenring: "Uralter Pilzkreis. Lockt Legenden an."
        }
    }

    var price: Int {
        switch self {
        case .stein: 10
        case .busch: 15
        case .pilz: 20
        case .sonnenblumen: 25
        case .blumenbeet: 30
        case .gartenzwerg: 40
        case .baumstamm: 45
        case .laterne: 55
        case .tunnel: 70
        case .heuraufe: 90
        case .teich: 140
        case .feenring: 450
        }
    }

    /// Gemütlichkeit – erhöht die Chance auf seltene Gäste.
    var cozy: Int {
        switch self {
        case .stein: 2
        case .busch: 3
        case .pilz: 3
        case .sonnenblumen: 4
        case .blumenbeet: 5
        case .gartenzwerg: 4
        case .baumstamm: 5
        case .laterne: 6
        case .tunnel: 9
        case .heuraufe: 7
        case .teich: 12
        case .feenring: 30
        }
    }

    var symbol: String {
        switch self {
        case .stein: "mountain.2.fill"
        case .busch: "tree.fill"
        case .pilz: "circle.hexagongrid.fill"
        case .sonnenblumen: "sun.max.fill"
        case .blumenbeet: "camera.macro"
        case .gartenzwerg: "figure.stand"
        case .baumstamm: "line.3.horizontal"
        case .laterne: "lamp.desk.fill"
        case .tunnel: "circle.dashed"
        case .heuraufe: "square.stack.3d.down.forward.fill"
        case .teich: "drop.fill"
        case .feenring: "sparkles"
        }
    }

    /// Wie oft man es besitzen kann.
    var limit: Int { self == .feenring || self == .teich ? 1 : 4 }
}

struct GardenDecor: Codable, Identifiable, Hashable {
    var id = UUID()
    var kind: DecorKind
    var x: Double
    var y: Double
}

enum HomeStyle: String, Codable, CaseIterable, Identifiable {
    case holzstall, cottage, pilzhaus, schloss
    var id: String { rawValue }

    var title: String {
        switch self {
        case .holzstall: "Holzstall"
        case .cottage: "Blaues Häuschen"
        case .pilzhaus: "Pilzhaus"
        case .schloss: "Hasenschloss"
        }
    }

    var capacity: Int { [4, 6, 8, 10][HomeStyle.allCases.firstIndex(of: self)!] }
    var price: Int { [0, 150, 400, 900][HomeStyle.allCases.firstIndex(of: self)!] }
    var cozy: Int { [0, 8, 16, 30][HomeStyle.allCases.firstIndex(of: self)!] }
}

// MARK: - Gespeicherter Zustand

struct GardenRabbit: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var look: RabbitLook
    var rarity: Rarity
    var personality: GardenPersonality
    /// 0…100 – 100 heißt satt.
    var hunger: Double = 80
    var mood: Double = 70
    var energy: Double = 80
    /// Freundschaft 0…100 (fünf Herzen).
    var friendship: Double = 10
    var joined: Date = .now
    var x: Double = 0.5
    var y: Double = 0.5
    /// Gäste sind noch nicht eingezogen.
    var isVisitor = false
    /// Vertrauen eines Gastes (100 → zieht ein).
    var trust: Double = 0
    var leaveAt: Date?
    /// Wunsch eines Gastes (optional gespeichert, damit ältere Spielstände lesbar bleiben).
    var wish: VisitorWish?
    var wishFulfilled: Bool?
    var wishProgress: Double?

    var hasOpenWish: Bool { isVisitor && wish != nil && wishFulfilled != true }

    /// Aufgepäppelt und bereit für ein neues Zuhause.
    /// Für immer behalten (eigenes Gehege, wird nicht vermittelt).
    var kept: Bool?
    /// Unzertrennlicher Partner – wird nur gemeinsam vermittelt.
    var partner: UUID?
    var isKept: Bool { kept == true }

    /// Aufgepäppelt und bereit für ein neues Zuhause.
    var isReady: Bool { !isVisitor && !isKept && hunger >= 55 && mood >= 60 && friendship >= 45 && Date.now.timeIntervalSince(joined) > 8 * 60 }

    static let names = [
        "Mümmel", "Flocke", "Hoppel", "Krümel", "Möhrchen", "Wuschel", "Puschel", "Stups",
        "Lotte", "Bommel", "Fussel", "Erbse", "Keks", "Zimt", "Muffin", "Socke", "Pünktchen",
        "Schnuffel", "Bruno", "Luna", "Wolke", "Hazel", "Ronja", "Pippa", "Ole", "Nougat",
        "Mokka", "Klee", "Rübe", "Hugo", "Frieda", "Kiwi", "Pommes", "Butterblume", "Locke",
        "Toffee", "Fiete", "Mo", "Nala", "Smilla", "Bärbel", "Kalle", "Pelle", "Lasse",
    ]

    static let legendaryNames: [GardenFur: [String]] = [
        .gold: ["Sternchen", "Goldi", "Funkel", "Komet"],
        .mond: ["Luna", "Selene", "Silberschein", "Nebel"],
        .kirsch: ["Sakura", "Blütenzauber", "Rosalie", "Kirschi"],
        .nacht: ["Orion", "Galaxie", "Nova", "Sternschnuppe"],
    ]
}

struct GardenFlower: Codable, Identifiable, Hashable {
    enum Kind: String, Codable { case loewenzahn, gaensebluemchen, gluecksklee }
    var id = UUID()
    var kind: Kind
    var x: Double
    var y: Double
}

enum GardenFoodKind: String, Codable, CaseIterable, Identifiable {
    case heu, loewenzahn, moehre, zweige
    var id: String { rawValue }

    var title: String {
        switch self {
        case .heu: "Heu"
        case .loewenzahn: "Löwenzahn"
        case .moehre: "Möhre"
        case .zweige: "Apfelzweige"
        }
    }

    var symbol: String {
        switch self {
        case .heu: "square.stack.3d.down.forward.fill"
        case .loewenzahn: "sun.max.fill"
        case .moehre: "carrot.fill"
        case .zweige: "tree.fill"
        }
    }

    var tint: Color {
        switch self {
        case .heu: Color(hex: 0xC9A646)
        case .loewenzahn: Color(hex: 0xF0C419)
        case .moehre: Color(hex: 0xE2722B)
        case .zweige: Color(hex: 0x8A5A3A)
        }
    }

    /// Wie viel eine Portion satt macht, glücklich macht und Vertrauen schenkt.
    var nourishment: Double { switch self { case .heu: 30; case .loewenzahn: 18; case .moehre: 25; case .zweige: 26 } }
    var joy: Double { switch self { case .heu: 4; case .loewenzahn: 14; case .moehre: 25; case .zweige: 18 } }
    var trust: Double { switch self { case .heu: 30; case .loewenzahn: 45; case .moehre: 80; case .zweige: 60 } }

    /// Kauf im Shop: Menge pro Kauf und Preis in Sternen.
    var shopBundle: (amount: Int, price: Int)? {
        switch self {
        case .heu: (10, 12)
        case .zweige: (3, 10)
        case .moehre: (2, 15)
        case .loewenzahn: nil
        }
    }
}

struct GardenFood: Codable, Identifiable, Hashable {
    var id = UUID()
    var kind: GardenFoodKind
    var x: Double
    var y: Double
    /// Verbleibende Menge 0…1.
    var amount: Double = 1
}

struct CarrotSlot: Codable, Hashable {
    var planted: Date?
    var wateredUntil: Date?
    var growth: Double = 0
    var isReady: Bool { planted != nil && growth >= 1 }
}

struct GardenInventory: Codable, Hashable {
    var heu = 10
    var loewenzahn = 2
    var moehre = 1
    var sterne = 30
    var zweige = 0

    init(heu: Int = 10, loewenzahn: Int = 2, moehre: Int = 1, sterne: Int = 30, zweige: Int = 0) {
        self.heu = heu; self.loewenzahn = loewenzahn; self.moehre = moehre; self.sterne = sterne; self.zweige = zweige
    }

    /// Ältere Spielstände kennen manche Felder noch nicht.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        heu = try c.decodeIfPresent(Int.self, forKey: .heu) ?? 10
        loewenzahn = try c.decodeIfPresent(Int.self, forKey: .loewenzahn) ?? 2
        moehre = try c.decodeIfPresent(Int.self, forKey: .moehre) ?? 1
        sterne = try c.decodeIfPresent(Int.self, forKey: .sterne) ?? 30
        zweige = try c.decodeIfPresent(Int.self, forKey: .zweige) ?? 0
    }

    subscript(kind: GardenFoodKind) -> Int {
        get {
            switch kind {
            case .heu: heu
            case .loewenzahn: loewenzahn
            case .moehre: moehre
            case .zweige: zweige
            }
        }
        set {
            switch kind {
            case .heu: heu = newValue
            case .loewenzahn: loewenzahn = newValue
            case .moehre: moehre = newValue
            case .zweige: zweige = newValue
            }
        }
    }
}

struct PendingVisit: Codable, Hashable {
    var arrive: Date
    var rarity: Rarity
    var look: RabbitLook
    var personality: GardenPersonality
}

struct GardenSave: Codable {
    static let cols = 10
    static let rows = 14

    var rabbits: [GardenRabbit] = []
    var grass: [Double] = Array(repeating: 0.75, count: cols * rows)
    var wet: [Double] = Array(repeating: 0, count: cols * rows)
    var flowers: [GardenFlower] = []
    var foods: [GardenFood] = []
    var bed: [CarrotSlot] = Array(repeating: CarrotSlot(), count: 3)
    var inventory = GardenInventory()
    var decor: [GardenDecor] = []
    /// Gekaufte, noch nicht aufgestellte Deko.
    var decorStock: [String: Int] = [:]
    var home: HomeStyle = .holzstall
    var ownedHomes: Set<HomeStyle> = [.holzstall]
    var discoveredFurs: Set<GardenFur> = []
    var discoveredPatterns: Set<GardenPattern> = []
    var discoveredBreeds: Set<GardenBreed> = []
    var metRarities: [Int] = [0, 0, 0, 0]
    var luckyClover = false
    var visitorsSeen = 0
    var hayProgress: Double = 0
    var lastSaved: Date = .now
    var tutorialStep = 0
    /// Ausgewürfelter Besuch, während die App geschlossen ist.
    var pendingVisit: PendingVisit?
    /// Winter, für den der Wintervorrat schon verschenkt wurde (Jahr, in dem er begann).
    var winterGiftYear: Int?
    /// Tag ("yyyy-MM-dd") der letzten Nachbarschaftshilfe.
    var lastAidDay: String?

    // Auffangstation: Fortschritt, Aufgaben, Sammelbuch, Vermittlung (optional – ältere Spielstände bleiben lesbar)
    var xp: Int?
    var level: Int?
    var quests: [GardenQuest]?
    var questDay: String?
    var rerollDay: String?
    var combos: Set<String>?
    var claimedMilestones: Set<Int>?
    var adopters: [Adopter]?
    var adoptions: [AdoptionRecord]?
    var nextAdopterAt: Date?
    var posts: [SocialPost]?
    /// Wie gut sich zwei Kaninchen kennen (0…100, Schlüssel "idA|idB").
    var bonds: [String: Double]?
    var followers: Int?

    func stock(_ kind: DecorKind) -> Int { decorStock[kind.rawValue] ?? 0 }
    func owned(_ kind: DecorKind) -> Int { stock(kind) + decor.filter { $0.kind == kind }.count }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// Eigene Farben und Schrift der App.
enum MTheme {
    static let carrot = Color(hex: 0xE2722B)
    static let leaf = Color(hex: 0x5E9A3E)
    static let star = Color(hex: 0xF0B429)
    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded) }
}

/// Demo-Modus für Screenshots: `-MuemmelDemo YES`, optional `-MuemmelScreen shop|album|night`.
enum GardenDemo {
    static var isActive: Bool { UserDefaults.standard.bool(forKey: "MuemmelDemo") }
    static var screen: String { UserDefaults.standard.string(forKey: "MuemmelScreen") ?? "" }
}
