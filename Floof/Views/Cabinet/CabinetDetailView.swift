import SwiftUI

struct CabinetDetailView: View {
    @Environment(PetStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let itemID: CabinetItem.ID

    @State private var showsEditor = false
    @State private var showsCorrection = false
    @State private var showsRefill = false
    @State private var lexiconProductID: String?

    var body: some View {
        if let item = store.cabinetItem(itemID) {
            content(item)
        } else {
            ContentUnavailableView("Nicht mehr im Schrank", systemImage: "cross.case")
        }
    }

    private func content(_ item: CabinetItem) -> some View {
        let status = store.status(of: item)
        let color = CabinetStatusText.color(status)

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Kopf: großer Füllstand
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.formatted(item.stock)).font(Theme.number(.largeTitle))
                        Text("von \(item.formatted(item.packageSize))").foregroundStyle(Theme.inkSoft)
                        Spacer()
                        Text(CabinetStatusText.short(status))
                            .font(.subheadline.weight(.bold)).foregroundStyle(color)
                    }
                    StockGauge(level: item.fillLevel, color: color, height: 22)
                    reachLine(item)
                }
                .card()

                // Schnellaktionen in Glas – fließen als Gruppe zusammen
                GlassEffectContainer(spacing: 10) {
                    HStack(spacing: 10) {
                        Button("Nachfüllen", systemImage: "plus.circle.fill") { showsRefill = true }
                            .buttonStyle(.glassProminent)
                        Button("Bestand korrigieren", systemImage: "slider.horizontal.3") { showsCorrection = true }
                            .buttonStyle(.glass)
                    }
                    .controlSize(.large)
                }

                facts(item)
                supplementInfo(item)
                linked(item)
                history(item)
            }
            .padding(16)
        }
        .background(Theme.paper)
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Bearbeiten") { showsEditor = true }
        }
        .sheet(isPresented: $showsEditor) { CabinetItemEditor(item: item, isNew: false) }
        .sheet(isPresented: $showsCorrection) { StockCorrectionSheet(item: item) }
        .sheet(isPresented: $showsRefill) { RefillSheet(item: item) }
        .sheet(isPresented: Binding(get: { lexiconProductID != nil }, set: { if !$0 { lexiconProductID = nil } })) {
            if let id = lexiconProductID { LexiconSheet(start: .supplement(id)) }
        }
    }

    /// Erkennt RodiCare-Mittel am Namen und verlinkt den Lexikon-Eintrag.
    @ViewBuilder
    private func supplementInfo(_ item: CabinetItem) -> some View {
        if let product = Supplements.mentioned(in: item.name).first {
            Button { lexiconProductID = product.id } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: product.area.symbol)
                        .foregroundStyle(Theme.leaf)
                        .frame(width: 36, height: 36)
                        .background(Theme.leaf.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Wofür ist das?").font(.caption.weight(.bold)).foregroundStyle(Theme.inkSoft)
                        Text(product.purpose).font(.subheadline).foregroundStyle(Theme.ink)
                        if !product.forRabbits {
                            Text("Laut Hersteller nicht für Kaninchen vorgesehen.")
                                .font(.caption.weight(.semibold)).foregroundStyle(Theme.berry)
                        }
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "books.vertical").foregroundStyle(Theme.inkSoft)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .card()
        }
    }

    @ViewBuilder
    private func reachLine(_ item: CabinetItem) -> some View {
        let perDay = store.dailyConsumption(of: item)
        if let days = store.daysLeft(of: item), let until = Calendar.current.date(byAdding: .day, value: days, to: .now) {
            Text("Verbrauch etwa \(item.formatted(perDay)) am Tag – reicht noch **\(days) Tage**, bis \(until.formatted(date: .long, time: .omitted)).")
                .font(.subheadline).foregroundStyle(Theme.inkSoft)
        } else {
            Text("Nicht im festen Plan – wird nur bei Bedarf abgebucht.")
                .font(.subheadline).foregroundStyle(Theme.inkSoft)
        }
    }

    private func facts(_ item: CabinetItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Haltbarkeit").font(Theme.title(18))
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 8) {
                if let expiry = item.expiryDate { row("Ablaufdatum", expiry.formatted(date: .long, time: .omitted)) }
                if let opened = item.openedDate { row("Angebrochen", opened.formatted(date: .long, time: .omitted)) }
                if let days = item.usableAfterOpeningDays { row("Nach Anbruch", "\(days) Tage verwendbar") }
                if let effective = item.effectiveExpiry { row("Verwenden bis", effective.formatted(date: .long, time: .omitted)) }
                if item.expiryDate == nil && item.openedDate == nil { row("", "Keine Angaben") }
            }
            if !item.notes.isEmpty {
                Text(item.notes).font(.subheadline).foregroundStyle(Theme.inkSoft).padding(.top, 4)
            }
        }
        .card()
    }

    @ViewBuilder
    private func linked(_ item: CabinetItem) -> some View {
        let meds = store.linkedMedications(of: item)
        VStack(alignment: .leading, spacing: 10) {
            Text("Wird verwendet für").font(Theme.title(18))
            if meds.isEmpty {
                Text("Noch mit keinem Medikament verknüpft. Öffne beim Tier das Medikament und wähle diesen Artikel aus.")
                    .font(.subheadline).foregroundStyle(Theme.inkSoft)
            }
            ForEach(meds, id: \.med.id) { link in
                HStack {
                    PetAvatar(pet: link.pet, size: 30)
                    VStack(alignment: .leading) {
                        Text("\(link.med.title) · \(link.pet.name)").font(.subheadline.weight(.semibold))
                        Text(scheduleText(link.med, item: item)).font(.caption).foregroundStyle(Theme.inkSoft)
                    }
                }
            }
        }
        .card()
    }

    private func scheduleText(_ med: CareEntry, item: CabinetItem) -> String {
        let amount = med.effectiveDoseAmount.map(item.formatted) ?? "?"
        guard let reminder = med.reminder else { return "\(amount) bei Bedarf" }
        return "\(amount) um " + reminder.allTimes.map(\.label).joined(separator: " & ")
    }

    private func history(_ item: CabinetItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Verlauf").font(Theme.title(18))
            if item.history.isEmpty {
                Text("Noch keine Buchungen.").font(.subheadline).foregroundStyle(Theme.inkSoft)
            }
            ForEach(item.history.prefix(30)) { event in
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(event.note ?? event.kind.label).font(.subheadline)
                        Text(event.date.formatted(.dateTime.day().month().hour().minute()))
                            .font(.caption).foregroundStyle(Theme.inkSoft)
                    }
                    Spacer()
                    Text((event.delta > 0 ? "+" : "−") + item.formatted(abs(event.delta)))
                        .font(Theme.number(.subheadline))
                        .foregroundStyle(event.delta > 0 ? Theme.leaf : Theme.inkSoft)
                }
                if event.id != item.history.prefix(30).last?.id { Divider() }
            }
        }
        .card()
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).font(.subheadline).foregroundStyle(Theme.inkSoft)
            Text(value).font(.subheadline)
        }
    }
}

