# EvaSys Dynamic Update System

**Version:** v6.0.0  
**Regelwerk:** v9.6.2  
**Author:** Flecki (Tom) Garnreiter  

## Overview

The EvaSys Dynamic Update System provides an automated solution for processing EvaSys update packages. It intelligently extracts, analyzes readme files, and executes update instructions automatically while maintaining comprehensive logging and backup capabilities.

## Features

- 🎓 **EvaSys Integration** - Specialized for EvaSys update package processing
- 📦 **Intelligent Package Processing** - Automatic extraction and analysis
- 📋 **Readme Instruction Parsing** - Converts text instructions to executable commands
- 💾 **Automatic Backups** - Creates backups before applying updates
- 📊 **Comprehensive Logging** - Detailed logging with multiple levels
- 🔒 **Security Controls** - Path validation and command restrictions
- 🎯 **Cross-Script Communication** - Status tracking and notifications
- 📱 **PowerShell 5.1/7.x Compatible** - Universal compatibility

## Architecture

``` verlauf
Update Package (.zip) ──► Extract ──► Find Readme ──► Parse Instructions ──► Execute Commands
                                         │                    │                    │
                                         ├─ TXT Files         ├─ Command Mapping   ├─ Backup Creation
                                         └─ PDF Files         └─ Security Check    └─ Status Tracking
```

## Installation

### Prerequisites

- Windows Server 2012 R2+ or Windows 8.1+
- PowerShell 5.1+ (compatible with 5.1 and 7.x according to MUW-Regelwerk v9.6.2)
- Administrator privileges
- EvaSys update packages in supported formats (ZIP, 7Z, RAR)

### Quick Setup

1. **Run Setup Script**

   ```powershell
   .\Setup.ps1
   
   # Silent installation
   .\Setup.ps1 -Silent
   
   # Force reinstallation
   .\Setup.ps1 -Force
   ```

2. **Verify Installation**
   - Configuration: `Settings.json`
   - Instructions: `InstructionSet.json`
   - Directories: `EvaSysUpdates`, `EvaSys_Backups`, `LOG`

## Configuration

### Main Configuration (`Settings.json`)

```json
{
  "EvaSys": {
    "UpdateDirectory": "EvaSysUpdates",
    "BackupDirectory": "EvaSys_Backups",
    "SupportedFormats": ["zip", "7z", "rar"]
  },
  "Processing": {
    "AutoExtract": true,
    "CreateBackups": true,
    "ValidatePackages": true
  },
  "Security": {
    "RequireAdminRights": true,
    "ValidateCommands": true,
    "RestrictedPaths": ["C:\\Windows", "C:\\Program Files"]
  }
}
```

### Instruction Mapping (`InstructionSet.json`)

The system uses pattern matching to convert readme instructions into PowerShell commands:

```json
{
  "instructions": {
    "copy file from {source} to {destination}": "Copy-Item -Path '{source}' -Destination '{destination}' -Force",
    "stop service {service}": "Stop-Service -Name '{service}' -Force",
    "run command {command}": "& {command}"
  }
}
```

## Usage

### Processing Update Packages

1. **Interactive Mode**

   ```powershell
   .\Update.ps1
   # Presents list of available packages for selection
   ```

2. **Automatic Mode**

   ```powershell
   # Process specific package
   .\Update.ps1 -PackagePath "EvaSys_Update_v2.1.zip"
   
   # Process latest package automatically
   .\Update.ps1 -AutoMode
   
   # Skip backup creation
   .\Update.ps1 -SkipBackup
   ```

### Package Processing Workflow

1. **Package Selection** - Choose from available packages in `EvaSysUpdates`
2. **Extraction** - Unpack to temporary `dump` directory
3. **Readme Detection** - Find readme.txt, installation.txt, or update.txt
4. **Backup Creation** - Backup current state (unless `-SkipBackup`)
5. **Instruction Processing** - Parse and execute commands
6. **Logging & Notification** - Log results and send status updates

### System Maintenance

```powershell
# Remove old logs and temporary files
Get-ChildItem "LOG" -Filter "*.log" | Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-30) } | Remove-Item

# Clean dump directory
Remove-Item "dump\*" -Recurse -Force

# Verify configuration
Test-Path "Settings.json" -and (Get-Content "Settings.json" | ConvertFrom-Json).RegelwerkVersion -eq "v9.6.2"
```

## File Structure

