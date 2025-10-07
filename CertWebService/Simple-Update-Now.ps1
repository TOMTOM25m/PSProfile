<#
.SYNOPSIS
    Simple CertWebService Update v1.0.0
    
.DESCRIPTION
    Einfaches Update für CertWebService v2.5.0 auf UVW-Servern
#>

param([switch]$Force)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  SIMPLE CERTWEBSERVICE UPDATE v1.0.0" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$servers = @("UVWmgmt01", "UVW-FINANZ01", "UVWDC001")

Write-Host "Servers to update:" -ForegroundColor Yellow
foreach ($server in $servers) {
    Write-Host "  - $server (v2.4.0 -> v2.5.0)" -ForegroundColor White
}
Write-Host ""

if (-not $Force) {
    $confirm = Read-Host "Proceed with update? (y/N)"
    if ($confirm -ne 'y') {
        Write-Host "Update cancelled" -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "Getting credentials..." -ForegroundColor Cyan
$cred = Get-Credential -Message "Enter admin credentials for server access"

if (-not $cred) {
    Write-Host "No credentials provided - exiting" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Starting updates..." -ForegroundColor Cyan

$results = @()

foreach ($serverName in $servers) {
    Write-Host ""
    Write-Host "Processing $serverName..." -ForegroundColor Yellow
    
    $fqdn = switch ($serverName) {
        "UVWmgmt01" { "UVWmgmt01.uvw.meduniwien.ac.at" }
        "UVW-FINANZ01" { "UVW-FINANZ01.uvw.meduniwien.ac.at" }
        "UVWDC001" { "UVWDC001.uvw.meduniwien.ac.at" }
    }
    
    try {
        # Test WinRM connection
        Write-Host "  Testing WinRM connection..." -NoNewline
        $testResult = Test-WSMan -ComputerName $fqdn -Credential $cred -ErrorAction Stop
        Write-Host " OK" -ForegroundColor Green
        
        # Copy CertWebService.ps1 via PSSession
        Write-Host "  Updating CertWebService..." -NoNewline
        
        $session = New-PSSession -ComputerName $fqdn -Credential $cred
        
        # Copy file
        Copy-Item -Path "$PSScriptRoot\CertWebService.ps1" -Destination "C:\CertWebService\CertWebService.ps1" -ToSession $session -Force
        
        # Restart service
        Invoke-Command -Session $session -ScriptBlock {
            # Stop old process
            Get-Process powershell | Where-Object { $_.CommandLine -like "*CertWebService*" } | Stop-Process -Force -ErrorAction SilentlyContinue
            
            # Start new service
            Set-Location "C:\CertWebService"
            Start-Process powershell -ArgumentList "-File CertWebService.ps1" -WindowStyle Hidden
            
            # Wait and test
            Start-Sleep -Seconds 5
            $response = Invoke-WebRequest -Uri "http://localhost:9080/health.json" -TimeoutSec 10
            $health = $response.Content | ConvertFrom-Json
            return $health.version
        } -OutVariable newVersion | Out-Null
        
        Remove-PSSession $session
        
        Write-Host " SUCCESS (Version: $newVersion)" -ForegroundColor Green
        
        $results += @{
            Server = $serverName
            Success = $true
            Version = $newVersion
        }
        
    } catch {
        Write-Host " FAILED: $($_.Exception.Message)" -ForegroundColor Red
        
        $results += @{
            Server = $serverName
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  UPDATE RESULTS" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$successful = $results | Where-Object Success
$failed = $results | Where-Object { -not $_.Success }

Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  Successful: $($successful.Count)" -ForegroundColor Green
Write-Host "  Failed: $($failed.Count)" -ForegroundColor Red
Write-Host ""

if ($successful) {
    Write-Host "Successfully updated:" -ForegroundColor Green
    foreach ($result in $successful) {
        Write-Host "  - $($result.Server) -> $($result.Version)" -ForegroundColor Green
    }
}

if ($failed) {
    Write-Host ""
    Write-Host "Failed updates:" -ForegroundColor Red
    foreach ($result in $failed) {
        Write-Host "  - $($result.Server): $($result.Error)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Update completed!" -ForegroundColor Green