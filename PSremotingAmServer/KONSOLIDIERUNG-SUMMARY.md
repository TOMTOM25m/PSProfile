# PSRemoting Installation - Konsolidierung v1.0.0

## 🎯 Zusammenfassung

Alle PSRemoting-Installations-Funktionen wurden in **einem einzigen, benutzerfreundlichen Script** konsolidiert.

---

## 📦 Das neue Hauptscript

### **`Install-PSRemoting.ps1`** (22.4 KB)

**Enthaltene Funktionen:**

| Komponente | Beschreibung |
|------------|-------------|
| ✅ **Pre-Installation Tests** | Prüft PowerShell Version, Admin-Rechte, WinRM Service, Netzwerk |
| ✅ **PSRemoting Konfiguration** | Enable-PSRemoting, WinRM Service, TrustedHosts, Firewall, Listener |
| ✅ **Status & Compliance** | Zeigt vollständigen Status und prüft Regelkonformität |
| ✅ **Interaktives Menü** | Benutzerfreundliche Menü-Navigation |
| ✅ **Logging** | Tages-Rotation, UTF8, parallele File/Console-Ausgabe |

---

## 🚀 Verwendung

### 1️⃣ Interaktiver Modus (EMPFOHLEN)

```powershell
cd "\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer"
.\Install-PSRemoting.ps1
```

**Menü-Optionen:**

```
[1] PRE-INSTALLATION TESTS
    Prüft alle Voraussetzungen

[2] PSREMOTING INSTALLIEREN
    Führt vollständige Konfiguration durch

[3] STATUS ANZEIGEN
    Zeigt aktuellen Status und Compliance

[4] LOG-DATEI ÖFFNEN
    Öffnet heutige Log-Datei

[0] BEENDEN
```

---

### 2️⃣ Automatischer Modus

```powershell
.\Install-PSRemoting.ps1 -Mode Auto
```

**Keine Benutzerinteraktion erforderlich** - perfekt für:

- Automatisierte Deployments
- Remote-Installation via Invoke-Command
- Unattended Installation

---

### 3️⃣ Status-Only Modus

```powershell
.\Install-PSRemoting.ps1 -Mode Status
```

**Nur Anzeige** - führt keine Änderungen durch:

- WinRM Service Status
- TrustedHosts Konfiguration
- Firewall-Regeln
- Listener
- Compliance-Check

---

## 🎨 Features

### ✅ Pre-Installation Tests

Automatische Prüfung vor Installation:

- ✅ PowerShell Version >= 5.1
- ✅ Administrator-Rechte vorhanden
- ✅ WinRM Service Status
- ✅ Netzwerk-Konnektivität zu Management-Servern

**Beispiel-Output:**

```
[TEST 1] PowerShell Version...
  Version: 5.1
  [SUCCESS] PowerShell Version OK: 5.1.19041.4894

[TEST 2] Administrator-Rechte...
  [SUCCESS] Administrator-Rechte: OK

[TEST 3] WinRM Service...
  Status: Running
  StartType: Automatic

[TEST 4] Netzwerk-Konnektivitaet...
  [SUCCESS] Ping erfolgreich: ITSC020.cc.meduniwien.ac.at
  [SUCCESS] Ping erfolgreich: itscmgmt03.srv.meduniwien.ac.at
```

---

### ✅ PSRemoting Konfiguration

5-Schritte-Prozess:

```
[SCHRITT 1] Enable-PSRemoting
[SCHRITT 2] WinRM Service Autostart
[SCHRITT 3] TrustedHosts Whitelist
[SCHRITT 4] Firewall-Regeln
[SCHRITT 5] HTTP Listener
```

**Whitelist-Konfiguration:**

- `ITSC020.cc.meduniwien.ac.at`
- `itscmgmt03.srv.meduniwien.ac.at`

**Firewall:**

- Port 5985 (HTTP) - **ENABLED**
- Port 5986 (HTTPS) - Optional

---

### ✅ Status & Compliance Check

Vollständige Status-Anzeige:

```
[1] WINRM SERVICE
  Status: Running
  StartType: Automatic

[2] TRUSTEDHOSTS
  [OK] ITSC020.cc.meduniwien.ac.at
  [OK] itscmgmt03.srv.meduniwien.ac.at

[3] FIREWALL RULES
  HTTP (Port 5985): ENABLED
  HTTPS (Port 5986): NOT CONFIGURED

[4] LISTENERS
  Transport: HTTP | Port: 5985 | Address: *

[5] COMPLIANCE CHECK
  WinRM : OK
  TrustedHosts : OK
  Firewall : OK
  Listener : OK

[SUCCESS] PSRemoting vollständig konfiguriert!
```

