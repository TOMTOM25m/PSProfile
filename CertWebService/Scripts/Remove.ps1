#Requires -version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Certificate Web Service - Complete Removal

.DESCRIPTION
    Cleanly removes the certificate web service, IIS site, and all components.
    Provides safe uninstallation with optional data preservation.
    Compatible with PowerShell 5.1 and 7.x according to MUW-Regelwerk v9.6.2.

.PARAMETER KeepData
    Preserves log files and configuration data
    
.PARAMETER KeepCertificates
    Keeps SSL certificates in certificate store
    
.PARAMETER Force
    Forces removal without confirmation prompts

.NOTES
    Author:         Flecki (Tom) Garnreiter
    Version:        v2.2.0
    Regelwerk:      v9.6.2
    
.EXAMPLE
    .\Remove.ps1
    Standard removal with confirmation prompts
    
.EXAMPLE
    .\Remove.ps1 -KeepData -Force
    Forced removal while preserving data
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$KeepData,
    [switch]$KeepCertificates,
    [switch]$Force
)

#region Initialization
. (Join-Path (Split-Path -Path $MyInvocation.MyCommand.Path) "VERSION.ps1")
Show-ScriptInfo -ScriptName "Certificate Web Service Removal" -CurrentVersion $ScriptVersion

$Global:ScriptDirectory = $PSScriptRoot
$Global:LogFile = Join-Path $Global:ScriptDirectory "LOG\Remove_$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

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
    Write-Warning "Some modules could not be imported. Continuing with basic functionality."
}

# Load configuration (if available)
try {
    $Config = Get-WebServiceConfiguration -ConfigPath (Join-Path $Global:ScriptDirectory "Config\Settings.json")
} catch {
    Write-Warning "Configuration file not found. Using default values."
    $Config = @{
        SiteName = "CertificateWebService"
        WebService = @{
            HttpPort = 8080
            HttpsPort = 8443
        }
    }
}
#endregion

#region Main Functions
function Remove-IISWebSite {
    param([string]$SiteName)
    
    Write-Log "Removing IIS website: $SiteName"
    
    if ($PSCmdlet.ShouldProcess($SiteName, "Remove IIS Website")) {
        try {
            # Import WebAdministration module
            Import-Module WebAdministration -Force -ErrorAction SilentlyContinue
            
            # Stop and remove website
            $site = Get-Website -Name $SiteName -ErrorAction SilentlyContinue
            if ($site) {
                Stop-Website -Name $SiteName -ErrorAction SilentlyContinue
                Remove-Website -Name $SiteName -ErrorAction SilentlyContinue
                Write-Log "IIS website '$SiteName' removed successfully"
            } else {
                Write-Log "IIS website '$SiteName' not found" -Level WARNING
            }
        } catch {
            Write-Log "Error removing IIS website: $($_.Exception.Message)" -Level ERROR
        }
    }
}

function Remove-SSLCertificates {
    param([string]$CommonName = $env:COMPUTERNAME)
    
    if ($KeepCertificates) {
        Write-Log "Keeping SSL certificates as requested"
        return
    }
    
    Write-Log "Removing SSL certificates for $CommonName..."
    
    if ($PSCmdlet.ShouldProcess($CommonName, "Remove SSL Certificates")) {
        try {
            # Remove from personal store
            Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { 
                $_.Subject -eq "CN=$CommonName" -and $_.Issuer -eq "CN=$CommonName" 
            } | ForEach-Object {
                Write-Log "Removing certificate: $($_.Thumbprint)"
                Remove-Item $_.PSPath -Force
            }
            
            # Remove from trusted root store
            Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object { 
                $_.Subject -eq "CN=$CommonName" -and $_.Issuer -eq "CN=$CommonName" 
            } | ForEach-Object {
                Write-Log "Removing trusted root certificate: $($_.Thumbprint)"
                Remove-Item $_.PSPath -Force
            }
            
            Write-Log "SSL certificates removed successfully"
        } catch {
            Write-Log "Error removing SSL certificates: $($_.Exception.Message)" -Level WARNING
        }
    }
}

function Remove-FirewallRules {
    Write-Log "Removing firewall rules..."
    
    if ($PSCmdlet.ShouldProcess("Firewall Rules", "Remove")) {
        try {
            $rules = @("CertWebService HTTP", "CertWebService HTTPS")
            
            foreach ($ruleName in $rules) {
                $rule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
                if ($rule) {
                    Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
                    Write-Log "Removed firewall rule: $ruleName"
                }
            }
        } catch {
            Write-Log "Error removing firewall rules: $($_.Exception.Message)" -Level WARNING
        }
    }
}

function Remove-WebFiles {
    Write-Log "Removing web files..."
    
    if ($PSCmdlet.ShouldProcess("Web Files", "Remove")) {
        $webPath = Join-Path $env:inetpub "wwwroot\CertWebService"
        
        if (Test-Path $webPath) {
            try {
                Remove-Item -Path $webPath -Recurse -Force
                Write-Log "Web files removed from: $webPath"
            } catch {
                Write-Log "Error removing web files: $($_.Exception.Message)" -Level WARNING
            }
        } else {
            Write-Log "Web files directory not found: $webPath"
        }
    }
}

