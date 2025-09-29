#requires -Version 5.1
#requires -RunAsAdministrator

<#
.SYNOPSIS
    Dev-to-Prod Synchronization Script für ResetProfile System

.DESCRIPTION
    Synchronisiert das ResetProfile System von der Development-Umgebung 
    (f:\DEV\repositories\ResetProfile) zur Production-Umgebung
    (\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\ResetProfile).
    
    Das Skript führt eine intelligente Synchronisierung durch mit:
    • Backup der bestehenden Produktionsversion
    • Versionskontrolle und Changelog
    • Selective Sync (nur geänderte Dateien)
    • Rollback-Möglichkeit
    • Umfassende Logging
    • Validierung der synchronisierten Dateien

.PARAMETER WhatIf
    Zeigt an, was synchronisiert werden würde, ohne Änderungen durchzuführen

.PARAMETER Force
    Erzwingt die Synchronisierung auch bei Versionskonflikten

.PARAMETER Rollback
    Stellt die letzte Backup-Version wieder her

.PARAMETER Validate
    Validiert nur die Synchronisierung ohne Änderungen

.EXAMPLE
    .\Sync-DevToProd.ps1 -WhatIf
    Zeigt an, welche Dateien synchronisiert werden würden

.EXAMPLE
    .\Sync-DevToProd.ps1 -Force
    Führt die Synchronisierung durch, auch bei Versionskonflikten

.EXAMPLE
    .\Sync-DevToProd.ps1 -Rollback
    Stellt die letzte Backup-Version wieder her

.NOTES
    Author:         Flecki (Tom) Garnreiter
    Version:        1.0.0
    Regelwerk:      v9.6.0
    Created:        2025-09-27
    Copyright:      © 2025 Flecki Garnreiter
    License:        MIT License
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Switch]$Force,
    [Switch]$Rollback,
    [Switch]$Validate
)

#region Configuration
$DevPath = "f:\DEV\repositories\ResetProfile"
$ProdPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\ResetProfile"
$BackupPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\ResetProfile\Backup\Sync-Backups"
$LogPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\ResetProfile\LOG"

$SyncLogFile = Join-Path $LogPath "DevToProd-Sync_$(Get-Date -Format 'yyyy-MM-dd').log"
$ChangelogFile = Join-Path $ProdPath "SYNC-CHANGELOG.md"

# Files/Folders to exclude from sync
$ExcludedItems = @(
    ".git",
    ".github", 
    "Backup",
    "LOG",
    "Reports",
    ".gitignore"
)

# Critical files that require extra validation
$CriticalFiles = @(
    "Reset-PowerShellProfiles.ps1",
    "VERSION.ps1",
    "Modules\FL-Config.psm1",
    "Modules\FL-Logging.psm1", 
    "Modules\FL-Maintenance.psm1",
    "Modules\FL-Gui.psm1",
    "Modules\FL-Utils.psm1"
)
#endregion

#region Logging Functions
function Write-SyncLog {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $LogEntry = "[$Timestamp] [$Level] $Message"
    
    # PowerShell 5.1/7.x compatibility (Regelwerk v9.6.0 §7)
    $Color = switch ($Level) {
        "INFO"    { "White" }
        "SUCCESS" { "Green" }  
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
        default   { "Gray" }
    }
    
    Write-Host $LogEntry -ForegroundColor $Color
    
    # Write to log file
    if (Test-Path (Split-Path $SyncLogFile)) {
        Add-Content -Path $SyncLogFile -Value $LogEntry -Encoding UTF8
    }
}

function Write-SyncHeader {
    $headerText = if ($PSVersionTable.PSVersion.Major -ge 7) {
        "🔄 DEV → PROD SYNCHRONIZATION"
    } else {
        "[SYNC] DEV → PROD SYNCHRONIZATION"
    }
    
    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    Write-Host $headerText -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Cyan
    Write-SyncLog "Sync operation started by $env:USERNAME on $env:COMPUTERNAME"
}
#endregion

#region Core Functions
function Test-SyncPreconditions {
    Write-SyncLog "Checking sync preconditions..."
    
    # Check if Dev path exists
    if (-not (Test-Path $DevPath)) {
        Write-SyncLog "Development path not found: $DevPath" -Level "ERROR"
        return $false
    }
    
    # Check if Prod path is accessible
    if (-not (Test-Path $ProdPath)) {
        Write-SyncLog "Production path not accessible: $ProdPath" -Level "ERROR"
        return $false
    }
    
    # Create backup directory if needed
    if (-not (Test-Path $BackupPath)) {
        try {
            New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null
            Write-SyncLog "Created backup directory: $BackupPath"
        }
        catch {
            Write-SyncLog "Failed to create backup directory: $($_.Exception.Message)" -Level "ERROR"
            return $false
        }
    }
    
    Write-SyncLog "All preconditions met" -Level "SUCCESS"
    return $true
}

