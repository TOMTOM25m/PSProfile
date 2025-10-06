#Requires -RunAsAdministrator
#Requires -Version 5.1

<#
.SYNOPSIS
    Deploy-Final-v1.0.ps1 - Finales Deployment fuer CertWebService
.DESCRIPTION
    Kopiert alle korrigierten Dateien auf das Netzlaufwerk und richtet
    den Scheduled Task korrekt ein.
.NOTES
    Version: 1.0.0
    Author: GitHub Copilot
    Date: 06.10.2025
#>

$ErrorActionPreference = "Stop"

$localBase = "F:\DEV\repositories\CertWebService"
$networkShare = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService"

Write-Host "=== CertWebService Final Deployment v1.0 ===" -ForegroundColor Cyan
Write-Host ""

# 1. Deploy Hauptskript
Write-Host "[1/3] Deploying CertWebService.ps1..." -ForegroundColor Yellow
Copy-Item -Path "$localBase\CertWebService.ps1" -Destination "$networkShare\" -Force
Write-Host "[OK] CertWebService.ps1 deployed." -ForegroundColor Green

# 2. Deploy Konfiguration
Write-Host "[2/3] Deploying Config-CertWebService.json..." -ForegroundColor Yellow
Copy-Item -Path "$localBase\Config\Config-CertWebService.json" -Destination "$networkShare\Config\" -Force
Write-Host "[OK] Config-CertWebService.json deployed." -ForegroundColor Green

# 3. Deploy Reparatur-Skript
Write-Host "[3/3] Deploying Fix-Installation-v1.3-ASCII.ps1..." -ForegroundColor Yellow
Copy-Item -Path "$localBase\Fix-Installation-v1.3-ASCII.ps1" -Destination "$networkShare\" -Force
Write-Host "[OK] Fix-Installation-v1.3-ASCII.ps1 deployed." -ForegroundColor Green

Write-Host ""
Write-Host "=== DEPLOYMENT ABGESCHLOSSEN ===" -ForegroundColor Green
Write-Host ""
Write-Host "Naechste Schritte auf dem Zielserver (UVWMGMT01):" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Scheduled Task einrichten:" -ForegroundColor White
Write-Host @"
   Unregister-ScheduledTask -TaskName "CertWebService-WebServer" -Confirm:`$false -ErrorAction SilentlyContinue
   
   `$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -Command \`"Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File C:\CertWebService\CertWebService.ps1 -ServiceMode' -RedirectStandardOutput 'C:\CertWebService\Logs\Service-Out.log' -RedirectStandardError 'C:\CertWebService\Logs\Service-Err.log' -NoNewWindow\`""
   
   `$trigger = New-ScheduledTaskTrigger -AtStartup
   
   `$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd -ExecutionTimeLimit ([TimeSpan]::Zero)
   
   `$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
   
   Register-ScheduledTask -TaskName "CertWebService-WebServer" -Action `$action -Trigger `$trigger -Settings `$settings -Principal `$principal -Force
"@ -ForegroundColor Gray
Write-Host ""
Write-Host "2. Manuellen Prozess beenden (falls noch aktiv)" -ForegroundColor White
Write-Host ""
Write-Host "3. Task starten:" -ForegroundColor White
Write-Host "   Start-ScheduledTask -TaskName 'CertWebService-WebServer'" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Testen:" -ForegroundColor White
Write-Host "   Test-NetConnection -ComputerName localhost -Port 9080" -ForegroundColor Gray
Write-Host ""
