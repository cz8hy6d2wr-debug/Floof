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
    /// So lange bleibt ein Gast (Sekunden).
    var stay: ClosedRange<Double> { [130...180, 120...160, 100...140, 90...120][rawValue] }

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
    case einfarbig, blesse, hollaender, schecke, russe

    var title: String {
        switch self {
        case .einfarbig: "Einfarbig"
        case .hollaender: "Holländer"
        case .schecke: "Schecke"
        case .blesse: "Blesse"
        case .russe: "Russe"
        }
    }
}

enum GardenBreed: String, Codable, CaseIterable {
    case stehohr, widder, zwerg, loewenkopf, riese

    var title: String {
        switch self {
        case .stehohr: "Stehohr"
        case .widder: "Widder"
        case .loewenkopf: "Löwenkopf"
        case .zwerg: "Zwerg"
        case .riese: "Riese"
        }
    }

    var bodyScale: CGFloat {
        switch self {
        case .zwerg: 0.82
        case .riese: 1.22
        default: 1
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
            breed = [.stehohr, .widder, .zwerg].randomElement()!
        case .selten:
            fur = (GardenFur.common + GardenFur.uncommon + GardenFur.uncommon).randomElement()!
            pattern = [.einfarbig, .blesse, .hollaender, .schecke].randomElement()!
            breed = [.stehohr, .widder, .zwerg, .loewenkopf].randomElement()!
            // mindestens ein besonderes Merkmal
            if !GardenFur.uncommon.contains(fur) && ![.hollaender, .schecke].contains(pattern) && breed != .loewenkopf {
                pattern = [.hollaender, .schecke].randomElement()!
            }
        case .superSelten:
            fur = (GardenFur.superRare + GardenFur.superRare + GardenFur.uncommon + GardenFur.common).randomElement()!
            pattern = [.einfarbig, .hollaender, .schecke, .russe].randomElement()!
            breed = [.widder, .loewenkopf, .riese, .zwerg].randomElement()!
            if !GardenFur.superRare.contains(fur) && pattern != .russe && breed != .riese {
                if Bool.random() { pattern = .russe } else { breed = .riese }
            }
        case .legendaer:
            fur = GardenFur.legendary.randomElement()!
            pattern = [.einfarbig, .einfarbig, .blesse].randomElement()!
            breed = GardenBreed.allCases.randomElement()!
        }
        if pattern == .russe { fur = .weiss }
        return RabbitLook(fur: fur, pattern: pattern, breed: breed, accent: fur == accent ? .schwarz : accent)
    }

    var description: String {
        pattern == .einfarbig ? "\(breed.title) · \(fur.title)" : "\(breed.title) · \(pattern.title) · \(fur.title)"
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
    case heu, loewenzahn, moehre
    var id: String { rawValue }

    var title: String {
        switch self {
        case .heu: "Heu"
        case .loewenzahn: "Löwenzahn"
        case .moehre: "Möhre"
        }
    }

    var symbol: String {
        switch self {
        case .heu: "square.stack.3d.down.forward.fill"
        case .loewenzahn: "sun.max.fill"
        case .moehre: "carrot.fill"
        }
    }

    var tint: Color {
        switch self {
        case .heu: Color(hex: 0xC9A646)
        case .loewenzahn: Color(hex: 0xF0C419)
        case .moehre: Color(hex: 0xE2722B)
        }
    }

    /// Wie viel eine Portion satt macht, glücklich macht und Vertrauen schenkt.
    var nourishment: Double { switch self { case .heu: 30; case .loewenzahn: 18; case .moehre: 25 } }
    var joy: Double { switch self { case .heu: 4; case .loewenzahn: 14; case .moehre: 25 } }
    var trust: Double { switch self { case .heu: 30; case .loewenzahn: 45; case .moehre: 80 } }
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

    subscript(kind: GardenFoodKind) -> Int {
        get {
            switch kind {
            case .heu: heu
            case .loewenzahn: loewenzahn
            case .moehre: moehre
            }
        }
        set {
            switch kind {
            case .heu: heu = newValue
            case .loewenzahn: loewenzahn = newValue
            case .moehre: moehre = newValue
            }
        }
    }
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
