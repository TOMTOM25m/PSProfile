#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
CertWebService Setup Script
.DESCRIPTION
Hauptinstallations-Script f?r CertWebService v2.4.0
Regelwerk v10.0.Write-Host "📋 Next Steps:" -ForegroundColor Cyan
Write-Host "   1. Open browser: http://localhost:$Port" -ForegroundColor White
Write-Host "   2. Check tasks: Get-ScheduledTask *CertWebService*" -ForegroundColor White
Write-Host "   3. View logs: Get-Content $InstallPath\Logs\*.log" -ForegroundColor White
Write-Host "   4. Daily scan runs automatically at 06:00" -ForegroundColor Whitenform | Stand: 02.10.2025
.PARAMETER Port
Standard HTTP Port (Default: 9080)
.PARAMETER InstallPath
Installationspfad (Default: C:\CertWebService)
.PARAMETER CreateService
Erstelle Scheduled Tasks (Web-Service + Daily Scan) (Default: $true)
#>

param(
    [int]$Port = 9080,
    [string]$InstallPath = "C:\CertWebService",
    [bool]$CreateService = $true,
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"

# === INSTALLATION SETUP ===
Write-Host "=== CERTWEBSERVICE SETUP v2.4.0 ===" -ForegroundColor Green
Write-Host "Regelwerk v10.0.2 | Stand: 02.10.2025" -ForegroundColor Gray
Write-Host ""

if (-not $Quiet) {
    Write-Host "Installation Parameters:" -ForegroundColor Cyan
    Write-Host "  Port: $Port" -ForegroundColor White
    Write-Host "  Path: $InstallPath" -ForegroundColor White
    Write-Host "  Service: $CreateService" -ForegroundColor White
    Write-Host ""
}

# === ADMINISTRATOR CHECK ===
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Administrator privileges required!"
}

# === CREATE INSTALLATION DIRECTORY ===
Write-Host "[1/5] Creating installation directory..." -ForegroundColor Yellow
if (-not (Test-Path $InstallPath)) {
    New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null
    Write-Host "      Created: $InstallPath" -ForegroundColor Green
} else {
    Write-Host "      Exists: $InstallPath" -ForegroundColor Green
}

# === COPY FILES ===
Write-Host "[2/5] Copying application files..." -ForegroundColor Yellow
$sourceFiles = @(
    "ScanCertificates.ps1",
    "Modules",
    "Config", 
    "Scripts",
    "WebFiles"
)

foreach ($item in $sourceFiles) {
    if (Test-Path $item) {
        $dest = Join-Path $InstallPath $item
        if (Test-Path $dest) {
            Remove-Item $dest -Recurse -Force
        }
        Copy-Item $item $dest -Recurse -Force
        Write-Host "      Copied: $item" -ForegroundColor Green
    } else {
        Write-Host "      Missing: $item (skipped)" -ForegroundColor Yellow
    }
}

# === CONFIGURE PORT ===
Write-Host "[3/5] Configuring port settings..." -ForegroundColor Yellow
$configFile = Join-Path $InstallPath "Config\CertSurv-Config.json"
if (Test-Path $configFile) {
    $config = Get-Content $configFile | ConvertFrom-Json
    $config.WebServicePort = $Port
    $config | ConvertTo-Json -Depth 3 | Out-File $configFile -Encoding UTF8
    Write-Host "      Port configured: $Port" -ForegroundColor Green
} else {
    # Create basic config
    $basicConfig = @{
        WebServicePort = $Port
        ScanInterval = 3600
        LogLevel = "INFO"
        EmailNotifications = $true
        CertificateThreshold = 30
    }
    $basicConfig | ConvertTo-Json -Depth 3 | Out-File $configFile -Encoding UTF8 -Force
    Write-Host "      Basic config created: $Port" -ForegroundColor Green
}

# === FIREWALL RULE ===
Write-Host "[4/5] Configuring firewall..." -ForegroundColor Yellow
try {
    $ruleName = "CertWebService-HTTP-$Port"
    $existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    if ($existingRule) {
        Remove-NetFirewallRule -DisplayName $ruleName
    }
    New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow | Out-Null
    Write-Host "      Firewall rule created: Port $Port" -ForegroundColor Green
} catch {
    Write-Host "      Firewall configuration failed: $($_.Exception.Message)" -ForegroundColor Red
}

