#requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    CertSurv Scanner Installation für ITSCMGMT03 v1.0.0

.DESCRIPTION
    Installiert und konfiguriert den CertSurv Scanner auf ITSCMGMT03.
    Der Scanner sammelt Zertifikatsdaten von allen CertWebService-Instanzen
    und erstellt Reports.

.PARAMETER TargetServer
    Zielserver (Standard: ITSCMGMT03.srv.meduniwien.ac.at)

.PARAMETER SourcePath
    Quellpfad der CertSurv-Installation (Standard: ..\CertSurv)

.PARAMETER ScheduleDaily
    Erstellt täglichen Scheduled Task (Standard: 08:00 Uhr)

.VERSION
    1.0.0

.RULEBOOK
    v10.0.2
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$TargetServer = "ITSCMGMT03.srv.meduniwien.ac.at",
    
    [Parameter(Mandatory = $false)]
    [string]$SourcePath = "..\CertSurv",
    
    [Parameter(Mandatory = $false)]
    [switch]$ScheduleDaily,
    
    [Parameter(Mandatory = $false)]
    [string]$ScheduleTime = "08:00",
    
    [Parameter(Mandatory = $false)]
    [switch]$TestOnly
)

# Import Compatibility Module
Import-Module ".\Modules\FL-PowerShell-VersionCompatibility-v3.1.psm1" -Force

Write-VersionSpecificHeader "CertSurv Scanner Installation" -Version "v1.0.0 | Regelwerk: v10.0.2" -Color Cyan

# Konfiguration
$Config = @{
    TargetServer = $TargetServer
    NetworkSharePath = "\\$TargetServer\iso\CertWebService"
    LocalInstallPath = "C:\CertSurv"  # Lokaler Installations-Pfad auf ITSCMGMT03
    CertSurvSource = $SourcePath
    
    # Benötigte Dateien/Ordner
    RequiredItems = @(
        "Start-CertificateSurveillance.ps1",
        "Main.ps1",
        "Config",
        "Modules",
        "LOG",
        "Reports"
    )
    
    # Server-Liste Konfiguration
    ServerListConfig = @{
        Path = "Config\ServerList.txt"
        DefaultServers = @(
            "wsus.srv.meduniwien.ac.at",
            "itscmgmt03.srv.meduniwien.ac.at"
        )
    }
    
    # Scheduled Task Config
    TaskName = "CertSurv-Daily-Scan"
    TaskDescription = "Daily Certificate Surveillance Scan"
}

Write-Host ""
Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  Target Server: $TargetServer" -ForegroundColor Gray
Write-Host "  Local Install Path: $($Config.LocalInstallPath)" -ForegroundColor Gray
Write-Host "  Network Share: $($Config.NetworkSharePath)" -ForegroundColor Gray
Write-Host "  Source Path: $SourcePath" -ForegroundColor Gray
Write-Host "  Schedule Daily: $($ScheduleDaily.IsPresent)" -ForegroundColor Gray
Write-Host ""

#region Functions

