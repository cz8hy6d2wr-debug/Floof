import Foundation

/// Inhalte des Kaninchen-Lexikons.
/// Allgemeine Informationen – sie ersetzen keine tierärztliche Untersuchung.
enum Lexicon {
    static let disclaimer = "Allgemeine Informationen, sorgfältig zusammengestellt – sie ersetzen keinen Tierarzt. Im Zweifel lieber einmal zu früh anrufen."

    static func article(_ id: String) -> LexiconArticle? { articles.first { $0.id == id } }

    static func articles(in category: LexiconCategory) -> [LexiconArticle] {
        articles.filter { $0.category == category }
    }

    /// Artikel, die zur Akte der Tiere passen: Medikamente, Erkrankungen und Notizen
    /// (z. B. "kleine Treppe" beim Zahnbefund → Zahnprobleme).
    static func relevant(for pets: [Pet]) -> [(article: LexiconArticle, pets: [Pet])] {
        articles.compactMap { article in
            let matching = pets.filter { pet in
                pet.care.contains { article.matches("\($0.title) \($0.details)") }
                    || pet.extraInfo.values.contains { article.matches($0) }
            }
            return matching.isEmpty ? nil : (article: article, pets: matching)
        }
    }

    static let vitals: [VitalSign] = [
        VitalSign(label: "Körpertemperatur", value: "38,5 – 39,5 °C", symbol: "thermometer.medium"),
        VitalSign(label: "Herzschlag", value: "130 – 325 / Min.", symbol: "heart.fill"),
        VitalSign(label: "Atmung (Ruhe)", value: "30 – 60 / Min.", symbol: "lungs.fill"),
        VitalSign(label: "Lebenserwartung", value: "8 – 12 Jahre", symbol: "birthday.cake.fill"),
        VitalSign(label: "Zähne wachsen", value: "lebenslang, mm pro Woche", symbol: "mouth.fill"),
        VitalSign(label: "Ohne Fressen kritisch", value: "ab 6 – 12 Stunden", symbol: "exclamationmark.triangle.fill"),
    ]

    // MARK: - Artikel

