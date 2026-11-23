import SwiftUI
import WidgetKit

@main
struct FloofWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextDoseWidget()
        CheckWidget()
        TodayWidget()
        OverviewWidget()
        DoseLiveActivity()
    }
}

// MARK: - Zeitleiste

struct FloofEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?

    /// Nur der Stand von heute zählt – ein alter Stand würde falsche Gaben zeigen.
    var current: WidgetSnapshot? { snapshot.flatMap { $0.isCurrent ? $0 : nil } }
}

struct FloofProvider: TimelineProvider {
    func placeholder(in context: Context) -> FloofEntry { FloofEntry(date: .now, snapshot: .sample) }

    func getSnapshot(in context: Context, completion: @escaping (FloofEntry) -> Void) {
        completion(FloofEntry(date: .now, snapshot: context.isPreview ? (WidgetSnapshot.load() ?? .sample) : WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FloofEntry>) -> Void) {
        let snapshot = WidgetSnapshot.load()
        let now = Date.now
        // Neue Einträge zu jeder Gabe, damit "nächste Gabe" weiterrückt, und um Mitternacht.
        var dates = [now]
        dates += (snapshot?.open ?? []).map(\.due).filter { $0 > now }
        let midnight = Calendar.current.startOfDay(for: now.addingTimeInterval(86_400))
        dates.append(midnight)
        let entries = Array(Set(dates)).sorted().map { FloofEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .after(midnight.addingTimeInterval(60))))
    }
}

extension WidgetSnapshot {
    static let sample: WidgetSnapshot = {
        let cal = Calendar.current
        func at(_ h: Int) -> Date { cal.date(bySettingHour: h, minute: 0, second: 0, of: .now) ?? .now }
        return WidgetSnapshot(
            day: .now,
            doses: [
                .init(id: "1", title: "Gabapentin", petName: "Brownie", amount: "0,15 ml", time: "07:00", due: at(7), taken: true, symbol: "drop.fill"),
                .init(id: "2", title: "Gabapentin", petName: "Brownie", amount: "0,15 ml", time: "15:00", due: at(15), taken: false, symbol: "drop.fill"),
                .init(id: "3", title: "Panacur", petName: "Brownie", amount: "0,35 ml", time: "15:00", due: at(15), taken: false, symbol: "drop.fill"),
            ],
            checks: [.init(id: "a", petName: "Cinnamon", done: false, allNormal: false),
                     .init(id: "b", petName: "Brownie", done: false, allNormal: false)],
            weight: .init(petName: "Brownie", grams: 1820, date: .now.addingTimeInterval(-3 * 86_400)),
            cabinetAlert: .init(name: "Panacur", text: "Noch 6 Tage"),
            lastActivity: "Anna · 07:02 · Gabapentin für Brownie gegeben",
            carrots: 240)
    }()

    /// "Noch zwei Gaben für Brownie." – derselbe Ton wie in der App.
    var headline: String {
        let words = ["Keine", "eine", "zwei", "drei", "vier", "fünf", "sechs", "sieben", "acht"]
        if doses.isEmpty { return "Heute ein freier Tag." }
        if open.isEmpty { return "Alles gegeben." }
        let n = open.count
        let lead = n == 1 ? "Noch eine Gabe" : "Noch \(n < words.count ? words[n] : "\(n)") Gaben"
        let pets = Set(open.map(\.petName))
        return pets.count == 1 ? "\(lead) für \(pets.first!)." : "\(lead) für deine Tiere."
    }
}

// MARK: - Nächste Gabe (klein + Sperrbildschirm)

