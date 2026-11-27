import SwiftUI

// MARK: - Level-Abzeichen

struct LevelBadge: View {
    let level: Int
    let progress: Double

    var body: some View {
        ZStack {
            Circle().stroke(.black.opacity(0.12), lineWidth: 4)
            Circle().trim(from: 0, to: progress)
                .stroke(MTheme.star.gradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: -2) {
                Text("Lv").font(.system(size: 8, weight: .heavy, design: .rounded)).foregroundStyle(.secondary)
                Text("\(level)").font(.system(size: 15, weight: .black, design: .rounded)).monospacedDigit()
            }
        }
        .frame(width: 38, height: 38)
        .padding(3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Stationslevel \(level)")
    }
}

/// Kleiner runder Knopf mit Zähler.
struct CountButton: View {
    let symbol: String
    let count: Int
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.headline).frame(width: 44, height: 44)
                .overlay(alignment: .topTrailing) {
                    if count > 0 {
                        Text("\(count)")
                            .font(.caption2.weight(.heavy)).foregroundStyle(.white)
                            .padding(.horizontal, 5).frame(minWidth: 18, minHeight: 18)
                            .background(MTheme.carrot, in: .capsule)
                            .offset(x: 2, y: -2)
                    }
                }
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(count > 0 ? "\(label), \(count) neu" : label)
    }
}

// MARK: - Station: Level & Aufgaben

struct StationSheet: View {
    let game: GardenGame
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let _ = game.hudTick
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 14) {
                            LevelBadge(level: game.level, progress: Double(game.xp) / Double(max(game.xpForNext, 1)))
                                .scaleEffect(1.3).frame(width: 60, height: 60)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Stationslevel \(game.level)").font(.title3.weight(.bold))
                                Text("\(game.xp) / \(game.xpForNext) Erfahrung").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        ProgressView(value: Double(game.xp), total: Double(max(game.xpForNext, 1))).tint(MTheme.star)
                        if let next = Progression.nextUnlock(after: game.level) {
                            Label("Ab Level \(next.level): \(next.items.joined(separator: ", "))", systemImage: "lock.open.fill")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        HStack {
                            stat("\(game.stationResidents.count)/\(game.capacity)", "Schützlinge", "hare.fill")
                            stat("\(game.keptRabbits.count)/\(game.keepCapacity)", "eigene", "heart.circle.fill")
                            stat("\(game.adoptions.count)", "vermittelt", "house.and.flag.fill")
                            stat("\(game.followers)", "Follower", "person.3.fill")
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    ForEach(game.quests) { q in
                        HStack(spacing: 12) {
                            Image(systemName: q.claimed ? "checkmark.circle.fill" : q.goal.symbol)
                                .font(.title3)
                                .foregroundStyle(q.claimed ? MTheme.leaf : MTheme.carrot)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(q.text).font(.subheadline.weight(.semibold))
                                    .strikethrough(q.claimed)
                                ProgressView(value: Double(q.progress), total: Double(q.target)).tint(MTheme.leaf)
                                HStack(spacing: 8) {
                                    Text("\(q.progress)/\(q.target)").monospacedDigit()
                                    Label("\(q.stars)", systemImage: "star.fill").foregroundStyle(MTheme.star)
                                    Text("+\(q.xp) EP")
                                    if let food = q.bonusFood {
                                        Label("\(q.bonusAmount)", systemImage: food.symbol).foregroundStyle(food.tint)
                                    }
                                }
                                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            if q.done && !q.claimed {
                                Button("Abholen") { game.claimQuest(q.id) }
                                    .buttonStyle(.glassProminent).tint(MTheme.leaf)
                            } else if !q.done && game.canReroll {
                                Button { game.rerollQuest(q.id) } label: { Image(systemName: "arrow.triangle.2.circlepath") }
                                    .buttonStyle(.glass)
                                    .accessibilityLabel("Aufgabe tauschen")
                            }
                        }
                    }
                } header: {
                    Text("Aufgaben für heute")
                } footer: {
                    Text(game.canReroll ? "Eine Aufgabe pro Tag kannst du tauschen. Um Mitternacht gibt es neue."
                                        : "Um Mitternacht gibt es neue Aufgaben.")
                }

                Section("So funktioniert die Station") {
                    step("hare.fill", "Fundtiere kommen an – ängstlich, hungrig, manchmal mit besonderem Bedarf. Gewinne ihr Vertrauen.")
                    step("heart.fill", "Päppel sie auf: satt, gut gelaunt, zutraulich, gebürstet und eingewöhnt = vermittlungsbereit.")
                    step("comb.fill", "Bürsten nicht vergessen: Angora und Löwenkopf verfilzen schnell, im Frühling und Herbst ist Fellwechsel.")
                    step("camera.fill", "Mach schöne Fotos (Luftsprung, goldene Stunde, Deko im Bild) und poste sie auf Hoppelgram.")
                    step("envelope.fill", "Menschen, die deine Posts sehen, fragen an. Wähle passende Schützlinge aus.")
                    step("house.and.flag.fill", "Nach der Vermittlung kommen Postkarten aus dem neuen Zuhause – und Platz für das nächste Fundtier.")
                    step("heart.fill", "Kaninchen, die viel Zeit miteinander verbringen, werden unzertrennlich – Partner werden nur zusammen vermittelt.")
                    step("heart.circle.fill", "Einige darfst du für immer behalten: Sie leben in deinem eigenen Gehege, bringen doppelt Sterne und beruhigen Neuankömmlinge.")
                }
            }
            .navigationTitle("Station")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func stat(_ value: String, _ title: String, _ symbol: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: symbol).foregroundStyle(MTheme.carrot)
            Text(value).font(.headline).monospacedDigit()
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func step(_ symbol: String, _ text: String) -> some View {
        Label { Text(text).font(.subheadline) } icon: { Image(systemName: symbol).foregroundStyle(MTheme.carrot) }
    }
}

