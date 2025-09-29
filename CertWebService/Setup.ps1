#Requires -version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Certificate Web Service - Complete Setup and Installation

.DESCRIPTION
    Sets up IIS-based certificate web service for fast certificate surveillance.
    Replaces all previous Install-* scripts with a single, comprehensive solution.
    Compatible with PowerShell 5.1 and 7.x according to MUW-Regelwerk v9.6.2.

.PARAMETER Port
    HTTP port for the web service (default: 8080)
    
.PARAMETER SecurePort  
    HTTPS port for the web service (default: 8443)
    
.PARAMETER Force
    Forces reinstallation even if service already exists

.NOTES
    Author:         Flecki (Tom) Garnreiter
    Version:        v2.2.0
    Regelwerk:      v9.6.2
    
.EXAMPLE
    .\Setup.ps1
    Standard installation with default ports
    
.EXAMPLE
    .\Setup.ps1 -Port 80 -SecurePort 443 -Force
    Custom ports with forced reinstall
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [int]$Port = 8080,
    [int]$SecurePort = 8443,
    [switch]$Force
)

#region Initialization
. (Join-Path (Split-Path -Path $MyInvocation.MyCommand.Path) "VERSION.ps1")
Show-ScriptInfo -ScriptName "Certificate Web Service Setup" -CurrentVersion $ScriptVersion

# Set initial status for cross-script communication
Set-CertWebServiceStatus -Status "SETUP_STARTED" -Details @{
    Port = $Port
    SecurePort = $SecurePort
    Force = $Force.IsPresent
}

$Global:ScriptDirectory = $PSScriptRoot
$Global:LogFile = Join-Path $Global:ScriptDirectory "LOG\Setup_$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Ensure LOG directory exists
$logDir = Split-Path $Global:LogFile -Parent
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

# Import modules
try {
    Import-Module (Join-Path $Global:ScriptDirectory 'Modules\Configuration.psm1') -Force
    Import-Module (Join-Path $Global:ScriptDirectory 'Modules\WebService.psm1') -Force  
    Import-Module (Join-Path $Global:ScriptDirectory 'Modules\Logging.psm1') -Force
} catch {
    Write-Error "Failed to import required modules: $_"
    exit 1
}

# Load configuration
$Config = Get-WebServiceConfiguration -ConfigPath (Join-Path $Global:ScriptDirectory "Config\Settings.json")
#endregion

#region Main Functions
function Install-RequiredFeatures {
    Write-Log "Installing required Windows features..."
    
    $features = @(
        'IIS-WebServerRole',
        'IIS-WebServer', 
        'IIS-CommonHttpFeatures',
        'IIS-HttpErrors',
        'IIS-HttpRedirect',
        'IIS-ApplicationDevelopment',
        'IIS-NetFxExtensibility45',
        'IIS-HealthAndDiagnostics',
        'IIS-HttpLogging',
        'IIS-Security',
        'IIS-RequestFiltering',
        'IIS-Performance',
        'IIS-WebServerManagementTools',
        'IIS-ManagementConsole',
        'IIS-IIS6ManagementCompatibility',
        'IIS-Metabase',
        'IIS-WindowsAuthentication'
    )
    
    foreach ($feature in $features) {
        if ($PSCmdlet.ShouldProcess($feature, "Enable Windows Feature")) {
            Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart | Out-Null
        }
    }
    
    Write-Log "Windows features installation completed."
}

