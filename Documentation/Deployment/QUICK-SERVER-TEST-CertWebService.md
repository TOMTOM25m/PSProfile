# 🚀 CertWebService v1.1.0 - Quick Server Test

**ZIP-Package:** `CertWebService_v1.1.0_ScheduledTask_2025-10-02-1201.zip` (55 KB)  
**Datum:** 02.10.2025  
**Architektur:** Scheduled Tasks (kein Windows Service)

## ⚡ SCHNELL-INSTALLATION

### 1. **ZIP auf Server kopieren**
```
CertWebService_v1.1.0_ScheduledTask_2025-10-02-1201.zip
```

### 2. **ZIP entpacken** 
```powershell
# Rechtsklick → "Alle extrahieren" ODER:
Expand-Archive -Path "CertWebService_v1.1.0_ScheduledTask_2025-10-02-1201.zip" -DestinationPath "."
```

### 3. **Als Administrator installieren**
```powershell
# PowerShell als Administrator öffnen
cd "CertWebService_v1.1.0_ScheduledTask_2025-10-02-1201"
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
.\Setup.ps1
```

### 4. **Installation prüfen**
```powershell
.\Scripts\Manage-CertWebService-Tasks.ps1 -Action Status
```

## 🌐 NACH INSTALLATION TESTEN

### **Web-Dashboard öffnen:**
- **Lokal:** http://localhost:9080
- **Netzwerk:** http://[SERVERNAME]:9080  
- **FQDN:** http://[SERVERNAME.DOMAIN.COM]:9080

### **API-Tests:**
```powershell
# Dashboard
Invoke-WebRequest "http://localhost:9080/"

# Zertifikatsdaten (JSON)
Invoke-WebRequest "http://localhost:9080/api/certificates"
```

## 🔧 SYSTEM-ARCHITEKTUR

### **Zwei Scheduled Tasks:**
1. **CertWebService-WebServer** → Läuft dauerhaft (Web-Dashboard)
2. **CertWebService-DailyScan** → Täglich um 06:00 (Zertifikatsscan)

### **Management:**
```powershell
# Status anzeigen
.\Scripts\Manage-CertWebService-Tasks.ps1 -Action Status

# Tasks starten/stoppen
.\Scripts\Manage-CertWebService-Tasks.ps1 -Action [Start|Stop|Restart]
```

## ✅ EXPECTED RESULTS

### **Nach Setup.ps1:**
```
✅ Verzeichnis C:\CertWebService erstellt
✅ Konfigurationsdateien kopiert  
✅ Scheduled Task "CertWebService-WebServer" erstellt (Running)
✅ Scheduled Task "CertWebService-DailyScan" erstellt (Ready, Next: 06:00)
✅ Installation erfolgreich
```

### **Nach Status-Check:**
```
Web-Service (dauerhaft): Running
Daily Scan (06:00 täglich): Ready, Next Run: [MORGEN] 06:00:00
Web-Service erreichbar (Port 9080): ✅
```

### **Dashboard sollte zeigen:**
- CertWebService Dashboard
- System-Status
- Letzte Scans
- Zertifikats-Übersicht

## 🆘 TROUBLESHOOTING

### **Tasks laufen nicht:**
```powershell
# Neustart versuchen
.\Scripts\Manage-CertWebService-Tasks.ps1 -Action Restart

# Manuelle Erstellung
.\Setup.ps1
```

### **Port 9080 nicht erreichbar:**
```powershell
# Port prüfen
netstat -an | findstr :9080

# Firewall-Test
Test-NetConnection -ComputerName localhost -Port 9080
```

### **Berechtigung-Probleme:**
```powershell
# PowerShell als Administrator neu starten
# Setup erneut ausführen
.\Setup.ps1
```

---

## 📞 SUPPORT-INFO

**Bei Problemen Logs senden:**
- `C:\CertWebService\Logs\*.log`
- Output von: `.\Scripts\Manage-CertWebService-Tasks.ps1 -Action Status`
- Output von: `Get-ScheduledTask -TaskName "CertWebService-*"`

**Erfolgreiche Installation = Web-Dashboard erreichbar unter http://[server]:9080** ✅

---
*CertWebService v1.1.0 | Scheduled Task Architecture | 02.10.2025*