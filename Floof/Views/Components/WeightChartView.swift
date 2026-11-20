import SwiftUI
import Charts

struct WeightChartView: View {
    let pet: Pet

    private var entries: [WeightEntry] { pet.sortedWeights }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Gewicht").font(Theme.title(20))
                Spacer()
                if let latest = pet.latestWeight {
                    Text("\(latest.grams) g").font(Theme.number(.title2))
                    if let delta = trend {
                        Text(delta > 0 ? "+\(delta) g" : "\(delta) g")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(abs(delta) > 50 ? Theme.berry : Theme.inkSoft)
                    }
                }
            }

            if entries.isEmpty {
                ContentUnavailableView("Noch nicht gewogen", systemImage: "scalemass",
                                       description: Text("Einmal pro Woche auf die Küchenwaage – dann siehst du hier, wie es \(pet.name) geht."))
                    .frame(minHeight: 200)
            } else {
                Chart(entries) { entry in
                    // Fläche nur bis zum unteren Achsenrand (nicht bis 0 g), weich ausblendend.
                    AreaMark(x: .value("Datum", entry.date, unit: .day),
                             yStart: .value("Basis", yDomain.lowerBound),
                             yEnd: .value("Gramm", entry.grams))
                        .foregroundStyle(LinearGradient(colors: [pet.tint.opacity(0.22), pet.tint.opacity(0)],
                                                        startPoint: .top, endPoint: .bottom))
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
                .chartYAxisLabel("g")
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) {
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

    /// Enger Bereich um die Messwerte, damit Schwankungen sichtbar werden.
    private var yDomain: ClosedRange<Int> {
        let grams = entries.map(\.grams)
        let lo = (grams.min() ?? 0) - 150, hi = (grams.max() ?? 0) + 150
        return max(0, lo)...hi
    }
}