// MARK: - Sheets

private struct StockCorrectionSheet: View {
    @Environment(PetStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let item: CabinetItem
    @State private var amount: Double

    init(item: CabinetItem) {
        self.item = item
        _amount = State(initialValue: item.stock)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Bestand", value: $amount, format: .number)
                            .keyboardType(.decimalPad)
                            .font(Theme.number(.title))
                        Text(item.form.unit).foregroundStyle(Theme.inkSoft)
                    }
                    Stepper("In \(item.formatted(item.form.step))-Schritten", value: $amount, in: 0...10_000, step: item.form.step)
                } footer: {
                    Text("Zum Beispiel nach dem Nachmessen der Flasche. Die Korrektur erscheint im Verlauf.")
                }
            }
            .navigationTitle("Bestand korrigieren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen", role: .cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", role: .confirm) { store.correctStock(item, to: amount); dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct RefillSheet: View {
    @Environment(PetStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let item: CabinetItem
    @State private var amount: Double
    @State private var hasExpiry = false
    @State private var expiry = Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now

    init(item: CabinetItem) {
        self.item = item
        _amount = State(initialValue: item.packageSize)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Neue Packung") {
                    HStack {
                        TextField("Menge", value: $amount, format: .number)
                            .keyboardType(.decimalPad)
                            .font(Theme.number(.title))
                        Text(item.form.unit).foregroundStyle(Theme.inkSoft)
                    }
                    Toggle("Neues Ablaufdatum", isOn: $hasExpiry)
                    if hasExpiry {
                        DatePicker("Haltbar bis", selection: $expiry, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("Nachfüllen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen", role: .cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Einbuchen", role: .confirm) {
                        store.refill(item, amount: amount, newExpiry: hasExpiry ? expiry : nil)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
