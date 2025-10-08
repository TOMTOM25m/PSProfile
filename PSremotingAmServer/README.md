# PSRemoting Configuration Tools

**Enterprise-Grade PSRemoting Configuration nach Regelwerk v10.0.3**

---

## 📋 Übersicht

Dieses Repository enthält professionelle Tools zur Konfiguration und Verwaltung von PowerShell Remoting in Enterprise-Umgebungen.

### Implementierte Standards

- ✅ **Regelwerk v10.0.3 Compliance**
- ✅ **PowerShell 5.1/7.x Kompatibilität**
- ✅ **3-Stufen Credential-Strategie (§14)**
- ✅ **Enterprise Logging & Error Handling**
- ✅ **Firewall-Automation**
- ✅ **HTTPS-Support mit Zertifikaten**

---

## 🚀 Quick Start

### 1. Standard-Konfiguration

```powershell
# Als Administrator ausführen
.\Configure-PSRemoting.ps1
```

**Aktiviert:**

- WinRM Service
- PSRemoting
- Firewall-Regeln (HTTP Port 5985)
- TrustedHosts: `*.meduniwien.ac.at`

### 2. Erweiterte Konfiguration mit HTTPS

```powershell
.\Configure-PSRemoting.ps1 -TrustedHosts "*.meduniwien.ac.at,192.168.*" -EnableHTTPS
```

**Zusätzlich:**

- HTTPS-Listener (Port 5986)
- Selbstsigniertes Zertifikat
- HTTPS Firewall-Regel

### 3. Verbindungstest

```powershell
.\Configure-PSRemoting.ps1 -TestConnection -RemoteComputer "SERVER01"
```

**Features:**

- Automatische Credential-Verwaltung (3-Stufen-Strategie)
- PowerShell-Versionsanzeige
- OS-Informationen

---

## 📖 Detaillierte Verwendung

### Configure-PSRemoting.ps1

#### Parameter

| Parameter | Typ | Standard | Beschreibung |
|-----------|-----|----------|--------------|
| `-TrustedHosts` | String | `*.meduniwien.ac.at` | Komma-separierte Liste erlaubter Hosts |
| `-EnableHTTPS` | Switch | `$false` | Aktiviert HTTPS-Listener mit Zertifikat |
| `-TestConnection` | Switch | `$false` | Testet PSRemoting-Verbindung |
| `-RemoteComputer` | String | - | Ziel-Computer für Test (mit `-TestConnection`) |

#### Beispiele

**Basis-Konfiguration:**

```powershell
.\Configure-PSRemoting.ps1
```

**Mit spezifischen TrustedHosts:**

```powershell
.\Configure-PSRemoting.ps1 -TrustedHosts "server01.domain.com,server02.domain.com"
```

**Mit Wildcard-Pattern:**

```powershell
.\Configure-PSRemoting.ps1 -TrustedHosts "*.meduniwien.ac.at,*.srv.meduniwien.ac.at"
```

**Komplette Enterprise-Konfiguration:**

```powershell
.\Configure-PSRemoting.ps1 -TrustedHosts "*" -EnableHTTPS -Verbose
```

**Test ohne Konfiguration:**

```powershell
.\Configure-PSRemoting.ps1 -TestConnection -RemoteComputer "proman.ad.meduniwien.ac.at"
```

---

## 🔐 Credential Management (§14 Regelwerk v10.0.3)

### 3-Stufen-Strategie

Das Script integriert automatisch die **3-Stufen Credential-Strategie**, wenn das Modul verfügbar ist:

```
┌─────────────────────────────────────────┐
│  STUFE 1: Default Admin Password        │
│  Environment Variable                    │
└─────────────────┬───────────────────────┘
                  │
                  ▼ Nicht gefunden?
┌─────────────────────────────────────────┐
│  STUFE 2: Windows Credential Manager    │
│  Gespeichertes Passwort                  │
└─────────────────┬───────────────────────┘
                  │
                  ▼ Nicht gefunden?
┌─────────────────────────────────────────┐
│  STUFE 3: Benutzer-Prompt               │
│  Get-Credential mit AutoSave             │
└─────────────────────────────────────────┘
```

### Setup FL-CredentialManager (Optional)

```powershell
# Modul kopieren (falls vorhanden)
Copy-Item "F:\DEV\repositories\CertWebService\Modules\FL-CredentialManager-v1.0.psm1" `
    -Destination "F:\DEV\repositories\PSremotingAmServer\Modules\" -Force

