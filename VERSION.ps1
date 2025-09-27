#region Version Information (MANDATORY - Regelwerk v9.6.0)
$ScriptVersion = "v11.2.3"  # Updated for v9.6.0 compliance
$RegelwerkVersion = "v9.6.0"
$BuildDate = "2025-09-27"
$Author = "Flecki (Tom) Garnreiter"

<#
.VERSION HISTORY
v11.2.3 - 2025-09-27 - Updated to Regelwerk v9.6.0 compliance, added cross-script communication
v11.2.2 - 2025-09-02 - Network Profiles feature added
v11.2.1 - Previous - Standard functionality
#>
#endregion

#region Script Information Display (MANDATORY - Regelwerk v9.6.0)
function Show-ScriptInfo {
    param(
        [string]$ScriptName = "ResetProfile System",
        [string]$CurrentVersion = $ScriptVersion
    )
    
    Write-Host "🚀 $ScriptName v$CurrentVersion" -ForegroundColor Green
    Write-Host "📅 Build: $BuildDate | Regelwerk: $RegelwerkVersion" -ForegroundColor Cyan
    Write-Host "👤 Author: $Author" -ForegroundColor Cyan
    Write-Host "💻 Server: $env:COMPUTERNAME" -ForegroundColor Yellow
    Write-Host "📂 Repository: ResetProfile" -ForegroundColor Magenta
}
#endregion

#region Cross-Script Communication (MANDATORY - Regelwerk v9.6.0)
function Send-ResetProfileMessage {
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
        Source = "Reset-PowerShellProfiles.ps1"
        Target = $TargetScript
        Message = $Message
        Type = $Type
        RegelwerkVersion = $RegelwerkVersion
    }
    
    $MessageData | ConvertTo-Json | Out-File $MessageFile -Encoding UTF8
    Write-Verbose "Message sent to $TargetScript: $Message"
}

function Set-ResetProfileStatus {
    param(
        [string]$Status,
        [hashtable]$Details = @{}
    )
    
    $StatusDir = "LOG\Status"
    if (-not (Test-Path $StatusDir)) {
        New-Item -Path $StatusDir -ItemType Directory -Force | Out-Null
    }
    
    $StatusFile = "$StatusDir\Reset-PowerShellProfiles-Status.json"
    $StatusData = @{
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Script = "Reset-PowerShellProfiles.ps1"
        Status = $Status
        Details = $Details
        RegelwerkVersion = $RegelwerkVersion
        Version = $ScriptVersion
    }
    
    $StatusData | ConvertTo-Json | Out-File $StatusFile -Encoding UTF8
    Write-Verbose "Status updated: $Status"
}
#endregion

# Export version information for other scripts
Export-ModuleMember -Variable ScriptVersion, RegelwerkVersion, BuildDate, Author -Function Show-ScriptInfo, Send-ResetProfileMessage, Set-ResetProfileStatus

Write-Verbose "VERSION.ps1 loaded - ResetProfile System v$ScriptVersion (Regelwerk $RegelwerkVersion)"