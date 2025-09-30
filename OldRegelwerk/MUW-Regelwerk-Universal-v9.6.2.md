# PowerShell-Regelwerk Universal v9.6.2

## PowerShell Development Standards - Universell Anwendbar

### Version v9.6.2 | Datum 2025-09-27

---

## UNIVERSELLE ANWENDUNG

**Dieses Regelwerk gilt für ALLE PowerShell-Entwicklungsprojekte:**

- **Skript-Entwicklung** (Einzelne Scripts, Module, Funktionen)
- **System-Administration** (Server-Management, Automatisierung)
- **Anwendungsentwicklung** (Web-Services, APIs, Datenverarbeitung)
- **DevOps & Deployment** (CI/CD, Infrastruktur, Monitoring)
- **Wartung & Support** (Troubleshooting, Updates, Patches)

---

## REGELWERK-PHILOSOPHIE

### Grundprinzipien

1. **Konsistenz**: Einheitliche Standards über alle Projekte hinweg
2. **Lesbarkeit**: Code ist für Menschen geschrieben, nicht nur für Maschinen
3. **Wartbarkeit**: Einfache Pflege und Erweiterung über Jahre
4. **Interoperabilität**: Systeme können miteinander kommunizieren
5. **Skalierbarkeit**: Von kleinen Scripts bis zu Enterprise-Lösungen

---

## UNIVERSELLE STANDARDS

### §1. Script-Struktur

```powershell
# requires -Version 5.1

<#
.SYNOPSIS
    Kurze Beschreibung des Scripts

.DESCRIPTION
    Detaillierte Beschreibung der Funktionalität

.NOTES
    Author:         Flecki (Tom) Garnreiter
    Version:        1.0.0
    Regelwerk:      v9.6.2

.EXAMPLE
    .\Script-Name.ps1 -Parameter Value
#>

param(
    [switch]$WhatIf,
    [string]$LogLevel = "INFO"
)

#region Initialization
. (Join-Path (Split-Path -Path $MyInvocation.MyCommand.Path) "VERSION.ps1")
Show-ScriptInfo
#endregion

# Haupt-Logik hier...
```

### §2. Namenskonventionen

#### Script-Namen

```powershell
#  Empfohlene Namensgebung:
Setup-[SystemName].ps1      # System-Einrichtung
Deploy-[AppName].ps1        # Software-Deployment
Manage-[Service].ps1        # Service-Management
Monitor-[Component].ps1     # Überwachung
Test-[Component].ps1        # Test-Ausführung
```

#### Modul-Namen

```powershell
# Präfix-System verwenden:
[PRÄFIX]-Config.psm1        # z.B. FL-Config.psm1
[PRÄFIX]-Logging.psm1       # z.B. PS-Logging.psm1
[PRÄFIX]-Utils.psm1         # z.B. CORP-Utils.psm1
```

### §3. Versionsverwaltung

#### VERSION.ps1

```powershell
#region Version Information
$ScriptVersion = "1.0.0"
$RegelwerkVersion = "v9.6.2"
$BuildDate = "2025-09-27"
$Author = "Flecki (Tom) Garnreiter"

function Show-ScriptInfo {
    Write-Host " Script v$ScriptVersion" -ForegroundColor Green
    Write-Host " Build: $BuildDate" -ForegroundColor Cyan
    Write-Host " Author: $Author" -ForegroundColor Cyan
}
#endregion
```

### §4. Repository-Organisation

```text
ProjectName/
 README.md               # Projekt-Übersicht (PFLICHT)
 VERSION.ps1             # Versionsverwaltung (PFLICHT)
 Main-Script.ps1         # Haupt-Script
 Config/                 # Konfigurationsdateien
 Modules/                # PowerShell-Module
 LOG/                    # Log-Dateien
 Docs/                   # Dokumentation
 TEST/                   # Test-Scripts
 old/                    # Archivierte Dateien
```

### §5. Konfiguration

```json
{
    "ProjectInfo": {
        "Name": "Projekt Name",
        "Version": "1.0.0",
        "Environment": "Development"
    },
    "Settings": {
        "LogLevel": "INFO",
        "Language": "de-DE"
    }
}
```

### §6. Logging

```powershell
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $LogEntry = "[$Timestamp] [$Level] $Message"
    
    Write-Host $LogEntry -ForegroundColor $(
        switch ($Level) {
            "INFO" { "White" }
            "WARNING" { "Yellow" }
            "ERROR" { "Red" }
            default { "Gray" }
        }
    )
}
```

### §7. PowerShell-Versionskompatibilität

#### Unicode-Emojis und Sonderzeichen

**KRITISCH**: Unicode-Emojis sind NICHT kompatibel mit PowerShell 5.1!

