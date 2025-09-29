#region Version Information (MANDATORY - Regelwerk v9.6.2)
$ScriptVersion = "v2.2.0"   # Modernized from legacy FolderPermissionReport v2.1.0.0
$RegelwerkVersion = "v9.6.2"
$BuildDate = (Get-Date -Format 'yyyy-MM-dd')
$Author = "Flecki (Tom) Garnreiter"
$RepositoryName = "DirectoryPermissionAudit"

<#!
.VERSION HISTORY
v2.2.0 - $BuildDate - Migrated legacy FolderPermissionReport (v2.1.0.0) to Universal Regelwerk v9.6.2 structure, added parameterized execution & multi-format export (Human/CSV/JSON)
v2.1.0.0 - 2023-03-08 - Legacy signed release (manual logging, interactive only)
#>
#endregion

#region Script Information Display (MANDATORY - Regelwerk v9.6.2)
function Show-ScriptInfo {
    param(
        [string]$ScriptName = "Directory Permission Audit System",
        [string]$CurrentVersion = $ScriptVersion,
        [string]$Context = "Audit"
    )

    $server = $env:COMPUTERNAME
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        Write-Host "🗂️  $ScriptName $CurrentVersion" -ForegroundColor Green
        Write-Host "📅 Build: $BuildDate | Regelwerk: $RegelwerkVersion" -ForegroundColor Cyan
        Write-Host "👤 Author: $Author" -ForegroundColor Cyan
        Write-Host "💻 Host: $server | PS: $($PSVersionTable.PSVersion.ToString())" -ForegroundColor Yellow
        Write-Host "📂 Repository: $RepositoryName | Context: $Context" -ForegroundColor Magenta
    } else {
        Write-Host ">> $ScriptName $CurrentVersion" -ForegroundColor Green
        Write-Host "[BUILD] $BuildDate | Regelwerk: $RegelwerkVersion" -ForegroundColor Cyan
        Write-Host "[AUTHOR] $Author" -ForegroundColor Cyan
        Write-Host "[HOST] $server | PS: $($PSVersionTable.PSVersion.ToString())" -ForegroundColor Yellow
        Write-Host "[REPO] $RepositoryName | Context: $Context" -ForegroundColor Magenta
    }
}
#endregion

#region Cross-Script Communication (OPTIONAL - Lightweight)
function Send-DirectoryPermissionAuditMessage {
    param(
        [string]$TargetScript,
        [string]$Message,
        [ValidateSet('INFO','WARNING','ERROR','STATUS')] [string]$Type = 'INFO'
    )
    try {
        $MessageDir = Join-Path -Path $PSScriptRoot -ChildPath 'LOG/Messages'
        if (-not (Test-Path $MessageDir)) { New-Item -ItemType Directory -Path $MessageDir -Force | Out-Null }
        $MessageFile = Join-Path $MessageDir ("${TargetScript}-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json')
        $payload = [ordered]@{
            Timestamp        = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            SourceScript     = $MyInvocation.ScriptName
            TargetScript     = $TargetScript
            Message          = $Message
            Type             = $Type
            RegelwerkVersion = $RegelwerkVersion
            Version          = $ScriptVersion
            Repository       = $RepositoryName
        }
        $payload | ConvertTo-Json | Out-File -FilePath $MessageFile -Encoding UTF8
    } catch {
        Write-Warning "Failed to send message: $($_.Exception.Message)"
    }
}
#endregion

Write-Verbose "VERSION.ps1 loaded - $RepositoryName $ScriptVersion (Regelwerk $RegelwerkVersion)"