#Requires -version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Certificate Web Service - Update and Maintenance

.DESCRIPTION
    Updates certificate data and performs maintenance tasks for the web service.
    Replaces all previous Update-* scripts with a single solution.
    Compatible with PowerShell 5.1 and 7.x according to MUW-Regelwerk v9.6.2.

.PARAMETER Force
    Forces update even if cache is still valid
    
.PARAMETER SkipCache
    Bypasses cache and performs fresh certificate scan

.NOTES
    Author:         Flecki (Tom) Garnreiter
    Version:        v2.2.0
    Regelwerk:      v9.6.2
    
.EXAMPLE
    .\Update.ps1
    Standard update respecting cache settings
    
.EXAMPLE
    .\Update.ps1 -Force -SkipCache
    Forces complete refresh of all data
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Force,
    [switch]$SkipCache
)

#region Initialization
. (Join-Path (Split-Path -Path $MyInvocation.MyCommand.Path) "VERSION.ps1")
Show-ScriptInfo -ScriptName "Certificate Web Service Update" -CurrentVersion $ScriptVersion

$Global:ScriptDirectory = $PSScriptRoot
$Global:LogFile = Join-Path $Global:ScriptDirectory "LOG\Update_$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

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
function Get-LocalCertificates {
    Write-Log "Scanning local certificate stores..."
    
    $certificates = @()
    $stores = @('My', 'Root', 'CA', 'Trust', 'Disallowed')
    
    foreach ($storeName in $stores) {
        try {
            $store = Get-ChildItem -Path "Cert:\LocalMachine\$storeName" -ErrorAction SilentlyContinue
            
            foreach ($cert in $store) {
                $daysRemaining = ($cert.NotAfter - (Get-Date)).Days
                
                # Apply filters from configuration
                $includecert = $true
                
                if ($Config.Certificate.FilterMicrosoft -and $cert.Subject -match "Microsoft|Windows") {
                    $includecer = $false
                }
                
                if ($Config.Certificate.FilterRootCerts -and $storeName -eq "Root") {
                    $includeCart = $false
                }
                
                if ($includecer) {
                    $certInfo = [PSCustomObject]@{
                        Subject = $cert.Subject
                        Issuer = $cert.Issuer
                        NotBefore = $cert.NotBefore
                        NotAfter = $cert.NotAfter
                        DaysRemaining = $daysRemaining
                        Thumbprint = $cert.Thumbprint
                        Store = $storeName
                        HasPrivateKey = $cert.HasPrivateKey
                        KeyUsage = $cert.Extensions | Where-Object { $_.Oid.FriendlyName -eq "Key Usage" } | Select-Object -ExpandProperty Format -First 1
                        Status = if ($daysRemaining -le 0) { "Expired" } elseif ($daysRemaining -le 30) { "Expiring" } else { "Valid" }
                    }
                    
                    $certificates += $certInfo
                }
            }
        } catch {
            Write-Log "Error accessing certificate store $storeName: $($_.Exception.Message)" -Level WARNING
        }
    }
    
    Write-Log "Found $($certificates.Count) certificates to process"
    return $certificates
}

function Update-WebServiceData {
    param([array]$Certificates)
    
    Write-Log "Updating web service data files..."
    
    $webPath = Join-Path $env:inetpub "wwwroot\CertWebService"
    
    if (-not (Test-Path $webPath)) {
        Write-Log "Web directory not found: $webPath" -Level ERROR
        throw "Web service not properly installed"
    }
    
    # Create API data
    $apiData = @{
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Server = $env:COMPUTERNAME
        CertificateCount = $Certificates.Count
        Certificates = $Certificates
        Summary = @{
            Valid = ($Certificates | Where-Object { $_.Status -eq "Valid" }).Count
            Expiring = ($Certificates | Where-Object { $_.Status -eq "Expiring" }).Count
            Expired = ($Certificates | Where-Object { $_.Status -eq "Expired" }).Count
        }
        Version = $ScriptVersion
        RegelwerkVersion = $RegelwerkVersion
    }
    
    # Save API data
    $apiPath = Join-Path $webPath "api.json"
    $apiData | ConvertTo-Json -Depth 10 | Out-File $apiPath -Encoding UTF8
    
    # Update summary for web interface
    $summaryPath = Join-Path $webPath "summary.json"
    $apiData.Summary | Add-Member -MemberType NoteProperty -Name "LastUpdate" -Value $apiData.Timestamp
    $apiData.Summary | Add-Member -MemberType NoteProperty -Name "Server" -Value $env:COMPUTERNAME
    $apiData.Summary | ConvertTo-Json | Out-File $summaryPath -Encoding UTF8
    
    Write-Log "Web service data updated successfully"
}

