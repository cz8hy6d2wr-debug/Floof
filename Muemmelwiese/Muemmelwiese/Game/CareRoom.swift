import SwiftUI

/// Werkzeuge im Pflegeraum.
enum CareTool: String, CaseIterable, Identifiable {
    case buerste, schere, untersuchen, streicheln, leckerli
    var id: String { rawValue }

    var title: String {
        switch self {
        case .buerste: "Bürste"
        case .schere: "Krallen"
        case .untersuchen: "Untersuchen"
        case .streicheln: "Streicheln"
        case .leckerli: "Leckerli"
        }
    }

    var symbol: String {
        switch self {
        case .buerste: "comb.fill"
        case .schere: "scissors"
        case .untersuchen: "stethoscope"
        case .streicheln: "hand.raised.fill"
        case .leckerli: "carrot.fill"
        }
    }

    var hint: String {
        switch self {
        case .buerste: "Wisch übers Fell – lose Haare fliegen raus."
        case .schere: "Tipp eine leuchtende Pfote an."
        case .untersuchen: "Tipp Mund, Ohr oder Auge an."
        case .streicheln: "Streicheln beruhigt."
        case .leckerli: "Ein Leckerli beruhigt sofort."
        }
    }
}

/// Ein Pflegeraum mit Behandlungstisch – das Kaninchen sitzt groß vor dir.
/// Simulation (Partikel, Ruhe) läuft in einem eigenen Takt, gezeichnet wird in einem Canvas.
@MainActor
@Observable
final class CareRoom {
    struct Particle {
        enum Kind { case fluff, heart, sparkle, snip }
        var kind: Kind
        var p: CGPoint
        var v: CGVector
        var life: Double
        var maxLife: Double
        var color: Color
        var rotation: Double = .random(in: 0...6)
    }

    struct Note: Equatable {
        let id = UUID()
        let text: String
        let ok: Bool
    }

    let game: GardenGame
    let rabbitID: UUID
    var tool: CareTool = .buerste
    /// 0 = ganz ruhig, 1 = gestresst
    var stress: Double = 0.15
    var note: Note?
    var clipped: Set<Int> = []
    var checked: Set<String> = []
    var tick = 0

    @ObservationIgnored var particles: [Particle] = []
    @ObservationIgnored var clock: Double = 0
    @ObservationIgnored var size: CGSize = CGSize(width: 390, height: 844)
    @ObservationIgnored var cursor: CGPoint?
    @ObservationIgnored private var lastDrag: CGPoint?
    @ObservationIgnored private var strokeAccum: Double = 0
    @ObservationIgnored var happyUntil: Double = 0
    @ObservationIgnored var wriggleUntil: Double = 0
    @ObservationIgnored private var noteUntil: Double = 0
    @ObservationIgnored private var lastWall = Date.now
    @ObservationIgnored private var checkupDone = false

    init(game: GardenGame, rabbitID: UUID) {
        self.game = game
        self.rabbitID = rabbitID
        let calm = rabbit.map { $0.isVisitor ? $0.trust : $0.friendship } ?? 50
        stress = calm < 35 ? 0.45 : 0.15
    }

    var rabbit: GardenRabbit? { game.save.rabbits.first { $0.id == rabbitID } }

    // MARK: Geometrie (Kaninchen nach rechts blickend, Boden bei y = 0)

    var center: CGPoint { CGPoint(x: size.width * 0.5, y: size.height * 0.64) }
    var scale: CGFloat { min(size.width / 82, size.height / 105) }

    func screen(_ p: CGPoint) -> CGPoint { CGPoint(x: center.x + p.x * scale, y: center.y + p.y * scale) }
    func local(_ p: CGPoint) -> CGPoint { CGPoint(x: (p.x - center.x) / scale, y: (p.y - center.y) / scale) }