// MARK: - Vermittlung

struct AdoptionSheet: View {
    let game: GardenGame
    @Environment(\.dismiss) private var dismiss
    @State private var choosingFor: Adopter?
    @State private var chosen: Set<UUID> = []

    var body: some View {
        let _ = game.hudTick
        NavigationStack {
            List {
                if game.adopters.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Noch keine Anfragen", systemImage: "envelope.open").font(.headline)
                            Text(game.posts.isEmpty
                                 ? "Interessenten finden deine Schützlinge über Hoppelgram. Mach ein schönes Foto (Werkzeug „Foto“) und poste es."
                                 : "Deine Posts sind online – die nächste Anfrage kommt bald. Bessere Fotos und mehr Follower bringen schneller Interessenten.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                ForEach(game.adopters) { adopter in
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                Image(systemName: adopter.symbol)
                                    .font(.title2).foregroundStyle(MTheme.carrot)
                                    .frame(width: 48, height: 48)
                                    .background(MTheme.carrot.opacity(0.12), in: .circle)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(adopter.name).font(.headline)
                                    if let via = adopter.viaPost {
                                        Text("Hat deinen Post von \(via) gesehen").font(.caption).foregroundStyle(MTheme.leaf)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Label("\(adopter.stars)", systemImage: "star.fill").font(.subheadline.weight(.bold)).foregroundStyle(MTheme.star)
                                    Text("bis \(adopter.expires.formatted(.relative(presentation: .named)))")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            Text(adopter.story).font(.subheadline)
                            HStack(spacing: 6) {
                                Text(adopter.count == 2 ? "Sucht zwei Kaninchen:" : "Sucht ein Kaninchen:")
                                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                ForEach(adopter.wishes, id: \.self) { w in
                                    Text(w.text)
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 8).padding(.vertical, 3)
                                        .background(MTheme.leaf.opacity(0.15), in: .capsule)
                                }
                            }
                            Button {
                                chosen = []
                                choosingFor = adopter
                            } label: {
                                Label("Schützlinge auswählen", systemImage: "hand.point.up.left.fill").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.glassProminent).tint(MTheme.carrot)
                        }
                        .padding(.vertical, 4)
                    }
                }

                if !game.adoptions.isEmpty {
                    Section("Zuletzt vermittelt") {
                        ForEach(game.adoptions.prefix(3)) { rec in
                            HStack {
                                RabbitPortrait(look: rec.look, size: 40)
                                Text("\(rec.name) → \(rec.family)").font(.subheadline)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Vermittlung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .sheet(item: $choosingFor) { adopter in
                chooser(for: adopter)
            }
        }
    }

    private func chooser(for adopter: Adopter) -> some View {
        NavigationStack {
            List {
                Section {
                    ForEach(game.stationResidents) { r in
                        let fitting = adopter.wishes.contains { $0.fits(r) }
                        let partnerID = r.partner
                        let blocked = partnerID != nil && adopter.count == 1
                        Button {
                            // Partner immer gemeinsam aus- und abwählen
                            let group = Set(partnerID.map { [r.id, $0] } ?? [r.id])
                            if chosen.contains(r.id) { chosen.subtract(group) }
                            else if chosen.count + group.count <= adopter.count { chosen.formUnion(group) }
                        } label: {
                            HStack(spacing: 12) {
                                RabbitPortrait(look: r.look, size: 46)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(r.name).font(.headline)
                                        if fitting { Image(systemName: "sparkles").foregroundStyle(MTheme.star) }
                                    }
                                    Text("\(r.look.description) · \(r.personality.title)").font(.caption).foregroundStyle(.secondary)
                                    Text(r.isReady ? "Vermittlungsbereit" : (game.readinessHint(r) ?? ""))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(r.isReady ? MTheme.leaf : .secondary)
                                    if let partner = game.partnerName(of: r) {
                                        Text(blocked ? "💞 Nur zusammen mit \(partner)" : "💞 Partner: \(partner)")
                                            .font(.caption2.weight(.semibold)).foregroundStyle(Color(hex: 0xE84A6F))
                                    }
                                }
                                Spacer()
                                Image(systemName: chosen.contains(r.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title2).foregroundStyle(chosen.contains(r.id) ? MTheme.leaf : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(!r.isReady || blocked)
                        .opacity(r.isReady && !blocked ? 1 : 0.5)
                    }
                } header: {
                    Text("\(adopter.name) wünscht sich: " + adopter.wishes.map(\.text).joined(separator: ", "))
                } footer: {
                    Text(adopter.count == 2 ? "Wähle zwei Schützlinge. Jeder Wunsch muss von mindestens einem erfüllt werden. Ein unzertrennliches Paar bringt 40 % Bonus."
                                            : "Wähle einen Schützling, der alle Wünsche erfüllt. Partner werden nicht getrennt.")
                }
            }
            .navigationTitle("Auswählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { choosingFor = nil } }
                ToolbarItem(placement: .confirmationAction) {
                    let picked = game.residents.filter { chosen.contains($0.id) }
                    Button("Vermitteln") {
                        if game.adopt(adopter.id, rabbits: Array(chosen)) {
                            choosingFor = nil
                            dismiss()
                        }
                    }
                    .disabled(!adopter.fits(picked))
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Hoppelgram

struct HoppelgramSheet: View {
    let game: GardenGame
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let _ = game.hudTick
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 14) {
                        Image("Logo").resizable().scaledToFill().frame(width: 64, height: 64).clipShape(.circle)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("@muemmelwiese").font(.headline)
                            Text("Kaninchen-Auffangstation · Vermittlung mit Herz").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    HStack {
                        stat("\(game.posts.count)", "Beiträge")
                        stat("\(game.followers)", "Follower")
                        stat("\(game.posts.reduce(0) { $0 + $1.likes })", "Likes")
                    }
                    if game.posts.isEmpty {
                        Text("Noch keine Beiträge. Wähle das Werkzeug „Foto“ und tipp auf einen Schützling – Luftsprünge und die goldene Stunde geben die besten Bilder.")
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).padding()
                    }
                    ForEach(game.posts) { post in
                        VStack(alignment: .leading, spacing: 8) {
                            if let image = game.photoImage(post.photo) {
                                Image(uiImage: image).resizable().scaledToFit().clipShape(.rect(cornerRadius: 14))
                                    .overlay(alignment: .topTrailing) {
                                        if post.adopted {
                                            Label("Vermittelt", systemImage: "house.and.flag.fill")
                                                .font(.caption.weight(.bold)).foregroundStyle(.white)
                                                .padding(.horizontal, 10).padding(.vertical, 5)
                                                .background(MTheme.leaf, in: .capsule).padding(8)
                                        }
                                    }
                            }
                            HStack(spacing: 12) {
                                Label("\(post.likes)", systemImage: "heart.fill").foregroundStyle(Color(hex: 0xE84A6F))
                                Label("\(post.comments.count)", systemImage: "bubble.right.fill").foregroundStyle(.secondary)
                                Spacer()
                                HStack(spacing: 1) {
                                    ForEach(0..<5) { i in
                                        Image(systemName: i < post.stars ? "star.fill" : "star").font(.caption2).foregroundStyle(MTheme.star)
                                    }
                                }
                            }
                            .font(.subheadline.weight(.semibold))
                            Text(post.caption).font(.subheadline)
                            ForEach(post.comments.prefix(3), id: \.self) { c in
                                Text(c).font(.caption).foregroundStyle(.secondary)
                            }
                            Text(post.created.formatted(.relative(presentation: .named))).font(.caption2).foregroundStyle(.tertiary)
                        }
                        .padding(12)
                        .background(.background.secondary, in: .rect(cornerRadius: 18))
                    }
                }
                .padding(16)
            }
            .navigationTitle("Hoppelgram")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
    }

    private func stat(_ value: String, _ title: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Polaroid nach dem Foto

struct PhotoSheet: View {
    let game: GardenGame
    let photo: PhotoResult
    @State private var caption = 0

    var body: some View {
        let captions = SocialPost.captions.map { String(format: $0, photo.name) }
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 10) {
                        Image(uiImage: photo.image).resizable().scaledToFit()
                        HStack(spacing: 2) {
                            ForEach(0..<5) { i in
                                Image(systemName: i < photo.stars ? "star.fill" : "star").foregroundStyle(MTheme.star)
                            }
                        }
                        .font(.title3)
                        Text(photo.name).font(.system(.title3, design: .rounded, weight: .bold))
                    }
                    .padding(12)
                    .padding(.bottom, 8)
                    .background(.white, in: .rect(cornerRadius: 6))
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
                    .rotationEffect(.degrees(-2))
                    .padding(.horizontal, 24)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(photo.notes, id: \.self) { note in
                            Label(note, systemImage: "sparkle").font(.subheadline)
                        }
                        if photo.stars <= 2 {
                            Text("Tipp: Warte auf einen Luftsprung, fotografiere in der Dämmerung oder mit Deko im Bild.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if photo.name != "Neuankömmling" {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Text für den Beitrag").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            ForEach(captions.indices, id: \.self) { i in
                                Button { caption = i } label: {
                                    HStack(alignment: .top) {
                                        Image(systemName: caption == i ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(caption == i ? MTheme.carrot : .secondary)
                                        Text(captions[i]).font(.subheadline).multilineTextAlignment(.leading)
                                        Spacer(minLength: 0)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Button {
                            game.post(photo, caption: captions[caption])
                        } label: {
                            Label("Auf Hoppelgram posten", systemImage: "paperplane.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent).tint(MTheme.carrot)
                    } else {
                        Text("Neuankömmlinge werden erst gepostet, wenn sie eingezogen sind.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Foto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Verwerfen") { game.photoResult = nil } }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Pflegestation: Krallen, Zähne, Ohren & Augen

struct CareSheet: View {
    let game: GardenGame
    let rabbitID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var clipped: Set<Int> = []
    @State private var wriggle: Int?
    @State private var checked = false

    private let paws = ["vorne links", "vorne rechts", "hinten links", "hinten rechts"]

    var body: some View {
        let _ = game.hudTick
        NavigationStack {
            if let r = game.save.rabbits.first(where: { $0.id == rabbitID }) {
                List {
                    Section {
                        HStack(spacing: 14) {
                            RabbitPortrait(look: r.look, size: 76)
                                .background(Circle().fill(MTheme.leaf.opacity(0.15)))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(r.isVisitor ? "Neuankömmling" : r.name).font(.title3.weight(.bold))
                                Text(r.isHealthy ? "Gesund 💚" : "Braucht Pflege").font(.subheadline)
                                    .foregroundStyle(r.isHealthy ? MTheme.leaf : MTheme.carrot)
                                if (r.isVisitor ? r.trust : r.friendship) < 35 {
                                    Text("Noch scheu – kann beim Krallenschneiden zappeln.").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Section {
                        meter("Krallenlänge", value: r.clawValue, warn: 60, symbol: "scissors")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(paws.indices, id: \.self) { i in
                                Button {
                                    if game.clipClaws(rabbitID) {
                                        clipped.insert(i)
                                        wriggle = nil
                                    } else {
                                        wriggle = i
                                    }
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: clipped.contains(i) ? "checkmark.circle.fill" : "pawprint.fill")
                                            .font(.title2)
                                            .foregroundStyle(clipped.contains(i) ? MTheme.leaf : MTheme.carrot)
                                            .rotationEffect(.degrees(wriggle == i ? 12 : 0))
                                            .animation(.spring(response: 0.2, dampingFraction: 0.2), value: wriggle)
                                        Text(wriggle == i ? "zappelt …" : paws[i]).font(.caption.weight(.semibold))
                                            .foregroundStyle(wriggle == i ? MTheme.carrot : .primary)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 64)
                                    .background(.background.secondary, in: .rect(cornerRadius: 14))
                                }
                                .buttonStyle(.plain)
                                .disabled(clipped.contains(i) || r.clawValue < 8)
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Krallen schneiden")
                    } footer: {
                        Text("Tipp jede Pfote an. Lange Krallen drücken auf die Laune und machen das Hoppeln schwer.")
                    }

                    Section {
                        Button {
                            game.checkup(rabbitID)
                            checked = true
                        } label: {
                            Label("Gesundheitscheck machen", systemImage: "stethoscope").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent).tint(MTheme.leaf)

                        if checked || (r.lastCheckup.map { Date.now.timeIntervalSince($0) < 3600 } ?? false) {
                            result("Zähne", ok: r.teethValue < 60,
                                   text: r.teethValue < 60 ? "In Ordnung" :
                                    (r.teethValue < 85 ? "Etwas lang – mehr Heu und Apfelzweige füttern" : "Viel zu lang – ab zur Tierärztin"),
                                   symbol: "mouth.fill")
                            result("Ohren", ok: r.illness != .ohrmilben,
                                   text: r.illness == .ohrmilben ? Illness.ohrmilben.detail : "Sauber", symbol: "ear.fill")
                            result("Augen & Nase", ok: r.illness != .schnupfen,
                                   text: r.illness == .schnupfen ? Illness.schnupfen.detail : "Klar und trocken", symbol: "eye.fill")
                            meter("Zahnlänge", value: r.teethValue, warn: 60, symbol: "mouth.fill")
                        }
                    } header: {
                        Text("Zähne, Ohren und Augen")
                    } footer: {
                        Text("Kaninchenzähne wachsen ständig. Heu und Zweige nutzen sie ab – Möhren und Löwenzahn kaum.")
                    }

                    if (r.illness != nil && r.illnessFound == true) || r.teethValue >= 85 {
                        Section {
                            let cost = r.illness?.cost ?? 15
                            VStack(alignment: .leading, spacing: 6) {
                                Label(r.illness?.title ?? "Zähne kürzen", systemImage: r.illness?.symbol ?? "mouth.fill")
                                    .font(.headline)
                                Text(r.illness?.detail ?? "Die Zähne sind so lang, dass sie gekürzt werden müssen.")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Button {
                                _ = game.treat(rabbitID)
                            } label: {
                                Label("Zu \(GardenGame.vetName) – \(cost) ★", systemImage: "cross.case.fill").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.glassProminent).tint(Color(hex: 0xD9534F))
                            .disabled(game.inventory.sterne < cost)
                        } header: {
                            Text("Tierärztin")
                        }
                    }
                }
                .navigationTitle("Pflege")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            } else {
                Text("Dieses Kaninchen ist nicht mehr da.").foregroundStyle(.secondary)
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func meter(_ title: String, value: Double, warn: Double, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(title, systemImage: symbol).font(.subheadline)
                Spacer()
                Text(value >= warn ? "zu lang" : "gut").font(.caption.weight(.bold))
                    .foregroundStyle(value >= warn ? MTheme.carrot : MTheme.leaf)
            }
            ProgressView(value: min(value, 100), total: 100).tint(value >= warn ? MTheme.carrot : MTheme.leaf)
        }
    }

    private func result(_ title: String, ok: Bool, text: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(ok ? MTheme.leaf : MTheme.carrot)
            VStack(alignment: .leading, spacing: 2) {
                Label(title, systemImage: symbol).font(.subheadline.weight(.semibold))
                Text(text).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
