#!/usr/bin/env powershell
#requires -Version 5.1
#requires -RunAsAdministrator

<#
.SYNOPSIS
    Safe installation script for Certificate Web Service
.DESCRIPTION
    Installs the Certificate Web Service with enhanced error handling,
    timeouts, and server-optimized settings for PowerShell 5.1 environments.
.AUTHOR
    System Administrator
.VERSION
    v1.0.3
.RULEBOOK
    v9.3.0
#>

param(
    [string]$SubjectName = "localhost",
    [int]$HttpPort = 8080,
    [int]$HttpsPort = 8443,
    [int]$TimeoutSeconds = 300
)

# Enhanced error handling
# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
$ErrorActionPreference = 'Stop'
$PSDefaultParameterValues['*:ErrorAction'] = 'Stop'

# Module imports
$ModulePath = Join-Path $PSScriptRoot "Modules"
Import-Module (Join-Path $ModulePath "FL-Logging.psm1") -Force
Import-Module (Join-Path $ModulePath "FL-Config.psm1") -Force
Import-Module (Join-Path $ModulePath "FL-WebService.psm1") -Force

# Initialize logging
$LogDir = Join-Path $PSScriptRoot "LOG"
if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}
$LogFile = Join-Path $LogDir "WebService-Install_$(Get-Date -Format 'yyyy-MM-dd_HH-mm').log"

