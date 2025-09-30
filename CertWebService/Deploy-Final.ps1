#requires -Version 5.1
#Requires -RunAsAdministrator

param(
    [string]$NetworkPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService",
    [switch]$BackupExisting
)

Write-Host "Certificate WebService - Network Deployment v2.3.0" -ForegroundColor Cyan
Write-Host ""

try {
    # Verify network access
    if (-not (Test-Path $NetworkPath)) {
        throw "Network path not accessible: $NetworkPath"
    }
    Write-Host "Network path accessible" -ForegroundColor Green
    
    # Backup if requested
    if ($BackupExisting) {
        $timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm"
        $backupPath = "$NetworkPath-Backup-$timestamp"
        Copy-Item -Path $NetworkPath -Destination $backupPath -Recurse -Force
        Write-Host "Backup created: $backupPath" -ForegroundColor Green
    }
    
    # Create Setup.ps1
    $setupScript = @"
#requires -Version 5.1
#Requires -RunAsAdministrator

Write-Host "Certificate WebService Setup v2.3.0" -ForegroundColor Cyan

try {
    # Enable IIS features
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole -All -NoRestart -ErrorAction SilentlyContinue
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServer -All -NoRestart -ErrorAction SilentlyContinue
    
    # Create site directory
    `$sitePath = "C:\inetpub\CertWebService"
    New-Item -Path `$sitePath -ItemType Directory -Force | Out-Null
    
    # Create certificates.json
    `$certificates = @{
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        server = `$env:COMPUTERNAME
        certificates = @(@{
            subject = "CN=`$env:COMPUTERNAME"
            issuer = "Internal CA"
            expiry = (Get-Date).AddDays(365).ToString("yyyy-MM-dd")
            status = "Valid"
        })
        total_count = 1
    } | ConvertTo-Json -Depth 5
    
    `$certificates | Set-Content "`$sitePath\certificates.json" -Encoding UTF8
    
    # Create health.json
    `$health = @{
        status = "healthy"
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        server = `$env:COMPUTERNAME
        version = "2.3.0"
    } | ConvertTo-Json
    
    `$health | Set-Content "`$sitePath\health.json" -Encoding UTF8
    
    # Create index.html
    `$html = "<!DOCTYPE html><html><head><title>Certificate WebService v2.3.0</title></head><body><h1>Certificate WebService v2.3.0</h1><p>Server: `$env:COMPUTERNAME</p><p>API: <a href='/certificates.json'>certificates.json</a></p></body></html>"
    `$html | Set-Content "`$sitePath\index.html" -Encoding UTF8
    
    # Configure IIS
    Import-Module WebAdministration -ErrorAction SilentlyContinue
    
    if (Get-IISSite -Name "CertWebService" -ErrorAction SilentlyContinue) {
        Remove-IISSite -Name "CertWebService" -Confirm:`$false
    }
    
    New-IISSite -Name "CertWebService" -PhysicalPath `$sitePath -Port 9080
    
    # Configure firewall
    New-NetFirewallRule -DisplayName "CertWebService" -Direction Inbound -Protocol TCP -LocalPort 9080 -Action Allow -ErrorAction SilentlyContinue
    
    Write-Host "Installation successful!" -ForegroundColor Green
    Write-Host "Access: http://`$env:COMPUTERNAME:9080/" -ForegroundColor Cyan
    
} catch {
    Write-Host "Installation failed: `$(`$_.Exception.Message)" -ForegroundColor Red
    exit 1
}
"@
    
    $setupPath = Join-Path $NetworkPath "Setup.ps1"
    $setupScript | Set-Content -Path $setupPath -Encoding UTF8
    Write-Host "Created Setup.ps1" -ForegroundColor Green
    
    # Create Install.bat
    $batchInstaller = @"
@echo off
title Certificate WebService v2.3.0

echo Certificate WebService v2.3.0 Installer
echo ========================================

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: Administrator privileges required!
    pause
    exit /b 1
)

set TEMP_DIR=C:\Temp\CertWebService
if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%"
mkdir "%TEMP_DIR%"

xcopy "%~dp0*" "%TEMP_DIR%\" /e /i /h /y >nul

PowerShell.exe -ExecutionPolicy Bypass -File "%TEMP_DIR%\Setup.ps1"

