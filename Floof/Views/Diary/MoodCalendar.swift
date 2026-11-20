import SwiftUI

/// Monatsübersicht: jeder Tag als Punkt, Farbe = Stimmung laut Tagebuch.
struct MoodCalendar: View {
    @Environment(PetStore.self) private var store
    let petID: Pet.ID?
    @State private var month = Date.now

    private let cal = Calendar.current

    var body: some View {
        let moods = store.moodByDay(in: month, petID: petID)
        let days = cal.range(of: .day, in: .month, for: month) ?? 1..<31
        let firstWeekday = cal.component(.weekday, from: cal.dateInterval(of: .month, for: month)?.start ?? month)
        let leading = (firstWeekday - cal.firstWeekday + 7) % 7

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(month, format: .dateTime.month(.wide).year()).font(Theme.title(18))
                Spacer()
                Button("Vorheriger Monat", systemImage: "chevron.left") { shift(-1) }
                Button("Nächster Monat", systemImage: "chevron.right") { shift(1) }
                    .disabled(cal.isDate(month, equalTo: .now, toGranularity: .month))
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .controlSize(.small)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(cal.veryShortWeekdaySymbols.indices, id: \.self) { i in
                    Text(cal.veryShortWeekdaySymbols[(i + cal.firstWeekday - 1) % 7])
                        .font(.caption2.weight(.bold)).foregroundStyle(Theme.inkSoft)
                }
                ForEach(0..<leading, id: \.self) { _ in Color.clear.frame(height: 30) }
                ForEach(Array(days), id: \.self) { day in
                    let score = moods[day]
                    ZStack {
                        Circle()
                            .fill(score.map(color(for:)) ?? Theme.sunken.opacity(0.6))
                        Text("\(day)")
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(score == nil ? Theme.inkSoft : .white)
                    }
                    .frame(height: 30)
                }
            }

            HStack(spacing: 10) {
                ForEach(DiaryEntry.Mood.allCases.reversed()) { mood in
                    Circle().fill(color(for: Double(mood.score))).frame(width: 8, height: 8)
                }
                Text("von krank bis super").font(.caption2).foregroundStyle(Theme.inkSoft)
            }
        }
        .card()
    }

    private func shift(_ months: Int) {
        withAnimation(.smooth) { month = cal.date(byAdding: .month, value: months, to: month) ?? month }
    }

    /// 0 = krank (Beere) … 4 = super (Blatt), dazwischen Honig.
    private func color(for score: Double) -> Color {
        switch score {
        case ..<1: Theme.berry
        case ..<2: Theme.berry.opacity(0.7)
        case ..<3: Theme.honey
        case ..<3.5: Theme.leaf.opacity(0.7)
        default: Theme.leaf
        }
    }
}

/// Wie oft welches Thema vorkam – kleine Statistik für die Seitenspalte.
struct TagSummary: View {
    @Environment(PetStore.self) private var store
    let petID: Pet.ID?

    var body: some View {
        let entries = store.diary.filter { petID == nil || $0.petIDs.contains(petID!) }
        let counts = DiaryTag.allCases
            .map { tag in (tag, entries.filter { $0.tags.contains(tag) }.count) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
        let maxCount = counts.first?.1 ?? 1

        VStack(alignment: .leading, spacing: 10) {
            Text("Worüber du schreibst").font(Theme.title(18))
            if counts.isEmpty {
                Text("Vergib Themen an deine Einträge, dann siehst du hier, was euch beschäftigt.")
                    .font(.caption).foregroundStyle(Theme.inkSoft)
            }
            ForEach(counts, id: \.0) { row in
                HStack {
                    Label(row.0.rawValue, systemImage: row.0.symbol).font(.subheadline)
                        .frame(width: 130, alignment: .leading)
                    Capsule().fill(Theme.carrot.opacity(0.7))
                        .frame(width: max(6, 110 * CGFloat(row.1) / CGFloat(maxCount)), height: 8)
                    Text("\(row.1)").font(Theme.number(.caption)).foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .card()
    }
}
