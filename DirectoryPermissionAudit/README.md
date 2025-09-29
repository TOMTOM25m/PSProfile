# Directory Permission Audit Tool

## Overview

Modern PowerShell solution for generating comprehensive reports about directory permissions, group memberships, and user access. This tool allows administrators to audit access rights across folders with detailed user and group information.

## Features

- Interaktiv oder automatisiert
- AD + lokale Gruppen/Benutzer (Fallback lokal)
- Auflösung: Ordner -> Gruppe -> Benutzer
- Exportformate: CSV, JSON, Human (Legacy Text), HTML (mit Hervorhebung), Excel (Fallback CSV falls ImportExcel fehlt)
- Modul oder Wrapper-Skript
- PowerShell 5.1 & 7.x kompatibel (Unicode / TLS 1.2)
- Regelwerk v9.6.2 konform (Struktur, Logging, Messaging)
- Konfigurierbare Defaults (PSD1 Settings + GUI Editor)

## Usage

### Option 1: Direktes Skript (Legacy-kompatibel)

```powershell
./FolderPermissionReport.ps1             # Interaktiv (Pfadauswahl Dialog)
./FolderPermissionReport.ps1 -Path D:\Data -OutputFormat CSV -Depth 2 -IncludeInherited
```

### Option 2: Als Modul verwenden

```powershell
Import-Module (Join-Path $PWD 'DirectoryPermissionAudit.psm1') -Force

# Audit starten (automatisch)
Start-DirectoryPermissionAudit -Path D:\Data -Depth 1 -OutputFormat JSON

# Interaktiv mit Dialog
Start-DirectoryPermissionAudit -Interactive -OutputFormat CSV

# Nur Analyse ausführen und Ergebnisobjekte im Speicher behalten
Invoke-DirectoryPermissionAnalysis -RootPath D:\Data -MaxDepth 1
$GlobalReport = $script:ReportData  # (im Modul-Scope)

# Export explizit
Export-ReportData -RootPath D:\Data -Format CSV -OutputPath C:\Reports
```

### Rückgabe / Datenstrukturen

- `$script:ReportData` : Flache Tabelle (Ordner, Gruppe, Benutzer, Rechte)
- `$script:VZinfosGesamt` : Struktur analog zur ursprünglichen Textausgabe

Beispiel einer Report-Zeile (CSV/JSON):

```text
FolderPath;GroupName;Permission;UserID;UserName;FullName;IsActive;Timestamp
```

## Standards Compliance

This project follows the [Universal PowerShell Regelwerk v9.6.2](../PowerShell-Regelwerk-Universal-v9.6.2.md) standard for PowerShell script development, which establishes consistent practices for:

- Version management and change history
- Code structure and regions
- Cross-script communication
- Error handling and logging
- Parameter validation
- Security practices
- Unicode compatibility (PowerShell 5.1/7.x dual paths)

## Repository Structure

```plaintext
DirectoryPermissionAudit/
├── FolderPermissionReport.ps1      # Hauptskript (Wrapper, lädt Modul)
├── DirectoryPermissionAudit.psm1   # Modul (Start-/Analyse-/Export-Funktionen)
├── VERSION.ps1                     # Version + Info + Messaging
├── README.md                      # Dokumentation
├── IMPLEMENTATION.md              # Regelwerk-Umsetzungsdetails
├── old/                           # Archiv (Legacy/Alt-Dateien)
└── LOG/                           # Wird automatisch erzeugt
    ├── Messages/                  # Cross-Script Nachrichten
    └── Reports/                   # Exportierte Reports
```

## Requirements

- PowerShell 5.1 oder 7.x
- AD-Modul (nur bei Domänenumgebung für Gruppen-/Userauflösung)
- Administrative Rechte empfohlen (vollständige ACL-Lesbarkeit)

Optional (zukünftig):

- PSScriptAnalyzer für CI
- Signaturprüfung

## History

| Version | Datum | Beschreibung |
|---------|-------|--------------|
| v2.2.0  | 2025-09-29 | Migration auf Regelwerk v9.6.2, Modul hinzugefügt |
| v2.1.0  | 2023-03-08 | Legacy signierte Version, rein interaktiv |

### Legacy Artefakte (Archiv: old\)

- FolderPermissionReport-legacy.exe (alte kompilierte Fassung)
- FolderPermissionReport-legacy-copy.ps1 (redundante Kopie der Vorgängerversion)
- OrdnerBerechtigungsstruktur_legacy.au3 (AutoIt Ursprung)
- main_code_section-archive.ps1 (Zwischenstand aus Refactor-Phase)

Legacy Name: VerzeichnisBerechtigungsAuswertung (intern)

## Konfiguration

Standardwerte werden aus `Config/DirectoryPermissionAudit.settings.psd1` geladen.

Beispiel:
 
```powershell
@{
    DefaultOutputFormat   = 'HTML'
    DefaultDepth          = 0
    IncludeInherited      = $true
    IncludeSystemAccounts = $false
    Parallel              = $false
    Throttle              = 5
}
```
Angepasste Werte wirken nur, wenn Parameter beim Aufruf nicht gesetzt werden.

GUI zum Bearbeiten:
 
```powershell
pwsh -File .\Scripts\Setup-GUI.ps1
```

Erlaubt Speichern (PSD1) & Export nach JSON.

### Erweiterte Filter & Pruning

Neue Parameter (ab v2.3.0):

```powershell
Start-DirectoryPermissionAudit -Path D:\Data -GroupInclude 'HR*','FIN-*' -GroupExclude '*Temp*' -PruneEmpty
```

- `-GroupInclude` : Liste von Wildcards – nur passende Gruppen bleiben erhalten
- `-GroupExclude` : Liste von Wildcards – passende Gruppen werden entfernt
- `-PruneEmpty`   : Entfernt Ordner ohne verbleibende Einträge nach dem Filtern

Hinweis: Filtering passiert vor Export; HTML/CSV/JSON enthalten nur verbleibende Datensätze.


## Next Steps (Roadmap)

- [x] HTML/Excel Export
- [x] Parallelisierung optional
- [x] Caching (Gruppen- & User-Lookups)
- [x] GUI für Settings
- [x] CI Workflow (Analyzer + Import Smoke)
- [ ] Scheduled Audit Beispielskript
- [x] Filter: -GroupInclude / -GroupExclude
- [x] Option: -PruneEmpty
- [ ] Persistenter Cache (optional JSON)
- [ ] Pester Tests (Analyse / Export)
- [ ] CI Matrix (PS 5.1 + 7.x) + Badge
- [ ] HTML Template externalisierbar
- [ ] Logging-Rotation / Retention
- [ ] Code Signing / Release Automation

## Support / Meldungen

Bei Bedarf: `Send-DirectoryPermissionAuditMessage -TargetScript Monitoring -Message "Audit completed" -Type STATUS`

---
© $(Get-Date -Format yyyy) $Author – Regelwerk $RegelwerkVersion
