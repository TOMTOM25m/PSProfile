#requires -Version 5.1
#Requires -RunAsAdministrator

# Import FL-CredentialManager für 3-Stufen-Strategie
Import-Module "$PSScriptRoot\Modules\FL-CredentialManager-v1.0.psm1" -Force

<#
.SYNOPSIS
    CertSurv Scanner Installation - Final Version v1.0.0

.DESCRIPTION
    Installiert CertSurv Scanner auf ITSCMGMT03 komplett LOKAL:
    - Quell-Daten: \\itscmgmt03\iso\CertSurv (Network Share)
    - Ziel: C:\CertSurv auf ITSCMGMT03 (komplett lokal)
    - Installation von: ITSC020 (Workstation)
    - Alle Daten lokal = schnell, keine Netzwerkfehler

.PARAMETER TargetServer
    Zielserver (Standard: ITSCMGMT03.srv.meduniwien.ac.at)

.PARAMETER SourceNetworkPath
    Netzwerk-Quellpfad (Standard: \\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv)

.PARAMETER LocalTargetPath
    Lokaler Zielpfad auf Server (Standard: C:\CertSurv)

.PARAMETER Credential
    Admin-Credentials für Server-Zugriff

.PARAMETER ScheduleDaily
    Erstellt täglichen Scheduled Task

.VERSION
    1.0.0

.RULEBOOK
    v10.1.0
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$TargetServer = "ITSCMGMT03.srv.meduniwien.ac.at",
    
    [Parameter(Mandatory = $false)]
    [string]$SourceNetworkPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv",
    
    [Parameter(Mandatory = $false)]
    [string]$LocalTargetPath = "C:\CertSurv",
    
    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]$Credential,
    
    [Parameter(Mandatory = $false)]
    [switch]$ScheduleDaily,
    
    [Parameter(Mandatory = $false)]
    [string]$ScheduleTime = "08:00",
    
    [Parameter(Mandatory = $false)]
    [switch]$TestOnly
)

# Import Compatibility Module
Import-Module ".\Modules\FL-PowerShell-VersionCompatibility-v3.1.psm1" -Force

Write-VersionSpecificHeader "CertSurv Scanner Installation - Final" -Version "v1.0.0 | Regelwerk: v10.1.0" -Color Cyan

