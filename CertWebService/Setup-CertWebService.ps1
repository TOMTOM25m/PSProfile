#Requires -RunAsAdministrator
#Requires -Version 5.1

<#
.SYNOPSIS
    Setup-CertWebService.ps1 - Vollstaendige Installation des CertWebService
.DESCRIPTION
    Dieses Skript installiert den CertWebService komplett:
    - Kopiert alle Dateien vom Netzlaufwerk nach C:\CertWebService
    - Erstellt Scheduled Tasks
    - Konfiguriert URL ACLs und Firewall
    - Startet den Service
.NOTES
    Version: 1.0.0
    Regelwerk: v10.0.2
    Author: GitHub Copilot
    Date: 2025-10-06
#>

param(
    [string]$SharePath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService",
    [string]$InstallPath = "C:\CertWebService"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  CertWebService Setup v1.0.0" -ForegroundColor Cyan
Write-Host "  Regelwerk v10.0.2" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Administrator-Check
Write-Host "[1/8] Pruefe Administratorrechte..." -ForegroundColor Yellow
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Dieses Skript muss mit Administratorrechten ausgefuehrt werden."
}
Write-Host "      [OK] Administrator-Rechte bestaetigt." -ForegroundColor Green

# 2. Pruefe Netzlaufwerk
Write-Host "[2/8] Pruefe Zugriff auf Netzlaufwerk..." -ForegroundColor Yellow
if (-not (Test-Path $SharePath)) {
    throw "Netzlaufwerk '$SharePath' ist nicht erreichbar!"
}
Write-Host "      [OK] Netzlaufwerk erreichbar." -ForegroundColor Green

# 3. Erstelle Zielverzeichnis
Write-Host "[3/8] Erstelle Installationsverzeichnis..." -ForegroundColor Yellow
if (-not (Test-Path $InstallPath)) {
    New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null
}
# Erstelle Unterverzeichnisse
@("Config", "Logs", "Scripts") | ForEach-Object {
    $dir = Join-Path $InstallPath $_
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
}
Write-Host "      [OK] Verzeichnisstruktur erstellt: $InstallPath" -ForegroundColor Green

# 4. Kopiere Dateien
Write-Host "[4/8] Kopiere Dateien vom Netzlaufwerk..." -ForegroundColor Yellow
$filesToCopy = @(
    @{Source="CertWebService.ps1"; Dest="CertWebService.ps1"},
    @{Source="Config\Config-CertWebService.json"; Dest="Config\Config-CertWebService.json"}
)

foreach ($file in $filesToCopy) {
    $source = Join-Path $SharePath $file.Source
    $dest = Join-Path $InstallPath $file.Dest
    if (Test-Path $source) {
        Copy-Item -Path $source -Destination $dest -Force
        Write-Host "      [OK] $($file.Source)" -ForegroundColor Green
    } else {
        Write-Warning "      [SKIP] $($file.Source) nicht gefunden"
    }
}

# 5. Bereinige alte Tasks und ACLs
Write-Host "[5/8] Bereinige alte Konfiguration..." -ForegroundColor Yellow
Get-ScheduledTask -TaskName "CertWebService-*" -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false
@(9080, 9088, 9443) | ForEach-Object {
    netsh http delete urlacl url="http://+:$($_)/" 2>&1 | Out-Null
    netsh http delete urlacl url="https://+:$($_)/" 2>&1 | Out-Null
}
Write-Host "      [OK] Alte Konfiguration entfernt." -ForegroundColor Green

# 6. Erstelle URL ACLs
Write-Host "[6/8] Erstelle URL ACLs..." -ForegroundColor Yellow
netsh http add urlacl url="http://+:9080/" user="NT AUTHORITY\SYSTEM" listen=yes | Out-Null
netsh http add urlacl url="https://+:9443/" user="NT AUTHORITY\SYSTEM" listen=yes | Out-Null
Write-Host "      [OK] URL ACLs erstellt (Ports 9080, 9443)." -ForegroundColor Green

# 7. Firewall-Regel
Write-Host "[7/8] Konfiguriere Firewall..." -ForegroundColor Yellow
$ruleName = "CertWebService-Ports"
if (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue) {
    Remove-NetFirewallRule -DisplayName $ruleName
}
New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Allow -Protocol TCP -LocalPort 9080,9443 | Out-Null
Write-Host "      [OK] Firewall-Regel erstellt." -ForegroundColor Green

# 8. Erstelle Scheduled Task (mit funktionierender Start-Process-Methode)
Write-Host "[8/8] Erstelle Scheduled Task..." -ForegroundColor Yellow

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File C:\CertWebService\CertWebService.ps1 -ServiceMode' -RedirectStandardOutput 'C:\CertWebService\Logs\Service-Out.log' -RedirectStandardError 'C:\CertWebService\Logs\Service-Err.log' -NoNewWindow`""

$trigger = New-ScheduledTaskTrigger -AtStartup

$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd -ExecutionTimeLimit ([TimeSpan]::Zero)

$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName "CertWebService-WebServer" -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null

Write-Host "      [OK] Scheduled Task 'CertWebService-WebServer' erstellt." -ForegroundColor Green

# 9. Starte den Service
Write-Host ""
Write-Host "Starte den Service..." -ForegroundColor Yellow
Start-ScheduledTask -TaskName "CertWebService-WebServer"
Start-Sleep -Seconds 10

# 10. Teste die Verbindung
Write-Host ""
Write-Host "Teste Verbindung..." -ForegroundColor Yellow
$testResult = Test-NetConnection -ComputerName localhost -Port 9080 -WarningAction SilentlyContinue

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
if ($testResult.TcpTestSucceeded) {
    Write-Host "  INSTALLATION ERFOLGREICH!" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Der CertWebService ist jetzt aktiv!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Dashboard: http://localhost:9080/" -ForegroundColor White
    Write-Host "API:       http://localhost:9080/certificates.json" -ForegroundColor White
    Write-Host ""
    Write-Host "Der Service startet automatisch beim Neustart des Servers." -ForegroundColor Cyan
} else {
    Write-Host "  WARNUNG: Service laeuft nicht!" -ForegroundColor Yellow
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Der Service wurde installiert, aber Port 9080 ist nicht erreichbar." -ForegroundColor Yellow
    Write-Host "Bitte pruefen Sie die Logs:" -ForegroundColor White
    Write-Host "  - C:\CertWebService\Logs\Service-Out.log" -ForegroundColor Gray
    Write-Host "  - C:\CertWebService\Logs\Service-Err.log" -ForegroundColor Gray
    Write-Host "  - C:\CertWebService\Logs\CertWebService_*.log" -ForegroundColor Gray
}
Write-Host ""
