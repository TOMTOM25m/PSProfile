# ResetProfile Production Deployment Guide
*Produktions-Deployment-Anleitung für ResetProfile v11.2.6*

## 🎯 Deployment-Ziel

**Produktiver Netzwerkpfad**: `\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\PSProfile\`

## 📋 Voraussetzungen

### Systemanforderungen
- **PowerShell 5.1+** (Administrator-Rechte erforderlich)
- **Netzwerk-Zugriff** auf `itscmgmt03.srv.meduniwien.ac.at`
- **Schreibberechtigungen** auf `\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\`
- **Robocopy** (für Enterprise-Backup)

### Vor dem Deployment prüfen
```powershell
# Server-Erreichbarkeit testen
Test-Connection -ComputerName itscmgmt03.srv.meduniwien.ac.at -Count 2

# Netzwerkpfad-Zugriff prüfen  
Test-Path "\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\"

# Aktuelle Version anzeigen
Get-Content "VERSION.ps1" | Select-String "ScriptVersion"
```

## 🚀 Deployment-Prozess

### Schritt 1: Validierung (PFLICHT)
```powershell
# Erst Validierung ohne Deployment
.\Deploy-ResetProfile-Production.ps1 -ValidateOnly

# Erwartetes Ergebnis:
# 📊 Production Access Validation: 4/4 (100%)
# ✅ Validation completed successfully!
```

### Schritt 2: Produktions-Deployment mit Backup
```powershell
# Standard-Deployment mit automatischem Backup
.\Deploy-ResetProfile-Production.ps1 -BackupExisting

# Überwachung des Deployment-Fortschritts:
# Phase 1: Pre-Deployment Validation ✅
# Phase 2: Backup Existing Production  ✅  
# Phase 3: Clean Deployment          ✅
# Phase 4: Production Configuration   ✅
# Phase 5: Deployment Manifest       ✅
```

### Schritt 3: Deployment-Verifikation
```powershell
# Produktive Version prüfen
& "\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\PSProfile\VERSION.ps1"

# Hauptscript testen (WhatIf-Modus)
& "\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\PSProfile\Reset-PowerShellProfiles.ps1" -WhatIf

# Deployment-Manifest prüfen
Get-Content "\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\PSProfile\DEPLOYMENT-MANIFEST.json" | ConvertFrom-Json
```

## 📁 Deployment-Struktur

Nach erfolgreichem Deployment auf `\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\PSProfile\`:

```
PSProfile/
├── Reset-PowerShellProfiles.ps1    # Haupt-Script v11.2.6
├── VERSION.ps1                      # Versionsverwaltung
├── DEPLOYMENT-MANIFEST.json         # Deployment-Informationen
├── Config/                          
│   ├── Config-Reset-PowerShellProfiles.ps1.json  # Produktions-Konfiguration
│   ├── de-DE.json                   # Deutsche Lokalisierung
│   └── en-US.json                   # Englische Lokalisierung
├── Modules/
│   ├── FL-Config.psm1               # Konfigurationsverwaltung
│   ├── FL-Logging.psm1              # Logging-Framework
│   ├── FL-Gui.psm1                  # GUI-Framework
│   ├── FL-Utils.psm1                # Utilities
│   └── FL-Maintenance.psm1          # Wartungsfunktionen
└── Templates/
    ├── Profile-template.ps1         # Standard-Profil-Template
    ├── Profile-templateX.ps1        # Erweiterte Profil-Template
    └── Profile-templateMOD.ps1      # Moderne Profil-Template
```

## 🔧 Deployment-Parameter

### Verfügbare Parameter
```powershell
.\Deploy-ResetProfile-Production.ps1 [Parameter]

# -ValidateOnly        Nur Validierung, kein Deployment
# -BackupExisting      Backup erstellen (Standard: $true)  
# -Force              Deployment auch bei Warnungen
# -WhatIf             Simulation des Deployment-Prozesses
# -Verbose            Detaillierte Ausgabe
```

### Beispiel-Kommandos
```powershell
# Sicheres Standard-Deployment
.\Deploy-ResetProfile-Production.ps1 -BackupExisting -Verbose

# Deployment ohne Backup (nicht empfohlen)
.\Deploy-ResetProfile-Production.ps1 -BackupExisting:$false

# Force-Deployment bei Warnungen
.\Deploy-ResetProfile-Production.ps1 -Force

# Vollständige Simulation
.\Deploy-ResetProfile-Production.ps1 -WhatIf -Verbose
```

## 📊 Deployment-Monitoring

### Log-Dateien
- **Deployment-Log**: `\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\Logs\Deployment\Deployment-[Timestamp].log`
- **Robocopy-Log**: `C:\Temp\Deployment-Backup.log`
- **Windows Event Log**: Application Log, Source: "PSProfile"

### Status-Überwachung
```powershell
# Deployment-Status prüfen
Get-Content "LOG\Status\Reset-PowerShellProfiles-Status.json" | ConvertFrom-Json

