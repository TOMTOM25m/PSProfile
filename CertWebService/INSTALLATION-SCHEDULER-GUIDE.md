# CertWebService - Installation & Scheduler Setup

## 🎯 Quick Start

### Option 1: Vollständige Installation (EMPFOHLEN)

```powershell
# Als Administrator PowerShell öffnen
cd F:\DEV\repositories\CertWebService
.\Install-CertWebService.ps1
```

**Was wird installiert:**

- ✅ Verzeichnis-Struktur (C:\CertWebService)
- ✅ Scripts (CertWebService.ps1, ScanCertificates.ps1, etc.)
- ✅ Konfiguration (Config\Config-CertWebService.json)
- ✅ Firewall-Regel (Port 9080)
- ✅ URL ACL Reservierung
- ✅ Scheduled Tasks (Web Server + Daily Scan)

---

### Option 2: Nur Scheduler einrichten

```powershell
# Wenn bereits installiert, nur Tasks neu erstellen
cd C:\CertWebService
.\Setup-CertWebService-Scheduler.ps1
```

---

## 📦 Neue konsolidierte Scripts

| Script | Beschreibung | Größe |
|--------|-------------|-------|
| **Install-CertWebService.ps1** | Konsolidiertes Installations-Script | ~22 KB |
| **Setup-CertWebService-Scheduler.ps1** | Dediziertes Scheduler-Setup | ~19 KB |
| **CertWebService.ps1** | HTTP Web Service (v2.6.0) | ~18 KB |

---

## 🚀 Scheduled Tasks

### 1️⃣ CertWebService-WebServer

**Funktion:** Startet HTTP Web Service dauerhaft

**Trigger:** Bei System-Start (At Startup)

**Details:**

- User: SYSTEM
- RunLevel: Highest
- StartWhenAvailable: Yes
- DontStopOnIdleEnd: Yes
- RestartCount: 3 (bei Crash)
- ExecutionTimeLimit: Unlimited

**Manuell starten:**

```powershell
Start-ScheduledTask -TaskName "CertWebService-WebServer"
```

**Status prüfen:**

```powershell
Get-ScheduledTask -TaskName "CertWebService-WebServer" | Get-ScheduledTaskInfo
```

---

### 2️⃣ CertWebService-DailyScan

**Funktion:** Täglicher Zertifikats-Scan

**Trigger:** Täglich um 06:00 Uhr

**Details:**

- User: SYSTEM
- RunLevel: Highest
- StartWhenAvailable: Yes
- ExecutionTimeLimit: 1 hour

**Manuell starten:**

```powershell
Start-ScheduledTask -TaskName "CertWebService-DailyScan"
```

**Scan-Zeit ändern:**

```powershell
.\Setup-CertWebService-Scheduler.ps1 -ScanTime "03:00"
```

---

## 🔧 Installation Modi

### Full Mode (Standard)

```powershell
.\Install-CertWebService.ps1 -Mode Full
```

**Führt durch:**

1. Verzeichnis-Struktur erstellen
2. Dateien kopieren (mit Backup)
3. Konfiguration erstellen
4. Firewall-Regel einrichten
5. URL ACL reservieren
6. Scheduled Tasks erstellen

---

### Update Mode

```powershell
.\Install-CertWebService.ps1 -Mode Update
```

**Aktualisiert nur:**

- Scripts (CertWebService.ps1, etc.)
- Konfiguration

**Lässt unverändert:**

- Scheduled Tasks
- Firewall
- URL ACL

---

### Repair Mode

```powershell
.\Install-CertWebService.ps1 -Mode Repair
```

**Repariert:**

- Alle Komponenten neu erstellen
- Bestehende Backups werden erstellt

---

### Remove Mode

```powershell
.\Install-CertWebService.ps1 -Mode Remove
```

**Entfernt:**

- ✅ Alle Scheduled Tasks (gestoppt & gelöscht)
- ✅ Firewall-Regel
- ✅ URL ACL
- ❓ Installations-Verzeichnis (fragt nach)

---

## 📝 Logging

### Installations-Log

```
F:\DEV\repositories\CertWebService\Install-CertWebService_YYYY-MM-DD_HH-mm-ss.log
```

### Scheduler-Setup Log

```
C:\CertWebService\Logs\Scheduler-Setup_YYYY-MM-DD.log
```

### Web Service Log

```
C:\CertWebService\Logs\CertWebService_YYYY-MM-DD.log
```

**Log-Level:**

- `[INFO]` - Informationen
- `[SUCCESS]` - Erfolgreiche Aktionen
- `[WARNING]` - Warnungen
- `[ERROR]` - Fehler
- `[FATAL]` - Kritische Fehler

---

## 🌐 Web Service

### Dashboard

```
http://localhost:9080
http://SERVERNAME:9080
```

### API Endpoints

```powershell
# Alle Zertifikate
Invoke-RestMethod -Uri "http://localhost:9080/certificates.json"

# Health Check
Invoke-RestMethod -Uri "http://localhost:9080/health.json"
```

---

## 🛠️ Troubleshooting

### Problem: Task startet nicht

**Diagnose:**

```powershell
Get-ScheduledTask -TaskName "CertWebService*" | Format-List *
Get-ScheduledTaskInfo -TaskName "CertWebService-WebServer"
```

**Lösung:**

