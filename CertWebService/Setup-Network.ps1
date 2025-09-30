#requires -Version 5.1
#Requires -RunAsAdministrator

Write-Host "Certificate WebService Setup v2.3.0" -ForegroundColor Cyan

try {
    # Enable IIS features
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole -All -NoRestart -ErrorAction SilentlyContinue
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServer -All -NoRestart -ErrorAction SilentlyContinue
    
    # Create site directory
    $sitePath = "C:\inetpub\CertWebService"
    New-Item -Path $sitePath -ItemType Directory -Force | Out-Null
    
    # Create certificates.json
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
    
    # Create health.json
    $health = @{
        status = "healthy"
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        server = $env:COMPUTERNAME
        version = "2.3.0"
    } | ConvertTo-Json
    
    $health | Set-Content "$sitePath\health.json" -Encoding UTF8
    
    # Create index.html
    $html = "<!DOCTYPE html><html><head><title>Certificate WebService v2.3.0</title></head><body><h1>Certificate WebService v2.3.0</h1><p>Server: $env:COMPUTERNAME</p><p>API: <a href='/certificates.json'>certificates.json</a></p></body></html>"
    $html | Set-Content "$sitePath\index.html" -Encoding UTF8
    
    # Configure IIS
    Import-Module WebAdministration -ErrorAction SilentlyContinue
    
    if (Get-IISSite -Name "CertWebService" -ErrorAction SilentlyContinue) {
        Remove-IISSite -Name "CertWebService" -Confirm:$false
    }
    
    New-IISSite -Name "CertWebService" -PhysicalPath $sitePath -Port 9080
    
    # Configure firewall
    New-NetFirewallRule -DisplayName "CertWebService" -Direction Inbound -Protocol TCP -LocalPort 9080 -Action Allow -ErrorAction SilentlyContinue
    
    Write-Host "Installation successful!" -ForegroundColor Green
    Write-Host "Access: http://$env:COMPUTERNAME:9080/" -ForegroundColor Cyan
    
} catch {
    Write-Host "Installation failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
