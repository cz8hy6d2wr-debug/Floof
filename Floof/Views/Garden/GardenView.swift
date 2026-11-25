import SwiftUI

/// Mümmelwiese: ein kleines Kaninchen-Spiel im Vollbild.
///
/// Kaninchen hoppeln zufällig zu Besuch. Mit Futter und vorsichtigem Streicheln
/// fassen sie Vertrauen und ziehen ein. Danach wollen sie versorgt werden –
/// langer Rasen ist Futter, gemähter Rasen wird zu Heu, im Beet wachsen Möhren.
/// Die Tageszeit folgt der echten Uhr. Niemand verhungert: der Garten bleibt sanft.
struct GardenView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var game = GardenGame()
    @State private var dragging = false
    @State private var showsAlbum = false
    @State private var renamingID: UUID?
    @State private var newName = ""

    var body: some View {
        ZStack {
            TimelineView(.animation(paused: scenePhase != .active)) { timeline in
                Canvas { ctx, size in
                    GardenRenderer.draw(game, in: &ctx, size: size,
                                        time: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !dragging {
                            dragging = true
                            game.touchBegan(value.startLocation)
                        }
                        game.touchMoved(value.location)
                    }
                    .onEnded { value in
                        dragging = false
                        game.touchEnded(value.location)
                    }
            )
            .onGeometryChange(for: CGSize.self) { $0.size } action: { game.size = $0 }
            .ignoresSafeArea()
            .accessibilityLabel("Mümmelwiese mit \(game.residents.count) Kaninchen")

            hud
        }
        .preferredColorScheme(.light)
        .task { await game.run() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { game.persist() }
        }
        .onDisappear { game.persist() }
        .sensoryFeedback(.selection, trigger: game.tool)
        .sheet(isPresented: $showsAlbum) { GardenAlbum(game: game) }
        .alert("Wie soll es heißen?", isPresented: Binding(get: { renamingID != nil }, set: { if !$0 { renamingID = nil } })) {
            TextField("Name", text: $newName)
            Button("Sichern") { if let id = renamingID { game.rename(id, to: newName) } }
            Button("Abbrechen", role: .cancel) {}
        }
    }

    // MARK: - Oberfläche

    private var hud: some View {
        VStack(spacing: 10) {
            topBar
            if let banner = game.banner {
                Label(banner.text, systemImage: banner.symbol)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .glassEffect(.regular.tint(.white.opacity(0.25)), in: .capsule)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .id(banner.id)
            }
            Spacer(minLength: 0)
            if let rabbit = selectedRabbit {
                RabbitCard(rabbit: rabbit, game: game) {
                    newName = rabbit.name
                    renamingID = rabbit.id
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .id(rabbit.id)
            }
            if game.tool == .futter { foodPicker.transition(.scale(scale: 0.9).combined(with: .opacity)) }
            toolbar
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
        .frame(maxWidth: 560)
        .animation(.spring(duration: 0.35), value: game.banner)
        .animation(.spring(duration: 0.35), value: game.selectedID)
        .animation(.spring(duration: 0.3), value: game.tool)
    }

    private var selectedRabbit: GardenRabbit? {
        _ = game.hudTick
        return game.selectedRabbit
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.headline).frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("Mümmelwiese schließen")

            Spacer(minLength: 0)
            HStack(spacing: 14) {
                ForEach(GardenFoodKind.allCases) { kind in
                    HStack(spacing: 4) {
                        Image(systemName: kind.symbol).foregroundStyle(kind.tint)
                        Text("\(game.inventory[kind])").monospacedDigit().contentTransition(.numericText())
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(game.inventory[kind]) \(kind.title)")
                }
            }
            .font(.subheadline.weight(.bold))
            .padding(.horizontal, 16).frame(height: 44)
            .glassEffect(.regular, in: .capsule)
            .animation(.snappy, value: game.inventory)
            Spacer(minLength: 0)

            Button { showsAlbum = true } label: {
                Image(systemName: "book.pages.fill").font(.headline).frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("Mümmel-Album")
        }
        .padding(.top, 4)
    }

    private var foodPicker: some View {
        HStack(spacing: 8) {
            ForEach(GardenFoodKind.allCases) { kind in
                Button { game.foodChoice = kind } label: {
                    Label("\(kind.title) · \(game.inventory[kind])", systemImage: kind.symbol)
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12).frame(height: 36)
                }
                .buttonStyle(.plain)
                .glassEffect(game.foodChoice == kind ? .regular.tint(kind.tint.opacity(0.55)).interactive() : .regular.interactive(),
                             in: .capsule)
            }
        }
    }

    private var toolbar: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(GardenTool.allCases) { tool in
                    Button { select(tool) } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tool.symbol).font(.title3.weight(.semibold))
                            Text(tool.title).font(.caption2.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .foregroundStyle(game.tool == tool ? Color.white : Color.primary)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(game.tool == tool ? .regular.tint(Theme.carrot.opacity(0.85)).interactive() : .regular.interactive(),
                                 in: .rect(cornerRadius: 22))
                    .accessibilityAddTraits(game.tool == tool ? .isSelected : [])
                }
            }
        }
    }

    private func select(_ tool: GardenTool) {
        game.tool = tool
        switch tool {
        case .hand: game.showBanner("Tippen zum Ansehen, wischen zum Streicheln", symbol: "hand.point.up.left.fill", duration: 2.5)
        case .maeher: game.showBanner("Über den Rasen wischen – gibt Heu", symbol: "scissors", duration: 2.5)
        case .giesskanne: game.showBanner("Nasser Rasen und Möhren wachsen doppelt so schnell", symbol: "drop.fill", duration: 2.5)
        case .futter: game.showBanner("Tippen legt Futter auf den Rasen", symbol: "carrot.fill", duration: 2.5)
        }
    }
}

