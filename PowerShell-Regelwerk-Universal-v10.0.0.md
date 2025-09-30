# PowerShell-Regelwerk Universal v10.0.0

**Enterprise Complete Edition - Comprehensive PowerShell Development Standards**

---

## 📋 Document Information

| **Attribute** | **Value** |
|---------------|-----------|
| **Version** | v10.0.0 |
| **Status** | Enterprise Complete |
| **Release Date** | 2025-09-29 |
| **Author** | © Flecki (Tom) Garnreiter |
| **Supersedes** | PowerShell-Regelwerk Universal v9.9.0 |
| **Scope** | Enterprise PowerShell Development |
| **License** | MIT License |
| **Language** | DE/EN (Bilingual) |

---

## 🎯 Executive Summary

**[DE]** Das PowerShell-Regelwerk Universal v10.0.0 Enterprise Complete Edition stellt die umfassendste Sammlung von PowerShell-Entwicklungsstandards dar. Mit 15 klar definierten Paragraphen, inklusive 6 neuer Enterprise-Standards, definiert es moderne, robuste und wartbare PowerShell-Entwicklung für Unternehmensumgebungen.

**[EN]** The PowerShell-Regelwerk Universal v10.0.0 Enterprise Complete Edition represents the most comprehensive collection of PowerShell development standards. With 15 clearly defined paragraphs, including 6 new enterprise standards, it defines modern, robust, and maintainable PowerShell development for enterprise environments.

---

## 📖 Inhaltsverzeichnis / Table of Contents

### Teil A: Grundlagen-Paragraphen / Foundation Paragraphs

