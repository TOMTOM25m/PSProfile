#Requires -version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    EvaSys Dynamic Update System - Complete Removal and Cleanup

.DESCRIPTION
    Cleanly removes the EvaSys update system and all components.
    Provides safe uninstallation with optional data preservation.
    Compatible with PowerShell 5.1 and 7.x according to MUW-Regelwerk v9.6.2.

.PARAMETER KeepData
    Preserves log files and backup data
    
.PARAMETER KeepPackages
    Keeps update packages in EvaSysUpdates directory
    
.PARAMETER Force
    Forces removal without confirmation prompts

.NOTES
    Author:         Flecki (Tom) Garnreiter
    Version:        v6.0.0
    Regelwerk:      v9.6.2
    
.EXAMPLE
    .\Remove.ps1
    Standard removal with confirmation prompts
    
.EXAMPLE
    .\Remove.ps1 -KeepData -Force
    Forced removal while preserving data
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$KeepData,
    [switch]$KeepPackages,
    [switch]$Force
)

#region Initialization
. (Join-Path (Split-Path -Path $MyInvocation.MyCommand.Path) "VERSION.ps1")
Show-ScriptInfo -ScriptName "EvaSys System Removal" -CurrentVersion $ScriptVersion

$Global:ScriptDirectory = $PSScriptRoot
$Global:LogFile = Join-Path $Global:ScriptDirectory "LOG\Remove_$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Ensure LOG directory exists
$logDir = Split-Path $Global:LogFile -Parent
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}
#endregion

#region Main Functions
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Console output with PowerShell version compatibility
    $color = switch ($Level) {
        'INFO'    { 'White' }
        'WARNING' { 'Yellow' }
        'ERROR'   { 'Red' }
        default   { 'White' }
    }
    
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        $prefix = switch ($Level) {
            'INFO'    { 'ℹ️ ' }
            'WARNING' { '⚠️ ' }
            'ERROR'   { '❌' }
            default   { '📝' }
        }
        Write-Host "$prefix $logEntry" -ForegroundColor $color
    } else {
        $prefix = switch ($Level) {
            'INFO'    { '[INF]' }
            'WARNING' { '[WRN]' }
            'ERROR'   { '[ERR]' }
            default   { '[LOG]' }
        }
        Write-Host "$prefix $logEntry" -ForegroundColor $color
    }
    
    # File output
    if ($Global:LogFile) {
        try {
            Add-Content -Path $Global:LogFile -Value $logEntry -Encoding UTF8
        } catch {
            Write-Warning "Failed to write to log file: $_"
        }
    }
}

function Remove-EvaSysConfiguration {
    Write-Log "Removing configuration files..."
    
    $configFiles = @("Settings.json", "InstructionSet.json")
    
    foreach ($file in $configFiles) {
        $filePath = Join-Path $Global:ScriptDirectory $file
        if (Test-Path $filePath) {
            if ($PSCmdlet.ShouldProcess($file, "Remove configuration file")) {
                try {
                    Remove-Item $filePath -Force
                    Write-Log "Removed: $file"
                } catch {
                    Write-Log "Failed to remove $file: $($_.Exception.Message)" -Level WARNING
                }
            }
        }
    }
}

function Remove-EvaSysDirectories {
    Write-Log "Removing system directories..."
    
    $directories = @("dump", "xpdf-tools")
    
    if (-not $KeepData) {
        $directories += @("LOG")
    }
    
    if (-not $KeepPackages) {
        $directories += @("EvaSysUpdates")
    }
    
    if (-not $KeepData) {
        $directories += @("EvaSys_Backups")
    }
    
    foreach ($dir in $directories) {
        $dirPath = Join-Path $Global:ScriptDirectory $dir
        if (Test-Path $dirPath) {
            if ($PSCmdlet.ShouldProcess($dir, "Remove directory")) {
                try {
                    Remove-Item $dirPath -Recurse -Force
                    Write-Log "Removed: $dir"
                } catch {
                    Write-Log "Failed to remove $dir: $($_.Exception.Message)" -Level WARNING
                }
            }
        }
    }
}

