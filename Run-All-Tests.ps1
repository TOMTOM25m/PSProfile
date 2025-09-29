# Run All Certificate Surveillance Tests
# Purpose: Execute all test scripts in the Tests directory
# Author: Certificate Surveillance System
# Date: September 9, 2025

param(
    [Parameter(Mandatory = $false)]
    [string]$Filter = "Test-*.ps1",
    
    [Parameter(Mandatory = $false)]
    [switch]$DetailedOutput,
    
    [Parameter(Mandatory = $false)]
    [switch]$StopOnError
)

Write-Host "=== Certificate Surveillance System - Test Runner ===" -ForegroundColor Green
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "Filter: $Filter" -ForegroundColor Gray
Write-Host ""

# Change to Tests directory
$TestsPath = Join-Path $PSScriptRoot "Tests"
if (-not (Test-Path $TestsPath)) {
    Write-Host "ERROR: Tests directory not found at: $TestsPath" -ForegroundColor Red
    exit 1
}

Set-Location $TestsPath

# Get all test scripts
$TestScripts = Get-ChildItem -Filter $Filter | Sort-Object Name

if ($TestScripts.Count -eq 0) {
    Write-Host "No test scripts found matching filter: $Filter" -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($TestScripts.Count) test script(s):" -ForegroundColor Cyan
foreach ($script in $TestScripts) {
    Write-Host "  - $($script.Name)" -ForegroundColor Gray
}
Write-Host ""

# Run tests
$SuccessCount = 0
$FailureCount = 0
$StartTime = Get-Date

foreach ($script in $TestScripts) {
    $TestStartTime = Get-Date
    Write-Host "=== Running: $($script.Name) ===" -ForegroundColor Yellow
    
    try {
        if ($DetailedOutput) {
            & $script.FullName
        } else {
            & $script.FullName 2>&1 | Out-Host
        }
        
        $TestEndTime = Get-Date
        $TestDuration = ($TestEndTime - $TestStartTime).TotalSeconds
        Write-Host "[SUCCESS] $($script.Name) completed in $($TestDuration.ToString('F2'))s" -ForegroundColor Green
        $SuccessCount++
        
    } catch {
        $TestEndTime = Get-Date
        $TestDuration = ($TestEndTime - $TestStartTime).TotalSeconds
        Write-Host "[FAILURE] $($script.Name) failed after $($TestDuration.ToString('F2'))s" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        $FailureCount++
        
        if ($StopOnError) {
            Write-Host "Stopping test execution due to -StopOnError flag" -ForegroundColor Red
            break
        }
    }
    
    Write-Host ""
}

# Summary
$EndTime = Get-Date
$TotalDuration = ($EndTime - $StartTime).TotalSeconds

Write-Host "=== Test Summary ===" -ForegroundColor Magenta
Write-Host "Total Duration: $($TotalDuration.ToString('F2'))s" -ForegroundColor Gray
Write-Host "Tests Run: $($TestScripts.Count)" -ForegroundColor Gray
Write-Host "Successful: $SuccessCount" -ForegroundColor Green
Write-Host "Failed: $FailureCount" -ForegroundColor $(if ($FailureCount -eq 0) { "Green" } else { "Red" })

if ($FailureCount -eq 0) {
    Write-Host "🎉 All tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ Some tests failed!" -ForegroundColor Red
    exit 1
}
