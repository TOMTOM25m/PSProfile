# Secure Credential Management für CertWebService

**Version**: 1.0.0  
**Regelwerk**: v10.0.2  
**Datum**: 1. Oktober 2025

---

## 🔐 Übersicht

Das CertWebService Credential Management System bietet sichere Speicherung und Verwaltung von Zugangsdaten für Remote-Server unter Verwendung der **Windows Data Protection API (DPAPI)**.

---

## 🎯 Features

### Sicherheit
- ✅ **DPAPI-Verschlüsselung**: Credentials werden mit Windows DPAPI verschlüsselt
- ✅ **User-gebunden**: Kann nur vom selben Benutzer entschlüsselt werden
- ✅ **Machine-gebunden**: Kann nur auf derselben Maschine entschlüsselt werden
- ✅ **ACL-geschützt**: Nur SYSTEM und aktueller Benutzer haben Zugriff
- ✅ **Keine Plaintext-Speicherung**: Passwörter werden niemals im Klartext gespeichert

### Funktionalität
- ✅ **Automatische Credential-Abfrage**: Bei fehlendem Credential wird Get-Credential aufgerufen
- ✅ **Persistente Speicherung**: Credentials bleiben über Neustarts erhalten
- ✅ **Multi-Target Support**: Unterschiedliche Credentials für verschiedene Server
- ✅ **Integration in Deployment**: Nahtlose Integration in Deploy-CertWebService.ps1

---

## 📁 Speicherort

```
C:\ProgramData\CertWebService\Credentials\
```

### Dateiformat
```
<TargetName>.cred
```

Beispiel:
```
wsus.srv.meduniwien.ac.at.cred
itscmgmt03.srv.meduniwien.ac.at.cred
```

---

## 🚀 Verwendung

### 1. Modul importieren

```powershell
Import-Module .\Modules\FL-CredentialManager.psm1
```

### 2. Credential speichern

```powershell
# Manuell
$cred = Get-Credential
Save-SecureCredential -Credential $cred -TargetName "wsus.srv.meduniwien.ac.at"
```

### 3. Credential abrufen

```powershell
# Ohne Prompt (gibt $null zurück wenn nicht vorhanden)
$cred = Get-SecureCredential -TargetName "wsus.srv.meduniwien.ac.at"

# Mit automatischem Prompt bei Nicht-Vorhandensein
$cred = Get-SecureCredential -TargetName "wsus.srv.meduniwien.ac.at" -PromptIfNotFound
```

### 4. Credential testen

```powershell
if (Test-SecureCredential -TargetName "wsus.srv.meduniwien.ac.at") {
    Write-Host "Credential exists!"
}
```

### 5. Alle Credentials anzeigen

```powershell
Get-StoredCredentials | Format-Table
```

### 6. Credential entfernen

```powershell
Remove-SecureCredential -TargetName "wsus.srv.meduniwien.ac.at"
```

---

## 🛠️ Integration in Deployment

### Automatisches Deployment mit gespeicherten Credentials

```powershell
# Erste Ausführung: Speichert Credential
.\Deploy-CertWebService.ps1 -Servers "wsus.srv.meduniwien.ac.at"
# -> Get-Credential wird aufgerufen
# -> Credential wird gespeichert

# Nachfolgende Ausführungen: Verwendet gespeichertes Credential
.\Deploy-CertWebService.ps1 -Servers "wsus.srv.meduniwien.ac.at"
# -> Credential wird automatisch geladen
# -> Kein erneutes Get-Credential nötig
```

### Mit explizitem Credential (überschreibt gespeicherte)

```powershell
$cred = Get-Credential
.\Deploy-CertWebService.ps1 -Servers "wsus.srv.meduniwien.ac.at" -Credential $cred
```

---

## 🧪 Test & Management Tool

### Interactive Management Tool starten

```powershell
.\Test-CredentialManager.ps1
```

### Menü-Optionen

```
╔══════════════════════════════════════════════════════════════╗
║      CertWebService Credential Manager v1.0.0           ║
║              Regelwerk v10.0.2                           ║
╚══════════════════════════════════════════════════════════════╝

  1. ➕ Add/Update Credential
  2. 🔍 View Stored Credentials
  3. ✅ Test Credential
  4. ❌ Remove Credential
  5. 🧪 Test Deployment with Stored Credentials
  6. ℹ️  Show Credential Store Path
  0. 🚪 Exit
```

