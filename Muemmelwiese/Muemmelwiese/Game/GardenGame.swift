import SwiftUI
import UIKit
import UserNotifications

enum GardenTool: String, CaseIterable, Identifiable {
    case hand, buerste, maeher, giesskanne, futter, foto, gestalten
    var id: String { rawValue }

    var title: String {
        switch self {
        case .hand: "Hand"
        case .maeher: "Mähen"
        case .giesskanne: "Gießen"
        case .futter: "Futter"
        case .buerste: "Bürste"
        case .foto: "Foto"
        case .gestalten: "Gestalten"
        }
    }

    var symbol: String {
        switch self {
        case .hand: "hand.point.up.left.fill"
        case .maeher: "scissors"
        case .giesskanne: "drop.fill"
        case .futter: "carrot.fill"
        case .buerste: "comb.fill"
        case .foto: "camera.fill"
        case .gestalten: "paintbrush.fill"
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
    enum Mode { case idle, wander, graze, seekFood, eat, sleep, flop, binky, groom, enter, leave, startled, seekDecor, hide, drink }

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
    var decorID: UUID?
    var incomeTimer: Double = .random(in: 30...80)
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
    enum Kind { case heart, sparkle, clip, drop, zzz, confetti, label(String), petal, fluff }
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
    private static let saveKey = "muemmelwiese.save.v1"

    // MARK: Beobachtet (Oberfläche)
    var inventory: GardenInventory
    var tool: GardenTool = .hand
    var foodChoice: GardenFoodKind = .heu
    var selectedID: UUID?
    var banner: GardenBanner?
    var hudTick = 0
    var celebrate = 0
    /// Gewählte Deko zum Aufstellen (Werkzeug „Gestalten“).
    var placing: DecorKind?
    /// Gerade aufgenommenes Foto (Polaroid-Ansicht)
    var photoResult: PhotoResult?
    @ObservationIgnored var photoCache: [String: UIImage] = [:]
    @ObservationIgnored var xpCarry: Double = 0
    @ObservationIgnored var stationTimer: Double = 1
    var selectedDecorID: UUID?

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
    @ObservationIgnored private var brushingID: UUID?
    @ObservationIgnored private var brushDistance: Double = 0
    @ObservationIgnored private var draggingDecorID: UUID?
    @ObservationIgnored private var lastCutHaptic: Double = 0
    let isDemo: Bool
    /// Für Screenshots: feste Uhrzeit.
    @ObservationIgnored var fixedHour: Double?

    // MARK: Akku
    /// Bilder pro Sekunde fürs Zeichnen – passt sich an (beobachtet, damit die Zeitleiste neu plant).
    var frameRate = 30
    /// Stromsparmodus des iPhones: weniger Halme, weniger Effekte, langsamere Takte.
    @ObservationIgnored var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    /// Läuft nur, solange die App im Vordergrund ist.
    @ObservationIgnored var isActive = true
    @ObservationIgnored private var cachedHour: Double = 12
    @ObservationIgnored private var cachedDaylight: Double = 1
    @ObservationIgnored private var clockTimer: Double = 0

    // MARK: Wetter & Jahreszeit
    /// 0 = blauer Himmel, 1 = grau bedeckt
    @ObservationIgnored var overcast: Double = 0.15
    @ObservationIgnored var fog: Double = 0
    /// fallender Schnee (0…1) und Schneedecke auf der Wiese (0…1)
    @ObservationIgnored var snowAmount: Double = 0
    @ObservationIgnored var snowCover: Double = 0
    @ObservationIgnored var windFactor: Double = 1
    /// Restzeit eines Blitzes (Sekunden)
    @ObservationIgnored var lightning: Double = 0
    /// Außentemperatur (°C), wenn echtes Wetter da ist
    var temperature: Double?
    var weatherKind: RealWeather.Kind?
    @ObservationIgnored var season: Season = .current
    @ObservationIgnored private var weatherTimer: Double = 0
    @ObservationIgnored private var targetRain: Double = 0
    @ObservationIgnored private var targetSnow: Double = 0
    @ObservationIgnored private var targetOvercast: Double = 0.15
    @ObservationIgnored private var targetFog: Double = 0
    @ObservationIgnored private var lastInteraction: Double = 0
    @ObservationIgnored private var powerCheck: Double = 0
    @ObservationIgnored private var backdropTimer: Double = 0
    @ObservationIgnored private var supplyTimer: Double = 60
    @ObservationIgnored private var weatherRefresh: Double = 2

    let light = UIImpactFeedbackGenerator(style: .light)
    let soft = UIImpactFeedbackGenerator(style: .soft)
    let notify = UINotificationFeedbackGenerator()

    init(demo: Bool = GardenDemo.isActive) {
        isDemo = demo
        if demo {
            save = Self.demoSave()
            fixedHour = GardenDemo.screen == "night" ? 22.5 : 10.5
        } else if let loaded = Self.loadFromDisk() {
            save = loaded
        } else {
            save = Self.freshSave()
        }
        inventory = save.inventory
        refreshClock()
        if demo, GardenDemo.screen == "wish" { selectedID = save.rabbits.last?.id }
        for rabbit in save.rabbits { actors[rabbit.id] = RabbitActor() }
        if !demo { catchUp(seconds: Date.now.timeIntervalSince(save.lastSaved)) }
        if !demo { checkWinterSupplies() }
        if !demo { refreshQuestsIfNeeded() }
        if save.rabbits.isEmpty { nextVisitor = 8 }   // erst Begrüßung bzw. Wintervorrat lesen lassen
    }

    // MARK: - Geometrie

    /// Faltbares iPhone aufgeklappt – wird von der Oberfläche gesetzt.
    @ObservationIgnored var unfolded = false
    var isLandscape: Bool { !unfolded && size.width > size.height * 1.15 }
    var lawnTop: CGFloat { size.height * (isLandscape || unfolded ? 0.3 : 0.34) }
    var unit: CGFloat {
        // Aufgeklappt nicht riesig zoomen, sondern mehr Wiese zeigen.
        let base = unfolded ? min(size.width, size.height) * 0.72 : min(size.width, size.height * (isLandscape ? 1.0 : 0.62))
        return min(max(base / 390, 0.8), 1.5)
    }

    func screen(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: x * size.width, y: lawnTop + y * (size.height - lawnTop))
    }

    func world(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x / max(size.width, 1), y: (p.y - lawnTop) / max(size.height - lawnTop, 1))
    }

    func scale(atY y: Double) -> CGFloat { unit * (0.62 + 0.55 * CGFloat(y)) }

    /// Tiefste Stelle, an die Tiere laufen (darunter liegt die Werkzeugleiste).
    var maxY: Double { max(0.5, 1 - Double((isLandscape ? 26 : 150) / max(size.height - lawnTop, 1))) }
    /// Im Querformat stehen die Werkzeuge rechts – dorthin laufen die Tiere nicht.
    var maxX: Double { isLandscape ? min(0.94, 1 - Double(110 / max(size.width, 1))) : 0.94 }

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

    /// Uhrzeit und Tageslicht werden zweimal pro Sekunde berechnet, nicht bei jedem Zugriff.
    var hour: Double { fixedHour ?? cachedHour }
    var daylight: Double { cachedDaylight }

    func refreshClock() {
        let c = Calendar.current.dateComponents([.hour, .minute, .second], from: .now)
        cachedHour = Double(c.hour ?? 12) + Double(c.minute ?? 0) / 60 + Double(c.second ?? 0) / 3600
        cachedDaylight = computeDaylight()
    }

