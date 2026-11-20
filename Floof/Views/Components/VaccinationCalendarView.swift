import SwiftUI

struct VaccinationCalendarView: View {
    let pet: Pet

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Impfungen").font(Theme.title(20))

            if pet.vaccinations.isEmpty {
                ContentUnavailableView("Noch nichts eingetragen", systemImage: "syringe",
                                       description: Text("Bei Kaninchen üblich: RHD-1/RHD-2 und Myxomatose, einmal im Jahr. Trag die letzte Impfung ein, dann erinnern wir dich."))
                    .frame(minHeight: 180)
            } else {
                ForEach(pet.vaccinations) { vaccination in
                    VaccinationRow(vaccination: vaccination)
                    if vaccination.id != pet.vaccinations.last?.id { Divider() }
                }
            }
        }
        .card()
    }
}

private struct VaccinationRow: View {
    let vaccination: CareEntry

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(vaccination.date, format: .dateTime.month(.abbreviated))
                    .font(.caption2.bold()).textCase(.uppercase).foregroundStyle(Theme.carrot)
                Text(vaccination.date, format: .dateTime.day())
                    .font(Theme.number(.title3))
            }
            .frame(width: 48, height: 48)
            .background(Theme.sunken, in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(vaccination.title).font(.body.weight(.semibold))
                if !vaccination.details.isEmpty {
                    Text(vaccination.details).font(.caption).foregroundStyle(Theme.inkSoft)
                }
            }
            Spacer()
            if let due = vaccination.nextDueDate {
                dueBadge(due)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func dueBadge(_ due: Date) -> some View {
        let days = Calendar.current.dateComponents([.day], from: .now, to: due).day ?? 0
        let color: Color = days < 0 ? Theme.berry : (days < 30 ? Theme.honey : Theme.leaf)
        VStack(alignment: .trailing, spacing: 2) {
            Text(days < 0 ? "Überfällig" : "Fällig").font(.caption2).foregroundStyle(Theme.inkSoft)
            Text(due, format: .dateTime.day().month().year())
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(color)
        }
    }
}
