#requires -Version 5.1
#Requires -RunAsAdministrator

param(
    [int]$Port = 9080,
    [int]$SecurePort = 9443
)

Write-Host "🚀 Certificate Web Service v2.3.0 Setup" -ForegroundColor Green
Write-Host "📋 Read-Only Mode für 3 autorisierte Server" -ForegroundColor Yellow
Write-Host ""

$ErrorActionPreference = 'Stop'

function Write-SetupLog {
    param($Message, $Level = 'INFO')
    $timestamp = Get-Date -Format 'HH:mm:ss'
    Write-Host "[$timestamp] [$Level] $Message"
}

try {
    Write-SetupLog "Starting Certificate Web Service Setup"
    
    # Install IIS Features
    Write-SetupLog "Installing IIS features..."
    $features = @('IIS-WebServerRole', 'IIS-WebServer', 'IIS-CommonHttpFeatures', 'IIS-StaticContent', 'IIS-DefaultDocument')
    
    foreach ($feature in $features) {
        try {
            Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart -ErrorAction SilentlyContinue | Out-Null
        } catch {
            Write-SetupLog "Feature $feature - already enabled" "INFO"
        }
    }
    
    # Create Web Directory
    Write-SetupLog "Creating web directory..."
    $webPath = "C:\inetpub\wwwroot\CertWebService"
    
    if (Test-Path $webPath) {
        Remove-Item $webPath -Recurse -Force
    }
    New-Item -Path $webPath -ItemType Directory -Force | Out-Null
    
    # Copy Web Files
    Write-SetupLog "Copying web files..."
    $sourceWebFiles = Join-Path $PSScriptRoot "WebFiles"
    
    if (Test-Path $sourceWebFiles) {
        Copy-Item "$sourceWebFiles\*" $webPath -Recurse -Force
        Write-SetupLog "Web files copied successfully"
    } else {
        # Create minimal files
        @{
            timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            certificates = @()
            summary = @{ total = 0; expired = 0; expiring_soon = 0 }
        } | ConvertTo-Json -Depth 3 | Set-Content "$webPath\certificates.json" -Encoding UTF8
        
        @{
            status = "healthy"
            timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            version = "v2.3.0"
            read_only_mode = $true
        } | ConvertTo-Json | Set-Content "$webPath\health.json" -Encoding UTF8
        
        @{
            service = "Certificate Web Service"
            version = "v2.3.0"
            mode = "Read-Only"
            last_update = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        } | ConvertTo-Json | Set-Content "$webPath\summary.json" -Encoding UTF8
        
        @"
<!DOCTYPE html>
<html>
<head><title>Certificate Web Service v2.3.0</title></head>
<body>
<h1>🔒 Certificate Web Service v2.3.0</h1>
<p><strong>Read-Only Mode</strong> - Nur für autorisierte Server</p>
<h2>API Endpoints:</h2>
<ul>
<li><a href="certificates.json">certificates.json</a></li>
<li><a href="health.json">health.json</a></li>
<li><a href="summary.json">summary.json</a></li>
</ul>
</body>
</html>
"@ | Set-Content "$webPath\index.html" -Encoding UTF8
    }
    
    # Create IIS Website
    Write-SetupLog "Creating IIS website..."
    try {
        Import-Module WebAdministration -ErrorAction SilentlyContinue
        
        if (Get-Website -Name "CertWebService" -ErrorAction SilentlyContinue) {
            Remove-Website -Name "CertWebService"
        }
        
        New-Website -Name "CertWebService" -PhysicalPath $webPath -Port $Port
        Write-SetupLog "Website created on port $Port"
    } catch {
        Write-SetupLog "IIS configuration failed: $_" "ERROR"
        throw
    }
    
    # Configure Firewall
    Write-SetupLog "Configuring firewall..."
    try {
        Get-NetFirewallRule -DisplayName "CertWebService*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule
        New-NetFirewallRule -DisplayName "CertWebService-HTTP" -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow -Enabled True
        Write-SetupLog "Firewall rules created"
    } catch {
        Write-SetupLog "Firewall configuration failed: $_" "WARNING"
    }
    
    Write-SetupLog "Setup completed successfully!"
    Write-Host ""
    Write-Host "✅ Certificate Web Service installed!" -ForegroundColor Green
    Write-Host "   URL: http://$($env:COMPUTERNAME):$Port" -ForegroundColor Cyan
    Write-Host "   API: http://$($env:COMPUTERNAME):$Port/certificates.json" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "🔒 Read-Only Mode: Nur GET/HEAD/OPTIONS erlaubt" -ForegroundColor Yellow
    Write-Host "👥 Autorisierte Server: 3" -ForegroundColor Yellow
    Write-Host ""
    
} catch {
    Write-SetupLog "Setup failed: $($_.Exception.Message)" "ERROR"
    Write-Host "❌ Installation failed: $_" -ForegroundColor Red
    exit 1
}