    /// 1 = heller Tag, 0 = tiefe Nacht.
    /// Tageslicht nach echtem Sonnenauf- und -untergang (falls bekannt), sonst nach fester Uhrzeit.
    private func computeDaylight() -> Double {
        let h = hour
        var rise = 6.5, set = 19.5
        if fixedHour == nil, let real = RealWeather.shared.current, let sr = real.sunrise, let ss = real.sunset {
            let cal = Calendar.current
            rise = Double(cal.component(.hour, from: sr)) + Double(cal.component(.minute, from: sr)) / 60
            set = Double(cal.component(.hour, from: ss)) + Double(cal.component(.minute, from: ss)) / 60
        } else if fixedHour == nil {
            switch season {
            case .winter: rise = 8; set = 16.5
            case .sommer: rise = 5.3; set = 21.3
            case .fruehling, .herbst: rise = 6.7; set = 19
            }
        }
        // Dämmerung je etwa eine Stunde um Auf- und Untergang
        if h < rise - 1 || h > set + 1.2 { return 0 }
        if h < rise + 0.8 { return (h - (rise - 1)) / 1.8 }
        if h > set - 0.6 { return 1 - (h - (set - 0.6)) / 1.8 }
        return 1
    }

    /// Kaninchen sind dämmerungsaktiv: morgens und abends am munterster.
    var isTwilight: Bool { daylight > 0.15 && daylight < 0.9 }
    /// Mittagshitze: dösen statt toben.
    var isSiesta: Bool { (11.5..<15.5).contains(hour) && (season == .sommer || (temperature ?? 0) > 24) }
    var isHot: Bool { (temperature ?? 0) >= 28 }
    var isFreezing: Bool { (temperature ?? 5) < 0 || (season == .winter && snowCover > 0.3) }

    var isNight: Bool { daylight < 0.3 }

    // MARK: - Zugriff

    var residents: [GardenRabbit] { save.rabbits.filter { !$0.isVisitor } }
    var capacity: Int { save.ownedHomes.map(\.capacity).max() ?? 4 }
    /// Gemütlichkeit: Deko und Zuhause – erhöht die Chance auf seltene Gäste.
    var cozy: Int { save.decor.reduce(save.home.cozy) { $0 + $1.kind.cozy } }
    var visitor: GardenRabbit? { save.rabbits.first { $0.isVisitor } }

    var selectedRabbit: GardenRabbit? {
        guard let selectedID else { return nil }
        return save.rabbits.first { $0.id == selectedID }
    }

    func index(of id: UUID) -> Int? { save.rabbits.firstIndex { $0.id == id } }

    // MARK: - Schleife

    func run() async {
        lastWall = .now
        light.prepare()
        while !Task.isCancelled {
            // Im Hintergrund oder bei offenem Kontrollzentrum: nichts rechnen.
            // Beim Zurückkommen holt catchUp die verpasste Zeit in einem Schritt nach.
            guard isActive else {
                try? await Task.sleep(for: .milliseconds(500))
                continue
            }
            let now = Date.now
            let gap = now.timeIntervalSince(lastWall)
            lastWall = now
            if gap > 3 {
                catchUp(seconds: gap)
            } else {
                step(min(gap, 0.12))
            }
            // Simulation braucht keine 60 Hz: 30 Hz, im Stromsparmodus oder Leerlauf 20 Hz.
            try? await Task.sleep(for: .milliseconds(frameRate >= 30 ? 33 : 50))
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
            nextFlower = clock + .random(in: 14...30) / max(season.flowers, 0.3)
            if season.flowers > 0, snowCover < 0.4 { spawnFlower() }
        }
        if clock >= nextVisitor {
            // Besuch ist etwas Besonderes: etwa alle 4–9 Minuten.
            nextVisitor = clock + .random(in: 240...540) / arrivalFactor
            if visitor == nil {
                if stationResidents.count < capacity { spawnVisitor() }
                else if !isDemo { showBanner("Die Station ist voll – vermittle Schützlinge, damit neue Fundtiere Platz haben", symbol: "house.fill", duration: 5) }
            }
        }
        if banner != nil, clock > bannerUntil { banner = nil }

        powerCheck += dt
        if powerCheck > 2 {
            powerCheck = 0
            updateFrameRate()
        }
        weatherRefresh -= dt
        if weatherRefresh <= 0 {
            weatherRefresh = 1800
            if !isDemo { Task { await RealWeather.shared.refresh() } }
        }
        backdropTimer -= dt
        if backdropTimer <= 0 {
            backdropTimer = 1
            GardenRenderer.BackdropCache.shared.prepare(self)
        }

        hudTimer += dt
        if hudTimer > 0.4 {
            hudTimer = 0
            hudTick &+= 1
        }
        clockTimer -= dt
        if clockTimer <= 0 {
            clockTimer = 0.5
            refreshClock()
        }
        stationTimer -= dt
        if stationTimer <= 0 {
            stationTimer = 3
            stationTick(elapsed: 3)
        }
        supplyTimer -= dt
        if supplyTimer <= 0 {
            supplyTimer = 60
            if !isDemo { checkWinterSupplies() }
        }
        if clock >= nextSave {
            nextSave = clock + 30
            persist()
        }
    }

    // MARK: - Wetter, Rasen, Beet

    private func updateWeather(_ dt: Double) {
        weatherTimer -= dt
        if weatherTimer <= 0 {
            weatherTimer = 1
            season = .current
            applyRealWeather()
        }
        let ease = min(1, dt * 0.3)
        overcast += (targetOvercast - overcast) * ease
        fog += (targetFog - fog) * ease
        snowAmount += (targetSnow - snowAmount) * ease
        if snowAmount > 0.25 {
            snowCover = min(1, snowCover + dt / 150 * snowAmount)
        } else if (temperature ?? 3) > 1.5 || season != .winter {
            snowCover = max(0, snowCover - dt / 900)
        }
        if lightning > 0 { lightning -= dt }
        if weatherKind == .gewitter, lightning <= 0, Double.random(in: 0...1) < dt * 0.06 {
            lightning = 0.35
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.8)
        }

        guard weatherKind == nil else {
            // echtes Wetter: Regen folgt draußen
            rainAmount += (targetRain - rainAmount) * min(1, dt * 0.4)
            raining = targetRain > 0.2
            return
        }
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

    /// Übernimmt das Wetter von draußen (oder Demo-Wetter für Screenshots).
    private func applyRealWeather() {
        if isDemo {
            switch GardenDemo.screen {
            case "winter":
                setWeather(.schnee, -3)
                targetSnow = 0.8; snowCover = max(snowCover, 0.85); targetOvercast = 0.7; targetRain = 0
            case "rain":
                setWeather(.regen, 12); targetRain = 0.9; targetOvercast = 0.85
            default:
                setWeather(.leichtBewoelkt, 21); targetOvercast = 0.25
            }
            return
        }
        guard let real = RealWeather.shared.current else {
            setWeather(nil, nil)
            targetSnow = 0; targetFog = 0
            targetOvercast = 0.15 + rainAmount * 0.7
            windFactor = 1 + rainAmount * 0.8
            return
        }
        let kind = RealWeather.kind(real)
        if kind != weatherKind, weatherKind != nil || clock > 5 {
            switch kind {
            case .schnee: showBanner("Draußen schneit es – deine Wiese auch", symbol: "cloud.snow.fill", duration: 4)
            case .regen, .starkregen: showBanner("Draußen regnet es – der Rasen freut sich", symbol: "cloud.rain.fill", duration: 4)
            case .gewitter: showBanner("Gewitter! Die Kaninchen bleiben lieber am Zuhause", symbol: "cloud.bolt.rain.fill", duration: 4)
            case .nebel: showBanner("Nebel liegt über der Wiese", symbol: "cloud.fog.fill", duration: 4)
            default: break
            }
        }
        setWeather(kind, real.temperature)
        switch kind {
        case .niesel: targetRain = 0.35
        case .regen: targetRain = 0.7
        case .starkregen, .gewitter: targetRain = 1
        default: targetRain = 0
        }
        targetSnow = kind == .schnee ? (real.precipitation > 1 ? 1 : 0.6) : 0
        targetFog = kind == .nebel ? 0.75 : 0
        targetOvercast = max(real.cloudCover / 100, targetRain > 0 || targetSnow > 0 ? 0.8 : 0)
        windFactor = min(3, 1 + real.wind / 18)
    }

