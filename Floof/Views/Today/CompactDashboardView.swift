import SwiftUI

/// Außendisplay (5,4"): Einhand-Dashboard mit Fokus auf die heutigen Medikamente.
/// Die wichtigste Aktion ("Gegeben") liegt in der gläsernen Leiste über den Tabs – im Daumenbereich.
struct CompactDashboardView: View {
    @Environment(PetStore.self) private var store

    var body: some View {
        let doses = store.todaysDoses()
        let open = doses.filter { !store.isTaken($0) }

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header(open: open, doses: doses)
                    .padding(.top, 4)
                    .padding(.bottom, 6)

                StreakStrip()

                if doses.isEmpty {
                    ContentUnavailableView("Heute nichts zu geben", systemImage: "leaf",
                                           description: Text("Genieß den Tag mit deinen Tieren."))
                } else {
                    ForEach(doses) { dose in
                        MedicationCard(dose: dose, style: .large)
                    }
                }

                AsNeededSection()
                DailyCheckCard()
                CabinetAlertCard()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .foldedReadableWidth()
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func header(open: [ScheduledDose], doses: [ScheduledDose]) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.inkSoft)
                HandTitle(text: Greeting.now)
                Text(Greeting.status(open: open, pets: store.pets))
                    .font(.callout)
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
            DoseProgressRing(progress: store.progress(doses), lineWidth: 6)
                .frame(width: 54, height: 54)
        }
    }
}

/// Texte, die nach Mensch klingen statt nach System.
enum Greeting {
    static var now: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<11: "Guten Morgen"
        case 11..<17: "Hallo am Mittag"
        case 17..<22: "Guten Abend"
        default: "Noch wach?"
        }
    }

    static func status(open: [ScheduledDose], pets: [Pet]) -> String {
        guard let next = open.first else {
            return pets.count == 1 ? "Alles gegeben. \(pets[0].name) ist versorgt."
                                   : "Alles gegeben. Feierabend für euch alle."
        }
        if next.isOverdue { return "\(next.pet.name) wartet noch auf \(next.medication.title)." }
        return open.count == 1 ? "Noch eine Gabe heute, um \(next.time.label)."
                               : "Noch \(open.count) Gaben, die nächste um \(next.time.label)."
    }
}

/// Medikamente ohne festen Zeitplan ("bei Bedarf") – mit Gegeben-Knopf, der Lager & Tagebuch pflegt.
struct AsNeededSection: View {
    @Environment(PetStore.self) private var store
    var pet: Pet? = nil   // nil = alle Tiere

    var body: some View {
        let items = (pet.map { [$0] } ?? store.pets)
            .flatMap { p in p.medications.filter(\.isAsNeeded).map { (p, $0) } }

        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Wenn nötig").font(Theme.title(18))
                ForEach(items, id: \.1.id) { item in
                    HStack(spacing: 10) {
                        Image(systemName: "pills").foregroundStyle(item.0.tint)
                        VStack(alignment: .leading) {
                            Text(item.1.title).font(.subheadline.weight(.semibold))
                            Text(pet == nil ? "\(item.0.name) · \(item.1.details)" : item.1.details)
                                .font(.caption).foregroundStyle(Theme.inkSoft)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button("Gegeben") { store.logAsNeeded(item.1, for: item.0) }
                            .buttonStyle(.glass)
                            .controlSize(.small)
                    }
                }
            }
            .card()
        }
    }
}

/// "Wie geht's heute?" – Ampel je Tier, ein Tipp genügt.
struct DailyCheckCard: View {
    @Environment(PetStore.self) private var store
    @Namespace private var glass

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wie geht's heute?").font(Theme.title(18))
            ForEach(store.pets) { pet in
                let today = pet.dailyChecks.first { $0.id == DoseKey.day(.now) }?.need
                HStack {
                    PetAvatar(pet: pet, size: 30)
                    Text(pet.name).font(.subheadline.weight(.semibold))
                    Spacer()
                    GlassEffectContainer(spacing: 6) {
                        HStack(spacing: 6) {
                            ForEach([DailyCheck.Need.green, .yellow, .red], id: \.self) { need in
                                Button {
                                    withAnimation(.bouncy) { store.setDailyCheck(need, for: pet.id) }
                                } label: {
                                    Circle().fill(need.color)
                                        .frame(width: today == need ? 18 : 12, height: today == need ? 18 : 12)
                                        .frame(width: 34, height: 34)
                                }
                                .buttonStyle(.plain)
                                .glassEffect(today == need ? .regular.tint(need.color.opacity(0.3)).interactive()
                                                           : .regular.interactive(), in: .circle)
                                .glassEffectID("\(pet.id)-\(need.rawValue)", in: glass)
                                .accessibilityLabel(need.label)
                                .accessibilityAddTraits(today == need ? .isSelected : [])
                            }
                        }
                    }
                }
            }
        }
        .card()
    }
}

/// Hinweis, wenn im Schrank etwas knapp wird oder abläuft.
struct CabinetAlertCard: View {
    @Environment(PetStore.self) private var store

    var body: some View {
        let alerts = store.cabinetAlerts
        if !alerts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label("Im Schrank wird's knapp", systemImage: "cross.case.fill")
                    .font(Theme.title(18))
                    .foregroundStyle(Theme.berry)
                ForEach(alerts) { item in
                    HStack {
                        Text(item.name).font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(CabinetStatusText.short(store.status(of: item)))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
            }
            .card()
        }
    }
}
