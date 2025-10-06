param(
    [string]$Mode = "Server",
    [switch]$ShowScripts
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PowerShellVersionsDir = Join-Path $ScriptDir "PowerShell-Versions"

Write-Host "CERTWEBSERVICE DEPLOYMENT LAUNCHER" -ForegroundColor Cyan

if ($ShowScripts) {
    Write-Host "Available Scripts:" -ForegroundColor Yellow
    if (Test-Path $PowerShellVersionsDir) {
        Get-ChildItem $PowerShellVersionsDir -Filter "*.ps1" | ForEach-Object {
            Write-Host "  $($_.Name)" -ForegroundColor Cyan
        }
    }
    exit 0
}

$psVersion = $PSVersionTable.PSVersion.Major
Write-Host "PowerShell Version: $psVersion" -ForegroundColor White

switch ($Mode) {
    "Server" {
        if ($psVersion -ge 7) {
            $script = Join-Path $PowerShellVersionsDir "Deploy-CertWebService-PS7.ps1"
        } else {
            $script = Join-Path $PowerShellVersionsDir "Deploy-CertWebService-PS5.ps1"
        }
    }
    "Excel" {
        if ($psVersion -ge 7) {
            $script = Join-Path $PowerShellVersionsDir "Deploy-FromExcel-PS7.ps1"
        } else {
            $script = Join-Path $PowerShellVersionsDir "Deploy-FromExcel-PS5.ps1"
        }
    }
}

Write-Host "Launching: $script" -ForegroundColor Green
& $script @args