    static let articles: [LexiconArticle] = [
        // MARK: Notfall
        LexiconArticle(
            id: "not-fressen",
            title: "Frisst nicht – Magen-Darm-Stillstand",
            category: .emergency,
            summary: "Frisst ein Kaninchen 6 – 12 Stunden nichts oder setzt keinen Kot mehr ab, ist das ein Notfall.",
            sections: [
                LexiconSection(heading: "Warnzeichen", body: """
                • frisst nichts oder nur wenig – auch das Lieblingsfutter nicht
                • kein Kot, oder nur sehr kleine, trockene Köttel
                • sitzt zusammengekauert, wirkt teilnahmslos
                • Bauch hart oder aufgebläht, lautes Zähneknirschen
                """),
                LexiconSection(heading: "Was tun", body: """
                • **Sofort Tierarzt oder Notdienst anrufen** – nicht über Nacht abwarten
                • Warm und ruhig halten, Wärmflasche in ein Handtuch gewickelt anbieten
                • Keine Medikamente auf eigene Faust geben
                • Futtermenge und letzten Kot notieren – hilft dem Tierarzt
                """),
                LexiconSection(heading: "Warum es so eilt", body: """
                Kaninchen haben einen „Stopfmagen“: Nur wenn ständig neues Futter nachkommt, bewegt sich der Brei weiter. Stockt der Darm, gären die Reste, Gase entstehen und der Kreislauf kann innerhalb weniger Stunden zusammenbrechen.
                """),
            ],
            keywords: ["Aufgasung", "Trommelsucht", "Verstopfung", "Darmstillstand", "frisst nicht", "Blähung"],
            related: ["not-erste-hilfe", "ern-grundlagen", "kh-zaehne"]),

        LexiconArticle(
            id: "not-hitze",
            title: "Hitzschlag",
            category: .emergency,
            summary: "Kaninchen können nicht schwitzen. Ab etwa 25 °C wird es für sie gefährlich.",
            sections: [
                LexiconSection(heading: "Warnzeichen", body: """
                • schnelle Atmung, **Atmen mit offenem Maul** (sehr ernst – Kaninchen atmen normalerweise nur durch die Nase)
                • heiße, stark durchblutete Ohren
                • Schwäche, Taumeln, Liegen auf der Seite, Krämpfe
                """),
                LexiconSection(heading: "Was tun", body: """
                • Sofort in einen kühlen, schattigen Raum bringen
                • Ohren mit einem kühlen (nicht eiskalten) feuchten Tuch befeuchten
                • Wasser anbieten, nicht zwingen
                • **Tierarzt anrufen** – auch wenn es sich scheinbar erholt
                """),
                LexiconSection(heading: "Vorbeugen", body: """
                • Fliesen oder Steinplatten zum Liegen, Schattenplätze
                • Gefrorene Wasserflaschen in ein Handtuch gewickelt
                • Frisches, wasserreiches Grünfutter
                • Nie im Auto oder in praller Sonne lassen
                """),
            ],
            keywords: ["Hitze", "Sommer", "Hitzschlag", "Überhitzung"],
            related: ["hal-platz", "not-erste-hilfe"]),

        LexiconArticle(
            id: "not-kopf",
            title: "Kopfschiefhaltung & Gleichgewichtsstörung",
            category: .emergency,
            summary: "Plötzlich schiefer Kopf, Rollen oder Taumeln – am selben Tag zum Tierarzt.",
            sections: [
                LexiconSection(heading: "Mögliche Ursachen", body: """
                • **EC** (Encephalitozoon cuniculi) – die häufigste Ursache
                • Mittel- oder Innenohrentzündung, oft durch Bakterien
                • Verletzungen, selten Tumore
                """),
                LexiconSection(heading: "Bis zum Tierarzt", body: """
                • Gehege polstern: Handtücher, Decken, keine hohen Ebenen
                • Futter und Wasser direkt vor die Nase stellen
                • Ruhig und abgedunkelt halten
                • Wenn es nicht frisst: päppeln (siehe Erste Hilfe)
                """),
                LexiconSection(heading: "Gut zu wissen", body: """
                Viele Kaninchen erholen sich erstaunlich gut und kommen später auch mit einer leichten Restschiefhaltung prima zurecht.
                """),
            ],
            keywords: ["Kopfschief", "Schiefhals", "Torticollis", "Gleichgewicht", "Rollen", "Taumeln"],
            related: ["kh-ec", "kh-schnupfen"]),

        LexiconArticle(
            id: "not-fliegen",
            title: "Fliegenmaden (Myiasis)",
            category: .emergency,
            summary: "Im Sommer legen Fliegen Eier ins Fell – die Maden fressen sich binnen Stunden ins Gewebe.",
            sections: [
                LexiconSection(heading: "Risiko", body: """
                Besonders gefährdet sind Kaninchen mit verschmutztem Po (Durchfall, Übergewicht, Arthrose, Zahnprobleme), Wunden oder bei Außenhaltung.
                """),
                LexiconSection(heading: "Was tun", body: """
                • Im Sommer **täglich den Afterbereich kontrollieren**
                • Eier (weiße Körnchen) oder Maden entdeckt: **sofort zum Tierarzt**
                • Nicht baden – das weicht die Haut weiter auf
                • Fliegengitter, Sauberkeit, Ursache für verschmutzten Po behandeln
                """),
            ],
            keywords: ["Fliegen", "Maden", "Myiasis", "Fliegenmaden"],
            related: ["pfl-fell"]),

        LexiconArticle(
            id: "not-erste-hilfe",
            title: "Notfallapotheke & Erste Hilfe",
            category: .emergency,
            summary: "Was im Haus sein sollte, bevor es ernst wird.",
            sections: [
                LexiconSection(heading: "Ins Notfallkörbchen", body: """
                • Telefonnummer von Tierarzt **und** Notdienst (am Kühlschrank und im Handy)
                • Päppelfutter (Pulver zum Anrühren) und Einwegspritzen ohne Nadel, 1 ml und 5 – 10 ml
                • Digitales Thermometer mit Vaseline
                • Wärmflasche oder Wärmekissen, Handtücher
                • Küchenwaage
                """),
                LexiconSection(heading: "Fieber messen", body: """
                Rektal, vorsichtig zu zweit: Ein Mensch hält das Kaninchen aufrecht und sicher, der andere misst. Normal sind **38,5 – 39,5 °C**. Unter 38 °C ist besonders kritisch.
                """),
                LexiconSection(heading: "Päppeln", body: """
                Brei seitlich hinter den Schneidezähnen in kleinen Portionen eingeben, das Kaninchen sitzt dabei aufrecht. Nie in Rückenlage – Verschluckungsgefahr. Päppeln überbrückt nur, es ersetzt nicht den Tierarzt.
                """),
            ],
            keywords: ["Erste Hilfe", "Päppeln", "Notdienst", "Fieber", "Thermometer", "Critical Care"],
            related: ["med-geben", "not-fressen"]),

        // MARK: Krankheiten
        LexiconArticle(
            id: "kh-ec",
            title: "EC – Encephalitozoon cuniculi",
            category: .health,
            summary: "Ein Einzeller, den viele Kaninchen unbemerkt tragen. Bei Stress oder schwachem Immunsystem kann er ausbrechen.",
            sections: [
                LexiconSection(heading: "Anzeichen", body: """
                • Kopfschiefhaltung, Gleichgewichtsstörungen, Rollen
                • Augenzittern, Lähmungen der Hinterbeine
                • Trinkt und pinkelt viel, nasser Po (Niere, Blase)
                • Trübe Linse oder Entzündung im Auge
                """),
                LexiconSection(heading: "Behandlung", body: """
                Meist mit **Fenbendazol (z. B. Panacur) über 28 Tage**, dazu je nach Beschwerden Entzündungshemmer, Vitamin B, Infusionen oder Physiotherapie. Dosis und Dauer legt der Tierarzt nach Gewicht fest – regelmäßiges Wiegen hilft.
                """),
                LexiconSection(heading: "Ansteckung & Hygiene", body: """
                Die Sporen werden mit dem Urin ausgeschieden und halten sich lange in der Umgebung. Toiletten und Böden gründlich und möglichst heiß reinigen. Ob Partnertiere mitbehandelt werden, mit dem Tierarzt besprechen. Für Menschen mit geschwächtem Immunsystem kann der Erreger relevant sein.
                """),
                LexiconSection(heading: "Leben mit EC", body: """
                Viele EC-Kaninchen leben nach einem Schub noch lange und zufrieden. Wichtig sind wenig Stress, ebenerdige Einrichtung und gute Beobachtung – das Tagebuch hilft, Veränderungen früh zu bemerken.
                """),
            ],
            keywords: ["EC", "E. cuniculi", "Encephalitozoon", "Panacur", "Fenbendazol", "Kopfschief"],
            related: ["med-panacur", "not-kopf", "kh-krampf"]),

        LexiconArticle(
            id: "kh-krampf",
            title: "Krampfanfälle & Epilepsie",
            category: .health,
            summary: "Anfälle haben viele Ursachen – ruhig bleiben, schützen, beobachten und notieren.",
            sections: [
                LexiconSection(heading: "Mögliche Ursachen", body: """
                EC, Hitzschlag, Vergiftung, Stoffwechselprobleme (Leber, Niere), Verletzungen, selten Tumore. Manchmal findet sich keine Ursache (idiopathische Epilepsie).
                """),
                LexiconSection(heading: "Während des Anfalls", body: """
                • Nicht festhalten – Verletzungsgefahr für Tier und Mensch
                • Harte Gegenstände wegräumen, weich polstern, Raum abdunkeln
                • **Dauer messen** und wenn möglich ein Video für den Tierarzt aufnehmen
                """),
                LexiconSection(heading: "Wann sofort zum Notdienst", body: """
                • Anfall länger als 2 – 3 Minuten
                • Mehrere Anfälle kurz hintereinander
                • Kaninchen erholt sich danach nicht oder frisst nicht
                """),
                LexiconSection(heading: "Im Tagebuch festhalten", body: """
                Datum, Uhrzeit, Dauer, mögliche Auslöser (Lärm, Stress, Hitze) und Medikamente. So erkennt man mit dem Tierarzt Muster und kann die Behandlung anpassen.
                """),
            ],
            keywords: ["Epilepsie", "Krampf", "Krämpfe", "Anfall", "Gabapentin"],
            related: ["med-gabapentin", "kh-ec", "not-hitze"]),

        LexiconArticle(
            id: "kh-zaehne",
            title: "Zahnprobleme",
            category: .health,
            summary: "Kaninchenzähne wachsen lebenslang. Nur viel Kauen auf Heu und Grün hält sie in Form.",
            sections: [
                LexiconSection(heading: "Warnzeichen", body: """
                • wählerisch, Futter fällt aus dem Maul, frisst langsamer
                • nasses Kinn, Sabbern, tränende Augen
                • Gewichtsverlust, kleinere Köttel
                • Schwellungen am Kiefer
                """),
                LexiconSection(heading: "Treppen & Spitzen", body: """
                Werden die Backenzähne ungleichmäßig abgenutzt, entsteht eine „Treppe“ oder es bilden sich Spitzen, die Zunge und Wangen verletzen. Kleine Treppen sind oft unbedenklich, sollten aber regelmäßig kontrolliert werden – je nach Befund alle 3 – 6 Monate.
                """),
                LexiconSection(heading: "Vorbeugen", body: """
                Heu rund um die Uhr, viel Wiese und Kräuter, wenig bis kein Trockenfutter. Gräser enthalten Kieselsäure, die den Abrieb fördert.
                """),
            ],
            keywords: ["Zähne", "Zahn", "Treppe", "Backenzähne", "Zahnspitzen"],
            related: ["ern-grundlagen", "pfl-gewicht"]),

        LexiconArticle(
            id: "kh-rhd",
            title: "RHD – Chinaseuche (RHD-1 & RHD-2)",
            category: .health,
            summary: "Ein hochansteckendes Virus, oft tödlich – auch für reine Wohnungskaninchen. Impfen schützt.",
            sections: [
                LexiconSection(heading: "Übertragung", body: """
                Direkt von Tier zu Tier, aber auch über Kleidung, Schuhe, Insekten und gepflücktes Grünfutter. Deshalb sind auch Wohnungskaninchen gefährdet.
                """),
                LexiconSection(heading: "Verlauf", body: """
                Oft plötzlich und ohne Vorzeichen. Mögliche Anzeichen: Fieber, Apathie, Atemnot, Blutungen aus der Nase.
                """),
                LexiconSection(heading: "Impfung", body: """
                Es gibt Impfstoffe, die gegen RHD-1, RHD-2 und Myxomatose gemeinsam schützen. In der Regel **jährlich auffrischen** – Floof erinnert dich, wenn du die Impfung beim Tier einträgst.
                """),
            ],
            keywords: ["RHD", "RHD-1", "RHD-2", "RHDV2", "Chinaseuche", "Impfung"],
            related: ["kh-myxo"]),

        LexiconArticle(
            id: "kh-myxo",
            title: "Myxomatose",
            category: .health,
            summary: "Virus, das vor allem über stechende Insekten übertragen wird. Impfung und Insektenschutz helfen.",
            sections: [
                LexiconSection(heading: "Anzeichen", body: """
                Geschwollene, verklebte Augenlider, Schwellungen an Kopf, Ohren und Genitalbereich, später Atemnot und Schwäche.
                """),
                LexiconSection(heading: "Schutz", body: """
                • Jährliche Impfung (meist kombiniert mit RHD)
                • Fliegengitter an Fenstern, besonders in Mückenzeiten
                • Kein Kontakt zu Wildkaninchen
                """),
            ],
            keywords: ["Myxomatose", "Myxo", "Impfung"],
            related: ["kh-rhd"]),

        LexiconArticle(
            id: "kh-schnupfen",
            title: "Kaninchenschnupfen",
            category: .health,
            summary: "Bakterielle Infektion der Atemwege – früh behandeln, sonst wird sie leicht chronisch.",
            sections: [
                LexiconSection(heading: "Anzeichen", body: """
                • häufiges Niesen, weißlicher bis gelber Nasenausfluss
                • verklebte Innenseiten der Vorderpfoten (vom Nase-Putzen)
                • Atemgeräusche, tränende Augen
                """),
                LexiconSection(heading: "Was hilft", body: """
                Tierarzt: oft Antibiotikum, idealerweise nach Erregernachweis, dazu Inhalation. Zugluft vermeiden, Stress reduzieren. Unbehandelt kann sich die Entzündung bis ins Mittelohr ausbreiten.
                """),
            ],
            keywords: ["Schnupfen", "Niesen", "Pasteurellen", "Atemwege"],
            related: ["med-gefahr", "not-kopf"]),

        LexiconArticle(
            id: "kh-schmerz",
            title: "Schmerzen erkennen",
            category: .health,
            summary: "Kaninchen sind Fluchttiere und verbergen Schmerzen. Kleine Veränderungen sind große Hinweise.",
            sections: [
                LexiconSection(heading: "Darauf achten", body: """
                • Rückzug, sitzt aufgeplustert und „rund“ in der Ecke
                • lautes Zähneknirschen (leises Zähnemahlen ist dagegen Wohlbehagen)
                • halb geschlossene Augen, angespanntes Gesicht
                • frisst weniger, putzt sich nicht mehr
                • Bewegungsunlust, ungewohnte Haltung, Bauch wird eingezogen
                """),
                LexiconSection(heading: "Was tun", body: """
                Beim Tierarzt abklären lassen. Häufig verschrieben wird ein Entzündungshemmer wie Meloxicam. Niemals Schmerzmittel für Menschen geben.
                """),
            ],
            keywords: ["Schmerz", "Schmerzen", "Meloxicam", "Metacam", "Zähneknirschen"],
            related: ["med-gefahr", "ver-sprache"]),

        // MARK: Medikamente
        LexiconArticle(
            id: "med-geben",
            title: "Medikamente richtig geben",
            category: .medicine,
            summary: "Mit Ruhe, der richtigen Haltung und einem kleinen Trick klappt es fast immer.",
            sections: [
                LexiconSection(heading: "Flüssiges", body: """
                • Einwegspritze ohne Nadel, Kaninchen sitzt **aufrecht auf allen vieren**
                • Spritze seitlich in die Zahnlücke hinter den Schneidezähnen schieben
                • Langsam in kleinen Portionen geben, schlucken lassen
                • **Nie in Rückenlage** – Verschluckungsgefahr
                """),
                LexiconSection(heading: "Tabletten", body: """
                Zerdrücken und mit wenig Wasser oder Päppelbrei aufschwemmen – vorher beim Tierarzt fragen, ob das bei diesem Wirkstoff geht.
                """),
                LexiconSection(heading: "Tricks", body: """
                • Zappelige Kaninchen locker in ein Handtuch wickeln („Burrito“)
                • Danach ein kleines Leckerli – dann wird es Routine
                • Spritzen nach Gebrauch mit warmem Wasser ausspülen
                • Zeiten einhalten: Floof erinnert dich und bucht die Menge im Schrank ab
                """),
            ],
            keywords: ["Spritze", "eingeben", "Medikament", "Tablette", "Saft"],
            related: ["not-erste-hilfe", "med-gefahr"]),

        LexiconArticle(
            id: "med-panacur",
            title: "Fenbendazol (Panacur)",
            category: .medicine,
            summary: "Wirkt gegen EC und Darmwürmer. Bei EC meist als Kur über 28 Tage.",
            sections: [
                LexiconSection(heading: "Anwendung", body: """
                Meist einmal täglich als Suspension mit der Spritze. Die Menge richtet sich nach dem Körpergewicht – deshalb vor der Kur wiegen und das Gewicht im Blick behalten.
                """),
                LexiconSection(heading: "Gut zu wissen", body: """
                • Die Kur nicht vorzeitig abbrechen, auch wenn es dem Tier besser geht
                • Flasche vor jeder Gabe gut schütteln
                • Bei langen oder wiederholten Kuren kann der Tierarzt Blutwerte kontrollieren
                • Haltbarkeit nach Anbruch beachten – steht im Medikamentenschrank
                """),
            ],
            keywords: ["Panacur", "Fenbendazol", "Wurmkur", "EC"],
            related: ["kh-ec", "med-geben"]),

        LexiconArticle(
            id: "med-gabapentin",
            title: "Gabapentin",
            category: .medicine,
            summary: "Gegen Nervenschmerzen und unterstützend bei neurologischen Problemen.",
            sections: [
                LexiconSection(heading: "Einsatz", body: """
                Bei Nervenschmerzen, chronischen Schmerzen und als Ergänzung bei neurologischen Erkrankungen oder Krampfneigung – immer nach tierärztlicher Verordnung.
                """),
                LexiconSection(heading: "Darauf achten", body: """
                • Kann müde oder etwas wackelig machen, besonders am Anfang
                • **Nicht abrupt absetzen** – nur nach Absprache langsam ausschleichen
                • Regelmäßige Zeiten einhalten, damit der Spiegel gleichmäßig bleibt
                """),
            ],
            keywords: ["Gabapentin", "Nervenschmerz"],
            related: ["kh-krampf", "kh-schmerz"]),

        LexiconArticle(
            id: "med-gefahr",
            title: "Gefährliche Wirkstoffe",
            category: .medicine,
            summary: "Manche Medikamente, die bei Hund, Katze oder Mensch harmlos sind, können Kaninchen töten.",
            sections: [
                LexiconSection(heading: "Bestimmte Antibiotika", body: """
                Einige Antibiotika – etwa Penicilline und Amoxicillin zum Eingeben, Clindamycin, Lincomycin oder Erythromycin – können die Darmflora zerstören und lebensbedrohliche Durchfälle auslösen. Deshalb: Tierarzt mit Kaninchenerfahrung.
                """),
                LexiconSection(heading: "Außerdem tabu", body: """
                • **Fipronil** (in manchen Floh- und Zeckenmitteln für Hund und Katze)
                • Schmerzmittel für Menschen wie Paracetamol oder Ibuprofen ohne Anweisung
                • Medikamente anderer Tiere „auf Verdacht“
                """),
            ],
            keywords: ["Antibiotika", "Amoxicillin", "Penicillin", "Clindamycin", "Fipronil", "giftig"],
            related: ["med-geben", "kh-schmerz"]),

        // MARK: Ernährung
        LexiconArticle(
            id: "ern-grundlagen",
            title: "Richtig füttern",
            category: .food,
            summary: "Heu rund um die Uhr, viel Grün, frisches Wasser – und Leckerlis nur in Mini-Portionen.",
            sections: [
                LexiconSection(heading: "Die Basis", body: """
                • **Heu immer verfügbar** – mindestens ein Haufen so groß wie das Kaninchen pro Tag
                • Reichlich Frischfutter: Wiese, Kräuter, Blattgemüse, Zweige
                • Frisches Wasser, am besten aus einem Napf
                """),
                LexiconSection(heading: "Lieber nicht", body: """
                Trockenfutter mit Getreide, Körnern, Zucker oder bunten Pellets, Brot, Joghurtdrops und Knabberstangen. Sie machen dick, fördern Zahnprobleme und bringen die Verdauung durcheinander.
                """),
                LexiconSection(heading: "Umstellen", body: """
                Neues Futter langsam einführen – über ein bis zwei Wochen die Menge steigern. Besonders Kohl und Wiese im Frühjahr behutsam anfüttern.
                """),
                LexiconSection(heading: "Blinddarmkot", body: """
                Kaninchen fressen weiche, glänzende Blinddarmköttel direkt am Po. Das ist normal und lebenswichtig. Liegen sie ständig herum, stimmt meist die Ernährung nicht.
                """),
            ],
            keywords: ["Ernährung", "Trockenfutter", "Pellets", "Blinddarmkot"],
            related: ["kh-zaehne", "not-fressen"]),

        // MARK: Pflege
        LexiconArticle(
            id: "pfl-gewicht",
            title: "Wiegen & Gewicht",
            category: .care,
            summary: "Einmal pro Woche auf die Küchenwaage – Gewichtsverlust ist oft das erste Warnzeichen.",
            sections: [
                LexiconSection(heading: "So geht's", body: """
                • Immer zur gleichen Tageszeit, am besten vor dem Frischfutter
                • Kaninchen in eine Schüssel oder Box setzen, Gewicht vorher abziehen
                • In Floof eintragen – die Kurve zeigt Trends sofort
                """),
                LexiconSection(heading: "Wann zum Tierarzt", body: """
                Verliert ein Kaninchen ohne erkennbaren Grund mehr als etwa 5 – 10 % seines Gewichts, sollte das abgeklärt werden – zum Beispiel Zähne oder Nieren.
                """),
                LexiconSection(heading: "Richtwerte", body: """
                • Zwergkaninchen: etwa 1 – 1,5 kg
                • Löwenköpfchen: etwa 1,2 – 1,8 kg
                • Mittelgroße Rassen: 2 – 4 kg
                Wichtiger als die Zahl ist der Körperbau: Rippen sollten leicht fühlbar, aber nicht sichtbar sein.
                """),
            ],
            keywords: ["Gewicht", "wiegen", "Waage", "abgenommen"],
            related: ["kh-zaehne", "ern-grundlagen"]),

        LexiconArticle(
            id: "pfl-krallen",
            title: "Krallen schneiden",
            category: .care,
            summary: "Alle 4 – 8 Wochen kontrollieren – bei Wohnungskaninchen nutzen sie sich selten genug ab.",
            sections: [
                LexiconSection(heading: "Anleitung", body: """
                • Spezielle Krallenschere für Kleintiere verwenden
                • Bei hellen Krallen ist das rötliche „Leben“ (Blutgefäß) sichtbar – mit Abstand davor schneiden
                • Bei dunklen Krallen mit einer Taschenlampe von hinten durchleuchten
                • Lieber öfter wenig als einmal zu viel
                """),
                LexiconSection(heading: "Doch geblutet?", body: """
                Ruhe bewahren, Mehl oder blutstillendes Puder auf die Kralle drücken. Hört es nicht auf, Tierarzt anrufen.
                """),
            ],
            keywords: ["Krallen", "Nägel", "Krallenschere"],
            related: ["pfl-fell"]),

        LexiconArticle(
            id: "pfl-fell",
            title: "Fellpflege & Fellwechsel",
            category: .care,
            summary: "Im Frühjahr und Herbst verlieren Kaninchen viel Fell – Bürsten hilft, Langhaar braucht mehr Pflege.",
            sections: [
                LexiconSection(heading: "Fellwechsel", body: """
                Beim Putzen verschlucken Kaninchen Haare. Mit viel Heu ist das meist kein Problem. Frisst es dabei weniger oder wird der Kot kleiner und mit Haaren verkettet, aufmerksam bleiben.
                """),
                LexiconSection(heading: "Löwenköpfchen & Langhaar", body: """
                Mähne und lange Haare regelmäßig bürsten, sonst verfilzen sie. Verfilzungen vorsichtig mit der Schere entfernen, nie ziehen.
                """),
                LexiconSection(heading: "Bitte nicht", body: """
                Kaninchen nicht baden – das bedeutet großen Stress und Unterkühlungsgefahr. Nur einen verschmutzten Po vorsichtig lokal säubern.
                """),
            ],
            keywords: ["Fell", "Fellwechsel", "bürsten", "Löwenköpfchen", "Langhaar"],
            related: ["not-fliegen", "pfl-krallen"]),

        LexiconArticle(
            id: "pfl-kastration",
            title: "Kastration",
            category: .care,
            summary: "Für Rammler in Gruppenhaltung unverzichtbar, bei Häsinnen ein wichtiges Gesundheitsthema.",
            sections: [
                LexiconSection(heading: "Rammler", body: """
                Kastrierte Rammler sind entspannter und können mit Häsinnen zusammenleben. Achtung: **Nach der Kastration noch etwa 6 Wochen zeugungsfähig.**
                """),
                LexiconSection(heading: "Häsinnen", body: """
                Ältere unkastrierte Häsinnen erkranken häufig an der Gebärmutter. Ob und wann eine Kastration sinnvoll ist, mit dem Tierarzt besprechen.
                """),
            ],
            keywords: ["Kastration", "kastriert", "Rammler", "Häsin"],
            related: ["ver-vg"]),

        // MARK: Verhalten
        LexiconArticle(
            id: "ver-sprache",
            title: "Körpersprache verstehen",
            category: .behavior,
            summary: "Vom Freudensprung bis zum Klopfen – so reden Kaninchen.",
            sections: [
                LexiconSection(heading: "Gute Laune", body: """
                • **Binky**: Luftsprung mit Drehung – pure Freude
                • **Flop**: lässt sich auf die Seite fallen – total entspannt
                • Leises Zähnemahlen beim Streicheln – das Kaninchen-„Schnurren“
                """),
                LexiconSection(heading: "Achtung", body: """
                • **Klopfen** mit den Hinterläufen – Warnung vor Gefahr oder Unmut
                • Brummen, Grunzen, Boxen mit den Vorderpfoten – „lass mich“
                • Ohren flach nach hinten, Körper angespannt – Angst oder Drohung
                • Lautes Zähneknirschen – Schmerzen
                """),
                LexiconSection(heading: "Markieren", body: """
                Kinnreiben an Gegenständen verteilt Duft aus Drüsen am Kinn: „Das gehört mir.“
                """),
            ],
            keywords: ["Körpersprache", "Binky", "Klopfen", "Verhalten", "Zähnemahlen"],
            related: ["kh-schmerz", "ver-vg"]),

        LexiconArticle(
            id: "ver-vg",
            title: "Vergesellschaftung & Revierverhalten",
            category: .behavior,
            summary: "Kaninchen brauchen Artgenossen. Das Zusammenführen braucht Geduld – und den richtigen Ort.",
            sections: [
                LexiconSection(heading: "Grundregeln", body: """
                • Nie allein halten – Menschen und Meerschweinchen ersetzen keinen Partner
                • Alle Tiere kastriert (Rammler) und gesund
                • **Neutrales Gebiet**, auf dem keines der Tiere vorher war
                • Genug Platz, Verstecke mit zwei Ausgängen, mehrere Futterstellen
                """),
                LexiconSection(heading: "Normal", body: """
                Jagen, Aufreiten, Fellbüschel fliegen – so wird die Rangordnung geklärt. Das kann Tage bis Wochen dauern.
                """),
                LexiconSection(heading: "Abbrechen, wenn", body: """
                Blut fließt, sich ein Tier festbeißt, eines dauerhaft gejagt wird und nicht mehr frisst, oder beide sich ineinander verknäueln.
                """),
                LexiconSection(heading: "Revierverhalten danach", body: """
                Auch nach erfolgreicher Vergesellschaftung kann ein Tier Revier verteidigen, besonders nach Umstellungen oder Tierarztbesuchen. Häufig hilft es, die Einrichtung umzustellen und Futter an mehreren Stellen anzubieten. Bei anhaltendem Stress oder Verletzungen Tierarzt oder erfahrene Beratung hinzuziehen.
                """),
            ],
            keywords: ["Vergesellschaftung", "Revier", "Revierverhalten", "Rangordnung", "Partner"],
            related: ["pfl-kastration", "ver-sprache", "hal-platz"]),

        // MARK: Haltung
        LexiconArticle(
            id: "hal-platz",
            title: "Platz, Gehege & Temperatur",
            category: .housing,
            summary: "Kaninchen sind Bewegungstiere. Ein Käfig allein reicht nie.",
            sections: [
                LexiconSection(heading: "Platz", body: """
                Tierschutzorganisationen empfehlen für zwei Kaninchen **mindestens 6 m² ständig nutzbare Fläche** – mehr ist immer besser. Ein eigenes Zimmer oder ein großes Gehege mit Auslauf ist ideal.
                """),
                LexiconSection(heading: "Wohnung kaninchensicher", body: """
                • Kabel in Kabelkanäle oder hochlegen
                • Giftige Zimmerpflanzen außer Reichweite
                • Rutschfeste Böden (Teppich, Matten) – glatte Böden belasten die Gelenke
                • Rückzugsorte, Buddelkiste, mehrere Ebenen (bei EC lieber flach)
                """),
                LexiconSection(heading: "Temperatur", body: """
                Kaninchen vertragen Kälte deutlich besser als Hitze. Ab etwa 25 °C kühlen, Zugluft vermeiden.
                """),
            ],
            keywords: ["Gehege", "Platzbedarf", "Kaninchensicher", "Temperatur"],
            related: ["not-hitze", "ver-vg", "hal-draussen"]),

        LexiconArticle(
            id: "hal-draussen",
            title: "Draußen bei jedem Wetter",
            category: .housing,
            summary: "Außenkaninchen vertragen Kälte gut – Nässe, Zugluft und Hitze sind die eigentlichen Gefahren.",
            sections: [
                LexiconSection(heading: "Kälte & Frost", body: """
                • Nur Tiere draußen halten, die **ab Herbst langsam daran gewöhnt** wurden – dann bildet sich ein dichtes Winterfell.
                • Ein **isoliertes, zugfreies Schutzhaus** mit viel Stroh und Heu, etwas erhöht vom Boden.
                • Nie allein: Kaninchen wärmen sich gegenseitig.
                • **Wasser mehrmals täglich auf Eis prüfen**, bei Frost lauwarm nachfüllen.
                • Kranke, alte oder geschwächte Tiere (z. B. bei EC) besser drinnen überwintern.
                """),
                LexiconSection(heading: "Nässe & Wind", body: """
                • Nässe zusammen mit Kälte ist gefährlicher als Kälte allein: immer einen **überdachten, trockenen Bereich** anbieten.
                • Nasse Einstreu zügig wechseln.
                • Bei Sturm das Gehege sichern, das Schutzhaus mit der Öffnung weg vom Wind stellen.
                """),
                LexiconSection(heading: "Hitze draußen", body: """
                • **Ganztags Schatten** – die Sonne wandert, also morgens und nachmittags prüfen.
                • Mehrere Wassernäpfe, Fliesen oder Kühlakkus zum Liegen.
                • Im Sommer **täglich den Po kontrollieren** – Fliegen legen Eier in verschmutztes Fell.
                """),
                LexiconSection(heading: "Drinnen mit Auslauf", body: """
                Wohnungskaninchen haben kein dichtes Winterfell. Bei Frost den Auslauf kurz halten und nicht ständig zwischen warmer Wohnung und Kälte wechseln. Bei Regen lieber drinnen bleiben oder einen trockenen Unterschlupf anbieten.
                """),
            ],
            keywords: ["Außenhaltung", "Winter", "Frost", "Kälte", "Regen", "Sturm", "Auslauf", "Garten", "Balkon"],
            related: ["not-hitze", "not-fliegen", "hal-platz"]),
    ]

