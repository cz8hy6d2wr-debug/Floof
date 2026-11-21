import SwiftUI

/// Tiertagebuch: eigene Einträge + automatisch erfasste Ereignisse auf einer Zeitleiste.
/// Aufgeklappt: zwei gleich breite Spalten (Zeitleiste | Stimmungskalender + Themen),
/// der Zwischenraum liegt auf dem Falz.
struct DiaryView: View {
    @Environment(PetStore.self) private var store
    @Environment(\.devicePosture) private var posture
    @State private var petFilter: Pet.ID?
    @State private var tagFilter: DiaryTag?
    @State private var editing: DiaryEntry?
    @State private var screenWidth: CGFloat = 0

    var body: some View {
        NavigationStack {
            Group {
                if posture == .unfolded {
                    FoldColumns {
                        timeline
                    } trailing: {
                        ScrollView {
                            VStack(spacing: 16) {
                                MoodCalendar(petID: petFilter)
                                TagSummary(petID: petFilter)
                            }
                            .padding(.vertical, 12)
                        }
                        .scrollIndicators(.hidden)
                    }
                } else {
                    timeline
                        .padding(.horizontal, 16)
                        .foldedReadableWidth()
                }
            }
            .ambientBackground()
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { screenWidth = $0 }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Thema", selection: $tagFilter) {
                            Text("Alle Themen").tag(DiaryTag?.none)
                            ForEach(DiaryTag.allCases) { tag in
                                Label(tag.rawValue, systemImage: tag.symbol).tag(Optional(tag))
                            }
                        }
                    } label: {
                        Label("Filtern", systemImage: tagFilter == nil ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
                    }
                }
            }
            .safeAreaInset(edge: .bottom, alignment: .trailing) {
                // Schwebender gläserner Stift – rechts unten im Daumenbereich.
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
                // Aufgeklappt in die linke Hälfte, damit der Knopf nicht auf dem Falz sitzt
                // und neben der Zeitleiste bleibt, zu der er gehört.
                .padding(.trailing, posture == .unfolded ? rightHalfInset : 20)
                .padding(.bottom, 8)
                .accessibilityLabel("Neuer Eintrag")
            }
            .sheet(item: $editing) { entry in
                DiaryEditor(entry: entry)
            }
        }
    }

    /// Abstand vom rechten Rand bis knapp links vom Falz (aufgeklappt).
    private var rightHalfInset: CGFloat {
        screenWidth / 2 + FoldLayout.hingeGutter / 2 + 12
    }

    private var timeline: some View {
        let items = store.timeline(petID: petFilter, tag: tagFilter)
        let months = Dictionary(grouping: items) { item in
            Calendar.current.dateInterval(of: .month, for: item.date)?.start ?? item.date
        }
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 14, pinnedViews: .sectionHeaders) {
                VStack(alignment: .leading, spacing: 10) {
                    HandTitle(text: "Tagebuch", size: 32)
                    if let tagFilter {
                        Label("Nur \(tagFilter.rawValue)", systemImage: tagFilter.symbol)
                            .font(.caption.weight(.semibold)).foregroundStyle(Theme.carrot)
                            .padding(.top, 4)
                    }
                }
                .padding(.top, 4)

                if store.pets.count > 1 {
                    PetFilterBar(selection: $petFilter)
                }

                if items.isEmpty {
                    ContentUnavailableView("Noch leer", systemImage: "book.closed",
                                           description: Text("Was war heute los? Ein Satz reicht – in einem Jahr freust du dich darüber."))
                        .padding(.top, 40)
                }

                ForEach(months.keys.sorted(by: >), id: \.self) { month in
                    Section {
                        ForEach(months[month] ?? []) { item in
                            TimelineRow(item: item) {
                                if case .entry(let entry) = item, !entry.isAutomatic { editing = entry }
                            }
                        }
                    } header: {
                        Text(month, format: .dateTime.month(.wide).year())
                            .font(.footnote.weight(.bold))
                            .textCase(.uppercase)
                            .kerning(1.2)
                            .foregroundStyle(Theme.inkSoft)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .glassEffect(.regular, in: .capsule)
                            .padding(.vertical, 4)
                    }
                }
            }
            .padding(.bottom, 90)
        }
        .scrollIndicators(.hidden)
    }
}

/// Eine Zeile der Zeitleiste – Tagebucheintrag groß, automatische Ereignisse klein.
struct TimelineRow: View {
    @Environment(PetStore.self) private var store
    let item: TimelineItem
    var onTap: () -> Void = {}

    var body: some View {
        switch item {
        case .entry(let entry):
            Button(action: onTap) { DiaryEntryCard(entry: entry) }
                .buttonStyle(.plain)
        case .weight(let pet, let weight):
            eventRow(pet: pet, symbol: "scalemass", date: weight.date,
                     text: "\(pet.name) gewogen: **\(weight.grams) g**")
        case .care(let pet, let care):
            eventRow(pet: pet, symbol: care.careKind.symbol, date: care.date,
                     text: "\(care.careKind.rawValue): **\(care.title)** · \(pet.name)")
        case .check(let pet, let check):
            eventRow(pet: pet, symbol: check.need == .red ? "exclamationmark.triangle.fill" : "stethoscope",
                     date: DoseKey.date(check.id) ?? .now,
                     text: "\(pet.name): **\(check.findings ?? "alles unauffällig")**\(check.note.map { " – \($0)" } ?? "")")
        }
    }

    private func eventRow(pet: Pet, symbol: String, date: Date, text: LocalizedStringKey) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(pet.tint)
                .frame(width: 28, height: 28)
                .background(pet.tint.opacity(0.12), in: Circle())
            Text(text).font(.subheadline).foregroundStyle(Theme.ink)
            Spacer()
            Text(date, format: .dateTime.day().month(.abbreviated))
                .font(.caption).foregroundStyle(Theme.inkSoft)
        }
        .padding(.horizontal, 6)
    }
}

struct DiaryEntryCard: View {
    @Environment(PetStore.self) private var store
    let entry: DiaryEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Datum wie in ein Notizbuch geschrieben
            VStack(spacing: 0) {
                Text(entry.date, format: .dateTime.day())
                    .font(Theme.title(26))
                Text(entry.date, format: .dateTime.weekday(.abbreviated))
                    .font(.caption2.weight(.bold)).textCase(.uppercase)
                    .foregroundStyle(Theme.inkSoft)
            }
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.title.isEmpty ? entry.mood.label : entry.title)
                        .font(Theme.title(18))
                    Spacer(minLength: 6)
                    Image(systemName: entry.mood.symbol)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(entry.mood.tint)
                        .accessibilityLabel(entry.mood.label)
                }
                if !entry.text.isEmpty {
                    Text(entry.text)
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink.opacity(0.85))
                        .lineLimit(5)
                }
                if let image = store.photo(named: entry.photoFilename) {
                    Image(uiImage: image)
                        .resizable().scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.vertical, 4)
                }
                HStack(spacing: 6) {
                    ForEach(entry.petIDs.compactMap(store.pet)) { pet in
                        PetAvatar(pet: pet, size: 22)
                    }
                    ForEach(entry.tags) { tag in
                        Label(tag.rawValue, systemImage: tag.symbol)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.inkSoft)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Theme.sunken, in: Capsule())
                    }
                }
            }
        }
        .card()
    }
}
