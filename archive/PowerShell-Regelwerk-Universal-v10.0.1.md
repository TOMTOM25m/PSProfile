# PowerShell-Regelwerk Universal v10.0.1

**Enterprise Complete Edition - Comprehensive PowerShell Development Standards**

---

## 📋 Document Information

| **Attribute** | **Value** |
|---------------|-----------|
| **Version** | v10.0.1 |
| **Status** | Enterprise Complete |
| **Release Date** | 2025-09-30 |
| **Author** | © Flecki (Tom) Garnreiter |
| **Supersedes** | PowerShell-Regelwerk Universal v10.0.0 |
| **Scope** | Enterprise PowerShell Development |
| **License** | MIT License |
| **Language** | DE/EN (Bilingual) |

---

## 🎯 Executive Summary

**[DE]** Das PowerShell-Regelwerk Universal v10.0.1 Enterprise Complete Edition erweitert v10.0.0 um **Certificate Surveillance Standards**, **MedUni Wien Email-Spezifikationen** und **Excel-Integration Guidelines**. Diese Version definiert moderne, robuste und wartbare PowerShell-Entwicklung für Unternehmensumgebungen mit Fokus auf Zertifikatsverwaltung und E-Mail-Automation.

**[EN]** The PowerShell-Regelwerk Universal v10.0.1 Enterprise Complete Edition extends v10.0.0 with **Certificate Surveillance Standards**, **MedUni Wien Email Specifications** and **Excel Integration Guidelines**. This version defines modern, robust, and maintainable PowerShell development for enterprise environments with focus on certificate management and email automation.

---

## 🆕 Version 10.0.1 Änderungen / Changes

### Neue Standards / New Standards:
- **📧 Email-Standards:** MedUni Wien SMTP-Spezifikationen
- **📊 Excel-Integration:** Vollständige Excel-Automatisierung
- **🔐 Certificate Surveillance:** Enterprise-Zertifikatsüberwachung
- **🚀 Robocopy-Mandatory:** IMMER Robocopy für File-Operations verwenden

### Erweiterte Compliance:
- **Universal PowerShell:** 5.1, 6.x, 7.x Kompatibilität
- **Network Deployment:** UNC-Path Installation Standards
- **Read-Only Security:** HTTP-Method Filtering für WebServices

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

## 📊 Compliance Matrix v10.0.1

| **Standard** | **v10.0.0** | **v10.0.1** | **Status** |
|--------------|-------------|-------------|------------|
| Version Management | ✅ | ✅ | Stable |
| Script Headers | ✅ | ✅ | Stable |
| Functions | ✅ | ✅ | Stable |
| Error Handling | ✅ | ✅ | Stable |
| Logging | ✅ | ✅ | Stable |
| Configuration | ✅ | ✅ | Stable |
| Modules & Repository | ✅ | ✅ | Stable |
| PowerShell Compatibility | ✅ | ✅ | Enhanced |
| GUI Standards | ✅ | ✅ | Enhanced |
| Strict Modularity | ✅ | ✅ | Stable |
| **Robocopy MANDATORY** | ✅ | **🆕 ENHANCED** | **CRITICAL** |
| Cross-Script Communication | ✅ | ✅ | Stable |
| Network Operations | ✅ | ✅ | Enhanced |
| Security Standards | ✅ | ✅ | Enhanced |
| Performance Optimization | ✅ | ✅ | Stable |
| **Email Standards MedUni** | ❌ | **🆕 NEW** | **MANDATORY** |
| **Excel Integration** | ❌ | **🆕 NEW** | **MANDATORY** |
| **Certificate Surveillance** | ❌ | **🆕 NEW** | **ENTERPRISE** |

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

### Critical Changes:
1. **ALLE Copy-Item/Move-Item durch Robocopy ersetzen**
2. **Email-Konfiguration auf MedUni Wien SMTP umstellen**
3. **Excel-Operationen standardisieren**
4. **Certificate Surveillance implementieren**

### Migration Script:
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

## 📜 Changelog v10.0.1

### New Features:
- **📧 §16:** Email Standards MedUni Wien
- **📊 §17:** Excel Integration Guidelines  
- **🔐 §18:** Certificate Surveillance Standards
- **🚀 Enhanced §11:** Robocopy MANDATORY enforcement

### Enhancements:
- **Universal PowerShell:** 5.1, 6.x, 7.x compatibility
- **Network Deployment:** UNC-Path installation standards
- **Read-Only Security:** HTTP-method filtering
- **Professional Templates:** Enterprise-grade email templates

### Critical:
- **Copy-Item/Move-Item:** Now FORBIDDEN - use Robocopy ALWAYS
- **SMTP:** Must use `smtpi.meduniwien.ac.at`
- **Excel:** Standardized column mappings mandatory

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

**PowerShell-Regelwerk Universal v10.0.1 Enterprise Complete Edition**  
**© 2025 Flecki (Tom) Garnreiter | Release: 2025-09-30**  
**Status: ENTERPRISE READY | Compliance: Certificate Surveillance, Email Automation, Excel Integration**