#Requires -Version 5.1

<#
.SYNOPSIS
Manage-CertWebService-Tasks.ps1 - Scheduled Tasks Management
.DESCRIPTION
Verwaltet die CertWebService Scheduled Tasks (Web-Service + Daily Scan)
Regelwerk v10.0.2 konform | Stand: 02.10.2025
.PARAMETER Action
Aktion: Status, Start, Stop, Restart, Remove
#>

param(
    [ValidateSet("Status", "Start", "Stop", "Restart", "Remove")]
    [string]$Action = "Status"
)

$webServiceTask = "CertWebService-WebServer"
$dailyScanTask = "CertWebService-DailyScan"

Write-Host "=== CERTWEBSERVICE SCHEDULED TASKS MANAGEMENT ===" -ForegroundColor Green
Write-Host "Regelwerk v10.0.2 | Stand: 02.10.2025" -ForegroundColor Gray
Write-Host ""

function Get-TaskStatus {
    param([string]$TaskName)
    
    try {
        $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
        return @{
            Exists = $true
            State = $task.State
            LastRunTime = (Get-ScheduledTaskInfo -TaskName $TaskName).LastRunTime
            NextRunTime = (Get-ScheduledTaskInfo -TaskName $TaskName).NextRunTime
        }
    } catch {
        return @{ Exists = $false }
    }
}

function Show-TaskStatus {
    param([string]$TaskName, [string]$Description)
    
    Write-Host "$Description ($TaskName):" -ForegroundColor Cyan
    $status = Get-TaskStatus -TaskName $TaskName
    
    if ($status.Exists) {
        $stateColor = switch ($status.State) {
            "Running" { "Green" }
            "Ready" { "Yellow" }
            "Disabled" { "Red" }
            default { "White" }
        }
        Write-Host "  Status: $($status.State)" -ForegroundColor $stateColor
        Write-Host "  Last Run: $($status.LastRunTime)" -ForegroundColor White
        Write-Host "  Next Run: $($status.NextRunTime)" -ForegroundColor White
    } else {
        Write-Host "  Status: NOT FOUND" -ForegroundColor Red
    }
    Write-Host ""
}

switch ($Action) {
    "Status" {
        Write-Host "TASK STATUS:" -ForegroundColor Yellow
        Show-TaskStatus -TaskName $webServiceTask -Description "Web-Service (dauerhaft)"
        Show-TaskStatus -TaskName $dailyScanTask -Description "Daily Scan (06:00 t?glich)"
        
        # Pr?fe ob Web-Service l?uft
        Write-Host "WEB-SERVICE CONNECTION TEST:" -ForegroundColor Yellow
        try {
            $testResult = Test-NetConnection -ComputerName localhost -Port 9080 -InformationLevel Quiet
            if ($testResult) {
                Write-Host " Web-Service erreichbar (Port 9080)" -ForegroundColor Green
            } else {
                Write-Host " Web-Service nicht erreichbar" -ForegroundColor Red
            }
        } catch {
            Write-Host " Connection Test failed" -ForegroundColor Red
        }
    }
    
    "Start" {
        Write-Host "STARTE TASKS..." -ForegroundColor Yellow
        try {
            Start-ScheduledTask -TaskName $webServiceTask
            Write-Host " $webServiceTask gestartet" -ForegroundColor Green
        } catch {
            Write-Host " Fehler bei $webServiceTask : $($_.Exception.Message)" -ForegroundColor Red
        }
        
        try {
            Start-ScheduledTask -TaskName $dailyScanTask  
            Write-Host " $dailyScanTask gestartet" -ForegroundColor Green
        } catch {
            Write-Host " Fehler bei $dailyScanTask : $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    "Stop" {
        Write-Host "STOPPE TASKS..." -ForegroundColor Yellow
        try {
            Stop-ScheduledTask -TaskName $webServiceTask
            Write-Host " $webServiceTask gestoppt" -ForegroundColor Green
        } catch {
            Write-Host " Fehler bei $webServiceTask : $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    "Restart" {
        Write-Host "RESTART TASKS..." -ForegroundColor Yellow
        & $MyInvocation.MyCommand.Path -Action Stop
        Start-Sleep 3
        & $MyInvocation.MyCommand.Path -Action Start
    }
    
    "Remove" {
        Write-Host "ENTFERNE TASKS..." -ForegroundColor Red
        try {
            Unregister-ScheduledTask -TaskName $webServiceTask -Confirm:$false
            Write-Host " $webServiceTask entfernt" -ForegroundColor Green
        } catch {
            Write-Host " Fehler bei $webServiceTask : $($_.Exception.Message)" -ForegroundColor Red
        }
        
        try {
            Unregister-ScheduledTask -TaskName $dailyScanTask -Confirm:$false
            Write-Host " $dailyScanTask entfernt" -ForegroundColor Green
        } catch {
            Write-Host " Fehler bei $dailyScanTask : $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "VERF?GBARE AKTIONEN:" -ForegroundColor Cyan
Write-Host "  .\Manage-CertWebService-Tasks.ps1 -Action Status   # Status anzeigen" -ForegroundColor White
Write-Host "  .\Manage-CertWebService-Tasks.ps1 -Action Start    # Tasks starten" -ForegroundColor White  
Write-Host "  .\Manage-CertWebService-Tasks.ps1 -Action Stop     # Tasks stoppen" -ForegroundColor White
Write-Host "  .\Manage-CertWebService-Tasks.ps1 -Action Restart  # Tasks neustarten" -ForegroundColor White
Write-Host "  .\Manage-CertWebService-Tasks.ps1 -Action Remove   # Tasks entfernen" -ForegroundColor White
