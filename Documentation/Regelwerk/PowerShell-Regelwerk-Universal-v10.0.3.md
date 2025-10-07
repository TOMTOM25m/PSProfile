# PowerShell-Regelwerk Universal v10.0.2

**Enterprise Complete Edition - Comprehensive PowerShell Development Standards**

---

## 📋 Document Information

| **Attribute** | **Value** |
|---------------|-----------|
| **Version** | v10.0.3 |
| **Status** | Enterprise Complete |
| **Release Date** | 2025-10-07 |
| **Author** | © Flecki (Tom) Garnreiter |
| **Supersedes** | PowerShell-Regelwerk Universal v10.0.2 |
| **Scope** | Enterprise PowerShell Development |
| **License** | MIT License |
| **Language** | DE/EN (Bilingual) |

---

## 🎯 Executive Summary

**[DE]** Das PowerShell-Regelwerk Universal v10.0.3 Enterprise Complete Edition erweitert v10.0.2 um **3-Stufen Credential-Strategie** für intelligentes Passwort-Management. Diese Version definiert moderne, robuste und wartbare PowerShell-Entwicklung für Unternehmensumgebungen mit Fokus auf Zertifikatsverwaltung, E-Mail-Automation und sicheres Credential-Management.

**[EN]** The PowerShell-Regelwerk Universal v10.0.3 Enterprise Complete Edition extends v10.0.2 with **3-Tier Credential Strategy** for intelligent password management. This version defines modern, robust, and maintainable PowerShell development for enterprise environments with focus on certificate management, email automation and secure credential management.

---

## 🆕 Version 10.0.3 Änderungen / Changes

### Neue Standards / New Standards (v10.0.3)

- **🔐 §14: Security Standards:** 3-Stufen Credential-Strategie (Default → Vault → Prompt)
- **💾 FL-CredentialManager:** Windows Credential Manager Integration
- **🔑 Smart Authentication:** Automatische Passwort-Beschaffung ohne manuelle Prompts

### Neue Standards / New Standards (v10.0.2)

- **📧 Email-Standards:** MedUni Wien SMTP-Spezifikationen
- **📊 Excel-Integration:** Vollständige Excel-Automatisierung
- **🔐 Certificate Surveillance:** Enterprise-Zertifikatsüberwachung
- **🚀 Robocopy-Mandatory:** IMMER Robocopy für File-Operations verwenden

### Erweiterte Compliance

- **Universal PowerShell:** 5.1, 6.x, 7.x Kompatibilität
- **Network Deployment:** UNC-Path Installation Standards
- **Read-Only Security:** HTTP-Method Filtering für WebServices
- **Credential Management:** Automatische Passwort-Verwaltung (v10.0.3)

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

### Teil C: Certificate & Email Standards (v10.0.1) / Certificate & Email Standards