# Produktions-Logs überwachen
Get-Content "\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\Logs\PSProfile\$(Get-Date -Format 'yyyy-MM-dd').jsonl" -Tail 10
```

## 🛡️ Backup & Rollback

### Automatisches Backup
Bei jedem Deployment wird automatisch ein Backup erstellt:
```
\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\Backup\PSProfile\
└── v11.2.6_2025-09-28_14-30-15/
    ├── BACKUP-MANIFEST.json
    ├── Reset-PowerShellProfiles.ps1
    ├── VERSION.ps1
    ├── Config/
    ├── Modules/
    └── Templates/
```

### Rollback-Prozess
```powershell
# 1. Verfügbare Backups anzeigen
Get-ChildItem "\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\Backup\PSProfile\" | Sort-Object Name -Descending

# 2. Rollback zu vorheriger Version
$BackupPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\Backup\PSProfile\v11.2.5_2025-09-27_10-15-30"
$ProductionPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\PSProfile"

# Aktuelle Version sichern
Rename-Item $ProductionPath "${ProductionPath}_ROLLBACK_$(Get-Date -Format 'yyyyMMdd-HHmmss')"

# Backup wiederherstellen
Copy-Item $BackupPath $ProductionPath -Recurse -Force

# Rollback verifizieren
& "$ProductionPath\VERSION.ps1"
```

## ⚠️ Wichtige Sicherheitshinweise

### KRITISCHE Regeln
1. **NIEMALS** direkt in der Produktion entwickeln
2. **IMMER** Validierung vor Deployment ausführen
3. **IMMER** Backup erstellen (außer bei kritischen Hotfixes)
4. **NIEMALS** `-Force` ohne vorherige Analyse verwenden
5. **IMMER** Deployment-Manifest prüfen

### Produktions-Umgebung
- **Environment**: Automatisch auf "PROD" gesetzt
- **WhatIf-Modus**: Automatisch deaktiviert
- **Git-Updates**: Automatisch deaktiviert für Produktions-Sicherheit
- **E-Mail-Sender**: Automatisch auf `noreply-prod@meduniwien.ac.at`
- **Logging**: Erweiterte Retention (90 Tage Logs, 365 Tage Archive)

## 🔍 Troubleshooting

### Häufige Probleme

#### Netzwerk-Zugriff fehlgeschlagen
```
❌ Server itscmgmt03.srv.meduniwien.ac.at is not reachable
```
**Lösung**:
```powershell
# VPN-Verbindung prüfen
Test-NetConnection -ComputerName itscmgmt03.srv.meduniwien.ac.at -Port 445

# Alternative: IP-Adresse verwenden
nslookup itscmgmt03.srv.meduniwien.ac.at
```

#### Berechtigungs-Probleme
```
❌ Write permission test failed: Access denied
```
**Lösung**:
```powershell
# Als Administrator ausführen
Start-Process PowerShell -Verb RunAs

# Oder Credentials explizit angeben
$Cred = Get-Credential
New-PSDrive -Name "PROD" -PSProvider FileSystem -Root "\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD" -Credential $Cred
```

#### Robocopy-Fehler
```
❌ Backup failed with Robocopy exit code: 8
```
**Robocopy Exit Codes**:
- **0-7**: Erfolgreich (0=Keine Änderungen, 1=Dateien kopiert, etc.)
- **8+**: Fehler (8=Fehler beim Kopieren, 16=Schwerer Fehler)

**Lösung**: Logs in `C:\Temp\Deployment-Backup.log` prüfen

### Deployment-Validierung fehlgeschlagen
```powershell
# Detaillierte Validierung
.\Deploy-ResetProfile-Production.ps1 -ValidateOnly -Verbose

# Source-Integrität einzeln prüfen
Test-Path "Reset-PowerShellProfiles.ps1"
Test-Path "VERSION.ps1" 
Test-Path "Modules\FL-*.psm1"
Test-Path "Templates\Profile-template*.ps1"
```

## 📞 Support & Kontakt

Bei Deployment-Problemen:

1. **Deployment-Logs** prüfen: `\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\Logs\Deployment\`
2. **Windows Event Log** kontrollieren (Application Log, Source: "PSProfile")
3. **Backup-Integrität** validieren vor Rollback
4. **Kontakt**: thomas.garnreiter@meduniwien.ac.at

---

## ✅ Deployment-Checkliste

- [ ] Netzwerk-Zugriff auf itscmgmt03.srv.meduniwien.ac.at validiert
- [ ] Administrator-Rechte bestätigt
- [ ] `Deploy-ResetProfile-Production.ps1 -ValidateOnly` erfolgreich
- [ ] Backup-Strategie definiert
- [ ] Deployment mit `Deploy-ResetProfile-Production.ps1 -BackupExisting` ausgeführt
- [ ] Deployment-Manifest geprüft
- [ ] Produktive Version mit `-WhatIf` getestet
- [ ] Rollback-Plan dokumentiert
- [ ] Deployment-Logs archiviert

**Version**: ResetProfile v11.2.6 | **Regelwerk**: v9.6.2 | **Deployment-Target**: `\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\PSProfile\`