# Floof

Tiertagebuch mit Medikamentenplan und Medikamentenschrank – SwiftUI, Liquid Glass,
optimiert für faltbare iPhones (Außen- und Innendisplay).

## Öffnen & starten

1. `Floof.xcodeproj` in Xcode 26 (oder neuer) öffnen.
2. Unter *Signing & Capabilities* dein Team wählen.
3. Auf iPhone oder Simulator starten (Mindestversion iOS 26 – wegen Liquid Glass).

Beim ersten Start: Tier anlegen oder unter *Tiere → Einstellungen → Floof-Export laden*
einen bestehenden Export importieren.

## Bereiche

| Tab | Inhalt |
|---|---|
| **Heute** | Medikamente des Tages zum Abhaken, "Wenn nötig"-Mittel, Tages-Check (Ampel), Hinweise aus dem Schrank, Möhren/Serie/Abzeichen |
| **Tagebuch** | Einträge mit Stimmung, Themen, Foto und optionalem Gewicht; automatisch dazu: Wiegen, Tierarzt, Impfungen. Aufgeklappt mit Stimmungskalender |
| **Schrank** | Bestand je Medikament, Reichweite in Tagen, Ablauf/Anbruch, Nachfüllen, Korrekturen, Verlauf. Abhaken einer Gabe bucht automatisch ab |
| **Lexikon** | Kaninchenwissen: Notfall-Hilfe, Krankheiten (EC, Epilepsie, Zähne, RHD …), Medikamente, Ernährung, Pflege, Verhalten, Haltung. Futter-Check „Darf mein Kaninchen das?“, RodiCare-Ergänzungsmittel nach Anwendungsgebiet, Normalwerte, Merkliste, Suche. Hebt automatisch Artikel hervor, die zur Akte deiner Tiere passen |
| **Tiere** | Profile, Gewichtskurve, Medikamente mit Zeitplan & Schrank-Verknüpfung, Erkrankungen, Impfungen, Einstellungen, Import/Export. Aufgeklappt Liste und Detail nebeneinander |

## Faltbares iPhone

- **Erkennung:** Seitenverhältnis + Size Class der verfügbaren Fläche (`DevicePosture`), in allen Tabs verfügbar
- **Zugeklappt (5,4"):** Einhand-Layouts, wichtigste Aktionen im Daumenbereich; im Querformat auf Lesebreite begrenzt
- **Aufgeklappt (7,6", 4:3):** zwei gleich breite Spalten in jedem Tab (`FoldColumns`) – der Spaltenabstand liegt genau auf dem Falz, nichts läuft über die Knickstelle
- **Nahtloser Wechsel:** ein NavigationStack pro Tab, Sheets hängen darüber; offene Editoren, das gewählte Tier und geöffnete Details überstehen das Auf-/Zuklappen
- **Editoren** erscheinen aufgeklappt als kompaktes Formular (`presentationSizing(.form)`)

## Liquid Glass

Glas nur auf der Steuerungsebene, Inhalte bleiben ruhig und lesbar:

- Tab-Leiste (System-Glas), schrumpft beim Scrollen (`tabBarMinimizeBehavior`)
- gläserne Zusatzleiste über den Tabs mit der nächsten Gabe (`tabViewBottomAccessory`)
- Filter-Chips, Stimmungswahl, Tages-Check: `GlassEffectContainer` + `glassEffectID` – die Kapseln verschmelzen beim Wechsel
- Aktionen: `.buttonStyle(.glass)` / `.glassProminent`, schwebender Stift im Tagebuch
- Toasts als getöntes Glas

## Aufbau

```
Floof/
├─ App/            Einstiegspunkt
├─ Models/         Pet & Care (Export-Format), Tagebuch, Schrank, AppData + DiskStore
├─ Lexicon/        Lexikon-Inhalte (Artikel, Futterliste, Normalwerte)
├─ Store/          PetStore (+Doses, +Cabinet, +Diary, +Pets, +Transfer), Gamification, Erinnerungen, Vorschaudaten
└─ Views/
   ├─ RootTabView  Tabs, Glas-Zusatzleiste, Toast, Feier
   ├─ Today/       Heute (zugeklappt: Einhand, aufgeklappt: zweispaltig)
   ├─ Diary/       Zeitleiste, Editor, Stimmungskalender
   ├─ Cabinet/     Übersicht, Detail, Editor, Füllstand
   ├─ Pets/        Liste + Detail, Editoren, Einstellungen
   ├─ Lexicon/     Übersicht, Artikel, Futter-Check
   ├─ Components/  Karten, Diagramm, Impfungen, Gamification
   ├─ Shared/      Faltzustand, Falz-Layout, Tier-Filter, Fotoauswahl
   └─ Theme/       Farben (hell + OLED-Schwarz), Schrift, handgezeichnete Details
```

## Teilen per AirDrop

- **Senden:** Tiere → ⚙︎ → „Alles teilen“ oder „Nur … teilen“, bzw. in der Tieransicht oben rechts. Das iOS-Teilen-Menü bietet AirDrop, Nachrichten, Mail, Dateien.
- **Empfangen:** Floof registriert das Format `.floof` – per AirDrop empfangene Dateien öffnen sich direkt in Floof mit Vorschau. Standard ist *Zusammenführen* (gleiche Tiere/Einträge werden aktualisiert, Neues ergänzt), optional *Alles ersetzen*.
- Ein einzelnes Tier enthält sein Tagebuch und die verknüpften Schrank-Artikel – ideal für Tiersitter.

## Daten

Alles liegt lokal in `Documents/floof-data.json` (+ `Documents/Photos`), mit
Dateischutz. Export/Import nutzt das Floof-Exportformat (Version 2 lesbar,
Version 3 ergänzt Tagebuch und Schrank).
