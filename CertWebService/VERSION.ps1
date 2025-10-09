#region Version Information (MANDATORY - Regelwerk v10.1.0)
$ScriptVersion = "v2.4.0"  # Updated for v10.1.0 compliance
$RegelwerkVersion = "v10.1.0"
$BuildDate = "2025-10-09""
$Author = "Flecki (Tom) Garnreiter"

<#
.VERSION HISTORY (MANDATORY)
v2.4.0 - 2025-10-02 - Updated to Regelwerk v10.1.0 compliance, PowerShell-optimized JSON, ASCII-safe encoding.
v2.3.0 - 2025-09-30 - Updated to Regelwerk v10.1.0 compliance.
v2.2.0 - 2025-09-29 - Updated to Regelwerk v9.6.2 compliance, PowerShell 5.1/7.x compatibility
v2.1.0 - 2025-09-27 - Updated to Regelwerk v9.6.0 compliance, added cross-script communication
v2.0.0 - Previous - Certificate Web Service deployment features
v1.x.x - Previous versions - Basic web service functionality
#>
#endregion

#region Script Information Display (MANDATORY - Regelwerk v10.1.0)
function Show-ScriptInfo {
    param(
        [string]$ScriptName = "Certificate Web Service System",
        [string]$CurrentVersion = $ScriptVersion
    )
    
    # PowerShell 5.1/7.x compatibility (Regelwerk v10.1.0 §19.3 - ASCII-safe output)
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        Write-Host "[ENHANCED] $ScriptName v$CurrentVersion" -ForegroundColor Green
        Write-Host "[BUILD] $BuildDate | Regelwerk: $RegelwerkVersion" -ForegroundColor Cyan
    } else {
        Write-Host "[STANDARD] $ScriptName v$CurrentVersion" -ForegroundColor Green
        Write-Host "[BUILD] $BuildDate | Regelwerk: $RegelwerkVersion" -ForegroundColor Cyan
    }
}
#endregion

#region Cross-Script Communication (MANDATORY - Regelwerk v10.1.0)
function Send-CertWebServiceMessage {
    param(
        [string]$TargetScript,
        [string]$Message,
        [string]$Type = "INFO"
    )
    
    $MessageDir = "LOG\Messages"
    if (-not (Test-Path $MessageDir)) {
        New-Item -Path $MessageDir -ItemType Directory -Force | Out-Null
    }
    
    $MessageFile = "$MessageDir\$TargetScript-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $MessageData = @{
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Source = $MyInvocation.ScriptName
        Target = $TargetScript
        Message = $Message
        Type = $Type
        RegelwerkVersion = $RegelwerkVersion
        ServiceContext = "CertWebService"
    }
    
    $MessageData | ConvertTo-Json | Out-File $MessageFile -Encoding UTF8
    Write-Verbose "Message sent to ${TargetScript}: $Message"
}

function Set-CertWebServiceStatus {
    param(
        [string]$Status,
        [hashtable]$Details = @{}
    )
    
    $StatusDir = "LOG\Status"
    if (-not (Test-Path $StatusDir)) {
        New-Item -Path $StatusDir -ItemType Directory -Force | Out-Null
    }
    
    $StatusFile = "$StatusDir\CertWebService-Status.json"
    $StatusData = @{
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Script = $MyInvocation.ScriptName
        Status = $Status
        Details = $Details
        RegelwerkVersion = $RegelwerkVersion
        Version = $ScriptVersion
        ServiceContext = "CertWebService"
    }
    
    $StatusData | ConvertTo-Json | Out-File $StatusFile -Encoding UTF8
    Write-Verbose "Status updated: $Status"
}

function Send-WebServiceNotification {
    param(
        [string]$ServiceStatus,
        [string]$IISStatus,
        [string]$CertificateCount
    )
    
    $NotificationMessage = "CertWebService Status: $ServiceStatus | IIS: $IISStatus | Certificates: $CertificateCount"
    Send-CertWebServiceMessage -TargetScript "CertSurv-System" -Message $NotificationMessage -Type "SERVICE_STATUS"
    Send-CertWebServiceMessage -TargetScript "Monitoring-System" -Message "WebService health check completed" -Type "HEALTH_CHECK"
}
#endregion

Write-Verbose "VERSION.ps1 loaded - Certificate Web Service System v$ScriptVersion (Regelwerk $RegelwerkVersion)"