// MARK: - Karte eines Kaninchens

private struct RabbitCard: View {
    let rabbit: GardenRabbit
    let game: GardenGame
    var onRename: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                RabbitPortrait(look: rabbit.look, size: 58)
                    .background(Circle().fill(.white.opacity(0.4)))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(rabbit.isVisitor ? "Zu Besuch" : rabbit.name)
                            .font(Theme.title(21))
                        if !rabbit.isVisitor {
                            Button(action: onRename) {
                                Image(systemName: "pencil").font(.footnote.weight(.bold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Umbenennen")
                        }
                    }
                    Text("\(rabbit.look.breed.title) · \(rabbit.look.pattern == .einfarbig ? rabbit.look.fur.title : rabbit.look.pattern.title)")
                        .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    Text("\(rabbit.personality.title.capitalized) – \(rabbit.personality.hint)")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                Button { game.selectedID = nil } label: {
                    Image(systemName: "xmark.circle.fill").font(.title2).symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Karte schließen")
            }

            if rabbit.isVisitor {
                StatBar(title: "Vertrauen", symbol: "heart.fill", value: rabbit.trust, tint: Color(hex: 0xF27A9B))
                Text(visitorHint)
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                HStack(spacing: 10) {
                    StatBar(title: "Satt", symbol: "fork.knife", value: rabbit.hunger, tint: Color(hex: 0xE2722B))
                    StatBar(title: "Laune", symbol: "face.smiling", value: rabbit.mood, tint: Color(hex: 0xE0A82E))
                    StatBar(title: "Energie", symbol: "bolt.fill", value: rabbit.energy, tint: Color(hex: 0x5E9BD6))
                }
                HStack(spacing: 3) {
                    ForEach(0..<5) { k in
                        Image(systemName: rabbit.friendship >= Double(k + 1) * 20 - 10 ? "heart.fill" : "heart")
                            .foregroundStyle(Color(hex: 0xF27A9B))
                    }
                    Text(status).font(.footnote).foregroundStyle(.secondary).padding(.leading, 6).lineLimit(1)
                }
                .font(.footnote)
                .accessibilityElement(children: .combine)
            }

            HStack(spacing: 8) {
                ForEach(GardenFoodKind.allCases) { kind in
                    Button { game.feed(rabbit.id, kind: kind) } label: {
                        HStack(spacing: 4) {
                            Image(systemName: kind.symbol).foregroundStyle(kind.tint)
                            Text("\(game.inventory[kind])").monospacedDigit()
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .opacity(game.inventory[kind] > 0 ? 1 : 0.45)
                    .accessibilityLabel("\(kind.title) geben, \(game.inventory[kind]) übrig")
                }
            }
        }
        .padding(14)
        .glassEffect(.regular.tint(.white.opacity(0.2)), in: .rect(cornerRadius: 26))
    }

    private var visitorHint: String {
        switch rabbit.personality {
        case .schuechtern: "Schüchtern – leg Futter in die Nähe und warte ab."
        case .verfressen: "Mit Futter gewinnst du es sofort."
        case .verschmust: "Ganz sanft streicheln wirkt Wunder."
        default: "Futter und vorsichtiges Streicheln schaffen Vertrauen. Möhren wirken am stärksten."
        }
    }

    private var status: String {
        if rabbit.hunger < 30 { return "hat Hunger" }
        if rabbit.energy < 25 { return "ist müde" }
        if rabbit.mood < 30 { return "langweilt sich" }
        if rabbit.mood > 85 { return "ist überglücklich" }
        return "fühlt sich wohl"
    }
}

private struct StatBar: View {
    let title: String
    let symbol: String
    let value: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.black.opacity(0.1))
                    Capsule().fill(tint.gradient)
                        .frame(width: max(6, proxy.size.width * value / 100))
                }
            }
            .frame(height: 7)
            .animation(.smooth, value: Int(value))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(Int(value)) Prozent")
    }
}

