# MUW-Regelwerk Universal v9.6.0 - PowerShell Development Standards

## Version: v9.6.0 | Datum: 2025-09-27 | **UNIVERSELLES ENTWICKLUNGSREGELWERK**

### 🌟 **UNIVERSELLE ANWENDUNG**

**Dieses Regelwerk gilt für ALLE PowerShell-Entwicklungsprojekte:**
- ✅ **Skript-Entwicklung** (Einzelne Scripts, Module, Funktionen)
- ✅ **System-Administration** (Server-Management, Automatisierung)
- ✅ **Anwendungsentwicklung** (Web-Services, APIs, Datenverarbeitung)
- ✅ **DevOps & Deployment** (CI/CD, Infrastruktur, Monitoring)
- ✅ **Wartung & Support** (Troubleshooting, Updates, Patches)

---

## 🎯 **REGELWERK-PHILOSOPHIE**

### **Grundprinzipien für ALLE Projekte:**
1. **Konsistenz**: Einheitliche Standards über alle Projekte hinweg
2. **Lesbarkeit**: Code ist für Menschen geschrieben, nicht nur für Maschinen
3. **Wartbarkeit**: Einfache Pflege und Erweiterung über Jahre
4. **Interoperabilität**: Systeme können miteinander kommunizieren
5. **Skalierbarkeit**: Von kleinen Scripts bis zu Enterprise-Lösungen

---

## 📋 **NEUE UNIVERSELLE ANFORDERUNGEN v9.6.0**

### **§14. File Operations Standards (UNIVERSELL ANWENDBAR)**

**ALLE PowerShell-Projekte müssen robuste File-Operations verwenden:**

##### **§14.1 Robocopy als Standard (PFLICHT)**

```powershell
#region File Operations Standards (UNIVERSAL - Regelwerk v9.6.0)

# ❌ NICHT EMPFOHLEN: Copy-Item für große/Netzwerk-Operationen
# Copy-Item "C:\Source" "\\Server\Share" -Recurse

# ✅ UNIVERSELLER STANDARD: Robocopy für robuste File-Operations
function Copy-FilesRobust {
    param(
        [string]$Source,
        [string]$Destination,
        [switch]$Mirror,
        [int]$RetryCount = 3,
        [int]$WaitTime = 5
    )
    
    $RobocopyParams = @('/E', "/R:$RetryCount", "/W:$WaitTime")
    if ($Mirror) { $RobocopyParams += '/PURGE' }
    
    Write-Log "Starting robust file copy: $Source -> $Destination" -Level INFO
    $Result = & robocopy $Source $Destination @RobocopyParams
    
    # Robocopy Exit Codes: 0-7 = Success, 8+ = Error
    if ($LASTEXITCODE -ge 8) {
        Write-Log "Robocopy failed with exit code: $LASTEXITCODE" -Level ERROR
        throw "File operation failed"
    }
    
    Write-Log "File copy completed successfully" -Level INFO
}
#endregion
```

##### **§14.2 Robocopy Parameter Standards (PFLICHT)**

```powershell
# Standard Robocopy Parameter für verschiedene Szenarien:

# Basis-Synchronisation:
# robocopy "Source" "Destination" /E /R:3 /W:5

# Mirror-Synchronisation (mit Löschung):
# robocopy "Source" "Destination" /E /PURGE /R:3 /W:5

# Deployment-Synchronisation:
# robocopy "Source" "Destination" /E /XO /R:3 /W:5

# Backup-Synchronisation:
# robocopy "Source" "Destination" /E /XO /DCOPY:DAT /R:5 /W:10
```

##### **§14.3 Copy-Item Verwendungsbeschränkungen**

```powershell
# Copy-Item ist NUR erlaubt für:
# 1. Lokale File-Operations (gleicher Server)
# 2. Einzelne kleine Dateien (<10MB)
# 3. Temporäre Operationen in Memory/Temp

# Beispiel ERLAUBTE Copy-Item Verwendung:
Copy-Item "C:\Temp\config.json" "C:\App\config.json" -Force
```

### **§15. Universelle Script Versioning (PFLICHT für ALLE Projekte)**

##### **§15.1 Semantic Versioning (PFLICHT)**