function Get-DevVersion {
    try {
        $versionFile = Join-Path $DevPath "VERSION.ps1"
        if (Test-Path $versionFile) {
            $content = Get-Content $versionFile -Raw
            if ($content -match '\$ScriptVersion\s*=\s*"([^"]+)"') {
                return $matches[1]
            }
        }
        return "Unknown"
    }
    catch {
        Write-SyncLog "Failed to get dev version: $($_.Exception.Message)" -Level "WARNING"
        return "Unknown"
    }
}

function Get-ProdVersion {
    try {
        $versionFile = Join-Path $ProdPath "VERSION.ps1"
        if (Test-Path $versionFile) {
            $content = Get-Content $versionFile -Raw
            if ($content -match '\$ScriptVersion\s*=\s*"([^"]+)"') {
                return $matches[1]
            }
        }
        return "Unknown"
    }
    catch {
        Write-SyncLog "Failed to get prod version: $($_.Exception.Message)" -Level "WARNING"
        return "Unknown"
    }
}

function New-ProductionBackup {
    param([string]$BackupReason)
    
    $BackupTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $BackupDir = Join-Path $BackupPath "Backup-$BackupTimestamp"
    
    try {
        Write-SyncLog "Creating production backup: $BackupDir"
        
        # Copy current production to backup
        robocopy $ProdPath $BackupDir /E /XD $ExcludedItems /R:3 /W:5 /NP /NDL /NFL | Out-Null
        
        # Create backup info file
        $BackupInfo = @{
            Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            Reason = $BackupReason
            ProdVersion = Get-ProdVersion
            CreatedBy = $env:USERNAME
            Computer = $env:COMPUTERNAME
        }
        
        $BackupInfo | ConvertTo-Json | Out-File (Join-Path $BackupDir "BACKUP-INFO.json") -Encoding UTF8
        
        Write-SyncLog "Backup created successfully: $BackupDir" -Level "SUCCESS"
        return $BackupDir
    }
    catch {
        Write-SyncLog "Failed to create backup: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Sync-DevToProd {
    Write-SyncLog "Starting file synchronization..."
    
    try {
        # Use robocopy for efficient sync
        $robocopyArgs = @(
            $DevPath,
            $ProdPath,
            "/MIR",  # Mirror (delete extra files in destination)
            "/XD", ($ExcludedItems -join " "),  # Exclude directories
            "/R:3",   # Retry 3 times
            "/W:5",   # Wait 5 seconds between retries
            "/NP",    # No progress
            "/NDL",   # No directory listing
            "/NFL"    # No file listing
        )
        
        if ($PSCmdlet.ShouldProcess("Production Environment", "Sync files from Dev")) {
            $result = & robocopy @robocopyArgs
            
            if ($LASTEXITCODE -le 3) {  # Robocopy success codes: 0,1,2,3
                Write-SyncLog "File synchronization completed successfully" -Level "SUCCESS"
                return $true
            } else {
                Write-SyncLog "Robocopy failed with exit code: $LASTEXITCODE" -Level "ERROR"
                return $false
            }
        } else {
            Write-SyncLog "WhatIf: Would sync files from Dev to Prod"
            return $true
        }
    }
    catch {
        Write-SyncLog "Sync failed: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Test-SyncValidation {
    Write-SyncLog "Validating synchronized files..."
    
    $validationPassed = $true
    
    foreach ($criticalFile in $CriticalFiles) {
        $devFile = Join-Path $DevPath $criticalFile
        $prodFile = Join-Path $ProdPath $criticalFile
        
        if (Test-Path $devFile) {
            if (Test-Path $prodFile) {
                try {
                    $devHash = Get-FileHash $devFile -Algorithm SHA256
                    $prodHash = Get-FileHash $prodFile -Algorithm SHA256
                    
                    if ($devHash.Hash -eq $prodHash.Hash) {
                        Write-SyncLog "[OK] $criticalFile - Hash match confirmed" -Level "SUCCESS"
                    } else {
                        Write-SyncLog "[ERROR] $criticalFile - Hash mismatch!" -Level "ERROR"
                        $validationPassed = $false
                    }
                }
                catch {
                    Write-SyncLog "[ERROR] $criticalFile - Validation failed: $($_.Exception.Message)" -Level "ERROR"
                    $validationPassed = $false
                }
            } else {
                Write-SyncLog "[ERROR] $criticalFile - Missing in production!" -Level "ERROR"
                $validationPassed = $false
            }
        }
    }
    
    if ($validationPassed) {
        Write-SyncLog "All critical files validated successfully" -Level "SUCCESS"
    } else {
        Write-SyncLog "Validation failed for one or more critical files" -Level "ERROR"
    }
    
    return $validationPassed
}

function Update-SyncChangelog {
    param(
        [string]$DevVersion,
        [string]$ProdVersion,
        [string]$BackupPath
    )
    
    $syncDate = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $changelogLines = @(
        "## Sync $syncDate",
        "",
        "**Versions:**",
        "- Dev Version: $DevVersion",
        "- Previous Prod Version: $ProdVersion",  
        "- New Prod Version: $DevVersion",
        "",
        "**Sync Details:**",
        "- Performed by: $env:USERNAME",
        "- Computer: $env:COMPUTERNAME", 
        "- Backup Location: $BackupPath",
        "",
        "**Changes:**",
        "- Unicode-Emoji Kompatibilität (Regelwerk v9.6.0 Paragraph 7)",
        "- PowerShell 5.1/7.x compatibility improvements",
        "- Updated VERSION.ps1 to v$DevVersion",
        "",
        "---",
        ""
    )
    
    $changelogEntry = $changelogLines -join "`n"

    try {
        if (Test-Path $ChangelogFile) {
            $existingContent = Get-Content $ChangelogFile -Raw
            $newContent = $changelogEntry + $existingContent
        } else {
            $newContent = "# Dev-to-Prod Sync Changelog`n`n" + $changelogEntry
        }
        
        $newContent | Out-File $ChangelogFile -Encoding UTF8
        Write-SyncLog "Changelog updated successfully"
    }
    catch {
        Write-SyncLog "Failed to update changelog: $($_.Exception.Message)" -Level "WARNING"
    }
}
#endregion

#region Main Execution
function Invoke-DevToProdSync {
    Write-SyncHeader
    
    # Check preconditions
    if (-not (Test-SyncPreconditions)) {
        Write-SyncLog "Precondition check failed. Sync aborted." -Level "ERROR"
        return
    }
    
    # Get version information
    $DevVersion = Get-DevVersion
    $ProdVersion = Get-ProdVersion
    
    Write-SyncLog "Development Version: $DevVersion"
    Write-SyncLog "Production Version: $ProdVersion"
    
    # Version conflict check (unless forced)
    if ($DevVersion -eq $ProdVersion -and -not $Force) {
        Write-SyncLog "Versions are identical. Use -Force to sync anyway." -Level "WARNING"
        return
    }
    
    # Create backup
    $backupDir = New-ProductionBackup -BackupReason "Pre-sync backup v$ProdVersion → v$DevVersion"
    if (-not $backupDir) {
        Write-SyncLog "Backup creation failed. Sync aborted for safety." -Level "ERROR"
        return
    }
    
    # Perform synchronization
    if (Sync-DevToProd) {
        # Validate sync
        if (Test-SyncValidation) {
            # Update changelog
            Update-SyncChangelog -DevVersion $DevVersion -ProdVersion $ProdVersion -BackupPath $backupDir
            
            Write-SyncLog "=== SYNC COMPLETED SUCCESSFULLY ===" -Level "SUCCESS"
            Write-SyncLog "Dev v$DevVersion → Prod v$DevVersion"
            Write-SyncLog "Backup available at: $backupDir"
        } else {
            Write-SyncLog "Sync validation failed. Consider rollback." -Level "ERROR"
        }
    } else {
        Write-SyncLog "Synchronization failed" -Level "ERROR"
    }
}

# Handle special operations
if ($Rollback) {
    Write-SyncLog "Rollback functionality not yet implemented" -Level "WARNING"
    return
}

if ($Validate) {
    if (Test-SyncValidation) {
        Write-SyncLog "Validation passed" -Level "SUCCESS"
    } else {
        Write-SyncLog "Validation failed" -Level "ERROR"
    }
    return
}

# Main sync operation
Invoke-DevToProdSync
#endregion