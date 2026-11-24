import SwiftUI

// MARK: - Auswahl für den Heute-Bereich

/// Welcher Tag und welches Tier gerade angezeigt werden.
struct TodaySelection: Equatable {
    var day: Date = Calendar.current.startOfDay(for: .now)
    /// `nil` = alle Tiere.
    var petID: Pet.ID?

    var isToday: Bool { Calendar.current.isDateInToday(day) }
    var isFuture: Bool { day > Calendar.current.startOfDay(for: .now) }
}

extension PetStore {
    /// Gaben eines Tages, optional für ein Tier.
    func doses(on day: Date, petID: Pet.ID?) -> [ScheduledDose] {
        if let petID, let pet = pet(petID) { return doses(for: pet, on: day) }
        return todaysDoses(on: day)
    }
}

// MARK: - Kopf: Datum, große Zahl, Fortschritt

struct TodayHeader: View {
    @Environment(PetStore.self) private var store
    let selection: TodaySelection

    var body: some View {
        let doses = store.doses(on: selection.day, petID: selection.petID)
        let given = doses.filter(store.isTaken).count
        let open = doses.filter { !store.isTaken($0) }

        VStack(alignment: .leading, spacing: 8) {
            Text(dayTitle)
                .sectionLabel()

            // Ein Satz statt einer Zahl – wie ihn ein Mensch sagen würde.
            Text(headline(doses: doses, open: open))
                .font(Theme.display(32))
                .tracking(-0.6)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .accessibilityAddTraits(.isHeader)
                // Fünfmal schnell tippen …
                .onTapGesture { EasterEggs.shared.tap("headline", needed: 5, then: .binky) }

            if selection.isToday, let special = EasterEggs.specialLine(pets: store.pets) {
                Label {
                    Text(special.text)
                } icon: {
                    FloofIcon(symbol: special.symbol, size: 18, tile: false)
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.carrot)
                .onAppear {
                    if !special.birthdayPets.isEmpty {
                        EasterEggs.shared.celebrateBirthdayOnce(petIDs: special.birthdayPets.map(\.id))
                    }
                }
            }

            if !doses.isEmpty {
                if selection.isToday, !open.isEmpty {
                    NextDoseCountdown(open: open, progress: Double(given) / Double(doses.count))
                        .padding(.top, 10)
                } else {
                    HStack(spacing: 10) {
                        ProgressBar(value: Double(given) / Double(doses.count))
                        Text("\(given) von \(doses.count)")
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize()
                    }
                    .padding(.top, 6)
                }
            }
        }
        .animation(.smooth, value: given)
    }

    /// "Noch zwei Gaben für Brownie." / "Alles gegeben." – kurz und freundlich.
    private func headline(doses: [ScheduledDose], open: [ScheduledDose]) -> AttributedString {
        func plain(_ s: String) -> AttributedString { AttributedString(s) }
        func accent(_ s: String) -> AttributedString {
            var a = AttributedString(s); a.foregroundColor = Theme.carrot; return a
        }
        if doses.isEmpty {
            return plain(selection.isToday ? "Heute ein freier Tag." : "Keine Medikamente.")
        }
        if open.isEmpty {
            if selection.isFuture { return plain("\(countWord(doses.count)) \(doses.count == 1 ? "Gabe" : "Gaben") geplant.") }
            return plain("Alles gegeben.")
        }
        if selection.isFuture {
            return plain("\(countWord(open.count)) \(open.count == 1 ? "Gabe" : "Gaben") geplant.")
        }
        if !selection.isToday {
            return plain("\(countWord(open.count)) \(open.count == 1 ? "Gabe" : "Gaben") nicht abgehakt.")
        }
        let names = Array(Set(open.map(\.pet.name))).sorted()
        let lead = open.count == 1 ? "Noch eine Gabe" : "Noch \(countWord(open.count).lowercased()) Gaben"
        if names.count == 1 {
            return plain("\(lead) für ") + accent(names[0]) + plain(".")
        }
        return plain("\(lead) für deine Tiere.")
    }

    private func countWord(_ n: Int) -> String {
        let words = ["Keine", "Eine", "Zwei", "Drei", "Vier", "Fünf", "Sechs", "Sieben", "Acht", "Neun", "Zehn", "Elf", "Zwölf"]
        return n < words.count ? words[n] : "\(n)"
    }

    private var dayTitle: String {
        let date = selection.day.formatted(.dateTime.weekday(.wide).day().month(.wide))
        if Calendar.current.isDateInYesterday(selection.day) { return "Gestern · \(date)" }
        if Calendar.current.isDateInTomorrow(selection.day) { return "Morgen · \(date)" }
        return date
    }
}

