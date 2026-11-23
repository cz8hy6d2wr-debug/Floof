import SwiftUI

/// Verlauf: alles, was passiert ist – eine Liste, nach Tagen sortiert.
/// Protokoll-Einträge ("Anna · 15:02 · Gabapentin gegeben") und Tagebuch-Einträge zusammen.
/// Einträge vom anderen iPhone, die neu sind, tragen einen Punkt.
struct HistoryView: View {
    @Environment(PetStore.self) private var store
    @Environment(\.devicePosture) private var posture
    @State private var filter: Filter = .all
    @State private var petFilter: Pet.ID?
    @State private var editing: DiaryEntry?
    /// Beim Öffnen gemerkt, damit die "Neu"-Punkte sichtbar bleiben, solange man schaut.
    @State private var seenAtOpen: Date = .distantPast
    @Namespace private var glass

    enum Filter: String, CaseIterable, Identifiable {
        case all = "Alles", medicine = "Medikamente", health = "Gesundheit", diary = "Tagebuch"
        var id: Self { self }
    }

    private enum Item: Identifiable {
        case activity(ActivityEntry)
        case entry(DiaryEntry)

        var id: String {
            switch self {
            case .activity(let a): "a-\(a.id)"
            case .entry(let e): "e-\(e.id)"
            }
        }
        var date: Date {
            switch self {
            case .activity(let a): a.date
            case .entry(let e): e.date
            }
        }
    }

