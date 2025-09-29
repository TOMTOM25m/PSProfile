#Requires -Version 5.1

#region PowerShell Version Detection (MANDATORY - # Script version information
$Global:ScriptVersion = "v1.3.0"
$Global:RulebookVersion = "v9.5.0"
$Global:ScriptName = "GitSyncService"lwerk v9.5.0)
$PSVersion = $PSVersionTable.PSVersion
$IsPS7Plus = $PSVersion.Major -ge 7
$IsPS5 = $PSVersion.Major -eq 5
$IsPS51 = $PSVersion.Major -eq 5 -and $PSVersion.Minor -eq 1

Write-Verbose "GitSyncService - PowerShell Version: $($PSVersion.ToString())"
Write-Verbose "Compatibility Mode: $(if($IsPS7Plus){'PowerShell 7.x Enhanced'}elseif($IsPS51){'PowerShell 5.1 Compatible'}else{'PowerShell 5.x Standard'})"
#endregion

<#
.SYNOPSIS
    Git Repository Synchronization Service - Multi-Repository Management
    
.DESCRIPTION
    [DE] Zentraler Service fuer die Synchronisation mehrerer Git-Repositories.
         Automatisiert Pull-, Push- und Merge-Operationen mit Konflikt-Management.
    [EN] Central service for synchronizing multiple Git repositories.
         Automates pull, push, and merge operations with conflict management.
    
.PARAMETER RepositoryPath
    [DE] Pfad zum Git-Repository (Standard: aktuelles Verzeichnis)
    [EN] Path to Git repository (default: current directory)
    
.PARAMETER Action
    [DE] Aktion: Sync, Pull, Push, Status, Clone
    [EN] Action: Sync, Pull, Push, Status, Clone
    
.PARAMETER Branch
    [DE] Branch-Name (Standard: main)
    [EN] Branch name (default: main)
    
.PARAMETER RemoteUrl
    [DE] Remote-URL fuer Clone-Operation
    [EN] Remote URL for clone operation
    
.EXAMPLE
    .\GitSyncService.ps1 -Action Sync
    [DE] Synchronisiert das aktuelle Repository
    [EN] Synchronizes the current repository
    
.EXAMPLE
    .\GitSyncService.ps1 -Action Status -RepositoryPath "f:\DEV\repositories\CertSurv"
    [DE] Zeigt den Status des angegebenen Repositories
    [EN] Shows status of the specified repository
    
.NOTES
    Version:        v1.3.0
    Author:         Flecki (Tom) Garnreiter
    Datum:          2025-09-23
    Regelwerk:      v9.5.0 (File Operations + Script Versioning Standards)
    [DE] Vollstaendig ASCII-kompatibel fuer universelle PowerShell-Unterstuetzung
    [EN] Fully ASCII-compatible for universal PowerShell support
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$RepositoryPath = (Get-Location).Path,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("Sync", "Pull", "Push", "Status", "Clone", "Branch", "Commit")]
    [string]$Action,
    
    [Parameter(Mandatory=$false)]
    [string]$Branch = "main",
    
    [Parameter(Mandatory=$false)]
    [string]$RemoteUrl = "",
    
    [Parameter(Mandatory=$false)]
    [string]$CommitMessage = "Automated sync via GitSyncService"
)

# Script version information
$Global:ScriptVersion = "v1.2.0"
$Global:RulebookVersion = "v9.5.0"
$Global:ScriptName = "GitSyncService"

#----------------------------------------------------------[Functions]----------------------------------------------------------

function Show-GitSyncBanner {
    param([string]$Action, [string]$Repository)
    
    $banner = @"

[CONFIG] ================================================================
[CONFIG] Git Repository Synchronization Service v$Global:ScriptVersion
[CONFIG] ================================================================
[CONFIG] Repository: $Repository
[CONFIG] Action: $Action
[CONFIG] Branch: $Branch  
[CONFIG] PowerShell: $($PSVersion.ToString())
[CONFIG] ================================================================

"@
    Write-Host $banner -ForegroundColor Cyan
}

function Test-GitRepository {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        Write-Host "[FAIL] Repository path does not exist: $Path" -ForegroundColor Red
        return $false
    }
    
    $gitPath = Join-Path $Path ".git"
    if (-not (Test-Path $gitPath)) {
        Write-Host "[FAIL] Not a Git repository: $Path" -ForegroundColor Red
        return $false
    }
    
    Write-Host "[OK] Valid Git repository detected" -ForegroundColor Green
    return $true
}