    /// Nur bei echter Änderung setzen – sonst würde die Oberfläche jede Sekunde neu zeichnen.
    private func setWeather(_ kind: RealWeather.Kind?, _ temp: Double?) {
        if weatherKind != kind { weatherKind = kind }
        let rounded = temp.map { ($0 * 2).rounded() / 2 }
        if temperature != rounded { temperature = rounded }
    }

    /// Ganz kurzer Rasen braucht etwa 12 Minuten bis hoch – nass doppelt so schnell.
    private func updateGrass(_ dt: Double) {
        let base = dt / 720
        for k in save.grass.indices {
            if rainAmount > 0.5 { save.wet[k] = min(1, save.wet[k] + dt * 0.2) }
            let w = save.wet[k]
            let growth = season.growth * (snowCover > 0.5 ? 0 : 1) * (isFreezing ? 0.3 : 1)
            save.grass[k] = min(1, save.grass[k] + base * (1 + 1.5 * w) * growth)
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
            let hungerRate = (p == .verfressen ? 0.03 : 0.02) * season.appetite * (isFreezing ? 1.15 : 1)
            var moodRate = (p == .verspielt ? 0.018 : 0.012)
            if r.hunger < 30 { moodRate *= 2 }
            // Fell verfilzt mit der Zeit – je nach Rasse und im Fellwechsel (Frühling, Herbst) schneller.
            let molt = season == .fruehling || season == .herbst ? 1.8 : 1
            r.coat = max(0, r.coatValue - 0.004 * r.look.breed.coatCare * molt * dt)
            if r.coatValue < 30 { moodRate *= 1.5 }
            r.hunger = max(0, r.hunger - hungerRate * dt)
            if a.mode == .sleep {
                r.energy = min(100, r.energy + 0.3 * dt)
            } else {
                r.energy = max(0, r.energy - (p == .verschlafen ? 0.016 : 0.01) * dt * (isTwilight ? 0.6 : 1) * (isSiesta ? 1.5 : 1))
                if isHot, !save.decor.contains(where: { [.busch, .teich, .tunnel].contains($0.kind) && hypot($0.x - r.x, $0.y - r.y) < 0.15 }) {
                    r.mood = max(0, r.mood - 0.01 * dt)   // Hitze ohne Schatten
                }
            }
            r.mood = max(0, r.mood - moodRate * dt)
            if save.decor.contains(where: { hypot($0.x - r.x, $0.y - r.y) < 0.13 }) {
                r.mood = min(100, r.mood + 0.012 * dt)
            }
            // Glückliche Kaninchen bringen Sterne.
            a.incomeTimer -= dt
            if a.incomeTimer <= 0 {
                a.incomeTimer = .random(in: 70...100)
                if r.mood > 55 && a.mode != .sleep {
                    let n = r.rarity.income * (r.isKept ? 2 : 1)
                    inventory.sterne += n
                    let sp = screen(r.x, r.y)
                    floatLabel("+\(n) ★", at: CGPoint(x: sp.x, y: sp.y - 60 * scale(atY: r.y)))
                }
            }
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
        if r.rarity >= .superSelten, a.mode != .hide,
           Double.random(in: 0...1) < dt * (r.rarity == .legendaer ? 2.5 : 0.5) {
            let p = screen(r.x, r.y)
            let s = scale(atY: r.y)
            let at = CGPoint(x: p.x + .random(in: -24...24) * s, y: p.y - .random(in: 5...44) * s - (a.isHopping ? 10 : 0))
            switch r.look.fur {
            case .kirsch: burst(.petal, at: at, count: 1, color: Color(hex: 0xF7B6CB))
            case .mond: burst(.sparkle, at: at, count: 1, color: Color(hex: 0xE4F0FF))
            case .nacht: burst(.sparkle, at: at, count: 1, color: Color(hex: 0xB9C6FF))
            case .gold: burst(.sparkle, at: at, count: 1, color: Color(hex: 0xFFE38A))
            default: burst(.sparkle, at: at, count: 1, color: Color(hex: 0xD9B8FF))
            }
        }

        // Wunsch „kurzer Rasen“ prüfen (etwa einmal pro Sekunde)
        if r.hasOpenWish, r.wish == .kurzerRasen, Double.random(in: 0...1) < dt {
            let near = save.grass.indices.filter {
                let c = cellCenter($0)
                return hypot(Double(c.x) - r.x, Double(c.y) - r.y) < 0.16
            }
            let avg = near.isEmpty ? 1 : near.reduce(0) { $0 + save.grass[$1] } / Double(near.count)
            if avg < 0.3 { fulfillWish(&r, &a) }
        }

        // Gast verlässt den Garten
        if r.isVisitor, a.mode == .leave, r.x < -0.06 || r.x > 1.06 {
            if r.rarity >= .selten {
                showBanner("Der \(r.rarity.title.lowercased())e Gast ist weitergezogen …", symbol: "hare.fill", duration: 4)
            }
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
                if case .futter(let wanted)? = r.wish, wanted == kind, r.wishFulfilled != true {
                    fulfillWish(&r, &a)
                }
                addTrust(&r, &a, kind.trust * bite * (r.personality == .schuechtern ? 0.7 : 1) * r.rarity.trustFactor)
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
        case .hide:
            a.timer -= dt
            r.mood = min(100, r.mood + 0.4 * dt)
            if a.timer > 0 { return }
            // auf der anderen Seite wieder heraus
            if let d = save.decor.first(where: { $0.id == a.decorID }) {
                let side: Double = r.x < d.x ? 1 : -1
                r.x = d.x + side * 0.07
                r.y = d.y + 0.005
                a.facing = CGFloat(side)
            }
            a.mode = .idle
            a.timer = 0.3
            binky(&r, &a)
            return
        case .drink:
            a.timer -= dt
            r.mood = min(100, r.mood + 0.8 * dt)
            r.hunger = min(100, r.hunger + 0.3 * dt)
            if a.timer > 0 { return }
        case .flop, .groom, .idle, .wander, .startled, .enter, .binky:
            a.timer -= dt
            if a.timer > 0 { return }
        case .leave, .seekFood, .seekDecor:
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
            if r.hasOpenWish, case .deko(let wanted)? = r.wish,
               let d = save.decor.first(where: { $0.kind == wanted }) {
                a.mode = .seekDecor
                a.decorID = d.id
                let side: Double = r.x < d.x ? -1 : 1
                a.goal = clampToLawn(CGPoint(x: d.x + side * (d.kind == .teich || d.kind == .feenring ? 0.1 : 0.065), y: d.y + 0.01))
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

        if weatherKind == .gewitter || (r.energy < 22 || (night && r.energy < 85)) {
            a.mode = .sleep
            a.goal = sleepSpot(for: r.id)
            return
        }
        if r.hunger < 75, let food = nearestFood(to: r, within: 2) {
            a.mode = .seekFood; a.foodID = food.id; a.goal = foodSpot(food, for: r); return
        }
        // Heuraufe füttert automatisch aus dem Vorrat.
        if r.hunger < 55, inventory.heu > 0, save.foods.count < 8,
           let rack = save.decor.first(where: { $0.kind == .heuraufe }),
           grassCell(near: r).map({ hypot(cellCenter($0).x - CGFloat(r.x), cellCenter($0).y - CGFloat(r.y)) > 0.3 }) ?? true {
            inventory.heu -= 1
            let food = GardenFood(kind: .heu, x: rack.x, y: min(maxY, rack.y + 0.03))
            save.foods.append(food)
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
        // Hitze: in den Schatten (Busch, Teich, Tunnel)
        if isHot, roll < 0.5, let shade = save.decor.filter({ [.busch, .teich, .tunnel].contains($0.kind) }).randomElement() {
            a.mode = .seekDecor
            a.decorID = shade.id
            let side: Double = r.x < shade.x ? -1 : 1
            a.goal = clampToLawn(CGPoint(x: shade.x + side * 0.07, y: shade.y + 0.01))
            return
        }
        var playful = r.personality == .verspielt ? 0.3 : 0.15
        if isTwilight { playful *= 2 }               // morgens und abends am muntersten
        if isSiesta || isFreezing { playful *= 0.4 }
        if isSiesta, roll < 0.35 {
            a.mode = .flop
            a.timer = .random(in: 10...20)
            return
        }
        if r.mood > 75 && roll < playful {
            binky(&r, &a)
            return
        }
        if r.mood > 65 && !raining && daylight > 0.6 && roll < playful + 0.12 {
            a.mode = .flop
            a.timer = .random(in: 6...14)
            return
        }
        // Partner suchen die Nähe des anderen
        if let pid = r.partner, roll < 0.32, let partner = save.rabbits.first(where: { $0.id == pid }) {
            a.mode = .wander
            let side: Double = r.x < partner.x ? -1 : 1
            a.goal = clampToLawn(CGPoint(x: partner.x + side * 0.07, y: partner.y + .random(in: -0.02...0.02)))
            return
        }
        if roll < 0.2, let d = save.decor.randomElement() {
            a.mode = .seekDecor
            a.decorID = d.id
            let side: Double = r.x < d.x ? -1 : 1
            a.goal = clampToLawn(CGPoint(x: d.x + side * (d.kind == .teich ? 0.1 : 0.065), y: d.y + 0.01))
        } else if roll < 0.5 {
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
        case .seekDecor:
            guard let d = save.decor.first(where: { $0.id == a.decorID }) else { a.mode = .idle; a.timer = 1; break }
            a.facing = d.x >= r.x ? 1 : -1
            if r.hasOpenWish, case .deko(let wanted)? = r.wish, wanted == d.kind { fulfillWish(&r, &a) }
            switch d.kind {
            case .tunnel:
                a.mode = .hide
                a.timer = .random(in: 2.5...5)
                r.x = d.x
                r.y = d.y
            case .teich:
                a.mode = .drink
                a.timer = .random(in: 3...5)
            case .feenring:
                r.mood = min(100, r.mood + 8)
                binky(&r, &a)
            default:
                r.mood = min(100, r.mood + 4)
                a.mode = Bool.random() ? .flop : .groom
                a.timer = .random(in: 3...7)
            }
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
        if stationResidents.count >= capacity {
            r.trust = 99
            showBanner("Kein Platz mehr – ein größeres Zuhause gibt's im Shop", symbol: "house.fill", duration: 5)
            return
        }
        r.isVisitor = false
        r.leaveAt = nil
        r.friendship = 25
        r.joined = .now
        let used = Set(save.rabbits.map(\.name))
        let pool = r.rarity == .legendaer ? (GardenRabbit.legendaryNames[r.look.fur] ?? GardenRabbit.names) : GardenRabbit.names
        r.name = pool.filter { !used.contains($0) }.randomElement() ?? GardenRabbit.names.randomElement()!
        inventory.sterne += r.rarity.reward
        track(.zaehmen(r.rarity))
        gainXP([15, 30, 60, 120][r.rarity.rawValue])
        a.mode = .idle
        a.timer = 1.5
        let p = screen(r.x, r.y)
        burst(.confetti, at: CGPoint(x: p.x, y: p.y - 30), count: 36 + 30 * r.rarity.rawValue, color: .white)
        floatLabel("+\(r.rarity.reward) ★", at: CGPoint(x: p.x, y: p.y - 70))
        burst(.heart, at: CGPoint(x: p.x, y: p.y - 30), count: 6, color: .pink)
        notify.notificationOccurred(.success)
        selectedID = r.id
        celebrate &+= 1
        showBanner(r.rarity == .gewoehnlich ? "\(r.name) zieht auf die Mümmelwiese!"
                   : "\(r.rarity.title)! \(r.name) zieht auf die Mümmelwiese!", symbol: r.rarity.symbol, duration: 5)
        if save.tutorialStep < 2 {
            save.tutorialStep = 2
            requestNotificationPermission()
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(6))
                self?.showBanner("Langer Rasen ist Futter. Gemähter Rasen gibt Heu.", symbol: "scissors", duration: 6)
            }
        }
    }

    /// Vertrauen wächst – mit offenem Wunsch aber höchstens bis 60.
    private func addTrust(_ r: inout GardenRabbit, _ a: inout RabbitActor, _ amount: Double) {
        let cap: Double = r.hasOpenWish ? 60 : 100
        let before = r.trust
        // Eigene Kaninchen beruhigen Neuankömmlinge – wie echte Begleitkaninchen.
        let calm = 1 + min(0.6, Double(keptRabbits.count) * 0.15)
        r.trust = min(cap, r.trust + amount * calm)
        if r.hasOpenWish, before < cap, r.trust >= cap, r.id == selectedID || save.tutorialStep < 3 {
            showBanner("Fast! Erst den Wunsch erfüllen: \(r.wish!.text.lowercased())", symbol: r.wish!.symbol, duration: 4)
        }
        if r.trust >= 100 { befriend(&r, &a) }
    }

    private func fulfillWish(_ r: inout GardenRabbit, _ a: inout RabbitActor) {
        guard r.hasOpenWish else { return }
        r.wishFulfilled = true
        track(.wunsch)
        gainXP(20)
        let p = screen(r.x, r.y)
        burst(.sparkle, at: CGPoint(x: p.x, y: p.y - 50), count: 14, color: Color(hex: 0xFFE38A))
        burst(.heart, at: CGPoint(x: p.x, y: p.y - 40), count: 3, color: .pink)
        notify.notificationOccurred(.success)
        showBanner("Wunsch erfüllt! Jetzt fasst es richtig Vertrauen.", symbol: "checkmark.seal.fill", duration: 4)
        if save.tutorialStep < 3 { save.tutorialStep = 3 }
        addTrust(&r, &a, 35)
        hudTick &+= 1
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
        if snowCover > 0.6 { return nil }   // unter Schnee kein Gras – jetzt hilft nur Heu
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
        var q = CGPoint(x: min(CGFloat(maxX), max(CGFloat(0.06), p.x)), y: min(CGFloat(maxY), max(CGFloat(0.05), p.y)))
        // nicht ins Beet
        if Self.bedRect.contains(q) { q.y = Self.bedRect.maxY + 0.02 }
        return q
    }

    // MARK: - Besuch & Blumen

    private func spawnVisitor(preset: PendingVisit? = nil) {
        let lucky = save.luckyClover
        if preset == nil { save.luckyClover = false }
        let rarity = preset?.rarity ?? gatedRarity(Rarity.roll(cozy: cozy, lucky: lucky), lucky: lucky)
        let look = preset?.look ?? RabbitLook.random(rarity)
        let fromLeft = Bool.random()
        let y = Double.random(in: 0.25...min(0.7, maxY))
        var r = GardenRabbit(name: "Gast", look: look, rarity: rarity,
                             personality: preset?.personality ?? GardenPersonality.allCases.randomElement()!)
        r.x = fromLeft ? -0.06 : 1.06
        r.y = y
        r.isVisitor = true
        r.leaveAt = nil   // Fundtiere bleiben, bis sie Vertrauen gefasst haben
        r.trust = 0
        r.coat = .random(in: 40...85)
        if save.tutorialStep > 0, Double.random(in: 0...1) < rarity.wishChance {
            r.wish = VisitorWish.random(for: rarity)
            r.wishFulfilled = false
            r.wishProgress = 0
        }
        if r.wish == .buersten { r.coat = 12 }
        var a = RabbitActor()
        a.mode = .enter
        a.facing = fromLeft ? 1 : -1
        a.goal = CGPoint(x: fromLeft ? .random(in: 0.2...0.4) : .random(in: 0.6...0.8), y: y)
        save.rabbits.append(r)
        actors[r.id] = a
        save.visitorsSeen += 1
        if save.metRarities.count < 4 { save.metRarities = [0, 0, 0, 0] }
        save.metRarities[rarity.rawValue] += 1
        let new = !save.discoveredFurs.contains(look.fur) || !save.discoveredPatterns.contains(look.pattern)
            || !save.discoveredBreeds.contains(look.breed)
        save.discoveredFurs.insert(look.fur)
        save.discoveredPatterns.insert(look.pattern)
        save.discoveredBreeds.insert(look.breed)
        register(look)
        if rarity >= .superSelten { notify.notificationOccurred(.success) } else { soft.impactOccurred() }

        let how = ["Ein Fundtier wurde abgegeben", "Edith hat ein Kaninchen am Feldrand gefunden",
                   "Jemand hat ein Kaninchen vor der Station ausgesetzt", "Ein Kaninchen wurde aus schlechter Haltung gerettet",
                   "Die Feuerwehr bringt ein entlaufenes Kaninchen"].randomElement()!
        if save.tutorialStep == 0 {
            save.tutorialStep = 1
            showBanner("Ein Fundtier! Es ist noch ängstlich – leg Futter hin oder streichle es ganz vorsichtig.", symbol: "hare.fill", duration: 7)
        } else {
            switch rarity {
            case .legendaer:
                showBanner("LEGENDÄR! Ein \(look.fur.title)-Kaninchen sucht Schutz in deiner Station …", symbol: "crown.fill", duration: 7)
            case .superSelten:
                showBanner("\(how): super selten – \(look.description)!", symbol: "star.fill", duration: 6)
            case .selten:
                showBanner("\(how) – \(new ? "neu im Sammelbuch!" : look.description)", symbol: "diamond.fill", duration: 5)
            case .gewoehnlich:
                showBanner("\(how)\(new ? " – neu im Sammelbuch!" : "")", symbol: "hare.fill", duration: 5)
            }
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

    /// 30 Bilder/s beim Spielen, 20 nach einer Minute ohne Berührung, 15 im Stromsparmodus.
    private func updateFrameRate() {
        lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        let idle = clock - lastInteraction > 60 && particles.isEmpty
        let target = lowPower ? 15 : (idle ? 20 : 30)
        if target != frameRate { frameRate = target }
    }

    func touchBegan(_ p: CGPoint) {
        lastInteraction = clock
        if frameRate < 30 && !lowPower { frameRate = 30 }
        touchStart = p
        lastTouch = p
        pettingID = tool == .hand ? rabbitID(at: p) : nil
        brushingID = tool == .buerste ? rabbitID(at: p) : nil
        if tool == .buerste { toolPoint = p }
        if tool == .gestalten {
            draggingDecorID = decorID(at: p)
            if let id = draggingDecorID { selectedDecorID = id; placing = nil }
        }
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
        case .futter, .foto:
            break
        case .buerste:
            toolPoint = p
            if brushingID == nil { brushingID = rabbitID(at: p) }
            if let id = brushingID { brush(id, distance: hypot(p.x - last.x, p.y - last.y), at: p) }
        case .gestalten:
            if let id = draggingDecorID, let i = save.decor.firstIndex(where: { $0.id == id }) {
                let w = clampToLawn(world(p))
                save.decor[i].x = Double(w.x)
                save.decor[i].y = Double(w.y)
            }
        }
    }

    func touchEnded(_ p: CGPoint) {
        let start = touchStart ?? p
        let isTap = hypot(p.x - start.x, p.y - start.y) < 12
        toolPoint = nil
        touchStart = nil
        lastTouch = nil
        pettingID = nil
        brushingID = nil
        let dragged = draggingDecorID
        draggingDecorID = nil
        guard isTap else {
            if dragged != nil { light.impactOccurred(); hudTick &+= 1 }
            return
        }
        switch tool {
        case .hand: tap(p)
        case .futter: placeFood(at: world(p))
        case .foto:
            if let id = rabbitID(at: p) { takePhoto(of: id) }
            else { showBanner("Tipp auf ein Kaninchen, um es zu fotografieren", symbol: "camera.fill", duration: 2.5) }
        case .gestalten:
            if dragged != nil { light.impactOccurred(); return }
            if let kind = placing { placeDecor(kind, at: world(p)) } else { selectedDecorID = nil }
        default: break
        }
    }

    private func rabbitID(at p: CGPoint) -> UUID? {
        var best: (UUID, CGFloat)?
        for r in save.rabbits {
            let s = scale(atY: r.y) * r.look.breed.bodyScale * 1.2
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
                    addTrust(&r, &a, 3)
                } else {
                    addTrust(&r, &a, 9 * r.rarity.trustFactor)
                    burst(.heart, at: CGPoint(x: p.x, y: p.y - 10), count: 1, color: .pink)
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
                track(.pfluecken)
                gainXP(1)
                floatLabel("+1 Löwenzahn", at: p)
            case .gaensebluemchen:
                track(.pfluecken)
                gainXP(1)
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
                inventory.sterne += 2
                track(.ernten, bonus)
                gainXP(4)
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

    /// Bürsten: lose Haare fliegen, das Fell wird glatt und glänzt.
    private func brush(_ id: UUID, distance: Double, at p: CGPoint) {
        guard let i = index(of: id) else { return }
        var r = save.rabbits[i]
        var a = actors[id] ?? RabbitActor()
        guard a.mode != .startled, !a.isHopping else { return }
        // Scheue Neuankömmlinge erschrecken sich anfangs leicht.
        if r.isVisitor && r.trust < 30 && r.personality == .schuechtern && Double.random(in: 0...1) < 0.02 {
            startle(&r, &a, from: world(p))
            brushingID = nil
            save.rabbits[i] = r
            actors[id] = a
            return
        }
        a.pettedUntil = clock + 0.7
        if a.mode == .wander { a.goal = nil; a.mode = .idle }
        a.timer = max(a.timer, 1)
        brushDistance += distance
        if Double.random(in: 0...1) < 0.35 {
            burst(.fluff, at: CGPoint(x: p.x + .random(in: -8...8), y: p.y - 6), count: 1, color: r.look.fur.main)
        }
        if brushDistance > 34 {
            brushDistance = 0
            let before = r.coatValue
            let gain = r.personality == .verschmust ? 7.0 : 5.5
            r.coat = min(100, before + gain)
            r.mood = min(100, r.mood + 1.5)
            soft.impactOccurred(intensity: 0.45)
            if r.isVisitor {
                if r.wish == .buersten, r.wishFulfilled != true, r.coatValue >= 85 { fulfillWish(&r, &a) }
                addTrust(&r, &a, 2.5 * r.rarity.trustFactor)
            } else {
                r.friendship = min(100, r.friendship + 0.4)
            }
            track(.buersten)
            gainXPFraction(0.4)
            if before < 100, r.coatValue >= 100 {
                burst(.sparkle, at: CGPoint(x: p.x, y: p.y - 20), count: 8, color: .white)
                floatLabel("Glänzt ✨", at: CGPoint(x: p.x, y: p.y - 40))
            }
        }
        save.rabbits[i] = r
        actors[id] = a
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
                    if r.wish == .streicheln, r.wishFulfilled != true {
                        r.wishProgress = (r.wishProgress ?? 0) + love
                        if (r.wishProgress ?? 0) >= 10 { fulfillWish(&r, &a) }
                    }
                    addTrust(&r, &a, 4 * love * r.rarity.trustFactor)
                } else {
                    r.mood = min(100, r.mood + 3 * love)
                    r.friendship = min(100, r.friendship + 0.8 * love)
                }
                burst(.heart, at: CGPoint(x: p.x, y: p.y - 14), count: 1, color: Color(hex: 0xF27A9B))
                track(.streicheln)
                gainXPFraction(0.5)
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
        var cutCells = 0
        defer { if cutCells > 0 { track(.maehen, cutCells); gainXPFraction(Double(cutCells) * 0.25) } }
        for k in cells(around: p, rx: 0.075, ry: 0.06) {
            let c = cellCenter(k)
            if Self.bedRect.insetBy(dx: -0.01, dy: -0.01).contains(c) { continue }
            if save.grass[k] > 0.16 {
                cutCells += 1
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
        var watered = 0
        for k in cells(around: p, rx: 0.07, ry: 0.055) {
            if save.wet[k] < 0.5 { watered += 1 }
            save.wet[k] = 1
        }
        if watered > 0 { track(.giessen, watered); gainXPFraction(Double(watered) * 0.2) }
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

    // MARK: - Gestalten & Shop

    func decorID(at p: CGPoint) -> UUID? {
        var best: (UUID, CGFloat)?
        for d in save.decor {
            let c = screen(d.x, d.y)
            let s = scale(atY: d.y)
            let size: CGFloat = d.kind == .teich || d.kind == .feenring ? 52 : 34
            let dist = hypot(p.x - c.x, (p.y - (c.y - 14 * s)) * 1.2)
            if dist < size * s, best == nil || dist < best!.1 { best = (d.id, dist) }
        }
        return best?.0
    }

    private func placeDecor(_ kind: DecorKind, at w: CGPoint) {
        guard save.stock(kind) > 0 else { placing = nil; return }
        let p = clampToLawn(w)
        save.decorStock[kind.rawValue] = save.stock(kind) - 1
        track(.deko)
        gainXP(3)
        let d = GardenDecor(kind: kind, x: Double(p.x), y: Double(p.y))
        save.decor.append(d)
        selectedDecorID = d.id
        burst(.sparkle, at: screen(d.x, d.y), count: 8, color: .white)
        light.impactOccurred()
        if save.stock(kind) == 0 { placing = nil }
        hudTick &+= 1
    }

    func packAway(_ id: UUID) {
        guard let i = save.decor.firstIndex(where: { $0.id == id }) else { return }
        let d = save.decor.remove(at: i)
        save.decorStock[d.kind.rawValue] = save.stock(d.kind) + 1
        selectedDecorID = nil
        soft.impactOccurred()
        hudTick &+= 1
    }

    /// Futter, das gerade angezeigt wird: Zweige nur im Winter oder wenn welche da sind.
    var availableFoods: [GardenFoodKind] {
        GardenFoodKind.allCases.filter { $0 != .zweige || inventory.zweige > 0 || season == .winter }
    }

    /// Seltenheit nach Stationslevel begrenzen (Glücksklee erlaubt eine Stufe mehr).
    func gatedRarity(_ r: Rarity, lucky: Bool) -> Rarity {
        var cap = Progression.maxRarity(level: level)
        if lucky, let up = Rarity(rawValue: min(3, cap.rawValue + 1)) { cap = up }
        return min(r, cap)
    }

    /// Nach Weihnachten und Ostern werden besonders viele Kaninchen abgegeben – wie in echten Tierheimen.
    var arrivalFactor: Double {
        let month = Calendar.current.component(.month, from: .now)
        return month == 1 || month == 4 ? 1.6 : 1
    }

    func gainXPFraction(_ amount: Double) {
        xpCarry += amount
        if xpCarry >= 1 {
            let whole = Int(xpCarry)
            xpCarry -= Double(whole)
            gainXP(whole)
        }
    }

    /// Im Winter wächst kaum etwas – niemand soll ohne Futter dastehen.
    /// 1) Zu Beginn jedes Winters (und beim ersten Start im Winter) ein geschenkter Vorrat samt Heuraufe.
    /// 2) Sind Heu und Zweige leer, hilft einmal am Tag Nachbarin Edith aus.
    func checkWinterSupplies() {
        let cal = Calendar.current
        let now = Date.now
        guard season == .winter || snowCover > 0.6 else { return }
        let month = cal.component(.month, from: now)
        let winterYear = cal.component(.year, from: now) - (month <= 2 ? 1 : 0)

        if season == .winter, save.winterGiftYear != winterYear {
            save.winterGiftYear = winterYear
            inventory.heu += 25
            inventory.zweige += 8
            inventory.moehre += 2
            var extra = ""
            if save.owned(.heuraufe) < DecorKind.heuraufe.limit && !save.decor.contains(where: { $0.kind == .heuraufe }) {
                save.decorStock[DecorKind.heuraufe.rawValue] = save.stock(.heuraufe) + 1
                extra = " und eine Heuraufe (unter „Gestalten“)"
            }
            notify.notificationOccurred(.success)
            showBanner("Wintervorrat geschenkt: 25 Heu, 8 Apfelzweige, 2 Möhren\(extra) ❄️", symbol: "gift.fill", duration: 7)
            hudTick &+= 1
            persist()
            return
        }

        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let today = f.string(from: now)
        if inventory.heu + inventory.zweige == 0, save.lastAidDay != today {
            save.lastAidDay = today
            inventory.heu += 15
            inventory.zweige += 3
            showBanner("Nachbarin Edith hat dir 15 Heu und 3 Apfelzweige vorbeigebracht 🧺", symbol: "gift.fill", duration: 6)
            hudTick &+= 1
            persist()
        }
    }

    func buyFood(_ kind: GardenFoodKind) {
        guard let bundle = kind.shopBundle, inventory.sterne >= bundle.price else { return }
        inventory.sterne -= bundle.price
        inventory[kind] += bundle.amount
        notify.notificationOccurred(.success)
        hudTick &+= 1
    }

    func buy(_ kind: DecorKind) {
        guard inventory.sterne >= kind.price, save.owned(kind) < kind.limit else { return }
        inventory.sterne -= kind.price
        save.decorStock[kind.rawValue] = save.stock(kind) + 1
        tool = .gestalten
        placing = kind
        notify.notificationOccurred(.success)
        showBanner("\(kind.title) gekauft – tipp auf die Wiese zum Aufstellen", symbol: kind.symbol, duration: 4)
        hudTick &+= 1
        persist()
    }

    func chooseHome(_ style: HomeStyle) {
        if !save.ownedHomes.contains(style) {
            guard inventory.sterne >= style.price else { return }
            inventory.sterne -= style.price
            save.ownedHomes.insert(style)
            notify.notificationOccurred(.success)
            showBanner("\(style.title)! Jetzt ist Platz für \(capacity) Kaninchen.", symbol: "house.fill", duration: 5)
            let c = screen(Self.hutch.x, Self.hutch.y)
            burst(.confetti, at: CGPoint(x: c.x, y: c.y - 40), count: 40, color: .white)
        }
        save.home = style
        hudTick &+= 1
        persist()
    }

    // MARK: - Füttern

    func placeFood(at w: CGPoint, kind: GardenFoodKind? = nil) {
        let kind = kind ?? foodChoice
        guard inventory[kind] > 0 else {
            let text: String = switch kind {
            case .moehre: "Keine Möhren – säe welche im Beet oder kauf sie im Shop"
            case .heu: season == .winter ? "Kein Heu – im Shop gibt es Nachschub" : "Kein Heu – mäh den Rasen"
            case .loewenzahn: "Kein Löwenzahn – pflück gelbe Blüten"
            case .zweige: "Keine Apfelzweige – die gibt es im Shop"
            }
            showBanner(text, symbol: kind.symbol)
            return
        }
        guard save.foods.count < 8 else { showBanner("Erst mal aufessen lassen", symbol: "hare.fill"); return }
        let p = clampToLawn(w)
        inventory[kind] -= 1
        track(.futtern(kind))
        gainXP(1)
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
            case .fluff:
                // lose Fellbüschel schweben langsam davon
                part.v = CGVector(dx: .random(in: -35...35), dy: .random(in: -40 ... -5))
                part.gravity = 18
                part.spin = .random(in: -1.5...1.5)
                part.life = .random(in: 1.2...2)
            case .zzz, .label:
                part.v = CGVector(dx: 0, dy: -30)
                part.life = 1.4
            }
            part.maxLife = part.life
            particles.append(part)
        }
    }

    func floatLabel(_ text: String, at p: CGPoint) {
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
            save.grass[k] = min(1, save.grass[k] + t / 720 * (1 + save.wet[k]) * season.growth * (snowCover > 0.5 ? 0 : 1))
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
            r.coat = max(min(r.coatValue, 25), r.coatValue - t * 0.004 * r.look.breed.coatCare)
            r.hunger = min(100, r.hunger)
            r.mood = max(min(r.mood, 40), r.mood - t * 0.012)
            r.energy = t > 1800 ? max(r.energy, 85) : r.energy
            save.rabbits[i] = r
            actors[r.id] = RabbitActor()
        }
        // Gäste gehen irgendwann wieder.
        save.rabbits.removeAll { $0.isVisitor && ($0.leaveAt.map { $0 < .now } ?? false) }
        if selectedID != nil, selectedRabbit == nil { selectedID = nil }

        let earned = min(400, Int(t / 180) * residents.reduce(0) { $0 + $1.rarity.income })
        if earned > 0 { inventory.sterne += earned }

        let newFlowers = season.flowers > 0 ? min(6, Int(t / 90 * season.flowers)) : 0
        for _ in 0..<newFlowers { spawnFlower() }

        let resolved = resolveAwayVisit()
        if t > 1200 {
            // Manchmal wartet schon jemand, wenn man zurückkommt.
            if !resolved, visitor == nil, Double.random(in: 0...1) < 0.4 { nextVisitor = min(nextVisitor, clock + 3) }
            if !residents.isEmpty {
                showBanner(earned > 0 ? "Willkommen zurück! Deine Kaninchen haben \(earned) ★ gesammelt."
                           : "Willkommen zurück! Der Rasen ist gewachsen.", symbol: "star.fill", duration: 5)
            }
        }
        hudTick &+= 1
    }

    // MARK: Besuch während die App zu ist (mit Mitteilung bei seltenen Gästen)

    static let notifyKey = "muemmelwiese.notifyRare"
    static var notificationsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: notifyKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: notifyKey) }
    }

    func requestNotificationPermission() {
        guard !isDemo, Self.notificationsEnabled else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Beim Verlassen der App: den nächsten Besuch schon auswürfeln.
    /// Super seltene und legendäre Gäste melden sich zur Ankunft mit einer Mitteilung.
    func prepareForBackground() {
        persist()
        guard !isDemo, visitor == nil, save.tutorialStep >= 1 else { return }
        let rarity = gatedRarity(Rarity.roll(cozy: cozy, lucky: save.luckyClover), lucky: save.luckyClover)
        if save.luckyClover { save.luckyClover = false }
        let pending = PendingVisit(arrive: Date.now.addingTimeInterval(.random(in: 20 * 60...90 * 60)),
                                   rarity: rarity, look: RabbitLook.random(rarity),
                                   personality: GardenPersonality.allCases.randomElement()!)
        save.pendingVisit = pending
        persist()
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["visit"])
        guard rarity >= .superSelten, Self.notificationsEnabled else { return }
        let content = UNMutableNotificationContent()
        if rarity == .legendaer {
            content.title = "👑 Legendärer Besuch!"
            content.body = "Ein \(pending.look.fur.title)-Kaninchen hoppelt über deine Mümmelwiese – es bleibt nicht lange."
        } else {
            content.title = "⭐ Super seltener Besuch"
            content.body = "Ein \(pending.look.description) schaut auf deiner Mümmelwiese vorbei."
        }
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: pending.arrive.timeIntervalSinceNow, repeats: false)
        center.add(UNNotificationRequest(identifier: "visit", content: content, trigger: trigger))
    }

    /// Beim Zurückkommen: Ist der ausgewürfelte Gast schon da (und noch nicht wieder weg)?
    @discardableResult
    private func resolveAwayVisit() -> Bool {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["visit"])
        guard let pending = save.pendingVisit else { return false }
        save.pendingVisit = nil
        guard Date.now >= pending.arrive else { return false }
        if visitor == nil, stationResidents.count < capacity {
            spawnVisitor(preset: pending)
            return true
        }
        if pending.rarity >= .superSelten {
            showBanner("Verpasst: Ein \(pending.rarity.title.lowercased())er Gast war da, während du weg warst.",
                       symbol: pending.rarity.symbol, duration: 5)
        }
        return false
    }

