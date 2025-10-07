#requires -Version 5.1

<#
.SYNOPSIS
    CertWebService Update Test v1.0.0

.DESCRIPTION
    Schneller Test für das Update-Deployment-Script
#>

param(
    [string]$Filter = "",
    [switch]$TestOnly = $true
)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  CERTWEBSERVICE UPDATE TEST" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Excel-Reading
Write-Host "[TEST 1] Excel Server List Reading..." -ForegroundColor Yellow
try {
    .\Update-CertWebService-Deployment.ps1 -TestOnly -Filter $Filter -MaxConcurrent 3
    Write-Host "[OK] Test completed successfully" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Test failed: $($_.Exception.Message)" -ForegroundColor Red
}