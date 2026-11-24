import SwiftUI
import UIKit

/// Form der Aussparung. Einstellbar unter Einstellungen → Anzeige (gilt je Gerät):
/// iPhone mit Dynamic Island = waagerecht, Außendisplay des Duo = senkrecht.
enum IslandShape: String, CaseIterable, Identifiable {
    case horizontal, vertical
    var id: Self { self }
    var title: String { self == .horizontal ? "Waagerecht (iPhone)" : "Senkrecht (Duo außen)" }
    static let storageKey = "floof.island.shape"
}

/// Wetter-Animation rund um die Dynamic Island – läuft beim Öffnen von "Heute" 10 Sekunden,
/// danach bleibt nur, was liegen bleibt (Schneehaube, Eiszapfen).
/// Alles bleibt in einem schmalen Bereich um die Island. Ohne Aussparung (Innendisplay)
/// fällt das Wetter in einem schmalen Streifen von der Oberkante.
struct WeatherIslandEffect: View {
    let conditions: [WeatherStore.Condition]
    let temperature: Int
    var posture: DevicePosture = .folded
    @AppStorage(IslandShape.storageKey) private var shapeRaw = IslandShape.horizontal.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sim: WeatherSim?
    @State private var region: CGRect = .zero
    @State private var hasIsland = false
    @State private var finished = false
    @State private var shown = false

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1.0 / 40, paused: finished)) { context in
                Canvas { gc, size in
                    guard let sim else { return }
                    sim.advance(to: context.date)
                    sim.draw(in: &gc)
                }
            }
            .mask { fade }
            .opacity(shown ? 1 : 0)
            .onAppear {
                guard !reduceMotion else { return }
                let island = Self.islandRect(width: proxy.size.width, posture: posture,
                                             shape: IslandShape(rawValue: shapeRaw) ?? .horizontal)
                let area = Self.region(size: proxy.size, island: island)
                hasIsland = island != nil
                region = area
                sim = WeatherSim(conditions: conditions, temperature: temperature,
                                 size: proxy.size, island: island, region: area)
                finished = false
                // Kurz warten, dann weich einblenden – so springt nichts ins Bild.
                withAnimation(.easeInOut(duration: 1.4).delay(0.25)) { shown = true }
                Task {
                    try? await Task.sleep(for: .seconds(WeatherSim.duration + 0.1))
                    finished = true
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Weicher Rand: nichts wird hart am Bereich abgeschnitten.
    @ViewBuilder
    private var fade: some View {
        if hasIsland {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(.black)
                .frame(width: region.width, height: region.height)
                .blur(radius: 14)
                .position(x: region.midX, y: region.midY)
        } else {
            LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.55),
                                   .init(color: .clear, location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: max(region.height, 1))
                .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    /// Lage der Aussparung auf dem Außendisplay bzw. iPhone, sonst `nil` (Innendisplay).
    static func islandRect(width: CGFloat, posture: DevicePosture, shape: IslandShape) -> CGRect? {
        guard posture == .folded, width < 500 else { return nil }
        switch shape {
        case .vertical:
            // Senkrechte Pille, mittig oben (Annahme: 37 × 125 pt, 11 pt vom Rand).
            let w: CGFloat = 37, h: CGFloat = 125
            return CGRect(x: (width - w) / 2, y: 11, width: w, height: h)
        case .horizontal:
            let window = UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow }.first
            guard let top = window?.safeAreaInsets.top, top >= 55 else { return nil }
            let w: CGFloat = 125, h: CGFloat = 37
            return CGRect(x: (width - w) / 2, y: 11, width: w, height: h)
        }
    }

    /// Bereich, in dem die Animation sichtbar sein darf.
    static func region(size: CGSize, island: CGRect?) -> CGRect {
        guard let island else { return CGRect(x: 0, y: 0, width: size.width, height: 110) }
        return CGRect(x: max(0, island.minX - 64), y: 0,
                      width: min(size.width, island.width + 128),
                      height: island.maxY + (island.height > island.width ? 44 : 56))
    }
}

// MARK: - Simulation

/// Mehrere Wetterlagen gleichzeitig (z. B. Nebel + Frost): jede Lage ist eine eigene Ebene,
/// von hinten nach vorn gezeichnet – Himmel, Nebel, Niederschlag, Wind, Frost.
final class WeatherSim {
    static let duration: Double = 10
    private let layers: [WeatherLayer]

    init(conditions: [WeatherStore.Condition], temperature: Int, size: CGSize, island: CGRect?, region: CGRect) {
        let order: [WeatherStore.Condition] = [.night, .clear, .heat, .clouds, .fog, .storm, .rain, .snow, .wind, .frost]
        let sorted = Array(Set(conditions)).sorted { order.firstIndex(of: $0)! < order.firstIndex(of: $1)! }
        layers = sorted.map {
            WeatherLayer(condition: $0, temperature: temperature, size: size, island: island, region: region)
        }
    }

    func advance(to date: Date) { for layer in layers { layer.advance(to: date) } }
    func draw(in gc: inout GraphicsContext) { for layer in layers { layer.draw(in: &gc) } }
}

/// Partikel-Simulation für eine Lage. Referenztyp, damit die Canvas sie pro Bild weiterrechnen kann.
final class WeatherLayer {

    let condition: WeatherStore.Condition
    let temperature: Int
    let size: CGSize
    let island: CGRect?
    let region: CGRect
    private var start: Date?
    private var last: Double = 0
    private var t: Double = 0

    private struct P { var x, y, vx, vy, r, phase, life: Double; var kind = 0; var a = 0.0; var side = 1.0 }
    private var particles: [P] = []
    private var runners: [P] = []      // Regentropfen am Inselrand
    private var drips: [P] = []
    private var sparks: [P] = []
    private var pile: [Double]         // Schneehöhe je Punkt über der Insel
    private var flash = 0.0
    private var bolt: [CGPoint] = []
    private var boltLife = 0.0
    private var nextBolt = 1.8

    /// Senkrechte Pille (Duo außen)?
    private var vertical: Bool { island.map { $0.height > $0.width } ?? false }

    init(condition: WeatherStore.Condition, temperature: Int, size: CGSize, island: CGRect?, region: CGRect) {
        self.condition = condition
        self.temperature = temperature
        self.size = size
        self.island = island
        self.region = region
        pile = Array(repeating: 0, count: Int(size.width) + 2)
        if condition == .fog || condition == .clouds || condition == .night {
            for _ in 0..<(condition == .night ? 22 : 6) {
                particles.append(P(x: .random(in: region.minX...region.maxX), y: .random(in: 0...max(20, region.maxY)),
                                   vx: .random(in: 6...16), vy: 0, r: .random(in: 24...56),
                                   phase: .random(in: 0...6), life: 1, a: .random(in: 0.05...0.13)))
            }
        }
    }

    /// Dichte baut sich in 1,5 s auf (0…1, weich).
    private var ramp: Double { let x = max(0, min(1, (t - 0.2) / 1.5)); return x * x * (3 - 2 * x) }

    /// Stärke der Effekte: blendet am Anfang weich ein und am Ende sanft aus.
    private var intensity: Double { min(ramp, max(0, min(1, (WeatherSim.duration - t) / 1.5))) }
    private var spawning: Bool { t < WeatherSim.duration - 2 }

    func advance(to date: Date) {
        if start == nil { start = date }
        let now = date.timeIntervalSince(start!)
        let dt = min(1.0 / 20, max(0, now - last))
        last = now
        t = now
        guard dt > 0 else { return }
        step(dt)
    }

    // MARK: Schritt

    private func step(_ dt: Double) {
        switch condition {
        case .snow: stepSnow(dt)
        case .rain: stepRain(dt, heavy: false)
        case .storm: stepRain(dt, heavy: true); stepStorm(dt)
        case .wind: stepWind(dt)
        case .clear, .heat: stepMotes(dt)
        case .fog, .clouds:
            for i in particles.indices {
                particles[i].x += particles[i].vx * dt
                if particles[i].x - particles[i].r > region.maxX { particles[i].x = region.minX - particles[i].r }
            }
        case .night, .frost: break
        }
    }

    private func stepSnow(_ dt: Double) {
        if spawning {
            for _ in 0..<2 where Double.random(in: 0...1) < 0.7 * ramp {
                particles.append(P(x: .random(in: region.minX...region.maxX), y: -5, vx: 0, vy: .random(in: 16...30),
                                   r: .random(in: 0.7...2), phase: .random(in: 0...6), life: 1))
            }
            if let island, Double.random(in: 0...1) < 0.5 * ramp {
                particles.append(P(x: .random(in: (island.minX + 8)...(island.maxX - 8)), y: -4, vx: 0,
                                   vy: .random(in: 16...26), r: .random(in: 0.8...1.8), phase: .random(in: 0...6), life: 1))
            }
        }
        for i in particles.indices {
            var f = particles[i]
            f.y += f.vy * dt
            f.x += sin(t * 1.5 + f.phase) * 8 * dt
            if let island {
                let ix = max(0, min(pile.count - 1, Int(f.x.rounded())))
                let top = island.minY - pile[ix]
                if f.x > island.minX + 6, f.x < island.maxX - 6, f.y >= top, f.y < island.minY + 4 {
                    for k in -3...3 {
                        let j = ix + k
                        if Double(j) > island.minX + 4, Double(j) < island.maxX - 4 {
                            pile[j] = min(10, pile[j] + f.r * 0.9 * (1 - Double(abs(k)) / 4))
                        }
                    }
                    f.life = 0
                } else if island.contains(CGPoint(x: f.x, y: f.y)) {
                    f.x += (f.x < island.midX ? -1 : 1) * 30 * dt
                }
            }
            particles[i] = f
        }
        particles.removeAll { $0.life <= 0 || $0.y > region.maxY }
        if let island {
            let a = Int(island.minX) + 5, b = Int(island.maxX) - 5
            if a < b { for j in a..<b { pile[j] = (pile[j - 1] + pile[j] * 2 + pile[j + 1]) / 4 } }
        }
    }

    private func stepRain(_ dt: Double, heavy: Bool) {
        if spawning {
            for _ in 0..<(heavy ? 4 : 6) where Double.random(in: 0...1) < ramp {
                particles.append(P(x: .random(in: region.minX...(region.maxX + 20)), y: -20, vx: heavy ? -40 : -20,
                                   vy: heavy ? 300 : .random(in: 260...340), r: 1, phase: 0, life: 1))
            }
        }
        for i in particles.indices {
            particles[i].y += particles[i].vy * dt
            particles[i].x += particles[i].vx * dt
            guard let island, particles[i].life > 0 else { continue }
            let d = particles[i]
            if d.x > island.minX + 4, d.x < island.maxX - 4, d.y > island.minY - 2, d.y < island.minY + 10 {
                particles[i].life = 0
                for _ in 0..<3 {
                    sparks.append(P(x: d.x, y: island.minY, vx: .random(in: -30...30), vy: .random(in: -70 ... -30),
                                    r: 0.8, phase: 0, life: 0.35, kind: 1))
                }
                if !heavy, Double.random(in: 0...1) < 0.35 {
                    runners.append(P(x: d.x, y: island.minY, vx: .random(in: 20...40), vy: 0,
                                     r: .random(in: 1.6...2.8), phase: 0, life: 1, kind: 0,
                                     side: d.x < island.midX ? -1 : 1))
                }
            }
        }
        particles.removeAll { $0.life <= 0 || $0.y > region.maxY }
        for i in sparks.indices where sparks[i].kind == 1 {
            sparks[i].x += sparks[i].vx * dt; sparks[i].y += sparks[i].vy * dt
            sparks[i].vy += 300 * dt; sparks[i].life -= dt
        }
        guard let island else { return }
        let r = min(island.width, island.height) / 2
        for i in runners.indices {
            var run = runners[i]
            if vertical, run.kind == 0 { run.kind = 1; run.a = 0 }
            switch run.kind {
            case 0:   // oben zur Seite
                let end = run.side > 0 ? island.maxX - r : island.minX + r
                run.x += run.side * run.vx * dt
                if (run.x - end) * run.side >= 0 { run.kind = 1 }
            case 1:   // am Bogen herunter
                run.a += dt * (vertical ? 0.35 + run.a * 0.8 : 0.5 + run.a * 1.5)
                if run.a >= 0.97 { run.kind = 2; run.phase = .random(in: 0.25...0.75) }
            default:  // sammeln, dann abtropfen
                run.phase -= dt
                run.r += dt * 1.5
                if run.phase <= 0 {
                    let p = sidePoint(island, side: run.side, a: 0.97)
                    drips.append(P(x: p.x, y: p.y, vx: 0, vy: 0, r: run.r, phase: 0, life: 1))
                    run.life = 0
                }
            }
            runners[i] = run
        }
        runners.removeAll { $0.life <= 0 }
        for i in drips.indices { drips[i].vy += 500 * dt; drips[i].y += drips[i].vy * dt }
        drips.removeAll { $0.y > region.maxY }
    }

    private func stepStorm(_ dt: Double) {
        flash = max(0, flash - dt * 2.5)
        boltLife -= dt
        if boltLife <= 0 { bolt = [] }
        nextBolt -= dt
        if nextBolt <= 0, spawning {
            nextBolt = .random(in: 1.6...2.8)
            flash = 1
            let target = island.map { CGPoint(x: $0.midX + .random(in: -40...40), y: $0.minY) }
                ?? CGPoint(x: .random(in: region.midX - 60...region.midX + 60), y: 60)
            var p = CGPoint(x: .random(in: region.minX...region.maxX), y: -5)
            bolt = [p]
            while p.y < target.y {
                p.y = min(target.y, p.y + .random(in: 6...12))
                p.x += (target.x - p.x) * 0.25 + .random(in: -7...7)
                bolt.append(p)
            }
            boltLife = 0.35
            if island != nil {
                for _ in 0..<24 {
                    sparks.append(P(x: 0, y: 0, vx: 0, vy: 0, r: 1.3, phase: .random(in: 0...1),
                                    life: 0.8, kind: 2, a: (Bool.random() ? -1 : 1) * .random(in: 0.4...1)))
                }
            }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.5)
        }
        for i in sparks.indices where sparks[i].kind == 2 {
            sparks[i].phase = (sparks[i].phase + sparks[i].a * dt + 1).truncatingRemainder(dividingBy: 1)
            sparks[i].life -= dt
        }
        sparks.removeAll { $0.life <= 0 }
    }

    private func stepWind(_ dt: Double) {
        if spawning, Double.random(in: 0...1) < 0.2 * ramp {
            particles.append(P(x: region.minX - 10, y: .random(in: 0...max(20, region.maxY - 10)), vx: .random(in: 110...190), vy: 0,
                               r: .random(in: 0...6), phase: .random(in: -4...4), life: 1, kind: Int.random(in: 0...4)))
        }
        for i in particles.indices {
            var l = particles[i]
            if l.a > 0 {          // hängt auf der Insel
                l.a -= dt
                l.r += sin(t * 20) * 0.05
                if l.a <= 0 { l.vx = 140; l.vy = -30; l.side = 0 }
            } else {
                l.x += l.vx * dt
                l.y += l.vy * dt + sin(t * 3 + l.r) * 20 * dt
                l.vy += 10 * dt
                l.r += l.phase * dt
                if let island, l.side == 1, l.x > island.minX + 10, l.x < island.midX,
                   abs(l.y - (island.minY - 2)) < 6, Bool.random() {
                    l.side = 2; l.a = .random(in: 0.8...1.8); l.y = island.minY - 2; l.vx = 0
                }
            }
            particles[i] = l
        }
        particles.removeAll { $0.x > region.maxX + 20 }
    }

    private func stepMotes(_ dt: Double) {
        guard let island, spawning, Double.random(in: 0...1) < 0.4 * ramp else {
            for i in particles.indices { particles[i].y += particles[i].vy * dt; particles[i].life -= dt }
            particles.removeAll { $0.life <= 0 }
            return
        }
        particles.append(P(x: .random(in: island.minX...island.maxX), y: island.maxY + 5, vx: 0,
                           vy: .random(in: 6...14), r: 0.9, phase: .random(in: 0...6), life: 3))
        for i in particles.indices {
            particles[i].y += particles[i].vy * dt
            particles[i].x += sin(t * 2 + particles[i].y) * 4 * dt
            particles[i].life -= dt
        }
        particles.removeAll { $0.life <= 0 }
    }

    /// Punkt am Rand der Island, an dem ein Tropfen entlangläuft (a: 0 = Anfang, 1 = Ende).
    /// Waagerecht: über die Rundung an der Seite. Senkrecht: über die obere Rundung,
    /// die gerade Seite hinunter und um die untere Rundung.
    private func sidePoint(_ island: CGRect, side: Double, a: Double) -> CGPoint {
        let r = min(island.width, island.height) / 2
        if island.height > island.width {
            let l = island.height - 2 * r
            let arc = Double.pi * r / 2
            let d = a * (2 * arc + l)
            let ro = r + 1.2
            if d < arc {
                let u = d / r
                return CGPoint(x: island.midX + side * sin(u) * ro, y: island.minY + r - cos(u) * ro)
            }
            if d < arc + l { return CGPoint(x: island.midX + side * ro, y: island.minY + r + (d - arc)) }
            let t = (d - arc - l) / r
            return CGPoint(x: island.midX + side * cos(t) * ro, y: island.maxY - r + sin(t) * ro)
        }
        let cx = side > 0 ? island.maxX - r : island.minX + r
        let ang = -Double.pi / 2 + a * .pi
        return CGPoint(x: cx + side * cos(ang) * (r + 1.2), y: island.minY + r + sin(ang) * (r + 1.2))
    }

    /// Punkt auf dem Umfang (p: 0…1), für Funken beim Gewitter.
    private func perimeterPoint(_ island: CGRect, _ p: Double) -> CGPoint {
        let r = min(island.width, island.height) / 2
        if island.height > island.width {
            let l = island.height - 2 * r
            var d = p * (2 * l + 2 * .pi * r)
            if d < .pi * r {
                let th = Double.pi - d / r
                return CGPoint(x: island.midX + r * cos(th), y: island.minY + r - r * sin(th))
            }
            d -= .pi * r
            if d < l { return CGPoint(x: island.maxX, y: island.minY + r + d) }
            d -= l
            if d < .pi * r {
                let th = -d / r
                return CGPoint(x: island.midX + r * cos(th), y: island.maxY - r - r * sin(th))
            }
            d -= .pi * r
            return CGPoint(x: island.minX, y: island.maxY - r - d)
        }
        let l = island.width - 2 * r
        var d = p * (2 * l + 2 * .pi * r)
        if d < l { return CGPoint(x: island.minX + r + d, y: island.minY) }
        d -= l
        if d < .pi * r { let a = -Double.pi / 2 + d / r; return CGPoint(x: island.maxX - r + cos(a) * r, y: island.midY + sin(a) * r) }
        d -= .pi * r
        if d < l { return CGPoint(x: island.maxX - r - d, y: island.maxY) }
        d -= l
        let a = Double.pi / 2 + d / r
        return CGPoint(x: island.minX + r + cos(a) * r, y: island.midY + sin(a) * r)
    }

    // MARK: Zeichnen

    private static let cream = Color(red: 0.96, green: 0.95, blue: 0.93)
    private static let water = Color(red: 0.75, green: 0.84, blue: 0.94)
    private static let warm = Color(red: 1, green: 0.67, blue: 0.31)
    private static let ice = Color(red: 0.86, green: 0.94, blue: 1)

    func draw(in gc: inout GraphicsContext) {
        let k = intensity
        let islandPath = island.map { Path(roundedRect: $0, cornerRadius: min($0.width, $0.height) / 2) }

        switch condition {
        case .snow:
            for f in particles {
                gc.fill(circle(f.x, f.y, f.r), with: .color(.white.opacity(0.9 * k)))
            }
        case .rain, .storm:
            if condition == .storm {
                gc.fill(Path(region),
                        with: .linearGradient(Gradient(colors: [Color(white: 0.08).opacity(0.75 * k), .clear]),
                                              startPoint: .zero, endPoint: CGPoint(x: 0, y: region.maxY)))
            }
            var streaks = Path()
            for d in particles where d.life > 0 {
                streaks.move(to: CGPoint(x: d.x, y: d.y))
                streaks.addLine(to: CGPoint(x: d.x + (condition == .storm ? 5 : 3), y: d.y - (condition == .storm ? 16 : 14)))
            }
            gc.stroke(streaks, with: .color(Self.water.opacity(0.5 * k)), lineWidth: 1)
            if flash > 0 { gc.fill(Path(region), with: .color(Color(red: 0.86, green: 0.9, blue: 1).opacity(flash * 0.3))) }
            if bolt.count > 1 {
                var p = Path(); p.addLines(bolt)
                var glow = gc; glow.addFilter(.shadow(color: Color(red: 0.62, green: 0.76, blue: 1), radius: 8))
                glow.stroke(p, with: .color(.white), lineWidth: 2.2)
            }
        case .wind:
            let colors: [Color] = [Color(red: 0.79, green: 0.39, blue: 0.16), Color(red: 0.88, green: 0.53, blue: 0.29),
                                   Color(red: 0.73, green: 0.54, blue: 0.16), Color(red: 0.55, green: 0.35, blue: 0.17),
                                   Color(red: 0.62, green: 0.71, blue: 0.54)]
            for l in particles {
                var c = gc
                c.translateBy(x: l.x, y: l.y); c.rotate(by: .radians(l.r))
                c.fill(Path(ellipseIn: CGRect(x: -6, y: -3, width: 12, height: 6)), with: .color(colors[l.kind % 5].opacity(k)))
            }
        case .clear, .heat:
            let center = CGPoint(x: island?.midX ?? size.width / 2, y: island?.midY ?? 0)
            var rays = gc
            rays.translateBy(x: center.x, y: center.y)
            rays.rotate(by: .radians(t * 0.15))
            for i in 0..<14 {
                var r = rays
                r.rotate(by: .radians(Double(i) * .pi * 2 / 14))
                var p = Path()
                p.move(to: CGPoint(x: -5, y: 0)); p.addLine(to: CGPoint(x: -12, y: -90))
                p.addLine(to: CGPoint(x: 12, y: -90)); p.addLine(to: CGPoint(x: 5, y: 0))
                r.fill(p, with: .linearGradient(Gradient(colors: [Self.warm.opacity(0.3 * k), .clear]),
                                                startPoint: .zero, endPoint: CGPoint(x: 0, y: -90)))
            }
            gc.fill(Path(ellipseIn: CGRect(x: center.x - 90, y: center.y - 90, width: 180, height: 180)),
                    with: .radialGradient(Gradient(colors: [Self.warm.opacity(0.35 * k), .clear]),
                                          center: center, startRadius: 6, endRadius: 90))
            if let island, condition == .heat {
                for row in 0..<4 {
                    var w = Path()
                    for x in stride(from: island.minX + 8, to: island.maxX - 8, by: 2) {
                        let y = island.maxY + 10 + Double(row) * 7 + sin(x * 0.18 + t * 6 + Double(row)) * 1.6
                        x == island.minX + 8 ? w.move(to: CGPoint(x: x, y: y)) : w.addLine(to: CGPoint(x: x, y: y))
                    }
                    gc.stroke(w, with: .color(Color(red: 1, green: 0.82, blue: 0.63).opacity(0.22 * k)), lineWidth: 1)
                }
            }
            for m in particles { gc.fill(circle(m.x, m.y, m.r), with: .color(Color(red: 1, green: 0.9, blue: 0.78).opacity(min(1, m.life) * 0.7 * k))) }
        case .fog:
            for b in particles {
                let rect = CGRect(x: b.x - b.r * 1.6, y: b.y - b.r * 0.6, width: b.r * 3.2, height: b.r * 1.2)
                gc.fill(Path(ellipseIn: rect), with: .radialGradient(Gradient(colors: [Color(white: 0.9).opacity(b.a * 2 * k), .clear]),
                                                                    center: CGPoint(x: b.x, y: b.y), startRadius: 0, endRadius: b.r * 1.6))
            }
        case .clouds:
            for c in particles.prefix(5) {
                var g = gc
                g.translateBy(x: c.x, y: 6 + c.phase * 4)
                g.scaleBy(x: 0.7 + c.a * 3, y: 0.7 + c.a * 3)
                var p = Path()
                p.addEllipse(in: CGRect(x: -10, y: 0, width: 20, height: 20))
                p.addEllipse(in: CGRect(x: 0, y: -8, width: 26, height: 26))
                p.addEllipse(in: CGRect(x: 18, y: 0, width: 20, height: 20))
                p.addRect(CGRect(x: 0, y: 10, width: 28, height: 10))
                g.fill(p, with: .color(Color(red: 0.88, green: 0.87, blue: 0.84).opacity(0.8 * k)))
            }
        case .night:
            for s in particles {
                let twinkle = 0.35 + 0.65 * abs(sin(t * 1.7 + s.phase))
                gc.fill(circle(s.x, s.y.truncatingRemainder(dividingBy: max(40, region.maxY)), 0.4 + s.a * 6), with: .color(Color(red: 1, green: 0.98, blue: 0.92).opacity(twinkle * k)))
            }
            let anchor = island.map { CGPoint(x: $0.maxX - 10, y: $0.minY + 10) } ?? CGPoint(x: size.width - 60, y: 30)
            let m = CGPoint(x: anchor.x + min(1, t / 2.5) * 34, y: anchor.y - min(1, t / 2.5) * 2)
            var moon = Path()
            moon.addEllipse(in: CGRect(x: m.x - 11, y: m.y - 11, width: 22, height: 22))
            moon.addEllipse(in: CGRect(x: m.x - 4.5, y: m.y - 12.5, width: 19, height: 19))
            var glow = gc; glow.addFilter(.shadow(color: Color(red: 1, green: 0.94, blue: 0.78).opacity(0.8), radius: 8))
            glow.fill(moon, with: .color(Color(red: 0.96, green: 0.92, blue: 0.82).opacity(k)), style: FillStyle(eoFill: true))
        case .frost:
            break
        }

        // Insel überdecken (verdeckt Strahlen/Wolken dahinter – auf dem Gerät ohnehin schwarz).
        if let islandPath, condition != .snow, condition != .frost {
            gc.fill(islandPath, with: .color(.black))
        }

        guard let island, let islandPath else { return }
        let r = min(island.width, island.height) / 2
        let narrow = island.height > island.width

        switch condition {
        case .snow:
            // Schneehaube – bleibt nach der Animation liegen.
            var cap = Path()
            cap.move(to: CGPoint(x: island.minX + 4, y: island.minY + 1))
            var x = island.minX + 4
            while x <= island.maxX - 4 {
                cap.addLine(to: CGPoint(x: x, y: island.minY + 1 - pile[Int(x)]))
                x += 1
            }
            cap.addLine(to: CGPoint(x: island.maxX - 4, y: island.minY + 1))
            cap.addQuadCurve(to: CGPoint(x: island.minX + 4, y: island.minY + 1), control: CGPoint(x: island.midX, y: island.minY + 4))
            var glow = gc; glow.addFilter(.shadow(color: .white.opacity(0.5), radius: 3))
            glow.fill(cap, with: .color(Self.cream))
        case .rain:
            gc.stroke(islandPath, with: .color(Self.water.opacity(0.35 * k)), lineWidth: 1)
            for run in runners {
                let p = run.kind == 0 ? CGPoint(x: run.x, y: island.minY - run.r * 0.6)
                                      : sidePoint(island, side: run.side, a: min(run.a, 0.97))
                drop(&gc, p.x, p.y + (run.kind == 2 ? run.r * 0.4 : 0), run.r)
            }
            for d in drips {
                gc.fill(Path(ellipseIn: CGRect(x: d.x - d.r * 0.8, y: d.y - d.r * 1.3, width: d.r * 1.6, height: d.r * 2.6)),
                        with: .color(Self.water.opacity(0.9)))
            }
            for s in sparks where s.kind == 1 { gc.fill(circle(s.x, s.y, 0.8), with: .color(Self.water.opacity(0.8))) }
        case .storm:
            var edge = gc; edge.addFilter(.shadow(color: Color(red: 0.56, green: 0.72, blue: 1), radius: 2 + 6 * flash))
            edge.stroke(islandPath, with: .color(Color(red: 0.63, green: 0.78, blue: 1).opacity((0.25 + flash * 0.75) * k)), lineWidth: 1.4)
            for s in sparks where s.kind == 2 {
                let p = perimeterPoint(island, s.phase)
                gc.fill(circle(p.x, p.y, s.r), with: .color(Color(red: 0.78, green: 0.88, blue: 1).opacity(s.life)))
            }
        case .heat:
            var edge = gc; edge.addFilter(.shadow(color: Color(red: 1, green: 0.55, blue: 0.24), radius: 8))
            edge.stroke(islandPath, with: .color(Color(red: 1, green: 0.59, blue: 0.27).opacity((0.6 + 0.3 * sin(t * 3)) * k)), lineWidth: 1.6)
            if !narrow {
                gc.draw(Text("\(temperature)°").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(red: 1, green: 0.84, blue: 0.66).opacity(k)),
                        at: CGPoint(x: island.maxX - 22, y: island.midY))
            }
        case .frost:
            // Eiskristalle oben und Eiszapfen unten – wachsen in 2 Sekunden und bleiben.
            let grow = min(1, t / 2.2)
            var edge = gc; edge.addFilter(.shadow(color: Self.ice, radius: 4))
            edge.stroke(islandPath, with: .color(Self.ice.opacity(0.5 * grow)), lineWidth: 1.2)
            var crystals = Path()
            let crystalCount = narrow ? 4 : 10
            let crystalInset = narrow ? 8.0 : r * 0.6
            for i in 0..<crystalCount {
                let x = island.minX + crystalInset + Double(i) * (island.width - 2 * crystalInset) / Double(crystalCount - 1)
                let s = 5 * grow * (0.6 + Double((i * 37) % 10) / 10)
                for a in -1...1 {
                    let ang = -Double.pi / 2 + Double(a) * 0.9
                    crystals.move(to: CGPoint(x: x, y: island.minY + (narrow ? 2 : 0)))
                    crystals.addLine(to: CGPoint(x: x + cos(ang) * s, y: island.minY + (narrow ? 2 : 0) + sin(ang) * s))
                }
            }
            gc.stroke(crystals, with: .color(Self.ice.opacity(0.9 * grow)), lineWidth: 0.8)
            let icicleCount = narrow ? 4 : 9
            let icicleInset = narrow ? 9.0 : r + 6
            for i in 0..<icicleCount {
                let x = island.minX + icicleInset + Double(i) * (island.width - 2 * icicleInset) / Double(icicleCount - 1)
                let length = (4 + Double((i * 53) % 9)) * min(1, grow * 1.4)
                var icicle = Path()
                icicle.move(to: CGPoint(x: x - 2.2, y: island.maxY - 0.5))
                icicle.addLine(to: CGPoint(x: x + 2.2, y: island.maxY - 0.5))
                icicle.addLine(to: CGPoint(x: x, y: island.maxY + length))
                gc.fill(icicle, with: .linearGradient(Gradient(colors: [Self.ice.opacity(0.95), Self.ice.opacity(0.2)]),
                                                      startPoint: CGPoint(x: x, y: island.maxY), endPoint: CGPoint(x: x, y: island.maxY + length)))
            }
            if !narrow {
                gc.draw(Text("\(temperature)°").font(.system(size: 12, weight: .semibold)).foregroundStyle(Self.ice.opacity(grow)),
                        at: CGPoint(x: island.maxX - 22, y: island.midY))
            }
        default:
            break
        }
    }

    private func circle(_ x: Double, _ y: Double, _ r: Double) -> Path {
        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }

    private func drop(_ gc: inout GraphicsContext, _ x: Double, _ y: Double, _ s: Double) {
        gc.fill(circle(x, y, s), with: .color(Self.water.opacity(0.9)))
        gc.fill(circle(x - s * 0.35, y - s * 0.35, s * 0.35), with: .color(.white.opacity(0.9)))
    }
}
