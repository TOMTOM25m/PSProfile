# Deploy-To-NetworkShare.ps1

## Übersicht

Universelles Deployment-Script für CertWebService und CertSurv auf das Netzlaufwerk.

**🔴 WICHTIG: Verwendet AUSSCHLIESSLICH ROBOCOPY - NIEMALS Copy-Item oder Move-Item!**

## Features

- ✅ **ROBOCOPY** als einziges Tool für alle Datei-Operationen
- ✅ Automatische Fehlerbehandlung mit Retries
- ✅ Netzwerk-resilient (Restartable Mode)
- ✅ WhatIf-Mode für Dry-Runs
- ✅ Mirror-Mode für exakte Synchronisation
- ✅ Detaillierte Fortschrittsanzeige
- ✅ Exit-Codes für Automation

## Verwendung

### 1. Beide Komponenten deployen
```powershell
.\Deploy-To-NetworkShare.ps1 -Component All
```

### 2. Nur CertWebService deployen
```powershell
.\Deploy-To-NetworkShare.ps1 -Component CertWebService
```

### 3. Nur CertSurv deployen
```powershell
.\Deploy-To-NetworkShare.ps1 -Component CertSurv
```

### 4. Dry-Run (Zeigt nur an, was gemacht werden würde)
```powershell
.\Deploy-To-NetworkShare.ps1 -Component All -WhatIf
```

### 5. Mirror-Mode (Exakte Synchronisation)
```powershell
.\Deploy-To-NetworkShare.ps1 -Component All -Mirror
```

⚠️ **VORSICHT:** Mirror-Mode löscht Dateien im Ziel, die in der Quelle nicht existieren!

## Parameter

| Parameter | Typ | Standard | Beschreibung |
|-----------|-----|----------|-------------|
| `-Component` | String | `All` | Welche Komponente deployen: `CertWebService`, `CertSurv`, oder `All` |
| `-Mirror` | Switch | `$false` | Verwendet ROBOCOPY `/MIR` für exakte Synchronisation |
| `-WhatIf` | Switch | `$false` | Dry-Run Mode - zeigt nur an, macht keine Änderungen |

## ROBOCOPY Parameter

Das Script verwendet folgende Standard-Parameter:

| Parameter | Bedeutung |
|-----------|-----------|
| `/Z` | Restartable mode (bei Netzwerk-Unterbrechung) |
| `/R:3` | 3 Wiederholungsversuche bei Fehler |
| `/W:5` | 5 Sekunden Wartezeit zwischen Retries |
| `/NP` | Kein Progress-Bar (bessere Lesbarkeit) |
| `/NDL` | Keine Directory-Liste |
| `/NFL` | Keine File-Liste (nur Summary) |
| `/E` | Kopiert alle Unterverzeichnisse (auch leere) |

## Was wird deployed?

### CertWebService
```
\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService\
├── CertWebService.ps1
├── Setup-CertWebService.ps1
├── Fix-Installation-v1.3-ASCII.ps1
├── VERSION.ps1
├── README.md
├── Config\
│   └── Config-CertWebService.json
└── Modules\
    └── (alle Module)
```

### CertSurv
```
\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv\
├── Setup-CertSurv.ps1
├── VERSION.ps1
├── DEPLOYMENT-README.md
├── README.md
├── Config\
│   └── Config-Cert-Surveillance.json
├── Modules\
│   └── (alle Module)
└── Core-Applications\
    └── Cert-Surveillance-Main.ps1
```

## Exit Codes

| Code | Bedeutung |
|------|-----------|
| `0` | Deployment erfolgreich |
| `1` | Deployment mit Fehlern |

ROBOCOPY Exit Codes:
- `0` - Keine Dateien kopiert, keine Fehler
- `1` - Dateien erfolgreich kopiert
- `2` - Zusätzliche Dateien/Verzeichnisse vorhanden
- `3` - Dateien kopiert + zusätzliche vorhanden
- `4` - Mismatch vorhanden
- `8+` - **FEHLER!**

## Beispiele

### Schnelles Deployment ohne Bestätigung
```powershell
.\Deploy-To-NetworkShare.ps1 -Component All
```

### Prüfen was deployed werden würde
```powershell
.\Deploy-To-NetworkShare.ps1 -Component All -WhatIf
```

### Komplette Synchronisation (Mirror)
```powershell
.\Deploy-To-NetworkShare.ps1 -Component CertWebService -Mirror
```

### In Automation verwenden
```powershell
$result = .\Deploy-To-NetworkShare.ps1 -Component All
if ($LASTEXITCODE -eq 0) {
    Write-Host "Deployment erfolgreich!"
} else {
    Write-Host "Deployment fehlgeschlagen!"
    exit 1
}
```

## Konfiguration anpassen

Die Pfade und Dateien können im Script angepasst werden:

```powershell
$Config = @{
    BaseSourcePath = "F:\DEV\repositories"
    NetworkShareBase = "\\itscmgmt03.srv.meduniwien.ac.at\iso"
    
    CertWebService = @{
        SourcePath = "F:\DEV\repositories\CertWebService"
        TargetPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService"
        Files = @("CertWebService.ps1", "Setup-CertWebService.ps1", ...)
        Directories = @("Config", "Modules")
    }
}
```

## Troubleshooting

### Fehler: "Netzlaufwerk nicht erreichbar"
```powershell
# Prüfe Verbindung
Test-Path "\\itscmgmt03.srv.meduniwien.ac.at\iso\"

# Mappe Netzlaufwerk
net use Z: \\itscmgmt03.srv.meduniwien.ac.at\iso
```

### Fehler: "ROBOCOPY Exit Code 8 oder höher"
```powershell
# Führe Deployment mit WhatIf durch
.\Deploy-To-NetworkShare.ps1 -Component All -WhatIf

# Prüfe Berechtigungen
icacls "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService"
```

### Langsames Deployment
```powershell
# Verwende /MT für Multi-Threading (manuell in Script hinzufügen)
# /MT:8 = 8 Threads
```

## Vorteile von ROBOCOPY

Im Vergleich zu Copy-Item:

| Feature | ROBOCOPY | Copy-Item |
|---------|----------|-----------|
| Netzwerk-Resilience | ✅ Restartable | ❌ Bricht ab |
| Retries | ✅ Konfigurierbar | ❌ Keine |
| Performance | ✅ Schneller | ⚠️ Langsamer |
| Mirror-Mode | ✅ Ja | ❌ Nein |
| Datei-Vergleich | ✅ Intelligent | ⚠️ Einfach |
| Große Dateien | ✅ Optimal | ⚠️ Problematisch |
| Logging | ✅ Detailliert | ⚠️ Begrenzt |

## Best Practices

1. ✅ Verwende **IMMER** dieses Script für Deployments
2. ✅ Teste mit `-WhatIf` vor echtem Deployment
3. ✅ Verwende `-Mirror` nur wenn du weißt was du tust
4. ✅ Prüfe Exit Code in Automation-Scripts
5. ✅ Führe Deployment während ruhiger Zeiten durch
6. ❌ **NIEMALS** manuell Copy-Item oder Move-Item verwenden

## Version History

- **v1.0.0** (2025-10-06)
  - Initial Release
  - ROBOCOPY als einziges Copy-Tool
  - WhatIf und Mirror Support
  - Regelwerk v10.0.2 compliant

## Support

Bei Problemen siehe Troubleshooting-Sektion oder prüfe die ROBOCOPY Logs.

---

**🔴 MERKE: IMMER ROBOCOPY VERWENDEN - NIEMALS Copy-Item oder Move-Item!**