---

### ✅ Logging

**Log-Datei:** `.\Logs\PSRemoting-Install_YYYY-MM-DD.log`

**Log-Level:**

- `[INFO]` - Allgemeine Informationen
- `[SUCCESS]` - Erfolgreiche Aktionen
- `[WARNING]` - Warnungen
- `[ERROR]` - Fehler

**Beispiel:**

```
[2025-10-07 15:49:44] [INFO] === INSTALLATION GESTARTET ===
[2025-10-07 15:49:44] [INFO] Hostname: EVAEXTEST01
[2025-10-07 15:49:44] [INFO] User: Administrator
[2025-10-07 15:49:45] [SUCCESS] PowerShell Version OK: 5.1.19041.4894
[2025-10-07 15:49:45] [SUCCESS] Administrator-Rechte: OK
[2025-10-07 15:49:46] [SUCCESS] Enable-PSRemoting erfolgreich
[2025-10-07 15:49:47] [SUCCESS] TrustedHosts Whitelist gesetzt
[2025-10-07 15:49:48] [SUCCESS] Firewall-Regel aktiviert: HTTP (Port 5985)
[2025-10-07 15:49:49] [SUCCESS] === INSTALLATION ABGESCHLOSSEN ===
```

---

## 🔧 Management-Server Workflow (ITSC020)

### Kompletter Workflow für Remote-Verwaltung

#### 1. Server zu TrustedHosts hinzufügen

```powershell
.\Add-ServerToTrustedHosts.ps1 -ComputerName "EVAEXTEST01.srv.meduniwien.ac.at"
```

#### 2. Verbindung testen

```powershell
Test-WSMan -ComputerName "EVAEXTEST01.srv.meduniwien.ac.at"
```

#### 3. Remote-Session starten

```powershell
Enter-PSSession -ComputerName "EVAEXTEST01.srv.meduniwien.ac.at"
```

#### 4. PSRemoting remote installieren

```powershell
Invoke-Command -ComputerName "EVAEXTEST01.srv.meduniwien.ac.at" -ScriptBlock {
    & "\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer\Install-PSRemoting.ps1" -Mode Auto
}
```

---

## 📂 Netzwerk-Share Struktur

### Deployment-Pfad

```
\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer
```

### Dateien

| Kategorie | Datei | Größe | Beschreibung |
|-----------|-------|-------|-------------|
| **🎯 HAUPTSCRIPT** | `Install-PSRemoting.ps1` | 22.4 KB | Konsolidiertes Installations-Script |
| **🛠️ MANAGEMENT** | `Add-ServerToTrustedHosts.ps1` | 6.7 KB | TrustedHosts Management für ITSC020 |
| **📚 DOKUMENTATION** | `QUICK-START.md` | 4.7 KB | Schnellstart-Anleitung |
| **📚 DOKUMENTATION** | `START-KONSOLIDIERT.txt` | 4.2 KB | Übersicht konsolidiertes Script |
| **📚 DOKUMENTATION** | `MANAGEMENT-SERVER-GUIDE.md` | 8.2 KB | Vollständige ITSC020-Anleitung |
| **📚 DOKUMENTATION** | `README.md` | 11.8 KB | Technische Dokumentation |
| **🔧 LEGACY** | `Configure-PSRemoting.ps1` | 18.7 KB | Original-Script (optional) |
| **🔧 LEGACY** | `Show-PSRemotingWhitelist.ps1` | 8.4 KB | Status-Script (optional) |

---

## ✅ Vorteile der Konsolidierung

| Vorher | Nachher |
|--------|---------|
| ❌ 3+ separate Scripts | ✅ **1 Hauptscript** |
| ❌ Manuelle Pre-Tests | ✅ **Automatische Pre-Tests** |
| ❌ Keine Menü-Navigation | ✅ **Interaktives Menü** |
| ❌ Status separat prüfen | ✅ **Integrierter Status** |
| ❌ Log-Datei manuell öffnen | ✅ **Menü-Option [4]** |
| ❌ Komplexe Bedienung | ✅ **3 einfache Modi** |

---

## 🎯 Use Cases

### Use Case 1: Neuer Server

