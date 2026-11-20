import SwiftUI

// MARK: - Farben

extension Pet {
    var tint: Color { Pet.tint(forColor: color) }

    static func tint(forColor color: Int) -> Color {
        // Erdige Töne statt Regenbogen – passend zum Fell, nicht zur Ampel.
        let palette: [Color] = [
            Color(light: 0xB5523B, dark: 0xE08A72),  // Rost
            Color(light: 0xC7743A, dark: 0xEBA06A),  // Terrakotta
            Color(light: 0xB98B2B, dark: 0xE2BC5E),  // Senf
            Color(light: 0x8A5A3B, dark: 0xC9946E),  // Zimt
            Color(light: 0x5D7F43, dark: 0x93BD73),  // Moos
            Color(light: 0x6E8F7C, dark: 0xA3C4B0),  // Salbei
            Color(light: 0x3F7F80, dark: 0x79B8B8),  // Petrol
            Color(light: 0x557A95, dark: 0x8FB3CE),  // Taubenblau
            Color(light: 0x45608A, dark: 0x8AA2CC),  // Jeans
            Color(light: 0x6A4F84, dark: 0xA990C4),  // Pflaume
            Color(light: 0x7E5A86, dark: 0xBD9AC6),  // Lavendel
            Color(light: 0xA85670, dark: 0xDB8FA6),  // Rosé
        ]
        return palette[((color % palette.count) + palette.count) % palette.count]
    }
}

extension DailyCheck.Need {
    var color: Color {
        switch self {
        case .green: Theme.leaf
        case .yellow: Theme.honey
        case .red: Theme.berry
        }
    }
    var label: String {
        switch self {
        case .green: "Alles gut"
        case .yellow: "Beobachten"
        case .red: "Tierarzt"
        }
    }
}

// MARK: - Avatar

struct PetAvatar: View {
    @Environment(PetStore.self) private var store
    let pet: Pet
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let image = store.photo(named: pet.photoFilename) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Text(pet.name.prefix(1))
                    .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(pet.tint.gradient)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(pet.tint, lineWidth: 2))
        .accessibilityHidden(true)
    }
}

// MARK: - Tier-Auswahl (Toolbar)

struct PetPickerMenu: View {
    @Environment(PetStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Menu {
            Picker("Tier", selection: $store.selectedPetID) {
                ForEach(store.pets) { pet in
                    Text(pet.name).tag(Optional(pet.id))
                }
            }
        } label: {
            if let pet = store.selectedPet {
                HStack(spacing: 8) {
                    PetAvatar(pet: pet, size: 28)
                    Text(pet.name).font(Theme.title(17)).foregroundStyle(Theme.ink)
                    Image(systemName: "chevron.down").font(.caption.bold())
                }
            }
        }
        .accessibilityLabel("Tier auswählen")
    }
}

// MARK: - Fortschrittsring

struct DoseProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle().stroke(Theme.sunken, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(progress >= 1 ? Theme.leaf : Theme.carrot,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(progress, format: .percent.precision(.fractionLength(0)))
                .font(Theme.number(.caption))
                .foregroundStyle(Theme.ink)
        }
        .animation(.smooth, value: progress)
        .accessibilityElement()
        .accessibilityLabel("Heute erledigt")
        .accessibilityValue(Text(progress, format: .percent))
    }
}

// MARK: - Karten-Hintergrund

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Theme.ink)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 0.5))
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}
