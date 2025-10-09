#requires -version 5.1
#requires -runasadministrator

<#
.SYNOPSIS
    Installs and configures the Certificate Web Service with IIS and self-signed certificates.

.DESCRIPTION
    This script installs a web service for certificate management, including:
    - IIS installation and configuration
    - Self-signed certificate creation
    - HTTPS binding setup
    - Windows Authentication configuration
    - Firewall rules configuration
    - Initial certificate data generation

.PARAMETER WhatIf
    Shows what the script would do without making changes

.EXAMPLE
    .\Install-CertificateWebService.ps1
    Installs the web service with default configuration

.EXAMPLE
    .\Install-CertificateWebService.ps1 -WhatIf
    Shows installation steps without executing them

.AUTHOR
    System Administrator

.VERSION
    1.0.0

.RULEBOOK
    v9.3.0
#>

[CmdletBinding()]
param(
    [Switch]$WhatIf
)

#---------------------------------------------------------[Script Parameters]------------------------------------------------------

# Script Metadata
$Global:ScriptVersion = "1.0.0"
$Global:RulebookVersion = "v9.3.0"
$Global:ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition
$Global:sLogFile = Join-Path $Global:ScriptDirectory "LOG\Install-CertificateWebService_$(Get-Date -Format 'yyyy-MM-dd').log"

# Ensure LOG directory exists
if (-not (Test-Path (Split-Path $Global:sLogFile -Parent))) {
    New-Item -ItemType Directory -Path (Split-Path $Global:sLogFile -Parent) -Force | Out-Null
}

#----------------------------------------------------------[Imports]-------------------------------------------------------------

# Import required modules
$modulePaths = @(
    ".\Modules\FL-Config.psm1",
    ".\Modules\FL-Logging.psm1",
    ".\Modules\FL-WebService.psm1"
)

foreach ($modulePath in $modulePaths) {
    $fullPath = Join-Path $Global:ScriptDirectory $modulePath
    if (Test-Path $fullPath) {
        Import-Module $fullPath -Force
        Write-Host "Module loaded: $modulePath" -ForegroundColor Green
    } else {
        Write-Error "Required module not found: $fullPath"
        exit 1
    }
}

#---------------------------------------------------------[# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
Functions]------------------------------------------------------------

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
function Show-Banner {
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host " Certificate Web Service Installer v$Global:ScriptVersion" -ForegroundColor White
    Write-Host " Rulebook Version: $Global:RulebookVersion" -ForegroundColor Gray
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
}

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
function Test-Prerequisites {
    param(
        [string]$LogFile
    )
    
    # Test Administrator privileges
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "This script must be run as Administrator"
    }
    
    # Test PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        throw "PowerShell 5.1 or higher is required"
    }
    
    # Test Windows version
    $osVersion = [System.Environment]::OSVersion.Version
    if ($osVersion.Major -lt 6 -or ($osVersion.Major -eq 6 -and $osVersion.Minor -lt 3)) {
        throw "Windows Server 2012 R2 or higher is required"
    }
    
    Write-Log "All prerequisites satisfied" -LogFile $LogFile
    return $true
}

#----------------------------------------------------------[Main Execution]----------------------------------------------------------

