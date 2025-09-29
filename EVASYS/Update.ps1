#Requires -version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    EvaSys Dynamic Update System - Package Processing and Updates

.DESCRIPTION
    Processes EvaSys update packages by extracting, analyzing readme files,
    and executing update instructions automatically.
    Compatible with PowerShell 5.1 and 7.x according to MUW-Regelwerk v9.6.2.

.PARAMETER PackagePath
    Path to specific update package to process
    
.PARAMETER AutoMode
    Runs in automatic mode without user interaction
    
.PARAMETER SkipBackup
    Skips backup creation before updates

.NOTES
    Author:         Flecki (Tom) Garnreiter
    Version:        v6.0.0
    Regelwerk:      v9.6.2
    
.EXAMPLE
    .\Update.ps1
    Interactive mode - user selects package
    
.EXAMPLE
    .\Update.ps1 -PackagePath "package.zip" -AutoMode
    Process specific package automatically
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$PackagePath,
    [switch]$AutoMode,
    [switch]$SkipBackup
)

#region Initialization
. (Join-Path (Split-Path -Path $MyInvocation.MyCommand.Path) "VERSION.ps1")
Show-ScriptInfo -ScriptName "EvaSys Update Processor" -CurrentVersion $ScriptVersion

$Global:ScriptDirectory = $PSScriptRoot
$Global:LogFile = Join-Path $Global:ScriptDirectory "LOG\Update_$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Ensure LOG directory exists
$logDir = Split-Path $Global:LogFile -Parent
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

# Load configuration
$configPath = Join-Path $Global:ScriptDirectory "Settings.json"
if (-not (Test-Path $configPath)) {
    Write-Error "Configuration file not found. Run Setup.ps1 first."
    exit 1
}