---

## 📊 Beispiel-Workflow

### Initial Setup für wsus Server

```powershell
# 1. Credential Manager testen
Import-Module .\Modules\FL-CredentialManager.psm1

# 2. Credential speichern
$cred = Get-Credential -Message "Credentials für wsus.srv.meduniwien.ac.at"
Save-SecureCredential -Credential $cred -TargetName "wsus.srv.meduniwien.ac.at"

# 3. Verifizieren
Get-StoredCredentials

# 4. Deployment testen
.\Deploy-CertWebService.ps1 -Servers "wsus.srv.meduniwien.ac.at"
```

### Tägliches Deployment (automatisiert)

```powershell
# Scheduled Task Inhalt
cd F:\DEV\repositories\CertWebService
.\Deploy-CertWebService.ps1 -DeployToNetworkShare
# -> Verwendet automatisch gespeicherte Credentials
```

---

## 🔒 Sicherheits-Details

### DPAPI (Data Protection API)

Die Windows Data Protection API bietet:

1. **User-Scope Encryption**
   - Verschlüsselung mit User-Master-Key
   - Nur der verschlüsselnde User kann entschlüsseln

2. **Machine-Binding**
   - Master-Key ist machine-spezifisch
   - Kopieren der Datei auf andere Maschine = keine Entschlüsselung möglich

3. **Kein Passwort nötig**
   - Automatische Entschlüsselung beim Login
   - Transparent für authentifizierten Benutzer

### Credential-Datei Struktur

```json
{
    "Username": "wsus\\Administrator",
    "EncryptedPassword": "01000000d08c9ddf0115d1118c7a00c04fc297eb01000000...",
    "TargetName": "wsus.srv.meduniwien.ac.at",
    "CreatedDate": "2025-10-01 16:57:11",
    "CreatedBy": "itsc020\\Flecki",
    "MachineName": "ITSC020"
}
```

- **Username**: Plaintext (kein Sicherheitsrisiko)
- **EncryptedPassword**: DPAPI-verschlüsselt (Base64)
- **Metadata**: Informationen für Audit-Trail

### File System Permissions

```
C:\ProgramData\CertWebService\Credentials\
├── ACL: Inheritance disabled
├── NT AUTHORITY\SYSTEM: FullControl
└── Current User (itsc020\Flecki): FullControl
```

---

## ⚠️ Wichtige Hinweise

### Was funktioniert

✅ Credentials für Remote-Server speichern  
✅ Automatisches Deployment ohne erneute Eingabe  
✅ Mehrere Server mit unterschiedlichen Credentials  
✅ Sichere Speicherung ohne zusätzliche Master-Passwörter  

### Was NICHT funktioniert

❌ **Credentials auf andere Maschine kopieren** → Entschlüsselung schlägt fehl  
❌ **Credentials von anderem User verwenden** → Entschlüsselung schlägt fehl  
❌ **Credentials nach User-Passwort-Änderung** → Möglicherweise neu eingeben nötig  
❌ **Domain-Credentials ohne Domain-Mitgliedschaft** → Prüfen mit Test-Funktion  

### Best Practices

1. **Initial Setup dokumentieren**
   ```powershell
   # Speichere alle nötigen Credentials einmalig
   Save-SecureCredential -Credential (Get-Credential) -TargetName "server1"
   Save-SecureCredential -Credential (Get-Credential) -TargetName "server2"
   ```

2. **Regelmäßig testen**
   ```powershell
   Get-StoredCredentials | ForEach-Object {
       Test-SecureCredential -TargetName $_.TargetName
   }
   ```

3. **Backup NICHT möglich**
   - Credentials können nicht exportiert werden
   - Bei Neuinstallation müssen Credentials neu eingegeben werden

4. **Service-Account verwenden**
   - Für automatisierte Deployments idealerweise Service-Account verwenden
   - Service-Account sollte minimale nötige Rechte haben

---

## 🔧 Troubleshooting

### Problem: Credential wird nicht gefunden

```powershell
# Prüfe Speicherort
Test-Path "C:\ProgramData\CertWebService\Credentials"

# Liste alle Credentials
Get-ChildItem "C:\ProgramData\CertWebService\Credentials" -Filter "*.cred"
```

### Problem: Entschlüsselung schlägt fehl

