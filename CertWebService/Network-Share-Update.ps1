<#
.SYNOPSIS
    Network Share CertWebService Update v1.0.0
    
.DESCRIPTION
    Updates CertWebService via network share deployment
    Copies updated CertWebService.ps1 to network location for servers to pick up
#>

param([switch]$Force)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  NETWORK SHARE UPDATE v1.0.0" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$servers = @("UVWmgmt01", "UVW-FINANZ01", "UVWDC001")
$networkPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService"

Write-Host "Target servers:" -ForegroundColor Yellow
foreach ($server in $servers) {
    Write-Host "  - $server (v2.4.0 -> v2.5.0)" -ForegroundColor White
}
Write-Host ""
Write-Host "Network deployment path: $networkPath" -ForegroundColor Yellow
Write-Host ""

if (-not $Force) {
    $confirm = Read-Host "Proceed with network deployment? (y/N)"
    if ($confirm -ne 'y') {
        Write-Host "Update cancelled" -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "Step 1: Preparing network deployment..." -ForegroundColor Cyan

try {
    # Test network path
    if (-not (Test-Path $networkPath)) {
        Write-Host "  Creating deployment directory..." -ForegroundColor Yellow
        New-Item -Path $networkPath -ItemType Directory -Force | Out-Null
    }
    
    # Copy CertWebService v2.5.0 to network location
    Write-Host "  Copying CertWebService v2.5.0 to network share..." -ForegroundColor Yellow
    
    $sourceFile = "$PSScriptRoot\CertWebService.ps1"
    $targetFile = "$networkPath\CertWebService-v2.5.0.ps1"
    
    Copy-Item -Path $sourceFile -Destination $targetFile -Force
    
    # Create update script
    $updateScript = @"
# CertWebService Update Script - Auto-generated $(Get-Date)
`$ErrorActionPreference = "Stop"

Write-Host "Starting CertWebService Update to v2.5.0..." -ForegroundColor Cyan

try {
    # Stop existing service
    Get-Process powershell | Where-Object { `$_.CommandLine -like "*CertWebService*" } | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    
    # Backup current version
    if (Test-Path "C:\CertWebService\CertWebService.ps1") {
        Copy-Item "C:\CertWebService\CertWebService.ps1" "C:\CertWebService\CertWebService-backup-`$(Get-Date -Format 'yyyyMMdd-HHmmss').ps1" -Force
    }
    
    # Copy new version
    Copy-Item "$targetFile" "C:\CertWebService\CertWebService.ps1" -Force
    
    # Start new service
    Set-Location "C:\CertWebService"
    Start-Process powershell -ArgumentList "-File CertWebService.ps1" -WindowStyle Hidden
    
    # Wait and verify
    Start-Sleep -Seconds 5
    `$response = Invoke-WebRequest -Uri "http://localhost:9080/health.json" -TimeoutSec 10
    `$health = `$response.Content | ConvertFrom-Json
    
    Write-Host "Update successful! New version: `$(`$health.version)" -ForegroundColor Green
    
} catch {
    Write-Host "Update failed: `$(`$_.Exception.Message)" -ForegroundColor Red
    exit 1
}
"@
    
    $updateScriptPath = "$networkPath\Update-CertWebService.ps1"
    $updateScript | Out-File -FilePath $updateScriptPath -Encoding UTF8 -Force
    
    Write-Host "  Network deployment prepared successfully!" -ForegroundColor Green
    
} catch {
    Write-Host "  Failed to prepare network deployment: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 2: Manual update instructions..." -ForegroundColor Cyan
Write-Host ""

Write-Host "The following files have been deployed to the network share:" -ForegroundColor Yellow
Write-Host "  - CertWebService-v2.5.0.ps1" -ForegroundColor White
Write-Host "  - Update-CertWebService.ps1" -ForegroundColor White
Write-Host ""

Write-Host "To update each server, run this command on each target machine:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  powershell -ExecutionPolicy Bypass -File `"$updateScriptPath`"" -ForegroundColor Cyan
Write-Host ""

Write-Host "Or connect to each server and run:" -ForegroundColor Yellow
Write-Host ""

foreach ($server in $servers) {
    $fqdn = switch ($server) {
        "UVWmgmt01" { "UVWmgmt01.uvw.meduniwien.ac.at" }
        "UVW-FINANZ01" { "UVW-FINANZ01.uvw.meduniwien.ac.at" }
        "UVWDC001" { "UVWDC001.uvw.meduniwien.ac.at" }
    }
    
    Write-Host "# $server ($fqdn)" -ForegroundColor Gray
    Write-Host "Enter-PSSession -ComputerName $fqdn" -ForegroundColor Cyan
    Write-Host "powershell -ExecutionPolicy Bypass -File `"$updateScriptPath`"" -ForegroundColor White
    Write-Host "Exit-PSSession" -ForegroundColor Cyan
    Write-Host ""
}

Write-Host "Alternative: Use RDP to connect to each server and run the update script locally." -ForegroundColor Yellow
Write-Host ""

# Try to create a batch file for easy execution
$batchContent = @"
@echo off
echo ==========================================
echo   CERTWEBSERVICE UPDATE BATCH v1.0.0
echo ==========================================
echo.

echo Updating CertWebService to v2.5.0...
powershell -ExecutionPolicy Bypass -File "$updateScriptPath"

echo.
echo Update completed!
pause
"@

$batchPath = "$networkPath\Update-CertWebService.bat"
$batchContent | Out-File -FilePath $batchPath -Encoding ASCII -Force

Write-Host "Batch file created: $batchPath" -ForegroundColor Green
Write-Host "Servers can also run the .bat file directly!" -ForegroundColor Green
Write-Host ""

Write-Host "Network deployment completed successfully!" -ForegroundColor Green
Write-Host "Files are ready for manual execution on target servers." -ForegroundColor Yellow