/// Countdown bis zur nächsten Gabe, z. B. "Panacur & Gabapentin · 2:14:05".
/// Das Herunterzählen übernimmt das System (Text mit Timer) – kein Ruckeln, kein Mehraufwand.
struct NextDoseCountdown: View {
    let open: [ScheduledDose]
    /// Anteil der heute schon gegebenen Dosen – für den Ring.
    var progress: Double = 0

    var body: some View {
        // Alle 30 Sekunden neu prüfen, damit eine fällig gewordene Gabe weiterrückt.
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let upcoming = open.filter { $0.dueDate > context.date }.sorted { $0.dueDate < $1.dueDate }
            if let next = upcoming.first {
                let sameTime = upcoming.filter { $0.dueDate == next.dueDate }
                let names = Array(Set(sameTime.map(\.medication.title))).sorted().joined(separator: " & ")
                HStack(spacing: 16) {
                    ZStack {
                        Circle().stroke(Theme.ink.opacity(0.1), lineWidth: 5)
                        Circle().trim(from: 0, to: max(0.02, min(progress, 1)))
                            .stroke(Theme.carrot, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        FloofIcon(symbol: "drop.fill", size: 28, tile: false)
                    }
                    .frame(width: 64, height: 64)
                    .animation(.smooth, value: progress)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Nächste Gabe in").font(.caption).foregroundStyle(Theme.inkSoft)
                        Text(timerInterval: context.date...next.dueDate, countsDown: true)
                            .font(Theme.display(28).monospacedDigit())
                            .foregroundStyle(Theme.ink)
                        Text("\(names) · \(next.time.label) Uhr")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
                .glassPanel(cornerRadius: 24)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Nächste Gabe \(names) um \(next.time.label) Uhr")
            } else if let late = open.first {
                HStack(spacing: 14) {
                    FloofIcon(symbol: "drop.fill", size: 26)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Seit \(late.time.label) Uhr fällig").font(.caption.weight(.semibold)).foregroundStyle(Theme.berry)
                        Text(late.medication.title).font(Theme.title(20)).foregroundStyle(Theme.ink)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
                .glassPanel(cornerRadius: 24)
            }
        }
    }
}

struct ProgressBar: View {
    let value: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.ink.opacity(0.08))
                Capsule()
                    .fill(value >= 1 ? Theme.leaf : Theme.carrot)
                    .frame(width: max(6, proxy.size.width * min(max(value, 0), 1)))
            }
        }
        .frame(height: 6)
        .animation(.smooth, value: value)
        .accessibilityElement()
        .accessibilityLabel("Fortschritt")
        .accessibilityValue(Text(value, format: .percent.precision(.fractionLength(0))))
    }
}

// MARK: - Wochenkalender

/// Eine Woche (Mo–So) als gläserne Leiste. Punkt unter dem Tag:
/// grün = alles gegeben, orange = nicht alles bzw. noch offen.
struct WeekStrip: View {
    @Environment(PetStore.self) private var store
    @Binding var selection: TodaySelection
    @Namespace private var glass
    @Environment(\.colorScheme) private var scheme
    private var weather: WeatherStore { WeatherStore.shared }

