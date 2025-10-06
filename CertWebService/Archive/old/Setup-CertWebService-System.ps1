# Certificate WebService Setup v2.0.0-FINAL
# Unified Script with All Features
# ASCII-Compatible, Port Detection, Server Core Support
# Author: Flecki (Tom) Garnreiter
# Build: 2025-09-23
# Regelwerk: v9.5.0 Compliant

param()

Write-Host "Certificate WebService Setup v2.0.0-FINAL" -ForegroundColor Cyan
Write-Host "Unified Setup - ASCII Compatible" -ForegroundColor Cyan
Write-Host "Author: Flecki (Tom) Garnreiter" -ForegroundColor Cyan
Write-Host "Build: 2025-09-23" -ForegroundColor Cyan
Write-Host ""

# Server information
$hostname = $env:COMPUTERNAME
Write-Host "[INFO] Server: $hostname" -ForegroundColor Yellow

# Check administrator privileges
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "[ERROR] This script requires Administrator privileges" -ForegroundColor Red
    Write-Host "[ERROR] Please run as Administrator" -ForegroundColor Red
    exit 1
}
Write-Host "[SUCCESS] Administrator privileges confirmed" -ForegroundColor Green

# Detect environment type
$osInfo = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue
$installationType = if ($osInfo) { $osInfo.InstallationType } else { "Unknown" }
$isServerCore = $installationType -eq "Server Core"

Write-Host "[INFO] Installation Type: $installationType" -ForegroundColor Yellow
if ($isServerCore) {
    Write-Host "[INFO] Server Core detected - using DISM/appcmd methods" -ForegroundColor Yellow
}

