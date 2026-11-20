import SwiftUI
import PhotosUI

/// Foto auswählen/entfernen. Speichert verkleinert und liefert den Dateinamen.
struct PhotoField: View {
    @Environment(PetStore.self) private var store
    @Binding var filename: String?
    var title = "Foto hinzufügen"
    @State private var selection: PhotosPickerItem?
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let image = store.photo(named: filename) {
                Image(uiImage: image)
                    .resizable().scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        Button("Foto entfernen", systemImage: "xmark") { filename = nil }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.glass)
                            .buttonBorderShape(.circle)
                            .padding(8)
                    }
            }
            PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
                Label(filename == nil ? title : "Anderes Foto", systemImage: "photo.on.rectangle.angled")
            }
            .overlay(alignment: .trailing) { if isLoading { ProgressView() } }
        }
        .onChange(of: selection) { _, item in
            guard let item else { return }
            isLoading = true
            Task {
                defer { isLoading = false; selection = nil }
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    filename = store.storePhoto(image)
                }
            }
        }
    }
}