    /// Pfoten: zwei vorn, zwei hinten (die hintere zweite liegt verdeckt dahinter)
    static let paws: [(String, CGPoint)] = [("vorne links", CGPoint(x: 12, y: -2)), ("vorne rechts", CGPoint(x: 18, y: -2)),
                                            ("hinten links", CGPoint(x: -25, y: -2)), ("hinten rechts", CGPoint(x: -14, y: -2))]
    static let parts: [(String, String, CGPoint)] = [("zaehne", "Zähne", CGPoint(x: 30, y: -24)),
                                                      ("ohren", "Ohren", CGPoint(x: 7, y: -50)),
                                                      ("augen", "Augen & Nase", CGPoint(x: 19, y: -29))]

    func onRabbit(_ l: CGPoint) -> Bool {
        let body = pow((l.x + 8) / 28, 2) + pow((l.y + 16) / 19, 2) <= 1
        let head = hypot(l.x - 15, l.y - (-25)) < 15
        return body || head
    }

    // MARK: Takt

    func run() async {
        lastWall = .now
        while !Task.isCancelled {
            let now = Date.now
            let dt = min(0.1, now.timeIntervalSince(lastWall))
            lastWall = now
            clock += dt
            for i in particles.indices {
                particles[i].life -= dt
                particles[i].p.x += particles[i].v.dx * CGFloat(dt)
                particles[i].p.y += particles[i].v.dy * CGFloat(dt)
                particles[i].v.dy += (particles[i].kind == .fluff ? 14 : 0) * CGFloat(dt)
                particles[i].rotation += dt
            }
            particles.removeAll { $0.life <= 0 }
            stress = max(0, stress - dt * 0.012)
            if note != nil, clock > noteUntil { note = nil }
            if Int(clock * 4) != Int((clock - dt) * 4) { tick &+= 1 }
            try? await Task.sleep(for: .milliseconds(33))
        }
    }

    private func say(_ text: String, ok: Bool, duration: Double = 3) {
        note = Note(text: text, ok: ok)
        noteUntil = clock + duration
    }

    private func spawn(_ kind: Particle.Kind, at p: CGPoint, count: Int, color: Color) {
        for _ in 0..<count {
            let v: CGVector = switch kind {
            case .fluff: CGVector(dx: .random(in: -50...50), dy: .random(in: -60 ... -10))
            case .heart: CGVector(dx: .random(in: -15...15), dy: .random(in: -55 ... -35))
            case .sparkle: CGVector(dx: .random(in: -60...60), dy: .random(in: -70...10))
            case .snip: CGVector(dx: .random(in: -40...40), dy: .random(in: 10...50))
            }
            let life = kind == .fluff ? Double.random(in: 1.4...2.4) : 1.1
            particles.append(Particle(kind: kind, p: p, v: v, life: life, maxLife: life, color: color))
        }
    }

    // MARK: Berührung

