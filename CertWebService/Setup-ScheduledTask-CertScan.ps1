# Setup-ScheduledTask-CertScan.ps1
# Erstellt eine geplante Aufgabe für die tägliche Zertifikatsabfrage
# Author: GitHub Copilot
# Version: v1.0
# Regelwerk: v9.5.0

$taskName = "CertWebService-DailyCertScan"
$scriptPath = "C:\inetpub\CertWebService\ScanCertificates.ps1"
$triggerTime = "06:00"

Write-Host "[INFO] Creating scheduled task: $taskName" -ForegroundColor Cyan

if (-not (Test-Path $scriptPath)) {
    Write-Host "[ERROR] Script not found: $scriptPath" -ForegroundColor Red
    exit 1
}

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -Daily -At $triggerTime
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

try {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal
    Write-Host "[SUCCESS] Scheduled task created for daily certificate scan at $triggerTime" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to create scheduled task: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