    // MARK: Speicherort
    // Der Spielstand liegt als Datei im App-Ordner (mit Sicherungskopie des vorigen Stands).

    static var saveURL: URL { URL.documentsDirectory.appending(path: "muemmelwiese.json") }
    static var backupURL: URL { URL.documentsDirectory.appending(path: "muemmelwiese-vorher.json") }

    /// Zuletzt gespeichert (für die Anzeige im Menü).
    var lastSavedAt: Date?

    static func decode(_ data: Data) -> GardenSave? {
        guard let loaded = try? JSONDecoder().decode(GardenSave.self, from: data),
              loaded.grass.count == GardenSave.cols * GardenSave.rows else { return nil }
        return loaded
    }

    private static func loadFromDisk() -> GardenSave? {
        if let data = try? Data(contentsOf: saveURL), let s = decode(data) { return s }
        if let data = try? Data(contentsOf: backupURL), let s = decode(data) { return s }
        // ältere Versionen speicherten in den Einstellungen
        if let data = UserDefaults.standard.data(forKey: saveKey), let s = decode(data) { return s }
        return nil
    }

    private static func freshSave() -> GardenSave {
        var s = GardenSave()
        s.flowers = (0..<5).map { _ in
            GardenFlower(kind: Bool.random() ? .gaensebluemchen : .loewenzahn,
                         x: .random(in: 0.08...0.92), y: .random(in: 0.2...0.75))
        }
        return s
    }

