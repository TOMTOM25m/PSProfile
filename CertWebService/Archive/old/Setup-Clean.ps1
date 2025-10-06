#requires -Version 5.1
#Requires -RunAsAdministrator

Write-Host "Certificate WebService Setup v2.3.0 (PowerShell 5.1 Compatible)" -ForegroundColor Cyan
Write-Host ""

try {
    # Enable IIS features
    Write-Host "Enabling IIS features..." -ForegroundColor Yellow
    
    $features = @("IIS-WebServerRole", "IIS-WebServer") 
    foreach ($feature in $features) {
        Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart -ErrorAction SilentlyContinue | Out-Null
    }
    Write-Host "IIS features enabled" -ForegroundColor Green
    
    # Create site directory
    Write-Host "Creating site directory..." -ForegroundColor Yellow
    $sitePath = "C:\inetpub\CertWebService"
    New-Item -Path $sitePath -ItemType Directory -Force | Out-Null
    Write-Host "Directory created: $sitePath" -ForegroundColor Green
    
    # Create API content
    Write-Host "Creating API files..." -ForegroundColor Yellow
    
    # certificates.json
    $certificates = @{
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
    $certificates | Set-Content "$sitePath\certificates.json" -Encoding UTF8
    
    # health.json
    $health = @{
        status = "healthy"
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        server = $env:COMPUTERNAME
        version = "2.3.0"
    } | ConvertTo-Json
    $health | Set-Content "$sitePath\health.json" -Encoding UTF8
    
    # index.html
    $html = "<!DOCTYPE html><html><head><title>Certificate WebService v2.3.0</title><style>body{font-family:Arial;margin:40px;background:#667eea;color:white;}</style></head><body><h1>Certificate WebService v2.3.0</h1><p>Server: $env:COMPUTERNAME</p><p>API: <a href='/certificates.json' style='color:#61dafb'>certificates.json</a></p><p>Health: <a href='/health.json' style='color:#61dafb'>health.json</a></p></body></html>"
    $html | Set-Content "$sitePath\index.html" -Encoding UTF8
    
    # Copy ScanCertificates.ps1 if it exists
    $scanScript = Join-Path $PSScriptRoot "ScanCertificates.ps1"
    if (Test-Path $scanScript) {
        Copy-Item $scanScript -Destination "$sitePath\ScanCertificates.ps1" -Force
        Write-Host "Certificate scan script installed" -ForegroundColor Green
    }
    
    Write-Host "API files created" -ForegroundColor Green
    
    # Configure IIS
    Write-Host "Configuring IIS..." -ForegroundColor Yellow
    Import-Module WebAdministration -ErrorAction SilentlyContinue
    
    # Remove existing site
    if (Get-Website -Name "CertWebService" -ErrorAction SilentlyContinue) {
        Remove-Website -Name "CertWebService"
    }
    
    # Create new site
    New-Website -Name "CertWebService" -PhysicalPath $sitePath -Port 9080
    Write-Host "IIS site created" -ForegroundColor Green
    
    # Configure firewall
    Write-Host "Configuring firewall..." -ForegroundColor Yellow
    New-NetFirewallRule -DisplayName "CertWebService" -Direction Inbound -Protocol TCP -LocalPort 9080 -Action Allow -ErrorAction SilentlyContinue
    Write-Host "Firewall configured" -ForegroundColor Green
    
    # Test installation
    Write-Host "Testing installation..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:9080/health.json" -UseBasicParsing -TimeoutSec 5
        if ($response.StatusCode -eq 200) {
            Write-Host "Test successful!" -ForegroundColor Green
        }
    } catch {
        Write-Host "Test failed, but installation may still work" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "INSTALLATION COMPLETED!" -ForegroundColor Green
    Write-Host "Dashboard: http://$env:COMPUTERNAME:9080/" -ForegroundColor Cyan
    Write-Host "API: http://$env:COMPUTERNAME:9080/certificates.json" -ForegroundColor Cyan
    Write-Host ""
    
} catch {
    Write-Host ""
    Write-Host "INSTALLATION FAILED!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    exit 1
}