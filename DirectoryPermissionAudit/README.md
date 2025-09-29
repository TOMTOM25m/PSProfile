# Directory Permission Audit Tool

## Overview

Modern PowerShell solution for generating comprehensive reports about directory permissions, group memberships, and user access. This tool allows administrators to audit access rights across folders with detailed user and group information.

## Features

- Interactive or automated permission analysis
- Active Directory + lokale Gruppen/Benutzer (Fallback lokal)
- Detaillierte Auflösung: Ordner -> Gruppe -> Benutzer
- Multi-Format Export: CSV, JSON, Human (Legacy Text)
- Modul-Nutzung oder direktes Skript
- PowerShell 5.1 & 7.x kompatibel (Unicode / TLS 1.2 Handling)
- Regelwerk v9.6.2 konform (Struktur, Logging, Messaging)

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

## Next Steps (Roadmap)

- [ ] HTML/Excel Export
- [ ] Parallelisierung (ForEach-Object -Parallel) optional
- [ ] Caching von Gruppenmitgliedschaften
- [ ] Scheduled Audit Beispielskript
- [ ] CI Workflow (Syntax + Style Check)

## Support / Meldungen

Bei Bedarf: `Send-DirectoryPermissionAuditMessage -TargetScript Monitoring -Message "Audit completed" -Type STATUS`

---
© $(Get-Date -Format yyyy) $Author – Regelwerk $RegelwerkVersion