```powershell
# ❌ FALSCH - Verursacht Parsing-Fehler in PS 5.1
function Show-Status {
    Write-Host "🚀 Starting process..." -ForegroundColor Green
    Write-Host "📋 Status: Running" -ForegroundColor Yellow
    Write-Host "⚙️ Configuration loaded" -ForegroundColor Cyan
}

# ✅ RICHTIG - Automatische Versionserkennung
function Show-Status {
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        # PowerShell 7.x - Unicode-Emojis erlaubt
        Write-Host "🚀 Starting process..." -ForegroundColor Green
        Write-Host "📋 Status: Running" -ForegroundColor Yellow
        Write-Host "⚙️ Configuration loaded" -ForegroundColor Cyan
    } else {
        # PowerShell 5.1 - ASCII-Alternativen verwenden
        Write-Host ">> Starting process..." -ForegroundColor Green
        Write-Host "Status: Running" -ForegroundColor Yellow
        Write-Host "[CFG] Configuration loaded" -ForegroundColor Cyan
    }
}

# ✅ OPTIMAL - Separate Funktionen für bessere Performance
function Show-StatusPS7 {
    Write-Host "🚀 Starting process..." -ForegroundColor Green
    Write-Host "📋 Status: Running" -ForegroundColor Yellow
    Write-Host "⚙️ Configuration loaded" -ForegroundColor Cyan
}

function Show-StatusPS5 {
    Write-Host ">> Starting process..." -ForegroundColor Green
    Write-Host "Status: Running" -ForegroundColor Yellow
    Write-Host "[CFG] Configuration loaded" -ForegroundColor Cyan
}

# Automatische Funktionsauswahl
if ($PSVersionTable.PSVersion.Major -ge 7) {
    Set-Alias Show-Status Show-StatusPS7
} else {
    Set-Alias Show-Status Show-StatusPS5
}
```

#### ASCII-Alternativen für häufige Emojis

| Unicode Emoji | PowerShell 5.1 Alternative | Verwendung |
|---------------|----------------------------|------------|
| 🚀 | `>>` oder `[START]` | Prozess-Start |
| 📋 | `[INFO]` oder `Status:` | Informationen |
| ⚙️ | `[CFG]` oder `Config:` | Konfiguration |
| ✅ | `[OK]` oder `SUCCESS:` | Erfolg |
| ❌ | `[ERROR]` oder `FAILED:` | Fehler |
| ⚠️ | `[WARN]` oder `WARNING:` | Warnung |
| 📁 | `[DIR]` oder `Folder:` | Verzeichnisse |
| 📄 | `[FILE]` oder `File:` | Dateien |
| 🔧 | `[TOOLS]` oder `Tools:` | Werkzeuge |
| 💾 | `[SAVE]` oder `Backup:` | Speichern |

#### Implementierungsrichtlinien

1. **Automatische Versionserkennung MANDATORY**
2. **Separate Funktionen für PS5.1 und PS7.x empfohlen**
3. **ASCII-Alternativen müssen aussagekräftig sein**
4. **Testing auf BEIDEN PowerShell-Versionen erforderlich**

### §8. E-Mail-Integration Template

#### Standard Mail-Konfiguration

**SMTP-Server Konfiguration für MedUni Wien:**

```powershell
# E-Mail Standard-Konfiguration
$EmailConfig = @{
    SMTPServer = "smtp.meduniwien.ac.at"
    From = "$env:COMPUTERNAME@meduniwien.ac.at"
    Port = 25
    UseSSL = $false
}

# Umgebungsspezifische Empfänger
$Recipients = @{
    DEV = @{
        Primary = "thomas.garnreiter@meduniwien.ac.at"
        Subject = "[DEV] PowerShell Script Notification"
    }
    PROD = @{
        Primary = "win-admin@meduniwien.ac.at"
        Subject = "[PROD] PowerShell Script Notification"
    }
}
```

#### Standard Mail-Funktion

```powershell
function Send-StandardMail {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter(Mandatory)]
        [ValidateSet("DEV", "PROD")]
        [string]$Environment,
        
        [string]$Subject = $null,
        [string]$Priority = "Normal"
    )
    
    try {
        # Umgebungsspezifische Konfiguration
        $Recipient = $Recipients[$Environment]
        $MailSubject = if ($Subject) { $Subject } else { $Recipient.Subject }
        
        # Mail-Parameter
        $MailParams = @{
            SmtpServer = $EmailConfig.SMTPServer
            From = $EmailConfig.From
            To = $Recipient.Primary
            Subject = $MailSubject
            Body = $Message
            Port = $EmailConfig.Port
        }
        
        # Mail versenden
        Send-MailMessage @MailParams
        Write-Log "Mail erfolgreich gesendet an: $($Recipient.Primary)" -Level "INFO"
        
    } catch {
        Write-Log "Fehler beim Mail-Versand: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}
```