```powershell
#region Script Version Information (UNIVERSAL MANDATORY - Regelwerk v9.6.0)
$ScriptVersion = "1.3.1"  # Format: MAJOR.MINOR.PATCH
$RegelwerkVersion = "v9.5.0"
$BuildDate = "2025-09-23"
$Author = "Flecki (Tom) Garnreiter"

<#
.VERSION HISTORY
1.3.1 - 2025-09-23 - Fixed syntax error in try-catch block
1.3.0 - 2025-09-23 - Added Server Core compatibility
1.2.0 - 2025-09-22 - Added WebService deployment features
1.1.0 - 2025-09-21 - Added certificate scanning
1.0.0 - 2025-09-20 - Initial release
#>
#endregion
```

##### **§15.2 Version Display (PFLICHT)**

```powershell
function Show-ScriptInfo {
    Write-Host "🚀 $($MyInvocation.MyCommand.Name) v$ScriptVersion" -ForegroundColor Green
    Write-Host "📅 Build: $BuildDate | Regelwerk: $RegelwerkVersion" -ForegroundColor Cyan
    Write-Host "👤 Author: $Author" -ForegroundColor Cyan
    Write-Host "Server: $env:COMPUTERNAME" -ForegroundColor Yellow
}

# Aufruf am Script-Start (PFLICHT):
Show-ScriptInfo
```

##### **§15.3 Deployment Package Versioning (PFLICHT)**

```powershell
# Deployment-Pakete müssen Versionsinformationen enthalten:

# Ordner-Struktur:
# CertWebService-Deployment-v1.3.1/
# ├── VERSION.txt
# ├── Setup-WebService-v1.3.1.ps1
# ├── Install-WebService.bat
# └── README.txt

# VERSION.txt Inhalt:
@"
Package: CertWebService-Deployment
Version: v1.3.1
Build Date: 2025-09-23
Regelwerk: v9.5.0
Author: Flecki (Tom) Garnreiter
Compatibility: Windows Server 2012R2+, PowerShell 5.1+
"@ | Out-File "VERSION.txt" -Encoding UTF8
```

#### **§16. Network Operations Best Practices (PFLICHT)**

##### **§16.1 Robuste Netzwerk-Verbindungen**

```powershell
function Test-NetworkPath {
    param([string]$Path, [int]$TimeoutSeconds = 10)
    
    try {
        $TestResult = Test-Path $Path -PathType Container
        if ($TestResult) {
            Write-Log "Network path accessible: $Path" -Level INFO
            return $true
        } else {
            Write-Log "Network path not accessible: $Path" -Level WARNING
            return $false
        }
    }
    catch {
        Write-Log "Network path test failed: $Path - $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

# Verwendung vor Robocopy (PFLICHT):
if (-not (Test-NetworkPath $NetworkShare)) {
    throw "Network share not accessible: $NetworkShare"
}
```

##### **§16.2 Robocopy Error Handling (PFLICHT)**

```powershell
function Invoke-RobocopyWithValidation {
    param(
        [string]$Source,
        [string]$Destination,
        [string[]]$AdditionalParams = @()
    )
    
    # Standard Parameter
    $BaseParams = @('/E', '/R:3', '/W:5')
    $AllParams = $BaseParams + $AdditionalParams
    
    Write-Log "Robocopy command: robocopy `"$Source`" `"$Destination`" $($AllParams -join ' ')" -Level INFO
    
    & robocopy $Source $Destination @AllParams
    
    switch ($LASTEXITCODE) {
        0 { Write-Log "Robocopy: No files copied" -Level INFO }
        1 { Write-Log "Robocopy: Files copied successfully" -Level INFO }
        2 { Write-Log "Robocopy: Extra files or directories detected" -Level WARNING }
        3 { Write-Log "Robocopy: Files copied + extra files detected" -Level INFO }
        4 { Write-Log "Robocopy: Mismatched files or directories" -Level WARNING }
        5 { Write-Log "Robocopy: Files copied + mismatched files" -Level WARNING }
        6 { Write-Log "Robocopy: Extra + mismatched files" -Level WARNING }
        7 { Write-Log "Robocopy: Files copied + extra + mismatched" -Level WARNING }
        Default { 
            Write-Log "Robocopy failed with exit code: $LASTEXITCODE" -Level ERROR
            throw "Robocopy operation failed"
        }
    }
}
```

#### **§18. Einheitliche Namensgebung Standards (ZWINGEND ERFORDERLICH)**

##### **§18.1 Script-Namenskonventionen (PFLICHT)**

```powershell
# ✅ KORREKTE Namensgebung (sprechend und einheitlich):

