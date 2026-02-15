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

## Dashboard-Logik

- Alle KPI-Karten sind klickbar und öffnen jeweils eine Detailansicht.
- **Umsatz**: nach Monaten gruppierte Rechnungen mit Trennung in Ausgangs-/Eingangsrechnungen.
- **Rechnungen offen**: getrennte Listen für offene Ausgangs- und Eingangsrechnungen; per „Als bezahlt“ werden sie entfernt.
- **Einnahmen**: zeigt bezahlte Ausgangsrechnungen mit netto erhaltenem Betrag.
- Monatsstatistik auf dem Hauptscreen zeigt Umsatz/Einnahmen pro Monat.

## Hinzufügen-Workflow

- Auswahl der Quelle: **PDF-Rechnung** oder **Manuelle Eingabe**.
- Auswahl des Typs: **Eingangsrechnung** oder **Ausgangsrechnung**.
- Neu angelegte Rechnungen werden als offen gespeichert und in „Rechnungen offen“ angezeigt.

## Fixkosten-Workflow

- Karte **Fixkosten** öffnen.
- Neue Positionen mit Intervall, Netto, MwSt (19/7/0) und Beschreibung erfassen.
- Doppelklick auf eine Zeile öffnet die Bearbeitung.

## Hinweis zur Container-Umgebung

In Linux-Containern ist `SwiftUI` nicht verfügbar, deshalb schlägt `swift build` dort erwartbar fehl.
