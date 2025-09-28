# PSProfile - PowerShell Profile Management System
*MUW-Regelwerk konformes PowerShell Profilverwaltungssystem | MUW-Regelwerk compliant PowerShell profile management system*

## Systemarchitektur | System Architecture

Dies ist ein **MUW-Regelwerk konformes** Enterprise PowerShell Profilverwaltungssystem mit WPF GUI, Versionierung und Enterprise-Features.

This is a **MUW-Regelwerk compliant** enterprise PowerShell profile management system with WPF GUI, versioning, and enterprise features.

### Kernkomponenten | Core Components

- **`Reset-PowerShellProfiles.ps1`**: Haupt-Orchestrator Script das Module lädt, Konfiguration verwaltet und PowerShell Profile mit Templates zurücksetzt | Main orchestrator script that loads modules, manages configuration, and resets PowerShell profiles using templates
- **`VERSION.ps1`**: Zentrale Versionsverwaltung mit `$ScriptVersion`, `$RegelwerkVersion` und Cross-Script-Kommunikationsfunktionen | Centralized version management with cross-script communication functions 
- **`Modules/FL-*.psm1`**: Modulare Architektur mit Config, Logging, GUI, Maintenance und Utils Modulen | Modular architecture with Config, Logging, GUI, Maintenance, and Utils modules
- **`Templates/`**: PowerShell Profil-Templates (Profile-template.ps1, Profile-templateX.ps1, Profile-templateMOD.ps1) | PowerShell profile templates
- **`Config/`**: JSON Konfigurationen, Lokalisierungsdateien (de-DE.json, en-US.json) und GUI Assets | JSON configurations, localization files, and GUI assets

## MUW-Regelwerk Compliance Patterns

### Versionsverwaltung (PFLICHT) | Version Management (MANDATORY)
Jedes Script MUSS `VERSION.ps1` laden und `Show-ScriptInfo` aufrufen:
Every script MUST load `VERSION.ps1` and call `Show-ScriptInfo`:

```powershell
# Zentrale Versionsverwaltung laden | Load centralized version management
. (Join-Path (Split-Path -Path $MyInvocation.MyCommand.Path) "VERSION.ps1")
Show-ScriptInfo -ScriptName "Your Script" -CurrentVersion $ScriptVersion
```

### PowerShell 5.1/7.x Kompatibilität (§7) | PowerShell 5.1/7.x Compatibility (§7)
Versionserkennung für Unicode-Inhalte verwenden | Use version detection for Unicode content:

```powershell
# PowerShell Version prüfen für Unicode-Kompatibilität | Check PowerShell version for Unicode compatibility
if ($PSVersionTable.PSVersion.Major -ge 7) {
    Write-Host "🚀 PowerShell 7.x - Unicode OK" 
} else {
    Write-Host ">> PowerShell 5.1 - ASCII alternatives"
}
```

### Cross-Script-Kommunikation (§8) | Cross-Script Communication (§8)
Standardisierte Funktionen aus VERSION.ps1 verwenden | Use standardized functions from VERSION.ps1:

```powershell
# Nachricht an andere Scripts senden | Send message to other scripts
Send-ResetProfileMessage -TargetScript "ScriptName" -Message "Status" -Type "INFO"

# Script-Status setzen | Set script status  
Set-ResetProfileStatus -Status "RUNNING" -Details @{Phase = "Config"}
```

### Modulares Import-Pattern | Modular Import Pattern
```powershell
# FL-Module importieren | Import FL-modules
$modulePath = Join-Path $Global:ScriptDirectory "Modules"
Import-Module (Join-Path $modulePath "FL-Config.psm1") -ErrorAction Stop -Force
Import-Module (Join-Path $modulePath "FL-Logging.psm1") -ErrorAction Stop -Force
# ... weitere FL-* Module | ... other FL-* modules
```

## Konfigurationssystem | Configuration System

### JSON Konfigurationsverwaltung | JSON Configuration Management
- `Get-Config -Path $ConfigFile` zum Laden, `Save-Config` zum Speichern | Use to load, Save-Config to persist
- `Invoke-VersionControl` aktualisiert Configs automatisch bei Versionsänderungen | automatically updates configs for version changes
- `Get-DefaultConfig` liefert Basis-Konfigurationsstruktur | provides baseline configuration structure
- Alle Configs unterstützen DEV/PROD Umgebungen mit `$Global:Config.Environment` | All configs support DEV/PROD environments

### Template-Versionierung | Template Versioning
Templates haben eingebettete Versionsmarkierungen, aktualisiert durch `Set-TemplateVersion`:
Templates have embedded version markers updated by `Set-TemplateVersion`:

```powershell
# Template-Versionen definieren | Define template versions
$Global:Config.TemplateVersions = @{ 
    Profile = "v25.0.0"; 
    ProfileX = "v8.0.0"; 
    ProfileMOD = "v7.0.0" 
}
```

### Netzwerk-Profile Feature | Network Profiles Feature
Verschlüsselte Credential-Speicherung für Netzwerk-Shares:
Encrypted credential storage for network shares:

