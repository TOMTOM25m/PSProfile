# Management-Server Konfiguration (ITSC020)

**Arbeitsplatz:** ITSC020.cc.meduniwien.ac.at  
**Network Share:** \\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer

---

## Problem: "TrustedHosts" auf Management-Server

Wenn du von **ITSC020** aus PSRemoting zu anderen Servern verwenden möchtest, musst du diese Server zu den **TrustedHosts auf ITSC020** hinzufügen!

**Symptom:**

```
Enter-PSSession: Connecting to remote server EVAEXTEST01.srv.meduniwien.ac.at failed 
with the following error message : The WinRM client cannot process the request. 
If the authentication scheme is different from Kerberos, or if the client computer 
is not joined to a domain, then HTTPS transport must be used or the destination 
machine must be added to the TrustedHosts configuration setting.
```

---

## Lösung: Server zu TrustedHosts hinzufügen

### Schritt 1: Server hinzufügen (als Administrator auf ITSC020)

```powershell
# Vom Network Share ausführen
cd "\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer"

# Server hinzufügen (IMMER vollen FQDN verwenden!)
.\Add-ServerToTrustedHosts.ps1 -ComputerName "EVAEXTEST01.srv.meduniwien.ac.at"
```

### Schritt 2: Mehrere Server gleichzeitig

```powershell
.\Add-ServerToTrustedHosts.ps1 -ComputerName @(
    "EVAEXTEST01.srv.meduniwien.ac.at",
    "proman.ad.meduniwien.ac.at",
    "campus-script01.srv.meduniwien.ac.at"
)
```

### Schritt 3: Aktuelle TrustedHosts anzeigen

```powershell
.\Add-ServerToTrustedHosts.ps1 -ShowCurrent
```

---

## Verbindung testen

### Test 1: WSMan-Test (ohne Credentials)

```powershell
Test-WSMan -ComputerName "EVAEXTEST01.srv.meduniwien.ac.at"
```

**Ergebnis bei Erfolg:**

```
wsmid           : http://schemas.dmtf.org/wbem/wsman/identity/1/wsmanidentity.xsd
ProtocolVersion : http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd
ProductVendor   : Microsoft Corporation
ProductVersion  : OS: 0.0.0 SP: 0.0 Stack: 3.0
```

### Test 2: PSSession mit Credentials

```powershell
$cred = Get-Credential
Enter-PSSession -ComputerName "EVAEXTEST01.srv.meduniwien.ac.at" -Credential $cred
```

**Bei Erfolg:**

```
[EVAEXTEST01.srv.meduniwien.ac.at]: PS C:\Users\Administrator\Documents>
```

### Test 3: Remote-Command

```powershell
$cred = Get-Credential
Invoke-Command -ComputerName "EVAEXTEST01.srv.meduniwien.ac.at" -Credential $cred -ScriptBlock {
    Get-Service | Where-Object { $_.Status -eq 'Running' } | Select-Object -First 5
}
```

---

## Workflow: PSRemoting auf Ziel-Server konfigurieren

### Von ITSC020 aus (2 Methoden)

#### Methode 1: Remote-Installation

```powershell
# Server zu TrustedHosts hinzufügen
.\Add-ServerToTrustedHosts.ps1 -ComputerName "EVAEXTEST01.srv.meduniwien.ac.at"

# Credentials holen
$cred = Get-Credential

# Remote-Installation
Invoke-Command -ComputerName "EVAEXTEST01.srv.meduniwien.ac.at" -Credential $cred -ScriptBlock {
    & "\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer\Configure-PSRemoting.ps1"
}
```

#### Methode 2: Via RDP

```powershell
# 1. RDP zum Server
mstsc /v:EVAEXTEST01.srv.meduniwien.ac.at

# 2. Auf dem Server ausführen:
\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer\Install-PSRemoting.bat
```

---

## Wichtige Regeln

### ✅ IMMER vollen FQDN verwenden

```powershell
# ✅ RICHTIG:
.\Add-ServerToTrustedHosts.ps1 -ComputerName "EVAEXTEST01.srv.meduniwien.ac.at"
Test-WSMan -ComputerName "EVAEXTEST01.srv.meduniwien.ac.at"
Enter-PSSession -ComputerName "EVAEXTEST01.srv.meduniwien.ac.at" -Credential $cred

# ❌ FALSCH:
.\Add-ServerToTrustedHosts.ps1 -ComputerName "EVAEXTEST01"
Test-WSMan -ComputerName "EVAEXTEST01"
Enter-PSSession -ComputerName "EVAEXTEST01" -Credential $cred
```

### ✅ Administrator-Rechte erforderlich

```powershell
# Prüfen:
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
# True = Admin, False = Nicht Admin
```

---

## Typischer Workflow für neue Server

### Server vorbereiten (Checklist)

