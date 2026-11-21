import SwiftUI
import Charts

struct WeightChartView: View {
    let pet: Pet
    /// Optional: "Wiegen"-Knopf im Kopf der Karte.
    var onWeigh: (() -> Void)? = nil

    private var entries: [WeightEntry] { pet.sortedWeights }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Gewicht").font(Theme.title(20))
                Spacer()
                if let latest = pet.latestWeight {
                    Text("\(latest.grams.formatted()) g").font(Theme.number(.title2))
                    if let delta = trend {
                        Text(delta > 0 ? "+\(delta) g" : "\(delta) g")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(abs(delta) > 50 ? Theme.berry : Theme.inkSoft)
                    }
                }
                if let onWeigh {
                    Button("Wiegen", systemImage: "plus", action: onWeigh)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .controlSize(.small)
                        .padding(.leading, 4)
                }
            }

            if entries.isEmpty {
                ContentUnavailableView("Noch nicht gewogen", systemImage: "scalemass",
                                       description: Text("Einmal pro Woche auf die Küchenwaage – dann siehst du hier, wie es \(pet.name) geht."))
                    .frame(minHeight: 200)
            } else {
                Chart(entries) { entry in
                    // Fläche nur bis zum unteren Achsenrand, nicht bis 0 g.
                    AreaMark(x: .value("Datum", entry.date, unit: .day),
                             yStart: .value("Basis", yDomain.lowerBound),
                             yEnd: .value("Gramm", entry.grams))
                        .foregroundStyle(pet.tint.opacity(0.18).gradient)
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Datum", entry.date, unit: .day),
                             y: .value("Gramm", entry.grams))
                        .foregroundStyle(pet.tint)
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    PointMark(x: .value("Datum", entry.date, unit: .day),
                              y: .value("Gramm", entry.grams))
                        .foregroundStyle(pet.tint)
                        .annotation(position: .top) {
                            if entries.count <= 6 {
                                Text("\(entry.grams)").font(Theme.number(.caption2)).foregroundStyle(Theme.inkSoft)
                            }
                        }
                }
                .chartYScale(domain: yDomain)
                .chartXScale(domain: xDomain)
                .chartXAxis {
                    // Wenige Messungen: genau deren Tage beschriften (keine doppelten Daten).
                    AxisMarks(values: entries.count <= 4 ? .stride(by: .day, count: max(1, xStrideDays))
                                                         : .automatic(desiredCount: 3)) {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        AxisValueLabel()
                    }
                }
                .chartPlotStyle { $0.clipped() }
                .frame(minHeight: 220)
                .accessibilityLabel("Gewichtsverlauf von \(pet.name)")

                if entries.count == 1 {
                    Text("Ab der zweiten Wägung wird daraus eine Linie.")
                        .font(.caption).foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .card()
    }

    private var trend: Int? {
        guard entries.count >= 2 else { return nil }
        return entries[entries.count - 1].grams - entries[entries.count - 2].grams
    }

    /// Zeitachse: bei nur einer Messung ±3 Tage drumherum, sonst Spanne der Messungen.
    private var xDomain: ClosedRange<Date> {
        let cal = Calendar.current
        let first = cal.startOfDay(for: entries.first?.date ?? .now)
        let last = cal.startOfDay(for: entries.last?.date ?? .now)
        let start = cal.date(byAdding: .day, value: first == last ? -3 : -1, to: first) ?? first
        let end = cal.date(byAdding: .day, value: first == last ? 3 : 1, to: last) ?? last
        return start...end
    }

    /// Abstand der Datumsbeschriftungen, damit höchstens etwa drei erscheinen.
    private var xStrideDays: Int {
        let days = Calendar.current.dateComponents([.day], from: xDomain.lowerBound, to: xDomain.upperBound).day ?? 6
        return max(1, days / 3)
    }

    /// Enger Bereich um die Messwerte, damit Schwankungen sichtbar werden.
    private var yDomain: ClosedRange<Int> {
        let grams = entries.map(\.grams)
        let lo = (grams.min() ?? 0) - 150, hi = (grams.max() ?? 0) + 150
        return max(0, lo)...hi
    }
}
