# Floof

Haustier-Gesundheits- und Medikamenten-App (SwiftUI) mit adaptivem Layout für faltbare iPhones.

## Aufbau

```
Floof/
├─ App/FloofApp.swift                 Einstiegspunkt
├─ Models/PetModels.swift             Datenmodell = Floof-Export (version 2)
├─ Store/PetStore.swift               @Observable Store, Tagesdosen, Import
├─ Views/Adaptive/
│  ├─ DevicePosture.swift             zugeklappt/aufgeklappt aus der Geometrie
│  └─ AdaptiveRootView.swift          Hauptansicht, wechselt das Layout animiert
├─ Views/Folded/CompactDashboardView  Außendisplay: Einhand, große Medikamenten-Karten
├─ Views/Unfolded/ExpandedDashboard   Innendisplay: 2 Spalten (Checkliste+Stammdaten | Gewicht+Impfungen)
├─ Views/Components/…                 Karten, Swift-Charts-Gewichtsverlauf, Impfkalender
└─ Resources/Info-FullScreen.plist    Info.plist-Schlüssel gegen Letterboxing
```

## Einrichten

1. In Xcode ein neues iOS-App-Projekt „Floof“ (SwiftUI) anlegen, Mindestziel iOS 18.
2. Den Ordner `Floof/` ins Projekt ziehen (die generierte `ContentView`/`App`-Datei löschen).
3. Schlüssel aus `Resources/Info-FullScreen.plist` in die Info.plist des Targets übernehmen.
4. Eigene Daten über den Import-Button (oben rechts) aus einer Floof-Export-JSON laden.

## Faltzustand

`DevicePosture.resolve` entscheidet anhand von Size Class **und** Seitenverhältnis der
verfügbaren Fläche (4:3 innen ≈ 0,75, außen ≈ 0,46). Sollte das SDK eine eigene
Faltzustand-API anbieten, wird sie nur dort eingehängt.
