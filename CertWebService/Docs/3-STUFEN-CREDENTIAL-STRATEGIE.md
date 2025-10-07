# 3-Stufen Credential-Strategie

## 📋 Übersicht

Die **3-Stufen-Strategie** eliminiert manuelle Passwort-Eingaben bei wiederkehrenden Deployments durch intelligentes Credential-Management.

## 🎯 Strategie-Ablauf

```
┌─────────────────────────────────────────┐
│  STUFE 1: Default Admin Password        │
│  Environment Variable                    │
│  ADMIN_DEFAULT_PASSWORD                  │
└─────────────────┬───────────────────────┘
                  │
                  ▼ Nicht gefunden?
┌─────────────────────────────────────────┐
│  STUFE 2: Windows Credential Manager    │
│  Gespeichertes Passwort für Target      │
│  cmdkey.exe / PasswordVault              │
└─────────────────┬───────────────────────┘
                  │
                  ▼ Nicht gefunden?
┌─────────────────────────────────────────┐
│  STUFE 3: Benutzer-Prompt               │
│  Get-Credential mit AutoSave             │
│  Speichert in Vault für nächstes Mal    │
└─────────────────────────────────────────┘
```

## 🔧 Setup

### Einmalige Konfiguration

```powershell
# 1. FL-CredentialManager Modul importieren
Import-Module ".\Modules\FL-CredentialManager-v1.0.psm1"

# 2. Default Admin Password setzen (STUFE 1)
Set-DefaultAdminPassword -Password (ConvertTo-SecureString "YourDefaultAdminPassword" -AsPlainText -Force) -Scope User
```

### Modul-Integration in Scripts

Alle Produktions-Scripts haben bereits den Import:

```powershell
# Import FL-CredentialManager für 3-Stufen-Strategie
Import-Module "$PSScriptRoot\Modules\FL-CredentialManager-v1.0.psm1" -Force
```

## 📦 Integrierte Scripts

Die 3-Stufen-Strategie ist **permanent integriert** in:

| Script | Verwendung | Target |
|--------|-----------|--------|
| `Update-CertSurv-ServerList.ps1` | Excel → ServerList Update | Server-spezifisch |
| `Install-CertSurv-Scanner-Final.ps1` | Scanner Installation | Server-spezifisch |
| `Update-AllServers-Hybrid-v2.5.ps1` | Mass Deployment | `CertWebService-Deployment` |
| `Deploy-CertSurv-QuickStart.ps1` | Quick Deployment | `CertSurv-Deployment` |
| `Update-FromExcel-MassUpdate.ps1` | Excel-basiertes Update | `CertWebService-MassUpdate` |

## 💻 Verwendung in eigenen Scripts

### Einfaches Beispiel

```powershell
Import-Module ".\Modules\FL-CredentialManager-v1.0.psm1"

# Automatische 3-Stufen-Strategie
$cred = Get-OrPromptCredential `
    -Target "ITSCMGMT03" `
    -Username "itscmgmt03\Administrator" `
    -AutoSave

# Verwenden
Invoke-Command -ComputerName ITSCMGMT03 -Credential $cred -ScriptBlock {
    Get-Service CertWebService*
}
```

### Mit Server-Loop

```powershell
$servers = @("SERVER01", "SERVER02", "SERVER03")

