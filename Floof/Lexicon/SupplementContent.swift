import Foundation

/// Ein Ergänzungsfuttermittel (z. B. aus der RodiCare-Reihe).
struct SupplementProduct: Identifiable, Hashable {
    let id: String
    let name: String
    let area: SupplementArea
    /// Wofür der Hersteller das Mittel vorsieht – in eigenen Worten.
    let purpose: String
    /// Wichtigste Merkmale und Inhaltsstoffe laut Hersteller.
    let highlights: [String]
    let packaging: String
    /// Laut Hersteller für Kaninchen vorgesehen.
    var forRabbits = true
    var note: String?

    var url: URL? { URL(string: "https://alfavet.de/produkte/detail/\(id)") }

    func matches(search: String) -> Bool {
        let q = search.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return true }
        return name.lowercased().contains(q) || purpose.lowercased().contains(q)
            || area.rawValue.lowercased().contains(q)
            || highlights.contains { $0.lowercased().contains(q) }
    }

    /// Erkennt das Produkt in einem Freitext, z. B. im Namen eines Schrank-Artikels.
    func isMentioned(in text: String) -> Bool {
        let normalized = text.lowercased().replacingOccurrences(of: "®", with: "")
            .replacingOccurrences(of: "  ", with: " ")
        return normalized.contains(name.lowercased().replacingOccurrences(of: "®", with: ""))
    }
}

enum SupplementArea: String, CaseIterable, Identifiable {
    case digestion = "Verdauung & Darmflora"
    case feeding = "Päppeln & Appetit"
    case immune = "Immunsystem"
    case urinary = "Harnwege"
    case joints = "Gelenke & Senioren"
    case skin = "Haut, Fell & Krallen"
    case liver = "Leber"
    case airways = "Atemwege"
    case vitamins = "Vitamine"
    case other = "Sonstiges"

    var id: Self { self }

    var symbol: String {
        switch self {
        case .digestion: "leaf.fill"
        case .feeding: "syringe.fill"
        case .immune: "shield.fill"
        case .urinary: "drop.fill"
        case .joints: "figure.walk"
        case .skin: "sparkles"
        case .liver: "cross.vial.fill"
        case .airways: "lungs.fill"
        case .vitamins: "pills.fill"
        case .other: "shippingbox.fill"
        }
    }
}

/// RodiCare-Reihe von alfavet. Angaben in eigenen Worten nach den Produktseiten
/// des Herstellers (alfavet.de), Stand November 2026.
enum Supplements {
    static let brand = "RodiCare"
    static let source = "Angaben laut Hersteller alfavet (alfavet.de), Stand November 2026. Ergänzungsfuttermittel sind keine Arzneimittel – Dosierung laut Packung oder Tierarzt. Bei kranken Tieren immer zuerst tierärztlich abklären."

    static func product(_ id: String) -> SupplementProduct? { products.first { $0.id == id } }

    /// RodiCare-Produkte, die in einem Text vorkommen (z. B. Schrank-Artikel „RodiCare akut“).
    static func mentioned(in text: String) -> [SupplementProduct] {
        guard text.lowercased().contains("rodicare") else { return [] }
        // Längere Namen zuerst, damit „RodiCare Dia Bites“ nicht als „RodiCare Dia“ erkannt wird.
        let sorted = products.sorted { $0.name.count > $1.name.count }
        guard let best = sorted.first(where: { $0.isMentioned(in: text) }) else { return [] }
        return [best]
    }