function Remove-EvaSysScripts {
    Write-Log "Removing system scripts..."
    
    $scripts = @("Setup.ps1", "Update.ps1", "VERSION.ps1")
    
    foreach ($script in $scripts) {
        $scriptPath = Join-Path $Global:ScriptDirectory $script
        if (Test-Path $scriptPath) {
            if ($PSCmdlet.ShouldProcess($script, "Remove script")) {
                try {
                    Remove-Item $scriptPath -Force
                    Write-Log "Removed: $script"
                } catch {
                    Write-Log "Failed to remove $script: $($_.Exception.Message)" -Level WARNING
                }
            }
        }
    }
}

function Show-RemovalSummary {
    param([hashtable]$Results)
    
    Write-Host "`n=== EvaSys System Removal Summary ===" -ForegroundColor Yellow
    
    foreach ($component in $Results.Keys) {
        $status = if ($Results[$component]) { "✓ SUCCESS" } else { "✗ FAILED" }
        $color = if ($Results[$component]) { "Green" } else { "Red" }
        Write-Host "  $component`: $status" -ForegroundColor $color
    }
    
    Write-Host "`n📋 Removal completed on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
    
    if ($KeepData) {
        Write-Host "📁 Data preserved: LOG directory retained" -ForegroundColor Yellow
    }
    
    if ($KeepPackages) {
        Write-Host "📦 Packages preserved: EvaSysUpdates directory retained" -ForegroundColor Yellow
    }
}
#endregion

#region Main Execution
try {
    Set-EvaSysStatus -Status "REMOVAL_STARTED" -Details @{
        KeepData = $KeepData.IsPresent
        KeepPackages = $KeepPackages.IsPresent
        Force = $Force.IsPresent
    }
    
    Write-Log "=== EvaSys System Removal Started ==="
    
    # Confirmation prompt (unless forced)
    if (-not $Force) {
        Write-Host "`n⚠️  WARNING: This will remove the EvaSys Dynamic Update System" -ForegroundColor Yellow
        Write-Host "The following will be removed:" -ForegroundColor Yellow
        Write-Host "  - Configuration files" -ForegroundColor Gray
        Write-Host "  - System scripts" -ForegroundColor Gray
        Write-Host "  - Processing directories" -ForegroundColor Gray
        
        if (-not $KeepData) {
            Write-Host "  - Log files and backups" -ForegroundColor Gray
        }
        
        if (-not $KeepPackages) {
            Write-Host "  - Update packages" -ForegroundColor Gray
        }
        
        $confirmation = Read-Host "`nDo you want to continue? (Y/N)"
        if ($confirmation -notlike 'Y*' -and $confirmation -notlike 'y*') {
            Write-Log "Removal cancelled by user"
            return
        }
    }
    
    # Track removal results
    $results = @{}
    
    # Step 1: Remove configuration files
    try {
        Remove-EvaSysConfiguration
        $results["Configuration Files"] = $true
    } catch {
        Write-Log "Failed to remove configuration: $($_.Exception.Message)" -Level ERROR
        $results["Configuration Files"] = $false
    }
    
    # Step 2: Remove directories
    try {
        Remove-EvaSysDirectories
        $results["System Directories"] = $true
    } catch {
        Write-Log "Failed to remove directories: $($_.Exception.Message)" -Level ERROR
        $results["System Directories"] = $false
    }
    
    # Step 3: Remove scripts (this should be last as it removes this script)
    try {
        Remove-EvaSysScripts
        $results["System Scripts"] = $true
    } catch {
        Write-Log "Failed to remove scripts: $($_.Exception.Message)" -Level ERROR
        $results["System Scripts"] = $false
    }
    
    Set-EvaSysStatus -Status "REMOVAL_COMPLETED" -Details @{
        Success = ($results.Values -notcontains $false)
        Results = $results
    }
    
    Show-RemovalSummary -Results $results
    Write-Log "=== EvaSys System Removal Completed ==="
    
} catch {
    $errorMessage = "Removal failed: $($_.Exception.Message)"
    Write-Log $errorMessage -Level ERROR
    
    Set-EvaSysStatus -Status "REMOVAL_FAILED" -Details @{
        Error = $errorMessage
    }
    
    exit 1
}
#endregion