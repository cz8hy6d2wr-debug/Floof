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

        VStack(alignment: .leading, spacing: 6) {
            Text(dayTitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.inkSoft)

            // Ohne Medikamente nur das Datum – der Hinweis steht darunter in der Liste.
            if !doses.isEmpty {
                HStack(alignment: .lastTextBaseline) {
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text("\(given)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .contentTransition(.numericText(value: Double(given)))
                        Text("von \(doses.count)")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Gaben").foregroundStyle(Theme.inkSoft)
                        statusLine(doses: doses, open: open)
                    }
                    .font(.subheadline)
                    .multilineTextAlignment(.trailing)
                }

                ProgressBar(value: Double(given) / Double(doses.count))
                    .padding(.top, 8)
            }
        }
        .animation(.smooth, value: given)
    }

    private var dayTitle: String {
        let date = selection.day.formatted(.dateTime.weekday(.wide).day().month(.wide))
        if selection.isToday { return "Heute, \(date)" }
        if Calendar.current.isDateInYesterday(selection.day) { return "Gestern, \(date)" }
        if Calendar.current.isDateInTomorrow(selection.day) { return "Morgen, \(date)" }
        return date
    }

    @ViewBuilder
    private func statusLine(doses: [ScheduledDose], open: [ScheduledDose]) -> some View {
        if doses.isEmpty {
            EmptyView()
        } else if open.isEmpty {
            Text("Alles gegeben").fontWeight(.semibold).foregroundStyle(Theme.leaf)
        } else if let late = open.first(where: \.isOverdue), !selection.isFuture {
            Text(selection.isToday ? "\(late.medication.title) überfällig" : "\(open.count) nicht gegeben")
                .fontWeight(.semibold).foregroundStyle(Theme.berry)
        } else if let next = open.first {
            Text("Nächste um \(next.time.label)").fontWeight(.semibold).foregroundStyle(Theme.ink)
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
        }
        .padding(.top, 12).padding(.bottom, 6).padding(.horizontal, 6)
        .glassPanel(cornerRadius: 26)
        .sensoryFeedback(.selection, trigger: selection.day)
    }

    private func dayCell(_ day: Date) -> some View {
        let selected = cal.isDate(day, inSameDayAs: selection.day)
        let today = cal.isDateInToday(day)
        return Button {
            move(to: day)
        } label: {
            VStack(spacing: 6) {
                Text(day, format: .dateTime.weekday(.narrow))
                    .font(.caption2.weight(.semibold))
                    .opacity(0.6)
                Text(day, format: .dateTime.day())
                    .font(.system(size: 17, weight: today ? .bold : .semibold, design: .rounded))
                Circle().fill(dotColor(day)).frame(width: 5, height: 5)
            }
            .foregroundStyle(selected ? Theme.paper : Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Theme.ink)
                        .matchedGeometryEffect(id: "selected", in: glass)
                }
            }
            .opacity(day > cal.startOfDay(for: .now) && !selected ? 0.45 : 1)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
        .accessibilityAddTraits(selected ? .isSelected : [])
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
                        Divider().padding(.leading, 18)
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
            .padding(.horizontal, 18).padding(.vertical, 15)
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
                tile(store.pets.count > 1 ? "Gewicht \(pet?.name ?? "")" : "Gewicht",
                     value: (Double(grams) / 1000).formatted(.number.precision(.fractionLength(2))), unit: "kg")
            }
        }
    }

    private func tile(_ title: String, value: String, unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(1).minimumScaleFactor(0.8)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value).font(.system(size: 26, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                if let unit {
                    Text(unit).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.inkSoft)
                }
            }
            .lineLimit(1).minimumScaleFactor(0.7)
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
