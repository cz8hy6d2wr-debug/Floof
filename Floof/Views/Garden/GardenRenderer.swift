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
        let top = game.lawnTop

        drawSky(&ctx, size: size, top: top, night: night, rain: rain, hour: game.hour, time: time)
        drawHills(&ctx, size: size, top: top, night: night)
        drawFence(&ctx, size: size, top: top, unit: game.unit)
        drawLawnBase(game, &ctx, size: size, top: top)
        drawHutch(game, &ctx, night: night)
        drawBed(game, &ctx, time: time)

        // Reihe für Reihe von hinten nach vorn: erst Dinge, dann die Halme der Reihe.
        let rows = GardenSave.rows
        var items: [(y: Double, kind: Int, index: Int)] = []
        for (i, r) in game.save.rabbits.enumerated() { items.append((r.y, 0, i)) }
        for (i, f) in game.save.foods.enumerated() { items.append((f.y, 1, i)) }
        for (i, f) in game.save.flowers.enumerated() { items.append((f.y, 2, i)) }
        items.sort { $0.y < $1.y }
        var next = 0
        let wind = CGFloat(1 + 0.8 * game.rainAmount)
        for j in 0..<rows {
            let rowEnd = Double(j + 1) / Double(rows)
            while next < items.count, items[next].y < rowEnd || j == rows - 1 {
                let item = items[next]
                switch item.kind {
                case 0: drawRabbit(game, index: item.index, &ctx, time: time)
                case 1: drawFood(game.save.foods[item.index], game, &ctx)
                default: drawFlower(game.save.flowers[item.index], game, &ctx, time: time)
                }
                next += 1
            }
            drawGrassRow(game, row: j, &ctx, time: time, wind: wind)
        }

        drawButterflies(&ctx, size: size, top: top, time: time, day: 1 - night - rain * 0.6)
        drawParticles(game, &ctx)

        // Nacht und Regen dunkeln alles ab; Glühwürmchen und Fenster leuchten darüber.
        if night > 0.01 {
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0x0B1438).opacity(Double(night) * 0.55)))
            drawHutchWindow(game, &ctx, night: night)
            drawFireflies(&ctx, size: size, top: top, time: time, night: night)
        }
        if rain > 0.01 { drawRain(&ctx, size: size, time: time, amount: rain) }
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

    static func drawSky(_ ctx: inout GraphicsContext, size: CGSize, top: CGFloat, night: CGFloat, rain: CGFloat, hour: Double, time: Double) {
        let dusk = max(0, 1 - abs(night - 0.5) * 2.2)   // Abend- und Morgenrot
        var skyTop = mix(Color(hex: 0x6FB8EA), Color(hex: 0x0A1230), night)
        var skyBottom = mix(Color(hex: 0xD3EEF6), Color(hex: 0x24325A), night)
        skyBottom = mix(skyBottom, Color(hex: 0xF7B27A), dusk * 0.7)
        skyTop = mix(skyTop, Color(hex: 0x8A9AAE), rain * 0.6)
        skyBottom = mix(skyBottom, Color(hex: 0xB9C3CC), rain * 0.6)
        let skyRect = CGRect(x: 0, y: 0, width: size.width, height: top + 20)
        ctx.fill(Path(skyRect), with: .linearGradient(Gradient(colors: [skyTop, skyBottom]),
                                                      startPoint: .zero, endPoint: CGPoint(x: 0, y: top)))

        // Sterne
        if night > 0.3 {
            for k in 0..<60 {
                let x = hash(k, 1) * size.width
                let y = hash(k, 2) * top * 0.8
                let tw = 0.5 + 0.5 * sin(time * (1 + Double(hash(k, 3)) * 2) + Double(k))
                let r = 0.6 + hash(k, 4) * 1.2
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                         with: .color(.white.opacity(Double(night - 0.3) * 1.3 * tw)))
            }
        }

        // Sonne bzw. Mond auf einem Bogen
        let dayT = (hour - 6) / 14            // 6 Uhr … 20 Uhr
        let nightT = ((hour + 24 - 20).truncatingRemainder(dividingBy: 24)) / 10
        let isDay = night < 0.5
        let t = CGFloat(isDay ? dayT : nightT)
        if t > -0.1 && t < 1.1 {
            let cx = size.width * (0.1 + 0.8 * t)
            let cy = top * (0.75 - 0.55 * sin(.pi * min(max(t, 0), 1)))
            let r: CGFloat = 22
            if isDay {
                ctx.fill(Path(ellipseIn: CGRect(x: cx - r * 3, y: cy - r * 3, width: r * 6, height: r * 6)),
                         with: .radialGradient(Gradient(colors: [Color(hex: 0xFFF3C4).opacity(0.55 * Double(1 - rain)), .clear]),
                                               center: CGPoint(x: cx, y: cy), startRadius: r * 0.8, endRadius: r * 3))
                ctx.fill(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                         with: .color(mix(Color(hex: 0xFFE9A0), Color(hex: 0xFFB070), dusk).opacity(Double(1 - rain * 0.7))))
            } else {
                ctx.fill(Path(ellipseIn: CGRect(x: cx - r * 2.5, y: cy - r * 2.5, width: r * 5, height: r * 5)),
                         with: .radialGradient(Gradient(colors: [Color.white.opacity(0.18), .clear]),
                                               center: CGPoint(x: cx, y: cy), startRadius: r * 0.8, endRadius: r * 2.5))
                ctx.fill(Path(ellipseIn: CGRect(x: cx - r * 0.8, y: cy - r * 0.8, width: r * 1.6, height: r * 1.6)),
                         with: .color(Color(hex: 0xF4F0DF)))
                ctx.fill(Path(ellipseIn: CGRect(x: cx - r * 0.45, y: cy - r * 0.95, width: r * 1.6, height: r * 1.6)),
                         with: .color(mix(Color(hex: 0x0A1230), Color(hex: 0x24325A), 0.3)))
            }
        }

        // Wolken ziehen langsam vorbei
        let cloudColor = mix(mix(.white, Color(hex: 0x3A4668), night), Color(hex: 0x9AA4B0), rain * 0.7)
        let cloudCount = 4 + Int(rain * 4)
        for k in 0..<cloudCount {
            let speed = 6 + Double(hash(k, 9)) * 8
            let span = size.width + 240
            let x = CGFloat((Double(hash(k, 7)) * Double(span) + time * speed).truncatingRemainder(dividingBy: Double(span))) - 120
            let y = top * (0.12 + hash(k, 8) * 0.45)
            let w = 70 + hash(k, 10) * 70
            var cloud = Path()
            cloud.addEllipse(in: CGRect(x: x, y: y, width: w, height: w * 0.32))
            cloud.addEllipse(in: CGRect(x: x + w * 0.18, y: y - w * 0.16, width: w * 0.45, height: w * 0.4))
            cloud.addEllipse(in: CGRect(x: x + w * 0.42, y: y - w * 0.1, width: w * 0.4, height: w * 0.34))
            ctx.fill(cloud, with: .color(cloudColor.opacity(0.85)))
        }
    }

    static func drawHills(_ ctx: inout GraphicsContext, size: CGSize, top: CGFloat, night: CGFloat) {
        let far = mix(Color(hex: 0x9CC38A), Color(hex: 0x1E2C3A), night * 0.8)
        let near = mix(Color(hex: 0x6E9F55), Color(hex: 0x17262A), night * 0.8)
        for (layer, color) in [(0, far), (1, near)] {
            var p = Path()
            let base = top - (layer == 0 ? 34 : 14)
            p.move(to: CGPoint(x: 0, y: top + 10))
            p.addLine(to: CGPoint(x: 0, y: base))
            let steps = 24
            for s in 0...steps {
                let x = size.width * CGFloat(s) / CGFloat(steps)
                let wave = CGFloat(0.5 + 0.5 * sin(Double(x) / (layer == 0 ? 90.0 : 60.0) + Double(layer) * 2))
                let amp: CGFloat = layer == 0 ? 26 : 18
                let y = base - amp * wave
                p.addLine(to: CGPoint(x: x, y: y))
            }
            p.addLine(to: CGPoint(x: size.width, y: top + 10))
            p.closeSubpath()
            ctx.fill(p, with: .color(color))
        }
        // Ein paar runde Bäume am Horizont
        for k in 0..<3 {
            let x = size.width * (0.35 + CGFloat(k) * 0.24 + hash(k, 21) * 0.05)
            let r = 20 + hash(k, 22) * 14
            let y = top - 18
            ctx.fill(Path(CGRect(x: x - 3, y: y - 6, width: 6, height: 18)), with: .color(mix(Color(hex: 0x6B4B33), .black, night * 0.7)))
            var crown = Path()
            crown.addEllipse(in: CGRect(x: x - r, y: y - r * 2, width: r * 2, height: r * 1.8))
            crown.addEllipse(in: CGRect(x: x - r * 1.2, y: y - r * 1.4, width: r * 1.3, height: r * 1.1))
            crown.addEllipse(in: CGRect(x: x - r * 0.1, y: y - r * 1.5, width: r * 1.3, height: r * 1.2))
            ctx.fill(crown, with: .color(mix(Color(hex: 0x4F8A3C), Color(hex: 0x12201F), night * 0.85)))
        }
    }

    static func drawFence(_ ctx: inout GraphicsContext, size: CGSize, top: CGFloat, unit: CGFloat) {
        let wood = Color(hex: 0xC99A6B), dark = Color(hex: 0x8E6440)
        let h = 26 * unit
        for rail in [0.35, 0.72] {
            let y = top - h * CGFloat(rail)
            ctx.fill(Path(CGRect(x: 0, y: y - 2, width: size.width, height: 4 * unit)), with: .color(dark))
        }
        var x: CGFloat = 8
        while x < size.width {
            var post = Path()
            post.move(to: CGPoint(x: x - 4 * unit, y: top + 2))
            post.addLine(to: CGPoint(x: x - 4 * unit, y: top - h))
            post.addLine(to: CGPoint(x: x, y: top - h - 5 * unit))
            post.addLine(to: CGPoint(x: x + 4 * unit, y: top - h))
            post.addLine(to: CGPoint(x: x + 4 * unit, y: top + 2))
            post.closeSubpath()
            ctx.fill(post, with: .color(wood))
            ctx.stroke(post, with: .color(dark.opacity(0.6)), lineWidth: 1)
            x += 34 * unit
        }
    }

    @MainActor
    static func drawLawnBase(_ game: GardenGame, _ ctx: inout GraphicsContext, size: CGSize, top: CGFloat) {
        let rect = CGRect(x: 0, y: top, width: size.width, height: size.height - top)
        ctx.fill(Path(rect), with: .linearGradient(Gradient(colors: [Color(hex: 0x7CB356), Color(hex: 0x5C9640)]),
                                                   startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: size.height)))
        // Mähstreifen und nasse Stellen je Zelle
        let cols = GardenSave.cols, rows = GardenSave.rows
        let cw = size.width / CGFloat(cols), ch = (size.height - top) / CGFloat(rows)
        var lightStripe = Path(), darkStripe = Path(), wetPath = Path()
        for k in 0..<(cols * rows) {
            let i = k % cols, j = k / cols
            let cell = CGRect(x: CGFloat(i) * cw, y: top + CGFloat(j) * ch, width: cw + 0.5, height: ch + 0.5)
            let h = CGFloat(game.save.grass[k])
            if h < 0.5 {
                if i % 2 == 0 { lightStripe.addRect(cell) } else { darkStripe.addRect(cell) }
            }
            if game.save.wet[k] > 0.15 { wetPath.addRect(cell) }
        }
        ctx.fill(lightStripe, with: .color(Color(hex: 0xA7D477).opacity(0.75)))
        ctx.fill(darkStripe, with: .color(Color(hex: 0x8DC25F).opacity(0.75)))
        ctx.fill(wetPath, with: .color(Color(hex: 0x2E5A30).opacity(0.18)))
    }

    @MainActor
    static func drawGrassRow(_ game: GardenGame, row j: Int, _ ctx: inout GraphicsContext, time: Double, wind: CGFloat) {
        let cols = GardenSave.cols, rows = GardenSave.rows
        let shades = [Color(hex: 0x4C8A34), Color(hex: 0x66A443), Color(hex: 0x86C158)]
        var paths = [Path(), Path(), Path()]
        let touch = game.toolPoint
        for i in 0..<cols {
            let k = j * cols + i
            let h = CGFloat(game.save.grass[k])
            let blades = h < 0.2 ? 3 : 7
            for b in 0..<blades {
                let fx = (CGFloat(i) + hash(i, j, b)) / CGFloat(cols)
                let fy = (CGFloat(j) + hash(i, j, b + 50)) / CGFloat(rows)
                let base = game.screen(Double(fx), Double(fy))
                let s = game.scale(atY: Double(fy))
                let variance = 0.7 + hash(i, j, b + 99) * 0.6
                let height = (3 + 26 * h) * s * variance
                let width = 1.7 * s
                var sway = CGFloat(sin(time * 1.6 + Double(base.x) * 0.025 + Double(b))) * (1.5 + 4 * h) * s * wind
                if let touch {
                    let dx = base.x - touch.x, dy = base.y - touch.y
                    let d = hypot(dx, dy)
                    if d < 60 { sway += (dx > 0 ? 1 : -1) * (60 - d) * 0.25 * h }
                }
                let tip = CGPoint(x: base.x + sway, y: base.y - height)
                var p = Path()
                p.move(to: CGPoint(x: base.x - width, y: base.y))
                p.addQuadCurve(to: tip, control: CGPoint(x: base.x - width * 0.2 + sway * 0.3, y: base.y - height * 0.6))
                p.addQuadCurve(to: CGPoint(x: base.x + width, y: base.y),
                               control: CGPoint(x: base.x + width * 0.4 + sway * 0.3, y: base.y - height * 0.55))
                paths[Int(hash(i, j, b + 7) * 2.999)].addPath(p)
            }
        }
        for (n, p) in paths.enumerated() { ctx.fill(p, with: .color(shades[n])) }
    }

    // MARK: - Stall & Beet

    @MainActor
    static func drawHutch(_ game: GardenGame, _ ctx: inout GraphicsContext, night: CGFloat) {
        let c = game.screen(GardenGame.hutch.x, GardenGame.hutch.y)
        let s = game.scale(atY: GardenGame.hutch.y) * 1.25
        let w = 92 * s, h = 58 * s
        let body = CGRect(x: c.x - w / 2, y: c.y - h, width: w, height: h)
        ctx.fill(Path(ellipseIn: CGRect(x: body.minX - 6, y: c.y - 6 * s, width: w + 12, height: 14 * s)),
                 with: .color(.black.opacity(0.18)))
        ctx.fill(Path(roundedRect: body, cornerRadius: 4 * s), with: .color(Color(hex: 0xD9A877)))
        // Bretter
        var boards = Path()
        var y = body.minY + 10 * s
        while y < body.maxY {
            boards.move(to: CGPoint(x: body.minX, y: y)); boards.addLine(to: CGPoint(x: body.maxX, y: y))
            y += 10 * s
        }
        ctx.stroke(boards, with: .color(Color(hex: 0xB07F52).opacity(0.6)), lineWidth: 1)
        // Dach
        var roof = Path()
        roof.move(to: CGPoint(x: body.minX - 10 * s, y: body.minY + 4 * s))
        roof.addLine(to: CGPoint(x: c.x, y: body.minY - 30 * s))
        roof.addLine(to: CGPoint(x: body.maxX + 10 * s, y: body.minY + 4 * s))
        roof.closeSubpath()
        ctx.fill(roof, with: .color(Color(hex: 0xB4503F)))
        ctx.stroke(roof, with: .color(Color(hex: 0x86362A)), lineWidth: 2 * s)
        // Tür
        var door = Path()
        let dw = 30 * s, dh = 34 * s
        door.move(to: CGPoint(x: c.x - dw / 2 + 12 * s, y: c.y))
        door.addLine(to: CGPoint(x: c.x - dw / 2 + 12 * s, y: c.y - dh + dw / 2))
        door.addArc(center: CGPoint(x: c.x + 12 * s, y: c.y - dh + dw / 2), radius: dw / 2,
                    startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        door.addLine(to: CGPoint(x: c.x + dw / 2 + 12 * s, y: c.y))
        door.closeSubpath()
        ctx.fill(door, with: .color(Color(hex: 0x3B2618)))
        // Fenster (leuchtet nachts, siehe drawHutchWindow)
        let win = CGRect(x: body.minX + 10 * s, y: body.minY + 12 * s, width: 18 * s, height: 16 * s)
        ctx.fill(Path(roundedRect: win, cornerRadius: 3 * s), with: .color(Color(hex: 0x5D4636)))
        // Wassernapf
        let bowl = CGRect(x: body.maxX + 6 * s, y: c.y - 8 * s, width: 22 * s, height: 10 * s)
        ctx.fill(Path(ellipseIn: bowl), with: .color(Color(hex: 0x4F7FB0)))
        ctx.fill(Path(ellipseIn: bowl.insetBy(dx: 3 * s, dy: 2 * s)), with: .color(Color(hex: 0x9FD3F2)))
    }

    @MainActor
    static func drawHutchWindow(_ game: GardenGame, _ ctx: inout GraphicsContext, night: CGFloat) {
        let c = game.screen(GardenGame.hutch.x, GardenGame.hutch.y)
        let s = game.scale(atY: GardenGame.hutch.y) * 1.25
        let w = 92 * s, h = 58 * s
        let win = CGRect(x: c.x - w / 2 + 10 * s, y: c.y - h + 12 * s, width: 18 * s, height: 16 * s)
        ctx.fill(Path(ellipseIn: win.insetBy(dx: -24 * s, dy: -24 * s)),
                 with: .radialGradient(Gradient(colors: [Color(hex: 0xFFC56E).opacity(0.35 * Double(night)), .clear]),
                                       center: CGPoint(x: win.midX, y: win.midY), startRadius: 2, endRadius: 34 * s))
        ctx.fill(Path(roundedRect: win, cornerRadius: 3 * s), with: .color(Color(hex: 0xFFCF7A).opacity(Double(night))))
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
        let s = game.scale(atY: r.y) * r.look.breed.bodyScale * 0.92
        let pose = GardenRenderer.pose(for: r, actor: a, clock: game.clock)
        let selected = game.selectedID == r.id

        // Schatten
        let shadowW = (pose.flop ? 64 : 52) * s * (1 - min(pose.lift, 40) / 90)
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - shadowW / 2, y: p.y - 5 * s, width: shadowW, height: 11 * s)),
                 with: .color(.black.opacity(0.2)))
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
            ctx.stroke(arc, with: .color(Color(hex: 0xF27A9B)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            let heart = ctx.resolve(Text(Image(systemName: "heart.fill")).font(.system(size: 8)).foregroundStyle(Color(hex: 0xF27A9B)))
            ctx.draw(heart, at: c)
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
        default:
            let spot = look.fur == .weiss ? look.accent.main : Color(hex: 0xF8F4EE)
            return Palette(main: look.fur.main, shade: look.fur.shade, belly: look.fur.belly, spot: spot, outline: look.fur.shade)
        }
    }

    /// Kaninchen nach rechts blickend, Boden bei y = 0, Einheit ≈ Punkte bei Maßstab 1.
    static func rabbitShape(_ ctx: inout GraphicsContext, look: RabbitLook, pose: RabbitPose) {
        let pal = palette(look)
        let seed = (look.fur.rawValue + look.pattern.rawValue).utf8.reduce(7) { $0 &* 31 &+ Int($1) }
        let outline = GraphicsContext.Shading.color(pal.outline.opacity(0.9))

        if pose.flop {
            flopShape(&ctx, look: look, pal: pal, pose: pose)
            return
        }

        ctx.scaleBy(x: 1 / pose.stretch, y: pose.stretch * pose.breath)

        let headR: CGFloat = look.breed == .zwerg ? 15.5 : 14
        let grooming = pose.groom > -1
        let hc = CGPoint(x: 15 + 7 * pose.headDown + (grooming ? pose.groom * 0.6 : 0),
                         y: -33 + 20 * pose.headDown + pose.chew * 0.6 + (pose.groom > -1 ? 2 : 0))
        let lop = look.breed == .widder

        // Schwänzchen
        let tail = CGRect(x: -32, y: -22, width: 12, height: 12)
        ctx.fill(Path(ellipseIn: tail.insetBy(dx: -1, dy: -1)), with: outline)
        ctx.fill(Path(ellipseIn: tail), with: .color(look.pattern == .russe ? pal.main : pal.belly))

        // Ohren hinter dem Kopf
        if lop {
            ear(&ctx, base: CGPoint(x: hc.x - 7, y: hc.y - 7), length: 22, width: 10,
                angle: 0.55 + pose.earTwitch * 0.3, hanging: true, color: earColor(look, pal), inner: nil)
        } else {
            let back = -0.42 - pose.earsBack * 0.85 + pose.earTwitch
            let front = -0.12 - pose.earsBack * 0.95
            ear(&ctx, base: CGPoint(x: hc.x - 6, y: hc.y - 8), length: 27, width: 10,
                angle: back, hanging: false, color: earColor(look, pal), inner: nil, shade: pal.shade)
            ear(&ctx, base: CGPoint(x: hc.x, y: hc.y - 10), length: 28, width: 10.5,
                angle: front, hanging: false, color: earColor(look, pal), inner: pal.ear)
        }

        // Körper
        let body = Path(ellipseIn: CGRect(x: -27, y: -33, width: 46, height: 33))
        ctx.stroke(body, with: outline, lineWidth: 2.2)
        ctx.fill(body, with: .linearGradient(Gradient(colors: [pal.main, mix(pal.main, pal.shade, 0.55)]),
                                             startPoint: CGPoint(x: 0, y: -33), endPoint: CGPoint(x: 0, y: 0)))
        ctx.drawLayer { l in
            l.clip(to: body)
            switch look.pattern {
            case .hollaender:
                l.fill(Path(CGRect(x: 0, y: -40, width: 30, height: 45)), with: .color(pal.spot))
            case .schecke:
                for k in 0..<3 {
                    let x = -22 + hash(seed, k) * 28
                    let y = -30 + hash(seed, k, 1) * 18
                    let w = 9 + hash(seed, k, 2) * 9
                    l.fill(Path(ellipseIn: CGRect(x: x, y: y, width: w, height: w * 0.8)), with: .color(pal.spot))
                }
                // Aalstrich
                l.fill(Path(roundedRect: CGRect(x: -22, y: -35, width: 30, height: 6), cornerRadius: 3), with: .color(pal.spot))
            default:
                break
            }
            // Keule
            l.fill(Path(ellipseIn: CGRect(x: -26, y: -27, width: 26, height: 24)), with: .color(pal.shade.opacity(0.16)))
        }
        // Brust
        ctx.fill(Path(ellipseIn: CGRect(x: 3, y: -21, width: 15, height: 17)), with: .color(pal.belly.opacity(0.9)))

        // Füße
        let footColor = look.pattern == .russe ? pal.spot : (look.pattern == .hollaender ? pal.spot : pal.shade)
        ctx.fill(Path(ellipseIn: CGRect(x: -24, y: -5, width: 21, height: 7)), with: .color(footColor))
        let pawY: CGFloat = pose.groom > -1 ? hc.y + 7 + pose.groom * 2 : -5
        let pawX: CGFloat = pose.groom > -1 ? hc.x + 5 : 8
        ctx.fill(Path(ellipseIn: CGRect(x: pawX, y: pawY, width: 9, height: 6)),
                 with: .color(look.pattern == .russe ? pal.spot : pal.belly))
        ctx.fill(Path(ellipseIn: CGRect(x: pawX + 6, y: pawY + (pose.groom > -1 ? 1 : 0), width: 9, height: 6)),
                 with: .color(look.pattern == .russe ? pal.spot : pal.belly))

        // Löwenkopf-Mähne
        if look.breed == .loewenkopf {
            for k in 0..<9 {
                let ang = Double(k) / 9 * 1.6 * .pi + 0.5 * .pi
                let c = CGPoint(x: hc.x + CGFloat(cos(ang)) * (headR + 1), y: hc.y + CGFloat(sin(ang)) * (headR - 1))
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - 6.5, y: c.y - 6.5, width: 13, height: 13)),
                         with: .color(mix(pal.main, .white, 0.25)))
            }
        }

        // Kopf
        let head = Path(ellipseIn: CGRect(x: hc.x - headR, y: hc.y - headR * 0.92, width: headR * 2.1, height: headR * 1.9))
        ctx.stroke(head, with: outline, lineWidth: 2.2)
        ctx.fill(head, with: .color(pal.main))
        ctx.fill(Path(ellipseIn: CGRect(x: hc.x - 2, y: hc.y - 1, width: 18, height: 14)), with: .color(mix(pal.main, pal.belly, 0.35)))
        ctx.drawLayer { l in
            l.clip(to: head)
            switch look.pattern {
            case .hollaender, .blesse:
                var blaze = Path()
                blaze.move(to: CGPoint(x: hc.x + 6, y: hc.y - headR))
                blaze.addQuadCurve(to: CGPoint(x: hc.x + 18, y: hc.y + 10), control: CGPoint(x: hc.x + 2, y: hc.y + 6))
                blaze.addLine(to: CGPoint(x: hc.x + 18, y: hc.y - headR))
                blaze.closeSubpath()
                l.fill(blaze, with: .color(pal.spot))
            case .schecke:
                l.fill(Path(ellipseIn: CGRect(x: hc.x + 1, y: hc.y - 7, width: 11, height: 10)), with: .color(pal.spot))
                l.fill(Path(ellipseIn: CGRect(x: hc.x + 9, y: hc.y + 1, width: 9, height: 7)), with: .color(pal.spot))
            case .russe:
                l.fill(Path(ellipseIn: CGRect(x: hc.x + 7, y: hc.y - 4, width: 14, height: 13)), with: .color(pal.spot))
            case .einfarbig:
                break
            }
        }

        // Auge
        let eye = CGPoint(x: hc.x + 6, y: hc.y - 3)
        if pose.eyesClosed {
            var lid = Path()
            if pose.happy {
                lid.move(to: CGPoint(x: eye.x - 3.5, y: eye.y + 1))
                lid.addQuadCurve(to: CGPoint(x: eye.x + 3.5, y: eye.y + 1), control: CGPoint(x: eye.x, y: eye.y - 3.5))
            } else {
                lid.move(to: CGPoint(x: eye.x - 3.5, y: eye.y))
                lid.addQuadCurve(to: CGPoint(x: eye.x + 3.5, y: eye.y), control: CGPoint(x: eye.x, y: eye.y + 3))
            }
            ctx.stroke(lid, with: .color(Color(hex: 0x2A1D15)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        } else {
            let irisColor = look.pattern == .russe || (look.fur == .weiss && look.pattern == .einfarbig)
                ? Color(hex: 0xB0384A) : Color(hex: 0x1E1512)
            ctx.fill(Path(ellipseIn: CGRect(x: eye.x - 3.6, y: eye.y - 3.9, width: 7.2, height: 7.8)), with: .color(irisColor))
            ctx.fill(Path(ellipseIn: CGRect(x: eye.x - 0.6, y: eye.y - 2.9, width: 2.6, height: 2.6)), with: .color(.white))
        }
        // Wange
        ctx.fill(Path(ellipseIn: CGRect(x: hc.x + 3, y: hc.y + 3, width: 7, height: 4)), with: .color(Color(hex: 0xF29AA5).opacity(0.35)))
        // Nase & Schnurrhaare
        let nose = CGPoint(x: hc.x + headR + 0.5, y: hc.y + 3 + pose.nose)
        ctx.fill(Path(ellipseIn: CGRect(x: nose.x - 2.2, y: nose.y - 1.6, width: 4.4, height: 3.4)), with: .color(Color(hex: 0xD9707E)))
        var whiskers = Path()
        for k in -1...1 {
            whiskers.move(to: CGPoint(x: nose.x - 2, y: nose.y + 1.5))
            whiskers.addLine(to: CGPoint(x: nose.x + 9, y: nose.y + 1.5 + CGFloat(k) * 3 + pose.nose * 0.5))
        }
        ctx.stroke(whiskers, with: .color(Color(hex: 0x2A1D15).opacity(0.35)), lineWidth: 0.7)

        // Widder: vorderes Schlappohr vor dem Kopf
        if lop {
            ear(&ctx, base: CGPoint(x: hc.x - 2, y: hc.y - 9), length: 24, width: 10.5,
                angle: 0.25 + pose.earTwitch * 0.3, hanging: true, color: earColor(look, pal), inner: nil, shade: pal.shade)
        }
    }

    private static func earColor(_ look: RabbitLook, _ pal: Palette) -> Color {
        switch look.pattern {
        case .russe, .schecke: pal.spot
        default: pal.main
        }
    }

    private static func ear(_ ctx: inout GraphicsContext, base: CGPoint, length: CGFloat, width: CGFloat,
                            angle: CGFloat, hanging: Bool, color: Color, inner: Color?, shade: Color? = nil) {
        ctx.drawLayer { l in
            l.translateBy(x: base.x, y: base.y)
            l.rotate(by: .radians(Double(angle)))
            let rect = hanging
                ? CGRect(x: -width / 2, y: 0, width: width, height: length)
                : CGRect(x: -width / 2, y: -length, width: width, height: length)
            let path = Path(roundedRect: rect, cornerRadius: width / 2)
            l.stroke(path, with: .color((shade ?? color).opacity(0.8)), lineWidth: 2)
            l.fill(path, with: .color(color))
            if let shade, hanging {
                l.fill(Path(roundedRect: rect.insetBy(dx: 2.5, dy: 4).offsetBy(dx: 1, dy: 2), cornerRadius: width / 3),
                       with: .color(shade.opacity(0.25)))
            }
            if let inner {
                l.fill(Path(roundedRect: rect.insetBy(dx: width * 0.27, dy: 4), cornerRadius: width / 3), with: .color(inner))
            }
        }
    }

    /// Ausgestreckt auf der Seite liegend – das glücklichste Kaninchen der Welt.
    private static func flopShape(_ ctx: inout GraphicsContext, look: RabbitLook, pal: Palette, pose: RabbitPose) {
        let outline = GraphicsContext.Shading.color(pal.outline.opacity(0.9))
        ctx.scaleBy(x: 1, y: pose.breath)
        // Hinterläufe
        ctx.fill(Path(roundedRect: CGRect(x: -42, y: -9, width: 22, height: 8), cornerRadius: 4), with: .color(pal.shade))
        let body = Path(ellipseIn: CGRect(x: -30, y: -21, width: 52, height: 21))
        ctx.stroke(body, with: outline, lineWidth: 2.2)
        ctx.fill(body, with: .color(pal.main))
        ctx.fill(Path(ellipseIn: CGRect(x: -18, y: -9, width: 30, height: 9)), with: .color(pal.belly.opacity(0.8)))
        if look.pattern == .schecke || look.pattern == .hollaender {
            ctx.drawLayer { l in
                l.clip(to: body)
                l.fill(Path(ellipseIn: CGRect(x: -14, y: -22, width: 14, height: 11)), with: .color(pal.spot))
            }
        }
        // Ohren flach nach hinten
        ear(&ctx, base: CGPoint(x: 20, y: -16), length: 26, width: 9.5, angle: -1.75, hanging: false,
            color: earColor(look, pal), inner: pal.ear)
        let head = Path(ellipseIn: CGRect(x: 14, y: -24, width: 27, height: 23))
        ctx.stroke(head, with: outline, lineWidth: 2.2)
        ctx.fill(head, with: .color(pal.main))
        var lid = Path()
        lid.move(to: CGPoint(x: 28, y: -14))
        lid.addQuadCurve(to: CGPoint(x: 34, y: -14), control: CGPoint(x: 31, y: -11.5))
        ctx.stroke(lid, with: .color(Color(hex: 0x2A1D15)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        ctx.fill(Path(ellipseIn: CGRect(x: 38.5, y: -11, width: 4, height: 3)), with: .color(Color(hex: 0xD9707E)))
        // Vorderpfötchen
        ctx.fill(Path(roundedRect: CGRect(x: 10, y: -5, width: 16, height: 6), cornerRadius: 3), with: .color(pal.belly))
        ctx.fill(Path(ellipseIn: CGRect(x: -36, y: -19, width: 11, height: 11)), with: .color(pal.belly))
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

    static func drawRain(_ ctx: inout GraphicsContext, size: CGSize, time: Double, amount: CGFloat) {
        var drops = Path()
        let count = Int(90 * amount)
        for k in 0..<count {
            let speed = 520 + Double(hash(k, 41)) * 200
            let y = CGFloat((Double(hash(k, 42)) * Double(size.height) + time * speed).truncatingRemainder(dividingBy: Double(size.height + 40))) - 20
            let x = hash(k, 43) * (size.width + 40) - 20 + y * 0.12
            drops.move(to: CGPoint(x: x, y: y))
            drops.addLine(to: CGPoint(x: x - 3, y: y - 16))
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