# Haupt-Scripts (Funktionale Beschreibung):
# Setup-CertSurv.ps1              # Hauptinstallation
# Setup-CertSurvGUI.ps1           # GUI-Konfiguration
# Deploy-CertSurv.ps1             # Deployment-Script
# Manage-CertSurv.ps1             # Management-Tool
# Check-CertSurv.ps1              # System-Überprüfung
# Install-CertSurv.bat            # Batch-Installer

# Spezial-Scripts (Zweck-orientiert):
# Test-CertWebService.ps1         # WebService-Tests
# Backup-CertData.ps1             # Backup-Funktionen  
# Monitor-CertExpiry.ps1          # Überwachung
# Report-CertStatus.ps1           # Berichtsgenerierung

# ❌ FALSCHE Namensgebung (nicht sprechend):
# Script1.ps1, test.ps1, main.ps1, copy.ps1
# a.ps1, temp.ps1, new.ps1, fix.ps1
```

##### **§18.2 Modul-Namenskonventionen (PFLICHT)**

```powershell
# ✅ KORREKTE Modul-Namen (FL-Präfix + Funktionsbereich):

# FL-Config.psm1          # Konfigurationsmanagement
# FL-Logging.psm1         # Logging-Funktionen
# FL-Utils.psm1           # Utility-Funktionen
# FL-Security.psm1        # Sicherheitsfunktionen
# FL-NetworkOperations.psm1   # Netzwerk-Operationen
# FL-DataProcessing.psm1  # Datenverarbeitung
# FL-Reporting.psm1       # Berichtsfunktionen
# FL-Maintenance.psm1     # Wartungsfunktionen
# FL-Compatibility.psm1   # Kompatibilitätsfunktionen
# FL-ActiveDirectory.psm1 # AD-Integration

# ❌ FALSCHE Modul-Namen:
# functions.psm1, tools.psm1, helper.psm1
# module1.psm1, common.psm1, shared.psm1
```

##### **§18.3 Funktions-Namenskonventionen (PFLICHT)**

```powershell
# ✅ KORREKTE Funktions-Namen (Verb-Noun + Kontext):

# Konfiguration:
function Get-CertSurvConfig { }      # Config laden
function Set-CertSurvConfig { }      # Config setzen
function Test-CertSurvConfig { }     # Config validieren

# Zertifikate:
function Get-CertificateExpiry { }   # Ablaufdatum ermitteln
function Test-CertificateValidity { } # Gültigkeit prüfen
function Export-CertificateReport { } # Report exportieren

# System:
function Install-WebServiceIIS { }   # IIS-Installation
function Start-CertSurvService { }   # Service starten
function Stop-CertSurvService { }    # Service stoppen

# ❌ FALSCHE Funktions-Namen:
# DoSomething, ProcessData, HandleStuff
# Function1, TestFunc, MyFunction
```

##### **§18.4 Variablen-Namenskonventionen (PFLICHT)**

```powershell
# ✅ KORREKTE Variablen-Namen (CamelCase + Kontext):

# Konfiguration:
$ConfigFilePath = "C:\\Config\\config.json"
$SmtpServerAddress = "smtp.meduniwien.ac.at"
$WebServicePort = 8443
$CertificateThreshold = 30

# Pfade:
$LogDirectoryPath = "C:\\Script\\LOG"
$BackupDirectoryPath = "C:\\Script\\Backup"
$NetworkSharePath = "\\\\server\\share"

# Status/Flags:
$IsServiceRunning = $true
$HasValidCertificate = $false
$InstallationComplete = $false

# ❌ FALSCHE Variablen-Namen:
# $a, $temp, $x, $data, $stuff, $thing
# $var1, $test, $config, $path
```

#### **§19. Repository-Organisation Standards (ZWINGEND ERFORDERLICH)**

##### **§19.1 Standard-Verzeichnisstruktur (PFLICHT)**

```Struktur
# ✅ PFLICHT-Struktur für alle Repositories:

