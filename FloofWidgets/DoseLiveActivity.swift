import ActivityKit
import SwiftUI
import WidgetKit

/// Live-Aktivität: nächste Gabe mit einem Kreis, der sich bis zur Gabe füllt (ohne Uhrzeit
/// und ohne Countdown), und "Gegeben"-Knopf – auf dem Sperrbildschirm und in der Dynamic Island.
struct DoseLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DoseActivityAttributes.self) { context in
            LockScreenDoseView(state: context.state)
                .padding(16)
                .activityBackgroundTint(Color(red: 0.08, green: 0.06, blue: 0.05).opacity(0.85))
                .activitySystemActionForegroundColor(Color(red: 0.95, green: 0.91, blue: 0.86))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    DoseRing(due: context.state.due, symbol: context.state.symbol, size: 44).padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(context.state.title).font(.headline).lineLimit(1)
                        Text(context.state.detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    GiveButton(ids: context.state.doseIDs).padding(.top, 4)
                }
            } compactLeading: {
                WIcon(symbol: context.state.symbol, size: 20)
            } compactTrailing: {
                DoseRing(due: context.state.due, symbol: nil, size: 20)
            } minimal: {
                DoseRing(due: context.state.due, symbol: nil, size: 20)
            }
            .keylineTint(LiveColors.carrot)
        }
    }
}

enum LiveColors {
    static let cream = Color(red: 0.95, green: 0.91, blue: 0.86)
    static let soft = Color(red: 0.66, green: 0.60, blue: 0.53)
    static let carrot = Color(red: 0.88, green: 0.53, blue: 0.29)
}

private struct LockScreenDoseView: View {
    let state: DoseActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            DoseRing(due: state.due, symbol: state.symbol, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(state.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(LiveColors.cream).lineLimit(1)
                Text(state.detail)
                .font(.caption)
                .foregroundStyle(LiveColors.soft)
                .lineLimit(1)
            }
            Spacer(minLength: 6)
            GiveButton(ids: state.doseIDs)
                .fixedSize()
        }
    }
}

private struct GiveButton: View {
    let ids: [String]

    var body: some View {
        Button(intent: GiveDosesIntent(doseIDs: ids)) {
            Text("Gegeben")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .foregroundStyle(Color(red: 0.10, green: 0.08, blue: 0.06))
                .background(Capsule().fill(LiveColors.cream))
        }
        .buttonStyle(.plain)
    }
}

/// Kreis, der sich in den letzten drei Stunden bis zur Gabe füllt – ohne Zeitangabe.
/// iOS lässt ihn selbst weiterlaufen (auch ohne App). Ist die Gabe fällig, ist er voll.
private struct DoseRing: View {
    let due: Date
    let symbol: String?
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            if due > .now {
                ProgressView(timerInterval: due.addingTimeInterval(-3 * 3600)...due, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.circular)
                .tint(LiveColors.carrot)
            } else {
                Circle().stroke(LiveColors.carrot, lineWidth: max(2, size / 14))
            }
            if let symbol {
                WIcon(symbol: symbol, size: size * 0.52)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(due > .now ? "Gabe bald fällig" : "Gabe jetzt fällig")
    }
}
