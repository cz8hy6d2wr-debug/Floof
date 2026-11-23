import SwiftUI

/// Gesundheitsverlauf der letzten 14 Tage: je Beobachtung eine Zeile, je Tag ein Punkt.
/// Auf einen Blick sieht man, seit wann sich etwas verändert hat.
struct PetHealthHistory: View {
    let pet: Pet
    private let dayCount = 14

    private var days: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return (0..<dayCount).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Gesundheitsverlauf").sectionLabel()
                Spacer()
                Text("14 Tage").font(.caption).foregroundStyle(Theme.inkSoft)
            }

            Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 8) {
                ForEach(DailyCheck.Aspect.allCases) { aspect in
                    GridRow {
                        Label {
                            Text(aspect.title)
                        } icon: {
                            FloofIcon(symbol: aspect.symbol, size: 16, tile: false)
                        }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.inkSoft)
                            .lineLimit(1)
                            .fixedSize()
                        ForEach(days, id: \.self) { day in
                            dot(pet.check(on: day)?.level(aspect))
                        }
                    }
                }
                GridRow {
                    Color.clear.frame(width: 1, height: 1)
                    ForEach(days, id: \.self) { day in
                        Text(day, format: .dateTime.day())
                            .font(.system(size: 9, weight: Calendar.current.isDateInToday(day) ? .bold : .regular))
                            .foregroundStyle(Theme.inkSoft)
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            if let latest = pet.dailyChecks.filter({ $0.findings != nil }).max(by: { $0.id < $1.id }),
               let date = DoseKey.date(latest.id) {
                Text("Zuletzt auffällig: \(date.formatted(.dateTime.weekday(.wide).day().month())) – \(latest.findings ?? "")")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            } else {
                Text("In den letzten Tagen nichts Auffälliges.")
                    .font(.caption).foregroundStyle(Theme.inkSoft)
            }
        }
        .card()
        .accessibilityElement(children: .combine)
    }

    private func dot(_ level: DailyCheck.Level?) -> some View {
        Circle()
            .fill(color(level))
            .frame(width: 9, height: 9)
            .frame(maxWidth: .infinity, minHeight: 14)
    }

    private func color(_ level: DailyCheck.Level?) -> Color {
        switch level {
        case .normal: Theme.leaf
        case .reduced: Theme.honey
        case .alarming: Theme.berry
        case nil: Theme.ink.opacity(0.12)
        }
    }
}

/// Pflege-Routinen mit Fälligkeit: Wiegen, Krallen, Zähne, Fell & Po.
struct PetRoutinesCard: View {
    @Environment(PetStore.self) private var store
    let pet: Pet
    @State private var weighing = false
    @State private var editing: CareRoutine?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pflege").sectionLabel()
            ForEach(pet.careRoutines) { routine in
                HStack(spacing: 12) {
                    FloofIcon(symbol: routine.kind.symbol, size: 24)
                    Button { editing = routine } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(routine.kind.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                            Text(statusText(routine)).font(.caption).foregroundStyle(statusColor(routine))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    Button(routine.kind == .weigh ? "Wiegen" : "Erledigt") {
                        if routine.kind == .weigh { weighing = true }
                        else { withAnimation(.snappy) { store.markRoutineDone(routine.kind, for: pet.id) } }
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }
            }
            Text("Tippe auf eine Routine, um den Abstand zu ändern.")
                .font(.caption2).foregroundStyle(Theme.inkSoft)
        }
        .card()
        .sheet(isPresented: $weighing) { WeightSheet(pet: pet) }
        .sheet(item: $editing) { routine in RoutineIntervalSheet(pet: pet, routine: routine) }
    }

    private func statusText(_ routine: CareRoutine) -> String {
        let every = "alle \(routine.intervalDays) Tage"
        guard let days = pet.daysUntilDue(routine) else { return "Noch nie eingetragen · \(every)" }
        switch days {
        case ..<0: return "Seit \(-days) Tag\(days == -1 ? "" : "en") fällig · \(every)"
        case 0: return "Heute fällig · \(every)"
        case 1: return "Morgen fällig · \(every)"
        default: return "In \(days) Tagen · \(every)"
        }
    }

    private func statusColor(_ routine: CareRoutine) -> Color {
        guard let days = pet.daysUntilDue(routine) else { return Theme.inkSoft }
        if days < 0 { return Theme.berry }
        if days == 0 { return Theme.carrot }
        return Theme.inkSoft
    }
}

private struct RoutineIntervalSheet: View {
    @Environment(PetStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let pet: Pet
    let routine: CareRoutine
    @State private var days: Int

    init(pet: Pet, routine: CareRoutine) {
        self.pet = pet
        self.routine = routine
        _days = State(initialValue: routine.intervalDays)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("Alle \(days) Tage", value: $days, in: 1...365)
                } footer: {
                    Text("Floof erinnert unter „Heute“, wenn \(routine.kind.title.lowercased()) wieder dran ist.")
                }
                if let last = pet.lastDone(routine) {
                    Section {
                        LabeledContent("Zuletzt", value: last.formatted(date: .long, time: .omitted))
                    }
                }
            }
            .navigationTitle(routine.kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen", role: .cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", role: .confirm) {
                        store.setRoutineInterval(routine.kind, days: days, for: pet.id)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