function Test-ServiceHealth {
    Write-Log "Performing service health check..."
    
    # Check IIS site status
    $site = Get-Website -Name $Config.SiteName -ErrorAction SilentlyContinue
    if (-not $site) {
        Write-Log "Website not found: $($Config.SiteName)" -Level ERROR
        return $false
    }
    
    if ($site.State -ne "Started") {
        Write-Log "Website is not running, attempting to start..." -Level WARNING
        Start-Website -Name $Config.SiteName
    }
    
    # Test web connectivity
    try {
        $response = Invoke-WebRequest -Uri "https://localhost:$($Config.WebService.HttpsPort)/api.json" -UseBasicParsing -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            Write-Log "Service health check passed"
            return $true
        }
    } catch {
        Write-Log "Service health check failed: $($_.Exception.Message)" -Level WARNING
    }
    
    return $false
}

function Invoke-Maintenance {
    Write-Log "Performing maintenance tasks..."
    
    # Clean old log files (older than 30 days)
    $logPath = Join-Path $Global:ScriptDirectory "LOG"
    $cutoffDate = (Get-Date).AddDays(-30)
    
    Get-ChildItem -Path $logPath -Filter "*.log" | Where-Object { 
        $_.CreationTime -lt $cutoffDate 
    } | ForEach-Object {
        Write-Log "Removing old log file: $($_.Name)"
        Remove-Item $_.FullName -Force
    }
    
    # Verify certificate expiration for web service itself
    $webCert = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { 
        $_.Subject -match $env:COMPUTERNAME 
    } | Sort-Object NotAfter -Descending | Select-Object -First 1
    
    if ($webCert) {
        $daysRemaining = ($webCert.NotAfter - (Get-Date)).Days
        if ($daysRemaining -le 30) {
            Write-Log "Web service SSL certificate expires in $daysRemaining days!" -Level WARNING
        }
    }
    
    Write-Log "Maintenance tasks completed"
}
#endregion

#region Main Execution
try {
    Write-Log "=== Certificate Web Service Update Started ==="
    
    # Check if update is needed (respect cache if not forced)
    if (-not $Force -and -not $SkipCache) {
        $lastUpdateFile = Join-Path $Global:ScriptDirectory "LOG\LastUpdate.txt"
        if (Test-Path $lastUpdateFile) {
            $lastUpdate = Get-Content $lastUpdateFile | ConvertTo-DateTime -ErrorAction SilentlyContinue
            $cacheMinutes = $Config.Performance.CacheDurationMinutes ?? 15
            
            if ($lastUpdate -and (Get-Date).AddMinutes(-$cacheMinutes) -lt $lastUpdate) {
                Write-Log "Cache is still valid, skipping update. Use -Force to override."
                exit 0
            }
        }
    }
    
    # Step 1: Get current certificates
    $certificates = Get-LocalCertificates
    
    # Step 2: Update web service data
    if ($PSCmdlet.ShouldProcess("Web Service Data", "Update")) {
        Update-WebServiceData -Certificates $certificates
    }
    
    # Step 3: Health check
    $healthOk = Test-ServiceHealth
    
    # Step 4: Maintenance
    Invoke-Maintenance
    
    # Step 5: Update cache timestamp
    $timestampFile = Join-Path $Global:ScriptDirectory "LOG\LastUpdate.txt"
    Get-Date | Out-File $timestampFile -Encoding UTF8
    
    Write-Log "=== Update completed successfully ==="
    Write-Host "✅ Certificate Web Service updated successfully!" -ForegroundColor Green
    Write-Host "📊 Processed $($certificates.Count) certificates" -ForegroundColor Cyan
    Write-Host "🏥 Service Health: $(if ($healthOk) { 'OK' } else { 'Warning' })" -ForegroundColor $(if ($healthOk) { 'Green' } else { 'Yellow' })
    
    # Send status notification
    Set-CertWebServiceStatus -Status "UPDATED" -Details @{
        CertificateCount = $certificates.Count
        ServiceHealth = $healthOk
        LastUpdate = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    }
    
    # Notify other systems
    Send-WebServiceNotification -ServiceStatus "RUNNING" -IISStatus "OK" -CertificateCount $certificates.Count
    
} catch {
    Write-Log "Update failed: $($_.Exception.Message)" -Level ERROR
    Write-Error "Update failed: $_"
    exit 1
}
#endregion