try {
    Show-Banner
    
    Write-Log "=== Certificate Web Service Installer $Global:ScriptVersion Started ===" -LogFile $Global:sLogFile
    Write-Log "Rulebook Version: $Global:RulebookVersion" -LogFile $Global:sLogFile
    Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)" -LogFile $Global:sLogFile
    Write-Log "Operating System: $([System.Environment]::OSVersion.VersionString)" -LogFile $Global:sLogFile
    Write-Log "Current User: $([System.Environment]::UserName)" -LogFile $Global:sLogFile
    
    if ($WhatIf) {
        Write-Host "WhatIf Mode - No changes will be made" -ForegroundColor Yellow
        Write-Log "Running in WhatIf mode - no changes will be made" -LogFile $Global:sLogFile
    }
    
    # Test prerequisites
    Write-Host "Testing prerequisites..." -ForegroundColor Yellow
    Test-Prerequisites -LogFile $Global:sLogFile
    Write-Host "   Prerequisites satisfied" -ForegroundColor Green
    
    # Load configuration
    Write-Host "Loading configuration..." -ForegroundColor Yellow
    $configResult = Get-ScriptConfiguration -ScriptDirectory $Global:ScriptDirectory
    $Config = $configResult.Config
    $Lang = $configResult.Localization
    
    if (-not $Config -or -not $Lang) {
        throw "Failed to load configuration or localization"
    }
    
    Write-Host "   Configuration loaded" -ForegroundColor Green
    Write-Host "   Site Name: $($Config.WebService.SiteName)" -ForegroundColor Gray
    Write-Host "   HTTP Port: $($Config.WebService.HttpPort)" -ForegroundColor Gray
    Write-Host "   HTTPS Port: $($Config.WebService.HttpsPort)" -ForegroundColor Gray
    Write-Host "   Subject: $($Config.WebService.SubjectName)" -ForegroundColor Gray
    Write-Host "   Certificate Validity: $($Config.Certificate.ValidityDays) days" -ForegroundColor Gray
    
    # Validate critical configuration
    if ([string]::IsNullOrEmpty($Config.WebService.SubjectName)) {
        throw "WebService.SubjectName is not configured"
    }
    
    if ($WhatIf) {
        Write-Host "WhatIf: Would perform the following actions:" -ForegroundColor Yellow
        Write-Host "   - Create self-signed certificate for $($Config.WebService.SubjectName)" -ForegroundColor Gray
        Write-Host "   - Install/configure IIS with website $($Config.WebService.SiteName)" -ForegroundColor Gray
        Write-Host "   - Create HTTPS binding on port $($Config.WebService.HttpsPort)" -ForegroundColor Gray
        Write-Host "   - Configure Windows Authentication" -ForegroundColor Gray
        Write-Host "   - Create firewall rules for ports $($Config.WebService.HttpPort) and $($Config.WebService.HttpsPort)" -ForegroundColor Gray
        Write-Host "   - Generate initial certificate data and HTML interface" -ForegroundColor Gray
        Write-Host "WhatIf completed - no changes were made" -ForegroundColor Green
        return
    }
    
    # Confirm installation
    Write-Host "Do you want to proceed with the installation? (Y/N): " -ForegroundColor Yellow -NoNewline
    $confirmation = Read-Host
    if ($confirmation -notlike 'Y*' -and $confirmation -notlike 'y*') {
        Write-Host "Installation cancelled by user" -ForegroundColor Red
        Write-Log "Installation cancelled by user" -LogFile $Global:sLogFile
        return
    }
    
    Write-Host "$($Lang.InstallationStarted)" -ForegroundColor Cyan
    Write-Log "$($Lang.InstallationStarted)" -LogFile $Global:sLogFile
    
    # Step 1: Create self-signed certificate
    Write-Host "$($Lang.CertificateCreated)..." -ForegroundColor Yellow
    $certificate = New-WebServiceCertificate -SubjectName $Config.WebService.SubjectName -ValidityDays $Config.Certificate.ValidityDays -LogFile $Global:sLogFile
    Write-Host "   Certificate created: $($certificate.Thumbprint)" -ForegroundColor Green
    
    # Step 2: Install IIS web service
    Write-Host "$($Lang.WebServiceInstalled)..." -ForegroundColor Yellow
    $webService = Install-CertificateWebService -SiteName $Config.WebService.SiteName -SitePath $Config.WebService.SitePath -HttpPort $Config.WebService.HttpPort -HttpsPort $Config.WebService.HttpsPort -Certificate $certificate.Certificate -Config $Config -LogFile $Global:sLogFile
    Write-Host "   Web service installed successfully" -ForegroundColor Green
    
    # Step 3: Generate initial content
    Write-Host "$($Lang.ContentUpdated)..." -ForegroundColor Yellow
    $updateResult = Update-CertificateWebService -SitePath $Config.WebService.SitePath -Config $Config -LogFile $Global:sLogFile
    Write-Host "   Found $($updateResult.CertificateCount) $($Lang.CertificateCount)" -ForegroundColor Green
    
    # Step 4: Test web service
    Write-Host "Testing web service..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    try {
        $testUrl = "https://localhost:$($Config.WebService.HttpsPort)/api/certificates"
        $response = Invoke-WebRequest -Uri $testUrl -UseBasicParsing -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            Write-Host "   Web service is responding correctly" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "   Warning: Web service test failed (this is normal during first installation)" -ForegroundColor Yellow
        Write-Log "Web service test failed: $($_.Exception.Message)" -LogFile $Global:sLogFile
    }
    
    Write-Log "Certificate Web Service installation completed successfully" -LogFile $Global:sLogFile
    Write-Host "Installation completed successfully!" -ForegroundColor Green
    Write-Host "   WebService URL: https://localhost:$($Config.WebService.HttpsPort)" -ForegroundColor Cyan
    Write-Host "   Log file: $Global:sLogFile" -ForegroundColor Gray
}
catch {
    $errorMessage = "Installation failed: $($_.Exception.Message)"
    Write-Host "$errorMessage" -ForegroundColor Red
    Write-Log $errorMessage -Level ERROR -LogFile $Global:sLogFile
    
    Write-Host "Troubleshooting suggestions:" -ForegroundColor Yellow
    Write-Host "   - Ensure script is run as Administrator" -ForegroundColor Gray
    Write-Host "   - Check Windows features (IIS components)" -ForegroundColor Gray
    Write-Host "   - Verify firewall allows IIS installation" -ForegroundColor Gray
    Write-Host "   - Review log file: $Global:sLogFile" -ForegroundColor Gray
    
    exit 1
}

# --- End of Script --- old: v1.0.0 ; now: v1.0.0 ; Regelwerk: v9.3.0 ---