    private var items: [Item] {
        var result: [Item] = []
        if filter != .diary {
            result += store.data.activity
                .filter { $0.kind != .diary }                       // Tagebuch steht als eigene Karte da
                .filter { petFilter == nil || $0.petID == nil || $0.petID == petFilter }
                .filter { entry in
                    switch filter {
                    case .medicine: entry.kind.group == .medicine
                    case .health: entry.kind.group == .health
                    default: true
                    }
                }
                .map { .activity($0) }
        }
        if filter == .all || filter == .diary {
            result += store.diary
                .filter { !$0.isAutomatic }
                .filter { petFilter == nil || $0.petIDs.contains(petFilter!) }
                .map { .entry($0) }
        }
        return result.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            Group {
                if posture == .unfolded {
                    FoldColumns {
                        list
                    } trailing: {
                        ScrollView {
                            VStack(spacing: 16) {
                                MoodCalendar(petID: petFilter)
                            }
                            .padding(.vertical, 12)
                        }
                        .scrollIndicators(.hidden)
                    }
                } else {
                    list
                        .padding(.horizontal, 16)
                        .foldedReadableWidth()
                }
            }
            .ambientBackground()
            .navigationTitle("Verlauf")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, alignment: .trailing) {
                Button {
                    editing = DiaryEntry(petIDs: petFilter.map { [$0] } ?? store.pets.map(\.id))
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.title2.weight(.semibold))
                        .frame(width: 58, height: 58)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .tint(Theme.carrot)
                .padding(.trailing, 20)
                .padding(.bottom, 8)
                .accessibilityLabel("Tagebuch-Eintrag schreiben")
            }
            .sheet(item: $editing) { DiaryEditor(entry: $0) }
            .onAppear {
                seenAtOpen = store.activitySeen
                store.markActivitySeen()
            }
        }
    }

    private var list: some View {
        let grouped = Dictionary(grouping: items) { Calendar.current.startOfDay(for: $0.date) }
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                filterBar
                    .padding(.top, 8)
                if store.pets.count > 1 {
                    PetFilterBar(selection: $petFilter)
                }

                if items.isEmpty {
                    ContentUnavailableView("Noch nichts passiert", systemImage: "clock",
                                           description: Text("Sobald jemand eine Gabe abhakt, wiegt oder ins Tagebuch schreibt, steht es hier – mit Name und Uhrzeit."))
                        .padding(.top, 40)
                }

                ForEach(grouped.keys.sorted(by: >), id: \.self) { day in
                    Section {
                        dayBlock(grouped[day] ?? [])
                    } header: {
                        Text(dayTitle(day))
                            .sectionLabel()
                            .padding(.horizontal, 4)
                            .padding(.top, 12)
                    }
                }
            }
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
    }

    /// Ein Tag: Protokoll-Zeilen gebündelt in einer Glasfläche, Tagebuch-Einträge als eigene Karten.
    @ViewBuilder
    private func dayBlock(_ dayItems: [Item]) -> some View {
        let activities: [ActivityEntry] = dayItems.compactMap { item in
            if case .activity(let a) = item { return a }
            return nil
        }
        let entries: [DiaryEntry] = dayItems.compactMap { item in
            if case .entry(let e) = item { return e }
            return nil
        }

        if !activities.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(activities.enumerated()), id: \.element.id) { index, entry in
                    ActivityRow(entry: entry, isNew: entry.date > seenAtOpen && !entry.author.isEmpty
                                && entry.author != store.myName)
                    if index < activities.count - 1 { Divider().padding(.leading, 52) }
                }
            }
            .glassPanel()
        }
        ForEach(entries) { entry in
            Button { editing = entry } label: { DiaryEntryCard(entry: entry) }
                .buttonStyle(.plain)
        }
    }

    private var filterBar: some View {
        GlassEffectContainer(spacing: 8) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(Filter.allCases) { f in
                        let selected = filter == f
                        Button(f.rawValue) { withAnimation(.snappy) { filter = f } }
                            .font(.subheadline.weight(selected ? .semibold : .regular))
                            .foregroundStyle(selected ? Theme.ink : Theme.inkSoft)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .glassEffect(selected ? .regular.tint(Theme.carrot.opacity(0.25)).interactive()
                                                  : .regular.interactive(), in: .capsule)
                            .glassEffectID(f.rawValue, in: glass)
                            .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func dayTitle(_ day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Heute" }
        if cal.isDateInYesterday(day) { return "Gestern" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}

/// Eine Zeile im Protokoll: Symbol · Wer · Was · Uhrzeit.
struct ActivityRow: View {
    @Environment(PetStore.self) private var store
    let entry: ActivityEntry
    var isNew = false

    var body: some View {
        HStack(spacing: 12) {
            FloofIcon(symbol: entry.kind.symbol, size: 20, fallbackTint: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.displayAuthor(entry))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.inkSoft)
                Text(entry.text)
                    .font(.subheadline)
                    .foregroundStyle(entry.kind == .doseUndo ? Theme.inkSoft : Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text(entry.date, format: .dateTime.hour().minute())
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.inkSoft)
                if isNew {
                    Circle().fill(Theme.carrot).frame(width: 8, height: 8)
                        .accessibilityLabel("Neu")
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .accessibilityElement(children: .combine)
    }

    private var color: Color {
        switch entry.kind {
        case .dose: Theme.leaf
        case .doseUndo: Theme.inkSoft
        case .check: entry.text.contains("alles normal") ? Theme.leaf : Theme.honey
        case .weight, .care, .pet: Theme.carrot
        case .cabinet: Theme.honey
        case .diary: Theme.carrot
        }
    }
}

/// Die letzten Einträge aus dem Verlauf (z. B. rechts auf dem Innendisplay).
struct RecentActivityCard: View {
    @Environment(PetStore.self) private var store
    var petID: Pet.ID?
    var limit = 6

    var body: some View {
        let entries = store.data.activity
            .filter { petID == nil || $0.petID == nil || $0.petID == petID }
            .prefix(limit)
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Zuletzt").sectionLabel().padding(.horizontal, 14).padding(.top, 12)
                ForEach(Array(entries)) { entry in
                    ActivityRow(entry: entry)
                }
            }
            .padding(.bottom, 4)
            .glassPanel()
        }
    }
}
