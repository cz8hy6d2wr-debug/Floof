import SwiftUI

extension EnvironmentValues {
    /// Öffnet ein Lexikon-Ziel im passenden Kontext (Spalte, Navigation oder Sheet).
    @Entry var openLexicon: (LexiconRoute) -> Void = { _ in }
}

/// Kaninchen-Lexikon: Notfall zuerst, dann Passendes zu den eigenen Tieren,
/// Futter-Check, Normalwerte, Themen und Merkliste. Durchsuchbar.
///
/// Zugeklappt: Liste → Artikel. Aufgeklappt: Liste | Artikel nebeneinander,
/// der Zwischenraum liegt auf dem Falz.
struct LexiconView: View {
    @Environment(PetStore.self) private var store
    @Environment(\.devicePosture) private var posture
    @State private var path: [LexiconRoute] = []
    @State private var selection: LexiconRoute = .article("not-fressen")
    @State private var search = ""

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if posture == .unfolded {
                    FoldColumns {
                        overview
                    } trailing: {
                        LexiconDestination(route: selection)
                            .id(selection)
                            .transition(.opacity)
                    }
                    .animation(.smooth, value: selection)
                } else {
                    overview
                        .padding(.horizontal, 16)
                        .foldedReadableWidth()
                }
            }
            .background(Theme.paper.ignoresSafeArea())
            .navigationDestination(for: LexiconRoute.self) { LexiconDestination(route: $0) }
            .searchable(text: $search, prompt: "Suchen, z. B. EC, Heu, Krallen")
        }
        .environment(\.openLexicon, open)
        .onChange(of: posture) { _, new in
            switch new {
            case .unfolded:
                if let last = path.last { selection = last }
                path = []
            case .folded:
                break   // zugeklappt startet das Lexikon in der Übersicht
            }
        }
    }

    private func open(_ route: LexiconRoute) {
        if posture == .unfolded { selection = route } else { path.append(route) }
    }

    private var overview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    HandTitle(text: "Lexikon", size: 32)
                    Text("Wissen rund ums Kaninchen – kurz, praktisch, mit Notfall-Hilfe.")
                        .font(.callout).foregroundStyle(Theme.inkSoft)
                        .padding(.top, 2)
                }
                .padding(.top, 4)

                if search.trimmingCharacters(in: .whitespaces).isEmpty {
                    EmergencyCard()
                    RelevantCard()
                    FoodCheckTeaser()
                    VitalsCard()
                    CategoryGrid()
                    BookmarksCard()
                } else {
                    SearchResults(query: search)
                }

                Text(Lexicon.disclaimer)
                    .font(.caption).foregroundStyle(Theme.inkSoft)
                    .padding(.top, 8)
            }
            .padding(.vertical, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }
}

/// Zeigt das Ziel einer Lexikon-Navigation.
struct LexiconDestination: View {
    let route: LexiconRoute

    var body: some View {
        switch route {
        case .article(let id):
            if let article = Lexicon.article(id) {
                ArticleView(article: article)
            } else {
                ContentUnavailableView("Artikel nicht gefunden", systemImage: "books.vertical")
            }
        case .foodCheck:
            FoodCheckView()
        case .category(let category):
            CategoryListView(category: category)
        }
    }
}

/// Artikel als eigenes Sheet mit eigener Navigation – z. B. aus der Tier-Ansicht heraus.
struct LexiconSheet: View {
    let start: LexiconRoute
    @State private var path: [LexiconRoute] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack(path: $path) {
            LexiconDestination(route: start)
                .navigationDestination(for: LexiconRoute.self) { LexiconDestination(route: $0) }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Schließen", role: .close) { dismiss() }
                    }
                }
        }
        .environment(\.openLexicon) { path.append($0) }
        .floofSheet()
    }
}

// MARK: - Bausteine der Übersicht

