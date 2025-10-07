#requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    CertSurv Scanner Installation (Hybrid Model) v1.1.0

.DESCRIPTION
    Installiert CertSurv Scanner auf ITSCMGMT03 im Hybrid-Modus:
    - Script läuft LOKAL auf C:\CertSurv
    - Liest Config/Server-Liste vom NETWORK SHARE (\\iso\CertWebService)
    - Schreibt Reports zum NETWORK SHARE (\\iso\CertWebService\Reports)

.PARAMETER TargetServer
    Zielserver (Standard: ITSCMGMT03.srv.meduniwien.ac.at)

.PARAMETER SourcePath
    Quellpfad der CertSurv-Installation

.PARAMETER ScheduleDaily
    Erstellt täglichen Scheduled Task

.VERSION
    1.1.0

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

Write-VersionSpecificHeader "CertSurv Scanner Installation (Hybrid)" -Version "v1.1.0 | Regelwerk: v10.0.2" -Color Cyan

# Konfiguration - HYBRID MODEL
$Config = @{
    TargetServer = $TargetServer
    
    # LOCAL Installation (wo Script liegt)
    LocalInstallPath = "C:\CertSurv"
    
    # NETWORK Share (Config + Reports)
    NetworkSharePath = "\\$TargetServer\iso\CertWebService"
    
    # Source
    CertSurvSource = $SourcePath
    
    # Benötigte Core-Dateien (lokal)
    LocalItems = @(
        "Start-CertificateSurveillance.ps1",
        "Modules"
    )
    
    # Config/Reports bleiben im Network Share
    NetworkItems = @(
        "Config",
        "Reports",
        "LOG"
    )
}

Write-Host ""
Write-Host "=== HYBRID INSTALLATION MODEL ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Local Installation (Scripts):" -ForegroundColor Yellow
Write-Host "  Path: $($Config.LocalInstallPath)" -ForegroundColor Gray
Write-Host "  Content: Start-CertificateSurveillance.ps1, Modules/" -ForegroundColor Gray
Write-Host ""
Write-Host "Network Share (Data):" -ForegroundColor Yellow
Write-Host "  Path: $($Config.NetworkSharePath)" -ForegroundColor Gray
Write-Host "  Content: Config/, Reports/, LOG/" -ForegroundColor Gray
Write-Host ""
Write-Host "Execution Model:" -ForegroundColor Yellow
Write-Host "  1. Script runs from: C:\CertSurv\" -ForegroundColor Gray
Write-Host "  2. Reads config from: \\iso\CertWebService\Config\" -ForegroundColor Gray
Write-Host "  3. Writes reports to: \\iso\CertWebService\Reports\" -ForegroundColor Gray
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
    
    # 1. Source Path
    Write-Host "  [1/5] Checking source path..." -ForegroundColor Gray
    $checks.SourcePathExists = Test-Path $Config.CertSurvSource
    
    if ($checks.SourcePathExists) {
        Write-Host "    [OK] Source found: $($Config.CertSurvSource)" -ForegroundColor Green
    } else {
        Write-Host "    [ERROR] Source not found" -ForegroundColor Red
        return $checks
    }
    
    # 2. Target Server
    Write-Host "  [2/5] Checking target server..." -ForegroundColor Gray
    $checks.TargetServerOnline = Test-Connection -ComputerName $Config.TargetServer -Count 1 -Quiet -ErrorAction SilentlyContinue
    
    if ($checks.TargetServerOnline) {
        Write-Host "    [OK] Server online" -ForegroundColor Green
    } else {
        Write-Host "    [ERROR] Server offline" -ForegroundColor Red
        return $checks
    }
    
    # 3. Network Share
    Write-Host "  [3/5] Checking network share..." -ForegroundColor Gray
    $checks.NetworkShareAccessible = Test-Path $Config.NetworkSharePath -ErrorAction SilentlyContinue
    
    if ($checks.NetworkShareAccessible) {
        Write-Host "    [OK] Network share accessible" -ForegroundColor Green
    } else {
        Write-Host "    [ERROR] Network share not accessible" -ForegroundColor Red
        return $checks
    }
    
    # 4. PSRemoting
    Write-Host "  [4/5] Checking PSRemoting..." -ForegroundColor Gray
    try {
        # DevSkim: ignore DS104456 - Required for installation
        $testResult = Invoke-Command -ComputerName $Config.TargetServer -ScriptBlock { $env:COMPUTERNAME } -ErrorAction Stop
        $checks.PSRemotingAvailable = $true
        Write-Host "    [OK] PSRemoting available" -ForegroundColor Green
    } catch {
        Write-Host "    [ERROR] PSRemoting not available" -ForegroundColor Red
        return $checks
    }
    
    # 5. Admin Rights
    Write-Host "  [5/5] Checking admin rights..." -ForegroundColor Gray
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $checks.AdminRights = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if ($checks.AdminRights) {
        Write-Host "    [OK] Admin rights present" -ForegroundColor Green
    } else {
        Write-Host "    [ERROR] Admin rights required" -ForegroundColor Red
    }
    
    return $checks
}

