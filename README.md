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

## Kennzahlen-Logik im Dashboard

- **Umsatz** = Summe der Netto-Beträge aus Ausgangsrechnungen.
- **Umsatzsteuer (Zahllast)** = Ausgangssteuer - Vorsteuer aus Eingangsrechnungen.
- **Einnahmen** = Umsatz - Umsatzsteuer-Zahllast - Kredite/Darlehen - Fixkosten (brutto).

## Hinzufügen-Workflow

Die Schaltfläche **Hinzufügen** erlaubt:
- Auswahl der Quelle: **PDF-Rechnung** oder **Manuelle Eingabe**.
- Auswahl des Typs: **Eingangsrechnung** oder **Ausgangsrechnung**.
- Eingabe von Netto, MwSt-Satz und Zahlungsstatus.

## Fixkosten-Workflow

- Auf die Karte **Fixkosten** klicken.
- Mit **Hinzufügen (+)** neue Position erstellen.
- Felder: Name, Intervall (monatlich/quartalsweise/halbjährlich/jährlich), automatische Abbuchung, Netto, Beschreibung.
- MwSt kann auf **19%**, **7%** oder **0%** gesetzt werden.
- **MwSt** und **Brutto** werden automatisch berechnet.
- Doppelklick auf eine Zeile öffnet den Bearbeitungsdialog.
- Schließen per **X**, **Abbrechen** oder Klick außerhalb des Dialogs.

## Hinweis zur Container-Umgebung

In Linux-Containern ist `SwiftUI` nicht verfügbar, deshalb schlägt `swift build` dort erwartbar fehl.
