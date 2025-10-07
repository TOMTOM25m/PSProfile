<#
.SYNOPSIS
    Quick Server Update v1.0.0
#>

param([switch]$Force)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  QUICK SERVER UPDATE v1.0.0" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$servers = @("UVWmgmt01", "UVW-FINANZ01", "UVWDC001")

Write-Host "Servers to update:" -ForegroundColor Yellow
foreach ($server in $servers) {
    Write-Host "  - $server" -ForegroundColor White
}
Write-Host ""

if (-not $Force) {
    $confirm = Read-Host "Proceed? (y/N)"
    if ($confirm -ne 'y') {
        Write-Host "Cancelled" -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "Starting updates..." -ForegroundColor Cyan

foreach ($serverName in $servers) {
    Write-Host ""
    Write-Host "Processing $serverName..." -ForegroundColor Yellow
    
    $fqdn = switch ($serverName) {
        "UVWmgmt01" { "UVWmgmt01.uvw.meduniwien.ac.at" }
        "UVW-FINANZ01" { "UVW-FINANZ01.uvw.meduniwien.ac.at" } 
        "UVWDC001" { "UVWDC001.uvw.meduniwien.ac.at" }
    }
    
    try {
        $adminPath = "\\$fqdn\C$\CertWebService"
        
        Write-Host "  Testing access..." -NoNewline
        if (Test-Path $adminPath) {
            Write-Host " OK" -ForegroundColor Green
            
            $targetFile = "$adminPath\CertWebService.ps1"
            
            # Backup
            if (Test-Path $targetFile) {
                $backup = "$adminPath\CertWebService-backup.ps1"
                Copy-Item $targetFile $backup -Force
                Write-Host "  Backup created" -ForegroundColor Green
            }
            
            # Update
            Write-Host "  Updating file..." -NoNewline
            Copy-Item "$PSScriptRoot\CertWebService.ps1" $targetFile -Force
            Write-Host " OK" -ForegroundColor Green
            
            # Create restart script
            $restartContent = @"
Write-Host "Restarting CertWebService..." -ForegroundColor Cyan
Get-Process powershell | Where-Object { `$_.CommandLine -like "*CertWebService*" } | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
Set-Location "C:\CertWebService"
Start-Process powershell -ArgumentList "-File CertWebService.ps1" -WindowStyle Hidden
Start-Sleep -Seconds 5
try {
    `$response = Invoke-WebRequest -Uri "http://localhost:9080/health.json" -TimeoutSec 10
    `$health = `$response.Content | ConvertFrom-Json
    Write-Host "SUCCESS: Version `$(`$health.version)" -ForegroundColor Green
} catch {
    Write-Host "ERROR: `$(`$_.Exception.Message)" -ForegroundColor Red
}
"@
            
            $restartScript = "$adminPath\Restart-Service.ps1"
            $restartContent | Out-File -FilePath $restartScript -Encoding UTF8 -Force
            
            Write-Host "  ✓ $serverName updated successfully" -ForegroundColor Green
            
        } else {
            Write-Host " FAILED - No access" -ForegroundColor Red
        }
        
    } catch {
        Write-Host " ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Files updated! Now restart services on each server:" -ForegroundColor Yellow
Write-Host ""

foreach ($serverName in $servers) {
    $fqdn = switch ($serverName) {
        "UVWmgmt01" { "UVWmgmt01.uvw.meduniwien.ac.at" }
        "UVW-FINANZ01" { "UVW-FINANZ01.uvw.meduniwien.ac.at" }
        "UVWDC001" { "UVWDC001.uvw.meduniwien.ac.at" }
    }
    
    Write-Host "$serverName: Run Restart-Service.ps1 in C:\CertWebService\" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Update completed!" -ForegroundColor Green