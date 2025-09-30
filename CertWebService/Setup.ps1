#requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Certificate Web Service - Complete Setup and Installation (Regelwerk v10.0.0)

.DESCRIPTION
    Orchestrates the setup of the IIS-based certificate web service.
    This script is compliant with Regelwerk v10.0.0, focusing on strict modularity (§10).
    All core logic is delegated to specialized `FL-*` modules.

.PARAMETER Port
    HTTP port for the web service (default: 8080).
    
.PARAMETER SecurePort  
    HTTPS port for the web service (default: 8443).
    
.PARAMETER Force
    Forces reinstallation even if the service already exists.

.NOTES
    Author:         Flecki (Tom) Garnreiter
    Version:        v2.3.0
    Regelwerk:      v10.0.0
    
.EXAMPLE
    .\Setup.ps1
    Standard installation with default ports.
    
.EXAMPLE
    .\Setup.ps1 -Port 80 -SecurePort 443 -Force
    Custom ports with forced reinstallation.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [int]$Port = 8080,
    [int]$SecurePort = 8443,
    [switch]$Force
)

#region Initialization (§1, §5, §6)
# --- Version and Script Info ---
. (Join-Path $PSScriptRoot "VERSION.ps1")
Show-ScriptInfo -ScriptName "Certificate Web Service Setup"

# --- Centralized Logging ---
$Global:LogFilePath = Join-Path $PSScriptRoot "LOG\Setup_$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
Import-Module (Join-Path $PSScriptRoot 'Modules\FL-Logging.psm1') -Force
$LogBlock = { param($Message, $Level = 'INFO') Write-Log -Message $Message -Level $Level -LogPath $Global:LogFilePath }

# --- Configuration ---
Import-Module (Join-Path $PSScriptRoot 'Modules\FL-Config.psm1') -Force
$Config = Get-ScriptConfiguration -ConfigPath (Join-Path $PSScriptRoot "Config\CertWebService-Config.json") -LogFunction $LogBlock

# --- Initial Status Update (§12) ---
Set-CertWebServiceStatus -Status "SETUP_STARTED" -Details @{ Port = $Port; SecurePort = $SecurePort; Force = $Force.IsPresent }
#endregion

#region Module Import (§7, §10)
try {
    . $LogBlock "Importing core logic modules."
    Import-Module (Join-Path $PSScriptRoot 'Modules\FL-System.psm1') -Force
    Import-Module (Join-Path $PSScriptRoot 'Modules\FL-Certificate.psm1') -Force
    Import-Module (Join-Path $PSScriptRoot 'Modules\FL-IIS-Management.psm1') -Force
    Import-Module (Join-Path $PSScriptRoot 'Modules\FL-Network.psm1') -Force
    Import-Module (Join-Path $PSScriptRoot 'Modules\FL-FileOperations.psm1') -Force
    Import-Module (Join-Path $PSScriptRoot 'Modules\FL-WebService-Content.psm1') -Force
    Import-Module (Join-Path $PSScriptRoot 'Modules\FL-AccessControl.psm1') -Force
} catch {
    . $LogBlock "Failed to import required modules: $_" -Level 'FATAL'
    exit 1
}
#endregion

#region Main Execution (§10 - Orchestration)
try {
    . $LogBlock "=== Certificate Web Service Setup Started (v10.0.0 Compliant) ==="
    
    # Check if already installed
    if (-not $Force -and (Get-Website -Name $Config.SiteName -ErrorAction SilentlyContinue)) {
        . $LogBlock "Website '$($Config.SiteName)' already exists. Use -Force to reinstall." -Level 'WARNING'
        exit 0
    }
    
    # Step 1: Install Windows features (§7)
    Install-RequiredFeatures -LogFunction $LogBlock
    
    # Step 2: Create SSL certificate (§14)
    $certificate = New-WebServiceCertificate -SubjectName $env:COMPUTERNAME -LogFunction $LogBlock
    
    # Step 3: Prepare web directory (§11)
    $webPath = Join-Path $env:SystemDrive "inetpub\wwwroot\CertWebService"
    $sourcePath = Join-Path $PSScriptRoot "WebFiles"
    Copy-FilesRobust -Source $sourcePath -Destination $webPath -LogFunction $LogBlock
    
    # Copy web.config for read-only access control
    $webConfigSource = Join-Path $sourcePath "web.config"
    $webConfigDest = Join-Path $webPath "web.config"
    if (Test-Path $webConfigSource) {
        Copy-Item $webConfigSource $webConfigDest -Force
        . $LogBlock "Web.config copied with read-only access control settings" "INFO"
    }
    
    # Step 4: Create IIS website (§7)
    Install-IISWebService -SiteName $Config.SiteName -PhysicalPath $webPath -HttpPort $Port -HttpsPort $SecurePort -CertificateThumbprint $certificate.Thumbprint -LogFunction $LogBlock
    
    # Step 5: Configure firewall (§13)
    New-FirewallRules -HttpPort $Port -HttpsPort $SecurePort -LogFunction $LogBlock
    
    # Step 6: Install Access Control Rules (§13)
    . $LogBlock "Installing Access Control and Firewall rules."
    Install-AccessControlRules -Config $Config -HttpPort $Port -HttpsPort $SecurePort -LogFunction $LogBlock
    
    # Step 7: Initial data update (§7)
    . $LogBlock "Performing initial certificate scan and content generation."
    $certData = Get-CertificateWebData -LogFunction $LogBlock
    Update-WebServiceContent -SitePath $webPath -CertificateData $certData -LogFunction $LogBlock
    
    . $LogBlock "=== Setup completed successfully ===" -Level 'INFO'
    Write-Host "`n✅ Certificate Web Service installed successfully!" -ForegroundColor Green
    Write-Host "   HTTP:  http://$($env:COMPUTERNAME):$Port" -ForegroundColor Cyan
    Write-Host "   HTTPS: https://$($env:COMPUTERNAME):$SecurePort" -ForegroundColor Cyan
    
    # Final Status Update (§12)
    Set-CertWebServiceStatus -Status "INSTALLED" -Details @{ HttpPort = $Port; HttpsPort = $SecurePort; SiteName = $Config.SiteName }
    
} catch {
    . $LogBlock "Setup failed: $($_.Exception.Message)" -Level 'FATAL'
    Write-Error "Setup failed: $_"
    exit 1
}
#endregion