function Remove-ScheduledTasks {
    Write-Log "Removing scheduled tasks..."
    
    if ($PSCmdlet.ShouldProcess("Scheduled Tasks", "Remove")) {
        $taskNames = @("CertWebService-Update", "CertWebService-DailyUpdate", "Certificate Web Service Update")
        
        foreach ($taskName in $taskNames) {
            try {
                $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
                if ($task) {
                    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
                    Write-Log "Removed scheduled task: $taskName"
                }
            } catch {
                Write-Log "Error removing scheduled task '$taskName': $($_.Exception.Message)" -Level WARNING
            }
        }
    }
}

function Remove-LogData {
    if ($KeepData) {
        Write-Log "Keeping log data as requested"
        return
    }
    
    Write-Log "Removing log data..."
    
    if ($PSCmdlet.ShouldProcess("Log Data", "Remove")) {
        $logPath = Join-Path $Global:ScriptDirectory "LOG"
        
        if (Test-Path $logPath) {
            try {
                # Keep the current removal log
                $currentLog = Split-Path $Global:LogFile -Leaf
                Get-ChildItem -Path $logPath | Where-Object { 
                    $_.Name -ne $currentLog 
                } | Remove-Item -Force -Recurse
                
                Write-Log "Log data removed (current log preserved)"
            } catch {
                Write-Log "Error removing log data: $($_.Exception.Message)" -Level WARNING
            }
        }
    }
}

function Show-RemovalSummary {
    param([hashtable]$Results)
    
    Write-Host "`n=== Certificate Web Service Removal Summary ===" -ForegroundColor Yellow
    
    foreach ($component in $Results.Keys) {
        $status = if ($Results[$component]) { "✅ Removed" } else { "⚠️  Warning" }
        $color = if ($Results[$component]) { "Green" } else { "Yellow" }
        Write-Host "$status $component" -ForegroundColor $color
    }
    
    Write-Host "`n📋 Removal completed on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
    
    if ($KeepData) {
        Write-Host "💾 Data preservation: Log files and configuration kept" -ForegroundColor Blue
    }
    
    if ($KeepCertificates) {
        Write-Host "🔒 Certificate preservation: SSL certificates kept in store" -ForegroundColor Blue
    }
}
#endregion

#region Main Execution
try {
    Write-Log "=== Certificate Web Service Removal Started ==="
    
    # Confirmation prompt (unless forced)
    if (-not $Force) {
        $siteName = $Config.SiteName
        Write-Host "⚠️  You are about to remove the Certificate Web Service:" -ForegroundColor Yellow
        Write-Host "   - IIS Website: $siteName" -ForegroundColor White
        Write-Host "   - SSL Certificates: $(if ($KeepCertificates) { 'KEEP' } else { 'REMOVE' })" -ForegroundColor White
        Write-Host "   - Log Data: $(if ($KeepData) { 'KEEP' } else { 'REMOVE' })" -ForegroundColor White
        Write-Host "   - Firewall Rules: REMOVE" -ForegroundColor White
        Write-Host "   - Web Files: REMOVE" -ForegroundColor White
        
        $confirmation = Read-Host "`nContinue with removal? (y/N)"
        if ($confirmation -notmatch '^[Yy]') {
            Write-Host "Removal cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    }
    
    # Track removal results
    $results = @{}
    
    # Step 1: Remove IIS website
    try {
        Remove-IISWebSite -SiteName $Config.SiteName
        $results["IIS Website"] = $true
    } catch {
        $results["IIS Website"] = $false
        Write-Log "Failed to remove IIS website: $_" -Level ERROR
    }
    
    # Step 2: Remove SSL certificates
    try {
        Remove-SSLCertificates
        $results["SSL Certificates"] = $true
    } catch {
        $results["SSL Certificates"] = $false
        Write-Log "Failed to remove SSL certificates: $_" -Level ERROR
    }
    
    # Step 3: Remove firewall rules
    try {
        Remove-FirewallRules
        $results["Firewall Rules"] = $true
    } catch {
        $results["Firewall Rules"] = $false
        Write-Log "Failed to remove firewall rules: $_" -Level ERROR
    }
    
    # Step 4: Remove web files
    try {
        Remove-WebFiles
        $results["Web Files"] = $true
    } catch {
        $results["Web Files"] = $false
        Write-Log "Failed to remove web files: $_" -Level ERROR
    }
    
    # Step 5: Remove scheduled tasks
    try {
        Remove-ScheduledTasks
        $results["Scheduled Tasks"] = $true
    } catch {
        $results["Scheduled Tasks"] = $false
        Write-Log "Failed to remove scheduled tasks: $_" -Level ERROR
    }
    
    # Step 6: Clean up log data
    try {
        Remove-LogData
        $results["Log Data"] = $true
    } catch {
        $results["Log Data"] = $false
        Write-Log "Failed to remove log data: $_" -Level ERROR
    }
    
    Write-Log "=== Removal completed ==="
    
    # Show summary
    Show-RemovalSummary -Results $results
    
    # Send final status notification
    try {
        Set-CertWebServiceStatus -Status "REMOVED" -Details @{
            RemovedComponents = $results
            DataPreserved = $KeepData
            CertificatesPreserved = $KeepCertificates
            RemovalTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        }
    } catch {
        # Ignore notification errors during removal
    }
    
} catch {
    Write-Log "Removal failed: $($_.Exception.Message)" -Level ERROR
    Write-Error "Removal failed: $_"
    exit 1
}
#endregion