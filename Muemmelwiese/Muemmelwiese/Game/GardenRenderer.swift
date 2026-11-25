import SwiftUI

/// Stellung eines Kaninchens in einem Bild.
struct RabbitPose {
    var lift: CGFloat = 0
    var stretch: CGFloat = 1
    var spin: CGFloat = 0
    var headDown: CGFloat = 0
    var chew: CGFloat = 0
    var eyesClosed = false
    var happy = false
    var earsBack: CGFloat = 0
    var earTwitch: CGFloat = 0
    var groom: CGFloat = -1
    var flop = false
    var breath: CGFloat = 1
    var nose: CGFloat = 0
}

/// Zeichnet den Garten in einen `Canvas`. Alles ist Vektorgrafik – keine Bilddateien.
enum GardenRenderer {

    // MARK: - Ganzes Bild

    @MainActor
    static func draw(_ game: GardenGame, in ctx: inout GraphicsContext, size: CGSize, time: Double) {
        let night = CGFloat(1 - game.daylight)
        let rain = CGFloat(game.rainAmount)
        let grey = CGFloat(max(game.rainAmount, game.overcast * 0.85, game.snowAmount * 0.7))
        let top = game.lawnTop

        drawBackdrop(game, &ctx, size: size, top: top, night: night, rain: grey)
        drawSky(&ctx, size: size, top: top, night: night, rain: grey, hour: game.hour, time: time)
        drawLawnBase(game, &ctx, size: size, top: top)
        drawGroundWeather(game, &ctx, size: size, top: top, time: time)
        drawHutch(game, &ctx, night: night)
        drawBed(game, &ctx, time: time)

        // Reihe für Reihe von hinten nach vorn: erst Dinge, dann die Halme der Reihe.
        let rows = GardenSave.rows
        var items: [(y: Double, kind: Int, index: Int)] = []
        for (i, r) in game.save.rabbits.enumerated() { items.append((r.y, 0, i)) }
        for (i, f) in game.save.foods.enumerated() { items.append((f.y, 1, i)) }
        for (i, f) in game.save.flowers.enumerated() { items.append((f.y, 2, i)) }
        for (i, d) in game.save.decor.enumerated() { items.append((d.y, 3, i)) }
        items.sort { $0.y < $1.y }
        var next = 0
        let wind = CGFloat(game.windFactor * (1 + 0.8 * game.rainAmount))
        let grassColors = grassPalette(game)
        for j in 0..<rows {
            let rowEnd = Double(j + 1) / Double(rows)
            while next < items.count, items[next].y < rowEnd || j == rows - 1 {
                let item = items[next]
                switch item.kind {
                case 0: drawRabbit(game, index: item.index, &ctx, time: time)
                case 1: drawFood(game.save.foods[item.index], game, &ctx)
                case 3: drawDecor(game.save.decor[item.index], game, &ctx, time: time)
                default: drawFlower(game.save.flowers[item.index], game, &ctx, time: time)
                }
                next += 1
            }
            drawGrassRow(game, row: j, &ctx, time: time, wind: wind, colors: grassColors)
        }

        if game.season != .winter && game.snowCover < 0.3 {
            drawButterflies(&ctx, size: size, top: top, time: time, day: 1 - night - grey * 0.8)
        }
        drawParticles(game, &ctx)

        // Nacht und Regen dunkeln alles ab; Glühwürmchen und Fenster leuchten darüber.
        if night > 0.01 {
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0x0B1438).opacity(Double(night) * 0.55)))
            drawHutchWindow(game, &ctx, night: night)
            drawFireflies(&ctx, size: size, top: top, time: time, night: night)
        }
        if rain > 0.01 { drawRain(&ctx, size: size, time: time, amount: rain, wind: CGFloat(game.windFactor)) }
        if game.snowAmount > 0.02 { drawSnowfall(&ctx, size: size, time: time, amount: CGFloat(game.snowAmount), wind: CGFloat(game.windFactor)) }
        if game.fog > 0.02 {
            // Nebel: in der Ferne dichter
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .linearGradient(Gradient(colors: [Color(hex: 0xDDE3E6).opacity(0.85 * game.fog), Color(hex: 0xDDE3E6).opacity(0.25 * game.fog)]),
                                           startPoint: CGPoint(x: 0, y: top - 40), endPoint: CGPoint(x: 0, y: size.height)))
        }
        if game.lightning > 0 {
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white.opacity(min(0.75, game.lightning * 2.4))))
        }
        drawToolCursor(game, &ctx, time: time)
    }

    // MARK: - Hilfen

    static func hash(_ a: Int, _ b: Int, _ c: Int = 0) -> CGFloat {
        var h = UInt64(bitPattern: Int64(a &* 73_856_093 ^ b &* 19_349_663 ^ c &* 83_492_791))
        h ^= h >> 33
        h = h &* 0xff51afd7ed558ccd
        h ^= h >> 33
        h = h &* 0xc4ceb9fe1a85ec53
        h ^= h >> 33
        return CGFloat(h % 10_000) / 10_000
    }

    static func mix(_ a: Color, _ b: Color, _ t: CGFloat) -> Color {
        let ra = UIColor(a), rb = UIColor(b)
        var (r1, g1, b1, a1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var (r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        ra.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        rb.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = min(max(t, 0), 1)
        return Color(red: Double(r1 + (r2 - r1) * t), green: Double(g1 + (g2 - g1) * t), blue: Double(b1 + (b2 - b1) * t))
    }

    // MARK: - Himmel & Hintergrund

    /// Unbewegter Hintergrund (Himmel, Horizont, Zaun, Boden) – wird selten neu gerendert und als Bild gezeichnet.
    @MainActor
    final class BackdropCache {
        static let shared = BackdropCache()
        private var key = ""
        private(set) var image: Image?
        private(set) var imageSize: CGSize = .zero

        /// Wird im Spieltakt aufgerufen (nicht beim Zeichnen) und rendert nur, wenn sich etwas geändert hat.
        func prepare(_ game: GardenGame) {
            let size = game.size
            guard size.width > 10, size.height > 10 else { return }
            let night = CGFloat(1 - game.daylight), top = game.lawnTop
            let rain = CGFloat(max(game.rainAmount, game.overcast * 0.85, game.snowAmount * 0.7))
            let season = game.season
            let k = "\(Int(size.width))x\(Int(size.height))-\(Int(game.hour * 6))-\(Int(rain * 4))-\(game.lowPower)-\(season.rawValue)"
            if k != key || image == nil {
                key = k
                let hour = game.hour, unit = game.unit, low = game.lowPower
                let content = Canvas(opaque: true) { c, s in
                    GardenRenderer.drawStaticBackdrop(&c, size: s, top: top, night: night, rain: rain, hour: hour, unit: unit,
                                                      detailed: !low, season: season)
                }
                .frame(width: size.width, height: size.height)
                let renderer = ImageRenderer(content: content)
                renderer.scale = low ? 1.5 : 2
                if let ui = renderer.uiImage {
                    image = Image(uiImage: ui)
                    imageSize = size
                }
            }
        }
    }

    @MainActor
    static func drawBackdrop(_ game: GardenGame, _ ctx: inout GraphicsContext, size: CGSize, top: CGFloat, night: CGFloat, rain: CGFloat) {
        let cache = BackdropCache.shared
        if let image = cache.image, abs(cache.imageSize.width - size.width) < 2, abs(cache.imageSize.height - size.height) < 2 {
            ctx.draw(image, in: CGRect(origin: .zero, size: size))
        } else {
            drawStaticBackdrop(&ctx, size: size, top: top, night: night, rain: rain, hour: game.hour, unit: game.unit,
                               detailed: false, season: game.season)
        }
    }

    static func drawStaticBackdrop(_ ctx: inout GraphicsContext, size: CGSize, top: CGFloat, night: CGFloat, rain: CGFloat,
                                   hour: Double, unit: CGFloat, detailed: Bool, season: Season = .sommer) {
        let dusk = max(0, 1 - abs(night - 0.5) * 2.2)   // Abend- und Morgenrot
        // Himmel: tiefes Blau oben, dunstig-hell am Horizont
        var zenith = mix(Color(hex: 0x3F8FD8), Color(hex: 0x060C24), night)
        var middle = mix(Color(hex: 0x86C1EC), Color(hex: 0x15214A), night)
        var horizon = mix(Color(hex: 0xE2F1F6), Color(hex: 0x2C3A62), night)
        horizon = mix(horizon, Color(hex: 0xF6B27C), dusk * 0.75)
        middle = mix(middle, Color(hex: 0xD99BA6), dusk * 0.35)
        zenith = mix(zenith, Color(hex: 0x7D8C9E), rain * 0.65)
        middle = mix(middle, Color(hex: 0xA2ADB8), rain * 0.65)
        horizon = mix(horizon, Color(hex: 0xC4CBD1), rain * 0.65)
        ctx.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: top + 30)),
                 with: .linearGradient(Gradient(stops: [.init(color: zenith, location: 0), .init(color: middle, location: 0.55),
                                                        .init(color: horizon, location: 1)]),
                                       startPoint: .zero, endPoint: CGPoint(x: 0, y: top)))

        // Sonne bzw. Mond auf einem Bogen
        let dayT = (hour - 6) / 14
        let nightT = ((hour + 24 - 20).truncatingRemainder(dividingBy: 24)) / 10
        let isDay = night < 0.5
        let t = CGFloat(isDay ? dayT : nightT)
        if t > -0.1 && t < 1.1 {
            let cx = size.width * (0.1 + 0.8 * t)
            let cy = top * (0.75 - 0.55 * sin(.pi * min(max(t, 0), 1)))
            let r: CGFloat = 20
            if isDay {
                ctx.fill(Path(ellipseIn: CGRect(x: cx - r * 6, y: cy - r * 6, width: r * 12, height: r * 12)),
                         with: .radialGradient(Gradient(colors: [Color(hex: 0xFFF6D8).opacity(0.5 * Double(1 - rain)), .clear]),
                                               center: CGPoint(x: cx, y: cy), startRadius: r, endRadius: r * 6))
                ctx.fill(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                         with: .radialGradient(Gradient(colors: [Color(hex: 0xFFFDF2), mix(Color(hex: 0xFFEFB0), Color(hex: 0xFFAA66), dusk)]),
                                               center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: r))
            } else {
                ctx.fill(Path(ellipseIn: CGRect(x: cx - r * 3, y: cy - r * 3, width: r * 6, height: r * 6)),
                         with: .radialGradient(Gradient(colors: [Color.white.opacity(0.16), .clear]),
                                               center: CGPoint(x: cx, y: cy), startRadius: r * 0.8, endRadius: r * 3))
                ctx.fill(Path(ellipseIn: CGRect(x: cx - r * 0.8, y: cy - r * 0.8, width: r * 1.6, height: r * 1.6)),
                         with: .radialGradient(Gradient(colors: [Color(hex: 0xFAF6E6), Color(hex: 0xD9D4C0)]),
                                               center: CGPoint(x: cx - 3, y: cy - 3), startRadius: 0, endRadius: r))
                for (dx, dy, rr) in [(CGFloat(-4), CGFloat(-2), CGFloat(3.5)), (5, 4, 2.5), (2, -7, 2)] {
                    ctx.fill(Path(ellipseIn: CGRect(x: cx + dx - rr, y: cy + dy - rr, width: rr * 2, height: rr * 2)),
                             with: .color(Color(hex: 0xBFB8A2).opacity(0.5)))
                }
            }
        }

        // Ferne Hügel im Dunst (Luftperspektive: je weiter weg, desto blasser und blauer)
        let haze = mix(horizon, Color(hex: 0x9FB8C8), 0.3)
        let hillColors = [mix(Color(hex: 0x8FB089), haze, 0.55), mix(Color(hex: 0x6E9A5E), haze, 0.3)]
        for layer in 0..<2 {
            var p = Path()
            let base = top - (layer == 0 ? 46 : 30) * unit
            p.move(to: CGPoint(x: 0, y: top + 10))
            p.addLine(to: CGPoint(x: 0, y: base))
            let steps = 40
            for s in 0...steps {
                let x = size.width * CGFloat(s) / CGFloat(steps)
                let wave = CGFloat(0.5 + 0.3 * sin(Double(x) / (layer == 0 ? 140 : 85) + Double(layer) * 2)
                                   + 0.2 * sin(Double(x) / 37 + Double(layer)))
                p.addLine(to: CGPoint(x: x, y: base - (layer == 0 ? 30 : 20) * unit * wave))
            }
            p.addLine(to: CGPoint(x: size.width, y: top + 10))
            p.closeSubpath()
            ctx.fill(p, with: .color(mix(hillColors[layer], Color(hex: 0x101A28), night * 0.3)))
        }

        // Baumreihe: viele Kronen, oben vom Licht getroffen, unten im Schatten
        ctx.drawLayer { l in
            if detailed { l.addFilter(.blur(radius: 0.6)) }
            // Laub je Jahreszeit: frisch, satt, golden-rot, kahl
            let leaf: (UInt32, UInt32, UInt32) = {
                switch season {
                case .fruehling: return (0x3A6B30, 0x5A9A40, 0x9CCB6A)
                case .sommer: return (0x2F5A2C, 0x41753A, 0x6E9F4E)
                case .herbst: return (0x6B3E22, 0xB2602A, 0xE3A23C)
                case .winter: return (0x4A4238, 0x6B6155, 0x8F877C)
                }
            }()
            let dark = mix(Color(hex: leaf.0), Color(hex: 0x0A1414), night * 0.3)
            let mid = mix(Color(hex: leaf.1), Color(hex: 0x0F1C1C), night * 0.3)
            let lit = mix(Color(hex: leaf.2), Color(hex: 0x16262A), night * 0.3)
            var x: CGFloat = -10
            var k = 0
            while x < size.width + 20 {
                let h = (22 + hash(k, 71) * 26 + (hash(k, 72) > 0.85 ? 22 : 0)) * unit
                let w = (16 + hash(k, 73) * 16) * unit
                let base = top - 6 * unit
                // Krone aus vielen Laubbüscheln: unten dunkel, oben vom Licht getroffen
                l.fill(Path(ellipseIn: CGRect(x: x - w * 0.8, y: base - h * 0.85, width: w * 1.6, height: h * 0.85)),
                       with: .color(dark))
                let tufts = detailed ? 22 : 10
                for b in 0..<tufts {
                    let u = hash(k, b, 74), v = hash(k, b, 75)
                    let bx = x + (u - 0.5) * w * 1.7 * (0.6 + v * 0.4)
                    let by = base - v * h
                    let br = (4 + hash(k, b, 76) * 6) * unit * (1.1 - v * 0.4)
                    let color = v > 0.62 ? lit : (v > 0.3 ? mid : dark)
                    l.fill(Path(ellipseIn: CGRect(x: bx - br, y: by - br * 0.85, width: br * 2, height: br * 1.7)),
                           with: .color(color.opacity(0.92)))
                }
                x += w * (1.1 + hash(k, 77) * 0.5)
                k += 1
            }
        }

        // Zaun aus verwittertem Holz
        let wood = mix(Color(hex: 0xB48A62), Color(hex: 0x2A2420), night * 0.3)
        let woodDark = mix(Color(hex: 0x7A5638), Color(hex: 0x15110E), night * 0.3)
        let fh = 26 * unit
        for rail in [0.38, 0.75] {
            let y = top - fh * CGFloat(rail)
            let r = CGRect(x: 0, y: y - 2 * unit, width: size.width, height: 4.5 * unit)
            ctx.fill(Path(r), with: .linearGradient(Gradient(colors: [wood, woodDark]),
                                                   startPoint: CGPoint(x: 0, y: r.minY), endPoint: CGPoint(x: 0, y: r.maxY)))
        }
        var px: CGFloat = 8
        var pk = 0
        while px < size.width {
            let lean = (hash(pk, 81) - 0.5) * 1.5 * unit
            var post = Path()
            post.move(to: CGPoint(x: px - 4 * unit, y: top + 2))
            post.addLine(to: CGPoint(x: px - 4 * unit + lean, y: top - fh))
            post.addLine(to: CGPoint(x: px + lean, y: top - fh - 5 * unit))
            post.addLine(to: CGPoint(x: px + 4 * unit + lean, y: top - fh))
            post.addLine(to: CGPoint(x: px + 4 * unit, y: top + 2))
            post.closeSubpath()
            ctx.fill(post, with: .linearGradient(Gradient(colors: [mix(wood, .white, 0.12), woodDark]),
                                                 startPoint: CGPoint(x: px - 4 * unit, y: 0), endPoint: CGPoint(x: px + 4 * unit, y: 0)))
            var grain = Path()
            grain.move(to: CGPoint(x: px - 1 * unit, y: top - 2))
            grain.addLine(to: CGPoint(x: px - 1 * unit + lean, y: top - fh + 3))
            grain.move(to: CGPoint(x: px + 1.8 * unit, y: top - 4))
            grain.addLine(to: CGPoint(x: px + 1.8 * unit + lean, y: top - fh * 0.6))
            ctx.stroke(grain, with: .color(woodDark.opacity(0.5)), lineWidth: 0.6)
            px += 34 * unit
            pk += 1
        }

        // Boden: in der Ferne heller und bläulicher, vorn satt; dazu Struktur aus Flecken und Klee
        let lawnRect = CGRect(x: 0, y: top, width: size.width, height: size.height - top)
        // Wiese je Jahreszeit (Winter: blasser, olivfarben)
        let lawnFar: UInt32 = season == .winter ? 0x9AA77A : (season == .herbst ? 0x9AAE5E : 0x8DB967)
        let lawnNear: UInt32 = season == .winter ? 0x5F7046 : (season == .herbst ? 0x5C7E32 : 0x4E8A35)
        let far = mix(mix(Color(hex: lawnFar), haze, 0.25), Color(hex: 0x0E1A14), night * 0.3)
        let near = mix(Color(hex: lawnNear), Color(hex: 0x0A140E), night * 0.3)
        ctx.fill(Path(lawnRect), with: .linearGradient(Gradient(colors: [far, mix(far, near, 0.5), near]),
                                                       startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: size.height)))
        let blotches = detailed ? 1400 : 500
        var darkDots = Path(), lightDots = Path(), soil = Path(), clover = Path()
        for k in 0..<blotches {
            let fy = hash(k, 91)
            let y = top + fy * fy * (size.height - top)          // mehr Details vorn
            let x = hash(k, 92) * size.width
            let sc = 0.5 + fy * 1.2
            let r = (1.5 + hash(k, 93) * 5) * sc
            let rect = CGRect(x: x - r * 2.4, y: y - r * 0.4, width: r * 4.8, height: r * 0.8)
            let pick = hash(k, 94)
            if pick < 0.45 { darkDots.addEllipse(in: rect) }
            else if pick < 0.88 { lightDots.addEllipse(in: rect) }
            else if pick < 0.94 { soil.addEllipse(in: rect.insetBy(dx: r * 0.8, dy: r * 0.2)) }
            else {
                for c in 0..<3 {
                    let a = Double(c) / 3 * 2 * .pi
                    let cr = r * 0.45
                    clover.addEllipse(in: CGRect(x: x + CGFloat(cos(a)) * cr - cr, y: y + CGFloat(sin(a)) * cr * 0.5 - cr * 0.6,
                                                 width: cr * 2, height: cr * 1.2))
                }
            }
        }
        ctx.fill(darkDots, with: .color(mix(Color(hex: 0x3B6E2A), .black, night * 0.3).opacity(0.16)))
        ctx.fill(lightDots, with: .color(mix(Color(hex: 0xA9CF7C), .black, night * 0.3).opacity(0.14)))
        ctx.fill(soil, with: .color(mix(Color(hex: 0x7A6244), .black, night * 0.3).opacity(0.35)))
        ctx.fill(clover, with: .color(mix(Color(hex: 0x5C9A3E), .black, night * 0.3).opacity(0.8)))
        // Dunst über dem fernen Rasen
        ctx.fill(Path(CGRect(x: 0, y: top - 4, width: size.width, height: (size.height - top) * 0.25)),
                 with: .linearGradient(Gradient(colors: [horizon.opacity(0.35 * Double(1 - night * 0.7)), .clear]),
                                       startPoint: CGPoint(x: 0, y: top - 4), endPoint: CGPoint(x: 0, y: top + (size.height - top) * 0.25)))
    }

    /// Was sich bewegt: Sterne funkeln, Wolken ziehen.
    static func drawSky(_ ctx: inout GraphicsContext, size: CGSize, top: CGFloat, night: CGFloat, rain: CGFloat, hour: Double, time: Double) {
        if night > 0.3 {
            var stars = Path(), bright = Path()
            for k in 0..<70 {
                let x = hash(k, 1) * size.width
                let y = hash(k, 2) * top * 0.8
                let tw = 0.5 + 0.5 * sin(time * (1 + Double(hash(k, 3)) * 2) + Double(k))
                let r = 0.5 + hash(k, 4) * 1.1
                let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                if tw > 0.6 { bright.addEllipse(in: rect) } else { stars.addEllipse(in: rect) }
            }
            ctx.fill(stars, with: .color(.white.opacity(Double(night - 0.3) * 0.7)))
            ctx.fill(bright, with: .color(.white.opacity(Double(night - 0.3) * 1.4)))
        }

        // Wolken: weich aus vielen Teilen, unten leicht verschattet
        let light = mix(mix(.white, Color(hex: 0x3A4668), night), Color(hex: 0xA3ACB6), rain * 0.7)
        let shadow = mix(mix(Color(hex: 0xC9D6E2), Color(hex: 0x1E2640), night), Color(hex: 0x7C8590), rain * 0.7)
        let cloudCount = 4 + Int(rain * 5)
        for k in 0..<cloudCount {
            let speed = 4 + Double(hash(k, 9)) * 6
            let span = size.width + 300
            let x = CGFloat((Double(hash(k, 7)) * Double(span) + time * speed).truncatingRemainder(dividingBy: Double(span))) - 150
            let y = top * (0.1 + hash(k, 8) * 0.42)
            let w = (80 + hash(k, 10) * 90) * (0.7 + y / top * 0.5)
            var lower = Path(), upper = Path()
            for p in 0..<7 {
                let px = x + w * (CGFloat(p) / 6)
                let ph = w * (0.18 + hash(k, p, 11) * 0.22) * (1 - abs(CGFloat(p) - 3) / 5)
                upper.addEllipse(in: CGRect(x: px - ph, y: y - ph * 1.2, width: ph * 2, height: ph * 1.7))
                lower.addEllipse(in: CGRect(x: px - ph * 1.1, y: y - ph * 0.5, width: ph * 2.2, height: ph * 1.2))
            }
            ctx.fill(lower, with: .color(shadow.opacity(0.8)))
            ctx.fill(upper, with: .color(light.opacity(0.92)))
        }
    }

    @MainActor
    static func drawLawnBase(_ game: GardenGame, _ ctx: inout GraphicsContext, size: CGSize, top: CGFloat) {
        // Mähstreifen (dezent wie bei echtem Rasen) und nasse Stellen je Zelle
        let cols = GardenSave.cols, rows = GardenSave.rows
        let cw = size.width / CGFloat(cols), ch = (size.height - top) / CGFloat(rows)
        var lightStripe = Path(), darkStripe = Path(), wetPath = Path(), tallShade = Path()
        for k in 0..<(cols * rows) {
            let i = k % cols, j = k / cols
            let cell = CGRect(x: CGFloat(i) * cw, y: top + CGFloat(j) * ch, width: cw + 0.5, height: ch + 0.5)
            let h = CGFloat(game.save.grass[k])
            if h < 0.45 {
                if i % 2 == 0 { lightStripe.addRect(cell) } else { darkStripe.addRect(cell) }
            } else if h > 0.7 {
                tallShade.addRect(cell)
            }
            if game.save.wet[k] > 0.15 { wetPath.addRect(cell) }
        }
        ctx.fill(lightStripe, with: .color(Color(hex: 0xB5DA86).opacity(0.38)))
        ctx.fill(darkStripe, with: .color(Color(hex: 0x6FA548).opacity(0.3)))
        ctx.fill(tallShade, with: .color(Color(hex: 0x2E5A22).opacity(0.22)))
        ctx.fill(wetPath, with: .color(Color(hex: 0x1F4A2A).opacity(0.2)))
    }

    /// Feste Eigenschaften jedes Halms – einmal berechnet statt in jedem Bild.
    struct Blade {
        let fx: CGFloat, fy: CGFloat
        let variance: CGFloat, width: CGFloat, lean: CGFloat
        let phase: Double
        let shade: Int
    }

    static let bladesPerCell = 18
    static let bladeTable: [[Blade]] = {
        let cols = GardenSave.cols, rows = GardenSave.rows
        var table: [[Blade]] = []
        for k in 0..<(cols * rows) {
            let i = k % cols, j = k / cols
            table.append((0..<bladesPerCell).map { b in
                Blade(fx: (CGFloat(i) + hash(i, j, b)) / CGFloat(cols),
                      fy: (CGFloat(j) + hash(i, j, b + 50)) / CGFloat(rows),
                      variance: 0.55 + hash(i, j, b + 99) * 0.9,
                      width: 1.0 + hash(i, j, b + 3) * 0.8,
                      lean: (hash(i, j, b + 5) - 0.5) * 6,
                      phase: Double(b),
                      shade: Int(hash(i, j, b + 7) * 3.999))
            })
        }
        return table
    }()

    /// Grasfarben für dieses Bild (Jahreszeit, Frost) – einmal pro Bild statt pro Reihe gemischt.
    @MainActor
    static func grassPalette(_ game: GardenGame) -> [Color] {
        let shades = [Color(hex: 0x3D7A2A), Color(hex: 0x4F8E35), Color(hex: 0x65A244), Color(hex: 0x82B957), Color(hex: 0xA9C66A)]
        let frost = CGFloat(game.isFreezing ? 0.45 : 0) + CGFloat(game.snowCover) * 0.3
        let winterTint: CGFloat = game.season == .winter ? 0.25 : (game.season == .herbst ? 0.12 : 0)
        guard frost > 0 || winterTint > 0 else { return shades }
        return shades.map { c in
            var m = mix(c, Color(hex: 0xA09A5A), winterTint)
            if frost > 0 { m = mix(m, Color(hex: 0xE8F1F4), frost) }
            return m
        }
    }

    @MainActor
    static func drawGrassRow(_ game: GardenGame, row j: Int, _ ctx: inout GraphicsContext, time: Double, wind: CGFloat,
                             colors: [Color]) {
        let cols = GardenSave.cols, rows = GardenSave.rows
        var paths = [Path(), Path(), Path(), Path(), Path()]
        let touch = game.toolPoint
        let bed = GardenGame.bedRect.insetBy(dx: -0.01, dy: -0.01)
        let W = game.size.width, top = game.lawnTop, H = game.size.height - top, unit = game.unit
        let cw = W / CGFloat(cols), ch = H / CGFloat(rows)
        let density = cw * ch / (game.lowPower ? 150 : 75)
        let snow = 1 - CGFloat(game.snowCover) * 0.85
        for i in 0..<cols {
            let k = j * cols + i
            let h = CGFloat(game.save.grass[k])
            let count = Int(min(CGFloat(bladesPerCell), max(3, density * (h < 0.2 ? 0.6 : 1))))
            let swayAmp = (1 + 4 * h) * wind
            for blade in bladeTable[k].prefix(count) {
                if bed.contains(CGPoint(x: blade.fx, y: blade.fy)) { continue }
                let bx = blade.fx * W, by = top + blade.fy * H
                let s = unit * (0.62 + 0.55 * blade.fy)
                let height = (2.5 + 28 * h) * s * blade.variance * snow
                let width = blade.width * s
                var sway = blade.lean * s * h + CGFloat(sin(time * 1.5 + Double(bx) * 0.022 + blade.phase)) * swayAmp * s
                if let touch {
                    let dx = bx - touch.x, dy = by - touch.y
                    let d2 = dx * dx + dy * dy
                    if d2 < 3600 { sway += (dx > 0 ? 1 : -1) * (60 - d2.squareRoot()) * 0.25 * h }
                }
                var p = Path()
                p.move(to: CGPoint(x: bx - width, y: by))
                p.addQuadCurve(to: CGPoint(x: bx + sway, y: by - height),
                               control: CGPoint(x: bx - width * 0.2 + sway * 0.25, y: by - height * 0.6))
                p.addLine(to: CGPoint(x: bx + width, y: by))
                let shade = h > 0.75 && blade.variance > 1.25 ? 4 : blade.shade   // trockene Spitzen
                paths[shade].addPath(p)
            }
        }
        for (n, p) in paths.enumerated() { ctx.fill(p, with: .color(colors[n])) }
    }

    // MARK: - Stall & Beet

    /// Fenster des Zuhauses (leuchtet nachts).
    @MainActor
    static func homeWindow(_ game: GardenGame) -> CGRect {
        let c = game.screen(GardenGame.hutch.x, GardenGame.hutch.y)
        let s = game.scale(atY: GardenGame.hutch.y) * 1.25
        switch game.save.home {
        case .holzstall: return CGRect(x: c.x - 36 * s, y: c.y - 46 * s, width: 18 * s, height: 16 * s)
        case .cottage: return CGRect(x: c.x - 36 * s, y: c.y - 46 * s, width: 20 * s, height: 20 * s)
        case .pilzhaus: return CGRect(x: c.x - 22 * s, y: c.y - 40 * s, width: 14 * s, height: 14 * s)
        case .schloss: return CGRect(x: c.x - 7 * s, y: c.y - 56 * s, width: 14 * s, height: 18 * s)
        }
    }

    private static func archDoor(center x: CGFloat, ground y: CGFloat, width dw: CGFloat, height dh: CGFloat) -> Path {
        var door = Path()
        door.move(to: CGPoint(x: x - dw / 2, y: y))
        door.addLine(to: CGPoint(x: x - dw / 2, y: y - dh + dw / 2))
        door.addArc(center: CGPoint(x: x, y: y - dh + dw / 2), radius: dw / 2,
                    startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        door.addLine(to: CGPoint(x: x + dw / 2, y: y))
        door.closeSubpath()
        return door
    }

    @MainActor
    static func drawHutch(_ game: GardenGame, _ ctx: inout GraphicsContext, night: CGFloat) {
        let c = game.screen(GardenGame.hutch.x, GardenGame.hutch.y)
        let s = game.scale(atY: GardenGame.hutch.y) * 1.25
        let win = homeWindow(game)
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - 56 * s, y: c.y - 6 * s, width: 112 * s, height: 14 * s)),
                 with: .color(.black.opacity(0.18)))
        let hole = Color(hex: 0x3B2618)

        switch game.save.home {
        case .holzstall:
            let w = 92 * s, h = 58 * s
            let body = CGRect(x: c.x - w / 2, y: c.y - h, width: w, height: h)
            ctx.fill(Path(roundedRect: body, cornerRadius: 4 * s), with: .color(Color(hex: 0xD9A877)))
            var boards = Path()
            var y = body.minY + 10 * s
            while y < body.maxY {
                boards.move(to: CGPoint(x: body.minX, y: y)); boards.addLine(to: CGPoint(x: body.maxX, y: y))
                y += 10 * s
            }
            ctx.stroke(boards, with: .color(Color(hex: 0xB07F52).opacity(0.6)), lineWidth: 1)
            var roof = Path()
            roof.move(to: CGPoint(x: body.minX - 10 * s, y: body.minY + 4 * s))
            roof.addLine(to: CGPoint(x: c.x, y: body.minY - 30 * s))
            roof.addLine(to: CGPoint(x: body.maxX + 10 * s, y: body.minY + 4 * s))
            roof.closeSubpath()
            ctx.fill(roof, with: .color(Color(hex: 0xB4503F)))
            ctx.stroke(roof, with: .color(Color(hex: 0x86362A)), lineWidth: 2 * s)
            ctx.fill(archDoor(center: c.x + 12 * s, ground: c.y, width: 30 * s, height: 34 * s), with: .color(hole))
            ctx.fill(Path(roundedRect: win, cornerRadius: 3 * s), with: .color(Color(hex: 0x5D4636)))

        case .cottage:
            let w = 98 * s, h = 60 * s
            let body = CGRect(x: c.x - w / 2, y: c.y - h, width: w, height: h)
            ctx.fill(Path(CGRect(x: body.maxX - 26 * s, y: body.minY - 34 * s, width: 12 * s, height: 30 * s)),
                     with: .color(Color(hex: 0x9C5B48)))
            ctx.fill(Path(roundedRect: body, cornerRadius: 3 * s), with: .color(Color(hex: 0x8EB9E0)))
            ctx.fill(Path(CGRect(x: body.minX, y: body.minY, width: 5 * s, height: h)), with: .color(.white))
            ctx.fill(Path(CGRect(x: body.maxX - 5 * s, y: body.minY, width: 5 * s, height: h)), with: .color(.white))
            var roof = Path()
            roof.move(to: CGPoint(x: body.minX - 12 * s, y: body.minY + 6 * s))
            roof.addLine(to: CGPoint(x: body.minX + 14 * s, y: body.minY - 30 * s))
            roof.addLine(to: CGPoint(x: body.maxX - 14 * s, y: body.minY - 30 * s))
            roof.addLine(to: CGPoint(x: body.maxX + 12 * s, y: body.minY + 6 * s))
            roof.closeSubpath()
            ctx.fill(roof, with: .color(Color(hex: 0x4A5472)))
            var tiles = Path()
            for k in 1..<4 {
                let y = body.minY + 6 * s - CGFloat(k) * 9 * s
                tiles.move(to: CGPoint(x: body.minX - 12 * s + CGFloat(k) * 6.5 * s, y: y))
                tiles.addLine(to: CGPoint(x: body.maxX + 12 * s - CGFloat(k) * 6.5 * s, y: y))
            }
            ctx.stroke(tiles, with: .color(Color(hex: 0x353D57)), lineWidth: 1.5 * s)
            let door = archDoor(center: c.x + 14 * s, ground: c.y, width: 30 * s, height: 38 * s)
            ctx.stroke(door, with: .color(.white), lineWidth: 4 * s)
            ctx.fill(door, with: .color(Color(hex: 0x2F4E7A)))
            ctx.fill(archDoor(center: c.x + 14 * s, ground: c.y, width: 18 * s, height: 22 * s), with: .color(hole))
            ctx.fill(Path(ellipseIn: win.insetBy(dx: -3 * s, dy: -3 * s)), with: .color(.white))
            ctx.fill(Path(ellipseIn: win), with: .color(Color(hex: 0x5D6E86)))
            // Blumenkasten
            let box = CGRect(x: win.minX - 4 * s, y: win.maxY + 3 * s, width: win.width + 8 * s, height: 6 * s)
            ctx.fill(Path(roundedRect: box, cornerRadius: 2 * s), with: .color(Color(hex: 0x9C6B45)))
            for k in 0..<4 {
                let fx = box.minX + 4 * s + CGFloat(k) * 6 * s
                ctx.fill(Path(ellipseIn: CGRect(x: fx - 2.5 * s, y: box.minY - 4 * s, width: 5 * s, height: 5 * s)),
                         with: .color(k % 2 == 0 ? Color(hex: 0xF27A9B) : Color(hex: 0xF7D154)))
            }

        case .pilzhaus:
            let stem = CGRect(x: c.x - 32 * s, y: c.y - 54 * s, width: 64 * s, height: 54 * s)
            ctx.fill(Path(roundedRect: stem, cornerRadius: 14 * s), with: .color(Color(hex: 0xF3E6CF)))
            ctx.fill(Path(roundedRect: stem.insetBy(dx: 4 * s, dy: 0).offsetBy(dx: 10 * s, dy: 0), cornerRadius: 12 * s),
                     with: .color(Color(hex: 0xE2D0B2).opacity(0.6)))
            var cap = Path()
            cap.move(to: CGPoint(x: c.x - 64 * s, y: c.y - 44 * s))
            cap.addCurve(to: CGPoint(x: c.x + 64 * s, y: c.y - 44 * s),
                         control1: CGPoint(x: c.x - 64 * s, y: c.y - 124 * s),
                         control2: CGPoint(x: c.x + 64 * s, y: c.y - 124 * s))
            cap.addQuadCurve(to: CGPoint(x: c.x - 64 * s, y: c.y - 44 * s), control: CGPoint(x: c.x, y: c.y - 34 * s))
            ctx.fill(cap, with: .linearGradient(Gradient(colors: [Color(hex: 0xE5453A), Color(hex: 0xB52C25)]),
                                                startPoint: CGPoint(x: c.x, y: c.y - 104 * s), endPoint: CGPoint(x: c.x, y: c.y - 40 * s)))
            let dots: [(CGFloat, CGFloat, CGFloat)] = [(-38, -62, 9), (-8, -86, 11), (26, -70, 8), (46, -54, 6), (-50, -50, 5), (8, -60, 6)]
            for (dx, dy, r) in dots {
                ctx.fill(Path(ellipseIn: CGRect(x: c.x + (dx - r) * s, y: c.y + (dy - r * 0.8) * s, width: r * 2 * s, height: r * 1.6 * s)),
                         with: .color(.white))
            }
            ctx.fill(archDoor(center: c.x + 10 * s, ground: c.y, width: 24 * s, height: 30 * s), with: .color(Color(hex: 0x7A4A2A)))
            ctx.fill(archDoor(center: c.x + 10 * s, ground: c.y, width: 16 * s, height: 20 * s), with: .color(hole))
            ctx.fill(Path(ellipseIn: win.insetBy(dx: -2 * s, dy: -2 * s)), with: .color(Color(hex: 0x7A4A2A)))
            ctx.fill(Path(ellipseIn: win), with: .color(Color(hex: 0x5D4636)))

        case .schloss:
            let stone = Color(hex: 0xB9B4AC), stoneDark = Color(hex: 0x8E887E), roofC = Color(hex: 0x5B5FA8)
            let body = CGRect(x: c.x - 42 * s, y: c.y - 64 * s, width: 84 * s, height: 64 * s)
            ctx.fill(Path(body), with: .color(stone))
            for k in 0..<5 {
                ctx.fill(Path(CGRect(x: body.minX + CGFloat(k) * 18 * s, y: body.minY - 8 * s, width: 10 * s, height: 9 * s)),
                         with: .color(stone))
            }
            var bricks = Path()
            for row in 1..<6 {
                let y = body.minY + CGFloat(row) * 11 * s
                bricks.move(to: CGPoint(x: body.minX, y: y)); bricks.addLine(to: CGPoint(x: body.maxX, y: y))
            }
            ctx.stroke(bricks, with: .color(stoneDark.opacity(0.5)), lineWidth: 1)
            for side in [-1.0, 1.0] {
                let tx = c.x + CGFloat(side) * 50 * s
                let tower = CGRect(x: tx - 14 * s, y: c.y - 92 * s, width: 28 * s, height: 92 * s)
                ctx.fill(Path(tower), with: .color(stone))
                ctx.stroke(Path(tower), with: .color(stoneDark.opacity(0.6)), lineWidth: 1)
                var cone = Path()
                cone.move(to: CGPoint(x: tower.minX - 5 * s, y: tower.minY))
                cone.addLine(to: CGPoint(x: tx, y: tower.minY - 36 * s))
                cone.addLine(to: CGPoint(x: tower.maxX + 5 * s, y: tower.minY))
                cone.closeSubpath()
                ctx.fill(cone, with: .color(roofC))
                var pole = Path()
                pole.move(to: CGPoint(x: tx, y: tower.minY - 36 * s)); pole.addLine(to: CGPoint(x: tx, y: tower.minY - 52 * s))
                ctx.stroke(pole, with: .color(Color(hex: 0x4A4A4A)), lineWidth: 1.5 * s)
                var flag = Path()
                flag.move(to: CGPoint(x: tx, y: tower.minY - 52 * s))
                flag.addQuadCurve(to: CGPoint(x: tx + 16 * s, y: tower.minY - 47 * s),
                                  control: CGPoint(x: tx + 8 * s, y: tower.minY - 55 * s))
                flag.addLine(to: CGPoint(x: tx, y: tower.minY - 42 * s))
                flag.closeSubpath()
                ctx.fill(flag, with: .color(Color(hex: 0xF27A9B)))
                ctx.fill(Path(roundedRect: CGRect(x: tx - 4 * s, y: tower.minY + 18 * s, width: 8 * s, height: 13 * s), cornerRadius: 4 * s),
                         with: .color(Color(hex: 0x4A4038)))
            }
            let gate = archDoor(center: c.x + 6 * s, ground: c.y, width: 30 * s, height: 36 * s)
            ctx.fill(gate, with: .color(Color(hex: 0x7A5230)))
            var bars = Path()
            for k in 0..<4 {
                let x = c.x + 6 * s - 11 * s + CGFloat(k) * 7.3 * s
                bars.move(to: CGPoint(x: x, y: c.y)); bars.addLine(to: CGPoint(x: x, y: c.y - 30 * s))
            }
            ctx.stroke(bars, with: .color(Color(hex: 0x4E341E)), lineWidth: 1.5 * s)
            ctx.fill(Path(roundedRect: win, cornerRadius: 6 * s), with: .color(Color(hex: 0x4A4038)))
        }

        if game.save.home != .schloss {
            let bowl = CGRect(x: c.x + 54 * s, y: c.y - 8 * s, width: 22 * s, height: 10 * s)
            ctx.fill(Path(ellipseIn: bowl), with: .color(Color(hex: 0x4F7FB0)))
            ctx.fill(Path(ellipseIn: bowl.insetBy(dx: 3 * s, dy: 2 * s)), with: .color(Color(hex: 0x9FD3F2)))
        }
    }

    @MainActor
    static func drawHutchWindow(_ game: GardenGame, _ ctx: inout GraphicsContext, night: CGFloat) {
        let s = game.scale(atY: GardenGame.hutch.y) * 1.25
        let win = homeWindow(game)
        ctx.fill(Path(ellipseIn: win.insetBy(dx: -24 * s, dy: -24 * s)),
                 with: .radialGradient(Gradient(colors: [Color(hex: 0xFFC56E).opacity(0.35 * Double(night)), .clear]),
                                       center: CGPoint(x: win.midX, y: win.midY), startRadius: 2, endRadius: 34 * s))
        ctx.fill(Path(roundedRect: win, cornerRadius: 4 * s), with: .color(Color(hex: 0xFFCF7A).opacity(Double(night))))
        // Laternen leuchten
        for d in game.save.decor where d.kind == .laterne {
            let p = game.screen(d.x, d.y)
            let ds = game.scale(atY: d.y)
            let lamp = CGPoint(x: p.x, y: p.y - 40 * ds)
            ctx.fill(Path(ellipseIn: CGRect(x: lamp.x - 60 * ds, y: lamp.y - 60 * ds, width: 120 * ds, height: 120 * ds)),
                     with: .radialGradient(Gradient(colors: [Color(hex: 0xFFD27A).opacity(0.4 * Double(night)), .clear]),
                                           center: lamp, startRadius: 2, endRadius: 60 * ds))
            ctx.fill(Path(ellipseIn: CGRect(x: lamp.x - 5 * ds, y: lamp.y - 6 * ds, width: 10 * ds, height: 12 * ds)),
                     with: .color(Color(hex: 0xFFE2A0).opacity(Double(night))))
        }
        for d in game.save.decor where d.kind == .feenring {
            let p = game.screen(d.x, d.y)
            let ds = game.scale(atY: d.y)
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 60 * ds, y: p.y - 30 * ds, width: 120 * ds, height: 50 * ds)),
                     with: .radialGradient(Gradient(colors: [Color(hex: 0xC9A6FF).opacity(0.35 * Double(night)), .clear]),
                                           center: CGPoint(x: p.x, y: p.y - 5 * ds), startRadius: 2, endRadius: 60 * ds))
        }
        for r in game.save.rabbits where r.rarity == .legendaer {
            let p = game.screen(r.x, r.y)
            let rs = game.scale(atY: r.y)
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 40 * rs, y: p.y - 50 * rs, width: 80 * rs, height: 60 * rs)),
                     with: .radialGradient(Gradient(colors: [r.look.fur.main.opacity(0.3 * Double(night)), .clear]),
                                           center: CGPoint(x: p.x, y: p.y - 20 * rs), startRadius: 2, endRadius: 40 * rs))
        }
    }

    @MainActor
    static func drawBed(_ game: GardenGame, _ ctx: inout GraphicsContext, time: Double) {
        let r = GardenGame.bedRect
        let a = game.screen(r.minX, r.minY), b = game.screen(r.maxX, r.maxY)
        let rect = CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y)
        let s = game.scale(atY: Double(r.midY))
        ctx.fill(Path(roundedRect: rect.insetBy(dx: -4, dy: -3), cornerRadius: 10 * s), with: .color(Color(hex: 0x8E6440)))
        ctx.fill(Path(roundedRect: rect, cornerRadius: 8 * s), with: .color(Color(hex: 0x6B4429)))
        var furrows = Path()
        for k in 1..<4 {
            let y = rect.minY + rect.height * CGFloat(k) / 4
            furrows.move(to: CGPoint(x: rect.minX + 6, y: y)); furrows.addLine(to: CGPoint(x: rect.maxX - 6, y: y))
        }
        ctx.stroke(furrows, with: .color(Color(hex: 0x553420)), lineWidth: 2)

        for i in game.save.bed.indices {
            let slot = game.save.bed[i]
            let c = GardenGame.slotCenter(i)
            let p = game.screen(c.x, c.y)
            let watered = (slot.wateredUntil ?? .distantPast) > .now
            if watered {
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 18 * s, y: p.y - 7 * s, width: 36 * s, height: 14 * s)),
                         with: .color(Color(hex: 0x3B2416).opacity(0.6)))
            }
            guard slot.planted != nil else {
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 5 * s, y: p.y - 2 * s, width: 10 * s, height: 4 * s)),
                         with: .color(Color(hex: 0x4A2D1B)))
                continue
            }
            let g = CGFloat(slot.growth)
            let leafH = (6 + 22 * g) * s
            let sway = CGFloat(sin(time * 2 + Double(i))) * 2 * s
            for l in -1...1 {
                var leaf = Path()
                leaf.move(to: CGPoint(x: p.x, y: p.y))
                leaf.addQuadCurve(to: CGPoint(x: p.x + CGFloat(l) * 9 * s * g + sway, y: p.y - leafH),
                                  control: CGPoint(x: p.x + CGFloat(l) * 2 * s, y: p.y - leafH * 0.6))
                ctx.stroke(leaf, with: .color(Color(hex: 0x4F9A3A)), style: StrokeStyle(lineWidth: 3 * s, lineCap: .round))
            }
            if slot.isReady {
                var top = Path()
                top.addEllipse(in: CGRect(x: p.x - 7 * s, y: p.y - 4 * s, width: 14 * s, height: 9 * s))
                ctx.fill(top, with: .color(Color(hex: 0xE2722B)))
                let pulse = 0.5 + 0.5 * sin(time * 4)
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 22 * s, y: p.y - 22 * s, width: 44 * s, height: 30 * s)),
                         with: .radialGradient(Gradient(colors: [Color(hex: 0xFFE38A).opacity(0.35 * pulse), .clear]),
                                               center: CGPoint(x: p.x, y: p.y - 8 * s), startRadius: 1, endRadius: 24 * s))
            }
        }
    }

    // MARK: - Futter & Blumen

    @MainActor
    static func drawFood(_ food: GardenFood, _ game: GardenGame, _ ctx: inout GraphicsContext) {
        let p = game.screen(food.x, food.y)
        let s = game.scale(atY: food.y) * (0.55 + 0.45 * CGFloat(food.amount))
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - 16 * s, y: p.y - 4 * s, width: 32 * s, height: 8 * s)), with: .color(.black.opacity(0.15)))
        let seed = Int(food.id.uuidString.hashValue & 0xFFFF)
        switch food.kind {
        case .heu:
            var mound = Path()
            mound.addEllipse(in: CGRect(x: p.x - 17 * s, y: p.y - 14 * s, width: 34 * s, height: 16 * s))
            ctx.fill(mound, with: .color(Color(hex: 0xD8B85A)))
            var straws = Path()
            for k in 0..<16 {
                let x = p.x + (hash(seed, k) - 0.5) * 32 * s
                let y = p.y - hash(seed, k, 1) * 12 * s
                let a = (hash(seed, k, 2) - 0.5) * 1.6
                straws.move(to: CGPoint(x: x - cos(a) * 8 * s, y: y - sin(a) * 4 * s))
                straws.addLine(to: CGPoint(x: x + cos(a) * 8 * s, y: y + sin(a) * 4 * s))
            }
            ctx.stroke(straws, with: .color(Color(hex: 0xB8953A)), lineWidth: 1.2 * s)
        case .loewenzahn:
            for k in 0..<5 {
                let a = Double(k) / 5 * .pi - .pi
                var leaf = Path()
                leaf.move(to: p)
                leaf.addQuadCurve(to: CGPoint(x: p.x + CGFloat(cos(a)) * 18 * s, y: p.y + CGFloat(sin(a)) * 9 * s),
                                  control: CGPoint(x: p.x + CGFloat(cos(a + 0.4)) * 12 * s, y: p.y + CGFloat(sin(a + 0.4)) * 8 * s))
                ctx.stroke(leaf, with: .color(Color(hex: 0x4E9A36)), style: StrokeStyle(lineWidth: 4 * s, lineCap: .round))
            }
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 6 * s, y: p.y - 12 * s, width: 12 * s, height: 12 * s)), with: .color(Color(hex: 0xF4C51C)))
        case .zweige:
            // Apfelzweige mit Knospen
            var twigs = Path()
            for k in 0..<4 {
                let a = (hash(seed, k, 5) - 0.5) * 0.9
                let len = (16 + hash(seed, k, 6) * 8) * s
                let start = CGPoint(x: p.x - len / 2 * cos(a), y: p.y - 3 * s - len / 2 * sin(a))
                let end = CGPoint(x: p.x + len / 2 * cos(a), y: p.y - 3 * s + len / 2 * sin(a))
                twigs.move(to: start)
                twigs.addQuadCurve(to: end, control: CGPoint(x: p.x, y: p.y - 6 * s))
                twigs.move(to: CGPoint(x: p.x + (hash(seed, k, 7) - 0.5) * len * 0.6, y: p.y - 4 * s))
                twigs.addLine(to: CGPoint(x: p.x + (hash(seed, k, 7) - 0.5) * len * 0.6 + 3 * s, y: p.y - 9 * s))
            }
            ctx.stroke(twigs, with: .color(Color(hex: 0x7A4E30)), style: StrokeStyle(lineWidth: 2 * s, lineCap: .round))
            for k in 0..<5 {
                let bx = p.x + (hash(seed, k, 8) - 0.5) * 20 * s, by = p.y - (3 + hash(seed, k, 9) * 6) * s
                ctx.fill(Path(ellipseIn: CGRect(x: bx - 1.6 * s, y: by - 1.6 * s, width: 3.2 * s, height: 3.2 * s)),
                         with: .color(Color(hex: 0x9BBF5A)))
            }
        case .moehre:
            var carrot = Path()
            carrot.move(to: CGPoint(x: p.x - 13 * s, y: p.y - 6 * s))
            carrot.addQuadCurve(to: CGPoint(x: p.x - 13 * s, y: p.y + 2 * s), control: CGPoint(x: p.x - 17 * s, y: p.y - 2 * s))
            carrot.addLine(to: CGPoint(x: p.x + 14 * s, y: p.y - 1 * s))
            carrot.closeSubpath()
            for k in 0..<3 {
                var leaf = Path()
                leaf.move(to: CGPoint(x: p.x - 14 * s, y: p.y - 2 * s))
                leaf.addLine(to: CGPoint(x: p.x - 24 * s, y: p.y - (8 - CGFloat(k) * 4) * s))
                ctx.stroke(leaf, with: .color(Color(hex: 0x4E9A36)), style: StrokeStyle(lineWidth: 2.5 * s, lineCap: .round))
            }
            ctx.fill(carrot, with: .color(Color(hex: 0xE8772E)))
            var rings = Path()
            for k in 1..<4 {
                let x = p.x - 12 * s + CGFloat(k) * 6 * s
                rings.move(to: CGPoint(x: x, y: p.y - 4 * s)); rings.addLine(to: CGPoint(x: x + 1 * s, y: p.y - 1 * s))
            }
            ctx.stroke(rings, with: .color(Color(hex: 0xB9561C)), lineWidth: 1 * s)
        }
    }

    @MainActor
    static func drawFlower(_ f: GardenFlower, _ game: GardenGame, _ ctx: inout GraphicsContext, time: Double) {
        let p = game.screen(f.x, f.y)
        let s = game.scale(atY: f.y)
        let sway = CGFloat(sin(time * 1.8 + f.x * 20)) * 2 * s
        let head = CGPoint(x: p.x + sway, y: p.y - 16 * s)
        var stem = Path()
        stem.move(to: p)
        stem.addQuadCurve(to: head, control: CGPoint(x: p.x, y: p.y - 8 * s))
        ctx.stroke(stem, with: .color(Color(hex: 0x3F7F2C)), lineWidth: 1.6 * s)
        switch f.kind {
        case .gaensebluemchen:
            for k in 0..<8 {
                let a = Double(k) / 8 * 2 * .pi
                let c = CGPoint(x: head.x + CGFloat(cos(a)) * 4.5 * s, y: head.y + CGFloat(sin(a)) * 4.5 * s * 0.8)
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - 2.6 * s, y: c.y - 2.6 * s, width: 5.2 * s, height: 5.2 * s)), with: .color(.white))
            }
            ctx.fill(Path(ellipseIn: CGRect(x: head.x - 2.6 * s, y: head.y - 2.6 * s, width: 5.2 * s, height: 5.2 * s)), with: .color(Color(hex: 0xF5C430)))
        case .loewenzahn:
            for k in 0..<12 {
                let a = Double(k) / 12 * 2 * .pi
                var petal = Path()
                petal.move(to: head)
                petal.addLine(to: CGPoint(x: head.x + CGFloat(cos(a)) * 6.5 * s, y: head.y + CGFloat(sin(a)) * 6.5 * s * 0.85))
                ctx.stroke(petal, with: .color(Color(hex: 0xF7C61E)), style: StrokeStyle(lineWidth: 2.4 * s, lineCap: .round))
            }
            ctx.fill(Path(ellipseIn: CGRect(x: head.x - 3 * s, y: head.y - 3 * s, width: 6 * s, height: 6 * s)), with: .color(Color(hex: 0xE9A80F)))
        case .gluecksklee:
            let glow = 0.5 + 0.5 * sin(time * 3)
            ctx.fill(Path(ellipseIn: CGRect(x: head.x - 16 * s, y: head.y - 16 * s, width: 32 * s, height: 32 * s)),
                     with: .radialGradient(Gradient(colors: [Color(hex: 0xC8FF9A).opacity(0.5 * glow), .clear]),
                                           center: head, startRadius: 1, endRadius: 16 * s))
            for k in 0..<4 {
                let a = Double(k) / 4 * 2 * .pi + .pi / 4
                let c = CGPoint(x: head.x + CGFloat(cos(a)) * 4 * s, y: head.y + CGFloat(sin(a)) * 4 * s)
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - 3.6 * s, y: c.y - 3.6 * s, width: 7.2 * s, height: 7.2 * s)), with: .color(Color(hex: 0x3FA33A)))
            }
        }
    }

    // MARK: - Deko

    @MainActor
    static func drawDecor(_ d: GardenDecor, _ game: GardenGame, _ ctx: inout GraphicsContext, time: Double) {
        let p = game.screen(d.x, d.y)
        let s = game.scale(atY: d.y)
        if game.tool == .gestalten {
            let selected = game.selectedDecorID == d.id
            let w: CGFloat = (d.kind == .teich || d.kind == .feenring ? 110 : 64) * s
            ctx.stroke(Path(ellipseIn: CGRect(x: p.x - w / 2, y: p.y - 10 * s, width: w, height: 20 * s)),
                       with: .color(.white.opacity(selected ? 0.95 : 0.35)),
                       style: StrokeStyle(lineWidth: selected ? 2.4 : 1.4, dash: [5, 4], dashPhase: selected ? CGFloat(time * 14) : 0))
        }
        ctx.drawLayer { l in
            l.translateBy(x: p.x, y: p.y)
            l.scaleBy(x: s, y: s)
            decorShape(&l, kind: d.kind, time: time, seed: Int(d.x * 1000))
        }
    }

    /// Deko am Boden bei y = 0, Einheit ≈ Punkte bei Maßstab 1.
    static func decorShape(_ ctx: inout GraphicsContext, kind: DecorKind, time: Double, seed: Int) {
        let shadow = Color.black.opacity(0.16)
        func ellipse(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path {
            Path(ellipseIn: CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h))
        }
        switch kind {
        case .stein:
            ctx.fill(ellipse(0, 0, 46, 10), with: .color(shadow))
            var rock = Path()
            rock.move(to: CGPoint(x: -22, y: 0))
            rock.addCurve(to: CGPoint(x: 22, y: 0), control1: CGPoint(x: -24, y: -34), control2: CGPoint(x: 20, y: -30))
            rock.closeSubpath()
            ctx.fill(rock, with: .linearGradient(Gradient(colors: [Color(hex: 0xBDB8AE), Color(hex: 0x8A857C)]),
                                                 startPoint: CGPoint(x: -10, y: -26), endPoint: CGPoint(x: 10, y: 0)))
            ctx.fill(ellipse(-6, -16, 12, 5), with: .color(.white.opacity(0.3)))
            ctx.fill(ellipse(10, -6, 9, 4), with: .color(Color(hex: 0x7FA36E).opacity(0.8)))
        case .busch:
            ctx.fill(ellipse(0, 0, 60, 12), with: .color(shadow))
            let greens = [Color(hex: 0x3F7A35), Color(hex: 0x4F8E3F), Color(hex: 0x62A34C)]
            let blobs: [(CGFloat, CGFloat, CGFloat)] = [(-16, -14, 18), (14, -14, 18), (0, -26, 20), (-4, -12, 16)]
            for (n, b) in blobs.enumerated() {
                ctx.fill(ellipse(b.0, b.1, b.2 * 2, b.2 * 1.8), with: .color(greens[n % 3]))
            }
            for k in 0..<5 {
                let x = -20 + hash(seed, k) * 40, y = -34 + hash(seed, k, 1) * 26
                ctx.fill(ellipse(x, y, 5, 5), with: .color(Color(hex: 0xE24A5A)))
            }
        case .pilz:
            ctx.fill(ellipse(0, 0, 30, 7), with: .color(shadow))
            ctx.fill(Path(roundedRect: CGRect(x: -5, y: -20, width: 10, height: 20), cornerRadius: 4), with: .color(Color(hex: 0xF4ECDD)))
            var cap = Path()
            cap.move(to: CGPoint(x: -17, y: -18))
            cap.addCurve(to: CGPoint(x: 17, y: -18), control1: CGPoint(x: -17, y: -42), control2: CGPoint(x: 17, y: -42))
            cap.closeSubpath()
            ctx.fill(cap, with: .color(Color(hex: 0xE0392F)))
            for (x, y) in [(-8.0, -26.0), (5.0, -31.0), (9.0, -22.0), (-2.0, -21.0)] {
                ctx.fill(ellipse(CGFloat(x), CGFloat(y), 4.5, 3.5), with: .color(.white))
            }
        case .sonnenblumen:
            ctx.fill(ellipse(0, 0, 40, 8), with: .color(shadow))
            for (k, h) in [(-10.0, 52.0), (4.0, 64.0), (14.0, 46.0)].enumerated() {
                let x = CGFloat(h.0), top = -CGFloat(h.1)
                let sway = CGFloat(sin(time * 1.4 + Double(k))) * 2
                var stem = Path()
                stem.move(to: CGPoint(x: x, y: 0)); stem.addQuadCurve(to: CGPoint(x: x + sway, y: top), control: CGPoint(x: x, y: top / 2))
                ctx.stroke(stem, with: .color(Color(hex: 0x3F7F2C)), lineWidth: 2.5)
                ctx.fill(ellipse(x + 6, top / 2, 10, 5), with: .color(Color(hex: 0x4E9A36)))
                for i in 0..<12 {
                    let a = Double(i) / 12 * 2 * .pi
                    ctx.fill(ellipse(x + sway + CGFloat(cos(a)) * 8, top + CGFloat(sin(a)) * 8, 7, 7), with: .color(Color(hex: 0xF7C21E)))
                }
                ctx.fill(ellipse(x + sway, top, 10, 10), with: .color(Color(hex: 0x6B3E1E)))
            }
        case .blumenbeet:
            ctx.fill(ellipse(0, -2, 64, 18), with: .color(Color(hex: 0x6B4429)))
            ctx.stroke(ellipse(0, -2, 64, 18), with: .color(Color(hex: 0xA2A09A)), lineWidth: 3)
            let colors = [Color(hex: 0xF27A9B), Color(hex: 0xB07CE8), Color(hex: 0xF7D154), Color(hex: 0xFFFFFF), Color(hex: 0xE24A5A)]
            for k in 0..<11 {
                let x = -24 + hash(seed, k, 3) * 48, y = -6 + hash(seed, k, 4) * 8
                ctx.stroke(Path { $0.move(to: CGPoint(x: x, y: y)); $0.addLine(to: CGPoint(x: x, y: y - 9)) },
                           with: .color(Color(hex: 0x3F7F2C)), lineWidth: 1.5)
                ctx.fill(ellipse(x, y - 10, 6, 6), with: .color(colors[k % colors.count]))
            }
        case .gartenzwerg:
            ctx.fill(ellipse(0, 0, 26, 6), with: .color(shadow))
            ctx.fill(Path(roundedRect: CGRect(x: -9, y: -20, width: 18, height: 20), cornerRadius: 6), with: .color(Color(hex: 0x3F6FB5)))
            ctx.fill(Path(CGRect(x: -9, y: -12, width: 18, height: 3)), with: .color(Color(hex: 0x5A3A22)))
            ctx.fill(ellipse(0, -16, 14, 12), with: .color(.white))
            ctx.fill(ellipse(0, -25, 12, 11), with: .color(Color(hex: 0xF2C9A8)))
            ctx.fill(ellipse(0, -23, 4, 4), with: .color(Color(hex: 0xE59A84)))
            var hat = Path()
            hat.move(to: CGPoint(x: -8, y: -28)); hat.addLine(to: CGPoint(x: 3, y: -50)); hat.addLine(to: CGPoint(x: 8, y: -28))
            hat.closeSubpath()
            ctx.fill(hat, with: .color(Color(hex: 0xD6372E)))
        case .baumstamm:
            ctx.fill(ellipse(0, 0, 70, 10), with: .color(shadow))
            ctx.fill(Path(roundedRect: CGRect(x: -32, y: -20, width: 60, height: 19), cornerRadius: 9), with: .color(Color(hex: 0x8A5B36)))
            var bark = Path()
            for k in 0..<4 {
                let y = -16 + CGFloat(k) * 4.5
                bark.move(to: CGPoint(x: -26, y: y)); bark.addLine(to: CGPoint(x: 18, y: y + 1))
            }
            ctx.stroke(bark, with: .color(Color(hex: 0x6B4429)), lineWidth: 1)
            ctx.fill(ellipse(28, -10.5, 12, 19), with: .color(Color(hex: 0xE3C08E)))
            ctx.stroke(ellipse(28, -10.5, 6, 10), with: .color(Color(hex: 0xB68B57)), lineWidth: 1)
            ctx.fill(ellipse(-12, -21, 14, 5), with: .color(Color(hex: 0x6FA548)))
        case .laterne:
            ctx.fill(ellipse(0, 0, 22, 6), with: .color(shadow))
            ctx.fill(Path(CGRect(x: -1.8, y: -34, width: 3.6, height: 34)), with: .color(Color(hex: 0x3A3A3A)))
            ctx.fill(Path(roundedRect: CGRect(x: -7, y: -48, width: 14, height: 16), cornerRadius: 3), with: .color(Color(hex: 0xFFE7B0)))
            ctx.stroke(Path(roundedRect: CGRect(x: -7, y: -48, width: 14, height: 16), cornerRadius: 3), with: .color(Color(hex: 0x3A3A3A)), lineWidth: 2)
            var roof = Path()
            roof.move(to: CGPoint(x: -10, y: -48)); roof.addLine(to: CGPoint(x: 0, y: -56)); roof.addLine(to: CGPoint(x: 10, y: -48))
            roof.closeSubpath()
            ctx.fill(roof, with: .color(Color(hex: 0x3A3A3A)))
        case .tunnel:
            ctx.fill(ellipse(0, 0, 86, 14), with: .color(shadow))
            var arch = Path()
            arch.move(to: CGPoint(x: -40, y: 0))
            arch.addCurve(to: CGPoint(x: 40, y: 0), control1: CGPoint(x: -40, y: -48), control2: CGPoint(x: 40, y: -48))
            arch.closeSubpath()
            ctx.fill(arch, with: .color(Color(hex: 0xC69B5E)))
            var weave = Path()
            for k in 0..<7 {
                let x = -33 + CGFloat(k) * 11
                weave.move(to: CGPoint(x: x, y: 0)); weave.addQuadCurve(to: CGPoint(x: x * 0.4, y: -35), control: CGPoint(x: x * 0.9, y: -26))
            }
            ctx.stroke(weave, with: .color(Color(hex: 0x9C7442)), lineWidth: 1.5)
            ctx.fill(ellipse(-40, -12, 10, 24), with: .color(Color(hex: 0x3B2618)))
            ctx.fill(ellipse(40, -12, 10, 24), with: .color(Color(hex: 0x2F1E13)))
        case .heuraufe:
            ctx.fill(ellipse(0, 0, 50, 9), with: .color(shadow))
            ctx.fill(Path(roundedRect: CGRect(x: -22, y: -40, width: 44, height: 40), cornerRadius: 3), with: .color(Color(hex: 0xB98A5A)))
            ctx.fill(Path(CGRect(x: -18, y: -36, width: 36, height: 22)), with: .color(Color(hex: 0xDCC06A)))
            var straws = Path()
            for k in 0..<10 {
                let x = -16 + CGFloat(k) * 3.6
                straws.move(to: CGPoint(x: x, y: -36)); straws.addLine(to: CGPoint(x: x + 3, y: -44 - hash(seed, k) * 5))
            }
            ctx.stroke(straws, with: .color(Color(hex: 0xC9A646)), lineWidth: 1.4)
            var bars = Path()
            for k in 0..<6 {
                let x = -18 + CGFloat(k) * 7.2
                bars.move(to: CGPoint(x: x, y: -36)); bars.addLine(to: CGPoint(x: x, y: -14))
            }
            ctx.stroke(bars, with: .color(Color(hex: 0x7A5230)), lineWidth: 2)
            ctx.fill(Path(CGRect(x: -24, y: -42, width: 48, height: 5)), with: .color(Color(hex: 0x8E6440)))
        case .teich:
            ctx.fill(ellipse(0, -4, 112, 34), with: .color(Color(hex: 0x8A857C)))
            ctx.fill(ellipse(0, -4, 100, 26), with: .linearGradient(Gradient(colors: [Color(hex: 0x4E8FC7), Color(hex: 0x7CC0E8)]),
                                                                  startPoint: CGPoint(x: 0, y: -17), endPoint: CGPoint(x: 0, y: 9)))
            let ripple = CGFloat((time * 0.6).truncatingRemainder(dividingBy: 1))
            ctx.stroke(ellipse(14, -2, 10 + 30 * ripple, 4 + 9 * ripple), with: .color(.white.opacity(0.5 * Double(1 - ripple))), lineWidth: 1)
            ctx.fill(ellipse(-26, -8, 18, 7), with: .color(Color(hex: 0x4E9A36)))
            ctx.fill(ellipse(-24, -10, 6, 4), with: .color(Color(hex: 0xF7B6CB)))
            ctx.fill(ellipse(-38, 4, 14, 6), with: .color(Color(hex: 0x4E9A36)))
            for k in 0..<3 {
                let x = 42 + CGFloat(k) * 4
                ctx.stroke(Path { $0.move(to: CGPoint(x: x, y: 2)); $0.addLine(to: CGPoint(x: x + 2, y: -26 + CGFloat(k) * 4)) },
                           with: .color(Color(hex: 0x4F8A3C)), lineWidth: 2)
            }
            ctx.fill(Path(roundedRect: CGRect(x: 44, y: -30, width: 4, height: 10), cornerRadius: 2), with: .color(Color(hex: 0x6B4429)))
        case .feenring:
            let glow = 0.5 + 0.5 * sin(time * 2)
            ctx.fill(ellipse(0, -2, 110, 36), with: .radialGradient(Gradient(colors: [Color(hex: 0xD8C2FF).opacity(0.25 + 0.2 * glow), .clear]),
                                                                    center: CGPoint(x: 0, y: -2), startRadius: 4, endRadius: 56))
            for k in 0..<11 {
                let a = Double(k) / 11 * 2 * .pi
                let x = CGFloat(cos(a)) * 48, y = CGFloat(sin(a)) * 15 - 2
                let sc: CGFloat = 0.55 + 0.25 * CGFloat(sin(a)) + 0.2
                ctx.fill(Path(roundedRect: CGRect(x: x - 2 * sc, y: y - 9 * sc, width: 4 * sc, height: 9 * sc), cornerRadius: 1.5),
                         with: .color(Color(hex: 0xF4ECDD)))
                var cap = Path()
                cap.addEllipse(in: CGRect(x: x - 7 * sc, y: y - 14 * sc, width: 14 * sc, height: 9 * sc))
                ctx.fill(cap, with: .color(Color(hex: 0xB18CF2)))
                let tw = 0.5 + 0.5 * sin(time * 3 + Double(k))
                ctx.fill(ellipse(x, y - 11 * sc, 3, 3), with: .color(.white.opacity(tw)))
            }
        }
    }

    // MARK: - Kaninchen

    static func pose(for r: GardenRabbit, actor a: RabbitActor, clock: Double) -> RabbitPose {
        var pose = RabbitPose()
        if a.isHopping {
            let t = a.hopT
            pose.lift = CGFloat(sin(.pi * t)) * CGFloat(a.hopHeight)
            pose.stretch = 1 + 0.14 * CGFloat(sin(.pi * t))
            if a.mode == .binky { pose.spin = CGFloat(sin(.pi * t)) * 0.55 * CGFloat(a.spinDirection) }
        }
        pose.breath = 1 + 0.018 * CGFloat(sin(clock * (a.mode == .sleep ? 2 : 3.4)))
        let petted = a.pettedUntil > clock
        switch a.mode {
        case .graze, .eat:
            pose.headDown = 1
            pose.chew = CGFloat(sin(clock * 16))
        case .sleep:
            pose.eyesClosed = true
            pose.earsBack = 0.9
            pose.breath = 1 + 0.03 * CGFloat(sin(clock * 1.6))
        case .flop:
            pose.flop = true
            pose.eyesClosed = true
        case .groom:
            pose.groom = CGFloat(sin(clock * 9))
            pose.headDown = 0.25
            pose.eyesClosed = true
            pose.happy = true
        case .startled:
            pose.earsBack = 0.5
        default:
            break
        }
        if petted {
            pose.eyesClosed = true
            pose.happy = true
            pose.earsBack = max(pose.earsBack, 0.75)
            pose.headDown = max(pose.headDown, 0.2)
        }
        if !r.isVisitor, r.mood < 30 || r.hunger < 25 { pose.earsBack = max(pose.earsBack, 0.45) }
        if a.blinkAt - clock < 0.13 { pose.eyesClosed = true }
        if a.twitchAt - clock < 0.3 { pose.earTwitch = CGFloat(sin((a.twitchAt - clock) * 40)) * 0.18 }
        if a.mode != .sleep && !a.isHopping && Int(clock * 0.7 + Double(r.x * 10)) % 3 == 0 {
            pose.nose = CGFloat(sin(clock * 28)) * 0.8
        }
        return pose
    }

    @MainActor
    static func drawRabbit(_ game: GardenGame, index: Int, _ ctx: inout GraphicsContext, time: Double) {
        let r = game.save.rabbits[index]
        let a = game.actors[r.id] ?? RabbitActor()
        let p = game.screen(r.x, r.y)
        let s = game.scale(atY: r.y) * r.look.breed.bodyScale * 1.12
        if a.mode == .hide { return }
        let pose = GardenRenderer.pose(for: r, actor: a, clock: game.clock)
        // Vermittlungsbereit: kleines Haus-Schild über dem Kopf
        if r.isReady {
            let c = CGPoint(x: p.x, y: p.y - 70 * game.scale(atY: r.y) * r.look.breed.bodyScale - pose.lift)
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 10, y: c.y - 10, width: 20, height: 20)), with: .color(MTheme.leaf.opacity(0.9)))
            let icon = ctx.resolve(Text(Image(systemName: "house.fill")).font(.system(size: 10, weight: .bold)).foregroundStyle(.white))
            ctx.draw(icon, at: c)
        }
        let selected = game.selectedID == r.id

        // Aura seltener Kaninchen
        if r.rarity >= .superSelten {
            let pulse = 0.75 + 0.25 * sin(time * 2.4 + r.x * 9)
            let glow = r.rarity == .legendaer ? r.look.fur.main : r.rarity.color
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 46 * s, y: p.y - 20 * s, width: 92 * s, height: 30 * s)),
                     with: .radialGradient(Gradient(colors: [glow.opacity((r.rarity == .legendaer ? 0.55 : 0.3) * pulse), .clear]),
                                           center: CGPoint(x: p.x, y: p.y - 4 * s), startRadius: 2, endRadius: 46 * s))
        }

        // Schatten
        let shadowW = (pose.flop ? 64 : 52) * s * (1 - min(pose.lift, 40) / 90)
        // weicher Schatten, leicht zur sonnenabgewandten Seite
        let shadowRect = CGRect(x: p.x - shadowW / 2 - 4 * s, y: p.y - 6 * s, width: shadowW + 8 * s, height: 13 * s)
        ctx.fill(Path(ellipseIn: shadowRect),
                 with: .radialGradient(Gradient(colors: [.black.opacity(0.32), .black.opacity(0.12), .clear]),
                                       center: CGPoint(x: shadowRect.midX, y: shadowRect.midY), startRadius: 0, endRadius: shadowRect.width / 2))
        if selected {
            let ring = CGRect(x: p.x - 34 * s, y: p.y - 9 * s, width: 68 * s, height: 18 * s)
            ctx.stroke(Path(ellipseIn: ring), with: .color(.white.opacity(0.85)),
                       style: StrokeStyle(lineWidth: 2.2, dash: [6, 5], dashPhase: CGFloat(time * 14)))
        }
        if r.isVisitor {
            // Vertrauen als kleiner Bogen über dem Gast
            let c = CGPoint(x: p.x, y: p.y - 66 * s - pose.lift)
            var bg = Path(); bg.addArc(center: c, radius: 9, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
            ctx.stroke(bg, with: .color(.white.opacity(0.35)), lineWidth: 3)
            var arc = Path()
            arc.addArc(center: c, radius: 9, startAngle: .degrees(-90),
                       endAngle: .degrees(-90 + 360 * r.trust / 100), clockwise: false)
            ctx.stroke(arc, with: .color(r.rarity.color), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            let icon = ctx.resolve(Text(Image(systemName: r.rarity.symbol)).font(.system(size: 8, weight: .bold))
                .foregroundStyle(r.rarity.color))
            ctx.draw(icon, at: c)

            // Wunsch als Sprechblase
            if let wish = r.wish {
                let done = r.wishFulfilled == true
                let bob = CGFloat(sin(time * 2.2)) * 1.5
                let b = CGRect(x: c.x + 14, y: c.y - 26 + bob, width: 30, height: 24)
                var bubble = Path(roundedRect: b, cornerRadius: 9)
                bubble.move(to: CGPoint(x: b.minX + 5, y: b.maxY - 2))
                bubble.addLine(to: CGPoint(x: b.minX - 4, y: b.maxY + 7))
                bubble.addLine(to: CGPoint(x: b.minX + 12, y: b.maxY - 1))
                bubble.closeSubpath()
                ctx.fill(bubble, with: .color(.black.opacity(0.12)))
                ctx.fill(bubble.offsetBy(dx: 0, dy: -1), with: .color(done ? Color(hex: 0xE4F4D8) : .white))
                let tint: Color = {
                    switch wish {
                    case .futter(let k): return k.tint
                    case .deko: return MTheme.leaf
                    case .streicheln: return Color(hex: 0xF27A9B)
                    case .kurzerRasen: return Color(hex: 0x5E9A3E)
                    }
                }()
                let symbol = ctx.resolve(Text(Image(systemName: done ? "checkmark" : wish.symbol))
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(done ? MTheme.leaf : tint))
                ctx.draw(symbol, at: CGPoint(x: b.midX, y: b.midY - 1))
                if wish == .streicheln, !done {
                    let w = b.width - 8
                    let f = CGFloat(min(1, (r.wishProgress ?? 0) / 10))
                    ctx.fill(Path(roundedRect: CGRect(x: b.minX + 4, y: b.maxY - 5, width: w, height: 2.5), cornerRadius: 1.2),
                             with: .color(.black.opacity(0.1)))
                    ctx.fill(Path(roundedRect: CGRect(x: b.minX + 4, y: b.maxY - 5, width: w * f, height: 2.5), cornerRadius: 1.2),
                             with: .color(tint))
                }
            }
        }

        ctx.drawLayer { layer in
            layer.translateBy(x: p.x, y: p.y - pose.lift)
            layer.scaleBy(x: a.facing * s, y: s)
            if pose.spin != 0 {
                layer.translateBy(x: 0, y: -18)
                layer.rotate(by: .radians(Double(pose.spin)))
                layer.translateBy(x: 0, y: 18)
            }
            rabbitShape(&layer, look: r.look, pose: pose)
        }
    }

    struct Palette {
        var main: Color
        var shade: Color
        var belly: Color
        var spot: Color
        var outline: Color
        var ear = Color(hex: 0xF2B3B8)
    }

    static func palette(_ look: RabbitLook) -> Palette {
        let white = GardenFur.weiss
        switch look.pattern {
        case .schecke:
            let spot = (look.fur == .weiss || look.fur == .creme) ? look.accent.main : look.fur.main
            return Palette(main: white.main, shade: white.shade, belly: white.belly, spot: spot, outline: white.shade)
        case .russe:
            return Palette(main: white.main, shade: white.shade, belly: white.belly,
                           spot: look.accent.shade, outline: white.shade)
        case .loh:
            return Palette(main: look.fur.main, shade: look.fur.shade, belly: Color(hex: 0xE09A55),
                           spot: Color(hex: 0xDB8F48), outline: look.fur.shade)
        case .japaner:
            return Palette(main: look.fur.main, shade: look.fur.shade, belly: Color(hex: 0xF0C089),
                           spot: Color(hex: 0xDE8A3E), outline: look.fur.shade)
        case .thueringer:
            return Palette(main: Color(hex: 0xC9995A), shade: Color(hex: 0x8C6235), belly: Color(hex: 0xB8874E),
                           spot: Color(hex: 0x4A3022), outline: Color(hex: 0x8C6235))
        default:
            let spot = look.fur == .weiss ? look.accent.main : Color(hex: 0xF8F4EE)
            return Palette(main: look.fur.main, shade: look.fur.shade, belly: look.fur.belly, spot: spot, outline: look.fur.shade)
        }
    }

    /// Kaninchen nach rechts blickend, Boden bei y = 0, Einheit ≈ Punkte bei Maßstab 1.
    /// Aufbau wie ein echtes sitzendes Kaninchen: tiefe Brust, hoher runder Rücken,
    /// kräftige Keule, länglicher Kopf mit Schnauze, große Augen seitlich am Kopf.
    static func rabbitShape(_ ctx: inout GraphicsContext, look: RabbitLook, pose: RabbitPose) {
        let pal = palette(look)
        let seed = (look.fur.rawValue + look.pattern.rawValue + look.breed.rawValue).utf8.reduce(7) { $0 &* 31 &+ Int($1) }

        if pose.flop {
            flopShape(&ctx, look: look, pal: pal, pose: pose, seed: seed)
            return
        }

        ctx.scaleBy(x: look.breed.bodyLength / pose.stretch, y: pose.stretch * pose.breath)

        let grooming = pose.groom > -1
        let hc = CGPoint(x: 14 + 8 * pose.headDown + (grooming ? pose.groom * 0.6 : 0),
                         y: -25 + 17 * pose.headDown + pose.chew * 0.5 + (grooming ? 2 : 0))
        let dark = mix(pal.main, pal.shade, 0.65)

        drawTail(&ctx, at: CGPoint(x: -32, y: -16), look: look, pal: pal)

        // Körper
        let body = bodyPath()
        if look.breed == .angora || look.breed == .loewenkopf {
            fluff(&ctx, around: body, color: pal.main, shade: pal.shade, width: look.breed == .angora ? 9 : 4)
        }
        ctx.fill(body, with: .linearGradient(Gradient(colors: [pal.main, pal.main, dark]),
                                             startPoint: CGPoint(x: -8, y: -34), endPoint: CGPoint(x: -4, y: 0)))
        ctx.drawLayer { l in
            l.clip(to: body)
            bodyPattern(&l, look: look, pal: pal, seed: seed)
            // Brust und Bauch
            l.fill(Path(ellipseIn: CGRect(x: 3, y: -20, width: 14, height: 20)), with: .color(pal.belly.opacity(0.22)))
            l.fill(Path(ellipseIn: CGRect(x: -16, y: -8, width: 34, height: 11)), with: .color(pal.belly.opacity(0.32)))
            // Keule
            var thigh = Path()
            thigh.move(to: CGPoint(x: -4, y: -1))
            thigh.addCurve(to: CGPoint(x: -20, y: -27), control1: CGPoint(x: -2, y: -15), control2: CGPoint(x: -9, y: -27))
            thigh.addCurve(to: CGPoint(x: -33, y: -10), control1: CGPoint(x: -29, y: -27), control2: CGPoint(x: -34, y: -18))
            thigh.addCurve(to: CGPoint(x: -24, y: -1), control1: CGPoint(x: -31, y: -4), control2: CGPoint(x: -28, y: -1))
            thigh.closeSubpath()
            l.fill(thigh, with: .color(pal.shade.opacity(0.16)))
            var thighLight = Path()
            thighLight.move(to: CGPoint(x: -5, y: -6))
            thighLight.addCurve(to: CGPoint(x: -22, y: -25), control1: CGPoint(x: -4, y: -17), control2: CGPoint(x: -12, y: -25))
            l.stroke(thighLight, with: .color(.white.opacity(0.22)), lineWidth: 1.4)
            // Licht von oben
            l.fill(Path(ellipseIn: CGRect(x: -32, y: -44, width: 40, height: 26)),
                   with: .radialGradient(Gradient(colors: [.white.opacity(0.32), .clear]),
                                         center: CGPoint(x: -12, y: -31), startRadius: 0, endRadius: 19))
            furTexture(&l, rect: CGRect(x: -34, y: -35, width: 54, height: 34), look: look, pal: pal, seed: seed, count: 60)
            // Schatten am Boden
            l.fill(Path(CGRect(x: -40, y: -7, width: 70, height: 8)),
                   with: .linearGradient(Gradient(colors: [.clear, .black.opacity(0.18)]),
                                         startPoint: CGPoint(x: 0, y: -7), endPoint: CGPoint(x: 0, y: 0)))
        }
        ctx.stroke(body, with: .color(pal.shade.opacity(0.3)), lineWidth: 0.7)
        // flauschige Fellkante statt harter Linie
        ctx.stroke(body, with: .color(mix(pal.main, .white, 0.1).opacity(0.9)),
                   style: StrokeStyle(lineWidth: look.breed == .rex ? 0.8 : 1.8, lineCap: .round, dash: [0.5, 1.7]))

        // Hinterpfote und Vorderpfoten
        let footColor = look.pattern == .russe ? pal.spot : (look.pattern == .hollaender ? pal.spot : mix(pal.main, pal.belly, 0.2))
        let foot = Path(roundedRect: CGRect(x: -31, y: -4.5, width: 25, height: 5), cornerRadius: 2.5)
        ctx.fill(foot, with: .color(footColor))
        ctx.stroke(foot, with: .color(pal.shade.opacity(0.35)), lineWidth: 0.6)
        let pawColor = look.pattern == .russe ? pal.spot : mix(pal.belly, pal.main, 0.3)
        let pawY: CGFloat = grooming ? hc.y + 8 + pose.groom * 2 : -4.2
        let pawX: CGFloat = grooming ? hc.x + 3 : 8
        for k in 0..<2 {
            let paw = Path(roundedRect: CGRect(x: pawX + CGFloat(k) * 5.5, y: pawY + (grooming && k == 1 ? 1 : 0), width: 8.5, height: 4.6),
                           cornerRadius: 2.3)
            ctx.fill(paw, with: .color(pawColor))
            ctx.stroke(paw, with: .color(pal.shade.opacity(0.35)), lineWidth: 0.5)
        }

        // Kopf
        ctx.drawLayer { h in
            h.translateBy(x: hc.x, y: hc.y)
            h.rotate(by: .radians(Double(pose.headDown) * 0.38))
            let hs = look.breed.headScale
            h.scaleBy(x: hs / look.breed.bodyLength, y: hs)
            drawHead(&h, look: look, pal: pal, pose: pose, seed: seed)
        }

        // Pfoten vor dem Gesicht beim Putzen
        if grooming {
            ctx.fill(Path(roundedRect: CGRect(x: hc.x + 4, y: hc.y + 4 + pose.groom * 2, width: 7, height: 4.5), cornerRadius: 2.2),
                     with: .color(pawColor))
        }
    }

    /// Flauschiger Rand aus Fellbüscheln (Angora, Löwenkopf).
    private static func fluff(_ ctx: inout GraphicsContext, around path: Path, color: Color, shade: Color, width: CGFloat) {
        ctx.stroke(path, with: .color(mix(color, shade, 0.2)),
                   style: StrokeStyle(lineWidth: width * 2, lineCap: .round, dash: [1.2, width * 0.55]))
        ctx.stroke(path, with: .color(color),
                   style: StrokeStyle(lineWidth: width * 1.4, lineCap: .round, dash: [1.5, width * 0.4], dashPhase: 2))
    }

    private static func bodyPath() -> Path { bodyShape }
    private static let bodyShape: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 13, y: -1))
        p.addCurve(to: CGPoint(x: 14, y: -18), control1: CGPoint(x: 17, y: -5), control2: CGPoint(x: 17, y: -12))
        p.addCurve(to: CGPoint(x: -2, y: -30), control1: CGPoint(x: 11, y: -24), control2: CGPoint(x: 5, y: -29))
        p.addCurve(to: CGPoint(x: -24, y: -31), control1: CGPoint(x: -10, y: -36), control2: CGPoint(x: -18, y: -36))
        p.addCurve(to: CGPoint(x: -32, y: -11), control1: CGPoint(x: -31, y: -27), control2: CGPoint(x: -33, y: -19))
        p.addCurve(to: CGPoint(x: -23, y: -1), control1: CGPoint(x: -31, y: -4), control2: CGPoint(x: -28, y: -1))
        p.closeSubpath()
        return p
    }()

    /// Kopf mit Schnauze, Ursprung in der Kopfmitte, Nase bei etwa (17, -1).
    private static func headPath() -> Path { headShape }
    private static let headShape: Path = {
        var p = Path()
        p.move(to: CGPoint(x: -12, y: 0))
        p.addCurve(to: CGPoint(x: 2, y: -12), control1: CGPoint(x: -12, y: -8), control2: CGPoint(x: -6, y: -12))
        p.addCurve(to: CGPoint(x: 17.5, y: -1), control1: CGPoint(x: 10, y: -12), control2: CGPoint(x: 16.5, y: -6))
        p.addCurve(to: CGPoint(x: 11, y: 7.5), control1: CGPoint(x: 18.5, y: 3.5), control2: CGPoint(x: 15, y: 7.5))
        p.addCurve(to: CGPoint(x: -4, y: 10), control1: CGPoint(x: 6, y: 8.5), control2: CGPoint(x: 2, y: 12))
        p.addCurve(to: CGPoint(x: -12, y: 0), control1: CGPoint(x: -10, y: 8.5), control2: CGPoint(x: -12, y: 5))
        p.closeSubpath()
        return p
    }()

    /// Kurze, leicht gebogene Haarstriche – Fell statt glatter Fläche.
    /// Fellstriche hängen nur von Rasse, Farbe und Fläche ab – einmal bauen, dann wiederverwenden.
    nonisolated(unsafe) private static var furCache: [String: Path] = [:]

    private static func furPath(in r: CGRect, count: Int, seed: Int, length: CGFloat = 4.5, angle: CGFloat = 2.6) -> Path {
        let key = "\(seed)|\(count)|\(r.minX),\(r.minY),\(r.width),\(r.height)|\(length)|\(angle)"
        if let cached = furCache[key] { return cached }
        let path = buildFurPath(in: r, count: count, seed: seed, length: length, angle: angle)
        if furCache.count > 400 { furCache.removeAll() }
        furCache[key] = path
        return path
    }

    private static func buildFurPath(in r: CGRect, count: Int, seed: Int, length: CGFloat, angle: CGFloat) -> Path {
        var p = Path()
        for k in 0..<count {
            let x = r.minX + hash(seed, k, 11) * r.width
            let y = r.minY + hash(seed, k, 12) * r.height
            let a = angle + (hash(seed, k, 13) - 0.5) * 0.7
            let len = length * (0.6 + hash(seed, k, 14) * 0.8)
            p.move(to: CGPoint(x: x, y: y))
            p.addQuadCurve(to: CGPoint(x: x + cos(a) * len, y: y + sin(a) * len),
                           control: CGPoint(x: x + cos(a - 0.45) * len * 0.5, y: y + sin(a - 0.45) * len * 0.5))
        }
        return p
    }

    private static func furTexture(_ l: inout GraphicsContext, rect: CGRect, look: RabbitLook, pal: Palette, seed: Int, count: Int) {
        switch look.breed {
        case .rex:
            // Samtfell: kaum Haarstriche, dafür seidiger Glanz
            l.fill(Path(ellipseIn: CGRect(x: rect.minX + rect.width * 0.2, y: rect.minY, width: rect.width * 0.5, height: rect.height * 0.35)),
                   with: .color(.white.opacity(0.18)))
            l.stroke(furPath(in: rect, count: count / 3, seed: seed, length: 2), with: .color(pal.shade.opacity(0.18)), lineWidth: 0.5)
        case .angora:
            l.stroke(furPath(in: rect, count: count * 2, seed: seed, length: 9, angle: 2.2), with: .color(pal.shade.opacity(0.28)), lineWidth: 0.8)
            l.stroke(furPath(in: rect, count: count, seed: seed &+ 9, length: 9, angle: 2.0), with: .color(.white.opacity(0.3)), lineWidth: 0.9)
        default:
            l.stroke(furPath(in: rect, count: count, seed: seed), with: .color(pal.shade.opacity(0.3)), lineWidth: 0.7)
            l.stroke(furPath(in: rect, count: count / 2, seed: seed &+ 9), with: .color(.white.opacity(0.18)), lineWidth: 0.7)
        }
        // Wildfarbene Kaninchen haben gesprenkeltes ("geticktes") Fell.
        if look.fur == .wildfarben || look.fur == .sand || look.fur == .silber {
            let key = "tick|\(seed)|\(rect.minX),\(rect.minY),\(rect.width),\(rect.height)"
            let dots: Path
            if let cached = furCache[key] { dots = cached } else {
            var built = Path()
            for k in 0..<45 {
                let x = rect.minX + hash(seed, k, 21) * rect.width
                let y = rect.minY + hash(seed, k, 22) * rect.height * 0.8
                let r: CGFloat = 0.45 + hash(seed, k, 23) * 0.45
                built.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            }
            furCache[key] = built
            dots = built
            }
            l.fill(dots, with: .color((look.fur == .silber ? Color.white : Color(hex: 0x2E2018)).opacity(0.35)))
        }
    }

    private static func bodyPattern(_ l: inout GraphicsContext, look: RabbitLook, pal: Palette, seed: Int) {
        switch look.pattern {
        case .hollaender:
            var front = Path()
            front.move(to: CGPoint(x: 0, y: -40))
            front.addQuadCurve(to: CGPoint(x: -6, y: 2), control: CGPoint(x: -9, y: -18))
            front.addLine(to: CGPoint(x: 30, y: 2))
            front.addLine(to: CGPoint(x: 30, y: -40))
            front.closeSubpath()
            l.fill(front, with: .color(pal.spot))
        case .schecke:
            for k in 0..<4 {
                let x = -28 + hash(seed, k) * 34
                let y = -30 + hash(seed, k, 1) * 18
                let w = 8 + hash(seed, k, 2) * 9
                var blob = Path()
                blob.addEllipse(in: CGRect(x: x, y: y, width: w, height: w * 0.75))
                blob.addEllipse(in: CGRect(x: x + w * 0.4, y: y + w * 0.3, width: w * 0.6, height: w * 0.5))
                l.fill(blob, with: .color(pal.spot))
            }
            // Aalstrich entlang des Rückens
            var stripe = Path()
            stripe.move(to: CGPoint(x: 6, y: -31))
            stripe.addCurve(to: CGPoint(x: -30, y: -24), control1: CGPoint(x: -6, y: -35), control2: CGPoint(x: -22, y: -34))
            l.stroke(stripe, with: .color(pal.spot), lineWidth: 5)
        case .blesse:
            l.fill(Path(ellipseIn: CGRect(x: 8, y: -24, width: 12, height: 18)), with: .color(pal.spot.opacity(0.9)))
        case .loh:
            // lohfarbener Bauch, Brust und Unterseite mit scharfer Kante
            l.fill(Path(ellipseIn: CGRect(x: -34, y: -10, width: 54, height: 16)), with: .color(pal.spot))
            l.fill(Path(ellipseIn: CGRect(x: 6, y: -22, width: 14, height: 22)), with: .color(pal.spot))
            var ticks = Path()
            for k in 0..<14 {
                let x = -30 + hash(seed, k, 31) * 44
                ticks.move(to: CGPoint(x: x, y: -12 + hash(seed, k, 32) * 4))
                ticks.addLine(to: CGPoint(x: x - 1.5, y: -9))
            }
            l.stroke(ticks, with: .color(pal.spot), lineWidth: 1.2)
        case .japaner:
            // Harlekin: abwechselnde Bänder
            for k in 0..<6 where k % 2 == 1 {
                let x = -36 + CGFloat(k) * 9.5
                var band = Path()
                band.move(to: CGPoint(x: x, y: -40))
                band.addLine(to: CGPoint(x: x + 9.5, y: -40))
                band.addLine(to: CGPoint(x: x + 7, y: 2))
                band.addLine(to: CGPoint(x: x - 2.5, y: 2))
                band.closeSubpath()
                l.fill(band, with: .color(pal.spot))
            }
        case .thueringer:
            // rußiger Schleier an Flanken und Hinterteil
            l.fill(Path(ellipseIn: CGRect(x: -40, y: -28, width: 30, height: 34)),
                   with: .radialGradient(Gradient(colors: [pal.spot.opacity(0.55), .clear]),
                                         center: CGPoint(x: -30, y: -10), startRadius: 0, endRadius: 22))
            l.fill(Path(CGRect(x: -40, y: -8, width: 70, height: 10)),
                   with: .linearGradient(Gradient(colors: [.clear, pal.spot.opacity(0.45)]),
                                         startPoint: CGPoint(x: 0, y: -8), endPoint: CGPoint(x: 0, y: 0)))
        case .russe, .einfarbig:
            break
        }
        if look.fur == .nacht && look.pattern != .russe {
            var stars = Path()
            for k in 0..<10 {
                let x = -28 + hash(k, 61) * 40, y = -31 + hash(k, 62) * 26, r = 0.6 + hash(k, 63) * 0.9
                stars.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            }
            l.fill(stars, with: .color(.white.opacity(0.9)))
        }
        if look.fur == .mond || look.fur == .gold {
            l.fill(Path(ellipseIn: CGRect(x: -18, y: -33, width: 26, height: 9)), with: .color(.white.opacity(0.4)))
        }
    }

    private static func drawTail(_ ctx: inout GraphicsContext, at c: CGPoint, look: RabbitLook, pal: Palette) {
        let color = look.pattern == .russe ? pal.spot : pal.belly
        for (dx, dy, r) in [(CGFloat(-1), CGFloat(-1), CGFloat(5.5)), (2, -4, 4.5), (-2.5, 3, 4)] {
            let center = CGPoint(x: c.x + dx, y: c.y + dy)
            ctx.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                     with: .radialGradient(Gradient(colors: [mix(color, .white, 0.2), mix(color, pal.shade, 0.25)]),
                                           center: CGPoint(x: center.x - 1, y: center.y - 1.5), startRadius: 0, endRadius: r))
        }
    }

    /// Kopf samt Ohren und Gesicht, Ursprung in der Kopfmitte.
    private static func drawHead(_ h: inout GraphicsContext, look: RabbitLook, pal: Palette, pose: RabbitPose, seed: Int) {
        let lop = look.breed == .widder
        let earLen = look.breed.earLength
        let earW: CGFloat = look.breed == .riese ? 13 : (look.breed == .hermelin ? 10.5 : 11)
        let earC = earColor(look, pal)
        let dark = mix(pal.main, pal.shade, 0.65)

        // Löwenkopf-Mähne
        if look.breed == .loewenkopf {
            let mane = mix(pal.main, pal.belly, 0.25)
            for k in 0..<18 {
                let ang = 0.35 * .pi + Double(k) / 17 * 1.5 * .pi
                let rr: CGFloat = 14 + hash(seed, k, 41) * 3
                let c = CGPoint(x: -1 + CGFloat(cos(ang)) * rr, y: 1 + CGFloat(sin(ang)) * rr * 0.9)
                h.fill(Path(ellipseIn: CGRect(x: c.x - 7, y: c.y - 6.5, width: 14, height: 13)), with: .color(mane))
            }
            h.stroke(furPath(in: CGRect(x: -26, y: -16, width: 30, height: 36), count: 60, seed: seed &+ 5, length: 9, angle: 2.2),
                     with: .color(pal.shade.opacity(0.35)), lineWidth: 0.8)
            h.stroke(furPath(in: CGRect(x: -26, y: -16, width: 30, height: 36), count: 30, seed: seed &+ 6, length: 9, angle: 1.9),
                     with: .color(.white.opacity(0.3)), lineWidth: 0.8)
        }

        // Ohren hinter dem Kopf
        if lop {
            ear(&h, base: CGPoint(x: -6, y: -7), length: earLen * 0.95, width: 13.5, angle: 0.4 + pose.earTwitch * 0.3,
                hanging: true, color: mix(earC, pal.shade, 0.35), inner: nil, shade: pal.shade)
        } else {
            ear(&h, base: CGPoint(x: -8, y: -8), length: earLen, width: earW,
                angle: -0.45 - pose.earsBack * 0.85 + pose.earTwitch, hanging: false,
                color: mix(earC, pal.shade, 0.3), inner: Color(hex: 0xC98A92), shade: pal.shade)
            ear(&h, base: CGPoint(x: -3, y: -10), length: earLen + 1, width: earW + 0.5,
                angle: -0.17 - pose.earsBack * 0.95, hanging: false, color: earC, inner: pal.ear, shade: pal.shade)
        }

        let head = headPath()
        h.fill(head, with: .radialGradient(Gradient(colors: [mix(pal.main, .white, 0.14), pal.main, dark]),
                                           center: CGPoint(x: 2, y: -6), startRadius: 1, endRadius: 20))
        h.drawLayer { f in
            f.clip(to: head)
            switch look.pattern {
            case .hollaender, .blesse:
                var blaze = Path()
                blaze.move(to: CGPoint(x: 3, y: -12.5))
                blaze.addQuadCurve(to: CGPoint(x: 18.5, y: -1), control: CGPoint(x: 13, y: -9))
                blaze.addLine(to: CGPoint(x: 13, y: 10))
                blaze.addQuadCurve(to: CGPoint(x: 3, y: -12.5), control: CGPoint(x: 3, y: 0))
                f.fill(blaze, with: .color(pal.spot))
            case .schecke:
                f.fill(Path(ellipseIn: CGRect(x: 8, y: -6, width: 10, height: 8)), with: .color(pal.spot))
                f.fill(Path(ellipseIn: CGRect(x: 11, y: -2, width: 8, height: 7)), with: .color(pal.spot))
                f.fill(Path(ellipseIn: CGRect(x: -1.5, y: -9, width: 12, height: 11)), with: .color(pal.spot))
            case .russe:
                f.fill(Path(ellipseIn: CGRect(x: 7.5, y: -7, width: 14, height: 15)), with: .color(pal.spot))
            case .thueringer:
                f.fill(Path(ellipseIn: CGRect(x: 2, y: -10, width: 22, height: 22)),
                       with: .radialGradient(Gradient(colors: [pal.spot.opacity(0.85), pal.spot.opacity(0)]),
                                             center: CGPoint(x: 16, y: 0), startRadius: 1, endRadius: 13))
            case .loh:
                f.fill(Path(ellipseIn: CGRect(x: -6, y: 4, width: 24, height: 10)), with: .color(pal.spot))
            case .japaner:
                f.fill(Path(CGRect(x: -14, y: -14, width: 17, height: 30)), with: .color(pal.spot))
            case .einfarbig:
                break
            }
            // Wange, Schnauzenpolster, Kiefer
            f.fill(Path(ellipseIn: CGRect(x: -7, y: -1, width: 17, height: 12)), with: .color(pal.belly.opacity(0.2)))
            f.fill(Path(ellipseIn: CGRect(x: 9.5, y: -2.5, width: 8.5, height: 8)),
                   with: .color(mix(look.pattern == .russe ? pal.spot : pal.main, pal.belly, 0.55).opacity(0.4)))
            f.fill(Path(ellipseIn: CGRect(x: -14, y: 4, width: 30, height: 12)), with: .color(pal.shade.opacity(0.22)))
            f.stroke(furPath(in: CGRect(x: -12, y: -12, width: 22, height: 20), count: 20, seed: seed &+ 3, length: 3, angle: 2.9),
                     with: .color(pal.shade.opacity(0.25)), lineWidth: 0.6)
        }
        h.stroke(head, with: .color(pal.shade.opacity(0.3)), lineWidth: 0.7)
        h.stroke(head, with: .color(pal.main.opacity(0.85)),
                 style: StrokeStyle(lineWidth: look.breed == .rex ? 0.6 : 1.3, lineCap: .round, dash: [0.4, 1.6]))

        // Auge mit hellem Augenring
        let eye = CGPoint(x: 4.5, y: -3.5)
        let ringColor = look.pattern == .loh ? pal.spot
            : (look.fur == .wildfarben || look.fur == .sand ? Color(hex: 0xF3E6D2) : mix(pal.main, pal.belly, 0.4))
        h.fill(Path(ellipseIn: CGRect(x: eye.x - 5.6, y: eye.y - 5.2, width: 11.2, height: 10.4)), with: .color(ringColor.opacity(0.75)))
        if pose.eyesClosed {
            var lid = Path()
            if pose.happy {
                lid.move(to: CGPoint(x: eye.x - 3.6, y: eye.y + 1))
                lid.addQuadCurve(to: CGPoint(x: eye.x + 3.6, y: eye.y + 1), control: CGPoint(x: eye.x, y: eye.y - 3))
            } else {
                lid.move(to: CGPoint(x: eye.x - 3.6, y: eye.y))
                lid.addQuadCurve(to: CGPoint(x: eye.x + 3.6, y: eye.y), control: CGPoint(x: eye.x, y: eye.y + 2.6))
            }
            h.stroke(lid, with: .color(Color(hex: 0x2A1D15)), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
        } else {
            let blue = look.breed == .hermelin
            let albino = !blue && (look.pattern == .russe || (look.fur == .weiss && look.pattern == .einfarbig))
            let outer = blue ? Color(hex: 0x1C3558) : (albino ? Color(hex: 0x8E1F33) : Color(hex: 0x1F1009))
            let inner = blue ? Color(hex: 0x6FA3E0) : (albino ? Color(hex: 0xE46D84) : Color(hex: 0x7A4626))
            let iris = CGRect(x: eye.x - 3.9, y: eye.y - 4.1, width: 7.8, height: 8.2)
            h.fill(Path(ellipseIn: iris), with: .radialGradient(Gradient(colors: [inner, outer]),
                                                               center: CGPoint(x: eye.x + 0.9, y: eye.y + 1.4),
                                                               startRadius: 0, endRadius: 4.6))
            h.fill(Path(ellipseIn: CGRect(x: eye.x - 1.9, y: eye.y - 1.8, width: 3.8, height: 4)), with: .color(.black.opacity(0.8)))
            var lid = Path()
            lid.addArc(center: eye, radius: 4.1, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
            h.stroke(lid, with: .color(Color(hex: 0x1F1009).opacity(0.6)), lineWidth: 1.1)
            h.fill(Path(ellipseIn: CGRect(x: eye.x + 0.2, y: eye.y - 3.2, width: 2.6, height: 2.4)), with: .color(.white))
            h.fill(Path(ellipseIn: CGRect(x: eye.x - 2.4, y: eye.y + 1.1, width: 1.2, height: 1.2)), with: .color(.white.opacity(0.6)))
        }

        // Nase, Mund, Schnurrhaare
        let n = CGPoint(x: 16.6, y: -1.6 + pose.nose * 0.8)
        var nose = Path()
        nose.move(to: CGPoint(x: n.x - 1.9, y: n.y - 1))
        nose.addQuadCurve(to: CGPoint(x: n.x + 1.1, y: n.y - 1.3), control: CGPoint(x: n.x - 0.4, y: n.y - 2.4))
        nose.addLine(to: CGPoint(x: n.x - 0.1, y: n.y + 1.2))
        nose.closeSubpath()
        h.fill(nose, with: .color(Color(hex: 0xD48592)))
        var mouth = Path()
        mouth.move(to: CGPoint(x: n.x - 0.1, y: n.y + 1.2))
        mouth.addQuadCurve(to: CGPoint(x: n.x - 2.4, y: n.y + 4.2), control: CGPoint(x: n.x + 0.2, y: n.y + 3.4))
        h.stroke(mouth, with: .color(pal.shade.opacity(0.7)), lineWidth: 0.7)
        let darkFur = [GardenFur.schwarz, .schoko, .nacht, .wildfarben].contains(look.fur) && look.pattern != .russe
        var whiskers = Path()
        for k in 0..<4 {
            let y0 = n.y + 2.2 + CGFloat(k) * 0.6
            whiskers.move(to: CGPoint(x: n.x - 3.5, y: y0))
            if look.breed == .rex {
                // Rex: gewellte Schnurrhaare
                whiskers.addCurve(to: CGPoint(x: n.x + 8 + CGFloat(k), y: y0 + CGFloat(k) * 2.4),
                                  control1: CGPoint(x: n.x + 1, y: y0 - 3), control2: CGPoint(x: n.x + 4, y: y0 + 4))
            } else {
                whiskers.addQuadCurve(to: CGPoint(x: n.x + 9 + CGFloat(k), y: y0 - 2 + CGFloat(k) * 2.6 + pose.nose * 0.4),
                                      control: CGPoint(x: n.x + 3, y: y0 - 1.5 + CGFloat(k)))
            }
        }
        h.stroke(whiskers, with: .color((darkFur ? Color.white : Color(hex: 0x4A3A30)).opacity(0.45)), lineWidth: 0.45)

        // Widder: vorderes Schlappohr vor dem Kopf
        if lop {
            ear(&h, base: CGPoint(x: -3, y: -9), length: earLen, width: 14, angle: 0.18 + pose.earTwitch * 0.3,
                hanging: true, color: earC, inner: nil, shade: pal.shade)
        }
    }

    private static func earColor(_ look: RabbitLook, _ pal: Palette) -> Color {
        switch look.pattern {
        case .russe, .schecke, .thueringer: pal.spot
        default: pal.main
        }
    }

    /// Blattförmiges Ohr: schmal am Ansatz, breit in der Mitte, runde Spitze.
    private static func ear(_ ctx: inout GraphicsContext, base: CGPoint, length L: CGFloat, width W: CGFloat,
                            angle: CGFloat, hanging: Bool, color: Color, inner: Color?, shade: Color) {
        ctx.drawLayer { l in
            l.translateBy(x: base.x, y: base.y)
            l.rotate(by: .radians(Double(angle)))
            let d: CGFloat = hanging ? 1 : -1
            var p = Path()
            p.move(to: CGPoint(x: -W * 0.32, y: 0))
            p.addCurve(to: CGPoint(x: 0, y: d * L), control1: CGPoint(x: -W * 0.78, y: d * L * 0.45),
                       control2: CGPoint(x: -W * 0.6, y: d * L))
            p.addCurve(to: CGPoint(x: W * 0.32, y: 0), control1: CGPoint(x: W * 0.62, y: d * L),
                       control2: CGPoint(x: W * 0.7, y: d * L * 0.4))
            p.closeSubpath()
            l.fill(p, with: .linearGradient(Gradient(colors: [color, mix(color, shade, 0.3)]),
                                            startPoint: .zero, endPoint: CGPoint(x: 0, y: d * L)))
            if let inner, !hanging {
                var q = Path()
                q.move(to: CGPoint(x: -W * 0.1, y: -3))
                q.addCurve(to: CGPoint(x: 0.3, y: -L * 0.86), control1: CGPoint(x: -W * 0.44, y: -L * 0.45),
                           control2: CGPoint(x: -W * 0.3, y: -L * 0.86))
                q.addCurve(to: CGPoint(x: W * 0.16, y: -3), control1: CGPoint(x: W * 0.32, y: -L * 0.86),
                           control2: CGPoint(x: W * 0.36, y: -L * 0.4))
                q.closeSubpath()
                l.fill(q, with: .linearGradient(Gradient(colors: [inner.opacity(0.95), inner.opacity(0.55)]),
                                                startPoint: CGPoint(x: 0, y: -3), endPoint: CGPoint(x: 0, y: -L)))
                var vein = Path()
                vein.move(to: CGPoint(x: 0.2, y: -5))
                vein.addQuadCurve(to: CGPoint(x: -0.4, y: -L * 0.72), control: CGPoint(x: -1.6, y: -L * 0.4))
                l.stroke(vein, with: .color(Color(hex: 0xB8606E).opacity(0.35)), lineWidth: 0.5)
            }
            if hanging {
                var fold = Path()
                fold.move(to: CGPoint(x: 0, y: 3))
                fold.addQuadCurve(to: CGPoint(x: 0.5, y: L * 0.85), control: CGPoint(x: -2.5, y: L * 0.5))
                l.stroke(fold, with: .color(shade.opacity(0.35)), lineWidth: 0.9)
            }
            l.stroke(p, with: .color(shade.opacity(0.45)), lineWidth: 0.7)
        }
    }

    /// Ausgestreckt auf der Seite liegend – das glücklichste Kaninchen der Welt.
    private static func flopShape(_ ctx: inout GraphicsContext, look: RabbitLook, pal: Palette, pose: RabbitPose, seed: Int) {
        ctx.scaleBy(x: 1, y: pose.breath)
        let dark = mix(pal.main, pal.shade, 0.65)
        // Hinterlauf ausgestreckt
        let leg = Path(roundedRect: CGRect(x: -47, y: -8, width: 22, height: 6.5), cornerRadius: 3.2)
        ctx.fill(leg, with: .color(look.pattern == .russe ? pal.spot : mix(pal.main, pal.belly, 0.35)))
        ctx.stroke(leg, with: .color(pal.shade.opacity(0.35)), lineWidth: 0.6)
        drawTail(&ctx, at: CGPoint(x: -32, y: -13), look: look, pal: pal)

        var body = Path()
        body.move(to: CGPoint(x: -32, y: -3))
        body.addCurve(to: CGPoint(x: -18, y: -21), control1: CGPoint(x: -37, y: -12), control2: CGPoint(x: -29, y: -20))
        body.addCurve(to: CGPoint(x: 18, y: -15), control1: CGPoint(x: -6, y: -23), control2: CGPoint(x: 10, y: -21))
        body.addCurve(to: CGPoint(x: 16, y: -1), control1: CGPoint(x: 24, y: -10), control2: CGPoint(x: 22, y: -2))
        body.closeSubpath()
        ctx.fill(body, with: .linearGradient(Gradient(colors: [pal.main, dark]),
                                             startPoint: CGPoint(x: 0, y: -22), endPoint: CGPoint(x: 0, y: 0)))
        ctx.drawLayer { l in
            l.clip(to: body)
            bodyPattern(&l, look: look, pal: pal, seed: seed)
            l.fill(Path(ellipseIn: CGRect(x: -20, y: -9, width: 34, height: 10)), with: .color(pal.belly.opacity(0.6)))
            l.fill(Path(ellipseIn: CGRect(x: -26, y: -28, width: 36, height: 18)),
                   with: .radialGradient(Gradient(colors: [.white.opacity(0.3), .clear]),
                                         center: CGPoint(x: -8, y: -20), startRadius: 0, endRadius: 16))
            furTexture(&l, rect: CGRect(x: -34, y: -23, width: 54, height: 22), look: look, pal: pal, seed: seed, count: 40)
        }
        ctx.stroke(body, with: .color(pal.shade.opacity(0.45)), lineWidth: 0.8)
        let paw = Path(roundedRect: CGRect(x: 13, y: -4.5, width: 15, height: 4.5), cornerRadius: 2.2)
        ctx.fill(paw, with: .color(look.pattern == .russe ? pal.spot : mix(pal.belly, pal.main, 0.3)))

        var headPose = pose
        headPose.eyesClosed = true
        headPose.happy = false
        headPose.earsBack = 1.45
        headPose.nose = 0
        ctx.drawLayer { h in
            h.translateBy(x: 25, y: -11)
            h.rotate(by: .radians(0.32))
            let hs = look.breed.headScale
            h.scaleBy(x: hs, y: hs)
            drawHead(&h, look: look, pal: pal, pose: headPose, seed: seed)
        }
    }

    // MARK: - Tiere der Luft, Wetter, Partikel

    static func drawButterflies(_ ctx: inout GraphicsContext, size: CGSize, top: CGFloat, time: Double, day: CGFloat) {
        guard day > 0.3 else { return }
        let colors = [Color(hex: 0xF7D154), Color(hex: 0xF4F1EA), Color(hex: 0xA6C8F2)]
        for k in 0..<3 {
            let t = time * (0.12 + Double(k) * 0.03) + Double(k) * 7
            let x = size.width * CGFloat(0.5 + 0.42 * sin(t) * cos(t * 0.37))
            let y = top + (size.height - top) * CGFloat(0.25 + 0.2 * sin(t * 1.3 + Double(k))) - 30
            let flap = CGFloat(abs(sin(time * 14 + Double(k))))
            let c = colors[k].opacity(Double(day))
            for side in [-1.0, 1.0] {
                let w = 7 * flap + 1.5
                ctx.fill(Path(ellipseIn: CGRect(x: x + CGFloat(side) * w / 2 - w / 2, y: y - 6, width: w, height: 7)), with: .color(c))
                ctx.fill(Path(ellipseIn: CGRect(x: x + CGFloat(side) * w / 2 - w / 2.5, y: y, width: w * 0.8, height: 5)), with: .color(c))
            }
            ctx.fill(Path(roundedRect: CGRect(x: x - 0.8, y: y - 6, width: 1.6, height: 10), cornerRadius: 0.8),
                     with: .color(Color(hex: 0x3A2A20).opacity(Double(day))))
        }
    }

    static func drawFireflies(_ ctx: inout GraphicsContext, size: CGSize, top: CGFloat, time: Double, night: CGFloat) {
        guard night > 0.4 else { return }
        for k in 0..<14 {
            let t = time * 0.2 + Double(k) * 3.1
            let x = size.width * (hash(k, 31) + 0.08 * CGFloat(sin(t * 1.3)))
            let y = top + (size.height - top) * (0.1 + hash(k, 32) * 0.7) + 14 * CGFloat(sin(t * 1.7))
            let glow = 0.5 + 0.5 * sin(time * (1.2 + Double(hash(k, 33))) + Double(k))
            let a = Double(night - 0.4) * 1.6 * (0.3 + 0.7 * glow)
            ctx.fill(Path(ellipseIn: CGRect(x: x - 9, y: y - 9, width: 18, height: 18)),
                     with: .radialGradient(Gradient(colors: [Color(hex: 0xE9FF8A).opacity(a * 0.6), .clear]),
                                           center: CGPoint(x: x, y: y), startRadius: 0, endRadius: 9))
            ctx.fill(Path(ellipseIn: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)), with: .color(Color(hex: 0xF4FFB8).opacity(a)))
        }
    }

    /// Schneedecke und Reif auf der Wiese.
    @MainActor
    static func drawGroundWeather(_ game: GardenGame, _ ctx: inout GraphicsContext, size: CGSize, top: CGFloat, time: Double) {
        let cover = CGFloat(game.snowCover)
        let lawn = CGRect(x: 0, y: top, width: size.width, height: size.height - top)
        if cover > 0.01 {
            ctx.fill(Path(lawn), with: .linearGradient(Gradient(colors: [Color(hex: 0xF4F8FB).opacity(Double(cover) * 0.95),
                                                                        Color(hex: 0xE6EEF4).opacity(Double(cover) * 0.9)]),
                                                       startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: size.height)))
            // weiche Schneewellen und blaue Schatten
            var drifts = Path()
            for k in 0..<26 {
                let fy = hash(k, 201)
                let y = top + fy * fy * (size.height - top)
                let x = hash(k, 202) * size.width
                let w = (40 + hash(k, 203) * 90) * (0.5 + fy)
                drifts.addEllipse(in: CGRect(x: x - w / 2, y: y - w * 0.06, width: w, height: w * 0.12))
            }
            ctx.fill(drifts, with: .color(Color(hex: 0xB9CBDD).opacity(Double(cover) * 0.35)))
        } else if game.isFreezing {
            // Reif glitzert
            ctx.fill(Path(lawn), with: .color(Color(hex: 0xDDEAF0).opacity(0.25)))
            var glints = Path()
            for k in 0..<50 {
                let tw = 0.5 + 0.5 * sin(time * 2 + Double(k))
                guard tw > 0.8 else { continue }
                let x = hash(k, 211) * size.width, y = top + hash(k, 212) * (size.height - top)
                glints.addEllipse(in: CGRect(x: x - 1, y: y - 1, width: 2, height: 2))
            }
            ctx.fill(glints, with: .color(.white.opacity(0.9)))
        }
    }

    static func drawSnowfall(_ ctx: inout GraphicsContext, size: CGSize, time: Double, amount: CGFloat, wind: CGFloat) {
        var near = Path(), far = Path()
        let count = Int(140 * amount)
        for k in 0..<count {
            let depth = hash(k, 221)                       // 0 = fern, 1 = nah
            let speed = 22 + Double(depth) * 50
            let y = CGFloat((Double(hash(k, 222)) * Double(size.height) + time * speed)
                .truncatingRemainder(dividingBy: Double(size.height + 20))) - 10
            let sway = CGFloat(sin(time * (0.8 + Double(depth)) + Double(k))) * 14 + y * 0.15 * (wind - 1)
            let x = (hash(k, 223) * (size.width + 60) - 30 + sway).truncatingRemainder(dividingBy: size.width + 60)
            let r = 1 + depth * 2.4
            let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
            if depth > 0.6 { near.addEllipse(in: rect) } else { far.addEllipse(in: rect) }
        }
        ctx.fill(far, with: .color(.white.opacity(0.7)))
        ctx.fill(near, with: .color(.white.opacity(0.95)))
    }

    static func drawRain(_ ctx: inout GraphicsContext, size: CGSize, time: Double, amount: CGFloat, wind: CGFloat = 1) {
        var drops = Path()
        let count = Int(90 * amount)
        for k in 0..<count {
            let speed = 520 + Double(hash(k, 41)) * 200
            let y = CGFloat((Double(hash(k, 42)) * Double(size.height) + time * speed).truncatingRemainder(dividingBy: Double(size.height + 40))) - 20
            let x = hash(k, 43) * (size.width + 40) - 20 + y * 0.12 * wind
            drops.move(to: CGPoint(x: x, y: y))
            drops.addLine(to: CGPoint(x: x - 3 * wind, y: y - 16))
        }
        ctx.stroke(drops, with: .color(Color(hex: 0xD6E6F5).opacity(0.55)), lineWidth: 1.2)
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0x4A5A6E).opacity(Double(amount) * 0.12)))
    }

    @MainActor
    static func drawParticles(_ game: GardenGame, _ ctx: inout GraphicsContext) {
        guard !game.particles.isEmpty else { return }
        let heart = ctx.resolve(Text(Image(systemName: "heart.fill")).font(.system(size: 16)).foregroundStyle(Color(hex: 0xF27A9B)))
        let sparkle = ctx.resolve(Text(Image(systemName: "sparkle")).font(.system(size: 12)).foregroundStyle(Color(hex: 0xFFE38A)))
        let zzz = ctx.resolve(Text("z").font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(.white))
        for part in game.particles {
            let fade = min(1, part.life / part.maxLife * 2)
            ctx.drawLayer { l in
                l.opacity = fade
                switch part.kind {
                case .heart:
                    l.draw(heart, at: part.p)
                case .sparkle:
                    l.translateBy(x: part.p.x, y: part.p.y)
                    l.rotate(by: .radians(part.rotation))
                    l.draw(sparkle, at: .zero)
                case .zzz:
                    let grow = 0.6 + (1 - part.life / part.maxLife) * 0.8
                    l.translateBy(x: part.p.x, y: part.p.y)
                    l.scaleBy(x: grow, y: grow)
                    l.draw(zzz, at: .zero)
                case .clip:
                    var p = Path()
                    p.move(to: CGPoint(x: part.p.x - 3 * CGFloat(cos(part.rotation)), y: part.p.y - 3 * CGFloat(sin(part.rotation))))
                    p.addLine(to: CGPoint(x: part.p.x + 3 * CGFloat(cos(part.rotation)), y: part.p.y + 3 * CGFloat(sin(part.rotation))))
                    l.stroke(p, with: .color(part.color), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                case .drop:
                    l.fill(Path(ellipseIn: CGRect(x: part.p.x - 2.2, y: part.p.y - 3, width: 4.4, height: 6)), with: .color(part.color))
                case .petal:
                    l.translateBy(x: part.p.x, y: part.p.y)
                    l.rotate(by: .radians(part.rotation))
                    l.fill(Path(ellipseIn: CGRect(x: -3, y: -1.5, width: 6, height: 3)), with: .color(part.color))
                case .confetti:
                    l.translateBy(x: part.p.x, y: part.p.y)
                    l.rotate(by: .radians(part.rotation))
                    l.fill(Path(CGRect(x: -3, y: -2, width: 6, height: 4)), with: .color(part.color))
                case .label(let text):
                    let label = l.resolve(Text(text).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white))
                    l.addFilter(.shadow(color: .black.opacity(0.45), radius: 2, y: 1))
                    l.draw(label, at: part.p)
                }
            }
        }
    }

    @MainActor
    static func drawToolCursor(_ game: GardenGame, _ ctx: inout GraphicsContext, time: Double) {
        guard let p = game.toolPoint else { return }
        let u = game.unit
        switch game.tool {
        case .maeher:
            // kleiner Spindelmäher
            let rect = CGRect(x: p.x - 22 * u, y: p.y - 12 * u, width: 44 * u, height: 18 * u)
            ctx.fill(Path(ellipseIn: CGRect(x: rect.minX, y: p.y + 2 * u, width: rect.width, height: 8 * u)), with: .color(.black.opacity(0.2)))
            ctx.fill(Path(roundedRect: rect, cornerRadius: 7 * u), with: .color(Color(hex: 0xD8463A)))
            ctx.fill(Path(roundedRect: rect.insetBy(dx: 6 * u, dy: 4 * u), cornerRadius: 4 * u), with: .color(Color(hex: 0xF06B5C)))
            for side in [-1.0, 1.0] {
                let wx = p.x + CGFloat(side) * 22 * u
                ctx.fill(Path(ellipseIn: CGRect(x: wx - 7 * u, y: p.y - 6 * u, width: 14 * u, height: 14 * u)), with: .color(Color(hex: 0x2C2C2C)))
                ctx.fill(Path(ellipseIn: CGRect(x: wx - 3 * u, y: p.y - 2 * u, width: 6 * u, height: 6 * u)), with: .color(Color(hex: 0xBDBDBD)))
            }
            var handle = Path()
            handle.move(to: CGPoint(x: p.x, y: p.y - 10 * u))
            handle.addLine(to: CGPoint(x: p.x + 4 * u, y: p.y - 46 * u))
            handle.move(to: CGPoint(x: p.x - 8 * u, y: p.y - 46 * u))
            handle.addLine(to: CGPoint(x: p.x + 16 * u, y: p.y - 46 * u))
            ctx.stroke(handle, with: .color(Color(hex: 0x3A3A3A)), style: StrokeStyle(lineWidth: 3 * u, lineCap: .round))
        case .giesskanne:
            let can = ctx.resolve(Text(Image(systemName: "drop.fill")).font(.system(size: 30 * u)).foregroundStyle(Color(hex: 0x6FB7EC)))
            ctx.draw(can, at: CGPoint(x: p.x + 18 * u, y: p.y - 34 * u))
            var spray = Path()
            for k in 0..<5 {
                let x = p.x + CGFloat(k - 2) * 5 * u
                let phase = CGFloat((time * 3 + Double(k) * 0.3).truncatingRemainder(dividingBy: 1))
                spray.move(to: CGPoint(x: x, y: p.y - 20 * u + phase * 16 * u))
                spray.addLine(to: CGPoint(x: x, y: p.y - 16 * u + phase * 16 * u))
            }
            ctx.stroke(spray, with: .color(Color(hex: 0x9FD3F2)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        default:
            break
        }
    }
}

/// Kleines Bild eines Kaninchens für Karten und das Album.
struct RabbitPortrait: View {
    let look: RabbitLook
    var size: CGFloat = 56
    var sleeping = false

    var body: some View {
        Canvas { ctx, sz in
            var pose = RabbitPose()
            pose.eyesClosed = sleeping
            pose.earsBack = sleeping ? 0.9 : 0
            let s = sz.width / 74 / max(look.breed.bodyScale, 1) * (look.breed == .zwerg ? 1.1 : 1)
            ctx.translateBy(x: sz.width * 0.46, y: sz.height * 0.9)
            ctx.scaleBy(x: s, y: s)
            GardenRenderer.rabbitShape(&ctx, look: look, pose: pose)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
