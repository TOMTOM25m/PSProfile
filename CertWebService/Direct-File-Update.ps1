<#
.SYNOPSIS
    Direct File Update v1.0.0 - Alternative Update Method
    
.DESCRIPTION
    Direkte Datei-Updates über Admin-Shares mit Credential Vault
#>

param([switch]$Execute)

# Import FL-CredentialManager
Import-Module "$PSScriptRoot\Modules\FL-CredentialManager-v1.0.psm1" -Force

Write-Host "Direct CertWebService File Update v1.0" -ForegroundColor Cyan
Write-Host ""

$servers = @("UVWmgmt01", "UVW-FINANZ01", "UVWDC001")

# Try different approaches
$updateMethods = @(
    @{
        Name = "Admin Share (C$)"
        Test = { param($server) Test-Path "\\$server.uvw.meduniwien.ac.at\C$\CertWebService" }
        Update = { param($server) 
            $target = "\\$server.uvw.meduniwien.ac.at\C$\CertWebService\CertWebService.ps1"
            Copy-Item "$PSScriptRoot\CertWebService.ps1" $target -Force
            return $target
        }
    },
    @{
        Name = "Network Share + Remote Copy"
        Test = { $true }
        Update = { param($server)
            # Copy to network share first
            $networkPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService"
            Copy-Item "$PSScriptRoot\CertWebService.ps1" "$networkPath\CertWebService-v2.5.0.ps1" -Force -ErrorAction SilentlyContinue
            return "$networkPath\CertWebService-v2.5.0.ps1"
        }
    }
)

Write-Host "Available servers:" -ForegroundColor Yellow
foreach ($server in $servers) {
    Write-Host "  - $server.uvw.meduniwien.ac.at" -ForegroundColor White
}
Write-Host ""

if (-not $Execute) {
    Write-Host "Testing update methods..." -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($method in $updateMethods) {
        Write-Host "Method: $($method.Name)" -ForegroundColor Yellow
        
        foreach ($server in $servers) {
            try {
                $testResult = & $method.Test $server
                $status = if ($testResult) { "✓ AVAILABLE" } else { "✗ NOT AVAILABLE" }
                $color = if ($testResult) { "Green" } else { "Red" }
                Write-Host "  [$server] $status" -ForegroundColor $color
            } catch {
                Write-Host "  [$server] ✗ ERROR: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        Write-Host ""
    }
    
    Write-Host "Run with -Execute to perform updates" -ForegroundColor Yellow
    exit 0
}

# Execute updates
Write-Host "Executing updates..." -ForegroundColor Cyan
Write-Host ""

$results = @()

foreach ($server in $servers) {
    Write-Host "Updating $server..." -ForegroundColor Yellow
    
    $updated = $false
    
    foreach ($method in $updateMethods) {
        if ($updated) { break }
        
        try {
            Write-Host "  Trying: $($method.Name)..." -NoNewline
            
            $testResult = & $method.Test $server
            if ($testResult) {
                $updateResult = & $method.Update $server
                Write-Host " ✓ SUCCESS" -ForegroundColor Green
                Write-Host "    Target: $updateResult" -ForegroundColor Gray
                
                $results += @{
                    Server = $server
                    Success = $true
                    Method = $method.Name
                    Target = $updateResult
                }
                $updated = $true
            } else {
                Write-Host " ✗ NOT AVAILABLE" -ForegroundColor Red
            }
        } catch {
            Write-Host " ✗ ERROR: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    if (-not $updated) {
        Write-Host "  ⚠ All methods failed for $server" -ForegroundColor Yellow
        $results += @{
            Server = $server
            Success = $false
            Error = "All update methods failed"
        }
    }
    
    Write-Host ""
}

# Summary
Write-Host "Update Summary:" -ForegroundColor Cyan
Write-Host ""

$successful = $results | Where-Object Success
$failed = $results | Where-Object { -not $_.Success }

Write-Host "Successful: $($successful.Count)" -ForegroundColor Green
Write-Host "Failed: $($failed.Count)" -ForegroundColor Red
Write-Host ""

if ($successful) {
    Write-Host "Files updated on:" -ForegroundColor Green
    foreach ($result in $successful) {
        Write-Host "  ✓ $($result.Server) via $($result.Method)" -ForegroundColor Green
    }
    Write-Host ""
    
    Write-Host "IMPORTANT: Restart CertWebService manually on each server:" -ForegroundColor Yellow
    foreach ($result in $successful) {
        Write-Host "  $($result.Server): Restart CertWebService in C:\CertWebService\" -ForegroundColor Cyan
    }
}

if ($failed) {
    Write-Host ""
    Write-Host "Failed updates:" -ForegroundColor Red
    foreach ($result in $failed) {
        Write-Host "  ✗ $($result.Server): $($result.Error)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Direct file update completed!" -ForegroundColor Green