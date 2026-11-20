import SwiftUI

struct VaccinationCalendarView: View {
    let pet: Pet

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Impfkalender", systemImage: "syringe.fill").font(.headline)

            if pet.vaccinations.isEmpty {
                ContentUnavailableView("Keine Impfungen eingetragen", systemImage: "calendar.badge.plus",
                                       description: Text("Für Kaninchen empfohlen: RHD-1/RHD-2 und Myxomatose, jährlich auffrischen."))
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
                    .font(.caption2.bold()).textCase(.uppercase).foregroundStyle(.red)
                Text(vaccination.date, format: .dateTime.day())
                    .font(.title3.bold().monospacedDigit())
            }
            .frame(width: 48, height: 48)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(vaccination.title).font(.body.weight(.semibold))
                if !vaccination.details.isEmpty {
                    Text(vaccination.details).font(.caption).foregroundStyle(.secondary)
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
        let color: Color = days < 0 ? .red : (days < 30 ? .orange : .green)
        VStack(alignment: .trailing, spacing: 2) {
            Text(days < 0 ? "Überfällig" : "Fällig").font(.caption2).foregroundStyle(.secondary)
            Text(due, format: .dateTime.day().month().year())
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(color)
        }
    }
}
