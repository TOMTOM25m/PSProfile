#requires -Version 5.1

<#
.SYNOPSIS
    Test script for PowerShell Profile Reset System functionality
.DESCRIPTION
    Comprehensive test suite for Reset-PowerShellProfiles.ps1 according to MUW-Regelwerk v9.6.0
.NOTES
    Author: Flecki (Tom) Garnreiter
    Version: v1.0.0
    Regelwerk: v9.6.0
    Created: 2025-09-27
#>

# Load VERSION.ps1 for version information
. (Join-Path (Split-Path -Path $MyInvocation.MyCommand.Path -Parent) "..\VERSION.ps1")
Show-ScriptInfo -ScriptName "ResetProfile Test Suite" -CurrentVersion "v1.0.0"

#region Test Configuration
$TestResults = @()
$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Path -Parent | Split-Path -Parent
$ModulesPath = Join-Path $ScriptDirectory "Modules"

Write-Host "🧪 Starting ResetProfile Test Suite" -ForegroundColor Cyan
Write-Host "📂 Script Directory: $ScriptDirectory" -ForegroundColor Gray
#endregion

#region Module Loading Tests
function Test-ModuleLoading {
    param([string]$TestName = "Module Loading Test")
    
    Write-Host "`n[TEST] $TestName" -ForegroundColor Yellow
    
    $RequiredModules = @(
        'FL-Config.psm1',
        'FL-Logging.psm1',
        'FL-Utils.psm1',
        'FL-Maintenance.psm1',
        'FL-Gui.psm1',
        'FL-Gui-Clean.psm1'
    )
    
    $TestResult = @{
        TestName = $TestName
        Status = "PASS"
        Details = @()
        ModulesFound = 0
        ModulesExpected = $RequiredModules.Count
    }
    
    foreach ($Module in $RequiredModules) {
        $ModulePath = Join-Path $ModulesPath $Module
        if (Test-Path $ModulePath) {
            try {
                Import-Module $ModulePath -Force -ErrorAction Stop
                Write-Host "  ✅ $Module loaded successfully" -ForegroundColor Green
                $TestResult.ModulesFound++
                $TestResult.Details += "✅ $Module: OK"
            } catch {
                Write-Host "  ❌ $Module failed to load: $($_.Exception.Message)" -ForegroundColor Red
                $TestResult.Status = "FAIL"
                $TestResult.Details += "❌ $Module: FAILED - $($_.Exception.Message)"
            }
        } else {
            Write-Host "  ❌ $Module not found" -ForegroundColor Red
            $TestResult.Status = "FAIL"
            $TestResult.Details += "❌ $Module: NOT FOUND"
        }
    }
    
    return $TestResult
}
#endregion

#region Cross-Script Communication Tests
function Test-CrossScriptCommunication {
    param([string]$TestName = "Cross-Script Communication Test")
    
    Write-Host "`n[TEST] $TestName" -ForegroundColor Yellow
    
    $TestResult = @{
        TestName = $TestName
        Status = "PASS"
        Details = @()
    }
    
    try {
        # Test Send-ScriptMessage function
        if (Get-Command Send-ScriptMessage -ErrorAction SilentlyContinue) {
            Send-ScriptMessage -TargetScript "TestTarget" -Message "Test message from ResetProfile" -Type "TEST"
            Write-Host "  ✅ Send-ScriptMessage function works" -ForegroundColor Green
            $TestResult.Details += "✅ Send-ScriptMessage: OK"
        } else {
            throw "Send-ScriptMessage function not found"
        }
        
        # Test Set-ScriptStatus function
        if (Get-Command Set-ScriptStatus -ErrorAction SilentlyContinue) {
            Set-ScriptStatus -Status "TESTING" -Details @{TestMode = $true; TestTime = Get-Date}
            Write-Host "  ✅ Set-ScriptStatus function works" -ForegroundColor Green
            $TestResult.Details += "✅ Set-ScriptStatus: OK"
        } else {
            throw "Set-ScriptStatus function not found"
        }
        
        # Test Get-ScriptStatus function
        if (Get-Command Get-ScriptStatus -ErrorAction SilentlyContinue) {
            $Status = Get-ScriptStatus -ScriptName "Reset-PowerShellProfiles.ps1"
            Write-Host "  ✅ Get-ScriptStatus function works" -ForegroundColor Green
            $TestResult.Details += "✅ Get-ScriptStatus: OK"
        } else {
            throw "Get-ScriptStatus function not found"
        }
        
    } catch {
        Write-Host "  ❌ Cross-Script Communication failed: $($_.Exception.Message)" -ForegroundColor Red
        $TestResult.Status = "FAIL"
        $TestResult.Details += "❌ Cross-Script Communication: FAILED - $($_.Exception.Message)"
    }
    
    return $TestResult
}
#endregion

