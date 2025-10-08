#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    CertWebService - Scheduled Task Setup
    
.DESCRIPTION
    Richtet Scheduled Tasks fuer CertWebService ein nach Regelwerk v10.0.3
    
    Tasks:
    - CertWebService-WebServer : HTTP Service (dauerhaft, startet bei Boot)
    - CertWebService-DailyScan : Taeglicher Zertifikatsscan (06:00 Uhr)
    
.PARAMETER InstallPath
    Installations-Pfad des CertWebService (Default: C:\CertWebService)
    
.PARAMETER WebServicePort
    HTTP Port fuer Web Service (Default: 9080)
    
.PARAMETER ScanTime
    Uhrzeit fuer täglichen Scan im Format HH:MM (Default: 06:00)
    
.PARAMETER RemoveOnly
    Entfernt existierende Tasks ohne neue zu erstellen
    
.EXAMPLE
    .\Setup-CertWebService-Scheduler.ps1
    Erstellt beide Scheduled Tasks mit Defaults
    
.EXAMPLE
    .\Setup-CertWebService-Scheduler.ps1 -ScanTime "03:00"
    Erstellt Tasks mit Scan um 03:00 Uhr
    
.EXAMPLE
    .\Setup-CertWebService-Scheduler.ps1 -RemoveOnly
    Entfernt alle CertWebService Scheduled Tasks
    
.NOTES
    Author:  Flecki (Tom) Garnreiter
    Version: v1.0.0
    Date:    2025-10-08
    Regelwerk: v10.0.3 (§5, §14, §19)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$InstallPath = "C:\CertWebService",
    
    [Parameter(Mandatory=$false)]
    [int]$WebServicePort = 9080,
    
    [Parameter(Mandatory=$false)]
    [ValidatePattern('^\d{2}:\d{2}$')]
    [string]$ScanTime = "06:00",
    
    [Parameter(Mandatory=$false)]
    [switch]$RemoveOnly
)

#region Configuration

$script:TaskPrefix = "CertWebService"
$script:WebServiceTaskName = "$script:TaskPrefix-WebServer"
$script:DailyScanTaskName = "$script:TaskPrefix-DailyScan"

# Logging
$script:LogDirectory = Join-Path $InstallPath "Logs"
$script:LogFile = Join-Path $script:LogDirectory "Scheduler-Setup_$(Get-Date -Format 'yyyy-MM-dd').log"

#endregion

#region Logging Functions

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "FATAL")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Ensure Log Directory
    if (-not (Test-Path $script:LogDirectory)) {
        try {
            New-Item -Path $script:LogDirectory -ItemType Directory -Force | Out-Null
        } catch {
            Write-Host "[ERROR] Could not create log directory: $($_.Exception.Message)" -ForegroundColor Red
            return
        }
    }
    
    # Write to file
    try {
        Add-Content -Path $script:LogFile -Value $logMessage -Encoding UTF8
    } catch {
        Write-Host "[WARN] Could not write to log file: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Console output with colors
    switch ($Level) {
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "ERROR"   { Write-Host $logMessage -ForegroundColor Red }
        "FATAL"   { Write-Host $logMessage -ForegroundColor Red -BackgroundColor Black }
        default   { Write-Host $logMessage -ForegroundColor Gray }
    }
}

function Show-Banner {
    param([string]$Title)
    
    Write-Host ""
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host ""
}

#endregion

#region Helper Functions