    // MARK: - Futter-Check

    static let foods: [FoodItem] = [
        FoodItem(name: "Heu", verdict: .ok, note: "Grundnahrung, immer verfügbar"),
        FoodItem(name: "Wiese & Gräser", verdict: .ok, note: "Ideal – im Frühjahr langsam anfüttern"),
        FoodItem(name: "Löwenzahn", verdict: .ok, note: "Blätter, Blüten und Stängel"),
        FoodItem(name: "Spitzwegerich", verdict: .ok),
        FoodItem(name: "Brennnessel", verdict: .ok, note: "Angewelkt oder getrocknet anbieten"),
        FoodItem(name: "Petersilie", verdict: .ok),
        FoodItem(name: "Dill", verdict: .ok),
        FoodItem(name: "Basilikum", verdict: .ok),
        FoodItem(name: "Pfefferminze", verdict: .ok),
        FoodItem(name: "Möhrengrün", verdict: .ok),
        FoodItem(name: "Fenchel", verdict: .ok, note: "Knolle und Grün"),
        FoodItem(name: "Romanasalat", verdict: .ok),
        FoodItem(name: "Feldsalat", verdict: .ok),
        FoodItem(name: "Endivie", verdict: .ok),
        FoodItem(name: "Rucola", verdict: .ok),
        FoodItem(name: "Chicorée", verdict: .ok),
        FoodItem(name: "Staudensellerie", verdict: .ok, note: "Fäden bei großen Stangen entfernen"),
        FoodItem(name: "Kohlrabiblätter", verdict: .ok),
        FoodItem(name: "Brombeerblätter", verdict: .ok, note: "Auch im Winter grün"),
        FoodItem(name: "Himbeerblätter", verdict: .ok),
        FoodItem(name: "Apfelzweige", verdict: .ok, note: "Ungespritzt – gut für die Zähne"),
        FoodItem(name: "Haselnusszweige", verdict: .ok, note: "Ungespritzt"),
        FoodItem(name: "Paprika", verdict: .ok, note: "Ohne Stiel"),
        FoodItem(name: "Brokkoli", verdict: .sometimes, note: "Kann blähen – langsam gewöhnen"),
        FoodItem(name: "Kohl", verdict: .sometimes, note: "Wirsing, Grünkohl: langsam anfüttern"),
        FoodItem(name: "Gurke", verdict: .sometimes, note: "Sehr wasserreich, wenig Nährstoffe"),
        FoodItem(name: "Möhre", verdict: .sometimes, note: "Zuckerreich – kleines Stück als Leckerli"),
        FoodItem(name: "Apfel", verdict: .sometimes, note: "Ohne Kerne, als Leckerli"),
        FoodItem(name: "Banane", verdict: .sometimes, note: "Sehr süß, nur ein Scheibchen"),
        FoodItem(name: "Erdbeere", verdict: .sometimes, note: "Frucht und Blätter, selten"),
        FoodItem(name: "Trockenfutter / Pellets", verdict: .sometimes, note: "Nur getreidefrei und sehr sparsam"),
        FoodItem(name: "Brot & Backwaren", verdict: .toxic, note: "Ungeeignet – Stärke stört die Verdauung"),
        FoodItem(name: "Avocado", verdict: .toxic),
        FoodItem(name: "Zwiebel, Lauch, Knoblauch", verdict: .toxic),
        FoodItem(name: "Kartoffel & Kartoffelkraut", verdict: .toxic, note: "Besonders rohe, grüne Teile"),
        FoodItem(name: "Tomatenpflanze", verdict: .toxic, note: "Grüne Pflanzenteile"),
        FoodItem(name: "Rhabarber", verdict: .toxic),
        FoodItem(name: "Rohe Bohnen", verdict: .toxic),
        FoodItem(name: "Schokolade & Süßes", verdict: .toxic),
        FoodItem(name: "Eibe", verdict: .toxic, note: "Hochgiftig"),
        FoodItem(name: "Thuja (Lebensbaum)", verdict: .toxic),
        FoodItem(name: "Efeu", verdict: .toxic),
        FoodItem(name: "Oleander", verdict: .toxic, note: "Hochgiftig"),
        FoodItem(name: "Maiglöckchen", verdict: .toxic),
        FoodItem(name: "Fingerhut", verdict: .toxic),
        FoodItem(name: "Rhododendron", verdict: .toxic),
        FoodItem(name: "Buchsbaum", verdict: .toxic),
        FoodItem(name: "Goldregen", verdict: .toxic),
        FoodItem(name: "Jakobskreuzkraut", verdict: .toxic, note: "Auch getrocknet im Heu giftig"),
        FoodItem(name: "Hahnenfuß", verdict: .toxic, note: "Frisch giftig"),
        FoodItem(name: "Dieffenbachie", verdict: .toxic, note: "Zimmerpflanze"),
    ]
}