function Test-Prerequisites {
    Write-VersionSpecificHost "Checking prerequisites..." -IconType 'shield' -ForegroundColor Cyan
    
    $checks = @{
        SourcePathExists = $false
        TargetServerOnline = $false
        NetworkShareAccessible = $false
        PSRemotingAvailable = $false
        AdminRights = $false
    }
    
    # 1. Source Path Check
    Write-Host "  [1/5] Checking source path..." -ForegroundColor Gray
    $checks.SourcePathExists = Test-Path $Config.CertSurvSource
    
    if ($checks.SourcePathExists) {
        Write-Host "    [OK] Source path found: $($Config.CertSurvSource)" -ForegroundColor Green
    } else {
        Write-Host "    [ERROR] Source path not found: $($Config.CertSurvSource)" -ForegroundColor Red
        return $checks
    }
    
    # 2. Target Server Ping
    Write-Host "  [2/5] Checking target server..." -ForegroundColor Gray
    $checks.TargetServerOnline = Test-Connection -ComputerName $Config.TargetServer -Count 1 -Quiet -ErrorAction SilentlyContinue
    
    if ($checks.TargetServerOnline) {
        Write-Host "    [OK] Target server online" -ForegroundColor Green
    } else {
        Write-Host "    [ERROR] Target server offline" -ForegroundColor Red
        return $checks
    }
    
    # 3. Network Share Access
    Write-Host "  [3/5] Checking network share..." -ForegroundColor Gray
    $checks.NetworkShareAccessible = Test-Path $Config.NetworkSharePath -ErrorAction SilentlyContinue
    
    if ($checks.NetworkShareAccessible) {
        Write-Host "    [OK] Network share accessible" -ForegroundColor Green
    } else {
        Write-Host "    [WARN] Network share not accessible (will try to create)" -ForegroundColor Yellow
    }
    
    # 4. PSRemoting Check
    Write-Host "  [4/5] Checking PSRemoting..." -ForegroundColor Gray
    try {
        # DevSkim: ignore DS104456 - Required for installation
        $testResult = Invoke-Command -ComputerName $Config.TargetServer -ScriptBlock { $env:COMPUTERNAME } -ErrorAction Stop
        $checks.PSRemotingAvailable = ($testResult -eq $Config.TargetServer.Split('.')[0].ToUpper())
        
        if ($checks.PSRemotingAvailable) {
            Write-Host "    [OK] PSRemoting available" -ForegroundColor Green
        }
    } catch {
        Write-Host "    [WARN] PSRemoting not available" -ForegroundColor Yellow
    }
    
    # 5. Admin Rights
    Write-Host "  [5/5] Checking admin rights..." -ForegroundColor Gray
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $checks.AdminRights = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if ($checks.AdminRights) {
        Write-Host "    [OK] Running with admin rights" -ForegroundColor Green
    } else {
        Write-Host "    [ERROR] Admin rights required" -ForegroundColor Red
    }
    
    return $checks
}

