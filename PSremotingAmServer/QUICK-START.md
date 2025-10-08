# PSRemoting Installation - Quick Start Guide

## 📦 Konsolidiertes Installations-Script

Alle Funktionen wurden in **einem einzigen Script** zusammengefasst:

```
Install-PSRemoting.ps1
```

---

## 🚀 Installation vom Netzlaufwerk

### Option 1: Interaktives Menü (EMPFOHLEN)

```powershell
# Als Administrator PowerShell öffnen
cd "\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer"
.\Install-PSRemoting.ps1
```

**Menü-Optionen:**

- `[1]` Pre-Installation Tests
- `[2]` PSRemoting installieren
- `[3]` Status anzeigen
- `[4]` Log-Datei öffnen
- `[0]` Beenden

---

### Option 2: Automatische Installation

```powershell
# Keine Benutzerinteraktion erforderlich
.\Install-PSRemoting.ps1 -Mode Auto
```

---

### Option 3: Nur Status anzeigen

```powershell
# Zeigt aktuellen PSRemoting-Status
.\Install-PSRemoting.ps1 -Mode Status
```

---

## 📋 Was macht das Script?

### ✅ Pre-Installation Tests

- PowerShell Version prüfen (>= 5.1)
- Administrator-Rechte prüfen
- WinRM Service Status
- Netzwerk-Konnektivität zu Management-Servern

### ✅ PSRemoting Konfiguration

1. **WinRM Service aktivieren**
   - Enable-PSRemoting
   - Service auf Automatic setzen

2. **TrustedHosts Whitelist**
   - `ITSC020.cc.meduniwien.ac.at`
   - `itscmgmt03.srv.meduniwien.ac.at`

3. **Firewall-Regeln**
   - HTTP Port 5985 aktivieren
   - HTTPS Port 5986 (optional)

4. **HTTP Listener**
   - WS-Management Listener konfigurieren

### ✅ Status & Compliance Check

- WinRM Service Status
- TrustedHosts Konfiguration
- Firewall-Regeln Status
- Listener Konfiguration
- Compliance-Check (OK/FEHLT)

---

## 📝 Logging

Alle Aktionen werden protokolliert:

```
.\Logs\PSRemoting-Install_YYYY-MM-DD.log
```

**Log-Level:**

- `[INFO]` - Informationen
- `[SUCCESS]` - Erfolgreiche Aktionen
- `[WARNING]` - Warnungen
- `[ERROR]` - Fehler

---

## 🔧 Management-Server (ITSC020)

Wenn Sie **von ITSC020 aus** arbeiten und zu anderen Servern verbinden möchten:

### 1. Server zu TrustedHosts hinzufügen

```powershell
.\Add-ServerToTrustedHosts.ps1 -ComputerName "SERVER.srv.meduniwien.ac.at"
```

**Mehrere Server auf einmal:**

```powershell
.\Add-ServerToTrustedHosts.ps1 -ComputerName @(
    "EVAEXTEST01.srv.meduniwien.ac.at",
    "EX01.uvw.meduniwien.ac.at",
    "proman.ad.meduniwien.ac.at"
)
```

### 2. PSRemoting testen

```powershell
Test-WSMan -ComputerName "SERVER.srv.meduniwien.ac.at"
```

### 3. Remote-Session starten

```powershell
Enter-PSSession -ComputerName "SERVER.srv.meduniwien.ac.at" -Credential (Get-Credential)
```

---

## 🛠️ Troubleshooting

### "Execution of scripts is disabled"

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```

### "Access is denied"

➡️ **Als Administrator ausführen!**

Rechtsklick auf PowerShell → "Als Administrator ausführen"

### "WinRM client cannot process the request"

➡️ Server muss zu TrustedHosts hinzugefügt werden:

```powershell
.\Add-ServerToTrustedHosts.ps1 -ComputerName "SERVER.srv.meduniwien.ac.at"
```

### Firewall blockiert Verbindung

➡️ Port 5985 (HTTP) muss offen sein:

```powershell
Test-NetConnection -ComputerName "SERVER" -Port 5985
```

---

## 📚 Weitere Dokumentation

| Datei | Beschreibung |
|-------|-------------|
| `MANAGEMENT-SERVER-GUIDE.md` | Vollständige Anleitung für ITSC020 |
| `README.md` | Detaillierte technische Dokumentation |
| `NETWORK-INSTALLATION.md` | Netzwerk-Deployment Infos |

---

## 🎯 Beispiel-Workflow

### Server konfigurieren (einmalig auf Ziel-Server)

```powershell
# Auf Ziel-Server (z.B. EVAEXTEST01)
cd "\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer"
.\Install-PSRemoting.ps1
# Option [2] wählen
```

### Von Management-Server verbinden

```powershell
# Auf ITSC020
.\Add-ServerToTrustedHosts.ps1 -ComputerName "EVAEXTEST01.srv.meduniwien.ac.at"
Test-WSMan -ComputerName "EVAEXTEST01.srv.meduniwien.ac.at"
Enter-PSSession -ComputerName "EVAEXTEST01.srv.meduniwien.ac.at"
```

---

## ✅ Compliance nach Regelwerk v10.0.3

- ✅ **§5** - Enterprise Logging (Tages-Rotation, UTF8)
- ✅ **§14** - 3-Stufen Credential-Strategie
- ✅ **§19** - PowerShell Version Detection (5.1/7.x)
- ✅ **Whitelist** - Nur autorisierte Management-Server
- ✅ **FQDN** - Immer vollqualifizierte Domain-Namen

---

## 📞 Support

Bei Fragen oder Problemen:

- Log-Datei prüfen: `.\Logs\PSRemoting-Install_*.log`
- Status anzeigen: `.\Install-PSRemoting.ps1 -Mode Status`
- Dokumentation lesen: `README.md`

---

**Version:** v1.0.0  
**Datum:** 2025-10-07  
**Author:** Flecki (Tom) Garnreiter  
**Regelwerk:** v10.0.3
