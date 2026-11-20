import SwiftUI

enum AppTab: Hashable {
    case today, diary, cabinet, pets, lexicon
}

/// Hauptnavigation.
///
/// Liquid Glass: Die Tab-Leiste ist systemseitig aus Glas, schrumpft beim Scrollen
/// (`tabBarMinimizeBehavior`) und trägt darüber eine gläserne Zusatzleiste mit der
/// nächsten fälligen Gabe (`tabViewBottomAccessory`).
///
/// Faltzustand: Die Größe wird hier einmal gemessen und als `devicePosture` an alle
/// Tabs weitergegeben. Jeder Tab hat genau einen NavigationStack, dessen Inhalt beim
/// Falten wechselt – Auswahl, geöffnete Details und offene Editoren bleiben erhalten.
struct RootTabView: View {
    @Environment(PetStore.self) private var store
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var tab: AppTab = .today
    @State private var size: CGSize = .zero

    var body: some View {
        let posture = DevicePosture.resolve(size: size, horizontalSizeClass: horizontalSizeClass)

        TabView(selection: $tab) {
            Tab("Heute", systemImage: "sun.horizon", value: AppTab.today) {
                TodayView()
            }
            Tab("Tagebuch", systemImage: "book.closed", value: AppTab.diary) {
                DiaryView()
            }
            Tab("Schrank", systemImage: "cross.case", value: AppTab.cabinet) {
                CabinetView()
            }
            .badge(store.cabinetAlerts.count)
            Tab("Tiere", systemImage: "pawprint", value: AppTab.pets) {
                PetsView()
            }
            Tab("Lexikon", systemImage: "books.vertical", value: AppTab.lexicon) {
                LexiconView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            NextDoseAccessory()
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .environment(\.devicePosture, posture)
        .animation(.smooth(duration: 0.35), value: posture)
        .celebrations(store)
        .overlay(alignment: .top) { ToastView() }
        // Empfangene .floof-Dateien (AirDrop, Dateien-App, Nachrichten) öffnen hier.
        .onOpenURL { url in
            guard url.isFileURL else { return }
            do { store.pendingImport = try PendingImport(url: url) }
            catch { store.showToast("Datei konnte nicht gelesen werden") }
        }
        .sheet(item: Binding(get: { store.pendingImport }, set: { store.pendingImport = $0 })) {
            ImportReviewSheet(pending: $0)
        }
        .animation(.spring(duration: 0.35), value: store.toast)
    }
}

/// Gläserne Leiste über den Tabs: nächste offene Gabe mit einem Tipp erledigen.
/// Eingeklappt (beim Scrollen) zeigt sie nur das Nötigste.
private struct NextDoseAccessory: View {
    @Environment(PetStore.self) private var store
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        if let dose = store.nextOpenDose {
            HStack(spacing: 10) {
                PetAvatar(pet: dose.pet, size: 28)
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(dose.medication.title) · \(dose.pet.name)")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if placement != .inline {
                        Text(dose.isOverdue ? "seit \(dose.time.label) Uhr fällig" : "um \(dose.time.label) Uhr")
                            .font(.caption)
                            .foregroundStyle(dose.isOverdue ? Theme.berry : Theme.inkSoft)
                    }
                }
                Spacer(minLength: 4)
                Button {
                    store.toggle(dose)
                } label: {
                    Label("Gegeben", systemImage: "checkmark")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.carrot)
            }
            .padding(.horizontal, 12)
            .accessibilityElement(children: .contain)
        } else {
            Label(store.todaysDoses().isEmpty ? "Heute keine Medikamente" : "Alles gegeben für heute",
                  systemImage: "checkmark.seal")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.leaf)
                .frame(maxWidth: .infinity)
        }
    }
}

/// Kurze gläserne Bestätigung am oberen Rand.
private struct ToastView: View {
    @Environment(PetStore.self) private var store

    var body: some View {
        if let text = store.toast {
            Label(text, systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16).padding(.vertical, 10)
                .glassEffect(.regular.tint(Theme.leaf.opacity(0.25)), in: .capsule)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .id(text)
        }
    }
}

#Preview("Zugeklappt") {
    RootTabView().environment(PetStore.preview)
}

#Preview("Aufgeklappt (4:3)", traits: .fixedLayout(width: 744, height: 992)) {
    RootTabView().environment(PetStore.preview)
}

#Preview("OLED-Dunkel") {
    RootTabView().environment(PetStore.preview).preferredColorScheme(.dark)
}