```powershell
# Teste Credential
Test-SecureCredential -TargetName "wsus.srv.meduniwien.ac.at"

# Falls False: Neu erstellen
Remove-SecureCredential -TargetName "wsus.srv.meduniwien.ac.at"
$cred = Get-Credential
Save-SecureCredential -Credential $cred -TargetName "wsus.srv.meduniwien.ac.at"
```

### Problem: Zugriff verweigert auf Credential-Store

```powershell
# Prüfe Permissions
Get-Acl "C:\ProgramData\CertWebService\Credentials" | Format-List

# Neu erstellen mit korrekten Permissions
Remove-Item "C:\ProgramData\CertWebService\Credentials" -Recurse -Force
# Beim nächsten Save-SecureCredential werden Permissions neu gesetzt
```

---

## 📚 API-Referenz

### Save-SecureCredential

```powershell
Save-SecureCredential -Credential <PSCredential> -TargetName <String>
```

**Parameter:**
- `Credential` (mandatory): PSCredential-Objekt
- `TargetName` (mandatory): Eindeutiger Identifier (meist Servername)

**Rückgabe:** `$true` bei Erfolg, `$false` bei Fehler

---

### Get-SecureCredential

```powershell
Get-SecureCredential -TargetName <String> [-PromptIfNotFound] [-PromptMessage <String>]
```

**Parameter:**
- `TargetName` (mandatory): Eindeutiger Identifier
- `PromptIfNotFound` (optional): Zeigt Get-Credential wenn nicht gefunden
- `PromptMessage` (optional): Custom Message für Get-Credential

**Rückgabe:** PSCredential oder `$null`

---

### Remove-SecureCredential

```powershell
Remove-SecureCredential -TargetName <String>
```

**Parameter:**
- `TargetName` (mandatory): Eindeutiger Identifier

**Rückgabe:** `$true` bei Erfolg, `$false` bei Fehler

---

### Get-StoredCredentials

```powershell
Get-StoredCredentials
```

**Rückgabe:** Array von PSCustomObjects mit:
- TargetName
- Username
- CreatedDate
- CreatedBy
- MachineName
- FilePath

---

### Test-SecureCredential

```powershell
Test-SecureCredential -TargetName <String>
```

**Parameter:**
- `TargetName` (mandatory): Eindeutiger Identifier

**Rückgabe:** `$true` wenn vorhanden und entschlüsselbar, sonst `$false`

---

## 🎓 Deployment-Beispiele

### Beispiel 1: Alle Server mit automatischen Credentials

```powershell
$servers = @("itscmgmt03.srv.meduniwien.ac.at", "wsus.srv.meduniwien.ac.at")

foreach ($srv in $servers) {
    .\Deploy-CertWebService.ps1 -Servers $srv
}
# -> Verwendet gespeicherte Credentials oder fragt bei Bedarf nach
```

### Beispiel 2: Network Share mit Credentials

```powershell
.\Deploy-CertWebService.ps1 -DeployToNetworkShare
# -> Verwendet automatisch gespeicherte Credentials für itscmgmt03
```

### Beispiel 3: Scheduled Task Setup

```powershell
# Task erstellen für tägliches Deployment um 02:00
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File F:\DEV\repositories\CertWebService\Deploy-CertWebService.ps1 -DeployToNetworkShare"

$trigger = New-ScheduledTaskTrigger -Daily -At "02:00"
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName "CertWebService-AutoDeploy" `
    -Action $action -Trigger $trigger -Principal $principal
```

---

## 📝 Changelog

### Version 1.0.0 (2025-10-01)
- ✅ Initial Release
- ✅ DPAPI-basierte Credential-Verschlüsselung
- ✅ Integration in Deploy-CertWebService.ps1 (PS5 & PS7)
- ✅ Test-CredentialManager.ps1 Management Tool
- ✅ Automatische ACL-Konfiguration
- ✅ Multi-Target Support
- ✅ Comprehensive API

---

## 👥 Support & Kontakt

**Maintainer**: thomas.garnreiter@meduniwien.ac.at  
**Organization**: IT-Services, Medizinische Universität Wien  
**Repository**: F:\\DEV\\repositories\\CertWebService  
**Module**: Modules\\FL-CredentialManager.psm1

---

**Status**: ✅ **PRODUCTION READY**  
**Security Level**: 🔒 **DPAPI-Protected**  
**Last Updated**: 2025-10-01
