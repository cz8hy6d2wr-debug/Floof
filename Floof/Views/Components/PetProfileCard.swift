import SwiftUI

/// Stammdaten des Tieres (Innendisplay, linke Spalte).
struct PetProfileCard: View {
    let pet: Pet

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                PetAvatar(pet: pet, size: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pet.name).font(.title2.bold())
                    Text("\(pet.breed) · \(pet.ageDescription)")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if let check = pet.dailyChecks.max(by: { $0.id < $1.id }) {
                    Label(check.need.label, systemImage: "circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(check.need.color)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(check.need.color.opacity(0.15), in: Capsule())
                }
            }

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 8) {
                row("Geburtstag", pet.birthday.formatted(date: .long, time: .omitted))
                if let w = pet.latestWeight { row("Gewicht", "\(w.grams) g") }
                ForEach(infoRows, id: \.0) { row($0.0, $0.1) }
            }

            if !pet.conditions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Erkrankungen").font(.caption.bold()).foregroundStyle(.secondary)
                    FlowChips(items: pet.conditions.map(\.title))
                }
            }
        }
        .card()
    }

    private var infoRows: [(String, String)] {
        [("Zähne", "teeth"), ("Krallen", "claws"), ("Fütterung", "feeding"), ("Partner", "companions")]
            .compactMap { label, key in pet.info(key).map { (label, $0) } }
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
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
                .background(.red.opacity(0.12), in: Capsule())
                .foregroundStyle(.red)
        }
    }
}
