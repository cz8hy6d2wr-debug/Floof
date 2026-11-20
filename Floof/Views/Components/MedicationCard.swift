import SwiftUI

/// Abhakbare Medikamentenkarte. `style` steuert die Größe:
/// `.large` für das Außendisplay (Daumen-Ziel, ganze Karte tippbar),
/// `.row` für die Checkliste auf dem Innendisplay.
struct MedicationCard: View {
    enum Style { case large, row }

    @Environment(PetStore.self) private var store
    let dose: ScheduledDose
    var style: Style = .large
    var showsPet = true

    private var taken: Bool { store.isTaken(dose) }

    var body: some View {
        Button {
            store.toggle(dose)
        } label: {
            HStack(spacing: style == .large ? 16 : 12) {
                checkmark
                VStack(alignment: .leading, spacing: 4) {
                    Text(dose.medication.title)
                        .font(style == .large ? .title2.bold() : .headline)
                        .strikethrough(taken)
                    Text(dosageLine)
                        .font(style == .large ? .body : .subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    if showsPet {
                        Label(dose.pet.name, systemImage: "pawprint.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(dose.pet.tint)
                    }
                }
                Spacer(minLength: 8)
                timeBadge
            }
            .padding(style == .large ? 20 : 14)
            .frame(maxWidth: .infinity, minHeight: style == .large ? 104 : 64, alignment: .leading)
            .background(background)
            .contentShape(.rect(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: taken) { _, new in new }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(dose.medication.title) für \(dose.pet.name) um \(dose.time.label)")
        .accessibilityValue(taken ? "Gegeben" : "Offen")
        .accessibilityAddTraits(taken ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint("Doppeltippen zum Abhaken")
    }

    private var dosageLine: String {
        // Erste Zeile der Details = Standarddosis ("0,35ml im Alltag")
        dose.medication.details.split(separator: "\n").first.map(String.init) ?? ""
    }

    private var checkmark: some View {
        Image(systemName: taken ? "checkmark.circle.fill" : "circle")
            .font(.system(size: style == .large ? 44 : 28, weight: .semibold))
            .foregroundStyle(taken ? Color.green : dose.pet.tint)
            .contentTransition(.symbolEffect(.replace))
    }

    private var timeBadge: some View {
        Text(dose.time.label)
            .font((style == .large ? Font.title3 : .subheadline).monospacedDigit().bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(timeColor.opacity(0.15), in: Capsule())
            .foregroundStyle(timeColor)
    }

    private var timeColor: Color {
        if taken { return .green }
        return dose.isOverdue ? .orange : .secondary
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(taken ? AnyShapeStyle(Color.green.opacity(0.12)) : AnyShapeStyle(BackgroundStyle()))
            .overlay {
                if dose.isOverdue && !taken {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(.orange.opacity(0.6), lineWidth: 2)
                }
            }
    }
}