// MARK: - Album

private struct GardenAlbum: View {
    let game: GardenGame
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let _ = game.hudTick
        let save = game.save
        NavigationStack {
            List {
                Section {
                    if game.residents.isEmpty {
                        Text("Noch niemand eingezogen. Warte auf Besuch und gewinne sein Vertrauen.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(game.residents) { rabbit in
                        HStack(spacing: 12) {
                            RabbitPortrait(look: rabbit.look, size: 52)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rabbit.name).font(.headline)
                                Text("\(rabbit.look.breed.title) · \(rabbit.look.fur.title) · \(rabbit.personality.title)")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text("Auf der Wiese seit \(rabbit.joined.formatted(.relative(presentation: .named)))")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(Int(rabbit.friendship)) ♥").font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color(hex: 0xF27A9B))
                        }
                        .contentShape(.rect)
                        .onTapGesture {
                            game.selectedID = rabbit.id
                            dismiss()
                        }
                    }
                } header: {
                    Text("Deine Kaninchen · \(game.residents.count) von \(GardenGame.capacity)")
                }

                Section("Entdeckt") {
                    discovered("Fellfarben", all: GardenFur.allCases.map(\.title),
                               found: Set(save.discoveredFurs.map(\.title)))
                    discovered("Zeichnungen", all: GardenPattern.allCases.map(\.title),
                               found: Set(save.discoveredPatterns.map(\.title)))
                    discovered("Rassen", all: GardenBreed.allCases.map(\.title),
                               found: Set(save.discoveredBreeds.map(\.title)))
                    LabeledContent("Besuche bisher", value: "\(save.visitorsSeen)")
                    if save.luckyClover {
                        Label("Glücksklee aktiv – der nächste Besuch wird besonders", systemImage: "sparkles")
                            .foregroundStyle(.green)
                    }
                }

                Section("So geht's") {
                    tip("hare.fill", "Kaninchen kommen zufällig zu Besuch. Futter und sanftes Streicheln gewinnen ihr Vertrauen – bei vollem Herz ziehen sie ein.")
                    tip("leaf.fill", "Langer Rasen ist ihr Futter. Gemäht wird er zu Heu für schlechte Zeiten.")
                    tip("drop.fill", "Gießen lässt Rasen und Möhren doppelt so schnell wachsen. Regen hilft auch.")
                    tip("carrot.fill", "Im Beet oben rechts säen und ernten. Möhren sind das beste Leckerli.")
                    tip("sun.max.fill", "Gelben Löwenzahn pflücken, bevor du mähst. Ein leuchtender Glücksklee lockt seltene Gäste.")
                    tip("moon.stars.fill", "Nachts schlafen die Kaninchen am Stall – genau wie bei dir die Uhr läuft.")
                }
            }
            .navigationTitle("Mümmel-Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func discovered(_ title: String, all: [String], found: Set<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent(title, value: "\(found.count) / \(all.count)")
            Text(all.map { found.contains($0) ? $0 : "?" }.joined(separator: " · "))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func tip(_ symbol: String, _ text: String) -> some View {
        Label {
            Text(text).font(.subheadline)
        } icon: {
            Image(systemName: symbol).foregroundStyle(Theme.carrot)
        }
    }
}

#Preview {
    GardenView()
}
