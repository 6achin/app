# BusinessAccountingApp (macOS)

Schnelle, minimalistische macOS-App für Business-Buchhaltung mit Login und Dashboard.

## Start auf macOS

1. Terminal auf einem Mac öffnen (nicht in einem Linux-Container).
2. Sicherstellen, dass Xcode bzw. Command Line Tools mit macOS-SDK installiert sind.
3. App starten:

```bash
swift run BusinessAccountingApp
```

## Demo-Logins

- `bachin` / `12345` (Admin)
- `manager` / `biz2026`

## Neue Funktion: Fixkosten-Workflow

- Auf die Karte **Fixkosten** klicken.
- Mit **Hinzufügen (+)** eine neue Fixkosten-Position anlegen.
- Felder: Name, Datum, automatische Abbuchung (Ja/Nein), Summe Netto, Beschreibung.
- **MwSt (19%)** und **Brutto** werden automatisch aus Netto berechnet.

## Hinweis zur Container-Umgebung

In Linux-Containern ist `SwiftUI` nicht verfügbar, deshalb schlägt `swift build` dort erwartbar fehl.