# Default Password setzen
Import-Module .\Modules\FL-CredentialManager-v1.0.psm1
$defaultPass = Read-Host "Default Admin Password" -AsSecureString
Set-DefaultAdminPassword -Password $defaultPass -Scope User
```

---

## 📊 Ausgabe-Beispiel

### Erfolgreiche Konfiguration

```
=====================================================================
  Configure-PSRemoting v1.0.0
  Enterprise PSRemoting Configuration Tool
  Regelwerk: v10.0.3
=====================================================================

[STEP 1] Aktiviere WinRM und PSRemoting...
[SUCCESS] WinRM Service aktiviert
[SUCCESS] PSRemoting aktiviert

[STEP 2] Konfiguriere TrustedHosts...
[SUCCESS] TrustedHosts gesetzt: *.meduniwien.ac.at

[STEP 3] Konfiguriere Firewall-Regeln...
[SUCCESS] Firewall-Regel für HTTP (5985) erstellt

[STATUS] PSRemoting-Konfiguration:
=====================================================================
WinRM Service:
  Status: Running
  Startup: Automatic

TrustedHosts:
  *.meduniwien.ac.at

WinRM Listener:
  Transport: HTTP | Port: 5985 | Address: *

Firewall-Regeln:
  HTTP (5985): True
=====================================================================

=====================================================================
  PSRemoting-Konfiguration erfolgreich abgeschlossen!
=====================================================================
```

---

## 🔧 Manuelle PSRemoting-Befehle

### Basis-Befehle

```powershell
# PSRemoting aktivieren
Enable-PSRemoting -Force -SkipNetworkProfileCheck

# WinRM Service starten
Start-Service WinRM

# TrustedHosts setzen
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*.meduniwien.ac.at" -Force

# Status prüfen
Get-WSManInstance -ResourceURI winrm/config/listener -Enumerate
```

### Test-Befehle

```powershell
# Lokaler Test
Test-WSMan -ComputerName localhost

# Remote-Test
Test-WSMan -ComputerName SERVER01

# Remote-Command ausführen
Invoke-Command -ComputerName SERVER01 -ScriptBlock { Get-Service }

# Mit Credentials
$cred = Get-Credential
Invoke-Command -ComputerName SERVER01 -Credential $cred -ScriptBlock {
    Get-Service | Where-Object { $_.Status -eq 'Running' }
}
```

### HTTPS-Konfiguration

```powershell
# Selbstsigniertes Zertifikat erstellen
$cert = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME `
    -CertStoreLocation Cert:\LocalMachine\My

# HTTPS-Listener erstellen
New-WSManInstance -ResourceURI winrm/config/Listener `
    -SelectorSet @{Address="*";Transport="HTTPS"} `
    -ValueSet @{Hostname=$env:COMPUTERNAME;CertificateThumbprint=$cert.Thumbprint}

# Firewall-Regel für HTTPS
New-NetFirewallRule -Name "WINRM-HTTPS-In-TCP" `
    -DisplayName "Windows Remote Management (HTTPS-In)" `
    -Direction Inbound -Protocol TCP -LocalPort 5986 -Action Allow
```

---

## 📁 Dateistruktur

```
PSremotingAmServer/
│
├── Configure-PSRemoting.ps1    # Haupt-Konfigurationsskript
├── README.md                    # Diese Dokumentation
│
├── Modules/                     # Optional: PowerShell Module
│   └── FL-CredentialManager-v1.0.psm1
│
├── Examples/                    # Beispiel-Scripts
│   ├── Test-RemoteConnection.ps1
│   ├── Deploy-ToMultipleServers.ps1
│   └── Remote-ServiceManagement.ps1
│
└── Logs/                        # Automatisch erstellt
    └── PSRemoting-Config-*.log
```

---

## 🛡️ Sicherheitshinweise

### 🔒 PSRemoting Whitelist (Standard)

**Nur folgende Rechner dürfen PSRemoting verwenden:**

- `ITSC020.cc.meduniwien.ac.at`
- `itscmgmt03.srv.meduniwien.ac.at`

Diese Whitelist ist der **Standard** beim Ausführen von `Configure-PSRemoting.ps1`.

**⚠️ WICHTIG:** Diese Einschränkung erhöht die Sicherheit erheblich, da nur bekannte Management-Server Zugriff erhalten!

### TrustedHosts Best Practices

```powershell
# ❌ NICHT EMPFOHLEN: Alle Hosts erlauben
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force

# ✅ EMPFOHLEN: Spezifische Domain
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*.meduniwien.ac.at" -Force

# ✅ EMPFOHLEN: Mehrere Domains
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*.meduniwien.ac.at,*.srv.meduniwien.ac.at" -Force

# ✅ EMPFOHLEN: Spezifische Server
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "server01,server02,server03" -Force
```

