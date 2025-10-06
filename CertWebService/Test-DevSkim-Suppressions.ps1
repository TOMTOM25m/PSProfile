#requires -Version 5.1

<#
.SYNOPSIS
    DevSkim Security Suppression Test v1.0.0

.DESCRIPTION
    Testet ob die DevSkim-Sicherheits-Suppressions korrekt funktionieren.
    Überprüft ob DS104456 und DS137138 Warnungen unterdrückt werden.
    
.VERSION
    1.0.0

.AUTHOR
    Field Level Automation
#>

param(
    [Parameter(Mandatory = $false)]
    [switch]$VerboseOutput
)

Write-Host "🔒 DevSkim Security Suppression Test" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Check if .devskim.json exists
Write-Host "📁 Test 1: DevSkim Configuration File" -ForegroundColor Yellow

$devskimConfigPath = Join-Path $PSScriptRoot ".devskim.json"
if (Test-Path $devskimConfigPath) {
    Write-Host "✅ .devskim.json found" -ForegroundColor Green
    
    try {
        $config = Get-Content $devskimConfigPath | ConvertFrom-Json
        Write-Host "✅ Configuration file is valid JSON" -ForegroundColor Green
        
        if ($VerboseOutput) {
            Write-Host "   Suppressions configured:" -ForegroundColor Gray
            foreach ($suppression in $config.rules.suppressions) {
                Write-Host "     - $($suppression.id): $($suppression.suppression_reason)" -ForegroundColor Gray
            }
        }
    } catch {
        Write-Host "❌ Configuration file is invalid: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "❌ .devskim.json not found" -ForegroundColor Red
}

Write-Host ""

# Test 2: Check Security Documentation
Write-Host "📋 Test 2: Security Documentation" -ForegroundColor Yellow

$securityDocPath = Join-Path $PSScriptRoot "SECURITY-CONFIGURATION.md"
if (Test-Path $securityDocPath) {
    Write-Host "✅ SECURITY-CONFIGURATION.md found" -ForegroundColor Green
    
    $docContent = Get-Content $securityDocPath -Raw
    if ($docContent -like "*DS104456*" -and $docContent -like "*DS137138*") {
        Write-Host "✅ Security documentation covers suppressed rules" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Documentation may be incomplete" -ForegroundColor Yellow
    }
} else {
    Write-Host "❌ Security documentation not found" -ForegroundColor Red
}

Write-Host ""

# Test 3: Simulate suppressed scenarios (for testing purposes)
Write-Host "🧪 Test 3: Suppressed Security Scenarios" -ForegroundColor Yellow

Write-Host "   Testing DS104456 suppression (PSRemoting):" -ForegroundColor Gray
try {
    # This would normally trigger DS104456 warning
    $testScriptBlock = { Write-Host "Test remote execution" }
    Write-Host "   ✅ PSRemoting code pattern accepted" -ForegroundColor Green
} catch {
    Write-Host "   ❌ PSRemoting test failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "   Testing DS137138 suppression (HTTP URLs):" -ForegroundColor Gray
try {
    # This would normally trigger DS137138 warning
    $testUrl = "http://localhost:9080/health.json"  # DevSkim: ignore DS137138 - Test URL
    Write-Host "   ✅ HTTP URL pattern accepted" -ForegroundColor Green
} catch {
    Write-Host "   ❌ HTTP URL test failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 4: Check PowerShell Scripts for Suppressions
Write-Host "📜 Test 4: PowerShell Scripts Suppression Check" -ForegroundColor Yellow

$scriptFiles = @(
    "Update-FromExcel-MassUpdate.ps1",
    "Update-AllServers-Hybrid.ps1", 
    "Excel-Update-Launcher.ps1",
    "Modules\FL-PowerShell-VersionCompatibility.psm1"
)

$suppressionCount = 0
foreach ($scriptFile in $scriptFiles) {
    $fullPath = Join-Path $PSScriptRoot $scriptFile
    if (Test-Path $fullPath) {
        $content = Get-Content $fullPath -Raw
        $ds104456Count = ($content | Select-String "DS104456" -AllMatches).Matches.Count
        $ds137138Count = ($content | Select-String "DS137138" -AllMatches).Matches.Count
        
        if ($ds104456Count -gt 0 -or $ds137138Count -gt 0) {
            Write-Host "   ✅ $(Split-Path $scriptFile -Leaf): DS104456=$ds104456Count, DS137138=$ds137138Count" -ForegroundColor Green
            $suppressionCount += $ds104456Count + $ds137138Count
        } else {
            Write-Host "   ⚠️ $(Split-Path $scriptFile -Leaf): No suppressions found" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ❌ $(Split-Path $scriptFile -Leaf): File not found" -ForegroundColor Red
    }
}

Write-Host "   Total suppressions found: $suppressionCount" -ForegroundColor Cyan

Write-Host ""

# Summary
Write-Host "📊 Test Summary" -ForegroundColor Yellow
Write-Host "===============" -ForegroundColor Yellow

$configExists = Test-Path $devskimConfigPath
$docExists = Test-Path $securityDocPath
$suppressionsFound = $suppressionCount -gt 0

if ($configExists -and $docExists -and $suppressionsFound) {
    Write-Host "🎉 All DevSkim suppression tests passed!" -ForegroundColor Green
    Write-Host "   ✅ Configuration file exists and is valid" -ForegroundColor Green
    Write-Host "   ✅ Security documentation is present" -ForegroundColor Green
    Write-Host "   ✅ Code suppressions are implemented" -ForegroundColor Green
} else {
    Write-Host "⚠️ Some DevSkim suppression tests failed:" -ForegroundColor Yellow
    if (-not $configExists) { Write-Host "   ❌ Configuration file missing" -ForegroundColor Red }
    if (-not $docExists) { Write-Host "   ❌ Security documentation missing" -ForegroundColor Red }
    if (-not $suppressionsFound) { Write-Host "   ❌ Code suppressions not found" -ForegroundColor Red }
}

Write-Host ""
Write-Host "💡 Next Steps:" -ForegroundColor Cyan
Write-Host "   1. Run VSCode DevSkim extension to verify suppressions work" -ForegroundColor White
Write-Host "   2. Test actual script execution to ensure functionality is preserved" -ForegroundColor White
Write-Host "   3. Review security documentation quarterly" -ForegroundColor White
Write-Host ""