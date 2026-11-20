import SwiftUI

/// Medikament, Erkrankung, Impfung oder sonstiger Pflegeeintrag.
/// Medikamente bekommen Zeitplan, Menge je Gabe und Verknüpfung zum Schrank.
struct CareEntryEditor: View {
    @Environment(PetStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var entry: CareEntry
    @State private var isScheduled: Bool
    @State private var times: [TimeSlot]
    @State private var weekdays: Set<Int>
    @State private var amount: Double
    @State private var showsNewCabinetItem = false
    @State private var confirmDelete = false
    let petID: Pet.ID

    init(entry: CareEntry, petID: Pet.ID) {
        _entry = State(initialValue: entry)
        self.petID = petID
        let reminder = entry.reminder
        _isScheduled = State(initialValue: reminder != nil || (entry.careKind == .medication && entry.title.isEmpty))
        let cal = Calendar.current
        let startTimes = (reminder?.allTimes ?? [ReminderTime(hour: 8, minute: 0)]).map {
            TimeSlot(date: cal.date(bySettingHour: $0.hour, minute: $0.minute, second: 0, of: .now) ?? .now)
        }
        _times = State(initialValue: startTimes)
        _weekdays = State(initialValue: Set(reminder?.weekdays ?? Array(1...7)))
        _amount = State(initialValue: entry.effectiveDoseAmount ?? 0)
    }

    private var exists: Bool { store.pet(petID)?.care.contains { $0.id == entry.id } ?? false }
    private var kind: CareKind { entry.careKind }
    private var linkedItem: CabinetItem? { store.cabinetItem(entry.cabinetItemID) }

    var body: some View {
        editor.floofSheet()
    }

    private var editor: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Art", selection: $entry.kind) {
                        ForEach(CareKind.allCases) { Label($0.rawValue, systemImage: $0.symbol).tag($0.rawValue) }
                    }
                    TextField(titlePlaceholder, text: $entry.title)
                        .font(Theme.title(18))
                    TextField(kind == .medication ? "Dosierung & Hinweise" : "Details", text: $entry.details, axis: .vertical)
                        .lineLimit(1...5)
                    DatePicker(kind == .vaccination ? "Geimpft am" : "Seit", selection: $entry.date, displayedComponents: .date)
                }

                if kind == .medication {
                    scheduleSection
                    cabinetSection
                }

                if exists {
                    Section {
                        Button("Eintrag löschen", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle(exists ? entry.title : "Neu: \(kind.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen", role: .cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", role: .confirm) { save() }
                        .disabled(entry.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showsNewCabinetItem) {
                CabinetItemEditor(item: CabinetItem(name: entry.title, stock: 0, packageSize: 10), isNew: true)
            }
            .onChange(of: store.cabinet.count) { old, new in
                // Gerade neu angelegten Artikel direkt verknüpfen.
                if new > old, let newest = store.cabinet.last { entry.cabinetItemID = newest.id }
            }
            .confirmationDialog("Eintrag löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    store.deleteCare(entry, from: petID)
                    dismiss()
                }
            }
        }
    }

    private var titlePlaceholder: String {
        switch kind {
        case .medication: "Name, z. B. Panacur"
        case .condition: "Erkrankung, z. B. EC"
        case .vaccination: "Impfung, z. B. RHD-1/RHD-2"
        case .other: "Was, z. B. Krallen geschnitten"
        }
    }

    private var scheduleSection: some View {
        Section {
            Toggle("Fester Zeitplan", isOn: $isScheduled.animation())
            if isScheduled {
                ForEach($times) { $slot in
                    HStack {
                        DatePicker("Uhrzeit", selection: $slot.date, displayedComponents: .hourAndMinute)
                        if times.count > 1 {
                            Button("Entfernen", systemImage: "minus.circle.fill", role: .destructive) {
                                withAnimation { times.removeAll { $0.id == slot.id } }
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                        }
                    }
                }
                Button("Weitere Uhrzeit", systemImage: "plus") {
                    withAnimation {
                        let next = Calendar.current.date(byAdding: .hour, value: 8, to: times.last?.date ?? .now) ?? .now
                        times.append(TimeSlot(date: next))
                    }
                }
                WeekdayPicker(selection: $weekdays)
            }
        } header: {
            Text("Wann")
        } footer: {
            Text(isScheduled ? "Floof erinnert dich zu diesen Zeiten und zeigt die Gaben unter „Heute“."
                             : "Erscheint unter „Wenn nötig“ mit einem Gegeben-Knopf.")
        }
    }

    private var cabinetSection: some View {
        Section {
            Picker("Aus dem Schrank", selection: $entry.cabinetItemID) {
                Text("Nicht verknüpft").tag(String?.none)
                ForEach(store.cabinet) { item in
                    Text(item.name).tag(Optional(item.id))
                }
            }
            if let item = linkedItem {
                LabeledContent("Menge je Gabe") {
                    HStack(spacing: 4) {
                        TextField("0", value: $amount, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(Theme.number(.body))
                            .frame(maxWidth: 90)
                        Text(item.form.unit).foregroundStyle(Theme.inkSoft)
                    }
                }
            } else {
                Button("Neu im Schrank anlegen", systemImage: "cross.case") { showsNewCabinetItem = true }
            }
        } header: {
            Text("Vorrat")
        } footer: {
            if let item = linkedItem, amount > 0 {
                let perDay = amount * Double(isScheduled ? times.count : 0) * Double(weekdays.count) / 7
                if perDay > 0 {
                    Text("Beim Abhaken werden \(item.formatted(amount)) abgebucht. Der Vorrat (\(item.formatted(item.stock))) reicht so noch etwa \(Int(item.stock / perDay)) Tage.")
                } else {
                    Text("Beim Eintragen werden \(item.formatted(amount)) abgebucht.")
                }
            } else {
                Text("Verknüpfe das Medikament mit dem Schrank, dann zählt Floof automatisch mit.")
            }
        }
    }

    private func save() {
        entry.title = entry.title.trimmingCharacters(in: .whitespaces)
        if kind == .medication, isScheduled, !weekdays.isEmpty {
            let cal = Calendar.current
            let reminderTimes = times
                .map { ReminderTime(hour: cal.component(.hour, from: $0.date), minute: cal.component(.minute, from: $0.date)) }
                .sorted()
            entry.reminder = CareReminder(hour: reminderTimes[0].hour, minute: reminderTimes[0].minute,
                                          times: reminderTimes, weekdays: weekdays.sorted())
        } else {
            entry.reminder = nil
        }
        if kind == .medication {
            entry.doseAmount = amount > 0 ? amount : nil
        } else {
            entry.doseAmount = nil
            entry.cabinetItemID = nil
        }
        store.upsertCare(entry, for: petID)
        dismiss()
    }
}

private struct TimeSlot: Identifiable {
    let id = UUID()
    var date: Date
}

/// Wochentage als runde Knöpfe (Mo zuerst, Calendar-Werte 1 = So … 7 = Sa).
struct WeekdayPicker: View {
    @Binding var selection: Set<Int>
    private let order = [2, 3, 4, 5, 6, 7, 1]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(order, id: \.self) { day in
                let on = selection.contains(day)
                Button {
                    if on { selection.remove(day) } else { selection.insert(day) }
                } label: {
                    Text(Calendar.current.veryShortWeekdaySymbols[day - 1])
                        .font(.footnote.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(on ? Theme.carrot : Theme.sunken, in: Circle())
                        .foregroundStyle(on ? .white : Theme.inkSoft)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}
