#requires -Version 5.1

<#
.SYNOPSIS
    Certificate Web Service Content Updater
.DESCRIPTION
    Updates the certificate data displayed by the Certificate Web Service.
    This script can be run manually or scheduled to keep certificate
    information current.
.PARAMETER Force
    Forces update even if cache is still valid
.EXAMPLE
    .\Update-CertificateWebService.ps1
    Updates certificate data using cache settings
.EXAMPLE
    .\Update-CertificateWebService.ps1 -Force
    Forces immediate update ignoring cache
.AUTHOR
    System Administrator
.VERSION
    v1.0.0
.RULEBOOK
    v9.3.0
#>

#----------------------------------------------------------[Parameters]----------------------------------------------------------

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

#----------------------------------------------------------[Declarations]----------------------------------------------------------

# Script metadata
$Global:ScriptName = "Update-CertificateWebService"
$Global:ScriptVersion = "v1.0.0"
$Global:RulebookVersion = "v9.3.0"

# Global paths
$Global:ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$Global:sLogFile = Join-Path $Global:ScriptDirectory "LOG\TASK_Update-CertWebService_$(Get-Date -Format 'yyyy-MM-dd').log"

# Task Scheduler specific settings
$Global:IsTaskScheduler = $true
$Global:TaskStartTime = Get-Date

#----------------------------------------------------------[Imports]----------------------------------------------------------

# Import required modules
try {
    Import-Module "$Global:ScriptDirectory\Modules\FL-Config.psm1" -Force
    Import-Module "$Global:ScriptDirectory\Modules\FL-Logging.psm1" -Force  
    Import-Module "$Global:ScriptDirectory\Modules\FL-WebService.psm1" -Force
}
catch {
    Write-Error "Failed to import required modules: $($_.Exception.Message)"
    exit 1
}

#----------------------------------------------------------[Main Execution]----------------------------------------------------------

try {
    Write-Log "=== Certificate Web Service Updater $Global:ScriptVersion Started ===" -LogFile $Global:sLogFile
    Write-Log "Execution Type: $(if ($Global:IsTaskScheduler) { 'Task Scheduler' } else { 'Manual' })" -LogFile $Global:sLogFile
    Write-Log "Start Time: $($Global:TaskStartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -LogFile $Global:sLogFile
    
    # Load configuration
    $configResult = Get-ScriptConfiguration -ScriptDirectory $Global:ScriptDirectory
    $Config = $configResult.Config
    $Lang = $configResult.Localization
    
    # Check if cache is still valid (unless forced)
    if (-not $Force -and $Config.Performance.CacheEnabled) {
        $lastUpdateFile = Join-Path $Config.WebService.SitePath "last_update.txt"
        if (Test-Path $lastUpdateFile) {
            $lastUpdate = Get-Content $lastUpdateFile | Get-Date
            $cacheExpiry = $lastUpdate.AddMinutes($Config.Performance.CacheDurationMinutes)
            
            if ((Get-Date) -lt $cacheExpiry) {
                $minutesLeft = [math]::Ceiling(($cacheExpiry - (Get-Date)).TotalMinutes)
                $message = "Cache still valid for $minutesLeft minutes. Use -Force to override."
                if ($Global:IsTaskScheduler) {
                    Write-Log $message -LogFile $Global:sLogFile
                } else {
                    Write-Host $message -ForegroundColor Yellow
                }
                Write-Log "Cache still valid, skipping update" -LogFile $Global:sLogFile
                return
            }
        }
    }
    
    $message = "Updating certificate web service content..."
    if ($Global:IsTaskScheduler) {
        Write-Log "Starting certificate data update (scheduled)" -LogFile $Global:sLogFile
    } else {
        Write-Host $message -ForegroundColor Cyan
    }
    Write-Log "Starting certificate data update" -LogFile $Global:sLogFile
    
    # Check if web service is installed
    if (-not (Test-Path $Config.WebService.SitePath)) {
        throw "Web service not found at $($Config.WebService.SitePath). Please run Install-CertificateWebService.ps1 first."
    }
    
    # Update certificate content
    $updateResult = Update-CertificateWebService -SitePath $Config.WebService.SitePath -Config $Config -LogFile $Global:sLogFile
    
    # Update last update timestamp
    $currentTime = Get-Date
    $lastUpdateFile = Join-Path $Config.WebService.SitePath "last_update.txt"
    $currentTime.ToString('yyyy-MM-dd HH:mm:ss') | Set-Content -Path $lastUpdateFile
    
    Write-Host "[SUCCESS] Update completed successfully" -ForegroundColor Green
    Write-Host "   Certificates found: $($updateResult.CertificateCount)" -ForegroundColor Gray
    Write-Host "   Last updated: $($currentTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
    
    Write-Log "Certificate data update completed successfully. Found $($updateResult.CertificateCount) certificates" -LogFile $Global:sLogFile
}
catch {
    $errorMessage = "Update failed: $($_.Exception.Message)"
    Write-Host "[ERROR] $errorMessage" -ForegroundColor Red
    Write-Log $errorMessage -Level ERROR -LogFile $Global:sLogFile
    exit 1
}

# --- End of Script --- old: v1.0.0 ; now: v1.0.0 ; Regelwerk: v9.3.0 ---