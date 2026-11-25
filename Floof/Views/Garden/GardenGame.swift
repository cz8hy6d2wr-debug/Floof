import SwiftUI
import UIKit

enum GardenTool: String, CaseIterable, Identifiable {
    case hand, maeher, giesskanne, futter
    var id: String { rawValue }

    var title: String {
        switch self {
        case .hand: "Hand"
        case .maeher: "Mähen"
        case .giesskanne: "Gießen"
        case .futter: "Futter"
        }
    }

    var symbol: String {
        switch self {
        case .hand: "hand.point.up.left.fill"
        case .maeher: "scissors"
        case .giesskanne: "drop.fill"
        case .futter: "carrot.fill"
        }
    }
}

struct GardenBanner: Equatable, Identifiable {
    let id = UUID()
    let text: String
    let symbol: String
}

/// Laufzeit-Zustand eines Kaninchens (Bewegung, Animation) – wird nicht gespeichert.
struct RabbitActor {
    enum Mode { case idle, wander, graze, seekFood, eat, sleep, flop, binky, groom, enter, leave, startled }

    var mode: Mode = .idle
    var timer: Double = .random(in: 0.5...2)
    var goal: CGPoint?
    var hopFrom: CGPoint = .zero
    var hopTo: CGPoint = .zero
    var hopT: Double = 1
    var hopDuration: Double = 0.32
    var hopHeight: Double = 9
    var pause: Double = 0
    var facing: CGFloat = 1
    var foodID: UUID?
    var cell: Int?
    var pettedUntil: Double = 0
    var strokeDistance: Double = 0
    var spinDirection: Double = 1
    var blinkAt: Double = .random(in: 1...5)
    var twitchAt: Double = .random(in: 1...6)
    var lookAt: Double = 0
    var zzzAt: Double = 0

    var isHopping: Bool { hopT < 1 }
}

struct GardenParticle {
    enum Kind { case heart, sparkle, clip, drop, zzz, confetti, label(String), petal }
    var kind: Kind
    var p: CGPoint
    var v: CGVector
    var life: Double
    var maxLife: Double
    var rotation: Double = .random(in: 0...(2 * .pi))
    var spin: Double = .random(in: -4...4)
    var color: Color = .white
    var gravity: Double = 0
}

/// Das Spiel: Simulation von Rasen, Blumen, Beet und Kaninchen.
/// Was sich jedes Bild ändert, ist von der Beobachtung ausgenommen (`@ObservationIgnored`) –
/// die Oberfläche hängt nur an Vorrat, Auswahl, Werkzeug, Hinweisen und einem Takt (`hudTick`).
@MainActor
@Observable
final class GardenGame {
    static let capacity = 8
    private static let saveKey = "floof.garden.v1"

    // MARK: Beobachtet (Oberfläche)
    var inventory: GardenInventory
    var tool: GardenTool = .hand
    var foodChoice: GardenFoodKind = .heu
    var selectedID: UUID?
    var banner: GardenBanner?
    var hudTick = 0
    var celebrate = 0

    // MARK: Simulation
    @ObservationIgnored var save: GardenSave
    @ObservationIgnored var actors: [UUID: RabbitActor] = [:]
    @ObservationIgnored var particles: [GardenParticle] = []
    @ObservationIgnored var size: CGSize = CGSize(width: 390, height: 844)
    @ObservationIgnored var clock: Double = 0
    @ObservationIgnored var raining = false
    @ObservationIgnored var rainAmount: Double = 0
    @ObservationIgnored private var rainUntil: Double = 0
    @ObservationIgnored private var nextRainCheck: Double = 90
    @ObservationIgnored private var nextVisitor: Double = 6
    @ObservationIgnored private var nextFlower: Double = 8
    @ObservationIgnored private var nextSave: Double = 15
    @ObservationIgnored private var hudTimer: Double = 0
    @ObservationIgnored private var bannerUntil: Double = 0
    @ObservationIgnored private var lastWall: Date = .now
    /// Werkzeug-Anzeige unter dem Finger (Bildschirmpunkte).
    @ObservationIgnored var toolPoint: CGPoint?
    @ObservationIgnored private var touchStart: CGPoint?
    @ObservationIgnored private var lastTouch: CGPoint?
    @ObservationIgnored private var pettingID: UUID?
    @ObservationIgnored private var lastCutHaptic: Double = 0
    let isDemo: Bool
    /// Für Screenshots: feste Uhrzeit.
    @ObservationIgnored var fixedHour: Double?

    private let light = UIImpactFeedbackGenerator(style: .light)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let notify = UINotificationFeedbackGenerator()

    init(demo: Bool = DemoMode.isActive) {
        isDemo = demo
        if demo {
            save = Self.demoSave()
            fixedHour = 10.5
        } else if let data = UserDefaults.standard.data(forKey: Self.saveKey),
                  let loaded = try? JSONDecoder().decode(GardenSave.self, from: data),
                  loaded.grass.count == GardenSave.cols * GardenSave.rows {
            save = loaded
        } else {
            save = GardenSave()
            save.flowers = (0..<5).map { _ in
                GardenFlower(kind: Bool.random() ? .gaensebluemchen : .loewenzahn,
                             x: .random(in: 0.08...0.92), y: .random(in: 0.2...0.75))
            }
        }
        inventory = save.inventory
        for rabbit in save.rabbits { actors[rabbit.id] = RabbitActor() }
        if !demo { catchUp(seconds: Date.now.timeIntervalSince(save.lastSaved)) }
        if save.rabbits.isEmpty { nextVisitor = 3 }
    }

    // MARK: - Geometrie

    var lawnTop: CGFloat { size.height * 0.34 }
    var unit: CGFloat { min(max(min(size.width, size.height * 0.62) / 390, 0.8), 1.7) }

