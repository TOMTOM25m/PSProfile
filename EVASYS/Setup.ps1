#Requires -version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    EvaSys Dynamic Update System - Simplified Installation and Configuration

.DESCRIPTION
    Sets up the EvaSys update automation system with intelligent package processing.
    Replaces complex setup procedures with a single, comprehensive solution.
    Compatible with PowerShell 5.1 and 7.x according to MUW-Regelwerk v9.6.2.

.PARAMETER ConfigFile
    Path to configuration file (default: Settings.json)
    
.PARAMETER Silent
    Runs setup without user interaction
    
.PARAMETER Force
    Forces reinstallation even if already configured

.NOTES
    Author:         Flecki (Tom) Garnreiter
    Version:        v6.0.0
    Regelwerk:      v9.6.2
    
.EXAMPLE
    .\Setup.ps1
    Standard setup with interactive configuration
    
.EXAMPLE
    .\Setup.ps1 -Silent -Force
    Silent reinstallation
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ConfigFile = "Settings.json",
    [switch]$Silent,
    [switch]$Force
)

#region Initialization
. (Join-Path (Split-Path -Path $MyInvocation.MyCommand.Path) "VERSION.ps1")
Show-ScriptInfo -ScriptName "EvaSys Setup" -CurrentVersion $ScriptVersion

# Set initial status for cross-script communication
Set-EvaSysStatus -Status "SETUP_STARTED" -Details @{
    ConfigFile = $ConfigFile
    Silent = $Silent.IsPresent
    Force = $Force.IsPresent
}

$Global:ScriptDirectory = $PSScriptRoot
$Global:LogFile = Join-Path $Global:ScriptDirectory "LOG\Setup_$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Ensure LOG directory exists
$logDir = Split-Path $Global:LogFile -Parent
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}
#endregion

#region Main Functions
function Test-Prerequisites {
    Write-Host "Testing system prerequisites..." -ForegroundColor Yellow
    
    # Test Administrator privileges
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "This script must be run as Administrator"
    }
    
    # Test PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        throw "PowerShell 5.1 or higher is required"
    }
    
    # Create required directories
    $requiredDirs = @("LOG", "EvaSysUpdates", "EvaSys_Backups", "dump")
    foreach ($dir in $requiredDirs) {
        $fullPath = Join-Path $Global:ScriptDirectory $dir
        if (-not (Test-Path $fullPath)) {
            New-Item -Path $fullPath -ItemType Directory -Force | Out-Null
            Write-Host "   Created directory: $dir" -ForegroundColor Green
        }
    }
    
    Write-Host "   Prerequisites satisfied" -ForegroundColor Green
}

function New-DefaultConfiguration {
    $config = @{
        ScriptVersion = $ScriptVersion
        RegelwerkVersion = $RegelwerkVersion
        Environment = "PROD"
        
        EvaSys = @{
            UpdateDirectory = "EvaSysUpdates"
            BackupDirectory = "EvaSys_Backups"
            DumpDirectory = "dump"
            SupportedFormats = @("zip", "7z", "rar")
        }
        
        Processing = @{
            AutoExtract = $true
            CreateBackups = $true
            ValidatePackages = $true
            ProcessReadme = $true
        }
        
        Logging = @{
            LogDirectory = "LOG"
            LogLevel = "INFO"
            LogRetentionDays = 30
            MaxLogSize = "10MB"
        }
        
        Notifications = @{
            Enabled = $true
            EmailEnabled = $false
            SMTPServer = ""
            Recipients = @()
        }
        
        Compliance = @{
            RegelwerkVersion = "v9.6.2"
            CrossScriptCommunication = $true
            MessageDirectory = "LOG\Messages"
            StatusDirectory = "LOG\Status"
            PowerShellCompatibility = "5.1+"
            UnicodeSupport = "conditional"
        }
    }
    
    return $config
}

