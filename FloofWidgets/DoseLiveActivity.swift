import ActivityKit
import SwiftUI
import WidgetKit

/// Live-Aktivität: nächste Gabe mit Countdown und "Gegeben"-Knopf
/// auf dem Sperrbildschirm und in der Dynamic Island.
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
                    WIcon(symbol: context.state.symbol, size: 34).padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(context.state.title).font(.headline).lineLimit(1)
                        Text(context.state.detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context.state).font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundStyle(LiveColors.carrot)
                        .frame(maxWidth: 80)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    GiveButton(ids: context.state.doseIDs).padding(.top, 4)
                }
            } compactLeading: {
                WIcon(symbol: context.state.symbol, size: 20)
            } compactTrailing: {
                countdown(context.state).font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(LiveColors.carrot)
                    .frame(maxWidth: 52)
            } minimal: {
                WIcon(symbol: context.state.symbol, size: 18)
            }
            .keylineTint(LiveColors.carrot)
        }
    }

    @ViewBuilder
    private func countdown(_ state: DoseActivityAttributes.ContentState) -> some View {
        if state.due > .now {
            Text(timerInterval: Date.now...state.due, countsDown: true).multilineTextAlignment(.trailing)
        } else {
            Text("fällig")
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
            WIcon(symbol: state.symbol, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(state.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(LiveColors.cream).lineLimit(1)
                Group {
                    if state.due > .now {
                        Text("\(state.detail) · in \(Text(timerInterval: Date.now...state.due, countsDown: true))")
                    } else {
                        Text("\(state.detail) · jetzt fällig")
                    }
                }
                .font(.caption.monospacedDigit())
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
