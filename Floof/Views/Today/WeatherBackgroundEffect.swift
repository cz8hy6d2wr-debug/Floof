import SwiftUI

/// Wetter als ruhiger Hintergrund hinter "Heute": läuft beim Öffnen 10 Sekunden,
/// blendet weich ein und aus. Mehrere Lagen können zusammen laufen (z. B. Nebel + Frost).
/// Der Effekt liegt hinter dem Inhalt und reagiert auf nichts – er ist nur Stimmung.
struct WeatherBackgroundEffect: View {
    let conditions: [WeatherStore.Condition]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sim: WeatherSim?
    @State private var finished = false
    @State private var shown = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: finished)) { context in
            Canvas { gc, size in
                guard let sim else { return }
                sim.advance(to: context.date, size: size)
                sim.draw(in: &gc)
            }
        }
        .opacity(shown ? 1 : 0)
        .onAppear {
            guard !reduceMotion else { return }
            sim = WeatherSim(conditions: conditions)
            finished = false
            // Kurz warten, dann weich einblenden – so springt nichts ins Bild.
            withAnimation(.easeInOut(duration: 1.4).delay(0.25)) { shown = true }
            Task {
                try? await Task.sleep(for: .seconds(WeatherSim.duration + 0.1))
                finished = true
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Mehrere Lagen

/// Jede Lage ist eine eigene Ebene, von hinten nach vorn gezeichnet:
/// Himmel, Nebel, Niederschlag, Wind, Frost.
final class WeatherSim {
    static let duration: Double = 10
    private let layers: [WeatherLayer]

    init(conditions: [WeatherStore.Condition]) {
        let order: [WeatherStore.Condition] = [.night, .clear, .heat, .clouds, .fog, .storm, .rain, .snow, .wind, .frost]
        let sorted = Array(Set(conditions)).sorted { order.firstIndex(of: $0)! < order.firstIndex(of: $1)! }
        layers = sorted.map { WeatherLayer(condition: $0) }
    }

    func advance(to date: Date, size: CGSize) { for layer in layers { layer.advance(to: date, size: size) } }
    func draw(in gc: inout GraphicsContext) { for layer in layers { layer.draw(in: &gc) } }
}

// MARK: - Eine Lage

final class WeatherLayer {
    let condition: WeatherStore.Condition
    private var size: CGSize = .zero
    private var start: Date?
    private var last = 0.0
    private var t = 0.0

    private struct P {
        var x, y, vx, vy, r, phase: Double
        var life = 1.0
        var kind = 0
    }
    private var particles: [P] = []
    private var spawnCarry = 0.0
    private var flash = 0.0
    private var bolt: [CGPoint] = []
    private var boltLife = 0.0
    private var nextBolt = 1.8

    /// Feste Positionen (0…1) für Sterne, Wolken, Nebelbänke, Frostkristalle.
    private let seeds: [(x: Double, y: Double, s: Double, p: Double)] = (0..<60).map { _ in
        (Double.random(in: 0...1), Double.random(in: 0...1), Double.random(in: 0...1), Double.random(in: 0...6))
    }

    init(condition: WeatherStore.Condition) { self.condition = condition }

    /// Dichte baut sich in 1,5 s auf (0…1, weich).
    private var ramp: Double { let x = max(0, min(1, (t - 0.2) / 1.5)); return x * x * (3 - 2 * x) }
    /// Blendet am Anfang weich ein und am Ende sanft aus.
    private var intensity: Double { min(ramp, max(0, min(1, (WeatherSim.duration - t) / 1.5))) }
    private var spawning: Bool { t < WeatherSim.duration - 2 }

    func advance(to date: Date, size: CGSize) {
        self.size = size
        if start == nil { start = date }
        let now = date.timeIntervalSince(start!)
        let dt = min(1.0 / 20, max(0, now - last))
        last = now
        t = now
        guard dt > 0, size.width > 0 else { return }
        step(dt)
    }

    // MARK: Schritt

    private func spawn(rate: Double, dt: Double, make: () -> P) {
        guard spawning else { return }
        spawnCarry += rate * ramp * dt * Double(size.width) / 400
        while spawnCarry >= 1 {
            spawnCarry -= 1
            particles.append(make())
        }
    }

    private func step(_ dt: Double) {
        let w = Double(size.width), h = Double(size.height)
        switch condition {
        case .snow:
            spawn(rate: 55, dt: dt) {
                P(x: .random(in: 0...w), y: -6, vx: 0, vy: .random(in: 22...46),
                  r: .random(in: 0.7...2.4), phase: .random(in: 0...6))
            }
            for i in particles.indices {
                particles[i].y += particles[i].vy * dt
                particles[i].x += sin(t * 1.4 + particles[i].phase) * 10 * dt
            }
        case .rain, .storm:
            let heavy = condition == .storm
            spawn(rate: heavy ? 330 : 240, dt: dt) {
                let depth = Double.random(in: 0.5...1)
                return P(x: .random(in: 0...(w + 60)), y: -20, vx: -55 * depth, vy: 520 * depth + 120, r: depth, phase: 0)
            }
            for i in particles.indices {
                particles[i].x += particles[i].vx * dt
                particles[i].y += particles[i].vy * dt
            }
            if heavy { stepBolt(dt, w: w, h: h) }
        case .wind:
            spawn(rate: 0.9, dt: dt) {
                P(x: -12, y: .random(in: 0...(h * 0.75)), vx: .random(in: 150...260), vy: .random(in: -10...10),
                  r: .random(in: 0...6), phase: .random(in: -6...6), kind: Int.random(in: 0...4))
            }
            for i in particles.indices {
                particles[i].x += particles[i].vx * dt
                particles[i].y += particles[i].vy * dt + sin(t * 3 + particles[i].r) * 20 * dt
                particles[i].r += particles[i].phase * dt
            }
        case .clear, .heat:
            spawn(rate: 4, dt: dt) {
                P(x: .random(in: 0...w), y: .random(in: (h * 0.1)...(h * 0.5)), vx: 0, vy: .random(in: -14 ... -6),
                  r: 0.9, phase: .random(in: 0...6))
            }
            for i in particles.indices {
                particles[i].y += particles[i].vy * dt
                particles[i].x += sin(t * 2 + particles[i].phase) * 4 * dt
                particles[i].life -= dt / 3.5
            }
        case .fog, .clouds, .night, .frost:
            break
        }
        particles.removeAll { $0.life <= 0 || $0.y > h + 30 || $0.x > w + 40 || $0.x < -80 || $0.y < -40 }
    }

    private func stepBolt(_ dt: Double, w: Double, h: Double) {
        flash = max(0, flash - dt * 2.5)
        boltLife -= dt
        if boltLife <= 0 { bolt = [] }
        nextBolt -= dt
        guard nextBolt <= 0, spawning else { return }
        nextBolt = .random(in: 1.8...3.2)
        flash = 1
        var p = CGPoint(x: .random(in: (w * 0.2)...(w * 0.8)), y: -5)
        let targetY = h * .random(in: 0.25...0.45)
        let targetX = p.x + .random(in: -60...60)
        bolt = [p]
        while p.y < targetY {
            p.y = min(targetY, p.y + .random(in: 8...16))
            p.x += (targetX - p.x) * 0.2 + .random(in: -9...9)
            bolt.append(p)
        }
        boltLife = 0.3
    }

    // MARK: Zeichnen

    private static let water = Color(red: 0.75, green: 0.84, blue: 0.94)
    private static let warm = Color(red: 1, green: 0.67, blue: 0.31)
    private static let ice = Color(red: 0.86, green: 0.94, blue: 1)

    func draw(in gc: inout GraphicsContext) {
        let k = intensity
        let w = Double(size.width), h = Double(size.height)
        guard k > 0.001, w > 0 else { return }

        switch condition {
        case .snow:
            for f in particles {
                let alpha = min(0.85, 0.3 + 0.28 * f.r) * k      // große Flocken: näher und heller
                gc.fill(circle(f.x, f.y, f.r), with: .color(.white.opacity(alpha)))
                if f.r > 1.8 {
                    gc.fill(circle(f.x, f.y, f.r * 2.4), with: .color(.white.opacity(alpha * 0.18)))
                }
            }

        case .rain, .storm:
            if condition == .storm {
                gc.fill(Path(CGRect(x: 0, y: 0, width: w, height: h * 0.42)),
                        with: .linearGradient(Gradient(colors: [Color(white: 0.06).opacity(0.7 * k), .clear]),
                                              startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.42)))
            }
            var near = Path(), far = Path()
            for d in particles {
                let tail = CGPoint(x: d.x - d.vx * 0.03, y: d.y - d.vy * 0.03)
                if d.r > 0.75 { near.move(to: CGPoint(x: d.x, y: d.y)); near.addLine(to: tail) }
                else { far.move(to: CGPoint(x: d.x, y: d.y)); far.addLine(to: tail) }
            }
            var rain = gc
            rain.blendMode = .screen
            rain.stroke(far, with: .color(Self.water.opacity(0.2 * k)), lineWidth: 0.8)
            rain.stroke(near, with: .color(Self.water.opacity(0.36 * k)), lineWidth: 1)
            if flash > 0 {
                var lightning = gc
                lightning.blendMode = .plusLighter
                lightning.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)),
                               with: .color(Color(red: 0.86, green: 0.9, blue: 1).opacity(flash * 0.16 * k)))
            }
            if bolt.count > 1 {
                var path = Path(); path.addLines(bolt)
                var glow = gc
                glow.addFilter(.shadow(color: Color(red: 0.62, green: 0.76, blue: 1), radius: 8))
                glow.stroke(path, with: .color(.white.opacity(min(1, boltLife / 0.2) * k)), lineWidth: 2)
            }

        case .wind:
            let colors: [Color] = [Color(red: 0.79, green: 0.39, blue: 0.16), Color(red: 0.88, green: 0.53, blue: 0.29),
                                   Color(red: 0.73, green: 0.54, blue: 0.16), Color(red: 0.55, green: 0.35, blue: 0.17),
                                   Color(red: 0.62, green: 0.71, blue: 0.54)]
            for row in 0..<4 {
                let y = h * (0.12 + 0.17 * Double(row))
                let x = (t * 220 + Double(row) * 140).truncatingRemainder(dividingBy: w + 240) - 120
                var line = Path()
                line.move(to: CGPoint(x: x, y: y))
                line.addCurve(to: CGPoint(x: x + 140, y: y),
                              control1: CGPoint(x: x + 45, y: y - 7), control2: CGPoint(x: x + 90, y: y + 7))
                gc.stroke(line, with: .color(.white.opacity(0.07 * k)), lineWidth: 1)
            }
            for l in particles {
                var c = gc
                c.translateBy(x: l.x, y: l.y)
                c.rotate(by: .radians(l.r))
                c.fill(Path(ellipseIn: CGRect(x: -6, y: -3, width: 12, height: 6)),
                       with: .color(colors[l.kind % 5].opacity(0.85 * k)))
            }

        case .clear, .heat:
            let hot = condition == .heat
            var add = gc
            add.blendMode = .plusLighter
            let center = CGPoint(x: w / 2, y: -30)
            add.fill(Path(CGRect(x: 0, y: 0, width: w, height: h * 0.65)),
                     with: .radialGradient(Gradient(colors: [Self.warm.opacity((hot ? 0.4 : 0.28) * k), .clear]),
                                           center: center, startRadius: 0, endRadius: w * 0.95))
            for i in 0..<10 {
                var ray = add
                ray.translateBy(x: center.x, y: center.y)
                ray.rotate(by: .radians(-0.9 + Double(i) * 0.2 + sin(t * 0.3 + Double(i)) * 0.03))
                let length = h * 0.7
                var path = Path()
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: -14, y: length))
                path.addLine(to: CGPoint(x: 14, y: length))
                path.closeSubpath()
                ray.fill(path, with: .linearGradient(Gradient(colors: [Self.warm.opacity(0.1 * k), .clear]),
                                                     startPoint: .zero, endPoint: CGPoint(x: 0, y: length)))
            }
            if hot {
                for row in 0..<5 {
                    var wave = Path()
                    let y0 = 90 + Double(row) * 16
                    for x in stride(from: 0.0, through: w, by: 4) {
                        let y = y0 + sin(x * 0.045 + t * 4 + Double(row)) * 2.4
                        x == 0 ? wave.move(to: CGPoint(x: x, y: y)) : wave.addLine(to: CGPoint(x: x, y: y))
                    }
                    add.stroke(wave, with: .color(Color(red: 1, green: 0.82, blue: 0.63).opacity(0.1 * k)), lineWidth: 1)
                }
            }
            for m in particles {
                add.fill(circle(m.x, m.y, m.r),
                         with: .color(Color(red: 1, green: 0.9, blue: 0.78).opacity(min(1, m.life) * 0.5 * k)))
            }

        case .clouds:
            for i in 0..<6 {
                let s = seeds[i]
                let span = w * 1.4
                let x = (s.x * span + t * (8 + s.p * 3)).truncatingRemainder(dividingBy: span) - w * 0.2
                let y = 30 + s.y * 110
                let scale = 0.8 + s.s * 0.9
                for (dx, dy) in [(-26.0, 0.0), (0.0, -10.0), (28.0, 2.0)] {
                    let c = CGPoint(x: x + dx * scale, y: y + dy * scale)
                    gc.fill(Path(ellipseIn: CGRect(x: c.x - 44 * scale, y: c.y - 26 * scale, width: 88 * scale, height: 52 * scale)),
                            with: .radialGradient(Gradient(colors: [Color(white: 0.92).opacity(0.26 * k), .clear]),
                                                  center: c, startRadius: 0, endRadius: 44 * scale))
                }
            }

        case .fog:
            for i in 0..<7 {
                let s = seeds[i]
                let span = w * 1.6
                let x = (s.x * span + t * (6 + s.p * 2)).truncatingRemainder(dividingBy: span) - w * 0.3
                let y = s.y * h * 0.8
                let r = 120 + s.s * 120
                gc.fill(Path(ellipseIn: CGRect(x: x - r * 1.6, y: y - r * 0.55, width: r * 3.2, height: r * 1.1)),
                        with: .radialGradient(Gradient(colors: [Color(white: 0.9).opacity(0.13 * k), .clear]),
                                              center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r * 1.6))
            }

        case .night:
            var add = gc
            add.blendMode = .plusLighter
            for i in 0..<40 {
                let s = seeds[i]
                let twinkle = 0.35 + 0.65 * abs(sin(t * 1.7 + s.p))
                add.fill(circle(s.x * w, s.y * h * 0.45, 0.5 + s.s * 1.1),
                         with: .color(Color(red: 1, green: 0.98, blue: 0.92).opacity(twinkle * 0.9 * k)))
            }
            let rise = 1 - min(1, t / 3)
            let m = CGPoint(x: w - 64, y: 96 + rise * 18)
            var moon = Path()
            moon.addEllipse(in: CGRect(x: m.x - 13, y: m.y - 13, width: 26, height: 26))
            moon.addEllipse(in: CGRect(x: m.x - 5, y: m.y - 15, width: 22, height: 22))
            var glow = gc
            glow.addFilter(.shadow(color: Color(red: 1, green: 0.94, blue: 0.78).opacity(0.8), radius: 10))
            glow.fill(moon, with: .color(Color(red: 0.96, green: 0.92, blue: 0.82).opacity(0.9 * k)),
                      style: FillStyle(eoFill: true))

        case .frost:
            // Frost wächst von den Rändern her und glitzert.
            let grow = min(1, t / 2.5)
            let band = 64.0
            let frost = Self.ice.opacity(0.22 * grow * k)
            gc.fill(Path(CGRect(x: 0, y: 0, width: w, height: band)),
                    with: .linearGradient(Gradient(colors: [frost, .clear]), startPoint: .zero, endPoint: CGPoint(x: 0, y: band)))
            gc.fill(Path(CGRect(x: 0, y: h - band, width: w, height: band)),
                    with: .linearGradient(Gradient(colors: [.clear, frost]), startPoint: CGPoint(x: 0, y: h - band), endPoint: CGPoint(x: 0, y: h)))
            gc.fill(Path(CGRect(x: 0, y: 0, width: band, height: h)),
                    with: .linearGradient(Gradient(colors: [frost, .clear]), startPoint: .zero, endPoint: CGPoint(x: band, y: 0)))
            gc.fill(Path(CGRect(x: w - band, y: 0, width: band, height: h)),
                    with: .linearGradient(Gradient(colors: [.clear, frost]), startPoint: CGPoint(x: w - band, y: 0), endPoint: CGPoint(x: w, y: 0)))
            var crystals = Path()
            for i in 0..<48 {
                let s = seeds[i % seeds.count]
                let side = i % 4
                let origin: CGPoint
                let inward: Double
                switch side {
                case 0: origin = CGPoint(x: s.x * w, y: 2); inward = .pi / 2
                case 1: origin = CGPoint(x: 2, y: s.y * h); inward = 0
                case 2: origin = CGPoint(x: w - 2, y: s.y * h); inward = .pi
                default: origin = CGPoint(x: s.y * w, y: h - 2); inward = -.pi / 2
                }
                let length = (5 + s.s * 11) * grow
                for a in [-0.6, 0.0, 0.6] {
                    crystals.move(to: origin)
                    crystals.addLine(to: CGPoint(x: origin.x + cos(inward + a) * length, y: origin.y + sin(inward + a) * length))
                }
            }
            gc.stroke(crystals, with: .color(Self.ice.opacity(0.6 * grow * k)), lineWidth: 0.9)
            var add = gc
            add.blendMode = .plusLighter
            for i in 0..<14 {
                let s = seeds[(i * 3) % seeds.count]
                let twinkle = max(0, sin(t * 2.2 + s.p))
                let x = i % 2 == 0 ? s.x * w : (i % 4 == 1 ? 6 : w - 6)
                let y = i % 2 == 0 ? (i % 4 == 0 ? 6 : h - 6) : s.y * h
                add.fill(circle(x, y, 0.8 + twinkle * 1.2), with: .color(.white.opacity(twinkle * 0.8 * grow * k)))
            }
        }
    }

    private func circle(_ x: Double, _ y: Double, _ r: Double) -> Path {
        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }
}