    func dragChanged(_ p: CGPoint, start: CGPoint) {
        cursor = p
        let last = lastDrag ?? start
        lastDrag = p
        guard let r = rabbit else { return }
        let dist = hypot(p.x - last.x, p.y - last.y)
        let l = local(p)
        switch tool {
        case .buerste:
            guard onRabbit(l) else { return }
            strokeAccum += dist
            if Double.random(in: 0...1) < 0.4 { spawn(.fluff, at: p, count: 1, color: r.look.fur.main) }
            if strokeAccum > 42 {
                strokeAccum = 0
                let before = r.coatValue
                game.careBrush(rabbitID)
                happyUntil = clock + 0.8
                stress = max(0, stress - 0.01)
                UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.45)
                if before < 100, (rabbit?.coatValue ?? 0) >= 100 {
                    spawn(.sparkle, at: p, count: 10, color: .white)
                    say("Das Fell glänzt ✨", ok: true)
                }
            }
        case .streicheln:
            guard onRabbit(l) else { return }
            strokeAccum += dist
            happyUntil = clock + 0.8
            if strokeAccum > 40 {
                strokeAccum = 0
                stress = max(0, stress - 0.05)
                game.carePet(rabbitID)
                spawn(.heart, at: CGPoint(x: p.x, y: p.y - 14), count: 1, color: Color(hex: 0xF27A9B))
                UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.4)
            }
        default:
            break
        }
    }

    func dragEnded(_ p: CGPoint, isTap: Bool) {
        cursor = nil
        lastDrag = nil
        strokeAccum = 0
        guard isTap, let r = rabbit else { return }
        let l = local(p)
        switch tool {
        case .schere:
            let nearest = Self.paws.enumerated().min { a, b in
                hypot(a.element.1.x - l.x, a.element.1.y - l.y) < hypot(b.element.1.x - l.x, b.element.1.y - l.y)
            }
            guard let nearest, hypot(nearest.element.1.x - l.x, nearest.element.1.y - l.y) < 7 else {
                say("Tipp direkt auf eine Pfote.", ok: false, duration: 2)
                return
            }
            let i = nearest.offset, paw = nearest.element
            if clipped.contains(i) || r.clawValue < 8 { say("Die Krallen \(paw.0) sind schon kurz.", ok: true, duration: 2); return }
            if game.clipClaws(rabbitID, stress: stress) {
                clipped.insert(i)
                stress = min(1, stress + 0.12)
                spawn(.snip, at: screen(paw.1), count: 4, color: Color(hex: 0xE9E1CF))
                say(clipped.count == 4 ? "Alle Krallen geschnitten! 🐾" : "Krallen \(paw.0) geschnitten.", ok: true, duration: 2)
            } else {
                stress = min(1, stress + 0.08)
                wriggleUntil = clock + 0.6
                say("Es zappelt! Streicheln oder ein Leckerli beruhigt.", ok: false)
            }
        case .untersuchen:
            guard let part = Self.parts.min(by: { hypot($0.2.x - l.x, $0.2.y - l.y) < hypot($1.2.x - l.x, $1.2.y - l.y) }),
                  hypot(part.2.x - l.x, part.2.y - l.y) < 9 else {
                say("Tipp auf Mund, Ohr oder Auge.", ok: false, duration: 2)
                return
            }
            if !checkupDone {
                checkupDone = true
                game.checkup(rabbitID)
            }
            checked.insert(part.0)
            let r2 = rabbit ?? r
            switch part.0 {
            case "zaehne":
                if r2.illness == .zahnspitzen || r2.teethValue >= 85 { say("Zähne: viel zu lang – ab zur Tierärztin!", ok: false, duration: 4) }
                else if r2.teethValue >= 60 { say("Zähne: etwas lang – mehr Heu und Apfelzweige füttern.", ok: false, duration: 4) }
                else { say("Zähne: alles in Ordnung 😁", ok: true) }
            case "ohren":
                say(r2.illness == .ohrmilben ? "Ohren: Krusten – Ohrmilben! Tierärztin nötig." : "Ohren: sauber 👂", ok: r2.illness != .ohrmilben, duration: 4)
            default:
                say(r2.illness == .schnupfen ? "Augen & Nase: niest, feuchte Nase – Schnupfen." : "Augen & Nase: klar und trocken 👀",
                    ok: r2.illness != .schnupfen, duration: 4)
            }
        case .leckerli:
            guard onRabbit(l) || hypot(l.x - 30, l.y + 24) < 10 else { return }
            if game.careTreat(rabbitID) {
                stress = max(0, stress - 0.4)
                happyUntil = clock + 1.5
                spawn(.heart, at: screen(CGPoint(x: 28, y: -30)), count: 3, color: Color(hex: 0xF27A9B))
                say("Mmh! Ganz entspannt 😌", ok: true, duration: 2)
            } else {
                say("Keine Leckerlis mehr – pflück Löwenzahn oder ernte Möhren.", ok: false)
            }
        default:
            break
        }
    }
}

