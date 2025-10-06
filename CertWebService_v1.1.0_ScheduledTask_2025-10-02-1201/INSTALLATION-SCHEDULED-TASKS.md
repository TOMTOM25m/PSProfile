# CertWebService v1.1.0 - Scheduled Task Installation

**Datum:** 02.10.2025  
**Version:** v1.1.0 mit Scheduled Task-Architektur  
**Regelwerk:** Universal v10.0.2

## ✨ NEUE ARCHITEKTUR

Das Windows Service-System wurde durch eine **Scheduled Task-basierte Architektur** ersetzt:

### 🔄 **Zwei getrennte Tasks:**
- **CertWebService-WebServer** (dauerhaft aktiv)
  - Startet beim Systemstart
  - Stellt Web-Dashboard und API bereit (Port 9080)
  - Läuft kontinuierlich im Hintergrund

- **CertWebService-DailyScan** (täglich um 06:00)  
  - Führt den Zertifikatsscan einmal täglich aus
  - Automatische Ausführung um 06:00 Uhr
  - Erstellt Reports und sendet E-Mails

## 🚀 INSTALLATION

### 1. **Vorbereitung**
```powershell
# Als Administrator ausführen
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
```

### 2. **Installation starten**
```powershell
# Im Package-Verzeichnis:
.\Setup.ps1
```

### 3. **Installation überprüfen**
```powershell
# Task-Status prüfen:
.\Scripts\Manage-CertWebService-Tasks.ps1 -Action Status
```

## 🛠️ VERWALTUNG

### **Management-Script verwenden:**
```powershell
# Status anzeigen
.\Scripts\Manage-CertWebService-Tasks.ps1 -Action Status

# Tasks starten
.\Scripts\Manage-CertWebService-Tasks.ps1 -Action Start

# Tasks stoppen  
.\Scripts\Manage-CertWebService-Tasks.ps1 -Action Stop

# Tasks neustarten
.\Scripts\Manage-CertWebService-Tasks.ps1 -Action Restart

# Tasks entfernen
.\Scripts\Manage-CertWebService-Tasks.ps1 -Action Remove
```

### **Manuelle Task-Verwaltung:**
```powershell
# Task-Status in Windows anzeigen
Get-ScheduledTask -TaskName "CertWebService-*"

# Task manuell starten
Start-ScheduledTask -TaskName "CertWebService-DailyScan"
```

## 🌐 WEB-ZUGRIFF

Nach der Installation ist das Web-Dashboard verfügbar unter:
- **http://localhost:9080** (lokal)
- **http://[servername]:9080** (netzwerkweit)
- **http://[servername.domain.com]:9080** (FQDN)

### **API-Endpunkte:**
- `GET /api/certificates` - Zertifikatsdaten als JSON
- `GET /api/health` - Service-Gesundheitsstatus
- `GET /` - HTML-Dashboard

## 📁 VERZEICHNISSTRUKTUR  

```
C:\CertWebService\
├── Setup.ps1                    # Installation
├── CertWebService.ps1           # Web-Service  
├── ScanCertificates.ps1         # Scan-Logic
├── Config\                      # Konfiguration
│   └── Config-CertWebService.json
├── Scripts\                     # Hilfsskripte
│   ├── Get-CertWebServicePaths.ps1
│   └── Manage-CertWebService-Tasks.ps1
├── Data\                        # Zertifikatsdaten
├── Reports\                     # HTML-Reports
└── Logs\                        # Log-Dateien
```

## ⚙️ KONFIGURATION

**Zentrale Konfiguration:** `Config\Config-CertWebService.json`

```json
{
  "WebService": {
    "Port": 9080,
    "AllowedHosts": ["localhost", "*"]
  },
  "Paths": {
    "Base": "C:\\CertWebService",
    "Data": "C:\\CertWebService\\Data",
    "Reports": "C:\\CertWebService\\Reports", 
    "Logs": "C:\\CertWebService\\Logs"
  }
}
```

## 🔧 TROUBLESHOOTING

### **Tasks werden nicht ausgeführt:**
```powershell
# Logs prüfen
Get-Content "C:\CertWebService\Logs\*.log" | Select-Object -Last 50

# Task-Events prüfen  
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-TaskScheduler/Operational'}
```

### **Web-Service nicht erreichbar:**
```powershell
# Port-Status prüfen
netstat -an | findstr :9080

# Firewall prüfen
Test-NetConnection -ComputerName localhost -Port 9080
```

### **Berechtigung-Probleme:**
```powershell
# Als Administrator neu installieren
.\Setup.ps1
```

## 📞 SUPPORT

Bei Problemen:
1. **Status prüfen:** `.\Scripts\Manage-CertWebService-Tasks.ps1 -Action Status`
2. **Logs auswerten:** `C:\CertWebService\Logs\`
3. **Neuinstallation:** `.\Setup.ps1` (als Administrator)

---
**© 2025 CertWebService v1.1.0 | Regelwerk Universal v10.0.2**