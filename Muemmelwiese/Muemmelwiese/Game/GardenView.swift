import SwiftUI
import UniformTypeIdentifiers

/// Mümmelwiese: ein Kaninchen-Spiel auf einer lebendigen Wiese.
///
/// Kaninchen hoppeln zufällig zu Besuch – gewöhnlich, selten, super selten oder legendär.
/// Mit Futter und vorsichtigem Streicheln fassen sie Vertrauen und ziehen ein.
/// Glückliche Kaninchen bringen Sterne; dafür gibt es Deko und größere Zuhause,
/// und je gemütlicher die Wiese, desto seltener die Gäste.
struct GardenView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var game = GardenGame()
    @State private var dragging = false
    @State private var showsAlbum = GardenDemo.isActive && GardenDemo.screen == "album"
    @State private var showsShop = GardenDemo.isActive && GardenDemo.screen == "shop"
    @State private var renamingID: UUID?
    @State private var newName = ""
    @State private var exporting = false
    @State private var exportDocument = SaveDocument(data: Data())
    @State private var importing = false
    @State private var confirmNewGame = false
    @State private var landscape = false
    @State private var showsStation = GardenDemo.isActive && GardenDemo.screen == "station"
    @State private var showsAdoption = GardenDemo.isActive && GardenDemo.screen == "adoption"
    @State private var showsHoppelgram = false
    /// Faltbares iPhone aufgeklappt (Innendisplay ~4:3): Bedienung links und rechts vom Falz.
    @State private var unfolded = false
    /// Zwischenraum über dem Falz – hier liegt kein Knopf und kein Text.
    private let hingeGutter: CGFloat = 32
    @State private var showsSplash = !GardenDemo.isActive

    var body: some View {
        ZStack {
            // Feste, niedrige Bildrate statt 120 Hz ProMotion – spart den meisten Strom.
            TimelineView(.animation(minimumInterval: 1 / Double(game.frameRate), paused: scenePhase != .active)) { timeline in
                Canvas(opaque: true) { ctx, size in
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
            .onGeometryChange(for: CGSize.self) { $0.size } action: {
                game.size = $0
                let short = min($0.width, $0.height), long = max($0.width, $0.height)
                unfolded = long > 0 && short >= 500 && short / long >= 0.62
                landscape = !unfolded && $0.width > $0.height * 1.15
                game.unfolded = unfolded
            }
            .ignoresSafeArea()
            .accessibilityLabel("Mümmelwiese mit \(game.residents.count) Kaninchen")

            hud

            if showsSplash {
                SplashView()
                    .transition(.opacity.combined(with: .scale(scale: 1.04)))
                    .task {
                        try? await Task.sleep(for: .seconds(1.6))
                        withAnimation(.easeInOut(duration: 0.6)) { showsSplash = false }
                    }
            }
        }
        .preferredColorScheme(.light)
        .statusBarHidden()
        .task { await game.run() }
        .task { if !GardenDemo.isActive { await RealWeather.shared.refresh() } }
        .onAppear {
            // Screenshots im Querformat
            if GardenDemo.isActive, GardenDemo.screen == "landscape",
               let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight)) { _ in }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            game.isActive = phase == .active
            if phase == .background { game.prepareForBackground() } else if phase != .active { game.persist() }
            if phase == .active { Task { await RealWeather.shared.refresh() } }
        }
        .sensoryFeedback(.selection, trigger: game.tool)
        .sheet(isPresented: $showsAlbum) { GardenAlbum(game: game).presentationSizing(.form) }
        .sheet(isPresented: $showsShop) { GardenShop(game: game).presentationSizing(.form) }
        .sheet(isPresented: $showsStation) { StationSheet(game: game).presentationSizing(.form) }
        .sheet(isPresented: $showsAdoption) { AdoptionSheet(game: game).presentationSizing(.form) }
        .sheet(isPresented: $showsHoppelgram) { HoppelgramSheet(game: game).presentationSizing(.form) }
        .sheet(item: Binding(get: { game.photoResult }, set: { game.photoResult = $0 })) { photo in
            PhotoSheet(game: game, photo: photo).presentationSizing(.form)
        }
        .fileExporter(isPresented: $exporting, document: exportDocument, contentType: .json,
                      defaultFilename: "Mümmelwiese \(Date.now.formatted(.dateTime.day().month().year()))") { result in
            if case .success = result { game.showBanner("In Dateien gesichert", symbol: "checkmark.circle.fill", duration: 3) }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result { _ = game.load(from: url) }
        }
        .alert("Neues Spiel beginnen?", isPresented: $confirmNewGame) {
            Button("Neu beginnen", role: .destructive) { game.newGame() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Deine Wiese und alle Kaninchen werden ersetzt. Sichere den Spielstand vorher in Dateien, wenn du ihn behalten möchtest.")
        }
        .alert("Wie soll es heißen?", isPresented: Binding(get: { renamingID != nil }, set: { if !$0 { renamingID = nil } })) {
            TextField("Name", text: $newName)
            Button("Sichern") { if let id = renamingID { game.rename(id, to: newName) } }
            Button("Abbrechen", role: .cancel) {}
        }
    }

    // MARK: - Oberfläche

    private var hud: some View {
        Group {
            if unfolded {
                // Aufgeklappt: zwei gleich breite Hälften, der Spalt dazwischen liegt genau auf dem Falz.
                VStack(spacing: 10) {
                    HStack(alignment: .top, spacing: hingeGutter) {
                        topBar.frame(maxWidth: .infinity)
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                stationBar
                                albumButton
                            }
                            bannerView
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                    }
                    Spacer(minLength: 0)
                    HStack(alignment: .bottom, spacing: hingeGutter) {
                        VStack(spacing: 10) { panels }
                            .frame(maxWidth: .infinity, alignment: .bottom)
                        toolbar(vertical: false)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 6)
            } else if landscape {
                // Querformat: Infos links, Werkzeuge senkrecht am rechten Rand, Wiese in voller Breite.
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        topBar
                        stationBar
                        bannerView
                        Spacer(minLength: 0)
                        panels
                    }
                    .frame(maxWidth: 430, alignment: .leading)
                    Spacer(minLength: 0)
                    toolbar(vertical: true)
                        .frame(width: 70)
                        .frame(maxHeight: .infinity, alignment: .center)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            } else {
                VStack(spacing: 10) {
                    topBar
                    stationBar
                    bannerView
                    Spacer(minLength: 0)
                    panels
                    toolbar(vertical: false)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 4)
                .frame(maxWidth: 560)
            }
        }
        .animation(.spring(duration: 0.35), value: game.banner)
        .animation(.spring(duration: 0.35), value: game.selectedID)
        .animation(.spring(duration: 0.3), value: game.tool)
    }

    /// Wetter von draußen und Jahreszeit
    private var weatherChip: some View {
        let isDay = game.daylight > 0.4
        return HStack(spacing: 6) {
            if let kind = game.weatherKind {
                Image(systemName: kind.symbol(isDay: isDay)).symbolRenderingMode(.multicolor)
                if let t = game.temperature { Text("\(Int(t.rounded()))°").monospacedDigit() }
                Text(kind.title).foregroundStyle(.secondary)
            }
            Image(systemName: game.season.symbol).foregroundStyle(MTheme.leaf)
                .accessibilityLabel(game.season.title)
        }
        .font(.caption.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.horizontal, 10).frame(height: 36)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .combine)
    }

    /// Station: Level, Wetter, Aufgaben, Vermittlung, Hoppelgram.
    private var stationBar: some View {
        let _ = game.hudTick
        return HStack(spacing: 8) {
            Button { showsStation = true } label: {
                LevelBadge(level: game.level, progress: Double(game.xp) / Double(max(game.xpForNext, 1)))
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            weatherChip
            Spacer(minLength: 0)
            CountButton(symbol: "checklist", count: game.claimableQuests, label: "Aufgaben") { showsStation = true }
            CountButton(symbol: "envelope.fill", count: game.adopters.count, label: "Vermittlung") { showsAdoption = true }
            CountButton(symbol: "camera.aperture", count: 0, label: "Hoppelgram") { showsHoppelgram = true }
        }
    }

    @ViewBuilder private var bannerView: some View {
        if let banner = game.banner {
            Label(banner.text, systemImage: banner.symbol)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .glassEffect(.regular.tint(.white.opacity(0.25)), in: .capsule)
                .transition(.move(edge: .top).combined(with: .opacity))
                .id(banner.id)
        }
    }

    @ViewBuilder private var panels: some View {
        if game.tool == .gestalten {
            decorBar.transition(.move(edge: .bottom).combined(with: .opacity))
        } else if let rabbit = selectedRabbit {
            RabbitCard(rabbit: rabbit, game: game, compact: landscape) {
                newName = rabbit.name
                renamingID = rabbit.id
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .id(rabbit.id)
        }
        if game.tool == .futter { foodPicker.transition(.scale(scale: 0.9).combined(with: .opacity)) }
    }

    private var selectedRabbit: GardenRabbit? {
        _ = game.hudTick
        return game.selectedRabbit
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Menu {
                Button { showsShop = true } label: { Label("Shop", systemImage: "bag.fill") }
                Section {
                    Button { game.saveNow() } label: {
                        Label {
                            Text("Jetzt speichern")
                            Text(game.lastSavedAt.map { "Zuletzt \($0.formatted(date: .omitted, time: .shortened))" }
                                 ?? "Speichert auch automatisch")
                        } icon: { Image(systemName: "square.and.arrow.down.fill") }
                    }
                    Button {
                        exportDocument = SaveDocument(data: game.snapshot())
                        exporting = true
                    } label: { Label("In Dateien sichern …", systemImage: "folder.fill") }
                    Button { importing = true } label: { Label("Spielstand laden …", systemImage: "tray.and.arrow.down.fill") }
                }
                Section {
                    Toggle(isOn: Binding(get: { RealWeather.shared.enabled }, set: { RealWeather.shared.enabled = $0 })) {
                        Label("Wetter von draußen", systemImage: "cloud.sun.fill")
                    }
                    Toggle(isOn: Binding(get: { GardenGame.notificationsEnabled },
                                         set: { GardenGame.notificationsEnabled = $0; if $0 { game.requestNotificationPermission() } })) {
                        Label("Mitteilung bei seltenen Gästen", systemImage: "bell.badge.fill")
                    }
                }
                Section {
                    Button(role: .destructive) { confirmNewGame = true } label: { Label("Neues Spiel …", systemImage: "arrow.counterclockwise") }
                }
            } label: {
                Image(systemName: "line.3.horizontal").font(.headline).frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("Menü: Shop und Spielstand")

            Spacer(minLength: 0)
            HStack(spacing: 11) {
                ForEach(game.availableFoods) { kind in
                    HStack(spacing: 3) {
                        Image(systemName: kind.symbol).foregroundStyle(kind.tint)
                        Text("\(game.inventory[kind])").monospacedDigit().contentTransition(.numericText())
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(game.inventory[kind]) \(kind.title)")
                }
                HStack(spacing: 3) {
                    Image(systemName: "star.fill").foregroundStyle(MTheme.star)
                    Text("\(game.inventory.sterne)").monospacedDigit().contentTransition(.numericText())
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(game.inventory.sterne) Sterne")
            }
            .font(.subheadline.weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 14).frame(height: 44)
            .glassEffect(.regular, in: .capsule)
            .animation(.snappy, value: game.inventory)
            Spacer(minLength: 0)

            // Aufgeklappt sitzt das Album rechts vom Falz neben dem Wetter.
            if !unfolded { albumButton }
        }
        .padding(.top, 4)
    }

    private var albumButton: some View {
        Button { showsAlbum = true } label: {
            Image(systemName: "book.pages.fill").font(.headline).frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Mümmel-Album")
    }

    private var foodPicker: some View {
        HStack(spacing: 8) {
            ForEach(game.availableFoods) { kind in
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

    /// Gestalten: gekaufte Deko auswählen und auf die Wiese tippen, Aufgestelltes verschieben oder einpacken.
    private var decorBar: some View {
        let _ = game.hudTick
        let stock = DecorKind.allCases.filter { game.save.stock($0) > 0 }
        let selected = game.selectedDecorID.flatMap { id in game.save.decor.first { $0.id == id } }
        return VStack(alignment: .leading, spacing: 10) {
            if let selected {
                HStack(spacing: 10) {
                    Image(systemName: selected.kind.symbol).foregroundStyle(MTheme.leaf)
                    Text(selected.kind.title).font(.subheadline.weight(.semibold))
                    Text("– ziehen zum Verschieben").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Spacer(minLength: 0)
                    Button("Einpacken") { game.packAway(selected.id) }
                        .font(.footnote.weight(.semibold))
                        .buttonStyle(.glass)
                }
            } else {
                Text(stock.isEmpty ? "Kauf Deko im Shop – oder zieh Aufgestelltes an einen neuen Platz."
                     : (game.placing.map { "Tipp auf die Wiese, um \($0.title) aufzustellen" } ?? "Wähle Deko zum Aufstellen"))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button { showsShop = true } label: {
                        Label("Shop", systemImage: "bag.fill")
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 12).frame(height: 40)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint(MTheme.star.opacity(0.5)).interactive(), in: .capsule)
                    ForEach(stock) { kind in
                        Button {
                            game.placing = game.placing == kind ? nil : kind
                            game.selectedDecorID = nil
                        } label: {
                            HStack(spacing: 6) {
                                DecorPortrait(kind: kind, size: 30)
                                Text("\(kind.title) ×\(game.save.stock(kind))").font(.footnote.weight(.semibold))
                            }
                            .padding(.horizontal, 10).frame(height: 40)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(game.placing == kind ? .regular.tint(MTheme.leaf.opacity(0.6)).interactive() : .regular.interactive(),
                                     in: .capsule)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(14)
        .glassEffect(.regular.tint(.white.opacity(0.2)), in: .rect(cornerRadius: 26))
    }

    private func toolbar(vertical: Bool) -> some View {
        let layout = vertical ? AnyLayout(VStackLayout(spacing: 6)) : AnyLayout(HStackLayout(spacing: 6))
        return GlassEffectContainer(spacing: 6) {
            layout {
                ForEach(GardenTool.allCases) { tool in
                    Button { select(tool) } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tool.symbol).font(.title3.weight(.semibold))
                            Text(tool.title).font(.caption2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity, minHeight: vertical ? 50 : 54)
                        .foregroundStyle(game.tool == tool ? Color.white : Color.primary)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(game.tool == tool ? .regular.tint(MTheme.carrot.opacity(0.85)).interactive() : .regular.interactive(),
                                 in: .rect(cornerRadius: 22))
                    .accessibilityAddTraits(game.tool == tool ? .isSelected : [])
                }
            }
        }
    }

    private func select(_ tool: GardenTool) {
        game.tool = tool
        if tool != .gestalten { game.placing = nil; game.selectedDecorID = nil }
        switch tool {
        case .hand: game.showBanner("Tippen zum Ansehen, wischen zum Streicheln", symbol: "hand.point.up.left.fill", duration: 2.5)
        case .maeher: game.showBanner("Über den Rasen wischen – gibt Heu", symbol: "scissors", duration: 2.5)
        case .giesskanne: game.showBanner("Nasser Rasen und Möhren wachsen doppelt so schnell", symbol: "drop.fill", duration: 2.5)
        case .futter: game.showBanner("Tippen legt Futter auf den Rasen", symbol: "carrot.fill", duration: 2.5)
        case .foto: game.showBanner("Tipp auf einen Schützling – Luftsprünge und Dämmerlicht geben die besten Fotos", symbol: "camera.fill", duration: 3)
        case .gestalten: game.showBanner("Gemütlichkeit \(game.cozy) – lockt seltenere Gäste", symbol: "sparkles", duration: 3)
        }
    }
}

// MARK: - Seltenheit

struct RarityBadge: View {
    let rarity: Rarity

    var body: some View {
        Label(rarity.title, systemImage: rarity.symbol)
            .font(.caption2.weight(.heavy))
            .textCase(.uppercase)
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(rarity.color.gradient, in: .capsule)
            .overlay {
                if rarity == .legendaer {
                    Capsule().strokeBorder(.white.opacity(0.7), lineWidth: 1)
                }
            }
    }
}

// MARK: - Karte eines Kaninchens

private struct RabbitCard: View {
    let rabbit: GardenRabbit
    let game: GardenGame
    var compact = false
    var onRename: () -> Void
    @State private var confirmKeep = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                RabbitPortrait(look: rabbit.look, size: 58)
                    .background(Circle().fill(rabbit.rarity.color.opacity(rabbit.rarity == .gewoehnlich ? 0.18 : 0.32)))
                    .overlay(Circle().strokeBorder(rabbit.rarity.color.opacity(0.7), lineWidth: rabbit.rarity >= .superSelten ? 2 : 0))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(rabbit.isVisitor ? "Neuankömmling" : rabbit.name)
                            .font(MTheme.title(21))
                        if !rabbit.isVisitor {
                            Button(action: onRename) {
                                Image(systemName: "pencil").font(.footnote.weight(.bold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Umbenennen")
                        }
                    }
                    HStack(spacing: 6) {
                        RarityBadge(rarity: rabbit.rarity)
                        Text(rabbit.look.description)
                            .font(.caption.weight(.medium)).foregroundStyle(.secondary).lineLimit(1)
                    }
                    if !compact {
                        Text("\(rabbit.personality.title.capitalized) – \(rabbit.personality.hint)")
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
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
                StatBar(title: "Vertrauen", symbol: "heart.fill", value: rabbit.trust, tint: rabbit.rarity.color)
                if let wish = rabbit.wish {
                    let done = rabbit.wishFulfilled == true
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: done ? "checkmark.seal.fill" : wish.symbol)
                            .font(.title3)
                            .foregroundStyle(done ? MTheme.leaf : MTheme.carrot)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(done ? "Wunsch erfüllt" : "Wunsch: \(wish.text)")
                                .font(.subheadline.weight(.semibold))
                            Text(done ? "Jetzt noch etwas Vertrauen – dann zieht es ein." : wish.hint)
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .background((done ? MTheme.leaf : MTheme.carrot).opacity(0.12), in: .rect(cornerRadius: 14))
                } else {
                    Text(visitorHint)
                        .font(.footnote).foregroundStyle(.secondary)
                }
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
                    Spacer(minLength: 0)
                    Label("\(rabbit.rarity.income)", systemImage: "star.fill")
                        .font(.caption.weight(.bold)).foregroundStyle(MTheme.star)
                        .accessibilityLabel("bringt \(rabbit.rarity.income) Sterne")
                }
                .font(.footnote)
                // Vermittlung oder für immer behalten
                HStack(spacing: 8) {
                    if rabbit.isKept {
                        Label("Für immer zuhause", systemImage: "heart.circle.fill")
                            .font(.footnote.weight(.semibold)).foregroundStyle(Color(hex: 0xE84A6F))
                    } else if rabbit.isReady {
                        Label("Vermittlungsbereit", systemImage: "house.and.flag.fill")
                            .font(.footnote.weight(.semibold)).foregroundStyle(MTheme.leaf)
                    } else if let hint = game.readinessHint(rabbit) {
                        Text(hint).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    Button { confirmKeep = true } label: {
                        Label(rabbit.isKept ? "Freigeben" : "Behalten", systemImage: rabbit.isKept ? "arrow.uturn.left" : "heart.fill")
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 12).frame(height: 32)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint(Color(hex: 0xF27A9B).opacity(rabbit.isKept ? 0.1 : 0.35)).interactive(), in: .capsule)
                    Button { game.takePhoto(of: rabbit.id) } label: {
                        Label("Foto", systemImage: "camera.fill").font(.footnote.weight(.semibold))
                            .padding(.horizontal, 12).frame(height: 32)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint(MTheme.carrot.opacity(0.35)).interactive(), in: .capsule)
                }
            }

            HStack(spacing: 8) {
                ForEach(game.availableFoods) { kind in
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
        .confirmationDialog(rabbit.isKept ? "\(rabbit.name) wieder zur Vermittlung freigeben?" : "\(rabbit.name) für immer behalten?",
                            isPresented: $confirmKeep, titleVisibility: .visible) {
            Button(rabbit.isKept ? "Zur Vermittlung freigeben" : "Für immer behalten 💛") { game.setKept(rabbit.id, !rabbit.isKept) }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text(rabbit.isKept ? "Es zieht zurück in die Station und kann vermittelt werden."
                 : "Es zieht in dein eigenes Gehege (\(game.keptRabbits.count)/\(game.keepCapacity) belegt), wird nicht vermittelt, bringt doppelt Sterne und beruhigt Neuankömmlinge.")
        }
    }

    private var visitorHint: String {
        if rabbit.rarity == .legendaer { return "Legendär – nur mit viel Geduld und Möhren zu gewinnen. Es bleibt nicht lange!" }
        if rabbit.rarity == .superSelten { return "Super selten – Möhren und Löwenzahn wirken am besten." }
        switch rabbit.personality {
        case .schuechtern: return "Schüchtern – leg Futter in die Nähe und warte ab."
        case .verfressen: return "Mit Futter gewinnst du es sofort."
        case .verschmust: return "Ganz sanft streicheln wirkt Wunder."
        default: return "Futter und vorsichtiges Streicheln schaffen Vertrauen. Möhren wirken am stärksten."
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

// MARK: - Shop

/// Kleines Bild einer Deko für Shop und Leiste.
struct DecorPortrait: View {
    let kind: DecorKind
    var size: CGFloat = 56

    var body: some View {
        Canvas { ctx, sz in
            let s = sz.width / (kind == .teich || kind == .feenring || kind == .tunnel ? 118 : 74)
            ctx.translateBy(x: sz.width / 2, y: sz.height * 0.86)
            ctx.scaleBy(x: s, y: s)
            GardenRenderer.decorShape(&ctx, kind: kind, time: 0, seed: 7)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Kleines Bild eines Zuhauses.
struct HomePortrait: View {
    let style: HomeStyle
    var size: CGFloat = 64

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.5))
            .foregroundStyle(tint.gradient)
            .frame(width: size, height: size)
            .background(tint.opacity(0.15), in: .rect(cornerRadius: 16))
            .accessibilityHidden(true)
    }

    private var symbol: String {
        switch style {
        case .holzstall: "house.fill"
        case .cottage: "house.lodge.fill"
        case .pilzhaus: "circle.hexagongrid.fill"
        case .schloss: "building.columns.fill"
        }
    }

    private var tint: Color {
        switch style {
        case .holzstall: Color(hex: 0xB4503F)
        case .cottage: Color(hex: 0x4F86C6)
        case .pilzhaus: Color(hex: 0xE0392F)
        case .schloss: Color(hex: 0x5B5FA8)
        }
    }
}

private struct GardenShop: View {
    let game: GardenGame
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let _ = game.hudTick
        let stars = game.inventory.sterne
        NavigationStack {
            List {
                Section {
                    HStack {
                        Label("\(stars) Sterne", systemImage: "star.fill")
                            .font(.headline).foregroundStyle(MTheme.star)
                        Spacer()
                        Label("Gemütlichkeit \(game.cozy)", systemImage: "sparkles")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(MTheme.leaf)
                    }
                    OddsRow(odds: Rarity.odds(cozy: game.cozy, lucky: game.save.luckyClover))
                } footer: {
                    Text("Glückliche Kaninchen bringen regelmäßig Sterne – seltene mehr. Je gemütlicher die Wiese, desto seltener die Gäste.")
                }

                Section {
                    ForEach(GardenFoodKind.allCases.filter { $0.shopBundle != nil }) { kind in
                        let bundle = kind.shopBundle!
                        HStack(spacing: 12) {
                            Image(systemName: kind.symbol)
                                .font(.title2).foregroundStyle(kind.tint)
                                .frame(width: 52, height: 52)
                                .background(kind.tint.opacity(0.14), in: .rect(cornerRadius: 14))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(bundle.amount)× \(kind.title)").font(.headline)
                                Text(kind == .zweige ? "Winterfutter – wenn kein frisches Grün wächst."
                                     : (kind == .heu ? "Vorrat für Regentage und Winter." : "Das liebste Leckerli."))
                                    .font(.caption).foregroundStyle(.secondary)
                                Text("Vorrat: \(game.inventory[kind])").font(.caption2.weight(.semibold)).foregroundStyle(MTheme.leaf)
                            }
                            Spacer()
                            Button("\(bundle.price) ★") { game.buyFood(kind) }
                                .buttonStyle(.glassProminent)
                                .tint(MTheme.star)
                                .disabled(stars < bundle.price)
                        }
                    }
                } header: {
                    Text("Futter")
                } footer: {
                    Text(game.season == .winter ? "Im Winter wächst kaum Gras – Heu und Zweige halten deine Kaninchen satt." : "")
                }

                Section("Zuhause") {
                    ForEach(HomeStyle.allCases) { style in
                        let owned = game.save.ownedHomes.contains(style)
                        let current = game.save.home == style
                        HStack(spacing: 12) {
                            HomePortrait(style: style, size: 52)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(style.title).font(.headline)
                                Text("Platz für \(style.capacity) Kaninchen · Gemütlichkeit +\(style.cozy)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if current {
                                Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(MTheme.leaf)
                            } else if !owned && game.level < style.unlockLevel {
                                Label("Lv \(style.unlockLevel)", systemImage: "lock.fill")
                                    .font(.caption.weight(.bold)).foregroundStyle(.secondary)
                            } else {
                                Button(owned ? "Wählen" : "\(style.price) ★") { game.chooseHome(style) }
                                    .buttonStyle(.glassProminent)
                                    .tint(owned ? MTheme.leaf : MTheme.star)
                                    .disabled(!owned && stars < style.price)
                            }
                        }
                    }
                }

                Section("Deko") {
                    ForEach(DecorKind.allCases) { kind in
                        let owned = game.save.owned(kind)
                        HStack(spacing: 12) {
                            DecorPortrait(kind: kind, size: 52)
                                .background(MTheme.leaf.opacity(0.12), in: .rect(cornerRadius: 14))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(kind.title).font(.headline)
                                Text(kind.detail).font(.caption).foregroundStyle(.secondary)
                                Text("Gemütlichkeit +\(kind.cozy) · \(owned) von \(kind.limit)")
                                    .font(.caption2.weight(.semibold)).foregroundStyle(MTheme.leaf)
                            }
                            Spacer()
                            if game.level < kind.unlockLevel {
                                Label("Lv \(kind.unlockLevel)", systemImage: "lock.fill")
                                    .font(.caption.weight(.bold)).foregroundStyle(.secondary)
                            } else {
                                Button("\(kind.price) ★") {
                                    game.buy(kind)
                                    dismiss()
                                }
                                .buttonStyle(.glassProminent)
                                .tint(MTheme.star)
                                .disabled(stars < kind.price || owned >= kind.limit)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Shop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
            }
        }
        .presentationDetents([.large])
    }
}

private struct OddsRow: View {
    let odds: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Chance je Besuch").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(Rarity.allCases) { rarity in
                    VStack(spacing: 3) {
                        Image(systemName: rarity.symbol).foregroundStyle(rarity.color)
                        Text(odds[rarity.rawValue], format: .percent.precision(.fractionLength(rarity == .legendaer ? 1 : 0)))
                            .font(.caption.weight(.bold)).monospacedDigit()
                        Text(rarity.title).font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(rarity.color.opacity(0.12), in: .rect(cornerRadius: 10))
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Album

private struct GardenAlbum: View {
    let game: GardenGame
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let _ = game.hudTick
        let save = game.save
        let residents = game.residents.sorted { ($0.rarity, $0.joined) > ($1.rarity, $1.joined) }
        NavigationStack {
            List {
                Section {
                    if residents.isEmpty {
                        Text("Noch niemand eingezogen. Warte auf Besuch und gewinne sein Vertrauen.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(residents) { rabbit in
                        HStack(spacing: 12) {
                            RabbitPortrait(look: rabbit.look, size: 52)
                                .background(Circle().fill(rabbit.rarity.color.opacity(0.18)))
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(rabbit.name).font(.headline)
                                    if rabbit.isKept {
                                        Image(systemName: "heart.circle.fill").foregroundStyle(Color(hex: 0xE84A6F))
                                            .accessibilityLabel("für immer behalten")
                                    }
                                    RarityBadge(rarity: rabbit.rarity)
                                }
                                Text("\(rabbit.look.description) · \(rabbit.personality.title)")
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
                            game.tool = .hand
                            game.selectedID = rabbit.id
                            dismiss()
                        }
                    }
                } header: {
                    Text("Schützlinge \(game.stationResidents.count)/\(game.capacity) · eigene \(game.keptRabbits.count)/\(game.keepCapacity)")
                }

                Section {
                    LabeledContent("Kombinationen entdeckt", value: "\(game.combosFound)")
                    if let next = Progression.milestones.first(where: { $0 > game.combosFound }) {
                        let r = Progression.milestoneReward(next)
                        ProgressView(value: Double(game.combosFound), total: Double(next)) {
                            Text("Nächster Meilenstein: \(next) – Belohnung \(r.stars) ★").font(.caption)
                        }
                        .tint(MTheme.star)
                    }
                } header: {
                    Text("Sammelbuch")
                } footer: {
                    Text("Jede neue Kombination aus Fellfarbe, Zeichnung und Rasse zählt – über 600 sind möglich.")
                }

                if !game.adoptions.isEmpty {
                    Section("Ehemalige Schützlinge · \(game.adoptions.count) vermittelt") {
                        ForEach(game.adoptions) { rec in
                            HStack(alignment: .top, spacing: 12) {
                                RabbitPortrait(look: rec.look, size: 48)
                                    .background(Circle().fill(rec.rarity.color.opacity(0.15)))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(rec.name) · bei \(rec.family)").font(.subheadline.weight(.semibold))
                                    if Date.now.timeIntervalSince(rec.date) > 3600 {
                                        Text("✉️ \(rec.postcard)").font(.footnote).italic()
                                    } else {
                                        Text("Postkarte ist unterwegs …").font(.footnote).foregroundStyle(.secondary)
                                    }
                                    Text(rec.date.formatted(date: .abbreviated, time: .omitted)).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("Seltenheit") {
                    ForEach(Rarity.allCases) { rarity in
                        let met = save.metRarities.indices.contains(rarity.rawValue) ? save.metRarities[rarity.rawValue] : 0
                        let living = residents.filter { $0.rarity == rarity }.count
                        HStack {
                            RarityBadge(rarity: rarity)
                            Spacer()
                            Text("\(living) eingezogen · \(met) gesehen")
                                .font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
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
                    tip("hare.fill", "Fundtiere kommen in deiner Station an. Futter und sanftes Streicheln gewinnen ihr Vertrauen – bei vollem Kreis ziehen sie ein.")
                    tip("camera.fill", "Päppel sie auf, mach schöne Fotos und poste sie auf Hoppelgram – so finden sich tolle Menschen, die ein Zuhause bieten.")
                    tip("crown.fill", "Es gibt vier Stufen: gewöhnlich, selten, super selten und legendär. Seltene sind scheuer, bringen aber mehr Sterne.")
                    tip("star.fill", "Glückliche Kaninchen sammeln Sterne. Im Shop gibt es dafür Deko und größere Zuhause.")
                    tip("paintbrush.fill", "Mit „Gestalten“ stellst du Deko auf und verschiebst sie. Mehr Gemütlichkeit lockt seltenere Gäste.")
                    tip("leaf.fill", "Langer Rasen ist Futter. Gemäht wird er zu Heu – eine Heuraufe verfüttert es automatisch.")
                    tip("drop.fill", "Gießen lässt Rasen und Möhren doppelt so schnell wachsen. Regen hilft auch.")
                    tip("sun.max.fill", "Löwenzahn pflücken, bevor du mähst. Ein leuchtender Glücksklee lockt besondere Gäste.")
                    tip("moon.stars.fill", "Nachts schlafen die Kaninchen am Zuhause – die Wiese folgt deiner echten Uhr.")
                }
            }
            .navigationTitle("Mümmel-Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
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
            Image(systemName: symbol).foregroundStyle(MTheme.carrot)
        }
    }
}

#Preview {
    GardenView()
}


// MARK: - Spielstand als Datei

/// Spielstand für „In Dateien sichern“ (JSON).
struct SaveDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}


// MARK: - Startbildschirm

private struct SplashView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x1F3D6B), Color(hex: 0x6A6FA0), Color(hex: 0xF29A6B), Color(hex: 0xFFD48A)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 18) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .clipShape(.rect(cornerRadius: 34, style: .continuous))
                    .shadow(color: .black.opacity(0.3), radius: 18, y: 10)
                    .scaleEffect(appeared ? 1 : 0.85)
                Text("Mümmelwiese")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFE2A8), Color(hex: 0xFFB65E)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                Text("Deine Kaninchen-Auffangstation")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .opacity(appeared ? 1 : 0)
        }
        .onAppear { withAnimation(.spring(duration: 0.7)) { appeared = true } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Mümmelwiese")
    }
}