### Firewall-Ports

| Port | Protokoll | Verwendung |
|------|-----------|------------|
| 5985 | HTTP | Standard PSRemoting (unverschlüsselt) |
| 5986 | HTTPS | Verschlüsseltes PSRemoting |

**Empfehlung:** In Produktionsumgebungen immer HTTPS verwenden!

---

## 🐛 Troubleshooting

### Problem: "Access Denied"

**Lösung:**

```powershell
# Als Administrator ausführen
Start-Process powershell -Verb RunAs
```

### Problem: "WinRM cannot process the request"

**Lösung:**

```powershell
# WinRM Service prüfen
Get-Service WinRM

# WinRM neu starten
Restart-Service WinRM

# Konfiguration zurücksetzen
winrm quickconfig -force
```

### Problem: "Connection refused"

**Lösung:**

```powershell
# Firewall-Regeln prüfen
Get-NetFirewallRule -Name "WINRM-HTTP-In-TCP"

# TrustedHosts prüfen
Get-Item WSMan:\localhost\Client\TrustedHosts

# Netzwerk-Verbindung testen
Test-NetConnection -ComputerName SERVER01 -Port 5985
```

### Problem: "Authentication failed"

**Lösung:**

```powershell
# Credentials explizit angeben
$cred = Get-Credential
Invoke-Command -ComputerName SERVER01 -Credential $cred -ScriptBlock { hostname }

# Oder: FL-CredentialManager verwenden (3-Stufen-Strategie)
Import-Module .\Modules\FL-CredentialManager-v1.0.psm1
$cred = Get-OrPromptCredential -Target "SERVER01" -Username "SERVER01\Administrator" -AutoSave
```

---

## 📝 Logging

Alle Aktionen werden automatisch protokolliert:

**Logfile-Pfad:** `.\Logs\PSRemoting-Config_YYYY-MM-DD.log`

**Tages-Rotation:** Pro Tag eine Logdatei (wie CertWebService)

**Beispiel:**

```
[2025-10-07 14:30:15] [INFO] Configure-PSRemoting v1.0.0 gestartet
[2025-10-07 14:30:15] [INFO] Computer: ITSCMGMT03
[2025-10-07 14:30:15] [INFO] User: Administrator
[2025-10-07 14:30:15] [INFO] PowerShell Version: 5.1.22621.1778
[2025-10-07 14:30:16] [SUCCESS] WinRM Service aktiviert
[2025-10-07 14:30:17] [SUCCESS] PSRemoting aktiviert
[2025-10-07 14:30:18] [SUCCESS] TrustedHosts gesetzt: *.meduniwien.ac.at
[2025-10-07 14:30:19] [SUCCESS] Firewall-Regel für HTTP (5985) erstellt
[2025-10-07 14:30:20] [SUCCESS] PSRemoting-Konfiguration erfolgreich abgeschlossen
```

---

## 🔗 Verwandte Ressourcen

### Regelwerk v10.0.3

Siehe: `F:\DEV\repositories\Documentation\Regelwerk\PowerShell-Regelwerk-Universal-v10.0.3.md`

**Relevante Paragraphen:**

- §14: Security Standards (3-Stufen Credential-Strategie)
- §13: Network Operations
- §19: PowerShell-Versionserkennung

### FL-CredentialManager

Siehe: `F:\DEV\repositories\CertWebService\Modules\FL-CredentialManager-v1.0.psm1`

---

## 📜 Changelog

### v1.0.0 (2025-10-07)

**Initial Release:**

- ✅ Regelwerk v10.0.3 Compliance
- ✅ PowerShell 5.1/7.x Kompatibilität
- ✅ Automatische WinRM/PSRemoting-Aktivierung
- ✅ TrustedHosts-Konfiguration
- ✅ Firewall-Automation (HTTP/HTTPS)
- ✅ HTTPS-Listener mit selbstsigniertem Zertifikat
- ✅ 3-Stufen Credential-Strategie Integration
- ✅ Enterprise Logging
- ✅ Verbindungstest-Funktion

---

## 📋 License

MIT License - © 2025 Flecki (Tom) Garnreiter

---

## 📧 Support

**Author:** Flecki (Tom) Garnreiter  
**Email:** <thomas.garnreiter@meduniwien.ac.at>  
**Version:** v1.0.0  
**Date:** 2025-10-07

---

**PowerShell-Regelwerk Universal v10.0.3 Compliance ✅**
