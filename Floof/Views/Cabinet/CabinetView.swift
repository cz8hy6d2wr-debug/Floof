import SwiftUI

/// Medikamentenschrank: was ist da, wie lange reicht es, was läuft ab.
/// Wird aus "Mehr" heraus geöffnet (der NavigationStack liegt dort).
struct CabinetView: View {
    @Environment(PetStore.self) private var store
    @Environment(\.devicePosture) private var posture
    @State private var showsNewItem = false
    @State private var filter: Filter = .all

    enum Filter: String, CaseIterable, Identifiable {
        case all = "Alle", attention = "Nachkaufen", scheduled = "Im Plan"
        var id: Self { self }
    }

    private var items: [CabinetItem] {
        let sorted = store.cabinet.sorted { lhs, rhs in
            (store.daysLeft(of: lhs) ?? .max, lhs.name) < (store.daysLeft(of: rhs) ?? .max, rhs.name)
        }
        switch filter {
        case .all: return sorted
        case .attention: return sorted.filter { store.status(of: $0).needsAttention }
        case .scheduled: return sorted.filter { store.dailyConsumption(of: $0) > 0 }
        }
    }

    var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    FilterChips(selection: $filter)

                    if store.cabinet.isEmpty {
                        ContentUnavailableView {
                            Label("Der Schrank ist leer", systemImage: "cross.case")
                        } description: {
                            Text("Leg deine Medikamente an und verknüpfe sie mit dem Plan – dann zählt Floof beim Abhaken automatisch mit.")
                        } actions: {
                            Button("Erstes Medikament", systemImage: "plus") { showsNewItem = true }
                                .buttonStyle(.glassProminent)
                        }
                    } else if items.isEmpty {
                        Text("Nichts zu tun – alles ist ausreichend da.")
                            .foregroundStyle(Theme.inkSoft)
                            .padding(.vertical, 24)
                    } else {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(items) { item in
                                NavigationLink(value: item.id) {
                                    CabinetItemCard(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, posture == .unfolded ? FoldLayout.outerMargin : 16)
                .padding(.bottom, 24)
                .modifier(FoldedWidth(isActive: posture == .folded))
            }
            .ambientBackground()
            .navigationDestination(for: CabinetItem.ID.self) { id in
                CabinetDetailView(itemID: id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Neu", systemImage: "plus") { showsNewItem = true }
                }
            }
            .sheet(isPresented: $showsNewItem) {
                CabinetItemEditor(item: CabinetItem(name: "", stock: 0, packageSize: 10), isNew: true)
            }
            .navigationTitle("Medikamentenschrank")
            .navigationBarTitleDisplayMode(.inline)
    }

    /// Aufgeklappt zwei gleich breite Spalten – der Spaltenabstand liegt auf dem Falz.
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: FoldLayout.hingeGutter), count: posture == .unfolded ? 2 : 1)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HandTitle(text: "Medikamentenschrank", size: 30)
            let alerts = store.cabinetAlerts.count
            Text(alerts == 0 ? "\(store.cabinet.count) Artikel, alles ausreichend da."
                             : "\(alerts) von \(store.cabinet.count) brauchen Aufmerksamkeit.")
                .font(.callout).foregroundStyle(Theme.inkSoft)
                .padding(.top, 2)
        }
        .padding(.top, 4)
    }
}

/// Gläserne Filter-Chips, die beim Wechsel ineinander fließen.
private struct FilterChips: View {
    @Binding var selection: CabinetView.Filter
    @Namespace private var glass

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(CabinetView.Filter.allCases) { filter in
                    Button(filter.rawValue) {
                        withAnimation(.bouncy) { selection = filter }
                    }
                    .font(.subheadline.weight(selection == filter ? .semibold : .regular))
                    .foregroundStyle(selection == filter ? Theme.ink : Theme.inkSoft)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .glassEffect(selection == filter ? .regular.tint(Theme.carrot.opacity(0.25)).interactive()
                                                     : .regular.interactive(), in: .capsule)
                    .glassEffectID(filter.rawValue, in: glass)
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
