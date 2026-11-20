import SwiftUI

/// Layout-Regeln für das faltbare iPhone.
enum FoldLayout {
    /// Abstand zwischen den zwei Spalten auf dem Innendisplay. Beide Spalten sind
    /// gleich breit, dadurch liegt dieser Zwischenraum genau über dem Falz –
    /// keine Karte, kein Text und kein Knopf läuft über die Knickstelle.
    static let hingeGutter: CGFloat = 32
    /// Gleicher Außenrand links und rechts, damit die Mitte wirklich die Mitte ist.
    static let outerMargin: CGFloat = 20
    /// Maximale Lesebreite auf dem Außendisplay (relevant im Querformat).
    static let foldedMaxWidth: CGFloat = 560
}

/// Zwei gleich breite Spalten, deren Zwischenraum auf dem Falz liegt.
struct FoldColumns<Leading: View, Trailing: View>: View {
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .top, spacing: FoldLayout.hingeGutter) {
            leading.frame(maxWidth: .infinity)
            trailing.frame(maxWidth: .infinity)
        }
        .padding(.horizontal, FoldLayout.outerMargin)
    }
}

extension View {
    /// Begrenzt die Breite auf dem Außendisplay und zentriert den Inhalt –
    /// im Hochformat ohne Wirkung, im Querformat keine überlangen Karten.
    func foldedReadableWidth() -> some View {
        frame(maxWidth: FoldLayout.foldedMaxWidth)
            .frame(maxWidth: .infinity)
    }

    /// Editoren als kompaktes Formular statt bildschirmfüllend auf dem Innendisplay.
    func floofSheet() -> some View {
        presentationSizing(.form)
    }
}

/// `foldedReadableWidth()` nur zugeklappt anwenden.
struct FoldedWidth: ViewModifier {
    let isActive: Bool
    @ViewBuilder
    func body(content: Content) -> some View {
        if isActive { content.foldedReadableWidth() } else { content }
    }
}