```powershell
# Task neu erstellen
.\Setup-CertWebService-Scheduler.ps1 -RemoveOnly
.\Setup-CertWebService-Scheduler.ps1
```

---

### Problem: Port bereits belegt

**Diagnose:**

```powershell
netstat -ano | findstr :9080
```

**Lösung:**

```powershell
# Anderen Port verwenden
.\Install-CertWebService.ps1 -WebServicePort 9090
```

---

### Problem: Firewall blockiert Zugriff

**Diagnose:**

```powershell
Get-NetFirewallRule -Name "CertWebService*" | Format-List *
Test-NetConnection -ComputerName localhost -Port 9080
```

**Lösung:**

```powershell
# Firewall-Regel neu erstellen
Remove-NetFirewallRule -Name "CertWebService-HTTP-9080"
.\Install-CertWebService.ps1 -Mode Repair
```

---

### Problem: URL ACL fehlt

**Diagnose:**

```powershell
netsh http show urlacl url=http://+:9080/
```

**Lösung:**

```powershell
# URL ACL neu reservieren
netsh http delete urlacl url=http://+:9080/
netsh http add urlacl url=http://+:9080/ user="NT AUTHORITY\SYSTEM"
```

---

## 📊 Task Management Befehle

### Tasks auflisten

```powershell
Get-ScheduledTask -TaskName "CertWebService*"
```

### Task starten

```powershell
Start-ScheduledTask -TaskName "CertWebService-WebServer"
```

### Task stoppen

```powershell
Stop-ScheduledTask -TaskName "CertWebService-WebServer"
```

### Task deaktivieren

```powershell
Disable-ScheduledTask -TaskName "CertWebService-WebServer"
```

### Task aktivieren

```powershell
Enable-ScheduledTask -TaskName "CertWebService-WebServer"
```

### Task-Info anzeigen

```powershell
Get-ScheduledTaskInfo -TaskName "CertWebService-WebServer"
```

### Task-Historie

```powershell
Get-WinEvent -FilterHashtable @{
    LogName = 'Microsoft-Windows-TaskScheduler/Operational'
    ID = 100, 102, 106, 107, 110, 111
} | Where-Object { $_.Message -match "CertWebService" } | Select-Object TimeCreated, Id, Message
```

---

## ✅ Compliance - Regelwerk v10.0.3

| Regelwerk | Implementierung |
|-----------|----------------|
| **§5** - Enterprise Logging | ✅ Tages-Rotation, UTF8, parallele File+Console-Ausgabe |
| **§14** - Credential-Strategie | ✅ SYSTEM Account für Scheduled Tasks |
| **§19** - Version Detection | ✅ PowerShell >= 5.1 erforderlich |
| **Encoding** | ✅ UTF8 für Logs, ASCII-kompatible Scripts |
| **Error Handling** | ✅ Try/Catch, strukturiertes Error-Logging |
| **Security** | ✅ Firewall, URL ACL, SYSTEM-Level Execution |

---

## 🎯 Beispiel-Workflow

### 1. Erstinstallation auf neuem Server

```powershell
# 1. Als Administrator PowerShell öffnen
# 2. Zum Source-Verzeichnis wechseln
cd F:\DEV\repositories\CertWebService

# 3. Vollständige Installation
.\Install-CertWebService.ps1

# 4. Browser öffnen
Start-Process "http://localhost:9080"

# 5. Tasks prüfen
Get-ScheduledTask -TaskName "CertWebService*"
```

---

### 2. Update bestehender Installation

```powershell
# Nur Scripts aktualisieren (ohne Tasks neu zu erstellen)
cd F:\DEV\repositories\CertWebService
.\Install-CertWebService.ps1 -Mode Update

# Tasks neu starten
Restart-ScheduledTask -TaskName "CertWebService-WebServer"
```

---

### 3. Scheduler reparieren

```powershell
# Alte Tasks entfernen
cd C:\CertWebService
.\Setup-CertWebService-Scheduler.ps1 -RemoveOnly

# Neue Tasks erstellen
.\Setup-CertWebService-Scheduler.ps1
```

---

### 4. Deinstallation

```powershell
cd F:\DEV\repositories\CertWebService
.\Install-CertWebService.ps1 -Mode Remove
```

---

## 📞 Support

**Log-Dateien prüfen:**

```powershell
# Installations-Log
Get-Content ".\Install-CertWebService_*.log" -Tail 50

# Scheduler-Log
Get-Content "C:\CertWebService\Logs\Scheduler-Setup_*.log" -Tail 50

# Web Service Log
Get-Content "C:\CertWebService\Logs\CertWebService_*.log" -Tail 50
```

**Task-Status prüfen:**

```powershell
Get-ScheduledTask -TaskName "CertWebService*" | Get-ScheduledTaskInfo
```

**Service-Test:**

```powershell
Test-NetConnection -ComputerName localhost -Port 9080
Invoke-RestMethod -Uri "http://localhost:9080/health.json"
```

---

**Version:** v1.0.0  
**Datum:** 2025-10-08  
**Author:** Flecki (Tom) Garnreiter  
**Regelwerk:** v10.0.3

---

## 🎉 Ready to Use

Die Scripts sind produktionsbereit und auf ASCII-Encoding optimiert.

**Start:**

```powershell
.\Install-CertWebService.ps1
```

**Viel Erfolg! 🚀**
