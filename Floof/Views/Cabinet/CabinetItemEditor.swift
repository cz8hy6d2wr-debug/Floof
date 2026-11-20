import SwiftUI

struct CabinetItemEditor: View {
    @Environment(PetStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var item: CabinetItem
    @State private var hasExpiry: Bool
    @State private var isOpened: Bool
    @State private var limitAfterOpening: Bool
    @State private var confirmDelete = false
    let isNew: Bool

    init(item: CabinetItem, isNew: Bool) {
        _item = State(initialValue: item)
        _hasExpiry = State(initialValue: item.expiryDate != nil)
        _isOpened = State(initialValue: item.openedDate != nil)
        _limitAfterOpening = State(initialValue: item.usableAfterOpeningDays != nil)
        self.isNew = isNew
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, z. B. Panacur Suspension", text: $item.name)
                    Picker("Darreichung", selection: $item.form) {
                        ForEach(CabinetItem.Form.allCases) { form in
                            Label(form.label, systemImage: form.symbol).tag(form)
                        }
                    }
                }

                Section("Menge") {
                    amountField("Inhalt einer Packung", value: $item.packageSize)
                    amountField("Aktuell vorhanden", value: $item.stock)
                    Stepper("Warnen, wenn's nur noch \(item.warnBelowDays) Tage reicht",
                            value: $item.warnBelowDays, in: 1...60)
                }

                Section("Haltbarkeit") {
                    Toggle("Ablaufdatum", isOn: $hasExpiry.animation())
                    if hasExpiry {
                        DatePicker("Haltbar bis", selection: binding(\.expiryDate, default: oneYear), displayedComponents: .date)
                    }
                    Toggle("Angebrochen", isOn: $isOpened.animation())
                    if isOpened {
                        DatePicker("Seit", selection: binding(\.openedDate, default: .now), displayedComponents: .date)
                    }
                    Toggle("Begrenzt haltbar nach Anbruch", isOn: $limitAfterOpening.animation())
                    if limitAfterOpening {
                        Stepper("\(item.usableAfterOpeningDays ?? 28) Tage",
                                value: Binding(get: { item.usableAfterOpeningDays ?? 28 },
                                               set: { item.usableAfterOpeningDays = $0 }),
                                in: 1...365)
                    }
                }

                Section("Notizen") {
                    TextField("Lagerung, Bezugsquelle …", text: $item.notes, axis: .vertical)
                        .lineLimit(2...6)
                }

                if !isNew {
                    Section {
                        Button("Aus dem Schrank entfernen", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle(isNew ? "Neues Medikament" : "Bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen", role: .cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", role: .confirm) { save() }
                        .disabled(item.name.trimmingCharacters(in: .whitespaces).isEmpty || item.packageSize <= 0)
                }
            }
            .confirmationDialog("\(item.name) wirklich entfernen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Entfernen", role: .destructive) {
                    store.deleteCabinetItem(item)
                    dismiss()
                }
            } message: {
                Text("Verknüpfte Medikamente bleiben erhalten, zählen aber nicht mehr mit.")
            }
        }
    }

    private var oneYear: Date { Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now }

    private func amountField(_ title: String, value: Binding<Double>) -> some View {
        LabeledContent(title) {
            HStack(spacing: 4) {
                TextField("0", value: value, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(Theme.number(.body))
                Text(item.form.unit).foregroundStyle(Theme.inkSoft)
            }
            .frame(maxWidth: 140)
        }
    }

    private func binding(_ keyPath: WritableKeyPath<CabinetItem, Date?>, default value: Date) -> Binding<Date> {
        Binding(get: { item[keyPath: keyPath] ?? value }, set: { item[keyPath: keyPath] = $0 })
    }

    private func save() {
        if !hasExpiry { item.expiryDate = nil } else if item.expiryDate == nil { item.expiryDate = oneYear }
        if !isOpened { item.openedDate = nil } else if item.openedDate == nil { item.openedDate = .now }
        if !limitAfterOpening { item.usableAfterOpeningDays = nil }
        else if item.usableAfterOpeningDays == nil { item.usableAfterOpeningDays = 28 }
        item.name = item.name.trimmingCharacters(in: .whitespaces)
        store.upsertCabinetItem(item)
        dismiss()
    }
}
