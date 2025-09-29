#region Version Information (MANDATORY - Regelwerk v9.6.2)
$ScriptVersion = "v6.0.0"  # Updated for v9.6.2 compliance and EVASYS
$RegelwerkVersion = "v9.6.2"
$BuildDate = "2025-09-29"
$Author = "Flecki (Tom) Garnreiter"

<#
.VERSION HISTORY
v2.2.0 - 2025-09-29 - Updated to Regelwerk v9.6.2 compliance, PowerShell 5.1/7.x compatibility
v2.1.0 - 2025-09-27 - Updated to Regelwerk v9.6.0 compliance, added cross-script communication
v2.0.0 - Previous - Certificate Web Service deployment features
v1.x.x - Previous versions - Basic web service functionality
#>
#endregion

#region Script Information Display (MANDATORY - Regelwerk v9.6.2)
function Show-ScriptInfo {
    param(
        [string]$ScriptName = "EvaSys Dynamic Update System",
        [string]$CurrentVersion = $ScriptVersion
    )
    
    # PowerShell 5.1/7.x Compatible Output (Regelwerk v9.6.2)
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        Write-Host "🚀 $ScriptName v$CurrentVersion" -ForegroundColor Green
        Write-Host "📅 Build: $BuildDate | Regelwerk: $RegelwerkVersion" -ForegroundColor Cyan
        Write-Host "👤 Author: $Author" -ForegroundColor Cyan
        Write-Host "💻 Server: $env:COMPUTERNAME" -ForegroundColor Yellow
        Write-Host "📂 Repository: EVASYS" -ForegroundColor Magenta
        Write-Host "� Service: EvaSys Update Automation" -ForegroundColor Blue
    } else {
        Write-Host ">> $ScriptName v$CurrentVersion" -ForegroundColor Green
        Write-Host "[BUILD] $BuildDate | Regelwerk: $RegelwerkVersion" -ForegroundColor Cyan
        Write-Host "[AUTHOR] $Author" -ForegroundColor Cyan
        Write-Host "[SERVER] $env:COMPUTERNAME" -ForegroundColor Yellow
        Write-Host "[REPO] EVASYS" -ForegroundColor Magenta
        Write-Host "[SERVICE] EvaSys Update Automation" -ForegroundColor Blue
    }
}
#endregion

#region Cross-Script Communication (MANDATORY - Regelwerk v9.6.2)
function Send-EvaSysMessage {
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