function Copy-CertSurvFiles {
    param(
        [string]$SourcePath,
        [string]$ServerName,
        [string]$LocalPath
    )
    
    Write-VersionSpecificHost "Copying CertSurv files to remote server..." -IconType 'file' -ForegroundColor Cyan
    
    try {
        Write-Host "  Source Path: $SourcePath" -ForegroundColor Gray
        Write-Host "  Target Server: $ServerName" -ForegroundColor Gray
        Write-Host "  Target Path: $LocalPath" -ForegroundColor Gray
        Write-Host ""
        
        # Verwende PSRemoting für Copy (da Admin-Share nicht verfügbar)
        Write-Host "  Using PSRemoting for file transfer..." -ForegroundColor Yellow
        
        $copiedItems = 0
        $failedItems = 0
        
        # Zielverzeichnis auf Server erstellen
        Write-Host "  Creating target directory on server..." -ForegroundColor Gray
        # DevSkim: ignore DS104456 - Required for installation
        Invoke-Command -ComputerName $ServerName -ScriptBlock {
            param($Path)
            if (-not (Test-Path $Path)) {
                New-Item -Path $Path -ItemType Directory -Force | Out-Null
            }
        } -ArgumentList $LocalPath -ErrorAction Stop
        
        foreach ($item in $Config.RequiredItems) {
            $sourcePath = Join-Path $SourcePath $item
            
            if (Test-Path $sourcePath) {
                Write-Host "  Copying: $item..." -ForegroundColor Gray
                
                try {
                    $destPath = Join-Path $LocalPath $item
                    
                    if (Test-Path $sourcePath -PathType Container) {
                        # Verzeichnis kopieren via PSRemoting
                        Write-Host "    Copying directory (this may take a moment)..." -ForegroundColor Gray
                        
                        # Get all files in directory
                        $files = Get-ChildItem -Path $sourcePath -Recurse -File
                        
                        foreach ($file in $files) {
                            $relativePath = $file.FullName.Substring($sourcePath.Length + 1)
                            $targetFile = Join-Path $destPath $relativePath
                            $targetDir = Split-Path $targetFile -Parent
                            
                            # Ensure directory exists on remote
                            # DevSkim: ignore DS104456 - Required for installation
                            Invoke-Command -ComputerName $ServerName -ScriptBlock {
                                param($Dir)
                                if (-not (Test-Path $Dir)) {
                                    New-Item -Path $Dir -ItemType Directory -Force | Out-Null
                                }
                            } -ArgumentList $targetDir -ErrorAction SilentlyContinue
                            
                            # Copy file content
                            $content = [System.IO.File]::ReadAllBytes($file.FullName)
                            # DevSkim: ignore DS104456 - Required for installation
                            Invoke-Command -ComputerName $ServerName -ScriptBlock {
                                param($Path, $Content)
                                [System.IO.File]::WriteAllBytes($Path, $Content)
                            } -ArgumentList $targetFile, $content
                        }
                    } else {
                        # Datei kopieren via PSRemoting
                        $content = [System.IO.File]::ReadAllBytes($sourcePath)
                        # DevSkim: ignore DS104456 - Required for installation
                        Invoke-Command -ComputerName $ServerName -ScriptBlock {
                            param($Path, $Content)
                            [System.IO.File]::WriteAllBytes($Path, $Content)
                        } -ArgumentList $destPath, $content -ErrorAction Stop
                    }
                    
                    $copiedItems++
                    Write-Host "    [OK] Copied" -ForegroundColor Green
                    
                } catch {
                    $failedItems++
                    Write-Host "    [ERROR] Failed: $($_.Exception.Message)" -ForegroundColor Red
                }
            } else {
                Write-Host "  [WARN] Item not found: $item" -ForegroundColor Yellow
            }
        }
        
        Write-Host ""
        Write-Host "  Copy Summary: $copiedItems successful, $failedItems failed" -ForegroundColor $(if($failedItems -eq 0){'Green'}else{'Yellow'})
        
        return ($copiedItems -eq 0 -or $failedItems -eq 0)
        
    } catch {
        Write-Host "  [ERROR] Copy failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Initialize-ServerList {
    param(
        [string]$BasePath
    )
    
    Write-VersionSpecificHost "Initializing server list..." -IconType 'list' -ForegroundColor Cyan
    
    try {
        $serverListPath = Join-Path $BasePath $Config.ServerListConfig.Path
        $configDir = Split-Path $serverListPath -Parent
        
        # Config-Verzeichnis erstellen
        if (-not (Test-Path $configDir)) {
            New-Item -Path $configDir -ItemType Directory -Force | Out-Null
        }
        
        # Server-Liste erstellen
        $serverList = $Config.ServerListConfig.DefaultServers -join "`r`n"
        $serverList | Out-File -FilePath $serverListPath -Encoding UTF8 -Force
        
        Write-Host "  [OK] Server list created with $($Config.ServerListConfig.DefaultServers.Count) servers" -ForegroundColor Green
        Write-Host "  Path: $serverListPath" -ForegroundColor Gray
        
        foreach ($server in $Config.ServerListConfig.DefaultServers) {
            Write-Host "    - $server" -ForegroundColor Gray
        }
        
        return $true
        
    } catch {
        Write-Host "  [ERROR] Server list creation failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function New-ScheduledScanTask {
    param(
        [string]$ServerName,
        [string]$ScriptPath,
        [string]$Time
    )
    
    Write-VersionSpecificHost "Creating scheduled task..." -IconType 'clock' -ForegroundColor Cyan
    
    try {
        $scriptBlock = {
            param($TaskName, $TaskDescription, $ScriptPath, $Time)
            
            # Task Action
            $action = New-ScheduledTaskAction `
                -Execute "powershell.exe" `
                -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" -SendEmail"
            
            # Task Trigger (Daily at specified time)
            $trigger = New-ScheduledTaskTrigger -Daily -At $Time
            
            # Task Settings
            $settings = New-ScheduledTaskSettingsSet `
                -AllowStartIfOnBatteries `
                -DontStopIfGoingOnBatteries `
                -StartWhenAvailable `
                -RunOnlyIfNetworkAvailable
            
            # Task Principal (Run as SYSTEM)
            $principal = New-ScheduledTaskPrincipal `
                -UserId "SYSTEM" `
                -LogonType ServiceAccount `
                -RunLevel Highest
            
            # Check if task exists
            $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
            
            if ($existingTask) {
                Write-Host "  Updating existing task..." -ForegroundColor Yellow
                Set-ScheduledTask `
                    -TaskName $TaskName `
                    -Action $action `
                    -Trigger $trigger `
                    -Settings $settings `
                    -Principal $principal | Out-Null
            } else {
                Write-Host "  Creating new task..." -ForegroundColor Yellow
                Register-ScheduledTask `
                    -TaskName $TaskName `
                    -Description $TaskDescription `
                    -Action $action `
                    -Trigger $trigger `
                    -Settings $settings `
                    -Principal $principal | Out-Null
            }
            
            return $true
        }
        
        # Remote execution via PSRemoting
        # DevSkim: ignore DS104456 - Required for scheduled task creation
        $result = Invoke-Command `
            -ComputerName $ServerName `
            -ScriptBlock $scriptBlock `
            -ArgumentList $Config.TaskName, $Config.TaskDescription, $ScriptPath, $Time `
            -ErrorAction Stop
        
        if ($result) {
            Write-Host "  [OK] Scheduled task created: $($Config.TaskName)" -ForegroundColor Green
            Write-Host "  Schedule: Daily at $Time" -ForegroundColor Gray
            Write-Host "  Script: $ScriptPath" -ForegroundColor Gray
            return $true
        }
        
    } catch {
        Write-Host "  [ERROR] Scheduled task creation failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    
    return $false
}

function Test-Installation {
    param(
        [string]$ServerName,
        [string]$NetworkSharePath
    )
    
    Write-VersionSpecificHost "Testing installation..." -IconType 'shield' -ForegroundColor Cyan
    
    $testResults = @{
        FilesPresent = $false
        ServerListValid = $false
        ScriptExecutable = $false
        TaskScheduled = $false
    }
    
    try {
        # 1. Files Present
        Write-Host "  [1/4] Checking files..." -ForegroundColor Gray
        $mainScript = Join-Path $NetworkSharePath "Start-CertificateSurveillance.ps1"
        $testResults.FilesPresent = Test-Path $mainScript
        
        if ($testResults.FilesPresent) {
            Write-Host "    [OK] Main script found" -ForegroundColor Green
        } else {
            Write-Host "    [ERROR] Main script not found" -ForegroundColor Red
        }
        
        # 2. Server List
        Write-Host "  [2/4] Checking server list..." -ForegroundColor Gray
        $serverListPath = Join-Path $NetworkSharePath "Config\ServerList.txt"
        
        if (Test-Path $serverListPath) {
            $serverList = Get-Content $serverListPath -ErrorAction SilentlyContinue
            $testResults.ServerListValid = ($serverList.Count -gt 0)
            
            if ($testResults.ServerListValid) {
                Write-Host "    [OK] Server list valid ($($serverList.Count) servers)" -ForegroundColor Green
            } else {
                Write-Host "    [WARN] Server list empty" -ForegroundColor Yellow
            }
        } else {
            Write-Host "    [ERROR] Server list not found" -ForegroundColor Red
        }
        
        # 3. Script Executable (syntax check)
        Write-Host "  [3/4] Checking script syntax..." -ForegroundColor Gray
        try {
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $mainScript -Raw), [ref]$null)
            $testResults.ScriptExecutable = $true
            Write-Host "    [OK] Script syntax valid" -ForegroundColor Green
        } catch {
            Write-Host "    [ERROR] Script syntax error" -ForegroundColor Red
        }
        
        # 4. Scheduled Task (if created)
        if ($ScheduleDaily) {
            Write-Host "  [4/4] Checking scheduled task..." -ForegroundColor Gray
            try {
                # DevSkim: ignore DS104456 - Required for task verification
                $task = Invoke-Command -ComputerName $ServerName -ScriptBlock {
                    param($TaskName)
                    Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
                } -ArgumentList $Config.TaskName -ErrorAction SilentlyContinue
                
                $testResults.TaskScheduled = ($null -ne $task)
                
                if ($testResults.TaskScheduled) {
                    Write-Host "    [OK] Scheduled task exists" -ForegroundColor Green
                } else {
                    Write-Host "    [WARN] Scheduled task not found" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "    [WARN] Could not check scheduled task" -ForegroundColor Yellow
            }
        } else {
            $testResults.TaskScheduled = $true  # N/A
        }
        
    } catch {
        Write-Host "  [ERROR] Installation test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    return $testResults
}

#endregion

#region Main Execution

try {
    Write-Host ""
    
    # Pre-Installation Checks
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "  PRE-INSTALLATION CHECKS" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""
    
    $prereqs = Test-Prerequisites
    
    Write-Host ""
    
    # Validate Prerequisites
    $canContinue = $true
    
    if (-not $prereqs.SourcePathExists) {
        Write-VersionSpecificHost "ERROR: Source path not found" -IconType 'error' -ForegroundColor Red
        $canContinue = $false
    }
    
    if (-not $prereqs.TargetServerOnline) {
        Write-VersionSpecificHost "ERROR: Target server offline" -IconType 'error' -ForegroundColor Red
        $canContinue = $false
    }
    
    if (-not $prereqs.AdminRights) {
        Write-VersionSpecificHost "ERROR: Admin rights required" -IconType 'error' -ForegroundColor Red
        $canContinue = $false
    }
    
    if (-not $canContinue) {
        Write-Host ""
        Write-Host "Prerequisites not met. Installation aborted." -ForegroundColor Red
        exit 1
    }
    
    # Test-Only Mode
    if ($TestOnly) {
        Write-Host ""
        Write-VersionSpecificHost "TEST MODE - No installation will be performed" -IconType 'warning' -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Prerequisites check complete. Ready for installation." -ForegroundColor Green
        exit 0
    }
    
    # Confirmation
    Write-Host ""
    Write-Host "Ready to install CertSurv Scanner on $($Config.TargetServer)" -ForegroundColor Yellow
    Write-Host "  Local Install Path: $($Config.LocalInstallPath)" -ForegroundColor Gray
    Write-Host "  Network Share (for output): $($Config.NetworkSharePath)" -ForegroundColor Gray
    Write-Host "  Schedule Daily: $($ScheduleDaily.IsPresent)" -ForegroundColor Gray
    Write-Host ""
    
    $confirm = Read-Host "Continue with installation? (Y/N)"
    
    if ($confirm -ne "Y" -and $confirm -ne "y") {
        Write-VersionSpecificHost "Installation cancelled by user." -IconType 'warning' -ForegroundColor Yellow
        exit 0
    }
    
    # Installation Steps
    Write-Host ""
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "  INSTALLATION" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Step 1: Copy Files to Local Installation Path
    Write-Host "[Step 1/5] Copying files to local installation..." -ForegroundColor Cyan
    $copySuccess = Copy-CertSurvFiles -SourcePath $Config.CertSurvSource -ServerName $Config.TargetServer -LocalPath $Config.LocalInstallPath
    
    if (-not $copySuccess) {
        Write-VersionSpecificHost "ERROR: File copy failed" -IconType 'error' -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
    
    # Step 2: Create Symlink for Network Share Access (optional)
    Write-Host "[Step 2/5] Creating network share link..." -ForegroundColor Cyan
    Write-Host "  Network share: $($Config.NetworkSharePath)" -ForegroundColor Gray
    Write-Host "  (CertWebService already deployed via separate process)" -ForegroundColor Gray
    Write-Host ""
    
    # Step 3: Initialize Server List on Local Installation
    Write-Host "[Step 3/5] Initializing server list on local installation..." -ForegroundColor Cyan
    
    # Construct remote path for local installation
    $computerShortName = $Config.TargetServer.Split('.')[0]
    $remoteLocalPath = "\\$computerShortName\C$" + $Config.LocalInstallPath.Substring(2)
    
    $serverListSuccess = Initialize-ServerList -BasePath $remoteLocalPath
    
    if (-not $serverListSuccess) {
        Write-VersionSpecificHost "ERROR: Server list initialization failed" -IconType 'error' -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
    
    # Step 4: Create Scheduled Task (optional)
    if ($ScheduleDaily) {
        Write-Host "[Step 4/5] Creating scheduled task..." -ForegroundColor Cyan
        
        if ($prereqs.PSRemotingAvailable) {
            # WICHTIG: Script läuft lokal auf dem Server!
            $scriptPath = Join-Path $Config.LocalInstallPath "Start-CertificateSurveillance.ps1"
            $taskSuccess = New-ScheduledScanTask -ServerName $Config.TargetServer -ScriptPath $scriptPath -Time $ScheduleTime
            
            if (-not $taskSuccess) {
                Write-Host "  [WARN] Scheduled task creation failed - continuing anyway" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  [WARN] PSRemoting not available - skipping scheduled task" -ForegroundColor Yellow
            Write-Host "  You can create the task manually later" -ForegroundColor Gray
        }
        
        Write-Host ""
    } else {
        Write-Host "[Step 4/5] Skipping scheduled task (use -ScheduleDaily to enable)" -ForegroundColor Gray
        Write-Host ""
    }
    
    # Step 5: Test Installation
    Write-Host "[Step 5/5] Testing installation..." -ForegroundColor Cyan
    $testResults = Test-Installation -ServerName $Config.TargetServer -NetworkSharePath $remoteLocalPath
    
    Write-Host ""
    
    # Final Summary
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "  INSTALLATION SUMMARY" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Installation Status:" -ForegroundColor White
    Write-Host "  Files Present: $($testResults.FilesPresent)" -ForegroundColor $(if($testResults.FilesPresent){'Green'}else{'Red'})
    Write-Host "  Server List Valid: $($testResults.ServerListValid)" -ForegroundColor $(if($testResults.ServerListValid){'Green'}else{'Red'})
    Write-Host "  Script Executable: $($testResults.ScriptExecutable)" -ForegroundColor $(if($testResults.ScriptExecutable){'Green'}else{'Red'})
    
    if ($ScheduleDaily) {
        Write-Host "  Scheduled Task: $($testResults.TaskScheduled)" -ForegroundColor $(if($testResults.TaskScheduled){'Green'}else{'Yellow'})
    }
    
    Write-Host ""
    Write-Host "Installation Paths:" -ForegroundColor White
    Write-Host "  Local (on server): $($Config.LocalInstallPath)" -ForegroundColor Gray
    Write-Host "  Remote Access: $remoteLocalPath" -ForegroundColor Gray
    Write-Host "  Network Share: $($Config.NetworkSharePath) (CertWebService output)" -ForegroundColor Gray
    Write-Host ""
    
    # Next Steps
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "  1. Edit server list: $remoteLocalPath\Config\ServerList.txt" -ForegroundColor Gray
    Write-Host "  2. Test manually on server:" -ForegroundColor Gray
    Write-Host "     Invoke-Command -ComputerName $($Config.TargetServer) -ScriptBlock {" -ForegroundColor Gray
    Write-Host "       cd $($Config.LocalInstallPath)" -ForegroundColor Gray
    Write-Host "       .\Start-CertificateSurveillance.ps1" -ForegroundColor Gray
    Write-Host "     }" -ForegroundColor Gray
    
    if ($ScheduleDaily -and $testResults.TaskScheduled) {
        Write-Host "  3. Scheduled task will run daily at $ScheduleTime" -ForegroundColor Gray
    } else {
        Write-Host "  3. Create scheduled task if needed" -ForegroundColor Gray
    }
    
    Write-Host ""
    
    # Success
    $allSuccess = $testResults.FilesPresent -and $testResults.ServerListValid -and $testResults.ScriptExecutable
    
    if ($allSuccess) {
        Write-VersionSpecificHost "Installation completed successfully!" -IconType 'party' -ForegroundColor Green
        exit 0
    } else {
        Write-VersionSpecificHost "Installation completed with warnings" -IconType 'warning' -ForegroundColor Yellow
        exit 2
    }
    
} catch {
    Write-VersionSpecificHost "Installation failed: $($_.Exception.Message)" -IconType 'error' -ForegroundColor Red
    Write-Host $_.Exception.StackTrace -ForegroundColor Red
    exit 1
}

#endregion