/// Der Pflegeraum im Vollbild.
struct CareRoomView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var room: CareRoom
    @State private var dragStart: CGPoint?

    init(game: GardenGame, rabbitID: UUID) {
        _room = State(initialValue: CareRoom(game: game, rabbitID: rabbitID))
    }

    var body: some View {
        ZStack {
            TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                Canvas(opaque: true) { ctx, size in
                    CareRoomRenderer.draw(room, in: &ctx, size: size, time: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if dragStart == nil { dragStart = v.startLocation }
                        room.dragChanged(v.location, start: v.startLocation)
                    }
                    .onEnded { v in
                        let start = dragStart ?? v.startLocation
                        dragStart = nil
                        room.dragEnded(v.location, isTap: hypot(v.location.x - start.x, v.location.y - start.y) < 12)
                    }
            )
            .onGeometryChange(for: CGSize.self) { $0.size } action: { room.size = $0 }
            .ignoresSafeArea()

            hud
        }
        .preferredColorScheme(.light)
        .statusBarHidden()
        .task { await room.run() }
        .sensoryFeedback(.selection, trigger: room.tool)
    }

    private var hud: some View {
        let _ = room.tick
        let r = room.rabbit
        let game = room.game
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Label("Zur Wiese", systemImage: "chevron.left").font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14).frame(height: 40)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .capsule)
                Spacer()
                Text(r.map { $0.isVisitor ? "Neuankömmling" : $0.name } ?? "")
                    .font(MTheme.title(20))
                    .padding(.horizontal, 14).frame(height: 40)
                    .glassEffect(.regular, in: .capsule)
            }
            if let r {
                HStack(spacing: 10) {
                    gauge("Fell", value: r.coatValue / 100, good: r.coatValue >= 50, symbol: "comb.fill")
                    gauge("Krallen", value: 1 - r.clawValue / 100, good: r.clawValue < 60, symbol: "scissors")
                    gauge("Ruhe", value: 1 - room.stress, good: room.stress < 0.5, symbol: "leaf.fill")
                }
                .padding(12)
                .glassEffect(.regular.tint(.white.opacity(0.25)), in: .rect(cornerRadius: 20))
            }
            if let note = room.note {
                Label(note.text, systemImage: note.ok ? "checkmark.circle.fill" : "exclamationmark.bubble.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(note.ok ? MTheme.leaf : MTheme.carrot)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .glassEffect(.regular.tint(.white.opacity(0.4)), in: .capsule)
                    .transition(.scale.combined(with: .opacity))
                    .id(note.id)
            }
            Spacer()
            if let r, (r.illness != nil && r.illnessFound == true) || r.teethValue >= 85 {
                let cost = r.illness?.cost ?? 15
                Button { _ = game.treat(r.id) } label: {
                    Label("\(GardenGame.vetName) rufen: \(r.illness?.title ?? "Zähne kürzen") – \(cost) ★", systemImage: "cross.case.fill")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 16).frame(height: 44)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(Color(hex: 0xD9534F).opacity(0.85)).interactive(), in: .capsule)
                .disabled(game.inventory.sterne < cost)
            }
            Text(room.tool.hint).font(.footnote.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .glassEffect(.regular, in: .capsule)
            GlassEffectContainer(spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(CareTool.allCases) { t in
                        Button { room.tool = t } label: {
                            VStack(spacing: 3) {
                                Image(systemName: t.symbol).font(.title3.weight(.semibold))
                                Text(t == .leckerli ? "Leckerli \(game.inventory.loewenzahn + game.inventory.moehre)" : t.title)
                                    .font(.caption2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
                            }
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .foregroundStyle(room.tool == t ? Color.white : Color.primary)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(room.tool == t ? .regular.tint(MTheme.carrot.opacity(0.85)).interactive() : .regular.interactive(),
                                     in: .rect(cornerRadius: 22))
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
        .frame(maxWidth: 600)
        .animation(.spring(duration: 0.3), value: room.note)
    }

    private func gauge(_ title: String, value: Double, good: Bool, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(.black.opacity(0.1))
                    Capsule().fill((good ? MTheme.leaf : MTheme.carrot).gradient)
                        .frame(width: max(6, g.size.width * min(max(value, 0), 1)))
                }
            }
            .frame(height: 8)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Zeichnet den Pflegeraum: Wand, Fenster zur Wiese, Regal, Tisch mit Handtuch, das große Kaninchen.
@MainActor
enum CareRoomRenderer {
    static func draw(_ room: CareRoom, in ctx: inout GraphicsContext, size: CGSize, time: Double) {
        let W = size.width, H = size.height
        let tableY = H * 0.66
        let day = room.game.daylight

        // Wand und Holzverkleidung
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .linearGradient(Gradient(colors: [Color(hex: 0xF6EBDA), Color(hex: 0xE9D6BB)]),
                                       startPoint: .zero, endPoint: CGPoint(x: 0, y: tableY)))
        let panel = CGRect(x: 0, y: tableY - H * 0.16, width: W, height: H * 0.16)
        ctx.fill(Path(panel), with: .color(Color(hex: 0xC9A47A)))
        var boards = Path()
        var x: CGFloat = 0
        while x < W { boards.move(to: CGPoint(x: x, y: panel.minY)); boards.addLine(to: CGPoint(x: x, y: panel.maxY)); x += 26 }
        ctx.stroke(boards, with: .color(Color(hex: 0xA9845C).opacity(0.6)), lineWidth: 1)
        ctx.fill(Path(CGRect(x: 0, y: panel.minY - 4, width: W, height: 6)), with: .color(Color(hex: 0xB08A60)))

        // Fenster zur Wiese (Tageslicht wie draußen)
        let win = CGRect(x: W * 0.08, y: H * 0.1, width: W * 0.34, height: H * 0.2)
        let sky = GardenRenderer.mix(Color(hex: 0x86C1EC), Color(hex: 0x15214A), CGFloat(1 - day))
        ctx.fill(Path(roundedRect: win, cornerRadius: 6), with: .linearGradient(Gradient(colors: [sky, GardenRenderer.mix(sky, .white, 0.4)]),
                                                                                startPoint: CGPoint(x: 0, y: win.minY), endPoint: CGPoint(x: 0, y: win.maxY)))
        var hill = Path()
        hill.move(to: CGPoint(x: win.minX, y: win.maxY))
        hill.addQuadCurve(to: CGPoint(x: win.maxX, y: win.maxY - win.height * 0.25), control: CGPoint(x: win.midX, y: win.maxY - win.height * 0.55))
        hill.addLine(to: CGPoint(x: win.maxX, y: win.maxY))
        hill.closeSubpath()
        ctx.fill(hill, with: .color(GardenRenderer.mix(Color(hex: 0x6EA34E), Color(hex: 0x14241A), CGFloat(1 - day) * 0.8)))
        ctx.stroke(Path(roundedRect: win, cornerRadius: 6), with: .color(.white), lineWidth: 6)
        var cross = Path()
        cross.move(to: CGPoint(x: win.midX, y: win.minY)); cross.addLine(to: CGPoint(x: win.midX, y: win.maxY))
        cross.move(to: CGPoint(x: win.minX, y: win.midY)); cross.addLine(to: CGPoint(x: win.maxX, y: win.midY))
        ctx.stroke(cross, with: .color(.white), lineWidth: 4)

        // Regal mit Gläsern, Bürste und Pflanze
        let shelfY = H * 0.24
        ctx.fill(Path(roundedRect: CGRect(x: W * 0.56, y: shelfY, width: W * 0.38, height: 7), cornerRadius: 2), with: .color(Color(hex: 0x9C6B45)))
        let jars: [(CGFloat, UInt32)] = [(0.6, 0xF2C14E), (0.68, 0x9DD67A), (0.76, 0xE2722B)]
        for (fx, color) in jars {
            let r = CGRect(x: W * fx, y: shelfY - 30, width: 22, height: 30)
            ctx.fill(Path(roundedRect: r, cornerRadius: 5), with: .color(Color(hex: color).opacity(0.75)))
            ctx.fill(Path(roundedRect: CGRect(x: r.minX - 1, y: r.minY - 5, width: 24, height: 6), cornerRadius: 2), with: .color(Color(hex: 0x7A5230)))
        }
        let pot = CGRect(x: W * 0.86, y: shelfY - 22, width: 22, height: 22)
        ctx.fill(Path(roundedRect: pot, cornerRadius: 4), with: .color(Color(hex: 0xC8643C)))
        for k in 0..<5 {
            let a = -Double.pi / 2 + (Double(k) - 2) * 0.4
            var leaf = Path()
            leaf.move(to: CGPoint(x: pot.midX, y: pot.minY))
            leaf.addQuadCurve(to: CGPoint(x: pot.midX + CGFloat(cos(a)) * 26, y: pot.minY + CGFloat(sin(a)) * 26),
                              control: CGPoint(x: pot.midX + CGFloat(cos(a + 0.3)) * 14, y: pot.minY + CGFloat(sin(a + 0.3)) * 14))
            ctx.stroke(leaf, with: .color(Color(hex: 0x4E9A36)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        }
        // warmes Licht der Lampe
        ctx.fill(Path(ellipseIn: CGRect(x: W * 0.2, y: -H * 0.1, width: W * 0.6, height: H * 0.5)),
                 with: .radialGradient(Gradient(colors: [Color(hex: 0xFFF3D6).opacity(0.55), .clear]),
                                       center: CGPoint(x: W * 0.5, y: H * 0.05), startRadius: 0, endRadius: W * 0.5))

        // Behandlungstisch mit Handtuch
        let table = CGRect(x: -20, y: tableY, width: W + 40, height: H - tableY + 20)
        ctx.fill(Path(table), with: .linearGradient(Gradient(colors: [Color(hex: 0xB9834F), Color(hex: 0x8E5F35)]),
                                                    startPoint: CGPoint(x: 0, y: tableY), endPoint: CGPoint(x: 0, y: H)))
        ctx.fill(Path(CGRect(x: 0, y: tableY, width: W, height: 5)), with: .color(Color(hex: 0xD9A877)))
        let c = room.center, s = room.scale
        let towel = CGRect(x: c.x - 48 * s, y: c.y - 4 * s, width: 92 * s, height: 22 * s)
        ctx.fill(Path(roundedRect: towel, cornerRadius: 8), with: .color(Color(hex: 0xBFD9EC)))
        var stripes = Path()
        for k in 0..<3 {
            let y = towel.minY + towel.height * (0.3 + CGFloat(k) * 0.2)
            stripes.move(to: CGPoint(x: towel.minX + 6, y: y)); stripes.addLine(to: CGPoint(x: towel.maxX - 6, y: y))
        }
        ctx.stroke(stripes, with: .color(.white.opacity(0.7)), lineWidth: 3)

        // Kaninchen
        if let r = room.rabbit {
            var pose = RabbitPose()
            pose.breath = 1 + 0.02 * CGFloat(sin(room.clock * 3))
            pose.coat = CGFloat(r.coatValue)
            pose.claws = CGFloat(r.clawValue)
            pose.earsBack = CGFloat(room.stress * 0.9)
            pose.nose = CGFloat(sin(room.clock * 26)) * 0.7
            if room.happyUntil > room.clock { pose.eyesClosed = true; pose.happy = true }
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 34 * s, y: c.y - 4 * s, width: 68 * s, height: 9 * s)),
                     with: .radialGradient(Gradient(colors: [.black.opacity(0.25), .clear]),
                                           center: c, startRadius: 0, endRadius: 34 * s))
            ctx.drawLayer { l in
                let wriggle = room.wriggleUntil > room.clock ? CGFloat(sin(room.clock * 60)) * 0.06 : 0
                l.translateBy(x: c.x, y: c.y)
                l.scaleBy(x: s, y: s)
                l.rotate(by: .radians(Double(wriggle)))
                GardenRenderer.rabbitShape(&l, look: r.look, pose: pose)
            }

            // Markierungen je Werkzeug
            let pulse = 0.5 + 0.5 * sin(time * 4)
            if room.tool == .schere {
                for (i, paw) in CareRoom.paws.enumerated() {
                    let p = room.screen(paw.1)
                    let done = room.clipped.contains(i) || r.clawValue < 8
                    ctx.stroke(Path(ellipseIn: CGRect(x: p.x - 16, y: p.y - 16, width: 32, height: 32)),
                               with: .color((done ? MTheme.leaf : MTheme.carrot).opacity(0.5 + 0.4 * pulse)), lineWidth: 3)
                    if done {
                        let check = ctx.resolve(Text(Image(systemName: "checkmark")).font(.system(size: 13, weight: .heavy)).foregroundStyle(MTheme.leaf))
                        ctx.draw(check, at: CGPoint(x: p.x, y: p.y - 26))
                    }
                }
            }
            if room.tool == .untersuchen {
                for part in CareRoom.parts {
                    let p = room.screen(part.2)
                    let done = room.checked.contains(part.0)
                    ctx.stroke(Path(ellipseIn: CGRect(x: p.x - 18, y: p.y - 18, width: 36, height: 36)),
                               with: .color((done ? MTheme.leaf : Color(hex: 0x3F8FE0)).opacity(0.5 + 0.4 * pulse)), lineWidth: 3)
                    let label = ctx.resolve(Text(part.1).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.white))
                    ctx.drawLayer { l in
                        l.addFilter(.shadow(color: .black.opacity(0.5), radius: 2, y: 1))
                        l.draw(label, at: CGPoint(x: p.x, y: p.y - 28))
                    }
                }
            }
        }

        // Partikel
        let heart = ctx.resolve(Text(Image(systemName: "heart.fill")).font(.system(size: 18)).foregroundStyle(Color(hex: 0xF27A9B)))
        let sparkle = ctx.resolve(Text(Image(systemName: "sparkle")).font(.system(size: 14)).foregroundStyle(Color(hex: 0xFFE38A)))
        for part in room.particles {
            ctx.drawLayer { l in
                l.opacity = min(1, part.life / part.maxLife * 2)
                l.translateBy(x: part.p.x, y: part.p.y)
                l.rotate(by: .radians(part.rotation))
                switch part.kind {
                case .heart: l.draw(heart, at: .zero)
                case .sparkle: l.draw(sparkle, at: .zero)
                case .fluff:
                    var tuft = Path()
                    for k in 0..<5 {
                        let a = Double(k) * 1.256
                        tuft.move(to: .zero)
                        tuft.addQuadCurve(to: CGPoint(x: CGFloat(cos(a)) * 8, y: CGFloat(sin(a)) * 8),
                                          control: CGPoint(x: CGFloat(cos(a + 0.6)) * 5, y: CGFloat(sin(a + 0.6)) * 5))
                    }
                    l.stroke(tuft, with: .color(part.color), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                case .snip:
                    l.fill(Path(roundedRect: CGRect(x: -3, y: -1, width: 6, height: 2), cornerRadius: 1), with: .color(part.color))
                }
            }
        }

        // Werkzeug am Finger
        if let p = room.cursor, room.tool == .buerste || room.tool == .streicheln {
            let symbol = ctx.resolve(Text(Image(systemName: room.tool.symbol)).font(.system(size: 34)).foregroundStyle(
                room.tool == .buerste ? Color(hex: 0xA8743E) : Color(hex: 0xF27A9B)))
            ctx.draw(symbol, at: CGPoint(x: p.x + 18, y: p.y - 30))
        }
    }
}
