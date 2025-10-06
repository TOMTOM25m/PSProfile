# 🎯 Excel-Based CertWebService Mass Update - Komplettanleitung

## ✅ Was Sie jetzt haben

Sie haben ein **vollständiges Excel-basiertes Mass Update System** erstellt, das:

1. **Ihre existierende `Serverliste2025.xlsx` einliest**
2. **Domain/Workgroup-Struktur erkennt** (wie Sie sie bereits verwenden)
3. **Automatisch prüft welche Server bereits CertWebService haben**
4. **Intelligent entscheidet: Installation vs. Update**
5. **Bulk-Deployment mit verschiedenen Methoden durchführt**

## 📁 Neue Dateien im System

| Datei | Zweck |
|-------|-------|
| `Excel-Update-Launcher.ps1` | **HAUPTLAUNCHER** - Steuert alle Excel-basierten Updates |
| `Update-FromExcel-MassUpdate.ps1` | Excel-Import + Intelligente Server-Analyse |  
| `Update-AllServers-Hybrid.ps1` | Hybrid-Deployment-Engine (bereits vorhanden) |
| `Server-Configuration.ps1` | Server-Konfiguration (bereits vorhanden) |

## 🚀 Sofort loslegen - 4 einfache Modi

### 1. **ANALYSE** (Empfohlener Start)

```powershell
# Analysiert alle Server aus Excel, keine Änderungen
.\Excel-Update-Launcher.ps1 -Mode Analyze
```

**Was passiert:**

- ✅ Liest `Serverliste2025.xlsx` mit Domain/Workgroup-Erkennung
- ✅ Prüft welche Server bereits CertWebService haben
- ✅ Testet PSRemoting/SMB/WMI-Connectivity
- ✅ Kategorisiert: Installation nötig vs. Update nötig
- ✅ Zeigt Deployment-Empfehlungen

### 2. **CONNECTIVITY TEST**

```powershell
# Testet nur Verbindungen, keine Änderungen
.\Excel-Update-Launcher.ps1 -Mode TestConnectivity
```

### 3. **DRY RUN** (Simulation)

```powershell
# Zeigt was gemacht würde, keine Änderungen
.\Excel-Update-Launcher.ps1 -Mode DryRun
```

### 4. **DEPLOYMENT** (Echte Ausführung)

```powershell
# Führt tatsächliche Installation/Updates durch
.\Excel-Update-Launcher.ps1 -Mode Deploy
```

## 🎛️ Erweiterte Filter-Optionen

### Domain-Server only

```powershell
.\Excel-Update-Launcher.ps1 -Mode Analyze -Filter Domain
```

### Spezifische Domain

```powershell
.\Excel-Update-Launcher.ps1 -Mode Analyze -Filter Domain -FilterValue "meduniwien"
```

### Workgroup-Server only

```powershell
.\Excel-Update-Launcher.ps1 -Mode Analyze -Filter Workgroup
```

### Test-Server only

```powershell
.\Excel-Update-Launcher.ps1 -Mode Analyze -Filter TestOnly
```

## 🔧 Was das System automatisch erkennt

### Aus Ihrer Excel-Datei

- **Domain-Blöcke:** `(Domain)meduniwien` → Server bekommen `.meduniwien.ac.at`
- **Workgroup-Blöcke:** `(Workgroup)srv` → Server werden als lokale Namen behandelt
- **Server-Namen:** Automatische Extraktion aus Spalte A
- **Block-Ende:** `SUMME:` beendet einen Block

### Server-Status

- **Hat CertWebService:** <http://server:9080/health.json> antwortet
- **Braucht CertWebService:** Kein CertWebService gefunden
- **Version-Info:** Automatische Versionserkennung falls vorhanden

### Deployment-Methoden

- **✅ PSRemoting:** Vollautomatische Installation/Update
- **🌐 Network Deployment:** SMB + WMI remote execution
- **📦 Manual Package:** Lokale Installation-Packages erstellen

## 📊 Typische Ausgabe nach Analyse