if %errorLevel% equ 0 (
    echo Installation completed successfully!
    echo Access: http://%COMPUTERNAME%:9080/
) else (
    echo Installation failed!
)

if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%"
pause
"@
    
    $batchPath = Join-Path $NetworkPath "Install.bat"
    $batchInstaller | Set-Content -Path $batchPath -Encoding ASCII
    Write-Host "Created Install.bat" -ForegroundColor Green
    
    # Create Test.ps1
    $testScript = @"
param([string]`$Server = `$env:COMPUTERNAME)

Write-Host "Testing Certificate WebService on `$Server" -ForegroundColor Cyan

`$tests = @(
    @{Name="Dashboard"; Url="http://`$Server:9080/"},
    @{Name="Health"; Url="http://`$Server:9080/health.json"},
    @{Name="Certificates"; Url="http://`$Server:9080/certificates.json"}
)

`$passed = 0
foreach (`$test in `$tests) {
    try {
        `$response = Invoke-WebRequest -Uri `$test.Url -UseBasicParsing -TimeoutSec 10
        if (`$response.StatusCode -eq 200) {
            Write-Host "OK `$(`$test.Name)" -ForegroundColor Green
            `$passed++
        } else {
            Write-Host "FAIL `$(`$test.Name): HTTP `$(`$response.StatusCode)" -ForegroundColor Red
        }
    } catch {
        Write-Host "FAIL `$(`$test.Name): `$(`$_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "Results: `$passed/`$(`$tests.Count) tests passed" -ForegroundColor Cyan
if (`$passed -eq `$tests.Count) {
    Write-Host "All tests passed!" -ForegroundColor Green
} else {
    Write-Host "Some tests failed" -ForegroundColor Yellow
}
"@
    
    $testPath = Join-Path $NetworkPath "Test.ps1"
    $testScript | Set-Content -Path $testPath -Encoding UTF8
    Write-Host "Created Test.ps1" -ForegroundColor Green
    
    # Create README.txt
    $readme = @"
Certificate WebService v2.3.0 - Network Deployment
==================================================

INSTALLATION:
1. Run as Administrator: Install.bat
2. Test: Test.ps1
3. Access: http://SERVER:9080/

API ENDPOINTS:
- GET /certificates.json
- GET /health.json

INTEGRATION:
Works with Certificate Surveillance System (CertSurv)

VERSION: v2.3.0
BUILD: $(Get-Date -Format 'yyyy-MM-dd')
COMPLIANCE: Regelwerk v10.0.0
"@
    
    $readmePath = Join-Path $NetworkPath "README.txt"
    $readme | Set-Content -Path $readmePath -Encoding UTF8
    Write-Host "Created README.txt" -ForegroundColor Green
    
    # Create VERSION.txt
    $version = @"
Certificate WebService Deployment Package
Version: v2.3.0
Build: $(Get-Date -Format 'yyyy-MM-dd')
Compliance: Regelwerk v10.0.0

FEATURES:
- Network Share Deployment
- Automatic IIS Configuration
- JSON API Endpoints
- HTML Dashboard
- CertSurv Integration
- PowerShell 5.1/7.x Compatible

INSTALLATION: Run Install.bat as Administrator
API ACCESS: http://SERVER:9080/certificates.json
"@
    
    $versionPath = Join-Path $NetworkPath "VERSION.txt"
    $version | Set-Content -Path $versionPath -Encoding UTF8
    Write-Host "Created VERSION.txt" -ForegroundColor Green
    
    # Summary
    $files = Get-ChildItem $NetworkPath -File
    
    Write-Host ""
    Write-Host "NETWORK DEPLOYMENT PACKAGE CREATED!" -ForegroundColor Green
    Write-Host "Location: $NetworkPath" -ForegroundColor Cyan
    Write-Host "Files: $($files.Count)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Package Contents:" -ForegroundColor Yellow
    foreach ($file in $files) {
        Write-Host "  $($file.Name)" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "READY FOR DEPLOYMENT!" -ForegroundColor Green
    Write-Host "1. Navigate to: $NetworkPath" -ForegroundColor White
    Write-Host "2. Run: Install.bat (as Administrator)" -ForegroundColor White
    Write-Host "3. Test: Test.ps1" -ForegroundColor White
    Write-Host ""
    
} catch {
    Write-Host "Deployment failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}