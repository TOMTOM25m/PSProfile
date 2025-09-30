# CertWebService v2.3.0 PowerShell Installer
# Supports UNC paths natively with PowerShell 7.x compatibility
param(
    [int]$Port = 9080
)

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "CertWebService v2.3.0 PowerShell Setup" -ForegroundColor Green
Write-Host "Read-Only Mode for 3 authorized servers" -ForegroundColor Yellow
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))" -ForegroundColor Gray
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Get the directory where this script is located (works with UNC paths)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$SetupScript = Join-Path $ScriptDir "Setup-Simple.ps1"

Write-Host "[INFO] Script directory: $ScriptDir" -ForegroundColor Gray
Write-Host "[INFO] Setup script: $SetupScript" -ForegroundColor Gray
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Host "[ERROR] This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "[ERROR] Please right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Administrator privileges confirmed" -ForegroundColor Green

# Check if Setup-Simple.ps1 exists
if (-not (Test-Path $SetupScript)) {
    Write-Host "[ERROR] Setup script not found: $SetupScript" -ForegroundColor Red
    Write-Host "[ERROR] Please ensure Setup-Simple.ps1 is in the same directory" -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Setup script found" -ForegroundColor Green
Write-Host "[INFO] Starting installation..." -ForegroundColor Green
Write-Host ""

try {
    # Execute the setup script with parameters
    & $SetupScript -Port $Port
    $exitCode = $LASTEXITCODE
    
    Write-Host ""
    if ($exitCode -eq 0) {
        Write-Host "=====================================" -ForegroundColor Green
        Write-Host "Installation completed successfully!" -ForegroundColor Green
        Write-Host "=====================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Service URL: http://localhost:$Port" -ForegroundColor Cyan
        Write-Host "API Endpoint: http://localhost:$Port/certificates.json" -ForegroundColor Cyan
        Write-Host "Health Check: http://localhost:$Port/health.json" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Read-Only Mode: Active for 3 servers" -ForegroundColor Yellow
        Write-Host "- ITSCMGMT03.srv.meduniwien.ac.at" -ForegroundColor Gray
        Write-Host "- ITSC020.cc.meduniwien.ac.at" -ForegroundColor Gray
        Write-Host "- itsc049.uvw.meduniwien.ac.at" -ForegroundColor Gray
        Write-Host ""
        Write-Host "[SUCCESS] CertWebService v2.3.0 installed successfully!" -ForegroundColor Green
    } else {
        Write-Host "=====================================" -ForegroundColor Red
        Write-Host "Installation failed!" -ForegroundColor Red
        Write-Host "=====================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please check the error messages above." -ForegroundColor Yellow
        Write-Host "Make sure you have:" -ForegroundColor Yellow
        Write-Host "- Administrator privileges" -ForegroundColor Gray
        Write-Host "- PowerShell 5.1 or later" -ForegroundColor Gray
        Write-Host "- IIS features available" -ForegroundColor Gray
        Write-Host ""
    }
    
} catch {
    Write-Host "[ERROR] Installation failed with exception: $($_.Exception.Message)" -ForegroundColor Red
    $exitCode = 1
}

Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
exit $exitCode