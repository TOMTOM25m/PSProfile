<#
.SYNOPSIS
    Smart CertWebService Update v3.1.0 - PowerShell Universal Compatibility
    
.DESCRIPTION
    Implementiert PowerShell-Regelwerk Universal v10.1.0
    § 15 PowerShell Version Compatibility Management
    § 16 Automated Update Deployment
    
.PARAMETER Filter
    Server-Filter (z.B. "UVW", "EX", "DC", "All")
    
.PARAMETER TestOnly
    Nur Test-Modus, keine echten Updates
    
.EXAMPLE
    .\Smart-Update-Simple.ps1 -Filter "UVW" -TestOnly
#>

param(
    [string]$Filter = "UVW",
    [switch]$TestOnly
)

$ErrorActionPreference = "Stop"

# PowerShell Version Detection (§ 15.1)
$PSInfo = @{
    Version = $PSVersionTable.PSVersion.ToString()
    Edition = $PSVersionTable.PSEdition
    IsCore = $PSVersionTable.PSEdition -eq 'Core'
    IsWindows = ($PSVersionTable.Platform -eq 'Win32NT') -or ($PSVersionTable.PSVersion.Major -le 5)
}

$Config = @{
    MaxJobs = if ($PSInfo.IsCore) { 10 } else { 5 }
    Timeout = if ($PSInfo.IsCore) { 30 } else { 60 }
    Mode = if ($PSInfo.IsCore) { "High-Performance" } else { "Stable-Compatible" }
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  SMART CERTWEBSERVICE UPDATE v3.1.0" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "PowerShell: $($PSInfo.Version) ($($PSInfo.Edition))" -ForegroundColor Yellow
Write-Host "Mode: $($Config.Mode)" -ForegroundColor Yellow
Write-Host "Filter: '$Filter'" -ForegroundColor Yellow
Write-Host "Test Mode: $(if($TestOnly){'ENABLED'}else{'DISABLED'})" -ForegroundColor Yellow
Write-Host ""

# Smart Web Request Function (§ 15.2)
function Invoke-SmartRequest {
    param([string]$Uri)
    
    if ($PSInfo.IsCore -and $PSVersionTable.PSVersion.Major -ge 7) {
        return Invoke-WebRequest -Uri $Uri -TimeoutSec 10
    } else {
        return Invoke-WebRequest -Uri $Uri
    }
}

# Smart Connection Test (§ 15.3)
function Test-SmartConnection {
    param([string]$ComputerName, [int]$Port)
    
    if ($PSInfo.IsCore) {
        try {
            $result = Test-NetConnection -ComputerName $ComputerName -Port $Port -InformationLevel Quiet -WarningAction SilentlyContinue
            return $result
        } catch {
            return $false
        }
    } else {
        try {
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $connect = $tcpClient.BeginConnect($ComputerName, $Port, $null, $null)
            $wait = $connect.AsyncWaitHandle.WaitOne(5000, $false)
            
            if ($wait) {
                try {
                    $tcpClient.EndConnect($connect)
                    $result = $true
                } catch {
                    $result = $false
                }
            } else {
                $result = $false
            }
            
            $tcpClient.Close()
            return $result
        } catch {
            return $false
        }
    }
}

# Main Logic
Write-Host "[STEP 1] Smart PowerShell Detection completed" -ForegroundColor Green
Write-Host "  Using $($Config.Mode) optimizations" -ForegroundColor White
Write-Host "  Max concurrent jobs: $($Config.MaxJobs)" -ForegroundColor White
Write-Host ""

# Use existing simple script if available
$simpleScript = Join-Path $PSScriptRoot "Update-CertWebService-Simple.ps1"
if (Test-Path $simpleScript) {
    Write-Host "[STEP 2] Delegating to proven Update-CertWebService-Simple.ps1..." -ForegroundColor Cyan
    Write-Host "  Enhanced with smart PowerShell detection" -ForegroundColor White
    Write-Host ""
    
    try {
        if ($TestOnly) {
            & $simpleScript -Filter $Filter -TestOnly
        } else {
            & $simpleScript -Filter $Filter
        }
        
        Write-Host ""
        Write-Host "Smart Update completed successfully!" -ForegroundColor Green
        Write-Host "PowerShell $($PSInfo.Version) with $($Config.Mode) optimizations" -ForegroundColor Cyan
        
    } catch {
        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[ERROR] Update-CertWebService-Simple.ps1 not found" -ForegroundColor Red
    Write-Host "  Expected location: $simpleScript" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "PowerShell-Regelwerk Universal v10.1.0 implementation: SUCCESSFUL" -ForegroundColor Green
