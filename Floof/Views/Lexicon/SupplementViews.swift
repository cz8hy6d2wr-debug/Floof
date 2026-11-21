import SwiftUI

/// RodiCare-Übersicht, sortiert nach Anwendungsgebiet.
struct SupplementListView: View {
    @State private var query = ""

    var body: some View {
        let results = Supplements.products.filter { $0.matches(search: query) }

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    HandTitle(text: "RodiCare-Mittel", size: 28)
                    Text("Ergänzungsfuttermittel von alfavet – wofür sie gedacht sind.")
                        .font(.callout).foregroundStyle(Theme.inkSoft)
                        .padding(.top, 2)
                }
                .padding(.top, 4)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.inkSoft)
                    TextField("Mittel oder Beschwerde, z. B. Verdauung", text: $query)
                    if !query.isEmpty {
                        Button("Leeren", systemImage: "xmark.circle.fill") { query = "" }
                            .labelStyle(.iconOnly)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 11)
                .glassEffect(.regular.interactive(), in: .capsule)

                if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                }

                ForEach(SupplementArea.allCases) { area in
                    let items = results.filter { $0.area == area }
                    if !items.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(area.rawValue, systemImage: area.symbol)
                                .font(Theme.title(18))
                            ForEach(items) { SupplementRow(product: $0) }
                        }
                        .card()
                    }
                }

                Text(Supplements.source)
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
}

struct SupplementRow: View {
    @Environment(LexiconNavigator.self) private var navigator
    let product: SupplementProduct

    var body: some View {
        Button { navigator.open(.supplement(product.id)) } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(product.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                        if !product.forRabbits {
                            Text("nicht für Kaninchen")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Theme.berry)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Theme.berry.opacity(0.12), in: Capsule())
                        }
                    }
                    Text(product.purpose).font(.caption).foregroundStyle(Theme.inkSoft).lineLimit(2)
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

struct SupplementDetailView: View {
    let product: SupplementProduct

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Label(product.area.rawValue, systemImage: product.area.symbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.carrot)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Theme.carrot.opacity(0.14), in: Capsule())

                HandTitle(text: product.name, size: 28)
                    .fixedSize(horizontal: false, vertical: true)

                Text(product.purpose)
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(Theme.ink.opacity(0.85))
                    .padding(.top, 4)

                if let note = product.note {
                    Label(note, systemImage: product.forRabbits ? "info.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(product.forRabbits ? Theme.ink : Theme.berry)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background((product.forRabbits ? Theme.honey : Theme.berry).opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Laut Hersteller").font(Theme.title(19))
                    ForEach(product.highlights, id: \.self) { item in
                        Label(item, systemImage: "checkmark")
                            .font(.body)
                            .labelStyle(BulletLabelStyle())
                    }
                    Divider().padding(.vertical, 4)
                    LabeledContent("Packung", value: product.packaging)
                        .font(.subheadline)
                }
                .card()

                if let url = product.url {
                    Link(destination: url) {
                        Label("Beim Hersteller ansehen", systemImage: "arrow.up.right.square")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.glass)
                }

                Label(Supplements.source, systemImage: "info.circle")
                    .font(.caption).foregroundStyle(Theme.inkSoft)
            }
            .padding(.vertical, 12)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .ambientBackground()
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            configuration.icon.font(.caption.bold()).foregroundStyle(Theme.leaf)
            configuration.title
        }
    }
}

/// Teaser auf der Lexikon-Übersicht.
struct SupplementTeaser: View {
    @Environment(LexiconNavigator.self) private var navigator

    var body: some View {
        Button { navigator.open(.supplements) } label: {
            HStack(spacing: 14) {
                Image(systemName: "cross.vial.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.leaf)
                    .frame(width: 50, height: 50)
                    .background(Theme.leaf.opacity(0.14), in: Circle())
                    .rotationEffect(.degrees(8))
                VStack(alignment: .leading, spacing: 2) {
                    Text("RodiCare-Mittel").font(Theme.title(18))
                    Text("\(Supplements.products.count) Ergänzungsmittel – wofür sie gut sind")
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
