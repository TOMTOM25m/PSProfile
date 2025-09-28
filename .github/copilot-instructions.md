# PSProfile - PowerShell Profile Management System

## System Architecture

This is a **MUW-Regelwerk compliant** enterprise PowerShell profile management system with WPF GUI, versioning, and enterprise features.

### Core Components

- **`Reset-PowerShellProfiles.ps1`**: Main orchestrator script that loads modules, manages configuration, and resets PowerShell profiles using templates
- **`VERSION.ps1`**: Centralized version management with `$ScriptVersion`, `$RegelwerkVersion`, and cross-script communication functions 
- **`Modules/FL-*.psm1`**: Modular architecture with Config, Logging, GUI, Maintenance, and Utils modules
- **`Templates/`**: PowerShell profile templates (Profile-template.ps1, Profile-templateX.ps1, Profile-templateMOD.ps1)
- **`Config/`**: JSON configurations, localization files (de-DE.json, en-US.json), and GUI assets

## MUW-Regelwerk Compliance Patterns

### Version Management (MANDATORY)
Every script MUST load `VERSION.ps1` and call `Show-ScriptInfo`:

```powershell
. (Join-Path (Split-Path -Path $MyInvocation.MyCommand.Path) "VERSION.ps1")
Show-ScriptInfo -ScriptName "Your Script" -CurrentVersion $ScriptVersion
```

### PowerShell 5.1/7.x Compatibility (§7)
Use version detection for Unicode content:

```powershell
if ($PSVersionTable.PSVersion.Major -ge 7) {
    Write-Host "🚀 PowerShell 7.x - Unicode OK" 
} else {
    Write-Host ">> PowerShell 5.1 - ASCII alternatives"
}
```

### Cross-Script Communication (§8)
Use standardized functions from VERSION.ps1:
- `Send-ResetProfileMessage -TargetScript "ScriptName" -Message "Status" -Type "INFO"`  
- `Set-ResetProfileStatus -Status "RUNNING" -Details @{Phase = "Config"}`

### Modular Import Pattern
```powershell
$modulePath = Join-Path $Global:ScriptDirectory "Modules"
Import-Module (Join-Path $modulePath "FL-Config.psm1") -ErrorAction Stop -Force
Import-Module (Join-Path $modulePath "FL-Logging.psm1") -ErrorAction Stop -Force
# ... other FL-* modules
```

## Configuration System

### JSON Configuration Management
- Use `Get-Config -Path $ConfigFile` to load, `Save-Config` to persist
- `Invoke-VersionControl` automatically updates configs for version changes
- `Get-DefaultConfig` provides baseline configuration structure
- All configs support DEV/PROD environments with `$Global:Config.Environment`

### Template Versioning
Templates have embedded version markers updated by `Set-TemplateVersion`:
```powershell
$Global:Config.TemplateVersions = @{ Profile = "v25.0.0"; ProfileX = "v8.0.0"; ProfileMOD = "v7.0.0" }
```

### Network Profiles Feature
Encrypted credential storage for network shares:
```powershell
ConvertTo-SecureCredential -PlainTextPassword "password"  # Encrypt
ConvertFrom-SecureCredential -EncryptedPassword $encrypted -Username $user  # Decrypt  
```

## Development Workflows

### Testing
Run comprehensive test suite:
```powershell
.\TEST\Test-ResetProfile-Functions.ps1
```
Tests validate: module loading, cross-script communication, configuration integrity, Regelwerk compliance

### Setup Mode
Launch WPF configuration GUI:
```powershell
.\Reset-PowerShellProfiles.ps1 -Setup
```
GUI supports multi-language (DE/EN), network profiles, email settings, and Git integration

### Simulation Mode  
Use `-WhatIf` for safe testing:
```powershell
.\Reset-PowerShellProfiles.ps1 -WhatIf  # No actual changes made
```

### Version Control Check
```powershell
.\Reset-PowerShellProfiles.ps1 -Versionscontrol
```

## Logging & Maintenance

### Structured Logging
```powershell  
Write-Log -Level INFO -Message "Operation completed"
Write-Log -Level ERROR -Message "Failed: $($_.Exception.Message)"
```
Levels: DEBUG, INFO, WARNING, ERROR. Automatic Event Log integration and 7-zip archiving.

### Archive Maintenance
`Invoke-ArchiveMaintenance` handles log rotation, ZIP compression, and retention policies per `$Global:Config.Logging` settings.

## Error Handling Patterns

### Template Processing
```powershell
$Global:Config.TemplateFilePaths.Values | ForEach-Object {
    if (-not (Test-Path $_)) { 
        throw "Template file '$_' not found. Please check configuration or repository." 
    }
}
```

### Module Loading
```powershell
try {
    Import-Module (Join-Path $modulePath "FL-Config.psm1") -ErrorAction Stop -Force
} catch {
    Write-Error "Critical error loading essential modules: $($_.ToString())"
    return
}
```

## Code Conventions

- **Global Variables**: `$Global:ScriptDirectory`, `$Global:Config`, `$Global:ScriptVersion`
- **Module Naming**: FL-{Function}.psm1 (FL-Config, FL-Logging, FL-Gui, FL-Utils, FL-Maintenance)
- **Error Handling**: Always use try/catch with Write-Log for enterprise environments
- **Encoding**: Force UTF-8: `$OutputEncoding = [System.Text.UTF8Encoding]::new($false)`
- **Admin Rights**: `#requires -RunAsAdministrator` for profile modifications

## Integration Points

- **Git Updates**: Optional template sync from GitHub repository via `$Global:Config.GitUpdate`
- **Email Notifications**: SMTP integration for operational alerts via `Send-MailNotification`
- **Event Log**: Windows Event Log integration for enterprise monitoring 
- **Network Shares**: Encrypted credential management for UNC path access
- **7-Zip**: Automated log compression and archival

Always validate configuration completeness with `Invoke-VersionControl` before operations and use `Initialize-LocalizationFiles` for GUI localization support.