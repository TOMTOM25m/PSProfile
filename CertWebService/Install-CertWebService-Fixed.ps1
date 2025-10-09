#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
CertWebService v2.4.0 - UNC-Path-Fixed Installer
.DESCRIPTION
Verbesserte Installer-Version die UNC-Pfad-Probleme durch lokale Kopie l?st
Regelwerk v10.1.0 konform | Stand: 09.10.2025
.EXAMPLE
.\Install-CertWebService-Fixed.ps1
.EXAMPLE  
.\Install-CertWebService-Fixed.ps1 -Port 8080 -InstallPath "D:\CertWebService"
#>

param(
    [int]$Port = 9080,
    [string]$InstallPath = "C:\CertWebService",
    [switch]$Quiet
)

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
$ErrorActionPreference = "Stop"

# === INSTALLER HEADER ===
if (-not $Quiet) {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Certificate WebService v2.4.0 Installer" -ForegroundColor Green
    Write-Host "UNC-Path-Fixed Version" -ForegroundColor Yellow
    Write-Host "Regelwerk v10.1.0 | Stand: 09.10.2025" -ForegroundColor Gray
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

# === ADMINISTRATOR CHECK ===
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ERROR] Administrator privileges required!" -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator." -ForegroundColor Yellow
    if (-not $Quiet) { Read-Host "Press Enter to exit" }
    exit 1
}

Write-Host "[INFO] Administrator privileges confirmed" -ForegroundColor Green
Write-Host "[INFO] Starting installation..." -ForegroundColor Green
Write-Host ""

# === TEMPORARY DIRECTORY SETUP ===
$tempDir = "C:\Temp\CertWebService-Install"
$uncSource = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService"

Write-Host "[INFO] Creating temporary directory: $tempDir" -ForegroundColor Cyan
if (Test-Path $tempDir) {
    Remove-Item $tempDir -Recurse -Force
}
New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

# === COPY FROM UNC SHARE ===
Write-Host "[INFO] Copying files from network share..." -ForegroundColor Cyan
Write-Host "       Source: $uncSource" -ForegroundColor Gray
Write-Host "       Target: $tempDir" -ForegroundColor Gray

try {
    # Copy all files and folders
    $items = Get-ChildItem -Path $uncSource -Force
    foreach ($item in $items) {
        $destination = Join-Path $tempDir $item.Name
        if ($item.PSIsContainer) {
            Copy-Item $item.FullName $destination -Recurse -Force
        } else {
            Copy-Item $item.FullName $destination -Force
        }
        Write-Host "       Copied: $($item.Name)" -ForegroundColor Green
    }
    Write-Host "[INFO] Files copied successfully to temporary directory" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to copy files from network share!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    throw
}

Write-Host ""

# === CHANGE TO TEMP DIRECTORY ===
Set-Location $tempDir
Write-Host "[INFO] Changed to temporary directory: $tempDir" -ForegroundColor Cyan

# === RUN INSTALLATION ===
Write-Host "[INFO] Starting PowerShell installation..." -ForegroundColor Cyan
Write-Host "[INFO] Running Setup.ps1..." -ForegroundColor Cyan
Write-Host ""

try {
    # Execute the setup script from temp directory
    $setupScript = Join-Path $tempDir "Setup.ps1"
    if (Test-Path $setupScript) {
        & $setupScript -Port $Port -InstallPath $InstallPath -Quiet:$Quiet
        $setupExitCode = $LASTEXITCODE
    } else {
        Write-Host "[ERROR] Setup.ps1 not found in temporary directory!" -ForegroundColor Red
        throw "Setup script missing"
    }
    
    if ($setupExitCode -eq 0 -or $null -eq $setupExitCode) {
        Write-Host ""
        Write-Host "[SUCCESS] Certificate WebService installation completed!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Installation Details:" -ForegroundColor Cyan
        Write-Host "  - Service Port: $Port" -ForegroundColor White
        Write-Host "  - Installation Path: $InstallPath" -ForegroundColor White  
        Write-Host "  - Web Interface: http://localhost:$Port" -ForegroundColor White
        Write-Host "  - API Endpoint: http://localhost:$Port/api/certificates.json" -ForegroundColor White
        Write-Host ""
        
        # Test service
        Write-Host "[INFO] Testing service..." -ForegroundColor Cyan
        Start-Sleep 3
        try {
            $testResult = Test-NetConnection -ComputerName localhost -Port $Port -InformationLevel Quiet
            if ($testResult) {
                Write-Host "[SUCCESS]  Service is running on port $Port" -ForegroundColor Green
            } else {
                Write-Host "[WARNING]   Service may need a moment to start" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "[WARNING]   Service test inconclusive - check manually" -ForegroundColor Yellow
        }
    } else {
        Write-Host ""
        Write-Host "[ERROR] Certificate WebService installation failed!" -ForegroundColor Red
        Write-Host "Check the PowerShell output above for details." -ForegroundColor Yellow
    }
    
} catch {
    Write-Host ""
    Write-Host "[ERROR] Installation process failed!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

# === CLEANUP ===
Write-Host ""
Write-Host "[INFO] Cleaning up temporary files..." -ForegroundColor Cyan
Set-Location "C:\"
if (Test-Path $tempDir) {
    Remove-Item $tempDir -Recurse -Force
    Write-Host "[INFO] Temporary files removed" -ForegroundColor Green
}

Write-Host ""
Write-Host "Installation process completed." -ForegroundColor Cyan

if (-not $Quiet) {
    Write-Host ""
    Write-Host " Quick Start:" -ForegroundColor Green
    Write-Host "   Open browser: http://localhost:$Port" -ForegroundColor White
    Write-Host "   Check service: Get-Service CertWebService" -ForegroundColor White
    Write-Host "   View logs: Get-Content $InstallPath\Logs\*.log" -ForegroundColor White
    Write-Host ""
    Read-Host "Press Enter to exit"
}

