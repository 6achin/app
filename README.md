# BusinessAccountingApp (macOS)

Minimalistische macOS-App für Business-Buchhaltung mit Login und Dashboard.

## Start auf macOS

1. Terminal auf einem Mac öffnen (nicht in einem Linux-Container).
2. Sicherstellen, dass Xcode bzw. Command Line Tools mit macOS-SDK installiert sind.
3. App starten:

```bash
swift run BusinessAccountingApp
```

## Demo-Logins

- `inhaber` / `12345`
- `manager` / `biz2026`

## Hinweis zur Container-Umgebung

In Linux-Containern ist `SwiftUI` nicht verfügbar, deshalb schlägt `swift build` dort erwartbar fehl.