function Install-LocalScripts {
    param(
        [string]$SourcePath,
        [string]$ServerName,
        [string]$LocalPath
    )
    
    Write-VersionSpecificHost "Installing local scripts..." -IconType 'file' -ForegroundColor Cyan
    
    try {
        # Erstelle lokalen Pfad auf Server
        Write-Host "  Creating local directory on server..." -ForegroundColor Gray
        # DevSkim: ignore DS104456 - Required for installation
        Invoke-Command -ComputerName $ServerName -ScriptBlock {
            param($Path)
            if (-not (Test-Path $Path)) {
                New-Item -Path $Path -ItemType Directory -Force | Out-Null
                Write-Host "    Created: $Path" -ForegroundColor Green
            } else {
                Write-Host "    Exists: $Path" -ForegroundColor Yellow
            }
        } -ArgumentList $LocalPath -ErrorAction Stop
        
        $copiedItems = 0
        
        foreach ($item in $Config.LocalItems) {
            $sourcePath = Join-Path $SourcePath $item
            
            if (Test-Path $sourcePath) {
                Write-Host "  Copying: $item..." -ForegroundColor Gray
                
                $destPath = Join-Path $LocalPath $item
                
                if (Test-Path $sourcePath -PathType Container) {
                    # Verzeichnis kopieren
                    Write-Host "    Directory - copying recursively..." -ForegroundColor Gray
                    
                    $files = Get-ChildItem -Path $sourcePath -Recurse -File
                    
                    foreach ($file in $files) {
                        $relativePath = $file.FullName.Substring($sourcePath.Length + 1)
                        $targetFile = Join-Path $destPath $relativePath
                        $targetDir = Split-Path $targetFile -Parent
                        
                        # DevSkim: ignore DS104456 - Required for installation
                        Invoke-Command -ComputerName $ServerName -ScriptBlock {
                            param($Dir)
                            if (-not (Test-Path $Dir)) {
                                New-Item -Path $Dir -ItemType Directory -Force | Out-Null
                            }
                        } -ArgumentList $targetDir -ErrorAction SilentlyContinue
                        
                        $content = [System.IO.File]::ReadAllBytes($file.FullName)
                        # DevSkim: ignore DS104456 - Required for installation
                        Invoke-Command -ComputerName $ServerName -ScriptBlock {
                            param($Path, $Content)
                            [System.IO.File]::WriteAllBytes($Path, $Content)
                        } -ArgumentList $targetFile, $content
                    }
                    
                    $copiedItems++
                    Write-Host "    [OK] $($files.Count) files copied" -ForegroundColor Green
                } else {
                    # Datei kopieren
                    $content = [System.IO.File]::ReadAllBytes($sourcePath)
                    # DevSkim: ignore DS104456 - Required for installation
                    Invoke-Command -ComputerName $ServerName -ScriptBlock {
                        param($Path, $Content)
                        [System.IO.File]::WriteAllBytes($Path, $Content)
                    } -ArgumentList $destPath, $content -ErrorAction Stop
                    
                    $copiedItems++
                    Write-Host "    [OK] File copied" -ForegroundColor Green
                }
            } else {
                Write-Host "  [WARN] Item not found: $item" -ForegroundColor Yellow
            }
        }
        
        Write-Host ""
        Write-Host "  Local installation: $copiedItems items copied" -ForegroundColor Green
        return $true
        
    } catch {
        Write-Host "  [ERROR] Local installation failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Initialize-NetworkShare {
    param(
        [string]$SourcePath,
        [string]$NetworkSharePath
    )
    
    Write-VersionSpecificHost "Initializing network share..." -IconType 'network' -ForegroundColor Cyan
    
    try {
        $copiedItems = 0
        
        foreach ($item in $Config.NetworkItems) {
            $sourcePath = Join-Path $SourcePath $item
            $destPath = Join-Path $NetworkSharePath $item
            
            Write-Host "  Initializing: $item..." -ForegroundColor Gray
            
            if (Test-Path $sourcePath) {
                if (Test-Path $destPath) {
                    Write-Host "    [EXISTS] $item already in network share" -ForegroundColor Yellow
                } else {
                    Write-Host "    Copying to network share..." -ForegroundColor Gray
                    Copy-Item -Path $sourcePath -Destination $destPath -Recurse -Force -ErrorAction Stop
                    $copiedItems++
                    Write-Host "    [OK] Copied" -ForegroundColor Green
                }
            } else {
                # Create empty directory
                if (-not (Test-Path $destPath)) {
                    New-Item -Path $destPath -ItemType Directory -Force | Out-Null
                    Write-Host "    [OK] Created empty directory" -ForegroundColor Green
                    $copiedItems++
                }
            }
        }
        
        # Server-Liste erstellen
        $serverListPath = Join-Path $NetworkSharePath "Config\ServerList.txt"
        
        if (-not (Test-Path $serverListPath)) {
            Write-Host "  Creating default server list..." -ForegroundColor Gray
            
            $defaultServers = @(
                "wsus.srv.meduniwien.ac.at",
                "itscmgmt03.srv.meduniwien.ac.at"
            )
            
            $defaultServers -join "`r`n" | Out-File -FilePath $serverListPath -Encoding UTF8 -Force
            Write-Host "    [OK] Server list created with $($defaultServers.Count) servers" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "  Network share initialized: $copiedItems items" -ForegroundColor Green
        return $true
        
    } catch {
        Write-Host "  [ERROR] Network share initialization failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function New-HybridWrapperScript {
    param(
        [string]$ServerName,
        [string]$LocalPath,
        [string]$NetworkSharePath
    )
    
    Write-VersionSpecificHost "Creating hybrid wrapper script..." -IconType 'file' -ForegroundColor Cyan
    
    $wrapperScript = @"
#requires -Version 5.1

<#
.SYNOPSIS
    CertSurv Scanner Wrapper - Hybrid Model

.DESCRIPTION
    Führt CertSurv Scanner im Hybrid-Modus aus:
    - Script läuft von: $LocalPath
    - Config von: $NetworkSharePath\Config
    - Reports nach: $NetworkSharePath\Reports
#>

`$ErrorActionPreference = "Stop"

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "  CertSurv Scanner - Hybrid Mode" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# Pfade
`$LocalScriptPath = "$LocalPath\Start-CertificateSurveillance.ps1"
`$NetworkConfigPath = "$NetworkSharePath\Config\ServerList.txt"
`$NetworkReportsPath = "$NetworkSharePath\Reports"
`$NetworkLogPath = "$NetworkSharePath\LOG"

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Script: `$LocalScriptPath" -ForegroundColor Gray
Write-Host "  Config: `$NetworkConfigPath" -ForegroundColor Gray
Write-Host "  Reports: `$NetworkReportsPath" -ForegroundColor Gray
Write-Host "  Logs: `$NetworkLogPath" -ForegroundColor Gray
Write-Host ""

# Validation
if (-not (Test-Path `$LocalScriptPath)) {
    Write-Host "[ERROR] Local script not found: `$LocalScriptPath" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path `$NetworkConfigPath)) {
    Write-Host "[ERROR] Network config not found: `$NetworkConfigPath" -ForegroundColor Red
    exit 1
}

# Execute with network paths
Write-Host "[START] Running certificate surveillance..." -ForegroundColor Green
Write-Host ""

try {
    & `$LocalScriptPath ``
        -ServerListPath `$NetworkConfigPath ``
        -OutputDirectory `$NetworkReportsPath ``
        -SendEmail
    
    Write-Host ""
    Write-Host "[SUCCESS] Scan completed" -ForegroundColor Green
    exit 0
    
} catch {
    Write-Host ""
    Write-Host "[ERROR] Scan failed: `$(`$_.Exception.Message)" -ForegroundColor Red
    exit 1
}
"@

    try {
        $wrapperPath = Join-Path $LocalPath "Run-CertSurv-Hybrid.ps1"
        
        # DevSkim: ignore DS104456 - Required for installation
        Invoke-Command -ComputerName $ServerName -ScriptBlock {
            param($Path, $Content)
            $Content | Out-File -FilePath $Path -Encoding UTF8 -Force
        } -ArgumentList $wrapperPath, $wrapperScript -ErrorAction Stop
        
        Write-Host "  [OK] Wrapper script created: $wrapperPath" -ForegroundColor Green
        return $wrapperPath
        
    } catch {
        Write-Host "  [ERROR] Wrapper creation failed: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function New-ScheduledHybridTask {
    param(
        [string]$ServerName,
        [string]$WrapperScriptPath,
        [string]$Time
    )
    
    Write-VersionSpecificHost "Creating scheduled task..." -IconType 'clock' -ForegroundColor Cyan
    
    try {
        $scriptBlock = {
            param($TaskName, $ScriptPath, $Time)
            
            $action = New-ScheduledTaskAction `
                -Execute "powershell.exe" `
                -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
            
            $trigger = New-ScheduledTaskTrigger -Daily -At $Time
            
            $settings = New-ScheduledTaskSettingsSet `
                -AllowStartIfOnBatteries `
                -DontStopIfGoingOnBatteries `
                -StartWhenAvailable `
                -RunOnlyIfNetworkAvailable
            
            $principal = New-ScheduledTaskPrincipal `
                -UserId "SYSTEM" `
                -LogonType ServiceAccount `
                -RunLevel Highest
            
            $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
            
            if ($existingTask) {
                Set-ScheduledTask `
                    -TaskName $TaskName `
                    -Action $action `
                    -Trigger $trigger `
                    -Settings $settings `
                    -Principal $principal | Out-Null
            } else {
                Register-ScheduledTask `
                    -TaskName $TaskName `
                    -Description "CertSurv Daily Certificate Scan (Hybrid Mode)" `
                    -Action $action `
                    -Trigger $trigger `
                    -Settings $settings `
                    -Principal $principal | Out-Null
            }
            
            return $true
        }
        
        # DevSkim: ignore DS104456 - Required for scheduled task
        $result = Invoke-Command `
            -ComputerName $ServerName `
            -ScriptBlock $scriptBlock `
            -ArgumentList "CertSurv-Daily-Scan-Hybrid", $WrapperScriptPath, $Time `
            -ErrorAction Stop
        
        if ($result) {
            Write-Host "  [OK] Scheduled task created" -ForegroundColor Green
            Write-Host "  Task: CertSurv-Daily-Scan-Hybrid" -ForegroundColor Gray
            Write-Host "  Schedule: Daily at $Time" -ForegroundColor Gray
            Write-Host "  Script: $WrapperScriptPath" -ForegroundColor Gray
            return $true
        }
        
    } catch {
        Write-Host "  [ERROR] Task creation failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    
    return $false
}

#endregion

#region Main Execution

try {
    Write-Host ""
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "  PRE-INSTALLATION CHECKS" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""
    
    $prereqs = Test-Prerequisites
    
    Write-Host ""
    
    # Validate
    $canContinue = $prereqs.SourcePathExists -and 
                   $prereqs.TargetServerOnline -and 
                   $prereqs.NetworkShareAccessible -and 
                   $prereqs.PSRemotingAvailable -and 
                   $prereqs.AdminRights
    
    if (-not $canContinue) {
        Write-VersionSpecificHost "Prerequisites not met. Aborting." -IconType 'error' -ForegroundColor Red
        exit 1
    }
    
    if ($TestOnly) {
        Write-VersionSpecificHost "TEST MODE - Prerequisites OK" -IconType 'success' -ForegroundColor Green
        exit 0
    }
    
    # Confirmation
    Write-Host ""
    Write-Host "Ready for hybrid installation:" -ForegroundColor Yellow
    Write-Host "  Local Scripts: $($Config.LocalInstallPath)" -ForegroundColor Gray
    Write-Host "  Network Data: $($Config.NetworkSharePath)" -ForegroundColor Gray
    Write-Host ""
    
    $confirm = Read-Host "Continue? (Y/N)"
    
    if ($confirm -ne "Y" -and $confirm -ne "y") {
        Write-Host "Installation cancelled." -ForegroundColor Yellow
        exit 0
    }
    
    # Installation
    Write-Host ""
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "  HYBRID INSTALLATION" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Step 1: Install Local Scripts
    Write-Host "[Step 1/4] Installing local scripts..." -ForegroundColor Cyan
    $localSuccess = Install-LocalScripts -SourcePath $Config.CertSurvSource -ServerName $Config.TargetServer -LocalPath $Config.LocalInstallPath
    
    if (-not $localSuccess) {
        Write-VersionSpecificHost "Local installation failed" -IconType 'error' -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
    
    # Step 2: Initialize Network Share
    Write-Host "[Step 2/4] Initializing network share..." -ForegroundColor Cyan
    $networkSuccess = Initialize-NetworkShare -SourcePath $Config.CertSurvSource -NetworkSharePath $Config.NetworkSharePath
    
    if (-not $networkSuccess) {
        Write-VersionSpecificHost "Network share initialization failed" -IconType 'error' -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
    
    # Step 3: Create Wrapper Script
    Write-Host "[Step 3/4] Creating hybrid wrapper script..." -ForegroundColor Cyan
    $wrapperPath = New-HybridWrapperScript -ServerName $Config.TargetServer -LocalPath $Config.LocalInstallPath -NetworkSharePath $Config.NetworkSharePath
    
    if (-not $wrapperPath) {
        Write-VersionSpecificHost "Wrapper creation failed" -IconType 'error' -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
    
    # Step 4: Scheduled Task
    if ($ScheduleDaily) {
        Write-Host "[Step 4/4] Creating scheduled task..." -ForegroundColor Cyan
        $taskSuccess = New-ScheduledHybridTask -ServerName $Config.TargetServer -WrapperScriptPath $wrapperPath -Time $ScheduleTime
        
        if (-not $taskSuccess) {
            Write-Host "  [WARN] Task creation failed - continuing" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[Step 4/4] Skipping scheduled task" -ForegroundColor Gray
    }
    
    Write-Host ""
    
    # Summary
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "  INSTALLATION COMPLETE" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Hybrid Installation Summary:" -ForegroundColor White
    Write-Host ""
    Write-Host "Local (Scripts):" -ForegroundColor Yellow
    Write-Host "  $($Config.LocalInstallPath)\" -ForegroundColor Gray
    Write-Host "  - Start-CertificateSurveillance.ps1" -ForegroundColor Gray
    Write-Host "  - Modules\" -ForegroundColor Gray
    Write-Host "  - Run-CertSurv-Hybrid.ps1 (wrapper)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Network Share (Data):" -ForegroundColor Yellow
    Write-Host "  $($Config.NetworkSharePath)\" -ForegroundColor Gray
    Write-Host "  - Config\ServerList.txt (INPUT)" -ForegroundColor Gray
    Write-Host "  - Reports\ (OUTPUT)" -ForegroundColor Gray
    Write-Host "  - LOG\ (OUTPUT)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "  1. Edit server list:" -ForegroundColor Gray
    Write-Host "     $($Config.NetworkSharePath)\Config\ServerList.txt" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2. Test manually:" -ForegroundColor Gray
    Write-Host "     Invoke-Command -ComputerName $($Config.TargetServer) -ScriptBlock {" -ForegroundColor Gray
    Write-Host "       $($Config.LocalInstallPath)\Run-CertSurv-Hybrid.ps1" -ForegroundColor Gray
    Write-Host "     }" -ForegroundColor Gray
    Write-Host ""
    
    if ($ScheduleDaily) {
        Write-Host "  3. Scheduled task will run daily at $ScheduleTime" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-VersionSpecificHost "Hybrid installation completed successfully!" -IconType 'party' -ForegroundColor Green
    exit 0
    
} catch {
    Write-VersionSpecificHost "Installation failed: $($_.Exception.Message)" -IconType 'error' -ForegroundColor Red
    Write-Host $_.Exception.StackTrace -ForegroundColor Red
    exit 1
}

#endregion