ProjectName/
├── README.md                    # Projekt-Übersicht (PFLICHT)
├── CHANGELOG.md                 # Änderungshistorie (PFLICHT)
├── VERSION.ps1                  # Zentrale Versionsverwaltung (PFLICHT)
├── Main-Script.ps1             # Haupt-Einstiegspunkt
├── Setup-Script.ps1            # Installation/Setup
├── Config/                     # Konfigurationsdateien
│   ├── Config-Main.json        # Hauptkonfiguration
│   ├── de-DE.json             # Deutsche Lokalisierung
│   └── en-US.json             # Englische Lokalisierung
├── Modules/                    # PowerShell-Module
│   ├── FL-Config.psm1         # Konfigurationsmodul
│   ├── FL-Logging.psm1        # Logging-Modul
│   └── FL-Utils.psm1          # Utility-Modul
├── LOG/                       # Log-Dateien (automatisch)
├── Reports/                   # Generierte Berichte
├── Docs/                      # Dokumentation
│   ├── USER-GUIDE.md          # Benutzerhandbuch
│   ├── INSTALL-GUIDE.md       # Installationsanleitung
│   └── API-REFERENCE.md       # API-Dokumentation
├── TEST/                      # Test-Scripts (PFLICHT)
│   ├── Test-MainFunctions.ps1 # Funktions-Tests
│   ├── Test-Integration.ps1   # Integrations-Tests
│   └── Test-Performance.ps1   # Performance-Tests
└── old/                       # Archivierte Scripts (PFLICHT)
    ├── deprecated-script1.ps1  # Nicht mehr verwendete Scripts
    └── backup-config.json     # Alte Konfigurationen
```

##### **§19.2 Repository-Bereinigung (PFLICHT)**

```powershell
# ✅ PFLICHT: Regelmäßige Repository-Bereinigung

# 1. Nicht verwendete Scripts nach old/ verschieben:
# Move-Item "Old-Script.ps1" "old\\" -Force

# 2. Test-Scripts nach TEST/ verschieben:
# Move-Item "Test-*.ps1" "TEST\\" -Force

# 3. Temporäre Dateien entfernen:
# Remove-Item "*.tmp", "*.temp", "*~" -Force

# 4. Leere Ordner entfernen:
# Get-ChildItem -Directory | Where-Object { (Get-ChildItem $_.FullName).Count -eq 0 } | Remove-Item

# ❌ NICHT ERLAUBT in Haupt-Repository:
# - Temporary files (.tmp, .temp, *~)
# - Test-Scripts im Root-Verzeichnis
# - Nicht funktionierende Scripts
# - Duplicate Scripts mit ähnlicher Funktionalität
```

##### **§19.3 Dokumentations-Standards (PFLICHT)**

```markdown
# ✅ PFLICHT: README.md Template

# ProjectName v1.0.0

## 📋 Übersicht
Kurze Beschreibung des Projekts und Hauptfunktionen.

## 🚀 Installation
Schritt-für-Schritt Installationsanleitung.

## ⚙️ Konfiguration
Konfigurationsmöglichkeiten und Einstellungen.

## 📖 Verwendung
Beispiele für die Nutzung der Scripts.

## 🔧 Module
Übersicht über verfügbare Module und Funktionen.

## 📊 Systemanforderungen
- PowerShell 5.1+ (kompatibel mit 7.x)
- Windows Server 2012R2+
- Administrative Rechte

## 📚 Dokumentation
- [Benutzerhandbuch](Docs/USER-GUIDE.md)
- [Installationsanleitung](Docs/INSTALL-GUIDE.md)
- [API-Referenz](Docs/API-REFERENCE.md)

## 👨‍💻 Autor
**Flecki (Tom) Garnreiter**
Regelwerk: v9.6.0 | Build: $(Get-Date -Format 'yyyyMMdd')
```

#### **§20. Script-Interoperabilität Standards (ZWINGEND ERFORDERLICH)**

##### **§20.1 Gemeinsame Schnittstellen (PFLICHT)**

```powershell
# ✅ PFLICHT: Alle Scripts müssen gemeinsame Standards verwenden

#region Common Interfaces (MANDATORY - Regelwerk v9.6.0)

# 1. Einheitliche Konfiguration:
$ConfigPath = "Config\\Config-Main.json"
$Config = Get-Content $ConfigPath | ConvertFrom-Json

# 2. Einheitliches Logging:
Import-Module ".\\Modules\\FL-Logging.psm1"
Write-Log "Script started" -Level INFO

