# 3-Stufen Credential-Strategie - Quick Reference

## 🚀 Quick Start (5 Minuten)

```powershell
# 1. Import Modul
Import-Module ".\Modules\FL-CredentialManager-v1.0.psm1"

# 2. Default Password setzen
$pass = Read-Host "Default Admin Password" -AsSecureString
Set-DefaultAdminPassword -Password $pass -Scope User

# 3. Fertig! Scripts nutzen jetzt automatisch:
#    STUFE 1 → Default Password
#    STUFE 2 → Vault (falls gespeichert)
#    STUFE 3 → Prompt (falls nötig) + Auto-Save
```

## 📋 Cheat Sheet

### Setup-Befehle

```powershell
# Default Password setzen
Set-DefaultAdminPassword -Password $securePass

# Default Password entfernen
Remove-DefaultAdminPassword

# Credential manuell speichern
Save-StoredCredential -Target "SERVER01" -Username "admin" -Password $pass

# Credential aus Vault holen
$cred = Get-StoredCredential -Target "SERVER01"

# Credential löschen
Remove-StoredCredential -Target "SERVER01"
```

### Verwendung in Scripts

```powershell
# Automatisch (empfohlen)
$cred = Get-OrPromptCredential -Target "SERVER" -Username "admin" -AutoSave

# Mit PSRemoting
Invoke-Command -ComputerName SERVER -Credential $cred -ScriptBlock { ... }
```

## 🔍 Diagnose

```powershell
# Default Password prüfen
[Environment]::GetEnvironmentVariable('ADMIN_DEFAULT_PASSWORD', 'User')

# Vault-Inhalt anzeigen
cmdkey /list

# Credential testen
Test-Connection SERVER
$cred = Get-OrPromptCredential -Target "SERVER" -Username "admin"
Invoke-Command -ComputerName SERVER -Credential $cred -ScriptBlock { whoami }
```

## 📦 Integrierte Scripts (nutzen automatisch 3-Stufen)

| Script | Verwendung |
|--------|-----------|
| `Update-CertSurv-ServerList.ps1` | ServerList Update |
| `Install-CertSurv-Scanner-Final.ps1` | Scanner Installation |
| `Update-AllServers-Hybrid-v2.5.ps1` | Mass Deployment |
| `Deploy-CertSurv-QuickStart.ps1` | Quick Deployment |
| `Update-FromExcel-MassUpdate.ps1` | Excel-Update |

## ⚡ Workflow

```
1. Setup (einmalig)
   ↓
   Set-DefaultAdminPassword
   
2. Script ausführen
   ↓
   Automatische Credential-Beschaffung:
   → Default Password versuchen
   → Vault durchsuchen
   → Falls nötig: User fragen + speichern
   
3. Nächstes Mal
   ↓
   KEIN Prompt! (aus Vault)
```

## 🧪 Test

```powershell
.\Test-3-Stufen-Credentials.ps1
```

## 📚 Vollständige Dokumentation

Siehe: [3-STUFEN-CREDENTIAL-STRATEGIE.md](3-STUFEN-CREDENTIAL-STRATEGIE.md)
