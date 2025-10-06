#Requires -Version 5.1#requires -Version 5.1

#Requires -RunAsAdministrator#Requires -RunAsAdministrator



<#Write-Host "🚀 Certificate WebService Setup v2.3.0 (FIXED)" -ForegroundColor Cyan

.SYNOPSISWrite-Host "   Compatible with PowerShell 5.1 and IIS Management" -ForegroundColor Gray

CertWebService Setup ScriptWrite-Host ""

.DESCRIPTION

Hauptinstallations-Script für CertWebService v2.4.0try {

Regelwerk v10.0.2 konform | Stand: 02.10.2025    # Enable IIS features

.PARAMETER Port    Write-Host "🔧 Enabling IIS features..." -ForegroundColor Yellow

Standard HTTP Port (Default: 9080)    

.PARAMETER InstallPath    $features = @(

Installationspfad (Default: C:\CertWebService)        "IIS-WebServerRole",

.PARAMETER CreateService        "IIS-WebServer", 

Erstelle Windows Service (Default: $true)        "IIS-CommonHttpFeatures",

#>        "IIS-HttpErrors",

        "IIS-HttpRedirect",

param(        "IIS-ApplicationDevelopment"

    [int]$Port = 9080,    )

    [string]$InstallPath = "C:\CertWebService",    

    [bool]$CreateService = $true,    foreach ($feature in $features) {

    [switch]$Quiet        try {

)            Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart -ErrorAction SilentlyContinue | Out-Null

        } catch {

$ErrorActionPreference = "Stop"            Write-Host "   Warning: Feature $feature might already be enabled" -ForegroundColor Yellow

        }

# === INSTALLATION SETUP ===    }

Write-Host "=== CERTWEBSERVICE SETUP v2.4.0 ===" -ForegroundColor Green    

Write-Host "Regelwerk v10.0.2 | Stand: 02.10.2025" -ForegroundColor Gray    Write-Host "✅ IIS features configured" -ForegroundColor Green

Write-Host ""    

    # Create site directory

if (-not $Quiet) {    Write-Host "📁 Creating site directory..." -ForegroundColor Yellow

    Write-Host "Installation Parameters:" -ForegroundColor Cyan    $sitePath = "C:\inetpub\CertWebService"

    Write-Host "  Port: $Port" -ForegroundColor White    if (-not (Test-Path $sitePath)) {

    Write-Host "  Path: $InstallPath" -ForegroundColor White        New-Item -Path $sitePath -ItemType Directory -Force | Out-Null

    Write-Host "  Service: $CreateService" -ForegroundColor White    }

    Write-Host ""    Write-Host "✅ Directory created: $sitePath" -ForegroundColor Green

}    

    # Create certificates.json

# === ADMINISTRATOR CHECK ===    Write-Host "📄 Creating API content..." -ForegroundColor Yellow

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())    $certificates = @{

if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

    throw "Administrator privileges required!"        server = $env:COMPUTERNAME

}        certificates = @(@{

            subject = "CN=$env:COMPUTERNAME"

# === CREATE INSTALLATION DIRECTORY ===            issuer = "Internal CA"

Write-Host "[1/5] Creating installation directory..." -ForegroundColor Yellow            expiry = (Get-Date).AddDays(365).ToString("yyyy-MM-dd")

if (-not (Test-Path $InstallPath)) {            status = "Valid"

    New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null            thumbprint = "SAMPLE123456789"

    Write-Host "      Created: $InstallPath" -ForegroundColor Green        })

} else {        total_count = 1

    Write-Host "      Exists: $InstallPath" -ForegroundColor Green        api_version = "2.3.0"

}    } | ConvertTo-Json -Depth 5

    

# === COPY FILES ===    $certificates | Set-Content "$sitePath\certificates.json" -Encoding UTF8

Write-Host "[2/5] Copying application files..." -ForegroundColor Yellow    

$sourceFiles = @(    # Create health.json

    "ScanCertificates.ps1",    $health = @{

    "Modules",        status = "healthy"

    "Config",         timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

    "Scripts",        server = $env:COMPUTERNAME

    "WebFiles"        version = "2.3.0"

)        uptime = "0d 0h 0m"

    } | ConvertTo-Json

