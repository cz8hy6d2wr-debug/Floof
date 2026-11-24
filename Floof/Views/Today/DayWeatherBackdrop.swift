import SwiftUI

/// Leise Wetter-Animation hinter einem Tag im Wochenkalender: Frost glitzert, Hitze flimmert,
/// Regen fällt, Schnee rieselt, Wind streicht vorbei. Alles ist zeitbasiert (ohne Zustand),
/// klein und langsam – die Kachel soll lebendig wirken, nicht unruhig.
struct DayWeatherBackdrop: View {
    let conditions: [WeatherStore.Condition]
    /// Ist der Untergrund der Kachel hell (z. B. gewählter Tag im dunklen Modus)? Dann dunklere Farben.
    let onLight: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            canvas(at: 3.0)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 15)) { context in
                canvas(at: context.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    private func canvas(at t: Double) -> some View {
        Canvas { gc, size in
            let order: [WeatherStore.Condition] = [.clear, .clouds, .fog, .heat, .storm, .rain, .snow, .wind, .frost]
            for condition in order where conditions.contains(condition) {
                draw(condition, in: &gc, size: size, t: t)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Farben

    private var warm: Color { onLight ? Color(hex: 0xC9642A) : Color(hex: 0xFFAA55) }
    private var water: Color { onLight ? Color(hex: 0x3A6EA5) : Color(hex: 0xBFD6F0) }
    private var ice: Color { onLight ? Color(hex: 0x4F8DB8) : Color(hex: 0xDCF0FF) }
    private var mist: Color { onLight ? Color(hex: 0x8A8178) : Color(white: 0.92) }

    /// Wiederholbarer Pseudo-Zufall je Element (keine Zustände nötig).
    private func r(_ i: Int, _ salt: Int) -> Double {
        let x = sin(Double(i * 127 + salt * 311) * 12.9898) * 43758.5453
        return x - floor(x)
    }

    // MARK: Zeichnen

    private func draw(_ condition: WeatherStore.Condition, in gc: inout GraphicsContext, size: CGSize, t: Double) {
        let w = Double(size.width), h = Double(size.height)
        guard w > 0, h > 0 else { return }
        let blend: GraphicsContext.BlendMode = onLight ? .normal : .plusLighter

        switch condition {
        case .frost:
            // Frostiger Rand oben und unten, Kristalle, glitzernde Punkte, ein Lichtstreif.
            let edge = ice.opacity(onLight ? 0.22 : 0.2)
            gc.fill(Path(CGRect(x: 0, y: 0, width: w, height: h * 0.32)),
                    with: .linearGradient(Gradient(colors: [edge, .clear]), startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.32)))
            gc.fill(Path(CGRect(x: 0, y: h * 0.68, width: w, height: h * 0.32)),
                    with: .linearGradient(Gradient(colors: [.clear, edge]), startPoint: CGPoint(x: 0, y: h * 0.68), endPoint: CGPoint(x: 0, y: h)))
            var crystals = Path()
            for i in 0..<7 {
                let top = i % 2 == 0
                let origin = CGPoint(x: w * (0.1 + 0.8 * r(i, 1)), y: top ? 1 : h - 1)
                let inward = top ? Double.pi / 2 : -Double.pi / 2
                let length = 4 + 6 * r(i, 2)
                for a in [-0.6, 0.0, 0.6] {
                    crystals.move(to: origin)
                    crystals.addLine(to: CGPoint(x: origin.x + cos(inward + a) * length, y: origin.y + sin(inward + a) * length))
                }
            }
            gc.stroke(crystals, with: .color(ice.opacity(0.7)), lineWidth: 0.8)
            var sparkle = gc
            sparkle.blendMode = blend
            for i in 0..<8 {
                let tw = max(0, sin(t * (1.4 + r(i, 3)) + r(i, 4) * 6))
                let x = w * r(i, 5), y = h * r(i, 6)
                sparkle.fill(circle(x, y, 0.6 + tw * 1.3), with: .color(.white.opacity(onLight ? tw * 0.55 : tw * 0.9)))
            }
            // Lichtstreif, der alle paar Sekunden diagonal über die Kachel zieht.
            let phase = (t / 5).truncatingRemainder(dividingBy: 1)
            if phase < 0.35 {
                let x = -w * 0.4 + (w * 1.8) * (phase / 0.35)
                var band = sparkle
                band.translateBy(x: x, y: 0)
                var p = Path()
                p.move(to: CGPoint(x: 0, y: h)); p.addLine(to: CGPoint(x: w * 0.25, y: h))
                p.addLine(to: CGPoint(x: w * 0.55, y: 0)); p.addLine(to: CGPoint(x: w * 0.3, y: 0)); p.closeSubpath()
                band.fill(p, with: .color(.white.opacity(onLight ? 0.18 : 0.12)))
            }

        case .heat:
            // Warmer Schein von unten, flimmernde Luft steigt auf, ein paar Funken.
            let pulse = 0.8 + 0.2 * sin(t * 2)
            var add = gc
            add.blendMode = blend
            add.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)),
                     with: .radialGradient(Gradient(colors: [warm.opacity((onLight ? 0.28 : 0.34) * pulse), .clear]),
                                           center: CGPoint(x: w / 2, y: h * 1.05), startRadius: 0, endRadius: h * 0.85))
            for i in 0..<4 {
                let progress = ((t * 0.12 + Double(i) / 4).truncatingRemainder(dividingBy: 1))
                let y0 = h * (1 - progress)
                var wave = Path()
                for x in stride(from: 0.0, through: w, by: 3) {
                    let y = y0 + sin(x * 0.28 + t * 5 + Double(i)) * 1.8
                    x == 0 ? wave.move(to: CGPoint(x: x, y: y)) : wave.addLine(to: CGPoint(x: x, y: y))
                }
                gc.stroke(wave, with: .color(warm.opacity(0.28 * sin(progress * .pi))), lineWidth: 0.9)
            }
            for i in 0..<4 {
                let progress = ((t * 0.09 + r(i, 7)).truncatingRemainder(dividingBy: 1))
                add.fill(circle(w * (0.15 + 0.7 * r(i, 8)) + sin(t * 2 + Double(i)) * 3, h * (1 - progress), 0.9),
                         with: .color(Color(hex: 0xFFE2B8).opacity(sin(progress * .pi) * (onLight ? 0.7 : 0.8))))
            }

        case .rain, .storm:
            if condition == .storm {
                gc.fill(Path(CGRect(x: 0, y: 0, width: w, height: h * 0.5)),
                        with: .linearGradient(Gradient(colors: [Color(white: onLight ? 0.2 : 0.05).opacity(0.5), .clear]),
                                              startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.5)))
                let cycle = (t + 1.3).truncatingRemainder(dividingBy: 4.5)
                if cycle < 0.22 {
                    let flash = 1 - cycle / 0.22
                    var lightning = gc
                    lightning.blendMode = blend
                    lightning.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)),
                                   with: .color(Color(red: 0.86, green: 0.9, blue: 1).opacity(flash * (onLight ? 0.2 : 0.22))))
                    var bolt = Path()
                    bolt.move(to: CGPoint(x: w * 0.55, y: 0))
                    bolt.addLine(to: CGPoint(x: w * 0.4, y: h * 0.22))
                    bolt.addLine(to: CGPoint(x: w * 0.52, y: h * 0.24))
                    bolt.addLine(to: CGPoint(x: w * 0.36, y: h * 0.5))
                    gc.stroke(bolt, with: .color(.white.opacity(flash)), lineWidth: 1.4)
                }
            }
            var drops = Path()
            let count = condition == .storm ? 9 : 7
            for i in 0..<count {
                let speed = 0.55 + 0.35 * r(i, 9)
                let y = ((t * speed + r(i, 10)).truncatingRemainder(dividingBy: 1)) * (h + 12) - 6
                let x = w * r(i, 11) - y * 0.08
                drops.move(to: CGPoint(x: x, y: y))
                drops.addLine(to: CGPoint(x: x + 1.2, y: y - 7))
            }
            gc.stroke(drops, with: .color(water.opacity(onLight ? 0.6 : 0.5)), lineWidth: 0.9)

        case .snow:
            for i in 0..<9 {
                let speed = 0.12 + 0.1 * r(i, 12)
                let y = ((t * speed + r(i, 13)).truncatingRemainder(dividingBy: 1)) * (h + 8) - 4
                let x = w * r(i, 14) + sin(t * 0.9 + r(i, 15) * 6) * 4
                gc.fill(circle(x, y, 0.9 + 0.9 * r(i, 16)), with: .color((onLight ? ice : .white).opacity(0.85)))
            }

        case .wind:
            for i in 0..<3 {
                let speed = 0.45 + 0.3 * r(i, 17)
                let x = ((t * speed + r(i, 18)).truncatingRemainder(dividingBy: 1)) * (w + 30) - 20
                let y = h * (0.22 + 0.28 * Double(i)) + sin(t * 2 + Double(i)) * 1.5
                var streak = Path()
                streak.move(to: CGPoint(x: x, y: y))
                streak.addCurve(to: CGPoint(x: x + 16, y: y),
                                control1: CGPoint(x: x + 5, y: y - 2), control2: CGPoint(x: x + 11, y: y + 2))
                gc.stroke(streak, with: .color((onLight ? mist : .white).opacity(onLight ? 0.6 : 0.4)), lineWidth: 1)
            }

        case .fog:
            for i in 0..<3 {
                let x = ((t * (0.03 + 0.02 * r(i, 19)) + r(i, 20)).truncatingRemainder(dividingBy: 1)) * (w + 60) - 30
                let y = h * (0.25 + 0.25 * Double(i))
                gc.fill(Path(ellipseIn: CGRect(x: x - 34, y: y - 12, width: 68, height: 24)),
                        with: .radialGradient(Gradient(colors: [mist.opacity(onLight ? 0.3 : 0.2), .clear]),
                                              center: CGPoint(x: x, y: y), startRadius: 0, endRadius: 34))
            }

        case .clouds:
            for i in 0..<2 {
                let x = ((t * (0.025 + 0.015 * r(i, 21)) + r(i, 22)).truncatingRemainder(dividingBy: 1)) * (w + 50) - 25
                let y = h * (0.12 + 0.12 * Double(i))
                for dx in [-9.0, 0.0, 10.0] {
                    gc.fill(Path(ellipseIn: CGRect(x: x + dx - 14, y: y - 8, width: 28, height: 16)),
                            with: .radialGradient(Gradient(colors: [mist.opacity(onLight ? 0.3 : 0.22), .clear]),
                                                  center: CGPoint(x: x + dx, y: y), startRadius: 0, endRadius: 14))
                }
            }

        case .clear:
            // Zarter Sonnenschein in der oberen Ecke.
            var add = gc
            add.blendMode = blend
            let pulse = 0.85 + 0.15 * sin(t * 1.2)
            add.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)),
                     with: .radialGradient(Gradient(colors: [warm.opacity((onLight ? 0.22 : 0.2) * pulse), .clear]),
                                           center: CGPoint(x: w * 0.85, y: -4), startRadius: 0, endRadius: h * 0.5))

        case .night:
            break
        }
    }

    private func circle(_ x: Double, _ y: Double, _ r: Double) -> Path {
        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }
}