function Invoke-GitCommand {
    param(
        [string]$Command,
        [string]$WorkingDirectory = $RepositoryPath,
        [switch]$IgnoreErrors
    )
    
    try {
        Push-Location $WorkingDirectory
        Write-Host "[INFO] Executing: git $Command" -ForegroundColor Yellow
        
        $result = & git $Command.Split(' ') 2>&1
        
        if ($LASTEXITCODE -eq 0 -or $IgnoreErrors) {
            Write-Host "[OK] Git command successful" -ForegroundColor Green
            if ($result) {
                Write-Host "Output: $result" -ForegroundColor Gray
            }
            return $result
        } else {
            Write-Host "[FAIL] Git command failed (Exit Code: $LASTEXITCODE)" -ForegroundColor Red
            Write-Host "Error: $result" -ForegroundColor Red
            return $null
        }
    }
    catch {
        Write-Host "[FAIL] Git command exception: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
    finally {
        Pop-Location
    }
}

function Get-GitStatus {
    param([string]$Path)
    
    Write-Host "[INFO] Repository Status Analysis:" -ForegroundColor Cyan
    
    # Current branch
    $currentBranch = Invoke-GitCommand "branch --show-current" -WorkingDirectory $Path
    Write-Host "   Current Branch: $currentBranch" -ForegroundColor White
    
    # Repository status
    $status = Invoke-GitCommand "status --porcelain" -WorkingDirectory $Path
    if ($status) {
        Write-Host "   [WARN] Repository has uncommitted changes:" -ForegroundColor Yellow
        $status | ForEach-Object { Write-Host "     $_" -ForegroundColor Gray }
    } else {
        Write-Host "   [OK] Repository is clean" -ForegroundColor Green
    }
    
    # Remote status
    $remote = Invoke-GitCommand "remote -v" -WorkingDirectory $Path
    if ($remote) {
        Write-Host "   Remote Origins:" -ForegroundColor White
        $remote | ForEach-Object { Write-Host "     $_" -ForegroundColor Gray }
    }
    
    # Last commit
    $lastCommit = Invoke-GitCommand "log -1 --oneline" -WorkingDirectory $Path
    Write-Host "   Last Commit: $lastCommit" -ForegroundColor White
}

function Sync-GitRepository {
    param([string]$Path, [string]$TargetBranch)
    
    Write-Host "[INFO] Starting repository synchronization..." -ForegroundColor Cyan
    
    # Fetch latest changes
    Write-Host "[INFO] Fetching latest changes..." -ForegroundColor Yellow
    $fetchResult = Invoke-GitCommand "fetch origin" -WorkingDirectory $Path
    
    if ($fetchResult -eq $null) {
        Write-Host "[FAIL] Failed to fetch from remote" -ForegroundColor Red
        return $false
    }
    
    # Check for local changes
    $status = Invoke-GitCommand "status --porcelain" -WorkingDirectory $Path
    if ($status) {
        Write-Host "[WARN] Repository has uncommitted changes. Stashing..." -ForegroundColor Yellow
        Invoke-GitCommand "stash push -m 'Auto-stash by GitSyncService'" -WorkingDirectory $Path
    }
    
    # Switch to target branch
    Write-Host "[INFO] Switching to branch: $TargetBranch" -ForegroundColor Yellow
    $checkoutResult = Invoke-GitCommand "checkout $TargetBranch" -WorkingDirectory $Path
    
    # Pull latest changes
    Write-Host "[INFO] Pulling latest changes..." -ForegroundColor Yellow
    $pullResult = Invoke-GitCommand "pull origin $TargetBranch" -WorkingDirectory $Path
    
    if ($pullResult -eq $null) {
        Write-Host "[FAIL] Failed to pull latest changes" -ForegroundColor Red
        return $false
    }
    
    # Restore stashed changes if any
    $stashList = Invoke-GitCommand "stash list" -WorkingDirectory $Path
    if ($stashList -and $stashList -like "*Auto-stash by GitSyncService*") {
        Write-Host "[INFO] Restoring stashed changes..." -ForegroundColor Yellow
        Invoke-GitCommand "stash pop" -WorkingDirectory $Path
    }
    
    Write-Host "[SUCCESS] Repository synchronization completed!" -ForegroundColor Green
    return $true
}

function Push-GitChanges {
    param([string]$Path, [string]$TargetBranch, [string]$Message)
    
    Write-Host "[INFO] Starting push operation..." -ForegroundColor Cyan
    
    # Check for changes to commit
    $status = Invoke-GitCommand "status --porcelain" -WorkingDirectory $Path
    if (-not $status) {
        Write-Host "[INFO] No changes to commit" -ForegroundColor Yellow
        return $true
    }
    
    # Add all changes
    Write-Host "[INFO] Adding changes..." -ForegroundColor Yellow
    Invoke-GitCommand "add ." -WorkingDirectory $Path
    
    # Commit changes
    Write-Host "[INFO] Committing changes..." -ForegroundColor Yellow
    $commitResult = Invoke-GitCommand "commit -m `"$Message`"" -WorkingDirectory $Path
    
    # Push to remote
    Write-Host "[INFO] Pushing to remote..." -ForegroundColor Yellow
    $pushResult = Invoke-GitCommand "push origin $TargetBranch" -WorkingDirectory $Path
    
    if ($pushResult -eq $null) {
        Write-Host "[FAIL] Failed to push changes" -ForegroundColor Red
        return $false
    }
    
    Write-Host "[SUCCESS] Changes pushed successfully!" -ForegroundColor Green
    return $true
}

function Clone-GitRepository {
    param([string]$RemoteUrl, [string]$LocalPath)
    
    Write-Host "[INFO] Cloning repository..." -ForegroundColor Cyan
    Write-Host "   From: $RemoteUrl" -ForegroundColor White
    Write-Host "   To: $LocalPath" -ForegroundColor White
    
    $cloneResult = Invoke-GitCommand "clone $RemoteUrl `"$LocalPath`"" -WorkingDirectory (Split-Path $LocalPath -Parent)
    
    if ($cloneResult -eq $null) {
        Write-Host "[FAIL] Failed to clone repository" -ForegroundColor Red
        return $false
    }
    
    Write-Host "[SUCCESS] Repository cloned successfully!" -ForegroundColor Green
    return $true
}

#----------------------------------------------------------[Main Execution]----------------------------------------------------------

try {
    Show-GitSyncBanner -Action $Action -Repository $RepositoryPath
    
    # Validate Git installation
    $gitVersion = Invoke-GitCommand "version" -IgnoreErrors
    if (-not $gitVersion) {
        Write-Host "[FAIL] Git is not installed or not accessible" -ForegroundColor Red
        exit 1
    }
    Write-Host "[OK] Git detected: $gitVersion" -ForegroundColor Green
    
    # Execute requested action
    $success = switch ($Action) {
        "Status" {
            if (Test-GitRepository $RepositoryPath) {
                Get-GitStatus -Path $RepositoryPath
                $true
            } else { $false }
        }
        "Sync" {
            if (Test-GitRepository $RepositoryPath) {
                Sync-GitRepository -Path $RepositoryPath -TargetBranch $Branch
            } else { $false }
        }
        "Pull" {
            if (Test-GitRepository $RepositoryPath) {
                Write-Host "[INFO] Pulling latest changes..." -ForegroundColor Yellow
                $result = Invoke-GitCommand "pull origin $Branch" -WorkingDirectory $RepositoryPath
                $result -ne $null
            } else { $false }
        }
        "Push" {
            if (Test-GitRepository $RepositoryPath) {
                Push-GitChanges -Path $RepositoryPath -TargetBranch $Branch -Message $CommitMessage
            } else { $false }
        }
        "Clone" {
            if ($RemoteUrl) {
                Clone-GitRepository -RemoteUrl $RemoteUrl -LocalPath $RepositoryPath
            } else {
                Write-Host "[FAIL] RemoteUrl parameter required for clone operation" -ForegroundColor Red
                $false
            }
        }
        "Branch" {
            if (Test-GitRepository $RepositoryPath) {
                Write-Host "[INFO] Branch information:" -ForegroundColor Cyan
                Invoke-GitCommand "branch -a" -WorkingDirectory $RepositoryPath
                $true
            } else { $false }
        }
        "Commit" {
            if (Test-GitRepository $RepositoryPath) {
                Write-Host "[INFO] Recent commits:" -ForegroundColor Cyan
                Invoke-GitCommand "log --oneline -10" -WorkingDirectory $RepositoryPath
                $true
            } else { $false }
        }
    }
    
    if ($success) {
        Write-Host "`n[SUCCESS] Git operation '$Action' completed successfully!" -ForegroundColor Green
    } else {
        Write-Host "`n[FAIL] Git operation '$Action' failed!" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "`n[FAIL] GitSyncService error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n[INFO] GitSyncService v$Global:ScriptVersion operation completed" -ForegroundColor Gray

# --- End of Script --- v1.3.0 ; Regelwerk: v9.5.0 ; PowerShell: $($PSVersion.ToString()) ---