function Test-Prerequisites {
    Show-Banner "PREREQUISITE CHECKS"
    Write-Log "Starte Prerequisite Checks..." -Level INFO
    
    $allOk = $true
    
    # Check 1: PowerShell Version
    Write-Host "[CHECK 1] PowerShell Version..." -ForegroundColor Yellow
    $psVersion = $PSVersionTable.PSVersion
    Write-Host "  Version: $($psVersion.Major).$($psVersion.Minor)" -ForegroundColor Gray
    
    if ($psVersion.Major -ge 5) {
        Write-Log "PowerShell Version OK: $psVersion" -Level SUCCESS
    } else {
        Write-Log "PowerShell Version zu alt: $psVersion (mind. 5.1)" -Level ERROR
        $allOk = $false
    }
    
    # Check 2: Admin Rights
    Write-Host ""
    Write-Host "[CHECK 2] Administrator-Rechte..." -ForegroundColor Yellow
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if ($isAdmin) {
        Write-Log "Administrator-Rechte: OK" -Level SUCCESS
    } else {
        Write-Log "Keine Administrator-Rechte!" -Level FATAL
        $allOk = $false
    }
    
    # Check 3: Installation Path
    Write-Host ""
    Write-Host "[CHECK 3] Installations-Pfad..." -ForegroundColor Yellow
    Write-Host "  Path: $InstallPath" -ForegroundColor Gray
    
    if (Test-Path $InstallPath) {
        Write-Log "Installations-Pfad existiert: $InstallPath" -Level SUCCESS
        
        # Check Scripts
        $webServiceScript = Join-Path $InstallPath "CertWebService.ps1"
        $scanScript = Join-Path $InstallPath "ScanCertificates.ps1"
        
        if (Test-Path $webServiceScript) {
            Write-Host "  [OK] CertWebService.ps1 gefunden" -ForegroundColor Green
        } else {
            Write-Log "CertWebService.ps1 nicht gefunden in $InstallPath" -Level ERROR
            $allOk = $false
        }
        
        if (Test-Path $scanScript) {
            Write-Host "  [OK] ScanCertificates.ps1 gefunden" -ForegroundColor Green
        } else {
            Write-Log "ScanCertificates.ps1 nicht gefunden in $InstallPath" -Level WARNING
        }
    } else {
        Write-Log "Installations-Pfad nicht gefunden: $InstallPath" -Level FATAL
        $allOk = $false
    }
    
    # Check 4: Existing Tasks
    Write-Host ""
    Write-Host "[CHECK 4] Existierende Tasks..." -ForegroundColor Yellow
    $existingTasks = Get-ScheduledTask -TaskName "$script:TaskPrefix*" -ErrorAction SilentlyContinue
    
    if ($existingTasks) {
        Write-Host "  Gefundene Tasks:" -ForegroundColor Gray
        foreach ($task in $existingTasks) {
            Write-Host "    - $($task.TaskName) (Status: $($task.State))" -ForegroundColor Gray
        }
        Write-Log "Existierende Tasks gefunden: $($existingTasks.Count)" -Level INFO
    } else {
        Write-Host "  Keine existierenden Tasks gefunden" -ForegroundColor Gray
        Write-Log "Keine existierenden Tasks gefunden" -Level INFO
    }
    
    Write-Host ""
    Write-Host "=====================================================================" -ForegroundColor Cyan
    
    if ($allOk) {
        Write-Log "Alle Prerequisite Checks bestanden" -Level SUCCESS
        return $true
    } else {
        Write-Log "Prerequisite Checks fehlgeschlagen!" -Level FATAL
        return $false
    }
}

#endregion

#region Task Management

function Remove-ExistingTasks {
    Show-Banner "REMOVE EXISTING TASKS"
    Write-Log "Entferne existierende Tasks..." -Level INFO
    
    $tasksToRemove = @($script:WebServiceTaskName, $script:DailyScanTaskName)
    $removedCount = 0
    
    foreach ($taskName in $tasksToRemove) {
        Write-Host "[REMOVE] $taskName..." -ForegroundColor Yellow
        
        try {
            $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
            
            if ($task) {
                # Stop wenn laufend
                if ($task.State -eq "Running") {
                    Write-Host "  Stopping task..." -ForegroundColor Cyan
                    Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 2
                }
                
                # Unregister
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
                Write-Log "Task entfernt: $taskName" -Level SUCCESS
                $removedCount++
            } else {
                Write-Host "  Task nicht gefunden (bereits entfernt)" -ForegroundColor Gray
                Write-Log "Task nicht gefunden: $taskName" -Level INFO
            }
        } catch {
            Write-Log "Fehler beim Entfernen von $taskName - $($_.Exception.Message)" -Level ERROR
        }
    }
    
    Write-Host ""
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Log "$removedCount Task(s) entfernt" -Level INFO
    
    return $removedCount
}

