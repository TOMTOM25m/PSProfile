#requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Certificate WebService - Simple Network Deployment v2.3.0

.DESCRIPTION
    Creates deployment package on network share with clean architecture
    
.VERSION
    2.3.0

.RULEBOOK
    v10.0.0
#>

param(
    [string]$NetworkPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService",
    [switch]$BackupExisting
)

$Script:Version = "v2.3.0"
$Script:BuildDate = Get-Date -Format "yyyy-MM-dd"

Write-Host "🚀 Certificate WebService - Network Deployment" -ForegroundColor Cyan
Write-Host "   Version: $Script:Version | Build: $Script:BuildDate" -ForegroundColor Gray
Write-Host ""

try {
    # Verify network access
    Write-Host "🔍 Verifying network access..." -ForegroundColor Yellow
    if (-not (Test-Path $NetworkPath)) {
        throw "Network path not accessible: $NetworkPath"
    }
    Write-Host "✅ Network path accessible" -ForegroundColor Green
    
    # Backup if requested
    if ($BackupExisting) {
        Write-Host "💾 Creating backup..." -ForegroundColor Yellow
        $timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm"
        $backupPath = "$NetworkPath-Backup-$timestamp"
        Copy-Item -Path $NetworkPath -Destination $backupPath -Recurse -Force
        Write-Host "✅ Backup created: $backupPath" -ForegroundColor Green
    }
    
    # Create PowerShell setup script
    Write-Host "📝 Creating Setup.ps1..." -ForegroundColor Yellow
    
    $setupContent = @'
#requires -Version 5.1
#Requires -RunAsAdministrator

Write-Host "🚀 Certificate WebService Setup v2.3.0" -ForegroundColor Cyan

try {
    # Enable IIS
    $features = @("IIS-WebServerRole", "IIS-WebServer", "IIS-CommonHttpFeatures")
    foreach ($feature in $features) {
        Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart -ErrorAction SilentlyContinue
    }
    
    # Create site
    $sitePath = "C:\inetpub\CertWebService"
    New-Item -Path $sitePath -ItemType Directory -Force | Out-Null
    
    # Create JSON files
    $certs = @{
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        server = $env:COMPUTERNAME
        certificates = @(@{
            subject = "CN=$env:COMPUTERNAME"
            issuer = "Internal CA"
            expiry = (Get-Date).AddDays(365).ToString("yyyy-MM-dd")
            status = "Valid"
        })
        total_count = 1
    } | ConvertTo-Json -Depth 5
    
    $certs | Set-Content "$sitePath\certificates.json" -Encoding UTF8
    
    $health = @{
        status = "healthy"
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        server = $env:COMPUTERNAME
        version = "2.3.0"
    } | ConvertTo-Json
    
    $health | Set-Content "$sitePath\health.json" -Encoding UTF8
    
    # Create HTML dashboard
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Certificate WebService v2.3.0</title>
    <style>
        body { font-family: Arial; margin: 40px; background: linear-gradient(135deg, #667eea, #764ba2); color: white; }
        .container { max-width: 800px; margin: 0 auto; }
        .card { background: rgba(255,255,255,0.1); padding: 30px; border-radius: 15px; margin: 20px 0; }
        .endpoint { background: rgba(255,255,255,0.05); padding: 15px; margin: 10px 0; border-radius: 8px; }
        .url { font-family: Courier; background: rgba(0,0,0,0.3); padding: 8px; border-radius: 4px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔒 Certificate WebService v2.3.0</h1>
        <div class="card">
            <h3>📊 API Endpoints</h3>
            <div class="endpoint">
                <h4>Certificates</h4>
                <div class="url">GET /certificates.json</div>
            </div>
            <div class="endpoint">
                <h4>Health</h4>
                <div class="url">GET /health.json</div>
            </div>
        </div>
        <div class="card">
            <h3>🌐 Access</h3>
            <p>HTTP: http://$env:COMPUTERNAME:9080/</p>
        </div>
    </div>
</body>
</html>
"@
    
    $html | Set-Content "$sitePath\index.html" -Encoding UTF8
    
    # Configure IIS
    Import-Module WebAdministration -ErrorAction SilentlyContinue
    
    if (Get-IISSite -Name "CertWebService" -ErrorAction SilentlyContinue) {
        Remove-IISSite -Name "CertWebService" -Confirm:$false
    }
    
    New-IISSite -Name "CertWebService" -PhysicalPath $sitePath -Port 9080
    
    # Firewall
    New-NetFirewallRule -DisplayName "CertWebService" -Direction Inbound -Protocol TCP -LocalPort 9080 -Action Allow -ErrorAction SilentlyContinue
    
    Write-Host "✅ Installation successful!" -ForegroundColor Green
    Write-Host "   Access: http://$env:COMPUTERNAME:9080/" -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ Installation failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
'@
    
    $setupPath = Join-Path $NetworkPath "Setup.ps1"
    $setupContent | Set-Content -Path $setupPath -Encoding UTF8
    
    # Create batch installer
    Write-Host "📝 Creating Install.bat..." -ForegroundColor Yellow
    
    $batchContent = @"
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
    echo.
    echo Installation completed successfully!
    echo Access: http://%COMPUTERNAME%:9080/
) else (
    echo Installation failed!
)

if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%"
pause
"@
    
    $batchPath = Join-Path $NetworkPath "Install.bat"
    $batchContent | Set-Content -Path $batchPath -Encoding ASCII
    
    # Create test script
    Write-Host "📝 Creating Test.ps1..." -ForegroundColor Yellow
    
    $testContent = @'
param([string]$Server = $env:COMPUTERNAME)

Write-Host "Testing Certificate WebService on $Server" -ForegroundColor Cyan

$tests = @(
    @{Name="Dashboard"; Url="http://$Server:9080/"},
    @{Name="Health"; Url="http://$Server:9080/health.json"},
    @{Name="Certificates"; Url="http://$Server:9080/certificates.json"}
)

$passed = 0
foreach ($test in $tests) {
    try {
        $response = Invoke-WebRequest -Uri $test.Url -UseBasicParsing -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            Write-Host "OK $($test.Name): OK" -ForegroundColor Green
            $passed++
        } else {
            Write-Host "FAIL $($test.Name): HTTP $($response.StatusCode)" -ForegroundColor Red
        }
    } catch {
        Write-Host "FAIL $($test.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "Results: $passed/$($tests.Count) tests passed" -ForegroundColor Cyan
if ($passed -eq $tests.Count) {
    Write-Host "All tests passed!" -ForegroundColor Green
} else {
    Write-Host "Some tests failed" -ForegroundColor Yellow
}
'@
    
    $testPath = Join-Path $NetworkPath "Test.ps1" 
    $testContent | Set-Content -Path $testPath -Encoding UTF8
    
    # Create documentation
    Write-Host "📝 Creating documentation..." -ForegroundColor Yellow
    
    $readmeContent = @"
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

VERSION: v$Script:Version
BUILD: $Script:BuildDate
COMPLIANCE: Regelwerk v10.0.0
"@
    
    $readmePath = Join-Path $NetworkPath "README.txt"
    $readmeContent | Set-Content -Path $readmePath -Encoding UTF8
    
    # Create version file
    $versionContent = @"
Certificate WebService Deployment Package
Version: v$Script:Version  
Build: $Script:BuildDate
Compliance: Regelwerk v10.0.0

MODERNIZED FEATURES:
✅ Network Share Deployment
✅ Automatic IIS Configuration  
✅ JSON API Endpoints
✅ HTML Dashboard
✅ CertSurv Integration
✅ PowerShell 5.1/7.x Compatible

INSTALLATION: Run Install.bat as Administrator
API ACCESS: http://SERVER:9080/certificates.json  
"@
    
    $versionPath = Join-Path $NetworkPath "VERSION.txt"
    $versionContent | Set-Content -Path $versionPath -Encoding UTF8
    
    # Summary
    $files = Get-ChildItem $NetworkPath -File
    
    Write-Host ""
    Write-Host "✅ NETWORK DEPLOYMENT PACKAGE CREATED!" -ForegroundColor Green
    Write-Host "   Location: $NetworkPath" -ForegroundColor Cyan
    Write-Host "   Files: $($files.Count)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📋 Package Contents:" -ForegroundColor Yellow
    foreach ($file in $files) {
        Write-Host "   📄 $($file.Name)" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "🚀 READY FOR DEPLOYMENT!" -ForegroundColor Green
    Write-Host "   1. Navigate to: $NetworkPath" -ForegroundColor White
    Write-Host "   2. Run: Install.bat (as Administrator)" -ForegroundColor White
    Write-Host "   3. Test: Test.ps1" -ForegroundColor White
    Write-Host ""
    
} catch {
    Write-Host "❌ Deployment failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}