    /// Aktueller Spielstand als Daten (für „In Dateien sichern“).
    func snapshot() -> Data {
        save.inventory = inventory
        save.lastSaved = .now
        return (try? JSONEncoder().encode(save)) ?? Data()
    }

    func persist() {
        guard !isDemo else { return }
        let data = snapshot()
        guard !data.isEmpty else { return }
        let fm = FileManager.default
        if fm.fileExists(atPath: Self.saveURL.path()) {
            try? fm.removeItem(at: Self.backupURL)
            try? fm.copyItem(at: Self.saveURL, to: Self.backupURL)
        }
        do {
            try data.write(to: Self.saveURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            lastSavedAt = .now
        } catch {
            UserDefaults.standard.set(data, forKey: Self.saveKey)   // Notlösung
        }
    }

    /// „Jetzt speichern“ aus dem Menü.
    func saveNow() {
        persist()
        notify.notificationOccurred(.success)
        showBanner(isDemo ? "Demo – wird nicht gespeichert" : "Spielstand gespeichert", symbol: "checkmark.circle.fill", duration: 2.5)
    }

    /// Spielstand aus einer Datei laden (ersetzt den aktuellen).
    func load(from url: URL) -> Bool {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), let loaded = Self.decode(data) else {
            showBanner("Diese Datei ist kein Mümmelwiese-Spielstand", symbol: "exclamationmark.triangle.fill", duration: 4)
            return false
        }
        replace(with: loaded)
        showBanner("Spielstand geladen – \(residents.count) Kaninchen", symbol: "tray.and.arrow.down.fill", duration: 4)
        return true
    }