- **[§16: Email Standards MedUni Wien](#§16-email-standards-meduni-wien)**
- **[§17: Excel Integration](#§17-excel-integration--excel-integration)**
- **[§18: Certificate Surveillance](#§18-certificate-surveillance--zertifikatsüberwachung)**
- **[§19: PowerShell-Versionserkennung](#§19-powershell-versionserkennung-und-kompatibilitätsfunktionen-mandatory)**

---

## §16: Email Standards MedUni Wien

### 16.1 SMTP-Konfiguration (MANDATORY)

**[DE]** Alle E-Mail-Operationen MÜSSEN die MedUni Wien SMTP-Spezifikationen verwenden.

**[EN]** All email operations MUST use MedUni Wien SMTP specifications.

```powershell
# ✅ MANDATORY Email Configuration (Regelwerk v10.0.1)
$EmailConfig = @{
    SMTPServer = "smtpi.meduniwien.ac.at"
    SMTPPort = 25
    SMTPUser = ""  # Leer lassen für authentifizierte Verbindung
    SMTPPassword = ""  # Leer lassen
    FromEmail = "$env:COMPUTERNAME@meduniwien.ac.at"
    EnableSSL = $false
}

# Umgebungsspezifische Empfänger
$Recipients = @{
    DEV = @("thomas.garnreiter@meduniwien.ac.at")
    PROD = @("win-admin@meduniwien.ac.at", "thomas.garnreiter@meduniwien.ac.at")
}

# Standard-Betreffzeilen
$Subjects = @{
    PROD = "[Zertifikat] Überprüfung"
    DEV = "[DEV] Zertifikats überprüfung Test"
    WARNING = "[Zertifikat] Überprüfung - Warnung"
    CRITICAL = "[Zertifikat] Überprüfung - KRITISCH"
    INFO = "[Zertifikat] Überprüfung - Bericht"
}
```

### 16.2 Email-Templates (MANDATORY)

```powershell
# ✅ Professional Email Templates
function Get-EmailTemplate {
    param(
        [ValidateSet("Warning", "Critical", "Info")]
        [string]$Type,
        [hashtable]$Data
    )
    
    switch ($Type) {
        "Warning" {
            return @"
Sehr geehrte Damen und Herren,

unser Certificate Surveillance System hat Zertifikate gefunden, die in den nächsten $($Data.WarningDays) Tagen ablaufen:

$($Data.CertificateList)

EMPFOHLENE MASSNAHMEN:
• Zertifikate rechtzeitig erneuern
• Backup der aktuellen Zertifikate erstellen
• Deployment-Prozess vorbereiten

Mit freundlichen Grüßen
Certificate Surveillance System
IT-Services, Medizinische Universität Wien

---
Automatisch generiert am $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')
System: CertSurv v$($Data.Version) | Regelwerk: v10.0.1
"@
        }
        "Critical" {
            return @"
ACHTUNG - KRITISCHE WARNUNG!

Sehr geehrte Damen und Herren,

folgende SSL-Zertifikate laufen in den nächsten $($Data.CriticalDays) Tagen ab und erfordern SOFORTIGE MASSNAHMEN:

$($Data.CertificateList)

SOFORT ERFORDERLICH:
🔴 Zertifikate UNVERZÜGLICH erneuern
🔴 Produktionssysteme prüfen
🔴 Backup-Strategien aktivieren
🔴 Monitoring verstärken

Ein Service-Ausfall ist ohne sofortige Maßnahmen sehr wahrscheinlich!

Kontakt für Notfälle: it-security@meduniwien.ac.at

Mit freundlichen Grüßen
Certificate Surveillance System
IT-Services, Medizinische Universität Wien

---
Automatisch generiert am $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')
System: CertSurv v$($Data.Version) | Regelwerk: v10.0.1
PRIORITÄT: KRITISCH
"@
        }
    }
}
```

---

## §17: Excel Integration / Excel Integration

### 17.1 Excel-Konfiguration Standards (MANDATORY)

**[DE]** Alle Excel-Operationen MÜSSEN standardisierte Spalten-Mappings verwenden.

**[EN]** All Excel operations MUST use standardized column mappings.

```powershell
# ✅ MANDATORY Excel Configuration (Regelwerk v10.0.1)
$ExcelConfig = @{
    FilePath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\WindowsServerListe\Serverliste2025.xlsx"
    Worksheet = "ServerListe"
    StartRow = 2  # Header in Zeile 1
    Columns = @{
        Server = "A"      # FQDN Server-Namen
        IP = "B"          # IP-Adressen
        Status = "C"      # Online/Offline Status
        Certificate = "D" # Zertifikatsinformationen
        Expiry = "E"      # Ablaufdatum
    }
    AutoOpenExcel = $false
    CreateBackup = $true
}
```

### 17.2 Excel-Operations mit COM (MANDATORY)

```powershell
# ✅ Standardisierte Excel-Operationen
function Update-ExcelCertificateData {
    param(
        [string]$ExcelPath,
        [array]$CertificateData
    )
    
    try {
        # Excel COM Object erstellen
        $Excel = New-Object -ComObject Excel.Application
        $Excel.Visible = $false
        $Excel.DisplayAlerts = $false
        
        # Workbook öffnen
        $Workbook = $Excel.Workbooks.Open($ExcelPath)
        $Worksheet = $Workbook.Worksheets.Item("ServerListe")
        
        # Daten aktualisieren
        foreach ($Cert in $CertificateData) {
            $Row = Find-ServerRow -Worksheet $Worksheet -ServerName $Cert.ServerName
            if ($Row -gt 0) {
                $Worksheet.Cells.Item($Row, 4).Value2 = $Cert.Subject
                $Worksheet.Cells.Item($Row, 5).Value2 = $Cert.ExpiryDate.ToString("dd.MM.yyyy")
            }
        }
        
        # Speichern und schließen
        $Workbook.Save()
        $Workbook.Close()
        $Excel.Quit()
        
        # COM Objects freigeben
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Worksheet) | Out-Null
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Workbook) | Out-Null
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Excel) | Out-Null
        [System.GC]::Collect()
        
        Write-Host "Excel-Daten erfolgreich aktualisiert: $ExcelPath" -ForegroundColor Green
        
    } catch {
        Write-Error "Excel-Update fehlgeschlagen: $($_.Exception.Message)"
        # Cleanup bei Fehlern
        if ($Excel) { $Excel.Quit() }
    }
}
```

---

## §18: Certificate Surveillance / Zertifikatsüberwachung

### 18.1 Certificate Surveillance Architecture (MANDATORY)

**[DE]** Certificate Surveillance MUSS aus zwei Komponenten bestehen: CertWebService (API) und CertSurv (Scanner).

**[EN]** Certificate Surveillance MUST consist of two components: CertWebService (API) and CertSurv (Scanner).

```powershell
# ✅ Certificate Surveillance Workflow (Regelwerk v10.0.1)

# CertWebService: HTTPS API für Zertifikatsdaten
# - Port: 8443
# - Read-Only Modus: Nur GET/HEAD/OPTIONS
# - 3-Server Whitelist: ITSCMGMT03, ITSC020, itsc049
# - HTTP-Method Filtering via IIS

# CertSurv: Scanner und Report-Generator
# - Sammelt Daten von Serverlisten
# - Generiert Reports und E-Mails
# - Excel-Integration für Serverlisten
# - Tägliche Überwachung um 06:00
```

### 18.2 Certificate Data Standards (MANDATORY)

```powershell
# ✅ Standardisierte Zertifikatsdaten-Struktur
$CertificateData = @{
    ServerName = $env:COMPUTERNAME
    IPAddress = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.PrefixOrigin -eq 'Manual'}).IPAddress
    Certificates = @(
        @{
            Subject = "CN=server.meduniwien.ac.at"
            Issuer = "CN=MedUni Wien CA"
            Thumbprint = "1234567890ABCDEF..."
            ExpiryDate = (Get-Date).AddDays(30)
            DaysUntilExpiry = 30
            Store = "LocalMachine\My"
            IsValid = $true
        }
    )
    ScanDate = Get-Date
    Version = "2.3.0"
}
```

### 18.3 Read-Only Security Implementation (MANDATORY)

```powershell
# ✅ IIS HTTP-Method Filtering (web.config)
$WebConfigContent = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.webServer>
    <security>
      <requestFiltering>
        <verbs>
          <add verb="GET" allowed="true" />
          <add verb="HEAD" allowed="true" />
          <add verb="OPTIONS" allowed="true" />
          <add verb="POST" allowed="false" />
          <add verb="PUT" allowed="false" />
          <add verb="DELETE" allowed="false" />
          <add verb="PATCH" allowed="false" />
        </verbs>
      </requestFiltering>
    </security>
  </system.webServer>
</configuration>
"@

# ✅ 3-Server Access Control
$AuthorizedServers = @(
    "ITSCMGMT03.srv.meduniwien.ac.at",
    "ITSC020.cc.meduniwien.ac.at", 
    "itsc049.uvw.meduniwien.ac.at"
)
```

---

## §19: PowerShell-Versionserkennung und Kompatibilitätsfunktionen (MANDATORY)

### 19.1 Intelligente PowerShell-Versionserkennung (MANDATORY)

**[DE]** Alle Skripte MÜSSEN PowerShell-Versionserkennung implementieren für universelle Kompatibilität.

**[EN]** All scripts MUST implement PowerShell version detection for universal compatibility.

```powershell
# ✅ Regelwerk v10.0.2 - PowerShell Version Detection (MANDATORY)
$PSVersion = $PSVersionTable.PSVersion
$IsPS7Plus = $PSVersion.Major -ge 7
$IsPS5 = $PSVersion.Major -eq 5
$IsPS51 = $PSVersion.Major -eq 5 -and $PSVersion.Minor -eq 1

Write-Verbose "PowerShell Version: $($PSVersion.ToString())"
Write-Verbose "Compatibility Mode: $(if($IsPS7Plus){'PS 7.x Enhanced'}elseif($IsPS51){'PS 5.1 Compatible'}else{'PS 5.x Standard'})"

# Versionsspezifische Ausgabe
if ($IsPS7Plus) {
    Write-Host "🚀 Enhanced PowerShell Features Available" -ForegroundColor Green
} else {
    Write-Host "[SUCCESS] Standard PowerShell Compatibility Mode" -ForegroundColor Green
}
```

### 19.2 Versionsspezifische Hilfsfunktionen (MANDATORY)

**[DE]** Null-Coalescing Operatoren (??) sind nur in PowerShell 7+ verfügbar. Universelle Hilfsfunktionen MÜSSEN implementiert werden.

**[EN]** Null-coalescing operators (??) are only available in PowerShell 7+. Universal helper functions MUST be implemented.

```powershell
# ✅ Regelwerk v10.0.2 - Universal Configuration Helper Functions
function Get-ConfigValueSafe {
    param(
        [object]$Config,
        [string]$PropertyName,
        [object]$DefaultValue
    )
    
    # Hashtable support (PowerShell 5.1+)
    if ($Config -is [hashtable] -and $Config.ContainsKey($PropertyName) -and $null -ne $Config[$PropertyName]) {
        Write-Verbose "Get-ConfigValueSafe: Using config value for '$PropertyName': $($Config[$PropertyName])"
        return $Config[$PropertyName]
    } 
    # PSCustomObject support (PowerShell 5.1+)
    elseif ($Config -and $Config.PSObject.Properties.Name -contains $PropertyName -and $null -ne $Config.$PropertyName) {
        Write-Verbose "Get-ConfigValueSafe: Using config value for '$PropertyName': $($Config.$PropertyName)"
        return $Config.$PropertyName
    } else {
        Write-Verbose "Get-ConfigValueSafe: Using default value for '$PropertyName': $DefaultValue"
        return $DefaultValue
    }
}

function Get-ConfigArraySafe {
    param(
        [object]$Config,
        [string]$PropertyName,
        [array]$DefaultValue = @()
    )
    
    $value = Get-ConfigValueSafe -Config $Config -PropertyName $PropertyName -DefaultValue $DefaultValue
    
    # Array-to-String conversion for GUI display
    if ($value -and $value.Count -gt 0) {
        return $value -join ";"
    } else {
        return ""
    }
}
```

### 19.3 Encoding und Unicode-Kompatibilität (MANDATORY)

**[DE]** ASCII-kompatible Zeichen MÜSSEN in PowerShell 5.1 verwendet werden. Unicode-Fallbacks für ältere Versionen.

**[EN]** ASCII-compatible characters MUST be used in PowerShell 5.1. Unicode fallbacks for older versions.

```powershell
# ✅ Regelwerk v10.0.2 - Encoding-sichere Ausgabe
# ❌ FALSCH - Unicode Checkmarks in PowerShell 5.1
Write-Host "✅ Success" -ForegroundColor Green

# ✅ KORREKT - ASCII-kompatible Alternative
Write-Host "[SUCCESS] Operation completed" -ForegroundColor Green

# ✅ KORREKT - Versionsspezifische Unicode-Behandlung
if ($PSVersionTable.PSVersion.Major -ge 7) {
    Write-Host "🚀 Enhanced PowerShell Features" -ForegroundColor Green
    Write-Host "📋 Configuration loaded" -ForegroundColor Cyan
} else {
    Write-Host "[ENHANCED] PowerShell Features" -ForegroundColor Green
    Write-Host "[CONFIG] Configuration loaded" -ForegroundColor Cyan
}
```

### 19.4 Best Practices für PowerShell-Kompatibilität (MANDATORY)

```powershell
# ✅ Regelwerk v10.0.2 - PowerShell Compatibility Best Practices

# 1. Immer Version Detection am Skript-Anfang
$IsPS7Plus = $PSVersionTable.PSVersion.Major -ge 7

# 2. Hilfsfunktionen statt direkte Null-Coalescing
# ❌ FALSCH (nur PowerShell 7+):
$value = $Config.Property ?? $DefaultValue

# ✅ KORREKT (PowerShell 5.1+):
$value = Get-ConfigValueSafe -Config $Config -PropertyName "Property" -DefaultValue $DefaultValue

# 3. ASCII-sichere Ausgaben
# ❌ FALSCH:
Write-Host "✅ Done"

# ✅ KORREKT:
Write-Host "[SUCCESS] Done"

# 4. Encoding-Definition am Datei-Anfang
# UTF-8 ohne BOM für alle .ps1 Dateien
```

---

## §14: Security Standards / Sicherheitsstandards (NEW v10.0.3)

### 14.1 3-Stufen Credential-Strategie (MANDATORY)

**[DE]** Alle Scripts mit PSRemoting/Invoke-Command MÜSSEN die 3-Stufen Credential-Strategie verwenden zur Eliminierung manueller Passwort-Eingaben.

**[EN]** All scripts using PSRemoting/Invoke-Command MUST implement the 3-tier credential strategy to eliminate manual password prompts.

```powershell
# ✅ MANDATORY: 3-Stufen Credential-Strategie (Regelwerk v10.0.3)

# Import FL-CredentialManager Modul
Import-Module "$PSScriptRoot\Modules\FL-CredentialManager-v1.0.psm1" -Force

# STUFE 1: Default Admin Password (Environment Variable)
# STUFE 2: Windows Credential Manager Vault
# STUFE 3: Benutzer-Prompt mit Auto-Save

$Credential = Get-OrPromptCredential `
    -Target "SERVERNAME" `
    -Username "SERVERNAME\Administrator" `
    -AutoSave
```

### 14.2 Credential-Strategie Workflow (MANDATORY)

```
┌─────────────────────────────────────────┐
│  STUFE 1: Default Admin Password        │
│  Environment Variable                    │
│  ADMIN_DEFAULT_PASSWORD                  │
└─────────────────┬───────────────────────┘
                  │
                  ▼ Nicht gefunden?
┌─────────────────────────────────────────┐
│  STUFE 2: Windows Credential Manager    │
│  Gespeichertes Passwort für Target      │
│  cmdkey.exe / PasswordVault              │
└─────────────────┬───────────────────────┘
                  │
                  ▼ Nicht gefunden?
┌─────────────────────────────────────────┐
│  STUFE 3: Benutzer-Prompt               │
│  Get-Credential mit AutoSave             │
│  Speichert in Vault für nächstes Mal    │
└─────────────────────────────────────────┘
```

### 14.3 Setup: Default Admin Password (MANDATORY)

**[DE]** Einmalige Konfiguration des Default Admin Passworts für Standard-Deployments.

**[EN]** One-time configuration of default admin password for standard deployments.

```powershell
# ✅ MANDATORY Setup (einmalig pro Workstation)
Import-Module "$PSScriptRoot\Modules\FL-CredentialManager-v1.0.psm1"

# Default Admin Password setzen
$defaultPass = Read-Host "Default Admin Password" -AsSecureString
Set-DefaultAdminPassword -Password $defaultPass -Scope User

# Ab jetzt: Alle Scripts verwenden automatisch:
# 1. Default Password (falls verfügbar)
# 2. Vault (falls gespeichert)
# 3. Prompt (nur wenn nötig)
```

### 14.4 FL-CredentialManager Funktionen (MANDATORY)

```powershell
# ✅ Regelwerk v10.0.3 - FL-CredentialManager API

# Hauptfunktion: Intelligente Credential-Beschaffung
Get-OrPromptCredential `
    -Target "ServerName" `
    -Username "Domain\User" `
    -AutoSave

# Setup-Funktionen
Set-DefaultAdminPassword -Password $securePass -Scope User
Remove-DefaultAdminPassword -Scope User

# Vault-Management
Save-StoredCredential -Target "SERVER" -Username "admin" -Password $pass
Get-StoredCredential -Target "SERVER"
Remove-StoredCredential -Target "SERVER"
```

### 14.5 Script-Integration (MANDATORY)

**[DE]** Alle Deployment-Scripts MÜSSEN FL-CredentialManager am Anfang importieren.

**[EN]** All deployment scripts MUST import FL-CredentialManager at the beginning.

```powershell
# ✅ MANDATORY Script Header
#requires -Version 5.1
#Requires -RunAsAdministrator

# Import FL-CredentialManager für 3-Stufen-Strategie
Import-Module "$PSScriptRoot\Modules\FL-CredentialManager-v1.0.psm1" -Force

<#
.SYNOPSIS
    Your Script Title
.DESCRIPTION
    Your script automatically uses 3-tier credential strategy
#>

# Verwendung in Script
$cred = Get-OrPromptCredential `
    -Target $ServerName `
    -Username "$ServerName\Administrator" `
    -AutoSave

if ($cred) {
    Invoke-Command -ComputerName $ServerName -Credential $cred -ScriptBlock {
        # Deployment-Code hier
    }
}
```

### 14.6 Security Best Practices (MANDATORY)

```powershell
# ✅ Regelwerk v10.0.3 - Security Guidelines

# DO ✅:
# - Default-Password für Standard-Admin-Account
# - Server-spezifische Credentials im Vault
# - AutoSave für wiederkehrende Deployments
# - Windows Credential Manager verschlüsselten Storage nutzen

# DON'T ❌:
# - Default-Password in Scripts hardcoden
# - Passwörter in Klartext speichern
# - Credentials per Parameter übergeben (außer Tests)
# - Vault-Credentials manuell bearbeiten
```

### 14.7 Target-Naming Convention (MANDATORY)

**[DE]** Target-Namen MÜSSEN eindeutig sein für korrekte Vault-Zuordnung.

**[EN]** Target names MUST be unique for correct vault mapping.

```powershell
# ✅ KORREKT: Eindeutige Target-Namen

# Für einzelne Server
-Target "SERVERNAME"
-Target "SERVERNAME.domain.meduniwien.ac.at"

# Für Deployment-Typen
-Target "CertWebService-Deployment"
-Target "CertSurv-Deployment"
-Target "CertWebService-MassUpdate"

# ❌ FALSCH: Generische Namen
-Target "Server"
-Target "Admin"
-Target "Deployment"
```

### 14.8 Credential-Testing (MANDATORY)

```powershell
# ✅ Test-Script für 3-Stufen-Strategie
.\Test-3-Stufen-Credentials.ps1

# Ablauf:
# 1. Setup: Default Password setzen
# 2. TEST 1: Erste Ausführung (Default → Vault)
# 3. TEST 2: Zweite Ausführung (aus Vault)
# 4. REMOTE TEST: Tatsächliche Verbindung
# 5. Cleanup: Optional löschen
```

### 14.9 Production Scripts mit 3-Stufen-Strategie (REFERENCE)

**[DE]** Folgende Scripts implementieren bereits die 3-Stufen-Strategie:

**[EN]** Following scripts already implement the 3-tier strategy:

| Script | Verwendung | Target |
|--------|-----------|--------|
| `Update-CertSurv-ServerList.ps1` | Excel → ServerList Update | Server-spezifisch |
| `Install-CertSurv-Scanner-Final.ps1` | Scanner Installation | Server-spezifisch |
| `Update-AllServers-Hybrid-v2.5.ps1` | Mass Deployment | `CertWebService-Deployment` |
| `Deploy-CertSurv-QuickStart.ps1` | Quick Deployment | `CertSurv-Deployment` |
| `Update-FromExcel-MassUpdate.ps1` | Excel-basiertes Update | `CertWebService-MassUpdate` |

---

## §11: File Operations / Dateivorgänge (UPDATED v10.0.1)

### 11.1 Robocopy MANDATORY (UPDATED)

**[DE]** Alle File-Operations MÜSSEN **IMMER** Robocopy verwenden. Copy-Item, Move-Item sind VERBOTEN.

**[EN]** All file operations MUST **ALWAYS** use Robocopy. Copy-Item, Move-Item are FORBIDDEN.

```powershell
# ✅ IMMER Robocopy verwenden (Regelwerk v10.0.1)
function Copy-FileRobocopy {
    param(
        [string]$Source,
        [string]$Destination,
        [string]$FileName = "*.*",
        [int]$Retries = 3,
        [switch]$Mirror
    )
    
    $RobocopyArgs = @(
        "`"$Source`"",
        "`"$Destination`"",
        $FileName,
        "/R:$Retries",
        "/W:1",
        "/NP",
        "/LOG+:C:\Temp\Robocopy.log"
    )
    
    if ($Mirror) {
        $RobocopyArgs += "/MIR"
    }
    
    Write-Host "Robocopy: $Source -> $Destination" -ForegroundColor Yellow
    $Result = & robocopy @RobocopyArgs
    
    # Robocopy Exit Codes: 0-7 sind Erfolg
    if ($LASTEXITCODE -le 7) {
        Write-Host "Robocopy erfolgreich (Exit Code: $LASTEXITCODE)" -ForegroundColor Green
        return $true
    } else {
        Write-Error "Robocopy fehlgeschlagen (Exit Code: $LASTEXITCODE)"
        return $false
    }
}

# ❌ VERBOTEN - Niemals verwenden!
# Copy-Item
# Move-Item
```

### 11.2 Network File Operations (UPDATED)

```powershell
# ✅ Network Robocopy mit UNC-Paths
function Sync-NetworkDirectory {
    param(
        [string]$LocalPath,
        [string]$NetworkPath,
        [switch]$ToNetwork,
        [switch]$FromNetwork
    )
    
    if ($ToNetwork) {
        $Source = $LocalPath
        $Destination = $NetworkPath
    } elseif ($FromNetwork) {
        $Source = $NetworkPath  
        $Destination = $LocalPath
    }
    
    # IMMER Robocopy für Network Operations
    robocopy "`"$Source`"" "`"$Destination`"" /MIR /R:3 /W:1 /NP /LOG+:C:\Temp\NetworkSync.log
    
    if ($LASTEXITCODE -le 7) {
        Write-Host "Network-Sync erfolgreich: $Source -> $Destination" -ForegroundColor Green
    } else {
        Write-Error "Network-Sync fehlgeschlagen (Exit Code: $LASTEXITCODE)"
    }
}
```

---

## 📊 Compliance Matrix v10.0.3

| **Standard** | **v10.0.0** | **v10.0.2** | **v10.0.3** | **Status** |
|--------------|-------------|-------------|-------------|------------|
| Version Management | ✅ | ✅ | ✅ | Stable |
| Script Headers | ✅ | ✅ | ✅ | Stable |
| Functions | ✅ | ✅ | ✅ | Stable |
| Error Handling | ✅ | ✅ | ✅ | Stable |
| Logging | ✅ | ✅ | ✅ | Stable |
| Configuration | ✅ | ✅ | ✅ | Stable |
| Modules & Repository | ✅ | ✅ | ✅ | Stable |
| PowerShell Compatibility | ✅ | ✅ | ✅ | Enhanced |
| GUI Standards | ✅ | ✅ | ✅ | Enhanced |
| Strict Modularity | ✅ | ✅ | ✅ | Stable |
| **Robocopy MANDATORY** | ✅ | **🆕 ENHANCED** | ✅ | **CRITICAL** |
| Cross-Script Communication | ✅ | ✅ | ✅ | Stable |
| Network Operations | ✅ | ✅ | ✅ | Enhanced |
| **§14: Security Standards** | ❌ | ❌ | **🆕 NEW** | **MANDATORY** |
| **3-Tier Credential Strategy** | ❌ | ❌ | **🆕 NEW** | **CRITICAL** |
| Performance Optimization | ✅ | ✅ | ✅ | Stable |
| **Email Standards MedUni** | ❌ | **🆕 NEW** | ✅ | **MANDATORY** |
| **Excel Integration** | ❌ | **🆕 NEW** | ✅ | **MANDATORY** |
| **Certificate Surveillance** | ❌ | **🆕 NEW** | ✅ | **ENTERPRISE** |

---

## 🚀 Implementation Roadmap v10.0.1

### Phase 1: Email & Excel Standards (COMPLETED)

- ✅ MedUni Wien SMTP-Konfiguration
- ✅ Professional Email-Templates  
- ✅ Excel-COM Integration
- ✅ Spalten-Mappings definiert

### Phase 2: Certificate Surveillance (COMPLETED)

- ✅ CertWebService v2.3.0 (Read-Only API)
- ✅ CertSurv v2.0.0 (Scanner & Reports)
- ✅ 3-Server Whitelist Security
- ✅ HTTP-Method Filtering

### Phase 3: Robocopy Enforcement (CRITICAL)

- ✅ Copy-Item/Move-Item VERBOTEN
- ✅ Network UNC-Path Standards
- ✅ Error Handling für Robocopy
- ✅ Logging für alle File-Operations

---

## 📝 Migration Guide: v10.0.0 → v10.0.1

### Critical Changes

1. **ALLE Copy-Item/Move-Item durch Robocopy ersetzen**
2. **Email-Konfiguration auf MedUni Wien SMTP umstellen**
3. **Excel-Operationen standardisieren**
4. **Certificate Surveillance implementieren**

### Migration Script

```powershell
# Migration Helper v10.0.1
function Update-ToRegelwerk1001 {
    Write-Host "=== Migration zu Regelwerk v10.0.1 ===" -ForegroundColor Cyan
    
    # 1. Robocopy Check
    $CopyItemUsage = Get-ChildItem -Recurse -Filter "*.ps1" | Select-String "Copy-Item|Move-Item"
    if ($CopyItemUsage) {
        Write-Warning "KRITISCH: Copy-Item/Move-Item gefunden! Muss durch Robocopy ersetzt werden!"
        $CopyItemUsage | Format-Table -AutoSize
    }
    
    # 2. Email-Konfiguration prüfen
    $EmailConfig = Get-ChildItem -Recurse -Filter "*.ps1" | Select-String "smtp\."
    if ($EmailConfig) {
        Write-Warning "Email-Konfiguration prüfen: Muss auf smtpi.meduniwien.ac.at umgestellt werden!"
    }
    
    Write-Host "Migration-Analyse abgeschlossen" -ForegroundColor Green
}
```

---

## 📜 Changelog v10.0.3

### New Features (v10.0.3)

- **🔐 §14:** 3-Stufen Credential-Strategie (Default → Vault → Prompt)
- **💾 FL-CredentialManager:** Windows Credential Manager Integration
- **🔑 Smart Authentication:** Automatische Passwort-Beschaffung
- **✅ Production Ready:** 5 Haupt-Scripts mit 3-Stufen-Strategie integriert

### New Features (v10.0.2)

- **📧 §16:** Email Standards MedUni Wien
- **📊 §17:** Excel Integration Guidelines  
- **🔐 §18:** Certificate Surveillance Standards
- **🚀 Enhanced §11:** Robocopy MANDATORY enforcement

### Enhancements

- **Universal PowerShell:** 5.1, 6.x, 7.x compatibility
- **Network Deployment:** UNC-Path installation standards
- **Read-Only Security:** HTTP-method filtering
- **Professional Templates:** Enterprise-grade email templates
- **Zero-Prompt Deployments:** Wiederholte Deployments ohne manuelle Eingaben (v10.0.3)

### Critical

- **Copy-Item/Move-Item:** Now FORBIDDEN - use Robocopy ALWAYS
- **SMTP:** Must use `smtpi.meduniwien.ac.at`
- **Excel:** Standardized column mappings mandatory
- **Credentials:** MUST use 3-tier strategy for all PSRemoting operations (v10.0.3)

---

## 📋 License & Copyright

```
MIT License

Copyright (c) 2025 Flecki (Tom) Garnreiter

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

**PowerShell-Regelwerk Universal v10.0.3 Enterprise Complete Edition**  
**© 2025 Flecki (Tom) Garnreiter | Release: 2025-10-07**  
**Status: ENTERPRISE READY | Compliance: Certificate Surveillance, Email Automation, Excel Integration, 3-Tier Credential Management**
