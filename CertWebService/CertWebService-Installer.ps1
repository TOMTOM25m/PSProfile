# CertWebService PowerShell Installer (Enhanced)
# Regelwerk v10.0.0 compliant wrapper around simplified setup script
param(
    [int]$Port = 9080,
    [int]$SecurePort = 9443,
    [string[]]$AuthorizedHosts = @(
        'localhost',
        '127.0.0.1',
        '::1',
        $env:COMPUTERNAME,
        "$env:COMPUTERNAME.srv.meduniwien.ac.at",
        'ITSCMGMT03.srv.meduniwien.ac.at',
        'ITSC020.cc.meduniwien.ac.at',
        'itsc049.uvw.meduniwien.ac.at'
    ),
    [switch]$SkipIISFeatures,
    [switch]$NoPause,
    [switch]$Json,
    [switch]$VerboseLogging
)

$ErrorActionPreference = 'Stop'

#region Helper / Logging
$global:__log = @()
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR','SUCCESS','DETAIL')][string]$Level = 'INFO',
        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = [PSCustomObject]@{ Timestamp=$ts; Level=$Level; Message=$Message }
    $global:__log += $entry
    if (-not $Json) {
        switch ($Level) {
            'ERROR'   { $Color = 'Red' }
            'WARN'    { $Color = 'Yellow' }
            'SUCCESS' { $Color = 'Green' }
            'INFO'    { if ($Color -eq 'Gray') { $Color = 'Gray' } }
            'DETAIL'  { $Color = 'DarkGray' }
        }
        Write-Host "[$($entry.Timestamp)] [$Level] $Message" -ForegroundColor $Color
    }
}

function Out-JsonIfRequested {
    param(
        [int]$ExitCode,
        [string]$Status,
        [hashtable]$Extra
    )
    if ($Json) {
        $payload = [ordered]@{
            Script        = 'CertWebService-Installer.ps1'
            Version       = $ScriptVersion
            Regelwerk     = $RegelwerkVersion
            BuildDate     = $BuildDate
            PowerShell    = $PSVersionTable.PSVersion.ToString()
            Edition       = $PSVersionTable.PSEdition
            Status        = $Status
            ExitCode      = $ExitCode
            Port          = $Port
            SecurePort    = $SecurePort
            AuthorizedHosts = $AuthorizedHosts
            Steps         = $global:__log
        }
        if ($Extra) { $Extra.GetEnumerator() | ForEach-Object { $payload[$_.Key] = $_.Value } }
        $payload | ConvertTo-Json -Depth 6
    }
}
#endregion

#region Version Import
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$VersionFile = Join-Path $ScriptDir 'VERSION.ps1'
if (Test-Path $VersionFile) {
    try { . $VersionFile } catch { Write-Log "Failed to import VERSION.ps1: $($_.Exception.Message)" 'WARN' }
}
if (-not $ScriptVersion) { $ScriptVersion = 'v2.3.0' }
if (-not $RegelwerkVersion) { $RegelwerkVersion = 'v10.0.0' }
if (-not $BuildDate) { $BuildDate = (Get-Date -Format 'yyyy-MM-dd') }
#endregion

#region Banner
if (-not $Json) {
    $line = '=' * 46
    Write-Host $line -ForegroundColor Cyan
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        Write-Host "🚀 CertWebService $ScriptVersion Installer" -ForegroundColor Green
    } else {
        Write-Host "CertWebService $ScriptVersion Installer" -ForegroundColor Green
    }
    Write-Host "Regelwerk: $RegelwerkVersion | Build: $BuildDate" -ForegroundColor Cyan
    Write-Host "Authorized Hosts (default): $((($AuthorizedHosts) -join ', '))" -ForegroundColor Yellow
    Write-Host "PowerShell: $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))" -ForegroundColor Gray
    Write-Host $line -ForegroundColor Cyan
    Write-Host
}
#endregion

#region Pre-Checks
Write-Log 'Running pre-checks' 'INFO'
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')
if (-not $isAdmin) {
    Write-Log 'Must be run as Administrator' 'ERROR'
    $__json = Out-JsonIfRequested -ExitCode 1 -Status 'NOT_ADMIN'
    if ($__json) { Write-Output $__json }
    if (-not $Json -and -not $NoPause) { Write-Host 'Press any key to exit...' -ForegroundColor DarkGray; $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') | Out-Null }
    exit 1
}
Write-Log 'Administrator privileges confirmed' 'SUCCESS'

foreach ($p in @($Port,$SecurePort)) {
    if ($p -lt 1 -or $p -gt 65535) { Write-Log "Invalid port: $p" 'ERROR'; $__json = Out-JsonIfRequested -ExitCode 1 -Status 'INVALID_PORT'; if ($__json) { Write-Output $__json }; exit 1 }
}

function Test-PortInUse {
    param([int]$TestPort)
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $iar = $client.BeginConnect('127.0.0.1',$TestPort,$null,$null)
        $wait = $iar.AsyncWaitHandle.WaitOne(200)
        if ($wait -and $client.Connected) { $client.Close(); return $true }
        $client.Close(); return $false
    } catch { return $false }
}