- **[§1: Version Management](#§1-version-management--versionsverwaltung)**
- **[§2: Script Headers & Naming](#§2-script-headers--naming--script-kopfzeilen--namensgebung)**
- **[§3: Functions](#§3-functions--funktionen)**
- **[§4: Error Handling](#§4-error-handling--fehlerbehandlung)**
- **[§5: Logging](#§5-logging--protokollierung)**
- **[§6: Configuration](#§6-configuration--konfiguration)**
- **[§7: Modules & Repository Structure](#§7-modules--repository-structure--module--repository-struktur)**
- **[§8: PowerShell Compatibility](#§8-powershell-compatibility--powershell-kompatibilität)**
- **[§9: GUI Standards](#§9-gui-standards--gui-standards)**

### Teil B: Enterprise-Paragraphen / Enterprise Paragraphs

- **[§10: Strict Modularity](#§10-strict-modularity--strikte-modularität)**
- **[§11: File Operations](#§11-file-operations--dateivorgänge)**
- **[§12: Cross-Script Communication](#§12-cross-script-communication--script-übergreifende-kommunikation)**
- **[§13: Network Operations](#§13-network-operations--netzwerkoperationen)**
- **[§14: Security Standards](#§14-security-standards--sicherheitsstandards)**
- **[§15: Performance Optimization](#§15-performance-optimization--performance-optimierung)**

---

## 🌟 UNIVERSELLE ANWENDUNG

**Dieses Regelwerk gilt für ALLE PowerShell-Entwicklungsprojekte:**

- **Skript-Entwicklung** (Einzelne Scripts, Module, Funktionen)
- **System-Administration** (Server-Management, Automatisierung)
- **Anwendungsentwicklung** (Web-Services, APIs, Datenverarbeitung)
- **DevOps & Deployment** (CI/CD, Infrastruktur, Monitoring)
- **Wartung & Support** (Troubleshooting, Updates, Patches)

---

## 🎨 REGELWERK-PHILOSOPHIE

### Grundprinzipien

1. **Konsistenz**: Einheitliche Standards über alle Projekte hinweg
2. **Lesbarkeit**: Code ist für Menschen geschrieben, nicht nur für Maschinen
3. **Wartbarkeit**: Einfache Pflege und Erweiterung über Jahre
4. **Interoperabilität**: Systeme können miteinander kommunizieren
5. **Skalierbarität**: Von kleinen Scripts bis zu Enterprise-Lösungen
6. **Modularität**: Strikte Trennung von Logik und Implementierung (NEU v10.0.0)
7. **Robustheit**: Fehlerresistente und zuverlässige Implementierungen (NEU v10.0.0)

---

# Teil A: Grundlagen-Paragraphen

## §1 Version Management / Versionsverwaltung

### 🔧 **Mandatory Requirements**

- **`VERSION.ps1`**: Jedes Projekt MUSS eine `VERSION.ps1` Datei zur zentralen Versionsverwaltung besitzen.
- **Semantic Versioning**: Die Versionierung MUSS dem `MAJOR.MINOR.PATCH` Schema folgen.
- **Regelwerk Reference**: Die `VERSION.ps1` MUSS eine explizite Referenz zur angewendeten Regelwerk-Version enthalten.

### 💻 **`VERSION.ps1` Template**

```powershell
#region Version Information (MANDATORY - Regelwerk v10.0.0)
$ScriptVersion = "1.0.0"  # Semantic Versioning: MAJOR.MINOR.PATCH
$RegelwerkVersion = "v10.0.0"
$BuildDate = "2025-09-29"
$Author = "Flecki (Tom) Garnreiter"

<#
.VERSION HISTORY (MANDATORY)
1.0.0 - 2025-09-29 - Initial release with Regelwerk v10.0.0 compliance
#>

function Show-ScriptInfo {
    param(
        [string]$ScriptName = $MyInvocation.MyCommand.Name,
        [string]$CurrentVersion = $ScriptVersion
    )
    
    # PowerShell 5.1/7.x compatibility (Regelwerk v10.0.0 §8)
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        Write-Host "🚀 $ScriptName v$CurrentVersion" -ForegroundColor Green
        Write-Host "📅 Build: $BuildDate | Regelwerk: $RegelwerkVersion" -ForegroundColor Cyan
    } else {
        Write-Host ">> $ScriptName v$CurrentVersion" -ForegroundColor Green
        Write-Host "[BUILD] $BuildDate | Regelwerk: $RegelwerkVersion" -ForegroundColor Cyan
    }
}
#endregion
```

---

## §2 Script Headers & Naming / Script-Kopfzeilen & Namensgebung

### 🔧 **Mandatory Requirements**

- **Comment-Based Help**: Jedes Script und jede Funktion MUSS ein vollständiges Comment-Based Help (CBH) haben.
- **Standard Header**: Der Header MUSS `.SYNOPSIS`, `.DESCRIPTION`, `.NOTES`, und `.EXAMPLE` enthalten.
- **Verb-Nomen-Konvention**: Alle Funktions- und Scriptnamen MÜSSEN der `Verb-Nomen` Konvention folgen.

### 💻 **Script Header & Naming Template**

```powershell
<#
.SYNOPSIS
    [DE] Kurze Beschreibung des Scripts.
    [EN] Brief description of the script.

.DESCRIPTION
    [DE] Detaillierte Beschreibung der Funktionalität.
    [EN] Detailed description of functionality.

.NOTES
    Author:         Flecki (Tom) Garnreiter
    Version:        1.0.0
    Regelwerk:      v10.0.0
    Copyright:      © 2025 Flecki Garnreiter

.EXAMPLE
    .\Deploy-Application.ps1 -AppName "CertWebService"
    Deploys the application "CertWebService".
#>
param()
```

### 📝 **Script Naming Patterns**

```powershell
# ✅ MANDATORY Naming Patterns (PFLICHT):
Deploy-[AppName].ps1                # Software deployment
Setup-[SystemName].ps1              # System setup
Manage-[Service].ps1                # Service management
Check-[Component]-Compliance.ps1    # Compliance validation
Sync-[Source]-To-[Target].ps1       # Data synchronization

# ❌ FORBIDDEN Names (VERBOTEN):
# main.ps1, script1.ps1, test.ps1, temp.ps1, run.ps1
```

---

## §3 Functions / Funktionen

### 🔧 **Mandatory Requirements**

- **`[CmdletBinding()]`**: Jede Funktion MUSS `[CmdletBinding()]` verwenden.
- **Parameter Validation**: Parameter MÜSSEN mit `[Validate...]` Attributen validiert werden.
- **Struktur**: Jede Funktion MUSS in `begin`, `process`, `end` Blöcke strukturiert sein.

### 💻 **Function Template**

```powershell
function Get-ComponentStatus {
    <#
    .SYNOPSIS
        [DE] Holt den Status einer Komponente.
        [EN] Gets the status of a component.

    .PARAMETER ComponentName
        [DE] Name der zu prüfenden Komponente.
        [EN] Name of the component to check.

    .EXAMPLE
        Get-ComponentStatus -ComponentName "WebService"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ComponentName
    )
    
    begin {
        Write-Verbose "[§3] Starting component status check for: $ComponentName"
    }
    
    process {
        try {
            # === MAIN LOGIC === #
            $result = @{ ComponentName = $ComponentName; Status = 'OK' }
            return $result
        }
        catch {
            Write-Error "[§3] Error in Get-ComponentStatus: $($_.Exception.Message)"
            throw # Fehler weiterleiten
        }
    }
    
    end {
        Write-Verbose "[§3] Function completed."
    }
}
```

---

## §4 Error Handling / Fehlerbehandlung

### 🔧 **Mandatory Requirements**

- **`try-catch` Blöcke**: Kritische Code-Abschnitte MÜSSEN in `try-catch` Blöcken gekapselt sein.
- **`$ErrorActionPreference`**: Der Standardwert MUSS auf `Stop` gesetzt sein, um Fehler sofort zu behandeln.
- **Spezifische Fehler**: Fehlerbehandlung sollte so spezifisch wie möglich sein.

### 💻 **Error Handling Template**

```powershell
$ErrorActionPreference = 'Stop'

try {
    # Kritischer Code
    $content = Get-Content -Path "C:\non-existent-file.txt"
}
catch [System.Management.Automation.ItemNotFoundException] {
    # Spezifischer Fehler für "Datei nicht gefunden"
    Write-Error "[§4] File not found. Please check the path."
    # Optional: Fallback-Logik
}
catch {
    # Allgemeiner Fehler
    Write-Error "[§4] An unexpected error occurred: $($_.Exception.Message)"
    throw # Unerwartete Fehler weiterleiten
}
finally {
    # Aufräumarbeiten, wird immer ausgeführt
    Write-Verbose "[§4] Error handling block finished."
}
```

---

## §5 Logging / Protokollierung

### 🔧 **Mandatory Requirements**

- **Zentrale Log-Funktion**: Jedes Projekt MUSS eine zentrale `Write-Log` Funktion verwenden.
- **Log-Levels**: Es MÜSSEN mindestens die Levels `DEBUG`, `INFO`, `WARNING`, `ERROR` unterstützt werden.
- **Timestamp & Level**: Jeder Log-Eintrag MUSS einen Zeitstempel und den Log-Level enthalten.

### 💻 **`Write-Log` Template**

```powershell
function Write-Log {
    param(
        [Parameter(Mandatory)] [string]$Message,
        [ValidateSet("DEBUG", "INFO", "WARNING", "ERROR", "FATAL")] [string]$Level = "INFO",
        [string]$LogPath = $Global:LogFilePath
    )
    
    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $LogEntry = "[$Timestamp] [$Level] $Message"
    
    # Console-Ausgabe mit Farben
    $Color = switch ($Level) {
        "DEBUG"   { "Gray" }
        "INFO"    { "White" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
        "FATAL"   { "Magenta" }
    }
    Write-Host $LogEntry -ForegroundColor $Color
    
    # File-Logging
    if ($LogPath) {
        $LogEntry | Out-File -FilePath $LogPath -Append -Encoding UTF8
    }
}
```

---

## §6 Configuration / Konfiguration

### 🔧 **Mandatory Requirements**

- **Externe JSON-Datei**: Die Konfiguration MUSS in einer externen `.json` Datei ausgelagert sein.
- **`config-[ProjectName].json`**: Der Name der Konfigurationsdatei MUSS diesem Muster folgen.
- **Umgebungstrennung**: Die Konfiguration MUSS zwischen `DEV` und `PROD` Umgebungen unterscheiden können.

### 💻 **`config-template.json`**

```json
{
    "ProjectInfo": {
        "Name": "MyProject",
        "Version": "1.0.0",
        "RegelwerkVersion": "v10.0.0"
    },
    "Environment": "DEV",
    "Settings": {
        "LogLevel": "INFO",
        "DebugMode": true
    },
    "Paths": {
        "LogPath": "./LOG/MyProject.log",
        "ReportPath": "./Reports"
    },
    "Mail": {
        "SMTPServer": "smtp.meduniwien.ac.at",
        "Port": 25,
        "Recipients": {
            "DEV": "thomas.garnreiter@meduniwien.ac.at",
            "PROD": "win-admin@meduniwien.ac.at"
        }
    }
}
```

---

## §7 Modules & Repository Structure / Module & Repository-Struktur

### 🔧 **Mandatory Requirements**

- **Standard-Verzeichnisstruktur**: Jedes Projekt MUSS eine standardisierte Ordnerstruktur aufweisen.
- **`Modules` Ordner**: Wiederverwendbarer Code MUSS in `.psm1` Module im `Modules` Ordner ausgelagert werden.
- **`FL-` Präfix**: Funktions-spezifische Module (Function Libraries) MÜSSEN das `FL-` Präfix tragen.

### 💻 **Repository Structure Template**

```text
ProjectName/
├── README.md                    # Projekt-Übersicht (PFLICHT)
├── CHANGELOG.md                 # Änderungsprotokoll (PFLICHT)
├── VERSION.ps1                  # Versionsverwaltung (PFLICHT)
├── Deploy-ProjectName.ps1       # Haupt-Script
├── Setup-ProjectName.ps1        # Setup-Script (PFLICHT)
├── Config/
│   └── config-ProjectName.json  # Hauptkonfiguration
├── Modules/
│   ├── FL-Config.psm1           # Konfigurationsmanagement
│   ├── FL-Logging.psm1          # Logging-Funktionen
│   └── FL-CoreLogic.psm1        # Haupt-Workflow-Logik
├── LOG/                         # Log-Dateien (zur Laufzeit erstellt)
├── Reports/                     # Generierte Berichte
└── Docs/                        # Dokumentation
```

---

## §8 PowerShell Compatibility / PowerShell-Kompatibilität

### 🔧 **Mandatory Requirements**

- **Versionserkennung**: Code, der sich zwischen PowerShell 5.1 und 7.x unterscheidet, MUSS die Version erkennen.
- **Keine Unicode-Emojis in PS 5.1**: In `Write-Host` dürfen in PS 5.1 keine Emojis verwendet werden.
- **ASCII-Alternativen**: Für PS 5.1 MÜSSEN aussagekräftige ASCII-Alternativen bereitgestellt werden.

### 💻 **Compatibility Template**

```powershell
function Show-StatusMessage {
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        # PowerShell 7.x - Unicode-Emojis erlaubt
        Write-Host "🚀 Starting process..." -ForegroundColor Green
        Write-Host "✅ Status: OK" -ForegroundColor Green
    } else {
        # PowerShell 5.1 - ASCII-Alternativen verwenden
        Write-Host ">> Starting process..." -ForegroundColor Green
        Write-Host "[OK] Status: OK" -ForegroundColor Green
    }
}
```

---

## §9 GUI Standards / GUI-Standards

### 🔧 **Mandatory Requirements**

- **WPF als Standard**: Alle GUIs MÜSSEN mit WPF (Windows Presentation Foundation) erstellt werden. WinForms ist verboten.
- **Setup-GUI**: Jedes Projekt MUSS eine `Setup-[ProjectName]-GUI.ps1` für die Konfigurationsverwaltung bereitstellen.
- **Corporate Design**: Das MedUni Wien Corporate Design (Farbe `#111d4e`) MUSS verwendet werden.

### 💻 **WPF GUI Template Snippet**

```powershell
# Setup-GUI Template (WPF-basiert)
function Show-SetupGUI {
    # WPF Assemblies laden
    Add-Type -AssemblyName PresentationFramework
    
    # MUW Corporate Design Farben
    $Colors = @{
        Primary = "#111d4e"        # MedUni Wien Official Dark Blue
        Background = "#F5F5F5"     # Light Gray Background
        Success = "#008000"        # Success Green
    }

    # XAML-Code für die GUI-Struktur
    [xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Setup GUI" Height="400" Width="600">
    <Grid>
        <Border Background="$($Colors.Primary)" Height="50" VerticalAlignment="Top">
            <TextBlock Text="Project Configuration" Foreground="White" FontSize="20" HorizontalAlignment="Center" VerticalAlignment="Center"/>
        </Border>
        <!-- Weitere GUI-Elemente hier -->
    </Grid>
</Window>
"@

    $reader = (New-Object System.Xml.XmlNodeReader $xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)
    
    # Event-Handler und Logik hier...
    
    $window.ShowDialog() | Out-Null
}
```

---
---

# Teil B: Enterprise-Paragraphen

## §10 Strict Modularity / Strikte Modularität

### 🔧 **Mandatory Requirements**

- **300-Zeilen-Limit**: Hauptskripte (`Deploy-*.ps1`, `Setup-*.ps1`) dürfen eine Länge von 300 Zeilen nicht überschreiten.
- **Logik-Auslagerung**: Die gesamte Geschäftslogik MUSS in spezialisierte `FL-*.psm1` Module ausgelagert werden.
- **Orchestrierung**: Das Hauptskript dient nur der Orchestrierung (Modul-Import, Konfigurations-Ladung, Funktionsaufrufe).

### 💻 **Lean Main Script Template**

```powershell
#requires -Version 5.1

param([switch]$Setup, [switch]$Debug)

#region Initialization (§1, §6)
. (Join-Path $PSScriptRoot "VERSION.ps1")
Show-ScriptInfo
$Config = Get-ScriptConfiguration # Lädt Konfiguration aus FL-Config.psm1
#endregion

#region Module Import (§7)
$ModulePath = Join-Path $PSScriptRoot "Modules"
Import-Module (Join-Path $ModulePath "FL-Config.psm1") -Force
Import-Module (Join-Path $ModulePath "FL-Logging.psm1") -Force
Import-Module (Join-Path $ModulePath "FL-CoreLogic.psm1") -Force
#endregion

#region Main Execution (§10)
try {
    if ($Setup) {
        Invoke-SetupMode # Funktion aus FL-CoreLogic.psm1
    } else {
        Invoke-MainWorkflow # Funktion aus FL-CoreLogic.psm1
    }
} catch {
    Write-Log "Critical Error: $($_.Exception.Message)" -Level "FATAL"
    exit 1
}
#endregion
```

---

## §11 File Operations / Dateivorgänge

### 🔧 **Mandatory Requirements**

- **Robocopy als Standard**: Für alle Netzwerk-Kopier-Operationen und große Datenmengen MUSS `Robocopy` verwendet werden.
- **`Copy-Item` Einschränkung**: `Copy-Item` ist nur für kleine, lokale Dateioperationen (< 10MB) erlaubt.
- **Zentrale Funktion**: Eine zentrale `Copy-FilesRobust` Funktion MUSS `Robocopy` kapseln.

### 💻 **`Copy-FilesRobust` Template**

```powershell
function Copy-FilesRobust {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination
    )
    
    # Robocopy-Parameter für robustes Kopieren
    $RobocopyParams = @(
        '/E',      # Kopiert Unterverzeichnisse, auch leere
        '/R:3',    # 3 Wiederholungsversuche bei Fehlern
        '/W:5',    # 5 Sekunden Wartezeit zwischen Wiederholungen
        '/NP',     # Kein Fortschrittsbalken
        '/NDL'     # Keine Verzeichnisliste im Log
    )
    
    Write-Log "Starting robust file copy: $Source -> $Destination" -Level INFO
    & robocopy $Source $Destination @RobocopyParams
    
    # Robocopy Exit Codes: 0-7 = Erfolg, 8+ = Fehler
    if ($LASTEXITCODE -ge 8) {
        throw "File operation failed with Robocopy exit code: $LASTEXITCODE"
    }
}
```

---

## §12 Cross-Script Communication / Script-übergreifende Kommunikation

### 🔧 **Mandatory Requirements**

- **JSON-basiertes Messaging**: Die Kommunikation zwischen verschiedenen Skripten MUSS über temporäre JSON-Dateien erfolgen.
- **`Messages` & `Status` Ordner**: Nachrichten und Status-Updates MÜSSEN in den Unterordnern `LOG\Messages` und `LOG\Status` gespeichert werden.
- **Zentrale Funktionen**: `Send-ScriptMessage` und `Set-ScriptStatus` MÜSSEN für die Kommunikation verwendet werden.

### 💻 **Communication Functions Template**

```powershell
function Send-ScriptMessage {
    param(
        [Parameter(Mandatory)][string]$TargetScript,
        [Parameter(Mandatory)][string]$Message
    )
    $MessageDir = "LOG\Messages"
    New-Item -Path $MessageDir -ItemType Directory -Force | Out-Null
    $MessageFile = "$MessageDir\$TargetScript-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $MessageData = @{
        Timestamp = Get-Date -Format 'O'
        Source = $MyInvocation.MyCommand.Name
        Message = $Message
    }
    $MessageData | ConvertTo-Json | Out-File $MessageFile -Encoding UTF8
}

function Set-ScriptStatus {
    param([Parameter(Mandatory)][string]$Status, [hashtable]$Details = @{})
    
    $StatusDir = "LOG\Status"
    New-Item -Path $StatusDir -ItemType Directory -Force | Out-Null
    $StatusFile = "$StatusDir\$($MyInvocation.MyCommand.Name -replace '\.ps1$', '')-Status.json"
    $StatusData = @{
        Timestamp = Get-Date -Format 'O'
        Status = $Status
        Details = $Details
        Computer = $env:COMPUTERNAME
    }
    $StatusData | ConvertTo-Json -Depth 5 | Out-File $StatusFile -Encoding UTF8
}
```

---

## §13 Network Operations / Netzwerkoperationen

### 🔧 **Mandatory Requirements**

- **Retry-Logik**: Alle Netzwerkoperationen (z.B. `Test-Path`, `Invoke-RestMethod`) MÜSSEN eine Retry-Logik mit `Start-Sleep` implementieren.
- **`Test-Connection` vor Zugriff**: Vor dem Zugriff auf eine Netzwerkressource MUSS die Erreichbarkeit mit `Test-Connection` oder `Test-NetConnection` geprüft werden.
- **Timeout-Parameter**: Alle Netzwerk-Cmdlets MÜSSEN explizite Timeout-Parameter verwenden.

### 💻 **Resilient Network Function Template**

```powershell
function Get-WebServiceData {
    param(
        [Parameter(Mandatory)][string]$Uri,
        [int]$RetryCount = 3,
        [int]$TimeoutSeconds = 30
    )
    
    for ($i = 1; $i -le $RetryCount; $i++) {
        try {
            Write-Log "Attempting to get data from $Uri (Attempt $i/$RetryCount)" -Level DEBUG
            $params = @{
                Uri = $Uri
                TimeoutSec = $TimeoutSeconds
                ErrorAction = 'Stop'
            }
            return Invoke-RestMethod @params
        }
        catch {
            Write-Log "Failed to get data from $Uri. Error: $($_.Exception.Message)" -Level WARNING
            if ($i -lt $RetryCount) {
                Start-Sleep -Seconds 5 # Warte 5 Sekunden vor dem nächsten Versuch
            } else {
                throw "Failed to retrieve data from $Uri after $RetryCount attempts."
            }
        }
    }
}
```

---

## §14 Security Standards / Sicherheitsstandards

### 🔧 **Mandatory Requirements**

- **Credential Management**: Passwörter und sensible Daten MÜSSEN als `PSCredential` Objekte behandelt und mit `Export-Clixml` verschlüsselt gespeichert werden.
- **Keine Klartext-Passwörter**: Passwörter dürfen NIEMALS im Klartext in Skripten oder Konfigurationsdateien stehen.
- **Input Validation**: Alle externen Eingaben (Parameter, Konfigurationswerte) MÜSSEN validiert werden, um Injection-Angriffe zu verhindern.

### 💻 **Secure Credential Handling Template**

```powershell
# Speichern eines Credentials
$cred = Get-Credential
$cred | Export-Clixml -Path ".\Config\WebService.cred"

# Laden eines Credentials
function Get-SecureCredential {
    param([Parameter(Mandatory)][string]$CredentialPath)
    
    try {
        return Import-Clixml -Path $CredentialPath
    } catch {
        throw "Failed to load secure credential from $CredentialPath."
    }
}

# Verwendung
$secureCred = Get-SecureCredential -CredentialPath ".\Config\WebService.cred"
Invoke-RestMethod -Uri "https://api.example.com" -Credential $secureCred
```

---

## §15 Performance Optimization / Performance-Optimierung

### 🔧 **Mandatory Requirements**

- **Parallel Processing**: Für die Verarbeitung großer Datenmengen MUSS `ForEach-Object -Parallel` (in PS 7+) oder `Start-Job` verwendet werden.
- **`$ThrottleLimit`**: Bei paralleler Verarbeitung MUSS ein `$ThrottleLimit` gesetzt werden, um das System nicht zu überlasten.
- **Memory Management**: Bei langen Skriptläufen MUSS explizit der Garbage Collector mit `[System.GC]::Collect()` aufgerufen werden, um Speicher freizugeben.

### 💻 **Parallel Processing Template (PowerShell 7+)**

```powershell
$items = 1..1000

$items | ForEach-Object -Parallel {
    # Dieser Code wird parallel für jedes Element ausgeführt
    $item = $_
    # ... intensive Verarbeitung ...
    
    # Wichtig: Logging innerhalb des Parallel-Blocks muss Thread-sicher sein
    # (z.B. durch Schreiben in separate Dateien oder Verwendung von Synchronisation)
    
} -ThrottleLimit 5 # Maximal 5 Threads gleichzeitig
```

---

## ✅ Compliance-Checkliste v10.0.0

- **[§1]**: `VERSION.ps1` existiert und ist korrekt formatiert.
- **[§2]**: Alle Skripte und Funktionen haben vollständige Comment-Based Help.
- **[§3]**: Alle Funktionen verwenden `[CmdletBinding()]` und Parameter-Validierung.
- **[§4]**: Kritischer Code ist in `try-catch` Blöcken. `$ErrorActionPreference` ist auf `Stop`.
- **[§5]**: Eine zentrale `Write-Log` Funktion wird verwendet.
- **[§6]**: Konfiguration ist in externer `config-*.json` Datei.
- **[§7]**: Das Projekt folgt der Standard-Verzeichnisstruktur. Logik ist in `FL-` Modulen.
- **[§8]**: Code ist kompatibel mit PS 5.1 und 7.x (keine Emojis in PS 5.1).
- **[§9]**: Eine WPF-basierte Setup-GUI ist vorhanden und nutzt das Corporate Design.
- **[§10]**: Hauptskripte sind unter 300 Zeilen.
- **[§11]**: `Robocopy` wird für Netzwerk-Kopier-Operationen verwendet.
- **[§12]**: Script-übergreifende Kommunikation erfolgt über JSON-Dateien.
- **[§13]**: Netzwerkoperationen haben eine Retry-Logik und Timeouts.
- **[§14]**: Keine Klartext-Passwörter im Code; `PSCredential` Objekte werden verwendet.
- **[§15]**: Parallelverarbeitung wird für rechenintensive Aufgaben genutzt.

---

## 📜 Entwicklungshistorie

### v10.0.0 (2025-09-29) - ENTERPRISE COMPLETE EDITION

- **MAJOR UPDATE**: Vollständige Neuausrichtung und Strukturierung in 15 klare Paragraphen.
- **§10-§15 NEU**: Einführung von 6 Enterprise-Paragraphen für Skalierbarkeit, Sicherheit und Performance.
- **KONSOLIDIERT**: Alle Standards aus `v9.x` Versionen und historischen Regelwerken wurden logisch integriert.
- **ENTERPRISE-READY**: Definiert einen 100% produktionsreifen Standard für alle PowerShell-Projekte.

---

**AUTOR**: Flecki (Tom) Garnreiter | **STATUS**: Enterprise Complete | **GÜLTIG AB**: 2025-09-29