```powershell
# Auf neuem Server (z.B. EVAEXTEST01)
cd "\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer"
.\Install-PSRemoting.ps1
# => Menü Option [2] wählen
```

### Use Case 2: Status prüfen

```powershell
# Auf beliebigem Server
.\Install-PSRemoting.ps1 -Mode Status
```

### Use Case 3: Remote-Installation

```powershell
# Von ITSC020 aus
Invoke-Command -ComputerName "SERVER.srv.meduniwien.ac.at" -ScriptBlock {
    & "\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer\Install-PSRemoting.ps1" -Mode Auto
}
```

### Use Case 4: Batch-Installation

```powershell
# Mehrere Server auf einmal
$servers = @(
    "EVAEXTEST01.srv.meduniwien.ac.at",
    "EX01.uvw.meduniwien.ac.at",
    "proman.ad.meduniwien.ac.at"
)

foreach ($server in $servers) {
    .\Add-ServerToTrustedHosts.ps1 -ComputerName $server
    Invoke-Command -ComputerName $server -ScriptBlock {
        & "\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer\Install-PSRemoting.ps1" -Mode Auto
    }
}
```

---

## 🛡️ Compliance - Regelwerk v10.0.3

| Regelwerk | Implementierung |
|-----------|----------------|
| **§5** - Enterprise Logging | ✅ Tages-Rotation, UTF8, File+Console |
| **§14** - Credential-Strategie | ✅ 3-Stufen: Get-Credential, Env, Manual |
| **§19** - Version Detection | ✅ PSVersionTable.PSVersion >= 5.1 |
| **Whitelist** | ✅ ITSC020 + itscmgmt03 |
| **FQDN** | ✅ Vollqualifizierte Domain-Namen |
| **Error Handling** | ✅ Try/Catch, Error-Level Logging |

---

## 🚨 Troubleshooting

### Problem: "Execution of scripts is disabled"

**Lösung:**

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```

### Problem: "Access is denied"

**Lösung:**  
➡️ PowerShell als Administrator ausführen!

### Problem: "WinRM client cannot process the request"

**Lösung:**

```powershell
.\Add-ServerToTrustedHosts.ps1 -ComputerName "SERVER.srv.meduniwien.ac.at"
```

### Problem: Firewall blockiert Port 5985

**Diagnose:**

```powershell
Test-NetConnection -ComputerName "SERVER.srv.meduniwien.ac.at" -Port 5985
```

**Lösung:**  
➡️ Script führt Firewall-Konfiguration automatisch durch

---

## 📞 Weitere Hilfe

**Dokumentation:**

- `QUICK-START.md` - Schnellstart
- `START-KONSOLIDIERT.txt` - Übersicht
- `MANAGEMENT-SERVER-GUIDE.md` - Vollständige Anleitung
- `README.md` - Technische Details

**Log-Datei prüfen:**

```powershell
Get-Content ".\Logs\PSRemoting-Install_$(Get-Date -Format 'yyyy-MM-dd').log"
```

**Status anzeigen:**

```powershell
.\Install-PSRemoting.ps1 -Mode Status
```

---

## 📊 Statistiken

- **Konsolidierte Scripts:** 3 → 1
- **Zeilen Code:** ~1100 (bereinigt)
- **Funktionen:** 15
- **Modi:** 3 (Interactive/Auto/Status)
- **Log-Level:** 4 (INFO/SUCCESS/WARNING/ERROR)
- **Pre-Tests:** 4
- **Konfigurations-Schritte:** 5
- **Compliance-Checks:** 4

---

## 📅 Versionshistorie

### v1.0.0 - 2025-10-07

- ✅ Konsolidierung aller Scripts in `Install-PSRemoting.ps1`
- ✅ Interaktives Menü implementiert
- ✅ Pre-Installation Tests integriert
- ✅ Status & Compliance Check integriert
- ✅ 3 Modi (Interactive/Auto/Status)
- ✅ Enterprise Logging (Tages-Rotation)
- ✅ Deployed auf Netzwerk-Share

---

**Author:** Flecki (Tom) Garnreiter  
**Version:** v1.0.0  
**Datum:** 2025-10-07  
**Regelwerk:** v10.0.3  
**Network Share:** `\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer`

---

## 🎉 Ready to Use

Das konsolidierte Script ist **produktionsbereit** und auf dem Netzwerk-Share deployed.

**Start:**

```powershell
cd "\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer"
.\Install-PSRemoting.ps1
```

**Viel Erfolg! 🚀**
