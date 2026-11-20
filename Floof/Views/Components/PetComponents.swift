import SwiftUI

// MARK: - Farben

extension Pet {
    var tint: Color {
        let palette: [Color] = [.red, .orange, .yellow, .brown, .green, .mint,
                                .teal, .cyan, .blue, .indigo, .purple, .pink]
        return palette[((color % palette.count) + palette.count) % palette.count]
    }
}

extension DailyCheck.Need {
    var color: Color {
        switch self {
        case .green: .green
        case .yellow: .yellow
        case .red: .red
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
            if let file = pet.photoFilename, let image = store.photos[file] {
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
                    Text(pet.name).font(.headline)
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
            Circle().stroke(.quaternary, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(progress >= 1 ? Color.green : .accentColor,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(progress, format: .percent.precision(.fractionLength(0)))
                .font(.caption.bold().monospacedDigit())
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
            .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}
