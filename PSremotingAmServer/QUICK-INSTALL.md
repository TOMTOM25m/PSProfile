# PSRemoting Network Share Installation

**Network Share Pfad:**  
`\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer`

---

## 🚀 Schnellstart - Installation auf Remote-Server

### ✅ EMPFOHLENE METHODE: Batch-File

**Als Administrator ausführen:**

```batch
\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer\Install-PSRemoting.bat
```

**Das macht das Script:**

1. ✅ Prüft Administrator-Rechte
2. ✅ Testet Netzwerk-Verbindung
3. ✅ Führt `Configure-PSRemoting.ps1` aus
4. ✅ Konfiguriert WinRM + PSRemoting
5. ✅ Setzt Whitelist (ITSC020 + itscmgmt03)
6. ✅ Erstellt Firewall-Regeln
7. ✅ Erstellt Logs in `.\Logs\`

---

## 📋 Alternative Methoden

### Methode 2: PowerShell direkt

```powershell
# Als Administrator in PowerShell ausführen
cd "\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer"
.\Configure-PSRemoting.ps1
```

### Methode 3: Mit HTTPS-Listener

```powershell
cd "\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer"
.\Configure-PSRemoting.ps1 -EnableHTTPS
```

### Methode 4: Verbindungstest

```powershell
cd "\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer"
.\Configure-PSRemoting.ps1 -TestConnection -RemoteComputer "SERVER01"
```

### Methode 5: Whitelist-Status anzeigen

```powershell
cd "\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer"
.\Show-PSRemotingWhitelist.ps1
```

---

## 🔐 Security - Whitelist

**Nur folgende Rechner dürfen PSRemoting verwenden:**

- ✅ `ITSC020.cc.meduniwien.ac.at`
- ✅ `itscmgmt03.srv.meduniwien.ac.at`

Diese Whitelist wird automatisch konfiguriert!

---

## 📁 Verfügbare Dateien auf Network Share

```
\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer\
│
├── Install-PSRemoting.bat           ⭐ EMPFOHLEN (als Admin)
├── Configure-PSRemoting.ps1         (Haupt-Konfiguration)
├── Show-PSRemotingWhitelist.ps1     (Status-Check)
├── README.md                         (Vollständige Doku)
├── NETWORK-INSTALLATION.md           (Diese Datei)
│
└── Examples\
    └── Test-RemoteConnection.ps1     (Verbindungstest)
```

---

## 🎯 Typischer Workflow

### Schritt 1: Auf Remote-Server verbinden

```powershell
# Via RDP oder PSSession
Enter-PSSession -ComputerName SERVER01
```

### Schritt 2: Installation ausführen

```batch
\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer\Install-PSRemoting.bat
```

### Schritt 3: Status prüfen

```powershell
cd "\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer"
.\Show-PSRemotingWhitelist.ps1
```

**Ergebnis:**

```
=====================================================================
  PSRemoting Whitelist-Konfiguration
=====================================================================

🔒 AUTORISIERTE COMPUTER (WHITELIST):
  ✓ ITSC020.cc.meduniwien.ac.at
  ✓ itscmgmt03.srv.meduniwien.ac.at

WINRM SERVICE STATUS:
  Status: Running
  StartType: Automatic

TRUSTEDHOSTS KONFIGURATION:
  [SUCCESS] ITSC020.cc.meduniwien.ac.at
  [SUCCESS] itscmgmt03.srv.meduniwien.ac.at

WHITELIST COMPLIANCE:
  ✓ COMPLIANT
```

---

## 📊 Logging

**Logs werden lokal auf dem Server erstellt:**

```
.\Logs\PSRemoting-Config_2025-10-07.log
```

**Tages-Rotation:** Pro Tag eine Logdatei

---

## 🔧 Remote-Installation (von ITSC020/itscmgmt03)

Falls du von einem autorisierten Rechner aus installieren möchtest:

```powershell
# Mit 3-Stufen Credential-Strategie
$cred = Get-Credential

Invoke-Command -ComputerName SERVER01 -Credential $cred -ScriptBlock {
    & "\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer\Configure-PSRemoting.ps1"
}
```

---

## 📝 Beispiele

### Beispiel 1: Standard-Installation

```batch
\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer\Install-PSRemoting.bat
```

### Beispiel 2: Installation mit HTTPS

```powershell
powershell -ExecutionPolicy Bypass -Command "& '\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer\Configure-PSRemoting.ps1' -EnableHTTPS"
```

### Beispiel 3: Verbindungstest nach Installation

```powershell
cd "\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer"
.\Examples\Test-RemoteConnection.ps1 -ComputerName "SERVER01"
```

---

## 🐛 Troubleshooting

### Problem: "Netzwerk-Share nicht erreichbar"

**Lösung:**

```powershell
# Teste Verbindung
Test-Path "\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer"

# Mount Share manuell
net use Z: \\itscmgmt03.srv.meduniwien.ac.at\iso
```

### Problem: "Access Denied"

**Lösung:**

- Als Administrator ausführen
- Rechtsklick auf Batch-File → "Als Administrator ausführen"

### Problem: "Execution Policy"

**Lösung:**

```powershell
# Temporär Policy ändern
Set-ExecutionPolicy Bypass -Scope Process -Force
```

---

## 📧 Support

**Author:** Flecki (Tom) Garnreiter  
**Email:** <thomas.garnreiter@meduniwien.ac.at>  
**Version:** v1.0.0  
**Date:** 2025-10-07

---

## 📋 Deployment History

**Letztes Deployment:** 2025-10-07 15:24:53  
**Deployed von:** ITSCMGMT03  
**Regelwerk:** v10.0.3

---

**✅ Network Share ready for production deployment!**

**Security:** 🔒 Nur ITSC020 + itscmgmt03  
**Logging:** 📊 Tages-Rotation  
**Installation:** ⚡ Batch-File (1-Click)
