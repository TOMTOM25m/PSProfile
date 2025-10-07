# CertSurv Deployment Plan - Regelwerk v10.0.2

**Version:** 1.0.0  
**Date:** 2025-10-06  
**Status:** Ready for Implementation

---

## 🎯 Deployment-Übersicht

### Infrastruktur-Rollen

| **Server** | **Rolle** | **Software** | **Deployment von** |
|------------|-----------|--------------|-------------------|
| **ITSC020** | Deployment-Zentrale | Update-Tools | Ihre Workstation |
| **ITSCMGMT03** | CertSurv Scanner + WebService Client | CertSurv + CertWebService | ITSC020 |
| **Alle anderen Server** | WebService Client Only | CertWebService | ITSC020 |

---

## 🚀 Phase 1: CertWebService auf alle Server deployen

### Option A: Mass-Update mit Hybrid-Script (EMPFOHLEN)

```powershell
# Von ITSC020 aus:
cd F:\DEV\repositories\CertWebService

# Excel-Serverliste aktualisieren
.\Excel-Update-Launcher.ps1 -Mode Deploy -Filter All

# Alle Server updaten
.\Update-AllServers-Hybrid-v2.5.ps1 `
    -ServerList @("server01.meduniwien.ac.at", "server02.meduniwien.ac.at", "...") `
    -NetworkSharePath "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService" `
    -GenerateReports
```

### Option B: Excel-gesteuerte Deployment

```powershell
# Von ITSC020 aus:
.\Excel-Update-Launcher.ps1 -Mode Deploy -Filter All -Force
```

### Option C: Einzelserver-Deployment

```powershell
# Für einzelne kritische Server
.\Update-AllServers-Hybrid-v2.5.ps1 `
    -ServerList @("critical-server.meduniwien.ac.at") `
    -NetworkSharePath "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService" `
    -TestOnly  # Erst testen!
```

---

## 📊 Phase 2: CertSurv auf ITSCMGMT03 installieren

### 2.1 CertSurv Scanner-Komponenten deployen

```powershell
# Von ITSC020 aus:

# 1. CertSurv Hauptverzeichnis erstellen
$TargetPath = "\\ITSCMGMT03.srv.meduniwien.ac.at\C$\CertSurv"
New-Item -Path $TargetPath -ItemType Directory -Force

# 2. Scanner-Komponenten kopieren
robocopy "F:\DEV\repositories\CertSurv" $TargetPath /MIR /R:3 /W:1 /XD ".git" "Temp" "Backup" /LOG+:C:\Temp\CertSurv-Deploy.log

# 3. Konfiguration anpassen
# Manuelle Anpassung der Config/AppConfig.json auf ITSCMGMT03
```

### 2.2 CertSurv Setup ausführen

```powershell
# Auf ITSCMGMT03 (Remote oder lokal):

# PowerShell-Version prüfen
$PSVersionTable.PSVersion

# Setup ausführen
cd C:\CertSurv
.\Setup-CertSurv.ps1

# Tägliche Überwachung einrichten
.\Setup-DailyEmailTask.ps1
```

---

## 🔐 Phase 3: Security & Access Control

### 3.1 3-Server Whitelist konfigurieren

Auf jedem CertWebService Server die `web.config` anpassen:

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <appSettings>
    <add key="AuthorizedServers" value="ITSCMGMT03.srv.meduniwien.ac.at;ITSC020.cc.meduniwien.ac.at;itsc049.uvw.meduniwien.ac.at" />
  </appSettings>
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
        </verbs>
      </requestFiltering>
    </security>
  </system.webServer>
</configuration>
```

### 3.2 Firewall-Regeln einrichten

```powershell
# Auf jedem Server:
New-NetFirewallRule -DisplayName "CertWebService HTTPS" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 8443 `
    -Action Allow `
    -Profile Domain
```

---

## 📧 Phase 4: Email-Konfiguration (MedUni Wien SMTP)

### 4.1 SMTP-Einstellungen in CertSurv anpassen

Datei: `C:\CertSurv\Config\AppConfig.json` auf ITSCMGMT03

```json
{
  "EmailSettings": {
    "SMTPServer": "smtpi.meduniwien.ac.at",
    "SMTPPort": 25,
    "EnableSSL": false,
    "FromEmail": "ITSCMGMT03@meduniwien.ac.at",
    "Recipients": {
      "PROD": [
        "win-admin@meduniwien.ac.at",
        "thomas.garnreiter@meduniwien.ac.at"
      ],
      "DEV": [
        "thomas.garnreiter@meduniwien.ac.at"
      ]
    }
  }
}
```

### 4.2 Email-Templates testen

```powershell
# Auf ITSCMGMT03:
cd C:\CertSurv
.\Test-EmailConfiguration.ps1
```

---

## 📊 Phase 5: Excel-Integration

### 5.1 Excel-Serverliste konfigurieren

Datei: `C:\CertSurv\Config\AppConfig.json`

```json
{
  "ExcelSettings": {
    "FilePath": "\\\\itscmgmt03.srv.meduniwien.ac.at\\iso\\WindowsServerListe\\Serverliste2025.xlsx",
    "Worksheet": "ServerListe",
    "StartRow": 2,
    "Columns": {
      "Server": "A",
      "IP": "B",
      "Status": "C",
      "Certificate": "D",
      "Expiry": "E"
    }
  }
}
```

### 5.2 Excel-Zugriff testen

```powershell
# Auf ITSCMGMT03:
.\Test-ExcelAccess.ps1
```

---

## 🔍 Phase 6: Monitoring & Testing

### 6.1 CertWebService Health-Check

```powershell
# Von ITSC020 aus alle Server testen:
$Servers = Get-Content ".\Config\ServerList.txt"

