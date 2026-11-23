import SwiftUI
import UIKit

/// Kleine Überraschungen, die man finden kann:
///
/// - **Binky:** Überschrift auf "Heute" fünfmal schnell antippen – ein Kaninchen hüpft
///   mit Luftsprung-Drehung über den Bildschirm (so springen Kaninchen vor Freude).
///   Aufgeklappt springt es mit dem großen Satz genau über den Falz.
/// - **Kuckuck:** Beim Aufklappen schaut ab und zu ein Kaninchen aus dem Falz.
/// - **Möhrenregen:** iPhone schütteln.
/// - **Wusstest du?:** Im "Mehr"-Tab unten auf das Floof-Zeichen tippen – jedes Mal ein Kaninchen-Fakt.
/// - **Besondere Tage:** Ostern, Tag des Kaninchens (4. Samstag im September),
///   Geburtstage (mit Möhrenregen) und ein Gruß für Nachteulen.
@MainActor
@Observable
final class EasterEggs {
    static let shared = EasterEggs()

    enum Effect: Equatable {
        case binky
        case carrotRain
        /// Aufgeklappt: Ein Kaninchen schaut kurz aus dem Falz.
        case peek
        case fact(String)
    }

    private(set) var effect: Effect?
    private(set) var effectID = UUID()
    @ObservationIgnored private var taps: [String: [Date]] = [:]
    @ObservationIgnored private var factIndex = Int.random(in: 0..<EasterEggs.facts.count)

    func play(_ effect: Effect) {
        self.effect = effect
        let id = UUID()
        effectID = id
        UIImpactFeedbackGenerator(style: effect == .binky ? .rigid : .soft).impactOccurred()
        let duration: Double = switch effect {
        case .binky: 2.4
        case .carrotRain: 3.6
        case .peek: 2.6
        case .fact: 7
        }
        Task {
            try? await Task.sleep(for: .seconds(duration))
            if effectID == id { self.effect = nil }
        }
    }

    func dismiss() { effect = nil }

    /// Zählt schnelle Tipps; nach `needed` Tipps innerhalb von 2 Sekunden startet der Effekt.
    func tap(_ key: String, needed: Int, then effect: Effect) {
        let now = Date.now
        var list = (taps[key] ?? []).filter { now.timeIntervalSince($0) < 2 }
        list.append(now)
        if list.count >= needed {
            taps[key] = []
            play(effect)
        } else {
            taps[key] = list
            if list.count >= 2 { UISelectionFeedbackGenerator().selectionChanged() }
        }
    }

    /// Beim Aufklappen: höchstens einmal am Tag, und nur jedes dritte Mal – damit es eine Überraschung bleibt.
    func didUnfold() {
        let key = "floof.egg.peek"
        let today = DoseKey.day(.now)
        guard UserDefaults.standard.string(forKey: key) != today else { return }
        let count = UserDefaults.standard.integer(forKey: key + ".count") + 1
        UserDefaults.standard.set(count, forKey: key + ".count")
        guard count % 3 == 1 else { return }
        UserDefaults.standard.set(today, forKey: key)
        Task {
            try? await Task.sleep(for: .seconds(0.6))   // erst die Umstellung auf zwei Spalten abwarten
            play(.peek)
        }
    }

    func nextFact() {
        factIndex = (factIndex + 1) % Self.facts.count
        play(.fact(Self.facts[factIndex]))
    }

    /// Geburtstags-Möhrenregen nur einmal pro Tag.
    func celebrateBirthdayOnce(petIDs: [String]) {
        let key = "floof.egg.birthday.\(DoseKey.day(.now)).\(petIDs.sorted().joined(separator: ","))"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        Task {
            try? await Task.sleep(for: .seconds(0.8))
            play(.carrotRain)
        }
    }

    // MARK: Besondere Tage

    /// Ein kurzer Satz für heute – oder `nil` an normalen Tagen.
    static func specialLine(pets: [Pet], date: Date = .now) -> (symbol: String, text: String, birthdayPets: [Pet])? {
        let cal = Calendar.current
        let today = cal.dateComponents([.month, .day], from: date)

        let birthdays = pets.filter {
            let b = cal.dateComponents([.month, .day], from: $0.birthday)
            return b.month == today.month && b.day == today.day && !cal.isDate($0.birthday, inSameDayAs: date)
        }
        if let pet = birthdays.first {
            let age = cal.dateComponents([.year], from: pet.birthday, to: date).year ?? 0
            let names = birthdays.map(\.name).formatted(.list(type: .and))
            let text = birthdays.count == 1
                ? "\(pet.name) wird heute \(age)! Extra-Petersilie ist erlaubt."
                : "\(names) haben heute Geburtstag!"
            return ("birthday.cake.fill", text, birthdays)
        }
        if cal.isDate(date, inSameDayAs: easterSunday(year: cal.component(.year, from: date))) {
            return ("carrot.fill", "Frohe Ostern! Heute ist offiziell Kaninchen-Tag.", [])
        }
        if isRabbitDay(date) {
            return ("hare.fill", "Heute ist der internationale Tag des Kaninchens.", [])
        }
        let hour = cal.component(.hour, from: date)
        if hour < 4 {
            return ("moon.stars.fill", "Kaninchen sind dämmerungsaktiv – du offenbar auch.", [])
        }
        return nil
    }

