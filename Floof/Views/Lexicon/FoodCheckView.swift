import SwiftUI

/// "Darf mein Kaninchen das?" – schnelle Suche mit Ampel.
struct FoodCheckView: View {
    @State private var query = ""
    @State private var filter: FoodItem.Verdict?
    @FocusState private var searchFocused: Bool
    @Namespace private var glass

    private var results: [FoodItem] {
        Lexicon.foods.filter { item in
            (filter == nil || item.verdict == filter)
                && (query.isEmpty || item.name.localizedCaseInsensitiveContains(query)
                    || item.note.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HandTitle(text: "Darf mein Kaninchen das?", size: 26)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)

                // Gläsernes Suchfeld + Ampel-Filter
                GlassEffectContainer(spacing: 8) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass").foregroundStyle(Theme.inkSoft)
                            TextField("Futter oder Pflanze", text: $query)
                                .focused($searchFocused)
                                .submitLabel(.search)
                            if !query.isEmpty {
                                Button("Leeren", systemImage: "xmark.circle.fill") { query = "" }
                                    .labelStyle(.iconOnly)
                                    .foregroundStyle(Theme.inkSoft)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .glassEffect(.regular.interactive(), in: .capsule)

                        HStack(spacing: 8) {
                            chip(nil, label: "Alle", color: Theme.carrot)
                            ForEach(FoodItem.Verdict.allCases) { verdict in
                                chip(verdict, label: verdict == .toxic ? "Giftig" : verdict.rawValue, color: verdict.color)
                            }
                        }
                    }
                }

                if results.isEmpty {
                    ContentUnavailableView {
                        Label("Nicht in der Liste", systemImage: "questionmark.circle")
                    } description: {
                        Text("Im Zweifel nicht füttern und beim Tierarzt nachfragen.")
                    }
                } else {
                    ForEach(FoodItem.Verdict.allCases) { verdict in
                        let items = results.filter { $0.verdict == verdict }
                        if !items.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Label(verdict.rawValue, systemImage: verdict.symbol)
                                    .font(Theme.title(18))
                                    .foregroundStyle(verdict.color)
                                ForEach(items) { FoodRow(food: $0) }
                            }
                            .card()
                        }
                    }
                }

                Text("Neues Futter immer langsam einführen. Pflanzen nur ungespritzt und abseits von Straßen sammeln.")
                    .font(.caption).foregroundStyle(Theme.inkSoft)
            }
            .padding(.vertical, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .ambientBackground()
        .navigationBarTitleDisplayMode(.inline)
    }

    private func chip(_ verdict: FoodItem.Verdict?, label: String, color: Color) -> some View {
        let selected = filter == verdict
        return Button {
            withAnimation(.snappy) { filter = verdict }
        } label: {
            Text(label)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? Theme.ink : Theme.inkSoft)
                .padding(.horizontal, 12).padding(.vertical, 7)
        }
        .buttonStyle(.plain)
        .glassEffect(selected ? .regular.tint(color.opacity(0.28)).interactive() : .regular.interactive(), in: .capsule)
        .glassEffectID(verdict?.rawValue ?? "alle", in: glass)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct FoodRow: View {
    let food: FoodItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: food.verdict.symbol)
                .foregroundStyle(food.verdict.color)
                .font(.body)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(food.name).font(.subheadline.weight(.semibold))
                if !food.note.isEmpty {
                    Text(food.note).font(.caption).foregroundStyle(Theme.inkSoft)
                }
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(food.verdict.rawValue)
    }
}