# === SCHEDULED TASKS ===
Write-Host "[5/5] Configuring Scheduled Tasks..." -ForegroundColor Yellow
if ($CreateService) {
    try {
        # 1. Web-Service Scheduled Task (läuft dauerhaft)
        $webServiceTaskName = "CertWebService-WebServer"
        $webServiceScript = Join-Path $InstallPath "CertWebService.ps1"
        
        Write-Host "      Erstelle Web-Service Task..." -ForegroundColor Cyan
        $webAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$webServiceScript`" -ServiceMode"
        $webTrigger = New-ScheduledTaskTrigger -AtStartup
        $webSettings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd
        $webPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        
        Unregister-ScheduledTask -TaskName $webServiceTaskName -Confirm:$false -ErrorAction SilentlyContinue
        Register-ScheduledTask -TaskName $webServiceTaskName -Action $webAction -Trigger $webTrigger -Settings $webSettings -Principal $webPrincipal -Force | Out-Null
        Start-ScheduledTask -TaskName $webServiceTaskName
        Write-Host "      ✅ Web-Service Task erstellt und gestartet" -ForegroundColor Green
        
        # 2. Daily Scan Scheduled Task (1x täglich um 06:00)
        $scanTaskName = "CertWebService-DailyScan" 
        $scanScript = Join-Path $InstallPath "ScanCertificates.ps1"
        
        Write-Host "      Erstelle Daily Scan Task..." -ForegroundColor Cyan
        $scanAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scanScript`""
        $scanTrigger = New-ScheduledTaskTrigger -Daily -At "06:00"
        $scanSettings = New-ScheduledTaskSettingsSet -StartWhenAvailable
        $scanPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        
        Unregister-ScheduledTask -TaskName $scanTaskName -Confirm:$false -ErrorAction SilentlyContinue  
        Register-ScheduledTask -TaskName $scanTaskName -Action $scanAction -Trigger $scanTrigger -Settings $scanSettings -Principal $scanPrincipal -Force | Out-Null
        Write-Host "      ✅ Daily Scan Task erstellt (läuft täglich um 06:00)" -ForegroundColor Green
        
    } catch {
        Write-Host "      ❌ Scheduled Tasks creation failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "      You can start manually:" -ForegroundColor Yellow
        Write-Host "        Web-Service: powershell.exe -File `"$webServiceScript`"" -ForegroundColor Gray
        Write-Host "        Daily Scan: powershell.exe -File `"$scanScript`"" -ForegroundColor Gray
    }
}

# === INSTALLATION COMPLETE ===
Write-Host ""
Write-Host "=== INSTALLATION COMPLETE ===" -ForegroundColor Green
Write-Host "Web Service URL: http://localhost:$Port" -ForegroundColor Cyan
Write-Host "API Endpoint: http://localhost:$Port/api/certificates.json" -ForegroundColor Cyan
Write-Host "Installation Path: $InstallPath" -ForegroundColor Gray
Write-Host ""

# === TEST CONNECTION ===
Write-Host "Testing connection..." -ForegroundColor Yellow
Start-Sleep 3
try {
    $testResult = Test-NetConnection -ComputerName localhost -Port $Port -InformationLevel Quiet
    if ($testResult) {
        Write-Host " Service is running on port $Port" -ForegroundColor Green
    } else {
        Write-Host "  Service may need a moment to start" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  Connection test failed - service may need manual start" -ForegroundColor Yellow
}

Write-Host ""
Write-Host " Next Steps:" -ForegroundColor Cyan
Write-Host "   1. Open browser: http://localhost:$Port" -ForegroundColor White
Write-Host "   2. Check service: Get-Service CertWebService" -ForegroundColor White
Write-Host "   3. View logs: Get-Content $InstallPath\Logs\*.log" -ForegroundColor White
Write-Host ""

if (-not $Quiet) {
    Write-Host "Installation completed successfully! " -ForegroundColor Green
}