``` system verzeichnis
EVASYS/
├── Setup.ps1                    # System installation and configuration
├── Update.ps1                   # Package processing engine
├── Remove.ps1                   # System removal and cleanup
├── VERSION.ps1                  # Version and cross-script communication
├── Settings.json                # Main configuration
├── InstructionSet.json          # Command mapping dictionary
├── README.md                    # This documentation
├── EvaSysUpdates/              # Update packages directory
├── EvaSys_Backups/             # Backup storage
├── LOG/                        # Logging directory
│   ├── Messages/               # Cross-script messages
│   └── Status/                 # System status files
├── dump/                       # Temporary extraction directory
├── Images/                     # Application assets
└── old/                        # Archived legacy files
    ├── Invoke-EvaSysDynamicUpdate.ps1  # Legacy main script
    ├── config-*.json           # Legacy configurations
    └── readme/                 # Legacy documentation
```

## Security Features

### Path Validation

- **Allowed Paths**: `C:\temp`, `C:\EvaSys`, `D:\`, `%TEMP%`
- **Blocked Paths**: `C:\Windows\System32`, `C:\Program Files`

### Command Restrictions

- **Allowed Extensions**: `.exe`, `.msi`, `.bat`, `.cmd`, `.ps1`
- **Blocked Commands**: `format`, `del /s`, `shutdown`, `reboot`

### Safety Measures

- Automatic backup creation before updates
- Command validation before execution
- Comprehensive audit trail
- Administrator rights requirement

## Logging and Monitoring

### Log Levels

- **DEBUG** - Detailed troubleshooting information
- **INFO** - General operational messages
- **WARNING** - Non-critical issues
- **ERROR** - Critical failures requiring attention

### Status Tracking

The system provides cross-script communication through JSON status files:

```json
{
  "Timestamp": "2025-09-29 10:30:00",
  "Status": "UPDATE_COMPLETED",
  "Details": {
    "Package": "EvaSys_Update_v2.1.zip",
    "Success": true
  }
}
```

## Troubleshooting

### Common Issues

1. **Package Not Found**
   - Ensure packages are in `EvaSysUpdates` directory
   - Check file permissions and path accessibility

2. **Extraction Failures**
   - Verify package integrity
   - Check available disk space
   - Ensure supported format (ZIP, 7Z, RAR)

3. **Command Execution Errors**
   - Review `InstructionSet.json` for correct command mapping
   - Check security restrictions in `Settings.json`
   - Verify administrator privileges

4. **PowerShell Version Compatibility**
   - PowerShell 5.1: Uses ASCII prefixes `[INF]`, `[WRN]`, `[ERR]`
   - PowerShell 7.x: Uses Unicode emojis ℹ️, ⚠️, ❌

### Debug Mode

Enable detailed logging:

```powershell
# Modify Settings.json
"Logging": {
  "LogLevel": "DEBUG",
  "EnableConsoleLogging": true
}
```

## Migration from Legacy System

The new system replaces the legacy `Invoke-EvaSysDynamicUpdate.ps1` with a simplified architecture:

| Legacy | New | Description |
|--------|-----|-------------|
| `Invoke-EvaSysDynamicUpdate.ps1` | `Update.ps1` | Simplified processing engine |
| `config-*.json` (multiple files) | `Settings.json` | Unified configuration |
| Manual setup | `Setup.ps1` | Automated installation |
| No removal tool | `Remove.ps1` | Clean uninstallation |

### Migration Steps

1. **Backup Legacy Configuration**

   ```powershell
   Copy-Item "config-*.json" "old\" -Force
   ```

2. **Run New Setup**

   ```powershell
   .\Setup.ps1
   ```

3. **Transfer Settings**
   - Review legacy configurations in `old/` directory
   - Update `Settings.json` with relevant settings
   - Update `InstructionSet.json` with custom commands

## Support

For technical support or feature requests, contact the development team or refer to the MUW-Regelwerk v9.6.2 documentation.

### System Requirements

- **Operating System**: Windows Server 2012 R2+ / Windows 8.1+
- **PowerShell**: 5.1+ (5.1 and 7.x compatible)
- **Memory**: Minimum 2GB RAM
- **Disk Space**: 500MB for system + space for packages/backups
- **Permissions**: Administrator rights required

---

### © 2025 Flecki (Tom) Garnreiter | MIT License | MUW-Regelwerk v9.6.2