```powershell
# 1. Server zu TrustedHosts auf ITSC020 hinzufügen
cd "\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer"
.\Add-ServerToTrustedHosts.ps1 -ComputerName "NEUER-SERVER.srv.meduniwien.ac.at"

# 2. Verbindung testen
Test-WSMan -ComputerName "NEUER-SERVER.srv.meduniwien.ac.at"

# 3. Credentials vorbereiten
$cred = Get-Credential  # NEUER-SERVER\Administrator

# 4a. Remote-Installation (bevorzugt)
Invoke-Command -ComputerName "NEUER-SERVER.srv.meduniwien.ac.at" -Credential $cred -ScriptBlock {
    & "\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer\Configure-PSRemoting.ps1"
}

# 4b. ODER: Via RDP
mstsc /v:NEUER-SERVER.srv.meduniwien.ac.at
# Auf Server: \\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer\Install-PSRemoting.bat

# 5. Status prüfen
Enter-PSSession -ComputerName "NEUER-SERVER.srv.meduniwien.ac.at" -Credential $cred
Get-Service WinRM
Get-Item WSMan:\localhost\Client\TrustedHosts
Exit-PSSession
```

---

## Bekannte Server-Liste (für TrustedHosts)

### CertWebService-Server (müssen aktualisiert werden)

```powershell
# Alle auf einmal hinzufügen:
.\Add-ServerToTrustedHosts.ps1 -ComputerName @(
    "EX01.uvw.meduniwien.ac.at",
    "proman.ad.meduniwien.ac.at",
    "campus-script01.srv.meduniwien.ac.at",
    "EVAEXTEST01.srv.meduniwien.ac.at",
    "UVW-FINANZ01.uvw.meduniwien.ac.at",
    "UVWmgmt01.uvw.meduniwien.ac.at",
    "UVWDC001.uvw.meduniwien.ac.at",
    "wsus.srv.meduniwien.ac.at"
)
```

---

## Troubleshooting

### Problem: "Access Denied"

**Lösung:** Als Administrator ausführen

```powershell
# PowerShell als Admin öffnen:
Start-Process powershell -Verb RunAs
```

### Problem: "The WinRM client cannot process the request"

**Lösung:** Server zu TrustedHosts hinzufügen (siehe oben)

### Problem: "Cannot overwrite variable Host"

**Lösung:** Script wurde aktualisiert - erneut vom Network Share kopieren

### Problem: Server antwortet nicht

**Prüfen:**

```powershell
# 1. Netzwerk-Verbindung
Test-NetConnection -ComputerName "SERVER.srv.meduniwien.ac.at" -Port 5985

# 2. WinRM-Service auf Ziel-Server
# Via RDP verbinden und prüfen:
Get-Service WinRM

# 3. Firewall-Regeln auf Ziel-Server
Get-NetFirewallRule -Name "WINRM-HTTP-In-TCP"
```

---

## Aktuelle Konfiguration auf ITSC020

### TrustedHosts anzeigen

```powershell
Get-Item WSMan:\localhost\Client\TrustedHosts
```

### WinRM-Service Status

```powershell
Get-Service WinRM
```

### PSRemoting-Status

```powershell
Get-PSSessionConfiguration
```

---

## Sicherheit

### Whitelist auf Ziel-Servern

**Auf den Ziel-Servern** wird automatisch eine Whitelist konfiguriert:

- ITSC020.cc.meduniwien.ac.at
- itscmgmt03.srv.meduniwien.ac.at

**Das bedeutet:** Nur von diesen beiden Servern kann man sich zu den Ziel-Servern verbinden!

### TrustedHosts auf ITSC020

**Auf ITSC020** musst du manuell festlegen, zu welchen Servern du dich verbinden darfst.

**Best Practice:**

- Nur die Server hinzufügen, die du wirklich managst
- Volle FQDN verwenden (keine Wildcards wie `*`)
- Regelmäßig prüfen: `.\Add-ServerToTrustedHosts.ps1 -ShowCurrent`

---

## Quick Reference

```powershell
# Server hinzufügen
.\Add-ServerToTrustedHosts.ps1 -ComputerName "SERVER.srv.meduniwien.ac.at"

# Liste anzeigen
.\Add-ServerToTrustedHosts.ps1 -ShowCurrent

# Verbindung testen
Test-WSMan -ComputerName "SERVER.srv.meduniwien.ac.at"

# Verbinden
$cred = Get-Credential
Enter-PSSession -ComputerName "SERVER.srv.meduniwien.ac.at" -Credential $cred

# Remote-Command
Invoke-Command -ComputerName "SERVER.srv.meduniwien.ac.at" -Credential $cred -ScriptBlock { Get-Service }

# PSRemoting konfigurieren (Remote)
Invoke-Command -ComputerName "SERVER.srv.meduniwien.ac.at" -Credential $cred -ScriptBlock {
    & "\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer\Configure-PSRemoting.ps1"
}
```

---

**Author:** Flecki (Tom) Garnreiter  
**Version:** v1.0.0  
**Date:** 2025-10-07  
**Arbeitsplatz:** ITSC020.cc.meduniwien.ac.at