foreach ($server in $servers) {
    # Automatische Credential-Beschaffung für jeden Server
    $cred = Get-OrPromptCredential `
        -Target $server `
        -Username "$server\Administrator" `
        -AutoSave
    
    if ($cred) {
        Invoke-Command -ComputerName $server -Credential $cred -ScriptBlock {
            # Deployment-Code hier
        }
    }
}
```

## 🔐 Sicherheit

### Speicherorte

1. **Default Password**: Environment Variable `ADMIN_DEFAULT_PASSWORD`
   - User-Scope: `HKCU:\Environment`
   - Machine-Scope: `HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment`

2. **Vault Passwords**: Windows Credential Manager
   - Verschlüsselt mit Windows DPAPI
   - Pro-User Isolierung
   - Target-Format: `{ServerName}` oder `{DeploymentType}`

### Best Practices

✅ **DO**:

- Default-Password für Standard-Admin-Account
- Server-spezifische Credentials im Vault
- AutoSave für wiederkehrende Deployments

❌ **DON'T**:

- Default-Password in Scripts hardcoden
- Passwörter in Klartext speichern
- Credentials per Parameter übergeben (außer für Tests)

## 🧪 Testing

```powershell
# Test-Script ausführen
.\Test-3-Stufen-Credentials.ps1

# Ablauf:
# 1. Setup: Default Password setzen
# 2. TEST 1: Erste Ausführung (Default → Vault)
# 3. TEST 2: Zweite Ausführung (aus Vault)
# 4. REMOTE TEST: Tatsächliche Verbindung
# 5. Cleanup: Optional löschen
```

## 📊 Funktions-Übersicht

### Get-OrPromptCredential

Hauptfunktion für intelligente Credential-Beschaffung.

```powershell
$cred = Get-OrPromptCredential `
    -Target "ServerName" `           # Ziel (für Vault-Lookup)
    -Username "Domain\User" `        # Benutzername
    -AutoSave                        # Bei Prompt automatisch speichern
```

### Set-DefaultAdminPassword

Setzt Standard-Admin-Passwort für STUFE 1.

```powershell
Set-DefaultAdminPassword `
    -Password (ConvertTo-SecureString "Pass" -AsPlainText -Force) `
    -Scope User                      # User oder Machine
```

### Save-StoredCredential

Manuelles Speichern von Credentials.

```powershell
Save-StoredCredential `
    -Target "SERVER01" `
    -Username "Administrator" `
    -Password (Read-Host -AsSecureString)
```

### Get-StoredCredential

Credential aus Vault laden.

```powershell
$cred = Get-StoredCredential -Target "SERVER01"
```

### Remove-StoredCredential

Credential aus Vault löschen.

```powershell
Remove-StoredCredential -Target "SERVER01"
```

### Remove-DefaultAdminPassword

Default-Password entfernen.

```powershell
Remove-DefaultAdminPassword -Scope User
```

## 🔄 Workflow-Beispiele

### Szenario 1: Erstmaliges Deployment

```powershell
# 1. Setup (einmalig)
Set-DefaultAdminPassword -Password $securePass

# 2. Script ausführen
.\Update-AllServers-Hybrid-v2.5.ps1 -ServerList @("SRV01", "SRV02")

# → STUFE 1 wird verwendet
# → Bei Erfolg wird in Vault gespeichert (AutoSave)
```

### Szenario 2: Wiederholtes Deployment

```powershell
# Script erneut ausführen
.\Update-AllServers-Hybrid-v2.5.ps1 -ServerList @("SRV01", "SRV02")

# → STUFE 2 wird verwendet (aus Vault)
# → KEIN Prompt!
```

### Szenario 3: Server mit anderem Passwort

```powershell
# Script ausführen für Server mit abweichendem Passwort
.\Install-CertSurv-Scanner-Final.ps1 -TargetServer "SPECIAL-SRV"

# → STUFE 1 schlägt fehl
# → STUFE 2 findet keinen Vault-Eintrag
# → STUFE 3: Benutzer-Prompt
# → Credential wird für "SPECIAL-SRV" gespeichert
```

### Szenario 4: Bulk-Deployment verschiedener Domains

```powershell
$servers = @(
    "UVW-SRV01.uvw.meduniwien.ac.at",
    "EX-SRV01.ex.meduniwien.ac.at",
    "NEURO-SRV01.neuro.meduniwien.ac.at"
)

foreach ($server in $servers) {
    $shortName = $server.Split('.')[0]
    
    # Automatische Credential-Beschaffung
    $cred = Get-OrPromptCredential `
        -Target $server `
        -Username "$shortName\Administrator" `
        -AutoSave
    
    if ($cred) {
        # Deployment durchführen
        Invoke-Command -ComputerName $server -Credential $cred -ScriptBlock {
            # Installation...
        }
    }
}

# → Jede Domain kann eigenes Passwort haben
# → Credentials werden pro Server gespeichert
# → Nächstes Mal: KEIN Prompt für bereits bekannte Server
```

## 🗑️ Cleanup

### Einzelne Credentials löschen

```powershell
Remove-StoredCredential -Target "SERVER01"
```

### Alle Server-Credentials löschen

```powershell
# Liste aller gespeicherten Credentials
cmdkey /list | Select-String "Target:" | ForEach-Object {
    $target = $_.ToString().Split('=')[1].Trim()
    if ($target -match "SERVER|ITSCMGMT") {
        cmdkey /delete:$target
    }
}
```

### Default Password entfernen

```powershell
Remove-DefaultAdminPassword -Scope User
```

## 📚 Regelwerk-Konformität

- **Regelwerk**: v10.0.2
- **§19**: PowerShell 5.1/7.x Kompatibilität ✅
- **§24**: Credential Management ✅
- **§27**: Automatisierung ✅

## 🆘 Troubleshooting

### Problem: "Default password not found"

```powershell
# Prüfen
[Environment]::GetEnvironmentVariable('ADMIN_DEFAULT_PASSWORD', 'User')

# Setzen
Set-DefaultAdminPassword -Password $securePass
```

### Problem: "Credential not found in vault"

```powershell
# Vault-Inhalt prüfen
cmdkey /list

# Manuell speichern
Save-StoredCredential -Target "SERVER" -Username "user" -Password $pass
```

### Problem: "Access Denied" trotz Credential

```powershell
# Credential testen
$testCred = Get-StoredCredential -Target "SERVER"
Invoke-Command -ComputerName SERVER -Credential $testCred -ScriptBlock { whoami }

# Bei Fehler: Credential neu setzen
Remove-StoredCredential -Target "SERVER"
# Nächstes Script-Run wird neu promten
```

## 📝 Version History

| Version | Datum | Änderungen |
|---------|-------|-----------|
| 1.0.0 | 2025-10-07 | Initial Release mit 3-Stufen-Strategie |

## 🔗 Related Documentation

- [FL-CredentialManager-v1.0.psm1](../Modules/FL-CredentialManager-v1.0.psm1)
- [Test-3-Stufen-Credentials.ps1](../Test-3-Stufen-Credentials.ps1)
- [PowerShell-Regelwerk v10.0.2](../archive/PowerShell-Regelwerk-Universal-v10.0.1.md)
