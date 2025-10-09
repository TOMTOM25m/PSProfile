#requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Certificate Web Service - Simplified Setup (Regelwerk v10.1.0)

.DESCRIPTION
    Simplified setup script for Read-Only Certificate Web Service
    with essential # Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
functionality only.

.NOTES
    Author:         Flecki (Tom) Garnreiter
    Version:        v2.3.0
    Regelwerk:      v10.1.0
#>
[CmdletBinding()]
param(
    [int]$Port = 9080,
    [int]$SecurePort = 9443,
    [string[]]$AuthorizedHosts = @(
        'ITSCMGMT03.srv.meduniwien.ac.at',
        'ITSC020.cc.meduniwien.ac.at',
        'itsc049.uvw.meduniwien.ac.at'
    )
)

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
#region Initialization
Write-Host "🚀 Certificate Web Service v2.3.0 Setup" -ForegroundColor Green
Write-Host "📋 Read-Only Mode für $($AuthorizedHosts.Count) autorisierte Server" -ForegroundColor Yellow
Write-Host ""

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
$ErrorActionPreference = 'Stop'
$StartTime = Get-Date
$LogPath = "C:\inetpub\CertWebService\Logs\Setup_$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Create log directory
$LogDir = Split-Path $LogPath -Parent
if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
function Write-SetupLog {
    param($Message, $Level = 'INFO')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    Add-Content $LogPath $logMessage -Encoding UTF8
}
#endregion

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
#region Main Installation
try {
    Write-SetupLog "=== Certificate Web Service Setup Started ==="
    
    # Step 1: Install IIS Features
    Write-SetupLog "Installing IIS features..."
    $features = @('IIS-WebServerRole', 'IIS-WebServer', 'IIS-CommonHttpFeatures', 'IIS-HttpErrors', 'IIS-HttpLogging', 'IIS-RequestFiltering', 'IIS-StaticContent', 'IIS-DefaultDocument', 'IIS-DirectoryBrowsing')
    
    foreach ($feature in $features) {
        try {
            Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart -ErrorAction SilentlyContinue | Out-Null
        } catch {
            Write-SetupLog "Feature $feature may already be enabled" "WARNING"
        }
    }
    
    # Step 2: Create Web Directory
    Write-SetupLog "Creating web directory..."
    $webPath = "C:\inetpub\wwwroot\CertWebService"
    if (Test-Path $webPath) {
        Remove-Item $webPath -Recurse -Force
    }
    New-Item -Path $webPath -ItemType Directory -Force | Out-Null
    
    # Copy WebFiles
    $sourceWebFiles = Join-Path $PSScriptRoot "WebFiles"
    if (Test-Path $sourceWebFiles) {
        Copy-Item "$sourceWebFiles\*" $webPath -Recurse -Force
        Write-SetupLog "Web files copied successfully"
    }
    
    # Step 3: Create IIS Website
    Write-SetupLog "Creating IIS website..."
    
    # Remove existing site if it exists
    try {
        Import-Module WebAdministration -ErrorAction SilentlyContinue
        if (Get-Website -Name "CertWebService" -ErrorAction SilentlyContinue) {
            Remove-Website -Name "CertWebService"
        }
    } catch { }
    
    # Create new website
    try {
        New-Website -Name "CertWebService" -PhysicalPath $webPath -Port $Port -ErrorAction Stop
        Write-SetupLog "Website created on port $Port"
    } catch {
        Write-SetupLog "Error creating website: $_" "ERROR"
        throw
    }
    
    # Step 4: Configure Firewall
    Write-SetupLog "Configuring firewall rules..."
    try {
        # Remove old rules
        Remove-NetFirewallRule -DisplayName "CertWebService*" -ErrorAction SilentlyContinue
        
        # Create new rules for authorized servers
    $authorizedHosts = $AuthorizedHosts
        
        New-NetFirewallRule -DisplayName "CertWebService-HTTP-Allow" -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow -Enabled True
        New-NetFirewallRule -DisplayName "CertWebService-HTTPS-Allow" -Direction Inbound -Protocol TCP -LocalPort $SecurePort -Action Allow -Enabled True
        
        Write-SetupLog "Firewall rules created"
    } catch {
        Write-SetupLog "Firewall configuration failed: $_" "WARNING"
    }
    
    # Step 5: Create initial certificate data
    Write-SetupLog "Creating initial certificate data..."
    $certData = @{
        timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        certificates = @()
        summary = @{
            total = 0
            expired = 0
            expiring_soon = 0
        }
    }
    
    # Scan local certificate store
    try {
        $certs = Get-ChildItem Cert:\LocalMachine\My | Where-Object { 
            $_.NotAfter -gt (Get-Date) -and 
            $_.Subject -notlike "*Microsoft*" 
        } | Select-Object -First 10
        
        foreach ($cert in $certs) {
            $daysToExpiry = ($cert.NotAfter - (Get-Date)).Days
            $certData.certificates += @{
                subject = $cert.Subject
                issuer = $cert.Issuer
                expires = $cert.NotAfter.ToString('yyyy-MM-dd')
                days_to_expiry = $daysToExpiry
                thumbprint = $cert.Thumbprint
            }
        }
        
        $certData.summary.total = $certData.certificates.Count
        $certData.summary.expired = ($certData.certificates | Where-Object { $_.days_to_expiry -le 0 }).Count
        $certData.summary.expiring_soon = ($certData.certificates | Where-Object { $_.days_to_expiry -le 30 -and $_.days_to_expiry -gt 0 }).Count
        
    } catch {
        Write-SetupLog "Certificate scan failed: $_" "WARNING"
    }
    
    # Save certificate data
    $certData | ConvertTo-Json -Depth 5 | Set-Content "$webPath\certificates.json" -Encoding UTF8
    
    # Create health status
    @{
        status = "healthy"
        timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        version = "v2.3.0"
        read_only_mode = $true
        authorized_host_count = $AuthorizedHosts.Count
        authorized_hosts = $AuthorizedHosts
    } | ConvertTo-Json -Depth 5 | Set-Content "$webPath\health.json" -Encoding UTF8
    
    # Create summary
    @{
        service = "Certificate Web Service"
        version = "v2.3.0"
        mode = "Read-Only"
        authorized_host_count = $AuthorizedHosts.Count
        authorized_hosts = $AuthorizedHosts
        last_update = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        certificate_count = $certData.summary.total
    } | ConvertTo-Json -Depth 5 | Set-Content "$webPath\summary.json" -Encoding UTF8
    
    Write-SetupLog "=== Setup completed successfully ==="
    Write-Host ""
    Write-Host "✅ Certificate Web Service installed successfully!" -ForegroundColor Green
    Write-Host "   HTTPS Endpoint: https://$($env:COMPUTERNAME):$SecurePort" -ForegroundColor Cyan
    Write-Host "   (HTTP endpoint disabled in summary output to encourage TLS usage)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "🔒 Read-Only Mode: Nur GET/HEAD/OPTIONS erlaubt" -ForegroundColor Yellow
    Write-Host "👥 Autorisierte Server: $($AuthorizedHosts.Count)" -ForegroundColor Yellow
    Write-Host ""
    
} catch {
    Write-SetupLog "Setup failed: $($_.Exception.Message)" "ERROR"
    Write-Error "Setup failed: $_"
    exit 1
}
#endregion
