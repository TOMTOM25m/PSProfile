# Certificate Web Service - Enterprise Deployment Guide

**Version:** 1.0.0  
**Datum:** 16. September 2025  
**Zielgruppe:** Server-Administratoren  
**Verteilungsserver:** `\\itscmgmt03.srv.meduniwien.ac.at\iso\CertDeployment`

## 📋 Übersicht

Das Certificate Web Service bietet eine performante Alternative zur direkten SSL-Zertifikatsabfrage durch Bereitstellung einer IIS-basierten REST API und Web-Dashboard. Anstatt 2-5 Sekunden pro Server für SSL-Verbindungen zu benötigen, ermöglicht das WebService API-Calls in 0.1-0.3 Sekunden.

### 🎯 Vorteile

- ⚡ **Performance:** 10x schnellere Zertifikatsabfrage
- 🔒 **HTTPS:** Self-Signed Certificate mit automatischer Installation
- 📊 **Web-Dashboard:** Übersichtliche Zertifikatsverwaltung
- 🔄 **Automatisierung:** Tägliche Updates um 17:00 Uhr
- 🛡️ **Security:** Windows Authentication
- 📱 **API:** REST-Endpunkte für programmatische Zugriffe

## 📦 Verfügbare Packages

### Aktuelle Version
- **Latest:** `CertWebService_Latest.zip` (immer die neueste Version)
- **Timestamped:** `CertWebService_YYYY-MM-DD_HH-mm.zip` (archivierte Versionen)

### Package Inhalt
```
CertWebService/
├── Install-CertificateWebService.ps1    # Hauptinstallation
├── Install-CertWebServiceTask.ps1       # Task Scheduler Setup
├── Update-CertificateWebService.ps1     # Content Updates
├── Manage-CertWebServiceTask.ps1        # Task Management
├── README.md                            # Vollständige Dokumentation
├── Config/
│   ├── Config-CertWebService.json       # Konfiguration
│   ├── en-US.json                       # Englische Texte
│   └── de-DE.json                       # Deutsche Texte
├── Modules/
│   ├── FL-Config.psm1                   # Konfigurationsmanagement
│   ├── FL-Logging.psm1                  # Logging-Funktionen
│   └── FL-WebService.psm1               # WebService-Kernfunktionen
└── LOG/                                 # Log-Verzeichnis
```

## 🚀 Installation auf Zielservern

### Schritt 1: Package herunterladen

```powershell
# Als Administrator auf dem Zielserver
Copy-Item '\\itscmgmt03.srv.meduniwien.ac.at\iso\CertDeployment\CertWebService_Latest.zip' 'C:\Temp\' -Force
```

### Schritt 2: Entpacken

```powershell
# Nach C:\Script\CertWebService entpacken
Expand-Archive 'C:\Temp\CertWebService_Latest.zip' 'C:\Script\' -Force
```

### Schritt 3: Installation

```powershell
# WebService installieren
cd 'C:\Script\CertWebService'
.\Install-CertificateWebService.ps1
```

**Was passiert bei der Installation:**
- ✅ IIS-Features aktivieren
- ✅ Self-Signed Certificate erstellen
- ✅ HTTPS-Binding auf Port 8443 konfigurieren
- ✅ Firewall-Regeln einrichten
- ✅ Windows Authentication aktivieren
- ✅ Web-Dashboard bereitstellen

### Schritt 4: Task Scheduler einrichten

```powershell
# Tägliche Updates um 17:00 Uhr
.\Install-CertWebServiceTask.ps1
```

### Schritt 5: Installation testen

```powershell
# Task Status prüfen
.\Manage-CertWebServiceTask.ps1 -Action Status

# Web-Interface testen
Start-Process "https://localhost:8443"
```

## 🔧 Systemanforderungen

### Mindestanforderungen
- **OS:** Windows Server 2016 oder höher
- **IIS:** Version 10.0+
- **PowerShell:** Version 5.1+
- **RAM:** 2 GB verfügbar
- **Disk:** 500 MB freier Speicher

### Netzwerk
- **Port 8080:** HTTP (wird zu HTTPS umgeleitet)
- **Port 8443:** HTTPS (Hauptzugang)
- **Firewall:** Automatisch konfiguriert

### Berechtigungen
- **Administrator-Rechte** für Installation erforderlich
- **SYSTEM-Konto** für Task Scheduler
- **Windows Authentication** für Web-Zugriff

## 📊 Verwendung nach Installation

### Web-Dashboard
```
https://[servername]:8443
```
- Übersichtliche Tabelle aller Zertifikate
- Filtermöglichkeiten nach Ablaufdatum
- Responsive Design für verschiedene Geräte