#### Verwendungsbeispiele

```powershell
# DEV-Umgebung Notification
Send-StandardMail -Message "Script ausgeführt - Status: OK" -Environment "DEV"

# PROD-Umgebung mit custom Subject
Send-StandardMail -Message "Deployment abgeschlossen" -Environment "PROD" -Subject "[PROD] ResetProfile Deployment Status"

# Mit Formatierung
$StatusMessage = @"
PowerShell Script Ausführung - Status Report

Script: Reset-PowerShellProfiles.ps1
Version: $ScriptVersion
Zeitpunkt: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Status: Erfolgreich abgeschlossen

Details:
- Profile zurückgesetzt: 15
- Fehler aufgetreten: 0
- Ausführungszeit: 2.3 Sekunden

System: $env:COMPUTERNAME
Benutzer: $env:USERNAME
"@

Send-StandardMail -Message $StatusMessage -Environment "PROD"
```

#### Mail-Template Richtlinien

1. **SMTP-Server**: Immer `smtp.meduniwien.ac.at` verwenden
2. **Sender-Adresse**: Automatisch `$env:COMPUTERNAME@meduniwien.ac.at` (Computer-spezifisch)
3. **Umgebungstrennung**: DEV vs PROD Empfänger strikt trennen
4. **Subject-Convention**: `[ENV] Description` Format verwenden
5. **Error-Handling**: Mail-Fehler loggen, aber Script nicht beenden
6. **Encoding**: UTF-8 für deutsche Umlaute

**Hinweis zur Sender-Adresse**: Die dynamische Verwendung von `$env:COMPUTERNAME@meduniwien.ac.at` ermöglicht es, den sendenden Server/Computer automatisch zu identifizieren. Dies ist besonders nützlich bei verteilten Systemen und erleichtert das Troubleshooting.

---

## COMPLIANCE-CHECKLISTE

### Projekt-Deployment

- [ ]  Sprechende Script-Namen verwendet
- [ ]  Standard-Verzeichnisstruktur implementiert  
- [ ]  VERSION.ps1 erstellt
- [ ]  README.md vorhanden
- [ ]  Namenskonventionen befolgt
- [ ]  Logging implementiert
- [ ]  Fehlerbehandlung vorhanden
- [ ]  PowerShell 5.1 & 7.x Kompatibilität getestet
- [ ]  Unicode-Emojis nur in PS7.x Funktionen verwendet
- [ ]  ASCII-Alternativen für PS5.1 implementiert
- [ ]  E-Mail-Integration nach Standard-Template implementiert
- [ ]  SMTP-Konfiguration für MedUni Wien korrekt

---

## ANWENDUNGSEMPFEHLUNGEN

### Kleine Scripts (< 100 Zeilen)

- VERSION.ps1 + Basic Logging
- Sprechende Namen
- Comment-Based Help

### Mittlere Projekte (100-500 Zeilen)

- Vollständige Struktur
- Modulare Architektur
- Test-Scripts

### Große Projekte (> 500 Zeilen)

- Komplette Standards
- Umfassende Tests
- Performance-Optimierung

---

## IMPLEMENTIERUNG

### 4-Phasen-Roadmap

1. **Tag 1**: Grundstruktur erstellen
2. **Tag 2-7**: Entwicklung nach Standards
3. **Tag 8-10**: Qualitätssicherung
4. **Tag 11**: Production-Deployment

---

## ENTWICKLUNGSHISTORIE

### v9.6.0 (2025-09-27) - UNIVERSELLE VERSION

- Vollständig universell anwendbar
- Flexible Präfix-Systeme
- Einheitliche Struktur
- Cross-Script Kommunikation
- **NEU**: Unicode-Emoji Kompatibilitätsrichtlinien (§7)
- **NEU**: PowerShell 5.1/7.x Versionskompatibilität
- **NEU**: ASCII-Alternativen für Unicode-Zeichen
- **NEU**: E-Mail-Integration Template (§8)
- **NEU**: Standard SMTP-Konfiguration für MedUni Wien

### v9.5.0 (2025-09-23)

- File Operations Standards
- Script Versioning Standards

### v9.4.0 (2025-09-22)

- PowerShell Compatibility
- Universal Functions

---

**AUTOR**: Flecki (Tom) Garnreiter
**STATUS**: Universal Standard für alle PowerShell-Projekte
**GÜLTIG AB**: 2025-09-27
**NÄCHSTE REVIEW**: 2025-12-27
