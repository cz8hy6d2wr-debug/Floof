import SwiftUI

/// Stammdaten des Tieres (Innendisplay, linke Spalte).
struct PetProfileCard: View {
    let pet: Pet

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Breit: Status-Kapsel rechts daneben. Schmal: darunter, damit Name und Rasse Platz haben.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) {
                    PetAvatar(pet: pet, size: 64)
                    identity
                    Spacer(minLength: 8)
                    statusBadge
                }
                HStack(alignment: .top, spacing: 14) {
                    PetAvatar(pet: pet, size: 56)
                    VStack(alignment: .leading, spacing: 8) {
                        identity
                        statusBadge
                    }
                    Spacer(minLength: 0)
                }
            }

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 8) {
                row("Geburtstag", pet.birthday.formatted(date: .long, time: .omitted))
                if let w = pet.latestWeight { row("Gewicht", "\(w.grams.formatted()) g") }
                ForEach(infoRows, id: \.0) { row($0.0, $0.1) }
            }

            if !pet.conditions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Worauf wir achten").font(.caption.bold()).foregroundStyle(Theme.inkSoft)
                    FlowChips(items: pet.conditions.map(\.title))
                }
            }
        }
        .card()
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(pet.name).font(Theme.title(24))
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(pet.breed.isEmpty ? pet.animalType : pet.breed)
                .font(.subheadline).foregroundStyle(Theme.inkSoft)
                .lineLimit(1).minimumScaleFactor(0.85)
            Text(pet.ageDescription)
                .font(.subheadline).foregroundStyle(Theme.inkSoft)
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if let check = pet.dailyChecks.max(by: { $0.id < $1.id }) {
            Label(check.need.label, systemImage: "circle.fill")
                .labelStyle(DotLabelStyle())
                .font(.caption.bold())
                .foregroundStyle(check.need.color)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(check.need.color.opacity(0.15), in: Capsule())
                .fixedSize()
        }
    }

    private var infoRows: [(String, String)] {
        [("Zähne", "teeth"), ("Krallen", "claws"), ("Fütterung", "feeding"), ("Partner", "companions")]
            .compactMap { label, key in pet.info(key).map { (label, $0) } }
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).font(.subheadline).foregroundStyle(Theme.inkSoft)
            Text(value).font(.subheadline)
        }
    }
}

private struct FlowChips: View {
    let items: [String]
    var body: some View {
        ViewThatFits {
            HStack { chips }
            VStack(alignment: .leading) { chips }
        }
    }
    @ViewBuilder private var chips: some View {
        ForEach(items, id: \.self) { item in
            Text(item)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Theme.berry.opacity(0.12), in: Capsule())
                .foregroundStyle(Theme.berry)
        }
    }
}

private struct DotLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon.font(.system(size: 7))
            configuration.title
        }
    }
}