foreach ($Server in $Servers) {
    Write-Host "Testing $Server..." -ForegroundColor Yellow
    
    try {
        $Response = Invoke-WebRequest -Uri "https://${Server}:8443/certificates" -UseBasicParsing -TimeoutSec 10
        Write-Host "  [OK] $Server - Status: $($Response.StatusCode)" -ForegroundColor Green
    } catch {
        Write-Host "  [ERROR] $Server - $($_.Exception.Message)" -ForegroundColor Red
    }
}
```

### 6.2 CertSurv Scanner-Test

```powershell
# Auf ITSCMGMT03:
cd C:\CertSurv

# Einzelnen Test-Scan durchführen
.\Cert-Surveillance-Main.ps1 -TestMode -Verbose

# Report prüfen
Get-ChildItem .\Reports\ | Sort-Object LastWriteTime -Descending | Select-Object -First 5
```

---

## 📅 Phase 7: Produktiv-Betrieb

### 7.1 Scheduled Task prüfen

```powershell
# Auf ITSCMGMT03:
Get-ScheduledTask | Where-Object { $_.TaskName -like "*CertSurv*" }

# Manuell ausführen zum Test
Start-ScheduledTask -TaskName "CertSurv-DailyCheck"
```

### 7.2 Log-Monitoring einrichten

```powershell
# Log-Dateien überwachen:
# C:\CertSurv\LOG\Cert-Surveillance-Main_*.log
# C:\CertWebService\LOG\CertWebService_*.log

# Log-Rotation einrichten
.\Cleanup-CertSurv.ps1
```

---

## 🛠️ Wichtige Scripts für Deployment

### Von ITSC020 (Deployment-Zentrale)

| **Script** | **Zweck** | **Ziel** |
|------------|-----------|----------|
| `Update-AllServers-Hybrid-v2.5.ps1` | Mass-Deployment | Alle Server |
| `Excel-Update-Launcher.ps1` | Excel-gesteuerte Updates | Serverliste-basiert |
| `Test-NetworkConnectivity.ps1` | Pre-Deployment Check | Alle Server |

### Auf ITSCMGMT03 (Management-Server)

| **Script** | **Zweck** | **Ausführung** |
|------------|-----------|----------------|
| `Cert-Surveillance-Main.ps1` | Haupt-Scanner | Täglich 06:00 |
| `Setup-DailyEmailTask.ps1` | Task-Scheduler | Einmalig |
| `Cleanup-CertSurv.ps1` | Log-Rotation | Wöchentlich |

### Auf allen Target-Servern

| **Komponente** | **Port** | **Zweck** |
|----------------|----------|-----------|
| CertWebService | 8443 | HTTPS API |
| IIS ApplicationHost | - | WebService Host |

---

## ⚠️ Pre-Deployment Checkliste

- [ ] PowerShell Version auf allen Servern geprüft (5.1 oder 7.x)
- [ ] Network Share Zugriff getestet: `\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService`
- [ ] Admin-Credentials für PSRemoting vorbereitet
- [ ] Excel-Serverliste aktualisiert
- [ ] SMTP-Server erreichbar: `smtpi.meduniwien.ac.at:25`
- [ ] Firewall-Regeln für Port 8443 geprüft
- [ ] Backup aller Konfigurationen erstellt
- [ ] Test-Server für Pilot-Deployment ausgewählt

---

## 🎯 Empfohlene Deployment-Reihenfolge

1. **Test-Server** (1-2 Server)
   - Deployment testen
   - Health-Check durchführen
   - 24h Monitoring

2. **ITSCMGMT03** (Management-Server)
   - CertWebService installieren
   - CertSurv Scanner installieren
   - Email-Konfiguration testen
   - Excel-Integration prüfen

3. **Kritische Server** (5-10 Server)
   - Deployment durchführen
   - Monitoring aktivieren

4. **Alle verbleibenden Server**
   - Mass-Deployment
   - Automatisches Monitoring

---

## 📞 Support & Troubleshooting

### Häufige Probleme

1. **PSRemoting schlägt fehl**
   - Fallback auf Network Share Deployment
   - Manual Package generieren

2. **Port 8443 blockiert**
   - Firewall-Regeln prüfen
   - `Test-NetConnection -ComputerName Server -Port 8443`

3. **Excel-Zugriff fehlgeschlagen**
   - SMB-Verbindung prüfen
   - Berechtigungen auf ISO-Share

### Log-Dateien

```
ITSC020:
- F:\DEV\repositories\CertWebService\LOG\*.log

ITSCMGMT03:
- C:\CertSurv\LOG\*.log
- C:\CertWebService\LOG\*.log

Target Servers:
- C:\CertWebService\LOG\*.log
```

---

**Deployment Plan v1.0.0**  
**Regelwerk: v10.0.2**  
**Erstellt: 2025-10-06**  
**Status: Ready for Implementation** ✅