try {
    Write-Host "[INFO] Certificate Web Service Installation - Safe Mode" -ForegroundColor Cyan
    Write-Host "[INFO] Log File: $LogFile" -ForegroundColor Gray
    
    Write-Log "=== Certificate Web Service Installation Started ===" -LogFile $LogFile
    Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)" -LogFile $LogFile
    if ($PSVersionTable.OS) {
        Write-Log "Operating System: $($PSVersionTable.OS)" -LogFile $LogFile
    } else {
        Write-Log "Operating System: Windows PowerShell 5.1" -LogFile $LogFile
    }
    Write-Log "Subject Name: $SubjectName" -LogFile $LogFile
    Write-Log "HTTP Port: $HttpPort" -LogFile $LogFile
    Write-Log "HTTPS Port: $HttpsPort" -LogFile $LogFile
    
    # Check prerequisites
    Write-Host "[INFO] Checking prerequisites..." -ForegroundColor Yellow
    
    # Check if running as Administrator
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "This script must be run as Administrator"
    }
    
    # Check IIS availability
    $iisFeature = Get-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole -ErrorAction SilentlyContinue
    if (-not $iisFeature -or $iisFeature.State -ne 'Enabled') {
        Write-Host "[INFO] Installing IIS Web Server Role..." -ForegroundColor Yellow
        Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole -All -NoRestart
        Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServer -All -NoRestart
        Enable-WindowsOptionalFeature -Online -FeatureName IIS-CommonHttpFeatures -All -NoRestart
        Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpErrors -All -NoRestart
        Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpRedirect -All -NoRestart
        Enable-WindowsOptionalFeature -Online -FeatureName IIS-ApplicationDevelopment -All -NoRestart
        Enable-WindowsOptionalFeature -Online -FeatureName IIS-NetFxExtensibility45 -All -NoRestart
        Enable-WindowsOptionalFeature -Online -FeatureName IIS-HealthAndDiagnostics -All -NoRestart
        Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpLogging -All -NoRestart
        Enable-WindowsOptionalFeature -Online -FeatureName IIS-Security -All -NoRestart
        Enable-WindowsOptionalFeature -Online -FeatureName IIS-RequestFiltering -All -NoRestart
        Enable-WindowsOptionalFeature -Online -FeatureName IIS-Performance -All -NoRestart
        Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerManagementTools -All -NoRestart
        Enable-WindowsOptionalFeature -Online -FeatureName IIS-ManagementConsole -All -NoRestart
        Enable-WindowsOptionalFeature -Online -FeatureName IIS-IIS6ManagementCompatibility -All -NoRestart
        Enable-WindowsOptionalFeature -Online -FeatureName IIS-Metabase -All -NoRestart
        Write-Log "IIS features installed successfully" -LogFile $LogFile
    }
    
    # Create website directory
    $InetPubRoot = if ($env:inetpub) { $env:inetpub } else { "C:\inetpub" }
    $SitePath = Join-Path $InetPubRoot "wwwroot\CertSurveillance"
    Write-Host "[INFO] Creating website directory: $SitePath" -ForegroundColor Yellow
    New-Item -Path $SitePath -ItemType Directory -Force | Out-Null
    
    # Copy web files
    $WebFilesPath = Join-Path $PSScriptRoot "WebFiles"
    if (Test-Path $WebFilesPath) {
        Copy-Item -Path "$WebFilesPath\*" -Destination $SitePath -Recurse -Force
        Write-Log "Web files copied to $SitePath" -LogFile $LogFile
    }
    
    # Create certificate with timeout
    Write-Host "[INFO] Creating SSL certificate (with timeout: $TimeoutSeconds seconds)..." -ForegroundColor Yellow
    
    $certJob = Start-Job -ScriptBlock {
        param($SubjectName, $LogFile, $ModulePath)
        
        Import-Module (Join-Path $ModulePath "FL-Logging.psm1") -Force
        Import-Module (Join-Path $ModulePath "FL-WebService.psm1") -Force
        
        try {
            New-WebServiceCertificate -SubjectName $SubjectName -ValidityDays 365 -LogFile $LogFile
        }
        catch {
            throw $_.Exception.Message
        }
    } -ArgumentList $SubjectName, $LogFile, $ModulePath
    
    $certResult = $null
    if (Wait-Job $certJob -Timeout $TimeoutSeconds) {
        $certResult = Receive-Job $certJob
        Remove-Job $certJob
        
        if ($certResult -and $certResult.Certificate) {
            Write-Host "[SUCCESS] Certificate created: $($certResult.Thumbprint)" -ForegroundColor Green
            Write-Log "Certificate creation completed: $($certResult.Thumbprint)" -LogFile $LogFile
        } else {
            throw "Certificate creation failed - no valid certificate returned"
        }
    } else {
        Stop-Job $certJob
        Remove-Job $certJob
        throw "Certificate creation timed out after $TimeoutSeconds seconds"
    }
    
    # Install IIS web service
    Write-Host "[INFO] Configuring IIS web service..." -ForegroundColor Yellow
    
    # Create basic config object
    $config = @{
        WebService = @{
            SiteName = "CertSurveillance"
            HttpPort = $HttpPort
            HttpsPort = $HttpsPort
        }
    }
    
    $webServiceResult = Install-CertificateWebService -SiteName "CertSurveillance" -SitePath $SitePath -Certificate $certResult.Certificate -HttpPort $HttpPort -HttpsPort $HttpsPort -Config $config -LogFile $LogFile
    
    if ($webServiceResult) {
        Write-Host "[SUCCESS] IIS web service configured successfully" -ForegroundColor Green
        Write-Log "IIS web service installation completed" -LogFile $LogFile
    } else {
        throw "IIS web service configuration failed"
    }
    
    # Test connections
    Write-Host "[INFO] Testing web service connections..." -ForegroundColor Yellow
    
    Start-Sleep -Seconds 5  # Allow IIS to stabilize
    
    try {
        $httpResponse = Invoke-WebRequest -Uri "http://localhost:$HttpPort/certificates.json" -UseBasicParsing -TimeoutSec 10 -ErrorAction SilentlyContinue
        if ($httpResponse.StatusCode -eq 200) {
            Write-Host "[SUCCESS] HTTP endpoint responding" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "[WARNING] HTTP endpoint test failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    try {
        $httpsResponse = Invoke-WebRequest -Uri "https://localhost:$HttpsPort/certificates.json" -UseBasicParsing -TimeoutSec 10 -SkipCertificateCheck -ErrorAction SilentlyContinue
        if ($httpsResponse.StatusCode -eq 200) {
            Write-Host "[SUCCESS] HTTPS endpoint responding" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "[WARNING] HTTPS endpoint test failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Summary
    Write-Host "`n[SUCCESS] Certificate Web Service Installation Completed!" -ForegroundColor Green
    Write-Host "  HTTP URL:  http://$(hostname):$HttpPort" -ForegroundColor Cyan
    Write-Host "  HTTPS URL: https://$(hostname):$HttpsPort" -ForegroundColor Cyan
    Write-Host "  Site Path: $SitePath" -ForegroundColor Cyan
    Write-Host "  Certificate: $($certResult.Thumbprint)" -ForegroundColor Cyan
    Write-Host "  Log File: $LogFile" -ForegroundColor Gray
    
    Write-Log "Certificate Web Service installation completed successfully" -LogFile $LogFile
    
}
catch {
    $errorMessage = $_.Exception.Message
    Write-Host "[ERROR] Installation failed: $errorMessage" -ForegroundColor Red
    Write-Log "Installation failed: $errorMessage" -Level ERROR -LogFile $LogFile
    
    Write-Host "`nTroubleshooting steps:" -ForegroundColor Yellow
    Write-Host "1. Ensure script is run as Administrator" -ForegroundColor Gray
    Write-Host "2. Check Windows Event Log for certificate errors" -ForegroundColor Gray
    Write-Host "3. Verify IIS is properly installed" -ForegroundColor Gray
    Write-Host "4. Check firewall settings for ports $HttpPort and $HttpsPort" -ForegroundColor Gray
    Write-Host "5. Review log file: $LogFile" -ForegroundColor Gray
    
    exit 1
}
finally {
    Write-Log "=== Certificate Web Service Installation Ended ===" -LogFile $LogFile
}
