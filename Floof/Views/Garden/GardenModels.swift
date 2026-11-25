import SwiftUI

// MARK: - Aussehen

/// Fellfarbe eines Garten-Kaninchens: Grundton, Schatten und Bauch.
enum GardenFur: String, Codable, CaseIterable {
    case weiss, creme, wildfarben, grau, schwarz, schoko, rot, sand, gold

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
        case .gold: "Sternenstaub"
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
        case .gold: Color(hex: 0xF2C14E)
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
        case .gold: Color(hex: 0xD3962A)
        }
    }

    var belly: Color {
        switch self {
        case .schwarz, .schoko: Color(hex: 0x5A4A42)
        case .gold: Color(hex: 0xFFF1C4)
        default: Color(hex: 0xFBF5EA)
        }
    }

    /// Nur mit Glücksklee oder sehr viel Glück.
    var isRare: Bool { self == .gold }
}

enum GardenPattern: String, Codable, CaseIterable {
    case einfarbig, hollaender, schecke, blesse, russe

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
    case stehohr, widder, loewenkopf, zwerg, riese

    var title: String {
        switch self {
        case .stehohr: "Stehohr"
        case .widder: "Widder"
        case .loewenkopf: "Löwenkopf"
        case .zwerg: "Zwerg"
        case .riese: "Deutscher Riese"
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

    static func random(lucky: Bool) -> RabbitLook {
        let fur: GardenFur
        if lucky && Double.random(in: 0...1) < 0.5 || Double.random(in: 0...1) < 0.02 {
            fur = .gold
        } else {
            fur = GardenFur.allCases.filter { !$0.isRare }.randomElement()!
        }
        let pattern: GardenPattern = {
            let roll = Double.random(in: 0...1)
            if roll < 0.40 { return .einfarbig }
            if roll < 0.60 { return .blesse }
            if roll < 0.78 { return .hollaender }
            if roll < 0.93 { return .schecke }
            return .russe
        }()
        let breed: GardenBreed = {
            let roll = Double.random(in: 0...1)
            if roll < 0.40 { return .stehohr }
            if roll < 0.65 { return .widder }
            if roll < 0.82 { return .zwerg }
            if roll < 0.94 { return .loewenkopf }
            return .riese
        }()
        let accent: GardenFur = [.schwarz, .schoko, .grau, .wildfarben, .rot].randomElement()!
        return RabbitLook(fur: fur, pattern: pattern, breed: breed, accent: fur == accent ? .schwarz : accent)
    }
}

// MARK: - Gespeicherter Zustand

struct GardenRabbit: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var look: RabbitLook
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
}

struct GardenFlower: Codable, Identifiable, Hashable {
    enum Kind: String, Codable { case loewenzahn, gaensebluemchen, gluecksklee }
    var id = UUID()
    var kind: Kind
    var x: Double
    var y: Double
    var born: Date = .now
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
    /// Fortschritt 0…1 (wird beim Speichern mitgenommen).
    var growth: Double = 0
    var isReady: Bool { planted != nil && growth >= 1 }
}

struct GardenInventory: Codable, Hashable {
    var heu = 10
    var loewenzahn = 2
    var moehre = 1

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
    var discoveredFurs: Set<GardenFur> = []
    var discoveredPatterns: Set<GardenPattern> = []
    var discoveredBreeds: Set<GardenBreed> = []
    var luckyClover = false
    var visitorsSeen = 0
    var hayProgress: Double = 0
    var lastSaved: Date = .now
    var tutorialStep = 0
}
