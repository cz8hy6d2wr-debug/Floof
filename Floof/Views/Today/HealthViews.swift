import SwiftUI

// MARK: - Kurz-Check

/// Kurz-Check je Tier: Fressen, Köttel, Verhalten – je ein Tipp.
/// Bei "gar nicht / keine / apathisch" erscheint sofort der Notfall-Hinweis.
struct HealthCheckCard: View {
    @Environment(PetStore.self) private var store
    let pet: Pet
    var day: Date = .now

    @State private var editing = false
    @State private var note = ""
    @State private var emergencyArticle: String?
    @Namespace private var glass

    private var check: DailyCheck? { pet.check(on: day) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let check, check.isComplete, check.need == .green, !editing {
                // Alles normal: kompakt bleiben.
                EmptyView()
            } else {
                ForEach(DailyCheck.Aspect.allCases) { aspect in
                    aspectRow(aspect)
                }
                if check?.isComplete == true {
                    TextField("Notiz (optional), z. B. „Heu nur angeknabbert“", text: $note, axis: .vertical)
                        .font(.subheadline)
                        .lineLimit(1...3)
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .onSubmit { store.setCheckNote(note, for: pet.id, on: day) }
                        .onChange(of: note) { _, new in store.setCheckNote(new, for: pet.id, on: day) }
                }
            }

            if check?.need == .red {
                emergencyBox
            }
        }
        .card()
        .onAppear { note = check?.note ?? "" }
        .animation(.snappy, value: check)
        .sheet(isPresented: Binding(get: { emergencyArticle != nil }, set: { if !$0 { emergencyArticle = nil } })) {
            if let id = emergencyArticle { LexiconSheet(start: .article(id)) }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            PetAvatar(pet: pet, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text("Kurz-Check").font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(Theme.inkSoft).lineLimit(2)
            }
            Spacer()
            if check?.isComplete != true {
                Button("Alles normal") {
                    withAnimation(.snappy) { store.setCheckAllNormal(for: pet.id, on: day) }
                    editing = false
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.leaf)
                .controlSize(.small)
                .lineLimit(1)
                .fixedSize()
            } else if check?.need == .green && !editing {
                Label("Alles normal", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.leaf)
                    .lineLimit(1)
                    .fixedSize()
                Button("Ändern") { withAnimation(.snappy) { editing = true } }
                    .font(.subheadline)
                    .buttonStyle(.borderless)
            }
        }
    }

    private var subtitle: String {
        guard let check else { return "\(pet.name) · noch nicht eingetragen" }
        if let findings = check.findings { return "\(pet.name) · \(findings)" }
        return check.isComplete ? "\(pet.name) · alles unauffällig" : "\(pet.name) · noch nicht vollständig"
    }

    private func aspectRow(_ aspect: DailyCheck.Aspect) -> some View {
        let current = check?.level(aspect)
        return VStack(alignment: .leading, spacing: 6) {
            Label(aspect.title, systemImage: aspect.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.inkSoft)
            GlassEffectContainer(spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(DailyCheck.Level.allCases) { level in
                        let selected = current == level
                        Button {
                            withAnimation(.bouncy) { store.setCheck(aspect, level, for: pet.id, on: day) }
                        } label: {
                            Text(aspect.label(level))
                                .font(.subheadline.weight(selected ? .semibold : .regular))
                                .lineLimit(1).minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .foregroundStyle(selected ? Theme.ink : Theme.inkSoft)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(selected ? .regular.tint(color(level).opacity(0.35)).interactive() : .regular.interactive(),
                                     in: .capsule)
                        .glassEffectID("\(aspect.rawValue)-\(level.rawValue)", in: glass)
                        .accessibilityLabel("\(aspect.title): \(aspect.label(level))")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
        }
    }

    private func color(_ level: DailyCheck.Level) -> Color {
        switch level {
        case .normal: Theme.leaf
        case .reduced: Theme.honey
        case .alarming: Theme.berry
        }
    }

    private var emergencyBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Das kann ein Notfall sein", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.berry)
            Text("Frisst ein Kaninchen nicht, setzt keine Köttel ab oder ist apathisch, bitte **sofort Tierarzt oder Notdienst anrufen** – nicht bis morgen warten.")
                .font(.subheadline)
            Button("Was ich bis dahin tun kann", systemImage: "cross.case") {
                emergencyArticle = check?.appetite == .alarming || check?.droppings == .alarming ? "not-fressen" : "not-erste-hilfe"
            }
            .buttonStyle(.glass)
            .controlSize(.small)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.berry.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Für heute

struct TodayHintsCard: View {
    @Environment(PetStore.self) private var store
    let petID: Pet.ID?
    var limit = 3

    @State private var sheet: HintSheet?

    private enum HintSheet: Identifiable {
        case weigh(Pet)
        case diary(DiaryEntry)
        case cabinet(CabinetItem.ID)
        case article(String)

        var id: String {
            switch self {
            case .weigh(let p): "w-\(p.id)"
            case .diary(let e): "d-\(e.id)"
            case .cabinet(let id): "c-\(id)"
            case .article(let id): "a-\(id)"
            }
        }
    }

    var body: some View {
        let hints = store.todayHints(petID: petID, limit: limit)
        if !hints.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Für heute").font(.headline)
                ForEach(hints) { hint in
                    HStack(spacing: 12) {
                        Image(systemName: hint.symbol)
                            .font(.body)
                            .foregroundStyle(hint.urgent ? Theme.berry : Theme.carrot)
                            .frame(width: 34, height: 34)
                            .glassEffect(.regular, in: .circle)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(hint.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                            Text(hint.detail).font(.caption).foregroundStyle(hint.urgent ? Theme.berry : Theme.inkSoft)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 6)
                        Button(hint.actionTitle) { perform(hint.action) }
                            .buttonStyle(.glass)
                            .controlSize(.small)
                    }
                }
            }
            .card()
            .sheet(item: $sheet) { sheet in
                switch sheet {
                case .weigh(let pet): WeightSheet(pet: pet)
                case .diary(let entry): DiaryEditor(entry: entry)
                case .cabinet(let id): NavigationStack { CabinetDetailView(itemID: id) }.floofSheet()
                case .article(let id): LexiconSheet(start: .article(id))
                }
            }
        }
    }

    private func perform(_ action: TodayHint.Action) {
        switch action {
        case .routine(let kind, let petID):
            withAnimation(.snappy) { store.markRoutineDone(kind, for: petID) }
        case .weigh(let petID):
            if let pet = store.pet(petID) { sheet = .weigh(pet) }
        case .diary(let petID):
            sheet = .diary(DiaryEntry(petIDs: petID.map { [$0] } ?? store.pets.map(\.id)))
        case .cabinet(let id):
            sheet = .cabinet(id)
        case .article(let id):
            sheet = .article(id)
        }
    }
}