Write-Host ""
Write-Host "=== INSTALLATION ARCHITECTURE ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Installation Source:" -ForegroundColor Yellow
Write-Host "  Workstation: ITSC020 ($(hostname))" -ForegroundColor Gray
Write-Host "  Current User: $env:USERNAME" -ForegroundColor Gray
Write-Host ""
Write-Host "Data Flow:" -ForegroundColor Yellow
Write-Host "  1. Source: $SourceNetworkPath" -ForegroundColor Gray
Write-Host "  2. Target Server: $TargetServer" -ForegroundColor Gray
Write-Host "  3. Local Install: $LocalTargetPath" -ForegroundColor Gray
Write-Host ""
Write-Host "Execution Model:" -ForegroundColor Yellow
Write-Host "  - ALL DATA STORED LOCALLY on $TargetServer" -ForegroundColor Gray
Write-Host "  - Config: $LocalTargetPath\Config\" -ForegroundColor Gray
Write-Host "  - Reports: $LocalTargetPath\Reports\" -ForegroundColor Gray
Write-Host "  - Logs: $LocalTargetPath\LOG\" -ForegroundColor Gray
Write-Host "  - Temp: $LocalTargetPath\Temp\" -ForegroundColor Gray
Write-Host ""

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
#region # Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
Functions

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
function Get-AdminCredential {
    param(
        [string]$ServerName
    )
    
    Write-VersionSpecificHost "Requesting admin credentials..." -IconType 'key' -ForegroundColor Cyan
    
    # Credential-Strategie
    $computerShortName = $ServerName.Split('.')[0]
    
    # Option 1: Provided credential
    if ($Credential) {
        Write-Host "  Using provided credentials: $($Credential.UserName)" -ForegroundColor Green
        return $Credential
    }
    
    # Option 2: 3-Stufen-Strategie (Default -> Vault -> Prompt)
    Write-Host "  Server: $ServerName" -ForegroundColor Gray
    Write-Host "  Using intelligent credential strategy..." -ForegroundColor Gray
    Write-Host ""
    
    $cred = Get-OrPromptCredential -Target $ServerName -Username "$computerShortName\Administrator" -AutoSave
    
    if (-not $cred) {
        throw "Credentials required for installation"
    }
    
    return $cred
}

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
function Test-Prerequisites {
    param(
        [string]$ServerName,
        [string]$NetworkPath,
        [System.Management.Automation.PSCredential]$Cred
    )
    
    Write-VersionSpecificHost "Testing prerequisites..." -IconType 'shield' -ForegroundColor Cyan
    
    $checks = @{
        SourceExists = $false
        ServerOnline = $false
        PSRemotingAvailable = $false
        DiskSpace = $false
        DiskSpaceGB = 0
    }
    
    # 1. Source Network Path
    Write-Host "  [1/4] Checking source path..." -ForegroundColor Gray
    $checks.SourceExists = Test-Path $NetworkPath -ErrorAction SilentlyContinue
    
    if ($checks.SourceExists) {
        $items = Get-ChildItem -Path $NetworkPath -Recurse -File
        $totalSizeMB = ($items | Measure-Object -Property Length -Sum).Sum / 1MB
        Write-Host "    [OK] Source found: $([math]::Round($totalSizeMB, 2)) MB" -ForegroundColor Green
    } else {
        Write-Host "    [ERROR] Source not accessible: $NetworkPath" -ForegroundColor Red
        return $checks
    }
    
    # 2. Target Server Ping
    Write-Host "  [2/4] Checking target server..." -ForegroundColor Gray
    $checks.ServerOnline = Test-Connection -ComputerName $ServerName -Count 1 -Quiet -ErrorAction SilentlyContinue
    
    if ($checks.ServerOnline) {
        Write-Host "    [OK] Server online" -ForegroundColor Green
    } else {
        Write-Host "    [ERROR] Server offline or unreachable" -ForegroundColor Red
        return $checks
    }
    
    # 3. PSRemoting with Credentials
    Write-Host "  [3/4] Testing PSRemoting with credentials..." -ForegroundColor Gray
    try {
        # DevSkim: ignore DS104456 - Required for installation
        $testResult = Invoke-Command -ComputerName $ServerName -Credential $Cred -ScriptBlock {
            [PSCustomObject]@{
                ComputerName = $env:COMPUTERNAME
                UserName = $env:USERNAME
                OSVersion = [System.Environment]::OSVersion.Version.ToString()
            }
        } -ErrorAction Stop
        
        $checks.PSRemotingAvailable = $true
        Write-Host "    [OK] PSRemoting successful" -ForegroundColor Green
        Write-Host "    Computer: $($testResult.ComputerName)" -ForegroundColor Gray
        Write-Host "    User: $($testResult.UserName)" -ForegroundColor Gray
        Write-Host "    OS: $($testResult.OSVersion)" -ForegroundColor Gray
        
    } catch {
        Write-Host "    [ERROR] PSRemoting failed: $($_.Exception.Message)" -ForegroundColor Red
        return $checks
    }
    
    # 4. Disk Space Check
    Write-Host "  [4/4] Checking disk space on target..." -ForegroundColor Gray
    try {
        # DevSkim: ignore DS104456 - Required for installation
        $diskInfo = Invoke-Command -ComputerName $ServerName -Credential $Cred -ScriptBlock {
            param($TargetPath)
            $drive = (Split-Path $TargetPath -Qualifier)
            $disk = Get-PSDrive -Name $drive.TrimEnd(':')
            [PSCustomObject]@{
                FreeGB = [math]::Round($disk.Free / 1GB, 2)
                UsedGB = [math]::Round($disk.Used / 1GB, 2)
                TotalGB = [math]::Round(($disk.Free + $disk.Used) / 1GB, 2)
            }
        } -ArgumentList $LocalTargetPath -ErrorAction Stop
        
        $checks.DiskSpaceGB = $diskInfo.FreeGB
        $checks.DiskSpace = ($diskInfo.FreeGB -gt 1)  # Mindestens 1 GB frei
        
        Write-Host "    [OK] Free space: $($diskInfo.FreeGB) GB" -ForegroundColor Green
        Write-Host "    Total: $($diskInfo.TotalGB) GB" -ForegroundColor Gray
        
    } catch {
        Write-Host "    [WARN] Could not check disk space" -ForegroundColor Yellow
        $checks.DiskSpace = $true  # Assume OK
    }
    
    return $checks
}

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
function Copy-ToServerLocal {
    param(
        [string]$ServerName,
        [string]$SourcePath,
        [string]$TargetPath,
        [System.Management.Automation.PSCredential]$Cred
    )
    
    Write-VersionSpecificHost "Copying CertSurv to server (local installation)..." -IconType 'file' -ForegroundColor Cyan
    
    try {
        Write-Host "  Source: $SourcePath" -ForegroundColor Gray
        Write-Host "  Target: $ServerName -> $TargetPath" -ForegroundColor Gray
        Write-Host ""
        
        # Methode: Robocopy via PSRemoting (schnellste Methode)
        Write-Host "  Using Robocopy for fast transfer..." -ForegroundColor Yellow
        
        $robocopyScript = {
            param($Source, $Target)
            
            # Zielverzeichnis erstellen
            if (-not (Test-Path $Target)) {
                New-Item -Path $Target -ItemType Directory -Force | Out-Null
            }
            
            # Robocopy durchführen
            $robocopyArgs = @(
                $Source,
                $Target,
                "/E",           # Alle Unterverzeichnisse
                "/COPYALL",     # Alle Attribute kopieren
                "/R:3",         # 3 Wiederholungen
                "/W:5",         # 5 Sekunden Wartezeit
                "/MT:8",        # Multi-Threading (8 Threads)
                "/NFL",         # No File List
                "/NDL",         # No Directory List
                "/NP"           # No Progress
            )
            
            $result = robocopy @robocopyArgs
            $exitCode = $LASTEXITCODE
            
            # Robocopy Exit Codes: 0-7 = Success, 8+ = Error
            $success = ($exitCode -lt 8)
            
            [PSCustomObject]@{
                Success = $success
                ExitCode = $exitCode
                Message = if ($success) { "Copy successful" } else { "Copy failed with exit code $exitCode" }
            }
        }
        
        # DevSkim: ignore DS104456 - Required for installation
        $copyResult = Invoke-Command -ComputerName $ServerName -Credential $Cred -ScriptBlock $robocopyScript -ArgumentList $SourcePath, $TargetPath -ErrorAction Stop
        
        if ($copyResult.Success) {
            Write-Host ""
            Write-Host "  [OK] Copy successful (Robocopy exit code: $($copyResult.ExitCode))" -ForegroundColor Green
            
            # Verify copy
            # DevSkim: ignore DS104456 - Required for installation
            $fileCount = Invoke-Command -ComputerName $ServerName -Credential $Cred -ScriptBlock {
                param($Path)
                (Get-ChildItem -Path $Path -Recurse -File | Measure-Object).Count
            } -ArgumentList $TargetPath
            
            Write-Host "  Files on target: $fileCount" -ForegroundColor Gray
            
            return $true
        } else {
            Write-Host "  [ERROR] Copy failed: $($copyResult.Message)" -ForegroundColor Red
            return $false
        }
        
    } catch {
        Write-Host "  [ERROR] Copy failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
function Initialize-LocalConfiguration {
    param(
        [string]$ServerName,
        [string]$InstallPath,
        [System.Management.Automation.PSCredential]$Cred
    )
    
    Write-VersionSpecificHost "Initializing local configuration..." -IconType 'settings' -ForegroundColor Cyan
    
    try {
        # DevSkim: ignore DS104456 - Required for installation
        $result = Invoke-Command -ComputerName $ServerName -Credential $Cred -ScriptBlock {
            param($InstallPath)
            
            $configPath = Join-Path $InstallPath "Config"
            $serverListPath = Join-Path $configPath "ServerList.txt"
            
            # Ensure Config directory exists
            if (-not (Test-Path $configPath)) {
                New-Item -Path $configPath -ItemType Directory -Force | Out-Null
            }
            
            # Create or update ServerList.txt
            $defaultServers = @(
                "wsus.srv.meduniwien.ac.at",
                "itscmgmt03.srv.meduniwien.ac.at"
            )
            
            if (-not (Test-Path $serverListPath)) {
                $defaultServers -join "`r`n" | Out-File -FilePath $serverListPath -Encoding UTF8 -Force
                $created = $true
            } else {
                $created = $false
            }
            
            # Ensure other directories exist
            $directories = @("Reports", "LOG", "Temp", "Backup")
            foreach ($dir in $directories) {
                $dirPath = Join-Path $InstallPath $dir
                if (-not (Test-Path $dirPath)) {
                    New-Item -Path $dirPath -ItemType Directory -Force | Out-Null
                }
            }
            
            [PSCustomObject]@{
                ServerListCreated = $created
                ServerCount = $defaultServers.Count
                ServerListPath = $serverListPath
            }
            
        } -ArgumentList $InstallPath -ErrorAction Stop
        
        if ($result.ServerListCreated) {
            Write-Host "  [OK] Server list created: $($result.ServerCount) servers" -ForegroundColor Green
        } else {
            Write-Host "  [OK] Server list exists" -ForegroundColor Green
        }
        
        Write-Host "  Path: $($result.ServerListPath)" -ForegroundColor Gray
        Write-Host "  Directories: Reports, LOG, Temp, Backup" -ForegroundColor Gray
        
        return $true
        
    } catch {
        Write-Host "  [ERROR] Configuration failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
function New-ScheduledScanTask {
    param(
        [string]$ServerName,
        [string]$ScriptPath,
        [string]$Time,
        [System.Management.Automation.PSCredential]$Cred
    )
    
    Write-VersionSpecificHost "Creating scheduled task..." -IconType 'clock' -ForegroundColor Cyan
    
    try {
        $taskScript = {
            param($TaskName, $ScriptPath, $Time)
            
            $action = New-ScheduledTaskAction `
                -Execute "powershell.exe" `
                -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
            
            $trigger = New-ScheduledTaskTrigger -Daily -At $Time
            
            $settings = New-ScheduledTaskSettingsSet `
                -AllowStartIfOnBatteries `
                -DontStopIfGoingOnBatteries `
                -StartWhenAvailable `
                -RunOnlyIfNetworkAvailable `
                -ExecutionTimeLimit (New-TimeSpan -Hours 4)
            
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
                $created = $false
            } else {
                Register-ScheduledTask `
                    -TaskName $TaskName `
                    -Description "CertSurv Daily Certificate Scanner - Runs locally on $env:COMPUTERNAME" `
                    -Action $action `
                    -Trigger $trigger `
                    -Settings $settings `
                    -Principal $principal | Out-Null
                $created = $true
            }
            
            [PSCustomObject]@{
                Created = $created
                TaskName = $TaskName
                NextRun = (Get-ScheduledTask -TaskName $TaskName).Triggers[0].StartBoundary
            }
        }
        
        # DevSkim: ignore DS104456 - Required for installation
        $result = Invoke-Command `
            -ComputerName $ServerName `
            -Credential $Cred `
            -ScriptBlock $taskScript `
            -ArgumentList "CertSurv-Daily-Scanner", $ScriptPath, $Time `
            -ErrorAction Stop
        
        if ($result.Created) {
            Write-Host "  [OK] Scheduled task created" -ForegroundColor Green
        } else {
            Write-Host "  [OK] Scheduled task updated" -ForegroundColor Green
        }
        
        Write-Host "  Task: $($result.TaskName)" -ForegroundColor Gray
        Write-Host "  Schedule: Daily at $Time" -ForegroundColor Gray
        Write-Host "  Script: $ScriptPath" -ForegroundColor Gray
        
        return $true
        
    } catch {
        Write-Host "  [ERROR] Task creation failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

#endregion

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
#region Main Execution

try {
    Write-Host ""
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "  PRE-INSTALLATION" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Get Credentials
    $adminCred = Get-AdminCredential -ServerName $TargetServer
    
    Write-Host ""
    
    # Prerequisites
    $prereqs = Test-Prerequisites -ServerName $TargetServer -NetworkPath $SourceNetworkPath -Cred $adminCred
    
    Write-Host ""
    
    # Validate
    $canContinue = $prereqs.SourceExists -and 
                   $prereqs.ServerOnline -and 
                   $prereqs.PSRemotingAvailable -and 
                   $prereqs.DiskSpace
    
    if (-not $canContinue) {
        Write-VersionSpecificHost "Prerequisites not met. Installation aborted." -IconType 'error' -ForegroundColor Red
        exit 1
    }
    
    if ($TestOnly) {
        Write-Host ""
        Write-VersionSpecificHost "TEST MODE - Prerequisites OK, ready for installation" -IconType 'success' -ForegroundColor Green
        exit 0
    }
    
    # Confirmation
    Write-Host ""
    Write-Host "Ready to install CertSurv Scanner:" -ForegroundColor Yellow
    Write-Host "  From: $SourceNetworkPath" -ForegroundColor Gray
    Write-Host "  To: $TargetServer -> $LocalTargetPath" -ForegroundColor Gray
    Write-Host "  All data will be stored LOCALLY (fast, no network dependency)" -ForegroundColor Gray
    Write-Host ""
    
    $confirm = Read-Host "Continue with installation? (Y/N)"
    
    if ($confirm -ne "Y" -and $confirm -ne "y") {
        Write-Host "Installation cancelled." -ForegroundColor Yellow
        exit 0
    }
    
    # Installation
    Write-Host ""
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "  INSTALLATION" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Step 1: Copy Files
    Write-Host "[Step 1/3] Copying files to server..." -ForegroundColor Cyan
    $copySuccess = Copy-ToServerLocal -ServerName $TargetServer -SourcePath $SourceNetworkPath -TargetPath $LocalTargetPath -Cred $adminCred
    
    if (-not $copySuccess) {
        Write-VersionSpecificHost "File copy failed. Installation aborted." -IconType 'error' -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
    
    # Step 2: Initialize Configuration
    Write-Host "[Step 2/3] Initializing local configuration..." -ForegroundColor Cyan
    $configSuccess = Initialize-LocalConfiguration -ServerName $TargetServer -InstallPath $LocalTargetPath -Cred $adminCred
    
    if (-not $configSuccess) {
        Write-VersionSpecificHost "Configuration failed. Installation aborted." -IconType 'error' -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
    
    # Step 3: Scheduled Task
    if ($ScheduleDaily) {
        Write-Host "[Step 3/3] Creating scheduled task..." -ForegroundColor Cyan
        $scriptPath = Join-Path $LocalTargetPath "Start-CertificateSurveillance.ps1"
        $taskSuccess = New-ScheduledScanTask -ServerName $TargetServer -ScriptPath $scriptPath -Time $ScheduleTime -Cred $adminCred
        
        if (-not $taskSuccess) {
            Write-Host "  [WARN] Task creation failed - continuing anyway" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[Step 3/3] Skipping scheduled task" -ForegroundColor Gray
    }
    
    Write-Host ""
    
    # Final Summary
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "  INSTALLATION COMPLETE" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Installation Details:" -ForegroundColor White
    Write-Host "  Server: $TargetServer" -ForegroundColor Gray
    Write-Host "  Local Path: $LocalTargetPath" -ForegroundColor Gray
    Write-Host "  All data stored locally (Config, Reports, Logs, Temp)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "  1. Edit server list (optional):" -ForegroundColor Gray
    Write-Host "     Invoke-Command -ComputerName $TargetServer -Credential `$cred -ScriptBlock {" -ForegroundColor Gray
    Write-Host "       notepad $LocalTargetPath\Config\ServerList.txt" -ForegroundColor Gray
    Write-Host "     }" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2. Test manually:" -ForegroundColor Gray
    Write-Host "     Invoke-Command -ComputerName $TargetServer -Credential `$cred -ScriptBlock {" -ForegroundColor Gray
    Write-Host "       cd $LocalTargetPath" -ForegroundColor Gray
    Write-Host "       .\Start-CertificateSurveillance.ps1" -ForegroundColor Gray
    Write-Host "     }" -ForegroundColor Gray
    Write-Host ""
    
    if ($ScheduleDaily) {
        Write-Host "  3. Scheduled task will run daily at $ScheduleTime" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-VersionSpecificHost "Installation completed successfully!" -IconType 'party' -ForegroundColor Green
    
    exit 0
    
} catch {
    Write-VersionSpecificHost "Installation failed: $($_.Exception.Message)" -IconType 'error' -ForegroundColor Red
    Write-Host $_.Exception.StackTrace -ForegroundColor Red
    exit 1
}

#endregion