if (Test-PortInUse -TestPort $Port)       { Write-Log "Port $Port already in use (HTTP)" 'WARN' }
if (Test-PortInUse -TestPort $SecurePort) { Write-Log "Port $SecurePort already in use (HTTPS)" 'WARN' }

#endregion

#region Locate Setup Script
$PreferredOrder = @('Setup-Simple.ps1','Setup-Final.ps1','Setup.ps1')
$SetupScript = $null
foreach ($candidate in $PreferredOrder) {
    $candidatePath = Join-Path $ScriptDir $candidate
    if (Test-Path $candidatePath) { $SetupScript = $candidatePath; break }
}
if (-not $SetupScript) {
    Write-Log 'No setup script found (expected one of Setup-Simple.ps1, Setup-Final.ps1, Setup.ps1)' 'ERROR'
    $__json = Out-JsonIfRequested -ExitCode 1 -Status 'NO_SETUP_SCRIPT'
    if ($__json) { Write-Output $__json }
    exit 1
}
Write-Log "Using setup script: $SetupScript" 'INFO'
#endregion

#region IIS Feature Handling
if ($SkipIISFeatures) {
    Write-Log 'Skipping IIS feature installation as requested' 'WARN'
} else {
    Write-Log 'Ensuring IIS feature baseline (lightweight check)' 'INFO'
    try {
        $featureCmd = Get-Command Enable-WindowsOptionalFeature -ErrorAction SilentlyContinue
        if ($featureCmd) {
            $baseline = @('IIS-WebServerRole','IIS-WebServer')
            foreach ($f in $baseline) {
                try { Enable-WindowsOptionalFeature -Online -FeatureName $f -All -NoRestart -ErrorAction SilentlyContinue | Out-Null } catch { Write-Log "Feature $f enable attempt failed (may be present)" 'DETAIL' }
            }
        } else {
            Write-Log 'Enable-WindowsOptionalFeature not available (non-Windows Core?) - continuing' 'WARN'
        }
    } catch { Write-Log "IIS baseline check failed: $($_.Exception.Message)" 'WARN' }
}
#endregion

#region Execute Setup
Write-Log 'Starting underlying setup script execution' 'INFO'
$invokeParams = @{
    Port = $Port
    SecurePort = $SecurePort
    AuthorizedHosts = $AuthorizedHosts
}
if ($VerboseLogging) { $invokeParams['Verbose'] = $true }

$setupExitCode = 0
try {
    & $SetupScript @invokeParams
    $setupExitCode = if ($LASTEXITCODE) { $LASTEXITCODE } else { 0 }
    if ($setupExitCode -eq 0) {
        Write-Log 'Underlying setup reported success' 'SUCCESS'
    } else {
        Write-Log "Underlying setup returned exit code $setupExitCode" 'ERROR'
    }
} catch {
    Write-Log "Setup script threw exception: $($_.Exception.Message)" 'ERROR'
    $setupExitCode = 1
}
#endregion

#region Post Summary
if ($setupExitCode -eq 0) {
    Write-Log "Service (HTTP) Port: $Port" 'INFO'
    Write-Log "Health Endpoint (relative): /health.json" 'INFO'
    Write-Log "Certificates Endpoint (relative): /certificates.json" 'INFO'
    Write-Log "Authorized Hosts: $((($AuthorizedHosts) -join ', '))" 'INFO'
    Write-Log 'Installation completed successfully' 'SUCCESS'
    $status = 'SUCCESS'
} else {
    Write-Log 'Installation failed - review log output' 'ERROR'
    $status = 'FAILED'
}

$__json = Out-JsonIfRequested -ExitCode $setupExitCode -Status $status
if ($__json) { Write-Output $__json }

if (-not $Json -and -not $NoPause) {
    Write-Host
    Write-Host 'Press any key to exit...' -ForegroundColor DarkGray
    try { $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') | Out-Null } catch { }
}

exit $setupExitCode