struct NextDoseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "floof.next", provider: FloofProvider()) { entry in
            NextDoseView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackground() }
        }
        .configurationDisplayName("Nächste Gabe")
        .description("Countdown bis zur nächsten Gabe.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct NextDoseView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FloofEntry

    var body: some View {
        if let s = entry.current {
            switch family {
            case .accessoryCircular: circular(s)
            case .accessoryRectangular: rectangular(s)
            case .accessoryInline: inline(s)
            default: small(s)
            }
        } else if family == .systemSmall {
            WOpenApp()
        } else {
            Image(systemName: "hare")
        }
    }

    private func small(_ s: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            WCaption(text: "Nächste Gabe", symbol: "drop.fill")
            Spacer(minLength: 6)
            if let next = s.nextOpen(after: entry.date) {
                HStack(spacing: 10) {
                    ZStack {
                        WRing(progress: s.progress, lineWidth: 5)
                        WIcon(symbol: next.symbol, size: 20)
                    }
                    .frame(width: 46, height: 46)
                    VStack(alignment: .leading, spacing: 0) {
                        if next.due > entry.date {
                            Text(timerInterval: entry.date...next.due, countsDown: true)
                                .font(WStyle.serif(24))
                                .monospacedDigit()
                                .foregroundStyle(WStyle.ink)
                            Text("um \(next.time)").font(.caption2).foregroundStyle(WStyle.soft)
                        } else {
                            Text("Fällig").font(WStyle.serif(22)).foregroundStyle(WStyle.berry)
                            Text("seit \(next.time)").font(.caption2).foregroundStyle(WStyle.soft)
                        }
                    }
                }
                Spacer(minLength: 6)
                Text(s.nextGroup(after: entry.date).map(\.title).joined(separator: " + "))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(WStyle.ink).lineLimit(1)
                Text("\(next.amount) · \(next.petName)")
                    .font(.caption2).foregroundStyle(WStyle.soft).lineLimit(1)
            } else {
                ZStack { WRing(progress: 1, lineWidth: 5); WCheck(done: true, size: 24) }
                    .frame(width: 46, height: 46)
                Spacer(minLength: 6)
                Text(s.doses.isEmpty ? "Heute frei" : "Alles gegeben")
                    .font(WStyle.serif(18, .semibold)).foregroundStyle(WStyle.ink)
                Text("\(s.carrots) Möhren").font(.caption2).foregroundStyle(WStyle.soft)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func circular(_ s: WidgetSnapshot) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            Gauge(value: s.progress) {
                Image(systemName: "pills")
            } currentValueLabel: {
                Text("\(s.givenCount)/\(s.doses.count)").font(.system(size: 13, weight: .semibold))
            }
            .gaugeStyle(.accessoryCircularCapacity)
        }
        .widgetAccentable()
    }

    private func rectangular(_ s: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            if let next = s.nextOpen(after: entry.date) {
                HStack(spacing: 4) {
                    Image(systemName: "pills.fill")
                    if next.due > entry.date {
                        Text("\(next.time) · in \(Text(next.due, style: .relative))")
                    } else {
                        Text("seit \(next.time) fällig")
                    }
                }
                .font(.caption2.weight(.semibold))
                .widgetAccentable()
                Text(s.nextGroup(after: entry.date).map(\.title).joined(separator: " + "))
                    .font(.headline).lineLimit(1)
                Text(next.petName).font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Floof").font(.caption2.weight(.semibold)).widgetAccentable()
                Text(s.doses.isEmpty ? "Heute keine Gaben" : "Alles gegeben").font(.headline)
                Text("\(s.givenCount) von \(s.doses.count)").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func inline(_ s: WidgetSnapshot) -> some View {
        if let next = s.nextOpen(after: entry.date) {
            Text("\(Image(systemName: "pills")) \(next.time) \(next.title)")
        } else {
            Text("\(Image(systemName: "checkmark")) Alles gegeben")
        }
    }
}

// MARK: - Kurz-Check (klein)

struct CheckWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "floof.check", provider: FloofProvider()) { entry in
            CheckView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackground() }
        }
        .configurationDisplayName("Kurz-Check")
        .description("Fressen, Köttel, Verhalten – mit einem Tipp „Alles normal“.")
        .supportedFamilies([.systemSmall])
    }
}

struct CheckView: View {
    let entry: FloofEntry

    var body: some View {
        if let s = entry.current {
            let open = s.checks.filter { !$0.done }
            VStack(alignment: .leading, spacing: 0) {
                WCaption(text: "Kurz-Check", symbol: "hare.fill")
                Spacer(minLength: 4)
                if open.isEmpty {
                    WCheck(done: true, size: 30)
                    Spacer(minLength: 6)
                    let issues = s.checks.filter { !$0.allNormal }
                    Text(issues.isEmpty ? "Alles normal" : "Eingetragen")
                        .font(WStyle.serif(18, .semibold)).foregroundStyle(WStyle.ink)
                    Text(issues.isEmpty ? s.checks.map(\.petName).joined(separator: " · ")
                                        : "Auffällig: \(issues.map(\.petName).joined(separator: ", "))")
                        .font(.caption2).foregroundStyle(issues.isEmpty ? WStyle.soft : WStyle.berry).lineLimit(2)
                } else {
                    Text("Noch offen").font(WStyle.serif(18, .semibold)).foregroundStyle(WStyle.ink)
                    Text(open.map(\.petName).joined(separator: " · "))
                        .font(.caption2).foregroundStyle(WStyle.soft).lineLimit(1)
                    Spacer(minLength: 8)
                    Button(intent: AllNormalIntent(petID: "")) {
                        Text("Alles normal")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .foregroundStyle(Color(red: 0.10, green: 0.08, blue: 0.06))
                            .background(Capsule().fill(Color(red: 0.95, green: 0.91, blue: 0.86)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            WOpenApp()
        }
    }
}

// MARK: - Heute (mittel)

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "floof.today", provider: FloofProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackground() }
        }
        .configurationDisplayName("Heute")
        .description("Alle Gaben des Tages – direkt abhaken.")
        .supportedFamilies([.systemMedium])
    }
}

struct TodayWidgetView: View {
    let entry: FloofEntry

