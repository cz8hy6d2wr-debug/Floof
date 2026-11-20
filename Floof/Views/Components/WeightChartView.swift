import SwiftUI
import Charts

struct WeightChartView: View {
    let pet: Pet

    private var entries: [WeightEntry] { pet.sortedWeights }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Gewichtsverlauf", systemImage: "scalemass.fill").font(.headline)
                Spacer()
                if let latest = pet.latestWeight {
                    Text("\(latest.grams) g").font(.title2.bold().monospacedDigit())
                    if let delta = trend {
                        Text(delta > 0 ? "+\(delta) g" : "\(delta) g")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(abs(delta) > 50 ? Color.orange : Color.secondary)
                    }
                }
            }

            if entries.isEmpty {
                ContentUnavailableView("Noch keine Messung", systemImage: "scalemass",
                                       description: Text("Wiege \(pet.name) regelmäßig, um den Verlauf zu sehen."))
                    .frame(minHeight: 200)
            } else {
                Chart(entries) { entry in
                    AreaMark(x: .value("Datum", entry.date, unit: .day),
                             y: .value("Gramm", entry.grams))
                        .foregroundStyle(pet.tint.opacity(0.15).gradient)
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
                                Text("\(entry.grams)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                            }
                        }
                }
                .chartYScale(domain: yDomain)
                .chartYAxisLabel("g")
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) {
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .frame(minHeight: 220)
                .accessibilityLabel("Gewichtsverlauf von \(pet.name)")
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