function Install-PDFTools {
    Write-Host "Checking PDF processing tools..." -ForegroundColor Yellow
    
    $xpdfPath = Join-Path $Global:ScriptDirectory "xpdf-tools"
    if (-not (Test-Path $xpdfPath)) {
        Write-Host "   PDF tools not found - manual installation may be required" -ForegroundColor Orange
        return $false
    }
    
    Write-Host "   PDF tools available" -ForegroundColor Green
    return $true
}

function Test-ConfigurationIntegrity {
    param([object]$Config)
    
    $issues = @()
    
    # Required settings validation
    if (-not $Config.EvaSys.UpdateDirectory) {
        $issues += "Missing EvaSys.UpdateDirectory"
    }
    
    if (-not $Config.Logging.LogDirectory) {
        $issues += "Missing Logging.LogDirectory"
    }
    
    if ($issues.Count -gt 0) {
        Write-Warning "Configuration issues found:"
        $issues | ForEach-Object { Write-Warning "  - $_" }
        return $false
    }
    
    return $true
}
#endregion

#region Main Execution
try {
    Write-Host "=== EvaSys Dynamic Update System Setup ===" -ForegroundColor Cyan
    
    # Step 1: Test prerequisites
    Test-Prerequisites
    
    # Step 2: Check existing configuration
    $configPath = Join-Path $Global:ScriptDirectory $ConfigFile
    if ((Test-Path $configPath) -and -not $Force) {
        if (-not $Silent) {
            $overwrite = Read-Host "Configuration exists. Overwrite? (Y/N)"
            if ($overwrite -notlike 'Y*') {
                Write-Host "Setup cancelled by user" -ForegroundColor Yellow
                return
            }
        } else {
            Write-Host "Configuration exists - use -Force to overwrite" -ForegroundColor Yellow
            return
        }
    }
    
    # Step 3: Create configuration
    Write-Host "Creating configuration..." -ForegroundColor Yellow
    $config = New-DefaultConfiguration
    
    if (-not $Silent) {
        Write-Host "Configuration created with default settings." -ForegroundColor Green
        Write-Host "Edit $ConfigFile to customize settings." -ForegroundColor Cyan
    }
    
    # Step 4: Validate and save configuration
    if (Test-ConfigurationIntegrity -Config $config) {
        $config | ConvertTo-Json -Depth 10 | Out-File $configPath -Encoding UTF8
        Write-Host "   Configuration saved: $ConfigFile" -ForegroundColor Green
    } else {
        throw "Configuration validation failed"
    }
    
    # Step 5: Install PDF tools check
    Install-PDFTools
    
    # Step 6: Create instruction dictionary template
    $instructionPath = Join-Path $Global:ScriptDirectory "InstructionSet.json"
    if (-not (Test-Path $instructionPath)) {
        $instructions = @{
            "copy file" = "Copy-Item -Path '{source}' -Destination '{destination}' -Force"
            "delete file" = "Remove-Item -Path '{target}' -Force"
            "create directory" = "New-Item -Path '{path}' -ItemType Directory -Force"
            "run command" = "& {command}"
            "stop service" = "Stop-Service -Name '{service}' -Force"
            "start service" = "Start-Service -Name '{service}'"
        }
        
        $instructions | ConvertTo-Json -Depth 3 | Out-File $instructionPath -Encoding UTF8
        Write-Host "   Instruction template created: InstructionSet.json" -ForegroundColor Green
    }
    
    Set-EvaSysStatus -Status "SETUP_COMPLETED" -Details @{
        ConfigurationFile = $ConfigFile
        Success = $true
    }
    
    Write-Host "`n=== Setup completed successfully! ===" -ForegroundColor Green
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Review and customize $ConfigFile" -ForegroundColor White
    Write-Host "  2. Update InstructionSet.json with your commands" -ForegroundColor White
    Write-Host "  3. Run .\Update.ps1 to process EvaSys packages" -ForegroundColor White
    
} catch {
    $errorMessage = "Setup failed: $($_.Exception.Message)"
    Write-Host $errorMessage -ForegroundColor Red
    Set-EvaSysStatus -Status "SETUP_FAILED" -Details @{
        Error = $errorMessage
    }
    exit 1
}
#endregion