function New-WebServiceTask {
    Show-Banner "CREATE WEB SERVICE TASK"
    Write-Log "Erstelle Web Service Task..." -Level INFO
    
    $webServiceScript = Join-Path $InstallPath "CertWebService.ps1"
    
    try {
        # Task Action
        $arguments = "-NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden " +
                     "-WorkingDirectory `"$InstallPath`" " +
                     "-File `"$webServiceScript`" -ServiceMode"
        
        Write-Host "[STEP 1] Action..." -ForegroundColor Yellow
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $arguments
        Write-Host "  Command: powershell.exe" -ForegroundColor Gray
        Write-Host "  Args: $arguments" -ForegroundColor Gray
        
        # Task Trigger
        Write-Host ""
        Write-Host "[STEP 2] Trigger..." -ForegroundColor Yellow
        $trigger = New-ScheduledTaskTrigger -AtStartup
        Write-Host "  Trigger: At System Startup" -ForegroundColor Gray
        
        # Task Settings
        Write-Host ""
        Write-Host "[STEP 3] Settings..." -ForegroundColor Yellow
        $settings = New-ScheduledTaskSettingsSet `
            -StartWhenAvailable `
            -DontStopOnIdleEnd `
            -RestartCount 3 `
            -RestartInterval (New-TimeSpan -Minutes 1) `
            -ExecutionTimeLimit (New-TimeSpan -Days 0)
        
        Write-Host "  StartWhenAvailable: Yes" -ForegroundColor Gray
        Write-Host "  DontStopOnIdleEnd: Yes" -ForegroundColor Gray
        Write-Host "  RestartCount: 3" -ForegroundColor Gray
        Write-Host "  ExecutionTimeLimit: Unlimited" -ForegroundColor Gray
        
        # Task Principal
        Write-Host ""
        Write-Host "[STEP 4] Principal..." -ForegroundColor Yellow
        $principal = New-ScheduledTaskPrincipal `
            -UserId "SYSTEM" `
            -LogonType ServiceAccount `
            -RunLevel Highest
        
        Write-Host "  User: SYSTEM" -ForegroundColor Gray
        Write-Host "  LogonType: ServiceAccount" -ForegroundColor Gray
        Write-Host "  RunLevel: Highest" -ForegroundColor Gray
        
        # Register Task
        Write-Host ""
        Write-Host "[STEP 5] Register Task..." -ForegroundColor Yellow
        
        Register-ScheduledTask `
            -TaskName $script:WebServiceTaskName `
            -Action $action `
            -Trigger $trigger `
            -Settings $settings `
            -Principal $principal `
            -Description "CertWebService HTTP Web Server - Port $WebServicePort (Regelwerk v10.0.3)" `
            -Force | Out-Null
        
        Write-Log "Task registriert: $script:WebServiceTaskName" -Level SUCCESS
        
        # Start Task
        Write-Host ""
        Write-Host "[STEP 6] Start Task..." -ForegroundColor Yellow
        Start-ScheduledTask -TaskName $script:WebServiceTaskName -ErrorAction Stop
        Start-Sleep -Seconds 2
        
        # Verify
        $task = Get-ScheduledTask -TaskName $script:WebServiceTaskName
        if ($task.State -eq "Running") {
            Write-Log "Task gestartet und laeuft: $script:WebServiceTaskName" -Level SUCCESS
        } else {
            Write-Log "Task gestartet, Status: $($task.State)" -Level WARNING
        }
        
        Write-Host ""
        Write-Host "=====================================================================" -ForegroundColor Cyan
        Write-Log "Web Service Task erfolgreich erstellt" -Level SUCCESS
        
        return $true
    } catch {
        Write-Log "Fehler beim Erstellen des Web Service Tasks: $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

function New-DailyScanTask {
    Show-Banner "CREATE DAILY SCAN TASK"
    Write-Log "Erstelle Daily Scan Task..." -Level INFO
    
    $scanScript = Join-Path $InstallPath "ScanCertificates.ps1"
    
    # Check if scan script exists
    if (-not (Test-Path $scanScript)) {
        Write-Log "ScanCertificates.ps1 nicht gefunden - ueberspringe Daily Scan Task" -Level WARNING
        return $false
    }
    
    try {
        # Task Action
        $arguments = "-NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden " +
                     "-WorkingDirectory `"$InstallPath`" " +
                     "-File `"$scanScript`""
        
        Write-Host "[STEP 1] Action..." -ForegroundColor Yellow
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $arguments
        Write-Host "  Command: powershell.exe" -ForegroundColor Gray
        Write-Host "  Args: $arguments" -ForegroundColor Gray
        
        # Task Trigger
        Write-Host ""
        Write-Host "[STEP 2] Trigger..." -ForegroundColor Yellow
        $trigger = New-ScheduledTaskTrigger -Daily -At $ScanTime
        Write-Host "  Trigger: Daily at $ScanTime" -ForegroundColor Gray
        
        # Task Settings
        Write-Host ""
        Write-Host "[STEP 3] Settings..." -ForegroundColor Yellow
        $settings = New-ScheduledTaskSettingsSet `
            -StartWhenAvailable `
            -ExecutionTimeLimit (New-TimeSpan -Hours 1)
        
        Write-Host "  StartWhenAvailable: Yes" -ForegroundColor Gray
        Write-Host "  ExecutionTimeLimit: 1 hour" -ForegroundColor Gray
        
        # Task Principal
        Write-Host ""
        Write-Host "[STEP 4] Principal..." -ForegroundColor Yellow
        $principal = New-ScheduledTaskPrincipal `
            -UserId "SYSTEM" `
            -LogonType ServiceAccount `
            -RunLevel Highest
        
        Write-Host "  User: SYSTEM" -ForegroundColor Gray
        Write-Host "  LogonType: ServiceAccount" -ForegroundColor Gray
        Write-Host "  RunLevel: Highest" -ForegroundColor Gray
        
        # Register Task
        Write-Host ""
        Write-Host "[STEP 5] Register Task..." -ForegroundColor Yellow
        
        Register-ScheduledTask `
            -TaskName $script:DailyScanTaskName `
            -Action $action `
            -Trigger $trigger `
            -Settings $settings `
            -Principal $principal `
            -Description "CertWebService Daily Certificate Scan - $ScanTime (Regelwerk v10.0.3)" `
            -Force | Out-Null
        
        Write-Log "Task registriert: $script:DailyScanTaskName" -Level SUCCESS
        
        # Verify
        $task = Get-ScheduledTask -TaskName $script:DailyScanTaskName
        Write-Host "  Task Status: $($task.State)" -ForegroundColor Gray
        
        Write-Host ""
        Write-Host "=====================================================================" -ForegroundColor Cyan
        Write-Log "Daily Scan Task erfolgreich erstellt" -Level SUCCESS
        
        return $true
    } catch {
        Write-Log "Fehler beim Erstellen des Daily Scan Tasks: $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

function Show-TaskStatus {
    Show-Banner "TASK STATUS"
    Write-Log "Zeige Task-Status..." -Level INFO
    
    $tasks = Get-ScheduledTask -TaskName "$script:TaskPrefix*" -ErrorAction SilentlyContinue
    
    if ($tasks) {
        Write-Host "Gefundene Tasks:" -ForegroundColor Cyan
        Write-Host ""
        
        foreach ($task in $tasks) {
            $info = Get-ScheduledTaskInfo -TaskName $task.TaskName
            
            Write-Host "  Task: $($task.TaskName)" -ForegroundColor Yellow
            Write-Host "    State: " -NoNewline -ForegroundColor Gray
            
            switch ($task.State) {
                "Running" { Write-Host $task.State -ForegroundColor Green }
                "Ready"   { Write-Host $task.State -ForegroundColor Cyan }
                "Disabled" { Write-Host $task.State -ForegroundColor Red }
                default   { Write-Host $task.State -ForegroundColor Yellow }
            }
            
            Write-Host "    LastRunTime: $($info.LastRunTime)" -ForegroundColor Gray
            Write-Host "    LastTaskResult: $($info.LastTaskResult)" -ForegroundColor Gray
            Write-Host "    NextRunTime: $($info.NextRunTime)" -ForegroundColor Gray
            Write-Host ""
        }
    } else {
        Write-Host "Keine CertWebService Tasks gefunden" -ForegroundColor Yellow
        Write-Log "Keine Tasks gefunden" -Level WARNING
    }
    
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host ""
}

#endregion

#region Main Execution

# Script Start
Show-Banner "CERTWEBSERVICE SCHEDULER SETUP v1.0.0"

Write-Host "Hostname: $env:COMPUTERNAME" -ForegroundColor Gray
Write-Host "User: $env:USERNAME" -ForegroundColor Gray
Write-Host "PowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
Write-Host "InstallPath: $InstallPath" -ForegroundColor Gray
Write-Host "Log-Datei: $script:LogFile" -ForegroundColor Gray
Write-Host ""

Write-Log "=== SCHEDULER SETUP GESTARTET ===" -Level INFO
Write-Log "Hostname: $env:COMPUTERNAME | User: $env:USERNAME" -Level INFO
Write-Log "InstallPath: $InstallPath | Port: $WebServicePort | ScanTime: $ScanTime" -Level INFO

# Prerequisite Checks
$prereqOk = Test-Prerequisites

if (-not $prereqOk) {
    Write-Host ""
    Write-Host "[FATAL] Prerequisite Checks fehlgeschlagen!" -ForegroundColor Red
    Write-Host "Setup kann nicht fortgesetzt werden." -ForegroundColor Red
    Write-Log "Setup abgebrochen: Prerequisite Checks fehlgeschlagen" -Level FATAL
    exit 1
}

# Remove existing tasks
$removedCount = Remove-ExistingTasks

# If RemoveOnly mode, exit here
if ($RemoveOnly) {
    Write-Host ""
    Write-Host "=====================================================================" -ForegroundColor Green
    Write-Host "  REMOVE-ONLY MODE: $removedCount Task(s) entfernt" -ForegroundColor Green
    Write-Host "=====================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Log "Remove-Only Mode: $removedCount Task(s) entfernt" -Level SUCCESS
    exit 0
}

# Create new tasks
$webServiceOk = New-WebServiceTask
$dailyScanOk = New-DailyScanTask

# Show final status
Show-TaskStatus

# Summary
Write-Host ""
Write-Host "=====================================================================" -ForegroundColor Green
Write-Host "  SCHEDULER SETUP ABGESCHLOSSEN" -ForegroundColor Green
Write-Host "=====================================================================" -ForegroundColor Green
Write-Host ""

if ($webServiceOk -and $dailyScanOk) {
    Write-Host "[SUCCESS] Alle Tasks erfolgreich erstellt!" -ForegroundColor Green
    Write-Log "Scheduler Setup erfolgreich abgeschlossen" -Level SUCCESS
} elseif ($webServiceOk) {
    Write-Host "[PARTIAL] Web Service Task erstellt, Daily Scan fehlgeschlagen" -ForegroundColor Yellow
    Write-Log "Scheduler Setup teilweise erfolgreich" -Level WARNING
} else {
    Write-Host "[ERROR] Scheduler Setup fehlgeschlagen!" -ForegroundColor Red
    Write-Log "Scheduler Setup fehlgeschlagen" -Level ERROR
}

Write-Host ""
Write-Host "NAECHSTE SCHRITTE:" -ForegroundColor Cyan
Write-Host "  1. Tasks pruefen:" -ForegroundColor White
Write-Host "     Get-ScheduledTask -TaskName 'CertWebService*'" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Web Service testen:" -ForegroundColor White
Write-Host "     http://localhost:$WebServicePort" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Logs pruefen:" -ForegroundColor White
Write-Host "     Get-Content '$InstallPath\Logs\*.log' -Tail 50" -ForegroundColor Gray
Write-Host ""
Write-Host "  4. Task manuell starten:" -ForegroundColor White
Write-Host "     Start-ScheduledTask -TaskName '$script:WebServiceTaskName'" -ForegroundColor Gray
Write-Host ""

Write-Log "=== SCHEDULER SETUP BEENDET ===" -Level INFO

#endregion