private struct EmergencyCard: View {
    @Environment(\.openLexicon) private var open

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Notfall?", systemImage: "cross.case.fill")
                .font(Theme.title(22))
                .foregroundStyle(Theme.berry)
            Text("Frisst nicht, atmet schwer, krampft oder kippt um? **Sofort Tierarzt oder Notdienst anrufen.** Hier steht, was du bis dahin tun kannst.")
                .font(.subheadline)
            ForEach(Lexicon.articles(in: .emergency)) { article in
                Button { open(.article(article.id)) } label: {
                    HStack {
                        Text(article.title).font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.bold())
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .background(Theme.berry.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(Theme.berry.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
    }
}

/// Artikel, die zu Medikamenten, Erkrankungen oder Notizen der eigenen Tiere passen.
private struct RelevantCard: View {
    @Environment(PetStore.self) private var store
    @Environment(\.openLexicon) private var open

    var body: some View {
        let items = Lexicon.relevant(for: store.pets).filter { $0.article.category != .emergency }
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Passend zu deinen Tieren").font(Theme.title(20))
                ForEach(items, id: \.article.id) { item in
                    Button { open(.article(item.article.id)) } label: {
                        HStack(spacing: 12) {
                            ArticleIcon(category: item.article.category)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.article.title).font(.subheadline.weight(.semibold))
                                Text(item.pets.map(\.name).joined(separator: " & "))
                                    .font(.caption).foregroundStyle(Theme.inkSoft)
                            }
                            Spacer()
                            HStack(spacing: -8) {
                                ForEach(item.pets) { PetAvatar(pet: $0, size: 26) }
                            }
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .card()
        }
    }
}

private struct FoodCheckTeaser: View {
    @Environment(\.openLexicon) private var open

    var body: some View {
        Button { open(.foodCheck) } label: {
            HStack(spacing: 14) {
                Image(systemName: "carrot.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.carrot)
                    .frame(width: 50, height: 50)
                    .background(Theme.carrot.opacity(0.14), in: Circle())
                    .rotationEffect(.degrees(-10))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Darf mein Kaninchen das?").font(Theme.title(18))
                    Text("\(Lexicon.foods.count) Futtermittel & Pflanzen auf einen Blick")
                        .font(.caption).foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(Theme.inkSoft)
            }
            .card()
        }
        .buttonStyle(.plain)
    }
}

private struct VitalsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Normalwerte").font(Theme.title(20))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(Lexicon.vitals) { vital in
                    VStack(alignment: .leading, spacing: 4) {
                        Label(vital.label, systemImage: vital.symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.inkSoft)
                        Text(vital.value).font(Theme.number(.subheadline))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Theme.sunken.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .card()
    }
}

private struct CategoryGrid: View {
    @Environment(\.openLexicon) private var open

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Themen").font(Theme.title(20))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                ForEach(LexiconCategory.allCases.filter { $0 != .emergency }) { category in
                    Button { open(.category(category)) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: category.symbol)
                                .font(.title3)
                                .foregroundStyle(category.tint)
                            Text(category.rawValue).font(.subheadline.weight(.semibold))
                            Text("\(Lexicon.articles(in: category).count) Artikel")
                                .font(.caption).foregroundStyle(Theme.inkSoft)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct BookmarksCard: View {
    @Environment(PetStore.self) private var store

    var body: some View {
        let saved = Lexicon.articles.filter { store.isBookmarked($0.id) }
        if !saved.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label("Gemerkt", systemImage: "bookmark.fill").font(Theme.title(20))
                ForEach(saved) { ArticleRow(article: $0) }
            }
            .card()
        }
    }
}

private struct SearchResults: View {
    let query: String

    var body: some View {
        let articles = Lexicon.articles.filter { $0.matches(search: query) }
        let foods = Lexicon.foods.filter { $0.name.localizedCaseInsensitiveContains(query) }

        VStack(alignment: .leading, spacing: 14) {
            if articles.isEmpty && foods.isEmpty {
                ContentUnavailableView.search(text: query)
            }
            if !articles.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Artikel").font(Theme.title(18))
                    ForEach(articles) { ArticleRow(article: $0) }
                }
                .card()
            }
            if !foods.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Futter-Check").font(Theme.title(18))
                    ForEach(foods) { FoodRow(food: $0) }
                }
                .card()
            }
        }
    }
}

// MARK: - Gemeinsame Bausteine

struct ArticleIcon: View {
    let category: LexiconCategory
    var body: some View {
        Image(systemName: category.symbol)
            .font(.subheadline)
            .foregroundStyle(category.tint)
            .frame(width: 36, height: 36)
            .background(category.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct ArticleRow: View {
    @Environment(\.openLexicon) private var open
    let article: LexiconArticle

    var body: some View {
        Button { open(.article(article.id)) } label: {
            HStack(alignment: .top, spacing: 12) {
                ArticleIcon(category: article.category)
                VStack(alignment: .leading, spacing: 2) {
                    Text(article.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    Text(article.summary).font(.caption).foregroundStyle(Theme.inkSoft).lineLimit(2)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(Theme.inkSoft)
                    .padding(.top, 4)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

struct CategoryListView: View {
    let category: LexiconCategory

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: category.symbol).font(.title).foregroundStyle(category.tint)
                    HandTitle(text: category.rawValue, size: 30)
                }
                .padding(.top, 4)
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Lexicon.articles(in: category)) { ArticleRow(article: $0) }
                }
                .card()
            }
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .background(Theme.paper)
        .navigationBarTitleDisplayMode(.inline)
    }
}