# 3. Einheitliche Versionsinformationen:
Import-Module ".\\VERSION.ps1"
Show-ScriptInfo

# 4. Einheitliche Fehlerbehandlung:
try {
    # Script-Logik
}
catch {
    Write-Log "Error: $($_.Exception.Message)" -Level ERROR
    throw
}

#endregion
```

##### **§20.2 Modulare Kompatibilität (PFLICHT)**

```powershell
# ✅ PFLICHT: Alle Module müssen untereinander kompatibel sein

# Standard Module-Import:
function Import-RequiredModules {
    $ModulePath = ".\\Modules"
    $RequiredModules = @(
        "FL-Config.psm1",
        "FL-Logging.psm1", 
        "FL-Utils.psm1"
    )
    
    foreach ($Module in $RequiredModules) {
        $FullPath = Join-Path $ModulePath $Module
        if (Test-Path $FullPath) {
            Import-Module $FullPath -Force
            Write-Log "Module imported: $Module" -Level INFO
        } else {
            Write-Log "Module not found: $Module" -Level ERROR
            throw "Required module missing: $Module"
        }
    }
}

# Verwendung in jedem Script (PFLICHT):
Import-RequiredModules
```

##### **§20.3 Cross-Script Kommunikation (PFLICHT)**

```powershell
# ✅ PFLICHT: Scripts müssen über standardisierte Methoden kommunizieren

# 1. Shared Configuration:
function Get-SharedConfig {
    param([string]$Section)
    $Config = Get-CertSurvConfig
    return $Config.$Section
}

# 2. Inter-Script Messaging:
function Send-ScriptMessage {
    param(
        [string]$TargetScript,
        [string]$Message,
        [string]$Type = "INFO"
    )
    
    $MessageFile = "LOG\\Messages\\$TargetScript-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $MessageData = @{
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Source = $MyInvocation.ScriptName
        Target = $TargetScript
        Message = $Message
        Type = $Type
    }
    
    $MessageData | ConvertTo-Json | Out-File $MessageFile -Encoding UTF8
    Write-Log "Message sent to $TargetScript: $Message" -Level INFO
}

# 3. Status Sharing:
function Set-ScriptStatus {
    param(
        [string]$Status,
        [hashtable]$Details = @{}
    )
    
    $StatusFile = "LOG\\Status\\$($MyInvocation.ScriptName)-Status.json"
    $StatusData = @{
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Script = $MyInvocation.ScriptName
        Status = $Status
        Details = $Details
        RegelwerkVersion = "v9.6.0"
    }
    
    $StatusData | ConvertTo-Json | Out-File $StatusFile -Encoding UTF8
}
```

---

## **Bestehende Regelwerk-Anforderungen (Überarbeitet)**

### **§1. Script-Struktur (ERWEITERT v9.5.0)**

- Hauptskript max. 300 Zeilen
- **NEU**: Versionsinformationen im Header (PFLICHT)
- **NEU**: Show-ScriptInfo Funktion am Start (PFLICHT)
- Strikte Modularität mit FL-* Modulen

### **§2. Modul-Standards (ERWEITERT v9.5.0)**

- PowerShell-Versions-Detection implementieren
- **NEU**: Robocopy-Functions für File-Operations
- Export-ModuleMember am Ende jedes Moduls
- Regelwerk-Compliance-Kommentar: `# --- End of module --- v1.1.0 ; Regelwerk: v9.5.0 ---`

### **§3. Konfiguration (ERWEITERT v9.5.0)**

- JSON-basierte Konfiguration
- **NEU**: Versionsinformationen in Config-Files
- Mehrsprachige Unterstützung (de-DE, en-US)
- Lokalisierte Fehlermeldungen

### **§4. Logging (ERWEITERT v9.5.0)**

- **NEU**: Robocopy-Operationen müssen geloggt werden
- PowerShell-Version dokumentieren
- **NEU**: File-Operation-Status dokumentieren
- Strukturierte Protokollierung mit Write-Log
- Zeitstempel in deutschem Format

### **§5. Fehlerbehandlung (ERWEITERT v9.5.0)**

- **NEU**: Robocopy Exit-Code Handling (PFLICHT)
- **NEU**: Network-Path Validation vor File-Operations
- Version-spezifische Fehlerbehandlung für HTTP/HTTPS
- Try-Catch-Finally Blöcke
- Graceful Degradation bei Feature-Unterschieden