#region Configuration Tests
function Test-Configuration {
    param([string]$TestName = "Configuration System Test")
    
    Write-Host "`n[TEST] $TestName" -ForegroundColor Yellow
    
    $TestResult = @{
        TestName = $TestName
        Status = "PASS"
        Details = @()
    }
    
    $ConfigPath = Join-Path $ScriptDirectory "Config"
    $ConfigFiles = @(
        "Config-Reset-PowerShellProfiles.ps1.json",
        "de-DE.json",
        "en-US.json"
    )
    
    foreach ($ConfigFile in $ConfigFiles) {
        $FilePath = Join-Path $ConfigPath $ConfigFile
        if (Test-Path $FilePath) {
            try {
                $Content = Get-Content $FilePath | ConvertFrom-Json
                Write-Host "  ✅ $ConfigFile is valid JSON" -ForegroundColor Green
                $TestResult.Details += "✅ $ConfigFile: Valid JSON"
            } catch {
                Write-Host "  ❌ $ConfigFile has invalid JSON: $($_.Exception.Message)" -ForegroundColor Red
                $TestResult.Status = "FAIL"
                $TestResult.Details += "❌ $ConfigFile: Invalid JSON - $($_.Exception.Message)"
            }
        } else {
            Write-Host "  ⚠️ $ConfigFile not found (may be created on first run)" -ForegroundColor Yellow
            $TestResult.Details += "⚠️ $ConfigFile: Not found"
        }
    }
    
    return $TestResult
}
#endregion

#region Regelwerk Compliance Tests
function Test-RegelwerkCompliance {
    param([string]$TestName = "Regelwerk v9.6.0 Compliance Test")
    
    Write-Host "`n[TEST] $TestName" -ForegroundColor Yellow
    
    $TestResult = @{
        TestName = $TestName
        Status = "PASS"
        Details = @()
        ComplianceScore = 0
        MaxScore = 10
    }
    
    # Check VERSION.ps1 exists
    $VersionFile = Join-Path $ScriptDirectory "VERSION.ps1"
    if (Test-Path $VersionFile) {
        Write-Host "  ✅ VERSION.ps1 exists" -ForegroundColor Green
        $TestResult.Details += "✅ VERSION.ps1: EXISTS"
        $TestResult.ComplianceScore++
    } else {
        Write-Host "  ❌ VERSION.ps1 missing" -ForegroundColor Red
        $TestResult.Status = "FAIL"
        $TestResult.Details += "❌ VERSION.ps1: MISSING"
    }
    
    # Check TEST/ directory exists
    $TestDir = Join-Path $ScriptDirectory "TEST"
    if (Test-Path $TestDir) {
        Write-Host "  ✅ TEST/ directory exists" -ForegroundColor Green
        $TestResult.Details += "✅ TEST/ directory: EXISTS"
        $TestResult.ComplianceScore++
    }
    
    # Check Docs/ directory exists
    $DocsDir = Join-Path $ScriptDirectory "Docs"
    if (Test-Path $DocsDir) {
        Write-Host "  ✅ Docs/ directory exists" -ForegroundColor Green
        $TestResult.Details += "✅ Docs/ directory: EXISTS"
        $TestResult.ComplianceScore++
    }
    
    # Check old/ directory exists
    $OldDir = Join-Path $ScriptDirectory "old"
    if (Test-Path $OldDir) {
        Write-Host "  ✅ old/ directory exists" -ForegroundColor Green
        $TestResult.Details += "✅ old/ directory: EXISTS"
        $TestResult.ComplianceScore++
    }
    
    # Check FL-* modules naming convention
    $ModuleFiles = Get-ChildItem -Path $ModulesPath -Filter "FL-*.psm1" -ErrorAction SilentlyContinue
    if ($ModuleFiles.Count -gt 0) {
        Write-Host "  ✅ FL-* naming convention followed ($($ModuleFiles.Count) modules)" -ForegroundColor Green
        $TestResult.Details += "✅ FL-* naming: $($ModuleFiles.Count) modules"
        $TestResult.ComplianceScore += 2
    }
    
    # Calculate compliance percentage
    $CompliancePercentage = [math]::Round(($TestResult.ComplianceScore / $TestResult.MaxScore) * 100)
    Write-Host "  📊 Compliance Score: $($TestResult.ComplianceScore)/$($TestResult.MaxScore) ($CompliancePercentage%)" -ForegroundColor Cyan
    
    return $TestResult
}
#endregion

#region Execute All Tests
Write-Host "`n🚀 Executing ResetProfile Test Suite" -ForegroundColor Green

# Run all tests
$TestResults += Test-ModuleLoading
$TestResults += Test-CrossScriptCommunication
$TestResults += Test-Configuration
$TestResults += Test-RegelwerkCompliance

# Generate summary
Write-Host "`n📊 TEST SUMMARY" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Gray

$PassedTests = ($TestResults | Where-Object { $_.Status -eq "PASS" }).Count
$TotalTests = $TestResults.Count

foreach ($Test in $TestResults) {
    $StatusColor = if ($Test.Status -eq "PASS") { "Green" } else { "Red" }
    $StatusIcon = if ($Test.Status -eq "PASS") { "✅" } else { "❌" }
    
    Write-Host "$StatusIcon $($Test.TestName): $($Test.Status)" -ForegroundColor $StatusColor
}

Write-Host "`n🎯 Overall Result: $PassedTests/$TotalTests tests passed" -ForegroundColor $(if ($PassedTests -eq $TotalTests) { "Green" } else { "Yellow" })

if ($PassedTests -eq $TotalTests) {
    Write-Host "🎉 All tests passed! ResetProfile system is ready for production." -ForegroundColor Green
    Set-ScriptStatus -Status "READY" -Details @{TestsPassed = $PassedTests; TestsTotal = $TotalTests}
} else {
    Write-Host "⚠️ Some tests failed. Review results before production deployment." -ForegroundColor Yellow
    Set-ScriptStatus -Status "NEEDS_ATTENTION" -Details @{TestsPassed = $PassedTests; TestsTotal = $TotalTests}
}
#endregion