# Install IIS with environment-appropriate method
Write-Host "[INSTALL] Installing IIS..."
try {
    if ($isServerCore) {
        # Server Core: Use DISM
        $dismFeatures = @(
            "IIS-WebServerRole",
            "IIS-WebServer", 
            "IIS-CommonHttpFeatures",
            "IIS-StaticContent"
        )
        
        foreach ($feature in $dismFeatures) {
            Write-Host "[INSTALLING] $feature via DISM..." -ForegroundColor Yellow
            $null = & dism.exe /online /enable-feature /featurename:$feature /all /norestart /quiet
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[SUCCESS] $feature installed" -ForegroundColor Green
            } else {
                Write-Host "[WARNING] $feature installation failed (may already exist)" -ForegroundColor Yellow
            }
        }
    } else {
        # Full Server: Try PowerShell modules first
        try {
            $iisFeature = Get-WindowsFeature -Name "Web-Server" -ErrorAction Stop
            if ($iisFeature.InstallState -ne "Installed") {
                Install-WindowsFeature -Name "Web-Server", "Web-Common-Http", "Web-Static-Content" -IncludeManagementTools
                Write-Host "[SUCCESS] IIS installed via PowerShell" -ForegroundColor Green
            } else {
                Write-Host "[INFO] IIS already installed" -ForegroundColor Yellow
            }
        } catch {
            # Fallback to Windows Optional Features (Windows 10/Client)
            Enable-WindowsOptionalFeature -Online -FeatureName "IIS-WebServer", "IIS-CommonHttpFeatures", "IIS-StaticContent" -All -NoRestart
            Write-Host "[SUCCESS] IIS installed via Optional Features" -ForegroundColor Green
        }
    }
} catch {
    Write-Host "[ERROR] IIS installation failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Create application directory
$appPath = "C:\inetpub\CertWebService"
Write-Host "[SETUP] Creating WebService application..."

if (Test-Path $appPath) {
    Write-Host "[INFO] Removing existing installation..." -ForegroundColor Yellow
    Remove-Item $appPath -Recurse -Force -ErrorAction SilentlyContinue
}

New-Item -Path $appPath -ItemType Directory -Force | Out-Null
Write-Host "[CREATE] Application directory: $appPath" -ForegroundColor Green

# Create web.config
$webConfig = @"
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <system.webServer>
        <directoryBrowse enabled="false" />
        <defaultDocument>
            <files>
                <clear />
                <add value="default.htm" />
                <add value="certificates.json" />
            </files>
        </defaultDocument>
    </system.webServer>
</configuration>
"@

$webConfig | Out-File -FilePath "$appPath\web.config" -Encoding ASCII
Write-Host "[CREATE] web.config created" -ForegroundColor Green

# Create simple HTML interface
$apiHtml = @"
<!DOCTYPE html>
<html>
<head>
    <title>Certificate WebService v2.0.0</title>
    <meta charset="UTF-8">
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { color: #2E8B57; }
        .info { background-color: #f0f8ff; padding: 15px; border-radius: 5px; }
        .endpoint { background-color: #e8f5e8; padding: 10px; margin: 5px 0; border-radius: 3px; }
        a { color: #1e90ff; text-decoration: none; }
        a:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <h1 class="header">Certificate WebService v2.0.0-FINAL</h1>
    <div class="info">
        <p><strong>Server:</strong> $hostname</p>
        <p><strong>Version:</strong> 2.0.0-FINAL</p>
        <p><strong>Timestamp:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        <p><strong>Environment:</strong> $installationType</p>
    </div>
    
    <h2>Available Endpoints:</h2>
    <div class="endpoint">
        <strong>Certificates:</strong> <a href="certificates.json">certificates.json</a>
        <br><small>Complete certificate data from all stores</small>
    </div>
    <div class="endpoint">
        <strong>Health Status:</strong> <a href="health.json">health.json</a>
        <br><small>Service health and status information</small>
    </div>
    
    <h2>For Certificate Surveillance System:</h2>
    <p>Use: <code>http://$hostname.domain:PORT/certificates.json</code></p>
</body>
</html>
"@

$apiHtml | Out-File -FilePath "$appPath\default.htm" -Encoding ASCII
Write-Host "[CREATE] Default page created" -ForegroundColor Green

# Port conflict detection and selection
Write-Host "[CHECK] Checking for port conflicts..."
$testPorts = @(9080, 9081, 9082, 9083)
$httpPort = $null

foreach ($port in $testPorts) {
    $portInUse = $false
    
    # Check with appcmd if available
    $appcmdPath = "$env:SystemRoot\System32\inetsrv\appcmd.exe"
    if (Test-Path $appcmdPath) {
        $existingSites = & $appcmdPath list site 2>$null
        $portInUse = $existingSites | Where-Object { $_ -like "*:$port*" }
    }
    
    # Check with netstat as backup
    if (-not $portInUse) {
        $netstatResult = netstat -an | Select-String ":$port "
        $portInUse = $netstatResult.Count -gt 0
    }
    
    if (-not $portInUse) {
        $httpPort = $port
        Write-Host "[INFO] Selected available port: $httpPort" -ForegroundColor Green
        break
    } else {
        Write-Host "[WARNING] Port $port is in use" -ForegroundColor Yellow
    }
}

if (-not $httpPort) {
    Write-Host "[ERROR] No available ports found in range 9080-9083" -ForegroundColor Red
    exit 1
}

# Create health status JSON
$healthJson = @"
{
    "status": "healthy",
    "server": "$hostname",
    "timestamp": "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')",
    "service": "Certificate WebService",
    "version": "2.0.0-FINAL",
    "environment": "$installationType",
    "port": $httpPort,
    "encoding": "ASCII-Compatible"
}
"@

$healthJson | Out-File -FilePath "$appPath\health.json" -Encoding ASCII
Write-Host "[CREATE] Health status endpoint created" -ForegroundColor Green

# Configure IIS site
Write-Host "[CONFIG] Configuring IIS site on port $httpPort..."

if (Test-Path $appcmdPath) {
    # Use appcmd (works on all IIS versions)
    try {
        & $appcmdPath delete site "CertWebService" 2>$null
        & $appcmdPath add site /name:"CertWebService" /bindings:"http/*:$($httpPort):" /physicalPath:"$appPath"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[SUCCESS] IIS site created using appcmd" -ForegroundColor Green
        } else {
            Write-Host "[ERROR] Failed to create IIS site" -ForegroundColor Red
            exit 1
        }
        
        & $appcmdPath start site "CertWebService"
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[SUCCESS] CertWebService site started" -ForegroundColor Green
        }
    } catch {
        Write-Host "[ERROR] IIS configuration failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    # Fallback to PowerShell IIS module
    try {
        Import-Module WebAdministration -ErrorAction Stop
        
        if (Get-IISSite -Name "CertWebService" -ErrorAction SilentlyContinue) {
            Remove-IISSite -Name "CertWebService" -Confirm:$false
        }
        
        New-IISSite -Name "CertWebService" -PhysicalPath $appPath -Port $httpPort
        Write-Host "[SUCCESS] IIS site created using PowerShell" -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] IIS configuration failed - no appcmd or WebAdministration available" -ForegroundColor Red
        exit 1
    }
}

# Configure Windows Firewall
Write-Host "[FIREWALL] Configuring Windows Firewall for port $httpPort..."
try {
    netsh advfirewall firewall delete rule name="Certificate WebService HTTP" 2>$null
    netsh advfirewall firewall add rule name="Certificate WebService HTTP" dir=in action=allow protocol=TCP localport=$httpPort
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[SUCCESS] Firewall rule created for port $httpPort" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] Firewall rule creation failed" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[WARNING] Firewall configuration failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Create certificate scanner script
Write-Host "[SCANNER] Creating certificate scanner script..."
$scannerScript = @'
# Certificate Scanner for WebService v2.0.0
try {
    Write-Host "Scanning certificates..."
    $certificates = Get-ChildItem -Path Cert:\ -Recurse | Where-Object { 
        $_.PSIsContainer -eq $false 
    } | Select-Object Thumbprint, Subject, NotAfter, NotBefore, Issuer, HasPrivateKey
    
    $outputPath = "C:\inetpub\CertWebService\certificates.json"
    $certificates | ConvertTo-Json | Out-File -FilePath $outputPath -Encoding UTF8
    
    Write-Host "Certificate scan completed: $($certificates.Count) certificates found"
    Write-Host "Output saved to: $outputPath"
} catch {
    Write-Host "Error scanning certificates: $($_.Exception.Message)" -ForegroundColor Red
}
'@

$scannerScript | Out-File -FilePath "$appPath\ScanCertificates.ps1" -Encoding ASCII
Write-Host "[CREATE] Certificate scanner created" -ForegroundColor Green

# Run initial certificate scan
Write-Host "[SCAN] Running initial certificate scan..."
try {
    & powershell.exe -ExecutionPolicy Bypass -File "$appPath\ScanCertificates.ps1"
} catch {
    Write-Host "[WARNING] Initial certificate scan failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Get FQDN for remote access
$domain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
if ($domain -and $domain -ne "WORKGROUP") {
    $fqdn = "$hostname.$domain"
} else {
    $fqdn = "$hostname.WORKGROUP"
}

# Final output
Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "CERTIFICATE WEBSERVICE SETUP COMPLETED" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Write-Host "[INFO] Certificate WebService v2.0.0-FINAL installed" -ForegroundColor Cyan
Write-Host "[INFO] Environment: $installationType" -ForegroundColor Cyan
Write-Host "[INFO] Port: $httpPort (auto-selected)" -ForegroundColor Cyan
Write-Host ""
Write-Host "[ENDPOINTS] Service Endpoints:" -ForegroundColor Cyan
Write-Host ""
Write-Host "[LOCAL] For local testing:" -ForegroundColor Yellow
Write-Host "  - HTTP:  http://localhost:$httpPort/certificates.json" -ForegroundColor White
Write-Host "  - Health: http://localhost:$httpPort/health.json" -ForegroundColor White
Write-Host "  - Web UI: http://localhost:$httpPort/" -ForegroundColor White
Write-Host ""
Write-Host "[REMOTE] For Certificate Surveillance System:" -ForegroundColor Yellow
Write-Host "  - HTTP:  http://$fqdn`:$httpPort/certificates.json" -ForegroundColor White
Write-Host "  - Health: http://$fqdn`:$httpPort/health.json" -ForegroundColor White
Write-Host ""
Write-Host "[TEST] Quick test command:" -ForegroundColor Yellow
Write-Host "  Invoke-WebRequest -Uri http://localhost:$httpPort/health.json" -ForegroundColor White
Write-Host ""
Write-Host "[MAINTENANCE] To update certificates:" -ForegroundColor Yellow
Write-Host "  & C:\inetpub\CertWebService\ScanCertificates.ps1" -ForegroundColor White
Write-Host ""
Write-Host "Installation completed successfully!" -ForegroundColor Green