$Config = Get-Content $configPath -Raw | ConvertFrom-Json
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
        'DEBUG'   { 'Gray' }
        'INFO'    { 'White' }
        'WARNING' { 'Yellow' }
        'ERROR'   { 'Red' }
        default   { 'White' }
    }
    
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        $prefix = switch ($Level) {
            'DEBUG'   { '🔍' }
            'INFO'    { 'ℹ️ ' }
            'WARNING' { '⚠️ ' }
            'ERROR'   { '❌' }
            default   { '📝' }
        }
        Write-Host "$prefix $logEntry" -ForegroundColor $color
    } else {
        $prefix = switch ($Level) {
            'DEBUG'   { '[DBG]' }
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

function Get-UpdatePackages {
    $updateDir = Join-Path $Global:ScriptDirectory $Config.EvaSys.UpdateDirectory
    
    if (-not (Test-Path $updateDir)) {
        Write-Log "Update directory not found: $updateDir" -Level ERROR
        return @()
    }
    
    $packages = Get-ChildItem -Path $updateDir -Filter "*.zip" -File
    Write-Log "Found $($packages.Count) update packages"
    
    return $packages
}

function Select-UpdatePackage {
    param([array]$Packages)
    
    if ($Packages.Count -eq 0) {
        Write-Log "No update packages found" -Level WARNING
        return $null
    }
    
    if ($AutoMode) {
        $selected = $Packages | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        Write-Log "Auto-selected latest package: $($selected.Name)"
        return $selected
    }
    
    Write-Host "`nAvailable update packages:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $Packages.Count; $i++) {
        Write-Host "  [$($i+1)] $($Packages[$i].Name) - $($Packages[$i].LastWriteTime)" -ForegroundColor White
    }
    
    do {
        $selection = Read-Host "`nSelect package (1-$($Packages.Count)) or 'Q' to quit"
        if ($selection -eq 'Q' -or $selection -eq 'q') {
            return $null
        }
        
        if ($selection -match '^\d+$' -and [int]$selection -ge 1 -and [int]$selection -le $Packages.Count) {
            return $Packages[[int]$selection - 1]
        }
        
        Write-Host "Invalid selection. Please try again." -ForegroundColor Yellow
    } while ($true)
}

function Expand-UpdatePackage {
    param(
        [System.IO.FileInfo]$Package
    )
    
    $extractPath = Join-Path $Global:ScriptDirectory "dump\$($Package.BaseName)"
    
    Write-Log "Extracting package to: $extractPath"
    
    if (Test-Path $extractPath) {
        Remove-Item -Path $extractPath -Recurse -Force
    }
    
    try {
        if ($PSVersionTable.PSVersion.Major -ge 5) {
            Expand-Archive -Path $Package.FullName -DestinationPath $extractPath -Force
        } else {
            # Fallback for older PowerShell versions
            $shell = New-Object -ComObject Shell.Application
            $zip = $shell.Namespace($Package.FullName)
            $destination = $shell.Namespace($extractPath)
            $destination.CopyHere($zip.Items(), 4)
        }
        
        Write-Log "Package extracted successfully"
        return $extractPath
    } catch {
        Write-Log "Failed to extract package: $($_.Exception.Message)" -Level ERROR
        return $null
    }
}

function Find-ReadmeFile {
    param([string]$Path)
    
    $readmeFiles = Get-ChildItem -Path $Path -Recurse -File | Where-Object {
        $_.Name -match '^readme\.(txt|pdf)$' -or 
        $_.Name -match '^installation\.(txt|pdf)$' -or
        $_.Name -match '^update\.(txt|pdf)$'
    }
    
    if ($readmeFiles) {
        $readme = $readmeFiles | Select-Object -First 1
        Write-Log "Found readme file: $($readme.Name)"
        return $readme
    }
    
    Write-Log "No readme file found" -Level WARNING
    return $null
}

function Process-ReadmeInstructions {
    param([System.IO.FileInfo]$ReadmeFile)
    
    Write-Log "Processing instructions from: $($ReadmeFile.Name)"
    
    # Load instruction dictionary
    $instructionPath = Join-Path $Global:ScriptDirectory "InstructionSet.json"
    if (-not (Test-Path $instructionPath)) {
        Write-Log "Instruction dictionary not found: $instructionPath" -Level ERROR
        return $false
    }
    
    $instructions = Get-Content $instructionPath -Raw | ConvertFrom-Json
    
    # Read readme content
    $content = Get-Content $ReadmeFile.FullName -Encoding UTF8
    $processedCommands = 0
    
    foreach ($line in $content) {
        $line = $line.Trim()
        if ([string]::IsNullOrEmpty($line) -or $line.StartsWith('#')) {
            continue
        }
        
        # Simple instruction matching (can be enhanced)
        foreach ($key in $instructions.PSObject.Properties.Name) {
            if ($line -match $key) {
                $command = $instructions.$key
                Write-Log "Executing: $command"
                
                if ($PSCmdlet.ShouldProcess($command, "Execute instruction")) {
                    try {
                        Invoke-Expression $command
                        $processedCommands++
                    } catch {
                        Write-Log "Command failed: $($_.Exception.Message)" -Level ERROR
                    }
                }
                break
            }
        }
    }
    
    Write-Log "Processed $processedCommands commands from readme"
    return $processedCommands -gt 0
}

function New-Backup {
    param([string]$SourcePath)
    
    if ($SkipBackup) {
        Write-Log "Backup skipped by parameter"
        return
    }
    
    $backupDir = Join-Path $Global:ScriptDirectory $Config.EvaSys.BackupDirectory
    if (-not (Test-Path $backupDir)) {
        New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
    }
    
    $backupName = "Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    $backupPath = Join-Path $backupDir $backupName
    
    Write-Log "Creating backup: $backupName"
    
    try {
        if (Test-Path $SourcePath) {
            Copy-Item -Path $SourcePath -Destination $backupPath -Recurse -Force
            Write-Log "Backup created successfully"
        }
    } catch {
        Write-Log "Backup failed: $($_.Exception.Message)" -Level WARNING
    }
}
#endregion

#region Main Execution
try {
    Set-EvaSysStatus -Status "UPDATE_STARTED" -Details @{
        PackagePath = $PackagePath
        AutoMode = $AutoMode.IsPresent
        SkipBackup = $SkipBackup.IsPresent
    }
    
    Write-Log "=== EvaSys Update Processing Started ==="
    
    if ($PackagePath) {
        if (-not (Test-Path $PackagePath)) {
            throw "Package file not found: $PackagePath"
        }
        $selectedPackage = Get-Item $PackagePath
    } else {
        # Get available packages
        $packages = Get-UpdatePackages
        if ($packages.Count -eq 0) {
            throw "No update packages found in update directory"
        }
        
        # Select package
        $selectedPackage = Select-UpdatePackage -Packages $packages
        if (-not $selectedPackage) {
            Write-Log "No package selected - exiting"
            return
        }
    }
    
    Write-Log "Processing package: $($selectedPackage.Name)"
    
    # Extract package
    $extractPath = Expand-UpdatePackage -Package $selectedPackage
    if (-not $extractPath) {
        throw "Failed to extract update package"
    }
    
    # Find readme file
    $readmeFile = Find-ReadmeFile -Path $extractPath
    if (-not $readmeFile) {
        Write-Log "No readme file found - manual processing required" -Level WARNING
    } else {
        # Create backup if needed
        New-Backup -SourcePath "." # Backup current state
        
        # Process instructions
        $success = Process-ReadmeInstructions -ReadmeFile $readmeFile
        
        if ($success) {
            Write-Log "Update processing completed successfully"
            Set-EvaSysStatus -Status "UPDATE_COMPLETED" -Details @{
                Package = $selectedPackage.Name
                Success = $true
            }
        } else {
            Write-Log "Update processing completed with warnings" -Level WARNING
            Set-EvaSysStatus -Status "UPDATE_COMPLETED_WITH_WARNINGS" -Details @{
                Package = $selectedPackage.Name
                Success = $false
            }
        }
    }
    
    # Send notification
    Send-EvaSysNotification -UpdateStatus "COMPLETED" -PackageProcessed $selectedPackage.Name -ResultSummary "Success"
    
    Write-Log "=== EvaSys Update Processing Finished ==="
    
} catch {
    $errorMessage = "Update processing failed: $($_.Exception.Message)"
    Write-Log $errorMessage -Level ERROR
    
    Set-EvaSysStatus -Status "UPDATE_FAILED" -Details @{
        Error = $errorMessage
    }
    
    Send-EvaSysNotification -UpdateStatus "FAILED" -PackageProcessed $selectedPackage.Name -ResultSummary $errorMessage
    
    exit 1
}
#endregion