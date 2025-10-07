<#
.SYNOPSIS
    Local Server Update v1.0.0 - Direct Server Access
    
.DESCRIPTION
    Direkter Update-Ansatz über administrative Freigaben (C$)
#>

param([switch]$Force)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  LOCAL SERVER UPDATE v1.0.0" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$servers = @(
    @{ Name = "UVWmgmt01"; FQDN = "UVWmgmt01.uvw.meduniwien.ac.at" },
    @{ Name = "UVW-FINANZ01"; FQDN = "UVW-FINANZ01.uvw.meduniwien.ac.at" },
    @{ Name = "UVWDC001"; FQDN = "UVWDC001.uvw.meduniwien.ac.at" }
)

Write-Host "Target servers for CertWebService v2.5.0 update:" -ForegroundColor Yellow
foreach ($server in $servers) {
    Write-Host "  - $($server.Name)" -ForegroundColor White
}
Write-Host ""

if (-not $Force) {
    $confirm = Read-Host "Proceed with direct file update? (y/N)"
    if ($confirm -ne 'y') {
        Write-Host "Update cancelled" -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "Starting direct file updates..." -ForegroundColor Cyan
Write-Host ""

$results = @()

foreach ($server in $servers) {
    Write-Host "Processing $($server.Name)..." -ForegroundColor Yellow
    
    try {
        # Try to access admin share
        $adminPath = "\\$($server.FQDN)\C$\CertWebService"
        
        Write-Host "  Testing admin share access..." -NoNewline
        if (Test-Path $adminPath) {
            Write-Host " OK" -ForegroundColor Green
            
            # Backup current file
            $currentFile = "$adminPath\CertWebService.ps1"
            if (Test-Path $currentFile) {
                $backupFile = "$adminPath\CertWebService-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').ps1"
                Write-Host "  Creating backup..." -NoNewline
                Copy-Item $currentFile $backupFile -Force
                Write-Host " OK" -ForegroundColor Green
            }
            
            # Copy new version
            Write-Host "  Copying CertWebService v2.5.0..." -NoNewline
            Copy-Item "$PSScriptRoot\CertWebService.ps1" $currentFile -Force
            Write-Host " OK" -ForegroundColor Green
            
            # Create restart script on server
            $restartScript = @"
# Auto-generated restart script for CertWebService
Write-Host "Restarting CertWebService..." -ForegroundColor Cyan

# Stop old process
Get-Process powershell | Where-Object { `$_.CommandLine -like "*CertWebService*" } | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

# Start new service  
Set-Location "C:\CertWebService"
Start-Process powershell -ArgumentList "-File CertWebService.ps1" -WindowStyle Hidden

# Verify
Start-Sleep -Seconds 5
try {
    `$response = Invoke-WebRequest -Uri "http://localhost:9080/health.json" -TimeoutSec 10
    `$health = `$response.Content | ConvertFrom-Json
    Write-Host "CertWebService restarted successfully! Version: `$(`$health.version)" -ForegroundColor Green
} catch {
    Write-Host "Failed to verify CertWebService: `$(`$_.Exception.Message)" -ForegroundColor Red
}
"@
            
            $restartScriptPath = "$adminPath\Restart-CertWebService.ps1"
            $restartScript | Out-File -FilePath $restartScriptPath -Encoding UTF8 -Force
            
            Write-Host "  Created restart script: Restart-CertWebService.ps1" -ForegroundColor Green
            
            $results += @{
                Server = $server.Name
                Success = $true
                Action = "File updated, restart script created"
                RestartScript = $restartScriptPath
            }
            
        } else {
            Write-Host " FAILED - No admin share access" -ForegroundColor Red
            
            $results += @{
                Server = $server.Name
                Success = $false
                Error = "Admin share not accessible"
            }
        }
        
    } catch {
        Write-Host " ERROR: $($_.Exception.Message)" -ForegroundColor Red
        
        $results += @{
            Server = $server.Name
            Success = $false
            Error = $_.Exception.Message
        }
    }
    
    Write-Host ""
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  UPDATE RESULTS" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$successful = $results | Where-Object Success
$failed = $results | Where-Object { -not $_.Success }

Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  Files updated: $($successful.Count)" -ForegroundColor Green
Write-Host "  Failed: $($failed.Count)" -ForegroundColor Red
Write-Host ""

if ($successful) {
    Write-Host "Successfully updated files:" -ForegroundColor Green
    foreach ($result in $successful) {
        Write-Host "  ✓ $($result.Server) - $($result.Action)" -ForegroundColor Green
    }
    Write-Host ""
    
    Write-Host "IMPORTANT: Services need to be restarted!" -ForegroundColor Yellow
    Write-Host "Run these restart scripts on each server:" -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($result in $successful) {
        $serverPath = $result.RestartScript -replace "\\\\[^\\]+\\", ""
        Write-Host "# $($result.Server)" -ForegroundColor Gray
        Write-Host "On server $($result.Server), run:" -ForegroundColor White
        Write-Host "  powershell -ExecutionPolicy Bypass -File `"$serverPath`"" -ForegroundColor Cyan
        Write-Host ""
    }
}

if ($failed) {
    Write-Host "Failed updates:" -ForegroundColor Red
    foreach ($result in $failed) {
        Write-Host "  ✗ $($result.Server): $($result.Error)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Local server update completed!" -ForegroundColor Green
Write-Host "REMINDER: Restart the CertWebService on updated servers!" -ForegroundColor Yellow