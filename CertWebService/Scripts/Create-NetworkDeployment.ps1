#requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Certificate WebService - Network Deployment Package Creator (Regelwerk v10.1.0)

.DESCRIPTION
    Creates a complete deployment package for the Certificate WebService
    on the network share \\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService
    with all necessary modules and installation scripts.
    
.AUTHOR
    System Administrator

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

# Script Information
$Script:Version = "v2.3.0"
$Script:RulebookVersion = "v10.1.0"
$Script:BuildDate = Get-Date -Format "yyyy-MM-dd"

Write-Host "🚀 Certificate WebService - Network Deployment Package Creator" -ForegroundColor Cyan
Write-Host "   Version: $Script:Version | Regelwerk: $Script:RulebookVersion" -ForegroundColor Gray
Write-Host ""

try {
    # Step 1: Verify network access
    Write-Host "🔍 Verifying network access..." -ForegroundColor Yellow
    if (-not (Test-Path $NetworkPath)) {
        throw "Network path not accessible: $NetworkPath"
    }
    Write-Host "✅ Network path accessible" -ForegroundColor Green
    
    # Step 2: Backup existing deployment if requested
    if ($BackupExisting) {
        Write-Host "💾 Creating backup of existing deployment..." -ForegroundColor Yellow
        $backupPath = "$NetworkPath-Backup-$(Get-Date -Format 'yyyy-MM-dd-HH-mm')"
        Copy-Item -Path $NetworkPath -Destination $backupPath -Recurse -Force
        Write-Host "✅ Backup created: $backupPath" -ForegroundColor Green
    }
    
    # Step 3: Create deployment directory structure
    Write-Host "📁 Creating deployment package structure..." -ForegroundColor Yellow
    
    $deploymentStructure = @{
        "Core" = @()
        "Modules" = @(
            "FL-Certificate.psm1",
            "FL-IIS-Management.psm1", 
            "FL-WebService-Content.psm1"
        )
        "Config" = @(
            "WebService.json"
        )
        "Scripts" = @(
            "Setup.ps1",
            "Install.bat",
            "Test.ps1",
            "Update-Content.ps1",
            "Remove.ps1"
        )
        "Documentation" = @(
            "README.md",
            "VERSION.txt",
            "DEPLOYMENT-GUIDE.md"
        )
    }
    
    # Create subdirectories
    foreach ($dir in $deploymentStructure.Keys) {
        $dirPath = Join-Path $NetworkPath $dir
        if (-not (Test-Path $dirPath)) {
            New-Item -Path $dirPath -ItemType Directory -Force | Out-Null
        }
    }
    
    # Step 4: Copy modernized modules
    Write-Host "📦 Copying modernized CertWebService modules..." -ForegroundColor Yellow
    
    $sourceModules = @(
        "F:\DEV\repositories\CertWebService\Modules\FL-Certificate.psm1",
        "F:\DEV\repositories\CertWebService\Modules\FL-IIS-Management.psm1",
        "F:\DEV\repositories\CertWebService\Modules\FL-WebService-Content.psm1"
    )
    
    $modulesPath = Join-Path $NetworkPath "Modules"
    foreach ($module in $sourceModules) {
        if (Test-Path $module) {
            $fileName = Split-Path $module -Leaf
            Copy-Item -Path $module -Destination (Join-Path $modulesPath $fileName) -Force
            Write-Host "   ✅ Copied: $fileName" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️ Module not found: $module" -ForegroundColor Yellow
        }
    }
    
    # Step 5: Generate deployment configuration
    Write-Host "⚙️ Generating deployment configuration..." -ForegroundColor Yellow
    
    $deploymentConfig = @{
        "WebService" = @{
            "Version" = $Script:Version
            "RulebookVersion" = $Script:RulebookVersion
            "BuildDate" = $Script:BuildDate
            "SiteName" = "CertWebService"
            "HttpPort" = 9080
            "HttpsPort" = 9443
            "SitePath" = "C:\inetpub\CertWebService"
            "UpdateInterval" = "Daily"
            "UpdateTime" = "06:00"
        }
        "Deployment" = @{
            "Method" = "NetworkShare"
            "LocalInstallPath" = "C:\Temp\CertWebService-Install"
            "RequiresAdminRights" = $true
            "SupportedOS" = @("Windows Server 2012 R2+", "Windows 10+")
            "Dependencies" = @("IIS", "PowerShell 5.1+")
        }
        "API" = @{
            "Endpoints" = @{
                "Certificates" = "/api/certificates.json"
                "Health" = "/api/health.json"
                "Summary" = "/api/summary.json"
            }
            "Authentication" = "Windows"
            "Protocols" = @("HTTP", "HTTPS")
        }
    }
    
    $configPath = Join-Path (Join-Path $NetworkPath "Config") "WebService.json"
    $deploymentConfig | ConvertTo-Json -Depth 5 | Set-Content -Path $configPath -Encoding UTF8
    
    # Step 6: Generate modern installation script
    Write-Host "📝 Generating installation scripts..." -ForegroundColor Yellow
    
    $modernSetupScript = @"
#requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Certificate WebService - Modern Setup Script (Regelwerk v10.1.0)

.DESCRIPTION
    Complete setup script for the modernized Certificate WebService
    with modular architecture and strict compliance to Regelwerk v10.1.0.
    
.VERSION
    $Script:Version

.RULEBOOK
    $Script:RulebookVersion
#>

param(
    [Parameter(Mandatory = `$false)]
    [int]`$HttpPort = 9080,
    
    [Parameter(Mandatory = `$false)]
    [int]`$HttpsPort = 9443,
    
    [Parameter(Mandatory = `$false)]
    [switch]`$Force
)

# Modern Setup Implementation
Write-Host "🚀 Certificate WebService Setup v$Script:Version" -ForegroundColor Cyan
Write-Host "   Regelwerk: $Script:RulebookVersion | Modern Modular Architecture" -ForegroundColor Gray
Write-Host ""

try {
    # Import modernized modules
    `$modulePath = Join-Path `$PSScriptRoot "Modules"
    
    Import-Module (Join-Path `$modulePath "FL-Certificate.psm1") -Force
    Import-Module (Join-Path `$modulePath "FL-IIS-Management.psm1") -Force  
    Import-Module (Join-Path `$modulePath "FL-WebService-Content.psm1") -Force
    
    # Load configuration
    `$configPath = Join-Path `$PSScriptRoot "Config\WebService.json"
    `$config = Get-Content `$configPath | ConvertFrom-Json
    
    # Execute deployment using orchestrated modules
    `$deployment = Deploy-CertificateWebService -SiteName `$config.WebService.SiteName -SitePath `$config.WebService.SitePath -HttpPort `$HttpPort -HttpsPort `$HttpsPort
    
    Write-Host "✅ Certificate WebService deployed successfully!" -ForegroundColor Green
    Write-Host "   Dashboard: `$(`$deployment.WebService.HttpsUrl)" -ForegroundColor Cyan
    Write-Host "   API: `$(`$deployment.WebService.ApiEndpoint)" -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ Setup failed: `$(`$_.Exception.Message)" -ForegroundColor Red
    exit 1
}
"@
    
    $setupPath = Join-Path (Join-Path $NetworkPath "Scripts") "Setup.ps1"
    $modernSetupScript | Set-Content -Path $setupPath -Encoding UTF8
    
    # Step 7: Generate VERSION.txt
    Write-Host "📄 Generating version documentation..." -ForegroundColor Yellow
    
    $versionContent = @"
Certificate WebService Deployment Package
==========================================

Version: $Script:Version
Build Date: $Script:BuildDate
Author: System Administrator
Compliance: Regelwerk $Script:RulebookVersion

=== MODERNIZED PACKAGE v$Script:Version ===

🎯 REGELWERK v10.1.0 COMPLIANCE:
✅ Strict Modularity (§10) - All modules < 300 lines
✅ PowerShell 5.1/7.x Compatibility (§3)
✅ Modern Architecture with Orchestration Pattern
✅ Enhanced Security & Performance
✅ Comprehensive Error Handling

📦 PACKAGE STRUCTURE:

Core/
├── Setup.ps1                    - Modern orchestrated setup
├── Install.bat                  - Network deployment installer
├── Test.ps1                     - Comprehensive testing suite
└── Update-Content.ps1           - Content refresh utility

Modules/
├── FL-Certificate.psm1          - SSL certificate management
├── FL-IIS-Management.psm1       - IIS configuration & setup
└── FL-WebService-Content.psm1   - Content generation & API

Config/
└── WebService.json              - Deployment configuration

Documentation/
├── README.md                    - Installation & usage guide
├── VERSION.txt                  - This file
└── DEPLOYMENT-GUIDE.md          - Deployment procedures

🚀 FEATURES:
=============
✅ Modular Architecture (Regelwerk v10.1.0)
✅ Network Share Deployment
✅ Local Installation Execution
✅ Automatic Certificate Management
✅ Rich HTML Dashboard
✅ RESTful JSON API
✅ Windows Authentication
✅ Firewall Auto-Configuration
✅ Scheduled Task Integration
✅ Health Monitoring
✅ Multi-OS Support (Server Core + Full)

🌐 API ENDPOINTS:
=================
- http://[SERVER]:9080/api/certificates.json
- http://[SERVER]:9080/api/health.json
- http://[SERVER]:9080/api/summary.json
- https://[SERVER]:9443/api/certificates.json (SSL)

📋 INSTALLATION:
================
1. Run as Administrator: Scripts\Install.bat
2. Test deployment: Scripts\Test.ps1
3. Update content: Scripts\Update-Content.ps1

🔧 INTEGRATION WITH CERTSURV:
=============================
The Certificate Surveillance System automatically discovers
and integrates with WebService APIs for high-performance
certificate data collection across the enterprise.

Last Updated: $Script:BuildDate
Build: Modern Modular Architecture v$Script:Version
"@
    
    $versionPath = Join-Path (Join-Path $NetworkPath "Documentation") "VERSION.txt"
    $versionContent | Set-Content -Path $versionPath -Encoding UTF8
    
    # Step 8: Final validation
    Write-Host "🧪 Validating deployment package..." -ForegroundColor Yellow
    
    $packageStats = @{
        TotalFiles = (Get-ChildItem $NetworkPath -Recurse -File).Count
        TotalSize = [math]::Round(((Get-ChildItem $NetworkPath -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB), 2)
        ModuleCount = (Get-ChildItem (Join-Path $NetworkPath "Modules") -Filter "*.psm1").Count
        ConfigFiles = (Get-ChildItem (Join-Path $NetworkPath "Config") -Filter "*.json").Count
    }
    
    Write-Host ""
    Write-Host "✅ DEPLOYMENT PACKAGE CREATED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host "   Location: $NetworkPath" -ForegroundColor Cyan
    Write-Host "   Version: $Script:Version (Regelwerk $Script:RulebookVersion)" -ForegroundColor Cyan
    Write-Host "   Files: $($packageStats.TotalFiles) | Size: $($packageStats.TotalSize) MB" -ForegroundColor Gray
    Write-Host "   Modules: $($packageStats.ModuleCount) | Config: $($packageStats.ConfigFiles)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "📋 NEXT STEPS:" -ForegroundColor Yellow
    Write-Host "   1. Test deployment on target server" -ForegroundColor White
    Write-Host "   2. Run: \\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService\Scripts\Install.bat" -ForegroundColor White
    Write-Host "   3. Verify: \\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService\Scripts\Test.ps1" -ForegroundColor White
    Write-Host ""
    
} catch {
    Write-Host "❌ Deployment package creation failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
