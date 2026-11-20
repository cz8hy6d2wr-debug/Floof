import SwiftUI

enum CabinetStatusText {
    static func short(_ status: CabinetStatus) -> String {
        switch status {
        case .empty: "Leer"
        case .expired: "Abgelaufen"
        case .low(let days): days <= 0 ? "Heute leer" : "Noch \(days) Tag\(days == 1 ? "" : "e")"
        case .expiringSoon(let days): "Läuft in \(days) T. ab"
        case .ok: "Alles da"
        }
    }

    static func color(_ status: CabinetStatus) -> Color {
        switch status {
        case .empty, .expired: Theme.berry
        case .low, .expiringSoon: Theme.honey
        case .ok: Theme.leaf
        }
    }
}

/// Füllstand als liegende "Flasche" – leicht unregelmäßige Kanten wirken gezeichnet statt generiert.
struct StockGauge: View {
    let level: Double
    let color: Color
    var height: CGFloat = 14

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.sunken)
                Capsule()
                    .fill(color.gradient)
                    .frame(width: max(height, proxy.size.width * level))
                    .opacity(level > 0 ? 1 : 0)
                // Messstriche bei 25/50/75 %
                HStack(spacing: 0) {
                    ForEach(1..<4) { _ in
                        Spacer()
                        Rectangle().fill(Theme.paper.opacity(0.7)).frame(width: 1.5, height: height * 0.5)
                    }
                    Spacer()
                }
            }
        }
        .frame(height: height)
        .animation(.smooth, value: level)
        .accessibilityElement()
        .accessibilityLabel("Füllstand")
        .accessibilityValue(Text(level, format: .percent.precision(.fractionLength(0))))
    }
}

/// Karte in der Schrank-Übersicht.
struct CabinetItemCard: View {
    @Environment(PetStore.self) private var store
    let item: CabinetItem

    var body: some View {
        let status = store.status(of: item)
        let color = CabinetStatusText.color(status)
        let linked = store.linkedMedications(of: item)

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: item.form.symbol)
                    .font(.title3)
                    .foregroundStyle(Theme.carrot)
                    .frame(width: 42, height: 42)
                    .background(Theme.carrot.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name).font(Theme.title(18)).foregroundStyle(Theme.ink)
                    Text(linked.isEmpty ? item.form.label
                                        : linked.map { "\($0.med.title) · \($0.pet.name)" }.joined(separator: ", "))
                        .font(.caption).foregroundStyle(Theme.inkSoft).lineLimit(1)
                }
                Spacer()
                Text(CabinetStatusText.short(status))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(color.opacity(0.14), in: Capsule())
            }

            StockGauge(level: item.fillLevel, color: color)

            HStack {
                Text("\(item.formatted(item.stock)) von \(item.formatted(item.packageSize))")
                    .font(Theme.number(.subheadline))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if let days = store.daysLeft(of: item), let until = Calendar.current.date(byAdding: .day, value: days, to: .now) {
                    Text("reicht bis \(until.formatted(.dateTime.day().month(.abbreviated)))")
                        .font(.caption).foregroundStyle(Theme.inkSoft)
                } else {
                    Text("bei Bedarf").font(.caption).foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .card()
    }
}