    /// Ostersonntag (Gaußsche Osterformel, gregorianisch).
    static func easterSunday(year y: Int) -> Date {
        let a = y % 19, b = y / 100, c = y % 100, d = b / 4, e = b % 4
        let f = (b + 8) / 25, g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4, k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = (h + l - 7 * m + 114) % 31 + 1
        return Calendar.current.date(from: DateComponents(year: y, month: month, day: day)) ?? .distantPast
    }

    /// Vierter Samstag im September.
    static func isRabbitDay(_ date: Date) -> Bool {
        let cal = Calendar.current
        let c = cal.dateComponents([.month, .day, .weekday], from: date)
        return c.month == 9 && c.weekday == 7 && (22...28).contains(c.day ?? 0)
    }

    static let facts = [
        "Kaninchen können fast 360° sehen – nur direkt vor der Nase haben sie einen toten Winkel.",
        "Ein „Binky“ ist der Freudensprung mit Drehung in der Luft. Glückliche Kaninchen machen das.",
        "Kaninchenzähne wachsen ein Leben lang – bis zu 2 mm pro Woche. Darum ist Heu so wichtig.",
        "Kaninchen können nicht erbrechen. Deshalb ist ein Fressstopp immer ein Fall für den Tierarzt.",
        "Wenn ein Kaninchen sich flach auf die Seite „wirft“, nennt man das Flop – es fühlt sich sicher.",
        "Kaninchen fressen einen Teil ihrer Köttel (Blinddarmkot) – das liefert wichtige Vitamine.",
        "Leises Zähneknirschen heißt oft: Wohlfühlen. Lautes Knirschen dagegen kann Schmerz bedeuten.",
        "Kaninchen haben rund 17.000 Geschmacksknospen – fast doppelt so viele wie wir.",
        "Das Nasenwackeln stoppt im Schlaf und bei völliger Entspannung.",
        "Kaninchen sind dämmerungsaktiv: am muntersten früh morgens und am Abend.",
        "Ein Kaninchen kann aus dem Stand über einen Meter weit springen.",
        "Klopfen mit den Hinterläufen ist eine Warnung an alle: „Achtung, Gefahr!“",
        "Kaninchen sind keine Nagetiere, sondern Hasenartige – mit einem zweiten, kleinen Zahnpaar oben.",
        "Ohren sind die Klimaanlage: Über die Ohren geben Kaninchen Wärme ab.",
    ]
}

// MARK: - Schütteln erkennen

extension Notification.Name {
    static let floofDeviceShaken = Notification.Name("floof.deviceShaken")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .floofDeviceShaken, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}

// MARK: - Darstellung

struct EasterEggOverlay: View {
    let eggs = EasterEggs.shared
    var posture: DevicePosture = .folded

    var body: some View {
        ZStack {
            switch eggs.effect {
            case .binky: BinkyView(acrossFold: posture == .unfolded).id(eggs.effectID)
            case .peek: FoldPeek().id(eggs.effectID)
            case .carrotRain: CarrotRain().id(eggs.effectID)
            case .fact(let text): FactCard(text: text, posture: posture).id(eggs.effectID)
            case nil: EmptyView()
            }
        }
        .animation(.spring(duration: 0.4), value: eggs.effectID)
        .onReceive(NotificationCenter.default.publisher(for: .floofDeviceShaken)) { _ in
            eggs.play(.carrotRain)
        }
    }
}

