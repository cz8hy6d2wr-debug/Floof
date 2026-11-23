import SwiftUI

/// Gläserne Tier-Auswahl ("Alle" + jedes Tier). Die Glas-Kapseln verschmelzen
/// beim Wechsel miteinander (GlassEffectContainer + glassEffectID).
struct PetFilterBar: View {
    @Environment(PetStore.self) private var store
    @Binding var selection: Pet.ID?
    var includesAll = true
    @Namespace private var glass

    var body: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    if includesAll {
                        chip(id: nil) {
                            Label("Alle", systemImage: "pawprint.fill").labelStyle(.titleAndIcon)
                        }
                    }
                    ForEach(store.pets) { pet in
                        chip(id: pet.id, tint: pet.tint) {
                            HStack(spacing: 6) {
                                PetAvatar(pet: pet, size: 22)
                                Text(pet.name)
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .scrollIndicators(.hidden)
    }

    private func chip<Content: View>(id: Pet.ID?, tint: Color = Theme.carrot,
                                     @ViewBuilder label: () -> Content) -> some View {
        let selected = selection == id
        return Button {
            withAnimation(.snappy) { selection = id }
        } label: {
            label()
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? Theme.ink : Theme.inkSoft)
                .padding(.horizontal, 12).padding(.vertical, 7)
        }
        .buttonStyle(.plain)
        .glassEffect(selected ? .regular.tint(tint.opacity(0.28)).interactive() : .regular.interactive(), in: .capsule)
        .glassEffectID(id ?? "all", in: glass)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