    static let products: [SupplementProduct] = [
        // MARK: Verdauung & Darmflora
        SupplementProduct(
            id: "rodicare-akut", name: "RodiCare akut", area: .digestion,
            purpose: "Zur Regulierung der Verdauung – regt Appetit und Darmtätigkeit an.",
            highlights: ["Unterstützt die Darmflora", "Ergänzt eine kräuterarme Ernährung", "Ohne Zuckerzusatz"],
            packaging: "15 ml, flüssig"),
        SupplementProduct(
            id: "rodicare-dia", name: "RodiCare Dia", area: .digestion,
            purpose: "Unterstützt eine normale Verdauung.",
            highlights: ["Bentonit und Flohsamenschalen", "Kurzkettige Fettsäuren Butyrat und Propionat",
                         "Heidelbeeren und Brombeerblätter", "Ohne Zuckerzusatz"],
            packaging: "3 × 12 ml"),
        SupplementProduct(
            id: "rodicare-bac-pro", name: "RodiCare Bac Pro", area: .digestion,
            purpose: "Stärkt die Darmflora mit Postbiotika und beruhigt bzw. reguliert die Verdauung.",
            highlights: ["Unterstützt die Darmbarriere", "Fördert Immunsystem und Nährstoffaufnahme",
                         "Für Kaninchen und Meerschweinchen"],
            packaging: "3 × 12 ml"),
        SupplementProduct(
            id: "rodicare-hairball", name: "RodiCare Hairball", area: .digestion,
            purpose: "Beruhigt und entspannt den Darm; Flohsamenschalen binden viel Wasser und halten den Darminhalt geschmeidig.",
            highlights: ["Lactulose und Flohsamenschalen", "Fenchel, Kamille und Pfefferminze",
                         "Ohne Zucker und Getreide"],
            packaging: "3 × 12 ml oder 100 ml"),
        SupplementProduct(
            id: "rodicarebasic", name: "RodiCare basic", area: .digestion,
            purpose: "Pellets mit viel leicht verdaulicher Rohfaser und Kräutern, die die Verdauung fördern.",
            highlights: ["Kamille, Pfefferminze, Kurkuma, Süßholz, Kalmus, Fenchel, Kümmel, Bockshornklee"],
            packaging: "1 kg, 4 kg, 25 kg"),
        SupplementProduct(
            id: "rodicare-dia-bites", name: "RodiCare Dia Bites", area: .digestion,
            purpose: "Fördert die Verdauung – als Snack zum Verfüttern.",
            highlights: ["Schonend kaltgepresst", "Staubfrei und rohfaserreich"],
            packaging: "140 g"),

        // MARK: Päppeln & Appetit
        SupplementProduct(
            id: "rodicare-instant", name: "RodiCare instant", area: .feeding,
            purpose: "Päppelfutter zur Notfallversorgung, wenn ein Tier nicht frisst, und nach Zahnbehandlungen.",
            highlights: ["Alleinfuttermittel mit sehr viel Rohfaser", "Schnell verfügbare Energie",
                         "Kräutermischung fördert die Verdauung"],
            packaging: "20 g, 170 g, 60 × 20 g, 2 kg – zum Anrühren",
            note: "Ersetzt nicht den Tierarzt: Frisst ein Kaninchen nicht, ist das ein Notfall."),
        SupplementProduct(
            id: "rodicare-paeppelpaste", name: "RodiCare Päppelpaste", area: .feeding,
            purpose: "Gebrauchsfertige Paste zum gezielten Anfüttern – ohne Anrühren direkt einsetzbar.",
            highlights: ["Sichert die tägliche Nährstoffversorgung", "Zwei Injektoren à 30 ml",
                         "Für Kaninchen und Meerschweinchen"],
            packaging: "60 ml (2 × 30 ml)"),
        SupplementProduct(
            id: "rodicare-paeppelspritzen", name: "RodiCare Päppelspritzen", area: .feeding,
            purpose: "Eingabehilfe für angerührtes RodiCare instant.",
            highlights: ["Spritzen à 5 ml"],
            packaging: "10 Stück"),
        SupplementProduct(
            id: "rodicare-appetit", name: "RodiCare Appetit", area: .feeding,
            purpose: "Für Tiere, die schlecht fressen.",
            highlights: ["Mit Kalmus und Ingwer"],
            packaging: "15 ml"),

        // MARK: Immunsystem
        SupplementProduct(
            id: "rodicare-immun", name: "RodiCare Immun", area: .immune,
            purpose: "Pflanzliche Mischung zur Unterstützung des Immunsystems.",
            highlights: ["Kap-Pelargonienwurzel, Sonnenhut (Echinacea), Lebensbaum, Wasserdost, Taigawurzel, Efeuextrakt",
                         "Mumijo als Lieferant von Spurenelementen", "Ohne Zuckerzusatz"],
            packaging: "15 ml",
            note: "Enthält Extrakte aus Lebensbaum und Efeu, die als Pflanze für Kaninchen giftig sind. Im Präparat sind sie dosiert – deshalb nur in der angegebenen Menge geben."),
        SupplementProduct(
            id: "rodicare-immun-bites", name: "RodiCare Immun Bites", area: .immune,
            purpose: "Snack zur Stärkung des Immunsystems.",
            highlights: ["Fördert den natürlichen Zahnabrieb", "Ohne Getreide, Zuckerzusatz und Konservierungsmittel"],
            packaging: "140 g"),

        // MARK: Harnwege
        SupplementProduct(
            id: "rodicare-uro", name: "RodiCare uro", area: .urinary,
            purpose: "Unterstützt die Harnwege mit harntreibenden Beeren und Kräutern.",
            highlights: ["Goldrute, schwarze Johannisbeere, Ackerschachtelhalm, Birkenblätter, Hauhechel",
                         "Kürbiskern, Cranberry und Glucosamin", "Sehr wenig Calcium (0,02 %)", "Ohne Zuckerzusatz"],
            packaging: "20 ml"),
        SupplementProduct(
            id: "rodicare-uro-bites", name: "RodiCare Uro Bites", area: .urinary,
            purpose: "Snack zur Unterstützung der Harnwege.",
            highlights: ["Vitamin C als Zellschutz", "Brennnessel", "Staubfrei, rohfaserreich, fördert Zahnabrieb",
                         "Ohne Getreide, Zuckerzusatz und Konservierungsmittel"],
            packaging: "140 g"),

        // MARK: Gelenke & Senioren
        SupplementProduct(
            id: "rodicare-artrin", name: "RodiCare Artrin", area: .joints,
            purpose: "Versorgt die Gelenke mit Knorpelnährstoffen.",
            highlights: ["GAGs, Hyaluronsäure und MSM", "Teufelskralle und Weidenrinde", "Ohne Zuckerzusatz"],
            packaging: "50 ml"),
        SupplementProduct(
            id: "rodicare-senior", name: "RodiCare Senior", area: .joints,
            purpose: "Ergänzung für ältere Tiere mit Pflanzenstoffen und Gelenknährstoffen.",
            highlights: ["Ginseng, Ginkgo und Weißdorn", "GAGs und Weidenrinde", "Ohne Zuckerzusatz"],
            packaging: "20 ml"),

        // MARK: Haut, Fell & Krallen
        SupplementProduct(
            id: "rodicare-derma", name: "RodiCare Derma", area: .skin,
            purpose: "Unterstützt Haut, Haare und Krallen – z. B. im Fellwechsel.",
            highlights: ["Omega-3-Fettsäuren aus Algenöl", "Klettenlabkraut und Ackerschachtelhalm (Kieselsäure)",
                         "Zink, Selen und Biotin"],
            packaging: "50 ml"),

        // MARK: Leber
        SupplementProduct(
            id: "rodicare-hepato", name: "RodiCare Hepato", area: .liver,
            purpose: "Versorgt die Leber mit Nährstoffen und Pflanzenstoffen.",
            highlights: ["Mariendistel, Artischocke und Curcuma", "Bentonit", "Ohne Zuckerzusatz"],
            packaging: "20 ml"),

        // MARK: Atemwege
        SupplementProduct(
            id: "rodicare-pulmo", name: "RodiCare Pulmo", area: .airways,
            purpose: "Unterstützt die Abwehrkräfte der Atemwege und die natürliche Reinigung der Bronchien.",
            highlights: ["Brunnenkresse, Süßholz, Spitzwegerich, Eibisch und Efeu", "Ohne Zuckerzusatz"],
            packaging: "20 ml"),

        // MARK: Vitamine
        SupplementProduct(
            id: "rodicare-vita-b", name: "RodiCare Vita B", area: .vitamins,
            purpose: "B-Vitamine in hoher Konzentration.",
            highlights: ["Zwei Komponenten – erst direkt vor dem ersten Gebrauch mischen, das schützt die Vitamine",
                         "Ohne Zuckerzusatz"],
            packaging: "25 ml"),
        SupplementProduct(
            id: "rodicare-vitab-bites", name: "RodiCare VitaB Bites", area: .vitamins,
            purpose: "Snack mit B-Vitamin-Komplex für Vitalität und Belastbarkeit.",
            highlights: ["Auf Basis von rohfaserreichem Alpengras", "Gut als Belohnung geeignet"],
            packaging: "140 g"),
        SupplementProduct(
            id: "rodicare-vita-c", name: "RodiCare Vita C", area: .vitamins,
            purpose: "Vitamin-C-Tabletten (ca. 40 mg pro Tablette) mit Petersilien- oder Karottengeschmack.",
            highlights: ["Einfach zu portionieren", "Ohne Zuckerzusatz"],
            packaging: "30 g",
            forRabbits: false,
            note: "Laut Hersteller für Meerschweinchen und Kleinnager – nicht für Kaninchen vorgesehen. Kaninchen bilden Vitamin C selbst."),

        // MARK: Sonstiges
        SupplementProduct(
            id: "rodicare-pregno", name: "RodiCare Pregno", area: .other,
            purpose: "Der Hersteller nennt online keinen Anwendungszweck – bitte beim Tierarzt erfragen.",
            highlights: ["Pulsatilla und Zitronenmelisse", "Asa foetida", "Ohne Zuckerzusatz"],
            packaging: "50 ml"),
    ]
}