```powershell
# Passwort verschlüsseln | Encrypt password
ConvertTo-SecureCredential -PlainTextPassword "password"

# Passwort entschlüsseln | Decrypt password  
ConvertFrom-SecureCredential -EncryptedPassword $encrypted -Username $user
```

## Entwicklungs-Workflows | Development Workflows

### Testen | Testing
Umfassende Testsuite ausführen | Run comprehensive test suite:

```powershell
# Alle Funktionen testen | Test all functions
.\TEST\Test-ResetProfile-Functions.ps1
```
Tests validieren: Modul-Loading, Cross-Script-Kommunikation, Konfigurationsintegrität, Regelwerk-Compliance
Tests validate: module loading, cross-script communication, configuration integrity, Regelwerk compliance

### Setup-Modus | Setup Mode
WPF Konfigurations-GUI starten | Launch WPF configuration GUI:

```powershell
# GUI für Konfiguration öffnen | Open GUI for configuration
.\Reset-PowerShellProfiles.ps1 -Setup
```
GUI unterstützt Multi-Language (DE/EN), Netzwerk-Profile, E-Mail-Einstellungen und Git-Integration
GUI supports multi-language, network profiles, email settings, and Git integration

### Simulation-Modus | Simulation Mode  
`-WhatIf` für sicheres Testen verwenden | Use for safe testing:

```powershell
# Simulation ohne echte Änderungen | Simulation without actual changes
.\Reset-PowerShellProfiles.ps1 -WhatIf
```

### Versionskontrolle-Check | Version Control Check
```powershell
# Konfiguration auf Aktualität prüfen | Check configuration for updates
.\Reset-PowerShellProfiles.ps1 -Versionscontrol
```

## Logging & Wartung | Logging & Maintenance

### Strukturiertes Logging | Structured Logging
```powershell  
# Verschiedene Log-Level verwenden | Use different log levels
Write-Log -Level INFO -Message "Operation completed"
Write-Log -Level ERROR -Message "Failed: $($_.Exception.Message)"
```
Level: DEBUG, INFO, WARNING, ERROR. Automatische Event Log Integration und 7-zip Archivierung.
Levels: DEBUG, INFO, WARNING, ERROR. Automatic Event Log integration and 7-zip archiving.

### Archiv-Wartung | Archive Maintenance
`Invoke-ArchiveMaintenance` behandelt Log-Rotation, ZIP-Kompression und Aufbewahrungsrichtlinien gemäß `$Global:Config.Logging` Einstellungen.
`Invoke-ArchiveMaintenance` handles log rotation, ZIP compression, and retention policies per `$Global:Config.Logging` settings.

## Fehlerbehandlungs-Pattern | Error Handling Patterns

### Template-Verarbeitung | Template Processing
```powershell
# Template-Dateien validieren | Validate template files
$Global:Config.TemplateFilePaths.Values | ForEach-Object {
    if (-not (Test-Path $_)) { 
        throw "Template file '$_' not found. Please check configuration or repository." 
    }
}
```

### Modul-Loading | Module Loading
```powershell
try {
    # Kritische Module laden | Load critical modules
    Import-Module (Join-Path $modulePath "FL-Config.psm1") -ErrorAction Stop -Force
} catch {
    Write-Error "Critical error loading essential modules: $($_.ToString())"
    return
}
```

## Code-Konventionen | Code Conventions

- **Globale Variablen | Global Variables**: `$Global:ScriptDirectory`, `$Global:Config`, `$Global:ScriptVersion`
- **Modul-Benennung | Module Naming**: FL-{Function}.psm1 (FL-Config, FL-Logging, FL-Gui, FL-Utils, FL-Maintenance)
- **Fehlerbehandlung | Error Handling**: Immer try/catch mit Write-Log für Enterprise-Umgebungen | Always use try/catch with Write-Log for enterprise environments
- **Encoding**: UTF-8 erzwingen | Force UTF-8: `$OutputEncoding = [System.Text.UTF8Encoding]::new($false)`
- **Admin-Rechte | Admin Rights**: `#requires -RunAsAdministrator` für Profil-Änderungen | for profile modifications

## Integrationspunkte | Integration Points

- **Git Updates**: Optionale Template-Synchronisation vom GitHub Repository via `$Global:Config.GitUpdate`
- **E-Mail-Benachrichtigungen | Email Notifications**: SMTP-Integration für operative Meldungen via `Send-MailNotification`
- **Event Log**: Windows Event Log Integration für Enterprise-Monitoring
- **Netzwerk-Shares | Network Shares**: Verschlüsselte Credential-Verwaltung für UNC-Pfad-Zugriff | Encrypted credential management for UNC path access
- **7-Zip**: Automatisierte Log-Kompression und Archivierung | Automated log compression and archival

**Wichtig | Important**: Immer Konfigurationsvollständigkeit mit `Invoke-VersionControl` vor Operationen validieren und `Initialize-LocalizationFiles` für GUI-Lokalisierung verwenden.
Always validate configuration completeness with `Invoke-VersionControl` before operations and use `Initialize-LocalizationFiles` for GUI localization support.