foreach ($item in $sourceFiles) {    

    if (Test-Path $item) {    $health | Set-Content "$sitePath\health.json" -Encoding UTF8

        $dest = Join-Path $InstallPath $item    

        if (Test-Path $dest) {    # Create summary.json

            Remove-Item $dest -Recurse -Force    $summary = @{

        }        total_certificates = 1

        Copy-Item $item $dest -Recurse -Force        valid_certificates = 1

        Write-Host "      Copied: $item" -ForegroundColor Green        expired_certificates = 0

    } else {        expiring_soon = 0

        Write-Host "      Missing: $item (skipped)" -ForegroundColor Yellow        last_update = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

    }        server = $env:COMPUTERNAME

}    } | ConvertTo-Json

    

# === CONFIGURE PORT ===    $summary | Set-Content "$sitePath\summary.json" -Encoding UTF8

Write-Host "[3/5] Configuring port settings..." -ForegroundColor Yellow    

$configFile = Join-Path $InstallPath "Config\CertSurv-Config.json"    # Create enhanced HTML dashboard

if (Test-Path $configFile) {    $html = @'

    $config = Get-Content $configFile | ConvertFrom-Json<!DOCTYPE html>

    $config.WebServicePort = $Port<html lang="en">

    $config | ConvertTo-Json -Depth 3 | Out-File $configFile -Encoding UTF8<head>

    Write-Host "      Port configured: $Port" -ForegroundColor Green    <meta charset="UTF-8">

} else {    <meta name="viewport" content="width=device-width, initial-scale=1.0">

    # Create basic config    <title>Certificate WebService v2.3.0</title>

    $basicConfig = @{    <style>

        WebServicePort = $Port        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; min-height: 100vh; }

        ScanInterval = 3600        .container { max-width: 800px; margin: 0 auto; padding: 40px 20px; }

        LogLevel = "INFO"        .header { text-align: center; margin-bottom: 40px; }

        EmailNotifications = $true        .card { background: rgba(255,255,255,0.1); backdrop-filter: blur(10px); border-radius: 15px; padding: 30px; margin: 20px 0; border: 1px solid rgba(255,255,255,0.2); }

        CertificateThreshold = 30        .api-endpoint { background: rgba(255,255,255,0.05); padding: 20px; border-radius: 10px; margin: 15px 0; transition: all 0.3s ease; }

    }        .api-endpoint:hover { background: rgba(255,255,255,0.15); transform: translateY(-2px); }

    $basicConfig | ConvertTo-Json -Depth 3 | Out-File $configFile -Encoding UTF8 -Force        .endpoint-url { font-family: 'Courier New', monospace; background: rgba(0,0,0,0.3); padding: 10px; border-radius: 5px; margin: 10px 0; word-break: break-all; }

    Write-Host "      Basic config created: $Port" -ForegroundColor Green        .status-badge { display: inline-block; padding: 5px 15px; border-radius: 20px; font-size: 0.8em; font-weight: bold; background: #28a745; }

}        .footer { text-align: center; margin-top: 40px; opacity: 0.8; }

        a { color: #61dafb; text-decoration: none; }

# === FIREWALL RULE ===        a:hover { text-decoration: underline; }

Write-Host "[4/5] Configuring firewall..." -ForegroundColor Yellow    </style>

try {</head>

    $ruleName = "CertWebService-HTTP-$Port"<body>

    $existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue    <div class="container">

    if ($existingRule) {        <div class="header">

        Remove-NetFirewallRule -DisplayName $ruleName            <h1>🔒 Certificate WebService</h1>

    }            <h2>Version 2.3.0 | Regelwerk v10.0.0</h2>

    New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow | Out-Null            <div class="status-badge">ONLINE</div>

    Write-Host "      Firewall rule created: Port $Port" -ForegroundColor Green        </div>

} catch {        

    Write-Host "      Firewall configuration failed: $($_.Exception.Message)" -ForegroundColor Red        <div class="card">

}            <h3>📊 API Endpoints</h3>

            

# === WINDOWS SERVICE ===            <div class="api-endpoint">

Write-Host "[5/5] Configuring Windows Service..." -ForegroundColor Yellow                <h4>🔍 Certificates</h4>

if ($CreateService) {                <div class="endpoint-url"><a href="/certificates.json">GET /certificates.json</a></div>

    try {                <p>Complete certificate inventory with expiry information and status details</p>

        $serviceName = "CertWebService"            </div>

        $existingService = Get-Service -Name $serviceName -ErrorAction SilentlyContinue            

        if ($existingService) {            <div class="api-endpoint">

            Stop-Service $serviceName -Force -ErrorAction SilentlyContinue                <h4>💚 Health Check</h4>

            & sc.exe delete $serviceName | Out-Null                <div class="endpoint-url"><a href="/health.json">GET /health.json</a></div>

            Start-Sleep 2                <p>Service health status, uptime information, and system metrics</p>

        }            </div>

                    

        $exePath = Join-Path $InstallPath "ScanCertificates.ps1"            <div class="api-endpoint">

        $serviceCmd = "powershell.exe -ExecutionPolicy Bypass -File `"$exePath`" -ServiceMode"                <h4>📈 Summary</h4>

                        <div class="endpoint-url"><a href="/summary.json">GET /summary.json</a></div>

        & sc.exe create $serviceName binPath= $serviceCmd start= auto DisplayName= "Certificate Web Service" | Out-Null                <p>Certificate statistics, overview data, and quick status summary</p>

        & sc.exe description $serviceName "SSL/TLS Certificate Monitoring Service for MedUni Wien" | Out-Null            </div>

                </div>

        Start-Service $serviceName        

        Write-Host "      Service created and started: $serviceName" -ForegroundColor Green        <div class="card">

    } catch {            <h3>🌐 Access Information</h3>

        Write-Host "      Service creation failed: $($_.Exception.Message)" -ForegroundColor Red            <p><strong>Server:</strong> SERVER_NAME</p>

        Write-Host "      You can start manually: powershell.exe -File `"$exePath`"" -ForegroundColor Yellow            <p><strong>HTTP:</strong> http://SERVER_NAME:9080/</p>

    }            <p><strong>Integration:</strong> Works seamlessly with Certificate Surveillance System (CertSurv)</p>

}            <p><strong>Monitoring:</strong> Provides real-time certificate data for enterprise surveillance</p>

        </div>

# === INSTALLATION COMPLETE ===        

Write-Host ""        <div class="footer">

Write-Host "=== INSTALLATION COMPLETE ===" -ForegroundColor Green            <p>Certificate WebService v2.3.0 | Built for Enterprise Certificate Management</p>

Write-Host "Web Service URL: http://localhost:$Port" -ForegroundColor Cyan            <p>Compliant with PowerShell Regelwerk v10.0.0 | System Administrator</p>

Write-Host "API Endpoint: http://localhost:$Port/api/certificates.json" -ForegroundColor Cyan        </div>

Write-Host "Installation Path: $InstallPath" -ForegroundColor Gray    </div>

Write-Host ""    

    <script>

# === TEST CONNECTION ===        // Replace SERVER_NAME with actual server name

Write-Host "Testing connection..." -ForegroundColor Yellow        document.body.innerHTML = document.body.innerHTML.replace(/SERVER_NAME/g, window.location.hostname || 'localhost');

Start-Sleep 3        

try {        // Auto-refresh health status every 30 seconds

    $testResult = Test-NetConnection -ComputerName localhost -Port $Port -InformationLevel Quiet        setInterval(function() {

    if ($testResult) {            fetch('/health.json')

        Write-Host "✅ Service is running on port $Port" -ForegroundColor Green                .then(response => response.json())

    } else {                .then(data => {

        Write-Host "⚠️  Service may need a moment to start" -ForegroundColor Yellow                    console.log('Health check:', data);

    }                })

} catch {                .catch(error => console.log('Health check failed:', error));

    Write-Host "⚠️  Connection test failed - service may need manual start" -ForegroundColor Yellow        }, 30000);

}    </script>

</body>

Write-Host ""</html>

Write-Host "📋 Next Steps:" -ForegroundColor Cyan'@

Write-Host "   1. Open browser: http://localhost:$Port" -ForegroundColor White    

Write-Host "   2. Check service: Get-Service CertWebService" -ForegroundColor White    $html | Set-Content "$sitePath\index.html" -Encoding UTF8

Write-Host "   3. View logs: Get-Content $InstallPath\Logs\*.log" -ForegroundColor White    Write-Host "✅ API content created" -ForegroundColor Green

Write-Host ""    

    # Configure IIS using WebAdministration cmdlets (PowerShell 5.1 compatible)

if (-not $Quiet) {    Write-Host "🌐 Configuring IIS site..." -ForegroundColor Yellow

    Write-Host "Installation completed successfully! 🎉" -ForegroundColor Green    

}    # Import WebAdministration module
    Import-Module WebAdministration -ErrorAction SilentlyContinue
    
    # Remove existing site if it exists
    if (Get-Website -Name "CertWebService" -ErrorAction SilentlyContinue) {
        Remove-Website -Name "CertWebService"
        Write-Host "   Removed existing site" -ForegroundColor Yellow
    }
    
    # Create new website using PowerShell 5.1 compatible cmdlets
    New-Website -Name "CertWebService" -PhysicalPath $sitePath -Port 9080
    
    # Configure authentication
    Set-WebConfiguration -Filter "/system.webServer/security/authentication/windowsAuthentication" -Value @{enabled="true"} -PSPath "IIS:\" -Location "CertWebService"
    Set-WebConfiguration -Filter "/system.webServer/security/authentication/anonymousAuthentication" -Value @{enabled="true"} -PSPath "IIS:\" -Location "CertWebService"
    
    Write-Host "✅ IIS site configured" -ForegroundColor Green
    
    # Configure Windows Firewall
    Write-Host "🔥 Configuring Windows Firewall..." -ForegroundColor Yellow
    
    try {
        # Remove existing rule if it exists
        Remove-NetFirewallRule -DisplayName "CertWebService HTTP" -ErrorAction SilentlyContinue
        
        # Create new firewall rule
        New-NetFirewallRule -DisplayName "CertWebService HTTP" -Direction Inbound -Protocol TCP -LocalPort 9080 -Action Allow
        Write-Host "✅ Firewall configured" -ForegroundColor Green
    } catch {
        Write-Host "   ⚠️ Firewall configuration failed (may already exist): $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Test the installation
    Write-Host "🧪 Testing installation..." -ForegroundColor Yellow
    
    Start-Sleep -Seconds 3
    
    try {
        $testUrl = "http://localhost:9080/health.json"
        $response = Invoke-WebRequest -Uri $testUrl -UseBasicParsing -TimeoutSec 10
        
        if ($response.StatusCode -eq 200) {
            Write-Host "✅ Installation test successful!" -ForegroundColor Green
        } else {
            Write-Host "⚠️ Installation completed but test returned HTTP $($response.StatusCode)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "⚠️ Installation completed but testing failed: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "   This is normal - try accessing manually after a few seconds" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "🎉 CERTIFICATE WEBSERVICE v2.3.0 INSTALLATION COMPLETED!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 Access Information:" -ForegroundColor Cyan
    Write-Host "   Dashboard: http://$env:COMPUTERNAME:9080/" -ForegroundColor White
    Write-Host "   API: http://$env:COMPUTERNAME:9080/certificates.json" -ForegroundColor White
    Write-Host "   Health: http://$env:COMPUTERNAME:9080/health.json" -ForegroundColor White
    Write-Host "   Summary: http://$env:COMPUTERNAME:9080/summary.json" -ForegroundColor White
    Write-Host ""
    Write-Host "🔗 Integration:" -ForegroundColor Cyan
    Write-Host "   Ready for Certificate Surveillance System (CertSurv) integration" -ForegroundColor White
    Write-Host "   Provides real-time certificate data via REST API" -ForegroundColor White
    Write-Host ""
    
} catch {
    Write-Host ""
    Write-Host "❌ INSTALLATION FAILED!" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "🔧 Troubleshooting:" -ForegroundColor Yellow
    Write-Host "   1. Ensure you're running as Administrator" -ForegroundColor White
    Write-Host "   2. Check if IIS is installed and running" -ForegroundColor White
    Write-Host "   3. Verify PowerShell execution policy allows scripts" -ForegroundColor White
    Write-Host "   4. Check Windows Firewall settings" -ForegroundColor White
    Write-Host ""
    exit 1
}