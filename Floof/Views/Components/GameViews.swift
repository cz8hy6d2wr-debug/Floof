import SwiftUI

// MARK: - Serie + Möhren

/// Kompakte Leiste: Möhren-Konto, aktuelle Serie und die letzten 7 Tage als Punkte.
struct StreakStrip: View {
    @Environment(PetStore.self) private var store

    var body: some View {
        // Breit: alles in einer Zeile. Schmal (halbe Spalte aufgeklappt): Wochenpunkte darunter.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                stats
                Spacer(minLength: 0)
                WeekDots()
            }
            VStack(alignment: .leading, spacing: 10) {
                stats
                WeekDots()
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var stats: some View {
        HStack(spacing: 10) {
            stat(value: store.game.carrots, label: "Möhren", symbol: "carrot.fill", tint: Theme.carrot)
            Rectangle().fill(Theme.hairline).frame(width: 1, height: 34)
            stat(value: store.streak, label: store.streak == 1 ? "Tag am Stück" : "Tage am Stück",
                 symbol: "flame.fill", tint: Theme.honey)
        }
    }

    private func stat(value: Int, label: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.title3).foregroundStyle(tint)
                .symbolEffect(.bounce, value: value)
            VStack(alignment: .leading, spacing: 0) {
                Text(value, format: .number).font(Theme.number(.title3)).foregroundStyle(Theme.ink)
                    .contentTransition(.numericText(value: Double(value)))
                Text(label).font(.caption2).foregroundStyle(Theme.inkSoft)
            }
            .lineLimit(1)
            .fixedSize()
        }
        .accessibilityElement(children: .combine)
    }
}

/// Die letzten sieben Tage: gefüllt = alles gegeben. Heute ist umrandet.
private struct WeekDots: View {
    @Environment(PetStore.self) private var store

    var body: some View {
        let cal = Calendar.current
        let days = (0..<7).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: .now) }
        HStack(spacing: 3) {
            ForEach(days, id: \.self) { day in
                let done = store.game.perfectDays.contains(DoseKey.day(day))
                VStack(spacing: 3) {
                    Circle()
                        .fill(done ? Theme.leaf : Theme.sunken)
                        .frame(width: 9, height: 9)
                        .overlay {
                            if cal.isDateInToday(day) {
                                Circle().stroke(Theme.carrot, lineWidth: 1.5).frame(width: 14, height: 14)
                            }
                        }
                        .frame(width: 14, height: 14)
                    Text(day, format: .dateTime.weekday(.narrow))
                        .font(.system(size: 9, weight: .semibold)).foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Abzeichen

struct BadgeShelf: View {
    @Environment(PetStore.self) private var store
    var columns = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Abzeichen").font(Theme.title(20)).foregroundStyle(Theme.ink)
                Spacer()
                Text("\(store.unlockedBadges.count) von \(Badge.all.count)")
                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSoft)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns), spacing: 14) {
                ForEach(Array(Badge.all.enumerated()), id: \.element.id) { index, badge in
                    BadgeTile(badge: badge, earned: store.unlockedBadges.contains(badge.id),
                              // kleine, feste Schieflage – wie aufgeklebte Sticker
                              tilt: [-4, 3, -2, 5, -3, 2][index % 6])
                }
            }
        }
        .card()
    }
}

private struct BadgeTile: View {
    let badge: Badge
    let earned: Bool
    let tilt: Double

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: earned ? badge.symbol : "lock.fill")
                .font(.title2)
                .foregroundStyle(earned ? Theme.carrot : Theme.inkSoft.opacity(0.5))
                .frame(width: 54, height: 54)
                .background(earned ? Theme.carrot.opacity(0.14) : Theme.sunken, in: Circle())
                .overlay(Circle().strokeBorder(earned ? Theme.carrot.opacity(0.5) : .clear,
                                               style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])))
                .rotationEffect(.degrees(earned ? tilt : 0))
            Text(badge.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(earned ? Theme.ink : Theme.inkSoft)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(badge.title)
        .accessibilityValue(earned ? "Freigeschaltet" : "Gesperrt – \(badge.detail)")
    }
}

// MARK: - Feier

/// Kurze Einblendung mit fallenden Möhren. Verschwindet von selbst, Tippen schließt sofort.
struct CelebrationOverlay: View {
    @Environment(PetStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let celebration: Celebration
    @State private var dropped = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
                .onTapGesture { dismiss() }

            if !reduceMotion {
                GeometryReader { proxy in
                    ForEach(0..<18, id: \.self) { i in
                        Image(systemName: i.isMultiple(of: 3) ? "leaf.fill" : "carrot.fill")
                            .font(.system(size: CGFloat(16 + (i * 7) % 14)))
                            .foregroundStyle(i.isMultiple(of: 3) ? Theme.leaf : Theme.carrot)
                            .rotationEffect(.degrees(dropped ? Double(i * 47 % 360) : 0))
                            .position(x: proxy.size.width * CGFloat((i * 37) % 100) / 100,
                                      y: dropped ? proxy.size.height + 40 : -40 - CGFloat(i * 23 % 120))
                            .animation(.easeIn(duration: 1.6 + Double(i % 5) * 0.15).delay(Double(i % 6) * 0.05),
                                       value: dropped)
                    }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            VStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 44)).foregroundStyle(Theme.carrot)
                    .symbolEffect(.bounce, value: dropped)
                Text(title).font(Theme.title(24)).foregroundStyle(Theme.ink).multilineTextAlignment(.center)
                Text(message).font(.subheadline).foregroundStyle(Theme.inkSoft).multilineTextAlignment(.center)
            }
            .padding(28)
            .frame(maxWidth: 320)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .rotationEffect(.degrees(-1.5))
            .padding(24)
            .onTapGesture { dismiss() }
        }
        .sensoryFeedback(.success, trigger: dropped)
        .task {
            dropped = true
            try? await Task.sleep(for: .seconds(3))
            dismiss()
        }
    }

    private func dismiss() {
        withAnimation(.smooth) { if store.celebration == celebration { store.celebration = nil } }
    }

    private var symbol: String {
        switch celebration.reason {
        case .perfectDay: "checkmark.seal.fill"
        case .badge(let badge): badge.symbol
        }
    }

    private var title: String {
        switch celebration.reason {
        case .perfectDay(let streak) where streak > 1: "\(streak) Tage am Stück!"
        case .perfectDay: "Alles gegeben für heute"
        case .badge(let badge): "Neues Abzeichen: \(badge.title)"
        }
    }

    private var message: String {
        switch celebration.reason {
        case .perfectDay:
            store.pets.count == 1
                ? "+20 Möhren. \(store.pets[0].name) kann sich auf dich verlassen."
                : "+20 Möhren. Deine \(store.pets.count) können sich auf dich verlassen."
        case .badge(let badge): badge.detail
        }
    }
}

extension View {
    /// Hängt die Feier-Einblendung an eine Ansicht.
    func celebrations(_ store: PetStore) -> some View {
        overlay {
            if let celebration = store.celebration {
                CelebrationOverlay(celebration: celebration)
                    .transition(.opacity)
                    .id(celebration.id)
            }
        }
        .animation(.smooth, value: store.celebration)
    }
}
