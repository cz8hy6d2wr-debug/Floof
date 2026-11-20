import SwiftUI

struct ArticleView: View {
    @Environment(PetStore.self) private var store
    @Environment(\.openLexicon) private var open
    let article: LexiconArticle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Label(article.category.rawValue, systemImage: article.category.symbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(article.category.tint)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(article.category.tint.opacity(0.14), in: Capsule())

                HandTitle(text: article.title, size: 28)
                    .fixedSize(horizontal: false, vertical: true)

                Text(article.summary)
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(Theme.ink.opacity(0.85))
                    .padding(.top, 4)

                if !affectedPets.isEmpty {
                    HStack(spacing: 8) {
                        HStack(spacing: -8) { ForEach(affectedPets) { PetAvatar(pet: $0, size: 26) } }
                        Text("Betrifft \(affectedPets.map(\.name).joined(separator: " & "))")
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .glassEffect(.regular.tint(Theme.carrot.opacity(0.18)), in: .capsule)
                }

                ForEach(article.sections, id: \.self) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        if let heading = section.heading {
                            Text(heading).font(Theme.title(19))
                        }
                        Text(markdown(section.body))
                            .font(.body)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .card()
                }

                if !related.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Weiterlesen").font(Theme.title(18))
                        ForEach(related) { ArticleRow(article: $0) }
                    }
                    .card()
                }

                Label(Lexicon.disclaimer, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(.vertical, 12)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .background(Theme.paper)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ShareLink(item: shareText, subject: Text(article.title)) {
                    Label("Teilen", systemImage: "square.and.arrow.up")
                }
                Button {
                    withAnimation(.bouncy) { store.toggleBookmark(article.id) }
                } label: {
                    Label(store.isBookmarked(article.id) ? "Gemerkt" : "Merken",
                          systemImage: store.isBookmarked(article.id) ? "bookmark.fill" : "bookmark")
                }
                .sensoryFeedback(.selection, trigger: store.isBookmarked(article.id))
            }
        }
    }

    private var affectedPets: [Pet] {
        Lexicon.relevant(for: store.pets).first { $0.article.id == article.id }?.pets ?? []
    }

    private var related: [LexiconArticle] { article.related.compactMap(Lexicon.article) }

    private func markdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text,
                               options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }

    private var shareText: String {
        let body = article.sections
            .map { [$0.heading, $0.body.replacingOccurrences(of: "**", with: "")].compactMap { $0 }.joined(separator: "\n") }
            .joined(separator: "\n\n")
        return "\(article.title)\n\n\(article.summary)\n\n\(body)\n\n– aus dem Floof-Lexikon. \(Lexicon.disclaimer)"
    }
}