/// Ein Kaninchen hüpft von links nach rechts, beim dritten Sprung mit Drehung (Binky).
private struct BinkyView: View {
    /// Aufgeklappt: drei Sprünge, der große genau über dem Falz.
    var acrossFold = false
    @State private var start = Date.now
    private let duration = 2.2

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation) { context in
                let t = min(1, context.date.timeIntervalSince(start) / duration)
                let hops = acrossFold ? 3.0 : 4.0
                let bigHop = acrossFold ? 1 : 2
                let phase = t * hops
                let hop = phase.truncatingRemainder(dividingBy: 1)
                let hopIndex = Int(phase)
                let height: CGFloat = hopIndex == bigHop ? (acrossFold ? 220 : 170) : 70
                let x = -70 + (proxy.size.width + 140) * t
                let y = proxy.size.height * 0.62 - sin(hop * .pi) * height
                let spin = hopIndex == bigHop ? hop * 360 : 0
                ZStack {
                    Image("FloofMark")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Theme.ink)
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(spin))
                        .scaleEffect(x: 1, y: hop < 0.12 || hop > 0.88 ? 0.86 : 1, anchor: .bottom)
                        .shadow(color: .black.opacity(0.3), radius: 6, y: 4)
                        .position(x: x, y: y)
                    if hopIndex == bigHop {
                        Text(acrossFold ? "Über den Falz!" : "Binky!")
                            .font(Theme.title(28))
                            .foregroundStyle(Theme.carrot)
                            .position(x: x, y: y - 70)
                            .opacity(sin(hop * .pi))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Aufgeklappt: Ein Kaninchen taucht unten aus dem Falz auf, schaut, wackelt mit den Ohren und verschwindet.
private struct FoldPeek: View {
    @State private var start = Date.now
    private let duration = 2.4

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation) { context in
                let t = min(1, context.date.timeIntervalSince(start) / duration)
                // 0–0.25 hoch, 0.25–0.75 schauen, 0.75–1 runter
                let rise: Double = t < 0.25 ? t / 0.25 : (t > 0.75 ? (1 - t) / 0.25 : 1)
                let eased = 1 - pow(1 - rise, 3)
                let wiggle = (t > 0.3 && t < 0.7) ? sin(t * 40) * 6 : 0
                let size: CGFloat = 92
                ZStack {
                    Image("FloofMark")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Theme.ink)
                        .frame(width: size, height: size)
                        .rotationEffect(.degrees(wiggle), anchor: .bottom)
                        .offset(y: (1 - eased) * size * 1.1)
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                    Text("Kuckuck!")
                        .font(Theme.title(20))
                        .foregroundStyle(Theme.carrot)
                        .offset(y: -size * 0.85)
                        .opacity(t > 0.3 && t < 0.72 ? 1 : 0)
                        .animation(.easeOut(duration: 0.2), value: t > 0.3 && t < 0.72)
                }
                .frame(width: size * 2, height: size * 2.4, alignment: .bottom)
                .clipped()
                // Genau auf dem Falz, knapp über der Tab-Leiste.
                .position(x: proxy.size.width / 2, y: proxy.size.height - size * 1.2 - 110)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Möhren fallen von oben, drehen sich leicht und verschwinden unten.
private struct CarrotRain: View {
    private struct Drop {
        let x: CGFloat, delay: Double, speed: Double, size: CGFloat, spin: Double, sway: Double
    }
    @State private var start = Date.now
    @State private var drops: [Drop] = (0..<34).map { _ in
        Drop(x: .random(in: 0...1), delay: .random(in: 0...1.2), speed: .random(in: 1.6...2.4),
             size: .random(in: 26...46), spin: .random(in: -260...260), sway: .random(in: 0...(2 * .pi)))
    }

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation) { context in
                let elapsed = context.date.timeIntervalSince(start)
                Canvas { ctx, size in
                    guard let carrot = ctx.resolveSymbol(id: 0) else { return }
                    for drop in drops {
                        let t = (elapsed - drop.delay) / drop.speed
                        guard t > 0, t < 1 else { continue }
                        let y = -60 + (size.height + 120) * t
                        let x = drop.x * size.width + sin(t * 6 + drop.sway) * 18
                        var c = ctx
                        c.translateBy(x: x, y: y)
                        c.rotate(by: .degrees(drop.spin * t))
                        c.scaleBy(x: drop.size / 44, y: drop.size / 44)
                        c.draw(carrot, at: .zero)
                    }
                } symbols: {
                    Image("fi.moehre").resizable().frame(width: 44, height: 44).tag(0)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// "Wusstest du?" – Karte oben, Tipp schließt sie.
private struct FactCard: View {
    let text: String
    var posture: DevicePosture = .folded

    var body: some View {
        GeometryReader { proxy in
            card
                // Aufgeklappt: nur in der linken Hälfte, nie über den Falz.
                .frame(width: posture == .unfolded
                       ? (proxy.size.width - FoldLayout.hingeGutter) / 2 - FoldLayout.outerMargin + 16
                       : proxy.size.width,
                       alignment: .leading)
                .padding(.leading, posture == .unfolded ? FoldLayout.outerMargin - 16 : 0)
        }
    }

    private var card: some View {
        VStack {
            HStack(alignment: .top, spacing: 12) {
                FloofIcon(symbol: "lightbulb", size: 26)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Wusstest du?").sectionLabel()
                    Text(text).font(.subheadline).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .glassPanel(cornerRadius: 24)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .onTapGesture { EasterEggs.shared.dismiss() }
            .transition(.move(edge: .top).combined(with: .opacity))
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}
