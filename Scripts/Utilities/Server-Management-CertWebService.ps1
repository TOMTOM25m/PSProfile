# CertWebService Scheduled Tasks Management
# Quick Status Check Script
# Version: v1.1.0 | Stand: 02.10.2025

param(
    [ValidateSet("Status", "Start", "Stop", "Restart", "Remove")]
    [string]$Action = "Status"
)

Write-Host "=== CERTWEBSERVICE SCHEDULED TASKS MANAGEMENT ===" -ForegroundColor Magenta
Write-Host "Regelwerk v10.0.2 | Stand: 02.10.2025" -ForegroundColor Gray
Write-Host ""

$webServerTask = "CertWebService-WebServer"
$dailyScanTask = "CertWebService-DailyScan"

switch ($Action) {
    "Status" {
        Write-Host "TASK STATUS:" -ForegroundColor Cyan
        
        # Web-Server Task
        $webTask = Get-ScheduledTask -TaskName $webServerTask -ErrorAction SilentlyContinue
        if ($webTask) {
            Write-Host "Web-Service (dauerhaft) ($webServerTask):" -ForegroundColor Yellow
            Write-Host "  Status: $($webTask.State)" -ForegroundColor Gray
            $webTaskInfo = Get-ScheduledTaskInfo -TaskName $webServerTask -ErrorAction SilentlyContinue
            if ($webTaskInfo) {
                Write-Host "  Last Run: $($webTaskInfo.LastRunTime)" -ForegroundColor Gray
                Write-Host "  Next Run: $($webTaskInfo.NextRunTime)" -ForegroundColor Gray
            }
        } else {
            Write-Host "❌ Web-Service Task nicht gefunden!" -ForegroundColor Red
        }
        
        Write-Host ""
        
        # Daily Scan Task  
        $scanTask = Get-ScheduledTask -TaskName $dailyScanTask -ErrorAction SilentlyContinue
        if ($scanTask) {
            Write-Host "Daily Scan (06:00 täglich) ($dailyScanTask):" -ForegroundColor Yellow
            Write-Host "  Status: $($scanTask.State)" -ForegroundColor Gray
            $scanTaskInfo = Get-ScheduledTaskInfo -TaskName $dailyScanTask -ErrorAction SilentlyContinue
            if ($scanTaskInfo) {
                Write-Host "  Last Run: $($scanTaskInfo.LastRunTime)" -ForegroundColor Gray
                Write-Host "  Next Run: $($scanTaskInfo.NextRunTime)" -ForegroundColor Gray
            }
        } else {
            Write-Host "❌ Daily Scan Task nicht gefunden!" -ForegroundColor Red
        }
        
        Write-Host ""
        Write-Host "WEB-SERVICE CONNECTION TEST:" -ForegroundColor Cyan
        try {
            $response = Invoke-WebRequest "http://localhost:9080/" -UseBasicParsing -TimeoutSec 3
            Write-Host "✅ Web-Service erreichbar (Port 9080)" -ForegroundColor Green
        } catch {
            Write-Host "❌ Web-Service nicht erreichbar: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        Write-Host ""
        Write-Host "VERFÜGBARE AKTIONEN:" -ForegroundColor Cyan
        Write-Host "  .\Manage-CertWebService-Tasks.ps1 -Action Status   # Status anzeigen" -ForegroundColor Gray
        Write-Host "  .\Manage-CertWebService-Tasks.ps1 -Action Start    # Tasks starten" -ForegroundColor Gray
        Write-Host "  .\Manage-CertWebService-Tasks.ps1 -Action Stop     # Tasks stoppen" -ForegroundColor Gray
        Write-Host "  .\Manage-CertWebService-Tasks.ps1 -Action Restart  # Tasks neustarten" -ForegroundColor Gray
        Write-Host "  .\Manage-CertWebService-Tasks.ps1 -Action Remove   # Tasks entfernen" -ForegroundColor Gray
    }
    
    "Start" {
        Write-Host "Starte CertWebService Tasks..." -ForegroundColor Yellow
        try {
            Start-ScheduledTask -TaskName $webServerTask -ErrorAction Stop
            Write-Host "✅ Web-Service Task gestartet" -ForegroundColor Green
        } catch {
            Write-Host "❌ Fehler beim Starten des Web-Service Tasks: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        Write-Host "Daily Scan Task läuft automatisch täglich um 06:00" -ForegroundColor Gray
    }
    
    "Stop" {
        Write-Host "Stoppe CertWebService Tasks..." -ForegroundColor Yellow
        try {
            Stop-ScheduledTask -TaskName $webServerTask -ErrorAction Stop
            Write-Host "✅ Web-Service Task gestoppt" -ForegroundColor Green
        } catch {
            Write-Host "❌ Fehler beim Stoppen des Web-Service Tasks: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    "Restart" {
        Write-Host "Starte CertWebService Tasks neu..." -ForegroundColor Yellow
        try {
            Stop-ScheduledTask -TaskName $webServerTask -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 3
            Start-ScheduledTask -TaskName $webServerTask -ErrorAction Stop
            Write-Host "✅ Web-Service Task neugestartet" -ForegroundColor Green
        } catch {
            Write-Host "❌ Fehler beim Neustarten: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    "Remove" {
        Write-Host "Entferne CertWebService Tasks..." -ForegroundColor Yellow
        Write-Host "⚠️  WARNUNG: Alle Tasks werden entfernt!" -ForegroundColor Red
        $confirm = Read-Host "Fortfahren? (y/N)"
        if ($confirm -eq 'y' -or $confirm -eq 'Y') {
            try {
                Unregister-ScheduledTask -TaskName $webServerTask -Confirm:$false -ErrorAction SilentlyContinue
                Unregister-ScheduledTask -TaskName $dailyScanTask -Confirm:$false -ErrorAction SilentlyContinue
                Write-Host "✅ Tasks entfernt" -ForegroundColor Green
            } catch {
                Write-Host "❌ Fehler beim Entfernen: $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "Abgebrochen." -ForegroundColor Gray
        }
    }
}

Write-Host ""
Write-Host "=== HINWEIS ===" -ForegroundColor Yellow  
Write-Host "CertWebService verwendet SCHEDULED TASKS statt Windows Services!" -ForegroundColor Gray
Write-Host "Web-Dashboard: http://localhost:9080" -ForegroundColor Cyan