    func newGame() {
        replace(with: Self.freshSave())
        nextVisitor = clock + 3
        showBanner("Neue Wiese – bald kommt der erste Besuch", symbol: "leaf.fill", duration: 4)
    }

    private func replace(with newSave: GardenSave) {
        save = newSave
        inventory = newSave.inventory
        actors = [:]
        for rabbit in save.rabbits { actors[rabbit.id] = RabbitActor() }
        particles.removeAll()
        selectedID = nil
        selectedDecorID = nil
        placing = nil
        tool = .hand
        lastWall = .now
        persist()
        hudTick &+= 1
    }

    // MARK: - Demo (Screenshots)

    private static func demoSave() -> GardenSave {
        var s = GardenSave()
        for k in s.grass.indices {
            let i = k % GardenSave.cols
            s.grass[k] = i < 5 ? 0.12 : 0.85
        }
        let looks: [(String, RabbitLook, Rarity, GardenPersonality, Double, Double)] = [
            ("Mümmel", RabbitLook(fur: .wildfarben, pattern: .einfarbig, breed: .stehohr, accent: .schwarz), .gewoehnlich, .verfressen, 0.3, 0.3),
            ("Flocke", RabbitLook(fur: .weiss, pattern: .einfarbig, breed: .hermelin, accent: .schwarz), .superSelten, .verschmust, 0.6, 0.46),
            ("Keks", RabbitLook(fur: .schwarz, pattern: .japaner, breed: .widder, accent: .schoko), .superSelten, .verspielt, 0.74, 0.62),
            ("Bruno", RabbitLook(fur: .sand, pattern: .thueringer, breed: .riese, accent: .schoko), .superSelten, .verschlafen, 0.2, 0.66),
            ("Sakura", RabbitLook(fur: .kirsch, pattern: .einfarbig, breed: .loewenkopf, accent: .schoko), .legendaer, .neugierig, 0.45, 0.72),
            ("Orion", RabbitLook(fur: .nacht, pattern: .blesse, breed: .stehohr, accent: .grau), .legendaer, .verschlafen, 0.84, 0.3),
        ]
        s.rabbits = looks.map { name, look, rarity, pers, x, y in
            var r = GardenRabbit(name: name, look: look, rarity: rarity, personality: pers)
            r.x = x; r.y = y
            r.hunger = 70; r.mood = 85; r.energy = 90; r.friendship = 60
            return r
        }
        var guest = GardenRabbit(name: "Gast", look: RabbitLook(fur: .schoko, pattern: .loh, breed: .angora, accent: .schwarz),
                                 rarity: .selten, personality: .schuechtern)
        guest.x = 0.62; guest.y = 0.24
        guest.isVisitor = true
        guest.trust = 45
        guest.leaveAt = Date.now.addingTimeInterval(600)
        guest.wish = .futter(.loewenzahn)
        guest.wishFulfilled = false
        s.rabbits.append(guest)
        s.flowers = [
            GardenFlower(kind: .loewenzahn, x: 0.62, y: 0.4),
            GardenFlower(kind: .gaensebluemchen, x: 0.85, y: 0.5),
            GardenFlower(kind: .gluecksklee, x: 0.68, y: 0.22),
        ]
        s.decor = [
            GardenDecor(kind: .teich, x: 0.42, y: 0.42),
            GardenDecor(kind: .tunnel, x: 0.12, y: 0.42),
            GardenDecor(kind: .busch, x: 0.92, y: 0.14),
            GardenDecor(kind: .laterne, x: 0.33, y: 0.12),
            GardenDecor(kind: .sonnenblumen, x: 0.9, y: 0.8),
            GardenDecor(kind: .pilz, x: 0.6, y: 0.76),
            GardenDecor(kind: .gartenzwerg, x: 0.58, y: 0.13),
            GardenDecor(kind: .feenring, x: 0.2, y: 0.7),
            GardenDecor(kind: .heuraufe, x: 0.5, y: 0.22),
        ]
        s.home = .cottage
        s.ownedHomes = [.holzstall, .cottage]
        s.foods = [GardenFood(kind: .moehre, x: 0.4, y: 0.68)]
        s.bed = [CarrotSlot(planted: .now, growth: 1), CarrotSlot(planted: .now, growth: 0.5), CarrotSlot()]
        s.tutorialStep = 3
        s.metRarities = [14, 6, 2, 2]
        s.discoveredFurs = [.wildfarben, .weiss, .sand, .kirsch, .nacht, .grau, .schoko]
        s.discoveredPatterns = [.einfarbig, .russe, .hollaender, .blesse]
        s.discoveredBreeds = [.stehohr, .zwerg, .widder, .loewenkopf]
        s.visitorsSeen = 24
        s.inventory = GardenInventory(heu: 14, loewenzahn: 3, moehre: 2, sterne: 236)
        // Station für Screenshots
        s.level = 7
        s.xp = 140
        s.followers = 486
        s.quests = GardenQuest.daily(level: 7, season: .herbst, residents: 6, decorOwned: true)
        if var q = s.quests?.first { q.progress = q.target; s.quests?[0] = q }
        let residents = s.rabbits.filter { !$0.isVisitor }
        s.adopters = [
            Adopter.random(level: 7, residents: residents, taken: [], via: residents.first { $0.name == "Keks" }),
            Adopter.random(level: 7, residents: residents, taken: [], via: residents.first { $0.name == "Mümmel" }),
        ]
        s.adoptions = [
            AdoptionRecord(name: "Hazel", look: RabbitLook(fur: .grau, pattern: .einfarbig, breed: .widder, accent: .schwarz),
                           rarity: .gewoehnlich, family: "Oma Gerda", date: Date.now.addingTimeInterval(-86_400 * 2),
                           postcard: "Gestern hat Hazel zum ersten Mal auf dem Schoß geschlafen. 💛 Oma Gerda"),
        ]
        s.combos = Set(s.rabbits.map { Progression.comboKey($0.look) })
        for i in s.rabbits.indices where !s.rabbits[i].isVisitor {
            s.rabbits[i].joined = Date.now.addingTimeInterval(-3600)
        }
        return s
    }
}