### REST API
```powershell
# Alle Zertifikate abrufen
$certs = Invoke-RestMethod -Uri "https://[servername]:8443/api/certificates" -UseDefaultCredentials

# JSON-Format
$certsJson = Invoke-RestMethod -Uri "https://[servername]:8443/api/certificates.json" -UseDefaultCredentials
```

### Task Management
```powershell
# Task Status prüfen
.\Manage-CertWebServiceTask.ps1 -Action Status

# Task manuell starten
.\Manage-CertWebServiceTask.ps1 -Action Start

# Task-Historie anzeigen
.\Manage-CertWebServiceTask.ps1 -Action History
```

## 🔄 Automatisierte Multi-Server Deployment

Für die Verteilung auf mehrere Server:

```powershell
# Multi-Server Deployment Script
$servers = @('server1', 'server2', 'server3')
$distributionZip = '\\itscmgmt03.srv.meduniwien.ac.at\iso\CertDeployment\CertWebService_Latest.zip'

foreach ($server in $servers) {
    Write-Host "Deploying to $server..." -ForegroundColor Cyan
    
    try {
        # Package zum Server kopieren
        Copy-Item $distributionZip "\\$server\C$\Temp\" -Force
        
        # Remote Installation (benötigt PowerShell Remoting)
        Invoke-Command -ComputerName $server -ScriptBlock {
            # Entpacken
            Expand-Archive 'C:\Temp\CertWebService_Latest.zip' 'C:\Script\' -Force
            
            # Installation
            Set-Location 'C:\Script\CertWebService'
            .\Install-CertificateWebService.ps1
            .\Install-CertWebServiceTask.ps1
        }
        
        Write-Host "✅ Deployment to $server completed" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Deployment to $server failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}
```

## 🛠️ Wartung und Updates

### Manuelle Updates
```powershell
# Sofortiges Update (ignoriert Cache)
.\Update-CertificateWebService.ps1 -Force

# Normales Update (respektiert Cache-Einstellungen)
.\Update-CertificateWebService.ps1
```

### Log-Dateien
```
C:\Script\CertWebService\LOG\
├── DEV_Install-CertWebService_YYYY-MM-DD.log
├── TASK_Update-CertWebService_YYYY-MM-DD.log
└── Windows Event Log: Application → CertificateWebService
```

### Konfiguration anpassen
```powershell
# Konfigurationsdatei bearbeiten
notepad "C:\Script\CertWebService\Config\Config-CertWebService.json"

# Cache-Einstellungen:
# - CacheDurationMinutes: 15 (Standard)
# - MaxCertificatesPerPage: 100
# - Ports: 8080 (HTTP), 8443 (HTTPS)
```

## 🔍 Troubleshooting

### Häufige Probleme

#### 1. IIS-Features fehlen
```powershell
# Features manuell installieren
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WindowsAuthentication
```

#### 2. Port-Konflikte
```powershell
# Verwendete Ports prüfen
netstat -an | findstr ":8443"
netstat -an | findstr ":8080"
```

#### 3. Certificate-Probleme
```powershell
# Certificates prüfen
Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -like "*CertWebService*" }
```

#### 4. Authentication-Issues
```powershell
# Test mit PowerShell
Invoke-RestMethod -Uri "https://localhost:8443/api/certificates.json" -UseDefaultCredentials
```

### Support-Informationen sammeln
```powershell
# System-Info sammeln
Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, TotalPhysicalMemory

# IIS-Status prüfen
Get-Service W3SVC, WAS

# Task-Status prüfen
Get-ScheduledTask -TaskName "CertWebService-DailyUpdate" | Get-ScheduledTaskInfo
```

## 📞 Support

Bei Problemen oder Fragen:

1. **Log-Dateien prüfen:** `C:\Script\CertWebService\LOG\`
2. **Task-Status überprüfen:** `.\Manage-CertWebServiceTask.ps1 -Action Status`
3. **Event Log kontrollieren:** Windows Event Viewer → Application → CertificateWebService

## 📚 Weiterführende Dokumentation

- **Vollständige Dokumentation:** `C:\Script\CertWebService\README.md`
- **Konfigurationsreferenz:** `Config\Config-CertWebService.json`
- **API-Dokumentation:** Siehe README.md im WebService-Verzeichnis

---

**© 2025 Medical University of Vienna | Regelwerk v9.3.0**

*Diese Anleitung wurde automatisch generiert und ist spezifisch für die Deployment-Umgebung der MedUni Wien.*