function New-SelfSignedSSLCertificate {
    param([string]$CommonName = $env:COMPUTERNAME)
    
    Write-Log "Creating self-signed SSL certificate for $CommonName..."
    
    if ($PSCmdlet.ShouldProcess($CommonName, "Create SSL Certificate")) {
        # Remove existing certificate if it exists
        Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { 
            $_.Subject -eq "CN=$CommonName" -and $_.Issuer -eq "CN=$CommonName" 
        } | Remove-Item
        
        # Create new certificate
        $cert = New-SelfSignedCertificate -DnsName $CommonName -CertStoreLocation "cert:\LocalMachine\My" -KeyLength 2048 -NotAfter (Get-Date).AddDays(365)
        
        # Add to trusted root certificates
        $store = New-Object System.Security.Cryptography.X509Certificates.X509Store([System.Security.Cryptography.X509Certificates.StoreName]::Root, [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine)
        $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
        $store.Add($cert)
        $store.Close()
        
        Write-Log "SSL certificate created and installed: $($cert.Thumbprint)"
        return $cert
    }
}

function New-IISWebSite {
    param(
        [string]$SiteName,
        [string]$PhysicalPath,
        [int]$HttpPort,
        [int]$HttpsPort,
        [string]$CertThumbprint
    )
    
    Write-Log "Creating IIS website: $SiteName"
    
    if ($PSCmdlet.ShouldProcess($SiteName, "Create IIS Website")) {
        # Import WebAdministration module
        Import-Module WebAdministration -Force
        
        # Remove existing site if it exists
        if (Get-Website -Name $SiteName -ErrorAction SilentlyContinue) {
            Remove-Website -Name $SiteName -ErrorAction SilentlyContinue
        }
        
        # Create new website
        New-Website -Name $SiteName -PhysicalPath $PhysicalPath -Port $HttpPort
        
        # Add HTTPS binding
        if ($CertThumbprint) {
            New-WebBinding -Name $SiteName -Protocol https -Port $HttpsPort
            $binding = Get-WebBinding -Name $SiteName -Protocol https
            $binding.AddSslCertificate($CertThumbprint, "my")
        }
        
        # Configure authentication
        Set-WebConfigurationProperty -Filter "/system.webServer/security/authentication/windowsAuthentication" -Name enabled -Value $true -PSPath "IIS:\" -Location "$SiteName"
        Set-WebConfigurationProperty -Filter "/system.webServer/security/authentication/anonymousAuthentication" -Name enabled -Value $false -PSPath "IIS:\" -Location "$SiteName"
        
        Write-Log "IIS website created successfully"
    }
}

function New-FirewallRules {
    param([int]$HttpPort, [int]$HttpsPort)
    
    Write-Log "Creating firewall rules for ports $HttpPort and $HttpsPort..."
    
    if ($PSCmdlet.ShouldProcess("Firewall", "Create Rules")) {
        # Remove existing rules
        Remove-NetFirewallRule -DisplayName "CertWebService HTTP" -ErrorAction SilentlyContinue
        Remove-NetFirewallRule -DisplayName "CertWebService HTTPS" -ErrorAction SilentlyContinue
        
        # Create new rules
        New-NetFirewallRule -DisplayName "CertWebService HTTP" -Direction Inbound -Protocol TCP -LocalPort $HttpPort -Action Allow
        New-NetFirewallRule -DisplayName "CertWebService HTTPS" -Direction Inbound -Protocol TCP -LocalPort $HttpsPort -Action Allow
        
        Write-Log "Firewall rules created successfully"
    }
}

function Copy-WebFiles {
    param([string]$DestinationPath)
    
    Write-Log "Copying web files to $DestinationPath..."
    
    if ($PSCmdlet.ShouldProcess($DestinationPath, "Copy Web Files")) {
        $sourcePath = Join-Path $Global:ScriptDirectory "WebFiles"
        
        if (-not (Test-Path $DestinationPath)) {
            New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
        }
        
        Copy-Item -Path "$sourcePath\*" -Destination $DestinationPath -Recurse -Force
        Write-Log "Web files copied successfully"
    }
}
#endregion

#region Main Execution
try {
    Write-Log "=== Certificate Web Service Setup Started ==="
    
    # Check if already installed
    if (-not $Force) {
        $existingSite = Get-Website -Name $Config.SiteName -ErrorAction SilentlyContinue
        if ($existingSite) {
            Write-Warning "Website '$($Config.SiteName)' already exists. Use -Force to reinstall."
            exit 0
        }
    }
    
    # Step 1: Install Windows features
    Install-RequiredFeatures
    
    # Step 2: Create SSL certificate
    $certificate = New-SelfSignedSSLCertificate -CommonName $env:COMPUTERNAME
    
    # Step 3: Prepare web directory
    $webPath = Join-Path $env:inetpub "wwwroot\CertWebService"
    Copy-WebFiles -DestinationPath $webPath
    
    # Step 4: Create IIS website
    New-IISWebSite -SiteName $Config.SiteName -PhysicalPath $webPath -HttpPort $Port -HttpsPort $SecurePort -CertThumbprint $certificate.Thumbprint
    
    # Step 5: Configure firewall
    New-FirewallRules -HttpPort $Port -HttpsPort $SecurePort
    
    # Step 6: Initial data update
    Write-Log "Performing initial certificate scan..."
    & (Join-Path $Global:ScriptDirectory "Update.ps1")
    
    Write-Log "=== Setup completed successfully ==="
    Write-Host "`n✅ Certificate Web Service installed successfully!" -ForegroundColor Green
    Write-Host "📍 HTTP:  http://$env:COMPUTERNAME:$Port" -ForegroundColor Cyan
    Write-Host "📍 HTTPS: https://$env:COMPUTERNAME:$SecurePort" -ForegroundColor Cyan
    Write-Host "🔧 Management: IIS Manager -> Sites -> $($Config.SiteName)" -ForegroundColor Yellow
    
    # Send status notification
    Set-CertWebServiceStatus -Status "INSTALLED" -Details @{
        HttpPort = $Port
        HttpsPort = $SecurePort
        SiteName = $Config.SiteName
        CertThumbprint = $certificate.Thumbprint
    }
    
} catch {
    Write-Log "Setup failed: $($_.Exception.Message)" -Level ERROR
    Write-Error "Setup failed: $_"
    exit 1
}
#endregion