    private var cal: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2   // Montag
        return c
    }

    private var days: [Date] {
        let start = cal.dateInterval(of: .weekOfYear, for: selection.day)?.start ?? selection.day
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(selection.day, format: .dateTime.month(.wide).year())
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if !selection.isToday {
                    Button("Heute") { move(to: .now) }
                        .font(.subheadline.weight(.semibold))
                        .padding(.trailing, 4)
                }
                Button("Vorige Woche", systemImage: "chevron.left") { shift(-7) }
                Button("Nächste Woche", systemImage: "chevron.right") { shift(7) }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .tint(Theme.ink)
            .padding(.horizontal, 10)

            HStack(spacing: 2) {
                ForEach(days, id: \.self) { day in
                    dayCell(day)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 12).padding(.bottom, 6).padding(.horizontal, 6)
        // Das Wetter des gewählten Tages läuft hinter dem ganzen Kasten (über dem Glas, hinter den Tagen).
        .background {
            ZStack {
                if let forecast = weather.forecast(on: selection.day) {
                    DayWeatherBackdrop(conditions: WeatherStore.conditions(for: forecast), onLight: scheme == .light)
                        .id(DoseKey.day(selection.day))
                        .transition(.opacity)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .animation(.smooth(duration: 0.6), value: DoseKey.day(selection.day))
        }
        .glassPanel(cornerRadius: 26)
        .sensoryFeedback(.selection, trigger: selection.day)
    }

    private func dayCell(_ day: Date) -> some View {
        let selected = cal.isDate(day, inSameDayAs: selection.day)
        let today = cal.isDateInToday(day)
        let forecast = weather.forecast(on: day)
        // Heller Untergrund? Gewählter Tag: Creme im Dunkeln. Sonst: das helle Glas im hellen Modus.
        let onLight = selected ? scheme == .dark : scheme == .light
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return Button {
            move(to: day)
        } label: {
            VStack(spacing: 5) {
                Text(day, format: .dateTime.weekday(.narrow))
                    .font(.caption2.weight(.semibold))
                    .opacity(0.6)
                Text(day, format: .dateTime.day())
                    .font(.system(size: 17, weight: today ? .bold : .medium, design: .serif))
                if let forecast {
                    let tint = tempColor(hi: forecast.hi, onLight: onLight)
                    Image(systemName: WeatherStore.lineSymbol(WeatherStore.condition(for: forecast)))
                        .font(.system(size: 13))
                        .foregroundStyle(tint)
                        .frame(height: 16)
                    Text("\(Int(forecast.hi.rounded()))°")
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundStyle(tint)
                    Text("\(Int(forecast.lo.rounded()))°")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(tint.opacity(0.6))
                        .padding(.top, -3)
                }
                Spacer(minLength: 0)
                Circle().fill(dotColor(day)).frame(width: 5, height: 5)
            }
            .foregroundStyle(selected ? Theme.paper : Theme.ink)
            // Alle Tage gleich hoch und oben bündig – auch ohne Vorhersage (z. B. gestern).
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.vertical, 8)
            .background {
                ZStack {
                    if selected {
                        shape.fill(Theme.ink)
                            .matchedGeometryEffect(id: "selected", in: glass)
                    }
                }
            }
            .opacity(day > cal.startOfDay(for: .now) && !selected ? (forecast == nil ? 0.45 : 0.85) : 1)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText(day, forecast: forecast))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// Warm = Orange, kalt = Blau, sonst die normale Schriftfarbe – je nach Untergrund etwas dunkler oder heller.
    private func tempColor(hi: Double, onLight: Bool) -> Color {
        if hi >= 25 { return onLight ? Color(hex: 0xC25A22) : Color(hex: 0xE0864A) }
        if hi <= 2 { return onLight ? Color(hex: 0x2F6F9F) : Color(hex: 0x8FC1E8) }
        return onLight ? Color(hex: 0x2A1D15) : Color(hex: 0xF3E9DC)
    }

    private func accessibilityText(_ day: Date, forecast: WeatherStore.Weather.Day?) -> String {
        let date = day.formatted(date: .complete, time: .omitted)
        guard let forecast else { return date }
        return "\(date), \(WeatherStore.label(WeatherStore.condition(for: forecast))), \(Int(forecast.hi.rounded())) Grad, nachts \(Int(forecast.lo.rounded())) Grad"
    }

    private func dotColor(_ day: Date) -> Color {
        let doses = store.doses(on: day, petID: selection.petID)
        guard !doses.isEmpty, day <= .now else { return .clear }
        return doses.allSatisfy(store.isTaken) ? Theme.leaf : Theme.carrot
    }

    private func move(to day: Date) {
        withAnimation(.snappy) { selection.day = cal.startOfDay(for: day) }
    }

    private func shift(_ days: Int) {
        if let d = cal.date(byAdding: .day, value: days, to: selection.day) { move(to: d) }
    }
}

// MARK: - Gaben als Glas-Liste

struct DoseList: View {
    @Environment(PetStore.self) private var store
    let selection: TodaySelection

    var body: some View {
        let doses = store.doses(on: selection.day, petID: selection.petID)
        let showsPet = selection.petID == nil && store.pets.count > 1

        if doses.isEmpty {
            Text(selection.isToday ? "Heute stehen keine Medikamente an." : "An diesem Tag stehen keine Medikamente an.")
                .font(.subheadline).foregroundStyle(Theme.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .glassPanel()
        } else {
            VStack(spacing: 0) {
                ForEach(Array(doses.enumerated()), id: \.element.id) { index, dose in
                    DoseRow(dose: dose, showsPet: showsPet, isFuture: selection.isFuture)
                    if index < doses.count - 1 {
                        Divider().padding(.leading, 64)
                    }
                }
            }
            .glassPanel()
        }
    }
}

struct DoseRow: View {
    @Environment(PetStore.self) private var store
    let dose: ScheduledDose
    var showsPet = false
    var isFuture = false

    private var taken: Bool { store.isTaken(dose) }

    var body: some View {
        Button {
            store.toggle(dose)
        } label: {
            HStack(spacing: 14) {
                FloofIcon(symbol: formSymbol, size: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text(dose.medication.title)
                        .font(.body.weight(.semibold))
                        .lineLimit(1).minimumScaleFactor(0.75)
                        .strikethrough(taken, color: Theme.inkSoft)
                        .foregroundStyle(taken ? Theme.inkSoft : Theme.ink)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(dose.time.label)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold).monospacedDigit())
                    .foregroundStyle(timeColor)
                checkmark
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .sensoryFeedback(.impact(weight: .medium), trigger: taken) { _, new in new }
        .overlay(alignment: .topTrailing) {
            // Nur direkt nach dem Abhaken – nicht jedes Mal, wenn die Zeile wieder erscheint.
            if taken, store.recentlyAwardedDoseID == dose.id, let points = store.game.awarded[dose.id] {
                PointsPop(points: points).offset(x: -14, y: -4)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(dose.medication.title) für \(dose.pet.name) um \(dose.time.label)")
        .accessibilityValue(taken ? "Gegeben" : "Offen")
        .accessibilityAddTraits(taken ? [.isButton, .isSelected] : .isButton)
    }

    private var detail: String {
        let firstLine = dose.medication.details.split(separator: "\n").first.map(String.init) ?? ""
        let dosage: String
        if let item = store.cabinetItem(dose.medication.cabinetItemID), let amount = dose.medication.effectiveDoseAmount {
            dosage = item.formatted(amount)
        } else {
            dosage = firstLine
        }
        return showsPet ? "\(dose.pet.name) · \(dosage)" : dosage
    }

    private var formSymbol: String {
        store.cabinetItem(dose.medication.cabinetItemID)?.form.symbol ?? "drop.fill"
    }

    private var timeColor: Color {
        if taken { return Theme.leaf }
        if !isFuture && dose.isOverdue { return Theme.berry }
        return Theme.inkSoft
    }

    private var checkmark: some View {
        ZStack {
            Circle().strokeBorder(taken ? Theme.leaf : Theme.ink.opacity(0.25), lineWidth: 2)
            if taken {
                Circle().fill(Theme.leaf)
                Image(systemName: "checkmark").font(.system(size: 13, weight: .heavy)).foregroundStyle(.white)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 28, height: 28)
        .animation(.snappy, value: taken)
    }
}

/// Kleines "+10" mit Möhre, das kurz nach oben wegschwebt.
struct PointsPop: View {
    let points: Int
    @State private var shown = false

    var body: some View {
        Label("+\(points)", systemImage: "carrot.fill")
            .font(Theme.number(.caption))
            .foregroundStyle(Theme.carrot)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .glassEffect(.regular, in: .capsule)
            .offset(y: shown ? -18 : 0)
            .opacity(shown ? 0 : 1)
            .onAppear { withAnimation(.easeOut(duration: 1.1).delay(0.2)) { shown = true } }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: - Kacheln

struct StatTiles: View {
    @Environment(PetStore.self) private var store
    var petID: Pet.ID?

    var body: some View {
        let pet = petID.flatMap(store.pet) ?? store.selectedPet
        HStack(spacing: 10) {
            tile("Möhren", value: "\(store.game.carrots)", unit: nil)
            tile("Serie", value: "\(store.streak)", unit: store.streak == 1 ? "Tag" : "Tage")
            if let grams = pet?.latestWeight?.grams {
                tile("Gewicht", value: (Double(grams) / 1000).formatted(.number.precision(.fractionLength(2))), unit: "kg",
                     caption: store.pets.count > 1 ? pet?.name : nil)
            }
        }
    }

    private func tile(_ title: String, value: String, unit: String?, caption: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(1).minimumScaleFactor(0.8)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value).font(Theme.display(26))
                    .contentTransition(.numericText())
                if let unit {
                    Text(unit).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.inkSoft)
                }
            }
            .lineLimit(1).minimumScaleFactor(0.7)
            if let caption {
                Text(caption).font(.caption2).foregroundStyle(Theme.inkSoft).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14).padding(.vertical, 12)
        .glassPanel(cornerRadius: 22)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Tier-Auswahl im Kopf

struct TodayPetMenu: View {
    @Environment(PetStore.self) private var store
    @Binding var petID: Pet.ID?

    var body: some View {
        Menu {
            Picker("Tier", selection: $petID) {
                if store.pets.count > 1 { Text("Alle Tiere").tag(Pet.ID?.none) }
                ForEach(store.pets) { Text($0.name).tag(Optional($0.id)) }
            }
        } label: {
            HStack(spacing: 8) {
                if let id = petID, let pet = store.pet(id) {
                    PetAvatar(pet: pet, size: 28)
                    Text(pet.name)
                } else {
                    HStack(spacing: -8) { ForEach(store.pets.prefix(3)) { PetAvatar(pet: $0, size: 26) } }
                    Text(store.pets.count > 1 ? "Alle" : (store.pets.first?.name ?? ""))
                }
                Image(systemName: "chevron.down").font(.caption2.bold()).foregroundStyle(Theme.inkSoft)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.ink)
        }
        .accessibilityLabel("Tier auswählen")
    }
}