```
📊 SERVER INVENTORY ANALYSIS RESULTS
====================================

📈 Overall Statistics:
   Total Servers Analyzed: 45
   Analysis Completed: 45

🎯 CertWebService Status:
   ✅ Already Installed: 12    ← Diese werden UPDATED
   📦 Needs Installation: 28   ← Diese werden NEU INSTALLIERT  
   ❌ Unreachable: 5

🔧 Deployment Capabilities:
   🚀 PSRemoting Available: 15    ← Vollautomatisch
   🌐 Network Deployment: 20      ← SMB-basiert
   📋 Manual Required: 5          ← Manuelle Packages
```

## 🎯 Empfohlener Workflow

### Phase 1: Erkundung (5 Minuten)

```powershell
# 1. Vollständige Analyse aller Server
.\Excel-Update-Launcher.ps1 -Mode Analyze

# 2. Connectivity-Test für problematische Server
.\Excel-Update-Launcher.ps1 -Mode TestConnectivity -Filter Domain
```

### Phase 2: Test-Deployment (15 Minuten)  

```powershell
# 3. Dry Run für Test-Server
.\Excel-Update-Launcher.ps1 -Mode DryRun -Filter TestOnly

# 4. Echter Test-Deployment
.\Excel-Update-Launcher.ps1 -Mode Deploy -Filter TestOnly
```

### Phase 3: Bulk-Deployment (30-60 Minuten)

```powershell
# 5. Domain-Server deployen
.\Excel-Update-Launcher.ps1 -Mode Deploy -Filter Domain

# 6. Workgroup-Server deployen  
.\Excel-Update-Launcher.ps1 -Mode Deploy -Filter Workgroup
```

## 🔄 Was automatisch passiert

### Das System macht für jeden Server

1. **Excel-Import:** Liest Ihren Server mit korrekter Domain/Workgroup-Zuordnung
2. **CertWebService-Check:** `GET http://server:9080/health.json`
3. **Connectivity-Test:** Ping → SMB → PSRemoting → WMI
4. **Entscheidung:** Installation vs. Update
5. **Deployment:** Automatisch beste Methode wählen
6. **Integration:** Verwendet Ihr existierendes Hybrid-Update-System

### Bulk-Operationen

- **Server ohne CertWebService** → Komplette Neu-Installation
- **Server mit CertWebService** → Version-Update
- **PSRemoting verfügbar** → Vollautomatisch über PowerShell
- **Nur SMB verfügbar** → Network-Deployment über File-Copy + WMI
- **Keine Remote-Verbindung** → Manuelle Installation-Packages

## 📋 Ausgabe und Reports

Das System erstellt automatisch:

### Während der Ausführung

- **Real-time Status** für jeden Server
- **Deployment-Methode-Anzeige**
- **Erfolg/Fehler-Tracking**

### Nach Abschluss

- **Deployment-Summary** (Erfolg/Fehlgeschlagen)
- **Method-Report** (Welche Methode pro Server)
- **Manual-Packages** (in `C:\Temp\` für manuelle Installation)
- **JSON-Report** (Detailergebnisse)

## ⚡ Sofort testen

**Starten Sie JETZT mit einer Analyse:**

```powershell
cd "f:\DEV\repositories\CertWebService"
.\Excel-Update-Launcher.ps1 -Mode Analyze
```

Das dauert ca. 2-5 Minuten und zeigt Ihnen:

- Welche Server bereits CertWebService haben
- Welche Server Installation brauchen  
- Welche Deployment-Methoden verfügbar sind
- Genaue Deployment-Empfehlungen

**Keine Änderungen werden gemacht - nur Analysis!**

## 🎉 Das war's

Sie haben jetzt:
✅ **Excel-Integration** mit Ihrer existierenden Serverliste  
✅ **Automatische CertWebService-Erkennung**  
✅ **Intelligente Bulk-Installation/Updates**  
✅ **Multiple Deployment-Methoden**  
✅ **Vollständige Automatisierung** mit manueller Kontrolle

**Probieren Sie es aus - es ist bereit zu laufen!** 🚀
