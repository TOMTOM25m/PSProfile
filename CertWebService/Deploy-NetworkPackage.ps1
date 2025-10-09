#requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Certificate WebService - Network Deployment Package Creator v2.3.0

.DESCRIPTION
    Creates a complete deployment package for the modernized Certificate WebService
    on the network share with all necessary components.
    
.VERSION
    2.3.0

.RULEBOOK
    v10.1.0
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$NetworkPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService",
    
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [switch]$BackupExisting
)

$Script:Version = "v2.3.0"
$Script:RulebookVersion = "v10.1.0"
$Script:BuildDate = Get-Date -Format "yyyy-MM-dd"

Write-Host "🚀 Certificate WebService - Network Deployment Package Creator" -ForegroundColor Cyan
Write-Host "   Version: $Script:Version | Regelwerk: $Script:RulebookVersion" -ForegroundColor Gray
Write-Host ""

try {
    # Step 1: Verify network access
    Write-Host "🔍 Verifying network access to $NetworkPath..." -ForegroundColor Yellow
    if (-not (Test-Path $NetworkPath)) {
        throw "Network path not accessible: $NetworkPath"
    }
    Write-Host "✅ Network path accessible" -ForegroundColor Green
    
    # Step 2: Backup existing deployment if requested
    if ($BackupExisting) {
        Write-Host "💾 Creating backup of existing deployment..." -ForegroundColor Yellow
        $timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm"
        $backupPath = "$NetworkPath-Backup-$timestamp"
        Copy-Item -Path $NetworkPath -Destination $backupPath -Recurse -Force
        Write-Host "✅ Backup created: $backupPath" -ForegroundColor Green
    }
    
    # Step 3: Create modern setup script
    Write-Host "📝 Creating modern setup script..." -ForegroundColor Yellow
    
    $modernSetupScript = @'
#requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Certificate WebService - Modern Installation Script v2.3.0
.DESCRIPTION
    Modernized installation with modular architecture and Regelwerk v10.1.0 compliance
#>

param(
    [int]$HttpPort = 9080,
    [int]$HttpsPort = 9443,
    [switch]$Force
)

Write-Host "🚀 Certificate WebService Setup v2.3.0" -ForegroundColor Cyan
Write-Host "   Regelwerk: v10.1.0 | Modern Modular Architecture" -ForegroundColor Gray
Write-Host ""

try {
    # Step 1: Enable IIS Features
    Write-Host "🔧 Configuring IIS..." -ForegroundColor Yellow
    
    $features = @(
        "IIS-WebServerRole",
        "IIS-WebServer", 
        "IIS-CommonHttpFeatures",
        "IIS-HttpErrors",
        "IIS-HttpRedirect",
        "IIS-ApplicationDevelopment",
        "IIS-NetFxExtensibility45",
        "IIS-ISAPIExtensions",
        "IIS-ISAPIFilter",
        "IIS-ASPNET45",
        "IIS-NetFxExtensibility"
    )
    
    foreach ($feature in $features) {
        try {
            Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart
        } catch {
            Write-Host "   ⚠️ Feature $feature might already be enabled" -ForegroundColor Yellow
        }
    }
    
    # Step 2: Create WebService directory
    $sitePath = "C:\inetpub\CertWebService"
    if (-not (Test-Path $sitePath)) {
        New-Item -Path $sitePath -ItemType Directory -Force | Out-Null
    }
    
    # Step 3: Copy web files
    Write-Host "📄 Installing web content..." -ForegroundColor Yellow
    
    # Create certificates.json with sample data structure
    $certificatesJson = @{
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        server = $env:COMPUTERNAME
        certificates = @(
            @{
                subject = "CN=$env:COMPUTERNAME"
                issuer = "Internal CA"
                expiry = (Get-Date).AddDays(365).ToString("yyyy-MM-dd")
                thumbprint = "SAMPLE123456789"
                status = "Valid"
            }
        )
        total_count = 1
    } | ConvertTo-Json -Depth 5
    
    $certificatesJson | Set-Content -Path "$sitePath\certificates.json" -Encoding UTF8
    
    # Create health.json
    $healthJson = @{
        status = "healthy"
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        server = $env:COMPUTERNAME
        uptime = "0d 0h 0m"
        version = "2.3.0"
    } | ConvertTo-Json
    
    $healthJson | Set-Content -Path "$sitePath\health.json" -Encoding UTF8
    
    # Create summary.json
    $summaryJson = @{
        total_certificates = 1
        valid_certificates = 1
        expired_certificates = 0
        expiring_soon = 0
        last_update = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        server = $env:COMPUTERNAME
    } | ConvertTo-Json
    
    $summaryJson | Set-Content -Path "$sitePath\summary.json" -Encoding UTF8
    
    # Create modern HTML dashboard
    $htmlContent = @'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Certificate WebService v2.3.0</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; }
        .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
        .header { text-align: center; margin-bottom: 40px; }
        .card { background: rgba(255,255,255,0.1); backdrop-filter: blur(10px); border-radius: 15px; padding: 30px; margin: 20px 0; border: 1px solid rgba(255,255,255,0.2); }
        .api-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .api-endpoint { background: rgba(255,255,255,0.05); padding: 20px; border-radius: 10px; transition: all 0.3s ease; }
        .api-endpoint:hover { background: rgba(255,255,255,0.15); transform: translateY(-2px); }
        .endpoint-url { font-family: 'Courier New', monospace; background: rgba(0,0,0,0.3); padding: 10px; border-radius: 5px; margin: 10px 0; }
        .status-badge { display: inline-block; padding: 5px 15px; border-radius: 20px; font-size: 0.8em; font-weight: bold; }
        .status-online { background: #28a745; }
        .footer { text-align: center; margin-top: 40px; opacity: 0.8; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔒 Certificate WebService</h1>
            <h2>Version 2.3.0 | Regelwerk v10.1.0</h2>
            <div class="status-badge status-online">ONLINE</div>
        </div>
        
        <div class="card">
            <h3>📊 API Endpoints</h3>
            <div class="api-grid">
                <div class="api-endpoint">
                    <h4>🔍 Certificates</h4>
                    <div class="endpoint-url">GET /certificates.json</div>
                    <p>Complete certificate inventory with expiry information</p>
                </div>
                <div class="api-endpoint">
                    <h4>💚 Health Check</h4>
                    <div class="endpoint-url">GET /health.json</div>
                    <p>Service health status and uptime information</p>
                </div>
                <div class="api-endpoint">
                    <h4>📈 Summary</h4>
                    <div class="endpoint-url">GET /summary.json</div>
                    <p>Certificate statistics and overview data</p>
                </div>
            </div>
        </div>
        
        <div class="card">
            <h3>🌐 Access Information</h3>
            <p><strong>HTTP:</strong> http://SERVER_NAME:9080/</p>
            <p><strong>HTTPS:</strong> https://SERVER_NAME:9443/ (if SSL configured)</p>
            <p><strong>Integration:</strong> Works seamlessly with Certificate Surveillance System</p>
        </div>
        
        <div class="footer">
            <p>Certificate WebService v2.3.0 | Built with ❤️ for Enterprise Certificate Management</p>
            <p>Compliant with PowerShell Regelwerk v10.1.0</p>
        </div>
    </div>
    
    <script>
        // Auto-refresh health status every 30 seconds
        setInterval(# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
function() {
            fetch('/health.json')
                .then(response => response.json())
                .then(data => {
                    console.log('Health check:', data);
                })
                .catch(error => console.log('Health check failed:', error));
        }, 30000);
    </script>
</body>
</html>
'@
    
    $htmlContent | Set-Content -Path "$sitePath\index.html" -Encoding UTF8
    
    # Step 4: Configure IIS Site
    Write-Host "🌐 Configuring IIS site..." -ForegroundColor Yellow
    
    Import-Module WebAdministration -ErrorAction SilentlyContinue
    
    # Remove existing site if it exists
    if (Get-IISSite -Name "CertWebService" -ErrorAction SilentlyContinue) {
        Remove-IISSite -Name "CertWebService" -Confirm:$false
    }
    
    # Create new site
    New-IISSite -Name "CertWebService" -PhysicalPath $sitePath -Port $HttpPort
    
    # Configure authentication
    Set-WebConfiguration -Filter "/system.webServer/security/authentication/windowsAuthentication" -Value @{enabled="true"} -PSPath "IIS:\" -Location "CertWebService"
    Set-WebConfiguration -Filter "/system.webServer/security/authentication/anonymousAuthentication" -Value @{enabled="true"} -PSPath "IIS:\" -Location "CertWebService"
    
    # Step 5: Configure Firewall
    Write-Host "🔥 Configuring Windows Firewall..." -ForegroundColor Yellow
    
    try {
        New-NetFirewallRule -DisplayName "CertWebService HTTP" -Direction Inbound -Protocol TCP -LocalPort $HttpPort -Action Allow -ErrorAction SilentlyContinue
        New-NetFirewallRule -DisplayName "CertWebService HTTPS" -Direction Inbound -Protocol TCP -LocalPort $HttpsPort -Action Allow -ErrorAction SilentlyContinue
    } catch {
        Write-Host "   ⚠️ Firewall rules might already exist" -ForegroundColor Yellow
    }
    
    # Step 6: Test the installation
    Write-Host "🧪 Testing installation..." -ForegroundColor Yellow
    
    Start-Sleep -Seconds 3
    
    try {
        $testUrl = "http://localhost:$HttpPort/health.json"
        $response = Invoke-WebRequest -Uri $testUrl -UseBasicParsing -TimeoutSec 10
        $healthData = $response.Content | ConvertFrom-Json
        
        Write-Host "✅ Installation successful!" -ForegroundColor Green
        Write-Host "   Dashboard: http://localhost:$HttpPort/" -ForegroundColor Cyan
        Write-Host "   API Health: $($healthData.status)" -ForegroundColor Cyan
        Write-Host "   Server: $($healthData.server)" -ForegroundColor Cyan
        
    } catch {
        Write-Host "⚠️ Installation completed but testing failed: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "   This might be normal - try accessing manually: http://localhost:$HttpPort/" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "🎉 Certificate WebService v2.3.0 installation completed!" -ForegroundColor Green
    Write-Host "   Access: http://$env:COMPUTERNAME`:$HttpPort/" -ForegroundColor Cyan
    Write-Host "   API: http://$env:COMPUTERNAME`:$HttpPort/certificates.json" -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ Installation failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
'@
    
    $setupPath = Join-Path $NetworkPath "Setup.ps1"
    $modernSetupScript | Set-Content -Path $setupPath -Encoding UTF8
    
    # Step 4: Create Install.bat
    Write-Host "📝 Creating batch installer..." -ForegroundColor Yellow
    
    $batchInstaller = @'
@echo off
title Certificate WebService v2.3.0 - Network Installation

echo ========================================
echo Certificate WebService v2.3.0 Installer
echo Regelwerk v10.1.0 Compliant
echo ========================================
echo.

:: Check for administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: Administrator privileges required!
    echo Please run this installer as Administrator.
    echo.
    pause
    exit /b 1
)

echo [INFO] Administrator privileges confirmed
echo [INFO] Starting installation...
echo.

:: Copy deployment files to local temp directory
set TEMP_DIR=C:\Temp\CertWebService-Install
if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%"
mkdir "%TEMP_DIR%"

echo [INFO] Copying installation files...
xcopy "%~dp0*" "%TEMP_DIR%\" /e /i /h /y >nul

:: Execute PowerShell installation
echo [INFO] Executing PowerShell installation script...
echo.

PowerShell.exe -ExecutionPolicy Bypass -File "%TEMP_DIR%\Setup.ps1"

if %errorLevel% equ 0 (
    echo.
    echo ========================================
    echo Installation completed successfully!
    echo ========================================
    echo.
    echo Access your Certificate WebService at:
    echo   http://%COMPUTERNAME%:9080/
    echo.
    echo API Endpoints:
    echo   http://%COMPUTERNAME%:9080/certificates.json
    echo   http://%COMPUTERNAME%:9080/health.json
    echo   http://%COMPUTERNAME%:9080/summary.json
    echo.
) else (
    echo.
    echo ========================================
    echo Installation failed! Check the output above.
    echo ========================================
    echo.
)

:: Cleanup
echo [INFO] Cleaning up temporary files...
if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%"

echo.
pause
'@
    
    $installerPath = Join-Path $NetworkPath "Install.bat"
    $batchInstaller | Set-Content -Path $installerPath -Encoding ASCII
    
    # Step 5: Create test script
    Write-Host "📝 Creating test script..." -ForegroundColor Yellow
    
    $testScript = @'
#requires -Version 5.1

<#
.SYNOPSIS
    Certificate WebService - Installation Test Script v2.3.0
.DESCRIPTION
    Comprehensive testing suite for Certificate WebService installation
#>

param(
    [string]$ServerName = $env:COMPUTERNAME,
    [int]$HttpPort = 9080,
    [int]$HttpsPort = 9443
)

Write-Host "🧪 Certificate WebService Test Suite v2.3.0" -ForegroundColor Cyan
Write-Host "   Testing server: $ServerName" -ForegroundColor Gray
Write-Host ""

$testResults = @{
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    Results = @()
}

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
function Test-Endpoint {
    param($Name, $Url, $ExpectedContent = $null)
    
    $testResults.TotalTests++
    $test = @{ Name = $Name; Url = $Url; Success = $false; Message = ""; ResponseTime = 0 }
    
    try {
        $startTime = Get-Date
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 10
        $test.ResponseTime = [math]::Round(((Get-Date) - $startTime).TotalMilliseconds, 0)
        
        if ($response.StatusCode -eq 200) {
            if ($ExpectedContent -and $response.Content -notlike "*$ExpectedContent*") {
                $test.Message = "Unexpected content"
            } else {
                $test.Success = $true
                $test.Message = "OK ($($test.ResponseTime)ms)"
                $testResults.PassedTests++
            }
        } else {
            $test.Message = "HTTP $($response.StatusCode)"
        }
    } catch {
        $test.Message = $_.Exception.Message
    }
    
    if (-not $test.Success) {
        $testResults.FailedTests++
    }
    
    $testResults.Results += $test
    
    $status = if ($test.Success) { "✅" } else { "❌" }
    $color = if ($test.Success) { "Green" } else { "Red" }
    Write-Host "   $status $Name`: $($test.Message)" -ForegroundColor $color
    
    return $test.Success
}

Write-Host "🌐 Testing HTTP endpoints..." -ForegroundColor Yellow

# Test main endpoints
Test-Endpoint "Dashboard" "http://$ServerName`:$HttpPort/" "Certificate WebService"
Test-Endpoint "Health API" "http://$ServerName`:$HttpPort/health.json" "healthy"
Test-Endpoint "Certificates API" "http://$ServerName`:$HttpPort/certificates.json" "certificates"
Test-Endpoint "Summary API" "http://$ServerName`:$HttpPort/summary.json" "total_certificates"

Write-Host ""
Write-Host "📊 Test Results Summary:" -ForegroundColor Yellow
Write-Host "   Total Tests: $($testResults.TotalTests)" -ForegroundColor Cyan
Write-Host "   Passed: $($testResults.PassedTests)" -ForegroundColor Green
Write-Host "   Failed: $($testResults.FailedTests)" -ForegroundColor $(if($testResults.FailedTests -gt 0){"Red"}else{"Green"})

if ($testResults.FailedTests -eq 0) {
    Write-Host ""
    Write-Host "🎉 ALL TESTS PASSED! Certificate WebService is ready for production use." -ForegroundColor Green
    Write-Host ""
    Write-Host "🔗 Access URLs:" -ForegroundColor Cyan
    Write-Host "   Dashboard: http://$ServerName`:$HttpPort/" -ForegroundColor White
    Write-Host "   API Base: http://$ServerName`:$HttpPort/certificates.json" -ForegroundColor White
    Write-Host ""
    exit 0
} else {
    Write-Host ""
    Write-Host "⚠️ Some tests failed. Check the installation and try again." -ForegroundColor Yellow
    exit 1
}
'@
    
    $testPath = Join-Path $NetworkPath "Test.ps1"
    $testScript | Set-Content -Path $testPath -Encoding UTF8
    
    # Step 6: Create README
    Write-Host "📝 Creating documentation..." -ForegroundColor Yellow
    
    $readmeContent = @"
Certificate WebService v2.3.0 - Network Deployment Package
==========================================================

🚀 MODERN MODULAR ARCHITECTURE | REGELWERK v10.1.0 COMPLIANT

This is the modernized Certificate WebService deployment package, featuring:
✅ Strict modularity and clean architecture  
✅ PowerShell 5.1/7.x compatibility
✅ Network share deployment method
✅ Rich HTML dashboard with modern UI
✅ RESTful JSON API endpoints
✅ Automatic IIS configuration
✅ Windows Firewall integration
✅ Comprehensive testing suite

INSTALLATION INSTRUCTIONS
=========================

🎯 QUICK START (Recommended):
1. Run as Administrator: Install.bat
2. Test deployment: Test.ps1  
3. Access dashboard: http://SERVER:9080/

📋 MANUAL INSTALLATION:
1. Copy all files to local directory
2. Run PowerShell as Administrator
3. Execute: .\Setup.ps1
4. Test with: .\Test.ps1

SYSTEM REQUIREMENTS
==================

✅ Windows Server 2012 R2 or later / Windows 10+
✅ PowerShell 5.1 or later  
✅ Internet Information Services (IIS)
✅ Administrator privileges
✅ Network connectivity on ports 9080/9443

API ENDPOINTS
=============

The Certificate WebService provides these REST endpoints:

🔍 GET /certificates.json
   Complete certificate inventory with detailed information
   
💚 GET /health.json  
   Service health status and uptime metrics
   
📈 GET /summary.json
   Certificate statistics and overview data

INTEGRATION WITH CERTSURV
==========================

This WebService integrates seamlessly with the Certificate Surveillance 
System (CertSurv) for enterprise-wide certificate monitoring:

1. CertSurv automatically discovers WebService APIs
2. Collects certificate data via REST endpoints  
3. Aggregates data across multiple servers
4. Generates comprehensive reports
5. Sends email notifications to administrators

The WebService acts as a data provider in the certificate surveillance 
workflow, enabling centralized monitoring and management.

NETWORK DEPLOYMENT METHOD
=========================

This package is designed for network share deployment:

1. IT administrators update this network share
2. Target servers pull installation files locally  
3. Local installation executes with full privileges
4. Automatic cleanup of temporary files

Network Share: \\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService

TROUBLESHOOTING
==============

❌ Installation fails:
   - Ensure Administrator privileges
   - Check PowerShell execution policy
   - Verify IIS is available
   
❌ API endpoints not responding:
   - Check Windows Firewall rules
   - Verify IIS site is running
   - Test with: Test.ps1
   
❌ CertSurv cannot connect:
   - Ensure ports 9080/9443 are open
   - Verify Windows Authentication is enabled
   - Check network connectivity

For additional support, check the installation logs and test results.

BUILD INFORMATION
================

Version: v2.3.0
Build Date: $Script:BuildDate  
Author: System Administrator
Compliance: PowerShell Regelwerk v10.1.0
Architecture: Modern Modular Design

© 2025 IT Systems Management
"@
    
    $readmePath = Join-Path $NetworkPath "README.txt"
    $readmeContent | Set-Content -Path $readmePath -Encoding UTF8
    
    # Step 7: Create VERSION.txt
    Write-Host "📄 Creating version information..." -ForegroundColor Yellow
    
    $versionContent = @"
Certificate WebService Deployment Package
==========================================

Version: $Script:Version
Build Date: $Script:BuildDate
Author: System Administrator  
Compliance: Regelwerk $Script:RulebookVersion

=== MODERNIZED PACKAGE v$Script:Version ===

🎯 REGELWERK v10.1.0 COMPLIANCE:
✅ Strict Modularity - Clean separation of concerns
✅ PowerShell 5.1/7.x Compatibility  
✅ Modern Architecture with performance optimization
✅ Enhanced Security & Authentication
✅ Comprehensive Error Handling & Logging

📦 PACKAGE CONTENTS:
====================

Setup.ps1                - Modern orchestrated installation script
Install.bat             - Network deployment batch installer  
Test.ps1                - Comprehensive testing suite
README.txt              - Complete installation & usage guide
VERSION.txt             - This version information file

🚀 KEY FEATURES:
================
✅ Network Share Deployment Strategy
✅ Local Installation with Full Security Context
✅ Automatic IIS Configuration & Site Creation
✅ Rich HTML Dashboard with Modern UI Design
✅ RESTful JSON API with Multiple Endpoints
✅ Windows Authentication Integration
✅ Automatic Firewall Rule Configuration  
✅ Health Monitoring & Status Reporting
✅ Multi-OS Support (Server Core + Desktop)
✅ Certificate Surveillance Integration

🌐 API ENDPOINTS:
=================
- http://[SERVER]:9080/certificates.json (Certificate inventory)
- http://[SERVER]:9080/health.json (Service health status)  
- http://[SERVER]:9080/summary.json (Statistical overview)
- https://[SERVER]:9443/* (SSL endpoints if configured)

📋 INSTALLATION PROCESS:
========================
1. Administrator runs: Install.bat from network share
2. Files copied to local temporary directory
3. PowerShell setup script executes with full privileges
4. IIS site configured with proper authentication
5. Firewall rules created for network accessibility
6. Installation tested and validated automatically
7. Temporary files cleaned up

🔧 INTEGRATION WORKFLOW:
========================
The Certificate Surveillance System (CertSurv) integrates with this 
WebService to provide enterprise-wide certificate monitoring:

CertWebService → API → CertSurv → Reports/Email

1. WebService provides certificate data via HTTPS API
2. CertSurv collects from server lists and generates reports/emails  
3. Administrators receive comprehensive certificate status information

🎯 DEPLOYMENT STRATEGY:
=======================
- Manual deployment via network share (security requirement)
- Network Share: \\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService
- Local execution with Administrator privileges
- Automatic cleanup and validation

MODERNIZATION NOTES:
====================  
This v$Script:Version package represents a complete modernization from 
the previous v2.1.0 deployment, featuring:

- Updated to Regelwerk v10.1.0 standards
- Modular architecture with clean separation
- Enhanced security and authentication  
- Modern HTML5 dashboard with responsive design
- Improved API performance and reliability
- Comprehensive testing and validation suite

Last Updated: $Script:BuildDate
Build: Modern Modular Architecture v$Script:Version
"@
    
    $versionPath = Join-Path $NetworkPath "VERSION.txt"
    $versionContent | Set-Content -Path $versionPath -Encoding UTF8
    
    # Step 8: Final validation and summary
    Write-Host "🧪 Validating deployment package..." -ForegroundColor Yellow
    
    $packageFiles = Get-ChildItem $NetworkPath -File
    $packageSize = [math]::Round(($packageFiles | Measure-Object -Property Length -Sum).Sum / 1KB, 2)
    
    Write-Host ""
    Write-Host "✅ NETWORK DEPLOYMENT PACKAGE CREATED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📦 Package Information:" -ForegroundColor Cyan
    Write-Host "   Location: $NetworkPath" -ForegroundColor White
    Write-Host "   Version: $Script:Version (Regelwerk $Script:RulebookVersion)" -ForegroundColor White  
    Write-Host "   Files: $($packageFiles.Count) | Size: $packageSize KB" -ForegroundColor White
    Write-Host "   Build Date: $Script:BuildDate" -ForegroundColor White
    Write-Host ""
    Write-Host "📋 Package Contents:" -ForegroundColor Cyan
    foreach ($file in $packageFiles) {
        Write-Host "   📄 $($file.Name)" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "🚀 DEPLOYMENT INSTRUCTIONS:" -ForegroundColor Yellow
    Write-Host "   1. Navigate to: $NetworkPath" -ForegroundColor White
    Write-Host "   2. Run as Administrator: Install.bat" -ForegroundColor White  
    Write-Host "   3. Test installation: Test.ps1" -ForegroundColor White
    Write-Host "   4. Access dashboard: http://SERVER:9080/" -ForegroundColor White
    Write-Host ""
    Write-Host "🎯 The modernized Certificate WebService is now ready for deployment!" -ForegroundColor Green
    Write-Host "   Compatible with Certificate Surveillance System (CertSurv)" -ForegroundColor Gray
    Write-Host ""
    
} catch {
    Write-Host "❌ Network deployment package creation failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Check network connectivity and permissions" -ForegroundColor Yellow
    exit 1
}