    var body: some View {
        if let s = entry.current {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    WCaption(text: "Heute · \(s.givenCount) von \(s.doses.count)", symbol: "calendar")
                    Spacer()
                    HStack(spacing: 3) {
                        Text("\(s.carrots)").font(WStyle.serif(13, .semibold)).foregroundStyle(WStyle.carrot)
                        WIcon(symbol: "carrot.fill", size: 13)
                    }
                }
                if s.doses.isEmpty {
                    Spacer()
                    Text("Heute stehen keine Medikamente an.").font(WStyle.serif(17)).foregroundStyle(WStyle.ink)
                    Spacer()
                } else {
                    DoseRows(doses: visible(s), compact: true)
                    Spacer(minLength: 0)
                }
            }
        } else {
            WOpenApp()
        }
    }

    /// Höchstens drei Zeilen: zuerst die offenen, dann die zuletzt gegebenen.
    private func visible(_ s: WidgetSnapshot) -> [WidgetSnapshot.Dose] {
        if s.doses.count <= 3 { return s.doses }
        let open = s.open.prefix(3)
        let rest = s.doses.filter(\.taken).suffix(3 - open.count)
        return (Array(rest) + Array(open)).sorted { $0.due < $1.due }
    }
}

/// Gaben-Zeilen mit Abhaken-Knopf.
struct DoseRows: View {
    let doses: [WidgetSnapshot.Dose]
    var compact = false

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(doses.enumerated()), id: \.element.id) { index, dose in
                Button(intent: ToggleDoseIntent(doseID: dose.id)) {
                    HStack(spacing: 9) {
                        WIconTile(symbol: dose.symbol, size: compact ? 16 : 18)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(dose.title)
                                .font(.system(size: 13.5, weight: .medium))
                                .strikethrough(dose.taken)
                                .foregroundStyle(dose.taken ? WStyle.soft : WStyle.ink)
                                .lineLimit(1)
                            Text("\(dose.amount) · \(dose.petName)")
                                .font(.system(size: 11)).foregroundStyle(WStyle.soft).lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        Text(dose.time).font(.system(size: 12).monospacedDigit())
                            .foregroundStyle(!dose.taken && dose.due < .now ? WStyle.berry : WStyle.soft)
                        WCheck(done: dose.taken, size: 21)
                    }
                    .padding(.vertical, compact ? 4 : 5)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                if index < doses.count - 1 {
                    Rectangle().fill(WStyle.hair).frame(height: 0.5).padding(.leading, 34)
                }
            }
        }
    }
}

// MARK: - Tagesüberblick (groß)

struct OverviewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "floof.overview", provider: FloofProvider()) { entry in
            OverviewView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackground() }
        }
        .configurationDisplayName("Tagesüberblick")
        .description("Gaben, Gewicht, Schrank und der letzte Eintrag.")
        .supportedFamilies([.systemLarge])
    }
}

struct OverviewView: View {
    let entry: FloofEntry

    var body: some View {
        if let s = entry.current {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        WCaption(text: entry.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        Text(s.headline)
                            .font(WStyle.serif(22))
                            .foregroundStyle(WStyle.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                    Spacer(minLength: 8)
                    WRing(progress: s.progress, lineWidth: 5).frame(width: 44, height: 44)
                }
                let rows = s.open.isEmpty ? Array(s.doses.suffix(2)) : Array(s.open.prefix(3))
                if !rows.isEmpty { DoseRows(doses: rows) }
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    if let w = s.weight {
                        tile(caption: "Gewicht", symbol: "scalemass",
                             value: (Double(w.grams) / 1000).formatted(.number.precision(.fractionLength(2))) + " kg",
                             detail: "\(w.petName) · \(w.date.formatted(.relative(presentation: .named)))", warn: false)
                    }
                    if let a = s.cabinetAlert {
                        tile(caption: "Schrank", symbol: "cross.case", value: a.name, detail: a.text, warn: true)
                    } else {
                        let open = s.checks.filter { !$0.done }
                        tile(caption: "Kurz-Check", symbol: "hare.fill",
                             value: open.isEmpty ? "Erledigt" : "Offen",
                             detail: open.isEmpty ? "alle Tiere" : open.map(\.petName).joined(separator: " · "), warn: false)
                    }
                }
                if let last = s.lastActivity {
                    HStack(spacing: 5) {
                        WIcon(symbol: "clock", size: 12)
                        Text(last).font(.system(size: 11)).foregroundStyle(WStyle.soft).lineLimit(1)
                    }
                }
            }
        } else {
            WOpenApp()
        }
    }

    private func tile(caption: String, symbol: String, value: String, detail: String, warn: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            WCaption(text: caption, symbol: symbol, color: warn ? WStyle.carrot : WStyle.soft)
            Text(value).font(WStyle.serif(17, .semibold)).foregroundStyle(WStyle.ink).lineLimit(1).minimumScaleFactor(0.8)
            Text(detail).font(.system(size: 11)).foregroundStyle(WStyle.soft).lineLimit(1)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(warn ? WStyle.carrot.opacity(0.12) : WStyle.ink.opacity(0.05)))
    }
}