---

## **§21. COMPLIANCE-CHECKLISTE v9.6.0**

### **Vor jedem Script-Deployment:**

#### **Namensgebung & Organisation:**

- [ ] ✅ Sprechende Script-Namen verwendet (Setup-, Deploy-, Manage-, etc.)
- [ ] ✅ FL-Präfix für alle Module implementiert
- [ ] ✅ CamelCase für Variablen und Funktionen
- [ ] ✅ Repository-Struktur standardisiert (Config/, Modules/, TEST/, old/)
- [ ] ✅ README.md mit Standard-Template erstellt
- [ ] ✅ Test-Scripts in TEST/ Verzeichnis
- [ ] ✅ Alte Scripts in old/ Verzeichnis archiviert

#### **Script-Interoperabilität:**

- [ ] ✅ Gemeinsame Konfigurationsdateien verwendet
- [ ] ✅ Standard Module-Import implementiert
- [ ] ✅ Cross-Script Kommunikation über JSON-Messages
- [ ] ✅ Einheitliche Logging-Standards
- [ ] ✅ Status-Sharing zwischen Scripts

#### **Technische Standards:**

- [ ] ✅ Script-Version im Header definiert
- [ ] ✅ Show-ScriptInfo Funktion implementiert
- [ ] ✅ Robocopy statt Copy-Item für Netzwerk-Operationen
- [ ] ✅ Robocopy Error-Handling implementiert
- [ ] ✅ Network-Path Validation vor File-Operations
- [ ] ✅ VERSION.txt in Deployment-Paketen
- [ ] ✅ PowerShell-Versions-Kompatibilität getestet
- [ ] ✅ Regelwerk-Compliance-Kommentar in Modulen

### **File-Operations Checkliste:**

- [ ] ✅ Lokale Operationen: Copy-Item erlaubt
- [ ] ✅ Netzwerk-Operationen: Robocopy verwendet
- [ ] ✅ Retry-Logic implementiert (/R:3 /W:5 minimum)
- [ ] ✅ Exit-Code Validation implementiert
- [ ] ✅ Logging aller File-Operations

### **Repository-Qualität Checkliste:**

- [ ] ✅ Keine temporären Dateien (.tmp, .temp, *~)
- [ ] ✅ Alle Test-Scripts in TEST/ Verzeichnis
- [ ] ✅ Redundante/alte Scripts in old/ archiviert
- [ ] ✅ Dokumentation vollständig (README, CHANGELOG, Docs/)
- [ ] ✅ Einheitliche Namenskonventionen durchgängig
- [ ] ✅ Modulare Struktur mit FL-* Modulen

---

## **Regelwerk-Änderungshistorie**

### v9.6.0 (2025-09-27)

- **NEU**: §18 Einheitliche Namensgebung Standards (Zwingend erforderlich)
- **NEU**: §19 Repository-Organisation Standards (Zwingend erforderlich)
- **NEU**: §20 Script-Interoperabilität Standards (Zwingend erforderlich)
- **NEU**: §21 Erweiterte Compliance-Checkliste v9.6.0
- **ERWEITERT**: Sprechende Namenskonventionen für Scripts, Module, Funktionen, Variablen
- **ERWEITERT**: Standard Repository-Struktur mit TEST/, old/, Docs/ Verzeichnissen
- **ERWEITERT**: Cross-Script Kommunikation und gemeinsame Schnittstellen

### v9.5.0 (2025-09-23)

- **NEU**: §14 File Operations Standards (Robocopy-Pflicht)
- **NEU**: §15 Script Versioning Standards
- **NEU**: §16 Network Operations Best Practices
- **NEU**: §17 Compliance-Checkliste
- **ERWEITERT**: Alle bestehenden Paragraphen um Versioning

### v9.4.0 (2025-09-22)

- **NEU**: §12 PowerShell Version Compatibility
- **NEU**: §13 Universal Functions Template
- **ERWEITERT**: Modul-Standards, Logging, Fehlerbehandlung

### v9.3.1 (2025-09-21)

- Basis-Regelwerk etabliert
- Script-Struktur, Konfiguration, Logging definiert

---

**Ende Regelwerk v9.6.0**
**Autor**: Flecki (Tom) Garnreiter
**Gültig ab**: 2025-09-27
**Nächste Review**: 2025-11-27
