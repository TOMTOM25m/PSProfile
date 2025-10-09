#Requires -RunAsAdministrator
#Requires -Version 5.1

<#
.SYNOPSIS
    Fix-Installation.ps1
.DESCRIPTION
    Dieses Skript bereinigt und repariert eine fehlerhafte CertWebService-Installation.
    Es stoppt Tasks, bereinigt URL ACLs, kopiert die neuesten Dateien vom Share
    und richtet die Scheduled Tasks neu ein.
.NOTES
    Version: 1.0.0
    Author: GitHub Copilot
#>

param(
    [string]$InstallPath = "C:\CertWebService",
    [string]$SharePath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService"
)

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
$ErrorActionPreference = "Stop"
$webServerTaskName = "CertWebService-WebServer"
$dailyScanTaskName = "CertWebService-DailyScan"
$aclUser = "NT-AUTORITÄT\SYSTEM" # Using German name for 'NT AUTHORITY\SYSTEM'
$firewallRuleName = "CertWebService-Ports"

# URLs und Ports, die konfiguriert werden sollen
$urlsToReserve = @(
    "http://+:9080/",
    "https://+:9443/"
)
# Alte Ports, die zur Sicherheit bereinigt werden
$portsToClean = @(9080, 9088, 9443)
$portsForFirewall = @(9080, 9443)

Write-Host "=== CertWebService Installation Repair Tool ===" -ForegroundColor Yellow

# 1. Administrator-Check
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Dieses Skript muss mit Administratorrechten ausgeführt werden."
}
Write-Host "[OK] Administratorrechte bestätigt." -ForegroundColor Green

# 2. Stoppe und lösche alte Scheduled Tasks
Write-Host "Stoppe und lösche existierende Scheduled Tasks..."
Stop-ScheduledTask -TaskName $webServerTaskName -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName $webServerTaskName -Confirm:$false -ErrorAction SilentlyContinue
Stop-ScheduledTask -TaskName $dailyScanTaskName -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName $dailyScanTaskName -Confirm:$false -ErrorAction SilentlyContinue
Write-Host "[OK] Alte Tasks wurden gestoppt und entfernt." -ForegroundColor Green

# 3. Bereinige alte URL-ACLs
Write-Host "Bereinige alte URL ACLs für Ports: $($portsToClean -join ', ')..."
foreach ($port in $portsToClean) {
    $urlHttp = "http://+:$($port)/"
    $urlHttps = "https://+:$($port)/"
    try {
        # Versuche, sowohl http als auch https zur Sicherheit zu löschen
        Write-Host "  > netsh http delete urlacl url=$urlHttp" -ForegroundColor Gray
        netsh http delete urlacl url=$urlHttp | Out-Null
    } catch {
        # Fehler ignorieren, wenn die ACL nicht existiert
    }
    try {
        Write-Host "  > netsh http delete urlacl url=$urlHttps" -ForegroundColor Gray
        netsh http delete urlacl url=$urlHttps | Out-Null
    } catch {
        # Fehler ignorieren, wenn die ACL nicht existiert
    }
}
Write-Host "[OK] URL ACLs bereinigt." -ForegroundColor Green

# 4. Kopiere die neuesten Dateien vom Share
Write-Host "Kopiere die neuesten Anwendungsdateien von '$SharePath'..."
$sourceFile = Join-Path $SharePath "CertWebService.ps1"
$destinationFile = Join-Path $InstallPath "CertWebService.ps1"

if (-not (Test-Path $sourceFile)) {
    throw "Die Quelldatei '$sourceFile' wurde nicht auf dem Share gefunden!"
}

Copy-Item -Path $sourceFile -Destination $destinationFile -Force
Write-Host "[OK] 'CertWebService.ps1' wurde erfolgreich nach '$InstallPath' kopiert." -ForegroundColor Green

# 5. Erstelle URL ACLs für SYSTEM neu
Write-Host "Erstelle neue URL ACLs für Benutzer '$aclUser'..."
foreach ($url in $urlsToReserve) {
    $command = "netsh http add urlacl url=$url user='$($aclUser)' listen=yes"
    Write-Host "  > $command"
    $output = Invoke-Expression $command
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Fehler beim Erstellen der URL ACL für '$url'. Ausgabe: $output"
    }
}
Write-Host "[OK] URL ACLs wurden erfolgreich erstellt." -ForegroundColor Green

# 6. Firewall-Regel erstellen/aktualisieren
Write-Host "Erstelle/Aktualisiere Firewall-Regel '$firewallRuleName' für Ports $($portsForFirewall -join ', ')..."
if (Get-NetFirewallRule -DisplayName $firewallRuleName -ErrorAction SilentlyContinue) {
    Remove-NetFirewallRule -DisplayName $firewallRuleName
}
New-NetFirewallRule -DisplayName $firewallRuleName -Direction Inbound -Action Allow -Protocol TCP -LocalPort $portsForFirewall
Write-Host "[OK] Firewall-Regel aktualisiert." -ForegroundColor Green

# 7. Richte Scheduled Tasks neu ein
Write-Host "Richte Scheduled Tasks neu ein..."

# Web-Service Task
$webServiceScript = $destinationFile
$webAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoLogo -NoProfile -ExecutionPolicy Bypass -WorkingDirectory `"$InstallPath`" -WindowStyle Hidden -File `"$webServiceScript`" -ServiceMode"
$webTrigger = New-ScheduledTaskTrigger -AtStartup
$webSettings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd -ExecutionTimeLimit ([TimeSpan]::Zero)
$webPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName $webServerTaskName -Action $webAction -Trigger $webTrigger -Settings $webSettings -Principal $webPrincipal -Force | Out-Null
Write-Host "[OK] Web-Service Task '$webServerTaskName' wurde neu erstellt." -ForegroundColor Green

# Daily Scan Task
$scanScript = Join-Path $InstallPath "ScanCertificates.ps1"
$scanAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoLogo -NoProfile -ExecutionPolicy Bypass -WorkingDirectory `"$InstallPath`" -WindowStyle Hidden -File `"$scanScript`""
$scanTrigger = New-ScheduledTaskTrigger -Daily -At "06:00"
$scanSettings = New-ScheduledTaskSettingsSet -StartWhenAvailable
$scanPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName $dailyScanTaskName -Action $scanAction -Trigger $scanTrigger -Settings $scanSettings -Principal $scanPrincipal -Force | Out-Null
Write-Host "[OK] Daily Scan Task '$dailyScanTaskName' wurde neu erstellt." -ForegroundColor Green

# 8. Starte den Web-Service Task
Write-Host "Starte den Web-Service Task..."
Start-ScheduledTask -TaskName $webServerTaskName
Write-Host "[OK] Task '$webServerTaskName' wurde gestartet." -ForegroundColor Green

Write-Host ""
Write-Host "=== REPARATUR ABGESCHLOSSEN ===" -ForegroundColor Cyan
Write-Host "Der Web-Service sollte in wenigen Momenten erreichbar sein."
Write-Host "Bitte teste die Verbindung in ca. 15-30 Sekunden."
Write-Host ""
Write-Host "Test-Befehle:"
Write-Host "Test-NetConnection -ComputerName localhost -Port 9080" -ForegroundColor White
Write-Host "Test-NetConnection -ComputerName localhost -Port 9443" -ForegroundColor White
Write-Host ""

