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
                        .font(Theme.title(style == .large ? 22 : 17))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(taken ? Theme.inkSoft : Theme.ink)
                        .strikethrough(taken, color: Theme.leaf)
                    Text(dosageLine)
                        .font(style == .large ? .body : .subheadline)
                        .foregroundStyle(Theme.inkSoft)
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
        .sensoryFeedback(.impact(weight: .medium), trigger: taken) { _, new in new }
        .overlay(alignment: .topTrailing) {
            // "+10" fliegt kurz aus der Karte, wenn abgehakt wird
            // Nur direkt nach dem Abhaken – nicht jedes Mal, wenn die Karte wieder erscheint.
            if taken, store.recentlyAwardedDoseID == dose.id, let points = store.game.awarded[dose.id] {
                PointsPop(points: points).offset(x: -16, y: -6)
            }
        }
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
            .foregroundStyle(taken ? Theme.leaf : dose.pet.tint)
            .contentTransition(.symbolEffect(.replace))
    }

    private var timeBadge: some View {
        Text(dose.time.label)
            .font(Theme.number(style == .large ? .title3 : .subheadline))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(timeColor.opacity(0.15), in: Capsule())
            .foregroundStyle(timeColor)
    }

    private var timeColor: Color {
        if taken { return Theme.leaf }
        return dose.isOverdue ? Theme.berry : Theme.inkSoft
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(taken ? Theme.leafWash : Theme.card)
            .overlay {
                if dose.isOverdue && !taken {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Theme.berry.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                }
            }
    }
}

/// Kleines "+10 🥕" das nach oben wegschwebt.
private struct PointsPop: View {
    let points: Int
    @State private var shown = false

    var body: some View {
        Label("+\(points)", systemImage: "carrot.fill")
            .font(Theme.number(.caption))
            .foregroundStyle(Theme.carrot)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Theme.card, in: Capsule())
            .offset(y: shown ? -18 : 0)
            .opacity(shown ? 0 : 1)
            .onAppear { withAnimation(.easeOut(duration: 1.1).delay(0.2)) { shown = true } }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
