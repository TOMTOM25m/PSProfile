# CertWebService Mass Update - Praktische Anleitung

## 🎯 Überblick

Sie haben jetzt ein vollständiges System für das Mass Update aller CertWebService-Installationen, das sich automatisch an verschiedene Verbindungstypen anpasst:

- **PSRemoting** (falls verfügbar)
- **Samba/SMB Network Deployment**
- **Manuelle Installation Packages**

## 📁 Verfügbare Dateien

| Datei | Beschreibung |
|-------|-------------|
| `Update-Launcher.ps1` | **Hauptskript** - Startet den gesamten Update-Prozess |
| `Update-AllServers-Hybrid.ps1` | Hybrid-Update-Engine mit mehreren Deployment-Methoden |
| `Server-Configuration.ps1` | Zentrale Server-Liste und Konfiguration |
| `Deploy-NetworkPackage.ps1` | Erstellt/aktualisiert das Deployment-Package |
| `Create-NetworkDeployment.ps1` | Alternative Package-Erstellung |

## 🚀 Quick Start

### 1. Erstelle das Deployment Package (einmalig)

```powershell
# Als Administrator ausführen
.\Deploy-NetworkPackage.ps1
```

### 2. Server-Liste anpassen

Bearbeiten Sie `Server-Configuration.ps1` und tragen Sie Ihre tatsächlichen Server ein:

```powershell
$Global:CertWebServiceServers = @{
    Production = @(
        "ihre-server-namen-hier.domain.local",
        "webserver01.ihr-domain.local",
        "webserver02.ihr-domain.local"
    )
    
    Testing = @(
        "testserver01.ihr-domain.local", 
        "devserver01.ihr-domain.local"
    )
}
```

### 3. Teste die Connectivity

```powershell
# Test-Modus - keine Änderungen
.\Update-Launcher.ps1 -ServerGroup Testing -TestConnectivityOnly
```

### 4. Dry Run (Simulation)

```powershell
# Simuliert den Update-Prozess ohne Änderungen
.\Update-Launcher.ps1 -ServerGroup Testing -DryRun
```

### 5. Echtes Update

```powershell
# Update der Test-Server
.\Update-Launcher.ps1 -ServerGroup Testing

# Update der Produktions-Server (mit Bestätigung)
.\Update-Launcher.ps1 -ServerGroup Production

# Spezifische Server
.\Update-Launcher.ps1 -ServerGroup Custom -CustomServers @("server1.domain.local", "server2.domain.local")
```

## 🔧 Was passiert automatisch

### Das System erkennt für jeden Server

1. **PSRemoting verfügbar?** → Direkte PowerShell-Installation
2. **Nur Samba/SMB?** → Kopiert Files auf Server, führt remote aus
3. **Keine Remote-Ausführung?** → Erstellt manuelle Installation-Packages

### Deployment-Methoden

| Methode | Beschreibung | Automatisierung |
|---------|-------------|-----------------|
| **PSRemoting** | Vollautomatisch über PowerShell Remoting | 100% automatisch |
| **Network Deployment** | Dateien über SMB kopieren, WMI remote execution | ~80% automatisch |
| **Manual Package** | Lokale Installation-Packages erstellen | Manuelle Ausführung nötig |

## 📊 Nach dem Update

Das System erstellt automatisch:

1. **Deployment-Summary** - Welche Server erfolgreich/fehlgeschlagen
2. **Method-Report** - Welche Deployment-Methode für welchen Server
3. **Manual-Packages** - Für Server die manuelle Installation brauchen
4. **Detailed JSON Report** - Vollständige Ergebnisse

## 🛠️ Troubleshooting

### Problem: "Network path not accessible"

**Lösung:**

```powershell
# Erstelle zuerst das Deployment Package
.\Deploy-NetworkPackage.ps1

# Oder prüfe Netzwerk-Zugriff
Test-Path "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService"
```

### Problem: "PSRemoting failed"

**Das ist normal!** Das System fällt automatisch auf Network-Deployment zurück.

### Problem: Server nicht erreichbar

```powershell
# Teste einzelnen Server
Test-Connection -ComputerName "server.domain.local" -Count 1
```

## 🔄 Typischer Workflow

### Phase 1: Vorbereitung

```powershell
# 1. Deployment Package erstellen/aktualisieren
.\Deploy-NetworkPackage.ps1

# 2. Server-Liste prüfen
.\Update-Launcher.ps1 -ServerGroup All -TestConnectivityOnly
```

### Phase 2: Test-Deployment

```powershell
# 3. Test-Server updaten
.\Update-Launcher.ps1 -ServerGroup Testing

# 4. Validierung der Test-Installationen
# Browser: http://testserver01:9080/
```

### Phase 3: Produktions-Deployment

```powershell
# 5. Produktions-Server updaten
.\Update-Launcher.ps1 -ServerGroup Production -GenerateReports

# 6. Manuelle Packages für problematische Server abarbeiten
# (werden automatisch in C:\Temp\ erstellt)
```

### Phase 4: Integration

```powershell
# 7. CertSurv-Konfiguration aktualisieren
# 8. End-to-End Test der Certificate Surveillance
```

## 🎯 Anpassung für Ihre Umgebung

### 1. Server-Namen aktualisieren

In `Server-Configuration.ps1`:

```powershell
$Global:CertWebServiceServers = @{
    Production = @(
        "ersetzen-sie-diese-namen.ihre-domain.local"
    )
}
```

### 2. Network Share anpassen

Falls Sie einen anderen Deployment-Share verwenden:

```powershell
$Global:NetworkConfiguration = @{
    DeploymentShare = "\\ihr-server\ihr-share\CertWebService"
}
```

### 3. Credentials

Das System fragt automatisch nach Administrator-Credentials, oder:

```powershell
$cred = Get-Credential
.\Update-Launcher.ps1 -ServerGroup Production -AdminCredential $cred
```

## 📈 Monitoring & Validierung

Nach dem Update können Sie die Installationen prüfen:

```powershell
# Einzelner Server
Invoke-WebRequest "http://servername:9080/health.json"

# Alle Server (PowerShell Loop)
$servers = Get-ServersByGroup -Group Production
foreach ($server in $servers) {
    try {
        $health = Invoke-WebRequest "http://$server:9080/health.json" -UseBasicParsing
        Write-Host "✅ $server - OK" -ForegroundColor Green
    } catch {
        Write-Host "❌ $server - Failed" -ForegroundColor Red
    }
}
```

## 🔗 Integration mit CertSurv

Nach erfolgreichem Update:

1. Aktualisieren Sie die Server-Liste in Ihrem CertSurv-System
2. Testen Sie die API-Konnektivität zu den neuen Endpoints
3. Führen Sie eine Test-Sammlung durch
4. Aktivieren Sie die reguläre Überwachung

Das war's! Das System ist jetzt bereit für das Mass Update Ihrer CertWebService-Installationen. 🎉
