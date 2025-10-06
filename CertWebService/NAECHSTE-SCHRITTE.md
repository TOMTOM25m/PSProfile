# CertWebService Update - Nächste Schritte

## ✅ Was Sie jetzt haben

Sie haben ein vollständiges **Hybrid Mass Update System** für CertWebService mit:

1. **Update-Launcher.ps1** - Hauptsteuerung für alle Updates
2. **Update-AllServers-Hybrid.ps1** - Intelligente Deployment-Engine  
3. **Server-Configuration.ps1** - Zentrale Server-Verwaltung
4. **Deploy-NetworkPackage.ps1** - Deployment-Package-Erstellung

## 🎯 Sofortiger nächster Schritt

### 1. Server-Liste anpassen

**WICHTIG:** Öffnen Sie `Server-Configuration.ps1` und ersetzen Sie die Beispiel-Server durch Ihre echten Server:

```powershell
$Global:CertWebServiceServers = @{
    Production = @(
        # IHRE ECHTEN SERVER HIER:
        "server01.meduniwien.ac.at",
        "webserver01.meduniwien.ac.at",
        "webserver02.meduniwien.ac.at"
    )
    
    Testing = @(
        # IHRE TEST-SERVER HIER:
        "testserver01.meduniwien.ac.at"
    )
}
```

### 2. Erstes Deployment-Package erstellen

```powershell
# Als Administrator in PowerShell:
cd "f:\DEV\repositories\CertWebService"
.\Deploy-NetworkPackage.ps1
```

Das erstellt das Update-Package im Netzwerk-Share: `\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService`

### 3. Connectivity testen

```powershell
# Test welche Server wie erreichbar sind:
.\Update-Launcher.ps1 -ServerGroup Testing -TestConnectivityOnly
```

### 4. Ersten Test-Update durchführen

```powershell
# Simulation (keine Änderungen):
.\Update-Launcher.ps1 -ServerGroup Testing -DryRun

# Echter Update der Test-Server:
.\Update-Launcher.ps1 -ServerGroup Testing
```

## 🔧 Was das System automatisch macht

### Für jeden Server wird automatisch erkannt

| Situation | Aktion |
|-----------|--------|
| ✅ **PSRemoting funktioniert** | Vollautomatische Installation über PowerShell Remoting |
| 🌐 **Nur Samba-Zugriff** | Kopiert Dateien über SMB, führt Installation remote aus |
| 📦 **Kein Remote-Zugriff** | Erstellt lokale Installation-Packages für manuelle Ausführung |
| ❌ **Server nicht erreichbar** | Überspringt mit Fehlermeldung |

## 📊 Was Sie als Ausgabe bekommen

Nach dem Update erhalten Sie:

1. **Deployment-Summary** - Übersicht über erfolgreiche/fehlgeschlagene Updates
2. **Method-Report** - Welche Deployment-Methode für welchen Server verwendet wurde
3. **Manual-Packages** - Fertige Installation-Packages für Server die manuelle Installation brauchen
4. **JSON-Report** - Detaillierte Ergebnisse für weitere Verarbeitung

## 🚀 Empfohlener Workflow

### Phase 1: Test-Umgebung

```powershell
# 1. Test-Server updaten
.\Update-Launcher.ps1 -ServerGroup Testing

# 2. Validierung
# Browser: http://testserver:9080/health.json
```

### Phase 2: Produktions-Umgebung  

```powershell
# 3. Produktions-Server updaten (mit Bestätigung)
.\Update-Launcher.ps1 -ServerGroup Production

# 4. Manuelle Installation wo nötig
# (Packages werden in C:\Temp\ erstellt)
```

## 🔄 Typische Szenarien

### Szenario 1: PSRemoting funktioniert teilweise

- ✅ Server mit PSRemoting werden vollautomatisch aktualisiert
- 🌐 Server ohne PSRemoting bekommen Network-Deployment  
- 📦 Problematische Server bekommen manuelle Packages

### Szenario 2: Nur Samba-Zugriff verfügbar

- 🌐 Alle Server werden über SMB/Network-Deployment aktualisiert
- 📦 Bei Problemen fallen wir auf manuelle Packages zurück

### Szenario 3: Kompletter manueller Modus

- 📦 Für alle Server werden Installation-Packages erstellt
- Sie können diese dann individuell auf den Servern ausführen

## ⚠️ Wichtige Hinweise

1. **Administrator-Rechte erforderlich** - Sowohl lokal als auch auf den Ziel-Servern
2. **Netzwerk-Share muss verfügbar sein** - `\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService`
3. **Server-Namen anpassen** - Unbedingt in `Server-Configuration.ps1` aktualisieren
4. **Testen vor Produktion** - Immer erst Test-Server, dann Produktion

## 🎯 Ihr nächster Schritt JETZT

**Öffnen Sie `Server-Configuration.ps1` und tragen Sie Ihre echten Server-Namen ein!**

Danach können Sie sofort mit dem ersten Test beginnen:

```powershell
.\Update-Launcher.ps1 -ServerGroup Testing -TestConnectivityOnly
```

Das System ist bereit! 🚀