    func screen(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: x * size.width, y: lawnTop + y * (size.height - lawnTop))
    }

    func world(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x / max(size.width, 1), y: (p.y - lawnTop) / max(size.height - lawnTop, 1))
    }

    func scale(atY y: Double) -> CGFloat { unit * (0.62 + 0.55 * CGFloat(y)) }

    /// Tiefste Stelle, an die Tiere laufen (darunter liegt die Werkzeugleiste).
    var maxY: Double { max(0.5, 1 - Double(150 / max(size.height - lawnTop, 1))) }

    static let hutch = CGPoint(x: 0.14, y: 0.02)
    static let bedRect = CGRect(x: 0.64, y: 0.0, width: 0.31, height: 0.11)
    static func slotCenter(_ i: Int) -> CGPoint { CGPoint(x: 0.69 + Double(i) * 0.105, y: 0.06) }

    func cellIndex(_ x: Double, _ y: Double) -> Int {
        let i = min(GardenSave.cols - 1, max(0, Int(x * Double(GardenSave.cols))))
        let j = min(GardenSave.rows - 1, max(0, Int(y * Double(GardenSave.rows))))
        return j * GardenSave.cols + i
    }

    func cellCenter(_ index: Int) -> CGPoint {
        let i = index % GardenSave.cols, j = index / GardenSave.cols
        return CGPoint(x: (Double(i) + 0.5) / Double(GardenSave.cols), y: (Double(j) + 0.5) / Double(GardenSave.rows))
    }

    // MARK: - Tageszeit

    var hour: Double {
        if let fixedHour { return fixedHour }
        let c = Calendar.current.dateComponents([.hour, .minute], from: .now)
        return Double(c.hour ?? 12) + Double(c.minute ?? 0) / 60
    }

    /// 1 = heller Tag, 0 = tiefe Nacht.
    var daylight: Double {
        let h = hour
        switch h {
        case 7.5..<19: return 1
        case 5..<7.5: return (h - 5) / 2.5
        case 19..<21.5: return 1 - (h - 19) / 2.5
        default: return 0
        }
    }

    var isNight: Bool { daylight < 0.3 }

    // MARK: - Zugriff

    var residents: [GardenRabbit] { save.rabbits.filter { !$0.isVisitor } }
    var visitor: GardenRabbit? { save.rabbits.first { $0.isVisitor } }

    var selectedRabbit: GardenRabbit? {
        guard let selectedID else { return nil }
        return save.rabbits.first { $0.id == selectedID }
    }

    private func index(of id: UUID) -> Int? { save.rabbits.firstIndex { $0.id == id } }

    // MARK: - Schleife

    func run() async {
        lastWall = .now
        light.prepare()
        while !Task.isCancelled {
            let now = Date.now
            let gap = now.timeIntervalSince(lastWall)
            lastWall = now
            if gap > 3 {
                catchUp(seconds: gap)
            } else {
                step(min(gap, 0.1))
            }
            try? await Task.sleep(for: .milliseconds(16))
        }
    }

    private func step(_ dt: Double) {
        guard dt > 0 else { return }
        clock += dt

        updateWeather(dt)
        updateGrass(dt)
        updateBed(dt)
        for i in save.rabbits.indices.reversed() { updateRabbit(at: i, dt: dt) }
        updateParticles(dt)

        if clock >= nextFlower {
            nextFlower = clock + .random(in: 14...30)
            spawnFlower()
        }
        if clock >= nextVisitor {
            nextVisitor = clock + .random(in: 50...140)
            if visitor == nil { spawnVisitor() }
        }
        if banner != nil, clock > bannerUntil { banner = nil }

        hudTimer += dt
        if hudTimer > 0.4 {
            hudTimer = 0
            hudTick &+= 1
        }
        if clock >= nextSave {
            nextSave = clock + 15
            persist()
        }
    }

    // MARK: - Wetter, Rasen, Beet

    private func updateWeather(_ dt: Double) {
        if raining {
            rainAmount = min(1, rainAmount + dt * 0.4)
            if clock > rainUntil { raining = false }
        } else {
            rainAmount = max(0, rainAmount - dt * 0.3)
            if clock > nextRainCheck {
                nextRainCheck = clock + 60
                if Double.random(in: 0...1) < 0.08 && !isDemo {
                    raining = true
                    rainUntil = clock + .random(in: 50...140)
                    showBanner("Es regnet – der Rasen freut sich", symbol: "cloud.rain.fill")
                }
            }
        }
    }

    /// Ganz kurzer Rasen braucht etwa 12 Minuten bis hoch – nass doppelt so schnell.
    private func updateGrass(_ dt: Double) {
        let base = dt / 720
        for k in save.grass.indices {
            if rainAmount > 0.5 { save.wet[k] = min(1, save.wet[k] + dt * 0.2) }
            let w = save.wet[k]
            save.grass[k] = min(1, save.grass[k] + base * (1 + 1.5 * w))
            if w > 0 { save.wet[k] = max(0, w - dt / 300) }
        }
    }

    private func updateBed(_ dt: Double) {
        let now = Date.now
        for i in save.bed.indices where save.bed[i].planted != nil && save.bed[i].growth < 1 {
            let watered = (save.bed[i].wateredUntil ?? .distantPast) > now || rainAmount > 0.5
            save.bed[i].growth = min(1, save.bed[i].growth + dt / 600 * (watered ? 2 : 1))
            if save.bed[i].growth >= 1 {
                let p = screen(Self.slotCenter(i).x, Self.slotCenter(i).y)
                burst(.sparkle, at: p, count: 6, color: .yellow)
            }
        }
    }

    // MARK: - Kaninchen

    private func updateRabbit(at i: Int, dt: Double) {
        var r = save.rabbits[i]
        var a = actors[r.id] ?? RabbitActor()
        let night = isNight

        // Bedürfnisse
        if !r.isVisitor {
            let p = r.personality
            let hungerRate = (p == .verfressen ? 0.03 : 0.02)
            var moodRate = (p == .verspielt ? 0.018 : 0.012)
            if r.hunger < 30 { moodRate *= 2 }
            r.hunger = max(0, r.hunger - hungerRate * dt)
            if a.mode == .sleep {
                r.energy = min(100, r.energy + 0.3 * dt)
            } else {
                r.energy = max(0, r.energy - (p == .verschlafen ? 0.016 : 0.01) * dt)
            }
            r.mood = max(0, r.mood - moodRate * dt)
            // Gesellschaft tut gut.
            if save.rabbits.contains(where: { $0.id != r.id && hypot($0.x - r.x, $0.y - r.y) < 0.12 }) {
                r.mood = min(100, r.mood + 0.02 * dt)
            }
        }

        // Hüpfen
        if a.hopT < 1 {
            a.hopT = min(1, a.hopT + dt / a.hopDuration)
            let t = a.hopT
            r.x = Double(a.hopFrom.x) + Double(a.hopTo.x - a.hopFrom.x) * t
            r.y = Double(a.hopFrom.y) + Double(a.hopTo.y - a.hopFrom.y) * t
            if a.hopT >= 1 {
                a.pause = a.mode == .startled ? 0.03 : .random(in: 0.06...0.3)
                if a.mode == .binky { a.mode = .idle; a.timer = .random(in: 0.6...1.5) }
            }
        } else if a.pause > 0 {
            a.pause -= dt
        } else if let goal = a.goal {
            let dx = Double(goal.x) - r.x, dy = Double(goal.y) - r.y
            let dist = hypot(dx, dy)
            if dist < 0.01 {
                a.goal = nil
                arrive(&r, &a)
            } else {
                let stepLen = min(dist, a.mode == .startled ? 0.075 : 0.055) * Double(r.look.breed.bodyScale)
                a.hopFrom = CGPoint(x: r.x, y: r.y)
                a.hopTo = CGPoint(x: r.x + dx / dist * stepLen, y: r.y + dy / dist * stepLen)
                a.hopT = 0
                a.hopDuration = a.mode == .startled ? 0.22 : 0.3
                a.hopHeight = a.mode == .startled ? 14 : 9
                if abs(dx) > 0.003 { a.facing = dx > 0 ? 1 : -1 }
            }
        } else {
            act(&r, &a, dt: dt, night: night)
        }

        // Blinzeln, Ohrenzucken, Zzz
        if clock > a.blinkAt { a.blinkAt = clock + .random(in: 2.5...6) }
        if clock > a.twitchAt { a.twitchAt = clock + .random(in: 2...7) }
        if a.mode == .sleep, clock > a.zzzAt {
            a.zzzAt = clock + 1.6
            let p = screen(r.x, r.y)
            let s = scale(atY: r.y)
            particles.append(GardenParticle(kind: .zzz, p: CGPoint(x: p.x + 10 * s * a.facing, y: p.y - 44 * s),
                                            v: CGVector(dx: 6 * a.facing, dy: -14), life: 2.2, maxLife: 2.2, spin: 0))
        }
        if r.look.fur == .gold, Double.random(in: 0...1) < dt * 1.5 {
            let p = screen(r.x, r.y)
            let s = scale(atY: r.y)
            burst(.sparkle, at: CGPoint(x: p.x + .random(in: -22...22) * s, y: p.y - .random(in: 5...40) * s),
                  count: 1, color: Color(hex: 0xFFE38A))
        }

        // Gast verlässt den Garten
        if r.isVisitor, a.mode == .leave, r.x < -0.06 || r.x > 1.06 {
            save.rabbits.remove(at: i)
            actors[r.id] = nil
            if selectedID == r.id { selectedID = nil }
            return
        }

        save.rabbits[i] = r
        actors[r.id] = a
    }

    /// Entscheidet, was ein Kaninchen als Nächstes tut (wenn es gerade nicht hüpft).
    private func act(_ r: inout GardenRabbit, _ a: inout RabbitActor, dt: Double, night: Bool) {
        switch a.mode {
        case .graze:
            guard let cell = a.cell else { a.mode = .idle; return }
            save.grass[cell] = max(0.12, save.grass[cell] - 0.05 * dt)
            r.hunger = min(100, r.hunger + 3.2 * dt)
            r.mood = min(100, r.mood + 0.15 * dt)
            a.timer -= dt
            if save.grass[cell] <= 0.18 || r.hunger >= 98 || a.timer <= 0 {
                a.mode = .idle
                a.timer = .random(in: 0.5...1.5)
                // Blumen in dieser Zelle werden mitgefressen.
                if let f = save.flowers.firstIndex(where: { cellIndex($0.x, $0.y) == cell }) {
                    save.flowers.remove(at: f)
                    r.mood = min(100, r.mood + 6)
                }
            }
            return
        case .eat:
            guard let id = a.foodID, let f = save.foods.firstIndex(where: { $0.id == id }) else {
                a.mode = .idle; a.timer = .random(in: 0.4...1); return
            }
            let kind = save.foods[f].kind
            let bite = min(save.foods[f].amount, 0.14 * dt)
            save.foods[f].amount -= bite
            r.hunger = min(100, r.hunger + kind.nourishment * bite)
            r.mood = min(100, r.mood + kind.joy * bite)
            if r.isVisitor {
                r.trust = min(100, r.trust + kind.trust * bite * (r.personality == .schuechtern ? 0.7 : 1))
                if r.trust >= 100 { befriend(&r, &a) }
            } else {
                r.friendship = min(100, r.friendship + kind.joy * bite * 0.25)
            }
            if save.foods[f].amount <= 0.001 {
                save.foods.remove(at: f)
                a.mode = .idle
                a.timer = .random(in: 0.5...1.2)
                if kind != .heu { binky(&r, &a) }
            }
            return
        case .sleep:
            if r.energy >= 99 && (!night || r.energy >= 100) && !r.isVisitor {
                a.mode = .idle
                a.timer = 1
            }
            return
        case .flop, .groom, .idle, .wander, .startled, .enter, .binky:
            a.timer -= dt
            if a.timer > 0 { return }
        case .leave, .seekFood:
            a.mode = .idle
        }

        decide(&r, &a, night: night)
    }

    private func decide(_ r: inout GardenRabbit, _ a: inout RabbitActor, night: Bool) {
        let roll = Double.random(in: 0...1)

        if r.isVisitor {
            if let leaveAt = r.leaveAt, leaveAt < .now {
                a.mode = .leave
                a.goal = CGPoint(x: r.x < 0.5 ? -0.1 : 1.1, y: r.y)
                return
            }
            if let food = nearestFood(to: r, within: r.personality == .schuechtern ? 0.35 : 0.6) {
                a.mode = .seekFood; a.foodID = food.id; a.goal = foodSpot(food, for: r); return
            }
            if roll < 0.35 {
                a.mode = .wander
                a.goal = randomNear(r, radius: 0.12)
            } else {
                a.mode = roll < 0.55 ? .groom : .idle
                a.timer = .random(in: 1.5...4)
            }
            return
        }

        if r.energy < 22 || (night && r.energy < 85) {
            a.mode = .sleep
            a.goal = sleepSpot(for: r.id)
            return
        }
        if r.hunger < 75, let food = nearestFood(to: r, within: 2) {
            a.mode = .seekFood; a.foodID = food.id; a.goal = foodSpot(food, for: r); return
        }
        if r.hunger < (r.personality == .verfressen ? 80 : 65), let cell = grassCell(near: r) {
            a.mode = .graze
            a.cell = cell
            a.timer = .random(in: 5...10)
            let c = cellCenter(cell)
            a.goal = CGPoint(x: c.x + .random(in: -0.025...0.025), y: min(maxY, c.y + .random(in: -0.02...0.02)))
            return
        }
        let playful = r.personality == .verspielt ? 0.3 : 0.15
        if r.mood > 75 && roll < playful {
            binky(&r, &a)
            return
        }
        if r.mood > 65 && !raining && daylight > 0.6 && roll < playful + 0.12 {
            a.mode = .flop
            a.timer = .random(in: 6...14)
            return
        }
        if roll < 0.5 {
            a.mode = .wander
            a.goal = randomNear(r, radius: 0.28)
        } else if roll < 0.68 {
            a.mode = .groom
            a.timer = .random(in: 2...3.5)
        } else {
            a.mode = .idle
            a.timer = .random(in: 1.5...4.5)
        }
    }

    private func arrive(_ r: inout GardenRabbit, _ a: inout RabbitActor) {
        switch a.mode {
        case .seekFood:
            if let id = a.foodID, let food = save.foods.first(where: { $0.id == id }) {
                a.mode = .eat
                a.facing = food.x >= r.x ? 1 : -1
            } else {
                a.mode = .idle
            }
        case .graze, .sleep:
            break
        case .enter:
            a.mode = .idle
            a.timer = .random(in: 1...2)
        case .startled:
            a.mode = .idle
            a.timer = .random(in: 1...2.5)
        case .leave:
            a.goal = CGPoint(x: r.x < 0.5 ? -0.12 : 1.12, y: r.y)
        default:
            a.mode = .idle
            a.timer = .random(in: 0.8...3)
        }
    }

    private func binky(_ r: inout GardenRabbit, _ a: inout RabbitActor) {
        a.mode = .binky
        a.hopFrom = CGPoint(x: r.x, y: r.y)
        let target = randomNear(r, radius: 0.05)
        a.hopTo = target
        if abs(Double(target.x) - r.x) > 0.002 { a.facing = Double(target.x) > r.x ? 1 : -1 }
        a.hopT = 0
        a.hopDuration = 0.62
        a.hopHeight = 36
        a.spinDirection = Bool.random() ? 1 : -1
        let p = screen(r.x, r.y)
        burst(.sparkle, at: CGPoint(x: p.x, y: p.y - 30 * scale(atY: r.y)), count: 4, color: Color(hex: 0xFFF2B0))
    }

    private func startle(_ r: inout GardenRabbit, _ a: inout RabbitActor, from p: CGPoint) {
        guard a.mode != .startled else { return }
        let dx = r.x - Double(p.x), dy = r.y - Double(p.y)
        let d = max(hypot(dx, dy), 0.001)
        a.mode = .startled
        a.goal = clampToLawn(CGPoint(x: r.x + dx / d * 0.18, y: r.y + dy / d * 0.12))
        a.hopT = 1
        a.pause = 0
    }

    private func befriend(_ r: inout GardenRabbit, _ a: inout RabbitActor) {
        guard r.isVisitor else { return }
        if residents.count >= Self.capacity {
            r.trust = 99
            showBanner("Der Garten ist voll – \(Self.capacity) Kaninchen sind genug Trubel", symbol: "house.fill")
            return
        }
        r.isVisitor = false
        r.leaveAt = nil
        r.friendship = 25
        r.joined = .now
        let used = Set(save.rabbits.map(\.name))
        r.name = GardenRabbit.names.filter { !used.contains($0) }.randomElement() ?? r.name
        a.mode = .idle
        a.timer = 1.5
        let p = screen(r.x, r.y)
        burst(.confetti, at: CGPoint(x: p.x, y: p.y - 30), count: 36, color: .white)
        burst(.heart, at: CGPoint(x: p.x, y: p.y - 30), count: 6, color: .pink)
        notify.notificationOccurred(.success)
        selectedID = r.id
        celebrate &+= 1
        showBanner("\(r.name) zieht bei dir ein!", symbol: "heart.fill", duration: 5)
        if save.tutorialStep < 2 {
            save.tutorialStep = 2
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(6))
                self?.showBanner("Langer Rasen ist Futter. Gemähter Rasen gibt Heu.", symbol: "scissors", duration: 6)
            }
        }
    }

    private func nearestFood(to r: GardenRabbit, within radius: Double) -> GardenFood? {
        save.foods
            .map { ($0, hypot($0.x - r.x, $0.y - r.y)) }
            .filter { $0.1 < radius }
            .min { $0.1 < $1.1 }?.0
    }

    /// Platz neben dem Futter – mehrere Tiere verteilen sich darum.
    private func foodSpot(_ food: GardenFood, for r: GardenRabbit) -> CGPoint {
        let side: Double = r.x < food.x ? -1 : 1
        return clampToLawn(CGPoint(x: food.x + side * 0.065, y: food.y + .random(in: -0.015...0.015)))
    }

    private func grassCell(near r: GardenRabbit) -> Int? {
        var best: (Int, Double)?
        for k in save.grass.indices where save.grass[k] > 0.42 {
            let c = cellCenter(k)
            guard c.y <= maxY, !Self.bedRect.insetBy(dx: -0.03, dy: -0.03).contains(c) else { continue }
            let dist: Double = hypot(Double(c.x) - r.x, Double(c.y) - r.y)
            let score: Double = dist - save.grass[k] * 0.25 + Double.random(in: 0...0.08)
            if best == nil || score < best!.1 { best = (k, score) }
        }
        return best?.0
    }

    private func sleepSpot(for id: UUID) -> CGPoint {
        let order = save.rabbits.filter { !$0.isVisitor }.firstIndex { $0.id == id } ?? 0
        let col = Double(order % 4), row = Double(order / 4)
        return CGPoint(x: Self.hutch.x - 0.06 + col * 0.07, y: Self.hutch.y + 0.1 + row * 0.05)
    }

    private func randomNear(_ r: GardenRabbit, radius: Double) -> CGPoint {
        clampToLawn(CGPoint(x: r.x + .random(in: -radius...radius), y: r.y + .random(in: -radius...radius) * 0.8))
    }

    func clampToLawn(_ p: CGPoint) -> CGPoint {
        var q = CGPoint(x: min(CGFloat(0.94), max(CGFloat(0.06), p.x)), y: min(CGFloat(maxY), max(CGFloat(0.05), p.y)))
        // nicht ins Beet
        if Self.bedRect.contains(q) { q.y = Self.bedRect.maxY + 0.02 }
        return q
    }

    // MARK: - Besuch & Blumen

    private func spawnVisitor() {
        let lucky = save.luckyClover
        save.luckyClover = false
        let look = RabbitLook.random(lucky: lucky)
        let fromLeft = Bool.random()
        let y = Double.random(in: 0.25...min(0.7, maxY))
        var r = GardenRabbit(name: "Gast", look: look, personality: GardenPersonality.allCases.randomElement()!)
        r.x = fromLeft ? -0.06 : 1.06
        r.y = y
        r.isVisitor = true
        r.leaveAt = Date.now.addingTimeInterval(.random(in: 110...170))
        r.trust = 0
        var a = RabbitActor()
        a.mode = .enter
        a.facing = fromLeft ? 1 : -1
        a.goal = CGPoint(x: fromLeft ? .random(in: 0.2...0.4) : .random(in: 0.6...0.8), y: y)
        save.rabbits.append(r)
        actors[r.id] = a
        save.visitorsSeen += 1
        let new = !save.discoveredFurs.contains(look.fur) || !save.discoveredPatterns.contains(look.pattern)
            || !save.discoveredBreeds.contains(look.breed)
        save.discoveredFurs.insert(look.fur)
        save.discoveredPatterns.insert(look.pattern)
        save.discoveredBreeds.insert(look.breed)
        soft.impactOccurred()

        if save.tutorialStep == 0 {
            save.tutorialStep = 1
            showBanner("Besuch! Leg Futter hin oder streichle ihn ganz vorsichtig.", symbol: "hare.fill", duration: 7)
        } else if look.fur == .gold {
            showBanner("Ein Sternenstaub-Kaninchen! Möhren mag es am liebsten.", symbol: "sparkles", duration: 6)
        } else {
            let what = "\(look.breed.title) in \(look.fur.title)"
            showBanner(new ? "Neu im Album: \(what) zu Besuch" : "Ein \(look.breed.title) schaut vorbei", symbol: "hare.fill")
        }
    }

    private func spawnFlower() {
        guard save.flowers.count < 14 else { return }
        let candidates = save.grass.indices.filter { save.grass[$0] > 0.55 && cellCenter($0).y < maxY && cellCenter($0).y > 0.12 }
        guard let cell = candidates.randomElement() else { return }
        let c = cellCenter(cell)
        let roll = Double.random(in: 0...1)
        let hasClover = save.flowers.contains { $0.kind == .gluecksklee }
        let kind: GardenFlower.Kind = roll < 0.05 && !hasClover ? .gluecksklee : (roll < 0.5 ? .loewenzahn : .gaensebluemchen)
        save.flowers.append(GardenFlower(kind: kind,
                                         x: c.x + .random(in: -0.04...0.04),
                                         y: c.y + .random(in: -0.025...0.025)))
    }

    // MARK: - Berührung

    func touchBegan(_ p: CGPoint) {
        touchStart = p
        lastTouch = p
        pettingID = tool == .hand ? rabbitID(at: p) : nil
        if tool == .maeher || tool == .giesskanne {
            toolPoint = p
            applyTool(from: p, to: p)
        }
    }

    func touchMoved(_ p: CGPoint) {
        let last = lastTouch ?? p
        lastTouch = p
        switch tool {
        case .maeher, .giesskanne:
            toolPoint = p
            applyTool(from: last, to: p)
        case .hand:
            if let id = pettingID { pet(id, distance: hypot(p.x - last.x, p.y - last.y), at: p) }
        case .futter:
            break
        }
    }

    func touchEnded(_ p: CGPoint) {
        let start = touchStart ?? p
        let isTap = hypot(p.x - start.x, p.y - start.y) < 12
        toolPoint = nil
        touchStart = nil
        lastTouch = nil
        pettingID = nil
        guard isTap else { return }
        switch tool {
        case .hand: tap(p)
        case .futter: placeFood(at: world(p))
        default: break
        }
    }

    private func rabbitID(at p: CGPoint) -> UUID? {
        var best: (UUID, CGFloat)?
        for r in save.rabbits {
            let s = scale(atY: r.y) * r.look.breed.bodyScale
            let c = screen(r.x, r.y)
            let center = CGPoint(x: c.x, y: c.y - 22 * s)
            let d = hypot(p.x - center.x, (p.y - center.y) * 0.9)
            if d < 38 * s, best == nil || d < best!.1 { best = (r.id, d) }
        }
        return best?.0
    }

    private func tap(_ p: CGPoint) {
        if let id = rabbitID(at: p), let i = index(of: id) {
            var r = save.rabbits[i]
            var a = actors[id] ?? RabbitActor()
            if r.isVisitor {
                let shy = r.personality == .schuechtern ? 0.55 : 0.3
                if r.trust < 40 && Double.random(in: 0...1) < shy {
                    startle(&r, &a, from: world(p))
                    r.trust = min(100, r.trust + 3)
                } else {
                    r.trust = min(100, r.trust + 9)
                    burst(.heart, at: CGPoint(x: p.x, y: p.y - 10), count: 1, color: .pink)
                    if r.trust >= 100 { befriend(&r, &a) }
                }
            } else {
                a.lookAt = clock + 1.2
                if a.mode == .idle || a.mode == .wander { a.facing = Double(world(p).x) >= r.x ? 1 : -1 }
            }
            save.rabbits[i] = r
            actors[id] = a
            selectedID = selectedID == id && !r.isVisitor ? nil : id
            light.impactOccurred()
            hudTick &+= 1
            return
        }

        let w = world(p)
        // Blume pflücken
        if let f = save.flowers.firstIndex(where: {
            let c = screen($0.x, $0.y)
            return hypot(c.x - p.x, c.y - 8 * scale(atY: $0.y) - p.y) < 26 * scale(atY: $0.y)
        }) {
            let flower = save.flowers.remove(at: f)
            switch flower.kind {
            case .loewenzahn:
                inventory.loewenzahn += 1
                floatLabel("+1 Löwenzahn", at: p)
            case .gaensebluemchen:
                burst(.petal, at: p, count: 8, color: .white)
                for k in save.rabbits.indices where !save.rabbits[k].isVisitor
                    && hypot(save.rabbits[k].x - Double(w.x), save.rabbits[k].y - Double(w.y)) < 0.2 {
                    save.rabbits[k].mood = min(100, save.rabbits[k].mood + 5)
                }
                floatLabel("Gänseblümchen!", at: p)
            case .gluecksklee:
                save.luckyClover = true
                nextVisitor = min(nextVisitor, clock + 20)
                burst(.sparkle, at: p, count: 14, color: .green)
                showBanner("Glücksklee! Der nächste Besuch wird besonders.", symbol: "sparkles", duration: 5)
            }
            light.impactOccurred()
            return
        }

        // Beet
        for i in save.bed.indices {
            let c = Self.slotCenter(i)
            let sp = screen(c.x, c.y)
            guard hypot(sp.x - p.x, sp.y - p.y) < 30 * unit else { continue }
            if save.bed[i].planted == nil {
                save.bed[i] = CarrotSlot(planted: .now, wateredUntil: nil, growth: 0)
                burst(.clip, at: sp, count: 6, color: Color(hex: 0x7A5230))
                floatLabel("Gesät", at: sp)
            } else if save.bed[i].isReady {
                let bonus = (save.bed[i].wateredUntil != nil) ? 2 : 1
                save.bed[i] = CarrotSlot()
                inventory.moehre += bonus
                floatLabel("+\(bonus) Möhre", at: sp)
                burst(.sparkle, at: sp, count: 8, color: .orange)
                notify.notificationOccurred(.success)
            } else {
                let left = Int(((1 - save.bed[i].growth) * 10).rounded(.up))
                floatLabel("noch ca. \(left) Min.", at: sp)
            }
            light.impactOccurred()
            return
        }

        // Neugierige kommen nachsehen.
        selectedID = nil
        for k in save.rabbits.indices where save.rabbits[k].personality == .neugierig && !save.rabbits[k].isVisitor {
            var a = actors[save.rabbits[k].id] ?? RabbitActor()
            if [.idle, .wander, .groom].contains(a.mode) {
                a.mode = .wander
                let side: CGFloat = save.rabbits[k].x < Double(w.x) ? -0.05 : 0.05
                a.goal = clampToLawn(CGPoint(x: w.x + side, y: w.y))
                actors[save.rabbits[k].id] = a
            }
        }
    }

    private func pet(_ id: UUID, distance: Double, at p: CGPoint) {
        guard let i = index(of: id) else { return }
        var r = save.rabbits[i]
        var a = actors[id] ?? RabbitActor()
        guard a.mode != .startled, !a.isHopping else { return }
        if r.isVisitor && r.trust < 25 && r.personality == .schuechtern && Double.random(in: 0...1) < 0.3 {
            startle(&r, &a, from: world(p))
            pettingID = nil
        } else {
            a.pettedUntil = clock + 0.7
            if a.mode == .wander { a.goal = nil; a.mode = .idle }
            a.timer = max(a.timer, 1)
            a.strokeDistance += distance
            if a.strokeDistance > 46 {
                a.strokeDistance = 0
                let love = r.personality == .verschmust ? 2.0 : 1.0
                if r.isVisitor {
                    r.trust = min(100, r.trust + 4 * love)
                    if r.trust >= 100 { befriend(&r, &a) }
                } else {
                    r.mood = min(100, r.mood + 3 * love)
                    r.friendship = min(100, r.friendship + 0.8 * love)
                }
                burst(.heart, at: CGPoint(x: p.x, y: p.y - 14), count: 1, color: Color(hex: 0xF27A9B))
                soft.impactOccurred(intensity: 0.6)
            }
        }
        save.rabbits[i] = r
        actors[id] = a
    }

    private func applyTool(from a: CGPoint, to b: CGPoint) {
        let steps = max(1, Int(hypot(b.x - a.x, b.y - a.y) / 10))
        for s in 0...steps {
            let t = CGFloat(s) / CGFloat(steps)
            let p = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            if tool == .maeher { mow(at: p) } else { water(at: p) }
        }
    }

    private func cells(around p: CGPoint, rx: Double, ry: Double) -> [Int] {
        let w = world(p)
        return save.grass.indices.filter {
            let c = cellCenter($0)
            let dx: Double = (Double(c.x) - Double(w.x)) / rx
            let dy: Double = (Double(c.y) - Double(w.y)) / ry
            return dx * dx + dy * dy <= 1
        }
    }

    private func mow(at p: CGPoint) {
        guard world(p).y > -0.02 else { return }
        var cut = 0.0
        for k in cells(around: p, rx: 0.075, ry: 0.06) {
            let c = cellCenter(k)
            if Self.bedRect.insetBy(dx: -0.01, dy: -0.01).contains(c) { continue }
            if save.grass[k] > 0.16 {
                cut += save.grass[k] - 0.08
                save.grass[k] = 0.08
            }
        }
        if cut > 0 {
            save.hayProgress += cut * 0.4
            burst(.clip, at: p, count: min(14, Int(cut * 10) + 2), color: Color(hex: 0x76B04A))
            if clock - lastCutHaptic > 0.07 {
                lastCutHaptic = clock
                soft.impactOccurred(intensity: 0.5)
            }
            while save.hayProgress >= 1 {
                save.hayProgress -= 1
                inventory.heu += 1
                floatLabel("+1 Heu", at: CGPoint(x: p.x, y: p.y - 30))
            }
        }
        let before = save.flowers.count
        save.flowers.removeAll {
            let s = screen($0.x, $0.y)
            return hypot(s.x - p.x, s.y - p.y) < 30 * unit && $0.kind != .gluecksklee
        }
        if save.flowers.count < before { burst(.petal, at: p, count: 6, color: Color(hex: 0xFFE680)) }
        scare(at: p, moodLoss: 5)
    }

    private func water(at p: CGPoint) {
        for k in cells(around: p, rx: 0.07, ry: 0.055) { save.wet[k] = 1 }
        if Double.random(in: 0...1) < 0.6 { burst(.drop, at: p, count: 2, color: Color(hex: 0x7CC3F2)) }
        for i in save.bed.indices where save.bed[i].planted != nil {
            let c = Self.slotCenter(i)
            let sp = screen(c.x, c.y)
            if hypot(sp.x - p.x, sp.y - p.y) < 34 * unit {
                save.bed[i].wateredUntil = Date.now.addingTimeInterval(300)
            }
        }
        scare(at: p, moodLoss: 2)
    }

    /// Mäher oder Wasser direkt am Kaninchen → es hoppelt erschrocken weg.
    private func scare(at p: CGPoint, moodLoss: Double) {
        for i in save.rabbits.indices {
            let r = save.rabbits[i]
            let c = screen(r.x, r.y)
            let s = scale(atY: r.y)
            guard hypot(c.x - p.x, c.y - 18 * s - p.y) < 40 * s else { continue }
            var rr = r
            var a = actors[r.id] ?? RabbitActor()
            if a.mode == .startled { continue }
            startle(&rr, &a, from: world(p))
            if !rr.isVisitor { rr.mood = max(0, rr.mood - moodLoss) } else { rr.trust = max(0, rr.trust - 10) }
            save.rabbits[i] = rr
            actors[r.id] = a
        }
    }

    // MARK: - Füttern

    func placeFood(at w: CGPoint, kind: GardenFoodKind? = nil) {
        let kind = kind ?? foodChoice
        guard inventory[kind] > 0 else {
            showBanner(kind == .moehre ? "Keine Möhren – säe welche im Beet oben rechts" :
                       kind == .heu ? "Kein Heu – mäh den Rasen" : "Kein Löwenzahn – pflück gelbe Blüten",
                       symbol: kind.symbol)
            return
        }
        guard save.foods.count < 8 else { showBanner("Erst mal aufessen lassen", symbol: "hare.fill"); return }
        let p = clampToLawn(w)
        inventory[kind] -= 1
        save.foods.append(GardenFood(kind: kind, x: p.x, y: p.y))
        light.impactOccurred()
        // Hungrige reagieren sofort.
        for k in save.rabbits.indices {
            var a = actors[save.rabbits[k].id] ?? RabbitActor()
            if [.idle, .wander, .groom, .flop].contains(a.mode) { a.timer = 0; a.goal = nil; a.mode = .idle }
            actors[save.rabbits[k].id] = a
        }
    }

    /// Futter direkt vor das gewählte Kaninchen legen.
    func feed(_ id: UUID, kind: GardenFoodKind) {
        guard let r = save.rabbits.first(where: { $0.id == id }) else { return }
        let a = actors[id] ?? RabbitActor()
        placeFood(at: CGPoint(x: r.x + 0.065 * Double(a.facing), y: r.y + 0.01), kind: kind)
        if var b = actors[id], let food = save.foods.last, food.kind == kind {
            b.mode = .seekFood
            b.foodID = food.id
            b.goal = foodSpot(food, for: r)
            actors[id] = b
        }
        hudTick &+= 1
    }

    func rename(_ id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let i = index(of: id) else { return }
        save.rabbits[i].name = String(trimmed.prefix(20))
        hudTick &+= 1
        persist()
    }

    // MARK: - Partikel

    func burst(_ kind: GardenParticle.Kind, at p: CGPoint, count: Int, color: Color) {
        guard particles.count < 260 else { return }
        for _ in 0..<count {
            var part = GardenParticle(kind: kind, p: p, v: .zero, life: 1, maxLife: 1, color: color)
            switch kind {
            case .heart:
                part.v = CGVector(dx: .random(in: -14...14), dy: .random(in: -48 ... -30))
                part.life = 1.4
            case .sparkle:
                part.v = CGVector(dx: .random(in: -40...40), dy: .random(in: -50...10))
                part.life = .random(in: 0.6...1.1)
            case .clip:
                part.v = CGVector(dx: .random(in: -80...80), dy: .random(in: -120 ... -40))
                part.gravity = 300
                part.life = .random(in: 0.5...0.9)
            case .drop:
                part.p.x += .random(in: -12...12)
                part.v = CGVector(dx: .random(in: -20...20), dy: .random(in: 20...60))
                part.gravity = 260
                part.life = 0.45
            case .confetti:
                part.v = CGVector(dx: .random(in: -160...160), dy: .random(in: -320 ... -120))
                part.gravity = 380
                part.life = .random(in: 1.4...2.2)
                part.color = [Color(hex: 0xF27A9B), Color(hex: 0xF2C14E), Color(hex: 0x7CC3F2),
                              Color(hex: 0x9DD67A), Color(hex: 0xE2722B)].randomElement()!
            case .petal:
                part.v = CGVector(dx: .random(in: -60...60), dy: .random(in: -90 ... -30))
                part.gravity = 120
                part.life = 1
            case .zzz, .label:
                part.v = CGVector(dx: 0, dy: -30)
                part.life = 1.4
            }
            part.maxLife = part.life
            particles.append(part)
        }
    }

    private func floatLabel(_ text: String, at p: CGPoint) {
        particles.append(GardenParticle(kind: .label(text), p: p, v: CGVector(dx: 0, dy: -36),
                                        life: 1.4, maxLife: 1.4, spin: 0))
    }

    private func updateParticles(_ dt: Double) {
        for i in particles.indices {
            particles[i].life -= dt
            particles[i].v.dy += CGFloat(particles[i].gravity * dt)
            particles[i].p.x += particles[i].v.dx * CGFloat(dt)
            particles[i].p.y += particles[i].v.dy * CGFloat(dt)
            particles[i].rotation += particles[i].spin * dt
        }
        particles.removeAll { $0.life <= 0 }
    }

    // MARK: - Hinweise

    func showBanner(_ text: String, symbol: String, duration: Double = 3.5) {
        banner = GardenBanner(text: text, symbol: symbol)
        bannerUntil = clock + duration
    }

    // MARK: - Abwesenheit & Speichern

    /// Was passiert ist, während der Garten zu war – sanft: niemand verhungert.
    private func catchUp(seconds: Double) {
        let t = min(max(seconds, 0), 3 * 86_400)
        guard t > 3 else { return }
        clock += 0.001

        for k in save.grass.indices {
            save.grass[k] = min(1, save.grass[k] + t / 720 * (1 + save.wet[k]))
            save.wet[k] = max(0, save.wet[k] - t / 300)
        }
        for i in save.bed.indices where save.bed[i].planted != nil {
            save.bed[i].growth = min(1, save.bed[i].growth + t / 600)
        }
        let lawn = save.grass.reduce(0, +) / Double(save.grass.count)
        let foodValue = save.foods.reduce(0) { $0 + $1.kind.nourishment * $1.amount }
        if !residents.isEmpty { save.foods.removeAll() }
        let share = foodValue / Double(max(residents.count, 1))

        for i in save.rabbits.indices {
            if save.rabbits[i].isVisitor { continue }
            var r = save.rabbits[i]
            let floor = lawn > 0.35 ? 60.0 : 20.0
            r.hunger = max(min(r.hunger, floor), r.hunger - t * 0.02) + share
            r.hunger = min(100, r.hunger)
            r.mood = max(min(r.mood, 40), r.mood - t * 0.012)
            r.energy = t > 1800 ? max(r.energy, 85) : r.energy
            save.rabbits[i] = r
            actors[r.id] = RabbitActor()
        }
        // Gäste gehen irgendwann wieder.
        save.rabbits.removeAll { $0.isVisitor && ($0.leaveAt ?? .distantPast) < .now }
        if selectedID != nil, selectedRabbit == nil { selectedID = nil }

        let newFlowers = min(6, Int(t / 90))
        for _ in 0..<newFlowers { spawnFlower() }

        if t > 600 {
            nextVisitor = min(nextVisitor, clock + 3)
            if !residents.isEmpty {
                showBanner("Willkommen zurück! Der Rasen ist gewachsen.", symbol: "leaf.fill", duration: 4)
            }
        }
        hudTick &+= 1
    }

    func persist() {
        guard !isDemo else { return }
        save.inventory = inventory
        save.lastSaved = .now
        if let data = try? JSONEncoder().encode(save) {
            UserDefaults.standard.set(data, forKey: Self.saveKey)
        }
    }

    // MARK: - Demo (Screenshots)

    private static func demoSave() -> GardenSave {
        var s = GardenSave()
        for k in s.grass.indices {
            let i = k % GardenSave.cols
            s.grass[k] = i < 5 ? 0.12 : 0.85
        }
        let looks: [(String, RabbitLook, GardenPersonality, Double, Double)] = [
            ("Mümmel", RabbitLook(fur: .wildfarben, pattern: .einfarbig, breed: .stehohr, accent: .schwarz), .verfressen, 0.3, 0.3),
            ("Flocke", RabbitLook(fur: .weiss, pattern: .russe, breed: .zwerg, accent: .schwarz), .verschmust, 0.55, 0.45),
            ("Keks", RabbitLook(fur: .sand, pattern: .hollaender, breed: .widder, accent: .schoko), .verspielt, 0.72, 0.62),
            ("Nougat", RabbitLook(fur: .schoko, pattern: .schecke, breed: .loewenkopf, accent: .schoko), .neugierig, 0.22, 0.6),
            ("Wolke", RabbitLook(fur: .grau, pattern: .blesse, breed: .riese, accent: .grau), .verschlafen, 0.8, 0.28),
        ]
        s.rabbits = looks.map { name, look, pers, x, y in
            var r = GardenRabbit(name: name, look: look, personality: pers)
            r.x = x; r.y = y
            r.hunger = 70; r.mood = 85; r.energy = 90; r.friendship = 60
            return r
        }
        s.flowers = [
            GardenFlower(kind: .loewenzahn, x: 0.62, y: 0.4),
            GardenFlower(kind: .gaensebluemchen, x: 0.85, y: 0.5),
            GardenFlower(kind: .gaensebluemchen, x: 0.9, y: 0.7),
            GardenFlower(kind: .gluecksklee, x: 0.7, y: 0.22),
        ]
        s.foods = [GardenFood(kind: .moehre, x: 0.42, y: 0.66)]
        s.bed = [CarrotSlot(planted: .now, growth: 1), CarrotSlot(planted: .now, growth: 0.5), CarrotSlot()]
        s.tutorialStep = 3
        s.inventory = GardenInventory(heu: 14, loewenzahn: 3, moehre: 2)
        return s
    }
}
