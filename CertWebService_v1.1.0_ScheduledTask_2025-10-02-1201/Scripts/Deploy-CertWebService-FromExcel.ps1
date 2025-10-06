<#
.SYNOPSIS
    Smart Loader - Mass Deploy CertWebService from Excel server list
.DESCRIPTION
    Detects PowerShell version and loads the appropriate implementation.
    - PowerShell 5.1: Deploy-FromExcel-PS5.ps1 (ASCII, compatible)
    - PowerShell 7.x:  Deploy-FromExcel-PS7.ps1 (UTF-8, enhanced visuals)
.PARAMETER ExcelPath
    Path to Excel file with server list (default: \\itscmgmt03\iso\WIndowsServerListe\Serverliste2025.xlsx)
.PARAMETER DryRun
    Preview deployment without executing
.PARAMETER ServerFilter
    Filter servers by name pattern
.EXAMPLE
    .\Deploy-CertWebService-FromExcel.ps1
    .\Deploy-CertWebService-FromExcel.ps1 -DryRun
    .\Deploy-CertWebService-FromExcel.ps1 -ServerFilter "wsus*"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ExcelPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\WIndowsServerListe\Serverliste2025.xlsx",
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory=$false)]
    [string]$ServerFilter = "*"
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if ($PSVersionTable.PSVersion.Major -ge 7) {
    $TargetScript = Join-Path $ScriptDir "Deploy-FromExcel-PS7.ps1"
} else {
    $TargetScript = Join-Path $ScriptDir "Deploy-FromExcel-PS5.ps1"
}

if (-not (Test-Path $TargetScript)) {
    throw "Implementation script not found: $TargetScript"
}

& $TargetScript -ExcelPath $ExcelPath -DryRun:$DryRun -ServerFilter $ServerFilter
