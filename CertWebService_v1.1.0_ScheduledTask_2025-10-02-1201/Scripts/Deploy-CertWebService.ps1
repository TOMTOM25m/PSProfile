#requires -Version 5.1
<#
.SYNOPSIS
    Smart Loader f?r CertWebService Deployment
.DESCRIPTION
    Erkennt PowerShell-Version und l?dt passendes Deployment-Script
.VERSION
    3.0.0
#>
[CmdletBinding()]
param(
    [string[]]$Servers = @("itscmgmt03.srv.meduniwien.ac.at", "wsus.srv.meduniwien.ac.at"),
    [switch]$DeployToNetworkShare,
    [switch]$RunInitialScan,
    [switch]$SkipBackup,
    [PSCredential]$Credential
)

$PSVer = $PSVersionTable.PSVersion
$IsPS7 = $PSVer.Major -ge 7
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

if ($IsPS7) {
    $target = Join-Path $scriptDir "Deploy-CertWebService-PS7.ps1"
    $mode = "PS7"
} else {
    $target = Join-Path $scriptDir "Deploy-CertWebService-PS5.ps1"
    $mode = "PS5"
}

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  CertWebService Smart Deployment Loader v3.0.0" -ForegroundColor Green
Write-Host "  PowerShell: $($PSVer.ToString()) | Mode: $mode" -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $target)) {
    Write-Host "ERROR: $target not found!" -ForegroundColor Red
    exit 1
}

& $target @PSBoundParameters
